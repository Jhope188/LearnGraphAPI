# CATech DLP & Sensitivity Label Protection Pack

Reference build guide: one section per policy, in the order you'd deploy them. Every policy starts in **SIM** (silent) per the naming convention — flip to `-with notifications` as a policy setting after your baseline period, then rename the ACTION token to `WARN`/`BLOCK` as you promote in the portal or with `Set-DlpCompliancePolicy -Identity "<name>" -Mode Enable`.

All scripts run in **Security & Compliance PowerShell** (`Connect-IPPSSession`), not standard Exchange Online PowerShell. Confirm with `Get-Module -ListAvailable ExchangePowerShell` if unsure which session you're in.

```powershell
Connect-IPPSSession -UserPrincipalName admin@yourtenant.onmicrosoft.com
```

## Naming convention

```
CATech - [Workload] - [Pack/Scope] - [Action]
```

| Segment | Values |
|---|---|
| **Workload** | `EXO` Exchange Online · `SPO` SharePoint/OneDrive · `TEAMS` Teams chat/channels · `COPILOT` M365 Copilot/Copilot Chat · `EDP-AI` Endpoint/browser AI app control |
| **Pack/Scope** | Protection pack + target population combined, e.g. `Confidential-AllUsers`, `Financial-Accounting`, `AntiExfil-AutoForward-AllUsers` |
| **Action** | `SIM` simulation (covers both silent and with-notifications — that's a policy *setting*, not a naming distinction) → `WARN` → `BLOCK` |

Worked example: `CATech - EXO - Financial-AllUsers - SIM` → `CATech - EXO - Financial-AllUsers - BLOCK` once promoted.

Group naming (unchanged from your existing Purview convention): `DG-Purview-AUG-[PolicyArea]-[PolicyName]-[Direction]`, e.g. `DG-Purview-AUG-Financial-AllUsers-Included`.

---

# Part 1 — General (label-based) policies

These apply the same way regardless of *why* content is sensitive — triggered by the sensitivity label itself, not a content pattern. Get each label's GUID first:

```powershell
Get-Label | Select-Object DisplayName, Guid
# Note the GUIDs for Confidential and Restricted — substitute below as $ConfidentialLabelId / $RestrictedLabelId
```

## 1. EXO — Confidential external block

**Policy name:** `CATech - EXO - Confidential-ExternalBlock-AllUsers - SIM`  
**License:** **Business Premium** — core DLP + label-as-condition, confirmed.

**What it is / why:** Confidential is your standard internal-sensitivity label. This policy blocks it leaving via email to anyone outside your own domain(s), while leaving internal Confidential email untouched.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - EXO - Confidential-ExternalBlock-AllUsers - SIM" `
    -Comment "Blocks Confidential-labeled content sent externally via Exchange" `
    -ExchangeLocation All `
    -Mode TestWithoutNotifications

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$ConfidentialLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Confidential External Block Rule" `
    -Policy "CATech - EXO - Confidential-ExternalBlock-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -ExceptIfRecipientDomainIs "yourtenant.com" `
    -BlockAccess $true `
    -NotifyUser Owner,LastModifier `
    -GenerateAlert SecurityTeam@yourtenant.com
```

> **Finish in the portal:** Swap `$ConfidentialLabelId` for the real label GUID from `Get-Label`, and list every accepted domain in `-ExceptIfRecipientDomainIs` (comma-separated) so internal mail between your own domains isn't blocked.

---

## 2. SPO — Confidential external block

**Policy name:** `CATech - SPO - Confidential-ExternalBlock-AllUsers - SIM`  
**License:** **Business Premium** — core DLP + label-as-condition, confirmed.

**What it is / why:** Covers Teams file attachments automatically — files shared in Teams chat/channels are auto-uploaded to SharePoint/OneDrive behind the scenes, so this is the policy that actually catches them. No separate Teams *file* policy needed.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - SPO - Confidential-ExternalBlock-AllUsers - SIM" `
    -Comment "Blocks external sharing of Confidential-labeled SharePoint/OneDrive files" `
    -SharePointLocation All `
    -OneDriveLocation All `
    -Mode TestWithoutNotifications

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$ConfidentialLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Confidential External Sharing Block Rule" `
    -Policy "CATech - SPO - Confidential-ExternalBlock-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -BlockAccess $true `
    -BlockAccessScope All `
    -NotifyUser Owner,LastModifier
```

> **Finish in the portal:** The 'shared with people outside my organization' toggle is easiest to confirm in the portal after this script runs — open the policy, edit the rule, and verify the sharing-scope condition matches what you intend before promoting past SIM.

---

## 3. EXO — Restricted external alert

**Policy name:** `CATech - EXO - Restricted-ExternalAlert-AllUsers - SIM`  
**License:** **Business Premium** — core DLP + label-as-condition, confirmed.

**What it is / why:** Restricted's real access control lives in the label itself — publish it scoped to the restricted group only, with RMS encryption permissions (Co-author for the group, no access for everyone else) set in the label's protection settings. This DLP policy is the second layer: audit trail + block if a group member tries to send it externally anyway.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - EXO - Restricted-ExternalAlert-AllUsers - SIM" `
    -Comment "Alerts + blocks external send of Restricted-labeled content" `
    -ExchangeLocation All `
    -Mode TestWithoutNotifications

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$RestrictedLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Restricted External Alert Rule" `
    -Policy "CATech - EXO - Restricted-ExternalAlert-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -ExceptIfRecipientDomainIs "yourtenant.com" `
    -BlockAccess $true `
    -GenerateAlert SecurityTeam@yourtenant.com `
    -GenerateIncidentReport SecurityTeam@yourtenant.com `
    -IncidentReportContent All
```

> **Finish in the portal:** Set up the Restricted label's group scoping and encryption permissions in Microsoft Purview → Information Protection → Labels *before* this policy goes live — the label is doing the primary access control, not this rule.

---

## 4. SPO — Restricted external alert

**Policy name:** `CATech - SPO - Restricted-ExternalAlert-AllUsers - SIM`  
**License:** **Business Premium** — core DLP + label-as-condition, confirmed.

**What it is / why:** Same label-first logic as the EXO Restricted policy above — this is the SharePoint/OneDrive side of the same control.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - SPO - Restricted-ExternalAlert-AllUsers - SIM" `
    -Comment "Alerts + blocks external sharing of Restricted-labeled files" `
    -SharePointLocation All `
    -OneDriveLocation All `
    -Mode TestWithoutNotifications

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$RestrictedLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Restricted External Sharing Alert Rule" `
    -Policy "CATech - SPO - Restricted-ExternalAlert-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -BlockAccess $true `
    -BlockAccessScope All `
    -GenerateAlert SecurityTeam@yourtenant.com `
    -GenerateIncidentReport SecurityTeam@yourtenant.com
```

---

## 5. TEAMS — Confidential message block

**Policy name:** `CATech - TEAMS - Confidential-ExternalBlock-AllUsers - SIM`  
**License:** **E5 / Purview add-on only** — confirmed gated, not available on Business Premium.

**What it is / why:** Different detection surface from the SPO policy above: this inspects the Teams **message body** itself, not files. Files shared in Teams are already caught by the SPO/OneDrive policy — adding Teams as a location there would be redundant. Only build this one if the client has E5 or the Purview add-on; on Business Premium, skip it.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - TEAMS - Confidential-ExternalBlock-AllUsers - SIM" `
    -Comment "Blocks Confidential-labeled content typed/pasted into Teams messages" `
    -TeamsLocation All `
    -Mode TestWithoutNotifications

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$ConfidentialLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Confidential Teams Block Rule" `
    -Policy "CATech - TEAMS - Confidential-ExternalBlock-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -BlockAccess $true `
    -NotifyUser Owner,LastModifier
```

> **Finish in the portal:** Teams DLP has less override flexibility than Exchange — validate user messaging carefully in SIM before promoting to BLOCK.

---

## 6. TEAMS — Restricted message block

**Policy name:** `CATech - TEAMS - Restricted-ExternalBlock-AllUsers - SIM`  
**License:** **E5 / Purview add-on only** — confirmed gated, not available on Business Premium.

**What it is / why:** Different detection surface from the SPO policy above: this inspects the Teams **message body** itself, not files. Files shared in Teams are already caught by the SPO/OneDrive policy — adding Teams as a location there would be redundant. Only build this one if the client has E5 or the Purview add-on; on Business Premium, skip it.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - TEAMS - Restricted-ExternalBlock-AllUsers - SIM" `
    -Comment "Blocks Restricted-labeled content typed/pasted into Teams messages" `
    -TeamsLocation All `
    -Mode TestWithoutNotifications

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$RestrictedLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Restricted Teams Block Rule" `
    -Policy "CATech - TEAMS - Restricted-ExternalBlock-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -BlockAccess $true `
    -NotifyUser Owner,LastModifier
```

> **Finish in the portal:** Teams DLP has less override flexibility than Exchange — validate user messaging carefully in SIM before promoting to BLOCK.

---

## 7. COPILOT — Confidential prompt block

**Policy name:** `CATech - COPILOT - Confidential-PromptBlock-AllUsers - SIM`  
**License:** **Business Premium — all tiers** with a Copilot license. Confirmed via official Purview service description: prompt-safeguarding DLP is available to any Copilot-licensed user regardless of M365 tier — this is NOT the same gate as grounding-exclusion below.

**What it is / why:** Stops someone typing or pasting Confidential content directly into a Copilot Chat prompt. This is the BP-achievable half of Copilot DLP — don't confuse it with the E5-only grounding control below.

**Script:**

```powershell
# Copilot as a DLP location is configured in the Microsoft Purview portal
# (Data Loss Prevention > Policies > Create policy > Copilot as location) —
# the New-DlpCompliancePolicy location parameter set for Copilot isn't a
# simple named flag the way Exchange/SharePoint/Teams are. Build the rule
# logic here, then attach the Copilot location in the portal wizard.

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$ConfidentialLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Confidential Copilot Prompt Block Rule" `
    -Policy "CATech - COPILOT - Confidential-PromptBlock-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -BlockAccess $true
```

> **Finish in the portal:** Create the policy shell and Copilot location assignment in the Purview portal (Data Loss Prevention → Policies → Create policy → choose Microsoft 365 Copilot as the location), then attach this rule logic to it.

---

## 8. COPILOT — Restricted prompt block

**Policy name:** `CATech - COPILOT - Restricted-PromptBlock-AllUsers - SIM`  
**License:** **Business Premium — all tiers** with a Copilot license. Confirmed via official Purview service description: prompt-safeguarding DLP is available to any Copilot-licensed user regardless of M365 tier — this is NOT the same gate as grounding-exclusion below.

**What it is / why:** Stops someone typing or pasting Restricted content directly into a Copilot Chat prompt. This is the BP-achievable half of Copilot DLP — don't confuse it with the E5-only grounding control below.

**Script:**

```powershell
# Copilot as a DLP location is configured in the Microsoft Purview portal
# (Data Loss Prevention > Policies > Create policy > Copilot as location) —
# the New-DlpCompliancePolicy location parameter set for Copilot isn't a
# simple named flag the way Exchange/SharePoint/Teams are. Build the rule
# logic here, then attach the Copilot location in the portal wizard.

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$RestrictedLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Restricted Copilot Prompt Block Rule" `
    -Policy "CATech - COPILOT - Restricted-PromptBlock-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -BlockAccess $true
```

> **Finish in the portal:** Create the policy shell and Copilot location assignment in the Purview portal (Data Loss Prevention → Policies → Create policy → choose Microsoft 365 Copilot as the location), then attach this rule logic to it.

---

## 9. COPILOT — Confidential grounding exclusion

**Policy name:** `CATech - COPILOT - Confidential-GroundingExclude-AllUsers - SIM`  
**License:** **E5 / Purview add-on only** — confirmed gated. Different control from prompt-block above, don't quote a BP client this one.

**What it is / why:** This is the stronger control: instead of just blocking a prompt that contains Confidential text, it stops Copilot from ever reading a Confidential-labeled file as grounding context in the first place.

**Script:**

```powershell
# E5 / Purview add-on only. Same portal-first approach as the prompt-block
# policy above — Copilot location is assigned in the portal wizard.

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$ConfidentialLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Confidential Copilot Grounding Exclude Rule" `
    -Policy "CATech - COPILOT - Confidential-GroundingExclude-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -RestrictAccess @(@{Setting="ExcludeFromCopilot"; Value="True"})
```

> **Finish in the portal:** Verify the exact `RestrictAccess` setting name against the current Copilot DLP location documentation before deploying — this is a newer, actively-changing policy location and the exact action property may have shifted since this was written. Cross-check in the portal rule builder if the script errors.

---

## 10. COPILOT — Restricted grounding exclusion

**Policy name:** `CATech - COPILOT - Restricted-GroundingExclude-AllUsers - SIM`  
**License:** **E5 / Purview add-on only** — confirmed gated. Different control from prompt-block above, don't quote a BP client this one.

**What it is / why:** This is the stronger control: instead of just blocking a prompt that contains Restricted text, it stops Copilot from ever reading a Restricted-labeled file as grounding context in the first place.

**Script:**

```powershell
# E5 / Purview add-on only. Same portal-first approach as the prompt-block
# policy above — Copilot location is assigned in the portal wizard.

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$RestrictedLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Restricted Copilot Grounding Exclude Rule" `
    -Policy "CATech - COPILOT - Restricted-GroundingExclude-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -RestrictAccess @(@{Setting="ExcludeFromCopilot"; Value="True"})
```

> **Finish in the portal:** Verify the exact `RestrictAccess` setting name against the current Copilot DLP location documentation before deploying — this is a newer, actively-changing policy location and the exact action property may have shifted since this was written. Cross-check in the portal rule builder if the script errors.

---

## 11. EDP-AI — Confidential block to consumer AI apps

**Policy name:** `CATech - EDP-AI - Confidential-BlockUpload-AllUsers - SIM`  
**License:** **E5 / Purview add-on + device onboarding** — no Business Premium equivalent exists. Disclose this as a coverage gap on BP-only clients rather than trying to work around it.

**What it is / why:** This is the one that actually stops someone pasting a Confidential doc into consumer ChatGPT in the browser. The `EndpointDlpRestrictions` action needs the target AI apps in your tenant's restricted/unallowed service domain list — set that up in Settings → Endpoint DLP → Browser and domain restrictions before this rule does anything.

**Script:**

```powershell
# Requires: devices onboarded to Purview/Defender for Endpoint DLP first.
# Confirm onboarding status:
Get-DlpEndpointDevice | Select-Object DeviceName, OnboardingStatus

New-DlpCompliancePolicy -Name "CATech - EDP-AI - Confidential-BlockUpload-AllUsers - SIM" `
    -Comment "Blocks paste/upload of Confidential content to consumer AI apps" `
    -EndpointDlpLocation All `
    -Mode TestWithoutNotifications

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$ConfidentialLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Confidential AI Upload Block Rule" `
    -Policy "CATech - EDP-AI - Confidential-BlockUpload-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -EndpointDlpRestrictions @(@{Setting="UploadText"; Value="Block"}, @{Setting="UploadFile"; Value="Block"})
```

> **Finish in the portal:** Build (or confirm) the unallowed-apps group covering the consumer AI destinations you want blocked — Settings → Data loss prevention → Endpoint DLP settings → Browser and domain restrictions — before promoting this past SIM.

---

## 12. EDP-AI — Restricted block to consumer AI apps

**Policy name:** `CATech - EDP-AI - Restricted-BlockUpload-AllUsers - SIM`  
**License:** **E5 / Purview add-on + device onboarding** — no Business Premium equivalent exists. Disclose this as a coverage gap on BP-only clients rather than trying to work around it.

**What it is / why:** This is the one that actually stops someone pasting a Restricted doc into consumer ChatGPT in the browser. The `EndpointDlpRestrictions` action needs the target AI apps in your tenant's restricted/unallowed service domain list — set that up in Settings → Endpoint DLP → Browser and domain restrictions before this rule does anything.

**Script:**

```powershell
# Requires: devices onboarded to Purview/Defender for Endpoint DLP first.
# Confirm onboarding status:
Get-DlpEndpointDevice | Select-Object DeviceName, OnboardingStatus

New-DlpCompliancePolicy -Name "CATech - EDP-AI - Restricted-BlockUpload-AllUsers - SIM" `
    -Comment "Blocks paste/upload of Restricted content to consumer AI apps" `
    -EndpointDlpLocation All `
    -Mode TestWithoutNotifications

$LabelRule = @"
{
  "Version": "1.0",
  "Condition": {
    "Operator": "And",
    "SubConditions": [
      {
        "ConditionName": "ContentContainsSensitiveInformation",
        "Value": [
          {
            "groups": [
              {
                "Operator": "Or",
                "name": "Default",
                "labels": [
                  { "name": "$RestrictedLabelId", "type": "Sensitivity" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
"@

New-DlpComplianceRule -Name "Restricted AI Upload Block Rule" `
    -Policy "CATech - EDP-AI - Restricted-BlockUpload-AllUsers - SIM" `
    -AdvancedRule $LabelRule `
    -EndpointDlpRestrictions @(@{Setting="UploadText"; Value="Block"}, @{Setting="UploadFile"; Value="Block"})
```

> **Finish in the portal:** Build (or confirm) the unallowed-apps group covering the consumer AI destinations you want blocked — Settings → Data loss prevention → Endpoint DLP settings → Browser and domain restrictions — before promoting this past SIM.

---

# Part 2 — Anti-exfiltration

## 13. EXO — Block auto-forward of sensitive mail

**Policy name:** `CATech - EXO - AntiExfil-AutoForward-AllUsers - SIM`  
**License:** **Business Premium** — `MessageTypeMatches` is a native Exchange DLP condition, confirmed independent of any add-on.

**What it is / why:** Auto-forward detection is a separate condition from content detection — combine them (as above) so legitimate business auto-forwarding rules aren't blocked outright, only ones that are also carrying sensitive data. Expand the `$SITs` list to match whatever verticals below you're also deploying (Financial/Medical SITs).

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - EXO - AntiExfil-AutoForward-AllUsers - SIM" `
    -Comment "Blocks auto-forwarded mail containing sensitive content" `
    -ExchangeLocation All `
    -Mode TestWithoutNotifications

$SITs = @(
    @{Name="U.S. Social Security Number (SSN)"},
    @{Name="Credit Card Number"},
    @{Name="U.S. Bank Account Number"}
)

New-DlpComplianceRule -Name "Auto-Forward Sensitive Content Block Rule" `
    -Policy "CATech - EXO - AntiExfil-AutoForward-AllUsers - SIM" `
    -ContentContainsSensitiveInformation $SITs `
    -MessageTypeMatches AutoForward `
    -BlockAccess $true `
    -GenerateAlert SecurityTeam@yourtenant.com
```

---

# Part 3 — Vertical (content-based) policies

These are SIT-driven — they trigger on content pattern regardless of whether anyone applied a label.

## 14. EXO — Financial data block

**Policy name:** `CATech - EXO - Financial-AllUsers - SIM`  
**License:** **Business Premium** — all listed SITs confirmed core DLP.

**What it is / why:** Content-based, triggers regardless of label. Deploy the Low-confidence discovery rule first (shown here); add a second High-confidence rule at min-count 10 once you've read SIM volume, per the standard two-rule structure.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - EXO - Financial-AllUsers - SIM" `
    -Comment "Blocks financial data sent externally by email" `
    -ExchangeLocation All `
    -Mode TestWithoutNotifications

$SITs = @(
    @{Name="Credit Card Number"}
    @{Name="U.S. Bank Account Number"}
    @{Name="ABA Routing Number"}
    @{Name="SWIFT Code"}
    @{Name="International Banking Account Number (IBAN)"}
)

New-DlpComplianceRule -Name "Financial External Block Rule - Low" `
    -Policy "CATech - EXO - Financial-AllUsers - SIM" `
    -ContentContainsSensitiveInformation $SITs `
    -ExceptIfRecipientDomainIs "yourtenant.com" `
    -NotifyUser Owner,LastModifier
```

---

## 15. SPO — Financial data block

**Policy name:** `CATech - SPO - Financial-AllUsers - SIM`  
**License:** **Business Premium** — confirmed core DLP.

**What it is / why:** Pairs with the EXO Financial policy above.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - SPO - Financial-AllUsers - SIM" `
    -Comment "Blocks external sharing of financial files" `
    -SharePointLocation All `
    -OneDriveLocation All `
    -Mode TestWithoutNotifications

$SITs = @(
    @{Name="Credit Card Number"}
    @{Name="U.S. Bank Account Number"}
    @{Name="ABA Routing Number"}
    @{Name="SWIFT Code"}
    @{Name="International Banking Account Number (IBAN)"}
)

New-DlpComplianceRule -Name "Financial External Sharing Block Rule" `
    -Policy "CATech - SPO - Financial-AllUsers - SIM" `
    -ContentContainsSensitiveInformation $SITs `
    -BlockAccess $true `
    -BlockAccessScope All
```

---

## 16. EXO — Financial Accounting exception (warn)

**Policy name:** `CATech - EXO - Financial-Accounting - SIM`  
**License:** **Business Premium**.

**What it is / why:** Exception companion to the EXO Financial block policy — scoped to the Accounting group via `-ExchangeSenderMemberOf` so approved work continues with a warning + justification prompt instead of a hard block. Give this policy a lower `-Priority` number than the block policy so it evaluates first for Accounting senders.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - EXO - Financial-Accounting - SIM" `
    -Comment "Warns (does not block) Accounting on financial data leaving by email" `
    -ExchangeLocation All `
    -Mode TestWithoutNotifications

$SITs = @(
    @{Name="Credit Card Number"}
    @{Name="U.S. Bank Account Number"}
    @{Name="ABA Routing Number"}
    @{Name="SWIFT Code"}
    @{Name="International Banking Account Number (IBAN)"}
)

New-DlpComplianceRule -Name "Financial Accounting Warn Rule" `
    -Policy "CATech - EXO - Financial-Accounting - SIM" `
    -ContentContainsSensitiveInformation $SITs `
    -ExchangeSenderMemberOf "Accounting@yourtenant.com" `
    -NotifyUser LastModifier `
    -NotifyOverrideRequirements RequireJustification `
    -NotifyAllowOverride BusinessJustification
```

---

## 17. EXO — Medical data block

**Policy name:** `CATech - EXO - Medical-AllUsers - SIM`  
**License:** **Business Premium** — confirmed.

**What it is / why:** The AND grouping (medical SIT **and** a supporting PII SIT) matches actual patient records rather than general medical reference material or training content — this is the pattern from the source workbook, carried through.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - EXO - Medical-AllUsers - SIM" `
    -Comment "Blocks patient/health data sent externally by email" `
    -ExchangeLocation All `
    -Mode TestWithoutNotifications

$MedicalSITs = @(
    @{Name="International Classification of Diseases (ICD-9-CM)"},
    @{Name="International Classification of Diseases (ICD-10-CM)"},
    @{Name="U.S. Drug Enforcement Agency (DEA) Number"}
)
$PIISITs = @(
    @{Name="U.S. Social Security Number (SSN)"}
)

$MedicalRule = @{
    Operator = "And"
    groups = @(
        @{ Operator = "Or"; Name = "Medical Terms"; sensitivetypes = $MedicalSITs }
        @{ Operator = "Or"; Name = "PII Identifiers"; sensitivetypes = $PIISITs }
    )
}

New-DlpComplianceRule -Name "Medical External Block Rule" `
    -Policy "CATech - EXO - Medical-AllUsers - SIM" `
    -ContentContainsSensitiveInformation $MedicalRule `
    -ExceptIfRecipientDomainIs "yourtenant.com" `
    -NotifyUser Owner,LastModifier
```

---

## 18. SPO — Medical data block

**Policy name:** `CATech - SPO - Medical-AllUsers - SIM`  
**License:** **Business Premium** — confirmed.

**What it is / why:** Pairs with the EXO Medical policy above; same AND-grouped condition.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - SPO - Medical-AllUsers - SIM" `
    -Comment "Blocks external sharing of patient records" `
    -SharePointLocation All `
    -OneDriveLocation All `
    -Mode TestWithoutNotifications

$MedicalSITs = @(
    @{Name="International Classification of Diseases (ICD-9-CM)"},
    @{Name="International Classification of Diseases (ICD-10-CM)"},
    @{Name="U.S. Drug Enforcement Agency (DEA) Number"}
)
$PIISITs = @(
    @{Name="U.S. Social Security Number (SSN)"}
)
$MedicalRule = @{
    Operator = "And"
    groups = @(
        @{ Operator = "Or"; Name = "Medical Terms"; sensitivetypes = $MedicalSITs }
        @{ Operator = "Or"; Name = "PII Identifiers"; sensitivetypes = $PIISITs }
    )
}

New-DlpComplianceRule -Name "Medical External Sharing Block Rule" `
    -Policy "CATech - SPO - Medical-AllUsers - SIM" `
    -ContentContainsSensitiveInformation $MedicalRule `
    -BlockAccess $true `
    -BlockAccessScope All
```

---

## 19. EXO — Medical Clinical & Billing exception (warn)

**Policy name:** `CATech - EXO - Medical-ClinicalBilling - SIM`  
**License:** **Business Premium**.

**What it is / why:** Exception companion to the EXO Medical block policy — same pattern as the Financial/Accounting exception above.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - EXO - Medical-ClinicalBilling - SIM" `
    -Comment "Warns (does not block) Clinical & Billing staff on patient data leaving by email" `
    -ExchangeLocation All `
    -Mode TestWithoutNotifications

$MedicalSITs = @(
    @{Name="International Classification of Diseases (ICD-9-CM)"},
    @{Name="International Classification of Diseases (ICD-10-CM)"},
    @{Name="U.S. Drug Enforcement Agency (DEA) Number"}
)
$MedicalRule = @{
    Operator = "And"
    groups = @( @{ Operator = "Or"; Name = "Medical Terms"; sensitivetypes = $MedicalSITs } )
}

New-DlpComplianceRule -Name "Medical ClinicalBilling Warn Rule" `
    -Policy "CATech - EXO - Medical-ClinicalBilling - SIM" `
    -ContentContainsSensitiveInformation $MedicalRule `
    -ExchangeSenderMemberOf "ClinicalBilling@yourtenant.com" `
    -NotifyUser LastModifier `
    -NotifyOverrideRequirements RequireJustification `
    -NotifyAllowOverride BusinessJustification
```

---

## 20. EXO — CUI custom marking block

**Policy name:** `CATech - EXO - CUI-Custom-AllUsers - SIM`  
**License:** **Business Premium** for the DLP mechanics — but read the compliance caveat below before quoting this to a client.

**What it is / why:** ⚠ **Not DFARS/NIST 800-171 compliance.** No built-in Microsoft SIT exists for CUI, so this uses a custom SIT you build from CUI markings. More importantly: DFARS/NIST 800-171 compliance requires the *cloud environment itself* be FedRAMP Moderate-authorized — that's Office 365 GCC High, not commercial Business Premium or commercial E5. This policy is detection hygiene on a commercial tenant, nothing more. Do not represent it as DFARS-compliant to an actual DoD contractor client still on commercial M365.

**Script:**

```powershell
# No built-in Microsoft SIT exists for CUI — build a custom SIT first from
# CUI markings (e.g. "CUI//SP-PRVCY" category banners) via the portal or XML
# upload, then reference it by name below.
#
# See: New-DlpSensitiveInformationTypeRulePackage (requires a saved rule
# package XML file) — https://learn.microsoft.com/purview/sit-customize-a-built-in-sensitive-information-type

New-DlpCompliancePolicy -Name "CATech - EXO - CUI-Custom-AllUsers - SIM" `
    -Comment "Detects CUI-marked content sent externally (hygiene, not DFARS compliance)" `
    -ExchangeLocation All `
    -Mode TestWithoutNotifications

$SITs = @(
    @{Name="CATech Custom CUI Marking"}   # replace with your custom SIT's actual name
)

New-DlpComplianceRule -Name "CUI External Block Rule" `
    -Policy "CATech - EXO - CUI-Custom-AllUsers - SIM" `
    -ContentContainsSensitiveInformation $SITs `
    -ExceptIfRecipientDomainIs "yourtenant.com" `
    -BlockAccess $true `
    -GenerateAlert SecurityTeam@yourtenant.com
```

---

## 21. SPO — CUI custom marking block

**Policy name:** `CATech - SPO - CUI-Custom-AllUsers - SIM`  
**License:** **Business Premium** for the DLP mechanics — same compliance caveat as the EXO CUI policy above.

**What it is / why:** ⚠ Same caveat as policy 20 — pair together, deploy together, disclose together.

**Script:**

```powershell
New-DlpCompliancePolicy -Name "CATech - SPO - CUI-Custom-AllUsers - SIM" `
    -Comment "Detects CUI-marked files shared externally (hygiene, not DFARS compliance)" `
    -SharePointLocation All `
    -OneDriveLocation All `
    -Mode TestWithoutNotifications

$SITs = @(
    @{Name="CATech Custom CUI Marking"}   # replace with your custom SIT's actual name
)

New-DlpComplianceRule -Name "CUI External Sharing Block Rule" `
    -Policy "CATech - SPO - CUI-Custom-AllUsers - SIM" `
    -ContentContainsSensitiveInformation $SITs `
    -BlockAccess $true `
    -BlockAccessScope All
```

---

# Part 4 — Retention labels & publishing policies

Retention labels and DLP/sensitivity labels are separate Purview objects — a retention label controls how long content lives and when it's deleted; it does nothing to protect or block sharing. Two labels can share a name (you already have a retention label called "Confidential" alongside the DLP sensitivity label "Confidential") — that's normal, just don't confuse the two when troubleshooting.

**Precedence, confirmed against Microsoft's retention documentation:** a retention label's delete action always takes precedence over a retention policy's delete action, and the longest retain period wins across whatever's applied to an item. Practically: publishing the labels below doesn't fight your existing 1-year blanket retention policy — it's the fix for it. Anything labeled gets its label's duration; anything unlabeled falls back to the 1-year policy as the floor.

```powershell
Connect-IPPSSession -UserPrincipalName admin@yourtenant.onmicrosoft.com
```

## Retention label inventory

| Label | Duration | Status | Maps to |
|---|---|---|---|
| Sensitive Financial Records | 5 years | Already exists | Financial DLP pack |
| Confidential | 7 years | Already exists | Confidential sensitivity label |
| Product Retired | 10 years | Already exists | — |
| Private | 5 years | Already exists | — |
| Personal Financial PII | 3 years | Already exists | Financial/PII pack |
| Public | 5 years | Already exists | Public pack |
| Employee Records | Forever | Already exists | HR |
| **Restricted** | 7 years | **New — create below** | Restricted sensitivity label |
| **Medical Records** | *state-dependent — see caveat* | **New — create below** | Medical DLP pack |

---

## Existing labels — recreate scripts (reference only)

These already exist in the tenant (per the Purview Labels page). `New-ComplianceTag` will error if you run these against a tenant where the label is already present — they're included here so the whole retention scheme is reproducible from this document alone, e.g. when building a new client tenant from the same design.

```powershell
New-ComplianceTag -Name "Sensitive Financial Records" -RetentionAction Keep -RetentionDuration 1825 -RetentionType ModificationAgeInDays
New-ComplianceTag -Name "Confidential" -RetentionAction Keep -RetentionDuration 2555 -RetentionType ModificationAgeInDays
New-ComplianceTag -Name "Product Retired" -RetentionAction Keep -RetentionDuration 3650 -RetentionType ModificationAgeInDays
New-ComplianceTag -Name "Private" -RetentionAction Keep -RetentionDuration 1825 -RetentionType ModificationAgeInDays
New-ComplianceTag -Name "Personal Financial PII" -RetentionAction Keep -RetentionDuration 1095 -RetentionType ModificationAgeInDays
New-ComplianceTag -Name "Public" -RetentionAction Keep -RetentionDuration 1825 -RetentionType ModificationAgeInDays

# Employee Records — Forever, no delete action
New-ComplianceTag -Name "Employee Records" -RetentionAction Keep -RetentionDuration Unlimited -RetentionType ModificationAgeInDays
```

---

## New label — Restricted

**What it is / why:** Retention counterpart to the Restricted DLP/sensitivity label. Aligned to the same 7-year duration as Confidential — adjust upward if the client's Restricted-tier data (e.g. legal, M&A, board material) needs longer.

```powershell
New-ComplianceTag -Name "Restricted" -RetentionAction Keep -RetentionDuration 2555 `
    -RetentionType ModificationAgeInDays `
    -Comment "Retention counterpart to the Restricted sensitivity label"
```

---

## New label — Medical Records

⚠ **Do not deploy this one on autopilot.** HIPAA itself doesn't set a federal patient-record retention period — that's governed by **state law** and varies (commonly 2–10 years, often longer for minors, sometimes measured from age of majority rather than date of service). What HIPAA *does* set federally is a 6-year retention requirement for **compliance documentation** (policies, risk assessments) under 45 CFR 164.316(b)(2) — that's a different obligation from patient record retention and doesn't substitute for it.

**Before running this:** confirm the client's state requirement. The script below uses 6 years (2190 days) as a conservative placeholder floor — replace `$MedicalRetentionDays` with the confirmed state-specific value.

```powershell
$MedicalRetentionDays = 2190   # PLACEHOLDER — confirm against client state law before publishing

New-ComplianceTag -Name "Medical Records" -RetentionAction Keep -RetentionDuration $MedicalRetentionDays `
    -RetentionType ModificationAgeInDays `
    -Comment "Retention counterpart to the Medical DLP pack — duration confirmed against [state] law on [date]"
```

---

## Publishing policy — makes all labels available for manual use

**License:** Business Premium — confirmed (publishing retention labels for manual application is core, not E5-gated).

**What it is / why:** Publishing doesn't apply anything automatically — it makes every label in the list available for people to pick manually in Outlook, SharePoint, and OneDrive. This is the step that was missing; the labels existed but nothing was using them.

```powershell
New-RetentionCompliancePolicy -Name "CATech - Retention - LabelPublish - AllLocations" `
    -ExchangeLocation All -SharePointLocation All -OneDriveLocation All

New-RetentionComplianceRule -Policy "CATech - Retention - LabelPublish - AllLocations" `
    -PublishComplianceTag "Confidential","Restricted","Sensitive Financial Records","Personal Financial PII","Medical Records","Employee Records","Product Retired","Private","Public"
```

---

## Auto-apply policies — E5 / Purview Suite / IPG only

**License:** Auto-applying a retention label based on content (rather than a human picking it) requires E5, the Purview Suite add-on, or Information Protection & Governance — confirmed via the Microsoft Purview service description, same licensing pattern as the DLP auto-labeling gate covered earlier. Skip this section entirely on Business Premium-only clients; the publishing policy above is as far as BP goes, and that's a real, working outcome on its own.

### Auto-apply Sensitive Financial Records

```powershell
New-RetentionCompliancePolicy -Name "CATech - Retention - AutoApply-Financial - EXO-SPO" `
    -ExchangeLocation All -SharePointLocation All -OneDriveLocation All

New-RetentionComplianceRule -Policy "CATech - Retention - AutoApply-Financial - EXO-SPO" `
    -ApplyComplianceTag "Sensitive Financial Records" `
    -ContentContainsSensitiveInformation @(@{Name="Credit Card Number"},@{Name="U.S. Bank Account Number"},@{Name="ABA Routing Number"})
```

### Auto-apply Medical Records

```powershell
New-RetentionCompliancePolicy -Name "CATech - Retention - AutoApply-Medical - EXO-SPO" `
    -ExchangeLocation All -SharePointLocation All -OneDriveLocation All

New-RetentionComplianceRule -Policy "CATech - Retention - AutoApply-Medical - EXO-SPO" `
    -ApplyComplianceTag "Medical Records" `
    -ContentContainsSensitiveInformation @(@{Name="International Classification of Diseases (ICD-9-CM)"},@{Name="International Classification of Diseases (ICD-10-CM)"})
```

---

## Rollout note

Publishing/auto-apply policies don't have a SIM equivalent the way DLP policies do — a label either gets applied or it doesn't, there's no simulation mode to tune thresholds. Instead:

1. Publish first (manual availability), let users start applying labels for a couple of weeks.
2. Check **Data classification → Content explorer** in the Purview portal to see actual label adoption before turning on any auto-apply policy — auto-apply on top of an untested label taxonomy just compounds a mistake at scale.
3. Only add auto-apply once the manual labels are confirmed correct and the client's on E5-tier.

# Rollout sequence for every policy above

| Day(s) | Mode | Action |
|---|---|---|
| 1–3 | `-Mode TestWithoutNotifications` | Silent baseline — no user impact, read match volume, set the Low rule min-count from real data |
| 4–7 | Same policy, toggle policy tips on | `Set-DlpCompliancePolicy -Identity "<name>" -Mode TestWithNotifications` — users see tips, can report false positives |
| 8+ | Promote | `Set-DlpCompliancePolicy -Identity "<name>" -Mode Enable` for BLOCK; rename the ACTION token in the display name to match |

Same policy object throughout — never delete and recreate to move between stages.
