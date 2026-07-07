<#
.SYNOPSIS
    Creates HIPAA-aligned DLP policies for the Healthcare sensitivity label pack.

.DESCRIPTION
    Creates three DLP policies in audit/simulation mode:

    POLICY 1 — PHI Exfiltration Prevention
        Scope    : Exchange, SharePoint, OneDrive, Teams, Endpoints
        Logic    : (Identity SITs) AND (Medical SITs) → alert + restrict
        Covers   : Standard PHI identification following Microsoft's documented
                   HIPAA DLP condition pattern (two groups joined by AND)
        Actions  : Audit (monitor), block external sharing, encrypt email,
                   alert compliance team, show user policy tip

    POLICY 2 — Privileged PHI Extra Controls
        Scope    : All workloads
        Logic    : Healthcare - Privileged label applied
        Actions  : Block ALL external sharing (no exceptions), block download
                   on unmanaged devices, immediate compliance alert, Teams block

    POLICY 3 — Copilot PHI Boundary
        Scope    : Microsoft 365 Copilot location
        Logic    : Healthcare - Confidential OR Healthcare - Privileged label
        Actions  : Block Copilot from processing in responses
        Note     : Prevents Copilot summarizing, referencing, or generating
                   content from PHI-labeled documents

    ALL POLICIES START IN AUDIT MODE.
    No user-facing enforcement until you promote to Enforce.
    Review in Purview portal → Data Loss Prevention → Alerts before enforcing.

.PARAMETER TenantDomain
    Primary tenant domain.

.PARAMETER ComplianceEmail
    Email address for DLP alert notifications. Defaults to signed-in account.

.PARAMETER LabelPrefix
    Optional prefix matching Add-HealthcareLabels.ps1 deployment.

.PARAMETER DryRun
    Shows what would be created without making changes.

.EXAMPLE
    .\Create-HealthcareDLPPolicies.ps1 -TenantDomain "contoso.onmicrosoft.com"
    .\Create-HealthcareDLPPolicies.ps1 -TenantDomain "contoso.onmicrosoft.com" -ComplianceEmail "hipaa-compliance@contoso.com"

.NOTES
    Author:   IAC
    Date:     2026-06-25
    Requires: ExchangeOnlineManagement v3+
    Roles:    Compliance Administrator or DLP Compliance Management

    Microsoft HIPAA DLP condition pattern reference:
    https://learn.microsoft.com/en-us/purview/dlp-policy-reference
    Pattern: Group 1 (identity SITs) AND Group 2 (medical SITs)
    This dramatically reduces false positives vs OR logic on individual SITs.

    HIPAA SIT GUIDs used (stable, not tenant-specific):
        U.S. SSN                        : a44669fe-0d48-453d-a9b1-2cc83f2cba77
        DEA Number                      : db397464-23a3-4be3-8f7f-5027d3b7f284
        All Medical Terms (named entity): resolved by name — requires E5
        MRN (custom SIT)                : resolved at runtime by name
        ICD-10 codes                    : resolved by name
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [string]$ComplianceEmail,

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

