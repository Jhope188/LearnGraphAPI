# M365 Admin Center — Security Hardening & Branding Walkthrough

> **Author:** Jon Hope
> **Last Updated:** April 2026
> **Applies To:** Microsoft 365 commercial tenants (Business Standard, E3, E5)
> **Benchmark Reference:** CIS Microsoft 365 Foundations Benchmark v6

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Part 1 — Org Settings Security Baseline](#part-1--org-settings-security-baseline)
   - 1.1 Organization Technical Contact
   - 1.2 Guest User Directory Access
   - 1.3 Conceal Names in Reports
   - 1.4 Idle Session Timeout
   - 1.5 Modern Authentication / Disable Basic Auth
3. [Part 2 — Authorization Policy Controls](#part-2--authorization-policy-controls)
   - 2.1 Block Email-Based Self-Service Subscriptions
   - 2.2 Block Email Verified Users Joining Org
   - 2.3 Block Legacy MSOL PowerShell
4. [Part 3 — Exchange Online Calendar Sharing](#part-3--exchange-online-calendar-sharing)
5. [Part 4 — Self-Service Purchase Policies](#part-4--self-service-purchase-policies)
6. [Part 5 — Default User Role Permissions](#part-5--default-user-role-permissions)
7. [Part 6 — Company Branding & Phishing Defense](#part-6--company-branding--phishing-defense)
   - 6.1 Entra ID Company Branding (Sign-in Page)
   - 6.2 M365 Admin Center Custom Theme (Suite Header)
8. [Compliance Summary](#8-compliance-summary)

---

## 1. Prerequisites

### Required PowerShell Modules

Install all required modules before running any scripts in this guide. Run the following from an elevated PowerShell session:

```powershell
# Install required modules (run once, elevated PowerShell)
Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
Install-Module MSCommerce -Scope CurrentUser -Force

# Verify installations
Get-Module Microsoft.Graph -ListAvailable | Select-Object Name, Version | Sort-Object Version -Descending | Select-Object -First 1
Get-Module ExchangeOnlineManagement -ListAvailable | Select-Object Name, Version | Sort-Object Version -Descending | Select-Object -First 1
Get-Module MSCommerce -ListAvailable | Select-Object Name, Version | Sort-Object Version -Descending | Select-Object -First 1
```

### Required Admin Roles

| Task Area | Minimum Required Role |
|---|---|
| Authorization Policy, User Role Permissions | Global Administrator or Privileged Role Administrator |
| Exchange Online Calendar Sharing | Exchange Administrator |
| Self-Service Purchase Policies | Billing Administrator or Global Administrator |
| Entra ID Company Branding | Organizational Branding Administrator |
| M365 Admin Center Custom Theme | Global Administrator |
| Reports Privacy Settings | Global Administrator or Reports Reader |

### Required Graph Scopes

The scripts in this guide collectively require the following Microsoft Graph scopes:

```
Policy.ReadWrite.Authorization
Organization.ReadWrite.All
ReportSettings.ReadWrite.All
Directory.ReadWrite.All
```

### Base Connection Helper

Use this helper at the start of each PowerShell section to establish a properly scoped Graph session:

```powershell
# ── Base Connection Helper ──────────────────────────────────────────────────
function Connect-AdminCenter {
    param(
        [string[]]$Scopes = @(
            "Policy.ReadWrite.Authorization",
            "Organization.ReadWrite.All",
            "ReportSettings.ReadWrite.All",
            "Directory.ReadWrite.All"
        )
    )
    Write-Host "[*] Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
    $context = Get-MgContext
    Write-Host "[+] Connected as: $($context.Account)" -ForegroundColor Green
    Write-Host "[+] Tenant ID: $($context.TenantId)" -ForegroundColor Green
    return $context
}

$ctx = Connect-AdminCenter
$OrgId = (Get-MgOrganization).Id
```

---

## Part 1 — Org Settings Security Baseline

These settings are configured in the Microsoft 365 Admin Center at **Settings → Org settings**.

---

### 1.1 Organization Technical Contact

| Property | Value |
|---|---|
| **Location** | Settings → Org settings → Organization profile → Organization information |
| **CIS Control** | No direct CIS mapping — operational security baseline |
| **Risk if Misconfigured** | Security alerts, breach notifications, and service health advisories from Microsoft go unread if this points to an unmonitored or personal mailbox |

**Why this matters:** Microsoft sends critical security and compliance alerts to the technical contact address. This must be a shared, monitored mailbox — not a personal account. If a breach notification arrives at a departed employee's inbox, your response window is lost.

#### UI Walkthrough

1. Navigate to [admin.microsoft.com](https://admin.microsoft.com) → **Settings** → **Org settings**
2. Select the **Organization profile** tab → **Organization information**
3. Verify the **Technical contact** field contains a monitored shared mailbox (e.g., `it-security@contoso.com`)
4. Click **Save**

#### PowerShell — Verify & Set Technical Contact

```powershell
# ── 1.1 Organization Technical Contact ─────────────────────────────────────
Connect-MgGraph -Scopes "Organization.ReadWrite.All" -NoWelcome
$OrgId = (Get-MgOrganization).Id

# Read current value
$org = Get-MgOrganization
Write-Host "`n[Current] Technical Contact: $($org.TechnicalNotificationMails -join ', ')" -ForegroundColor Yellow

# Set technical contact (replace with your monitored shared mailbox)
$newContact = "it-security@contoso.com"

Update-MgOrganization -OrganizationId $OrgId -BodyParameter @{
    technicalNotificationMails = @($newContact)
}

# Verify
$updated = Get-MgOrganization
if ($updated.TechnicalNotificationMails -contains $newContact) {
    Write-Host "[+] PASS: Technical contact set to $newContact" -ForegroundColor Green
} else {
    Write-Host "[!] FAIL: Technical contact was not updated as expected" -ForegroundColor Red
}

Disconnect-MgGraph
```

---

### 1.2 Guest User Directory Access

| Property | Value |
|---|---|
| **Location** | Settings → Org settings → Security & privacy → Sharing |
| **Setting** | Let guest users access the directory |
| **Recommended Value** | Disabled (unchecked) |
| **Risk if Enabled** | Guest accounts — including compromised ones — can enumerate users, groups, and org structure, enabling reconnaissance attacks |

**Why this matters:** Guest users with directory read access can map your organisation structure, identify high-value targets (executives, privileged admins), and enumerate groups before escalating access or launching spear-phishing campaigns. The principle of least privilege demands that guests see only what they need for their specific collaboration purpose.

#### UI Walkthrough

1. Navigate to **Settings** → **Org settings** → **Security & privacy**
2. Select **Sharing**
3. Ensure **Let guest users access the directory** is **unchecked**
4. Click **Save**

#### PowerShell — Restrict Guest Directory Access

This setting maps to the `guestUserRoleId` in the Entra ID authorization policy. Three tiers are available:

| Role ID | Access Level | Recommendation |
|---|---|---|
| `10dae51f-b6af-4016-8d66-8c2a99b929b3` | Same access as members (most permissive) | ❌ Avoid |
| `2af84b1e-32c8-42b7-82bc-daa82404023b` | Limited access to directory properties and memberships | ⚠️ Minimum acceptable |
| `2d2d1f73-5a06-4d65-9f9e-6bcb6b4e3f99` | Restricted to own objects only (most restrictive) | ✅ Recommended |

```powershell
# ── 1.2 Guest User Directory Access ────────────────────────────────────────
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization" -NoWelcome

# Role IDs
$GuestMemberAccess   = "10dae51f-b6af-4016-8d66-8c2a99b929b3"  # Most permissive — do not use
$GuestLimitedAccess  = "2af84b1e-32c8-42b7-82bc-daa82404023b"   # Minimum acceptable
$GuestRestrictedRole = "2d2d1f73-5a06-4d65-9f9e-6bcb6b4e3f99"  # RECOMMENDED

# Read current setting
$authPolicy = Get-MgPolicyAuthorizationPolicy
Write-Host "`n[Current] Guest User Role ID: $($authPolicy.GuestUserRoleId)" -ForegroundColor Yellow

# Apply most restrictive guest access
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    guestUserRoleId = $GuestRestrictedRole
}

# Verify
$updated = Get-MgPolicyAuthorizationPolicy
if ($updated.GuestUserRoleId -eq $GuestRestrictedRole) {
    Write-Host "[+] PASS: Guest directory access set to Restricted (own objects only)" -ForegroundColor Green
} else {
    Write-Host "[!] FAIL: Guest role ID not updated as expected. Current: $($updated.GuestUserRoleId)" -ForegroundColor Red
}

Disconnect-MgGraph
```

---

### 1.3 Conceal User, Group & Site Names in Reports

| Property | Value |
|---|---|
| **Location** | Settings → Org settings → Services → Reports |
| **Setting** | Display concealed user, group, and site names in all reports |
| **Recommended Value** | Enabled (concealed) |
| **CIS Control** | CIS M365 v3.1.0 — 1.3.6 |

**Why this matters:** Microsoft 365 Usage Reports default to displaying real user display names. Any admin or delegated access to the Reports section can correlate individuals' mailbox usage, Teams activity, and file access patterns. Enabling concealment replaces names with anonymised identifiers, enforcing data minimisation and reducing insider threat exposure from report viewers.

#### UI Walkthrough

1. Navigate to **Settings** → **Org settings** → **Services**
2. Select **Reports**
3. Check **Display concealed user, group, and site names in all reports**
4. Click **Save**

#### PowerShell — Enable Report Concealment

```powershell
# ── 1.3 Conceal Names in Reports ───────────────────────────────────────────
Connect-MgGraph -Scopes "ReportSettings.ReadWrite.All" -NoWelcome

# Read current setting
$reportSettings = Get-MgAdminReportSetting
Write-Host "`n[Current] Display Concealed Names: $($reportSettings.DisplayConcealedNames)" -ForegroundColor Yellow

# Enable concealment
# Note: -DisplayConcealedNames is a SwitchParameter; use -BodyParameter for explicit boolean control
Update-MgAdminReportSetting -BodyParameter @{ displayConcealedNames = $true }

# Verify
$updated = Get-MgAdminReportSetting
if ($updated.DisplayConcealedNames -eq $true) {
    Write-Host "[+] PASS: Report names are now concealed" -ForegroundColor Green
} else {
    Write-Host "[!] FAIL: Concealment setting was not applied. Current: $($updated.DisplayConcealedNames)" -ForegroundColor Red
}

Disconnect-MgGraph
```

---

### 1.4 Idle Session Timeout

| Property | Value |
|---|---|
| **Location** | Settings → Org settings → Security & privacy → Idle session timeout |
| **Recommended Value** | **3 hours** (or less) |
| **CIS Control** | CIS M365 v3.1.0 — 5.2.2.3 (L1) |
| **Applies To** | Unmanaged / non-Intune-enrolled devices using M365 web apps |

**Why this matters:** Shared or public devices where users forget to sign out leave active session tokens exposed for the duration of the browser session. A 3-hour idle timeout forces re-authentication on all M365 web apps (Outlook Web, SharePoint, OneDrive, Teams web) and significantly reduces the window for session hijacking attacks. Note: this setting applies only to web app sessions on unmanaged devices — Conditional Access session controls provide a more comprehensive enforcement mechanism for managed device scenarios.

> **⚠️ Note:** Idle session timeout via the Admin Center UI applies broadly to unmanaged device web sessions. For managed devices, use Conditional Access Sign-in Frequency policies in Entra ID for finer-grained control.

#### UI Walkthrough

1. Navigate to **Settings** → **Org settings** → **Security & privacy**
2. Select **Idle session timeout**
3. Check **Turn on to set the period of inactivity for users to be signed off of Microsoft 365 web apps**
4. Set **When do you want users signed out?** to **3 hours**
5. Click **Save**

#### PowerShell — Configure Idle Session Timeout

The idle session timeout policy is managed via an Activity-Based Timeout Policy in Microsoft Graph.

```powershell
# ── 1.4 Idle Session Timeout ────────────────────────────────────────────────
Connect-MgGraph -Scopes "Policy.ReadWrite.ApplicationConfiguration" -NoWelcome

# Check for existing activity-based timeout policy
$existingPolicies = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/policies/activityBasedTimeoutPolicies"

Write-Host "`n[Current] Activity-Based Timeout Policies:" -ForegroundColor Yellow
$existingPolicies.value | ForEach-Object {
    Write-Host "  - Name: $($_.displayName) | Definition: $($_.definition -join ', ')"
}

# Define 3-hour idle timeout policy (ISO 8601 duration: PT3H)
# The definition JSON controls sign-in frequency per application type
$policyDefinition = @'
[{
  "ActivityBasedTimeoutPolicy": {
    "Version": 1,
    "ApplicationPolicies": [
      {
        "ApplicationId": "default",
        "WebSessionIdleTimeout": "PT03H00M"
      }
    ]
  }
}]
'@

if ($existingPolicies.value.Count -eq 0) {
    # Create new policy
    $body = @{
        displayName   = "M365 Web App Idle Session Timeout - 3 Hours"
        isOrganizationDefault = $true
        definition    = @($policyDefinition)
    }
    $created = Invoke-MgGraphRequest -Method POST `
        -Uri "https://graph.microsoft.com/v1.0/policies/activityBasedTimeoutPolicies" `
        -Body ($body | ConvertTo-Json -Depth 5) `
        -ContentType "application/json"
    Write-Host "[+] PASS: Idle session timeout policy created (3 hours)" -ForegroundColor Green
} else {
    Write-Host "[i] INFO: Existing policy found — review and update via Admin Center UI to ensure 3-hour value is set" -ForegroundColor Cyan
    Write-Host "    Recommended: Verify via Settings → Org Settings → Security & Privacy → Idle session timeout" -ForegroundColor Cyan
}

Disconnect-MgGraph
```

> **Best Practice:** Pair the 3-hour idle timeout with a **Conditional Access Sign-in Frequency policy** of 4–8 hours for managed devices (via Entra ID → Protection → Conditional Access) for consistent enforcement across web and native app sessions.

---

### 1.5 Modern Authentication / Disable Basic Authentication

| Property | Value |
|---|---|
| **Location** | Settings → Org settings → Services → Modern authentication |
| **Policy** | Enable modern authentication; disable all basic auth protocols |
| **CIS Control** | CIS M365 v3.1.0 — 1.2 (L1) |
| **Target State** | "Migration Complete" in Admin Center UI |

**Why this matters:** Basic authentication transmits credentials with every request and does not support MFA or Conditional Access. Password spray and credential stuffing attacks almost universally exploit basic auth. Disabling it forces OAuth 2.0 (modern auth) across all clients, enabling MFA enforcement and token-based flows that Conditional Access can govern.

> **⚠️ Pre-check before disabling:** Review Entra ID Sign-in Logs → filter by **"Legacy authentication"** client app type. Confirm no active users or service accounts rely on legacy protocols. Pay particular attention to SMTP Auth (used by legacy printers, MFDs, and line-of-business applications).

#### Protocol Disable Reference

| Protocol | Purpose | Target State |
|---|---|---|
| Authenticated SMTP | Legacy printer/LOB app mail sending | ❌ Disabled |
| Exchange ActiveSync (EAS) | Legacy mobile mail sync | ❌ Disabled |
| AutoDiscover (Basic) | Legacy Outlook auto-config | ❌ Disabled |
| IMAP4 | Legacy IMAP retrieval | ❌ Disabled |
| POP3 | Legacy POP retrieval | ❌ Disabled |
| MAPI over HTTP | Legacy Outlook desktop | ❌ Disabled |
| Outlook Anywhere (RPC over HTTP) | Legacy Outlook remote | ❌ Disabled |
| Exchange Web Services (EWS) | Legacy programmatic mailbox access | ❌ Disabled |
| Remote PowerShell | Legacy Exchange management | ❌ Disabled |

#### UI Walkthrough

1. Navigate to **Settings** → **Org settings** → **Services**
2. Select **Modern authentication**
3. Ensure **Turn on modern authentication for Outlook 2013 for Windows and later** is ✅ checked
4. **Uncheck every basic authentication protocol** listed below the warning banner
5. Click **Save**
6. Verify the compliance status reads **"Migration Complete"**

#### PowerShell — Disable All Basic Auth (Exchange Online)

```powershell
# ── 1.5 Modern Authentication / Disable Basic Auth ─────────────────────────
# Pre-check: Identify any accounts still using legacy auth
Connect-ExchangeOnline -ShowBanner:$false

Write-Host "`n[*] Checking existing authentication policies..." -ForegroundColor Cyan
$existingPolicies = Get-AuthenticationPolicy
$existingPolicies | Select-Object Name, AllowBasicAuthActiveSync, AllowBasicAuthSmtp | Format-Table -AutoSize

# Create a block-all basic auth policy
$policyName = "BlockAllBasicAuth"

$existingBlock = Get-AuthenticationPolicy -Identity $policyName -ErrorAction SilentlyContinue

if (-not $existingBlock) {
    New-AuthenticationPolicy -Name $policyName `
        -AllowBasicAuthActiveSync:$false `
        -AllowBasicAuthAutodiscover:$false `
        -AllowBasicAuthImap:$false `
        -AllowBasicAuthMapi:$false `
        -AllowBasicAuthOfflineAddressBook:$false `
        -AllowBasicAuthOutlookService:$false `
        -AllowBasicAuthPop:$false `
        -AllowBasicAuthReportingWebServices:$false `
        -AllowBasicAuthRest:$false `
        -AllowBasicAuthRpc:$false `
        -AllowBasicAuthSmtp:$false `
        -AllowBasicAuthWebServices:$false `
        -AllowBasicAuthPowershell:$false
    Write-Host "[+] Policy '$policyName' created successfully" -ForegroundColor Green
} else {
    Write-Host "[i] Policy '$policyName' already exists — updating all AllowBasicAuth parameters to False" -ForegroundColor Cyan
    Set-AuthenticationPolicy -Identity $policyName `
        -AllowBasicAuthActiveSync:$false `
        -AllowBasicAuthAutodiscover:$false `
        -AllowBasicAuthImap:$false `
        -AllowBasicAuthMapi:$false `
        -AllowBasicAuthOfflineAddressBook:$false `
        -AllowBasicAuthOutlookService:$false `
        -AllowBasicAuthPop:$false `
        -AllowBasicAuthReportingWebServices:$false `
        -AllowBasicAuthRest:$false `
        -AllowBasicAuthRpc:$false `
        -AllowBasicAuthSmtp:$false `
        -AllowBasicAuthWebServices:$false `
        -AllowBasicAuthPowershell:$false
}

# Set as organization default
Set-OrganizationConfig -DefaultAuthenticationPolicy $policyName
Write-Host "[+] Set '$policyName' as organization default authentication policy" -ForegroundColor Green

# Verification
Write-Host "`n[*] Verifying policy settings..." -ForegroundColor Cyan
$verifyPolicy = Get-AuthenticationPolicy -Identity $policyName
$basicAuthProps = $verifyPolicy | Select-Object AllowBasicAuth*

$anyEnabled = $false
$basicAuthProps.PSObject.Properties | ForEach-Object {
    if ($_.Value -eq $true) {
        Write-Host "[!] WARN: $($_.Name) is still ENABLED" -ForegroundColor Red
        $anyEnabled = $true
    }
}
if (-not $anyEnabled) {
    Write-Host "[+] PASS: All basic authentication protocols are disabled" -ForegroundColor Green
}

# Verify org default
$orgConfig = Get-OrganizationConfig
Write-Host "[+] Org Default Auth Policy: $($orgConfig.DefaultAuthenticationPolicy)" -ForegroundColor Green

Disconnect-ExchangeOnline -Confirm:$false
```

---

## Part 2 — Authorization Policy Controls

These settings control tenant-wide user self-service capabilities and are managed via the Microsoft Graph authorization policy.

---

### 2.1 Block Email-Based Self-Service Subscriptions

| Property | Value |
|---|---|
| **Graph Property** | `allowedToSignUpEmailBasedSubscriptions` |
| **Recommended Value** | `False` (Disabled) |
| **Risk if Enabled** | Users can independently sign up for Microsoft service trials using their corporate email, creating ungoverned data processing agreements and potential shadow IT |

**Why this matters:** When users can independently spin up Power Platform trials or other Microsoft cloud trials, they create tenancy relationships and data flows outside IT governance. Shadow subscriptions generate compliance exposure, particularly under data residency and sovereignty requirements.

#### PowerShell — Disable Email-Based Subscriptions

```powershell
# ── 2.1 Email-Based Self-Service Subscriptions ─────────────────────────────
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization" -NoWelcome

# Read current value
$authPolicy = Get-MgPolicyAuthorizationPolicy
Write-Host "`n[Current] AllowedToSignUpEmailBasedSubscriptions: $($authPolicy.AllowedToSignUpEmailBasedSubscriptions)" -ForegroundColor Yellow

# Disable self-service email subscriptions
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    allowedToSignUpEmailBasedSubscriptions = $false
}

# Verify
$updated = Get-MgPolicyAuthorizationPolicy
if ($updated.AllowedToSignUpEmailBasedSubscriptions -eq $false) {
    Write-Host "[+] PASS: Email-based self-service subscriptions are disabled" -ForegroundColor Green
} else {
    Write-Host "[!] FAIL: Setting did not apply. Current value: $($updated.AllowedToSignUpEmailBasedSubscriptions)" -ForegroundColor Red
}
```

---

### 2.2 Block Email Verified Users Joining the Organisation

| Property | Value |
|---|---|
| **Graph Property** | `allowEmailVerifiedUsersToJoinOrganization` |
| **Recommended Value** | `False` (Disabled) |
| **Risk if Enabled** | Any user with a verified email address can request to join your tenant, bypassing invite-based governance |

**Why this matters:** Uncontrolled tenant join introduces the risk of external parties gaining access to shared resources without going through the formal B2B invitation and approval process. This should be locked down in virtually all enterprise environments.

#### PowerShell — Block Unverified Join

```powershell
# ── 2.2 Block Email Verified Users Joining Org ─────────────────────────────

# Read current value
$authPolicy = Get-MgPolicyAuthorizationPolicy
Write-Host "`n[Current] AllowEmailVerifiedUsersToJoinOrganization: $($authPolicy.AllowEmailVerifiedUsersToJoinOrganization)" -ForegroundColor Yellow

# Disable the capability
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    allowEmailVerifiedUsersToJoinOrganization = $false
}

# Verify
$updated = Get-MgPolicyAuthorizationPolicy
if ($updated.AllowEmailVerifiedUsersToJoinOrganization -eq $false) {
    Write-Host "[+] PASS: Email-verified users cannot self-join the organisation" -ForegroundColor Green
} else {
    Write-Host "[!] FAIL: Setting did not apply. Current value: $($updated.AllowEmailVerifiedUsersToJoinOrganization)" -ForegroundColor Red
}
```

---

### 2.3 Block Legacy MSOL PowerShell

| Property | Value |
|---|---|
| **Graph Property** | `blockMsolPowerShell` |
| **Recommended Value** | `True` (Block legacy module) |
| **Note** | Not configurable via Admin Center UI — Graph API / PowerShell only |

**Why this matters:** The legacy MSOnline (MSOL) module uses deprecated Azure AD authentication flows and lacks support for modern Graph-based security features. Blocking it forces all administrative operations through Microsoft Graph PowerShell, which supports Entra Conditional Access, Privileged Identity Management (PIM) just-in-time access, and modern audit logging.

#### PowerShell — Block Legacy MSOL

```powershell
# ── 2.3 Block Legacy MSOL PowerShell ───────────────────────────────────────
# Note: re-uses the Graph session from 2.1/2.2 if still active

# Read current value
$authPolicy = Get-MgPolicyAuthorizationPolicy
Write-Host "`n[Current] BlockMsolPowerShell: $($authPolicy.BlockMsolPowerShell)" -ForegroundColor Yellow

# Block legacy MSOL
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    blockMsolPowerShell = $true
}

# Verify
$updated = Get-MgPolicyAuthorizationPolicy
$blockValue = $updated.AdditionalProperties["blockMsolPowerShell"]
if ($blockValue -eq $true) {
    Write-Host "[+] PASS: Legacy MSOL PowerShell is blocked" -ForegroundColor Green
} else {
    Write-Host "[i] INFO: Value is '$blockValue'. Confirm via Entra admin center → Users → User settings → 'Restrict access to Microsoft Entra administration portal'" -ForegroundColor Cyan
}

Disconnect-MgGraph
```

> **Note:** The `blockMsolPowerShell` property is returned inside `AdditionalProperties` in some SDK versions. Use `Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy"` to inspect the raw JSON response if the verification step above returns null.

---

## Part 3 — Exchange Online Calendar Sharing

| Property | Value |
|---|---|
| **Location** | M365 Admin Center → Settings → Org settings → Calendar |
| **Risk Profile** | Information disclosure — meeting patterns, free/busy times, potentially sensitive meeting titles |
| **Default State** | External calendar sharing with Office 365/Exchange orgs enabled — requires intentional decision |

**Why this matters:** Calendar information reveals organisational patterns: who meets with whom, executive availability, project timelines, and meeting subject lines. Even free/busy data can be leveraged for social engineering ("I know you're free Thursday at 2pm — can we jump on a call?"). Anonymous calendar publishing is the highest-risk variant and should be disabled entirely except where explicitly required.

**Decision Matrix:**

| Sharing Type | Risk Level | Recommendation |
|---|---|---|
| Anonymous link publishing | 🔴 High | Disable entirely |
| Federated sharing (free/busy only) | 🟡 Moderate | Allow only if business-required |
| Federated sharing (full details) | 🔴 High | Disable |
| Per-user calendar permissions | 🟢 Low | Allow (user-controlled) |

#### UI Walkthrough

1. Navigate to **Settings** → **Org settings**
2. Select the **Services** tab → **Calendar**
3. Review sharing options:
   - For **Let your users share their calendars with people outside of your organization who have Office 365 or Exchange**: set to **Calendar free/busy information with time only** as maximum, or disable entirely
   - For **Let your users share their calendars with people outside of your organization**: disable unless explicitly required
4. Click **Save**

#### PowerShell — Audit & Restrict Calendar Sharing

```powershell
# ── Part 3: Exchange Online Calendar Sharing ────────────────────────────────
Connect-ExchangeOnline -ShowBanner:$false

Write-Host "`n[*] Auditing current calendar sharing policies..." -ForegroundColor Cyan

# Get all sharing policies
$sharingPolicies = Get-SharingPolicy
$defaultPolicy   = $sharingPolicies | Where-Object { $_.Default -eq $true }

Write-Host "`n[Current] Default Sharing Policy: $($defaultPolicy.Name)" -ForegroundColor Yellow
Write-Host "[Current] Domains configured:"
$defaultPolicy.Domains | ForEach-Object { Write-Host "  - $_" }

# Check for anonymous or high-privilege sharing
$riskyDomains = $defaultPolicy.Domains | Where-Object {
    $_ -like "*Anonymous*" -or $_ -like "*CalendarSharingFreeBusyDetail*"
}

if ($riskyDomains) {
    Write-Host "`n[!] HIGH RISK: Anonymous or detailed calendar sharing is enabled" -ForegroundColor Red
    $riskyDomains | ForEach-Object { Write-Host "    Risky domain entry: $_" -ForegroundColor Red }
} else {
    Write-Host "[+] No anonymous calendar sharing domains detected" -ForegroundColor Green
}

# Get organization-level federation
$orgConfig = Get-OrganizationConfig
Write-Host "`n[Info] Org Federation Config:"
Write-Host "  - IsDehydrated: $($orgConfig.IsDehydrated)"

# Restrict default policy to free/busy time only (no subject/location)
# CalendarSharingFreeBusySimple = free/busy time only (recommended minimum)
# CalendarSharingFreeBusyMerged = free/busy + limited details
# CalendarSharingFreeBusyReviewer = free/busy + subject/location (HIGH RISK)
# CalendarSharingFreeBusyDetail  = everything (VERY HIGH RISK)

Write-Host "`n[*] Setting default sharing policy to free/busy time only..." -ForegroundColor Cyan
Set-SharingPolicy -Identity $defaultPolicy.Name `
    -Domains "Anonymous:CalendarSharingFreeBusySimple" `
    -Enabled $false   # Start disabled — change to $true if external sharing is required

Write-Host "[+] Default calendar sharing policy updated to free/busy simple (disabled)" -ForegroundColor Green
Write-Host "[i] Enable it only if business requirements confirm external calendar sharing is needed" -ForegroundColor Cyan

# Verify
$verifiedPolicy = Get-SharingPolicy -Identity $defaultPolicy.Name
Write-Host "`n[Verify] Policy: $($verifiedPolicy.Name) | Enabled: $($verifiedPolicy.Enabled)"
Write-Host "[Verify] Domains: $($verifiedPolicy.Domains -join ', ')"

Disconnect-ExchangeOnline -Confirm:$false
```

---

## Part 4 — Self-Service Purchase Policies

| Property | Value |
|---|---|
| **Module** | MSCommerce |
| **Policy ID** | `AllowSelfServicePurchase` |
| **Recommended Value** | `Disabled` for all products in enterprise environments |
| **Risk if Enabled** | Users can purchase Microsoft subscriptions with corporate credit cards, creating ungoverned billing, data processing, and licence management obligations |

**Why this matters:** Self-service purchase bypasses procurement review, creates untracked licensing obligations, and may result in data being processed under subscription agreements the organisation hasn't reviewed. Every product in the Power Platform and Microsoft 365 ecosystem that supports self-service purchase should be explicitly locked down.

#### UI Walkthrough

Self-service purchase policies are **not configurable via the Admin Center UI** for granular per-product control. All configuration must be done via PowerShell.

#### PowerShell — Disable All Self-Service Purchases

```powershell
# ── Part 4: Self-Service Purchase Policies ─────────────────────────────────
Install-Module -Name MSCommerce -Force -Scope CurrentUser
Import-Module MSCommerce

Connect-MSCommerce

Write-Host "`n[*] Auditing self-service purchase policies..." -ForegroundColor Cyan

# Get all products
$products = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase

# Report current state
Write-Host "`n[Current] Self-Service Purchase Policy Audit:"
$products | Select-Object ProductName, PolicyValue | Format-Table -AutoSize

# Identify any enabled products
$enabled = $products | Where-Object { $_.PolicyValue -eq "Enabled" }

if ($enabled.Count -eq 0) {
    Write-Host "[+] PASS: All $($products.Count) products have self-service purchase disabled" -ForegroundColor Green
} else {
    Write-Host "[!] WARN: $($enabled.Count) products have self-service purchase enabled — disabling now..." -ForegroundColor Yellow

    $errors = 0
    foreach ($product in $enabled) {
        try {
            Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
                -ProductId $product.ProductId -Enabled $false
            Write-Host "    [+] Disabled: $($product.ProductName)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] ERROR disabling $($product.ProductName): $_" -ForegroundColor Red
            $errors++
        }
    }

    if ($errors -eq 0) {
        Write-Host "`n[+] PASS: All self-service purchase policies successfully disabled" -ForegroundColor Green
    } else {
        Write-Host "`n[!] PARTIAL: $errors products could not be disabled — review errors above" -ForegroundColor Red
    }
}

# Final verification
Write-Host "`n[*] Final verification audit..." -ForegroundColor Cyan
$finalCheck = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
$stillEnabled = $finalCheck | Where-Object { $_.PolicyValue -eq "Enabled" }

if ($stillEnabled.Count -eq 0) {
    Write-Host "[+] PASS: $($finalCheck.Count) products confirmed disabled" -ForegroundColor Green
} else {
    Write-Host "[!] FAIL: The following products remain enabled:"
    $stillEnabled | ForEach-Object { Write-Host "    - $($_.ProductName)" -ForegroundColor Red }
}
```

---

## Part 5 — Default User Role Permissions

These settings define what standard (non-admin) users can do within the Entra ID tenant. All are managed via the Microsoft Graph authorization policy.

| Setting | Graph Property | Recommended Value | Reason |
|---|---|---|---|
| Can create applications | `allowedToCreateApps` | `False` | Prevents users from registering apps that access tenant resources without admin review |
| Can create security groups | `allowedToCreateSecurityGroups` | `False` | Prevents ungoverned group creation and access control sprawl |
| Can create new tenants | `allowedToCreateTenants` | `False` | Prevents tenant sprawl and shadow IT |
| Can read BitLocker keys (own device) | `allowedToReadBitlockerKeysForOwnedDevice` | `True` | Enables self-service recovery, reduces helpdesk burden |
| Can read other users | `allowedToReadOtherUsers` | `True` | Required for collaboration features (search, address book, etc.) |

> **Note on `allowedToReadOtherUsers`:** Setting this to `False` prevents directory search and breaks people pickers in Teams, SharePoint, and other apps. Only disable this if your organisation has a specific high-security isolation requirement, and combine with appropriate Conditional Access and B2B governance controls.

#### UI Walkthrough

1. Navigate to **Entra admin center** ([entra.microsoft.com](https://entra.microsoft.com)) → **Users** → **User settings**
2. Review **App registrations**, **Group settings**, and **Directory settings**
3. For Admin Center: navigate to **Settings** → **Org settings** → **Security & privacy** → **Sharing**

#### PowerShell — Harden Default User Role Permissions

```powershell
# ── Part 5: Default User Role Permissions ──────────────────────────────────
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization" -NoWelcome

# Read current values
$authPolicy = Get-MgPolicyAuthorizationPolicy

Write-Host "`n[Current] Default User Role Permissions:" -ForegroundColor Yellow
Write-Host "  AllowedToCreateApps:                        $($authPolicy.DefaultUserRolePermissions.AllowedToCreateApps)"
Write-Host "  AllowedToCreateSecurityGroups:              $($authPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups)"
Write-Host "  AllowedToCreateTenants:                     $($authPolicy.DefaultUserRolePermissions.AllowedToCreateTenants)"
Write-Host "  AllowedToReadBitlockerKeysForOwnedDevice:   $($authPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice)"
Write-Host "  AllowedToReadOtherUsers:                    $($authPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers)"

# Apply recommended settings
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    defaultUserRolePermissions = @{
        allowedToCreateApps                       = $false   # Restrict app registration to admins
        allowedToCreateSecurityGroups             = $false   # Restrict group creation to admins
        allowedToCreateTenants                    = $false   # Block new tenant creation by users
        allowedToReadBitlockerKeysForOwnedDevice  = $true    # Enable self-service BitLocker recovery
        allowedToReadOtherUsers                   = $true    # Maintain collaboration functionality
    }
}

# Verify all settings
$updated = Get-MgPolicyAuthorizationPolicy
$perms   = $updated.DefaultUserRolePermissions

$results = @{
    "AllowedToCreateApps (expect False)"                      = ($perms.AllowedToCreateApps -eq $false)
    "AllowedToCreateSecurityGroups (expect False)"            = ($perms.AllowedToCreateSecurityGroups -eq $false)
    "AllowedToCreateTenants (expect False)"                   = ($perms.AllowedToCreateTenants -eq $false)
    "AllowedToReadBitlockerKeysForOwnedDevice (expect True)"  = ($perms.AllowedToReadBitlockerKeysForOwnedDevice -eq $true)
    "AllowedToReadOtherUsers (expect True)"                   = ($perms.AllowedToReadOtherUsers -eq $true)
}

Write-Host "`n[*] Verification Results:" -ForegroundColor Cyan
$allPassed = $true
foreach ($check in $results.GetEnumerator()) {
    if ($check.Value) {
        Write-Host "  [+] PASS: $($check.Key)" -ForegroundColor Green
    } else {
        Write-Host "  [!] FAIL: $($check.Key)" -ForegroundColor Red
        $allPassed = $false
    }
}
if ($allPassed) {
    Write-Host "`n[+] All user role permission checks passed" -ForegroundColor Green
}

Disconnect-MgGraph
```

---

## Part 6 — Company Branding & Phishing Defense

### Why Branding Matters for Phishing Defense

Configuring company branding on the Entra ID sign-in page is a layered social engineering defence. When users see a consistent, recognisable sign-in experience, they develop a baseline expectation for what your organisation's login page looks like — making generic or clone phishing pages more conspicuous.

**What branding does (and doesn't do):**

| Capability | Notes |
|---|---|
| ✅ Creates a recognisable sign-in baseline | Users trained to expect org branding will notice its absence |
| ✅ Displays custom security messaging | Use the sign-in page text field to include security awareness reminders |
| ✅ Reinforces identity trust for managed users | Microsoft shows the custom branding after recognising a managed account UPN |
| ⚠️ Does NOT prevent attackers from copying your branding | Adversary-in-the-middle (AiTM) phishing kits can replicate visual elements |
| ⚠️ Does NOT apply to personal Microsoft accounts | Users authenticating with personal MSAs will see default Microsoft branding |
| ❌ Not a substitute for MFA and Conditional Access | Branding is defence-in-depth only — phishing-resistant MFA (FIDO2/passkeys) is the primary control |

**Recommended complementary controls:** Phishing-resistant MFA (Windows Hello for Business, FIDO2 security keys), Conditional Access authentication strength policies, Defender for Office 365 anti-phishing policies with first-contact safety tips, and user awareness training that specifically teaches users to verify the URL (`login.microsoftonline.com`) regardless of visual appearance.

---

### 6.1 Entra ID Company Branding — Sign-in Page

| Property | Value |
|---|---|
| **Location** | Entra admin center → Entra ID → Custom Branding |
| **Required License** | Entra ID P1/P2, M365 Business Standard, or SharePoint Plan 1 |
| **Required Role** | Organizational Branding Administrator (minimum) |
| **Graph API Endpoint** | `/beta/organization/{id}/branding` |

#### Branding Elements Reference

| Element | Purpose | Specifications |
|---|---|---|
| Favicon | Browser tab icon | PNG, 32×32 px, max 5 KB |
| Background image | Sign-in page backdrop | PNG/JPG, 1920×1080 px, max 300 KB |
| Background colour | Fallback if image fails to load | Hex colour code |
| Banner logo | Org logo shown on sign-in card | PNG/JPG, 280×60 px (max), max 10 KB |
| Square logo | Used in some M365 app headers | PNG/JPG, 240×240 px, max 50 KB |
| Sign-in page text | Custom text shown below the sign-in box | Max 1024 characters. **Use for security awareness messaging.** |
| Username hint text | Placeholder in the UPN field | e.g., `jane.smith@contoso.com` |
| Self-service password reset link | Footer SSPR link label | e.g., `Forgot my password` |

#### Recommended Security-Aware Sign-in Page Text

Include this (or similar) as your sign-in page text to reinforce phishing awareness at the point of authentication:

```
This is the official sign-in page for [Organisation Name]. Always verify
you are at login.microsoftonline.com before entering your credentials.
If you did not initiate this sign-in, contact IT Security immediately.
```

#### UI Walkthrough — Configure Company Branding

1. Navigate to [entra.microsoft.com](https://entra.microsoft.com) → **Entra ID** → **Custom Branding**
2. Click **Configure** (first time) or **Edit** (if branding exists)
3. Complete each section:

**Basics tab:**
- Upload Favicon (PNG, 32×32 px)
- Upload Background image (PNG/JPG, 1920×1080 px, max 300 KB)
- Set Background colour (hex code, e.g., `#F3F2F1`)

**Layout tab:**
- Select **Partial-screen background** (recommended — preserves background image visibility)
- Header: Enable and configure if custom header link is needed
- Footer: Configure with privacy policy and terms of use links

**Header tab:**
- Upload Banner logo (PNG, max 280×60 px, max 10 KB)
- Recommended: use a horizontal version of your org logo on a transparent background

**Sign-in form tab:**
- Set **Username hint text** to a sample UPN format (e.g., `jane.smith@contoso.com`)
- Set **Sign-in page text** to your security awareness message (see above)

**Footer tab:**
- Add Privacy & Cookies link URL
- Add Terms of Use link URL

4. Click **Review + save** → **Save**

#### PowerShell — Configure Entra ID Branding (Text Properties)

> **Important:** The Entra Company Branding API uses the `/beta` endpoint. Image uploads require binary `PUT` requests and are handled separately from text/colour properties. The script below configures all text and colour properties via PowerShell and provides instructions for the image upload steps.

```powershell
# ── 6.1 Entra ID Company Branding — Text & Color Properties ────────────────
Connect-MgGraph -Scopes "Organization.ReadWrite.All" -NoWelcome
$OrgId = (Get-MgOrganization).Id

# ── Configuration Block — customise these values ────────────────────────────
$BrandingConfig = @{
    signInPageText   = "This is the official sign-in page for Contoso. Always verify you are at login.microsoftonline.com. If you did not initiate this sign-in, contact IT Security immediately."
    usernameHintText = "jane.smith@contoso.com"
    backgroundColor  = "#F3F2F1"
    # squareLogoRelativeUrl and bannerLogoRelativeUrl are set via binary PUT (see below)
}

# ── Read current branding ────────────────────────────────────────────────────
Write-Host "`n[*] Reading current Entra ID branding configuration..." -ForegroundColor Cyan
try {
    $currentBranding = Invoke-MgGraphRequest -Method GET `
        -Uri "https://graph.microsoft.com/beta/organization/$OrgId/branding"
    Write-Host "[Current] Sign-in page text: $($currentBranding.signInPageText)" -ForegroundColor Yellow
    Write-Host "[Current] Background color:  $($currentBranding.backgroundColor)" -ForegroundColor Yellow
} catch {
    Write-Host "[i] No existing branding found — will create default branding" -ForegroundColor Cyan
}

# ── Apply text and color properties ─────────────────────────────────────────
Write-Host "`n[*] Applying branding text and colour properties..." -ForegroundColor Cyan
Invoke-MgGraphRequest -Method PATCH `
    -Uri "https://graph.microsoft.com/beta/organization/$OrgId/branding" `
    -Body ($BrandingConfig | ConvertTo-Json -Depth 3) `
    -ContentType "application/json"
Write-Host "[+] Text and colour properties applied" -ForegroundColor Green

# ── Upload Banner Logo (binary PUT) ─────────────────────────────────────────
# Ensure the logo file exists at the path below before running
$BannerLogoPath = "C:\Branding\banner-logo.png"   # Max 280x60px, max 10 KB, PNG recommended
if (Test-Path $BannerLogoPath) {
    Write-Host "`n[*] Uploading banner logo from $BannerLogoPath..." -ForegroundColor Cyan
    $logoBytes = [System.IO.File]::ReadAllBytes($BannerLogoPath)
    Invoke-MgGraphRequest -Method PUT `
        -Uri "https://graph.microsoft.com/beta/organization/$OrgId/branding/bannerLogo" `
        -Body $logoBytes `
        -ContentType "image/png"
    Write-Host "[+] Banner logo uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "[i] Banner logo not found at $BannerLogoPath — skipping logo upload" -ForegroundColor Cyan
    Write-Host "    Upload manually via Entra admin center → Entra ID → Custom Branding → Header tab" -ForegroundColor Cyan
}

# ── Upload Square Logo (binary PUT) ─────────────────────────────────────────
$SquareLogoPath = "C:\Branding\square-logo.png"   # Max 240x240px, max 50 KB, PNG recommended
if (Test-Path $SquareLogoPath) {
    Write-Host "`n[*] Uploading square logo from $SquareLogoPath..." -ForegroundColor Cyan
    $squareBytes = [System.IO.File]::ReadAllBytes($SquareLogoPath)
    Invoke-MgGraphRequest -Method PUT `
        -Uri "https://graph.microsoft.com/beta/organization/$OrgId/branding/squareLogo" `
        -Body $squareBytes `
        -ContentType "image/png"
    Write-Host "[+] Square logo uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "[i] Square logo not found at $SquareLogoPath — skipping" -ForegroundColor Cyan
}

# ── Upload Background Image (binary PUT) ────────────────────────────────────
$BackgroundPath = "C:\Branding\sign-in-background.jpg"  # 1920x1080px, max 300 KB
if (Test-Path $BackgroundPath) {
    Write-Host "`n[*] Uploading background image from $BackgroundPath..." -ForegroundColor Cyan
    $bgBytes = [System.IO.File]::ReadAllBytes($BackgroundPath)
    Invoke-MgGraphRequest -Method PUT `
        -Uri "https://graph.microsoft.com/beta/organization/$OrgId/branding/backgroundImage" `
        -Body $bgBytes `
        -ContentType "image/jpeg"
    Write-Host "[+] Background image uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "[i] Background image not found — skipping" -ForegroundColor Cyan
}

# ── Verification ─────────────────────────────────────────────────────────────
Write-Host "`n[*] Verifying applied branding..." -ForegroundColor Cyan
$verify = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/organization/$OrgId/branding"

Write-Host "[Verify] Sign-in page text:   $(if ($verify.signInPageText) { '✓ Set' } else { '✗ Not set' })"
Write-Host "[Verify] Username hint text:  $(if ($verify.usernameHintText) { '✓ Set' } else { '✗ Not set' })"
Write-Host "[Verify] Background color:    $(if ($verify.backgroundColor) { $verify.backgroundColor } else { '✗ Not set' })"
Write-Host "[Verify] Banner logo URL:     $(if ($verify.bannerLogoRelativeUrl) { '✓ Set' } else { '✗ Not set' })"
Write-Host "[Verify] Square logo URL:     $(if ($verify.squareLogoRelativeUrl) { '✓ Set' } else { '✗ Not set' })"
Write-Host "[Verify] Background image:    $(if ($verify.backgroundImageRelativeUrl) { '✓ Set' } else { '✗ Not set' })"

Write-Host "`n[i] Validate visually at: https://login.microsoftonline.com (sign in with a test account)" -ForegroundColor Cyan

Disconnect-MgGraph
```

#### Adding Language-Specific Branding (Optional)

If your organisation has multilingual users, Entra ID supports locale-specific branding overrides. For example, to configure French Canadian branding:

```powershell
# ── 6.1b Locale-Specific Branding (Optional) ────────────────────────────────
Connect-MgGraph -Scopes "Organization.ReadWrite.All" -NoWelcome
$OrgId = (Get-MgOrganization).Id

# Create a locale-specific branding localisation
$localeConfig = @{
    signInPageText = "Page de connexion officielle de Contoso. Vérifiez toujours l'URL."
}

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/organization/$OrgId/branding/localizations" `
    -Body (@{ id = "fr-CA" } + $localeConfig | ConvertTo-Json -Depth 3) `
    -ContentType "application/json"

Write-Host "[+] French Canadian branding localisation created" -ForegroundColor Green
Disconnect-MgGraph
```

---

### 6.2 M365 Admin Center Custom Theme — Suite Header Branding

| Property | Value |
|---|---|
| **Location** | M365 Admin Center → Settings → Org settings → Organization profile → Custom themes |
| **Effect** | Custom logo and colour scheme displayed in the M365 suite navigation bar (top header) for all users |
| **Security Value** | Helps users recognise the genuine M365 admin and user portal, reducing susceptibility to admin portal impersonation |
| **Max Themes** | 1 default + 4 group-specific themes |

#### What the Custom Theme Controls

| Element | Description |
|---|---|
| Logo (default) | Displayed in the top navigation bar for all M365 apps (Outlook web, Teams web, SharePoint, etc.) |
| Alternate logo | Used in dark/high-contrast themes |
| Logo click-through URL | URL users navigate to when clicking the logo (e.g., internal intranet) |
| Navigation bar colour | Hex colour for the top suite header |
| Accent colour | Used for links and selected states |
| Text & icon colour | Colour of icons and text in the navigation bar |

#### Image Specifications

| Asset | Format | Max Size | Dimensions |
|---|---|---|---|
| Default logo | JPG, PNG, GIF, SVG | 10 KB | Scaled to 200×48 px (aspect ratio preserved) |
| Alternate logo | JPG, PNG, GIF, SVG | 10 KB | Same as default |

> **Important:** The M365 Custom Theme logo is served in the suite header for signed-in users — not on the sign-in page. These are two distinct branding surfaces. The sign-in page branding is managed in Entra ID (Section 6.1); the suite header branding is managed here via M365 Admin Center.

#### UI Walkthrough — Configure M365 Custom Theme

1. Navigate to [admin.microsoft.com](https://admin.microsoft.com) → **Settings** → **Org settings**
2. Select the **Organization profile** tab → **Custom themes**
3. Click **Add theme** (or edit the default theme)

**General tab:**
- Name the theme (e.g., "Contoso Default Theme")
- Assign to groups if creating a group-specific theme, or leave blank for org-wide default

**Logos tab:**
- Upload your **Default logo** via URL or direct upload (max 10 KB, JPG/PNG/GIF/SVG)
- Upload your **Alternate logo** (optimised for dark backgrounds)
- Set **On-click link** to your intranet or company homepage URL

**Colors tab:**
- Set **Navigation bar color** (hex, e.g., `#0078D4` for Microsoft blue)
- Set **Accent color** (hex)
- Set **Text and icon color** (ensure WCAG AA contrast ratio ≥ 4.5:1 against nav bar colour)

4. Click **Save**

#### PowerShell — Verify M365 Custom Theme (Read-Only Audit)

> The M365 Admin Center Custom Theme is not configurable via the standard Microsoft Graph or Exchange PowerShell modules as of April 2026. Configuration must be done via the Admin Center UI. The script below audits the current organisation settings to confirm the theme has been applied.

```powershell
# ── 6.2 M365 Custom Theme — Audit via Graph ─────────────────────────────────
Connect-MgGraph -Scopes "Organization.Read.All" -NoWelcome
$OrgId = (Get-MgOrganization).Id

# Read organisation branding properties visible at the org level
Write-Host "`n[*] Checking M365 organisation configuration..." -ForegroundColor Cyan
$org = Get-MgOrganization

Write-Host "[Current] Display Name:    $($org.DisplayName)"
Write-Host "[Current] Verified Domains: $($org.VerifiedDomains.Name -join ', ')"

# Check for existing admin center theme via beta endpoint
try {
    $themeData = Invoke-MgGraphRequest -Method GET `
        -Uri "https://graph.microsoft.com/beta/admin/sharepoint/settings"
    Write-Host "[Info] SharePoint/M365 settings accessible" -ForegroundColor Green
} catch {
    Write-Host "[i] Custom theme configuration requires Admin Center UI — use the walkthrough steps above" -ForegroundColor Cyan
}

# Validate branding is in place via the sign-in endpoint check
Write-Host "`n[*] Validating Entra ID branding is configured..." -ForegroundColor Cyan
$branding = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/organization/$OrgId/branding"

$brandingApplied = $false
if ($branding.bannerLogoRelativeUrl -or $branding.backgroundImageRelativeUrl -or $branding.signInPageText) {
    Write-Host "[+] PASS: Entra ID sign-in page branding is configured" -ForegroundColor Green
    $brandingApplied = $true
} else {
    Write-Host "[!] WARN: Entra ID sign-in branding does not appear to be configured" -ForegroundColor Red
    Write-Host "    Complete Section 6.1 to configure sign-in page branding" -ForegroundColor Yellow
}

Write-Host "`n[i] M365 Suite Header (Custom Theme) — validate manually:" -ForegroundColor Cyan
Write-Host "    1. Sign in as a standard user at https://www.office.com"
Write-Host "    2. Verify your organisation logo appears in the top navigation bar"
Write-Host "    3. Confirm the navigation bar colour matches your configured theme"

Disconnect-MgGraph
```

#### Branding Anti-Phishing Checklist

After configuring branding, verify the following are in place as complementary controls:

```
[ ] Entra ID sign-in page shows custom banner logo
[ ] Entra ID sign-in page text includes security awareness message referencing login.microsoftonline.com
[ ] M365 suite header shows org logo for signed-in users
[ ] Defender for Office 365 — First Contact Safety Tip is enabled in anti-phishing policy
[ ] Defender for Office 365 — Anti-phishing impersonation protection is configured for key executives
[ ] User training includes instruction to verify URL (login.microsoftonline.com) regardless of visual branding
[ ] Conditional Access — Phishing-resistant MFA (FIDO2 or Windows Hello for Business) enforced for admins
[ ] SSPR (Self-Service Password Reset) branded sign-in experience tested from private browser
```

---

## 8. Compliance Summary

| # | Control Area | Setting | CIS Control | Recommended Value | Verification |
|---|---|---|---|---|---|
| 1.1 | Org Settings | Technical Contact Email | — | Monitored shared mailbox | Manual review |
| 1.2 | Org Settings | Guest User Directory Access | — | Restricted (own objects only) | PowerShell |
| 1.3 | Org Settings | Conceal Names in Reports | CIS 1.3.6 | Enabled | PowerShell |
| 1.4 | Org Settings | Idle Session Timeout | CIS 5.2.2.3 (L1) | 3 hours | Admin Center + PowerShell |
| 1.5 | Org Settings | Modern Auth / Block Basic Auth | CIS 1.2 (L1) | Migration Complete | PowerShell (Exchange) |
| 2.1 | Auth Policy | Block Email-Based Subscriptions | — | False (disabled) | PowerShell |
| 2.2 | Auth Policy | Block Email Verified Join | — | False (disabled) | PowerShell |
| 2.3 | Auth Policy | Block Legacy MSOL PowerShell | — | True (blocked) | PowerShell |
| 3 | Exchange | External Calendar Sharing | — | Disabled or Free/Busy only | PowerShell |
| 4 | Billing | Self-Service Purchase Policies | — | All products disabled | PowerShell |
| 5 | Auth Policy | User Role Permissions (App creation) | — | False | PowerShell |
| 5 | Auth Policy | User Role Permissions (Group creation) | — | False | PowerShell |
| 5 | Auth Policy | User Role Permissions (Tenant creation) | — | False | PowerShell |
| 5 | Auth Policy | User Role Permissions (BitLocker self-service) | — | True | PowerShell |
| 6.1 | Branding | Entra ID Sign-in Page Branding | — | Configured with org logo + security text | PowerShell + UI |
| 6.2 | Branding | M365 Suite Header Custom Theme | — | Configured with org logo | UI |

---

## Appendix — Master Hardening Script

The following script consolidates all authorization policy and report settings controls into a single, idempotent run. Review and customise all `#── CONFIG ──` sections before executing.

```powershell
# ═══════════════════════════════════════════════════════════════════════════════
# M365 Admin Center — Master Hardening Script
# M365 Baseline — April 2026
# Covers: Auth Policy, Report Settings, User Role Permissions
# Requires: Microsoft.Graph module | Role: Global Admin or Privileged Role Admin
# ═══════════════════════════════════════════════════════════════════════════════

#── CONFIG ──────────────────────────────────────────────────────────────────────
$TechnicalContactEmail  = "it-security@contoso.com"   # Replace with your monitored mailbox
$GuestRestrictedRoleId  = "2d2d1f73-5a06-4d65-9f9e-6bcb6b4e3f99"  # Most restrictive guest role
#────────────────────────────────────────────────────────────────────────────────

#── Connect ─────────────────────────────────────────────────────────────────────
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " M365 Admin Center — Hardening Script" -ForegroundColor Cyan
Write-Host " M365 Baseline | $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

Connect-MgGraph -Scopes @(
    "Policy.ReadWrite.Authorization",
    "Organization.ReadWrite.All",
    "ReportSettings.ReadWrite.All"
) -NoWelcome -ErrorAction Stop

$OrgId = (Get-MgOrganization).Id
Write-Host "[+] Connected. Tenant: $OrgId" -ForegroundColor Green

$results = @{}

#── 1.1 Technical Contact ────────────────────────────────────────────────────────
Write-Host "`n[1.1] Setting technical contact email..." -ForegroundColor Cyan
Update-MgOrganization -OrganizationId $OrgId -BodyParameter @{
    technicalNotificationMails = @($TechnicalContactEmail)
}
$results["1.1 Technical Contact"] = ((Get-MgOrganization).TechnicalNotificationMails -contains $TechnicalContactEmail)

#── 1.2 Guest Directory Access ──────────────────────────────────────────────────
Write-Host "[1.2] Restricting guest directory access..." -ForegroundColor Cyan
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    guestUserRoleId = $GuestRestrictedRoleId
}
$results["1.2 Guest Directory Access"] = ((Get-MgPolicyAuthorizationPolicy).GuestUserRoleId -eq $GuestRestrictedRoleId)

#── 1.3 Conceal Names in Reports ────────────────────────────────────────────────
Write-Host "[1.3] Enabling report name concealment..." -ForegroundColor Cyan
Update-MgAdminReportSetting -BodyParameter @{ displayConcealedNames = $true }
$results["1.3 Conceal Names in Reports"] = ((Get-MgAdminReportSetting).DisplayConcealedNames -eq $true)

#── 2.1-2.3 Authorization Policy ────────────────────────────────────────────────
Write-Host "[2.x] Applying authorization policy controls..." -ForegroundColor Cyan
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    allowedToSignUpEmailBasedSubscriptions    = $false
    allowEmailVerifiedUsersToJoinOrganization = $false
    blockMsolPowerShell                       = $true
    defaultUserRolePermissions = @{
        allowedToCreateApps                      = $false
        allowedToCreateSecurityGroups            = $false
        allowedToCreateTenants                   = $false
        allowedToReadBitlockerKeysForOwnedDevice = $true
        allowedToReadOtherUsers                  = $true
    }
}

$ap = Get-MgPolicyAuthorizationPolicy
$results["2.1 Block Email Subscriptions"]    = ($ap.AllowedToSignUpEmailBasedSubscriptions -eq $false)
$results["2.2 Block Email Verified Join"]    = ($ap.AllowEmailVerifiedUsersToJoinOrganization -eq $false)
$results["5.x User Role — No App Creation"]  = ($ap.DefaultUserRolePermissions.AllowedToCreateApps -eq $false)
$results["5.x User Role — No Group Create"]  = ($ap.DefaultUserRolePermissions.AllowedToCreateSecurityGroups -eq $false)
$results["5.x User Role — No Tenant Create"] = ($ap.DefaultUserRolePermissions.AllowedToCreateTenants -eq $false)
$results["5.x User Role — BitLocker Self-Svc"] = ($ap.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice -eq $true)
$results["5.x User Role — Read Other Users"]   = ($ap.DefaultUserRolePermissions.AllowedToReadOtherUsers -eq $true)

#── Final Report ─────────────────────────────────────────────────────────────────
Write-Host "`n═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " HARDENING RESULTS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

$passCount = 0
$failCount = 0
foreach ($check in $results.GetEnumerator() | Sort-Object Name) {
    if ($check.Value) {
        Write-Host "  [PASS] $($check.Key)" -ForegroundColor Green
        $passCount++
    } else {
        Write-Host "  [FAIL] $($check.Key)" -ForegroundColor Red
        $failCount++
    }
}
Write-Host "`n  Total: $($passCount + $failCount) | Pass: $passCount | Fail: $failCount" -ForegroundColor White

if ($failCount -gt 0) {
    Write-Host "`n[!] Review failed items above and remediate manually or re-run the script" -ForegroundColor Yellow
} else {
    Write-Host "`n[+] All controls passed — Admin Center baseline hardening complete" -ForegroundColor Green
}

Disconnect-MgGraph
Write-Host "`n[*] Disconnected from Microsoft Graph" -ForegroundColor Cyan
```

---

*Document maintained by Jon Hope. Review quarterly against CIS Microsoft 365 Foundations Benchmark updates and Microsoft Graph API changelog.*
