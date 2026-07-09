<#
.SYNOPSIS
    Creates service-side auto-labeling policies for Confidential - Financial and
    Confidential - Medical labels.

.DESCRIPTION
    Creates two auto-labeling policies in Simulation mode (safe — no content
    is labelled until you promote to Enforce):

    POLICY 1: Auto-Label - Confidential Financial
        Label    : Confidential - Financial
        Locations: SharePoint (All), OneDrive (All), Exchange (All)
        Rule A   : Built-in SITs (Credit Card, Bank Account, ABA, SSN, ITIN)
                   → High-confidence financial content detection
        Rule B   : EDM SIT (Financial Customer Record) paired with Credit Card SIT
                   → Exact match against your customer account database
        Logic    : Rule A OR Rule B → apply label
                   Within Rule B: Credit Card SIT AND EDM SIT (required — EDM alone
                   silently disables auto-labeling per Microsoft platform constraint)

    POLICY 2: Auto-Label - Confidential Medical
        Label    : Confidential - Medical
        Locations: SharePoint (All), OneDrive (All), Exchange (All)
        Rule A   : Built-in SITs (Medical Terms named entity, SSN, DEA Number, MRN custom SIT)
                   → Broad PHI content detection
        Rule B   : EDM SIT (Patient Medical Record) paired with MRN custom SIT
                   → Exact match against your patient database
        Logic    : Rule A OR Rule B → apply label

    CRITICAL CONSTRAINT — EDM + built-in SIT pairing:
        EDM SITs cannot be used alone in auto-labeling rules. If a rule contains
        only an EDM SIT, Purview silently disables the auto-labeling setting.
        Every rule that references an EDM SIT must also include at least one
        non-EDM SIT. This is implemented via the AND group operator below.
        Reference: https://learn.microsoft.com/en-us/purview/apply-sensitivity-label-automatically

    SIMULATION MODE:
        All policies start in TestWithoutNotifications (simulation).
        Review results in Purview portal → Information Protection → Auto-labeling
        → select policy → Items to review tab.
        Run simulation for 1-2 weeks before promoting to Enforce.
        Promote with: Set-AutoSensitivityLabelPolicy -Identity "<name>" -Mode Enable

.PARAMETER TenantDomain
    Your tenant's primary onmicrosoft.com domain.

.PARAMETER LabelPrefix
    Optional prefix matching what was used in SensitivityLabel.ps1.

.PARAMETER DryRun
    Shows what would be created without making changes.

.EXAMPLE
    .\Create-AutoLabelingPolicies.ps1 -TenantDomain "contoso.onmicrosoft.com"
    .\Create-AutoLabelingPolicies.ps1 -TenantDomain "contoso.onmicrosoft.com" -DryRun

.NOTES
    Author:   IAC
    Date:     2026-06-24
    Requires: ExchangeOnlineManagement v3+, EDM schemas uploaded and indexed
    Roles:    Compliance Administrator or Information Protection Administrator

    Built-in SIT GUIDs referenced in this script (stable, not tenant-specific):
        Credit Card Number         : a44669fe-0d48-453d-a9b1-2cc83f2cba77
        U.S. Bank Account Number   : c8763536-a325-4245-a49e-cae7c5e6f08e
        ABA Routing Number         : a0ce132a-a558-4803-8fe0-df56a6fcecc4
        U.S. SSN                   : a44669fe-0d48-453d-a9b1-2cc83f2cba77 (reused as anchor)
        U.S. ITIN                  : e55e2a32-f92d-4985-a35d-a0b269eb687b
        DEA Number                 : db397464-23a3-4be3-8f7f-5027d3b7f284
        All Medical Terms (named)  : Use display name — GUID varies by tenant
        Medical Record Number (MRN): Created by Create-EDMSchemas.ps1 — resolved by name

    EDM SIT GUIDs: Resolved at runtime via Get-DlpSensitiveInformationType
    (EDM GUIDs are tenant-specific and generated at schema creation time)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [string]$LabelPrefix = "",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

function Get-LabelName {
    param([Parameter(Mandatory)][string]$BaseName)
    if ([string]::IsNullOrWhiteSpace($LabelPrefix)) { return $BaseName }
    return "$LabelPrefix-$BaseName"
}

# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IAC Auto-Labeling Policy Creation" -ForegroundColor Cyan
Write-Host "  Financial + Medical (Simulation Mode)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow }
Write-Host ""
Write-Host "  All policies created in SIMULATION mode." -ForegroundColor Yellow
Write-Host "  No content will be labelled until you promote to Enforce." -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# CONNECT
# ============================================================================
try {
    Get-Label -ErrorAction Stop | Out-Null
    Write-Host "[OK] Already connected to Security & Compliance" -ForegroundColor Green
} catch {
    Write-Host "[..] Connecting..." -ForegroundColor Yellow
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "[OK] Connected" -ForegroundColor Green
}

if (-not $TenantDomain) {
    $TenantDomain = ((Get-ConnectionInformation | Select-Object -First 1).UserPrincipalName).Split('@')[1]
    Write-Host "[OK] TenantDomain derived: $TenantDomain" -ForegroundColor Green
}

# ============================================================================
# RESOLVE LABELS
# ============================================================================
Write-Host "[..] Resolving label GUIDs..." -ForegroundColor Yellow

$financialLabelName = Get-LabelName "Confidential-Financial"
$medicalLabelName   = Get-LabelName "Confidential-Medical"

$financialLabel = Get-Label -Identity $financialLabelName -ErrorAction SilentlyContinue
$medicalLabel   = Get-Label -Identity $medicalLabelName   -ErrorAction SilentlyContinue

if (-not $financialLabel -and -not $DryRun) {
    Write-Host "[ERROR] Label '$financialLabelName' not found. Run Add-FinancialMedicalLabels.ps1 first." -ForegroundColor Red
    exit 1
}
if (-not $medicalLabel -and -not $DryRun) {
    Write-Host "[ERROR] Label '$medicalLabelName' not found. Run Add-FinancialMedicalLabels.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Financial label: $($financialLabel.DisplayName) ($($financialLabel.ImmutableId))" -ForegroundColor Green
Write-Host "[OK] Medical label  : $($medicalLabel.DisplayName) ($($medicalLabel.ImmutableId))" -ForegroundColor Green

# ============================================================================
# RESOLVE EDM SIT GUIDs (tenant-specific — must query at runtime)
# ============================================================================
Write-Host "[..] Resolving EDM SIT GUIDs..." -ForegroundColor Yellow

$allSITs = Get-DlpSensitiveInformationType -ErrorAction SilentlyContinue

$edmFinancialSIT = $allSITs | Where-Object { $_.Name -eq "EDM - Financial Customer Record" } | Select-Object -First 1
$edmMedicalSIT   = $allSITs | Where-Object { $_.Name -eq "EDM - Patient Medical Record"    } | Select-Object -First 1
$mrnCustomSIT    = $allSITs | Where-Object { $_.Name -eq "Medical Record Number (MRN)"     } | Select-Object -First 1

$edmFinancialAvailable = $null -ne $edmFinancialSIT
$edmMedicalAvailable   = $null -ne $edmMedicalSIT
$mrnSITAvailable       = $null -ne $mrnCustomSIT

if (-not $edmFinancialAvailable) {
    Write-Host "[WARN] EDM - Financial Customer Record SIT not found." -ForegroundColor Yellow
    Write-Host "[WARN] Run Create-EDMSchemas.ps1 and upload data before EDM rules will work." -ForegroundColor Yellow
    Write-Host "[WARN] Financial policy will be created with built-in SITs only for now." -ForegroundColor Yellow
}
if (-not $edmMedicalAvailable) {
    Write-Host "[WARN] EDM - Patient Medical Record SIT not found." -ForegroundColor Yellow
    Write-Host "[WARN] Run Create-EDMSchemas.ps1 and upload data before EDM rules will work." -ForegroundColor Yellow
    Write-Host "[WARN] Medical policy will be created with built-in SITs only for now." -ForegroundColor Yellow
}
if (-not $mrnSITAvailable) {
    Write-Host "[WARN] Medical Record Number (MRN) custom SIT not found." -ForegroundColor Yellow
    Write-Host "[WARN] Run Create-EDMSchemas.ps1 first to create the MRN SIT." -ForegroundColor Yellow
}

# ============================================================================
# HELPER: Check if auto-labeling policy already exists
# ============================================================================
function Test-AutoLabelPolicyExists {
    param([string]$PolicyName)
    $existing = Get-AutoSensitivityLabelPolicy -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $PolicyName }
    return ($null -ne $existing)
}

