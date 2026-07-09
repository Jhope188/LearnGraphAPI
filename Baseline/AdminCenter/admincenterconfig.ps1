#############################################################################
# Admin Center Security Hardening Script - CIS M365 Foundations Benchmark
# Aligned to CIS Microsoft 365 Foundations Benchmark v6.0.0
# Last Updated: February 2026
#############################################################################

# --- Required Scopes ---
# Graph: Policy.ReadWrite.Authorization, Policy.Read.All, Domain.ReadWrite.All,
#        Application.Read.All, Directory.ReadWrite.All, SharePointTenantSettings.ReadWrite.All
# Exchange Online: Organization Management (for transport, audit, forwarding)
# MSCommerce: Self-service purchase policies

# Force a consistent Microsoft.Graph version to prevent assembly conflicts
# (occurs when multiple Graph module versions are installed side-by-side)
$graphModule = Get-Module Microsoft.Graph -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if ($graphModule) {
    Import-Module Microsoft.Graph -RequiredVersion $graphModule.Version -Force -ErrorAction Stop
} else {
    Write-Error "Microsoft.Graph module not found. Install it with: Install-Module Microsoft.Graph -Scope CurrentUser"
    exit 1
}

Connect-MgGraph -Scopes @(
    "Policy.ReadWrite.Authorization",
    "Policy.Read.All",
    "Domain.ReadWrite.All",
    "Application.Read.All",
    "Directory.ReadWrite.All",
    "SharePointTenantSettings.ReadWrite.All"
) -NoWelcome

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Admin Center Security Hardening - CIS M365 Benchmark      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

#############################################################################
# SECTION 1: Authorization Policy & User Permissions
# CIS Controls: 5.1.2.3 (Restrict tenant creation)
# Additional best practices: Disable email subscriptions, email-verified join,
# block MSOL PowerShell, restrict app registration, restrict group creation
#############################################################################
Write-Host "=== [1/10] Authorization Policy & User Permissions ===" -ForegroundColor Cyan
Write-Host "Applying CIS 5.1.2.3 + security best practices..." -ForegroundColor Gray

Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    AllowedToSignUpEmailBasedSubscriptions = $false       # Disable email-based trials (best practice)
    AllowEmailVerifiedUsersToJoinOrganization = $false    # Prevent unauthorized join (best practice)
    BlockMsolPowerShell = $true                           # Block legacy PowerShell (best practice)
    DefaultUserRolePermissions = @{
        AllowedToCreateApps = $false                      # Restrict app registration (best practice)
        AllowedToCreateSecurityGroups = $false             # Centralize group management (best practice)
        AllowedToCreateTenants = $false                    # CIS 5.1.2.3 - Restrict tenant creation
        AllowedToReadBitlockerKeysForOwnedDevice = $true   # Self-service Bitlocker recovery
        AllowedToReadOtherUsers = $true                    # Enable collaboration
    }
}
Write-Host "  ✓ Authorization policy and user permissions applied" -ForegroundColor Green

#############################################################################
# SECTION 2: Password Expiration Policy
# CIS 1.3.1 - Ensure the 'Password expiration policy' is set to
#             'Set passwords to never expire (recommended)' (NIST 800-63B)
#############################################################################
Write-Host ""
Write-Host "=== [2/10] Password Expiration Policy ===" -ForegroundColor Cyan
Write-Host "Applying CIS 1.3.1 (NIST 800-63B)..." -ForegroundColor Gray

try {
    $domains = Get-MgDomain
    foreach ($domain in $domains) {
        if ($domain.PasswordValidityPeriodInDays -ne 2147483647) {
            Update-MgDomain -DomainId $domain.Id -PasswordValidityPeriodInDays 2147483647 -PasswordNotificationWindowInDays 14
            Write-Host "  ✓ Set passwords to never expire for domain: $($domain.Id)" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Passwords already set to never expire for: $($domain.Id)" -ForegroundColor Green
        }
    }
    Write-Host "  ℹ️  Note: This requires MFA enforcement to be secure (NIST 800-63B)" -ForegroundColor Gray
}
catch {
    Write-Host "  ⚠️ Password policy error: $($_.Exception.Message)" -ForegroundColor Red
}

