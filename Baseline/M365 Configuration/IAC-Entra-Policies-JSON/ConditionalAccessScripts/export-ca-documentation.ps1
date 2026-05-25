<#
.SYNOPSIS
    Creates comprehensive markdown documentation for IAC Conditional Access policies and Named Locations.

.DESCRIPTION
    Reads exported JSON files and generates detailed markdown documentation including
    policy configurations, conditions, controls, and descriptions.

.PARAMETER ImportPath
    Path to the exported JSON files. Default: /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON

.PARAMETER OutputPath
    Path for the output markdown file. Default: /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-Documentation.md

.EXAMPLE
    .\export-ca-documentation.ps1

.NOTES
    Author: GitHub Copilot
    Date: 2026-01-16
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ImportPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-Documentation.md"
)

# Helper function to describe policy purpose based on name and config
function Get-PolicyDescription {
    param(
        [string]$Name,
        [object]$Config
    )
    
    $description = ""
    
    # Analyze policy name and configuration to generate description
    if ($Name -match "BLOCK.*Legacy Authentication") {
        $description = "Blocks legacy authentication protocols that don't support modern security features like MFA. Prevents sign-ins using basic authentication, which is commonly exploited in password spray attacks."
    }
    elseif ($Name -match "BLOCK.*Device Code") {
        $description = "Blocks the device code authentication flow to prevent unauthorized access. Device code flow can be abused for phishing attacks where attackers trick users into authenticating on their behalf."
    }
    elseif ($Name -match "BLOCK.*Unsupported.*Platform") {
        $description = "Blocks sign-ins from unsupported or unmanaged device platforms to reduce security risks. Ensures users only access resources from approved operating systems."
    }
    elseif ($Name -match "GRANT.*Device Registration.*trusted") {
        $description = "Allows device registration only from trusted network locations. Ensures devices are enrolled from secure, known locations like corporate offices."
    }
    elseif ($Name -match "GRANT.*Mobile Apps.*Desktop") {
        $description = "Enforces security requirements for mobile apps and desktop client access. Ensures modern authentication and security controls are applied to native applications."
    }
    elseif ($Name -match "GRANT.*Mobile Device Access") {
        $description = "Requires mobile devices to meet compliance requirements before accessing resources. Enforces device compliance policies for iOS and Android devices."
    }
    elseif ($Name -match "SESSION.*Admin Persistence") {
        $description = "Limits administrator session duration to reduce the risk of compromised admin accounts. Forces admins to re-authenticate after the specified time period."
    }
    elseif ($Name -match "GRANT.*MFA.*Admin") {
        $description = "Requires Multi-Factor Authentication for all administrator roles. Provides additional security for privileged accounts that have elevated access."
    }
    elseif ($Name -match "GRANT.*MFA") {
        $description = "Requires Multi-Factor Authentication for user access. Adds an extra layer of security beyond just username and password."
    }
    elseif ($Name -match "GRANT.*Compliant.*Device") {
        $description = "Requires devices to be compliant with organizational security policies. Ensures devices meet minimum security standards before accessing corporate resources."
    }
    elseif ($Name -match "GRANT.*Hybrid.*Join") {
        $description = "Requires devices to be Hybrid Azure AD Joined or compliant. Ensures devices are managed and meet security requirements."
    }
    elseif ($Name -match "BLOCK.*Risk") {
        $description = "Blocks sign-ins based on detected risk levels. Uses Microsoft Entra ID Protection to identify and block potentially compromised accounts or risky sign-in attempts."
    }
    elseif ($Name -match "SESSION.*Sign.*in.*Frequency") {
        $description = "Controls how often users must re-authenticate. Balances security and user experience by requiring periodic re-authentication."
    }
    elseif ($Name -match "BLOCK.*Countries|BLOCK.*Location") {
        $description = "Blocks access from specific geographic locations or countries. Prevents unauthorized access from regions where the organization doesn't operate."
    }
    elseif ($Name -match "GRANT.*Trusted.*Location") {
        $description = "Applies different security controls based on user location. Allows reduced security requirements when accessing from trusted corporate networks."
    }
    elseif ($Name -match "GRANT.*Terms.*Use") {
        $description = "Requires users to accept terms of use before accessing resources. Ensures users acknowledge and agree to organizational policies."
    }
    else {
        $description = "Conditional Access policy that enforces security requirements based on specific conditions."
    }
    
    return $description
}

