<#
.SYNOPSIS
    Creates a master markdown documentation file combining IAC Entra and Intune policies.

.DESCRIPTION
    Reads the IAC Entra Policies JSON and IAC Intune Policies JSON folders and generates
    a comprehensive master documentation file with all policies in one place.

.PARAMETER EntraPath
    Path to the Entra policies JSON folder. Default: /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON

.PARAMETER IntunePath
    Path to the Intune policies JSON folder. Default: /Users/jon/Desktop/BaslineSetup/IAC-Policies-JSON

.PARAMETER OutputPath
    Path for the output master documentation file. Default: /Users/jon/Desktop/BaslineSetup/IAC-Master-Documentation.md

.EXAMPLE
    .\create-master-documentation.ps1

.NOTES
    Author: GitHub Copilot
    Date: 2026-01-16
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$EntraPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON",
    
    [Parameter(Mandatory=$false)]
    [string]$IntunePath = "/Users/jon/Desktop/BaslineSetup/IAC-Intune-Policies-JSON",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "/Users/jon/Desktop/BaslineSetup/IAC-Master-Documentation.md"
)

Write-Host "`n=== Generating Master IAC Documentation ===" -ForegroundColor Cyan
Write-Host "Entra Path: $EntraPath" -ForegroundColor Gray
Write-Host "Intune Path: $IntunePath" -ForegroundColor Gray
Write-Host "Output Path: $OutputPath`n" -ForegroundColor Gray

# Initialize markdown content
$markdown = @"
# IAC Master Documentation

**Complete Infrastructure as Code Policy Documentation**