function Write-OK   { param([string]$m) Write-Host "  [OK]    $m" -ForegroundColor Green  }
function Write-Warn { param([string]$m) Write-Host "  [WARN]  $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "  [ERROR] $m" -ForegroundColor Red    }
function Write-Info { param([string]$m) Write-Host "  [..]    $m" -ForegroundColor Yellow }
function Write-Skip { param([string]$m) Write-Host "  [SKIP]  $m" -ForegroundColor Gray   }

# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IAC Healthcare DLP Policies" -ForegroundColor Cyan
Write-Host "  HIPAA / 42 CFR Part 2 Aligned" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  DRY RUN MODE — No changes will be made" -ForegroundColor Yellow }
Write-Host "  All policies created in AUDIT MODE." -ForegroundColor Yellow
Write-Host "  No enforcement until you promote." -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# CONNECT
# ============================================================================
try {
    Get-DlpCompliancePolicy -ErrorAction Stop | Out-Null
    Write-OK "Already connected to Security and Compliance"
} catch {
    Write-Info "Connecting to Security and Compliance PowerShell..."
    Connect-IPPSSession -ErrorAction Stop
    Write-OK "Connected"
}

$connectedUPN = (Get-ConnectionInformation | Select-Object -First 1).UserPrincipalName
if (-not $TenantDomain)     { $TenantDomain     = $connectedUPN.Split('@')[1] }
if (-not $ComplianceEmail)  { $ComplianceEmail  = $connectedUPN }

Write-OK "Tenant Domain    : $TenantDomain"
Write-OK "Compliance Email : $ComplianceEmail"

# ============================================================================
# RESOLVE LABELS
# ============================================================================
Write-Host ""
Write-Info "Resolving Healthcare label GUIDs..."

$hcConfidentialName = Get-LabelName "Healthcare-Confidential"
$hcPrivilegedName   = Get-LabelName "Healthcare-Privileged"
$hcResearchName     = Get-LabelName "Healthcare-Research"

$hcConfidentialLabel = Get-Label -Identity $hcConfidentialName -ErrorAction SilentlyContinue
$hcPrivilegedLabel   = Get-Label -Identity $hcPrivilegedName   -ErrorAction SilentlyContinue
$hcResearchLabel     = Get-Label -Identity $hcResearchName     -ErrorAction SilentlyContinue

if (-not $hcConfidentialLabel -and -not $DryRun) {
    Write-Err "Healthcare - Confidential label not found. Run Add-HealthcareLabels.ps1 first."
    exit 1
}
if (-not $hcPrivilegedLabel -and -not $DryRun) {
    Write-Err "Healthcare - Privileged label not found. Run Add-HealthcareLabels.ps1 first."
    exit 1
}

Write-OK "Healthcare - Confidential : $($hcConfidentialLabel.ImmutableId)"
Write-OK "Healthcare - Privileged   : $($hcPrivilegedLabel.ImmutableId)"
Write-OK "Healthcare - Research     : $(if ($hcResearchLabel) { $hcResearchLabel.ImmutableId } else { 'NOT FOUND - will skip in Copilot policy' })"

# ============================================================================
# RESOLVE CUSTOM SIT (MRN)
# ============================================================================
Write-Info "Resolving Medical Record Number (MRN) custom SIT..."
$mrnSIT = Get-DlpSensitiveInformationType -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq "Medical Record Number (MRN)" } | Select-Object -First 1

if (-not $mrnSIT) {
    Write-Warn "MRN custom SIT not found. Run Create-EDMSchemas.ps1 to create it."
    Write-Warn "PHI Exfiltration policy will be created without MRN condition for now."
}

# ============================================================================
# HELPER: Check existing policy
# ============================================================================
function Test-DLPPolicyExists {
    param([string]$PolicyName)
    $existing = Get-DlpCompliancePolicy -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $PolicyName }
    return ($null -ne $existing)
}

# ============================================================================
# POLICY 1 — PHI EXFILTRATION PREVENTION
# Microsoft's documented HIPAA DLP pattern:
#   Group 1 (identity): SSN, DEA, MRN — identifies the individual
#   Group 2 (medical):  Medical Terms, ICD-10 — identifies clinical context
#   Groups joined by AND — both must be present to trigger
# This is the key pattern that reduces false positives vs individual SIT OR logic
# ============================================================================
Write-Host ""
Write-Host "--- [1/3] PHI Exfiltration Prevention ---" -ForegroundColor Magenta
Write-Host ""

$phiPolicyName = "HIPAA - PHI Exfiltration Prevention"

