<#
.SYNOPSIS
    Publishes sensitivity labels using a tiered policy architecture.

.DESCRIPTION
    Creates 3 label policies following Option B (Tiered Approach):

    Policy 1: IAC - Base Label Policy
      Labels:    Public, General
      Scope:     All Users
      Default:   General
      Mandatory: Yes
      Downgrade: Justification required
      Purpose:   Every user gets base classification labels

    Policy 2: IAC - Confidential Label Policy
      Labels:    Confidential (parent + 3 children)
      Scope:     All Users (exclude groups via -ExcludeFromConfidential)
      Default:   None (inherits from base)
      Purpose:   Internal staff see Confidential labels; contractors/externals excluded

    Policy 3: IAC - Restricted Label Policy
      Labels:    Restricted (parent + 2 children)
      Scope:     All Users (exclude groups via -ExcludeFromRestricted)
      Default:   None (inherits from base)
      Purpose:   All users get Restricted by default; exclude groups that shouldn't have access

    This tiered approach allows you to:
      - Exclude contractors from Confidential labels
      - Exclude non-privileged users from Restricted labels
      - Add department-specific labels to individual policies later
      - Set different defaults per classification tier

    Policy Conflict Resolution (how Microsoft Purview merges):
      - Label visibility: Union of ALL matching policies (merged)
      - Default label:    Highest-priority policy wins (lowest number)
      - Mandatory:        If ANY policy says mandatory, it's mandatory
      - Downgrade:        If ANY policy requires justification, it's required

.PARAMETER TenantDomain
    Your tenant's primary domain (e.g., acme2m365.onmicrosoft.com).

.PARAMETER ExcludeFromConfidential
    Array of group email addresses to EXCLUDE from the Confidential policy.
    Example: @("SG-Contractors@acme2m365.onmicrosoft.com")

.PARAMETER ExcludeFromRestricted
    Array of group email addresses to EXCLUDE from the Restricted policy.
    Example: @("SG-Contractors@acme2m365.onmicrosoft.com","SG-Temps@acme2m365.onmicrosoft.com")

.PARAMETER DryRun
    If specified, shows what would be created without making changes.

.EXAMPLE
    # Publish to all users (no exclusions)
    .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain "acme2m365.onmicrosoft.com"

    # Exclude contractors from Confidential and Restricted
    .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain "acme2m365.onmicrosoft.com" `
        -ExcludeFromConfidential @("SG-Contractors@acme2m365.onmicrosoft.com") `
        -ExcludeFromRestricted @("SG-Contractors@acme2m365.onmicrosoft.com")

    # Dry run first
    .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain "acme2m365.onmicrosoft.com" -DryRun

.NOTES
    Author: IAC
    Date: 2026-02-27
    Requires: ExchangeOnlineManagement module v3+
    Role: Compliance Administrator or Information Protection Administrator
    Dependencies: Run SensitivityLabel.ps1 first to create the labels
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeFromConfidential = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeFromRestricted = @(),

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

# ============================================================================
# CONNECT
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IAC Sensitivity Label Policy Publisher" -ForegroundColor Cyan
Write-Host "  Tiered Architecture (3 Policies)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow }
Write-Host "  Tenant: $TenantDomain" -ForegroundColor Gray
if ($ExcludeFromConfidential.Count -gt 0) {
    Write-Host "  Exclude from Confidential: $($ExcludeFromConfidential -join ', ')" -ForegroundColor Gray
}
if ($ExcludeFromRestricted.Count -gt 0) {
    Write-Host "  Exclude from Restricted:   $($ExcludeFromRestricted -join ', ')" -ForegroundColor Gray
}
Write-Host ""

try {
    Get-Label -ErrorAction Stop | Out-Null
    Write-Host "[OK] Already connected to Security & Compliance" -ForegroundColor Green
} catch {
    Write-Host "[..] Connecting to Security & Compliance PowerShell..." -ForegroundColor Yellow
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "[OK] Connected" -ForegroundColor Green
}

# ============================================================================
# VERIFY LABELS EXIST
# ============================================================================
Write-Host ""
Write-Host "--- Verifying Labels Exist ---" -ForegroundColor Magenta
Write-Host ""

$requiredLabels = @(
    "Public",
    "General",
    "Confidential",
    "Confidential - Internal",
    "Confidential - Third Parties",
    "Confidential - Reporting",
    "Restricted",
    "Restricted - Internal",
    "Restricted - Third Parties"
)

