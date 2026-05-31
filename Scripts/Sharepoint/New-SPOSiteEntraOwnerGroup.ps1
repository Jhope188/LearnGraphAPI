<#
.SYNOPSIS
    Creates ONE Entra ID group per SharePoint site ("SPO - <Site> Owners") and grants
    it owner-level (Full Control) access on that site, so ownership/membership can be
    audited centrally in Microsoft Entra.

.DESCRIPTION
    Runs in two PHASES, intentionally kept in SEPARATE PowerShell processes to avoid a
    well-known assembly conflict: PnP.PowerShell and Microsoft.Graph load different
    versions of Microsoft.Identity.Client (MSAL) and cannot reliably co-exist in one
    process. Use the companion orchestrator (or call each phase in its own pwsh).

      Phase 1  CreateEntraGroups  (Microsoft.Graph only)
               Creates/finds an Entra group "<Prefix><Title><NameSuffix>" per site.
               Default SECURITY group (recommended): mail-disabled, security-enabled,
               no mailbox/Team/site side effects. Optionally -GroupType Microsoft365.
               Optionally adds members (-Owners) and group owners (-GroupOwners).
               Writes a MAPPING CSV (Url,Title,EntraGroupId,EntraGroupName,...).

      Phase 2  GrantSiteAccess    (PnP.PowerShell only)
               Reads the mapping CSV and grants Full Control by nesting each Entra group
               into the site's existing "<SharePointGroupPrefix><Title>" SharePoint
               permission group (falls back to the associated Owners group).

    SAFE BY DEFAULT: report-only unless -Apply. Idempotent in both phases.

.PARAMETER Phase
    'CreateEntraGroups' or 'GrantSiteAccess'.

.PARAMETER SitesCsv
    (Phase 1) CSV with at least 'Url' and 'Title' columns. e.g. tenant-sites.csv.

.PARAMETER MappingCsv
    Path to the mapping CSV. Written by Phase 1, read by Phase 2.
    Default: <OutputPath>/spo-entra-owner-group-mapping.csv

.PARAMETER Prefix
    Entra group name prefix. Default: "SPO - ".

.PARAMETER NameSuffix
    Entra group name suffix. Default: " Owners". -> "SPO - <Title> Owners".

.PARAMETER GroupType
    "Security" (default) or "Microsoft365".

.PARAMETER Owners
    (Phase 1) UPNs/object IDs to add as MEMBERS of each Entra group.

.PARAMETER GroupOwners
    (Phase 1) UPNs/object IDs to set as OWNERS of each Entra group.

.PARAMETER SharePointGroupPrefix
    (Phase 2) Existing SP permission group prefix to nest into. Default "SPO - ".

.PARAMETER Apply
    Actually make changes. Without it, each phase only reports.

.PARAMETER ClientId
    Entra app (client) ID used for BOTH Connect-MgGraph and Connect-PnPOnline.

.PARAMETER GraphScopes
    (Phase 1) Delegated scopes. Default: Group.ReadWrite.All, GroupMember.ReadWrite.All,
    User.Read.All.

.PARAMETER OutputPath
    Directory for mapping CSV, report CSV, and transcript. Default: current directory.

.EXAMPLE
    # Phase 1 (own process): create Entra security groups from a sites CSV
    ./New-SPOSiteEntraOwnerGroup.ps1 -Phase CreateEntraGroups -SitesCsv sites.csv -Apply -ClientId <id>

.EXAMPLE
    # Phase 2 (own process): grant Full Control by nesting into SP groups
    ./New-SPOSiteEntraOwnerGroup.ps1 -Phase GrantSiteAccess -Apply -ClientId <id>

.NOTES
    Requires: Microsoft.Graph.Authentication, Microsoft.Graph.Groups, Microsoft.Graph.Users
              (Phase 1) and PnP.PowerShell (Phase 2).
    Run the two phases in SEPARATE processes (see Invoke-SPOSiteEntraOwnerGroup.ps1).
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('CreateEntraGroups', 'GrantSiteAccess')]
    [string]$Phase,

    [string]$SitesCsv,

    [string]$MappingCsv,

    [string]$Prefix = 'SPO - ',

    [string]$NameSuffix = ' Owners',

    [ValidateSet('Security', 'Microsoft365')]
    [string]$GroupType = 'Security',

    [string[]]$Owners,

    [string[]]$GroupOwners,

    [string]$SharePointGroupPrefix = 'SPO - ',

    [switch]$Apply,

    [string]$ClientId,

    [string]$GraphClientId,

    [string[]]$GraphScopes = @('Group.ReadWrite.All', 'GroupMember.ReadWrite.All', 'User.Read.All'),

    [string]$OutputPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}