**Generated:** $(Get-Date -Format "MMMM dd, yyyy HH:mm:ss")

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Entra ID (Identity & Access)](#entra-id-identity--access)
   - [Conditional Access Policies](#conditional-access-policies)
   - [Named Locations](#named-locations)
3. [Microsoft Intune (Device Management)](#microsoft-intune-device-management)
   - [Device Configuration Policies](#device-configuration-policies)
   - [Settings Catalog Policies](#settings-catalog-policies)
   - [Compliance Policies](#compliance-policies)
   - [Administrative Templates](#administrative-templates)
   - [Endpoint Security](#endpoint-security)
   - [Scripts](#scripts)
   - [Autopilot Profiles](#autopilot-profiles)

---

## Executive Summary

This master documentation provides a comprehensive overview of all Infrastructure as Code (IAC) policies deployed across the organization. These policies are organized into two main categories:

### Entra ID (Identity & Access Management)
Identity and access control policies that govern how users authenticate and access resources:
- **Conditional Access Policies**: Dynamic access controls based on conditions
- **Named Locations**: Trusted network locations and IP ranges

### Microsoft Intune (Device & Endpoint Management)
Device configuration and compliance policies that ensure endpoints meet security standards:
- **Device Configuration**: Platform-specific settings and configurations
- **Settings Catalog**: Modern, granular policy settings
- **Compliance Policies**: Required security baseline for devices
- **Administrative Templates**: Group Policy-style settings
- **Endpoint Security**: Security-focused configurations (antivirus, firewall, disk encryption)
- **Scripts**: PowerShell scripts for automation and remediation
- **Autopilot Profiles**: Automated device enrollment and setup

---

"@

# ========================================
# ENTRA ID POLICIES
# ========================================

$markdown += @"
## Entra ID (Identity & Access)

Microsoft Entra ID (formerly Azure Active Directory) policies control authentication, authorization, and access to resources.

### Conditional Access Policies

Conditional Access policies evaluate signals such as user, device, location, and risk to make real-time access decisions.

"@

# Process Conditional Access Policies
$caFolder = Join-Path $EntraPath "ConditionalAccess"
$caCount = 0

if (Test-Path $caFolder) {
    $caFiles = Get-ChildItem -Path $caFolder -Filter "*.json" | Sort-Object Name
    $caCount = $caFiles.Count
    Write-Host "Processing $caCount Conditional Access policies..." -ForegroundColor Yellow
    
    $policyNum = 0
    foreach ($file in $caFiles) {
        $policyNum++
        Write-Host "  CA [$policyNum/$caCount] $($file.BaseName)" -ForegroundColor White
        
        $policyData = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        $config = $policyData.PolicyConfig
        
        $stateEmoji = switch ($config.state) {
            "enabled" { "🟢" }
            "disabled" { "🔴" }
            "enabledForReportingButNotEnforced" { "🟡" }
            default { "⚪" }
        }
        
        $markdown += @"

#### $($config.displayName) $stateEmoji

**State:** ``$($config.state)``

"@
        
        # Add conditions summary
        if ($config.conditions) {
            $markdown += "**Applies To:** "
            
            $appliesTo = @()
            
            # Users
            if ($policyData.AssignmentDetails.IncludeUsers) {
                $userCount = $policyData.AssignmentDetails.IncludeUsers.Count
                if ($policyData.AssignmentDetails.IncludeUsers.DisplayName -contains "All") {
                    $appliesTo += "All users"
                } else {
                    $appliesTo += "$userCount user(s)"
                }
            }
            
            # Groups
            if ($policyData.AssignmentDetails.IncludeGroups) {
                $appliesTo += "$($policyData.AssignmentDetails.IncludeGroups.Count) group(s)"
            }
            
            # Roles
            if ($policyData.AssignmentDetails.IncludeRoles) {
                $appliesTo += "$($policyData.AssignmentDetails.IncludeRoles.Count) role(s)"
            }
            
            $markdown += ($appliesTo -join ", ") + "`n`n"
            
            # Applications
            if ($config.conditions.applications.includeApplications) {
                $appList = $config.conditions.applications.includeApplications
                if ("All" -in $appList) {
                    $markdown += "**Applications:** All cloud apps`n`n"
                } elseif ("Office365" -in $appList) {
                    $markdown += "**Applications:** Office 365`n`n"
                } else {
                    $markdown += "**Applications:** $($appList.Count) app(s)`n`n"
                }
            }
            
            # Controls
            if ($config.grantControls.builtInControls) {
                $controls = @()
                foreach ($control in $config.grantControls.builtInControls) {
                    switch ($control) {
                        "mfa" { $controls += "MFA" }
                        "compliantDevice" { $controls += "Compliant Device" }
                        "domainJoinedDevice" { $controls += "Hybrid Azure AD Join" }
                        "block" { $controls += "Block Access" }
                        default { $controls += $control }
                    }
                }
                $markdown += "**Controls:** " + ($controls -join ", ") + "`n`n"
            }
        }
    }
} else {
    Write-Host "⚠️  Conditional Access folder not found" -ForegroundColor Yellow
}

# Named Locations
$markdown += @"

### Named Locations

Named Locations define trusted network locations used in Conditional Access policies.

"@

$locFolder = Join-Path $EntraPath "NamedLocations"
$locCount = 0

if (Test-Path $locFolder) {
    $locFiles = Get-ChildItem -Path $locFolder -Filter "*.json" | Sort-Object Name
    $locCount = $locFiles.Count
    Write-Host "Processing $locCount Named Locations..." -ForegroundColor Yellow
    
    $locNum = 0
    foreach ($file in $locFiles) {
        $locNum++
        Write-Host "  NL [$locNum/$locCount] $($file.BaseName)" -ForegroundColor White
        
        $locationData = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        $config = $locationData.LocationConfig
        
        $trustedEmoji = if ($config.isTrusted) { "✅" } else { "❌" }
        
        $markdown += @"

#### $($config.displayName) $trustedEmoji

**Type:** $($locationData.LocationType) | **Trusted:** $(if ($config.isTrusted) { "Yes" } else { "No" })

"@
        
        if ($locationData.LocationType -eq "IP Location" -and $config.ipRanges) {
            $markdown += "**IP Ranges:** " + $config.ipRanges.Count + " range(s)`n`n"
        }
        
        if ($locationData.LocationType -eq "Country Location" -and $config.countriesAndRegions) {
            $markdown += "**Countries:** " + ($config.countriesAndRegions -join ", ") + "`n`n"
        }
    }
} else {
    $markdown += "*No Named Locations configured*`n`n"
}

# ========================================
# INTUNE POLICIES
# ========================================

$markdown += @"

---

## Microsoft Intune (Device Management)

Microsoft Intune policies manage device configuration, compliance, and security across Windows, iOS, Android, and macOS platforms.

"@

# Helper function to get policy type folders
$intuneTypes = @{
    "DeviceConfiguration" = "Device Configuration Policies"
    "SettingsCatalog" = "Settings Catalog Policies"
    "Compliance" = "Compliance Policies"
    "AdminTemplates" = "Administrative Templates"
    "EndpointSecurity" = "Endpoint Security"
    "Scripts" = "Scripts"
    "Autopilot" = "Autopilot Profiles"
}

foreach ($folder in $intuneTypes.Keys) {
    $folderPath = Join-Path $IntunePath $folder
    $sectionTitle = $intuneTypes[$folder]
    
    $markdown += @"

### $sectionTitle

"@
    
    if (Test-Path $folderPath) {
        $policyFiles = Get-ChildItem -Path $folderPath -Filter "*.json" | Sort-Object Name
        $policyCount = $policyFiles.Count
        
        Write-Host "Processing $policyCount $folder policies..." -ForegroundColor Yellow
        
        if ($policyCount -eq 0) {
            $markdown += "*No policies in this category*`n`n"
            continue
        }
        
        $policyNum = 0
        foreach ($file in $policyFiles) {
            $policyNum++
            Write-Host "  [$folder] [$policyNum/$policyCount] $($file.BaseName)" -ForegroundColor White
            
            $policyData = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $config = $policyData.PolicyConfig
            
            # Get policy name - try different fields
            $policyName = if ($config.name) { 
                $config.name 
            } elseif ($config.displayName) { 
                $config.displayName 
            } else { 
                $file.BaseName 
            }
            
            $markdown += @"

#### $policyName

"@
            
            # Description if available
            if ($config.description -and $config.description -ne "") {
                $markdown += "**Description:** $($config.description)`n`n"
            }
            
            # Platform information
            if ($config.platforms) {
                $markdown += "**Platforms:** " + ($config.platforms -join ", ") + "`n`n"
            } elseif ($config.'@odata.type') {
                $odataType = $config.'@odata.type'
                if ($odataType -match "windows") {
                    $markdown += "**Platform:** Windows`n`n"
                } elseif ($odataType -match "ios") {
                    $markdown += "**Platform:** iOS`n`n"
                } elseif ($odataType -match "android") {
                    $markdown += "**Platform:** Android`n`n"
                } elseif ($odataType -match "macOS") {
                    $markdown += "**Platform:** macOS`n`n"
                }
            }
            
            # Technology/Template
            if ($config.technologies) {
                $markdown += "**Technology:** " + ($config.technologies -join ", ") + "`n`n"
            }
            
            if ($config.templateReference) {
                $markdown += "**Template:** " + $config.templateReference.templateDisplayName + "`n`n"
            }
            
            # Assignments
            if ($policyData.Assignments -and $policyData.Assignments.Count -gt 0) {
                $markdown += "**Assignments:** $($policyData.Assignments.Count) assignment(s)`n`n"
                
                # List assignment targets
                $markdown += "**Assigned To:**`n"
                foreach ($assignment in $policyData.Assignments) {
                    if ($assignment.target) {
                        $targetType = $assignment.target.'@odata.type'
                        if ($targetType -eq '#microsoft.graph.allDevicesAssignmentTarget') {
                            $markdown += "- All Devices`n"
                        } elseif ($targetType -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                            $markdown += "- All Users`n"
                        } elseif ($targetType -eq '#microsoft.graph.groupAssignmentTarget') {
                            $markdown += "- Group: " + $assignment.target.groupId + "`n"
                        }
                    }
                }
                $markdown += "`n"
            }
            
            # Settings details
            if ($policyData.Settings) {
                $settingsArray = if ($policyData.Settings -is [array]) { 
                    $policyData.Settings 
                } else { 
                    @($policyData.Settings) 
                }
                
                $markdown += "**Settings Configured:** $($settingsArray.Count)`n`n"
                
                # Show key settings (limit to avoid overwhelming the doc)
                if ($settingsArray.Count -gt 0 -and $settingsArray.Count -le 20) {
                    $markdown += "<details>`n<summary>View Settings</summary>`n`n"
                    
                    foreach ($setting in $settingsArray) {
                        if ($setting.settingInstance) {
                            # Settings Catalog format
                            $settingDef = $setting.settingInstance.settingDefinitionId
                            if ($settingDef) {
                                # Extract readable name from definition ID
                                $settingName = ($settingDef -split '_')[-1]
                                $markdown += "- **$settingName**"
                                
                                # Get value
                                if ($setting.settingInstance.simpleSettingValue) {
                                    $value = $setting.settingInstance.simpleSettingValue.value
                                    if ($value -is [bool]) {
                                        $markdown += ": " + $(if ($value) { "Enabled" } else { "Disabled" })
                                    } else {
                                        $markdown += ": ``$value``"
                                    }
                                } elseif ($setting.settingInstance.choiceSettingValue) {
                                    $choice = ($setting.settingInstance.choiceSettingValue.value -split '_')[-1]
                                    $markdown += ": $choice"
                                }
                                $markdown += "`n"
                            }
                        } elseif ($setting.'@odata.type') {
                            # Device Configuration format
                            $settingType = $setting.'@odata.type'
                            if ($settingType -match 'OmaSettingString|OmaSettingInteger') {
                                $markdown += "- **$($setting.displayName)**: ``$($setting.value)```n"
                            }
                        }
                    }
                    
                    $markdown += "`n</details>`n`n"
                } elseif ($settingsArray.Count -gt 20) {
                    $markdown += "*Too many settings to display inline. See detailed documentation or JSON export for full configuration.*`n`n"
                }
            }
            
            # For Group Policy (Admin Templates)
            if ($policyData.GroupPolicyValues) {
                $gpValues = $policyData.GroupPolicyValues
                $markdown += "**Group Policy Values:** $($gpValues.Count)`n`n"
                
                if ($gpValues.Count -gt 0 -and $gpValues.Count -le 15) {
                    $markdown += "<details>`n<summary>View Group Policy Settings</summary>`n`n"
                    
                    foreach ($gp in $gpValues) {
                        $markdown += "- **$($gp.definition.displayName)**"
                        if ($gp.value) {
                            $markdown += ": ``$($gp.value)``"
                        }
                        $markdown += "`n"
                    }
                    
                    $markdown += "`n</details>`n`n"
                }
            }
            
            # For Endpoint Security Intents
            if ($policyData.IntentSettings) {
                $intentSettings = $policyData.IntentSettings
                $markdown += "**Security Settings:** $($intentSettings.Count)`n`n"
                
                if ($intentSettings.Count -gt 0 -and $intentSettings.Count -le 15) {
                    $markdown += "<details>`n<summary>View Security Settings</summary>`n`n"
                    
                    foreach ($intentSetting in $intentSettings) {
                        if ($intentSetting.displayName) {
                            $markdown += "- **$($intentSetting.displayName)**"
                            if ($intentSetting.value) {
                                $markdown += ": ``$($intentSetting.value)``"
                            }
                            $markdown += "`n"
                        }
                    }
                    
                    $markdown += "`n</details>`n`n"
                }
            }
        }
    } else {
        Write-Host "⚠️  $folder folder not found" -ForegroundColor Yellow
        $markdown += "*Folder not found*`n`n"
    }
}

# ========================================
# SUMMARY STATISTICS
# ========================================

$markdown += @"

---

## Summary Statistics

### Entra ID Policies
- **Conditional Access Policies:** $caCount
- **Named Locations:** $locCount

### Intune Policies

"@

foreach ($folder in $intuneTypes.Keys) {
    $folderPath = Join-Path $IntunePath $folder
    if (Test-Path $folderPath) {
        $count = (Get-ChildItem -Path $folderPath -Filter "*.json").Count
        $markdown += "- **$($intuneTypes[$folder]):** $count`n"
    } else {
        $markdown += "- **$($intuneTypes[$folder]):** 0`n"
    }
}

$markdown += @"

---

## Policy Management

### Export Locations

**Entra Policies JSON:** ``$EntraPath``
**Intune Policies JSON:** ``$IntunePath``

### Documentation Scripts

- **Entra Export:** ``/Users/jon/Desktop/BaslineSetup/Scripts/Entra/export-iac-entra-policies-json.ps1``
- **Entra Recreate:** ``/Users/jon/Desktop/BaslineSetup/Scripts/Entra/recreate-iac-entra-policies.ps1``
- **Intune Export:** ``/Users/jon/Desktop/BaslineSetup/Scripts/Intune/export-iac-policies-json.ps1``
- **Intune Recreate:** ``/Users/jon/Desktop/BaslineSetup/Scripts/Intune/recreate-iac-policies.ps1``

### Related Documentation

- **Detailed Entra Documentation:** [IAC-Entra-Policies-Documentation.md](IAC-Entra-Policies-Documentation.md)
- **Detailed Intune Documentation:** [IAC-Intune-Policies-Documentation.md](IAC-Intune-Policies-Documentation.md)
- **Entra README:** [Scripts/Entra/README-RecreateIACEntraPolicies.md](Scripts/Entra/README-RecreateIACEntraPolicies.md)
- **Intune README:** [Scripts/Intune/README-RecreateIACPolicies.md](Scripts/Intune/README-RecreateIACPolicies.md)

---

*This master documentation provides a high-level overview. For detailed policy configurations, settings, and JSON exports, refer to the individual documentation files listed above.*

"@

# Save markdown file
$markdown | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "`n✅ Master documentation generated successfully!" -ForegroundColor Green
Write-Host "   Output: $OutputPath" -ForegroundColor Gray
Write-Host "`nPolicy Counts:" -ForegroundColor Cyan
Write-Host "   CA Policies: $caCount" -ForegroundColor Gray
Write-Host "   Named Locations: $locCount" -ForegroundColor Gray

foreach ($folder in $intuneTypes.Keys) {
    $folderPath = Join-Path $IntunePath $folder
    if (Test-Path $folderPath) {
        $count = (Get-ChildItem -Path $folderPath -Filter "*.json").Count
        Write-Host "   $($intuneTypes[$folder]): $count" -ForegroundColor Gray
    }
}

Write-Host ""