$allLabels = Get-Label -ErrorAction Stop
$missingLabels = @()

foreach ($labelName in $requiredLabels) {
    $found = $allLabels | Where-Object { $_.DisplayName -eq $labelName }
    if ($found) {
        Write-Host "  [OK] $labelName" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $labelName" -ForegroundColor Red
        $missingLabels += $labelName
    }
}

if ($missingLabels.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: $($missingLabels.Count) labels are missing. Run SensitivityLabel.ps1 first." -ForegroundColor Red
    Write-Host "Missing: $($missingLabels -join ', ')" -ForegroundColor Red
    exit 1
}

# Get General label ImmutableId for default label setting
$generalLabel = $allLabels | Where-Object { $_.DisplayName -eq "General" }
$generalId = $generalLabel.ImmutableId
Write-Host ""
Write-Host "  General ImmutableId (for default): $generalId" -ForegroundColor Gray

# ============================================================================
# HELPER: Create or report on a label policy
# ============================================================================
function Ensure-LabelPolicy {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string[]]$Labels,
        [Parameter(Mandatory)] [string]$Comment,
        [string[]]$ExchangeLocationException = @(),
        [hashtable]$AdvancedSettings = @{}
    )

    $existing = Get-LabelPolicy -Identity $Name -ErrorAction SilentlyContinue

    if ($existing) {
        Write-Host "  [EXISTS] $Name" -ForegroundColor Gray
        Write-Host "           Labels: $($existing.Labels -join ', ')" -ForegroundColor Gray
        return $existing
    }

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create: $Name" -ForegroundColor Yellow
        Write-Host "            Labels: $($Labels -join ', ')" -ForegroundColor Yellow
        if ($ExchangeLocationException.Count -gt 0) {
            Write-Host "            Exclude: $($ExchangeLocationException -join ', ')" -ForegroundColor Yellow
        }
        if ($AdvancedSettings.Count -gt 0) {
            foreach ($key in $AdvancedSettings.Keys) {
                Write-Host "            $key = $($AdvancedSettings[$key])" -ForegroundColor Yellow
            }
        }
        return $null
    }

    Write-Host "  [CREATING] $Name" -ForegroundColor Green

    $params = @{
        Name             = $Name
        Labels           = $Labels
        ExchangeLocation = "All"
        Comment          = $Comment
    }

    if ($ExchangeLocationException.Count -gt 0) {
        $params["ExchangeLocationException"] = $ExchangeLocationException
    }

    $result = New-LabelPolicy @params -ErrorAction Stop
    Write-Host "  [OK] $Name created" -ForegroundColor Green

    # Apply advanced settings separately (New-LabelPolicy doesn't accept them)
    if ($AdvancedSettings.Count -gt 0) {
        Write-Host "  [SETTINGS] Applying advanced settings..." -ForegroundColor Cyan
        Set-LabelPolicy -Identity $Name -AdvancedSettings $AdvancedSettings -ErrorAction Stop
        foreach ($key in $AdvancedSettings.Keys) {
            Write-Host "    $key = $($AdvancedSettings[$key])" -ForegroundColor Gray
        }
        Write-Host "  [OK] Advanced settings applied" -ForegroundColor Green
    }

    return $result
}

# ============================================================================
# POLICY 1: BASE — Public + General for everyone
# ============================================================================
Write-Host ""
Write-Host "--- Policy 1: Base ---" -ForegroundColor Magenta
Write-Host ""

$baseLabels = @(
    "Public",
    "General"
)

$baseAdvancedSettings = @{
    mandatory                     = "true"
    requiredowngradejustification = "true"
    defaultlabelid                = $generalId
    powerbimandatory              = "true"
}

Ensure-LabelPolicy `
    -Name "IAC - Base Label Policy" `
    -Labels $baseLabels `
    -Comment "Base policy: Public + General for all users. Default=General, mandatory labelling, downgrade justification." `
    -AdvancedSettings $baseAdvancedSettings

# ============================================================================
# POLICY 2: CONFIDENTIAL — Parent + 3 children
# ============================================================================
Write-Host ""
Write-Host "--- Policy 2: Confidential ---" -ForegroundColor Magenta
Write-Host ""

# Parent label "Confidential" is automatically included as a navigation
# header when any of its children are published — do NOT add it explicitly.
# Use internal Name property, not DisplayName (e.g. "Confidential-Internal" not "Confidential - Internal")
$confLabels = @(
    "Confidential-Internal",
    "Confidential-ThirdParties",
    "Confidential-Reporting"
)