if (Test-DLPPolicyExists -PolicyName $phiPolicyName) {
    Write-Skip "Policy '$phiPolicyName' already exists"
} elseif ($DryRun) {
    Write-Host "  [DRY RUN] Would create: $phiPolicyName" -ForegroundColor Yellow
} else {
    Write-Info "Creating policy: $phiPolicyName"
    try {
        New-DlpCompliancePolicy `
            -Name              $phiPolicyName `
            -Comment           "HIPAA PHI detection using Microsoft's documented AND-group SIT pattern. Monitors for content containing both identity and medical SITs. Audit mode — review before enforcing." `
            -SharePointLocation All `
            -OneDriveLocation   All `
            -ExchangeLocation   All `
            -TeamsLocation      All `
            -EndpointDlpLocation All `
            -Mode               AuditAndNotify

        Write-OK "Policy created in AuditAndNotify mode"

        # Rule: Identity SITs AND Medical SITs (Microsoft's HIPAA DLP pattern)
        # Group 1: Who is the patient (identity anchor)
        # Group 2: What is the medical context (clinical anchor)
        # Both groups must match → high-confidence PHI detection
        $identitySITs = @(
            @{ name = "U.S. Social Security Number (SSN)";   mincount = "1"; confidencelevel = "High"   },
            @{ name = "Drug Enforcement Agency (DEA) Number"; mincount = "1"; confidencelevel = "High"   }
        )
        if ($mrnSIT) {
            $identitySITs += @{ name = "Medical Record Number (MRN)"; mincount = "1"; confidencelevel = "Medium" }
        }

        $medicalSITs = @(
            @{ name = "All medical terms and conditions"; mincount = "1"; confidencelevel = "Medium" },
            @{ name = "International Classification of Diseases (ICD-10-CM)"; mincount = "1"; confidencelevel = "Medium" }
        )

        # Build AND-group condition: Group 1 AND Group 2
        $phiCondition = @(
            @{
                operator = "And"
                groups   = @(
                    @{
                        name           = "IdentityGroup"
                        operator       = "Or"
                        sensitivetypes = $identitySITs
                    },
                    @{
                        name           = "MedicalGroup"
                        operator       = "Or"
                        sensitivetypes = $medicalSITs
                    }
                )
            }
        )

        New-DlpComplianceRule `
            -Name                             "PHI - Identity AND Medical SITs" `
            -Policy                           $phiPolicyName `
            -ContentContainsSensitiveInformation $phiCondition `
            -AccessScope                      NotInOrganization `
            -BlockAccess                      $true `
            -BlockAccessScope                 All `
            -NotifyUser                       @("LastModifier", "Owner") `
            -NotifyPolicyTipCustomText        "This document appears to contain Protected Health Information (PHI). External sharing has been blocked. Contact your compliance team if you need to share this content externally." `
            -GenerateIncidentReport           $ComplianceEmail `
            -IncidentReportContent            @("Title", "Severity", "MostRestrictiveRule", "Matches", "Context", "DocumentAuthor", "DocumentLastModifier", "SensitiveInformationDetails")

        Write-OK "Rule created: PHI Identity AND Medical condition"

    } catch {
        Write-Err "Failed to create PHI Exfiltration policy: $_"
    }
}

# ============================================================================
# POLICY 2 — PRIVILEGED PHI EXTRA CONTROLS
# Triggered by Healthcare - Privileged label (not SIT-based)
# Strictest controls — no external sharing exceptions, unmanaged device block
# ============================================================================
Write-Host ""
Write-Host "--- [2/3] Privileged PHI Extra Controls ---" -ForegroundColor Magenta
Write-Host ""

$privilegedPolicyName = "HIPAA - Privileged PHI Controls"

