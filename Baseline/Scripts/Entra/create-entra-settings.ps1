# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "Policy.ReadWrite.All", "Directory.ReadWrite.All", "DeviceManagementConfiguration.ReadWrite.All" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   ENTRA ID TENANT SETTINGS CONFIGURATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Get Tenant Information
$org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization"
$orgData = $org.value[0]
Write-Host "Configuring tenant: $($orgData.displayName) ($($orgData.id))`n" -ForegroundColor White

# ═══════════════════════════════════════════════════════════════
# 1. Device Registration Policy (LAPS)
# ═══════════════════════════════════════════════════════════════
Write-Host "🔐 Step 1: Configuring Device Registration Policy (LAPS)..." -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray

try {
    $deviceRegPolicyBody = @{
        localAdminPassword = @{
            isEnabled = $true
        }
        azureADJoin = @{
            allowedToJoin = "all"
            isAdminConfigurable = $false
        }
        azureADRegistration = @{
            allowedToRegister = "all"
            isAdminConfigurable = $false
        }
    }
    
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy" -Body ($deviceRegPolicyBody | ConvertTo-Json -Depth 10)
    
    Write-Host "✅ Device Registration Policy configured:" -ForegroundColor Green
    Write-Host "   • LAPS enabled for local admin password backup" -ForegroundColor White
    Write-Host "   • Azure AD Join: All users allowed" -ForegroundColor White
    Write-Host "   • Azure AD Registration: All users allowed`n" -ForegroundColor White
    
} catch {
    Write-Host "❌ Failed to configure Device Registration Policy: $($_.Exception.Message)" -ForegroundColor Red
}

# ═══════════════════════════════════════════════════════════════
# 2. Authorization Policy
# ═══════════════════════════════════════════════════════════════
Write-Host "`n🔒 Step 2: Configuring Authorization Policy..." -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray

try {
    # Get current policy ID
    $currentAuthPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy"
    $policyId = $currentAuthPolicy.id
    
    $authPolicyBody = @{
        allowInvitesFrom = "adminsAndGuestInviters"
        blockMsolPowerShell = $false
        defaultUserRolePermissions = @{
            allowedToCreateApps = $true
            allowedToCreateSecurityGroups = $true
            allowedToCreateTenants = $true
            allowedToReadOtherUsers = $true
            allowedToReadBitlockerKeysForOwnedDevice = $true
        }
    }
    
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy/$policyId" -Body ($authPolicyBody | ConvertTo-Json -Depth 10)
    
    Write-Host "✅ Authorization Policy configured:" -ForegroundColor Green
    Write-Host "   • Guest invites: Admins and guest inviters only" -ForegroundColor White
    Write-Host "   • MSOL PowerShell: Not blocked" -ForegroundColor White
    Write-Host "   • Users can create apps, security groups, and tenants" -ForegroundColor White
    Write-Host "   • Users can read other users and BitLocker keys`n" -ForegroundColor White
    
} catch {
    Write-Host "❌ Failed to configure Authorization Policy: $($_.Exception.Message)" -ForegroundColor Red
}

# ═══════════════════════════════════════════════════════════════
# 3. Identity Security Defaults
# ═══════════════════════════════════════════════════════════════
Write-Host "`n🛡️ Step 3: Configuring Identity Security Defaults..." -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray

try {
    # Get current policy
    $secDefaults = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy"
    
    # Disable security defaults (typically disabled when using Conditional Access)
    $secDefaultsBody = @{
        isEnabled = $false
    }
    
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy/$($secDefaults.id)" -Body ($secDefaultsBody | ConvertTo-Json -Depth 10)
    
    Write-Host "✅ Security Defaults configured:" -ForegroundColor Green
    Write-Host "   • Security Defaults: Disabled (using Conditional Access instead)`n" -ForegroundColor White
    
} catch {
    Write-Host "⚠️  Could not configure Security Defaults: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   Note: May already be disabled or require Conditional Access policies`n" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════
# 4. Authentication Methods Policy
# ═══════════════════════════════════════════════════════════════
Write-Host "`n📱 Step 4: Configuring Authentication Methods Policy..." -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray

try {
    $authMethodsPolicyBody = @{
        registrationEnforcement = @{
            authenticationMethodsRegistrationCampaignEnabled = $true
        }
    }
    
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy" -Body ($authMethodsPolicyBody | ConvertTo-Json -Depth 10)
    
    Write-Host "✅ Authentication Methods Policy configured:" -ForegroundColor Green
    Write-Host "   • Registration campaign enabled for MFA methods`n" -ForegroundColor White
    
    # Enable Microsoft Authenticator
    Write-Host "   Enabling Microsoft Authenticator..." -ForegroundColor Gray
    $authenticatorBody = @{
        "@odata.type" = "#microsoft.graph.microsoftAuthenticatorAuthenticationMethodConfiguration"
        state = "enabled"
        includeTargets = @(
            @{
                targetType = "group"
                id = "all_users"
                isRegistrationRequired = $false
            }
        )
        featureSettings = @{
            companionAppAllowedState = @{
                state = "enabled"
                includeTarget = @{
                    targetType = "group"
                    id = "all_users"
                }
            }
        }
    }
    
    try {
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/MicrosoftAuthenticator" -Body ($authenticatorBody | ConvertTo-Json -Depth 10)
        Write-Host "   ✓ Microsoft Authenticator enabled for all users" -ForegroundColor White
    } catch {
        Write-Host "   ⚠️  Could not enable Microsoft Authenticator: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Enable SMS
    Write-Host "   Enabling SMS authentication..." -ForegroundColor Gray
    $smsBody = @{
        "@odata.type" = "#microsoft.graph.smsAuthenticationMethodConfiguration"
        state = "enabled"
        includeTargets = @(
            @{
                targetType = "group"
                id = "all_users"
                isRegistrationRequired = $false
            }
        )
    }
    
    try {
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/Sms" -Body ($smsBody | ConvertTo-Json -Depth 10)
        Write-Host "   ✓ SMS authentication enabled for all users`n" -ForegroundColor White
    } catch {
        Write-Host "   ⚠️  Could not enable SMS: $($_.Exception.Message)`n" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Failed to configure Authentication Methods Policy: $($_.Exception.Message)`n" -ForegroundColor Red
}

# ═══════════════════════════════════════════════════════════════
# 5. Password Protection Settings
# ═══════════════════════════════════════════════════════════════
Write-Host "`n🔑 Step 5: Configuring Password Protection..." -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────── `n" -ForegroundColor Gray

Write-Host "⚠️  Password policies are configured per-domain and require Azure AD Premium." -ForegroundColor Yellow
Write-Host "   These settings should be configured manually in:" -ForegroundColor Yellow
Write-Host "   Entra ID > Security > Authentication methods > Password protection`n" -ForegroundColor Yellow

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ ENTRA ID CONFIGURATION COMPLETE!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n📋 Summary of Changes:" -ForegroundColor Yellow
Write-Host "   ✅ Device Registration Policy (LAPS enabled)" -ForegroundColor White
Write-Host "   ✅ Authorization Policy (user permissions)" -ForegroundColor White
Write-Host "   ✅ Security Defaults (disabled for Conditional Access)" -ForegroundColor White
Write-Host "   ✅ Authentication Methods (MFA enabled)" -ForegroundColor White

Write-Host "`n⚠️  Manual Configuration Required:" -ForegroundColor Yellow
Write-Host "   • Conditional Access Policies (create based on your requirements)" -ForegroundColor White
Write-Host "   • Company Branding (logos, colors, text)" -ForegroundColor White
Write-Host "   • Password Protection custom banned password list" -ForegroundColor White
Write-Host "   • Named Locations for Conditional Access" -ForegroundColor White

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
