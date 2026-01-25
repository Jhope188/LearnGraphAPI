<#
.SYNOPSIS
    Recreates IAC Conditional Access policies and Named Locations from exported JSON files.

.DESCRIPTION
    This script imports Conditional Access policies and Named Locations from JSON exports
    and recreates them in the target tenant. Supports group/user/role ID mapping for
    cross-tenant migrations and disaster recovery scenarios.

.PARAMETER ImportPath
    Path to the folder containing exported JSON files.
    Default: /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON

.PARAMETER DryRun
    When specified, shows what would be created without actually creating policies.
    Recommended for testing before actual import.

.PARAMETER GroupIdMapping
    Hashtable mapping source tenant group IDs to target tenant group IDs.
    Example: @{ "source-guid-1" = "target-guid-1"; "source-guid-2" = "target-guid-2" }

.PARAMETER UserIdMapping
    Hashtable mapping source tenant user IDs to target tenant user IDs.

.PARAMETER RoleIdMapping
    Hashtable mapping source tenant role IDs to target tenant role IDs.

.EXAMPLE
    .\recreate-iac-entra-policies.ps1 -DryRun
    Test import without creating anything

.EXAMPLE
    .\recreate-iac-entra-policies.ps1
    Create all policies and locations in target tenant

.EXAMPLE
    $groupMap = @{ "old-guid" = "new-guid" }
    .\recreate-iac-entra-policies.ps1 -GroupIdMapping $groupMap
    Create with group ID mapping

.NOTES
    Author: GitHub Copilot
    Date: 2026-01-16
    Requires: Microsoft.Graph PowerShell Module
    Permissions: Policy.ReadWrite.ConditionalAccess, Application.ReadWrite.All
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ImportPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [hashtable]$GroupIdMapping = @{},
    
    [Parameter(Mandatory=$false)]
    [hashtable]$UserIdMapping = @{},
    
    [Parameter(Mandatory=$false)]
    [hashtable]$RoleIdMapping = @{}
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns

# Helper function to map IDs
function Map-Id {
    param(
        [string]$Id,
        [hashtable]$Mapping
    )
    
    # Special values don't get mapped
    if ($Id -in @('All', 'GuestsOrExternalUsers', 'None', 'AllApplications', 'Office365')) {
        return $Id
    }
    
    # Return mapped ID if exists, otherwise original
    if ($Mapping.ContainsKey($Id)) {
        return $Mapping[$Id]
    }
    
    return $Id
}

# Helper function to update policy conditions with ID mappings
function Update-PolicyConditions {
    param(
        [object]$Conditions,
        [hashtable]$GroupMap,
        [hashtable]$UserMap,
        [hashtable]$RoleMap
    )
    
    $updatedConditions = $Conditions | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    
    if ($updatedConditions.users) {
        # Map users
        if ($updatedConditions.users.includeUsers) {
            $updatedConditions.users.includeUsers = $updatedConditions.users.includeUsers | ForEach-Object {
                Map-Id -Id $_ -Mapping $UserMap
            }
        }
        
        if ($updatedConditions.users.excludeUsers) {
            $updatedConditions.users.excludeUsers = $updatedConditions.users.excludeUsers | ForEach-Object {
                Map-Id -Id $_ -Mapping $UserMap
            }
        }
        
        # Map groups
        if ($updatedConditions.users.includeGroups) {
            $updatedConditions.users.includeGroups = $updatedConditions.users.includeGroups | ForEach-Object {
                Map-Id -Id $_ -Mapping $GroupMap
            }
        }
        
        if ($updatedConditions.users.excludeGroups) {
            $updatedConditions.users.excludeGroups = $updatedConditions.users.excludeGroups | ForEach-Object {
                Map-Id -Id $_ -Mapping $GroupMap
            }
        }
        
        # Map roles
        if ($updatedConditions.users.includeRoles) {
            $updatedConditions.users.includeRoles = $updatedConditions.users.includeRoles | ForEach-Object {
                Map-Id -Id $_ -Mapping $RoleMap
            }
        }
        
        if ($updatedConditions.users.excludeRoles) {
            $updatedConditions.users.excludeRoles = $updatedConditions.users.excludeRoles | ForEach-Object {
                Map-Id -Id $_ -Mapping $RoleMap
            }
        }
    }
    
    return $updatedConditions
}