if (-not $MappingCsv) {
    $MappingCsv = Join-Path $OutputPath 'spo-entra-owner-group-mapping.csv'
}
$transcriptPath = Join-Path $OutputPath "spo-entra-owner-group-$Phase-log-$timestamp.txt"
Start-Transcript -Path $transcriptPath -Append | Out-Null

function Write-Section($text) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
    Write-Host " $text" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor DarkCyan
}

function Get-MailNickname($displayName) {
    $clean = ($displayName -replace '[^a-zA-Z0-9]', '')
    if ([string]::IsNullOrWhiteSpace($clean)) { $clean = 'spogroup' }
    if ($clean.Length -gt 60) { $clean = $clean.Substring(0, 60) }
    return $clean.ToLower()
}

try {

if ($Phase -eq 'CreateEntraGroups') {
    # ════════════════════════════════════════════════════════════════════════
    #  PHASE 1 — Microsoft Graph ONLY
    # ════════════════════════════════════════════════════════════════════════
    Write-Section "Phase 1 — Create Entra groups (Microsoft Graph)"

    foreach ($m in @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Groups', 'Microsoft.Graph.Users')) {
        if (-not (Get-Module -ListAvailable -Name $m)) {
            Write-Host "$m not found. Installing for current user..." -ForegroundColor Yellow
            Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber
        }
        Import-Module $m -Force
    }
    Write-Host "✅ Graph modules loaded." -ForegroundColor Green

    if (-not $SitesCsv -or -not (Test-Path $SitesCsv)) {
        throw "Phase 1 requires -SitesCsv pointing to a CSV with 'Url' and 'Title' columns."
    }
    $rows = Import-Csv $SitesCsv
    Write-Host ("Sites to process: {0}" -f $rows.Count) -ForegroundColor Green

    if (-not $Apply) {
        Write-Host ""
        Write-Host "REPORT-ONLY. No Entra groups will be created. Pass -Apply to commit." -ForegroundColor Cyan
    } else {
        $connectMg = @{ Scopes = $GraphScopes }
        if ($GraphClientId) { $connectMg['ClientId'] = $GraphClientId }
        Connect-MgGraph @connectMg | Out-Null
        $ctx = Get-MgContext
        Write-Host ("✅ Connected to Graph as {0} (tenant {1})" -f $ctx.Account, $ctx.TenantId) -ForegroundColor Green
    }

    $mapping = New-Object System.Collections.Generic.List[object]
    $created = 0; $exists = 0; $errors = 0

    foreach ($row in $rows) {
        $url = $row.Url
        $title = if ($row.Title) { $row.Title } else { ($url -split '/')[-1] }
        $entraName = "{0}{1}{2}" -f $Prefix, $title, $NameSuffix

        Write-Host ""
        Write-Host ("── {0}  ({1})" -f $title, $url) -ForegroundColor White

        if (-not $Apply) {
            Write-Host ("  → WOULD CREATE Entra $GroupType group: '{0}'" -f $entraName) -ForegroundColor Yellow
            $mapping.Add([PSCustomObject]@{
                Url = $url; Title = $title; EntraGroupId = ''; EntraGroupName = $entraName
                Action = 'WouldCreate'; Detail = "type $GroupType"
            })
            $created++
            continue
        }

        # Find existing
        $group = $null
        try {
            $existing = Get-MgGroup -Filter "displayName eq '$($entraName.Replace("'","''"))'" -ConsistencyLevel eventual -CountVariable c -ErrorAction Stop
            if ($existing) { $group = $existing | Select-Object -First 1 }
        } catch { $group = $null }

        if ($group) {
            Write-Host ("  • EXISTS: '{0}' ({1})" -f $entraName, $group.Id) -ForegroundColor DarkGray
            $exists++
        } else {
            try {
                $params = @{
                    DisplayName     = $entraName
                    MailNickname    = (Get-MailNickname $entraName)
                    MailEnabled     = ($GroupType -eq 'Microsoft365')
                    SecurityEnabled = $true
                    Description     = "Owner group for SharePoint site $url"
                    GroupTypes      = @(if ($GroupType -eq 'Microsoft365') { 'Unified' })
                }
                $group = New-MgGroup @params -ErrorAction Stop
                Write-Host ("  ✅ CREATED: '{0}' ({1})" -f $entraName, $group.Id) -ForegroundColor Green
                $created++
            } catch {
                Write-Warning ("  Failed to create '{0}': {1}" -f $entraName, $_.Exception.Message)
                $errors++
                $mapping.Add([PSCustomObject]@{
                    Url = $url; Title = $title; EntraGroupId = ''; EntraGroupName = $entraName
                    Action = 'CreateError'; Detail = $_.Exception.Message
                })
                continue
            }
        }

        # Members
        if ($Owners) {
            foreach ($o in $Owners) {
                try {
                    $u = Get-MgUser -UserId $o -ErrorAction Stop
                    New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $u.Id -ErrorAction Stop
                    Write-Host ("     + member: {0}" -f $o) -ForegroundColor Green
                } catch {
                    if ($_.Exception.Message -match 'already exist|added object references') {
                        Write-Host ("     • member already present: {0}" -f $o) -ForegroundColor DarkGray
                    } else { Write-Warning ("     member '{0}': {1}" -f $o, $_.Exception.Message) }
                }
            }
        }
        # Group owners
        if ($GroupOwners) {
            foreach ($go in $GroupOwners) {
                try {
                    $u = Get-MgUser -UserId $go -ErrorAction Stop
                    New-MgGroupOwnerByRef -GroupId $group.Id -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.Id)" } -ErrorAction Stop
                    Write-Host ("     + group owner: {0}" -f $go) -ForegroundColor Green
                } catch {
                    if ($_.Exception.Message -match 'already exist|added object references') {
                        Write-Host ("     • group owner already present: {0}" -f $go) -ForegroundColor DarkGray
                    } else { Write-Warning ("     group owner '{0}': {1}" -f $go, $_.Exception.Message) }
                }
            }
        }

        $mapping.Add([PSCustomObject]@{
            Url = $url; Title = $title; EntraGroupId = $group.Id; EntraGroupName = $entraName
            Action = 'Created'; Detail = "type $GroupType"
        })
    }

    $mapping | Export-Csv -Path $MappingCsv -NoTypeInformation -Encoding UTF8

    Write-Section "Phase 1 — Summary"
    Write-Host ("Created/would-create: {0}" -f $created) -ForegroundColor Green
    Write-Host ("Already existed: {0}" -f $exists) -ForegroundColor DarkGray
    Write-Host ("Errors: {0}" -f $errors) -ForegroundColor $(if ($errors) { 'Red' } else { 'DarkGray' })
    Write-Host ("Mapping CSV: {0}" -f $MappingCsv) -ForegroundColor Cyan
    if ($Apply) {
        Write-Host ""
        Write-Host "Next: run Phase 2 (GrantSiteAccess) in a SEPARATE process to nest these groups." -ForegroundColor Cyan
    }
}
else {
    # ════════════════════════════════════════════════════════════════════════
    #  PHASE 2 — PnP.PowerShell ONLY
    # ════════════════════════════════════════════════════════════════════════
    Write-Section "Phase 2 — Grant site access (PnP.PowerShell)"

    if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
        Install-Module -Name PnP.PowerShell -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module PnP.PowerShell -Force
    Write-Host "✅ PnP.PowerShell loaded." -ForegroundColor Green

    if (-not (Test-Path $MappingCsv)) {
        throw "Phase 2 requires the mapping CSV from Phase 1: $MappingCsv (not found)."
    }
    $rows = Import-Csv $MappingCsv | Where-Object { $_.EntraGroupId }
    Write-Host ("Mapped groups to grant: {0}" -f $rows.Count) -ForegroundColor Green

    if (-not $Apply) {
        Write-Host ""
        Write-Host "REPORT-ONLY. No permissions will be granted. Pass -Apply to commit." -ForegroundColor Cyan
    }

    $report = New-Object System.Collections.Generic.List[object]
    $granted = 0; $errors = 0

    foreach ($row in $rows) {
        $url = $row.Url
        $title = $row.Title
        $groupId = $row.EntraGroupId
        $entraName = $row.EntraGroupName
        $spGroupName = "{0}{1}" -f $SharePointGroupPrefix, $title

        Write-Host ""
        Write-Host ("── {0}  ({1})" -f $title, $url) -ForegroundColor White

        $connectArgs = @{ Url = $url; Interactive = $true }
        if ($ClientId) { $connectArgs['ClientId'] = $ClientId }
        try {
            Connect-PnPOnline @connectArgs
        } catch {
            Write-Warning ("  Could not connect to {0}: {1}" -f $url, $_.Exception.Message)
            $errors++
            $report.Add([PSCustomObject]@{ Url = $url; EntraGroup = $entraName; SPGroup = $spGroupName; Action = 'ConnectError'; Detail = $_.Exception.Message })
            continue
        }

        # Find target SP group, fall back to associated Owners group
        $targetSpGroup = $null
        try { $targetSpGroup = Get-PnPGroup -Identity $spGroupName -ErrorAction SilentlyContinue } catch { $targetSpGroup = $null }
        if (-not $targetSpGroup) {
            try {
                $assocWeb = Get-PnPWeb -Includes AssociatedOwnerGroup -ErrorAction Stop
                $targetSpGroup = $assocWeb.AssociatedOwnerGroup
                $spGroupName = $targetSpGroup.Title
                Write-Host ("  ℹ SP group '{0}{1}' not found — using associated Owners group '{2}'." -f $SharePointGroupPrefix, $title, $spGroupName) -ForegroundColor DarkYellow
            } catch {
                Write-Warning ("  No SP group to nest into on {0}." -f $url)
                $errors++
                $report.Add([PSCustomObject]@{ Url = $url; EntraGroup = $entraName; SPGroup = ''; Action = 'NoSPGroup'; Detail = $_.Exception.Message })
                continue
            }
        }

        $claims = if ($GroupType -eq 'Microsoft365') {
            "c:0o.c|federateddirectoryclaimprovider|$groupId"
        } else {
            "c:0t.c|tenant|$groupId"
        }

        if (-not $Apply) {
            Write-Host ("  → WOULD NEST '{0}' into SP group '{1}' (Full Control)" -f $entraName, $spGroupName) -ForegroundColor Yellow
            $report.Add([PSCustomObject]@{ Url = $url; EntraGroup = $entraName; SPGroup = $spGroupName; Action = 'WouldGrant'; Detail = $claims })
            continue
        }

        try {
            Add-PnPGroupMember -LoginName $claims -Identity $targetSpGroup.Id -ErrorAction Stop
            Write-Host ("  ✅ GRANTED Full Control: nested '{0}' into '{1}'" -f $entraName, $spGroupName) -ForegroundColor Green
            $granted++
            $report.Add([PSCustomObject]@{ Url = $url; EntraGroup = $entraName; SPGroup = $spGroupName; Action = 'Granted'; Detail = $claims })
        } catch {
            if ($_.Exception.Message -match 'already') {
                Write-Host ("  • Already nested into '{0}'." -f $spGroupName) -ForegroundColor DarkGray
                $report.Add([PSCustomObject]@{ Url = $url; EntraGroup = $entraName; SPGroup = $spGroupName; Action = 'AlreadyGranted'; Detail = '' })
            } else {
                Write-Warning ("  Could not nest: {0}" -f $_.Exception.Message)
                $errors++
                $report.Add([PSCustomObject]@{ Url = $url; EntraGroup = $entraName; SPGroup = $spGroupName; Action = 'GrantError'; Detail = $_.Exception.Message })
            }
        }
    }

    $reportCsv = Join-Path $OutputPath "spo-entra-owner-group-grant-report-$timestamp.csv"
    $report | Export-Csv -Path $reportCsv -NoTypeInformation -Encoding UTF8

    Write-Section "Phase 2 — Summary"
    Write-Host ("Full Control grants: {0}" -f $granted) -ForegroundColor Green
    Write-Host ("Errors: {0}" -f $errors) -ForegroundColor $(if ($errors) { 'Red' } else { 'DarkGray' })
    Write-Host ("Report CSV: {0}" -f $reportCsv) -ForegroundColor DarkGray
}

} catch {
    Write-Error $_
} finally {
    try { Disconnect-PnPOnline -ErrorAction SilentlyContinue } catch { }
    try { if (Get-MgContext -ErrorAction SilentlyContinue) { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } } catch { }
    Stop-Transcript | Out-Null
    Write-Host ""
    Write-Host "Transcript log: $transcriptPath" -ForegroundColor DarkGray
}
