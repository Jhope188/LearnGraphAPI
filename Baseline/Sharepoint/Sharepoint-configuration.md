# SharePoint & OneDrive — CIS Settings Reference
**M365 Managed Settings | SharePoint Admin Center**
*Last updated: May 2026*

**References:**
- [Microsoft Learn: Manage sharing settings for SharePoint and OneDrive in Microsoft 365](https://learn.microsoft.com/sharepoint/turn-external-sharing-on-or-off)
- [Microsoft Learn: Set-SPOTenant](https://learn.microsoft.com/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps)
- [YouTube: SharePoint/OneDrive sharing expiration settings walkthrough](https://www.youtube.com/watch?v=H94rtivkzSw)

---

## Quick Navigation URLs

| Destination | URL |
|-------------|-----|
| Sharing | `https://admin.microsoft.com/sharepoint#/sharing` |
| Access Control | `https://admin.microsoft.com/sharepoint#/accessControl` |
| Settings | `https://admin.microsoft.com/sharepoint#/settings` |
| Site Lifecycle Management | `https://admin.microsoft.com/sharepoint#/siteLifecycleManagement` |
| Data Access Governance | `https://admin.microsoft.com/sharepoint#/dataAccessGovernance` |

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
~~SharePoint admin center → **Settings** → **Sync** → check *"Block sync on Mac OS X"*~~

> ⚠️ **The "Block sync on Mac OS X" checkbox no longer appears in the modern SharePoint admin center UI.** It has been silently removed from the Settings → Sync page. The underlying property still exists and can be read/set via PowerShell only.

> ⚠️ Same page as setting #1 and #11 (for the controls that *are* still visible).

**JSON:**
```json
{
  "BlockMacSync": false
}
```

> The recommended value is **`false`** — meaning macOS sync is **not** blocked. Inforcer monitors this setting to detect if it is ever unexpectedly enabled.

**Check current value (PowerShell — macOS/PnP):**

```powershell
Connect-PnPOnline `
    -Url 'https://<tenant>-admin.sharepoint.com' `
    -Interactive `
    -ClientId '<clientId>' `
    -Tenant '<tenant>.onmicrosoft.com'

Get-PnPTenant | Select-Object BlockMacSync
```

> ⚠️ **Observed behaviour (March 2026):** The property is returned by `Get-PnPTenant` but with **no value** — the column header appears with a blank result. Microsoft has deprecated this property at both the UI and API level. It is no longer settable or readable in a meaningful way.

> **Conclusion:** `BlockMacSync` is fully deprecated. The UI checkbox was removed from the modern admin center and the API property no longer returns a boolean value. Inforcer monitoring of this setting may show as unknown/null rather than `false`. **No remediation action is possible or required** — macOS sync blocking is not enforceable through this property in current tenants. Use Conditional Access device compliance policies if you need to restrict sync by device platform.

**Rationale:**

`BlockMacSync` is a legacy control from an era when the macOS OneDrive client lacked feature parity with Windows. The modern OneDrive client on macOS is fully supported by Microsoft, respects Conditional Access policies, supports sensitivity labels and DLP enforcement, and is functionally equivalent to the Windows client. This is a **drift detection** setting — Inforcer flags it if it deviates from `false` to catch accidental toggles during bulk policy changes.

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

**"More external sharing settings" — Additional Controls & Impact:**

| Setting | JSON Field | CIS Recommended Value | Business Impact |
|---------|-----------|----------------------|----------------|
| Guests must sign in using the same account invitations were sent to | `RequireAcceptingAccountMatchInvitedAccount` | `true` | ✅ Prevents invitation forwarding — recipient must use the exact email address the invite was sent to. Stops guests forwarding share links to unintended parties. |
| Limit external sharing by domain | `SharingDomainRestrictionMode` + `SharingAllowedDomainList` | `AllowList` | ✅ Restricts sharing to approved partner domains only. Strong control for orgs with known, fixed external partners. Without this, users can share to any domain. |
| Allow only users in specific security groups to share externally | `SharingAllowedDomainList` (group-scoped) | Enabled | ✅ Limits external sharing to a vetted subset of users (e.g. senior staff, sales team). Reduces accidental oversharing by standard employees. |
| Allow guests to share items they don't own | **SPO PS:** `PreventExternalUsersFromResharing` = `true`<br>**Graph API (Inforcer):** `isResharingByExternalUsersEnabled` = `false` | Block resharing | ⚠️ **CIS: Block guest resharing.** If guests can reshare, content can spread beyond your intended audience with no audit trail. ⚠️ **Note: the two property names have inverted logic** — SPO PowerShell uses `PreventExternalUsersFromResharing: true` to block, while the Graph API / Inforcer uses `isResharingByExternalUsersEnabled: false` to block. They are the same underlying setting. |
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

**Rationale:**

Disabling self-service site creation prevents ungoverned SharePoint sprawl. Without governance controls at the provisioning layer, users can create sites with no owner designation, no sensitivity label, no naming convention, and no lifecycle policy applied. This is the root cause of the ownerless site problem — sites created without an accountable party from day one.

> **Governance impact:** If self-service creation is disabled, all site creation must go through a governed provisioning process (e.g. a Power Automate request flow, Teams provisioning, or an IT-managed form). This is the most effective point to enforce owner requirements, sensitivity label assignment, and naming conventions — before the site exists, not reactively afterward.

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

### 12.1 Tenant-Wide Sharing Link Expiration Controls

**Admin Center Path:**
SharePoint admin center → **Policies** → **Sharing** → advanced sharing settings

**PowerShell:**

```powershell
Set-SPOTenant `
  -CoreOrganizationSharingLinkRecommendedExpirationInDays 30 `
  -OneDriveOrganizationSharingLinkRecommendedExpirationInDays 30 `
  -CoreOrganizationSharingLinkMaxExpirationInDays 90 `
  -OneDriveOrganizationSharingLinkMaxExpirationInDays 90
```

**What this does:**

These settings apply a **tenant-wide expiration policy** for organization-scoped sharing links. They are separate from the default link type and default permission settings above.

| Control | Purpose |
|---|---|
| `CoreOrganizationSharingLinkRecommendedExpirationInDays` | Sets the recommended expiration for SharePoint organization sharing links. |
| `OneDriveOrganizationSharingLinkRecommendedExpirationInDays` | Sets the recommended expiration for OneDrive organization sharing links. |
| `CoreOrganizationSharingLinkMaxExpirationInDays` | Sets the maximum allowed expiration for SharePoint organization sharing links. |
| `OneDriveOrganizationSharingLinkMaxExpirationInDays` | Sets the maximum allowed expiration for OneDrive organization sharing links. |

**Why this matters:**

- **Recommended expiration** nudges users toward shorter-lived links by setting the default expiry they see when creating a link.
- **Maximum expiration** places a hard tenant-wide cap on how long a link can last, even if a user tries to choose a longer period.
- Together, these controls reduce the lifetime of shared links and limit the blast radius of accidentally over-shared content.

> **Important:** This controls **organization sharing links** at the tenant level. It does **not** change the default link type from “Specific people” / “Only people in your organisation” / “Anyone with the link”; that is controlled by `DefaultSharingLinkType` and `DefaultLinkPermission` in section #12.

> **Practical intent:** Use this when you want a tenant-wide policy that keeps “My organization” links from living forever, while still allowing collaboration to occur under a controlled expiry window.

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
Connect-SPOService -Url "https://<tenant>-admin.sharepoint.com"
Get-SPOTenant | Select-Object EnableAzureADB2BIntegration
```

**Check current value (PowerShell — macOS/PnP):**
```powershell
# Step 1 — One-time app registration (run once per tenant, requires Global Admin)
Import-Module PnP.PowerShell
$app = Register-PnPEntraIDAppForInteractiveLogin `
    -ApplicationName 'PnP-SPOAdmin-MacOS' `
    -Tenant '<tenant>.onmicrosoft.com' `
    -SharePointDelegatePermissions 'AllSites.FullControl' `
    -GraphDelegatePermissions 'Group.ReadWrite.All','User.ReadWrite.All'

# Step 2 — Connect and check
Connect-PnPOnline `
    -Url 'https://<tenant>-admin.sharepoint.com' `
    -Interactive `
    -ClientId '<clientId-from-step-1>' `
    -Tenant '<tenant>.onmicrosoft.com'
Get-PnPTenant | Select-Object EnableAzureADB2BIntegration
```

**Enable the setting (PowerShell — Windows):**
```powershell
Connect-SPOService -Url "https://<tenant>-admin.sharepoint.com"
Set-SPOTenant -EnableAzureADB2BIntegration $true
```

**Enable the setting (PowerShell — macOS/PnP):**
```powershell
Set-PnPTenant -EnableAzureADB2BIntegration $true
```

> ℹ️ **Not currently Inforcer managed.** This setting is not yet read, audited, or remediated by Inforcer. Configuration must be done manually via PowerShell or the admin center UI where available. This is a candidate for a future Inforcer managed setting.

---

### 14. Disallow Infected File Download

> 📋 **CIS Benchmark:** 7.3.1 (L2) — Ensure Office 365 SharePoint infected files are disallowed for download (Automated)

**Admin Center Path:**
Not available in the modern SharePoint admin center UI — **PowerShell only**.

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

When SharePoint detects a file that cannot be scanned for malware or has been identified as infected, the default behaviour is to allow download anyway — presenting a warning that the user can dismiss. `DisallowInfectedFileDownload: true` changes this to a hard block. This prevents users from dismissing the malware warning, automated tools or scripts bypassing the warning prompt entirely, and silent download of files that failed scanning (unscanned ≠ clean).

> **CIS recommended value:** `true` — block download of infected or unscanned files. A warning-only approach relies on user behaviour, which is not a reliable security control.

> ℹ️ **Not currently Inforcer managed.** This is a candidate for a future Inforcer managed setting.

---

### 15. Modern Authentication for SharePoint Applications

> 📋 **CIS Benchmark:** 7.2.1 (L1) — Ensure modern authentication for SharePoint applications is required (Automated)

**Admin Center Path:**
Not exposed in the modern SharePoint admin center UI — **PowerShell only**.

**JSON / Graph API property:**
```json
{
  "IsLegacyAuthProtocolsEnabled": false
}
```

**SPO PowerShell property:** `LegacyAuthProtocolsEnabled`
**Graph API property:** `isLegacyAuthProtocolsEnabled`

> ⚠️ **Property logic:** `LegacyAuthProtocolsEnabled: false` means legacy auth **is blocked** — this is the CIS-compliant state. Setting it to `true` would re-enable legacy authentication, which is the insecure state. The naming is counterintuitive.

**Check current value (PowerShell — Windows):**
```powershell
Connect-SPOService -Url "https://<tenant>-admin.sharepoint.com"
Get-SPOTenant | Select-Object LegacyAuthProtocolsEnabled
```

**Check current value (PowerShell — macOS/PnP):**
```powershell
Get-PnPTenant | Select-Object LegacyAuthProtocolsEnabled
```

**Remediate (PowerShell — Windows):**
```powershell
Set-SPOTenant -LegacyAuthProtocolsEnabled $false
```

**Remediate (PowerShell — macOS/PnP):**
```powershell
Set-PnPTenant -LegacyAuthProtocolsEnabled $false
```

**Rationale:**

Legacy authentication protocols (IDCRL — Identity Client Runtime Library) cannot enforce MFA. They predate token-based modern authentication and communicate credentials directly without supporting the Entra ID Conditional Access evaluation chain. An attacker who obtains a password can use legacy auth to authenticate to SharePoint and bypass any MFA or CA policy that has been configured. Over 97% of credential stuffing attacks use legacy authentication.

> **Relationship to CA policy (CIS 5.3.9):** This is a SharePoint-layer enforcement that complements the tenant-wide Conditional Access legacy auth block. CA 5.3.9 blocks legacy auth at the identity layer; this setting blocks it at the SharePoint service layer. Both should be configured — defence in depth at two separate enforcement points.

> **Deprecation note (October 2025):** `LegacyBrowserAuthProtocolsEnabled` (the RPS/browser legacy auth protocol) was **deprecated for enterprise tenants as of October 2025** and the RPS protocol no longer functions. Microsoft has removed the ability to re-enable it. This is distinct from `LegacyAuthProtocolsEnabled` (IDCRL), which remains configurable and is what CIS 7.2.1 evaluates.

> **Microsoft Baseline Security Mode:** Microsoft's own Baseline Security Mode (separate from CIS) also enforces blocking of both IDCRL (`LegacyAuthProtocolsEnabled`) and RPS (`LegacyBrowserAuthProtocolsEnabled`) as minimum baseline controls.

---

### 16. Unmanaged Device Access Control

> 📋 **Related:** CIS 5.4.3 (L2), Zero Trust Enterprise tier, CIS 7.3.2 (L2 — OneDrive sync restriction)

**Admin Center Path:**
SharePoint admin center → **Policies** → **Access control** → **Unmanaged devices**

> ⚠️ **Auto-creates a Conditional Access policy.** Setting this in the SharePoint admin center automatically creates a CA policy in Entra ID targeting all users. This CA policy will not follow your ACME naming conventions and will be created out-of-band from your Inforcer-managed CA baseline. Review the Entra CA policies after configuring this setting.

**Configuration options:**

| Option | SPO PowerShell | Business Impact |
|--------|---------------|----------------|
| **Allow full access** | `Set-SPOTenant -ConditionalAccessPolicy AllowFullAccess` | No restriction. Managed and unmanaged devices have identical access. |
| **Allow limited, web-only access** ✅ *Zero Trust Enterprise* | `Set-SPOTenant -ConditionalAccessPolicy AllowLimitedAccess` | Unmanaged devices get browser-only access — no download, print, or sync. Office desktop apps blocked on unmanaged devices. |
| **Block access** ✅ *Zero Trust Specialized Security* | `Set-SPOTenant -ConditionalAccessPolicy BlockAccess` | Unmanaged devices cannot access SharePoint or OneDrive at all. Most restrictive. |

**Site-level override (more restrictive only):**
```powershell
# Enterprise sites — web-only for unmanaged
Set-SPOSite -Identity https://<tenant>.sharepoint.com/sites/<sitename> `
    -ConditionalAccessPolicy AllowLimitedAccess

# Specialized security sites — block unmanaged entirely
Set-SPOSite -Identity https://<tenant>.sharepoint.com/sites/<sitename> `
    -ConditionalAccessPolicy BlockAccess
```

> ⚠️ **"Anyone" link bypass:** "Anyone" sharing links (anonymous, no sign-in required) are **not** restricted by this Conditional Access policy. If unmanaged device access is restricted, you must also disable "Anyone" links (see settings #2 and #9) — otherwise, users can share anonymous links that bypass the device restriction entirely.

> ⚠️ **Modern authentication dependency:** Blocking or limiting unmanaged devices also requires blocking apps that don't use modern authentication (see setting #15). Third-party apps and older Office versions using legacy auth can bypass the unmanaged device CA policy.

**Advanced configurations for limited access:**
```powershell
# Block editing in browser (view-only)
Set-SPOTenant -ConditionalAccessPolicy AllowLimitedAccess -AllowEditing $false

# Restrict to Office files only (highest security variant)
Set-SPOTenant -ConditionalAccessPolicy AllowLimitedAccess `
    -LimitedAccessFileType OfficeOnlineFilesOnly
```

---

### 17. Safe Attachments for SharePoint, OneDrive, and Teams

> 📋 **CIS Benchmark:** 2.1.5 (L2) — Ensure Safe Attachments for SharePoint, OneDrive, and Teams is enabled (Automated)

**Admin Center Path:**
Microsoft Defender portal → **Email & collaboration** → **Policies & rules** → **Threat policies** → **Safe Attachments** → **Global settings** → *"Turn on Defender for Office 365 for SharePoint, OneDrive, and Microsoft Teams"*

> ⚠️ This is configured in the **Microsoft Defender portal** (`https://security.microsoft.com`), not the SharePoint admin center.

**PowerShell check:**
```powershell
Get-AtpPolicyForO365 | Format-List EnableATPForSPOTeamsODB
```

**PowerShell remediate:**
```powershell
Set-AtpPolicyForO365 -EnableATPForSPOTeamsODB $true
```

**Block infected file download (companion setting — see #14):**
```powershell
# Required alongside Safe Attachments — prevents download even after detection
Set-SPOTenant -DisallowInfectedFileDownload $true
```

**Rationale:**

Safe Attachments for SharePoint, OneDrive, and Teams provides an additional protection layer on top of the standard virus detection engine. After initial scanning, Safe Attachments opens files in a virtual environment (detonation/sandboxing) to observe behaviour, including checking password-protected files against known malicious patterns. It also detects and blocks files already identified as malicious in team sites and document libraries.

> **Important behaviour note:** Safe Attachments does not scan every single file in SharePoint — this is by design. Files are scanned asynchronously using sharing and guest activity events, smart heuristics, and threat signals to identify malicious files. This means newly uploaded files are not immediately blocked until the async scan completes.

> **Requires Modern experience:** Visual indicators that a file is blocked (the shield icon and warning banner) are **only available in the SharePoint Modern experience**. Classic sites will not show these indicators.

> **Relationship to setting #14:** Safe Attachments detects malicious files. `DisallowInfectedFileDownload` prevents detected files from being downloaded. Both controls are needed — Safe Attachments without the download block still allows users to download files flagged as infected by dismissing the warning. Configure both together.

**Create alert policy for detected files (Recommended):**

In the Defender portal → **Email & collaboration** → **Policies & rules** → **Alert policy** → create a new alert:
- Activity: **Detected malware in file**
- Trigger: Every time an activity matches the rule
- Recipients: SharePoint/security admins

```powershell
# PowerShell equivalent
New-ProtectionAlert `
    -Name "Malicious Files in SharePoint/OD/Teams" `
    -Description "Notifies admins when malicious files are detected" `
    -AggregationType None `
    -Category ThreatManagement `
    -ThreatType Activity `
    -Operation FileMalwareDetected `
    -NotifyUser "admin@contoso.com"
```

---

## Site Governance & Lifecycle

---

### 18. Site Ownership Enforcement

> 📋 **Microsoft Best Practice** — No direct CIS control; foundational prerequisite for all other SPO security controls to be meaningful.
> **License required:** SharePoint Advanced Management (SAM) add-on for automated policy enforcement. M365 E5 provides limited DAG reporting only.

**The problem:** Sites with no accountable owner cannot be governed. Sensitivity labels can't be reviewed, access reviews can't be triggered, and sharing settings can't be validated. Ownership is the prerequisite for all other governance controls.

#### Option A — SAM Site Ownership Policy (Recommended)

**Admin Center Path:**
SharePoint admin center → **Site lifecycle management** → **Site ownership policies** → **New policy**

**Configuration guidance:**
- Set minimum owner count to **2** (not 1) — a single-owner site becomes ownerless as soon as that person leaves, so requiring 2 owners provides continuity
- Set enforcement action to **Read-only** for zero-owner sites and **Do nothing** (notify only) for single-owner sites
- Configure notification recipients: current site owners, current site admins, managers of previous owners, and most active members (within 180 days of activity)
- Run a **simulation policy** first to generate a one-time report of all currently non-compliant sites before switching to active enforcement

**Enforcement behaviour:**

| Site state | Enforcement action | Policy behaviour |
|---|---|---|
| Zero owners | Read-only or Archive | Monthly notifications for 3 months → read-only → archive (if configured) |
| Single owner (below minimum of 2) | Do nothing (nudge only) | Monthly notifications for 3 months → 3-month cool-off → notifications resume |
| Two or more owners | Compliant | No action |

> ⚠️ Hard enforcement (read-only, archive) applies **only to zero-owner sites**. Single-owner sites receive notifications and enter a cool-off period if no action is taken — they are never automatically locked. This is intentional: locking a site with an active owner would be disruptive.

**Download and review the policy execution report** (CSV) monthly — it lists sites in violation, notification status, and sites with no one to notify (a critical category requiring admin intervention).

#### Option B — Ownerless M365 Group Policy (Included in E3/E5)

**Admin Center Path:**
M365 Admin Center → **Settings** → **Org settings** → **Microsoft 365 Groups** → check *"When there's no owner, email and ask active group members to become an owner"*

This is available without SAM and applies to all M365 group-connected SPO sites. When a group becomes ownerless, weekly email notifications are sent to the most active members asking them to accept ownership.

> **Limitation:** This policy only covers **M365 group-connected sites** (Teams sites, group sites). Communication sites and classic SharePoint sites that are not backed by an M365 Group are not covered.

#### PowerShell — Find currently ownerless sites

```powershell
# Find SPO sites with no owner set
Get-SPOSite -Limit All |
    Where-Object { $_.Owner -eq "" -or $_.Owner -eq $null } |
    Select-Object Url, Title, LastContentModifiedDate

# Find M365 groups with no owners (covers group-connected SPO sites)
Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All |
    ForEach-Object {
        $owners = Get-MgGroupOwner -GroupId $_.Id
        if ($owners.Count -eq 0) {
            [PSCustomObject]@{
                DisplayName = $_.DisplayName
                GroupId     = $_.Id
                Mail        = $_.Mail
            }
        }
    }
```

---

### 19. Inactive Site Detection & Lifecycle Management

> 📋 **Microsoft Best Practice** — No direct CIS control.
> **License required:** SharePoint Advanced Management (SAM) add-on.

**Admin Center Path:**
SharePoint admin center → **Site lifecycle management** → **Inactive site policies** → **New policy**

**What counts as activity:** File views, edits, shares and syncs; page visits; Teams channel messages; Exchange mail received in the connected mailbox. The policy analyses activity across SharePoint, Teams, Viva Engage, and Exchange.

> ⚠️ App token activity is **not** counted — only user-driven activity is considered. PnP PowerShell activity via user token is also excluded. Avoid using automated monitoring scripts as a proxy for site activity.

**Recommended configuration:**
- Inactive threshold: **180 days** (6 months) for most sites; 90 days for high-sensitivity sites
- Enforcement: **Read-only** after 3 missed monthly notifications, then **Archive** after a configurable read-only period (3, 6, 9, or 12 months)
- Scope: Target by site template (Teams sites, Communication sites, classic sites separately) — do not apply a single policy across all templates if you want different thresholds

**Enforcement behaviour:**

| Phase | Timeline | What happens |
|---|---|---|
| Initial notifications | Months 1–3 | Monthly emails to site owner/admin with Certify Site button |
| No response | After 3 notifications | Site moves to read-only |
| Read-only period | Configured 3–12 months | Site accessible but no edits |
| No action during read-only | After read-only period | Site archived via Microsoft 365 Archive |

> **Microsoft 365 Archive:** Archived sites preserve all content, permissions, and metadata but are inaccessible to users until reactivated. They no longer consume active SharePoint storage quota. Only tenant admins can reactivate archived sites. Copilot does not index archived content.

---

### 20. Site Attestation Policy

> 📋 **Microsoft Best Practice** — No direct CIS control; recommended annual or biannual cadence.
> **License required:** SharePoint Advanced Management (SAM) add-on.

**Admin Center Path:**
SharePoint admin center → **Site lifecycle management** → **Site attestation policies** → **New policy**

Site attestation asks site owners to periodically confirm and review: site necessity, current owners, members, permissions accuracy, and sharing settings. It is the SPO equivalent of an access review — not automated removal of access, but a structured checkpoint requiring human confirmation.

**Recommended configuration:**
- Attestation frequency: **Annually** for standard sites; **every 6 months** for sites with sensitive content or external sharing enabled
- Scope: All active sites, or scoped to sites with specific sensitivity labels applied
- Enforcement: Read-only or Archive for sites whose owners do not respond after 3 notification cycles

> **Relationship to Entra access reviews:** Site attestation (SAM) reviews the site-level configuration — ownership, permissions structure, sharing settings. Entra access reviews (Entra P2) review the group **membership** — who the individual members and guests are. These are complementary controls, not substitutes. For full SPO governance, both are needed.

---

### 21. Sensitivity Label Governance for SharePoint Sites

> 📋 **Microsoft Best Practice** — No direct CIS control for site-level labelling, but underpins DLP enforcement, CA policy scoping, and external sharing restrictions.
> **License required:** Microsoft Purview Information Protection (included in E3/E5 and Microsoft 365 Business Premium).

**The two-layer label model:**

| Layer | What it covers | Where applied |
|---|---|---|
| **Site/container label** | Applies governance settings to the SharePoint site: external sharing restrictions, unmanaged device access, privacy (public/private), guest access | Applied to the M365 Group or SharePoint site at creation or by site admin |
| **File/document label** | Applies classification and protection to individual files: encryption, visual markings, DLP policy triggers | Applied by users in Office apps or auto-applied via Purview policies |

> ⚠️ **Site labels do not automatically cascade to files.** A site labelled "Confidential" does not mean files inside it are classified as Confidential — users must still apply file labels. However, if a document with a **higher priority** label than the site label is uploaded, Purview automatically generates an alert to the uploader and site owners (audit event: `Detected document sensitivity mismatch`).

#### Finding sites without a sensitivity label

There is no native UI report showing sites with *no* container label. Use PowerShell:

```powershell
# Find all SPO sites missing a container sensitivity label
Connect-SPOService -Url "https://<tenant>-admin.sharepoint.com"
Get-SPOSite -Limit All -DetailedView |
    Where-Object { $_.SensitivityLabel -eq "" -or $_.SensitivityLabel -eq $null } |
    Select-Object Url, Title, SensitivityLabel, StorageUsageCurrent

# Via Microsoft Graph — M365 Groups without an assigned label
Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All |
    Where-Object { $_.AssignedLabels.Count -eq 0 } |
    Select-Object DisplayName, Id, Mail
```

#### Sensitivity label snapshot report (SAM / E5)

**Admin Center Path:**
SharePoint admin center → **Reports** → **Data access governance** → **Sensitivity label for files report**

This report shows sites containing the **highest number of files** with a specific sensitivity label applied. It is **per-label** (you run one report per label) and shows file-level classification, not site-level container labels. Use it to verify that high-sensitivity files are stored in appropriately governed sites.

> **Limitation:** OneDrive sites are not currently supported in the sensitivity label snapshot report. SharePoint sites only.

**Recommended cadence:**
- Quarterly snapshot: run site permissions report + sensitivity label report to establish governance baseline
- Monthly activity: run sharing links report + EEEU report to catch emerging oversharing

#### Enforcing label at site creation

Sensitivity labels can be configured to appear as required selections during Teams or SharePoint site creation. In Purview → **Information protection** → **Sensitivity labels** → edit label → **Scope: Groups & sites** → configure site and group settings. Users must select a label before the site is created.

> This is the most effective point to enforce labelling — at provisioning, not retroactively. Combine with disabled self-service site creation (#10) and a governed provisioning workflow that requires label selection as a mandatory step.

---

### 22. Access Reviews for SharePoint-Backed Groups

> 📋 **Microsoft Best Practice** — No direct CIS control for SPO groups specifically; recommended annually for all groups, quarterly for groups with guest members or sensitive site access.
> **License required:** **Entra ID P2** or **Microsoft Entra ID Governance** — access reviews are not available on P1 or included-only plans.

#### What can be reviewed vs. what cannot

| Group type | Access review support | Notes |
|---|---|---|
| M365 Groups (backing Teams sites / group-connected SPO sites) | ✅ Full support | Reviewable via Entra ID Governance → Access Reviews |
| Security Groups (used to grant SPO site access) | ✅ Full support | Reviewable via Entra ID Governance → Access Reviews |
| Classic SharePoint groups (built-in Owners/Members/Visitors) | ❌ Not supported | These are SPO-native groups, not Entra ID objects — cannot be targeted by Entra access reviews |

**Admin Center Path (Entra):**
Entra admin center → **Identity Governance** → **Access Reviews** → **New access review**

**Recommended review configuration for SPO groups:**
- Resource type: **Teams + Groups**
- Scope: **Everyone** for internal members; add a **separate guest-only review** for sites with external sharing enabled
- Reviewers: **Group owners** — they are best placed to know who needs access
- Recurrence: **Annually** for standard sites; **quarterly** for groups with guests
- On no response: **Remove access** (auto-apply results) — reviewers who don't respond should not maintain access by default
- Enable **auto-apply results** to automatically remove denied members without manual follow-up

#### Targeting SPO site groups by naming convention

Access reviews cannot be filtered by sensitivity label natively. If SPO site groups follow a naming convention (e.g. `SPO-*`, `Site-*`), create reviews programmatically targeting matching groups:

```powershell
# Create a recurring access review via Graph for all groups matching a naming pattern
# Requires: Microsoft.Graph.Identity.Governance module + Identity Governance Admin role

Import-Module Microsoft.Graph.Identity.Governance

$reviewDefinition = @{
    displayName       = "SPO Site Group — Annual Access Review"
    descriptionForAdmins = "Annual review of all SPO site group memberships"
    scope = @{
        query      = "/groups?`$filter=startswith(displayName,'SPO-')"
        queryType  = "MicrosoftGraph"
    }
    reviewers = @(
        @{
            query      = "./owners"
            queryType  = "MicrosoftGraph"
        }
    )
    settings = @{
        mailNotificationsEnabled   = $true
        reminderNotificationsEnabled = $true
        defaultDecisionEnabled     = $true
        defaultDecision            = "Deny"
        autoApplyDecisionsEnabled  = $true
        recurrence = @{
            pattern = @{ type = "absoluteMonthly"; interval = 12 }
            range   = @{ type = "noEnd"; startDate = (Get-Date -Format "yyyy-MM-dd") }
        }
    }
}

New-MgIdentityGovernanceAccessReviewDefinition -BodyParameter $reviewDefinition
```

> ⚠️ **Fallback reviewer required for PIM-governed groups:** For access reviews of groups governed by PIM, only **active** owners are assigned as reviewers — eligible owners are not included. Configure at least one fallback reviewer to handle cases where there are no active owners when the review starts.

#### Guest access reviews (all M365 groups)

For a tenant-wide guest access review across all M365-connected SPO sites:

**Entra admin center → Identity Governance → Access Reviews → New access review**
- Select: **All Microsoft 365 groups with guest users**
- Scope: **Guest users only**
- Reviewers: **Group owners**
- Recurrence: **Quarterly**
- On no response: **Remove access**

---

## Conditional Access Policies for SharePoint

---

### 23. CA Policies — SPO Protection Recommendations

Conditional Access policies are configured in Entra ID, not the SharePoint admin center. The following CA controls directly protect SharePoint Online and should be part of every Inforcer baseline that includes SPO governance.

> 📋 **Reference:** See the Inforcer CA Policy Reference document for full policy templates, ACME naming conventions, and FOCI bypass analysis.

**SPO-relevant CA policy summary:**

| CA Control | CIS | Level | License | What it protects |
|---|---|---|---|---|
| Block legacy auth (all apps including SPO) | 5.3.9 | L1 | Included | Prevents credential attacks via legacy auth protocols that bypass MFA |
| Block unknown/unsupported platforms | 5.3.11 | L1 | Included | Blocks unrecognised device platforms that can't satisfy compliance |
| Require compliant or hybrid-joined device | 5.4.3 | L2 | Intune | Ensures only managed devices access SPO — strongest device control |
| Token protection for SPO | 5.4.4 | L2 | Entra P2 | Binds session tokens to the device — stolen tokens cannot be replayed |
| App-enforced restrictions (unmanaged devices) | Zero Trust | Best practice | Entra P1 | Web-only access for unmanaged devices, scoped via SPO Access Control |
| App protection policy for mobile (iOS/Android) | 5.4.5 | L2 | Intune | Requires MAM policy on mobile devices accessing SPO |

**Token protection — critical scoping requirement:**

Token protection (CA 5.4.4) must target **only** these supported apps:
- `00000003-0000-0ff1-ce00-000000000000` — SharePoint Online
- `00000002-0000-0ff1-ce00-000000000000` — Exchange Online
- `cc15fd57-2c6c-4117-a88c-83b1d56b4bbe` — Microsoft Teams
- `9cdead84-a844-4324-93f2-b2e6bb768d07` — Azure Virtual Desktop
- `0af06dc6-e4b5-4f28-818e-e78e62d137a5` — Windows 365

> ⛔ **Never target "All cloud apps" with token protection.** Unsupported apps will fail sign-in entirely. This is a Critical finding in any CA policy audit.

**App-enforced restrictions and the SPO Access Control relationship:**

The unmanaged device CA policy created by the SharePoint admin center's Access Control setting (see setting #16) uses **app-enforced restrictions** as its session control. This creates a dependency between the SharePoint tenant setting and the Entra CA policy — they must be consistent. If the SPO tenant setting is changed, the CA policy must also be updated, and vice versa.

Microsoft recommends targeting the **Office 365** cloud app (rather than SharePoint-only) for device-based access policies to avoid service dependency gaps — a user blocked in SharePoint but still accessing the Teams Files tab is a common misconfiguration.

---

## Data Access Governance Reporting

---

### 24. Data Access Governance (DAG) Reports

> 📋 **Microsoft Best Practice** — Supports CIS 7.2.x controls through visibility and remediation.
> **License required:** M365 E5 (limited activity reports only) or SharePoint Advanced Management (full snapshot + activity reports + remediation actions).

**Admin Center Path:**
SharePoint admin center → **Reports** → **Data access governance**

**Available reports:**

| Report type | Report name | Cadence | What it shows |
|---|---|---|---|
| Snapshot | Site permissions across your organisation | Quarterly | Broadest access exposure: sites with thousands of users, external guests, or EEEU permissions |
| Snapshot | Sensitivity label applied to files | Quarterly | Sites containing the most files with a specific sensitivity label |
| Activity | Sharing links | Monthly | Sites where users created the most sharing links (Anyone, Org, Specific People) in the last 28 days |
| Activity | Shared with Everyone except external users (EEEU) | Monthly | Sites where content was shared with all internal users in the last 28 days |

> ⚠️ **Activity reports require data collection to be enabled first.** Without SAM, enable data collection in the admin center; data is stored for 28 days and reports become available 24 hours after enabling. If no reports are generated for 3 months, data collection pauses automatically.

**Recommended governance cadence:**

1. **Quarterly:** Run site permissions snapshot + sensitivity label snapshot to establish and maintain a governance baseline
2. **Monthly:** Run sharing links + EEEU activity reports to catch emerging oversharing risks in real time
3. **On alert:** Investigate any site appearing in multiple reports simultaneously (broad sharing + sensitive files + no label = highest risk)

**High-risk site signals (require immediate review):**
- Sites with "Anyone" sharing links AND sensitive files
- Sites with EEEU permissions AND no sensitivity label
- Sites with no owner AND external sharing enabled
- Sites with broken permission inheritance AND large audiences

**Initiate site access reviews from DAG reports:**

For sites identified as overshared, use **Initiate site access review** directly from the DAG report. This delegates the oversharing review to the site owner, sends them a copy of the relevant report for their site, and asks them to remediate. This is site-level remediation delegation, not the same as an Entra access review.

---

## Inforcer Managed Controls — CIS Mapping

> All controls below marked (\*) are Inforcer Managed. CIS control numbers reference **CIS Microsoft 365 Foundations Benchmark v6.0.0**.

| # | Inforcer Setting | CIS Control | Level | Description |
|---|-----------------|-------------|-------|-------------|
| 1 | Allow Syncing Only on Domain-Joined Computers | 7.3.2 | **L2** | Restricts OneDrive sync to on-premises AD domain-joined devices. Does not apply to Entra ID joined devices — use Conditional Access for cloud-native environments. |
| 2 | External Sharing (SharePoint) | 7.2.3 | **L1** | Limits SharePoint sharing to guests already in your Entra directory. Prevents new external accounts being created via sharing links. |
| 3 | External Sharing (OneDrive) | 7.2.4 | **L2** | Limits OneDrive sharing to existing directory guests only. Must be equal to or more restrictive than SharePoint sharing level. |
| 4 | Idle Session Sign-Out | 1.3.2 | **L1** | Signs out users on unmanaged devices after inactivity. CIS recommends ≤3 hours threshold with prior warning. |
| 5 | OneDrive Deleted User Default Retention | *(no direct CIS control)* | — | Sets how many days a deleted user's OneDrive is retained. Default and CIS-aligned value is 180 days. |
| 6 | OneDrive Retention | *(same as #5)* | — | Same underlying property as #5. Surfaced independently in Inforcer for separate tracking and alerting. |
| 7 | OneDrive Storage Quota | *(no direct CIS control)* | — | Sets default storage cap per user OneDrive. Limits data hoarding, reduces DLP surface area. |
| 8 | Block macOS Sync | *(drift detection)* | — | Drift detection — monitors if macOS sync is accidentally blocked. Fully deprecated setting; no enforcement action possible. |
| 9 | SPO & OD External Sharing — Full Controls | 7.2.3 / 7.2.4 / 7.2.5 / 7.2.6 / 7.2.9 / 7.2.10 | **L1/L2** | Full sharing control set: domain allowlists, guest resharing prevention, security group scoping, automatic guest expiry, verification code reauthentication. |
| 10 | SharePoint Site Creation (Self-Service) | *(no direct CIS control)* | — | Controls whether users can self-create sites. Disabling enforces governed provisioning and enables owner + label enforcement at creation time. |
| 11 | Sync File Type Exclusions | *(no direct CIS control)* | — | Blocks upload of specified file types via sync client (e.g. `.exe`, `.bat`, `.ps1`). |
| 15 | Modern Authentication for SharePoint | 7.2.1 | **L1** | Blocks legacy IDCRL authentication at the SharePoint service layer. Complements the tenant-wide CA legacy auth block. |

**Not yet Inforcer managed (candidates for future inclusion):**

| # | Setting | CIS Control | Level | Notes |
|---|---------|-------------|-------|-------|
| 13 | Azure AD B2B Integration | 7.2.2 | **L1** | Foundational for guest governance. PowerShell only. |
| 14 | Disallow Infected File Download | 7.3.1 | **L2** | PowerShell only. Should be paired with Safe Attachments (#17). |
| 16 | Unmanaged Device Access Control | 5.4.3 / Zero Trust | **L2** | Creates out-of-band CA policy — governance complexity. |
| 17 | Safe Attachments for SPO/OD/Teams | 2.1.5 | **L2** | Configured in Defender portal, not SharePoint admin center. |

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
| 8 | macOS sync block \* | `BlockMacSync` | Settings → Sync (deprecated — UI removed) |
| 9 | SPO & OD external sharing (full) \* | `SharingCapability` + domain fields | Policies → Sharing → More external sharing settings |
| 10 | Site creation \* | `SelfServiceSiteCreationEnabled` | Settings → Site creation |
| 11 | Sync file exclusions \* | `ExcludedFileExtensionsForSyncClient` | Settings → Sync |
| 12 | File and folder link defaults | `DefaultSharingLinkType` / `DefaultLinkPermission` | Policies → Sharing → File and folder links |
| 13 | Azure AD B2B integration (CIS 7.2.2) | `EnableAzureADB2BIntegration` | PowerShell only |
| 14 | Disallow infected file download (CIS 7.3.1) | `DisallowInfectedFileDownload` | PowerShell only |
| 15 | Modern authentication (CIS 7.2.1) | `LegacyAuthProtocolsEnabled` / `IsLegacyAuthProtocolsEnabled` | PowerShell only |
| 16 | Unmanaged device access control | `ConditionalAccessPolicy` | Policies → Access control → Unmanaged devices |
| 17 | Safe Attachments for SPO/OD/Teams (CIS 2.1.5) | `EnableATPForSPOTeamsODB` | Defender portal → Safe Attachments → Global settings |
| 18 | Site ownership enforcement | *(SAM lifecycle policy)* | Site lifecycle management → Site ownership policies |
| 19 | Inactive site detection | *(SAM lifecycle policy)* | Site lifecycle management → Inactive site policies |
| 20 | Site attestation | *(SAM lifecycle policy)* | Site lifecycle management → Site attestation policies |
| 21 | Sensitivity label governance | *(Purview + PowerShell)* | Purview → Information protection / DAG reports |
| 22 | Access reviews for SPO groups | *(Entra ID Governance)* | Entra admin center → Identity Governance → Access Reviews |
| 23 | CA policies for SharePoint | *(Entra CA)* | Entra admin center → Conditional Access |
| 24 | Data access governance reports | *(SAM / E5 reporting)* | Reports → Data access governance |

---

## Sync Settings Page — Three in One

Settings **#1**, **#8**, and **#11** are all located on the same page:

> **SharePoint admin center → Settings → Sync**

| Setting | Control |
|---------|---------|
| #1 Domain-joined only | *"Allow syncing only on computers joined to specific domains"* |
| #8 Block macOS | *"Block sync on Mac OS X"* — **UI removed; deprecated** |
| #11 File type exclusions | *"Block upload of specific file types"* |

---

## Licensing Reference

| Feature | Minimum License |
|---|---|
| CIS Section 7 tenant settings (sharing, auth, sync) | Included in all M365 plans |
| Safe Attachments for SPO (CIS 2.1.5) | Defender for Office 365 Plan 1 (included in Business Premium, E3 with add-on, E5) |
| Unmanaged device CA policy | Entra ID P1 |
| Token protection (CIS 5.4.4) | Entra ID P2 |
| Compliant device CA (CIS 5.4.3) | Intune Plan 1 |
| Ownerless group policy (M365 Admin Center) | Business Premium, E3, E5 |
| Entra access reviews (group membership) | **Entra ID P2** or Entra ID Governance |
| DAG reports (limited activity only) | M365 E5 |
| SharePoint Advanced Management (SAM) — full site lifecycle, ownership policies, attestation, full DAG | **SAM add-on** (separate purchase, ~$3/user/month) |
| Sensitivity labels for sites/groups | Purview Information Protection (included in Business Premium, E3, E5) |
