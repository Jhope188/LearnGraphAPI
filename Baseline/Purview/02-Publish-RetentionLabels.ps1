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
    ),

    # --- Pilot scoping ---
    # Leave all three empty/unset to publish tenant-wide (original behavior).
    # Populate any of these to scope the policy to a pilot group instead of everyone:
    #   -ExchangeLocation "pilot-group@yourtenant.com"   (mail-enabled security group or individual mailboxes)
    #   -SharePointLocation "https://yourtenant.sharepoint.com/sites/PilotSite"
    #   -OneDriveLocation "user1@yourtenant.com","user2@yourtenant.com"
    [string[]]$ExchangeLocation,
    [string[]]$SharePointLocation,
    [string[]]$OneDriveLocation
)

# If none of the pilot-scoping params were supplied, fall back to tenant-wide (All).
# This keeps the script's default behavior unchanged for anyone not opting into a pilot.
$isPilotScoped = $ExchangeLocation -or $SharePointLocation -or $OneDriveLocation
if (-not $isPilotScoped) {
    Write-Host "No pilot scope supplied — this will publish labels tenant-wide (All locations)." -ForegroundColor Yellow
}
else {
    Write-Host "Pilot scope supplied — publishing only to the specified locations, not tenant-wide." -ForegroundColor Cyan
}

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
$policyIsNew = $false
if (-not $policy) {
    if ($PSCmdlet.ShouldProcess($PolicyName, "Create retention policy")) {
        # Build the location parameters dynamically: use the pilot-scoped values if
        # supplied, otherwise fall back to "All" (tenant-wide) for each location type.
        $newPolicyParams = @{
            Name = $PolicyName
        }
        $newPolicyParams.ExchangeLocation   = if ($ExchangeLocation)   { $ExchangeLocation }   else { "All" }
        $newPolicyParams.SharePointLocation = if ($SharePointLocation) { $SharePointLocation } else { "All" }
        $newPolicyParams.OneDriveLocation   = if ($OneDriveLocation)   { $OneDriveLocation }   else { "All" }

        New-RetentionCompliancePolicy @newPolicyParams | Out-Null
        Write-Host "[created] policy '$PolicyName'" -ForegroundColor Green
        $policyIsNew = $true
    }
}
else {
    Write-Host "[exists]  policy '$PolicyName' — reusing" -ForegroundColor DarkGray
}

# Newly created policies take time to deploy/propagate in the Purview backend before
# rules can be attached to them — attaching a rule immediately after creation reliably
# fails with "Policy '<guid>' failed to be deployed. ... please retry the policy
# operation after some time." This is expected backend latency, not a script bug.
# Poll Get-RetentionCompliancePolicy's DistributionStatus until it reports the policy
# has finished deploying (or timeout), instead of a blind fixed sleep, so this stays
# fast on tenants where propagation is quick and still reliable when it's slow.
if ($policyIsNew) {
    Write-Host "Waiting for policy to finish deploying before attaching rules..." -ForegroundColor Yellow
    $maxWaitSeconds = 180
    $pollIntervalSeconds = 10
    $elapsed = 0
    $deployed = $false

    while ($elapsed -lt $maxWaitSeconds) {
        Start-Sleep -Seconds $pollIntervalSeconds
        $elapsed += $pollIntervalSeconds
        $currentPolicy = Get-RetentionCompliancePolicy -Identity $PolicyName -ErrorAction SilentlyContinue
        if ($currentPolicy -and $currentPolicy.DistributionStatus -eq "Success") {
            $deployed = $true
            break
        }
        Write-Host "  ...still deploying ($elapsed s elapsed, status: $($currentPolicy.DistributionStatus))" -ForegroundColor DarkGray
    }

    if ($deployed) {
        Write-Host "Policy deployed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Policy did not report 'Success' within $maxWaitSeconds seconds — proceeding anyway," -ForegroundColor Yellow
        Write-Host "but rule creation below may need to be re-run if it fails with a deployment error." -ForegroundColor Yellow
    }
}

# --- Publish the labels ---
# IMPORTANT: -PublishComplianceTag is typed as a single String by the cmdlet
# (confirmed against Microsoft's official New-RetentionComplianceRule docs) —
# it accepts exactly ONE label name per call, NOT an array of labels and NOT
# an array of hashtables. Passing multiple values in one call always fails with
# "Cannot process argument transformation on parameter 'PublishComplianceTag'.
# Cannot convert value to type System.String." (this is what happened both times
# we tried arrays and hashtables above).
#
# The fix: create one rule per label, all attached to the same policy. Rule
# names must be unique within the policy, so each rule is named after its label.
#
# Any existing rules on this policy are removed first so re-running the script
# with a different $LabelsToPublish list ends up with exactly the rules that
# match the current list (no stale rules left over from a previous run).
$existingRules = Get-RetentionComplianceRule -Policy $PolicyName -ErrorAction SilentlyContinue

function New-RuleWithRetry {
    param(
        [Parameter(Mandatory)][string]$PolicyName,
        [Parameter(Mandatory)][string]$Label,
        [int]$MaxAttempts = 4,
        [int]$RetryDelaySeconds = 15
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            New-RetentionComplianceRule -Policy $PolicyName -PublishComplianceTag $Label -ErrorAction Stop | Out-Null
            return
        }
        catch {
            $isDeploymentError = $_.Exception.Message -match "failed to be deployed|retry the policy operation"
            if ($isDeploymentError -and $attempt -lt $MaxAttempts) {
                Write-Host "  [retry $attempt/$MaxAttempts] Policy still deploying for label '$Label' — waiting ${RetryDelaySeconds}s..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelaySeconds
                continue
            }
            throw
        }
    }
}

try {
    if ($existingRules) {
        foreach ($rule in $existingRules) {
            if ($PSCmdlet.ShouldProcess($rule.Identity, "Remove existing publishing rule")) {
                Remove-RetentionComplianceRule -Identity $rule.Identity -Confirm:$false -ErrorAction Stop
            }
        }
    }

    foreach ($label in $LabelsToPublish) {
        if ($PSCmdlet.ShouldProcess($PolicyName, "Publish label '$label'")) {
            New-RuleWithRetry -PolicyName $PolicyName -Label $label
            Write-Host "[created] publishing rule for '$label' on '$PolicyName'" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "`n[FAILED] Could not create/update the publishing rule(s): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "The policy container '$PolicyName' may exist WITHOUT all rules attached — it will show" -ForegroundColor Red
    Write-Host "up under Retention policies in Purview but NOT under Label policies until this is fixed." -ForegroundColor Red
    Write-Host "Delete '$PolicyName' in Purview (or via Remove-RetentionCompliancePolicy) and re-run this script." -ForegroundColor Red
    return
}

Write-Host "`nPublished labels:" -ForegroundColor Cyan
$LabelsToPublish | ForEach-Object { Write-Host "  - $_" }

Write-Host "`nDone. Labels are now selectable in Outlook, SharePoint, and OneDrive"
if ($isPilotScoped) {
    Write-Host "for the pilot scope you specified (not tenant-wide)." -ForegroundColor Cyan
}
else {
    Write-Host "tenant-wide (all users/sites)." -ForegroundColor Yellow
}
Write-Host "Note: retention label policy propagation can take up to 24 hours to reach all clients.`n"