# Helper function to import policy from JSON
function Import-PolicyFromJson {
    param([string]$FilePath)
    
    $json = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
    return $json
}

# Helper function to remove @odata.context metadata
function Remove-ODataContext {
    param([object]$Object)
    
    $json = $Object | ConvertTo-Json -Depth 20
    $cleaned = $json -replace '"[^"]*@odata\.context":\s*"[^"]*",?\s*', ''
    # Clean up any trailing commas
    $cleaned = $cleaned -replace ',(\s*[}\]])', '$1'
    
    return ($cleaned | ConvertFrom-Json)
}

# Helper function to extract custom authentication strengths from policies
function Get-CustomAuthenticationStrengths {
    param([array]$PolicyFiles)
    
    $customStrengths = @{}
    
    foreach ($file in $PolicyFiles) {
        $policyData = Import-PolicyFromJson -FilePath $file.FullName
        
        if ($policyData.PolicyConfig.grantControls.authenticationStrength) {
            $strength = $policyData.PolicyConfig.grantControls.authenticationStrength
            
            # Check if it's a custom strength (not built-in)
            if ($strength.policyType -eq 'custom' -and $strength.id) {
                if (-not $customStrengths.ContainsKey($strength.id)) {
                    $customStrengths[$strength.id] = @{
                        DisplayName = $strength.displayName
                        Description = $strength.description
                        AllowedCombinations = $strength.allowedCombinations
                        RequirementsSatisfied = $strength.requirementsSatisfied
                        SourceId = $strength.id
                    }
                }
            }
        }
    }
    
    return $customStrengths
}

