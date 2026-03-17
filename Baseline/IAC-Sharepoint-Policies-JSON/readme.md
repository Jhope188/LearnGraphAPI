# SharePoint & OneDrive — CIS Settings Reference
**SharePoint Admin Center**
*Last updated: March 9, 2026*

---

## Quick Navigation URLs

| Destination | URL |
|-------------|-----|
| Sharing | `https://admin.microsoft.com/sharepoint#/sharing` |
| Access Control | `https://admin.microsoft.com/sharepoint#/accessControl` |
| Settings | `https://admin.microsoft.com/sharepoint#/settings` |

---

## Settings Detail

---

### 1. Allow Syncing Only on Computers Joined to Specific Domains \*

**Admin Center Path:**
SharePoint admin center → **Settings** → **Sync** → enable *"Allow syncing only on computers joined to specific domains"* → enter domain GUIDs

**JSON:**
```json
{
  "IsUnmanagedSyncAppForTenantRestricted": true,
  "AllowedDomainGuidsForSyncApp": ["<domain-guid-1>", "<domain-guid-2>"]
}
```

**Rationale:**

This setting prevents the OneDrive sync client from running on unmanaged or personal computers — only devices whose domain GUID is in the allowlist can sync corporate content. The primary threat it addresses is an employee installing the OneDrive sync client on a personal laptop and pulling down large volumes of corporate data to a device that has no MDM policy, no encryption enforcement, and no remote wipe capability.

> ⚠️ **Important limitation — this does not apply to Entra ID joined devices.** This control is scoped to **on-premises Active Directory domain-joined** machines (identified by their AD domain GUID). Devices that are Entra ID joined (formerly Azure AD joined) or Entra hybrid joined are **not** governed by this setting — their sync access is managed through Conditional Access policies instead.

> **Legacy trajectory:** This is an increasingly legacy control. In modern M365 environments where the device fleet is Entra joined and managed via Intune, Conditional Access Device Compliance policies provide a far stronger and more granular equivalent — they can restrict sync based on compliance state, platform, and location, rather than just domain membership. For organisations still running a hybrid or on-prem AD environment, this setting remains relevant as a backstop. For cloud-native tenants, Conditional Access is the preferred replacement.

> **CIS context:** CIS recommends enabling this as a baseline control. The domain GUIDs to supply are your on-premises AD domain GUIDs — not Entra tenant IDs. If your organisation is fully cloud-native with no on-prem AD, the practical effect of this setting is limited and Conditional Access should be your primary enforcement mechanism.

---

### 2. External Sharing Settings (SharePoint) \*

**Admin Center Path:**
SharePoint admin center → **Policies** → **Sharing** → **top slider** (SharePoint) → drag to desired level

**JSON:**
```json
{
  "SharingCapability": "ExistingExternalUserSharingOnly"
}
```

**Slider Options & Business Impact:**

| Slider Position | JSON Value | Business Impact |
|----------------|-----------|----------------|
| **Anyone** | `ExternalUserAndGuestSharing` | ⛔ **Highest risk.** Anyone with a link can access content — no sign-in required. Files can be forwarded and accessed by unintended recipients. Not recommended for any organisation handling sensitive data. |
| **New and existing guests** | `ExternalUserSharingOnly` | ⚠️ **Moderate risk.** External users must sign in or use a one-time code. New guest accounts are created in your directory. Suitable for orgs that actively collaborate with external partners but requires governance of guest accounts. |
| **Existing guests** ✅ *CIS Recommended* | `ExistingExternalUserSharingOnly` | ✅ **Recommended.** Sharing is limited to guests already in your Entra ID directory. No new guest accounts created via sharing links. Reduces risk of accidental external exposure while still supporting managed collaboration. |
| **Only people in your organisation** | `Disabled` | 🔒 **Most restrictive.** No external sharing of any kind. Best for highly regulated industries (legal, finance, government). May impact legitimate external collaboration workflows — users may resort to shadow IT (personal email, Dropbox etc.). |

---

### 3. External Sharing Settings (OneDrive) \*

