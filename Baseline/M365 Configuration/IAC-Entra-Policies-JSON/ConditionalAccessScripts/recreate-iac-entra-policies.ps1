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

.PARAMETER SkipTenantPolicies
    When specified, skips restoring tenant-level policies (Authorization Policy, Authentication Methods Policy).
    Use if you only want to restore CA policies and locations.

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
    Required Graph API Permissions:
        - Policy.ReadWrite.ConditionalAccess (for CA policies)
        - Policy.ReadWrite.Authorization (for tenant authorization policy)
        - Application.ReadWrite.All (for custom authentication strengths)
        - Directory.ReadWrite.All (for custom security attributes)
        - Policy.Read.All (for reading existing policies)
        - RoleManagement.ReadWrite.Directory (for role assignments)
    
    Connection Example:
        Connect-MgGraph -Scopes @(
            'Policy.ReadWrite.ConditionalAccess',
            'Policy.ReadWrite.Authorization',
            'Application.ReadWrite.All',
            'Directory.ReadWrite.All',
            'Policy.Read.All',
            'RoleManagement.ReadWrite.Directory'
        ) -NoWelcome
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
    [hashtable]$RoleIdMapping = @{},
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTenantPolicies,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSecurityAttributes
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns

# Remove corrupted Exchange Online module if present (prevents module load errors)
Remove-Module ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue

# Explicitly import required modules to verify they load correctly
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
} catch {
    Write-Host "❌ Error loading required Microsoft Graph modules: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Try running: Remove-Module ExchangeOnlineManagement -Force" -ForegroundColor Yellow
    Write-Host "💡 Then restart PowerShell and try again" -ForegroundColor Yellow
    exit 1
}

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
        [hashtable]$RoleMap,
        [hashtable]$LocationMap
    )
    
    # Work with the object directly without JSON round-trip
    $updatedConditions = $Conditions
    
    if ($updatedConditions.users) {
        # Map users - ensure arrays stay as arrays
        if ($updatedConditions.users.includeUsers) {
            $newIncludeUsers = @($updatedConditions.users.includeUsers | ForEach-Object {
                Map-Id -Id $_ -Mapping $UserMap
            })
            $updatedConditions.users.includeUsers = $newIncludeUsers
        }
        
        if ($updatedConditions.users.excludeUsers) {
            $newExcludeUsers = @($updatedConditions.users.excludeUsers | ForEach-Object {
                Map-Id -Id $_ -Mapping $UserMap
            })
            $updatedConditions.users.excludeUsers = $newExcludeUsers
        }
        
        # Map groups
        if ($updatedConditions.users.includeGroups) {
            $newIncludeGroups = @($updatedConditions.users.includeGroups | ForEach-Object {
                Map-Id -Id $_ -Mapping $GroupMap
            })
            $updatedConditions.users.includeGroups = $newIncludeGroups
        }
        
        if ($updatedConditions.users.excludeGroups) {
            $newExcludeGroups = @($updatedConditions.users.excludeGroups | ForEach-Object {
                Map-Id -Id $_ -Mapping $GroupMap
            })
            $updatedConditions.users.excludeGroups = $newExcludeGroups
        }
        
        # Map roles
        if ($updatedConditions.users.includeRoles) {
            $newIncludeRoles = @($updatedConditions.users.includeRoles | ForEach-Object {
                Map-Id -Id $_ -Mapping $RoleMap
            })
            $updatedConditions.users.includeRoles = $newIncludeRoles
        }
        
        if ($updatedConditions.users.excludeRoles) {
            $newExcludeRoles = @($updatedConditions.users.excludeRoles | ForEach-Object {
                Map-Id -Id $_ -Mapping $RoleMap
            })
            $updatedConditions.users.excludeRoles = $newExcludeRoles
        }
    }
    
    # Map named locations
    if ($updatedConditions.locations -and $LocationMap.Count -gt 0) {
        if ($updatedConditions.locations.includeLocations) {
            $newIncludeLocs = @($updatedConditions.locations.includeLocations | ForEach-Object {
                # Don't map special keywords like "All", "AllTrusted"
                if ($_ -match '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$') {
                    Map-Id -Id $_ -Mapping $LocationMap
                } else {
                    $_
                }
            })
            $updatedConditions.locations.includeLocations = $newIncludeLocs
        }
        
        if ($updatedConditions.locations.excludeLocations) {
            $newExcludeLocs = @($updatedConditions.locations.excludeLocations | ForEach-Object {
                # Don't map special keywords like "All", "AllTrusted"
                if ($_ -match '^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$') {
                    Map-Id -Id $_ -Mapping $LocationMap
                } else {
                    $_
                }
            })
            $updatedConditions.locations.excludeLocations = $newExcludeLocs
        }
    }
    
    # Ensure includeApplications is always an array
    if ($updatedConditions.applications -and $updatedConditions.applications.includeApplications) {
        if ($updatedConditions.applications.includeApplications -isnot [array]) {
            $updatedConditions.applications.includeApplications = @($updatedConditions.applications.includeApplications)
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
# Helper function to remove @odata.context fields from JSON objects
function Remove-ODataContext {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Json
    )
    
    # Remove @odata fields using multiple patterns:
    # Pattern 1: "@odata.context": "value" (standalone property)
    $cleaned = $Json -replace '"@odata\.(context|type)"\s*:\s*"[^"]*",?\s*[\r\n]*', ''
    
    # Pattern 2: "propertyName@odata.context": "value" (property with @odata suffix)
    $cleaned = $cleaned -replace '"[^"]+@odata\.(context|type)"\s*:\s*"[^"]*",?\s*[\r\n]*', ''
    
    # Pattern 3: Handle trailing commas before closing braces/brackets
    $cleaned = $cleaned -replace ',\s*}', '}'
    $cleaned = $cleaned -replace ',\s*]', ']'
    
    # Pattern 4: Handle leading commas after opening braces
    $cleaned = $cleaned -replace '{\s*,', '{'
    
    # Pattern 5: Clean up multiple blank lines
    $cleaned = $cleaned -replace '(\r?\n\s*){3,}', "`n`n"
    
    return $cleaned
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
        UpdatedTenantPolicies = @()
        FailedTenantPolicies = @()
        CreatedSecurityAttributes = @()
        FailedSecurityAttributes = @()
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
    
    # ===== Restore Tenant-Level Policies =====
    if (-not $SkipTenantPolicies) {
        Write-Host "\n--- Restoring Tenant-Level Policies ---" -ForegroundColor Cyan
        
        $tenantPoliciesFolder = Join-Path $ImportPath "TenantPolicies"
        if (Test-Path $tenantPoliciesFolder) {
            # Restore Authorization Policy
            $authzPolicyFile = Join-Path $tenantPoliciesFolder "AuthorizationPolicy.json"
            if (Test-Path $authzPolicyFile) {
                try {
                    Write-Host "\n  🔐 Processing: Authorization Policy" -ForegroundColor White
                    
                    $authzData = Import-PolicyFromJson -FilePath $authzPolicyFile
                    $authzConfig = $authzData.PolicyConfig
                    
                    # Remove read-only properties
                    $authzConfig.PSObject.Properties.Remove('@odata.context')
                    $authzConfig.PSObject.Properties.Remove('id')
                    $authzConfig.PSObject.Properties.Remove('displayName')
                    $authzConfig.PSObject.Properties.Remove('description')
                    
                    if ($DryRun) {
                        Write-Host "     🧪 [DRY RUN] Would update Authorization Policy" -ForegroundColor Yellow
                        Write-Host "        blockMsolPowerShell: $($authzConfig.blockMsolPowerShell)" -ForegroundColor Gray
                        Write-Host "        allowedToSignUpEmailBasedSubscriptions: $($authzConfig.allowedToSignUpEmailBasedSubscriptions)" -ForegroundColor Gray
                        
                        $results.UpdatedTenantPolicies += @{
                            PolicyType = "AuthorizationPolicy"
                            DryRun = $true
                        }
                    } else {
                        # Get current policy ID
                        $currentPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy"
                        
                        # Update policy
                        $body = $authzConfig | ConvertTo-Json -Depth 10
                        Invoke-MgGraphRequest -Method PATCH `
                            -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy/$($currentPolicy.id)" `
                            -Body $body `
                            -ContentType "application/json" | Out-Null
                        
                        Write-Host "     ✅ Updated Authorization Policy" -ForegroundColor Green
                        Write-Host "        blockMsolPowerShell: $($authzConfig.blockMsolPowerShell)" -ForegroundColor Gray
                        Write-Host "        allowedToSignUpEmailBasedSubscriptions: $($authzConfig.allowedToSignUpEmailBasedSubscriptions)" -ForegroundColor Gray
                        
                        $results.UpdatedTenantPolicies += @{
                            PolicyType = "AuthorizationPolicy"
                            Settings = @{
                                blockMsolPowerShell = $authzConfig.blockMsolPowerShell
                                allowedToSignUpEmailBasedSubscriptions = $authzConfig.allowedToSignUpEmailBasedSubscriptions
                            }
                        }
                    }
                    
                } catch {
                    Write-Host "     ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                    $results.FailedTenantPolicies += @{
                        PolicyType = "AuthorizationPolicy"
                        Error = $_.Exception.Message
                    }
                }
            } else {
                Write-Host "  ⚠️  Authorization Policy file not found" -ForegroundColor Yellow
            }
            
            # Restore Authentication Methods Policy
            $authMethodsPolicyFile = Join-Path $tenantPoliciesFolder "AuthenticationMethodsPolicy.json"
            if (Test-Path $authMethodsPolicyFile) {
                try {
                    Write-Host "\n  🔐 Processing: Authentication Methods Policy" -ForegroundColor White
                    
                    $authMethodsData = Import-PolicyFromJson -FilePath $authMethodsPolicyFile
                    $authMethodsConfig = $authMethodsData.PolicyConfig
                    
                    # Remove read-only properties
                    $authMethodsConfig.PSObject.Properties.Remove('@odata.context')
                    $authMethodsConfig.PSObject.Properties.Remove('id')
                    
                    if ($DryRun) {
                        Write-Host "     🧪 [DRY RUN] Would update Authentication Methods Policy" -ForegroundColor Yellow
                        if ($authMethodsConfig.registrationEnforcement.authenticationMethodsRegistrationCampaign) {
                            Write-Host "        Registration Campaign State: $($authMethodsConfig.registrationEnforcement.authenticationMethodsRegistrationCampaign.state)" -ForegroundColor Gray
                        }
                        
                        $results.UpdatedTenantPolicies += @{
                            PolicyType = "AuthenticationMethodsPolicy"
                            DryRun = $true
                        }
                    } else {
                        # Update policy
                        $body = $authMethodsConfig | ConvertTo-Json -Depth 10
                        Invoke-MgGraphRequest -Method PATCH `
                            -Uri "https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy" `
                            -Body $body `
                            -ContentType "application/json" | Out-Null
                        
                        Write-Host "     ✅ Updated Authentication Methods Policy" -ForegroundColor Green
                        if ($authMethodsConfig.registrationEnforcement.authenticationMethodsRegistrationCampaign) {
                            Write-Host "        Registration Campaign State: $($authMethodsConfig.registrationEnforcement.authenticationMethodsRegistrationCampaign.state)" -ForegroundColor Gray
                        }
                        
                        $results.UpdatedTenantPolicies += @{
                            PolicyType = "AuthenticationMethodsPolicy"
                            Settings = @{
                                registrationCampaignState = $authMethodsConfig.registrationEnforcement.authenticationMethodsRegistrationCampaign.state
                            }
                        }
                    }
                    
                } catch {
                    Write-Host "     ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                    $results.FailedTenantPolicies += @{
                        PolicyType = "AuthenticationMethodsPolicy"
                        Error = $_.Exception.Message
                    }
                }
            } else {
                Write-Host "  ⚠️  Authentication Methods Policy file not found" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ℹ️  TenantPolicies folder not found - skipping tenant policy restoration" -ForegroundColor Gray
        }
    } else {
        Write-Host "\n  ⏭️  Skipping tenant-level policies (SkipTenantPolicies specified)" -ForegroundColor Gray
    }
    
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
    
    # ===== Restore Custom Security Attributes =====
    if (-not $SkipSecurityAttributes) {
        Write-Host "`n--- Restoring Custom Security Attributes ---" -ForegroundColor Cyan
        
        $securityAttributesFolder = Join-Path $ImportPath "SecurityAttributes"
        if (Test-Path $securityAttributesFolder) {
            $attributeFiles = Get-ChildItem -Path $securityAttributesFolder -Filter "*.json" | Where-Object { $_.Name -ne "export-summary.json" }
            Write-Host "Found $($attributeFiles.Count) attribute set(s) to restore" -ForegroundColor Yellow
            
            foreach ($file in $attributeFiles) {
                try {
                    Write-Host "`n  📦 Processing: $($file.BaseName)" -ForegroundColor White
                    
                    $attributeData = Import-PolicyFromJson -FilePath $file.FullName
                    $attributeSet = $attributeData.AttributeSetConfig
                    $attributeDefinitions = $attributeData.AttributeDefinitions
                    
                    # Step 1: Check if attribute set exists, if not create it
                    $existingAttributeSet = $null
                    try {
                        $existingAttributeSet = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/attributeSets/$($attributeSet.id)"
                    } catch {
                        # Attribute set doesn't exist
                    }
                    
                    if (-not $existingAttributeSet) {
                        if ($DryRun) {
                            Write-Host "     🧪 [DRY RUN] Would create attribute set: $($attributeSet.id)" -ForegroundColor Yellow
                            Write-Host "        Description: $($attributeSet.description)" -ForegroundColor Gray
                        } else {
                            # Create attribute set
                            $setBody = @{
                                id = $attributeSet.id
                                description = $attributeSet.description
                                maxAttributesPerSet = $attributeSet.maxAttributesPerSet
                            } | ConvertTo-Json -Depth 5
                            
                            Invoke-MgGraphRequest -Method POST `
                                -Uri "https://graph.microsoft.com/v1.0/directory/attributeSets" `
                                -Body $setBody `
                                -ContentType "application/json" | Out-Null
                            
                            Write-Host "     ✅ Created attribute set: $($attributeSet.id)" -ForegroundColor Green
                        }
                    } else {
                        Write-Host "     ℹ️  Attribute set already exists: $($attributeSet.id)" -ForegroundColor Gray
                    }
                    
                    # Step 2: Create/update attribute definitions
                    foreach ($definition in $attributeDefinitions) {
                        try {
                            $defId = $definition.id
                            
                            # Check if definition exists
                            $existingDefinition = $null
                            try {
                                $existingDefinition = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions/$defId"
                            } catch {
                                # Definition doesn't exist
                            }
                            
                            if (-not $existingDefinition) {
                                if ($DryRun) {
                                    Write-Host "        🧪 [DRY RUN] Would create attribute: $($definition.name)" -ForegroundColor Yellow
                                    Write-Host "           Type: $($definition.type), Predefined Values: $($definition.usePreDefinedValuesOnly)" -ForegroundColor Gray
                                } else {
                                    # Create attribute definition
                                    $defBody = @{
                                        attributeSet = $definition.attributeSet
                                        name = $definition.name
                                        description = $definition.description
                                        type = $definition.type
                                        status = $definition.status
                                        isCollection = $definition.isCollection
                                        isSearchable = $definition.isSearchable
                                        usePreDefinedValuesOnly = $definition.usePreDefinedValuesOnly
                                    } | ConvertTo-Json -Depth 5
                                    
                                    $newDefinition = Invoke-MgGraphRequest -Method POST `
                                        -Uri "https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions" `
                                        -Body $defBody `
                                        -ContentType "application/json"
                                    
                                    Write-Host "        ✅ Created attribute: $($definition.name)" -ForegroundColor Green
                                    
                                    # Step 3: Add allowed values if applicable
                                    if ($definition.usePreDefinedValuesOnly -eq $true -and $definition.allowedValues) {
                                        Write-Host "           Adding $($definition.allowedValues.Count) allowed values..." -ForegroundColor Gray
                                        
                                        foreach ($allowedValue in $definition.allowedValues) {
                                            try {
                                                $valueBody = @{
                                                    id = $allowedValue.id
                                                    isActive = $allowedValue.isActive
                                                } | ConvertTo-Json -Depth 5
                                                
                                                Invoke-MgGraphRequest -Method POST `
                                                    -Uri "https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions/$($newDefinition.id)/allowedValues" `
                                                    -Body $valueBody `
                                                    -ContentType "application/json" | Out-Null
                                                
                                                Write-Host "              - $($allowedValue.id)" -ForegroundColor DarkGray
                                            } catch {
                                                Write-Host "              ⚠️  Failed to add value: $($allowedValue.id)" -ForegroundColor Yellow
                                            }
                                        }
                                    }
                                    
                                    $results.CreatedSecurityAttributes += @{
                                        AttributeSet = $attributeSet.id
                                        AttributeName = $definition.name
                                        Type = $definition.type
                                        AllowedValues = $definition.allowedValues.Count
                                    }
                                }
                            } else {
                                Write-Host "        ℹ️  Attribute already exists: $($definition.name)" -ForegroundColor Gray
                                
                                # Check if we need to add missing allowed values
                                if ($definition.usePreDefinedValuesOnly -eq $true -and $definition.allowedValues -and -not $DryRun) {
                                    $existingValues = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions/$defId/allowedValues"
                                    $existingValueIds = $existingValues.value | ForEach-Object { $_.id }
                                    
                                    foreach ($allowedValue in $definition.allowedValues) {
                                        if ($allowedValue.id -notin $existingValueIds) {
                                            try {
                                                $valueBody = @{
                                                    id = $allowedValue.id
                                                    isActive = $allowedValue.isActive
                                                } | ConvertTo-Json -Depth 5
                                                
                                                Invoke-MgGraphRequest -Method POST `
                                                    -Uri "https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions/$defId/allowedValues" `
                                                    -Body $valueBody `
                                                    -ContentType "application/json" | Out-Null
                                                
                                                Write-Host "           ✅ Added missing value: $($allowedValue.id)" -ForegroundColor Green
                                            } catch {
                                                Write-Host "           ⚠️  Failed to add value: $($allowedValue.id)" -ForegroundColor Yellow
                                            }
                                        }
                                    }
                                }
                            }
                            
                        } catch {
                            Write-Host "        ❌ Failed to process attribute: $($definition.name) - $($_.Exception.Message)" -ForegroundColor Red
                            $results.FailedSecurityAttributes += @{
                                AttributeSet = $attributeSet.id
                                AttributeName = $definition.name
                                Error = $_.Exception.Message
                            }
                        }
                    }
                    
                } catch {
                    Write-Host "     ❌ Failed to process attribute set: $($_.Exception.Message)" -ForegroundColor Red
                    $results.FailedSecurityAttributes += @{
                        AttributeSet = $file.BaseName
                        Error = $_.Exception.Message
                    }
                }
            }
        } else {
            Write-Host "  ℹ️  SecurityAttributes folder not found - skipping" -ForegroundColor Gray
        }
    } else {
        Write-Host "`n  ⏭️  Skipping custom security attributes (SkipSecurityAttributes specified)" -ForegroundColor Gray
    }
    
    # ===== Import Named Locations FIRST (before policies that reference them) =====
    Write-Host "`n--- Processing Named Locations ---" -ForegroundColor Cyan
    
    $LocationIdMapping = @{}
    
    $locFolder = Join-Path $ImportPath "NamedLocations"
    if (Test-Path $locFolder) {
        $locFiles = Get-ChildItem -Path $locFolder -Filter "*.json"
        Write-Host "Found $($locFiles.Count) Named Location files" -ForegroundColor Yellow
        
        foreach ($file in $locFiles) {
            try {
                Write-Host "`n  📍 Processing: $($file.BaseName)" -ForegroundColor White
                
                # Load location JSON and remove @odata fields BEFORE parsing
                $locationJson = Get-Content -Path $file.FullName -Raw
                $cleanedJson = Remove-ODataContext -Json $locationJson
                $locationData = $cleanedJson | ConvertFrom-Json
                $locationConfig = $locationData.LocationConfig
                
                # Remove read-only fields that shouldn't be sent during creation
                if ($locationConfig.PSObject.Properties['id']) { $locationConfig.PSObject.Properties.Remove('id') }
                if ($locationConfig.PSObject.Properties['createdDateTime']) { $locationConfig.PSObject.Properties.Remove('createdDateTime') }
                if ($locationConfig.PSObject.Properties['modifiedDateTime']) { $locationConfig.PSObject.Properties.Remove('modifiedDateTime') }
                
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
                    Write-Host "        Old ID: $($locationData.SourceLocationId)" -ForegroundColor Gray
                    Write-Host "        New ID: $($newLocation.id)" -ForegroundColor Gray
                    Write-Host "        Type: $($locationData.LocationType)" -ForegroundColor Gray
                    
                    # Build location ID mapping (old source ID -> new ID)
                    if ($locationData.SourceLocationId) {
                        $LocationIdMapping[$locationData.SourceLocationId] = $newLocation.id
                        Write-Host "        📝 Mapped: $($locationData.SourceLocationId) -> $($newLocation.id)" -ForegroundColor DarkGray
                    }
                    
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
    
    if ($LocationIdMapping.Count -gt 0) {
        Write-Host "`n  📊 Location ID Mapping Summary:" -ForegroundColor Cyan
        $LocationIdMapping.GetEnumerator() | ForEach-Object {
            Write-Host "     $($_.Key) -> $($_.Value)" -ForegroundColor DarkGray
        }
    }
    
    # ===== Build Group ID Mapping (if not provided) =====
    if ($GroupIdMapping.Count -eq 0) {
        Write-Host "`n--- Building Group ID Mapping ---" -ForegroundColor Cyan
        
        # Scan all policy JSON files for group IDs
        $caFolder = Join-Path $ImportPath "ConditionalAccess"
        if (Test-Path $caFolder) {
            $caFiles = Get-ChildItem -Path $caFolder -Filter "*.json"
            $allGroupDetails = @{}
            
            foreach ($file in $caFiles) {
                try {
                    $policyData = Import-PolicyFromJson -FilePath $file.FullName
                    
                    # Check AssignmentDetails for group display names
                    if ($policyData.AssignmentDetails) {
                        foreach ($group in $policyData.AssignmentDetails.ExcludeGroups) {
                            if ($group.Id -and $group.DisplayName) {
                                $allGroupDetails[$group.Id] = $group.DisplayName
                            }
                        }
                        foreach ($group in $policyData.AssignmentDetails.IncludeGroups) {
                            if ($group.Id -and $group.DisplayName) {
                                $allGroupDetails[$group.Id] = $group.DisplayName
                            }
                        }
                    }
                } catch {
                    # Skip files that can't be parsed
                }
            }
            
            Write-Host "  Found $($allGroupDetails.Count) unique groups referenced in policies" -ForegroundColor Yellow
            
            # Look up each group in target tenant by displayName
            $GroupIdMapping = @{}
            foreach ($oldId in $allGroupDetails.Keys) {
                $displayName = $allGroupDetails[$oldId]
                
                try {
                    $filter = "displayName eq '$($displayName.Replace("'", "''"))'"
                    $targetGroup = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=$filter"
                    
                    if ($targetGroup.value -and $targetGroup.value.Count -gt 0) {
                        $newId = $targetGroup.value[0].id
                        $GroupIdMapping[$oldId] = $newId
                        Write-Host "     ✅ Mapped: $displayName" -ForegroundColor Green
                        Write-Host "        $oldId -> $newId" -ForegroundColor DarkGray
                    } else {
                        Write-Host "     ⚠️  Group not found in target tenant: $displayName" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "     ❌ Failed to lookup: $displayName" -ForegroundColor Red
                }
            }
            
            Write-Host "`n  📊 Built $($GroupIdMapping.Count) group ID mappings" -ForegroundColor Cyan
        }
    } else {
        Write-Host "`n  ℹ️  Using provided GroupIdMapping ($($GroupIdMapping.Count) mappings)" -ForegroundColor Gray
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
                
                # Load policy JSON and remove @odata fields BEFORE parsing
                $policyJson = Get-Content -Path $file.FullName -Raw
                $cleanedJson = Remove-ODataContext -Json $policyJson
                $policyData = $cleanedJson | ConvertFrom-Json
                $policyConfig = $policyData.PolicyConfig
                
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
                if ($GroupIdMapping.Count -gt 0 -or $UserIdMapping.Count -gt 0 -or $RoleIdMapping.Count -gt 0 -or $LocationIdMapping.Count -gt 0) {
                    Write-Host "     🔄 Applying ID mappings..." -ForegroundColor Gray
                    $policyConfig.conditions = Update-PolicyConditions `
                        -Conditions $policyConfig.conditions `
                        -GroupMap $GroupIdMapping `
                        -UserMap $UserIdMapping `
                        -RoleMap $RoleIdMapping `
                        -LocationMap $LocationIdMapping
                }
                
                # Remove external tenant references that may not be valid in target tenant
                if ($policyConfig.conditions.users.excludeGuestsOrExternalUsers.externalTenants) {
                    $policyConfig.conditions.users.excludeGuestsOrExternalUsers = $null
                }
                if ($policyConfig.conditions.users.includeGuestsOrExternalUsers.externalTenants) {
                    $policyConfig.conditions.users.includeGuestsOrExternalUsers = $null
                }
                
                # Clean up authenticationStrength to only include required fields
                if ($policyConfig.grantControls.authenticationStrength -and $policyConfig.grantControls.authenticationStrength -ne $null) {
                    $authStrength = $policyConfig.grantControls.authenticationStrength
                    if ($authStrength.PSObject.Properties.Name -contains 'id') {
                        # Keep only id - Graph API will reject read-only fields
                        $policyConfig.grantControls.authenticationStrength = @{
                            id = $authStrength.id
                        }
                    }
                }
                
                # Validate policy has users targeted (required by Graph API)
                $hasUsers = $false
                if ($policyConfig.conditions.users.includeUsers.Count -gt 0 -or 
                    $policyConfig.conditions.users.includeGroups.Count -gt 0 -or 
                    $policyConfig.conditions.users.includeRoles.Count -gt 0 -or
                    $policyConfig.conditions.users.includeGuestsOrExternalUsers -ne $null) {
                    $hasUsers = $true
                }
                
                if (-not $hasUsers) {
                    Write-Host "     ⚠️  Skipping: Policy has no users targeted after cleanup" -ForegroundColor Yellow
                    $results.FailedPolicies += @{
                        Name = $policyConfig.displayName
                        Error = "Policy has no users targeted (includeGuestsOrExternalUsers was removed)"
                    }
                    continue
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
                    # Remove read-only fields that shouldn't be included in POST requests
                    $policyConfig.PSObject.Properties.Remove('id')
                    $policyConfig.PSObject.Properties.Remove('createdDateTime')
                    $policyConfig.PSObject.Properties.Remove('modifiedDateTime')
                    
                    # Create policy
                    $body = $policyConfig | ConvertTo-Json -Depth 10
                    
                    # DEBUG: Save body to file for inspection
                    $debugFile = "/tmp/policy-body-$($policyConfig.displayName -replace '[^a-zA-Z0-9]', '-').json"
                    $body | Out-File -FilePath $debugFile -Encoding utf8
                    Write-Host "     🐛 DEBUG: Body saved to $debugFile" -ForegroundColor Magenta
                    
                    $newPolicy = Invoke-MgGraphRequest -Method POST `
                        -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies" `
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
    
    # Save results summary
    Write-Host "`n--- Saving Results Summary ---" -ForegroundColor Cyan
    $summaryPath = "/Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json"
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryPath -Encoding utf8
    Write-Host "✅ Summary saved to: $summaryPath" -ForegroundColor Green
    
    # Final summary
    Write-Host "`n=== Recreation Complete ===" -ForegroundColor Cyan
    Write-Host "📊 Summary:" -ForegroundColor White
    Write-Host "   Tenant Policies Updated: $($results.UpdatedTenantPolicies.Count)" -ForegroundColor Green
    Write-Host "   Tenant Policies Failed: $($results.FailedTenantPolicies.Count)" -ForegroundColor $(if ($results.FailedTenantPolicies.Count -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "   Security Attributes Created: $($results.CreatedSecurityAttributes.Count)" -ForegroundColor Green
    Write-Host "   Security Attributes Failed: $($results.FailedSecurityAttributes.Count)" -ForegroundColor $(if ($results.FailedSecurityAttributes.Count -gt 0) { 'Red' } else { 'Gray' })
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
