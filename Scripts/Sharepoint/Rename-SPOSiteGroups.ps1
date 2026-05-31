<#
.SYNOPSIS
    Renames SharePoint site permission groups by adding an "SPO - " prefix.
    Skips any group that already starts with "SPO - " (re-runnable / idempotent).

.DESCRIPTION
    Connects to SharePoint Online via PnP.PowerShell (cross-platform, works on macOS)
    and renames the permission groups on one site, several sites, or every site in the
    tenant. Each eligible group "<Name>" becomes "SPO - <Name>".

    SAFE BY DEFAULT: runs in report-only (-WhatIf-style preview) mode unless you pass
    -Apply. Nothing is changed until you explicitly opt in.

    Groups already starting with the prefix (default "SPO - ") are skipped, so the
    script can be run repeatedly without double-prefixing.

.PARAMETER SiteUrl
    One or more site collection URLs to process, e.g.
    "https://contoso.sharepoint.com/sites/Finance".
    Mutually exclusive with -AllSites.

.PARAMETER AllSites
    Process every site collection in the tenant. Requires -AdminUrl. Enumerates sites
    with Get-PnPTenantSite (skips OneDrive personal sites by default).

.PARAMETER AdminUrl
    SharePoint admin center URL, e.g. "https://contoso-admin.sharepoint.com".
    Required when using -AllSites.

.PARAMETER Prefix
    The prefix to add. Default: "SPO - ".

.PARAMETER Apply
    Actually perform the renames. Without it, the script only reports what it WOULD do.

.PARAMETER IncludeOneDrive
    When used with -AllSites, also include OneDrive personal sites. Off by default.

.PARAMETER ClientId
    Optional Entra app (client) ID to use for the PnP connection. If your tenant blocks
    the default PnP multitenant app, register your own and pass its ID here.

.PARAMETER OutputPath
    Directory for the CSV report and transcript log. Default: current directory.

.EXAMPLE
    # Report only — single site (no changes)
    ./Rename-SPOSiteGroups.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/Finance"

.EXAMPLE
    # Apply the rename on a single site
    ./Rename-SPOSiteGroups.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/Finance" -Apply

.EXAMPLE
    # Report across the WHOLE tenant
    ./Rename-SPOSiteGroups.ps1 -AllSites -AdminUrl "https://contoso-admin.sharepoint.com"

.EXAMPLE
    # Apply tenant-wide after reviewing the report
    ./Rename-SPOSiteGroups.ps1 -AllSites -AdminUrl "https://contoso-admin.sharepoint.com" -Apply

.NOTES
    Requires: PnP.PowerShell  (Install-Module PnP.PowerShell -Scope CurrentUser)
    Auth:     Interactive on macOS uses -Interactive (browser) or device code.
    Role:     Site Collection Admin (per-site) or SharePoint Administrator (tenant).

    These are SharePoint *site permission groups* (Owners/Members/Visitors and any
    custom SharePoint groups). This does NOT rename connected Microsoft 365 Groups,
    Teams, or Entra security groups.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(ParameterSetName = 'Site', Mandatory = $true)]
    [string[]]$SiteUrl,

    [Parameter(ParameterSetName = 'All', Mandatory = $true)]
    [switch]$AllSites,

    [Parameter(ParameterSetName = 'All', Mandatory = $true)]
    [string]$AdminUrl,

    [string]$Prefix = 'SPO - ',

    [switch]$Apply,

    # By default, the site's associated Owners/Members/Visitors groups and known
    # built-in SharePoint system groups are PROTECTED (not renamed) because flows,
    # Teams, and permission inheritance can reference them by name. Use this switch
    # to rename them anyway (not recommended).
    [switch]$IncludeDefaultGroups,

    [Parameter(ParameterSetName = 'All')]
    [switch]$IncludeOneDrive,

    [string]$ClientId,

    [string]$OutputPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}
$transcriptPath = Join-Path $OutputPath "spo-group-rename-log-$timestamp.txt"
Start-Transcript -Path $transcriptPath -Append | Out-Null

function Write-Section($text) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
    Write-Host " $text" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
}

# Common parameters used for every Connect-PnPOnline call
function Get-ConnectArgs($url) {
    $connectArgs = @{ Url = $url; Interactive = $true }
    if ($ClientId) { $connectArgs['ClientId'] = $ClientId }
    return $connectArgs
}

