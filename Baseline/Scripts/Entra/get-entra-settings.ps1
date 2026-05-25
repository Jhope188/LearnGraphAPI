# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Policy.Read.All", "Directory.Read.All", "DeviceManagementConfiguration.Read.All" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   ENTRA ID TENANT SETTINGS DOCUMENTATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Get Tenant Information
Write-Host "📊 TENANT INFORMATION" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray
$org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization"
$orgData = $org.value[0]
Write-Host "Tenant Name:          $($orgData.displayName)" -ForegroundColor White
Write-Host "Tenant ID:            $($orgData.id)" -ForegroundColor White
Write-Host "Primary Domain:       $($orgData.verifiedDomains | Where-Object {$_.isDefault -eq $true} | Select-Object -ExpandProperty name)" -ForegroundColor White

# Device Registration Policy (LAPS)
Write-Host "`n`n🔐 DEVICE REGISTRATION POLICY (LAPS Settings)" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray
$deviceRegPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy"
Write-Host "Local Admin Password (LAPS):" -ForegroundColor White
Write-Host "  Enabled: $($deviceRegPolicy.localAdminPassword.isEnabled)" -ForegroundColor Cyan
Write-Host "`nAzure AD Join Settings:" -ForegroundColor White
Write-Host "  Allowed to join: $($deviceRegPolicy.azureADJoin.allowedToJoin)" -ForegroundColor Cyan
Write-Host "  Is admin configurable: $($deviceRegPolicy.azureADJoin.isAdminConfigurable)" -ForegroundColor Cyan
Write-Host "`nAzure AD Registration Settings:" -ForegroundColor White
Write-Host "  Allowed to register: $($deviceRegPolicy.azureADRegistration.allowedToRegister)" -ForegroundColor Cyan
Write-Host "  Is admin configurable: $($deviceRegPolicy.azureADRegistration.isAdminConfigurable)" -ForegroundColor Cyan

# Authorization Policy
Write-Host "`n`n👤 AUTHORIZATION POLICY" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray
$authPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy"
Write-Host "Guest User Role:      $($authPolicy.guestUserRoleId)" -ForegroundColor White
Write-Host "Allow Invites From:   $($authPolicy.allowInvitesFrom)" -ForegroundColor White
Write-Host "Block MSOL PowerShell: $($authPolicy.blockMsolPowerShell)" -ForegroundColor White
Write-Host "`nUser Default Permissions:" -ForegroundColor White
Write-Host "  Can create apps:                    $($authPolicy.defaultUserRolePermissions.allowedToCreateApps)" -ForegroundColor Cyan
Write-Host "  Can create security groups:         $($authPolicy.defaultUserRolePermissions.allowedToCreateSecurityGroups)" -ForegroundColor Cyan
Write-Host "  Can create tenants:                 $($authPolicy.defaultUserRolePermissions.allowedToCreateTenants)" -ForegroundColor Cyan
Write-Host "  Can read other users:               $($authPolicy.defaultUserRolePermissions.allowedToReadOtherUsers)" -ForegroundColor Cyan
Write-Host "  Can read BitLocker keys for device: $($authPolicy.defaultUserRolePermissions.allowedToReadBitlockerKeysForOwnedDevice)" -ForegroundColor Cyan

# Identity Security Defaults
Write-Host "`n`n🛡️ IDENTITY SECURITY DEFAULTS" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray
try {
    $secDefaults = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy"
    Write-Host "Security Defaults Enabled: $($secDefaults.isEnabled)" -ForegroundColor White
} catch {
    Write-Host "Could not retrieve security defaults: $($_.Exception.Message)" -ForegroundColor Red
}

# Conditional Access Policies
Write-Host "`n`n🔒 CONDITIONAL ACCESS POLICIES" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray
$caPolicies = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
if ($caPolicies.value.Count -eq 0) {
    Write-Host "No Conditional Access policies found." -ForegroundColor Gray
} else {
    $caPolicies.value | Select-Object displayName, state, createdDateTime | Format-Table -AutoSize
}

# Authentication Methods Policy
Write-Host "`n📱 AUTHENTICATION METHODS POLICY" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray
try {
    $authMethodsPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy"
    Write-Host "Registration Enforcement:" -ForegroundColor White
    Write-Host "  Auth Method Registration Campaign Enabled: $($authMethodsPolicy.registrationEnforcement.authenticationMethodsRegistrationCampaignEnabled)" -ForegroundColor Cyan
    
    Write-Host "`nEnabled Authentication Methods:" -ForegroundColor White
    $authMethodsPolicy.authenticationMethodConfigurations | Where-Object {$_.state -eq 'enabled'} | ForEach-Object {
        Write-Host "  - $($_.id): $($_.state)" -ForegroundColor Cyan
    }
} catch {
    Write-Host "Could not retrieve authentication methods policy: $($_.Exception.Message)" -ForegroundColor Red
}

# Password Policies
Write-Host "`n`n🔑 PASSWORD POLICIES" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray
$domains = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/domains"
$defaultDomain = $domains.value | Where-Object {$_.isDefault -eq $true}
Write-Host "Password Validity Period: $($defaultDomain.passwordValidityPeriodInDays) days" -ForegroundColor White
Write-Host "Password Notification Window: $($defaultDomain.passwordNotificationWindowInDays) days" -ForegroundColor White

# Company Branding
Write-Host "`n`n🎨 COMPANY BRANDING" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray
try {
    $branding = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization/$($orgData.id)/branding"
    if ($branding.backgroundColor) {
        Write-Host "Background Color:     $($branding.backgroundColor)" -ForegroundColor White
        Write-Host "Sign In Page Text:    $($branding.signInPageText)" -ForegroundColor White
    } else {
        Write-Host "No custom branding configured." -ForegroundColor Gray
    }
} catch {
    Write-Host "No custom branding configured." -ForegroundColor Gray
}

Write-Host "`n`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ Documentation complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
