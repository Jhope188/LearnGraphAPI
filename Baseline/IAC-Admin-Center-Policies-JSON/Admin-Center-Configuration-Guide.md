# Microsoft 365 Administrative Center Configuration Documentation

**Last Updated:** January 17, 2026

This document describes the Microsoft 365 Administrative Center features and their current configuration status for your tenant.

---

## Table of Contents

1. [Authorization Policy Settings](#authorization-policy-settings)
2. [Exchange Online Calendar Sharing](#exchange-online-calendar-sharing)
3. [Self-Service Purchase Policies](#self-service-purchase-policies)
4. [Default User Role Permissions](#default-user-role-permissions)
5. [Management Scripts](#management-scripts)

---

## Authorization Policy Settings

These settings control tenant-wide user capabilities related to self-service features and trials.

### Email-Based Subscriptions (Self-Service Trials)

**Setting:** `AllowedToSignUpEmailBasedSubscriptions`

**Description:** Controls whether users can sign up for email-based subscriptions and trials using their organizational email address.

**Recommended Value:** `False` (Disabled)

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can sign up for Microsoft services trials independently
- When **Disabled**: Prevents users from creating trial subscriptions, giving IT full control over service adoption

**Management:**
```powershell
# Disable self-service email-based subscriptions
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    allowedToSignUpEmailBasedSubscriptions = $false
}

# Enable self-service email-based subscriptions
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    allowedToSignUpEmailBasedSubscriptions = $true
}
```

---

### Email Verified Users Can Join Organization

**Setting:** `AllowEmailVerifiedUsersToJoinOrganization`

**Description:** Controls whether users with verified email addresses can join the organization without an invitation.

**Recommended Value:** `False` (Disabled) for most organizations

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Any user with a verified email can request to join your organization
- When **Disabled**: Only invited users can join the organization (recommended for security)

---

### Block Legacy MSOL PowerShell

**Setting:** `BlockMsolPowerShell`

**Description:** Controls whether the legacy MSOnline (MSOL) PowerShell module can be used to manage your tenant.

**Recommended Value:** `True` (Enabled) - blocks legacy module, forces modern Microsoft Graph

**Current Status:** ✅ `True` (Enabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Forces use of modern Microsoft Graph PowerShell cmdlets (recommended)
- When **Disabled**: Allows continued use of deprecated MSOnline module

**Security Note:** Microsoft recommends blocking MSOL PowerShell and transitioning to Microsoft Graph PowerShell for improved security and functionality.

**Management:**
```powershell
# Enable blocking of legacy MSOL PowerShell (Recommended)
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization" -NoWelcome
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    BlockMsolPowerShell = $true
}

# Disable blocking (Allow MSOL PowerShell - Not Recommended)
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    BlockMsolPowerShell = $false
}

# Verify current setting
$authPolicy = Get-MgPolicyAuthorizationPolicy
Write-Host "Block MSOL PowerShell:" ($authPolicy.BlockMsolPowerShell ? "ENABLED" : "DISABLED")
```

**Note:** This setting is **not available in the Microsoft 365 Admin Center UI**. It must be configured via Microsoft Graph PowerShell API. The `admincenterconfig.ps1` script in this repository automatically enables this setting.

---

## Exchange Online Calendar Sharing

### External Calendar Sharing with Office 365/Exchange Organizations

**Setting:** Calendar sharing with external organizations

**Location:** M365 Admin Center → Settings → Org settings → Calendar

**Description:** Controls whether users can share their calendars with people outside your organization who have Office 365 or Exchange. This includes free/busy information and calendar details.

**Recommended Value:** Depends on business requirements
- **Disabled**: Recommended for most organizations to prevent information disclosure
- **Enabled**: Only if external collaboration requires calendar visibility

**Current Status:** ⚠️ Requires manual review

**Impact:**
- When **Enabled**: Users can share calendar information (including free/busy times) with external Office 365/Exchange users
- When **Disabled**: Prevents calendar information sharing outside the organization

**Security Considerations:**
- **Information Disclosure**: Calendar sharing can reveal meeting patterns, availability, and potentially sensitive meeting details
- **Business Collaboration**: May be required for organizations working closely with partners/clients
- **Federated Sharing**: This is separate from anonymous calendar publishing

**Types of Calendar Sharing:**
1. **Anonymous Calendar Publishing**: Share calendar via anonymous links (very high risk)
2. **Federated Sharing with O365/Exchange**: Share with other Office 365 or Exchange organizations (moderate risk)
3. **Individual Permissions**: Users control specific sharing on per-calendar basis

**Management via PowerShell:**
```powershell
# Check current calendar sharing policy
Connect-ExchangeOnline
$sharingPolicy = Get-SharingPolicy | Where-Object {$_.Default -eq $true}
$sharingPolicy | Select-Object Name, Domains, Enabled

# Check for anonymous/external sharing domains
$sharingPolicy.Domains | Where-Object { $_ -like "*Anonymous*" -or $_ -like "*CalendarSharing*" }

# Check organization-level federated sharing
Get-OrganizationConfig | Select-Object Name, IsDehydrated, OrganizationSummary

# To disable external calendar sharing, modify the default sharing policy
# Remove anonymous domains (requires careful planning - may impact users)
Set-SharingPolicy "Default Sharing Policy" -Domains "Anonymous:CalendarSharingFreeBusySimple"
```

**Recommendation:**
- Review your organization's collaboration requirements
- If external calendar sharing is not needed, disable it to prevent information disclosure
- If required, implement least-privilege access:
  - Only allow specific users/groups to share calendars externally
  - Limit sharing to free/busy only (not full details)
  - Educate users on risks of calendar sharing
- Monitor calendar sharing activity via audit logs

**Note:** The `admincenterconfig.ps1` script checks this setting but does not automatically change it, as it requires business decision-making. Manual review and configuration are recommended.

---

## Self-Service Purchase Policies

Self-service purchase allows users to purchase subscriptions directly using their corporate credit card, without IT approval. These policies can be controlled per product.

### Policy: AllowSelfServicePurchase

**Description:** Controls whether users can make self-service purchases of Microsoft products.

**Recommended Value:** `Disabled` for most products in enterprise environments

**Current Status:** ✅ All 27 products are **Disabled** - **Matches recommendation**

**Products Currently Configured:**

| Product Name | Current Setting | Status |
|-------------|----------------|--------|
| Power Apps per user | ✅ Disabled | Matches recommendation |
| Power Automate per user | ✅ Disabled | Matches recommendation |
| Power Automate RPA | ✅ Disabled | Matches recommendation |
| Power Automate Per User with Attended RPA | ✅ Disabled | Matches recommendation |
| Power BI Pro | ✅ Disabled | Matches recommendation |
| Power BI Premium per user | ✅ Disabled | Matches recommendation |
| Project Plan 1 | ✅ Disabled | Matches recommendation |
| Project Plan 3 | ✅ Disabled | Matches recommendation |
| Visio Plan 1 | ✅ Disabled | Matches recommendation |
| Visio Plan 2 | ✅ Disabled | Matches recommendation |
| Microsoft 365 F3 | ✅ Disabled | Matches recommendation |
| Microsoft 365 Copilot | ✅ Disabled | Matches recommendation |
| Windows 365 Enterprise | ✅ Disabled | Matches recommendation |
| Windows 365 Business | ✅ Disabled | Matches recommendation |
| Windows 365 Business with Windows Hybrid Benefit | ✅ Disabled | Matches recommendation |
| Viva Learning | ✅ Disabled | Matches recommendation |
| Viva Goals | ✅ Disabled | Matches recommendation |
| Dynamics 365 Marketing | ✅ Disabled | Matches recommendation |
| Dynamics 365 Marketing Attach | ✅ Disabled | Matches recommendation |
| Dynamics 365 Marketing Additional Application | ✅ Disabled | Matches recommendation |
| Dynamics 365 Marketing Additional Non-Prod Application | ✅ Disabled | Matches recommendation |
| Teams Exploratory | ✅ Disabled | Matches recommendation |
| Teams Essentials | ✅ Disabled | Matches recommendation |
| Teams Premium | ✅ Disabled | Matches recommendation |
| Python in Excel | ✅ Disabled | Matches recommendation |
| Microsoft Purview Discovery | ✅ Disabled | Matches recommendation |
| Microsoft ClipChamp | ✅ Disabled | Matches recommendation |

**Management:**

```powershell
# Disable self-service purchase for a specific product
Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
    -ProductId <ProductId> -Enabled $false

# Enable self-service purchase for a specific product
Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
    -ProductId <ProductId> -Enabled $true

# View all product policies
Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase | 
    Select-Object ProductName, PolicyValue | 
    Format-Table -AutoSize
```

**To Disable All Products:**
```powershell
# Get all products and disable self-service purchase
$products = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
foreach ($product in $products) {
    if ($product.PolicyValue -eq "Enabled") {
        Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
            -ProductId $product.ProductId -Enabled $false
        Write-Host "Disabled: $($product.ProductName)"
    }
}
```

---

## Default User Role Permissions

These settings define what standard (non-admin) users can do in your Microsoft 365 tenant.

### Can Create Applications

**Setting:** `AllowedToCreateApps`

**Description:** Controls whether users can register applications in Azure AD.

**Recommended Value:** `False` for most enterprises

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Any user can register applications that can access tenant resources
- When **Disabled**: Only administrators can register applications (recommended for security)

---

### Can Create Security Groups

**Setting:** `AllowedToCreateSecurityGroups`

**Description:** Controls whether users can create security groups.

**Recommended Value:** `False` for most enterprises

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can create security groups and manage membership
- When **Disabled**: Only administrators can create security groups (recommended for governance)

---

### Can Create Tenants

**Setting:** `AllowedToCreateTenants`

**Description:** Controls whether users can create new Azure AD tenants.

**Recommended Value:** `False` (Disabled) - prevents unauthorized tenant sprawl

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can create their own separate Azure AD tenants
- When **Disabled**: Prevents tenant creation by standard users (recommended for governance)

**Note:** While creating new tenants doesn't directly affect your organization's security, allowing users to create tenants can lead to shadow IT, data sprawl, and governance challenges.

---

### Can Read Bitlocker Keys for Owned Devices

**Setting:** `AllowedToReadBitlockerKeysForOwnedDevice`

**Description:** Controls whether users can view their own device's Bitlocker recovery keys in Azure AD.

**Recommended Value:** `True` (Enabled) - allows self-service recovery

**Current Status:** ✅ `True` (Enabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can retrieve their own Bitlocker keys without contacting helpdesk
- When **Disabled**: Only administrators can view Bitlocker keys (increases helpdesk burden)

---

### Can Read Other Users

**Setting:** `AllowedToReadOtherUsers`

**Description:** Controls whether users can view information about other users in the directory.

**Recommended Value:** `True` for most organizations (enables collaboration)

**Current Status:** ✅ `True` (Enabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can search for and view other users' profiles (useful for collaboration)
- When **Disabled**: Users cannot see other users in the directory (limits collaboration)

---

## Management Scripts

### Available Scripts

1. **admincenterconfig.ps1** - CIS M365 Benchmark-aligned admin center hardening (19 automated controls)
2. **export-admin-center-config.ps1** - Exports current configuration to JSON

### Usage

**To Configure Admin Center (CIS Hardening):**
```powershell
cd /Users/jon/Desktop/BaslineSetup/IAC-Admin-Center-Policies-JSON/Scripts
./admincenterconfig.ps1
```

**Required Modules:**
- Microsoft.Graph PowerShell SDK
- ExchangeOnlineManagement
- MSCommerce

**Required Graph Scopes:**
- `Policy.ReadWrite.Authorization`
- `Policy.Read.All`
- `Domain.ReadWrite.All`
- `Application.Read.All`
- `Directory.ReadWrite.All`
- `SharePointTenantSettings.ReadWrite.All`

**To Export Current Configuration:**
```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts
./export-admin-center-config.ps1
```

---

## Password Expiration Policy (CIS 1.3.1)

**CIS Control:** 1.3.1 - Ensure the 'Password expiration policy' is set to 'Set passwords to never expire (recommended)'

**Description:** CIS and NIST 800-63B recommend setting passwords to **never expire** when MFA is enforced. Frequent password changes lead to weaker passwords (users create predictable patterns) and do not meaningfully improve security when combined with MFA.

**Recommended Value:** Passwords set to **never expire** (2147483647 days)

**Management:**

```powershell
# Check current password expiration policy
Get-MgDomain | Select-Object Id, PasswordValidityPeriodInDays, PasswordNotificationWindowInDays

# Set passwords to never expire for a domain
Update-MgDomain -DomainId "yourdomain.onmicrosoft.com" `
    -PasswordValidityPeriodInDays 2147483647 `
    -PasswordNotificationWindowInDays 14
```

**Prerequisites:** MFA must be enforced for all users before disabling password expiration.

**Impact:**
- When passwords **don't expire**: Users create stronger passwords they can remember; MFA provides the security layer
- When passwords **expire**: Users tend to create weaker, predictable passwords (Password1!, Password2!, etc.)

---

## User Consent to Applications (CIS 5.1.5.1)

**CIS Control:** 5.1.5.1 (L2) - Ensure user consent to apps accessing company data on their behalf is not allowed

**Description:** Controls whether users can grant permissions to third-party applications to access organizational data. Unrestricted consent allows users to potentially grant malicious applications access to corporate resources.

**Recommended Value:** Allow user consent only for apps from **verified publishers** with **low-impact permissions**

**Management:**

```powershell
# Restrict user consent to verified publishers with low-impact permissions only
$consentBody = @{
    defaultUserRolePermissions = @{
        permissionGrantPoliciesAssigned = @(
            "managePermissionGrantsForSelf.microsoft-user-default-low"
        )
    }
}
Invoke-MgGraphRequest -Method PATCH `
    -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" `
    -Body $consentBody
```

**Options:**
| Setting | Description |
|---------|-------------|
| `microsoft-user-default-low` | Users can consent to verified publishers for low-impact permissions only |
| Do not allow user consent | All consent requires admin approval |

**Impact:**
- When **unrestricted**: Any user can grant apps access to their mailbox, files, etc. — high risk of consent phishing
- When **restricted**: Users can only consent to trusted apps; all others require admin approval

---

## Admin Consent Workflow (CIS 5.1.5.2)

**CIS Control:** 5.1.5.2 (L1) - Ensure the admin consent workflow is enabled

**Description:** When user consent is restricted, users need a way to request access to apps they need. The admin consent workflow provides a structured process for these requests.

**Recommended Value:** `Enabled`

**Management:**

```powershell
# Check current admin consent workflow status
Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy"

# Enable admin consent workflow
$adminConsentBody = @{
    isEnabled = $true
    notifyReviewers = $true
    remindersEnabled = $true
    requestDurationInDays = 30
}
Invoke-MgGraphRequest -Method PUT `
    -Uri "https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy" `
    -Body $adminConsentBody
```

**Manual Configuration:**
Navigate to: **Entra Admin Center** > Enterprise apps > Consent and permissions > Admin consent settings

---

## External Collaboration (Guest) Settings (CIS 5.1.6.3)

**CIS Control:** 5.1.6.3 (L2) - Ensure guest user invitations are limited to the Guest Inviter role

**Description:** Controls who can invite external guests to your organization. By default, all users can invite guests, which creates uncontrolled external access.

**Recommended Value:** `adminsAndGuestInviters` (Only admins and users with the Guest Inviter role)

**Management:**

```powershell
# Restrict guest invitations to admins and Guest Inviter role only
$extCollabBody = @{
    allowInvitesFrom = "adminsAndGuestInviters"
}
Invoke-MgGraphRequest -Method PATCH `
    -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" `
    -Body $extCollabBody
```

**Options:**
| Value | Description |
|-------|-------------|
| `everyone` | Anyone including guests can invite (least secure) |
| `everyoneExceptGuests` | All members can invite, but not guests |
| `adminsAndGuestInviters` | Only admins + Guest Inviter role (recommended) |
| `none` | No one can invite guests (most restrictive) |

---

## Unified Audit Logging (CIS 3.1.1 / 6.1.1)

**CIS Control:** 3.1.1 (L1) - Ensure Microsoft 365 audit log search is Enabled
*(Also referenced as CIS 6.1.1 — Ensure 'AuditDisabled' organizationally is set to 'False')*

**Description:** Unified audit logging records user and admin activity across Microsoft 365 services. This is critical for security monitoring, incident response, and compliance.

**Recommended Value:** `Enabled` (UnifiedAuditLogIngestionEnabled = $true)

**⚠️ Important:** Auditing is **NOT enabled by default** for Business Basic, Business Standard, and Business Premium licenses. It must be manually enabled.

**Management:**

```powershell
# Connect to Exchange Online
Connect-ExchangeOnline -ShowBanner:$false

# Check audit logging status
Get-AdminAuditLogConfig | Format-List UnifiedAuditLogIngestionEnabled

# Enable audit logging
Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true
```

**Impact:**
- When **Enabled**: All user/admin activities are recorded and searchable for 180 days (default)
- When **Disabled**: No audit trail — severely impacts incident response and compliance reporting

**Compliance Relevance:** Required for SOC 2, ISO 27001, HIPAA, GDPR, and virtually all compliance frameworks.

---

## External Email Forwarding (CIS 6.2.1)

**CIS Control:** 6.2.1 (L1) - Ensure all forms of mail forwarding are blocked and/or disabled

**Description:** Automatic email forwarding to external domains is a common data exfiltration technique. Attackers who compromise an account often set up forwarding rules to silently copy emails to external addresses.

**Recommended Value:** AutoForwardingMode = `Off` on all outbound spam filter policies

**Management:**

```powershell
# Check current auto-forwarding settings
Get-HostedOutboundSpamFilterPolicy | Select-Object Name, AutoForwardingMode

# Disable auto-forwarding on all outbound spam policies
Get-HostedOutboundSpamFilterPolicy | ForEach-Object {
    Set-HostedOutboundSpamFilterPolicy -Identity $_.Name -AutoForwardingMode Off
}

# Also disable on Default remote domain
Set-RemoteDomain -Identity Default -AutoForwardEnabled $false

# Check remote domain settings
Get-RemoteDomain | Select-Object DomainName, AutoForwardEnabled
```

**Impact:**
- When **Off**: Users cannot create inbox rules or mailbox forwarding to external addresses
- When **On**: Compromised accounts can silently exfiltrate email data

---

## Authenticated SMTP (CIS 6.5.4)

**CIS Control:** 6.5.4 (L1) - Ensure SMTP AUTH is disabled

**Description:** SMTP AUTH (Authenticated SMTP) is a legacy protocol that doesn't support modern authentication or Conditional Access policies. It should be disabled organization-wide unless specifically required for legacy applications.

**Recommended Value:** SmtpClientAuthenticationDisabled = `$true` (org-level + per-mailbox)

**Management:**

```powershell
# Disable SMTP AUTH at organization level
Set-TransportConfig -SmtpClientAuthenticationDisabled $true

# Verify
Get-TransportConfig | Select-Object SmtpClientAuthenticationDisabled

# Disable per-mailbox (safety net)
Get-CASMailbox -ResultSize Unlimited | Where-Object { $_.SmtpClientAuthenticationDisabled -ne $true } |
    ForEach-Object { Set-CASMailbox -Identity $_.Identity -SmtpClientAuthenticationDisabled $true }
```

---

## SharePoint & OneDrive Security (CIS 7.2.x)

### Legacy Authentication Protocols (CIS 7.2.1)

**CIS Control:** 7.2.1 (L1) - Ensure modern authentication for SharePoint applications is required

**Description:** Legacy auth protocols (e.g., older Office clients, third-party apps using basic auth) bypass Conditional Access and MFA.

**Recommended Value:** `isLegacyAuthProtocolsEnabled = false`

```powershell
# Check via Graph
$spo = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/admin/sharepoint/settings"
$spo.isLegacyAuthProtocolsEnabled  # Should be False

# Disable legacy auth
Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/admin/sharepoint/settings" `
    -Body @{ isLegacyAuthProtocolsEnabled = $false }
```

### External Sharing (CIS 7.2.3)

**CIS Control:** 7.2.3 (L1) - Ensure external content sharing is restricted

**Recommended Value:** `externalUserSharingOnly` (New and existing guests — requires authentication)

| Level | Value | Description |
|-------|-------|-------------|
| Most Open | `externalUserAndGuestSharing` | Anyone links (no authentication) |
| Recommended | `externalUserSharingOnly` | New and existing guests (requires sign-in) |
| Restrictive | `existingExternalUserSharingOnly` | Only guests already in directory |
| Most Secure | `disabled` | No external sharing |

```powershell
# Set sharing to authenticated guests only
Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/admin/sharepoint/settings" `
    -Body @{ sharingCapability = "externalUserSharingOnly" }
```

### Default Sharing Link Type (CIS 7.2.7 / 7.2.11)

**CIS Control:** 7.2.7 (L1) - Ensure link sharing is restricted in SharePoint and OneDrive
**CIS Control:** 7.2.11 (L1) - Ensure the SharePoint default sharing link permission is set

**Recommended Value:** `specificPeople`

```powershell
# Set default sharing link to Specific People (most restrictive)
Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/admin/sharepoint/settings" `
    -Body @{ defaultSharingLinkType = "specificPeople" }
```

---

## Release Preferences (Best Practice)

**Note:** In CIS v6.0, control 1.3.3 now covers External Calendar Sharing. Release preferences remain a security best practice but are no longer a specific numbered CIS control.

**Description:** Release preferences control how your organization receives Microsoft 365 feature updates. Targeted release for select users allows IT admins to preview and prepare for changes.

**Recommended Value:** `Targeted Release for select users` (add IT admins/helpdesk)

**Manual Configuration Required:**
Navigate to: **M365 Admin Center** > Settings > Org settings > Organization profile > **Release preferences**

**Options:**
| Option | Description |
|--------|-------------|
| Standard release | Updates released to all users simultaneously |
| Targeted release for everyone | All users get early access (risky for large orgs) |
| **Targeted release for select users** | **Recommended** — IT admins preview first |

**Note:** This setting cannot be configured via Graph API or PowerShell — manual action required.

---

## Idle Session Timeout (CIS 1.3.2)

**CIS Control:** 1.3.2 (L1) - Ensure 'Idle session timeout' is set to '3 hours (or less)' for unmanaged devices

**Description:** Configures automatic sign-out for inactive users accessing Microsoft 365 web apps. Prevents unauthorized access from unattended sessions.

**Recommended Value:** Sign out after **3 hours or less** of inactivity for unmanaged devices

**Manual Configuration Required:**

**Option A - M365 Admin Center:**
Navigate to: **M365 Admin Center** > Settings > Org settings > Security & privacy > **Idle session timeout**
- ✅ Enable "Sign out inactive users"
- Set timeout period (e.g., 1 hour)

**Option B - Conditional Access (more granular):**
Navigate to: **Entra Admin Center** > Identity > Protection > Conditional Access
- Create policy with Session controls > Sign-in frequency

```
Conditional Access Policy:
  Users: All users
  Cloud apps: Office 365
  Session: Sign-in frequency = 1 hour
```

---

## Customer Lockbox (CIS 1.3.6)

**CIS Control:** 1.3.6 (L2) - Ensure the customer lockbox feature is enabled

**Description:** Customer Lockbox ensures that Microsoft engineers cannot access your content without your explicit approval during support operations. This provides an additional layer of data sovereignty.

**Recommended Value:** `Enabled`

**License Required:** Microsoft 365 E5, E5 Compliance, or F5 Compliance add-on

**Manual Configuration Required:**
Navigate to: **M365 Admin Center** > Settings > Org settings > Security & privacy > **Customer lockbox**
- ✅ Check "Require approval for all data access requests"

**Note:** Not available on Business Standard/Premium licenses. If E5 is available, this should be enabled.

---

## Quick Reference: CIS M365 Benchmark Compliance

**Last Updated:** February 2026
**Benchmark:** CIS Microsoft 365 Foundations Benchmark v6.0.0

### Automated Settings (Applied by admincenterconfig.ps1)

<!-- INSERT IMAGE: Automated checks screenshot -->
![Automated CIS Checks](images/automated-checks-placeholder.png)

| CIS Control | Setting | Recommended | Status |
|-------------|---------|------------|--------|
| 1.3.1 (L1) | Password expiration | Never expire (with MFA) | ✅ Automated |
| 1.3.4 (L1) | Self-service purchases (27 products) | ❌ Disabled (all) | ✅ Automated |
| 3.1.1 / 6.1.1 | Unified audit logging | ✅ Enabled | ✅ Automated |
| 5.1.2.3 | Users can create tenants | ❌ Disabled | ✅ Automated |
| 5.1.5.1 (L2) | User consent to apps | Verified publishers only | ✅ Automated |
| 5.1.5.2 (L1) | Admin consent workflow | ✅ Enabled | ✅ Automated |
| 5.1.6.3 (L2) | Guest invitations | Admins + Guest Inviter only | ✅ Automated |
| 6.2.1 (L1) | External email forwarding | ❌ Blocked (Off) | ✅ Automated |
| 6.5.4 (L1) | Authenticated SMTP | ❌ Disabled | ✅ Automated |
| 7.2.1 (L1) | SharePoint modern auth | ✅ Required (legacy disabled) | ✅ Automated |
| 7.2.3 (L1) | SharePoint external sharing | Authenticated guests only | ✅ Automated |
| 7.2.7/7.2.11 (L1) | Default sharing link type | Specific People | ✅ Automated |
| — | Email-based subscriptions | ❌ Disabled | ✅ Automated |
| — | Email verified users can join | ❌ Disabled | ✅ Automated |
| — | Block legacy MSOL PowerShell | ✅ Enabled | ✅ Automated |
| — | Users can register apps | ❌ Disabled | ✅ Automated |
| — | Users can create security groups | ❌ Disabled | ✅ Automated |
| — | Users can read Bitlocker keys | ✅ Enabled | ✅ Automated |
| — | Users can read other users | ✅ Enabled | ✅ Automated |

### Manual Settings (Require Admin Center / Portal Configuration)

<!-- INSERT IMAGE: Manual checks screenshot -->
![Manual CIS Checks](images/manual-checks-placeholder.png)

| CIS Control | Setting | Recommended | Status |
|-------------|---------|------------|--------|
| 1.1.1 (L1) | Cloud-only admin accounts | All admin accounts cloud-only | ⚠️ Manual |
| 1.1.2 (L1) | Emergency access accounts | 2 break-glass accounts | ⚠️ Manual |
| 1.1.3 (L1) | Global admin count | Between 2 and 4 | ⚠️ Manual |
| 1.2.2 (L1) | Shared mailbox sign-in | ❌ Blocked | ⚠️ Manual |
| 1.3.2 (L1) | Idle session timeout | 3 hours or less | ⚠️ Manual |
| 1.3.3 (L2) | External calendar sharing | ❌ Disabled | ⚠️ Manual |
| 1.3.4 (L1) | User owned apps & services | ❌ Restricted | ⚠️ Manual |
| 1.3.5 (L1) | Forms phishing protection | ✅ Enabled | ⚠️ Manual |
| 1.3.6 (L2) | Customer Lockbox (E5 only) | ✅ Enabled | ⚠️ Manual |
| 1.3.7 (L2) | Third-party storage in M365 web | ❌ Disabled | ⚠️ Manual |
| 3.2.1/3.2.2 (L1) | DLP policies (incl. Teams) | Create for PII, financial, health | ⚠️ Manual |
| 3.3.1 (L1) | Sensitivity label policies | Published | ⚠️ Manual |
| 5.1.6.1/5.1.6.2 | Guest access & domain restrictions | Restricted | ⚠️ Manual |
| 5.2.2.1 (L1) | MFA for admin roles | ✅ CA policy | ⚠️ Manual |
| 5.2.2.2 (L1) | MFA for all users | ✅ CA policy | ⚠️ Manual |
| 5.2.2.3 (L1) | Block legacy authentication | ✅ CA policy | ⚠️ Manual |
| 5.2.2.5 (L2) | Phishing-resistant MFA for admins | ✅ CA policy | ⚠️ Manual |
| 8.2.2/8.2.3 (L1) | Teams external access | Restricted | ⚠️ Manual |
| 8.5.x (L1/L2) | Teams meeting settings | Restricted | ⚠️ Manual |
| — | Copilot agent settings | Restricted to security group | ⚠️ Manual |
| — | Release preferences | Targeted Release for select users | ⚠️ Manual |

**Legend:**
- ✅ Automated = Applied by `admincenterconfig.ps1`
- ⚠️ Manual = Requires manual configuration in admin center/portal
- L1 = Level 1 (essential baseline, minimal impact)
- L2 = Level 2 (defence-in-depth, may reduce functionality)

### Summary
- **19 automated settings** applied by script
- **22 manual settings** require portal configuration (expanded for v6.0)
- **12 CIS controls** directly automated
- **18+ CIS controls** documented for manual completion
- **0 critical security gaps** in automated controls

---

## Security & Governance Impact

### Critical Priority (CIS Automated)
- **Unified audit logging** (CIS 3.1.1/6.1.1) - Foundation for all security monitoring and compliance
- **External email forwarding disabled** (CIS 6.2.1) - Prevents data exfiltration via compromised accounts
- **User consent restricted** (CIS 5.1.5.1) - Prevents consent phishing attacks
- **SMTP AUTH disabled** (CIS 6.5.4) - Blocks legacy auth credential attacks
- **SharePoint modern auth required** (CIS 7.2.1) - Forces modern authentication

### High Priority (CIS Automated)
- **Self-service trials & purchases disabled** (CIS 1.3.4) - Prevents shadow IT
- **User app registration disabled** - Prevents unauthorized app access
- **Guest invitations restricted** (CIS 5.1.6.3) - Controls external access
- **Password never expires** (CIS 1.3.1) - Aligns with NIST 800-63B when MFA is enforced
- **SharePoint sharing restricted** (CIS 7.2.3) - Prevents anonymous external sharing

### High Priority (Manual Required)
- **MFA enforcement** (CIS 5.2.2.1/5.2.2.2) - Essential security control
- **Idle session timeout** (CIS 1.3.2) - Prevents unauthorized access from unattended sessions
- **Customer Lockbox** (CIS 1.3.6) - Data sovereignty during support operations
- **Cloud-only admin accounts** (CIS 1.1.1) - Prevents on-prem compromise escalation
- **Emergency access accounts** (CIS 1.1.2) - Break-glass for lockout scenarios
- **Block legacy authentication** (CIS 5.2.2.3) - Eliminates legacy auth attack vector

### Medium Priority
- **User owned apps & services** (CIS 1.3.4) - Prevent uncontrolled app installations
- **Forms phishing protection** (CIS 1.3.5) - Internal phishing prevention
- **Third-party storage** (CIS 1.3.7) - Prevent data leakage to external storage
- **Teams external access** (CIS 8.2.x) - Control Teams collaboration boundaries
- **DLP policies** (CIS 3.2.1/3.2.2) - Data protection
- **Copilot agent settings** - AI governance and control
- **Release preferences** - IT admin preview of changes

### Low Priority (Usually Enable)
- **Bitlocker key self-service** - Reduces helpdesk burden
- **Read other users** - Enables collaboration

---

## Compliance Considerations

### CIS Microsoft 365 Foundations Benchmark v6.0.0
This configuration addresses the following CIS benchmark sections:
- **Section 1** - Microsoft 365 Admin Center: Admin accounts (1.1.x), Groups/Mailboxes (1.2.x), Password policy (1.3.1), Session timeout (1.3.2), Calendar sharing (1.3.3), User owned apps (1.3.4), Forms (1.3.5), Lockbox (1.3.6), Third-party storage (1.3.7)
- **Section 3** - Auditing & Data Protection: Audit logging (3.1.1), DLP policies (3.2.x), Sensitivity labels (3.3.1)
- **Section 5** - Microsoft Entra ID: Tenant restrictions (5.1.2.3), Application consent (5.1.5.x), Guest access (5.1.6.x), Conditional Access/MFA (5.2.2.x)
- **Section 6** - Exchange Online: Audit logging (6.1.1), Forwarding (6.2.1), SMTP AUTH (6.5.4)
- **Section 7** - SharePoint/OneDrive: Modern auth (7.2.1), External sharing (7.2.3), Link sharing (7.2.7/7.2.11)
- **Section 8** - Microsoft Teams: External access (8.2.x), Meeting settings (8.5.x)

### Regulatory Alignment
- **NIST 800-63B:** Password policy (no expiration with MFA)
- **SOC 2 Type II:** Audit logging, access controls, change management
- **ISO 27001:** Information security management controls (A.9, A.12, A.13)
- **GDPR:** Data protection, access controls, audit trail
- **HIPAA:** Access controls (§164.312), audit controls (§164.312(b))
- **SOX:** Segregation of duties, approval workflows, audit trail

---

## Next Steps

### ✅ CIS Benchmark Security Settings Applied

**Script Coverage:** 19 automated settings across 15 CIS controls

**Automated Controls Applied:**
- ✅ Authorization policy (email subscriptions, verified users, MSOL block)
- ✅ Password expiration policy (NIST 800-63B aligned)
- ✅ User consent restricted to verified publishers
- ✅ Admin consent workflow enabled
- ✅ Guest invitations restricted to admin roles
- ✅ SMTP AUTH disabled (org-level + per-mailbox)
- ✅ Unified audit logging enabled
- ✅ External email forwarding blocked
- ✅ SharePoint legacy auth disabled
- ✅ SharePoint sharing restricted to authenticated guests
- ✅ Default sharing link set to Specific People
- ✅ Self-service purchases disabled (27 products)
- ✅ User permissions restricted (apps, groups, tenants)

**Manual Actions Remaining:**
- ⏭️ Configure release preferences (Targeted Release for select users)
- ⏭️ Enable idle session timeout (1 hour)
- ⏭️ Enable Customer Lockbox (if E5 licensed)
- ⏭️ Create DLP policies in Microsoft Purview
- ⏭️ Verify MFA enforcement (Security Defaults or Conditional Access)
- ⏭️ Configure user owned apps & services
- ⏭️ Review Copilot agent settings
- ⏭️ Review external calendar sharing

### Documentation Tasks
1. ✅ Export completed (January 17, 2026)
2. ✅ Configuration reviewed against CIS M365 Benchmark v6.0.0
3. ✅ Applied CIS-aligned security hardening (February 2026)
4. ✅ Updated to CIS Microsoft 365 Foundations Benchmark v6.0.0
5. ⏭️ Complete manual configuration items (18 items)
6. ⏭️ Re-export configuration to verify changes
6. ⏭️ Document in change management system
7. ⏭️ Include in master IAC documentation
8. ⏭️ Schedule periodic CIS benchmark re-assessment (quarterly)

---

## Security Best Practices: Why These Two Settings Matter

### 🔒 Why Block Legacy MSOL PowerShell (MSOnline Module)

**Security & Compliance Reasons:**

1. **Deprecated Authentication Methods**
   - MSOL uses legacy authentication protocols that don't support modern security features
   - No support for Conditional Access policies during authentication
   - Cannot enforce Multi-Factor Authentication (MFA) requirements
   - Lacks certificate-based authentication options

2. **Limited Security Controls**
   - No support for Privileged Identity Management (PIM)
   - Cannot leverage Azure AD Identity Protection risk detections
   - Missing audit logging capabilities available in Microsoft Graph
   - No support for Continuous Access Evaluation (CAE)

3. **Operational Risk**
   - Microsoft has officially deprecated the MSOnline module
   - No new features or security updates being developed
   - Will eventually be retired completely by Microsoft
   - Scripts using MSOL will break without warning when service ends

4. **Compliance & Audit Trail**
   - Limited logging compared to Microsoft Graph API calls
   - Harder to track who did what and when
   - Insufficient detail for compliance audits (SOX, ISO 27001, etc.)
   - Cannot differentiate between automated scripts and interactive sessions

5. **Zero Trust Architecture Incompatibility**
   - Zero Trust requires continuous verification of identity and device state
   - MSOL's authentication model doesn't align with Zero Trust principles
   - Modern Graph API supports identity-driven security controls

**Migration Path:** Microsoft Graph PowerShell provides all MSOL functionality plus modern security features. Blocking MSOL forces adoption of better security practices.

**Real-World Impact:** Organizations that don't block MSOL often have:
- Service accounts using stored credentials with no MFA
- Scripts running with excessive permissions
- No visibility into automated operations
- Higher risk of credential compromise

---

### 🚪 Why Disable "Allow Email Verified Users to Join Organization"

**Security & Identity Governance Reasons:**

1. **Uncontrolled External Access**
   - When enabled, anyone with a verified email address (Gmail, Yahoo, Hotmail, etc.) can request to join your organization
   - Creates a backdoor for unauthorized access attempts
   - IT has no advance control over who can even request access
   - Increases attack surface for social engineering

2. **Identity & Access Management (IAM) Bypass**
   - Circumvents your formal user provisioning process
   - Users gain access before proper background checks or approval workflows
   - Breaks integration with HR systems and automated provisioning
   - Creates "shadow accounts" outside normal user lifecycle management

3. **Guest vs Member Confusion**
   - Users added through email verification often have incorrect account types
   - May receive higher privileges than intended (Member instead of Guest)
   - Difficult to audit and track these "self-invited" accounts
   - Compliance frameworks require formal approval for all access

4. **Data Exfiltration Risk**
   - Malicious actors can use this to gain initial foothold
   - Once in, they can potentially access shared resources
   - Can use insider position to conduct reconnaissance
   - Harder to detect as they appear as "legitimate" joined users

5. **Regulatory Compliance Issues**
   - GDPR: Cannot properly validate data processing lawful basis
   - HIPAA: Violates access control requirements (§164.312(a)(1))
   - SOX: Lacks segregation of duties and approval controls
   - ISO 27001: Fails access control policy requirements

6. **License & Cost Impact**
   - Self-joined users may automatically consume licenses
   - No budget approval or cost center assignment
   - Can lead to unexpected Azure AD Premium consumption
   - Difficult to charge back to proper departments

**Proper Alternative:** Use Azure AD B2B guest invitations where:
- IT/managers explicitly invite external users
- Access is time-limited and purpose-specific
- Full audit trail of who invited whom and why
- Automatic expiration and periodic access reviews

**Real-World Attack Scenario:**
1. Attacker identifies your domain (company.com)
2. Attacker creates realistic external email (john.smith.contractor@gmail.com)
3. Attacker requests to join using company knowledge from LinkedIn/website
4. If approved manually without verification, attacker gains initial access
5. Attacker explores shared resources, Teams channels, SharePoint sites
6. Lateral movement to more sensitive resources using social engineering

**Best Practice:** Keep this disabled and use formal invitation-based processes for all external collaboration. Every user account should be traceable to a formal business justification and approval.

---

## References

- [CIS Microsoft 365 Foundations Benchmark v6.0.0](https://www.cisecurity.org/benchmark/microsoft_365)
- [NIST SP 800-63B Digital Identity Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [Microsoft 365 admin center documentation](https://learn.microsoft.com/microsoft-365/admin/)
- [Manage self-service purchases](https://learn.microsoft.com/microsoft-365/commerce/subscriptions/manage-self-service-purchases-admins)
- [Authorization policy in Azure AD](https://learn.microsoft.com/graph/api/resources/authorizationpolicy)
- [MSCommerce PowerShell module](https://www.powershellgallery.com/packages/MSCommerce)
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/powershell/microsoftgraph/)
- [Retirement of MSOnline and AzureAD PowerShell modules](https://techcommunity.microsoft.com/t5/microsoft-entra-azure-ad-blog/important-azure-ad-graph-retirement-and-powershell-module/ba-p/3848270)
- [Azure AD B2B collaboration](https://learn.microsoft.com/azure/active-directory/external-identities/what-is-b2b)
- [Zero Trust security model](https://learn.microsoft.com/security/zero-trust/)
- [Configure user consent to applications](https://learn.microsoft.com/entra/identity/enterprise-apps/configure-user-consent)
- [Configure admin consent workflow](https://learn.microsoft.com/entra/identity/enterprise-apps/configure-admin-consent-workflow)
- [Turn auditing on or off](https://learn.microsoft.com/purview/audit-log-enable-disable)
- [Control automatic external email forwarding](https://learn.microsoft.com/defender-office-365/outbound-spam-policies-external-email-forwarding)
- [Manage sharing settings for SharePoint](https://learn.microsoft.com/sharepoint/turn-external-sharing-on-or-off)
- [Set password expiration policy](https://learn.microsoft.com/microsoft-365/admin/manage/set-password-expiration-policy)
- [Release options in Microsoft 365](https://learn.microsoft.com/microsoft-365/admin/manage/release-options-in-office-365)
- [Customer Lockbox](https://learn.microsoft.com/purview/customer-lockbox-requests)
