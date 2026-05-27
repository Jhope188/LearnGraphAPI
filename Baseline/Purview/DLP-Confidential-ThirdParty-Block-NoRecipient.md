# DLP Policy: Confidential - Block External Third Party without Recipient

> **Author:** IAC / Jhope  
> **Date:** May 2026  
> **Workload:** Exchange Online  
> **Label Target:** Confidential - Third Parties  
> **Reference:** [Use sensitivity labels as conditions in DLP policies](https://learn.microsoft.com/en-us/purview/dlp-sensitivity-label-as-condition) · [DLP Exchange conditions and actions reference](https://learn.microsoft.com/en-us/purview/dlp-exchange-conditions-and-actions)

---

## Purpose

The `Confidential - Third Parties` label uses **user-defined permissions** — when applied in Outlook, the user must actively assign Do Not Forward (DNF) or Encrypt-Only before sending. This is the correct behaviour and works as expected in a supported client.

However, the label metadata can be applied **without IRM protection being set** in the following scenarios:

| Scenario | Risk |
|---|---|
| Label applied via script or migration tool | No encryption is triggered — label is metadata only |
| Label applied in an older mobile client or unsupported app | Permissions dialog may not surface |
| Auto-labeling service applies the label to content at rest | User-defined permissions are not triggered by service-side labeling |
| User dismisses the permissions dialog in Word/PowerPoint/Excel | Label applied, encryption skipped |

This DLP policy acts as the **enforcement backstop**: if an email tagged `Confidential - Third Parties` leaves the organisation without IRM protection applied, it is blocked at transport.

---

## Policy Design

### Logic

```
IF:
  Content contains sensitivity label: Confidential - Third Parties
  AND recipient is outside the organisation
  AND message is NOT IRM-protected (PermissionControlled)

THEN:
  Block send (Block everyone)
  Notify sender with policy tip
  Generate incident report
```

### Why `ExceptIfMessageTypeMatches PermissionControlled`

There is no native "content is not encrypted" condition in Purview DLP for Exchange. The correct equivalent is checking the IRM message type at the transport layer. `PermissionControlled` covers both Do Not Forward and Encrypt-Only — the two protection types a user-defined permissions label can apply. Using this as an **exception** means:

- Message has label + is going external + **IS** IRM-protected → **allow** (user configured recipients correctly)
- Message has label + is going external + **is NOT** IRM-protected → **block** (misconfigured — policy fires)

---

## Configuration Settings

| Setting | Value |
|---|---|
| **Policy name** | `Confidential - Block External Third Party without Recipient` |
| **Workload** | Exchange |
| **Scope** | All users |
| **Mode** | Enable (enforce) |
| **Rule name** | `Block-ConfThirdParty-NoEncryptionRecipient` |
| **Condition 1** | Content contains sensitivity label: `Confidential - Third Parties` |
| **Condition 2** | Sent to: people outside the organisation |
| **Exception** | Message type is `PermissionControlled` |
| **Action** | Block — block everyone from receiving |
| **User notification** | Policy tip (before send) |
| **Override allowed** | No |
| **Incident report severity** | High |
| **Alert on** | Every event |

---

## Deployment Scripts

> **Prerequisites:**  
> - `ExchangeOnlineManagement` module v3+  
> - Role: Compliance Administrator or DLP Compliance Management  
> - The `Confidential - Third Parties` sensitivity label must already exist and be published in your tenant

### Scripts Provided

Two scripts are included in `/Baseline/Purview/`:

| Script | Purpose |
|---|---|
| `Connect-ConditionalAccessTech-And-CreateDlp.ps1` | **Wrapper script** — connects to your tenant and invokes the main DLP creation script. Use this. |
| `Create-Dlp-ConfidentialThirdParty-NoRecipient.ps1` | **Core logic** — creates the policy and rule. Called by the wrapper. |

### How to Deploy to Your Tenant

**Option 1: Interactive Login (Recommended)**

```powershell
cd /path/to/LearnGraphAPI/Baseline/Purview

# Will prompt for interactive sign-in
pwsh -NoProfile -File "./Connect-ConditionalAccessTech-And-CreateDlp.ps1"
```

**Option 2: Specify Admin UPN**

```powershell
pwsh -NoProfile -File "./Connect-ConditionalAccessTech-And-CreateDlp.ps1" -AdminUpn "admin@yourtenant.onmicrosoft.com"
```

**Option 3: Dry-Run (Preview Without Deploying)**

```powershell
# Shows what would be created without making changes
pwsh -NoProfile -File "./Connect-ConditionalAccessTech-And-CreateDlp.ps1" -DryRun
```

### Manual Deployment (If Not Using Wrapper)

If you prefer to deploy directly without the wrapper:

```powershell
# Step 1: Connect to Security & Compliance PowerShell
Connect-IPPSSession -UserPrincipalName "admin@yourtenant.onmicrosoft.com"

# Step 2: Run the core script
$scriptPath = "/path/to/LearnGraphAPI/Baseline/Purview/Create-Dlp-ConfidentialThirdParty-NoRecipient.ps1"
& $scriptPath
```

### Script Parameters

**Create-Dlp-ConfidentialThirdParty-NoRecipient.ps1:**
```
-TenantDomain <string>        Optional: Your tenant domain (e.g., contoso.onmicrosoft.com)
-UserPrincipalName <string>   Optional: Admin UPN for Connect-IPPSSession
-DryRun                        Optional: Preview mode (no changes made)
```

**Connect-ConditionalAccessTech-And-CreateDlp.ps1:**
```
-AdminUpn <string>            Optional: Admin UPN in your tenant
-DryRun                        Optional: Preview mode (no changes made)
```

### What the Scripts Do

1. **Ensure modules installed** — Installs/imports `ExchangeOnlineManagement` v3+
2. **Connect to Security & Compliance** — Uses `Connect-IPPSSession` (interactive or UPN-based)
3. **Resolve label** — Finds the `Confidential - Third Parties` label by display name
4. **Create policy** — `New-DlpCompliancePolicy` (or skip if exists)
5. **Create rule** — `New-DlpComplianceRule` with correct parameters:
   - **Condition:** `-ContentContainsSensitiveInformation` (label ImmutableId)
   - **Condition:** `-AccessScope NotInOrganization` (external recipients only)
   - **Exception:** `-ExceptIfMessageTypeMatches PermissionControlled` (allow if encrypted)
   - **Action:** `-BlockAccess $true`, `-NotifyUser Owner`
   - **Alert:** `-GenerateAlert $true` with threshold of ≥3 events in 60-minute window
6. **Verify** — Displays policy and rule confirmation

### Important Notes

- **Label must exist first** — The script fails gracefully if `Confidential - Third Parties` is not published in your tenant
- **Idempotent** — Safe to run multiple times; skips policy/rule if already exists
- **No manual prompts** — Set `-AdminUpn` to make login non-interactive, or omit for interactive sign-in
- **Alert threshold** — Minimum of 3 events in the time window (service requirement)

---

## Verification Commands

```powershell
# Confirm policy is enabled
Get-DlpCompliancePolicy -Identity "Confidential - Block External Third Party without Recipient" |
    Format-List Name, Mode, ExchangeLocation

# Confirm rule conditions
Get-DlpComplianceRule -Identity "Block-ConfThirdParty-NoEncryptionRecipient" |
    Format-List Name, Disabled, ContentContainsSensitivityLabel, SentToScope, ExceptIfMessageTypeMatches, BlockAccess

# Review recent DLP matches (last 7 days)
Get-DlpDetailReport `
    -StartDate (Get-Date).AddDays(-7) `
    -EndDate (Get-Date) `
    -Action BlockAccess |
    Where-Object { $_.PolicyName -eq "Confidential - Block External Third Party without Recipient" } |
    Select-Object Date, UserEmail, PolicyName, RuleName, Action |
    Format-Table -AutoSize
```

---

## Full DLP Policy Set for IAC Label Taxonomy

This policy is one of the recommended set for the IAC label taxonomy. The complete set is:

| # | Policy Name | Label(s) | Condition | Action |
|---|---|---|---|---|
| 1 | Block Unlabeled External Email | *(none)* | No label applied + external recipient | Block |
| 2 | **Confidential - Block External Third Party without Recipient** ← *this policy* | Confidential - Third Parties | External + NOT PermissionControlled | Block |
| 3 | Confidential - Block Internal Unencrypted External Share | Confidential - Internal | Shared externally | Block |
| 4 | Restricted - Block All External Sharing | Restricted - Internal | Any external recipient | Block |
| 5 | Restricted - Block Third Party without Recipient | Restricted - Third Parties | External + NOT PermissionControlled | Block |

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Policy not firing on test email | Label `ImmutableId` mismatch in rule | Re-run script; verify `Get-Label` resolves correctly |
| Policy fires on correctly-protected email | `ExceptIfMessageTypeMatches` not set | Verify rule has `ExceptIfMessageTypeMatches = PermissionControlled` |
| Policy not visible in Purview portal | Propagation delay | Allow up to 1 hour for new DLP policies to sync |
| Rule disabled unexpectedly | Policy mode set to `TestWithoutNotifications` | Set `Set-DlpCompliancePolicy -Identity "..." -Mode Enable` |
| Alert emails not arriving | Alert configuration missing | Re-run with correct `-AlertProperties` block |

---

## Notes

- DLP policies for Exchange propagate within **~1 hour** of creation
- This policy applies at **transport** — it fires whether the email originates from Outlook desktop, Outlook on the web, or a mobile client
- The policy does **not** apply to SharePoint/OneDrive file sharing — a separate policy targeting those workloads is required for full coverage
- **Do not apply this policy to Teams** in the same rule — Teams DLP uses different condition handling; create a separate Teams policy if required

---

## Why DLP Policies Cannot Be Created via Microsoft Graph API

Microsoft Purview DLP policies are managed through the **Security & Compliance PowerShell endpoint** (`Connect-IPPSSession`), not Microsoft Graph. Graph API does not expose DLP policy creation endpoints. To deploy this policy you must:

1. Connect via `Connect-IPPSSession` (interactive or with UPN)
2. Run the provided wrapper script: `Connect-ConditionalAccessTech-And-CreateDlp.ps1`
3. Verify via `Get-DlpCompliancePolicy` and `Get-DlpComplianceRule`

The scripts handle all of this automatically.
