# Script to recreate IAC Intune policies in another tenant from JSON exports
# This script reads IAC policy JSON files and recreates them in the target tenant

param(
    [Parameter(Mandatory=$false)]
    [string]$ImportPath = "/Users/jon/Desktop/BaslineSetup/IAC-Intune-Policies-JSON",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeAssignments = $false,
    
    [Parameter(Mandatory=$false)]
    [hashtable]$GroupIdMapping = @{}
)

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   RECREATE IAC INTUNE POLICIES FROM JSON EXPORTS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "⚠️  DRY RUN MODE - No policies will be created`n" -ForegroundColor Yellow
}

if (-not (Test-Path $ImportPath)) {
    Write-Host "❌ Import path not found: $ImportPath" -ForegroundColor Red
    Write-Host "   Please run export-IAC-Intune-Policies-JSON.ps1 first to export policies.`n" -ForegroundColor Yellow
    exit
}

Write-Host "📁 Import path: $ImportPath`n" -ForegroundColor Cyan

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All", "DeviceManagementApps.ReadWrite.All" -NoWelcome

$createdPolicies = @()
$failedPolicies = @()

# Helper function to load JSON file
function Import-PolicyFromJson {
    param($filePath)
    try {
        $content = Get-Content -Path $filePath -Raw | ConvertFrom-Json
        return $content
    } catch {
        Write-Host "   ❌ Failed to read: $filePath - $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Helper function to create Settings Catalog policy
function Create-SettingsCatalogPolicy {
    param($sourcePolicy, $settings)
    
    try {
        # Build the policy body
        $policyBody = @{
            name = $sourcePolicy.name
            description = $sourcePolicy.description
            platforms = $sourcePolicy.platforms
            technologies = $sourcePolicy.technologies
            settings = $settings
        }
        
        if (-not $DryRun) {
            $newPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Body ($policyBody | ConvertTo-Json -Depth 20)
            return $newPolicy
        } else {
            Write-Host "      [DRY RUN] Would create Settings Catalog policy" -ForegroundColor Gray
            return @{ id = "dry-run-id"; name = $sourcePolicy.name }
        }
    } catch {
        throw $_
    }
}

# Helper function to create Device Configuration policy
function Create-DeviceConfigurationPolicy {
    param($sourcePolicy)
    
    try {
        # Clone the policy configuration
        $policyBody = $sourcePolicy | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        
        # Remove read-only properties
        $policyBody.PSObject.Properties.Remove('id')
        $policyBody.PSObject.Properties.Remove('createdDateTime')
        $policyBody.PSObject.Properties.Remove('lastModifiedDateTime')
        $policyBody.PSObject.Properties.Remove('version')
        $policyBody.PSObject.Properties.Remove('supportsScopeTags')
        $policyBody.PSObject.Properties.Remove('roleScopeTagIds')
        
        if (-not $DryRun) {
            $newPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body ($policyBody | ConvertTo-Json -Depth 20)
            return $newPolicy
        } else {
            Write-Host "      [DRY RUN] Would create Device Configuration policy" -ForegroundColor Gray
            return @{ id = "dry-run-id"; displayName = $sourcePolicy.displayName }
        }
    } catch {
        throw $_
    }
}

# Helper function to create Compliance Policy
function Create-CompliancePolicy {
    param($sourcePolicy)
    
    try {
        # Clone the policy configuration
        $policyBody = $sourcePolicy | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        
        # Remove read-only properties
        $policyBody.PSObject.Properties.Remove('id')
        $policyBody.PSObject.Properties.Remove('createdDateTime')
        $policyBody.PSObject.Properties.Remove('lastModifiedDateTime')
        $policyBody.PSObject.Properties.Remove('version')
        
        if (-not $DryRun) {
            $newPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies" -Body ($policyBody | ConvertTo-Json -Depth 20)
            return $newPolicy
        } else {
            Write-Host "      [DRY RUN] Would create Compliance Policy" -ForegroundColor Gray
            return @{ id = "dry-run-id"; displayName = $sourcePolicy.displayName }
        }
    } catch {
        throw $_
    }
}

# Helper function to create Administrative Template
function Create-AdministrativeTemplate {
    param($sourcePolicy, $settings)
    
    try {
        # Create the base policy
        $policyBody = @{
            displayName = $sourcePolicy.displayName
            description = $sourcePolicy.description
        }
        
        if (-not $DryRun) {
            $newPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations" -Body ($policyBody | ConvertTo-Json -Depth 20)
            
            # Add each definition value
            foreach ($setting in $settings) {
                $settingBody = @{
                    definition = @{
                        "@odata.bind" = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions('$($setting.definition.id)')"
                    }
                    enabled = $setting.enabled
                }
                
                if ($setting.presentationValues) {
                    $settingBody.presentationValues = $setting.presentationValues
                }
                
                Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$($newPolicy.id)')/definitionValues" -Body ($settingBody | ConvertTo-Json -Depth 20)
            }
            
            return $newPolicy
        } else {
            Write-Host "      [DRY RUN] Would create Administrative Template with $($settings.Count) settings" -ForegroundColor Gray
            return @{ id = "dry-run-id"; displayName = $sourcePolicy.displayName }
        }
    } catch {
        throw $_
    }
}

# Helper function to create Endpoint Security Intent
function Create-EndpointSecurityIntent {
    param($sourcePolicy, $settings)
    
    try {
        $policyBody = @{
            displayName = $sourcePolicy.displayName
            description = $sourcePolicy.description
            templateId = $sourcePolicy.templateId
            settings = $settings
        }
        
        if (-not $DryRun) {
            $newPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/intents" -Body ($policyBody | ConvertTo-Json -Depth 20)
            return $newPolicy
        } else {
            Write-Host "      [DRY RUN] Would create Endpoint Security Intent" -ForegroundColor Gray
            return @{ id = "dry-run-id"; displayName = $sourcePolicy.displayName }
        }
    } catch {
        throw $_
    }
}

# Helper function to apply assignments
function Apply-PolicyAssignments {
    param($policyId, $policyType, $assignments)
    
    if (-not $IncludeAssignments) {
        return
    }
    
    try {
        $assignmentBodies = @()
        
        foreach ($assignment in $assignments) {
            $targetBody = @{
                "@odata.type" = $assignment.target.'@odata.type'
            }
            
            if ($assignment.target.groupId) {
                # Check if there's a mapping for this group ID
                if ($GroupIdMapping.ContainsKey($assignment.target.groupId)) {
                    $targetBody.groupId = $GroupIdMapping[$assignment.target.groupId]
                } else {
                    $targetBody.groupId = $assignment.target.groupId
                }
            }
            
            if ($assignment.target.deviceAndAppManagementAssignmentFilterId) {
                $targetBody.deviceAndAppManagementAssignmentFilterId = $assignment.target.deviceAndAppManagementAssignmentFilterId
            }
            
            if ($assignment.target.deviceAndAppManagementAssignmentFilterType) {
                $targetBody.deviceAndAppManagementAssignmentFilterType = $assignment.target.deviceAndAppManagementAssignmentFilterType
            }
            
            $assignmentBodies += @{ target = $targetBody }
        }
        
        $assignBody = @{
            assignments = $assignmentBodies
        }
        
        if (-not $DryRun) {
            switch ($policyType) {
                "Settings Catalog" {
                    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assign" -Body ($assignBody | ConvertTo-Json -Depth 20)
                }
                "Device Configuration" {
                    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations('$policyId')/assign" -Body ($assignBody | ConvertTo-Json -Depth 20)
                }
                "Compliance Policy" {
                    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies('$policyId')/assign" -Body ($assignBody | ConvertTo-Json -Depth 20)
                }
                "Administrative Template" {
                    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$policyId')/assign" -Body ($assignBody | ConvertTo-Json -Depth 20)
                }
                "Endpoint Security" {
                    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/intents('$policyId')/assign" -Body ($assignBody | ConvertTo-Json -Depth 20)
                }
            }
        } else {
            Write-Host "      [DRY RUN] Would apply $($assignments.Count) assignments" -ForegroundColor Gray
        }
    } catch {
        Write-Host "      ⚠️  Warning: Failed to apply assignments - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "📋 Loading IAC policies from JSON files...`n" -ForegroundColor Cyan

# 1. Process Device Configuration Policies
Write-Host "🔍 Processing Device Configuration Policies..." -ForegroundColor Yellow
$deviceConfigPath = "$ImportPath/DeviceConfiguration"
if (Test-Path $deviceConfigPath) {
    $jsonFiles = Get-ChildItem -Path $deviceConfigPath -Filter "*.json"
    foreach ($file in $jsonFiles) {
        $policyData = Import-PolicyFromJson -filePath $file.FullName
        if ($policyData) {
            Write-Host "   Creating: $($policyData.Policy.displayName)" -ForegroundColor Cyan
            try {
                $newPolicy = Create-DeviceConfigurationPolicy -sourcePolicy $policyData.Policy
                
                if ($IncludeAssignments -and $policyData.Assignments) {
                    Apply-PolicyAssignments -policyId $newPolicy.id -policyType "Device Configuration" -assignments $policyData.Assignments
                }
                
                $createdPolicies += [PSCustomObject]@{
                    Type = "Device Configuration"
                    Name = $policyData.Policy.displayName
                    SourceId = $policyData.Policy.id
                    NewId = $newPolicy.id
                }
                Write-Host "   ✅ Created successfully" -ForegroundColor Green
            } catch {
                Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $failedPolicies += [PSCustomObject]@{
                    Type = "Device Configuration"
                    Name = $policyData.Policy.displayName
                    Error = $_.Exception.Message
                }
            }
        }
    }
} else {
    Write-Host "   ⚠️  No Device Configuration policies found" -ForegroundColor Yellow
}

# 2. Process Settings Catalog Policies
Write-Host "`n🔍 Processing Settings Catalog Policies..." -ForegroundColor Yellow
$settingsCatalogPath = "$ImportPath/SettingsCatalog"
if (Test-Path $settingsCatalogPath) {
    $jsonFiles = Get-ChildItem -Path $settingsCatalogPath -Filter "*.json"
    foreach ($file in $jsonFiles) {
        $policyData = Import-PolicyFromJson -filePath $file.FullName
        if ($policyData) {
            Write-Host "   Creating: $($policyData.Policy.name)" -ForegroundColor Cyan
            try {
                $newPolicy = Create-SettingsCatalogPolicy -sourcePolicy $policyData.Policy -settings $policyData.Settings
                
                if ($IncludeAssignments -and $policyData.Assignments) {
                    Apply-PolicyAssignments -policyId $newPolicy.id -policyType "Settings Catalog" -assignments $policyData.Assignments
                }
                
                $createdPolicies += [PSCustomObject]@{
                    Type = "Settings Catalog"
                    Name = $policyData.Policy.name
                    SourceId = $policyData.Policy.id
                    NewId = $newPolicy.id
                }
                Write-Host "   ✅ Created successfully" -ForegroundColor Green
            } catch {
                Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $failedPolicies += [PSCustomObject]@{
                    Type = "Settings Catalog"
                    Name = $policyData.Policy.name
                    Error = $_.Exception.Message
                }
            }
        }
    }
} else {
    Write-Host "   ⚠️  No Settings Catalog policies found" -ForegroundColor Yellow
}

# 3. Process Compliance Policies
Write-Host "`n🔍 Processing Compliance Policies..." -ForegroundColor Yellow
$compliancePath = "$ImportPath/Compliance"
if (Test-Path $compliancePath) {
    $jsonFiles = Get-ChildItem -Path $compliancePath -Filter "*.json"
    foreach ($file in $jsonFiles) {
        $policyData = Import-PolicyFromJson -filePath $file.FullName
        if ($policyData) {
            Write-Host "   Creating: $($policyData.Policy.displayName)" -ForegroundColor Cyan
            try {
                $newPolicy = Create-CompliancePolicy -sourcePolicy $policyData.Policy
                
                if ($IncludeAssignments -and $policyData.Assignments) {
                    Apply-PolicyAssignments -policyId $newPolicy.id -policyType "Compliance Policy" -assignments $policyData.Assignments
                }
                
                $createdPolicies += [PSCustomObject]@{
                    Type = "Compliance Policy"
                    Name = $policyData.Policy.displayName
                    SourceId = $policyData.Policy.id
                    NewId = $newPolicy.id
                }
                Write-Host "   ✅ Created successfully" -ForegroundColor Green
            } catch {
                Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $failedPolicies += [PSCustomObject]@{
                    Type = "Compliance Policy"
                    Name = $policyData.Policy.displayName
                    Error = $_.Exception.Message
                }
            }
        }
    }
} else {
    Write-Host "   ⚠️  No Compliance policies found" -ForegroundColor Yellow
}

# 4. Process Administrative Templates
Write-Host "`n🔍 Processing Administrative Templates..." -ForegroundColor Yellow
$adminTemplatePath = "$ImportPath/AdminTemplates"
if (Test-Path $adminTemplatePath) {
    $jsonFiles = Get-ChildItem -Path $adminTemplatePath -Filter "*.json"
    foreach ($file in $jsonFiles) {
        $policyData = Import-PolicyFromJson -filePath $file.FullName
        if ($policyData) {
            Write-Host "   Creating: $($policyData.Policy.displayName)" -ForegroundColor Cyan
            try {
                $newPolicy = Create-AdministrativeTemplate -sourcePolicy $policyData.Policy -settings $policyData.Settings
                
                if ($IncludeAssignments -and $policyData.Assignments) {
                    Apply-PolicyAssignments -policyId $newPolicy.id -policyType "Administrative Template" -assignments $policyData.Assignments
                }
                
                $createdPolicies += [PSCustomObject]@{
                    Type = "Administrative Template"
                    Name = $policyData.Policy.displayName
                    SourceId = $policyData.Policy.id
                    NewId = $newPolicy.id
                }
                Write-Host "   ✅ Created successfully" -ForegroundColor Green
            } catch {
                Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $failedPolicies += [PSCustomObject]@{
                    Type = "Administrative Template"
                    Name = $policyData.Policy.displayName
                    Error = $_.Exception.Message
                }
            }
        }
    }
} else {
    Write-Host "   ⚠️  No Administrative Templates found" -ForegroundColor Yellow
}

# 5. Process Endpoint Security Intents
Write-Host "`n🔍 Processing Endpoint Security Policies..." -ForegroundColor Yellow
$endpointSecurityPath = "$ImportPath/EndpointSecurity"
if (Test-Path $endpointSecurityPath) {
    $jsonFiles = Get-ChildItem -Path $endpointSecurityPath -Filter "*.json"
    foreach ($file in $jsonFiles) {
        $policyData = Import-PolicyFromJson -filePath $file.FullName
        if ($policyData) {
            Write-Host "   Creating: $($policyData.Policy.displayName)" -ForegroundColor Cyan
            try {
                $newPolicy = Create-EndpointSecurityIntent -sourcePolicy $policyData.Policy -settings $policyData.Settings
                
                if ($IncludeAssignments -and $policyData.Assignments) {
                    Apply-PolicyAssignments -policyId $newPolicy.id -policyType "Endpoint Security" -assignments $policyData.Assignments
                }
                
                $createdPolicies += [PSCustomObject]@{
                    Type = "Endpoint Security"
                    Name = $policyData.Policy.displayName
                    SourceId = $policyData.Policy.id
                    NewId = $newPolicy.id
                }
                Write-Host "   ✅ Created successfully" -ForegroundColor Green
            } catch {
                Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
                $failedPolicies += [PSCustomObject]@{
                    Type = "Endpoint Security"
                    Name = $policyData.Policy.displayName
                    Error = $_.Exception.Message
                }
            }
        }
    }
} else {
    Write-Host "   ⚠️  No Endpoint Security policies found" -ForegroundColor Yellow
}

# Display Summary
Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "✅ Successfully created: $($createdPolicies.Count) policies" -ForegroundColor Green
Write-Host "❌ Failed to create: $($failedPolicies.Count) policies`n" -ForegroundColor Red

if ($createdPolicies.Count -gt 0) {
    Write-Host "Created Policies:" -ForegroundColor Green
    $createdPolicies | Format-Table -AutoSize
}

if ($failedPolicies.Count -gt 0) {
    Write-Host "`nFailed Policies:" -ForegroundColor Red
    $failedPolicies | Format-Table -AutoSize
}

# Export summary to file
$summaryPath = "/Users/jon/Desktop/BaslineSetup/policy-recreation-summary.json"
$summary = @{
    CreatedPolicies = $createdPolicies
    FailedPolicies = $failedPolicies
    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    DryRun = $DryRun.IsPresent
    IncludeAssignments = $IncludeAssignments.IsPresent
}
$summary | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Host "`n📄 Summary exported to: $summaryPath" -ForegroundColor Cyan

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