# Built-in SharePoint system groups that should never be renamed — these are created
# by SharePoint/publishing features and are frequently referenced by name. Matched
# case-insensitively against the group title (suffix-aware for the associated trio).
$WellKnownSystemGroups = @(
    'Excel Services Viewers',
    'Style Resource Readers',
    'Quick Deploy Users',
    'Designers',
    'Hierarchy Managers',
    'Approvers',
    'Restricted Readers',
    'Translation Managers',
    'Restricted Interface Contributors',
    'Records Center Web Service Submitters for SharePoint',
    'Viewers'
)

$report = New-Object System.Collections.Generic.List[object]

try {
    # ── 1. Module check ────────────────────────────────────────────────────────
    Write-Section "Step 1 — Checking PnP.PowerShell module"

    if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
        Write-Host "PnP.PowerShell not found. Installing for current user..." -ForegroundColor Yellow
        Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module PnP.PowerShell -Force
    Write-Host "✅ PnP.PowerShell loaded." -ForegroundColor Green

    if (-not $Apply) {
        Write-Host ""
        Write-Host "REPORT-ONLY mode. No groups will be renamed. Pass -Apply to make changes." -ForegroundColor Cyan
    }
    if (-not $IncludeDefaultGroups) {
        Write-Host "Protection ON: default associated (Owners/Members/Visitors) and built-in system groups will be skipped." -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  -IncludeDefaultGroups set: default associated and system groups WILL be renamed (may break flows/Teams)." -ForegroundColor Yellow
    }

    # ── 2. Build the list of sites to process ──────────────────────────────────
    Write-Section "Step 2 — Resolving target sites"

    $sites = @()

    if ($AllSites) {
        Write-Host "Connecting to admin center: $AdminUrl" -ForegroundColor Yellow
        $adminConnect = Get-ConnectArgs $AdminUrl
        Connect-PnPOnline @adminConnect

        Write-Host "Enumerating site collections..." -ForegroundColor Yellow
        $tenantSites = Get-PnPTenantSite -ErrorAction Stop
        if (-not $IncludeOneDrive) {
            $tenantSites = $tenantSites | Where-Object { $_.Template -notlike 'SPSPERS*' -and $_.Url -notlike '*-my.sharepoint.com/personal/*' }
        }
        $sites = $tenantSites | Select-Object -ExpandProperty Url
        Write-Host "Found $($sites.Count) site collection(s) to process." -ForegroundColor Green
    }
    else {
        $sites = $SiteUrl
        Write-Host "Processing $($sites.Count) specified site(s)." -ForegroundColor Green
    }

    # ── 3. Process each site ───────────────────────────────────────────────────
    Write-Section "Step 3 — Scanning groups"

    $renameCount    = 0
    $skipCount      = 0
    $protectedCount = 0

    foreach ($url in $sites) {
        Write-Host ""
        Write-Host "── Site: $url" -ForegroundColor White
        try {
            $siteConnect = Get-ConnectArgs $url
            Connect-PnPOnline @siteConnect
        } catch {
            Write-Warning ("  Could not connect to {0}: {1}" -f $url, $_.Exception.Message)
            $report.Add([PSCustomObject]@{
                SiteUrl = $url; GroupId = ''; OldName = ''; NewName = ''
                Action = 'ConnectError'; Detail = $_.Exception.Message
            })
            continue
        }

        try {
            $groups = Get-PnPGroup -ErrorAction Stop
        } catch {
            Write-Warning ("  Could not read groups on {0}: {1}" -f $url, $_.Exception.Message)
            $report.Add([PSCustomObject]@{
                SiteUrl = $url; GroupId = ''; OldName = ''; NewName = ''
                Action = 'GroupReadError'; Detail = $_.Exception.Message
            })
            continue
        }

        # Determine this site's associated default group IDs (Owners/Members/Visitors).
        # Matching by ID is reliable even when these groups have custom titles.
        $protectedGroupIds = @()
        if (-not $IncludeDefaultGroups) {
            try {
                $web = Get-PnPWeb -Includes AssociatedOwnerGroup, AssociatedMemberGroup, AssociatedVisitorGroup -ErrorAction Stop
                foreach ($assoc in @($web.AssociatedOwnerGroup, $web.AssociatedMemberGroup, $web.AssociatedVisitorGroup)) {
                    if ($assoc -and $assoc.Id) { $protectedGroupIds += [int]$assoc.Id }
                }
            } catch {
                Write-Warning ("  Could not resolve associated default groups on {0}: {1}" -f $url, $_.Exception.Message)
            }
        }

        foreach ($group in $groups) {
            $oldName = $group.Title

            # Protect default associated + built-in system groups (unless overridden)
            if (-not $IncludeDefaultGroups) {
                $isAssociated = $protectedGroupIds -contains [int]$group.Id
                $isSystemName = $WellKnownSystemGroups | Where-Object { $oldName -ieq $_ }

                if ($isAssociated -or $isSystemName) {
                    $why = if ($isAssociated) { 'Default associated group (Owners/Members/Visitors)' } else { 'Built-in system group' }
                    Write-Host ("  • PROTECTED (skipped): {0}  [{1}]" -f $oldName, $why) -ForegroundColor Magenta
                    $protectedCount++
                    $report.Add([PSCustomObject]@{
                        SiteUrl = $url; GroupId = $group.Id; OldName = $oldName; NewName = $oldName
                        Action = 'Protected'; Detail = $why
                    })
                    continue
                }
            }

            # Idempotent skip — already prefixed
            if ($oldName -like "$Prefix*") {
                Write-Host ("  • SKIP (already prefixed): {0}" -f $oldName) -ForegroundColor DarkGray
                $skipCount++
                $report.Add([PSCustomObject]@{
                    SiteUrl = $url; GroupId = $group.Id; OldName = $oldName; NewName = $oldName
                    Action = 'Skipped'; Detail = 'Already has prefix'
                })
                continue
            }

            $newName = "$Prefix$oldName"

            if ($Apply) {
                if ($PSCmdlet.ShouldProcess("$url :: $oldName", "Rename to '$newName'")) {
                    try {
                        Set-PnPGroup -Identity $group.Id -Title $newName -ErrorAction Stop
                        Write-Host ("  ✅ RENAMED: '{0}' → '{1}'" -f $oldName, $newName) -ForegroundColor Green
                        $renameCount++
                        $report.Add([PSCustomObject]@{
                            SiteUrl = $url; GroupId = $group.Id; OldName = $oldName; NewName = $newName
                            Action = 'Renamed'; Detail = ''
                        })
                    } catch {
                        Write-Warning ("  Failed to rename '{0}': {1}" -f $oldName, $_.Exception.Message)
                        $report.Add([PSCustomObject]@{
                            SiteUrl = $url; GroupId = $group.Id; OldName = $oldName; NewName = $newName
                            Action = 'RenameError'; Detail = $_.Exception.Message
                        })
                    }
                }
            }
            else {
                Write-Host ("  → WOULD RENAME: '{0}' → '{1}'" -f $oldName, $newName) -ForegroundColor Yellow
                $renameCount++
                $report.Add([PSCustomObject]@{
                    SiteUrl = $url; GroupId = $group.Id; OldName = $oldName; NewName = $newName
                    Action = 'WouldRename'; Detail = ''
                })
            }
        }
    }

    # ── 4. Summary + export ────────────────────────────────────────────────────
    Write-Section "Step 4 — Summary"

    $verb = if ($Apply) { 'Renamed' } else { 'Would rename' }
    Write-Host ("{0}: {1}" -f $verb, $renameCount) -ForegroundColor Green
    Write-Host ("Protected (built-in/associated, skipped): {0}" -f $protectedCount) -ForegroundColor Magenta
    Write-Host ("Skipped (already prefixed): {0}" -f $skipCount) -ForegroundColor DarkGray

    $reportCsv = Join-Path $OutputPath "spo-group-rename-report-$timestamp.csv"
    $report | Export-Csv -Path $reportCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Report exported: $reportCsv" -ForegroundColor DarkGray

    if (-not $Apply) {
        Write-Host ""
        Write-Host "Review the report above, then re-run with -Apply to perform the renames." -ForegroundColor Cyan
    }

} catch {
    Write-Error $_
} finally {
    try { Disconnect-PnPOnline -ErrorAction SilentlyContinue } catch { }
    Stop-Transcript | Out-Null
    Write-Host ""
    Write-Host "Transcript log: $transcriptPath" -ForegroundColor DarkGray
}
