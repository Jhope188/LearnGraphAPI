<#
.SYNOPSIS
    Publishes the CATech retention label set for manual use across
    Exchange, SharePoint, and OneDrive.

.DESCRIPTION
    Creates a retention policy scoped to all three locations, then adds
    a rule that publishes every CATech retention label so people can pick
    them manually in Outlook/SharePoint/OneDrive.

    Publishing does NOT apply anything automatically — it only makes the
    labels selectable. This is Business Premium-achievable; it does not
    require E5 or the Purview add-on.

    Auto-apply (label picked automatically based on content) is a separate,
    E5/Purview Suite-gated capability — not covered by this script. See the
    CATech DLP Policy Build Guide, Part 4, for the auto-apply versions.

.NOTES
    Run in Security & Compliance PowerShell (Connect-IPPSSession).
    Run 01-Create-RetentionLabels.ps1 first — this script publishes
    labels, it doesn't create them.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PolicyName = "CATech - Retention - LabelPublish - AllLocations",

    [string[]]$LabelsToPublish = @(
        "Confidential",
        "Restricted",
        "Sensitive Financial Records",
        "Personal Financial PII",
        "Medical Records",
        "Employee Records",
        "Product Retired",
        "Private",
        "Public"
    )
)

function Connect-IfNeeded {
    try {
        Get-RetentionCompliancePolicy -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Host "Not connected to Security & Compliance PowerShell. Connecting..." -ForegroundColor Yellow
        Connect-IPPSSession
    }
}

Connect-IfNeeded

Write-Host "`nPublishing CATech retention label set...`n"

# Confirm every label in the list actually exists before trying to publish it —
# a typo or a label that hasn't been created yet fails the whole rule otherwise.
$missing = @()
foreach ($label in $LabelsToPublish) {
    if (-not (Get-ComplianceTag -Identity $label -ErrorAction SilentlyContinue)) {
        $missing += $label
    }
}
if ($missing.Count -gt 0) {
    Write-Host "The following labels don't exist yet — run 01-Create-RetentionLabels.ps1 first:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    return
}

# --- Create (or reuse) the publishing policy ---
$policy = Get-RetentionCompliancePolicy -Identity $PolicyName -ErrorAction SilentlyContinue
if (-not $policy) {
    if ($PSCmdlet.ShouldProcess($PolicyName, "Create retention policy")) {
        New-RetentionCompliancePolicy -Name $PolicyName `
            -ExchangeLocation All -SharePointLocation All -OneDriveLocation All | Out-Null
        Write-Host "[created] policy '$PolicyName'" -ForegroundColor Green
    }
}
else {
    Write-Host "[exists]  policy '$PolicyName' — reusing" -ForegroundColor DarkGray
}

# --- Publish the labels ---
# New-RetentionComplianceRule only allows one rule per policy, and
# -PublishComplianceTag isn't a valid Set-RetentionComplianceRule parameter
# (it's create-only) — so to change the published label list on a rule that
# already exists, remove and recreate the rule rather than trying to modify it in place.
$existingRule = Get-RetentionComplianceRule -Policy $PolicyName -ErrorAction SilentlyContinue

if ($existingRule) {
    if ($PSCmdlet.ShouldProcess($PolicyName, "Replace publishing rule with updated label list")) {
        Remove-RetentionComplianceRule -Identity $existingRule.Identity -Confirm:$false
        New-RetentionComplianceRule -Policy $PolicyName -PublishComplianceTag $LabelsToPublish | Out-Null
        Write-Host "[updated] publishing rule on '$PolicyName' (removed + recreated)" -ForegroundColor Green
    }
}
else {
    if ($PSCmdlet.ShouldProcess($PolicyName, "Publish labels")) {
        New-RetentionComplianceRule -Policy $PolicyName -PublishComplianceTag $LabelsToPublish | Out-Null
        Write-Host "[created] publishing rule on '$PolicyName'" -ForegroundColor Green
    }
}

Write-Host "`nPublished labels:" -ForegroundColor Cyan
$LabelsToPublish | ForEach-Object { Write-Host "  - $_" }

Write-Host "`nDone. Labels are now selectable in Outlook, SharePoint, and OneDrive."
Write-Host "Note: retention label policy propagation can take up to 24 hours to reach all clients.`n"
