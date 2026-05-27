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

## Deployment Script

> **Prerequisites:**  
> - `ExchangeOnlineManagement` module v3+  
> - Role: Compliance Administrator or DLP Compliance Management  
> - Run `Connect-IPPSSession` before executing

```powershell
#Requires -Version 7
<#
.SYNOPSIS
    Creates the DLP policy: Confidential - Block External Third Party without Recipient

.DESCRIPTION
    Blocks outbound email tagged with "Confidential - Third Parties" that does not
    have IRM protection (PermissionControlled) applied. Catches misconfigured label
    applications where the user-defined permissions dialog was skipped or bypassed.

.PARAMETER TenantDomain
    Your *.onmicrosoft.com domain (used to resolve label identity)

.PARAMETER DryRun
    If specified, shows what would be created without making changes

.EXAMPLE
    ./Create-DlpThirdPartyPolicy.ps1 -TenantDomain "acme2m365.onmicrosoft.com"
    ./Create-DlpThirdPartyPolicy.ps1 -TenantDomain "acme2m365.onmicrosoft.com" -DryRun
#>

param(
    [Parameter(Mandatory)]
    [string]$TenantDomain,

    [switch]$DryRun
)

$PolicyName = "Confidential - Block External Third Party without Recipient"
$RuleName   = "Block-ConfThirdParty-NoEncryptionRecipient"
$LabelName  = "Confidential - Third Parties"

# ── Step 1: Resolve label ImmutableId ────────────────────────────────────────
Write-Host "`n[INFO] Resolving label: $LabelName" -ForegroundColor Cyan

$label = Get-Label -Identity $LabelName -ErrorAction SilentlyContinue
if (-not $label) {
    Write-Error "[ERROR] Label '$LabelName' not found. Verify the label exists and is published before creating this DLP policy."
    exit 1
}

$labelId = $label.ImmutableId
Write-Host "[OK]   Label resolved. ImmutableId: $labelId" -ForegroundColor Green

# ── Step 2: Build label condition object ─────────────────────────────────────
$labelCondition = @{
    operator = "And"
    groups   = @(
        @{
            operator = "Or"
            name     = "Default"
            labels   = @(
                @{
                    name = $labelId
                    type = "Sensitivity"
                }
            )
        }
    )
}

# ── Step 3: Check if policy already exists ────────────────────────────────────
$existingPolicy = Get-DlpCompliancePolicy -Identity $PolicyName -ErrorAction SilentlyContinue

if ($existingPolicy) {
    Write-Host "[EXISTS] Policy '$PolicyName' already exists — skipping creation." -ForegroundColor Yellow
} else {
    if ($DryRun) {
        Write-Host "[DRY RUN] Would create policy: $PolicyName" -ForegroundColor Magenta
    } else {
        Write-Host "[CREATING] Policy: $PolicyName" -ForegroundColor Cyan
        New-DlpCompliancePolicy `
            -Name             $PolicyName `
            -Comment          "Blocks outbound Confidential-Third Parties email where IRM recipients were not configured. Catches misconfigured user-defined permission label applications." `
            -ExchangeLocation All `
            -Mode             Enable
        Write-Host "[OK]   Policy created." -ForegroundColor Green
    }
}

# ── Step 4: Check if rule already exists ─────────────────────────────────────
$existingRule = Get-DlpComplianceRule -Identity $RuleName -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "[EXISTS] Rule '$RuleName' already exists — skipping creation." -ForegroundColor Yellow
} else {
    if ($DryRun) {
        Write-Host "[DRY RUN] Would create rule: $RuleName" -ForegroundColor Magenta
        Write-Host "  Condition:  Label = $LabelName ($labelId)" -ForegroundColor Magenta
        Write-Host "  Condition:  SentToScope = NotInOrganization" -ForegroundColor Magenta
        Write-Host "  Exception:  MessageType = PermissionControlled" -ForegroundColor Magenta
        Write-Host "  Action:     BlockAccess (Block everyone)" -ForegroundColor Magenta
    } else {
        Write-Host "[CREATING] Rule: $RuleName" -ForegroundColor Cyan
        New-DlpComplianceRule `
            -Name                            $RuleName `
            -Policy                          $PolicyName `
            -ContentContainsSensitivityLabel $labelCondition `
            -SentToScope                     NotInOrganization `
            -ExceptIfMessageTypeMatches      PermissionControlled `
            -BlockAccess                     $true `
            -NotifyUser                      Owner `
            -NotifyPolicyTipCustomText       "This email is labeled Confidential - Third Parties but authorised recipients have not been configured. Re-open the email, re-apply the label, and select your authorised recipients before sending." `
            -GenerateAlert                   $true `
            -AlertProperties                 @{
                AggregationType = "SimpleAggregation"
                Threshold       = 1
                TimeWindow      = 60
            }
        Write-Host "[OK]   Rule created." -ForegroundColor Green
    }
}

# ── Step 5: Verify ────────────────────────────────────────────────────────────
Write-Host "`n[INFO] Verification:" -ForegroundColor Cyan
Get-DlpCompliancePolicy -Identity $PolicyName | Format-List Name, Mode, ExchangeLocation
Get-DlpComplianceRule   -Identity $RuleName   | Format-List Name, Disabled, SentToScope, ExceptIfMessageTypeMatches, BlockAccess
```

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

1. Connect via `Connect-IPPSSession -UserPrincipalName admin@<tenant>`
2. Run the deployment script above
3. Verify via `Get-DlpCompliancePolicy` and `Get-DlpComplianceRule`