**Admin Center Path:**
SharePoint admin center → **Policies** → **Sharing** → **second slider** (OneDrive) → drag to desired level

> ⚠️ **Note:** The OneDrive slider can only be set to the **same level or more restrictive** than the SharePoint slider above it.

**JSON:**
```json
{
  "OneDriveSharingCapability": "ExistingExternalUserSharingOnly"
}
```

**Slider Options & Business Impact:**

| Slider Position | JSON Value | Business Impact |
|----------------|-----------|----------------|
| **Anyone** | `ExternalUserAndGuestSharing` | ⛔ **Highest risk.** Users can share personal OneDrive files via anonymous links. A single accidental share exposes files to anyone on the internet with no audit trail. Not recommended. |
| **New and existing guests** | `ExternalUserSharingOnly` | ⚠️ **Moderate risk.** External recipients must authenticate. Enables broad external file sharing from personal OneDrives. Increases guest account sprawl and DLP surface area. |
| **Existing guests** ✅ *CIS Recommended* | `ExistingExternalUserSharingOnly` | ✅ **Recommended.** OneDrive files can only be shared with guests already in the directory. Prevents users from inadvertently inviting new external parties directly from OneDrive. |
| **Only people in your organisation** | `Disabled` | 🔒 **Most restrictive.** No OneDrive external sharing. Suitable for high-security environments. Users cannot share any OneDrive content externally — consider impact on legitimate file exchange workflows. |

---

### 4. Idle Session Sign-Out \*

**Admin Center Path:**
SharePoint admin center → **Policies** → **Access control** → **Idle session sign-out** → toggle on → set *"Sign out users after:"* and *"Give users this much notice before signing out:"*

**JSON:**
```json
{
  "SignOutWhenIdleEnabled": true,
  "SignOutWhenIdleThreshold": 3600,
  "SignOutWhenIdleNotifyThreshold": 300
}
```

> Values are in **seconds**. `3600` = 1 hour sign-out, `300` = 5 min warning.

---

### 5. OneDrive Deleted User Default Retention \*

**Admin Center Path:**
SharePoint admin center → **Settings** → **OneDrive** → **Retention** tab → *"Days to retain a deleted user's OneDrive"* → enter number of days

**JSON:**
```json
{
  "OrphanedPersonalSitesRetentionPeriod": 180
}
```

> Range: **30–3650 days**. Default is 180.

---

### 6. OneDrive Retention \*

**Admin Center Path:**
SharePoint admin center → **Settings** → **OneDrive** → **Retention** tab

**JSON:**
```json
{
  "OrphanedPersonalSitesRetentionPeriod": 180
}
```

> ℹ️ **Note:** This is the same underlying SharePoint tenant property as setting **#5** (`OrphanedPersonalSitesRetentionPeriod`) and is configured in the same location in the admin center. It is **not a separate CIS control** — CIS covers this as a single requirement. Inforcer surfaces it as a distinct policy item to allow it to be tracked, baselined, and alerted on independently within the platform (e.g. as part of a different baseline group or remediation workflow). If #5 is compliant, this setting will be compliant by definition — they cannot be in different states.

---

### 7. OneDrive Storage Quota \*

**Admin Center Path:**
SharePoint admin center → **Settings** → **OneDrive** → **Storage** tab → *"Default storage limit"* → set value in GB

**JSON:**
```json
{
  "OneDriveStorageQuota": 1048576
}
```

> Value in **MB**. `1048576` = 1 TB | `5242880` = 5 TB

**Rationale:**

Setting a default storage quota prevents data hoarding and ungoverned accumulation of content across user OneDrives. Without a defined limit, users can store terabytes of unclassified data indefinitely — increasing Microsoft 365 storage costs, expanding the DLP surface area, and making Purview classification coverage harder to maintain. A bounded storage footprint also reduces the risk of large-scale exfiltration via OneDrive sync (e.g. a leaving employee staging a bulk download before account deletion).

> **CIS context:** CIS doesn't mandate a specific quota value — it's about ensuring you have *intentionally set* one rather than accepting the Microsoft default (which often varies by licence). The `1048576` MB (1 TB) value is a reasonable baseline for most organisations; high-security or cost-conscious tenants often set this lower (e.g. 100–500 GB).

