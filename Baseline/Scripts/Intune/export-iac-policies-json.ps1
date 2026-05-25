# Export all IAC Intune policies to JSON files for backup and recreation

Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All", "DeviceManagementApps.Read.All" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   EXPORT IAC POLICIES TO JSON FILES" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Create export directory structure
$exportPath = "/Users/jon/Desktop/BaslineSetup/IAC-Policies-JSON"
$paths = @{
    Root = $exportPath
    DeviceConfiguration = "$exportPath/DeviceConfiguration"
    SettingsCatalog = "$exportPath/SettingsCatalog"
    Compliance = "$exportPath/Compliance"
    AdminTemplates = "$exportPath/AdminTemplates"
    EndpointSecurity = "$exportPath/EndpointSecurity"
    Scripts = "$exportPath/Scripts"
    Autopilot = "$exportPath/Autopilot"
}

foreach ($path in $paths.Values) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

Write-Host "📁 Export directory: $exportPath`n" -ForegroundColor Cyan

$exportedCount = 0

# Helper function to sanitize filename
function Get-SafeFileName {
    param($name)
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $safe = $name
    foreach ($char in $invalid) {
        $safe = $safe.Replace($char, '_')
    }
    return $safe
}

# Helper function to get Settings Catalog configuration
function Get-SettingsCatalogConfig {
    param($policyId)
    try {
        $settings = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/settings").value
        return $settings
    } catch {
        Write-Host "      ⚠️  Could not retrieve settings" -ForegroundColor Yellow
        return $null
    }
}

# Helper function to get Group Policy values
function Get-GroupPolicyValues {
    param($configId)
    try {
        $values = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$configId')/definitionValues?`$expand=definition").value
        return $values
    } catch {
        Write-Host "      ⚠️  Could not retrieve settings" -ForegroundColor Yellow
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
        Write-Host "      ⚠️  Could not retrieve settings" -ForegroundColor Yellow
        return $null
    }
}

# Helper function to get assignments
function Get-PolicyAssignments {
    param($policyId, $uri)
    try {
        $assignments = (Invoke-MgGraphRequest -Method GET -Uri $uri).value
        return $assignments
    } catch {
        return $null
    }
}

# 1. Export Device Configuration Policies
Write-Host "🔍 Exporting Device Configuration Policies..." -ForegroundColor Yellow
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
            $safeName = Get-SafeFileName -name $policy.displayName
            $fileName = "$($paths.DeviceConfiguration)/$safeName.json"
            
            Write-Host "   Exporting: $($policy.displayName)" -ForegroundColor White
            
            $assignments = Get-PolicyAssignments -policyId $policy.id -uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations('$($policy.id)')/assignments"
            
            $export = @{
                PolicyType = "DeviceConfiguration"
                Policy = $policy
                Assignments = $assignments
                ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            
            $export | ConvertTo-Json -Depth 20 | Out-File -FilePath $fileName -Encoding UTF8
            $exportedCount++
        }
    }
    Write-Host "   ✅ Exported $($deviceConfigs.Where({$_.displayName -like 'IAC*'}).Count) policies`n" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# 2. Export Settings Catalog Policies
Write-Host "🔍 Exporting Settings Catalog Policies..." -ForegroundColor Yellow
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
            $safeName = Get-SafeFileName -name $policy.name
            $fileName = "$($paths.SettingsCatalog)/$safeName.json"
            
            Write-Host "   Exporting: $($policy.name)" -ForegroundColor White
            Write-Host "      Retrieving settings..." -ForegroundColor Gray
            
            $settings = Get-SettingsCatalogConfig -policyId $policy.id
            $assignments = Get-PolicyAssignments -policyId $policy.id -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$($policy.id)')/assignments"
            
            $export = @{
                PolicyType = "SettingsCatalog"
                Policy = $policy
                Settings = $settings
                Assignments = $assignments
                ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            
            $export | ConvertTo-Json -Depth 20 | Out-File -FilePath $fileName -Encoding UTF8
            $exportedCount++
        }
    }
    Write-Host "   ✅ Exported $($settingsCatalog.Where({$_.name -like 'IAC*'}).Count) policies`n" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# 3. Export Compliance Policies
