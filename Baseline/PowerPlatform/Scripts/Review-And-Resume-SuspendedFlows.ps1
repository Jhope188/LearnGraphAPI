<#
.SYNOPSIS
    Reviews Power Platform cloud flows across all environments, reports suspended
    flows (including DLP-suspended ones), and optionally re-enables them.

.DESCRIPTION
    Connects to a Power Platform tenant (default: conditionalaccess.tech), enumerates
    every cloud flow in every environment the signed-in admin can see, and builds a
    full inventory. It then isolates flows that are not running — with special focus
    on those suspended by a Data Loss Prevention (DLP) policy violation
    (flowSuspensionReason = 'CompanyDlpViolation').

    By default the script runs in REPORT-ONLY mode (no changes). To actually re-enable
    flows, pass -Resume. Re-enabling forces a fresh DLP re-evaluation: if the
    offending DLP policy has NOT been fixed, the flow will simply suspend again.

    All findings are exported to timestamped CSV files and a transcript log.

.PARAMETER TenantDomain
    The tenant you intend to operate against, used as a guard. The script verifies the
    signed-in account's domain matches before making any changes. Default:
    conditionalaccess.tech

.PARAMETER Resume
    Switch. When supplied, the script attempts to re-enable the suspended flows it
    finds. Without it, the script only reports (safe default).

.PARAMETER IncludeAllSuspended
    By default only DLP-suspended flows (CompanyDlpViolation) are eligible for resume.
    Use this switch to also resume flows suspended for other reasons.

.PARAMETER EnvironmentName
    Optional. Restrict the operation to a single environment (GUID/name). When omitted,
    all environments are processed.

.PARAMETER OutputPath
    Directory for CSV exports and the transcript log. Default: current directory.

.PARAMETER WhatIf
    Standard PowerShell dry-run. Shows what would be re-enabled without doing it.

.EXAMPLE
    # Report only — no changes (safe default)
    .\Review-And-Resume-SuspendedFlows.ps1

.EXAMPLE
    # Re-enable DLP-suspended flows after you've fixed the DLP policy
    .\Review-And-Resume-SuspendedFlows.ps1 -Resume

.EXAMPLE
    # Preview which flows would be re-enabled, without doing it
    .\Review-And-Resume-SuspendedFlows.ps1 -Resume -WhatIf

.EXAMPLE
    # Resume ALL suspended flows (any reason) in one environment
    .\Review-And-Resume-SuspendedFlows.ps1 -Resume -IncludeAllSuspended -EnvironmentName "Default-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

.NOTES
    Requires: Microsoft.PowerApps.Administration.PowerShell
    Role:     Power Platform Administrator (or Global Administrator)

    IMPORTANT: Fix the DLP policy conflict BEFORE running with -Resume, otherwise
    DLP-suspended flows will re-suspend immediately on re-evaluation.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$TenantDomain = 'conditionalaccess.tech',

    [switch]$Resume,

    [switch]$IncludeAllSuspended,

    [string]$EnvironmentName,

    [string]$OutputPath = (Get-Location).Path,

    # ── Authentication (required on macOS/Linux — interactive WinForms login is Windows-only) ──
    # Service principal (recommended). The SPN needs Power Platform admin rights.
    [string]$ApplicationId,
    [string]$ClientSecret,
    [string]$TenantId,

    # Username/password (ROPC) — only works for accounts WITHOUT MFA.
    [string]$Username,
    [string]$Password
)

# ── Setup ──────────────────────────────────────────────────────────────────────

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcriptPath = Join-Path $OutputPath "flow-resume-log-$timestamp.txt"

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

Start-Transcript -Path $transcriptPath -Append | Out-Null

function Write-Section($text) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
    Write-Host " $text" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
}

