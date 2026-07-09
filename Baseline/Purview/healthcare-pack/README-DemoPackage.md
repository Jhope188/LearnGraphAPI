# IAC Purview Demo Package — Financial & Medical Labels
**Confidential - Financial** and **Confidential - Medical** sub-labels  
with EDM schemas, custom SITs, and service-side auto-labeling policies.

---

## Files in This Package

| File | Purpose | Run Order |
|---|---|---|
| `SensitivityLabel.ps1` | Base taxonomy (Personal, Public, General, Confidential, Restricted) | 1 |
| `Add-FinancialMedicalLabels.ps1` | Adds Confidential - Financial and Confidential - Medical sub-labels | 2 |
| `Create-EDMSchemas.ps1` | Creates Financial and Medical EDM schemas + custom MRN SIT | 3 |
| `EDM-Financial-SampleData.csv` | Fake financial records for EDM demo upload | Upload in Step 4 |
| `EDM-Medical-SampleData.csv` | Fake patient records for EDM demo upload | Upload in Step 4 |
| `Create-AutoLabelingPolicies.ps1` | Creates auto-labeling policies (simulation mode) | 5 |

---

## Prerequisites

Before running anything:

1. Run `Enable-SensitivityLabelsPrerequisites.ps1` (existing script — not in this package)
2. Wait up to 24 hours for Groups & Sites scope to become available
3. Ensure `ExchangeOnlineManagement` v3+ is installed:
   ```powershell
   Install-Module ExchangeOnlineManagement -Force
   ```
4. **Teams Premium license** required if using Meetings scope enforcement
5. **E5 Compliance or equivalent** required for EDM SITs and service-side auto-labeling

---

## Run Order

### Step 1 — Base Taxonomy
```powershell
# Dry run first
.\SensitivityLabel.ps1 -TenantDomain "contoso.onmicrosoft.com" -DryRun

# Create labels
.\SensitivityLabel.ps1 -TenantDomain "contoso.onmicrosoft.com"
```

### Step 2 — Add Financial + Medical Labels
```powershell
.\Add-FinancialMedicalLabels.ps1 -TenantDomain "contoso.onmicrosoft.com"
```

Then publish the new labels (add to Confidential policy):
```powershell
Set-LabelPolicy -Identity "IAC - Confidential Label Policy" `
    -AddLabels "Confidential-Financial","Confidential-Medical"
```

### Step 3 — Create EDM Schemas and Custom SIT
```powershell
.\Create-EDMSchemas.ps1 -TenantDomain "contoso.onmicrosoft.com"
```

This creates:
- `FinancialCustomerRecord` EDM schema + SIT
- `PatientMedicalRecord` EDM schema + SIT  
- `Medical Record Number (MRN)` custom SIT (required as EDM primary classifier)

### Step 4 — Upload Sample Data to EDM

**Option A — Purview Portal (easiest for demo):**
1. Go to **Purview portal → Information Protection → Classifiers → EDM Classifiers**
2. Select `EDM - Financial Customer Record` → Upload data → upload `EDM-Financial-SampleData.csv`
3. Select `EDM - Patient Medical Record` → Upload data → upload `EDM-Medical-SampleData.csv`
4. Wait ~1 hour for indexing to complete

**Option B — EDM Upload Agent (production use):**
```cmd
# Download: https://go.microsoft.com/fwlink/?linkid=2088639

EdmUploadAgent.exe /CreateHash /DataStoreName FinancialCustomerRecord ^
  /DataFile EDM-Financial-SampleData.csv /HashLocation C:\EDMHashes\

EdmUploadAgent.exe /UploadHash /DataStoreName FinancialCustomerRecord ^
  /HashLocation C:\EDMHashes\

