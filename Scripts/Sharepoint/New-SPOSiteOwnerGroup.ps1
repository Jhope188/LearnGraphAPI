<#
.SYNOPSIS
    Creates ONE custom SharePoint permission group per site (named "SPO - <Site>")
    and grants it Full Control (owner-level) on that site. Re-runnable / idempotent.

.DESCRIPTION
    Connects to SharePoint Online via PnP.PowerShell (cross-platform, works on macOS)
    and, for each target site, creates a new SharePoint group whose title is the site
    title prefixed with "SPO - " (configurable). The new group is granted the
    "Full Control" role so it behaves as an owner group. You can then add the desired
    owner accounts to that single group per site.

    Why this instead of renaming the built-in Owners group?
      • The default associated Owners/Members/Visitors groups are referenced by
        Teams, flows, and permission inheritance — renaming them is risky.
      • Creating a NEW group leaves the built-ins untouched and gives you a clean,
        consistently named owner group per site.

    SAFE BY DEFAULT: runs in report-only (preview) mode unless you pass -Apply.
    Idempotent: if a group with the target name already exists on a site, it is left
    as-is (and its Full Control role is ensured), so the script can be re-run safely.

.PARAMETER SiteUrl
    One or more site collection URLs to process. Mutually exclusive with -AllSites.

.PARAMETER AllSites
    Process every site collection in the tenant. Requires -AdminUrl.

.PARAMETER AdminUrl
    SharePoint admin center URL, e.g. "https://contoso-admin.sharepoint.com".
    Required when using -AllSites.

.PARAMETER Prefix
    Prefix for the new group name. Default: "SPO - ".
    The group is named "<Prefix><SiteTitle>", e.g. "SPO - Finance".

.PARAMETER NameSuffix
    Optional suffix appended after the site title, e.g. " Owners" to produce
    "SPO - Finance Owners". Default: '' (no suffix).

.PARAMETER PermissionLevel
    The role to grant the new group. Default: "Full Control" (owner-level).

.PARAMETER Owners
    Optional. One or more login names / emails to add as members of the new group
    (i.e. the people who should own the site). Applied only with -Apply.

.PARAMETER Apply
    Actually create the groups / grant permissions. Without it, the script only
    reports what it WOULD do.

.PARAMETER IncludeOneDrive
    When used with -AllSites, also include OneDrive personal sites. Off by default.

.PARAMETER ClientId
    Optional Entra app (client) ID for the PnP connection.

.PARAMETER OutputPath
    Directory for the CSV report and transcript log. Default: current directory.

.EXAMPLE
    # Report only — single site
    ./New-SPOSiteOwnerGroup.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/Finance"

.EXAMPLE
    # Create the group and grant Full Control on a single site
    ./New-SPOSiteOwnerGroup.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/Finance" -Apply

.EXAMPLE
    # Create owner group on several sites and add owners
    ./New-SPOSiteOwnerGroup.ps1 -SiteUrl $urls -Owners "jon@contoso.com" -Apply

.EXAMPLE
    # Tenant-wide report
    ./New-SPOSiteOwnerGroup.ps1 -AllSites -AdminUrl "https://contoso-admin.sharepoint.com"