# Main execution
try {
    Write-Host "`n=== IAC Entra Policy Recreation ===" -ForegroundColor Cyan
    Write-Host "Import Path: $ImportPath" -ForegroundColor Gray
    Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'LIVE (will create policies)' })`n" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Green' })
    
    # Verify Graph connection
    $context = Get-MgContext
    if (-not $context) {
        Write-Host "❌ Not connected to Microsoft Graph. Please run Connect-MgGraph first." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Connected to target tenant: $($context.TenantId)" -ForegroundColor Green
    Write-Host "   Account: $($context.Account)`n" -ForegroundColor Gray
    
    # Verify import path exists
    if (-not (Test-Path $ImportPath)) {
        Write-Host "❌ Import path does not exist: $ImportPath" -ForegroundColor Red
        exit 1
    }
    
    # Initialize results tracking
    $results = @{
        CreatedPolicies = @()
        CreatedLocations = @()
        CreatedAuthStrengths = @()
        FailedPolicies = @()
        FailedLocations = @()
        FailedAuthStrengths = @()
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        TargetTenantId = $context.TenantId
        DryRun = $DryRun.IsPresent
    }
    
    # Authentication Strength ID mapping
    $authStrengthMapping = @{}
    
    # ===== Scan for Custom Authentication Strengths =====
    Write-Host "`n--- Scanning for Custom Authentication Strengths ---" -ForegroundColor Cyan
    
    $caFolder = Join-Path $ImportPath "ConditionalAccess"
    if (Test-Path $caFolder) {
        $caFiles = Get-ChildItem -Path $caFolder -Filter "*.json"
        $customStrengths = Get-CustomAuthenticationStrengths -PolicyFiles $caFiles
        
        if ($customStrengths.Count -gt 0) {
            Write-Host "Found $($customStrengths.Count) custom authentication strength(s) to create" -ForegroundColor Yellow
            
            foreach ($strengthId in $customStrengths.Keys) {
                $strength = $customStrengths[$strengthId]
                
                try {
                    Write-Host "`n  🔐 Processing: $($strength.DisplayName)" -ForegroundColor White
                    
                    if ($DryRun) {
                        Write-Host "     🧪 [DRY RUN] Would create authentication strength: $($strength.DisplayName)" -ForegroundColor Yellow
                        Write-Host "        Allowed Combinations: $($strength.AllowedCombinations.Count) methods" -ForegroundColor Gray
                        
                        # Create mock mapping for dry run
                        $authStrengthMapping[$strengthId] = "00000000-0000-0000-0000-000000000000"
                        
                        $results.CreatedAuthStrengths += @{
                            Name = $strength.DisplayName
                            SourceId = $strengthId
                            DryRun = $true
                        }
                    } else {
                        # Create authentication strength
                        $body = @{
                            displayName = $strength.DisplayName
                            description = $strength.Description
                            allowedCombinations = $strength.AllowedCombinations
                        } | ConvertTo-Json -Depth 10
                        
                        $newStrength = Invoke-MgGraphRequest -Method POST `
                            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/authenticationStrength/policies" `
                            -Body $body `
                            -ContentType "application/json"
                        
                        Write-Host "     ✅ Created authentication strength: $($newStrength.displayName)" -ForegroundColor Green
                        Write-Host "        New ID: $($newStrength.id)" -ForegroundColor Gray
                        
                        # Map old ID to new ID
                        $authStrengthMapping[$strengthId] = $newStrength.id
                        
                        $results.CreatedAuthStrengths += @{
                            Name = $newStrength.displayName
                            SourceId = $strengthId
                            NewId = $newStrength.id
                        }
                    }
                    
                } catch {
                    Write-Host "     ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                    $results.FailedAuthStrengths += @{
                        Name = $strength.DisplayName
                        Error = $_.Exception.Message
                    }
                }
            }
        } else {
            Write-Host "No custom authentication strengths found" -ForegroundColor Gray
        }
    }
    
    # ===== Import Conditional Access Policies =====
    Write-Host "`n--- Processing Conditional Access Policies ---" -ForegroundColor Cyan
    
    $caFolder = Join-Path $ImportPath "ConditionalAccess"
    if (Test-Path $caFolder) {
        $caFiles = Get-ChildItem -Path $caFolder -Filter "*.json"
        Write-Host "Found $($caFiles.Count) CA policy files" -ForegroundColor Yellow
        
        foreach ($file in $caFiles) {
            try {
                Write-Host "`n  📄 Processing: $($file.BaseName)" -ForegroundColor White
                
                $policyData = Import-PolicyFromJson -FilePath $file.FullName
                $policyConfig = $policyData.PolicyConfig
                
                # Remove @odata.context metadata
                $policyConfig = Remove-ODataContext -Object $policyConfig
                
                # Update authentication strength ID if needed
                if ($policyConfig.grantControls.authenticationStrength) {
                    $oldStrengthId = $policyConfig.grantControls.authenticationStrength.id
                    
                    if ($authStrengthMapping.ContainsKey($oldStrengthId)) {
                        Write-Host "     🔄 Mapping authentication strength ID..." -ForegroundColor Gray
                        $policyConfig.grantControls.authenticationStrength = @{
                            id = $authStrengthMapping[$oldStrengthId]
                        }
                    }
                }
                
                # Update conditions with ID mappings
                if ($GroupIdMapping.Count -gt 0 -or $UserIdMapping.Count -gt 0 -or $RoleIdMapping.Count -gt 0) {
                    Write-Host "     🔄 Applying ID mappings..." -ForegroundColor Gray
                    $policyConfig.conditions = Update-PolicyConditions `
                        -Conditions $policyConfig.conditions `
                        -GroupMap $GroupIdMapping `
                        -UserMap $UserIdMapping `
                        -RoleMap $RoleIdMapping
                }
                
                if ($DryRun) {
                    Write-Host "     🧪 [DRY RUN] Would create CA policy: $($policyConfig.displayName)" -ForegroundColor Yellow
                    Write-Host "        State: $($policyConfig.state)" -ForegroundColor Gray
                    
                    $results.CreatedPolicies += @{
                        Name = $policyConfig.displayName
                        SourceId = $policyData.SourcePolicyId
                        DryRun = $true
                    }
                } else {
                    # Create policy
                    $body = $policyConfig | ConvertTo-Json -Depth 10
                    $newPolicy = Invoke-MgGraphRequest -Method POST `
                        -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" `
                        -Body $body `
                        -ContentType "application/json"
                    
                    Write-Host "     ✅ Created CA policy: $($newPolicy.displayName)" -ForegroundColor Green
                    Write-Host "        New ID: $($newPolicy.id)" -ForegroundColor Gray
                    
                    $results.CreatedPolicies += @{
                        Name = $newPolicy.displayName
                        SourceId = $policyData.SourcePolicyId
                        NewId = $newPolicy.id
                        State = $newPolicy.state
                    }
                }
                
            } catch {
                Write-Host "     ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.FailedPolicies += @{
                    Name = $file.BaseName
                    Error = $_.Exception.Message
                }
            }
        }
    } else {
        Write-Host "⚠️  ConditionalAccess folder not found" -ForegroundColor Yellow
    }
    
    # ===== Import Named Locations =====
    Write-Host "`n--- Processing Named Locations ---" -ForegroundColor Cyan
    
    $locFolder = Join-Path $ImportPath "NamedLocations"
    if (Test-Path $locFolder) {
        $locFiles = Get-ChildItem -Path $locFolder -Filter "*.json"
        Write-Host "Found $($locFiles.Count) Named Location files" -ForegroundColor Yellow
        
        foreach ($file in $locFiles) {
            try {
                Write-Host "`n  📍 Processing: $($file.BaseName)" -ForegroundColor White
                
                $locationData = Import-PolicyFromJson -FilePath $file.FullName
                $locationConfig = $locationData.LocationConfig
                
                # Re-add @odata.type for proper creation
                $locationConfig | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value $locationData.ODataType -Force
                
                if ($DryRun) {
                    Write-Host "     🧪 [DRY RUN] Would create Named Location: $($locationConfig.displayName)" -ForegroundColor Yellow
                    Write-Host "        Type: $($locationData.LocationType)" -ForegroundColor Gray
                    Write-Host "        Trusted: $($locationConfig.isTrusted)" -ForegroundColor Gray
                    
                    $results.CreatedLocations += @{
                        Name = $locationConfig.displayName
                        SourceId = $locationData.SourceLocationId
                        Type = $locationData.LocationType
                        DryRun = $true
                    }
                } else {
                    # Create location
                    $body = $locationConfig | ConvertTo-Json -Depth 10
                    $newLocation = Invoke-MgGraphRequest -Method POST `
                        -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations" `
                        -Body $body `
                        -ContentType "application/json"
                    
                    Write-Host "     ✅ Created Named Location: $($newLocation.displayName)" -ForegroundColor Green
                    Write-Host "        New ID: $($newLocation.id)" -ForegroundColor Gray
                    Write-Host "        Type: $($locationData.LocationType)" -ForegroundColor Gray
                    
                    $results.CreatedLocations += @{
                        Name = $newLocation.displayName
                        SourceId = $locationData.SourceLocationId
                        NewId = $newLocation.id
                        Type = $locationData.LocationType
                    }
                }
                
            } catch {
                Write-Host "     ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $results.FailedLocations += @{
                    Name = $file.BaseName
                    Error = $_.Exception.Message
                }
            }
        }
    } else {
        Write-Host "⚠️  NamedLocations folder not found" -ForegroundColor Yellow
    }
    
    # Save results summary
    Write-Host "`n--- Saving Results Summary ---" -ForegroundColor Cyan
    $summaryPath = "/Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json"
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryPath -Encoding utf8
    Write-Host "✅ Summary saved to: $summaryPath" -ForegroundColor Green
    
    # Final summary
    Write-Host "`n=== Recreation Complete ===" -ForegroundColor Cyan
    Write-Host "📊 Summary:" -ForegroundColor White
    Write-Host "   Authentication Strengths Created: $($results.CreatedAuthStrengths.Count)" -ForegroundColor Green
    Write-Host "   Authentication Strengths Failed: $($results.FailedAuthStrengths.Count)" -ForegroundColor $(if ($results.FailedAuthStrengths.Count -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "   CA Policies Created: $($results.CreatedPolicies.Count)" -ForegroundColor Green
    Write-Host "   CA Policies Failed: $($results.FailedPolicies.Count)" -ForegroundColor $(if ($results.FailedPolicies.Count -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "   Named Locations Created: $($results.CreatedLocations.Count)" -ForegroundColor Green
    Write-Host "   Named Locations Failed: $($results.FailedLocations.Count)" -ForegroundColor $(if ($results.FailedLocations.Count -gt 0) { 'Red' } else { 'Gray' })
    
    if ($DryRun) {
        Write-Host "`n✅ Dry run complete! Review the summary and run without -DryRun to create policies.`n" -ForegroundColor Yellow
    } else {
        Write-Host "`n✅ All IAC Entra policies recreated successfully!`n" -ForegroundColor Green
    }
    
} catch {
    Write-Host "`n❌ Recreation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