#############################################################################
# SECTION 3: User Consent to Applications
# CIS 5.1.5.1 (L2) - Ensure user consent to apps is not allowed / restricted
# CIS 5.1.5.2 (L1) - Ensure the admin consent workflow is enabled
#############################################################################
Write-Host ""
Write-Host "=== [3/10] User Consent & Admin Consent Workflow ===" -ForegroundColor Cyan
Write-Host "Applying CIS 5.1.5.1, 5.1.5.2..." -ForegroundColor Gray

try {
    # CIS 5.1.5.1 - Restrict user consent to apps from verified publishers only
    # permissionGrantPoliciesAssigned: "managePermissionGrantsForSelf.microsoft-user-default-low"
    # means users can only consent to apps from verified publishers for low-impact permissions
    $consentBody = @{
        defaultUserRolePermissions = @{
            permissionGrantPoliciesAssigned = @(
                "managePermissionGrantsForSelf.microsoft-user-default-low"
            )
        }
    }
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" -Body $consentBody
    Write-Host "  ✓ User consent restricted to verified publishers with low-impact permissions" -ForegroundColor Green

    # CIS 5.1.5.2 - Enable admin consent workflow
    $consentWorkflow = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy"
    if (-not $consentWorkflow.isEnabled) {
        # Use PATCH to enable without overwriting existing reviewers
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy" -Body @{
            isEnabled = $true
            notifyReviewers = $true
            remindersEnabled = $true
            requestDurationInDays = 30
        }
        Write-Host "  ✓ Admin consent workflow enabled" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Admin consent workflow already enabled" -ForegroundColor Green
    }
    # Warn if no reviewers are configured (workflow is useless without them)
    if ($consentWorkflow.reviewers.Count -eq 0) {
        Write-Host "  ⚠️  WARNING: No reviewers configured for admin consent workflow!" -ForegroundColor Red
        Write-Host "  ➜ Navigate: Entra Admin Center > Enterprise apps > Admin consent settings" -ForegroundColor Yellow
        Write-Host "  ➜ Add Global Admin or Application Admin as reviewer" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ⚠️ Consent policy error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  ℹ️  You may need to configure consent settings manually in Entra admin center" -ForegroundColor Gray
}

#############################################################################
# SECTION 4: External Collaboration (Guest) Settings
# CIS 5.1.6.3 (L2) - Ensure guest user invitations are limited to the
#                     Guest Inviter role
#############################################################################
Write-Host ""
Write-Host "=== [4/10] External Collaboration (Guest) Settings ===" -ForegroundColor Cyan
Write-Host "Applying CIS 5.1.6.3..." -ForegroundColor Gray

try {
    # Restrict who can invite guests: adminsAndGuestInviters means only admins + users with Guest Inviter role
    $extCollabBody = @{
        allowInvitesFrom = "adminsAndGuestInviters"
    }
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" -Body $extCollabBody
    Write-Host "  ✓ Guest invitations restricted to admins and Guest Inviter role only" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️ External collaboration error: $($_.Exception.Message)" -ForegroundColor Yellow
}

#############################################################################
# SECTION 5: Authenticated SMTP Disable
# CIS 6.5.4 (L1) - Ensure SMTP AUTH is disabled
#############################################################################
Write-Host ""
Write-Host "=== [5/10] Authenticated SMTP ===" -ForegroundColor Cyan
Write-Host "Applying CIS 6.5.4..." -ForegroundColor Gray