Ensure-LabelPolicy `
    -Name "IAC - Confidential Label Policy" `
    -Labels $confLabels `
    -Comment "Confidential tier: published to all users. Exclude contractors/externals via ExchangeLocationException." `
    -ExchangeLocationException $ExcludeFromConfidential

# ============================================================================
# POLICY 3: RESTRICTED — Parent + 2 children
# ============================================================================
Write-Host ""
Write-Host "--- Policy 3: Restricted ---" -ForegroundColor Magenta
Write-Host ""

# Parent label "Restricted" is automatically included as a navigation
# header when any of its children are published — do NOT add it explicitly.
# Use internal Name property ("RestrictedGroup" is the parent's Name, children use hyphenated names)
$restLabels = @(
    "Restricted-Internal",
    "Restricted-ThirdParties"
)

Ensure-LabelPolicy `
    -Name "IAC - Restricted Label Policy" `
    -Labels $restLabels `
    -Comment "Restricted tier: published to all users. Exclude non-privileged groups via ExchangeLocationException." `
    -ExchangeLocationException $ExcludeFromRestricted

# ============================================================================
# PROPAGATION WARNING
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  IMPORTANT: Label policies take up to 24 hours to propagate" -ForegroundColor Yellow
Write-Host "  to all users and applications. During this time:" -ForegroundColor Yellow
Write-Host "    - Labels may not appear in Office apps immediately" -ForegroundColor Yellow
Write-Host "    - Default label and mandatory settings sync gradually" -ForegroundColor Yellow
Write-Host "    - Power BI and SharePoint may take longer" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary — Tiered Policies" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Policy 1: IAC - Base Label Policy" -ForegroundColor White
Write-Host "    Labels:    Public, General" -ForegroundColor Gray
Write-Host "    Scope:     All Users" -ForegroundColor Gray
Write-Host "    Default:   General" -ForegroundColor Gray
Write-Host "    Mandatory: Yes" -ForegroundColor Gray
Write-Host "    Downgrade: Justification required" -ForegroundColor Gray
Write-Host ""
Write-Host "  Policy 2: IAC - Confidential Label Policy" -ForegroundColor White
Write-Host "    Labels:    Confidential + Internal, Third Parties, Reporting" -ForegroundColor Gray
Write-Host "    Scope:     All Users" -ForegroundColor Gray
if ($ExcludeFromConfidential.Count -gt 0) {
    Write-Host "    Excluded:  $($ExcludeFromConfidential -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "    Excluded:  None" -ForegroundColor Gray
}
Write-Host ""
Write-Host "  Policy 3: IAC - Restricted Label Policy" -ForegroundColor White
Write-Host "    Labels:    Restricted + Internal, Third Parties" -ForegroundColor Gray
Write-Host "    Scope:     All Users" -ForegroundColor Gray
if ($ExcludeFromRestricted.Count -gt 0) {
    Write-Host "    Excluded:  $($ExcludeFromRestricted -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "    Excluded:  None" -ForegroundColor Gray
}
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

# ============================================================================
# VERIFICATION COMMANDS
# ============================================================================
Write-Host ""
Write-Host "  Verification commands:" -ForegroundColor Gray
Write-Host "    Get-LabelPolicy | Sort Name | FT Name, Labels, ExchangeLocation, ExchangeLocationException -AutoSize -Wrap" -ForegroundColor Gray
Write-Host "    Get-LabelPolicy -Identity 'IAC - Base Label Policy' | FL Settings" -ForegroundColor Gray
Write-Host ""
Write-Host "  To add exclusions later:" -ForegroundColor Gray
Write-Host "    Set-LabelPolicy -Identity 'IAC - Confidential Label Policy' -AddExchangeLocationException 'group@domain.com'" -ForegroundColor Gray
Write-Host "    Set-LabelPolicy -Identity 'IAC - Restricted Label Policy' -AddExchangeLocationException 'group@domain.com'" -ForegroundColor Gray
Write-Host ""
Write-Host "  To remove exclusions:" -ForegroundColor Gray
Write-Host "    Set-LabelPolicy -Identity 'IAC - Confidential Label Policy' -RemoveExchangeLocationException 'group@domain.com'" -ForegroundColor Gray
Write-Host ""
Write-Host "  To disconnect:" -ForegroundColor Gray
Write-Host "    Disconnect-ExchangeOnline -Confirm:`$false" -ForegroundColor Gray
Write-Host ""