# Repeat for PatientMedicalRecord / EDM-Medical-SampleData.csv
```

Verify indexing complete:
```powershell
Get-DlpEdmSchema | Format-Table Name, State
# State should show: Completed
```

### Step 5 — Create Auto-Labeling Policies
```powershell
# Run AFTER EDM data is uploaded and indexed
.\Create-AutoLabelingPolicies.ps1 -TenantDomain "contoso.onmicrosoft.com"
```

---

## Label Design Decisions

### Why no Meetings scope on Financial and Medical?

- **Financial**: Financial reporting documents (balance sheets, tax filings, account statements) don't naturally belong in meeting context classification. A meeting discussing finances is General or Confidential-Internal.
- **Medical**: PHI in Teams meeting labels creates HIPAA compliance complexity around recording, transcription, and retention of meeting content. Deliberately excluded until your compliance team reviews the meeting recording retention implications.

### Why are both labels org-wide encrypted (same as Confidential-Internal)?

For a demo/baseline these use the same org-wide Co-Author rights as Confidential-Internal. In production you would typically narrow the encryption rights:
- **Financial**: Finance team + Legal + C-Suite security group
- **Medical**: Clinical staff + Compliance + Legal security group

Update `EncryptionRightsDefinitions` in `Add-FinancialMedicalLabels.ps1` accordingly.

### Why does Medical have a watermark but Financial doesn't?

HIPAA-regulated PHI carries a specific handling obligation that benefits from visual reinforcement at the document level. Financial content is more frequently shared in normal business workflows (invoices, statements) where a watermark would create friction. You can add a watermark to Financial by uncommenting the `-WatermarkText` parameter in `Add-FinancialMedicalLabels.ps1`.

---

## EDM Architecture

### Critical constraint
EDM SITs **cannot be used alone** in auto-labeling rules. If a rule contains only an EDM SIT, Purview silently disables the auto-labeling setting. Every EDM rule must be paired with at least one non-EDM built-in SIT using an AND group operator.

### How the rules work

```
Financial Policy
│
├─ Rule A (OR): ANY of these built-in SITs detected
│   ├─ Credit Card Number (High confidence)
│   ├─ U.S. Bank Account Number (High confidence)
│   ├─ ABA Routing Number (High confidence)
│   └─ U.S. ITIN (Medium confidence)
│
└─ Rule B (AND groups): BOTH must match
    ├─ Group 1: Credit Card Number (built-in SIT — required pairing)
    └─ Group 2: EDM - Financial Customer Record (exact match vs your data)

Medical Policy
│
├─ Rule A (OR): ANY of these SITs detected
│   ├─ U.S. SSN (High confidence)
│   ├─ DEA Number (High confidence)
│   ├─ All Medical Terms and Conditions (Medium confidence)
│   └─ Medical Record Number MRN (Medium confidence — custom SIT)
│
└─ Rule B (AND groups): BOTH must match
    ├─ Group 1: Medical Record Number MRN (custom SIT — required pairing)
    └─ Group 2: EDM - Patient Medical Record (exact match vs your data)
```

Rule A OR Rule B → label applies.  
Within Rule B, both groups must match (AND) — this is what makes EDM high-confidence.

---

## Simulation Mode

Both auto-labeling policies are created in `TestWithoutNotifications` (simulation).  
**No content is labeled until you promote to Enforce.**

Monitor simulation results:
- Purview portal → Information Protection → Auto-labeling → select policy → Items to review

Promote when ready:
```powershell
Set-AutoSensitivityLabelPolicy -Identity "Auto-Label - Confidential Financial" -Mode Enable
Set-AutoSensitivityLabelPolicy -Identity "Auto-Label - Confidential Medical"   -Mode Enable
```

---

## Verification Commands

```powershell
# All labels
Get-Label | Sort-Object Priority | Format-Table DisplayName, Priority, EncryptionEnabled

# EDM schemas
Get-DlpEdmSchema | Format-Table Name, State

# All SITs including custom
Get-DlpSensitiveInformationType | Where-Object Publisher -ne "Microsoft" | Format-Table Name, Publisher

# Auto-labeling policies
Get-AutoSensitivityLabelPolicy | Format-Table Name, Mode, ApplySensitivityLabel

# Auto-labeling rules
Get-AutoSensitivityLabelRule | Format-Table Name, Policy

# Simulation results
Get-AutoSensitivityLabelPolicy -Identity "Auto-Label - Confidential Financial" -IncludeTestModeResults $true
```

---

## References

- [Sensitivity label auto-labeling](https://learn.microsoft.com/en-us/purview/apply-sensitivity-label-automatically)
- [EDM SIT overview](https://learn.microsoft.com/en-us/purview/sit-learn-about-exact-data-match-based-sits)
- [Create EDM SIT (new experience)](https://learn.microsoft.com/en-us/purview/sit-create-edm-sit-unified-ux-workflow)
- [EDM Upload Agent](https://go.microsoft.com/fwlink/?linkid=2088639)
- [New-AutoSensitivityLabelPolicy](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/new-autosensitivitylabelpolicy)
- [New-AutoSensitivityLabelRule](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/new-autosensitivitylabelrule)
