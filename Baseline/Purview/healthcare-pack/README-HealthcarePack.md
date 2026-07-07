# IAC Healthcare Compliance Pack
**HIPAA / HITECH / 42 CFR Part 2 Aligned**  
Additive overlay for the IAC base sensitivity label taxonomy.

---

## Architecture

This pack is completely separate from the base taxonomy. It deploys alongside it, not inside it.

```
BASE TAXONOMY (universal — deploy to all customers)
  Personal, Public, General
  Confidential: Internal, Third Parties, Reporting
  Restricted: Internal, Third Parties

HEALTHCARE PACK (additive — deploy to healthcare customers only)
  Healthcare: General, Confidential, Privileged, Research
  + 2 mail-enabled security groups
  + 3 DLP policies
  + 1 auto-labeling policy (via Create-EDMSchemas + healthcare auto-label script)
```

No naming collision with the base taxonomy. Healthcare labels are published separately, scoped to clinical staff — not org-wide.

---

## Label Design

| Label | Encryption | Scope | HIPAA Coverage |
|---|---|---|---|
| Healthcare - General | None | File, Email, Site, Group, Meetings | Internal operational content — NOT PHI |
| Healthcare - Confidential | Org-wide (Co-Author) | File, Email, Site, Group | Standard PHI — §164.312 |
| Healthcare - Privileged | Purview-Medical-Privileged group | File, Email only | Special Categories: psychotherapy notes, HIV/AIDS, substance abuse (42 CFR Part 2), genetic info (GINA), mental health |
| Healthcare - Research | Purview-Medical-Research group | File, Email only | IRB-governed — HIPAA Safe Harbor / Expert Determination |

### Why no Meetings scope on Confidential, Privileged, Research?

PHI in Teams meeting recordings and transcripts creates compounded compliance complexity — retention policies, transcript access controls, and recording consent interact in ways that vary by state law. The deliberate exclusion forces a conscious decision: if a customer wants to label PHI meetings, they add Meetings scope explicitly after reviewing their state-specific consent and retention obligations.

### Why no Site/UnifiedGroup scope on Privileged and Research?

You don't want "Healthcare - Privileged" labeling an entire SharePoint site or Teams channel. That would restrict every file and conversation in that container to the Purview-Medical-Privileged group. These labels are file and email-scoped only — the encryption travels with the document, not the container.

---

## Security Groups

| Group | Purpose | Membership |
|---|---|---|
| Purview-Medical-Privileged@domain | Decrypt Healthcare - Privileged content | Clinical lead, Compliance, Legal, Privacy officer |
| Purview-Medical-Research@domain | Decrypt Healthcare - Research content | IRB members, Research compliance, Named investigators |

Both groups are hidden from the GAL — they are system groups, not for general directory visibility.

**PIM recommendation:** Configure these groups with PIM for Groups in Entra ID. Standing membership should be minimal (compliance lead, privacy officer). Clinical staff activate JIT for a bounded window when they need access to special category records.

---

## DLP Policies

### Policy 1 — HIPAA PHI Exfiltration Prevention
Uses Microsoft's documented HIPAA DLP condition pattern:

```
Group 1 (identity) OR:          Group 2 (medical) OR:
  U.S. SSN                        All Medical Terms and Conditions
  DEA Number                      ICD-10-CM codes
  Medical Record Number (MRN)

Group 1 AND Group 2 must both match → PHI detected
```

The AND logic is critical. A document containing only an SSN is not necessarily PHI. A document containing only medical terms is not necessarily PHI. Both together in the same document is high-confidence PHI.

Actions: Block external sharing, encrypt outbound email, alert compliance team, show policy tip to user.

### Policy 2 — Privileged PHI Extra Controls
Label-based trigger: Healthcare - Privileged applied → strictest controls.
- Block ALL external sharing (no exception prompt)
- Immediate high-severity compliance alert
- Block Teams sharing