---

### 8. OneDrive Sync macOS Settings \*

**Admin Center Path:**
SharePoint admin center → **Settings** → **Sync** → check *"Block sync on Mac OS X"*

> ⚠️ Same page as setting #1 and #11.

**JSON:**
```json
{
  "BlockMacSync": false
}
```

> The recommended value is **`false`** — meaning macOS sync is **not** blocked. Inforcer monitors this setting to detect if it is ever unexpectedly enabled.

**Rationale:**

`BlockMacSync` is a legacy control from an era when the macOS OneDrive client lacked feature parity with Windows — it didn't fully support Conditional Access, information protection integrations, or selective sync. In that context, blocking Mac sync was sometimes recommended as a risk mitigation.

The modern OneDrive client on macOS is fully supported by Microsoft, respects Conditional Access policies, supports sensitivity labels and DLP enforcement, and is functionally equivalent to the Windows client. Setting `BlockMacSync: true` today would:

- Break OneDrive sync for **all Mac users** with no security benefit over Windows
- Likely drive users to shadow IT alternatives (iCloud Drive, Dropbox, personal email) to compensate
- Conflict with any Mac-first or mixed-device environment

> **Why Inforcer monitors it:** This is a **drift detection** setting. The concern isn't that you'd deliberately block Macs — it's that this setting could be inadvertently toggled `true` (e.g. during a bulk policy change or a misconfigured baseline import). Inforcer flags it if it deviates from `false` so you can catch and revert it quickly before it impacts Mac users.

---

### 9. SharePoint & OneDrive External Sharing (Full Controls) \*

**Admin Center Path:**
SharePoint admin center → **Policies** → **Sharing** → set both sliders → expand **"More external sharing settings"** accordion → configure domain restrictions, security group limits, and guest account matching

**JSON:**
```json
{
  "SharingCapability": "ExistingExternalUserSharingOnly",
  "OneDriveSharingCapability": "ExistingExternalUserSharingOnly",
  "RequireAcceptingAccountMatchInvitedAccount": true,
  "SharingDomainRestrictionMode": "AllowList",
  "SharingAllowedDomainList": "contoso.com partnerco.com"
}
```

**Slider Options & Business Impact:**

| Slider Position | JSON Value | Business Impact |
|----------------|-----------|----------------|
| **Anyone** | `ExternalUserAndGuestSharing` | ⛔ **Highest risk.** Anonymous links require no authentication. Data can be freely forwarded beyond intended recipients. Fails most compliance frameworks (ISO 27001, CIS, NIST). |
| **New and existing guests** | `ExternalUserSharingOnly` | ⚠️ **Moderate risk.** Enables external collaboration but creates net-new guest accounts on every share. Requires strong guest lifecycle management to avoid stale accounts accumulating. |
| **Existing guests** ✅ *CIS Recommended* | `ExistingExternalUserSharingOnly` | ✅ **Recommended balance.** Collaboration is possible with pre-approved external parties. Prevents uncontrolled guest proliferation. Works well alongside Entra ID B2B invite governance. |
| **Only people in your organisation** | `Disabled` | 🔒 **Most restrictive.** Zero external access. Appropriate for government or regulated industries. High friction for teams that routinely collaborate with clients or partners — evaluate before enforcing. |

**"More external sharing settings" — Additional Controls & Impact:**