Write-Host "🔍 Exporting Compliance Policies..." -ForegroundColor Yellow
try {
    $compliancePolicies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies").value
    
    foreach ($policy in $compliancePolicies) {
        if ($policy.displayName -like "IAC*") {
            $safeName = Get-SafeFileName -name $policy.displayName
            $fileName = "$($paths.Compliance)/$safeName.json"
            
            Write-Host "   Exporting: $($policy.displayName)" -ForegroundColor White
            
            $assignments = Get-PolicyAssignments -policyId $policy.id -uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies('$($policy.id)')/assignments"
            
            $export = @{
                PolicyType = "Compliance"
                Policy = $policy
                Assignments = $assignments
                ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            
            $export | ConvertTo-Json -Depth 20 | Out-File -FilePath $fileName -Encoding UTF8
            $exportedCount++
        }
    }
    Write-Host "   ✅ Exported $($compliancePolicies.Where({$_.displayName -like 'IAC*'}).Count) policies`n" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# 4. Export Administrative Templates
Write-Host "🔍 Exporting Administrative Templates..." -ForegroundColor Yellow
try {
    $adminTemplates = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations").value
    
    foreach ($template in $adminTemplates) {
        if ($template.displayName -like "IAC*") {
            $safeName = Get-SafeFileName -name $template.displayName
            $fileName = "$($paths.AdminTemplates)/$safeName.json"
            
            Write-Host "   Exporting: $($template.displayName)" -ForegroundColor White
            Write-Host "      Retrieving settings..." -ForegroundColor Gray
            
            $settings = Get-GroupPolicyValues -configId $template.id
            $assignments = Get-PolicyAssignments -policyId $template.id -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations('$($template.id)')/assignments"
            
            $export = @{
                PolicyType = "AdminTemplate"
                Policy = $template
                Settings = $settings
                Assignments = $assignments
                ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            
            $export | ConvertTo-Json -Depth 20 | Out-File -FilePath $fileName -Encoding UTF8
            $exportedCount++
        }
    }
    Write-Host "   ✅ Exported $($adminTemplates.Where({$_.displayName -like 'IAC*'}).Count) policies`n" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# 5. Export Endpoint Security Intents
Write-Host "🔍 Exporting Endpoint Security Policies..." -ForegroundColor Yellow
try {
    $intents = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/intents").value
    
    foreach ($policy in $intents) {
        if ($policy.displayName -like "IAC*") {
            $safeName = Get-SafeFileName -name $policy.displayName
            $fileName = "$($paths.EndpointSecurity)/$safeName.json"
            
            Write-Host "   Exporting: $($policy.displayName)" -ForegroundColor White
            Write-Host "      Retrieving settings..." -ForegroundColor Gray
            
            $settings = Get-IntentSettings -intentId $policy.id
            $assignments = Get-PolicyAssignments -policyId $policy.id -uri "https://graph.microsoft.com/beta/deviceManagement/intents('$($policy.id)')/assignments"
            
            $export = @{
                PolicyType = "EndpointSecurity"
                Policy = $policy
                Settings = $settings
                Assignments = $assignments
                ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            
            $export | ConvertTo-Json -Depth 20 | Out-File -FilePath $fileName -Encoding UTF8
            $exportedCount++
        }
    }
    Write-Host "   ✅ Exported $($intents.Where({$_.displayName -like 'IAC*'}).Count) policies`n" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# 6. Export PowerShell Scripts
Write-Host "🔍 Exporting PowerShell Scripts..." -ForegroundColor Yellow
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
            $safeName = Get-SafeFileName -name $script.displayName
            $fileName = "$($paths.Scripts)/$safeName.json"
            
            Write-Host "   Exporting: $($script.displayName)" -ForegroundColor White
            
            # Get script content
            try {
                $scriptContent = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts('$($script.id)')"
                $assignments = Get-PolicyAssignments -policyId $script.id -uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts('$($script.id)')/assignments"
                
                $export = @{
                    PolicyType = "PowerShellScript"
                    Policy = $scriptContent
                    Assignments = $assignments
                    ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                }
                
                $export | ConvertTo-Json -Depth 20 | Out-File -FilePath $fileName -Encoding UTF8
                $exportedCount++
            } catch {
                Write-Host "      ⚠️  Could not export script content" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "   ✅ Exported $($psScripts.Where({$_.displayName -like 'IAC*'}).Count) scripts`n" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# 7. Export Autopilot Profiles
Write-Host "🔍 Exporting Autopilot Profiles..." -ForegroundColor Yellow
try {
    $autopilotProfiles = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles").value
    
    foreach ($profile in $autopilotProfiles) {
        if ($profile.displayName -like "IAC*") {
            $safeName = Get-SafeFileName -name $profile.displayName
            $fileName = "$($paths.Autopilot)/$safeName.json"
            
            Write-Host "   Exporting: $($profile.displayName)" -ForegroundColor White
            
            $assignments = Get-PolicyAssignments -policyId $profile.id -uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles('$($profile.id)')/assignments"
            
            $export = @{
                PolicyType = "AutopilotProfile"
                Policy = $profile
                Assignments = $assignments
                ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            
            $export | ConvertTo-Json -Depth 20 | Out-File -FilePath $fileName -Encoding UTF8
            $exportedCount++
        }
    }
    Write-Host "   ✅ Exported $($autopilotProfiles.Where({$_.displayName -like 'IAC*'}).Count) profiles`n" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# Create index file
Write-Host "📝 Creating index file..." -ForegroundColor Cyan
$index = @{
    ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    TotalPolicies = $exportedCount
    ExportPath = $exportPath
    PolicyTypes = @{
        DeviceConfiguration = (Get-ChildItem "$($paths.DeviceConfiguration)/*.json").Count
        SettingsCatalog = (Get-ChildItem "$($paths.SettingsCatalog)/*.json").Count
        Compliance = (Get-ChildItem "$($paths.Compliance)/*.json").Count
        AdminTemplates = (Get-ChildItem "$($paths.AdminTemplates)/*.json").Count
        EndpointSecurity = (Get-ChildItem "$($paths.EndpointSecurity)/*.json").Count
        Scripts = (Get-ChildItem "$($paths.Scripts)/*.json").Count
        Autopilot = (Get-ChildItem "$($paths.Autopilot)/*.json").Count
    }
}

$index | ConvertTo-Json -Depth 10 | Out-File -FilePath "$exportPath/index.json" -Encoding UTF8

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "EXPORT COMPLETE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "✅ Total policies exported: $exportedCount" -ForegroundColor Green
Write-Host "📁 Export location: $exportPath" -ForegroundColor Cyan
Write-Host "`n📊 Breakdown:" -ForegroundColor White
$index.PolicyTypes.GetEnumerator() | Sort-Object Name | ForEach-Object {
    Write-Host "   $($_.Key): " -ForegroundColor White -NoNewline
    Write-Host "$($_.Value)" -ForegroundColor Yellow
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