try {
    # ── 1. Ensure module is available ──────────────────────────────────────────
    Write-Section "Step 1 — Checking Power Apps Administration module"

    $module = 'Microsoft.PowerApps.Administration.PowerShell'
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Module '$module' not found. Installing for current user..." -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $module -Force
    Write-Host "✅ Module loaded." -ForegroundColor Green

    # ── 2. Connect ─────────────────────────────────────────────────────────────
    Write-Section "Step 2 — Connecting to Power Platform"

    $onWindows = if ($null -ne $IsWindows) { $IsWindows } else { $true }  # PS5.1 has no $IsWindows; it's Windows-only

    if ($ApplicationId -and $ClientSecret -and $TenantId) {
        # Service principal authentication (works cross-platform, MFA-safe)
        Write-Host "Authenticating as service principal $ApplicationId on tenant $TenantId..." -ForegroundColor Yellow
        Add-PowerAppsAccount -TenantID $TenantId -ApplicationId $ApplicationId -ClientSecret $ClientSecret
        Write-Host "✅ Service principal connected." -ForegroundColor Green
    }
    elseif ($Username -and $Password) {
        # Username/password (ROPC) — no MFA accounts only
        Write-Host "Authenticating as $Username (username/password)..." -ForegroundColor Yellow
        $securePwd = ConvertTo-SecureString $Password -AsPlainText -Force
        Add-PowerAppsAccount -Username $Username -Password $securePwd
        Write-Host "✅ Connected as $Username." -ForegroundColor Green
    }
    elseif ($onWindows) {
        # Interactive (Windows only — relies on System.Windows.Forms)
        Write-Host "A sign-in prompt will appear. Sign in with a Power Platform Administrator" -ForegroundColor Yellow
        Write-Host "account for tenant: $TenantDomain" -ForegroundColor Yellow
        Add-PowerAppsAccount
        Write-Host ""
        Write-Host "Signed in. Confirm the account/tenant shown in the sign-in window" -ForegroundColor Yellow
        Write-Host "matches '$TenantDomain' before proceeding with any -Resume action." -ForegroundColor Yellow
    }
    else {
        throw @"
Interactive sign-in is not supported on macOS/Linux (it requires System.Windows.Forms, which is Windows-only).
Provide non-interactive credentials instead:

  Service principal (recommended, MFA-safe):
    -ApplicationId <appId> -ClientSecret <secret> -TenantId <tenantGuid>

  Username/password (non-MFA accounts only):
    -Username admin@$TenantDomain -Password <password>

To create a service principal for Power Platform admin, see Step 16 of the
PowerPlatform-Security-Guide.md, or run on a Windows host for interactive login.
"@
    }

    # ── 3. Enumerate environments ──────────────────────────────────────────────
    Write-Section "Step 3 — Enumerating environments"

    if ($EnvironmentName) {
        $environments = @(Get-AdminPowerAppEnvironment -EnvironmentName $EnvironmentName)
    } else {
        $environments = Get-AdminPowerAppEnvironment
    }

    if (-not $environments -or $environments.Count -eq 0) {
        throw "No environments returned. Check your permissions and tenant."
    }
    Write-Host "Found $($environments.Count) environment(s)." -ForegroundColor Green

    # Tenant guard: confirm the connected tenant matches the expected domain.
    # We derive the tenant from the signed-in admin's UPN (creator) on the environments.
    $observedDomains = $environments |
        ForEach-Object { $_.Internal.properties.createdBy.userPrincipalName } |
        Where-Object { $_ -match '@' } |
        ForEach-Object { ($_ -split '@')[1] } |
        Sort-Object -Unique

    if ($observedDomains) {
        Write-Host ("Observed admin domain(s): {0}" -f ($observedDomains -join ', ')) -ForegroundColor DarkGray
        $domainMatch = $observedDomains | Where-Object { $_ -like "*$TenantDomain*" }
        if (-not $domainMatch) {
            Write-Warning ("Connected tenant domain does not appear to match '{0}'." -f $TenantDomain)
            if ($Resume) {
                throw "Tenant guard tripped: refusing to -Resume against a tenant that doesn't match '$TenantDomain'. Re-run after signing into the correct tenant, or adjust -TenantDomain."
            }
        } else {
            Write-Host ("✅ Tenant domain matches '{0}'." -f $TenantDomain) -ForegroundColor Green
        }
    }

    # ── 4. Inventory all flows ─────────────────────────────────────────────────
    Write-Section "Step 4 — Inventorying all cloud flows"

    $allFlows = New-Object System.Collections.Generic.List[object]

    foreach ($env in $environments) {
        Write-Host ("  → {0} ({1})" -f $env.DisplayName, $env.EnvironmentName) -ForegroundColor Gray
        try {
            $flows = Get-AdminFlow -EnvironmentName $env.EnvironmentName
        } catch {
            Write-Warning ("    Could not enumerate flows in {0}: {1}" -f $env.DisplayName, $_.Exception.Message)
            continue
        }

        foreach ($flow in $flows) {
            $props = $flow.Internal.properties
            $allFlows.Add([PSCustomObject]@{
                EnvironmentDisplayName = $env.DisplayName
                EnvironmentName        = $env.EnvironmentName
                FlowName               = $flow.DisplayName
                FlowId                 = $flow.FlowName
                State                  = $props.state
                SuspensionReason       = $props.flowSuspensionReason
                SuspensionTime         = $props.flowSuspensionTime
                Owner                  = $props.creator.userPrincipalName
                CreatedTime            = $props.createdTime
                LastModifiedTime       = $props.lastModifiedTime
            })
        }
    }

    Write-Host "✅ Inventoried $($allFlows.Count) flow(s) total." -ForegroundColor Green

    $inventoryCsv = Join-Path $OutputPath "flow-inventory-$timestamp.csv"
    $allFlows | Export-Csv -Path $inventoryCsv -NoTypeInformation -Encoding UTF8
    Write-Host "   Inventory exported: $inventoryCsv" -ForegroundColor DarkGray

    # ── 5. Identify suspended flows ────────────────────────────────────────────
    Write-Section "Step 5 — Identifying suspended flows"

    $suspended = $allFlows | Where-Object { $_.State -eq 'Suspended' }
    $dlpSuspended = $suspended | Where-Object { $_.SuspensionReason -eq 'CompanyDlpViolation' }
    $otherSuspended = $suspended | Where-Object { $_.SuspensionReason -ne 'CompanyDlpViolation' }

    Write-Host ("Suspended (all reasons): {0}" -f @($suspended).Count) -ForegroundColor Yellow
    Write-Host ("  • DLP-suspended (CompanyDlpViolation): {0}" -f @($dlpSuspended).Count) -ForegroundColor Yellow
    Write-Host ("  • Suspended (other reasons):           {0}" -f @($otherSuspended).Count) -ForegroundColor Yellow

    if (@($suspended).Count -gt 0) {
        Write-Host ""
        $suspended |
            Select-Object EnvironmentDisplayName, FlowName, Owner, SuspensionReason, SuspensionTime |
            Format-Table -AutoSize

        $suspendedCsv = Join-Path $OutputPath "flow-suspended-$timestamp.csv"
        $suspended | Export-Csv -Path $suspendedCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Suspended flows exported: $suspendedCsv" -ForegroundColor DarkGray
    } else {
        Write-Host "🎉 No suspended flows found. Nothing to do." -ForegroundColor Green
        return
    }

    # ── 6. Re-enable (only if -Resume) ─────────────────────────────────────────
    Write-Section "Step 6 — Re-enabling suspended flows"

    if (-not $Resume) {
        Write-Host "REPORT-ONLY mode. No flows were changed." -ForegroundColor Cyan
        Write-Host "Re-run with -Resume to re-enable the flows listed above." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "⚠️  Reminder: fix the offending DLP policy FIRST, or DLP-suspended" -ForegroundColor Yellow
        Write-Host "    flows will re-suspend immediately on re-evaluation." -ForegroundColor Yellow
        return
    }

    # Decide which set to resume
    $toResume = if ($IncludeAllSuspended) { $suspended } else { $dlpSuspended }

    if (@($toResume).Count -eq 0) {
        Write-Host "No eligible flows to resume with the current options." -ForegroundColor Cyan
        if (-not $IncludeAllSuspended -and @($otherSuspended).Count -gt 0) {
            Write-Host "Tip: $($otherSuspended.Count) non-DLP suspended flow(s) exist. Use -IncludeAllSuspended to include them." -ForegroundColor DarkGray
        }
        return
    }

    Write-Host ""
    Write-Host "⚠️  Before continuing, confirm the DLP policy conflict has been resolved." -ForegroundColor Yellow
    Write-Host "    Otherwise these flows will re-suspend on the next DLP evaluation." -ForegroundColor Yellow
    Write-Host ""

    $results = New-Object System.Collections.Generic.List[object]
    $success = 0
    $failed  = 0

    foreach ($flow in $toResume) {
        $target = "{0}  (owner: {1}, env: {2})" -f $flow.FlowName, $flow.Owner, $flow.EnvironmentDisplayName

        if ($PSCmdlet.ShouldProcess($target, "Enable suspended flow")) {
            try {
                Enable-AdminFlow -EnvironmentName $flow.EnvironmentName -FlowName $flow.FlowId | Out-Null

                # Re-check state to confirm it actually resumed (did not immediately re-suspend)
                Start-Sleep -Seconds 2
                $recheck = Get-AdminFlow -EnvironmentName $flow.EnvironmentName -FlowName $flow.FlowId
                $newState = $recheck.Internal.properties.state

                $outcome = if ($newState -eq 'Started') { 'Resumed' }
                           elseif ($newState -eq 'Suspended') { 'Re-suspended (DLP likely still in conflict)' }
                           else { "State: $newState" }

                if ($newState -eq 'Started') { $success++ } else { $failed++ }

                Write-Host ("  {0} → {1}" -f $flow.FlowName, $outcome) -ForegroundColor (
                    if ($newState -eq 'Started') { 'Green' } else { 'Yellow' }
                )

                $results.Add([PSCustomObject]@{
                    FlowName        = $flow.FlowName
                    Owner           = $flow.Owner
                    Environment     = $flow.EnvironmentDisplayName
                    PreviousReason  = $flow.SuspensionReason
                    NewState        = $newState
                    Outcome         = $outcome
                })
            } catch {
                $failed++
                Write-Warning ("  Failed to enable {0}: {1}" -f $flow.FlowName, $_.Exception.Message)
                $results.Add([PSCustomObject]@{
                    FlowName        = $flow.FlowName
                    Owner           = $flow.Owner
                    Environment     = $flow.EnvironmentDisplayName
                    PreviousReason  = $flow.SuspensionReason
                    NewState        = 'Error'
                    Outcome         = $_.Exception.Message
                })
            }
        }
    }

    # ── 7. Summary ─────────────────────────────────────────────────────────────
    Write-Section "Step 7 — Summary"

    Write-Host ("Attempted:     {0}" -f @($toResume).Count)
    Write-Host ("Resumed OK:    {0}" -f $success) -ForegroundColor Green
    Write-Host ("Not resumed:   {0}" -f $failed) -ForegroundColor Yellow

    if ($results.Count -gt 0) {
        $resultsCsv = Join-Path $OutputPath "flow-resume-results-$timestamp.csv"
        $results | Export-Csv -Path $resultsCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Results exported: $resultsCsv" -ForegroundColor DarkGray
    }

    if ($failed -gt 0) {
        Write-Host ""
        Write-Host "Some flows did not resume. The most common cause is the DLP policy" -ForegroundColor Yellow
        Write-Host "conflict still being active. Fix the policy, then re-run with -Resume." -ForegroundColor Yellow
    }

} catch {
    Write-Error $_
} finally {
    Stop-Transcript | Out-Null
    Write-Host ""
    Write-Host "Transcript log: $transcriptPath" -ForegroundColor DarkGray
}