# Helper function to format user/group assignments
function Format-Assignments {
    param([object]$Details)
    
    $output = ""
    
    if ($Details.IncludeUsers -and $Details.IncludeUsers.Count -gt 0) {
        $output += "**Include Users:**`n"
        foreach ($user in $Details.IncludeUsers) {
            if ($user.DisplayName -eq "All") {
                $output += "- All users`n"
            }
            elseif ($user.DisplayName -eq "GuestsOrExternalUsers") {
                $output += "- Guest or External Users`n"
            }
            else {
                $output += "- $($user.DisplayName)"
                if ($user.UPN) { $output += " ($($user.UPN))" }
                $output += "`n"
            }
        }
    }
    
    if ($Details.ExcludeUsers -and $Details.ExcludeUsers.Count -gt 0) {
        $output += "`n**Exclude Users:**`n"
        foreach ($user in $Details.ExcludeUsers) {
            $output += "- $($user.DisplayName)"
            if ($user.UPN) { $output += " ($($user.UPN))" }
            $output += "`n"
        }
    }
    
    if ($Details.IncludeGroups -and $Details.IncludeGroups.Count -gt 0) {
        $output += "`n**Include Groups:**`n"
        foreach ($group in $Details.IncludeGroups) {
            $output += "- $($group.DisplayName)`n"
        }
    }
    
    if ($Details.ExcludeGroups -and $Details.ExcludeGroups.Count -gt 0) {
        $output += "`n**Exclude Groups:**`n"
        foreach ($group in $Details.ExcludeGroups) {
            $output += "- $($group.DisplayName)`n"
        }
    }
    
    if ($Details.IncludeRoles -and $Details.IncludeRoles.Count -gt 0) {
        $output += "`n**Include Roles:**`n"
        foreach ($role in $Details.IncludeRoles) {
            $output += "- $($role.DisplayName)`n"
        }
    }
    
    if ($Details.ExcludeRoles -and $Details.ExcludeRoles.Count -gt 0) {
        $output += "`n**Exclude Roles:**`n"
        foreach ($role in $Details.ExcludeRoles) {
            $output += "- $($role.DisplayName)`n"
        }
    }
    
    return $output
}

# Helper function to format applications
function Format-Applications {
    param([object]$Apps)
    
    $output = ""
    
    if ($Apps.includeApplications) {
        $output += "**Include Applications:**`n"
        foreach ($app in $Apps.includeApplications) {
            if ($app -eq "All") {
                $output += "- All cloud apps`n"
            }
            elseif ($app -eq "Office365") {
                $output += "- Office 365`n"
            }
            else {
                $output += "- $app`n"
            }
        }
    }
    
    if ($Apps.excludeApplications) {
        $output += "`n**Exclude Applications:**`n"
        foreach ($app in $Apps.excludeApplications) {
            $output += "- $app`n"
        }
    }
    
    return $output
}

# Helper function to format platforms
function Format-Platforms {
    param([object]$Platforms)
    
    if (-not $Platforms) { return "" }
    
    $output = ""
    
    if ($Platforms.includePlatforms) {
        $output += "**Include Platforms:** "
        $output += ($Platforms.includePlatforms -join ", ") + "`n"
    }
    
    if ($Platforms.excludePlatforms) {
        $output += "**Exclude Platforms:** "
        $output += ($Platforms.excludePlatforms -join ", ") + "`n"
    }
    
    return $output
}

# Helper function to format locations
function Format-Locations {
    param([object]$Locations)
    
    if (-not $Locations) { return "" }
    
    $output = ""
    
    if ($Locations.includeLocations) {
        $output += "**Include Locations:** "
        $includeList = @()
        foreach ($loc in $Locations.includeLocations) {
            if ($loc -eq "All") {
                $includeList += "All locations"
            }
            elseif ($loc -eq "AllTrusted") {
                $includeList += "All trusted locations"
            }
            else {
                $includeList += $loc
            }
        }
        $output += ($includeList -join ", ") + "`n"
    }
    
    if ($Locations.excludeLocations) {
        $output += "**Exclude Locations:** "
        $output += ($Locations.excludeLocations -join ", ") + "`n"
    }
    
    return $output
}

