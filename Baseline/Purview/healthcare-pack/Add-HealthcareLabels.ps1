<#
.SYNOPSIS
    Creates Healthcare sensitivity label group and sub-labels for HIPAA-aligned deployments.

.DESCRIPTION
    Phase 1 — Group creation (Exchange Online):
        Creates two mail-enabled security groups required for label encryption:
            Purview-Medical-Privileged  → encryption rights for Healthcare - Privileged
            Purview-Medical-Research    → encryption rights for Healthcare - Research
        Validates group propagation before proceeding to label creation.

    Phase 2 — Label creation (Security & Compliance):
        Creates Healthcare parent label group + 4 sub-labels:
            Healthcare - General       No encryption. Internal operational content. Not PHI.
                                       Offline access: Always (not encrypted — N/A)
            Healthcare - Confidential  Org-wide encryption. Standard PHI.
                                       Offline access: 7 days — weekly reauthentication for PHI
            Healthcare - Privileged    Named group encryption (Purview-Medical-Privileged).
                                       HIPAA Special Categories: psychotherapy notes, HIV/AIDS,
                                       substance abuse (42 CFR Part 2), genetic info (GINA),
                                       mental health records.
                                       Offline access: Never — must be online to open at all times
            Healthcare - Research      Named group encryption (Purview-Medical-Research).
                                       IRB-governed research. De-identified / limited datasets.
                                       Offline access: 7 days — aligned to IRB protocol review cadence

    OFFLINE ACCESS (Azure RMS Use License Validity):
        This is NOT a HIPAA requirement — it is an Azure RMS feature.
        HIPAA is technology-neutral and does not prescribe reauthentication intervals.
        The values below reflect a defensible HIPAA posture based on PHI sensitivity tier:
            Never  (-1) : User must have internet connection every time they open the document.
                          RMS calls aadrm.com on every open. If account is disabled or removed
                          from the encryption group, access is revoked immediately.
            7 days (7)  : User can open offline for up to 7 days before reauthentication.
                          When license expires, encryption group membership is re-evaluated.
                          If user was removed from group during that window, access is denied.
        Changing these values on existing labels takes effect after the current use license
        expires — not immediately. For immediate revocation, use the Super User group to
        re-encrypt the document, or revoke via AipService PowerShell.

    LABEL POLICY:
        Labels are NOT published by this script.
        Run Publish-SensitivityLabelPolicies.ps1 with -Pack Healthcare, or publish manually
        scoped to your clinical staff security group — not org-wide.

    PREREQUISITES:
        1. SensitivityLabel.ps1 must have been run first (base taxonomy deployed)
        2. Azure Rights Management service must be active in your tenant
        3. ExchangeOnlineManagement v3+ installed
        4. Signed-in account must have:
             - Exchange Online: Distribution Group management role
             - Purview: Information Protection Admin or Compliance Admin

    NAMING CONVENTION:
        Groups follow the Purview-[Workload]-[Purpose] pattern:
            Purview-Medical-Privileged@<domain>
            Purview-Medical-Research@<domain>
        This aligns with MSP group naming standards and makes Entra access reviews clear.

.PARAMETER TenantDomain
    Primary tenant domain (e.g. contoso.onmicrosoft.com or contoso.com).
    Used to construct group email addresses and encryption rights.

.PARAMETER LabelPrefix
    Optional prefix matching SensitivityLabel.ps1 deployment (e.g. "Contoso").
    Produces "Contoso-Healthcare-Confidential" etc.

.PARAMETER PrivilegedGroupOwner
    UPN of the user to set as owner of Purview-Medical-Privileged group.
    Defaults to signed-in account. Should be a compliance or clinical lead.

.PARAMETER ResearchGroupOwner
    UPN of the user to set as owner of Purview-Medical-Research group.
    Defaults to signed-in account. Should be a research compliance lead.

.PARAMETER SkipGroupCreation
    Skip Phase 1 if groups already exist. Script will validate they exist before proceeding.

.PARAMETER DryRun
    Shows what would be created without making changes.