.NOTES
    Requires: PnP.PowerShell  (Install-Module PnP.PowerShell -Scope CurrentUser)
    Role:     Site Collection Admin (per-site) or SharePoint Administrator (tenant).

    Creating a SharePoint permission group does NOT create a mail-enabled object and
    does NOT affect any connected Microsoft 365 Group, Team, or its email address.
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

    [string]$NameSuffix = '',

    [string]$PermissionLevel = 'Full Control',

    [string[]]$Owners,

    [switch]$Apply,

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
$transcriptPath = Join-Path $OutputPath "spo-owner-group-log-$timestamp.txt"
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
        Write-Host "REPORT-ONLY mode. No groups will be created. Pass -Apply to make changes." -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "APPLY mode. New owner groups will be created and granted '$PermissionLevel'." -ForegroundColor Yellow
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

    # ── 3. Create one owner group per site ─────────────────────────────────────
    Write-Section "Step 3 — Creating owner groups"

    $createdCount = 0
    $existsCount  = 0
    $errorCount   = 0

    foreach ($url in $sites) {
        Write-Host ""
        Write-Host ("── Site: {0}" -f $url) -ForegroundColor White

        try {
            $siteConnect = Get-ConnectArgs $url
            Connect-PnPOnline @siteConnect
        } catch {
            Write-Warning ("  Could not connect to {0}: {1}" -f $url, $_.Exception.Message)
            $errorCount++
            $report.Add([PSCustomObject]@{
                SiteUrl = $url; GroupName = ''; Action = 'ConnectError'; Detail = $_.Exception.Message
            })
            continue
        }

        # Resolve the site title to build the group name
        try {
            $web = Get-PnPWeb -Includes Title -ErrorAction Stop
            $siteTitle = $web.Title
        } catch {
            $siteTitle = ($url -split '/')[-1]
        }

        $groupName = "{0}{1}{2}" -f $Prefix, $siteTitle, $NameSuffix

        # Idempotent check — does the group already exist?
        $existing = $null
        try {
            $existing = Get-PnPGroup -Identity $groupName -ErrorAction SilentlyContinue
        } catch { $existing = $null }

        if ($existing) {
            Write-Host ("  • EXISTS: '{0}' (id {1}) — ensuring '{2}' role" -f $groupName, $existing.Id, $PermissionLevel) -ForegroundColor DarkGray
            $existsCount++

            if ($Apply) {
                try {
                    Set-PnPGroupPermissions -Identity $existing.Id -AddRole $PermissionLevel -ErrorAction Stop
                } catch {
                    Write-Warning ("    Could not ensure role: {0}" -f $_.Exception.Message)
                }
                if ($Owners) {
                    foreach ($o in $Owners) {
                        try { Add-PnPGroupMember -LoginName $o -Identity $existing.Id -ErrorAction Stop }
                        catch { Write-Warning ("    Could not add owner '{0}': {1}" -f $o, $_.Exception.Message) }
                    }
                }
            }

            $report.Add([PSCustomObject]@{
                SiteUrl = $url; GroupName = $groupName; Action = 'AlreadyExists'; Detail = "id $($existing.Id)"
            })
            continue
        }

        if ($Apply) {
            if ($PSCmdlet.ShouldProcess("$url :: $groupName", "Create group and grant '$PermissionLevel'")) {
                try {
                    $newGroup = New-PnPGroup -Title $groupName -ErrorAction Stop
                    Set-PnPGroupPermissions -Identity $newGroup.Id -AddRole $PermissionLevel -ErrorAction Stop
                    Write-Host ("  ✅ CREATED: '{0}' (id {1}) with '{2}'" -f $groupName, $newGroup.Id, $PermissionLevel) -ForegroundColor Green
                    $createdCount++

                    if ($Owners) {
                        foreach ($o in $Owners) {
                            try {
                                Add-PnPGroupMember -LoginName $o -Identity $newGroup.Id -ErrorAction Stop
                                Write-Host ("     + added owner: {0}" -f $o) -ForegroundColor Green
                            } catch {
                                Write-Warning ("    Could not add owner '{0}': {1}" -f $o, $_.Exception.Message)
                            }
                        }
                    }

                    $report.Add([PSCustomObject]@{
                        SiteUrl = $url; GroupName = $groupName; Action = 'Created'; Detail = "id $($newGroup.Id); role $PermissionLevel"
                    })
                } catch {
                    Write-Warning ("  Failed to create '{0}': {1}" -f $groupName, $_.Exception.Message)
                    $errorCount++
                    $report.Add([PSCustomObject]@{
                        SiteUrl = $url; GroupName = $groupName; Action = 'CreateError'; Detail = $_.Exception.Message
                    })
                }
            }
        }
        else {
            Write-Host ("  → WOULD CREATE: '{0}' and grant '{1}'" -f $groupName, $PermissionLevel) -ForegroundColor Yellow
            if ($Owners) {
                Write-Host ("     would add owners: {0}" -f ($Owners -join ', ')) -ForegroundColor Yellow
            }
            $createdCount++
            $report.Add([PSCustomObject]@{
                SiteUrl = $url; GroupName = $groupName; Action = 'WouldCreate'; Detail = "role $PermissionLevel"
            })
        }
    }

    # ── 4. Summary + export ────────────────────────────────────────────────────
    Write-Section "Step 4 — Summary"

    $verb = if ($Apply) { 'Created' } else { 'Would create' }
    Write-Host ("{0}: {1}" -f $verb, $createdCount) -ForegroundColor Green
    Write-Host ("Already existed: {0}" -f $existsCount) -ForegroundColor DarkGray
    Write-Host ("Errors: {0}" -f $errorCount) -ForegroundColor $(if ($errorCount) { 'Red' } else { 'DarkGray' })

    $reportCsv = Join-Path $OutputPath "spo-owner-group-report-$timestamp.csv"
    $report | Export-Csv -Path $reportCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Report exported: $reportCsv" -ForegroundColor DarkGray

    if (-not $Apply) {
        Write-Host ""
        Write-Host "Review the report above, then re-run with -Apply to create the groups." -ForegroundColor Cyan
    }

} catch {
    Write-Error $_
} finally {
    try { Disconnect-PnPOnline -ErrorAction SilentlyContinue } catch { }
    Stop-Transcript | Out-Null
    Write-Host ""
    Write-Host "Transcript log: $transcriptPath" -ForegroundColor DarkGray
}