| Setting | JSON Field | CIS Recommended Value | Business Impact |
|---------|-----------|----------------------|----------------|
| Guests must sign in using the same account invitations were sent to | `RequireAcceptingAccountMatchInvitedAccount` | `true` | ✅ Prevents invitation forwarding — recipient must use the exact email address the invite was sent to. Stops guests forwarding share links to unintended parties. |
| Limit external sharing by domain | `SharingDomainRestrictionMode` + `SharingAllowedDomainList` | `AllowList` | ✅ Restricts sharing to approved partner domains only. Strong control for orgs with known, fixed external partners. Without this, users can share to any domain. |
| Allow only users in specific security groups to share externally | `SharingAllowedDomainList` (group-scoped) | Enabled | ✅ Limits external sharing to a vetted subset of users (e.g. senior staff, sales team). Reduces accidental oversharing by standard employees. |
| Allow guests to share items they don't own | `PreventExternalUsersFromResharing` | `false` (disable resharing) | ⚠️ **CIS: Disable this.** If guests can reshare, content can spread beyond your intended audience with no audit trail. Set to `false` so guests cannot reshare items. |
| Guest access to a site or OneDrive will automatically expire after this many days | `ExternalUserExpireInDays` | `30` | ✅ **CIS: Enable with 30 days.** Automatically revokes guest access after the set period. Without this, guest access persists indefinitely even when the business relationship ends. Reduces stale access risk significantly. |
| People who use a verification code must reauthenticate after this many days | `EmailAttestationReAuthDays` | `15` | ✅ **CIS: Enable with 15 days.** Forces one-time-code users to re-verify periodically. Without this, a one-time code used once grants indefinite access from that browser session. |

---

### 10. SharePoint Site Creation Settings \*

**Admin Center Path:**
SharePoint admin center → **Settings** → **Site creation** → toggle *"Let users create their own sites"* → set default site type, storage limit, time zone

**JSON:**
```json
{
  "SelfServiceSiteCreationEnabled": false,
  "DefaultSharingLinkType": "Internal",
  "DefaultLinkPermission": "View"
}
```

> `DefaultSharingLinkType` values: `None` | `Direct` | `Internal` | `AnonymousAccess`
> `DefaultLinkPermission` values: `None` | `View` | `Edit`

---

### 11. Sync File Type Exclusions \*

**Admin Center Path:**
SharePoint admin center → **Settings** → **Sync** → *"Block upload of specific file types"* → enter extensions separated by semicolons (e.g. `.exe;.bat;.ps1`)

> ⚠️ Same page as setting #1 and #8.

**JSON:**
```json
{
  "ExcludedFileExtensionsForSyncClient": [".exe", ".dll", ".bat", ".ps1", ".tmp"]
}
```

---

### 12. File and Folder Link Defaults

**Admin Center Path:**
SharePoint admin center → **Policies** → **Sharing** → scroll to **"File and folder links"** section (below the More external sharing settings accordion)

**JSON:**
```json
{
  "DefaultSharingLinkType": "Internal",
  "DefaultLinkPermission": "View"
}
```

**Default Link Type Options & Business Impact:**

| Option | JSON Value | Business Impact |
|--------|-----------|----------------|
| **Specific people** (only the people the user specifies) | `Direct` | ⚠️ User must enter each recipient manually. Most controlled for intentional sharing but more friction. Default in many tenants. No risk of accidental broad access. |
| **Only people in your organisation** ✅ *CIS Recommended* | `Internal` | ✅ **Recommended.** The default share link only works for internal users. External sharing still possible but requires the user to consciously choose it. Reduces accidental external exposure from copy-paste links. |
| **Anyone with the link** | `AnonymousAccess` | ⛔ **Highest risk.** Default link is anonymous — anyone who receives it can access the file with no sign-in. Only appropriate if `SharingCapability` is already set to `Disabled`. |

**Default Link Permission Options & Business Impact:**

| Option | JSON Value | Business Impact |
|--------|-----------|----------------|
| **View** ✅ *CIS Recommended* | `View` | ✅ **Recommended.** Shared links are read-only by default. Recipients can view but not edit or download unless the user explicitly upgrades the permission. Prevents accidental co-authoring or content modification by external parties. |
| **Edit** | `Edit` | ⚠️ Shared links grant edit access by default. Users may not notice the permission level when sharing, leading to unintended external editing. Requires user awareness and discipline. |

> 💡 **Default Sharing comparison from screenshot:**
> - **Default (no policy):** Link type = *Specific people*, Permission = *Edit*
> - **CIS Recommended:** Link type = *Only people in your organisation*, Permission = *View*

---

### 13. SharePoint & OneDrive Integration with Azure AD B2B

> 📋 **CIS Benchmark:** 7.2.2 (L1) — Ensure SharePoint and OneDrive integration with Azure AD B2B is enabled (Automated)