.EXAMPLE
    # Standard deployment
    .\Add-HealthcareLabels.ps1 -TenantDomain "contoso.onmicrosoft.com"

    # With label prefix
    .\Add-HealthcareLabels.ps1 -TenantDomain "contoso.onmicrosoft.com" -LabelPrefix "Contoso"

    # Groups already exist
    .\Add-HealthcareLabels.ps1 -TenantDomain "contoso.onmicrosoft.com" -SkipGroupCreation

    # Dry run
    .\Add-HealthcareLabels.ps1 -TenantDomain "contoso.onmicrosoft.com" -DryRun

.NOTES
    Author:   IAC
    Date:     2026-06-25
    Updated:  2026-06-26 — Added EncryptionOfflineAccessDays per label + Phase 2B update logic
    Requires: ExchangeOnlineManagement v3+
    Roles:    Exchange: Distribution Groups | Purview: Information Protection Admin

    HIPAA references:
        §164.312(a)(1) — Access control
        §164.312(b)    — Audit controls
        §164.312(c)(1) — Integrity
        §164.312(e)(2) — Encryption
        42 CFR Part 2  — Substance abuse records (stricter than HIPAA)
        GINA           — Genetic information non-discrimination
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [string]$LabelPrefix = "",

    [Parameter(Mandatory = $false)]
    [string]$PrivilegedGroupOwner,

    [Parameter(Mandatory = $false)]
    [string]$ResearchGroupOwner,

    [Parameter(Mandatory = $false)]
    [switch]$SkipGroupCreation,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

# ============================================================================
# HELPERS
# ============================================================================
function Get-LabelName {
    param([Parameter(Mandatory)][string]$BaseName)
    if ([string]::IsNullOrWhiteSpace($LabelPrefix)) { return $BaseName }
    return "$LabelPrefix-$BaseName"
}

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "  $Message" -ForegroundColor $Color
}