# Helper function to format grant controls
function Format-GrantControls {
    param([object]$Controls)
    
    if (-not $Controls) { return "None" }
    
    $output = ""
    
    if ($Controls.operator) {
        $output += "**Operator:** " + $Controls.operator.ToUpper() + "`n`n"
    }
    
    if ($Controls.builtInControls) {
        $output += "**Required Controls:**`n"
        foreach ($control in $Controls.builtInControls) {
            switch ($control) {
                "mfa" { $output += "- Multi-Factor Authentication`n" }
                "compliantDevice" { $output += "- Require device to be marked as compliant`n" }
                "domainJoinedDevice" { $output += "- Require Hybrid Azure AD joined device`n" }
                "approvedApplication" { $output += "- Require approved client app`n" }
                "compliantApplication" { $output += "- Require app protection policy`n" }
                "passwordChange" { $output += "- Require password change`n" }
                default { $output += "- $control`n" }
            }
        }
    }
    
    if ($Controls.customAuthenticationFactors) {
        $output += "`n**Custom Authentication Factors:**`n"
        foreach ($factor in $Controls.customAuthenticationFactors) {
            $output += "- $factor`n"
        }
    }
    
    if ($Controls.termsOfUse) {
        $output += "`n**Terms of Use:**`n"
        foreach ($terms in $Controls.termsOfUse) {
            $output += "- $terms`n"
        }
    }
    
    return $output
}

# Helper function to format session controls
function Format-SessionControls {
    param([object]$Controls)
    
    if (-not $Controls) { return "None" }
    
    $output = ""
    
    if ($Controls.signInFrequency) {
        $output += "**Sign-in Frequency:** "
        $output += "$($Controls.signInFrequency.value) $($Controls.signInFrequency.type)"
        if ($Controls.signInFrequency.isEnabled) {
            $output += " (Enabled)"
        }
        $output += "`n"
    }
    
    if ($Controls.persistentBrowser) {
        $output += "**Persistent Browser:** "
        $output += "$($Controls.persistentBrowser.mode)"
        if ($Controls.persistentBrowser.isEnabled) {
            $output += " (Enabled)"
        }
        $output += "`n"
    }
    
    if ($Controls.applicationEnforcedRestrictions) {
        if ($Controls.applicationEnforcedRestrictions.isEnabled) {
            $output += "**Application Enforced Restrictions:** Enabled`n"
        }
    }
    
    if ($Controls.cloudAppSecurity) {
        if ($Controls.cloudAppSecurity.isEnabled) {
            $output += "**Cloud App Security:** $($Controls.cloudAppSecurity.cloudAppSecurityType)`n"
        }
    }
    
    if ($output -eq "") {
        return "None"
    }
    
    return $output
}

