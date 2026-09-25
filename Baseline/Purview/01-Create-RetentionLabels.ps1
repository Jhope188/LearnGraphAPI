<#
.SYNOPSIS
    Creates the CATech retention label set in Microsoft Purview.

.DESCRIPTION
    Creates all retention labels for the CATech data lifecycle design:
    7 existing-taxonomy labels plus the 2 new labels (Restricted, Medical Records)
    added to align with the CATech DLP/sensitivity label pack.

    Idempotent: skips any label that already exists rather than erroring out,
    so this is safe to re-run against a tenant that already has some labels.

.NOTES
    Run in Security & Compliance PowerShell (Connect-IPPSSession), not
    standard Exchange Online PowerShell.

    Medical Records uses a PLACEHOLDER retention period — HIPAA does not set
    a federal patient-record retention period; that's governed by state law
    and varies by jurisdiction. Confirm the correct duration for the client's
    state before running this against a production tenant, and update
    $MedicalRetentionDays below.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    # Placeholder — confirm against client state law before use.
    # 2190 days = 6 years, used here only as a conservative floor
    # (matches HIPAA's federal compliance-documentation retention minimum,
    # NOT a patient-record retention citation).
    [int]$MedicalRetentionDays = 2190
)

function Connect-IfNeeded {
    try {
        Get-ComplianceTag -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "Not connected to Security & Compliance PowerShell. Connecting..." -ForegroundColor Yellow
        Connect-IPPSSession
    }
}

function New-RetentionLabelIfMissing {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$RetentionAction,   # Keep | KeepAndDelete | Delete
        [string]$RetentionType = "ModificationAgeInDays",
        [object]$RetentionDuration,                        # int (days) or "Unlimited"
        [string]$Comment
    )

    $existing = Get-ComplianceTag -Identity $Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  [skip]   '$Name' already exists" -ForegroundColor DarkGray
        return
    }

    $params = @{
        Name            = $Name
        RetentionAction = $RetentionAction
        RetentionType   = $RetentionType
        RetentionDuration = $RetentionDuration
    }
    if ($Comment) { $params.Comment = $Comment }

    if ($PSCmdlet.ShouldProcess($Name, "Create retention label")) {
        New-ComplianceTag @params | Out-Null
        Write-Host "  [created] '$Name'" -ForegroundColor Green
    }
}

Connect-IfNeeded

Write-Host "`nCreating CATech retention label set...`n"

# --- Existing labels (recreate-safe — already present in most CATech tenants) ---
New-RetentionLabelIfMissing -Name "Sensitive Financial Records" -RetentionAction Keep -RetentionDuration 1825 `
    -Comment "Financial DLP pack — 5 years"

New-RetentionLabelIfMissing -Name "Confidential" -RetentionAction Keep -RetentionDuration 2555 `
    -Comment "Confidential sensitivity label counterpart — 7 years"

New-RetentionLabelIfMissing -Name "Product Retired" -RetentionAction Keep -RetentionDuration 3650 `
    -Comment "10 years"

New-RetentionLabelIfMissing -Name "Private" -RetentionAction Keep -RetentionDuration 1825 `
    -Comment "5 years"

New-RetentionLabelIfMissing -Name "Personal Financial PII" -RetentionAction Keep -RetentionDuration 1095 `
    -Comment "Financial/PII pack — 3 years"

New-RetentionLabelIfMissing -Name "Public" -RetentionAction Keep -RetentionDuration 1825 `
    -Comment "Public pack — 5 years"

New-RetentionLabelIfMissing -Name "Employee Records" -RetentionAction Keep -RetentionDuration "Unlimited" `
    -Comment "HR — retained forever"

# --- New labels ---
New-RetentionLabelIfMissing -Name "Restricted" -RetentionAction Keep -RetentionDuration 2555 `
    -Comment "Restricted sensitivity label counterpart — 7 years, aligned to Confidential"

New-RetentionLabelIfMissing -Name "Medical Records" -RetentionAction Keep -RetentionDuration $MedicalRetentionDays `
    -Comment "Medical DLP pack counterpart — CONFIRM against client state law before publishing"

Write-Host "`nDone. Run 02-Publish-RetentionLabels.ps1 next to make these labels usable.`n"