**Admin Center Path:**
SharePoint admin center → **Settings** → **SharePoint** → *"Azure Active Directory guest sign-in"* section (if surfaced in your tenant)

> ⚠️ This setting is **not consistently exposed in the SharePoint admin center UI** across all tenants. The most reliable way to check and configure it is via PowerShell.

**JSON:**
```json
{
  "EnableAzureADB2BIntegration": true
}
```

**Rationale:**

When SharePoint and OneDrive external sharing is enabled, guests can be created through two different mechanisms:

- **Legacy SharePoint guest model** — guests receive content access but are created as lightweight SharePoint-only accounts. These accounts do not appear as full objects in Entra ID, meaning they cannot be managed via Entra ID access reviews, lifecycle policies, Conditional Access, or Entra ID Governance. They are essentially invisible to your identity governance tooling.
- **Azure AD B2B integration** — every guest invitation flows through the Entra ID B2B framework. Guests become proper Entra ID guest objects, fully visible in the directory and subject to the same governance controls as any other external identity.

Enabling this integration ensures that **all SharePoint/OneDrive-initiated external sharing creates a properly governed Entra ID B2B guest account**. This is the foundational dependency that makes the other sharing controls (guest expiry, access reviews, Conditional Access for guests, MFA enforcement) actually apply to SharePoint-sourced guests.

> Without this enabled, you can have guests with access to SharePoint content who are completely invisible to Entra ID — they won't appear in access reviews, won't be subject to Conditional Access, and can't be managed through the guest lifecycle policies you've configured.

> **Relationship to other settings:** The `ExistingExternalUserSharingOnly` recommendation in settings #2, #3, and #9 states sharing is limited to *"guests already in your Entra ID directory"* — but without B2B integration, older SharePoint-only guests may exist outside of Entra ID entirely. Enabling B2B integration closes that gap going forward.

**Check current value (PowerShell — Windows):**
```powershell
# SharePoint Online Management Shell (Windows only)
Connect-SPOService -Url "https://<tenant>-admin.sharepoint.com"
Get-SPOTenant | Select-Object EnableAzureADB2BIntegration
```

**Check current value (PowerShell — macOS):**

> ⚠️ `Microsoft.Online.SharePoint.PowerShell` (`Connect-SPOService`) is **Windows-only** and will fail on macOS. Use PnP PowerShell instead.
>
> PnP.PowerShell v3+ also no longer accepts `-Interactive` without an explicit `-ClientId`. The well-known PnP Management Shell app was deprecated in September 2024. You must register your own Entra ID app first (one-time per tenant).

```powershell
# Step 1 — One-time app registration (run once per tenant, requires Global Admin)
Import-Module PnP.PowerShell
$app = Register-PnPEntraIDAppForInteractiveLogin `
    -ApplicationName 'PnP-SPOAdmin-MacOS' `
    -Tenant '<tenant>.onmicrosoft.com' `
    -SharePointDelegatePermissions 'AllSites.FullControl' `
    -GraphDelegatePermissions 'Group.ReadWrite.All','User.ReadWrite.All'
# Save the ClientId output — you'll reuse it for every future connection

# Step 2 — Connect and check (reuse the ClientId from Step 1)
Connect-PnPOnline `
    -Url 'https://<tenant>-admin.sharepoint.com' `
    -Interactive `
    -ClientId '<clientId-from-step-1>' `
    -Tenant '<tenant>.onmicrosoft.com'
Get-PnPTenant | Select-Object EnableAzureADB2BIntegration
```

**Enable the setting (PowerShell — Windows):**
```powershell
# SharePoint Online Management Shell (Windows only)
Connect-SPOService -Url "https://<tenant>-admin.sharepoint.com"
Set-SPOTenant -EnableAzureADB2BIntegration $true
```

**Enable the setting (PowerShell — macOS):**
```powershell
# After connecting with Connect-PnPOnline as above
Set-PnPTenant -EnableAzureADB2BIntegration $true
```

> 🔬 **Observed state (inforcer2m365 demo tenant, March 12 2026):** `EnableAzureADB2BIntegration = True` ✅ — compliant with CIS 7.2.2.