### Policy 3 — Copilot PHI Boundary
Prevents Microsoft 365 Copilot from processing Healthcare - Confidential or Healthcare - Privileged labeled content in summaries, responses, or citations.

**Important:** Sensitivity label conditions in DLP rules cannot be combined with SIT conditions in the same rule. The Copilot policy uses label-only conditions. After script runs, verify label conditions are set in Purview portal.

---

## Files in This Pack

| File | Purpose | Run Order |
|---|---|---|
| `Add-HealthcareLabels.ps1` | Creates security groups + Healthcare label group + 4 sub-labels | 1 |
| `Create-HealthcareDLPPolicies.ps1` | Creates 3 HIPAA DLP policies (audit mode) | 2 |
| `README-HealthcarePack.md` | This file | — |

**Reused from base demo pack (run separately if not already done):**
- `Create-EDMSchemas.ps1` — creates Patient Medical Record EDM schema + MRN custom SIT
- `EDM-Medical-SampleData.csv` — sample patient data for EDM upload

---

## Prerequisites

Before running this pack:

1. **Base taxonomy deployed**: `SensitivityLabel.ps1` must have been run
2. **Azure RMS active**: Verify at `Get-AipServiceConfiguration | Select-Object IsServiceActive`
3. **BAA signed**: Microsoft Business Associate Agreement accepted for the tenant
4. **Licensing**: E5 Compliance or Microsoft 365 E5 for:
   - EDM SITs
   - Named entity SITs (All medical terms and conditions)
   - Service-side auto-labeling
   - Advanced DLP (endpoint + Teams)
5. **Exchange Online Management Shell v3+**: `Install-Module ExchangeOnlineManagement -Force`

---

## Run Order

### Step 1 — Create Groups and Labels
```powershell
# Dry run first
.\Add-HealthcareLabels.ps1 -TenantDomain "contoso.onmicrosoft.com" -DryRun

# Deploy
.\Add-HealthcareLabels.ps1 -TenantDomain "contoso.onmicrosoft.com"

# With label prefix
.\Add-HealthcareLabels.ps1 -TenantDomain "contoso.onmicrosoft.com" -LabelPrefix "Contoso"
```

### Step 2 — Add Members to Security Groups
```powershell
# Add clinical/compliance staff to Privileged group
Add-DistributionGroupMember `
    -Identity "Purview-Medical-Privileged@contoso.onmicrosoft.com" `
    -Member   "compliance.officer@contoso.onmicrosoft.com"

# Add research team to Research group
Add-DistributionGroupMember `
    -Identity "Purview-Medical-Research@contoso.onmicrosoft.com" `
    -Member   "principal.investigator@contoso.onmicrosoft.com"
```

### Step 3 — Publish Labels to Healthcare Staff
Publish to a healthcare staff security group, NOT org-wide:
```powershell
New-LabelPolicy `
    -Name        "IAC - Healthcare Label Policy" `
    -Labels      @("Healthcare-General","Healthcare-Confidential","Healthcare-Privileged","Healthcare-Research") `
    -ExchangeLocation All `
    -ModernGroupLocation All `
    -Comment     "Healthcare sensitivity labels for clinical staff. HIPAA-aligned."
```
Then scope to users:
```
Purview portal → Information Protection → Label policies
→ IAC - Healthcare Label Policy → Edit → Choose users/groups
→ Scope to: SG-ClinicalStaff or equivalent
```

### Step 4 — Create EDM Schemas (if not already done)
```powershell
.\Create-EDMSchemas.ps1 -TenantDomain "contoso.onmicrosoft.com"
# Upload EDM-Medical-SampleData.csv per instructions in that script
```

### Step 5 — Create DLP Policies
```powershell
.\Create-HealthcareDLPPolicies.ps1 `
    -TenantDomain    "contoso.onmicrosoft.com" `
    -ComplianceEmail "hipaa-compliance@contoso.onmicrosoft.com"
