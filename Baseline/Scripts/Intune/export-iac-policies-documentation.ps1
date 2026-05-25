# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All", "DeviceManagementApps.Read.All" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   EXPORT IAC INTUNE POLICIES DOCUMENTATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$allPolicies = @()

# Helper function to get Settings Catalog configuration
function Get-SettingsCatalogConfig {
    param($policyId)
    try {
        $settings = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/settings").value
        return $settings
    } catch {
        return $null
    }
}

# Helper function to get Endpoint Security Intent settings
function Get-IntentSettings {
    param($intentId)
    try {
        $settings = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/intents('$intentId')/settings").value
        return $settings
    } catch {
        return $null
    }
}

# Helper function to get Group Policy Configuration values
function Get-GroupPolicyValues {
    param($configId)
    try {
        $values = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$configId')/definitionValues?`$expand=definition").value
        return $values
    } catch {
        return $null
    }
}

# Helper function to get assignments
function Get-PolicyAssignments {
    param($policyId, $policyType)
    try {
        switch ($policyType) {
            "Settings Catalog" {
                $assignments = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assignments").value
            }
            "Device Configuration" {
                $assignments = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations('$policyId')/assignments").value
            }
            "Compliance Policy" {
                $assignments = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies('$policyId')/assignments").value
            }
            "Administrative Template" {
                $assignments = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$policyId')/assignments").value
            }
            "Endpoint Security" {
                $assignments = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/intents('$policyId')/assignments").value
            }
            default {
                $assignments = $null
            }
        }
        return $assignments
    } catch {
        return $null
    }
}