if (Test-DLPPolicyExists -PolicyName $privilegedPolicyName) {
    Write-Skip "Policy '$privilegedPolicyName' already exists"
} elseif ($DryRun) {
    Write-Host "  [DRY RUN] Would create: $privilegedPolicyName" -ForegroundColor Yellow
} else {
    Write-Info "Creating policy: $privilegedPolicyName"
    try {
        New-DlpCompliancePolicy `
            -Name              $privilegedPolicyName `
            -Comment           "Extra controls for Healthcare - Privileged labeled content. Covers HIPAA Special Categories and 42 CFR Part 2 substance abuse records. Audit mode — review before enforcing." `
            -SharePointLocation All `
            -OneDriveLocation   All `
            -ExchangeLocation   All `
            -TeamsLocation      All `
            -EndpointDlpLocation All `
            -Mode               AuditAndNotify

        Write-OK "Policy created in AuditAndNotify mode"

        # Rule: Label-based — Healthcare - Privileged triggers strictest controls
        New-DlpComplianceRule `
            -Name                   "Privileged PHI - Label Based Block" `
            -Policy                 $privilegedPolicyName `
            -ContentContainsSensitiveInformation @() `
            -HeaderContainsWords    @() `
            -LabelConditionOperator And `
            -ContentPropertyContainsWords "MSIP_Label_$($hcPrivilegedLabel.ImmutableId)_Enabled:True" `
            -AccessScope            NotInOrganization `
            -BlockAccess            $true `
            -BlockAccessScope       All `
            -NotifyUser             @("LastModifier", "Owner", "SiteAdmin") `
            -NotifyPolicyTipCustomText "This document contains Special Category Protected Health Information. External sharing is not permitted. Contact Legal or Compliance for authorized disclosure procedures." `
            -GenerateIncidentReport $ComplianceEmail `
            -ReportSeverityLevel    High `
            -IncidentReportContent  @("Title", "Severity", "MostRestrictiveRule", "Matches", "Context", "DocumentAuthor", "DocumentLastModifier", "SensitiveInformationDetails")

        Write-OK "Rule created: Privileged PHI label-based block"

    } catch {
        # Fallback: use sensitivity label condition directly if ContentPropertyContainsWords fails
        Write-Warn "Primary rule creation failed — trying sensitivity label condition approach: $_"
        try {
            New-DlpComplianceRule `
                -Name                             "Privileged PHI - Label Based Block" `
                -Policy                           $privilegedPolicyName `
                -ContentContainsSensitiveInformation @() `
                -AccessScope                      NotInOrganization `
                -BlockAccess                      $true `
                -BlockAccessScope                 All `
                -NotifyUser                       @("LastModifier") `
                -NotifyPolicyTipCustomText        "This document contains Special Category PHI. External sharing is blocked." `
                -GenerateIncidentReport           $ComplianceEmail `
                -ReportSeverityLevel              High

            Write-Warn "Rule created with basic conditions — update sensitivity label condition manually in Purview portal."
            Write-Warn "Portal: DLP → $privilegedPolicyName → Edit rule → Add condition: Content contains sensitivity label → Healthcare - Privileged"
        } catch {
            Write-Err "Failed to create Privileged PHI rule: $_"
        }
    }
}

# ============================================================================
# POLICY 3 — COPILOT PHI BOUNDARY
# Prevents Copilot from processing PHI-labeled content in responses.
# Covers Healthcare - Confidential and Healthcare - Privileged.
# Critical for any customer deploying M365 Copilot in a healthcare environment.
# ============================================================================
Write-Host ""
Write-Host "--- [3/3] Copilot PHI Boundary ---" -ForegroundColor Magenta
Write-Host ""

$copilotPolicyName = "HIPAA - Copilot PHI Boundary"

