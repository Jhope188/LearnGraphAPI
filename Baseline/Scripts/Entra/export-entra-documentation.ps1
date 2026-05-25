# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Policy.Read.All", "Directory.Read.All", "DeviceManagementConfiguration.Read.All" -NoWelcome

Write-Host "`n📝 Exporting Entra ID Configuration to Markdown...`n" -ForegroundColor Cyan

# Get Tenant Information
$org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization"
$orgData = $org.value[0]

# Initialize markdown content
$markdown = @"
# Entra ID Configuration Documentation

**Tenant:** $($orgData.displayName)  
**Tenant ID:** $($orgData.id)  
**Primary Domain:** $($orgData.verifiedDomains | Where-Object {`$_.isDefault -eq `$true} | Select-Object -ExpandProperty name)  
**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

---

## Table of Contents

1. [Device Registration Policy](#device-registration-policy)
2. [Authorization Policy](#authorization-policy)
3. [Identity Security Defaults](#identity-security-defaults)
4. [Conditional Access Policies](#conditional-access-policies)
5. [Named Locations](#named-locations)
6. [Authentication Methods](#authentication-methods)
7. [Password Policies](#password-policies)

---

## Device Registration Policy

### LAPS Settings

"@

# Device Registration Policy
Write-Host "📋 Retrieving Device Registration Policy..." -ForegroundColor Yellow
$deviceRegPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy"

$markdown += @"
- **Local Admin Password (LAPS) Enabled:** $($deviceRegPolicy.localAdminPassword.isEnabled)

### Azure AD Join

- **Allowed to Join:** $($deviceRegPolicy.azureADJoin.allowedToJoin)
- **Admin Configurable:** $($deviceRegPolicy.azureADJoin.isAdminConfigurable)

### Azure AD Registration

- **Allowed to Register:** $($deviceRegPolicy.azureADRegistration.allowedToRegister)
- **Admin Configurable:** $($deviceRegPolicy.azureADRegistration.isAdminConfigurable)

---

## Authorization Policy

"@

# Authorization Policy
Write-Host "📋 Retrieving Authorization Policy..." -ForegroundColor Yellow
$authPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy"

$markdown += @"
- **Guest User Role ID:** $($authPolicy.guestUserRoleId)
- **Allow Invites From:** $($authPolicy.allowInvitesFrom)
- **Block MSOL PowerShell:** $($authPolicy.blockMsolPowerShell)

### Default User Role Permissions

- **Can Create Apps:** $($authPolicy.defaultUserRolePermissions.allowedToCreateApps)
- **Can Create Security Groups:** $($authPolicy.defaultUserRolePermissions.allowedToCreateSecurityGroups)
- **Can Create Tenants:** $($authPolicy.defaultUserRolePermissions.allowedToCreateTenants)
- **Can Read Other Users:** $($authPolicy.defaultUserRolePermissions.allowedToReadOtherUsers)
- **Can Read BitLocker Keys for Owned Device:** $($authPolicy.defaultUserRolePermissions.allowedToReadBitlockerKeysForOwnedDevice)

---

## Identity Security Defaults

"@

# Security Defaults
Write-Host "📋 Retrieving Security Defaults..." -ForegroundColor Yellow
try {
    $secDefaults = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy"
    $markdown += "- **Security Defaults Enabled:** $($secDefaults.isEnabled)`n`n"
} catch {
    $markdown += "- **Security Defaults:** Unable to retrieve`n`n"
}

$markdown += "---`n`n## Conditional Access Policies`n`n"

# Conditional Access Policies
Write-Host "📋 Retrieving Conditional Access Policies..." -ForegroundColor Yellow
$caPolicies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies").value

# Filter out policies starting with CIS or ACME
$caPolicies = $caPolicies | Where-Object { $_.displayName -notlike "CIS*" -and $_.displayName -notlike "ACME*" }

# Remove duplicates based on displayName and rename NCT to IAC
$uniquePolicies = @{}
foreach ($policy in $caPolicies) {
    $displayName = $policy.displayName -replace "^NCT", "IAC"
    if (-not $uniquePolicies.ContainsKey($displayName)) {
        $uniquePolicies[$displayName] = $policy
    }
}

if ($uniquePolicies.Count -eq 0) {
    $markdown += "No Conditional Access policies configured.`n`n"
} else {
    $markdown += "**Total Policies:** $($uniquePolicies.Count)`n`n"
    
    foreach ($displayName in ($uniquePolicies.Keys | Sort-Object)) {
        $policy = $uniquePolicies[$displayName]
        
        $markdown += "### $displayName`n`n"
        $markdown += "- **Policy ID:** $($policy.id)`n"
        $markdown += "- **State:** $($policy.state)`n"
        $markdown += "- **Created:** $($policy.createdDateTime)`n"
        $markdown += "- **Modified:** $($policy.modifiedDateTime)`n`n"
        
        # Conditions
        $markdown += "#### Conditions`n`n"
        
        # Users
        if ($policy.conditions.users) {
            $markdown += "**Users/Groups:**`n`n"
            
            if ($policy.conditions.users.includeUsers) {
                $includeUsers = $policy.conditions.users.includeUsers -join ", "
                $markdown += "- Include Users: ``$includeUsers```n"
            }
            if ($policy.conditions.users.excludeUsers) {
                $excludeUsers = $policy.conditions.users.excludeUsers -join ", "
                $markdown += "- Exclude Users: ``$excludeUsers```n"
            }
            if ($policy.conditions.users.includeGroups) {
                $includeGroups = $policy.conditions.users.includeGroups -join ", "
                $markdown += "- Include Groups: ``$includeGroups```n"
            }
            if ($policy.conditions.users.excludeGroups) {
                $excludeGroups = $policy.conditions.users.excludeGroups -join ", "
                $markdown += "- Exclude Groups: ``$excludeGroups```n"
            }
            if ($policy.conditions.users.includeRoles) {
                $includeRoles = $policy.conditions.users.includeRoles -join ", "
                $markdown += "- Include Roles: ``$includeRoles```n"
            }
            if ($policy.conditions.users.excludeRoles) {
                $excludeRoles = $policy.conditions.users.excludeRoles -join ", "
                $markdown += "- Exclude Roles: ``$excludeRoles```n"
            }
            $markdown += "`n"
        }
        
        # Applications
        if ($policy.conditions.applications) {
            $markdown += "**Applications:**`n`n"
            
            if ($policy.conditions.applications.includeApplications) {
                $includeApps = $policy.conditions.applications.includeApplications -join ", "
                $markdown += "- Include: ``$includeApps```n"
            }
            if ($policy.conditions.applications.excludeApplications) {
                $excludeApps = $policy.conditions.applications.excludeApplications -join ", "
                $markdown += "- Exclude: ``$excludeApps```n"
            }
            $markdown += "`n"
        }
        
        # Platforms
        if ($policy.conditions.platforms) {
            $markdown += "**Platforms:**`n`n"
            
            if ($policy.conditions.platforms.includePlatforms) {
                $includePlatforms = $policy.conditions.platforms.includePlatforms -join ", "
                $markdown += "- Include: ``$includePlatforms```n"
            }
            if ($policy.conditions.platforms.excludePlatforms) {
                $excludePlatforms = $policy.conditions.platforms.excludePlatforms -join ", "
                $markdown += "- Exclude: ``$excludePlatforms```n"
            }
            $markdown += "`n"
        }
        
        # Locations
        if ($policy.conditions.locations) {
            $markdown += "**Locations:**`n`n"
            
            if ($policy.conditions.locations.includeLocations) {
                $includeLocations = $policy.conditions.locations.includeLocations -join ", "
                $markdown += "- Include: ``$includeLocations```n"
            }
            if ($policy.conditions.locations.excludeLocations) {
                $excludeLocations = $policy.conditions.locations.excludeLocations -join ", "
                $markdown += "- Exclude: ``$excludeLocations```n"
            }
            $markdown += "`n"
        }
        
        # Client Apps
        if ($policy.conditions.clientAppTypes) {
            $clientApps = $policy.conditions.clientAppTypes -join ", "
            $markdown += "**Client App Types:** ``$clientApps```n`n"
        }
        
        # Sign-in Risk
        if ($policy.conditions.signInRiskLevels) {
            $riskLevels = $policy.conditions.signInRiskLevels -join ", "
            $markdown += "**Sign-in Risk Levels:** ``$riskLevels```n`n"
        }
        
        # User Risk
        if ($policy.conditions.userRiskLevels) {
            $userRiskLevels = $policy.conditions.userRiskLevels -join ", "
            $markdown += "**User Risk Levels:** ``$userRiskLevels```n`n"
        }
        
        # Grant Controls
        $markdown += "#### Grant Controls`n`n"
        
        if ($policy.grantControls) {
            $markdown += "- **Operator:** $($policy.grantControls.operator)`n"
            
            if ($policy.grantControls.builtInControls) {
                $controls = $policy.grantControls.builtInControls -join ", "
                $markdown += "- **Built-in Controls:** ``$controls```n"
            }
            
            if ($policy.grantControls.customAuthenticationFactors) {
                $customFactors = $policy.grantControls.customAuthenticationFactors -join ", "
                $markdown += "- **Custom Auth Factors:** ``$customFactors```n"
            }
            
            if ($policy.grantControls.termsOfUse) {
                $tou = $policy.grantControls.termsOfUse -join ", "
                $markdown += "- **Terms of Use:** ``$tou```n"
            }
        } else {
            $markdown += "No grant controls configured.`n"
        }
        
        # Session Controls
        $markdown += "`n#### Session Controls`n`n"
        
        if ($policy.sessionControls) {
            if ($policy.sessionControls.applicationEnforcedRestrictions) {
                $markdown += "- **Application Enforced Restrictions:** Enabled ($($policy.sessionControls.applicationEnforcedRestrictions.isEnabled))`n"
            }
            if ($policy.sessionControls.cloudAppSecurity) {
                $markdown += "- **Cloud App Security:** $($policy.sessionControls.cloudAppSecurity.cloudAppSecurityType) (Enabled: $($policy.sessionControls.cloudAppSecurity.isEnabled))`n"
            }
            if ($policy.sessionControls.persistentBrowser) {
                $markdown += "- **Persistent Browser:** $($policy.sessionControls.persistentBrowser.mode) (Enabled: $($policy.sessionControls.persistentBrowser.isEnabled))`n"
            }
            if ($policy.sessionControls.signInFrequency) {
                $markdown += "- **Sign-in Frequency:** $($policy.sessionControls.signInFrequency.value) $($policy.sessionControls.signInFrequency.type) (Enabled: $($policy.sessionControls.signInFrequency.isEnabled))`n"
            }
        } else {
            $markdown += "No session controls configured.`n"
        }
        
        $markdown += "`n---`n`n"
    }
}

# Named Locations
$markdown += "## Named Locations`n`n"

Write-Host "📋 Retrieving Named Locations..." -ForegroundColor Yellow
$namedLocations = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations").value

if ($namedLocations.Count -eq 0) {
    $markdown += "No named locations configured.`n`n"
} else {
    foreach ($location in $namedLocations) {
        $displayName = $location.displayName -replace "^NCT", "IAC"
        
        $markdown += "### $displayName`n`n"
        $markdown += "- **Location ID:** $($location.id)`n"
        $markdown += "- **Type:** $($location.'@odata.type' -replace '#microsoft.graph.', '')`n"
        $markdown += "- **Created:** $($location.createdDateTime)`n"
        $markdown += "- **Modified:** $($location.modifiedDateTime)`n"
        
        if ($location.isTrusted) {
            $markdown += "- **Trusted Location:** $($location.isTrusted)`n"
        }
        
        if ($location.ipRanges) {
            $markdown += "`n**IP Ranges:**`n`n"
            foreach ($ipRange in $location.ipRanges) {
                $markdown += "- ``$($ipRange.cidrAddress)```n"
            }
        }
        
        if ($location.countriesAndRegions) {
            $countries = $location.countriesAndRegions -join ", "
            $markdown += "`n**Countries/Regions:** ``$countries```n"
            $markdown += "- **Include Unknown Countries:** $($location.includeUnknownCountriesAndRegions)`n"
        }
        
        $markdown += "`n---`n`n"
    }
}

# Authentication Methods
$markdown += "## Authentication Methods`n`n"

Write-Host "📋 Retrieving Authentication Methods..." -ForegroundColor Yellow
try {
    $authMethodsPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy"
    
    $markdown += "### Registration Enforcement`n`n"
    $markdown += "- **Registration Campaign Enabled:** $($authMethodsPolicy.registrationEnforcement.authenticationMethodsRegistrationCampaignEnabled)`n`n"
    
    $markdown += "### Enabled Authentication Methods`n`n"
    
    $enabledMethods = $authMethodsPolicy.authenticationMethodConfigurations | Where-Object {$_.state -eq 'enabled'}
    
    if ($enabledMethods) {
        foreach ($method in $enabledMethods) {
            $markdown += "- **$($method.id):** $($method.state)`n"
        }
    } else {
        $markdown += "No authentication methods explicitly enabled.`n"
    }
    
    $markdown += "`n"
} catch {
    $markdown += "Unable to retrieve authentication methods policy.`n`n"
}

# Password Policies
$markdown += "---`n`n## Password Policies`n`n"

Write-Host "📋 Retrieving Password Policies..." -ForegroundColor Yellow
$domains = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/domains"
$defaultDomain = $domains.value | Where-Object {$_.isDefault -eq $true}

if ($defaultDomain) {
    $markdown += "- **Password Validity Period:** $($defaultDomain.passwordValidityPeriodInDays) days`n"
    $markdown += "- **Password Notification Window:** $($defaultDomain.passwordNotificationWindowInDays) days`n"
} else {
    $markdown += "Default domain password policies not available.`n"
}

$markdown += "`n---`n`n"
$markdown += "*End of Entra ID Configuration Documentation*`n"

# Save to file
$outputPath = "/Users/jon/Desktop/BaslineSetup/Entra-Configuration.md"
$markdown | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ Documentation exported successfully!" -ForegroundColor Green
Write-Host "   File: $outputPath`n" -ForegroundColor White
Write-Host "✨ Done!`n" -ForegroundColor Cyan
