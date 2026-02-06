<#
.SYNOPSIS
    Clean up duplicate CA policies, named locations, and map group GUIDs.

.DESCRIPTION
    This script:
    1. Removes duplicate Conditional Access policies (keeps most recent)
    2. Removes duplicate Named Locations (keeps most recent)
    3. Imports Custom Security Attributes from JSON
    4. Maps old tenant group GUIDs to new tenant group GUIDs in remaining policies

.NOTES
    Required Graph API Permissions:
        - Policy.ReadWrite.ConditionalAccess
        - Directory.ReadWrite.All
        - Policy.Read.All
        - Group.Read.All
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

# Remove corrupted Exchange module
Remove-Module ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue

Write-Host "`n===================================================" -ForegroundColor Cyan
Write-Host "  IAC Cleanup and GUID Mapping Script" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# Connect to Microsoft Graph
Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Yellow
try {
    Connect-MgGraph -Scopes @(
        'Policy.ReadWrite.ConditionalAccess',
        'Directory.ReadWrite.All',
        'Policy.Read.All',
        'Group.Read.All',
        'CustomSecAttributeDefinition.ReadWrite.All'
    ) -NoWelcome -ErrorAction Stop
    
    $context = Get-MgContext
    Write-Host "✅ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
    Write-Host "   Account: $($context.Account)`n" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Initialize counters
$stats = @{
    PoliciesDeleted = 0
    LocationsDeleted = 0
    PoliciesUpdated = 0
    AttributesCreated = 0
    Errors = @()
}

#region Clean up duplicate CA policies
Write-Host "`n=== Step 1: Cleaning up duplicate CA policies ===" -ForegroundColor Cyan

try {
    $policies = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
    
    # Group by display name
    $policyGroups = $policies.value | Group-Object displayName
    
    Write-Host "Found $($policies.value.Count) total policies" -ForegroundColor Yellow
    Write-Host "Unique policy names: $($policyGroups.Count)" -ForegroundColor Yellow
    
    foreach ($group in $policyGroups) {
        if ($group.Count -gt 1) {
            Write-Host "`n  Policy: '$($group.Name)' has $($group.Count) copies" -ForegroundColor Yellow
            
            # Sort by creation date, keep the most recent one
            $sorted = $group.Group | Sort-Object createdDateTime -Descending
            $toKeep = $sorted[0]
            $toDelete = $sorted[1..($sorted.Count-1)]
            
            Write-Host "    Keeping: ID $($toKeep.id) (created $($toKeep.createdDateTime))" -ForegroundColor Green
            
            foreach ($policy in $toDelete) {
                Write-Host "    Deleting: ID $($policy.id) (created $($policy.createdDateTime))" -ForegroundColor Red
                
                if (-not $WhatIf) {
                    try {
                        Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)" | Out-Null
                        $stats.PoliciesDeleted++
                        Write-Host "      ✅ Deleted" -ForegroundColor Green
                    } catch {
                        Write-Host "      ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                        $stats.Errors += "Policy delete failed: $($group.Name) - $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "      [WhatIf] Would delete this policy" -ForegroundColor Gray
                }
            }
        }
    }
    
    Write-Host "`n✅ Deleted $($stats.PoliciesDeleted) duplicate policies" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error processing policies: $($_.Exception.Message)" -ForegroundColor Red
    $stats.Errors += "Policy cleanup failed: $($_.Exception.Message)"
}
#endregion

#region Clean up duplicate Named Locations
Write-Host "`n=== Step 2: Cleaning up duplicate Named Locations ===" -ForegroundColor Cyan

try {
    $locations = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations'
    
    # Group by display name
    $locationGroups = $locations.value | Group-Object displayName
    
    Write-Host "Found $($locations.value.Count) total locations" -ForegroundColor Yellow
    Write-Host "Unique location names: $($locationGroups.Count)" -ForegroundColor Yellow
    
    # Build location ID mapping (old IDs -> new ID)
    $locationMapping = @{}
    
    foreach ($group in $locationGroups) {
        if ($group.Count -gt 1) {
            Write-Host "`n  Location: '$($group.Name)' has $($group.Count) copies" -ForegroundColor Yellow
            
            # Sort by creation date, keep the most recent one
            $sorted = $group.Group | Sort-Object createdDateTime -Descending
            $toKeep = $sorted[0]
            $toDelete = $sorted[1..($sorted.Count-1)]
            
            Write-Host "    Keeping: ID $($toKeep.id) (created $($toKeep.createdDateTime))" -ForegroundColor Green
            
            # Map old IDs to new ID
            foreach ($location in $toDelete) {
                $locationMapping[$location.id] = $toKeep.id
                Write-Host "    Will remap: $($location.id) -> $($toKeep.id)" -ForegroundColor Yellow
            }
        }
    }
    
    # Remap location IDs in policies if we have any mappings
    if ($locationMapping.Count -gt 0) {
        Write-Host "`n  Updating policies to use newest location IDs..." -ForegroundColor Cyan
        
        $allPolicies = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
        $policiesUpdated = 0
        
        foreach ($policy in $allPolicies.value) {
            $needsUpdate = $false
            $conditions = $policy.conditions
            
            # Check includeLocations
            if ($conditions.locations.includeLocations) {
                $updated = $false
                $newInclude = @()
                
                foreach ($locId in $conditions.locations.includeLocations) {
                    if ($locationMapping.ContainsKey($locId)) {
                        $newInclude += $locationMapping[$locId]
                        $updated = $true
                    } else {
                        $newInclude += $locId
                    }
                }
                
                if ($updated) {
                    $conditions.locations.includeLocations = $newInclude
                    $needsUpdate = $true
                }
            }
            
            # Check excludeLocations
            if ($conditions.locations.excludeLocations) {
                $updated = $false
                $newExclude = @()
                
                foreach ($locId in $conditions.locations.excludeLocations) {
                    if ($locationMapping.ContainsKey($locId)) {
                        $newExclude += $locationMapping[$locId]
                        $updated = $true
                    } else {
                        $newExclude += $locId
                    }
                }
                
                if ($updated) {
                    $conditions.locations.excludeLocations = $newExclude
                    $needsUpdate = $true
                }
            }
            
            # Update policy if needed
            if ($needsUpdate) {
                Write-Host "    Updating policy: $($policy.displayName)" -ForegroundColor Yellow
                
                if (-not $WhatIf) {
                    try {
                        $updateBody = @{
                            conditions = $conditions
                        }
                        
                        Invoke-MgGraphRequest -Method PATCH `
                            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)" `
                            -Body ($updateBody | ConvertTo-Json -Depth 10) `
                            -ContentType "application/json" | Out-Null
                        
                        $policiesUpdated++
                        Write-Host "      ✅ Updated" -ForegroundColor Green
                    } catch {
                        Write-Host "      ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                        $stats.Errors += "Policy location remap failed: $($policy.displayName) - $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "      [WhatIf] Would update this policy" -ForegroundColor Gray
                }
            }
        }
        
        Write-Host "`n  ✅ Updated $policiesUpdated policies with new location IDs" -ForegroundColor Green
    }
    
    # Now delete duplicate locations
    foreach ($group in $locationGroups) {
        if ($group.Count -gt 1) {
            $sorted = $group.Group | Sort-Object createdDateTime -Descending
            $toDelete = $sorted[1..($sorted.Count-1)]
            
            foreach ($location in $toDelete) {
                Write-Host "    Deleting old location: ID $($location.id)" -ForegroundColor Red
                
                if (-not $WhatIf) {
                    try {
                        Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$($location.id)" | Out-Null
                        $stats.LocationsDeleted++
                        Write-Host "      ✅ Deleted" -ForegroundColor Green
                    } catch {
                        Write-Host "      ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                        $stats.Errors += "Location delete failed: $($group.Name) - $($_.Exception.Message)"
                    }
                } else {
                    Write-Host "      [WhatIf] Would delete this location" -ForegroundColor Gray
                }
            }
        }
    }
    
    Write-Host "`n✅ Deleted $($stats.LocationsDeleted) duplicate locations" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error processing locations: $($_.Exception.Message)" -ForegroundColor Red
    $stats.Errors += "Location cleanup failed: $($_.Exception.Message)"
}
#endregion

#region Import Custom Security Attributes
Write-Host "`n=== Step 3: Importing Custom Security Attributes ===" -ForegroundColor Cyan

$attributesPath = "../SecurityAttributes"
if (Test-Path $attributesPath) {
    $attributeFiles = Get-ChildItem -Path $attributesPath -Filter "*.json"
    
    Write-Host "Found $($attributeFiles.Count) attribute definition files" -ForegroundColor Yellow
    
    foreach ($file in $attributeFiles) {
        try {
            $attributeExport = Get-Content $file.FullName -Raw | ConvertFrom-Json
            
            # Handle both old and new JSON formats
            if ($attributeExport.AttributeSetConfig) {
                # New export format
                $attributeSet = $attributeExport.AttributeSetConfig
                $attributes = $attributeExport.AttributeDefinitions
            } elseif ($attributeExport.id) {
                # Old format (direct properties)
                $attributeSet = $attributeExport
                $attributes = $attributeExport.attributes
            } else {
                Write-Host "  ⚠️  Skipping $($file.Name) - not a valid attribute set file" -ForegroundColor Yellow
                continue
            }
            
            Write-Host "`n  Processing: $($attributeSet.id)" -ForegroundColor Yellow
            
            if (-not $WhatIf) {
                # Check if attribute set exists
                try {
                    $existing = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/directory/attributeSets/$($attributeSet.id)" -ErrorAction Stop
                    Write-Host "    ℹ️  Attribute set already exists, skipping" -ForegroundColor Gray
                } catch {
                    if ($_.Exception.Message -match '404|NotFound') {
                        # Create the attribute set
                        $body = @{
                            id = $attributeSet.id
                            description = $attributeSet.description
                            maxAttributesPerSet = $attributeSet.maxAttributesPerSet
                        }
                        
                        try {
                            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/directory/attributeSets" -Body ($body | ConvertTo-Json -Depth 10) | Out-Null
                            $stats.AttributesCreated++
                            Write-Host "    ✅ Created attribute set" -ForegroundColor Green
                            
                            # Create individual attributes
                            if ($attributes) {
                                foreach ($attr in $attributes) {
                                    try {
                                        # Build attribute body (exclude fields that are auto-generated or read-only)
                                        $attrBody = @{
                                            name = $attr.name
                                            description = $attr.description
                                            type = $attr.type
                                            status = if ($attr.status) { $attr.status } else { "Available" }
                                            isCollection = if ($null -ne $attr.isCollection) { $attr.isCollection } else { $false }
                                            isSearchable = if ($null -ne $attr.isSearchable) { $attr.isSearchable } else { $true }
                                            usePreDefinedValuesOnly = if ($null -ne $attr.usePreDefinedValuesOnly) { $attr.usePreDefinedValuesOnly } else { $false }
                                        }
                                        
                                        # Add allowed values if they exist
                                        if ($attr.allowedValues -and $attr.allowedValues.Count -gt 0) {
                                            $attrBody.allowedValues = $attr.allowedValues
                                        }
                                        
                                        $jsonBody = $attrBody | ConvertTo-Json -Depth 10 -Compress
                                        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/directory/customSecurityAttributeDefinitions" -Body $jsonBody -ContentType "application/json" | Out-Null
                                        Write-Host "      ✅ Created attribute: $($attr.name)" -ForegroundColor Green
                                    } catch {
                                        $errorMsg = $_.Exception.Message
                                        if ($errorMsg -match "already exists") {
                                            Write-Host "      ℹ️  Attribute already exists: $($attr.name)" -ForegroundColor Gray
                                        } else {
                                            Write-Host "      ❌ Error creating attribute: $errorMsg" -ForegroundColor Red
                                            $stats.Errors += "Attribute creation failed: $($attr.name) - $errorMsg"
                                        }
                                    }
                                }
                            }
                        } catch {
                            Write-Host "    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                            $stats.Errors += "Attribute set creation failed: $($attributeSet.id) - $($_.Exception.Message)"
                        }
                    } else {
                        throw
                    }
                }
            } else {
                Write-Host "    [WhatIf] Would create attribute set: $($attributeSet.id)" -ForegroundColor Gray
            }
            
        } catch {
            Write-Host "  ❌ Error processing file $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
            $stats.Errors += "Attribute file processing failed: $($file.Name) - $($_.Exception.Message)"
        }
    }
    
    Write-Host "`n✅ Created $($stats.AttributesCreated) custom security attribute sets" -ForegroundColor Green
} else {
    Write-Host "ℹ️  Custom Security Attributes directory not found at: $attributesPath" -ForegroundColor Yellow
    Write-Host "   Skipping attribute import..." -ForegroundColor Gray
}
#endregion

#region Map Group GUIDs in remaining policies
Write-Host "`n=== Step 4: Mapping Group GUIDs in policies ===" -ForegroundColor Cyan

try {
    # Get current group mappings in new tenant
    Write-Host "Retrieving current groups..." -ForegroundColor Yellow
    $allGroups = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups"
    $caGroups = $allGroups.value | Where-Object { $_.displayName -like 'CA-*' -or $_.displayName -like 'Azure-*' }
    
    $groupMapping = @{}
    foreach ($group in $caGroups) {
        $groupMapping[$group.displayName] = $group.id
    }
    
    Write-Host "Found $($groupMapping.Count) CA/Azure groups for mapping:" -ForegroundColor Green
    foreach ($key in $groupMapping.Keys | Sort-Object) {
        Write-Host "  $key -> $($groupMapping[$key])" -ForegroundColor Gray
    }
    
    # Get current policies (after cleanup)
    $currentPolicies = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
    
    Write-Host "`nProcessing $($currentPolicies.value.Count) policies for GUID mapping..." -ForegroundColor Yellow
    
    foreach ($policy in $currentPolicies.value) {
        $needsUpdate = $false
        $updatedConditions = $policy.conditions
        
        # Check if policy has user exclusions with old GUIDs
        if ($updatedConditions.users.excludeGroups) {
            Write-Host "`n  Checking policy: $($policy.displayName)" -ForegroundColor Yellow
            Write-Host "    Current excluded groups: $($updatedConditions.users.excludeGroups.Count)" -ForegroundColor Gray
            
            # For now, we'll clear invalid GUIDs and note which groups should be added
            # You can expand this logic to map specific old GUIDs to new ones if you have that mapping
            $validGroups = @()
            foreach ($groupId in $updatedConditions.users.excludeGroups) {
                # Check if this GUID exists in current tenant
                try {
                    $exists = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$groupId" -ErrorAction Stop
                    $validGroups += $groupId
                } catch {
                    Write-Host "      ⚠️  Invalid group GUID found: $groupId (will be removed)" -ForegroundColor Yellow
                    $needsUpdate = $true
                }
            }
            
            if ($needsUpdate) {
                $updatedConditions.users.excludeGroups = $validGroups
            }
        }
        
        # Update policy if needed
        if ($needsUpdate -and -not $WhatIf) {
            try {
                $updateBody = @{
                    conditions = $updatedConditions
                }
                
                Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)" -Body ($updateBody | ConvertTo-Json -Depth 20) | Out-Null
                $stats.PoliciesUpdated++
                Write-Host "    ✅ Updated policy (removed invalid group GUIDs)" -ForegroundColor Green
            } catch {
                Write-Host "    ❌ Error updating policy: $($_.Exception.Message)" -ForegroundColor Red
                $stats.Errors += "Policy update failed: $($policy.displayName) - $($_.Exception.Message)"
            }
        } elseif ($needsUpdate) {
            Write-Host "    [WhatIf] Would update this policy" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n✅ Updated $($stats.PoliciesUpdated) policies with corrected GUIDs" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error mapping GUIDs: $($_.Exception.Message)" -ForegroundColor Red
    $stats.Errors += "GUID mapping failed: $($_.Exception.Message)"
}
#endregion

# Summary
Write-Host "`n===================================================" -ForegroundColor Cyan
Write-Host "  Cleanup and Mapping Summary" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Duplicate policies deleted:  $($stats.PoliciesDeleted)" -ForegroundColor $(if($stats.PoliciesDeleted -gt 0){'Green'}else{'Gray'})
Write-Host "Duplicate locations deleted: $($stats.LocationsDeleted)" -ForegroundColor $(if($stats.LocationsDeleted -gt 0){'Green'}else{'Gray'})
Write-Host "Attribute sets created:      $($stats.AttributesCreated)" -ForegroundColor $(if($stats.AttributesCreated -gt 0){'Green'}else{'Gray'})
Write-Host "Policies updated (GUIDs):    $($stats.PoliciesUpdated)" -ForegroundColor $(if($stats.PoliciesUpdated -gt 0){'Green'}else{'Gray'})
Write-Host "Errors encountered:          $($stats.Errors.Count)" -ForegroundColor $(if($stats.Errors.Count -gt 0){'Red'}else{'Gray'})

if ($stats.Errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    foreach ($error in $stats.Errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
}

if ($WhatIf) {
    Write-Host "`n⚠️  WhatIf mode: No changes were actually made" -ForegroundColor Yellow
}

Write-Host "`n✅ Cleanup and mapping complete!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Cyan

Disconnect-MgGraph | Out-Null