# ============================================================================
# POLICY 1 — CONFIDENTIAL FINANCIAL
# ============================================================================
Write-Host ""
Write-Host "--- [1/2] Auto-Label - Confidential Financial ---" -ForegroundColor Magenta
Write-Host ""

$financialPolicyName   = "Auto-Label - Confidential Financial"
$financialRuleNameSIT  = "Financial - Built-in SITs"
$financialRuleNameEDM  = "Financial - EDM Customer Record"

if (Test-AutoLabelPolicyExists -PolicyName $financialPolicyName) {
    Write-Host "  [EXISTS] Policy '$financialPolicyName' already present — skipping" -ForegroundColor Gray
} elseif ($DryRun) {
    Write-Host "  [DRY RUN] Would create policy : $financialPolicyName" -ForegroundColor Yellow
    Write-Host "  [DRY RUN] Would create rule   : $financialRuleNameSIT (Credit Card, Bank Account, ABA, ITIN)" -ForegroundColor Yellow
    if ($edmFinancialAvailable) {
        Write-Host "  [DRY RUN] Would create rule   : $financialRuleNameEDM (Credit Card SIT AND EDM)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [..] Creating policy: $financialPolicyName" -ForegroundColor Yellow

    try {
        # Create policy in simulation mode
        New-AutoSensitivityLabelPolicy `
            -Name                  $financialPolicyName `
            -Comment               "Auto-labels documents containing financial account data. Simulation mode — review before enforcing." `
            -ApplySensitivityLabel $financialLabelName `
            -SharePointLocation    "All" `
            -OneDriveLocation      "All" `
            -ExchangeLocation      "All" `
            -Mode                  TestWithoutNotifications

        Write-Host "  [OK] Policy created in simulation mode" -ForegroundColor Green

        # Rule A — Built-in SITs (OR logic — any one match triggers)
        # mincount=1 for demo; increase to 2-5 in production to reduce false positives
        Write-Host "  [..] Creating Rule A: Built-in financial SITs..." -ForegroundColor Yellow

        $builtInFinancialSITs = @(
            @{ name = "Credit Card Number";            mincount = "1"; confidencelevel = "High"   },
            @{ name = "U.S. Bank Account Number";      mincount = "1"; confidencelevel = "High"   },
            @{ name = "ABA Routing Number";            mincount = "1"; confidencelevel = "High"   },
            @{ name = "U.S. Individual Taxpayer Identification Number (ITIN)"; mincount = "1"; confidencelevel = "Medium" }
        )

        New-AutoSensitivityLabelRule `
            -Name                             $financialRuleNameSIT `
            -Policy                           $financialPolicyName `
            -ContentContainsSensitiveInformation $builtInFinancialSITs `
            -Workload                         "SharePoint,OneDrive,Exchange"

        Write-Host "  [OK] Rule A created: Built-in SITs" -ForegroundColor Green

        # Rule B — EDM + Credit Card SIT (AND logic via group operator)
        # EDM must be paired with at least one non-EDM SIT — this is the required pattern
        if ($edmFinancialAvailable) {
            Write-Host "  [..] Creating Rule B: EDM + Credit Card paired rule..." -ForegroundColor Yellow

            # Group operator: AND — both the built-in SIT AND the EDM SIT must match
            $edmFinancialCondition = @(
                @{
                    operator = "And"
                    groups   = @(
                        @{
                            name         = "BuiltInSIT"
                            operator     = "Or"
                            sensitivetypes = @(
                                @{
                                    id             = "a44669fe-0d48-453d-a9b1-2cc83f2cba77"
                                    name           = "Credit Card Number"
                                    mincount       = "1"
                                    maxcount       = "-1"
                                    confidencelevel = "High"
                                    classifiertype = "Content"
                                }
                            )
                        },
                        @{
                            name         = "EDMMatch"
                            operator     = "Or"
                            sensitivetypes = @(
                                @{
                                    id             = $edmFinancialSIT.RulePackId
                                    name           = "EDM - Financial Customer Record"
                                    mincount       = "1"
                                    maxcount       = "-1"
                                    confidencelevel = "Medium"
                                    classifiertype = "ExactMatch"
                                }
                            )
                        }
                    )
                }
            )

            New-AutoSensitivityLabelRule `
                -Name                             $financialRuleNameEDM `
                -Policy                           $financialPolicyName `
                -ContentContainsSensitiveInformation $edmFinancialCondition `
                -Workload                         "SharePoint,OneDrive,Exchange"

            Write-Host "  [OK] Rule B created: EDM + Credit Card" -ForegroundColor Green
        } else {
            Write-Host "  [SKIP] Rule B skipped — EDM SIT not yet available. Add after uploading data:" -ForegroundColor Yellow
            Write-Host "  [SKIP] Re-run this script after Create-EDMSchemas.ps1 + data upload." -ForegroundColor Yellow
        }

    } catch {
        Write-Host "  [ERROR] Failed to create Financial auto-labeling policy: $_" -ForegroundColor Red
    }
}

# ============================================================================
# POLICY 2 — CONFIDENTIAL MEDICAL
# ============================================================================
Write-Host ""
Write-Host "--- [2/2] Auto-Label - Confidential Medical ---" -ForegroundColor Magenta
Write-Host ""

$medicalPolicyName   = "Auto-Label - Confidential Medical"
$medicalRuleNameSIT  = "Medical - Built-in SITs"
$medicalRuleNameEDM  = "Medical - EDM Patient Record"

if (Test-AutoLabelPolicyExists -PolicyName $medicalPolicyName) {
    Write-Host "  [EXISTS] Policy '$medicalPolicyName' already present — skipping" -ForegroundColor Gray
} elseif ($DryRun) {
    Write-Host "  [DRY RUN] Would create policy : $medicalPolicyName" -ForegroundColor Yellow
    Write-Host "  [DRY RUN] Would create rule   : $medicalRuleNameSIT (Medical Terms, SSN, DEA, MRN)" -ForegroundColor Yellow
    if ($edmMedicalAvailable) {
        Write-Host "  [DRY RUN] Would create rule   : $medicalRuleNameEDM (MRN SIT AND EDM)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [..] Creating policy: $medicalPolicyName" -ForegroundColor Yellow

    try {
        New-AutoSensitivityLabelPolicy `
            -Name                  $medicalPolicyName `
            -Comment               "Auto-labels documents containing PHI or medical record data. Simulation mode — review before enforcing." `
            -ApplySensitivityLabel $medicalLabelName `
            -SharePointLocation    "All" `
            -OneDriveLocation      "All" `
            -ExchangeLocation      "All" `
            -Mode                  TestWithoutNotifications

        Write-Host "  [OK] Policy created in simulation mode" -ForegroundColor Green

        # Rule A — Built-in + custom SITs
        Write-Host "  [..] Creating Rule A: Built-in medical SITs..." -ForegroundColor Yellow

        # Build SIT condition array dynamically — include MRN only if custom SIT was created
        $builtInMedicalSITs = @(
            @{ name = "U.S. Social Security Number (SSN)";          mincount = "1"; confidencelevel = "High"   },
            @{ name = "Drug Enforcement Agency (DEA) Number";        mincount = "1"; confidencelevel = "High"   },
            @{ name = "All medical terms and conditions";            mincount = "1"; confidencelevel = "Medium" }
        )

        if ($mrnSITAvailable) {
            $builtInMedicalSITs += @{ name = "Medical Record Number (MRN)"; mincount = "1"; confidencelevel = "Medium" }
        }

        New-AutoSensitivityLabelRule `
            -Name                             $medicalRuleNameSIT `
            -Policy                           $medicalPolicyName `
            -ContentContainsSensitiveInformation $builtInMedicalSITs `
            -Workload                         "SharePoint,OneDrive,Exchange"

        Write-Host "  [OK] Rule A created: Built-in + MRN SITs" -ForegroundColor Green

        # Rule B — EDM + MRN SIT (AND group — EDM must be paired with non-EDM SIT)
        if ($edmMedicalAvailable -and $mrnSITAvailable) {
            Write-Host "  [..] Creating Rule B: EDM + MRN paired rule..." -ForegroundColor Yellow

            $edmMedicalCondition = @(
                @{
                    operator = "And"
                    groups   = @(
                        @{
                            name         = "MRNSit"
                            operator     = "Or"
                            sensitivetypes = @(
                                @{
                                    id             = $mrnCustomSIT.RulePackId
                                    name           = "Medical Record Number (MRN)"
                                    mincount       = "1"
                                    maxcount       = "-1"
                                    confidencelevel = "High"
                                    classifiertype = "Content"
                                }
                            )
                        },
                        @{
                            name         = "EDMMatch"
                            operator     = "Or"
                            sensitivetypes = @(
                                @{
                                    id             = $edmMedicalSIT.RulePackId
                                    name           = "EDM - Patient Medical Record"
                                    mincount       = "1"
                                    maxcount       = "-1"
                                    confidencelevel = "Medium"
                                    classifiertype = "ExactMatch"
                                }
                            )
                        }
                    )
                }
            )

            New-AutoSensitivityLabelRule `
                -Name                             $medicalRuleNameEDM `
                -Policy                           $medicalPolicyName `
                -ContentContainsSensitiveInformation $edmMedicalCondition `
                -Workload                         "SharePoint,OneDrive,Exchange"

            Write-Host "  [OK] Rule B created: EDM + MRN" -ForegroundColor Green
        } elseif ($edmMedicalAvailable -and -not $mrnSITAvailable) {
            Write-Host "  [SKIP] Rule B skipped — MRN custom SIT not found. Run Create-EDMSchemas.ps1 first." -ForegroundColor Yellow
        } else {
            Write-Host "  [SKIP] Rule B skipped — EDM SIT not yet available. Re-run after data upload." -ForegroundColor Yellow
        }

    } catch {
        Write-Host "  [ERROR] Failed to create Medical auto-labeling policy: $_" -ForegroundColor Red
    }
}

# ============================================================================
# SIMULATION GUIDANCE
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  SIMULATION MODE — What To Do Next" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Wait 24-48 hours for simulation to scan SharePoint/OneDrive." -ForegroundColor White
Write-Host ""
Write-Host "  2. Review results in Purview portal:" -ForegroundColor White
Write-Host "     Information Protection → Auto-labeling → select each policy" -ForegroundColor Gray
Write-Host "     → 'Items to review' tab shows matched content before labeling" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Check for false positives. Tune if needed:" -ForegroundColor White
Write-Host "     → Increase mincount (e.g. 1 → 3) to reduce noise" -ForegroundColor Gray
Write-Host "     → Change confidencelevel from Medium to High" -ForegroundColor Gray
Write-Host "     → Exclude specific sites with -AddSharePointLocationException" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. When satisfied, promote to Enforce:" -ForegroundColor White
Write-Host "     Set-AutoSensitivityLabelPolicy -Identity '$financialPolicyName' -Mode Enable" -ForegroundColor Cyan
Write-Host "     Set-AutoSensitivityLabelPolicy -Identity '$medicalPolicyName'   -Mode Enable" -ForegroundColor Cyan
Write-Host ""
Write-Host "  5. Monitor Activity Explorer for label application activity:" -ForegroundColor White
Write-Host "     Purview portal → Information Protection → Activity explorer" -ForegroundColor Gray
Write-Host "     Filter: Activity = 'Auto applied label'" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Auto-Labeling Policy Creation Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  View policies  : Get-AutoSensitivityLabelPolicy | FT Name, Mode, ApplySensitivityLabel" -ForegroundColor Gray
Write-Host "  View rules     : Get-AutoSensitivityLabelRule | FT Name, Policy" -ForegroundColor Gray
Write-Host "  Simulation     : Get-AutoSensitivityLabelPolicy -Identity '$financialPolicyName' -IncludeTestModeResults `$true" -ForegroundColor Gray
Write-Host "  Disconnect     : Disconnect-ExchangeOnline -Confirm:`$false" -ForegroundColor Gray
Write-Host ""