try {
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    
    # Disable SMTP AUTH at the organization level
    Set-TransportConfig -SmtpClientAuthenticationDisabled $true -ErrorAction Stop
    Write-Host "  ✓ Authenticated SMTP disabled at organization level" -ForegroundColor Green

    $transportConfig = Get-TransportConfig
    Write-Host "    SMTP Client Auth Disabled:" ($transportConfig.SmtpClientAuthenticationDisabled ? "Yes (SECURE)" : "No (INSECURE)") -ForegroundColor $(if ($transportConfig.SmtpClientAuthenticationDisabled) { "Green" } else { "Red" })

    # Disable per-mailbox SMTP AUTH as safety net
    Write-Host "  Disabling SMTP AUTH on all individual mailboxes..." -ForegroundColor Yellow
    $mailboxes = Get-CASMailbox -ResultSize Unlimited | Where-Object { $_.SmtpClientAuthenticationDisabled -ne $true }
    $mbxCount = 0
    foreach ($mbx in $mailboxes) {
        Set-CASMailbox -Identity $mbx.Identity -SmtpClientAuthenticationDisabled $true -ErrorAction SilentlyContinue
        $mbxCount++
    }
    if ($mbxCount -gt 0) {
        Write-Host "  ✓ Disabled SMTP AUTH on $mbxCount mailbox(es)" -ForegroundColor Green
    } else {
        Write-Host "  ✓ All mailboxes already have SMTP AUTH disabled" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ⚠️ Exchange Online Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    Install-Module ExchangeOnlineManagement -Force" -ForegroundColor Gray
}

#############################################################################
# SECTION 6: Unified Audit Logging
# CIS 3.1.1 (L1) - Ensure Microsoft 365 audit log search is Enabled
# (Also referenced as CIS 6.1.1 in Exchange Online section)
#############################################################################
Write-Host ""
Write-Host "=== [6/10] Unified Audit Logging ===" -ForegroundColor Cyan
Write-Host "Applying CIS 3.1.1 / 6.1.1..." -ForegroundColor Gray

try {
    # Exchange Online connection should already be established from Section 5
    $auditConfig = Get-AdminAuditLogConfig
    if (-not $auditConfig.UnifiedAuditLogIngestionEnabled) {
        Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true -ErrorAction Stop
        Write-Host "  ✓ Unified audit logging ENABLED" -ForegroundColor Green
        Write-Host "  ℹ️  Note: May take up to 60 minutes to take full effect" -ForegroundColor Gray
    } else {
        Write-Host "  ✓ Unified audit logging already enabled" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ⚠️ Audit logging error (attempt 1): $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Retrying in 5 seconds..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    try {
        $auditConfig = Get-AdminAuditLogConfig
        if (-not $auditConfig.UnifiedAuditLogIngestionEnabled) {
            Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true -ErrorAction Stop
            Write-Host "  ✓ Unified audit logging ENABLED (on retry)" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Unified audit logging already enabled" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ❌ Audit logging failed after retry: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  ℹ️  For Business Standard/Premium, audit logging must be enabled manually" -ForegroundColor Gray
        Write-Host "  ℹ️  Run: Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled `$true" -ForegroundColor Gray
    }
}

#############################################################################
# SECTION 7: External Email Forwarding
# CIS 6.2.1 (L1) - Ensure all forms of mail forwarding are blocked
#                   and/or disabled
#############################################################################
Write-Host ""
Write-Host "=== [7/10] External Email Forwarding ===" -ForegroundColor Cyan
Write-Host "Applying CIS 6.2.1..." -ForegroundColor Gray

try {
    # Check & set outbound spam policy to block automatic external forwarding
    $outboundPolicies = Get-HostedOutboundSpamFilterPolicy
    foreach ($policy in $outboundPolicies) {
        if ($policy.AutoForwardingMode -ne "Off") {
            Set-HostedOutboundSpamFilterPolicy -Identity $policy.Name -AutoForwardingMode Off -ErrorAction Stop
            Write-Host "  ✓ Auto-forwarding disabled on policy: $($policy.Name)" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Auto-forwarding already disabled on policy: $($policy.Name)" -ForegroundColor Green
        }
    }

    # Also disable forwarding on Remote Domains (Default) to external
    $remoteDomain = Get-RemoteDomain -Identity Default -ErrorAction SilentlyContinue
    if ($remoteDomain -and $remoteDomain.AutoForwardEnabled) {
        Set-RemoteDomain -Identity Default -AutoForwardEnabled $false -ErrorAction Stop
        Write-Host "  ✓ Auto-forwarding disabled on Default remote domain" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Auto-forwarding already disabled on Default remote domain" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ⚠️ Forwarding policy error: $($_.Exception.Message)" -ForegroundColor Yellow
}

#############################################################################
# SECTION 8: SharePoint & OneDrive Security
# CIS 7.2.1 (L1) - Ensure modern authentication for SharePoint is required
# CIS 7.2.3 (L1) - Ensure external content sharing is restricted
# CIS 7.2.7 (L1) - Ensure link sharing is restricted in SharePoint/OneDrive
# CIS 7.2.11 (L1) - Ensure the SharePoint default sharing link permission
#############################################################################
Write-Host ""
Write-Host "=== [8/10] SharePoint & OneDrive Security ===" -ForegroundColor Cyan
Write-Host "Applying CIS 7.2.1, 7.2.3, 7.2.7, 7.2.11..." -ForegroundColor Gray

try {
    # Get current SharePoint settings via Graph beta
    $spoSettings = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/admin/sharepoint/settings"
    
    $spoUpdateBody = @{}
    $changed = $false

    # CIS 7.2.1 - Ensure modern authentication for SharePoint applications is required
    if ($spoSettings.isLegacyAuthProtocolsEnabled) {
        $spoUpdateBody["isLegacyAuthProtocolsEnabled"] = $false
        $changed = $true
    }

    # CIS 7.2.3 - Ensure external content sharing is restricted
    # Options: disabled, externalUserSharingOnly, externalUserAndGuestSharing, existingExternalUserSharingOnly
    if ($spoSettings.sharingCapability -eq "externalUserAndGuestSharing") {
        $spoUpdateBody["sharingCapability"] = "externalUserSharingOnly"
        $changed = $true
    }

    # CIS 7.2.7/7.2.11 - Set default sharing link type to specificPeople (most restrictive)
    if ($spoSettings.defaultSharingLinkType -ne "specificPeople") {
        $spoUpdateBody["defaultSharingLinkType"] = "specificPeople"
        $changed = $true
    }

    if ($changed) {
        Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/admin/sharepoint/settings" -Body $spoUpdateBody | Out-Null
        if ($spoUpdateBody.ContainsKey("isLegacyAuthProtocolsEnabled")) {
            Write-Host "  ✓ Legacy authentication protocols disabled for SharePoint" -ForegroundColor Green
        }
        if ($spoUpdateBody.ContainsKey("sharingCapability")) {
            Write-Host "  ✓ External sharing restricted to authenticated guests only" -ForegroundColor Green
        }
        if ($spoUpdateBody.ContainsKey("defaultSharingLinkType")) {
            Write-Host "  ✓ Default sharing link type set to Specific People" -ForegroundColor Green
        }
    } else {
        Write-Host "  ✓ SharePoint legacy auth already disabled" -ForegroundColor Green
        Write-Host "  ✓ SharePoint sharing settings already aligned with CIS" -ForegroundColor Green
    }

    # Report current state
    $spoVerify = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/admin/sharepoint/settings"
    Write-Host "    Legacy Auth: $(if ($spoVerify.isLegacyAuthProtocolsEnabled) { 'ENABLED (⚠️)' } else { 'DISABLED (✅)' })" -ForegroundColor $(if ($spoVerify.isLegacyAuthProtocolsEnabled) { "Red" } else { "Green" })
    Write-Host "    Sharing Level: $($spoVerify.sharingCapability)" -ForegroundColor White
    Write-Host "    Default Link Type: $($spoVerify.defaultSharingLinkType)" -ForegroundColor White
}
catch {
    Write-Host "  ⚠️ SharePoint settings error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  ℹ️  Ensure SharePointTenantSettings.ReadWrite.All scope is granted" -ForegroundColor Gray
}

#############################################################################
# SECTION 9: Release Preferences
# Best Practice - Organization release preferences should be configured
# Note: In CIS v6.0, 1.3.3 now covers External Calendar Sharing
#############################################################################
Write-Host ""
Write-Host "=== [9/10] Release Preferences (Informational) ===" -ForegroundColor Cyan
Write-Host "Best Practice - Verify release preferences..." -ForegroundColor Gray
Write-Host "  ℹ️  Release preferences should be set to 'Targeted Release for select users'" -ForegroundColor Yellow
Write-Host "  ℹ️  This allows IT admins to preview features before general rollout" -ForegroundColor Gray
Write-Host "  ℹ️  Navigate: M365 Admin Center > Settings > Org settings > Release preferences" -ForegroundColor Gray
Write-Host "  ℹ️  Note: This setting cannot be configured via Graph API - manual action required" -ForegroundColor Gray

#############################################################################
# SECTION 10: Self-Service Purchase Policies
# CIS 1.3.4 (L1) - Ensure 'User owned apps and services' is restricted
# Includes disabling self-service purchases and admin-initiated trials
#############################################################################
Write-Host ""
Write-Host "=== [10/10] Self-Service Purchase Policies ===" -ForegroundColor Cyan
Write-Host "  ⚠️  SKIPPED — MSCommerce module commented out (fix module issue first)" -ForegroundColor Yellow
Write-Host "  ℹ️  Run Disable-SelfServiceTrials.ps1 separately once MSCommerce is working" -ForegroundColor Gray
Write-Host "  ℹ️  Manual: M365 Admin Center > Settings > Org settings > Services > User owned apps" -ForegroundColor Gray

<#  ── MSCommerce block — commented out until module auth is resolved ──────────
Write-Host "Applying CIS 1.3.4..." -ForegroundColor Gray

# MSCommerce must run in a subprocess to avoid Microsoft.Identity.Client DLL version
# conflict with Exchange Online Management module (loaded in Section 5).
Write-Host "  ℹ️  Running MSCommerce in subprocess to avoid DLL conflict..." -ForegroundColor Gray

$msCommerceScript = @'
try {
    Import-Module MSCommerce -ErrorAction Stop
    Connect-MSCommerce -ErrorAction Stop

    $selfServiceProducts = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
    $disabledSelfService = 0
    $alreadyDisabledSelfService = 0
    foreach ($product in $selfServiceProducts) {
        if ($product.PolicyValue -eq "Enabled") {
            Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase -ProductId $product.ProductId -Enabled $false
            Write-Host "    ✓ Disabled: $($product.ProductName)" -ForegroundColor Green
            $disabledSelfService++
        } else {
            $alreadyDisabledSelfService++
        }
    }

    try {
        $adminTrialProducts = Get-MSCommerceProductPolicies -PolicyId AllowAdminTrialPurchase -ErrorAction Stop
        $disabledAdminTrial = 0
        $alreadyDisabledAdminTrial = 0
        foreach ($product in $adminTrialProducts) {
            if ($product.PolicyValue -eq "Enabled") {
                Update-MSCommerceProductPolicy -PolicyId AllowAdminTrialPurchase -ProductId $product.ProductId -Enabled $false
                $disabledAdminTrial++
            } else {
                $alreadyDisabledAdminTrial++
            }
        }
    } catch {
        Write-Host "    ℹ️  Admin trial policies not available in this tenant" -ForegroundColor Gray
    }

    $finalSelfService = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase | Where-Object { $_.PolicyValue -eq "Enabled" }
    if ($finalSelfService.Count -eq 0) {
        Write-Host "  ✅ All self-service purchases DISABLED" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ $($finalSelfService.Count) self-service purchases still enabled" -ForegroundColor Red
    }
} catch {
    Write-Host "  ⚠️ MSCommerce Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
'@

$tempScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
$msCommerceScript | Set-Content -Path $tempScript -Encoding UTF8
try {
    $result = & pwsh -NoProfile -File $tempScript 2>&1
    $result | ForEach-Object { Write-Host $_ }
} catch {
    Write-Host "  ⚠️ Failed to launch MSCommerce subprocess: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
}
──────────────────────────────────────────────────────────────────────────── #>

#############################################################################
# VERIFICATION SUMMARY
#############################################################################
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Verification Summary                      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$authPolicy = Get-MgPolicyAuthorizationPolicy

Write-Host ""
Write-Host "Authorization Policy:" -ForegroundColor Yellow
Write-Host "  Email-based subscriptions:     " -NoNewline; Write-Host ($authPolicy.AllowedToSignUpEmailBasedSubscriptions ? "ENABLED ⚠️" : "DISABLED ✅") -ForegroundColor $(if (-not $authPolicy.AllowedToSignUpEmailBasedSubscriptions) { "Green" } else { "Red" })
Write-Host "  Email verified users can join: " -NoNewline; Write-Host ($authPolicy.AllowEmailVerifiedUsersToJoinOrganization ? "ENABLED ⚠️" : "DISABLED ✅") -ForegroundColor $(if (-not $authPolicy.AllowEmailVerifiedUsersToJoinOrganization) { "Green" } else { "Red" })
Write-Host "  Block MSOL PowerShell:         " -NoNewline; Write-Host ($authPolicy.BlockMsolPowerShell ? "ENABLED ✅" : "DISABLED ⚠️") -ForegroundColor $(if ($authPolicy.BlockMsolPowerShell) { "Green" } else { "Red" })

Write-Host ""
Write-Host "Default User Permissions:" -ForegroundColor Yellow
Write-Host "  Can create apps:               " -NoNewline; Write-Host ($authPolicy.DefaultUserRolePermissions.AllowedToCreateApps ? "Yes ⚠️" : "No ✅") -ForegroundColor $(if (-not $authPolicy.DefaultUserRolePermissions.AllowedToCreateApps) { "Green" } else { "Red" })
Write-Host "  Can create security groups:     " -NoNewline; Write-Host ($authPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups ? "Yes ⚠️" : "No ✅") -ForegroundColor $(if (-not $authPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups) { "Green" } else { "Red" })
Write-Host "  Can create tenants:             " -NoNewline; Write-Host ($authPolicy.DefaultUserRolePermissions.AllowedToCreateTenants ? "Yes ⚠️" : "No ✅") -ForegroundColor $(if (-not $authPolicy.DefaultUserRolePermissions.AllowedToCreateTenants) { "Green" } else { "Red" })
Write-Host "  Can read Bitlocker keys:        " -NoNewline; Write-Host ($authPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice ? "Yes ✅" : "No ⚠️") -ForegroundColor $(if ($authPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice) { "Green" } else { "Red" })
Write-Host "  Can read other users:           " -NoNewline; Write-Host ($authPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers ? "Yes ✅" : "No ⚠️") -ForegroundColor $(if ($authPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers) { "Green" } else { "Red" })

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Admin Center CIS Hardening Complete             ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

#############################################################################
# MANUAL CONFIGURATION REQUIRED
# CIS Microsoft 365 Foundations Benchmark v6.0.0 - Manual Items
# Settings that cannot be automated via Graph API or PowerShell
#############################################################################
Write-Host "=== Manual Configuration Required (CIS v6.0) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  The following CIS v6.0 recommended settings require manual configuration:" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━ ADMIN CENTER SETTINGS ━━━" -ForegroundColor Magenta
Write-Host ""
Write-Host "1. Idle Session Timeout (CIS 1.3.2 - L1):" -ForegroundColor White
Write-Host "   Entra Admin Center > Identity > Protection > Conditional Access" -ForegroundColor Gray
Write-Host "   ➜ Create policy with Session > Sign-in frequency: 3 hours or less" -ForegroundColor Yellow
Write-Host "   ➜ Or: M365 Admin Center > Org settings > Security & privacy > Idle session timeout" -ForegroundColor Gray
Write-Host "   ➜ Enable 'Sign out inactive users' — 3 hours or less for unmanaged devices" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. External Calendar Sharing (CIS 1.3.3 - L2):" -ForegroundColor White
Write-Host "   M365 Admin Center > Settings > Org settings > Calendar" -ForegroundColor Gray
Write-Host "   ➜ Ensure 'External sharing' of calendars is NOT available" -ForegroundColor Yellow
Write-Host "   ➜ Or restrict to 'Calendar free/busy information with time only'" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. User Owned Apps and Services (CIS 1.3.4 - L1):" -ForegroundColor White
Write-Host "   M365 Admin Center > Settings > Org settings > Services > 'User owned apps and services'" -ForegroundColor Gray
Write-Host "   ☐ Uncheck 'Let users access the Office Store'" -ForegroundColor Red
Write-Host "   ☐ Uncheck 'Let users start trials on behalf of your organization'" -ForegroundColor Red
Write-Host "   ☐ Uncheck 'Let users auto-claim licenses the first time they sign in'" -ForegroundColor Red
Write-Host "   ℹ️  This prevents shadow IT from uncontrolled app/trial installations" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Internal Phishing Protection for Forms (CIS 1.3.5 - L1):" -ForegroundColor White
Write-Host "   M365 Admin Center > Settings > Org settings > Microsoft Forms" -ForegroundColor Gray
Write-Host "   ➜ Enable internal phishing protection" -ForegroundColor Yellow
Write-Host ""
Write-Host "5. Customer Lockbox (CIS 1.3.6 - L2 - E5/E5 Compliance only):" -ForegroundColor White
Write-Host "   M365 Admin Center > Settings > Org settings > Security & privacy > Customer lockbox" -ForegroundColor Gray
Write-Host "   ➜ Enable 'Require approval for all data access requests'" -ForegroundColor Yellow
Write-Host ""
Write-Host "6. Third-Party Storage in M365 on the Web (CIS 1.3.7 - L2):" -ForegroundColor White
Write-Host "   M365 Admin Center > Settings > Org settings > Services > Office on the web" -ForegroundColor Gray
Write-Host "   ➜ Disable 'Let people open files stored in third-party storage services'" -ForegroundColor Yellow
Write-Host ""
Write-Host "7. Release Preferences (Best Practice):" -ForegroundColor White
Write-Host "   M365 Admin Center > Settings > Org settings > Release preferences" -ForegroundColor Gray
Write-Host "   ➜ Set to 'Targeted Release for select users' (add IT admins)" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━ COPILOT & AI GOVERNANCE ━━━" -ForegroundColor Magenta
Write-Host ""
Write-Host "8. Microsoft 365 Copilot Agent Settings:" -ForegroundColor White
Write-Host "   M365 Admin Center > Copilot > Settings > Data access > Agents" -ForegroundColor Gray
Write-Host "   STEP 1: Create a Security Group for Copilot users:" -ForegroundColor Yellow
Write-Host "     ➜ Entra Admin Center > Groups > New group" -ForegroundColor Gray
Write-Host "     ➜ Type: Security | Name: 'SG-M365-Copilot-Agents-Users'" -ForegroundColor Gray
Write-Host "     ➜ Add licensed Copilot users as members" -ForegroundColor Gray
Write-Host "   STEP 2: Assign the group to Copilot agent access:" -ForegroundColor Yellow
Write-Host "     ➜ Who can access agents: Specific users/groups → select 'SG-M365-Copilot-Agents-Users'" -ForegroundColor Yellow
Write-Host "     ➜ Who can share agents: Specific users → select appropriate admins only" -ForegroundColor Yellow
Write-Host "   STEP 3: Restrict third-party agent apps:" -ForegroundColor Yellow
Write-Host "     ☐ Allow apps from Microsoft: OFF (unless specifically needed)" -ForegroundColor Red
Write-Host "     ☐ Allow apps from external publishers: OFF" -ForegroundColor Red
Write-Host "     ☑ Allow apps built by your organization: ON (if org-developed agents exist)" -ForegroundColor Green
Write-Host ""
Write-Host "━━━ ENTRA ID & IDENTITY ━━━" -ForegroundColor Magenta
Write-Host ""
Write-Host "9. Cloud-Only Admin Accounts (CIS 1.1.1 - L1):" -ForegroundColor White
Write-Host "   ➜ Ensure all admin accounts are cloud-only (not synced from on-prem AD)" -ForegroundColor Yellow
Write-Host "   ➜ Admin accounts should NOT have mailboxes or desktop app licenses" -ForegroundColor Yellow
Write-Host ""
Write-Host "10. Emergency Access Accounts (CIS 1.1.2 - L1):" -ForegroundColor White
Write-Host "    ➜ Create 2 cloud-only break-glass accounts with Global Admin role" -ForegroundColor Yellow
Write-Host "    ➜ Exclude from ALL Conditional Access policies" -ForegroundColor Yellow
Write-Host "    ➜ Use long complex passwords stored securely (not tied to any person)" -ForegroundColor Yellow
Write-Host ""
Write-Host "11. Global Admin Count (CIS 1.1.3 - L1):" -ForegroundColor White
Write-Host "    ➜ Ensure between 2 and 4 Global Administrators are designated" -ForegroundColor Yellow
Write-Host ""
Write-Host "12. Shared Mailbox Sign-in (CIS 1.2.2 - L1):" -ForegroundColor White
Write-Host "    ➜ Ensure sign-in to shared mailboxes is blocked (disable direct login)" -ForegroundColor Yellow
Write-Host ""
Write-Host "13. Conditional Access / MFA (CIS 5.2.2.x - L1):" -ForegroundColor White
Write-Host "    Entra Admin Center > Identity > Protection > Conditional Access" -ForegroundColor Gray
Write-Host "    ➜ CIS 5.2.2.1: Ensure MFA is enabled for all users in admin roles" -ForegroundColor Yellow
Write-Host "    ➜ CIS 5.2.2.2: Ensure MFA is enabled for all users" -ForegroundColor Yellow
Write-Host "    ➜ CIS 5.2.2.3: Enable CA policies to block legacy authentication" -ForegroundColor Yellow
Write-Host "    ➜ CIS 5.2.2.4: Ensure sign-in frequency for admins" -ForegroundColor Yellow
Write-Host "    ➜ CIS 5.2.2.5: Require phishing-resistant MFA for admins (L2)" -ForegroundColor Yellow
Write-Host ""
Write-Host "14. Guest User Access (CIS 5.1.6.1/5.1.6.2 - L1/L2):" -ForegroundColor White
Write-Host "    ➜ CIS 5.1.6.1: Ensure collaboration invitations go to allowed domains only" -ForegroundColor Yellow
Write-Host "    ➜ CIS 5.1.6.2: Ensure guest user access is restricted" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━ DATA PROTECTION ━━━" -ForegroundColor Magenta
Write-Host ""
Write-Host "15. DLP Policies (CIS 3.2.1/3.2.2 - L1):" -ForegroundColor White
Write-Host "    Microsoft Purview > Data loss prevention > Policies" -ForegroundColor Gray
Write-Host "    ➜ CIS 3.2.1: Ensure DLP policies are enabled" -ForegroundColor Yellow
Write-Host "    ➜ CIS 3.2.2: Ensure DLP policies are enabled for Microsoft Teams" -ForegroundColor Yellow
Write-Host "    ➜ Create policies for sensitive data (PII, financial, health)" -ForegroundColor Yellow
Write-Host ""
Write-Host "16. Sensitivity Labels (CIS 3.3.1 - L1):" -ForegroundColor White
Write-Host "    Microsoft Purview > Information protection > Labels" -ForegroundColor Gray
Write-Host "    ➜ Ensure sensitivity label policies are published" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━ TEAMS (CIS Section 8 - NEW) ━━━" -ForegroundColor Magenta
Write-Host ""
Write-Host "17. Teams External Access (CIS 8.2.x - L1):" -ForegroundColor White
Write-Host "    Teams Admin Center > Users > External access" -ForegroundColor Gray
Write-Host "    ➜ CIS 8.2.1: Restrict external domains (L2)" -ForegroundColor Yellow
Write-Host "    ➜ CIS 8.2.2: Disable communication with unmanaged Teams users" -ForegroundColor Yellow
Write-Host "    ➜ CIS 8.2.3: Ensure external users cannot initiate conversations" -ForegroundColor Yellow
Write-Host ""
Write-Host "18. Teams Meeting Settings (CIS 8.5.x - L1/L2):" -ForegroundColor White
Write-Host "    Teams Admin Center > Meetings > Meeting policies" -ForegroundColor Gray
Write-Host "    ➜ CIS 8.5.2: Anonymous users/dial-in can't start meetings" -ForegroundColor Yellow
Write-Host "    ➜ CIS 8.5.3: Only org members can bypass lobby" -ForegroundColor Yellow
Write-Host "    ➜ CIS 8.5.7: External participants can't give/request control" -ForegroundColor Yellow
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host ""
Write-Host "ℹ️  Full CIS v6.0 benchmark: https://www.cisecurity.org/benchmark/microsoft_365" -ForegroundColor Gray
Write-Host "ℹ️  Some settings require E3/E5 licensing. Review license level before applying." -ForegroundColor Gray
Write-Host "ℹ️  L1 = Level 1 (essential), L2 = Level 2 (defence-in-depth, may impact usability)" -ForegroundColor Gray