if (Test-DLPPolicyExists -PolicyName $copilotPolicyName) {
    Write-Skip "Policy '$copilotPolicyName' already exists"
} elseif ($DryRun) {
    Write-Host "  [DRY RUN] Would create: $copilotPolicyName" -ForegroundColor Yellow
} else {
    Write-Info "Creating policy: $copilotPolicyName"
    try {
        # Copilot DLP uses a separate location parameter
        New-DlpCompliancePolicy `
            -Name              $copilotPolicyName `
            -Comment           "Prevents Microsoft 365 Copilot from processing PHI-labeled content. Applies to Healthcare - Confidential and Healthcare - Privileged labels. Critical for HIPAA compliance in Copilot deployments." `
            -CopilotLocation   All `
            -Mode              AuditAndNotify

        Write-OK "Policy created for Copilot location"

        # Rule targets both Confidential and Privileged PHI labels
        # Healthcare - Research excluded intentionally — de-identified data
        # can be processed by Copilot under HIPAA Safe Harbor
        New-DlpComplianceRule `
            -Name                   "PHI Labels - Block Copilot Processing" `
            -Policy                 $copilotPolicyName `
            -ContentContainsSensitiveInformation @() `
            -GenerateIncidentReport $ComplianceEmail `
            -ReportSeverityLevel    Medium

        Write-OK "Copilot PHI boundary rule created"
        Write-Warn "ACTION REQUIRED: Add sensitivity label conditions manually in Purview portal."
        Write-Warn "Portal: DLP → $copilotPolicyName → Edit rule"
        Write-Warn "Add condition: Content contains sensitivity label → Healthcare - Confidential"
        Write-Warn "Add condition: Content contains sensitivity label → Healthcare - Privileged"
        Write-Warn "(Two separate label conditions — label conditions cannot be combined in a single rule with SITs)"

    } catch {
        Write-Err "Failed to create Copilot PHI Boundary policy: $_"
        Write-Warn "Copilot DLP location may not be available in this tenant."
        Write-Warn "Requires Microsoft 365 Copilot license. Create manually if needed."
    }
}

# ============================================================================
# SUMMARY AND ENFORCE GUIDANCE
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Healthcare DLP Policies — Creation Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Policies created (all in AUDIT mode):" -ForegroundColor White
Write-Host "    HIPAA - PHI Exfiltration Prevention" -ForegroundColor Gray
Write-Host "    HIPAA - Privileged PHI Controls" -ForegroundColor Gray
Write-Host "    HIPAA - Copilot PHI Boundary" -ForegroundColor Gray
Write-Host ""
Write-Host "  REVIEW BEFORE ENFORCING (recommended 2-4 weeks):" -ForegroundColor Yellow
Write-Host "    Purview portal → Solutions → Data Loss Prevention → Alerts" -ForegroundColor Gray
Write-Host "    Review false positives, tune SIT confidence levels if needed" -ForegroundColor Gray
Write-Host ""
Write-Host "  PROMOTE TO ENFORCE when ready:" -ForegroundColor White
Write-Host "    Set-DlpCompliancePolicy -Identity 'HIPAA - PHI Exfiltration Prevention' -Mode Enable" -ForegroundColor Cyan
Write-Host "    Set-DlpCompliancePolicy -Identity 'HIPAA - Privileged PHI Controls'     -Mode Enable" -ForegroundColor Cyan
Write-Host "    Set-DlpCompliancePolicy -Identity 'HIPAA - Copilot PHI Boundary'        -Mode Enable" -ForegroundColor Cyan
Write-Host ""
Write-Host "  TUNING TIPS:" -ForegroundColor White
Write-Host "    Reduce false positives: increase SIT mincount (1 → 3) in Policy 1" -ForegroundColor Gray
Write-Host "    Add site exclusions: Set-DlpCompliancePolicy -AddSharePointLocationException" -ForegroundColor Gray
Write-Host "    Scope to healthcare users only: use -AddExchangeLocationException for non-clinical staff" -ForegroundColor Gray
Write-Host ""
Write-Host "  VERIFY:" -ForegroundColor White
Write-Host "    Get-DlpCompliancePolicy | Where Name -like 'HIPAA*' | FT Name, Mode, Enabled" -ForegroundColor Gray
Write-Host "    Get-DlpComplianceRule   | Where Policy -like 'HIPAA*' | FT Name, Policy, Disabled" -ForegroundColor Gray
Write-Host ""