> ℹ️ **Not currently Inforcer managed.** This setting is not yet read, audited, or remediated by Inforcer. Configuration must be done manually via PowerShell or the admin center UI where available. This is a candidate for a future Inforcer managed setting given its dependency relationship with the existing external sharing controls.

---

### 14. Disallow Infected File Download

> 📋 **CIS Benchmark:** 7.3.1 (L2) — Ensure Office 365 SharePoint infected files are disallowed for download (Automated)

**Admin Center Path:**
Not available in the modern SharePoint admin center UI — **PowerShell only**.

> ℹ️ The modern Settings page (shown at `https://admin.microsoft.com/sharepoint#/settings`) does not expose this control. It is not present on the new Settings page or the classic settings page. `Get-PnPTenant` / `Set-PnPTenant` is the only supported way to read and configure this setting.

**JSON:**

```json
{
  "DisallowInfectedFileDownload": true
}
```

**Check current value (PowerShell — macOS/PnP):**

```powershell
Connect-PnPOnline `
    -Url 'https://<tenant>-admin.sharepoint.com' `
    -Interactive `
    -ClientId '<clientId>' `
    -Tenant '<tenant>.onmicrosoft.com'
Get-PnPTenant | Select-Object DisallowInfectedFileDownload
```

**Check current value (PowerShell — Windows):**

```powershell
Connect-PnPOnline -Url "https://Inforcer2m365-admin.sharepoint.com" -Interactive -ClientId "7b394b1f-92e5-4be8-b433-b0fa7e938cb7" -Tenant "Inforcer2m365.onmicrosoft.com"

Connect-SPOService -Url "https://<tenant>-admin.sharepoint.com"
Get-SPOTenant | Select-Object DisallowInfectedFileDownload
```

**Remediate (PowerShell — macOS/PnP):**

```powershell
Set-PnPTenant -DisallowInfectedFileDownload $true
```

**Remediate (PowerShell — Windows):**

```powershell
Set-SPOTenant -DisallowInfectedFileDownload $true
```

**Rationale:**

When SharePoint detects a file that cannot be scanned for malware or has been identified as infected, the default behaviour is to allow download anyway — presenting a warning that the user can dismiss. `DisallowInfectedFileDownload: true` changes this to a hard block. The file cannot be downloaded regardless of user action.

This prevents:

- Users dismissing the malware warning and downloading an infected file anyway
- Automated tools or scripts that bypass the warning prompt entirely
- Silent download of files that failed scanning (unscanned ≠ clean)

> **CIS recommended value:** `true` — block download of infected or unscanned files. A warning-only approach relies on user behaviour, which is not a reliable security control.

> ℹ️ **Not currently Inforcer managed.** This setting must be configured manually via PowerShell or the admin center UI. It is a candidate for a future Inforcer managed setting.

---

## Inforcer Managed Controls — CIS Mapping

> All controls below are Inforcer Managed (\*). CIS control numbers reference the **CIS Microsoft 365 Foundations Benchmark v6.0.0**.