# 1. Device Configuration Policies
Write-Host "🔍 Retrieving Device Configuration Policies..." -ForegroundColor Yellow
try {
    $deviceConfigs = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $deviceConfigs += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    foreach ($policy in $deviceConfigs) {
        if ($policy.displayName -like "IAC*") {
            Write-Host "   Found: $($policy.displayName)" -ForegroundColor White
            $assignments = Get-PolicyAssignments -policyId $policy.id -policyType "Device Configuration"
            $allPolicies += [PSCustomObject]@{
                Type = "Device Configuration"
                Name = $policy.displayName
                ID = $policy.id
                ODataType = $policy.'@odata.type'
                Configuration = $policy
                Assignments = $assignments
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2. Settings Catalog Policies
Write-Host "🔍 Retrieving Settings Catalog Policies..." -ForegroundColor Yellow
try {
    $settingsCatalog = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $settingsCatalog += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    foreach ($policy in $settingsCatalog) {
        if ($policy.name -like "IAC*") {
            Write-Host "   Found: $($policy.name)" -ForegroundColor White
            Write-Host "      Retrieving settings..." -ForegroundColor Gray
            $settings = Get-SettingsCatalogConfig -policyId $policy.id
            $assignments = Get-PolicyAssignments -policyId $policy.id -policyType "Settings Catalog"
            $allPolicies += [PSCustomObject]@{
                Type = "Settings Catalog"
                Name = $policy.name
                ID = $policy.id
                ODataType = "Settings Catalog"
                Configuration = $policy
                Settings = $settings
                Assignments = $assignments
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 3. Compliance Policies
Write-Host "🔍 Retrieving Compliance Policies..." -ForegroundColor Yellow
try {
    $compliancePolicies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies").value
    
    foreach ($policy in $compliancePolicies) {
        if ($policy.displayName -like "IAC*") {
            Write-Host "   Found: $($policy.displayName)" -ForegroundColor White
            $assignments = Get-PolicyAssignments -policyId $policy.id -policyType "Compliance Policy"
            $allPolicies += [PSCustomObject]@{
                Type = "Compliance Policy"
                Name = $policy.displayName
                ID = $policy.id
                ODataType = $policy.'@odata.type'
                Configuration = $policy
                Assignments = $assignments
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 4. Administrative Templates
Write-Host "🔍 Retrieving Administrative Templates..." -ForegroundColor Yellow
try {
    $adminTemplates = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations").value
    
    foreach ($template in $adminTemplates) {
        if ($template.displayName -like "IAC*") {
            Write-Host "   Found: $($template.displayName)" -ForegroundColor White
            Write-Host "      Retrieving settings..." -ForegroundColor Gray
            $gpSettings = Get-GroupPolicyValues -configId $template.id
            $assignments = Get-PolicyAssignments -policyId $template.id -policyType "Administrative Template"
            $allPolicies += [PSCustomObject]@{
                Type = "Administrative Template"
                Name = $template.displayName
                ID = $template.id
                ODataType = "Group Policy"
                Configuration = $template
                Settings = $gpSettings
                Assignments = $assignments
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 5. Endpoint Security Intents
Write-Host "🔍 Retrieving Endpoint Security Policies..." -ForegroundColor Yellow
try {
    $intents = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/intents").value
    
    foreach ($policy in $intents) {
        if ($policy.displayName -like "IAC*") {
            Write-Host "   Found: $($policy.displayName)" -ForegroundColor White
            Write-Host "      Retrieving settings..." -ForegroundColor Gray
            $intentSettings = Get-IntentSettings -intentId $policy.id
            $assignments = Get-PolicyAssignments -policyId $policy.id -policyType "Endpoint Security"
            $allPolicies += [PSCustomObject]@{
                Type = "Endpoint Security"
                Name = $policy.displayName
                ID = $policy.id
                ODataType = $policy.templateId
                Configuration = $policy
                Settings = $intentSettings
                Assignments = $assignments
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 6. PowerShell Scripts
Write-Host "🔍 Retrieving PowerShell Scripts..." -ForegroundColor Yellow
try {
    $psScripts = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $psScripts += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    foreach ($script in $psScripts) {
        if ($script.displayName -like "IAC*") {
            Write-Host "   Found: $($script.displayName)" -ForegroundColor White
            $allPolicies += [PSCustomObject]@{
                Type = "PowerShell Script"
                Name = $script.displayName
                ID = $script.id
                ODataType = "PowerShell"
                Configuration = $script
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 7. Autopilot Profiles
Write-Host "🔍 Retrieving Autopilot Profiles..." -ForegroundColor Yellow
try {
    $autopilotProfiles = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles").value
    
    foreach ($profile in $autopilotProfiles) {
        if ($profile.displayName -like "IAC*") {
            Write-Host "   Found: $($profile.displayName)" -ForegroundColor White
            $allPolicies += [PSCustomObject]@{
                Type = "Autopilot Profile"
                Name = $profile.displayName
                ID = $profile.id
                ODataType = "Autopilot"
                Configuration = $profile
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Display Summary
Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "📊 Total IAC Policies Found: $($allPolicies.Count)`n" -ForegroundColor Green

$groupedPolicies = $allPolicies | Group-Object -Property Type
foreach ($group in $groupedPolicies | Sort-Object Name) {
    Write-Host "   $($group.Name): " -ForegroundColor White -NoNewline
    Write-Host "$($group.Count)" -ForegroundColor Yellow
}

# Generate Markdown Documentation
Write-Host "`n📝 Generating Markdown documentation...`n" -ForegroundColor Cyan

$markdown = @"
# IAC Intune Policies - Complete Documentation

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Total IAC Policies:** $($allPolicies.Count)

---

## Table of Contents

"@

# Add TOC
foreach ($group in ($groupedPolicies | Sort-Object Name)) {
    $anchor = $group.Name -replace ' ', '-' -replace '\(', '' -replace '\)', ''
    $markdown += "- [$($group.Name)](#$($anchor.ToLower())) ($($group.Count))`n"
}

$markdown += "`n---`n`n"

# Add each section with full details
foreach ($group in ($groupedPolicies | Sort-Object Name)) {
    $markdown += "## $($group.Name)`n`n"
    $markdown += "**Count:** $($group.Count)`n`n"
    
    $policies = $group.Group | Sort-Object Name
    
    foreach ($policy in $policies) {
        $markdown += "### $($policy.Name)`n`n"
        $markdown += "- **Policy ID:** ``$($policy.ID)```n"
        $markdown += "- **Type:** $($policy.ODataType)`n`n"
        
        # Add assignments information
        if ($policy.Assignments -and $policy.Assignments.Count -gt 0) {
            $markdown += "#### Assignments`n`n"
            $markdown += "| Target | Group ID | Filter ID | Filter Type |`n"
            $markdown += "|--------|----------|-----------|-------------|`n"
            foreach ($assignment in $policy.Assignments) {
                $targetType = if ($assignment.target.'@odata.type') { 
                    $assignment.target.'@odata.type' -replace '#microsoft.graph.', '' 
                } else { 
                    "N/A" 
                }
                $groupId = if ($assignment.target.groupId) { $assignment.target.groupId } else { "N/A" }
                $filterId = if ($assignment.target.deviceAndAppManagementAssignmentFilterId) { $assignment.target.deviceAndAppManagementAssignmentFilterId } else { "N/A" }
                $filterType = if ($assignment.target.deviceAndAppManagementAssignmentFilterType) { $assignment.target.deviceAndAppManagementAssignmentFilterType } else { "N/A" }
                $markdown += "| $targetType | ``$groupId`` | ``$filterId`` | $filterType |`n"
            }
            $markdown += "`n"
        }
        
        # Add full configuration details
        if ($policy.Configuration) {
            $markdown += "#### Policy Configuration`n`n"
            $markdown += "``````json`n"
            $markdown += ($policy.Configuration | ConvertTo-Json -Depth 10)
            $markdown += "`n``````n`n"
        }
        
        # Add Settings Catalog specific settings
        if ($policy.Settings) {
            $markdown += "#### Settings Details`n`n"
            $markdown += "``````json`n"
            $markdown += ($policy.Settings | ConvertTo-Json -Depth 10)
            $markdown += "`n``````n`n"
        }
        
        $markdown += "---`n`n"
    }
}

$markdown += "`n*End of IAC Intune Policies Documentation*`n"

# Save to file
$outputPath = "/Users/jon/Desktop/BaslineSetup/IAC-Intune-Policies-Documentation.md"
$markdown | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ Documentation exported to: $outputPath" -ForegroundColor Green
Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