function Write-OK   { param([string]$m) Write-Host "  [OK]    $m" -ForegroundColor Green  }
function Write-Warn { param([string]$m) Write-Host "  [WARN]  $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "  [ERROR] $m" -ForegroundColor Red    }
function Write-Info { param([string]$m) Write-Host "  [..]    $m" -ForegroundColor Yellow }
function Write-Skip { param([string]$m) Write-Host "  [SKIP]  $m" -ForegroundColor Gray   }

# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IAC Healthcare Compliance Pack" -ForegroundColor Cyan
Write-Host "  Sensitivity Labels + Security Groups" -ForegroundColor Cyan
Write-Host "  HIPAA / HITECH / 42 CFR Part 2 Aligned" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  DRY RUN MODE — No changes will be made" -ForegroundColor Yellow }
Write-Host "  Label Prefix : $(if ($LabelPrefix) { $LabelPrefix } else { '(none)' })" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# PHASE 0 — CONNECT
# ============================================================================
Write-Host "--- Phase 0: Connect ---" -ForegroundColor Magenta
Write-Host ""

# Exchange Online (needed for group creation)
try {
    Get-DistributionGroup -ResultSize 1 -ErrorAction Stop | Out-Null
    Write-OK "Already connected to Exchange Online"
} catch {
    Write-Info "Connecting to Exchange Online..."
    Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    Write-OK "Connected to Exchange Online"
}

# Derive domain and owner from signed-in account
$connectedUPN = (Get-ConnectionInformation | Select-Object -First 1).UserPrincipalName
if (-not $TenantDomain)         { $TenantDomain         = $connectedUPN.Split('@')[1] }
if (-not $PrivilegedGroupOwner) { $PrivilegedGroupOwner = $connectedUPN }
if (-not $ResearchGroupOwner)   { $ResearchGroupOwner   = $connectedUPN }

Write-OK "Tenant Domain    : $TenantDomain"
Write-OK "Privileged Owner : $PrivilegedGroupOwner"
Write-OK "Research Owner   : $ResearchGroupOwner"

# Security & Compliance (needed for label creation)
try {
    Get-Label -ErrorAction Stop | Out-Null
    Write-OK "Already connected to Security and Compliance"
} catch {
    Write-Info "Connecting to Security and Compliance PowerShell..."
    Connect-IPPSSession -ErrorAction Stop
    Write-OK "Connected to Security and Compliance"
}

# ============================================================================
# PHASE 1 — GROUP CREATION
# ============================================================================
Write-Host ""
Write-Host "--- Phase 1: Security Group Creation ---" -ForegroundColor Magenta
Write-Host ""

# Group definitions
$groups = @(
    @{
        Name        = "Purview-Medical-Privileged"
        Alias       = "Purview-Medical-Privileged"
        Email       = "Purview-Medical-Privileged@$TenantDomain"
        Owner       = $PrivilegedGroupOwner
        Description = "Encryption group for Healthcare - Privileged sensitivity label. Members can decrypt HIPAA Special Category PHI including psychotherapy notes, HIV/AIDS status, substance abuse records (42 CFR Part 2), and genetic information. Membership requires approval. Review quarterly."
        Purpose     = "Healthcare - Privileged label encryption"
    },
    @{
        Name        = "Purview-Medical-Research"
        Alias       = "Purview-Medical-Research"
        Email       = "Purview-Medical-Research@$TenantDomain"
        Owner       = $ResearchGroupOwner
        Description = "Encryption group for Healthcare - Research sensitivity label. Members can decrypt IRB-governed research data and HIPAA de-identified / limited datasets. Membership tied to active IRB protocol. Review on protocol renewal."
        Purpose     = "Healthcare - Research label encryption"
    }
)

$groupResults = @{}

foreach ($g in $groups) {
    Write-Step "Processing group: $($g.Name)" "White"

    # Check if already exists
    $existing = Get-DistributionGroup -Identity $g.Email -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Skip "$($g.Name) already exists ($($existing.PrimarySmtpAddress))"
        $groupResults[$g.Name] = $existing.PrimarySmtpAddress
        continue
    }

    if ($SkipGroupCreation) {
        Write-Err "$($g.Name) not found and -SkipGroupCreation was specified. Cannot proceed."
        Write-Err "Create the group manually or remove -SkipGroupCreation."
        exit 1
    }

    if ($DryRun) {
        Write-Step "[DRY RUN] Would create: $($g.Email)" "Yellow"
        $groupResults[$g.Name] = $g.Email
        continue
    }

    Write-Info "Creating mail-enabled security group: $($g.Name)..."
    try {
        $newGroup = New-DistributionGroup `
            -Name              $g.Name `
            -Alias             $g.Alias `
            -PrimarySmtpAddress $g.Email `
            -Type              Security `
            -ManagedBy         $g.Owner `
            -Notes             $g.Description `
            -ErrorAction       Stop

        Write-OK "Group created: $($newGroup.PrimarySmtpAddress)"
        $groupResults[$g.Name] = $newGroup.PrimarySmtpAddress

        # Hide from GAL — these are system groups, not for general address book visibility
        Set-DistributionGroup -Identity $g.Email -HiddenFromAddressListsEnabled $true
        Write-OK "Hidden from address lists (system group)"

    } catch {
        Write-Err "Failed to create $($g.Name): $_"
        Write-Err "Resolve this error before proceeding — labels cannot be created without valid group email addresses."
        exit 1
    }
}

# ============================================================================
# PHASE 1B — GROUP PROPAGATION VALIDATION
# ============================================================================
# RMS encryption rights require the group to resolve in Exchange Online before
# Purview can reference the email address in label encryption definitions.
# We validate resolution before attempting label creation to avoid silent failures.
# ============================================================================
if (-not $DryRun) {
    Write-Host ""
    Write-Info "Validating group propagation (required before label encryption can reference groups)..."
    Write-Warn "This may take 1-3 minutes. Do not interrupt."
    Write-Host ""

    $maxWaitSeconds = 180
    $intervalSeconds = 15
    $elapsed = 0
    $allResolved = $false

    while ($elapsed -lt $maxWaitSeconds) {
        $resolved = $true
        foreach ($g in $groups) {
            $check = Get-DistributionGroup -Identity $g.Email -ErrorAction SilentlyContinue
            if (-not $check) {
                $resolved = $false
                break
            }
        }

        if ($resolved) {
            $allResolved = $true
            Write-OK "All groups resolved in Exchange Online"
            break
        }

        Write-Info "Waiting for propagation... ($elapsed/$maxWaitSeconds seconds)"
        Start-Sleep -Seconds $intervalSeconds
        $elapsed += $intervalSeconds
    }

    if (-not $allResolved) {
        Write-Warn "Groups did not resolve within $maxWaitSeconds seconds."
        Write-Warn "This is normal in large tenants. Options:"
        Write-Warn "  1. Wait 15-30 minutes and re-run with -SkipGroupCreation"
        Write-Warn "  2. Continue anyway — label creation may fail if RMS cannot resolve group"
        Write-Host ""
        $continue = Read-Host "  Continue with label creation anyway? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            Write-Host "  Exiting. Re-run with -SkipGroupCreation once groups are fully propagated." -ForegroundColor Yellow
            exit 0
        }
    }

    # Additional buffer for RMS propagation — group must exist in both Exchange AND RMS
    Write-Info "Waiting additional 30 seconds for RMS propagation..."
    Start-Sleep -Seconds 30
    Write-OK "Propagation wait complete"
}

# ============================================================================
# BUILD ENCRYPTION RIGHTS STRINGS
# ============================================================================
# CO-AUTHOR rights: View, Edit, Print, Copy, Reply, Forward, Save — no re-encrypt
# Appropriate for clinical staff who need to work with PHI documents actively
$privilegedGroupEmail = $groupResults["Purview-Medical-Privileged"]
$researchGroupEmail   = $groupResults["Purview-Medical-Research"]
$orgWideRights        = "$($TenantDomain):VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL"
$privilegedRights     = "$($privilegedGroupEmail):VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL"
$researchRights       = "$($researchGroupEmail):VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL"

# ============================================================================
# PHASE 2 — LABEL CREATION
# ============================================================================
Write-Host ""
Write-Host "--- Phase 2: Sensitivity Label Creation ---" -ForegroundColor Magenta
Write-Host ""

# Cache existing labels
$script:LabelCache = @(Get-Label -ErrorAction SilentlyContinue | Where-Object { $_.Mode -ne 'PendingDeletion' })
Write-OK "Found $($script:LabelCache.Count) existing labels (PendingDeletion excluded)"

function Ensure-Label {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$Tooltip,
        [string]$Comment,
        [string]$ParentImmutableId,
        [switch]$IsParentLabel,
        [string[]]$ContentType,
        [string]$HeaderText,
        [string]$FooterText,
        [string]$WatermarkText,
        [bool]$EncryptionEnabled = $false,
        [string]$EncryptionProtectionType,
        [string]$EncryptionRightsDefinitions,
        # Offline access (RMS use license validity):
        #   -1 = Never  (must be online every open — use for Privileged)
        #    7 = 7 days  (weekly reauth — use for Confidential and Research)
        #   $null = omit parameter (label uses tenant default of 30 days)
        [nullable[int]]$OfflineAccessDays = $null
    )

    $existing = $script:LabelCache | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
    if ($existing) {
        Write-Skip "$DisplayName"
        return $existing
    }

    if ($DryRun) {
        Write-Step "[DRY RUN] Would create: $DisplayName" "Yellow"
        return @{ ImmutableId = "DRYRUN-$Name"; DisplayName = $DisplayName }
    }

    $params = @{
        Name        = $Name
        DisplayName = $DisplayName
        Tooltip     = $Tooltip
        Comment     = $Comment
    }

    if ($ContentType -and -not $IsParentLabel) { $params["ContentType"] = $ContentType }
    if ($ParentImmutableId) { $params["ParentId"] = $ParentImmutableId }

    if ($HeaderText) {
        $params["ApplyContentMarkingHeaderEnabled"]   = $true
        $params["ApplyContentMarkingHeaderText"]      = $HeaderText
        $params["ApplyContentMarkingHeaderFontSize"]  = 10
        $params["ApplyContentMarkingHeaderFontColor"] = "#800000"
        $params["ApplyContentMarkingHeaderAlignment"] = "Center"
    }
    if ($FooterText) {
        $params["ApplyContentMarkingFooterEnabled"]   = $true
        $params["ApplyContentMarkingFooterText"]      = $FooterText
        $params["ApplyContentMarkingFooterFontSize"]  = 8
        $params["ApplyContentMarkingFooterFontColor"] = "#800000"
        $params["ApplyContentMarkingFooterAlignment"] = "Center"
    }
    if ($WatermarkText) {
        $params["ApplyWaterMarkingEnabled"]  = $true
        $params["ApplyWaterMarkingText"]     = $WatermarkText
        $params["ApplyWaterMarkingFontSize"] = 48
        $params["ApplyWaterMarkingLayout"]   = "Diagonal"
    }

    if ($EncryptionEnabled) {
        $params["EncryptionEnabled"]            = $true
        $params["EncryptionProtectionType"]     = $EncryptionProtectionType
        $params["EncryptionRightsDefinitions"]  = $EncryptionRightsDefinitions

        # Offline access — only valid on Template-encrypted labels (not user-defined)
        # -1 maps to "Never" in the Purview portal
        # Positive integer maps to "Only for this many days"
        # Omitting this parameter leaves the tenant default (30 days) in place
        if ($null -ne $OfflineAccessDays) {
            $params["EncryptionOfflineAccessDays"] = $OfflineAccessDays
        }
    }

    if ($IsParentLabel) { $params["IsLabelGroup"] = $true }

    Write-Info "Creating: $DisplayName"
    try {
        $result = New-Label @params
        $script:LabelCache += $result
        Start-Sleep -Seconds 2
        Write-OK "Created: $DisplayName"
        return $result
    } catch {
        if ($_.Exception.Message -like '*already exists*') {
            Write-Warn "$DisplayName already exists — recovering..."
            $result = Get-Label | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
            $script:LabelCache += $result
            return $result
        }
        Write-Err "Failed to create '$DisplayName': $_"
        return $null
    }
}

# ----------------------------------------------------------------------------
# HEALTHCARE PARENT
# Scope: Groups & Sites only — sub-labels handle File/Email/Meetings
# ----------------------------------------------------------------------------
Write-Host ""
Write-Step "[1/5] Healthcare (parent container)" "White"

$healthcare = Ensure-Label `
    -Name          (Get-LabelName "Healthcare") `
    -DisplayName   "Healthcare" `
    -Tooltip       "Select a Healthcare sub-label. All sub-labels apply HIPAA-aligned protections." `
    -Comment       "HIPAA-aligned label group for healthcare organizations. Sub-labels cover operational content, standard PHI, special category PHI, and research data." `
    -ContentType   @("Site", "UnifiedGroup") `
    -IsParentLabel

if (-not $healthcare) {
    Write-Err "Healthcare parent label creation failed. Cannot create sub-labels."
    exit 1
}

# ----------------------------------------------------------------------------
# HEALTHCARE - GENERAL
# Operational content that is NOT PHI.
# Staff schedules, HR policies, training materials, admin documents.
# No encryption — friction-free for clinical staff on non-sensitive content.
# Meetings scope ON — clinical huddles, staff meetings, training sessions.
# ----------------------------------------------------------------------------
Write-Host ""
Write-Step "[2/5] Healthcare - General" "White"
Write-Step "      No encryption. Operational content only. NOT for PHI." "Gray"

$hcGeneral = Ensure-Label `
    -Name          (Get-LabelName "Healthcare-General") `
    -DisplayName   "Healthcare - General" `
    -Tooltip       "Internal operational content. Not PHI. Staff schedules, policies, training materials." `
    -Comment       "Apply to internal healthcare operational content that does not contain patient information. Do NOT apply to any content containing patient names, identifiers, or clinical data." `
    -ParentImmutableId $healthcare.ImmutableId `
    -ContentType   @("File", "Email", "Site", "UnifiedGroup", "Teamwork") `
    -HeaderText    "Healthcare - Internal Use Only" `
    -FooterText    "Healthcare - Internal Use Only"

# ----------------------------------------------------------------------------
# HEALTHCARE - CONFIDENTIAL
# Standard PHI. HIPAA §164.312 governs.
# Patient demographics, appointments, test results, billing, clinical notes.
# Org-wide encryption — any authenticated user can read (appropriate for care teams).
# Meetings scope OFF — PHI in meeting recordings/transcripts requires
# additional retention and access review complexity. Deliberate exclusion.
# ----------------------------------------------------------------------------
Write-Host ""
Write-Step "[3/5] Healthcare - Confidential" "White"
Write-Step "      Org-wide encryption. Standard PHI. HIPAA §164.312." "Gray"

$hcConfidential = Ensure-Label `
    -Name                       (Get-LabelName "Healthcare-Confidential") `
    -DisplayName                "Healthcare - Confidential" `
    -Tooltip                    "Standard Protected Health Information (PHI). Encrypted for all authenticated users. Handle per HIPAA Privacy and Security Rules." `
    -Comment                    "Apply to content containing standard PHI: patient demographics, appointments, test results, diagnoses, billing records, and general clinical notes." `
    -ParentImmutableId          $healthcare.ImmutableId `
    -ContentType                @("File", "Email", "Site", "UnifiedGroup") `
    -HeaderText                 "Healthcare - Confidential | PHI" `
    -FooterText                 "Protected Health Information — Handle Per HIPAA" `
    -WatermarkText              "PHI - CONFIDENTIAL" `
    -EncryptionEnabled          $true `
    -EncryptionProtectionType   "Template" `
    -EncryptionRightsDefinitions $orgWideRights `
    -OfflineAccessDays          7

# ----------------------------------------------------------------------------
# HEALTHCARE - PRIVILEGED
# HIPAA Special Categories. 42 CFR Part 2. GINA.
# Psychotherapy notes, HIV/AIDS, substance abuse, genetic info, mental health.
# Named group encryption — Purview-Medical-Privileged only.
# Stricter than standard PHI — separate authorization required even from
# treating providers in many state laws.
# Meetings scope OFF — deliberate. Recording privileged PHI discussions
# creates significant compliance and legal risk.
# ----------------------------------------------------------------------------
Write-Host ""
Write-Step "[4/5] Healthcare - Privileged" "White"
Write-Step "      Named group encryption (Purview-Medical-Privileged)." "Gray"
Write-Step "      HIPAA Special Categories + 42 CFR Part 2 + GINA." "Gray"

$hcPrivileged = Ensure-Label `
    -Name                       (Get-LabelName "Healthcare-Privileged") `
    -DisplayName                "Healthcare - Privileged" `
    -Tooltip                    "HIPAA Special Category PHI. Restricted to Purview-Medical-Privileged group. Covers psychotherapy notes, HIV/AIDS status, substance abuse (42 CFR Part 2), genetic information (GINA), and mental health records." `
    -Comment                    "Apply ONLY to content containing HIPAA Special Category information. Access is restricted to members of Purview-Medical-Privileged. Requires separate patient authorization beyond standard HIPAA consent. Do not apply to general clinical notes — use Healthcare - Confidential instead." `
    -ParentImmutableId          $healthcare.ImmutableId `
    -ContentType                @("File", "Email") `
    -HeaderText                 "Healthcare - Privileged | Special Category PHI" `
    -FooterText                 "Special Category PHI — Restricted Access | 42 CFR Part 2 / GINA / HIPAA" `
    -WatermarkText              "PRIVILEGED - RESTRICTED PHI" `
    -EncryptionEnabled          $true `
    -EncryptionProtectionType   "Template" `
    -EncryptionRightsDefinitions $privilegedRights `
    -OfflineAccessDays          -1

# Note: No Site/UnifiedGroup scope — privileged PHI should not label entire
# SharePoint sites or Teams channels. File and Email only.

# ----------------------------------------------------------------------------
# HEALTHCARE - RESEARCH
# IRB-governed research. De-identified or limited datasets.
# HIPAA Safe Harbor or Expert Determination methods apply.
# Named group encryption — Purview-Medical-Research only.
# Meetings scope OFF — research data in meeting context creates IRB
# protocol compliance complexity.
# ----------------------------------------------------------------------------
Write-Host ""
Write-Step "[5/5] Healthcare - Research" "White"
Write-Step "      Named group encryption (Purview-Medical-Research)." "Gray"
Write-Step "      IRB-governed. De-identified / limited datasets." "Gray"

$hcResearch = Ensure-Label `
    -Name                       (Get-LabelName "Healthcare-Research") `
    -DisplayName                "Healthcare - Research" `
    -Tooltip                    "IRB-governed research data. De-identified or limited datasets under HIPAA Safe Harbor or Expert Determination. Restricted to Purview-Medical-Research group." `
    -Comment                    "Apply to research datasets, study documents, and IRB submissions containing de-identified patient data or limited datasets. Access tied to active IRB protocol membership. Review membership on protocol renewal." `
    -ParentImmutableId          $healthcare.ImmutableId `
    -ContentType                @("File", "Email") `
    -HeaderText                 "Healthcare - Research | IRB Governed" `
    -FooterText                 "Research Data — IRB Protocol Required | HIPAA Safe Harbor / Expert Determination" `
    -WatermarkText              "RESEARCH - RESTRICTED" `
    -EncryptionEnabled          $true `
    -EncryptionProtectionType   "Template" `
    -EncryptionRightsDefinitions $researchRights `
    -OfflineAccessDays          7

# ============================================================================
# PHASE 2B — UPDATE OFFLINE ACCESS ON EXISTING LABELS
# ============================================================================
# Ensure-Label skips labels that already exist (idempotent creation).
# This phase explicitly applies EncryptionOfflineAccessDays via Set-Label
# on all healthcare labels regardless of whether they were just created or
# already existed — so re-running this script always enforces correct values.
#
# IMPORTANT: Changes to offline access take effect after the user's current
# use license expires (up to 30 days for previously cached licenses).
# For immediate enforcement on Privileged content, re-encrypt via Super User.
# ============================================================================
Write-Host ""
Write-Host "--- Phase 2B: Enforce Offline Access Settings ---" -ForegroundColor Magenta
Write-Host ""
Write-Step "Applying EncryptionOfflineAccessDays to all Healthcare labels..." "White"
Write-Step "Note: Changes apply to new use licenses only — existing cached licenses" "Gray"
Write-Step "      are honoured until they expire (up to current tenant default)." "Gray"
Write-Host ""

$offlineUpdates = @(
    @{
        LabelName    = Get-LabelName "Healthcare-Confidential"
        DisplayName  = "Healthcare - Confidential"
        OfflineDays  = 7
        Rationale    = "Standard PHI — 7-day offline window, weekly reauthentication"
    },
    @{
        LabelName    = Get-LabelName "Healthcare-Privileged"
        DisplayName  = "Healthcare - Privileged"
        OfflineDays  = -1
        Rationale    = "Special Category PHI — Never offline, must reauthenticate every open"
    },
    @{
        LabelName    = Get-LabelName "Healthcare-Research"
        DisplayName  = "Healthcare - Research"
        OfflineDays  = 7
        Rationale    = "IRB-governed data — 7-day offline window, aligned to protocol review"
    }
)

foreach ($update in $offlineUpdates) {
    $portalValue = if ($update.OfflineDays -eq -1) { "Never" } else { "$($update.OfflineDays) days" }
    Write-Step "$($update.DisplayName) → Offline access: $portalValue" "White"
    Write-Step "  $($update.Rationale)" "Gray"

    if ($DryRun) {
        Write-Step "  [DRY RUN] Would set EncryptionOfflineAccessDays = $($update.OfflineDays)" "Yellow"
        continue
    }

    try {
        Set-Label -Identity $update.LabelName `
                  -EncryptionOfflineAccessDays $update.OfflineDays `
                  -ErrorAction Stop
        Write-OK "Set offline access: $portalValue on $($update.DisplayName)"
    } catch {
        Write-Warn "Failed to update offline access on $($update.DisplayName): $_"
        Write-Warn "You can set this manually in Purview portal:"
        Write-Warn "  Information Protection → $($update.DisplayName) → Edit → Encryption → Allow offline access → $portalValue"
    }
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Step "Verifying offline access settings..." "White"
Get-Label -IncludeDetailedLabelActions |
    Where-Object { $_.DisplayName -like "Healthcare*" -and $_.DisplayName -ne "Healthcare" } |
    ForEach-Object {
        $actions  = $_.LabelActions | ConvertFrom-Json -ErrorAction SilentlyContinue
        $offline  = ($actions.settings | Where-Object key -eq "EncryptionOfflineAccessDays").value
        $display  = if ($null -eq $offline)     { "(tenant default 30d)" }
                    elseif ($offline -eq "-1")   { "Never" }
                    else                         { "$offline days" }
        Write-Host ("  {0,-40} OfflineAccess: {1}" -f $_.DisplayName, $display) -ForegroundColor Gray
    }

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Healthcare Label Pack — Creation Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Security Groups Created:" -ForegroundColor White
Write-Host "    Purview-Medical-Privileged@$TenantDomain" -ForegroundColor Gray
Write-Host "    Purview-Medical-Research@$TenantDomain" -ForegroundColor Gray
Write-Host ""
Write-Host "  Labels Created / Updated:" -ForegroundColor White
Write-Host "    Healthcare (container)     Groups & Sites scope only" -ForegroundColor White
Write-Host "    Healthcare - General       No encryption | Meetings ON | Offline: N/A" -ForegroundColor White
Write-Host "    Healthcare - Confidential  Org-wide encryption | Offline: 7 days" -ForegroundColor White
Write-Host "    Healthcare - Privileged    Purview-Medical-Privileged | Offline: Never" -ForegroundColor White
Write-Host "    Healthcare - Research      Purview-Medical-Research   | Offline: 7 days" -ForegroundColor White
Write-Host ""
Write-Host "  Offline Access Note:" -ForegroundColor Yellow
Write-Host "    These are Azure RMS use license settings — NOT a HIPAA requirement." -ForegroundColor Gray
Write-Host "    Changes apply to new use licenses only. Existing cached licenses" -ForegroundColor Gray
Write-Host "    are honoured until they expire. For immediate revocation on" -ForegroundColor Gray
Write-Host "    Privileged content use the Super User group to re-encrypt." -ForegroundColor Gray
Write-Host "    Verify: Set-AipServiceMaxUseLicenseValidityTime (tenant default)" -ForegroundColor Gray
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Add members to security groups (clinical lead, compliance, legal):" -ForegroundColor White
Write-Host "     Add-DistributionGroupMember -Identity 'Purview-Medical-Privileged@$TenantDomain' -Member 'user@$TenantDomain'" -ForegroundColor Gray
Write-Host "     Add-DistributionGroupMember -Identity 'Purview-Medical-Research@$TenantDomain'   -Member 'user@$TenantDomain'" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Publish labels to healthcare staff (NOT org-wide):" -ForegroundColor White
Write-Host "     .\Publish-HealthcareLabels.ps1 -TenantDomain '$TenantDomain'" -ForegroundColor Gray
Write-Host "     OR add to existing label policy manually in Purview portal" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Create DLP policies:" -ForegroundColor White
Write-Host "     .\Create-HealthcareDLPPolicies.ps1 -TenantDomain '$TenantDomain'" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Create EDM schemas (reuse from base demo pack):" -ForegroundColor White
Write-Host "     .\Create-EDMSchemas.ps1 -TenantDomain '$TenantDomain'" -ForegroundColor Gray
Write-Host ""
Write-Host "  5. Create auto-labeling policies:" -ForegroundColor White
Write-Host "     .\Create-HealthcareAutoLabelPolicies.ps1 -TenantDomain '$TenantDomain'" -ForegroundColor Gray
Write-Host ""
Write-Host "  VERIFY:" -ForegroundColor White
Write-Host "  Groups : Get-DistributionGroup -Filter `"Name -like 'Purview-Medical*'`" | FT Name, PrimarySmtpAddress" -ForegroundColor Gray
Write-Host "  Labels : Get-Label | Where ParentId -ne `$null | Where DisplayName -like 'Healthcare*' | FT DisplayName, Priority" -ForegroundColor Gray
Write-Host ""