| # | Inforcer Setting | CIS Control | Level | Description |
|---|-----------------|-------------|-------|-------------|
| 1 | Allow Syncing Only on Domain-Joined Computers | 7.3.2 | **L2** | Restricts OneDrive sync to on-premises AD domain-joined devices only. Prevents corporate data syncing to unmanaged personal devices. Does not apply to Entra ID joined devices. |
| 2 | External Sharing (SharePoint) | 7.2.3 | **L1** | Limits SharePoint sharing to guests already in your Entra directory. Prevents new external accounts being created via sharing links. |
| 3 | External Sharing (OneDrive) | 7.2.4 | **L2** | Limits OneDrive sharing to existing directory guests only. Must be equal to or more restrictive than the SharePoint sharing level. |
| 4 | Idle Session Sign-Out | 1.3.2 | **L1** | Signs out users on unmanaged devices after inactivity. CIS recommends ≤3 hours threshold with a prior warning to reduce unattended session risk. |
| 5 | OneDrive Deleted User Default Retention | *(no direct CIS control)* | — | Sets how many days a deleted user's OneDrive is retained before permanent deletion. Default and CIS-aligned value is 180 days, giving time to transfer ownership or recover data before it is lost. |
| 6 | OneDrive Retention | *(same as #5)* | — | Same underlying property as #5 (`OrphanedPersonalSitesRetentionPeriod`). Surfaced independently in Inforcer for separate tracking and alerting. If #5 is compliant, this is compliant by definition. |
| 7 | OneDrive Storage Quota | *(no direct CIS control)* | — | Sets a default storage cap per user OneDrive. Limits data hoarding, reduces DLP surface area, and bounds costs. Ensure a value is intentionally set rather than left at Microsoft's default. |
| 8 | Block macOS Sync | *(drift detection)* | — | Drift detection — monitors if macOS sync is accidentally blocked. The modern macOS client is fully supported; blocking it breaks sync for all Mac users with no security benefit. |
| 9 | SPO & OD External Sharing — Full Controls | 7.2.3 / 7.2.4 / 7.2.5 / 7.2.6 / 7.2.9 / 7.2.10 | **L1/L2** | Full sharing control set: domain allowlists, guest resharing prevention, security group scoping, automatic guest expiry, and verification code reauthentication. |
| 10 | SharePoint Site Creation (Self-Service) | *(no direct CIS control)* | — | Controls whether users can self-create SharePoint sites. Disabling prevents ungoverned sprawl and enforces a governed provisioning process. |
| 11 | Sync File Type Exclusions | *(no direct CIS control)* | — | Blocks upload of specified file types via the sync client (e.g. `.exe`, `.bat`, `.ps1`). Reduces risk of malicious executables being distributed via OneDrive sync. |

---

## Summary Table

> **\* Inforcer Managed** — Inforcer can read, audit, and remediate this setting automatically.

| # | Setting | JSON Field | Admin Center Location |
|---|---------|-----------|----------------------|
| 1 | Domain-joined sync only \* | `IsUnmanagedSyncAppForTenantRestricted` | Settings → Sync |
| 2 | External sharing (SharePoint) \* | `SharingCapability` | Policies → Sharing → top slider |
| 3 | External sharing (OneDrive) \* | `OneDriveSharingCapability` | Policies → Sharing → second slider |
| 4 | Idle session sign-out \* | `SignOutWhenIdleEnabled` | Policies → Access control → Idle session sign-out |
| 5 | Deleted user retention \* | `OrphanedPersonalSitesRetentionPeriod` | Settings → OneDrive → Retention |
| 6 | OneDrive retention \* | `OrphanedPersonalSitesRetentionPeriod` | Settings → OneDrive → Retention |
| 7 | Storage quota \* | `OneDriveStorageQuota` | Settings → OneDrive → Storage |
| 8 | macOS sync block \* | `BlockMacSync` | Settings → Sync |
| 9 | SPO & OD external sharing (full) \* | `SharingCapability` + domain fields | Policies → Sharing → More external sharing settings |
| 10 | Site creation \* | `SelfServiceSiteCreationEnabled` | Settings → Site creation |
| 11 | Sync file exclusions \* | `ExcludedFileExtensionsForSyncClient` | Settings → Sync |
| 12 | File and folder link defaults | `DefaultSharingLinkType` / `DefaultLinkPermission` | Policies → Sharing → File and folder links |
| 13 | Azure AD B2B integration (CIS 7.2.2) | `EnableAzureADB2BIntegration` | PowerShell / Settings → SharePoint |
| 14 | Disallow infected file download (CIS 7.3.1) | `DisallowInfectedFileDownload` | PowerShell / Settings → Infected files |

---

## Sync Settings Page — Three in One

Settings **#1**, **#8**, and **#11** are all located on the same page:

> **SharePoint admin center → Settings → Sync**

| Setting | Control |
|---------|---------|
| #1 Domain-joined only | *"Allow syncing only on computers joined to specific domains"* |
| #8 Block macOS | *"Block sync on Mac OS X"* |
| #11 File type exclusions | *"Block upload of specific file types"* |
