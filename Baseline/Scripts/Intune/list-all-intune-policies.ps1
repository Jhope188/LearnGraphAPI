# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All", "DeviceManagementApps.Read.All" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   LIST ALL INTUNE POLICIES" -ForegroundColor Cyan
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

# 1. Device Configuration Policies (with pagination)
Write-Host "🔍 Retrieving Device Configuration Policies..." -ForegroundColor Yellow
try {
    $deviceConfigs = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $deviceConfigs += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    Write-Host "   Found: $($deviceConfigs.Count) policies" -ForegroundColor White
    foreach ($policy in $deviceConfigs) {
        $allPolicies += [PSCustomObject]@{
            Type = "Device Configuration"
            Name = $policy.displayName
            ID = $policy.id
            ODataType = $policy.'@odata.type'
            Configuration = $policy
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2. Settings Catalog Policies (with pagination)
Write-Host "🔍 Retrieving Settings Catalog Policies..." -ForegroundColor Yellow
try {
    $settingsCatalog = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $settingsCatalog += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    Write-Host "   Found: $($settingsCatalog.Count) policies" -ForegroundColor White
    foreach ($policy in $settingsCatalog) {
        Write-Host "      Retrieving settings for: $($policy.name)" -ForegroundColor Gray
        $settings = Get-SettingsCatalogConfig -policyId $policy.id
        $allPolicies += [PSCustomObject]@{
            Type = "Settings Catalog"
            Name = $policy.name
            ID = $policy.id
            ODataType = "Settings Catalog"
            Configuration = $policy
            Settings = $settings
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 3. Compliance Policies
Write-Host "🔍 Retrieving Compliance Policies..." -ForegroundColor Yellow
try {
    $compliancePolicies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies").value
    Write-Host "   Found: $($compliancePolicies.Count) policies" -ForegroundColor White
    foreach ($policy in $compliancePolicies) {
        $allPolicies += [PSCustomObject]@{
            Type = "Compliance Policy"
            Name = $policy.displayName
            ID = $policy.id
            ODataType = $policy.'@odata.type'
            Configuration = $policy
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 4. App Configuration Policies (with pagination)
Write-Host "🔍 Retrieving App Configuration Policies..." -ForegroundColor Yellow
try {
    $appConfigs = @()
    $uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $appConfigs += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    Write-Host "   Found: $($appConfigs.Count) policies" -ForegroundColor White
    foreach ($policy in $appConfigs) {
        $allPolicies += [PSCustomObject]@{
            Type = "App Configuration"
            Name = $policy.displayName
            ID = $policy.id
            ODataType = $policy.'@odata.type'
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 5. App Protection Policies (Android)
Write-Host "🔍 Retrieving App Protection Policies (Android)..." -ForegroundColor Yellow
try {
    $androidAppProtection = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections").value
    Write-Host "   Found: $($androidAppProtection.Count) policies" -ForegroundColor White
    foreach ($policy in $androidAppProtection) {
        $allPolicies += [PSCustomObject]@{
            Type = "App Protection (Android)"
            Name = $policy.displayName
            ID = $policy.id
            ODataType = "Android MAM"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 6. App Protection Policies (iOS)
Write-Host "🔍 Retrieving App Protection Policies (iOS)..." -ForegroundColor Yellow
try {
    $iosAppProtection = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections").value
    Write-Host "   Found: $($iosAppProtection.Count) policies" -ForegroundColor White
    foreach ($policy in $iosAppProtection) {
        $allPolicies += [PSCustomObject]@{
            Type = "App Protection (iOS)"
            Name = $policy.displayName
            ID = $policy.id
            ODataType = "iOS MAM"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 7. App Protection Policies (Windows)
Write-Host "🔍 Retrieving App Protection Policies (Windows)..." -ForegroundColor Yellow
try {
    $windowsAppProtection = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections").value
    Write-Host "   Found: $($windowsAppProtection.Count) policies" -ForegroundColor White
    foreach ($policy in $windowsAppProtection) {
        $allPolicies += [PSCustomObject]@{
            Type = "App Protection (Windows)"
            Name = $policy.displayName
            ID = $policy.id
            ODataType = "Windows MAM"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 8. Endpoint Security - Intents (Antivirus, Firewall, etc.)
Write-Host "🔍 Retrieving Endpoint Security Policies..." -ForegroundColor Yellow
try {
    $intents = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/intents").value
    Write-Host "   Found: $($intents.Count) policies" -ForegroundColor White
    foreach ($policy in $intents) {
        Write-Host "      Retrieving settings for: $($policy.displayName)" -ForegroundColor Gray
        $intentSettings = Get-IntentSettings -intentId $policy.id
        $allPolicies += [PSCustomObject]@{
            Type = "Endpoint Security"
            Name = $policy.displayName
            ID = $policy.id
            ODataType = $policy.templateId
            Configuration = $policy
            Settings = $intentSettings
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 9. PowerShell Scripts (with pagination)
Write-Host "🔍 Retrieving PowerShell Scripts..." -ForegroundColor Yellow
try {
    $psScripts = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $psScripts += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    Write-Host "   Found: $($scripts.Count) scripts" -ForegroundColor White
    foreach ($script in $scripts) {
        $allPolicies += [PSCustomObject]@{
            Type = "PowerShell Script"
            Name = $script.displayName
            ID = $script.id
            ODataType = "Script"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 10. Health Scripts (Proactive Remediation)
Write-Host "🔍 Retrieving Health Scripts (Proactive Remediation)..." -ForegroundColor Yellow
try {
    $healthScripts = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts").value
    Write-Host "   Found: $($healthScripts.Count) scripts" -ForegroundColor White
    foreach ($script in $healthScripts) {
        $allPolicies += [PSCustomObject]@{
            Type = "Health Script"
            Name = $script.displayName
            ID = $script.id
            ODataType = "Remediation"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 11. Windows Update Rings
Write-Host "🔍 Retrieving Windows Update Rings..." -ForegroundColor Yellow
try {
    $updateRings = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')").value
    Write-Host "   Found: $($updateRings.Count) policies" -ForegroundColor White
    foreach ($policy in $updateRings) {
        $allPolicies += [PSCustomObject]@{
            Type = "Windows Update Ring"
            Name = $policy.displayName
            ID = $policy.id
            ODataType = "Update Ring"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 12. Administrative Templates
Write-Host "🔍 Retrieving Administrative Templates..." -ForegroundColor Yellow
try {
    $adminTemplates = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations").value
    Write-Host "   Found: $($adminTemplates.Count) templates" -ForegroundColor White
    foreach ($template in $adminTemplates) {
        Write-Host "      Retrieving settings for: $($template.displayName)" -ForegroundColor Gray
        $gpSettings = Get-GroupPolicyValues -configId $template.id
        $allPolicies += [PSCustomObject]@{
            Type = "Administrative Template"
            Name = $template.displayName
            ID = $template.id
            ODataType = "Group Policy"
            Configuration = $template
            Settings = $gpSettings
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 13. Enrollment Restrictions
Write-Host "🔍 Retrieving Enrollment Restrictions..." -ForegroundColor Yellow
try {
    $enrollmentRestrictions = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations").value
    Write-Host "   Found: $($enrollmentRestrictions.Count) configurations" -ForegroundColor White
    foreach ($config in $enrollmentRestrictions) {
        $allPolicies += [PSCustomObject]@{
            Type = "Enrollment Configuration"
            Name = $config.displayName
            ID = $config.id
            ODataType = $config.'@odata.type'
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 14. Autopilot Profiles
Write-Host "🔍 Retrieving Autopilot Profiles..." -ForegroundColor Yellow
try {
    $autopilotProfiles = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles").value
    Write-Host "   Found: $($autopilotProfiles.Count) profiles" -ForegroundColor White
    foreach ($profile in $autopilotProfiles) {
        $allPolicies += [PSCustomObject]@{
            Type = "Autopilot Profile"
            Name = $profile.displayName
            ID = $profile.id
            ODataType = "Autopilot"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 15. Enrollment Status Page
Write-Host "🔍 Retrieving Enrollment Status Page Profiles..." -ForegroundColor Yellow
try {
    $espProfiles = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations?`$filter=isof('microsoft.graph.windows10EnrollmentCompletionPageConfiguration')").value
    Write-Host "   Found: $($espProfiles.Count) profiles" -ForegroundColor White
    foreach ($profile in $espProfiles) {
        $allPolicies += [PSCustomObject]@{
            Type = "Enrollment Status Page"
            Name = $profile.displayName
            ID = $profile.id
            ODataType = "ESP"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 16. macOS Shell Scripts
Write-Host "🔍 Retrieving macOS Shell Scripts..." -ForegroundColor Yellow
try {
    $macScripts = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts").value
    Write-Host "   Found: $($macScripts.Count) scripts" -ForegroundColor White
    foreach ($script in $macScripts) {
        $allPolicies += [PSCustomObject]@{
            Type = "macOS Shell Script"
            Name = $script.displayName
            ID = $script.id
            ODataType = "Shell Script"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 17. Platform Scripts (Custom Attributes)
Write-Host "🔍 Retrieving Platform Scripts (Custom Attributes)..." -ForegroundColor Yellow
try {
    $customAttributes = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts").value
    Write-Host "   Found: $($customAttributes.Count) scripts" -ForegroundColor White
    foreach ($script in $customAttributes) {
        $allPolicies += [PSCustomObject]@{
            Type = "Custom Attribute Script"
            Name = $script.displayName
            ID = $script.id
            ODataType = "Custom Attribute"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 18. Security Baselines
Write-Host "🔍 Retrieving Security Baselines..." -ForegroundColor Yellow
try {
    $securityBaselines = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/templates").value
    Write-Host "   Found: $($securityBaselines.Count) templates" -ForegroundColor White
    foreach ($baseline in $securityBaselines) {
        $allPolicies += [PSCustomObject]@{
            Type = "Security Baseline Template"
            Name = $baseline.displayName
            ID = $baseline.id
            ODataType = $baseline.templateType
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 19. Feature Update Profiles
Write-Host "🔍 Retrieving Feature Update Profiles..." -ForegroundColor Yellow
try {
    $featureUpdates = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles").value
    Write-Host "   Found: $($featureUpdates.Count) profiles" -ForegroundColor White
    foreach ($update in $featureUpdates) {
        $allPolicies += [PSCustomObject]@{
            Type = "Feature Update Profile"
            Name = $update.displayName
            ID = $update.id
            ODataType = "Feature Update"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 20. Quality Update Profiles
Write-Host "🔍 Retrieving Quality Update Profiles..." -ForegroundColor Yellow
try {
    $qualityUpdates = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles").value
    Write-Host "   Found: $($qualityUpdates.Count) profiles" -ForegroundColor White
    foreach ($update in $qualityUpdates) {
        $allPolicies += [PSCustomObject]@{
            Type = "Quality Update Profile"
            Name = $update.displayName
            ID = $update.id
            ODataType = "Quality Update"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 21. Driver Update Profiles
Write-Host "🔍 Retrieving Driver Update Profiles..." -ForegroundColor Yellow
try {
    $driverUpdates = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles").value
    Write-Host "   Found: $($driverUpdates.Count) profiles" -ForegroundColor White
    foreach ($update in $driverUpdates) {
        $allPolicies += [PSCustomObject]@{
            Type = "Driver Update Profile"
            Name = $update.displayName
            ID = $update.id
            ODataType = "Driver Update"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 22. iOS Update Policies
Write-Host "🔍 Retrieving iOS Update Policies..." -ForegroundColor Yellow
try {
    $iosUpdates = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/iosUpdateStatuses").value
    Write-Host "   Found: $($iosUpdates.Count) policies" -ForegroundColor White
    foreach ($update in $iosUpdates) {
        $allPolicies += [PSCustomObject]@{
            Type = "iOS Update Policy"
            Name = $update.displayName
            ID = $update.id
            ODataType = "iOS Update"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 23. Notification Message Templates
Write-Host "🔍 Retrieving Notification Message Templates..." -ForegroundColor Yellow
try {
    $notifications = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/notificationMessageTemplates").value
    Write-Host "   Found: $($notifications.Count) templates" -ForegroundColor White
    foreach ($template in $notifications) {
        $allPolicies += [PSCustomObject]@{
            Type = "Notification Template"
            Name = $template.displayName
            ID = $template.id
            ODataType = "Notification"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 24. Terms and Conditions
Write-Host "🔍 Retrieving Terms and Conditions..." -ForegroundColor Yellow
try {
    $terms = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/termsAndConditions").value
    Write-Host "   Found: $($terms.Count) policies" -ForegroundColor White
    foreach ($term in $terms) {
        $allPolicies += [PSCustomObject]@{
            Type = "Terms and Conditions"
            Name = $term.displayName
            ID = $term.id
            ODataType = "T&C"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 25. Mobile Threat Defense Connectors
Write-Host "🔍 Retrieving Mobile Threat Defense Connectors..." -ForegroundColor Yellow
try {
    $mtdConnectors = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/mobileThreatDefenseConnectors").value
    Write-Host "   Found: $($mtdConnectors.Count) connectors" -ForegroundColor White
    foreach ($connector in $mtdConnectors) {
        $allPolicies += [PSCustomObject]@{
            Type = "MTD Connector"
            Name = $connector.displayName
            ID = $connector.id
            ODataType = "MTD"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 26. Derived Credentials
Write-Host "🔍 Retrieving Derived Credentials..." -ForegroundColor Yellow
try {
    $derivedCreds = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/derivedCredentials").value
    Write-Host "   Found: $($derivedCreds.Count) configurations" -ForegroundColor White
    foreach ($cred in $derivedCreds) {
        $allPolicies += [PSCustomObject]@{
            Type = "Derived Credential"
            Name = $cred.displayName
            ID = $cred.id
            ODataType = "Derived Cred"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 27. Android for Work Settings
Write-Host "🔍 Retrieving Android for Work Settings..." -ForegroundColor Yellow
try {
    $androidSettings = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/androidManagedStoreAccountEnterpriseSettings").value
    if ($androidSettings) {
        $allPolicies += [PSCustomObject]@{
            Type = "Android Enterprise Settings"
            Name = "Android Enterprise Binding"
            ID = "N/A"
            ODataType = "Android Enterprise"
        }
        Write-Host "   Found: 1 configuration" -ForegroundColor White
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 28. Apple Push Notification Certificate
Write-Host "🔍 Retrieving Apple Push Notification Certificate..." -ForegroundColor Yellow
try {
    $applePush = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/applePushNotificationCertificate").value
    if ($applePush) {
        $allPolicies += [PSCustomObject]@{
            Type = "Apple Push Certificate"
            Name = "Apple MDM Push Certificate"
            ID = "N/A"
            ODataType = "APNS"
        }
        Write-Host "   Found: 1 certificate" -ForegroundColor White
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 29. Device Categories
Write-Host "🔍 Retrieving Device Categories..." -ForegroundColor Yellow
try {
    $categories = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCategories").value
    Write-Host "   Found: $($categories.Count) categories" -ForegroundColor White
    foreach ($category in $categories) {
        $allPolicies += [PSCustomObject]@{
            Type = "Device Category"
            Name = $category.displayName
            ID = $category.id
            ODataType = "Category"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 30. Role Definitions
Write-Host "🔍 Retrieving Role Definitions..." -ForegroundColor Yellow
try {
    $roles = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/roleDefinitions").value
    Write-Host "   Found: $($roles.Count) roles" -ForegroundColor White
    foreach ($role in $roles) {
        $allPolicies += [PSCustomObject]@{
            Type = "Role Definition"
            Name = $role.displayName
            ID = $role.id
            ODataType = "Role"
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Display Summary
Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "📊 Total Policies Found: $($allPolicies.Count)`n" -ForegroundColor Green

$groupedPolicies = $allPolicies | Group-Object -Property Type
foreach ($group in $groupedPolicies | Sort-Object Name) {
    Write-Host "   $($group.Name): " -ForegroundColor White -NoNewline
    Write-Host "$($group.Count)" -ForegroundColor Yellow
}

# Generate Markdown Documentation
Write-Host "`n📝 Generating Markdown documentation...`n" -ForegroundColor Cyan

$markdown = @"
# Intune Policies Documentation

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Total Policies:** $($allPolicies.Count)

---

## Table of Contents

"@

# Add TOC
foreach ($group in ($groupedPolicies | Sort-Object Name)) {
    $anchor = $group.Name -replace ' ', '-' -replace '\(', '' -replace '\)', ''
    $markdown += "- [$($group.Name)](#$($anchor.ToLower())) ($($group.Count))`n"
}

$markdown += "`n---`n`n"

# Add each section
foreach ($group in ($groupedPolicies | Sort-Object Name)) {
    $markdown += "## $($group.Name)`n`n"
    $markdown += "**Count:** $($group.Count)`n`n"
    
    $policies = $group.Group | Sort-Object Name
    
    foreach ($policy in $policies) {
        $markdown += "### $($policy.Name)`n`n"
        $markdown += "- **Policy ID:** ``$($policy.ID)```n"
        $markdown += "- **Type:** $($policy.ODataType)`n`n"
        
        # Add full configuration details
        if ($policy.Configuration) {
            $markdown += "#### Configuration Details`n`n"
            $markdown += "``````json`n"
            $markdown += ($policy.Configuration | ConvertTo-Json -Depth 10)
            $markdown += "`n``````n`n"
        }
        
        # Add Settings Catalog specific settings
        if ($policy.Settings) {
            $markdown += "#### Settings Catalog Configuration`n`n"
            $markdown += "``````json`n"
            $markdown += ($policy.Settings | ConvertTo-Json -Depth 10)
            $markdown += "`n``````n`n"
        }
        
        $markdown += "---`n`n"
    }
}

$markdown += "*End of Intune Policies Documentation*`n"

# Save to file
$outputPath = "/Users/jon/Desktop/BaslineSetup/Intune-Policies.md"
$markdown | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ Documentation exported to: $outputPath" -ForegroundColor Green
Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