```

### Step 6 — Review Copilot Policy Manually
After DLP script runs, the Copilot policy needs label conditions verified in portal:

```
Purview portal → Data Loss Prevention → HIPAA - Copilot PHI Boundary
→ Edit policy → Edit rule → PHI Labels - Block Copilot Processing
→ Add condition: Content contains sensitivity label → Healthcare - Confidential
→ Add condition: Content contains sensitivity label → Healthcare - Privileged
→ Save
```

### Step 7 — Monitor in Audit Mode (2-4 weeks)
```
Purview portal → Solutions → Data Loss Prevention → Alerts
Review matches, tune false positives before enforcing.
```

### Step 8 — Promote to Enforce
```powershell
Set-DlpCompliancePolicy -Identity "HIPAA - PHI Exfiltration Prevention" -Mode Enable
Set-DlpCompliancePolicy -Identity "HIPAA - Privileged PHI Controls"     -Mode Enable
Set-DlpCompliancePolicy -Identity "HIPAA - Copilot PHI Boundary"        -Mode Enable
```

---

## HIPAA Control Mapping

| HIPAA Rule | Section | Control | Implementation |
|---|---|---|---|
| Security Rule | §164.312(a)(1) | Access Control | Named group encryption on Privileged + Research labels |
| Security Rule | §164.312(a)(2)(i) | Unique User Identification | Encryption tied to Entra identity — every access logged |
| Security Rule | §164.312(b) | Audit Controls | DLP alert logs + Purview Activity Explorer |
| Security Rule | §164.312(c)(1) | Integrity | Encryption prevents unauthorized modification |
| Security Rule | §164.312(e)(2)(ii) | Encryption in Transit | Label encryption applies to email + file in transit |
| Privacy Rule | §164.524 | Patient Access Rights | Super User group enables authorized PHI retrieval |
| Privacy Rule | §164.512 | Special Categories | Healthcare - Privileged label for 42 CFR Part 2 / GINA |
| Breach Notification | §164.400-414 | Notification | DLP alerts provide audit trail for breach assessment |

**42 CFR Part 2 note:** Substance abuse treatment records are governed by a separate federal regulation that is stricter than HIPAA. The Healthcare - Privileged label and Purview-Medical-Privileged group provide the access restriction required, but your customer must also implement consent tracking and disclosure accounting outside Purview for full 42 CFR Part 2 compliance.

---

## Verification Commands

```powershell
# Security groups
Get-DistributionGroup -Filter "Name -like 'Purview-Medical*'" |
    Format-Table Name, PrimarySmtpAddress, HiddenFromAddressListsEnabled

# Group members
Get-DistributionGroupMember -Identity "Purview-Medical-Privileged@domain.com" |
    Format-Table Name, PrimarySmtpAddress

# Healthcare labels
Get-Label | Where-Object { $_.DisplayName -like "Healthcare*" } |
    Sort-Object Priority |
    Format-Table DisplayName, Priority, EncryptionEnabled, ContentType

# DLP policies
Get-DlpCompliancePolicy | Where-Object { $_.Name -like "HIPAA*" } |
    Format-Table Name, Mode, Enabled

# DLP rules
Get-DlpComplianceRule | Where-Object { $_.Policy -like "HIPAA*" } |
    Format-Table Name, Policy, Disabled
```

---

## References

- [HIPAA DLP condition pattern — Microsoft Learn](https://learn.microsoft.com/en-us/purview/dlp-policy-reference)
- [Sensitivity labels encryption — Microsoft Learn](https://learn.microsoft.com/en-us/purview/encryption-sensitivity-labels)
- [42 CFR Part 2 — SAMHSA](https://www.samhsa.gov/about-us/who-we-are/laws-regulations/confidentiality-regulations-faqs)
- [GINA — EEOC](https://www.eeoc.gov/laws/statutes/gina.cfm)
- [Microsoft HIPAA BAA](https://www.microsoft.com/en-us/trust-center/compliance/hipaa)
- [New-DistributionGroup — Microsoft Learn](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/new-distributiongroup)