# Main execution
try {
    Write-Host "`n=== Generating IAC Entra Policy Documentation ===" -ForegroundColor Cyan
    Write-Host "Import Path: $ImportPath" -ForegroundColor Gray
    Write-Host "Output Path: $OutputPath`n" -ForegroundColor Gray
    
    # Verify import path exists
    if (-not (Test-Path $ImportPath)) {
        Write-Host "❌ Import path does not exist: $ImportPath" -ForegroundColor Red
        exit 1
    }
    
    # Initialize markdown content
    $markdown = @"
# IAC Entra ID Policy Documentation

**Generated:** $(Get-Date -Format "MMMM dd, yyyy HH:mm:ss")
**Source:** $ImportPath

---

## Table of Contents

- [Overview](#overview)
- [Conditional Access Policies](#conditional-access-policies)
- [Named Locations](#named-locations)

---

## Overview

This document provides comprehensive documentation for all IAC (Infrastructure as Code) Conditional Access policies and Named Locations in the tenant. Each policy includes:

- **Purpose**: What the policy does and why it exists
- **State**: Whether the policy is enabled, disabled, or in report-only mode
- **Assignments**: Which users, groups, and roles the policy applies to
- **Conditions**: The circumstances under which the policy is evaluated
- **Controls**: The security requirements enforced by the policy

---

## Conditional Access Policies

"@
    
    # Process Conditional Access Policies
    $caFolder = Join-Path $ImportPath "ConditionalAccess"
    if (Test-Path $caFolder) {
        $caFiles = Get-ChildItem -Path $caFolder -Filter "*.json" | Sort-Object Name
        Write-Host "Processing $($caFiles.Count) Conditional Access policies..." -ForegroundColor Yellow
        
        $policyCount = 0
        foreach ($file in $caFiles) {
            $policyCount++
            Write-Host "  [$policyCount/$($caFiles.Count)] Processing: $($file.BaseName)" -ForegroundColor White
            
            $policyData = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $config = $policyData.PolicyConfig
            $assignments = $policyData.AssignmentDetails
            
            # Get policy description
            $description = Get-PolicyDescription -Name $config.displayName -Config $config
            
            # Build policy section
            $markdown += @"

### $($config.displayName)

**Purpose:** $description

**State:** ``$($config.state)``

**Policy ID:** ``$($policyData.SourcePolicyId)``

#### Assignments

$(Format-Assignments -Details $assignments)

#### Conditions

##### Applications
$(Format-Applications -Apps $config.conditions.applications)

##### Platforms
$(Format-Platforms -Platforms $config.conditions.platforms)

##### Locations
$(Format-Locations -Locations $config.conditions.locations)

##### Client App Types
$(if ($config.conditions.clientAppTypes) { "- " + ($config.conditions.clientAppTypes -join "`n- ") } else { "Not configured" })

##### Device States
$(if ($config.conditions.devices) { 
    $deviceOutput = ""
    if ($config.conditions.devices.includeDevices) {
        $deviceOutput += "**Include:** " + ($config.conditions.devices.includeDevices -join ", ") + "`n"
    }
    if ($config.conditions.devices.excludeDevices) {
        $deviceOutput += "**Exclude:** " + ($config.conditions.devices.excludeDevices -join ", ")
    }
    if ($deviceOutput) { $deviceOutput } else { "Not configured" }
} else { "Not configured" })

#### Grant Controls

$(Format-GrantControls -Controls $config.grantControls)

#### Session Controls

$(Format-SessionControls -Controls $config.sessionControls)

#### Configuration JSON

``````json
$(($config | ConvertTo-Json -Depth 10))
``````

---

"@
        }
    }
    
    # Process Named Locations
    $markdown += @"

## Named Locations

Named Locations are used in Conditional Access policies to define trusted network locations, IP ranges, or geographic regions.

"@
    
    $locFolder = Join-Path $ImportPath "NamedLocations"
    if (Test-Path $locFolder) {
        $locFiles = Get-ChildItem -Path $locFolder -Filter "*.json" | Sort-Object Name
        Write-Host "`nProcessing $($locFiles.Count) Named Locations..." -ForegroundColor Yellow
        
        $locCount = 0
        foreach ($file in $locFiles) {
            $locCount++
            Write-Host "  [$locCount/$($locFiles.Count)] Processing: $($file.BaseName)" -ForegroundColor White
            
            $locationData = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $config = $locationData.LocationConfig
            
            $markdown += @"

### $($config.displayName)

**Type:** $($locationData.LocationType)

**Trusted Location:** $(if ($config.isTrusted) { "Yes ✅" } else { "No ❌" })

**Location ID:** ``$($locationData.SourceLocationId)``

"@
            
            # IP Location details
            if ($locationData.LocationType -eq "IP Location" -and $config.ipRanges) {
                $markdown += @"

#### IP Ranges

"@
                foreach ($ipRange in $config.ipRanges) {
                    $markdown += "- ``$($ipRange.cidrAddress)``"
                    if ($ipRange.'@odata.type' -eq '#microsoft.graph.iPv6CidrRange') {
                        $markdown += " (IPv6)"
                    } else {
                        $markdown += " (IPv4)"
                    }
                    $markdown += "`n"
                }
            }
            
            # Country Location details
            if ($locationData.LocationType -eq "Country Location" -and $config.countriesAndRegions) {
                $markdown += @"

#### Countries and Regions

- $($config.countriesAndRegions -join "`n- ")

**Include Unknown Areas:** $(if ($config.includeUnknownCountriesAndRegions) { "Yes" } else { "No" })

"@
            }
            
            # Configuration JSON
            $markdown += @"

#### Configuration JSON

``````json
$(($config | ConvertTo-Json -Depth 10))
``````

---

"@
        }
    }
    
    # Add footer
    $markdown += @"

---

## Summary

This documentation was automatically generated from exported IAC policy JSON files.

**Total Conditional Access Policies:** $($caFiles.Count)
**Total Named Locations:** $($locFiles.Count)

For questions or updates to these policies, please refer to the change management process.

"@
    
    # Save markdown file
    $markdown | Out-File -FilePath $OutputPath -Encoding utf8
    
    Write-Host "`n✅ Documentation generated successfully!" -ForegroundColor Green
    Write-Host "   Output: $OutputPath" -ForegroundColor Gray
    Write-Host "   CA Policies: $($caFiles.Count)" -ForegroundColor Gray
    Write-Host "   Named Locations: $($locFiles.Count)`n" -ForegroundColor Gray
    
} catch {
    Write-Host "`n❌ Documentation generation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
