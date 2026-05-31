<#
.SYNOPSIS
    Orchestrates New-SPOSiteEntraOwnerGroup.ps1 by running its two phases in SEPARATE
    PowerShell processes — required because PnP.PowerShell and Microsoft.Graph cannot
    share a process (conflicting Microsoft.Identity.Client / MSAL versions).

.DESCRIPTION
    1. Builds a filtered sites CSV (Url,Title) from a tenant export, excluding sites you
       don't want to touch (e.g. All Company, Viva).
    2. Phase 1 (own process): Microsoft.Graph — create Entra security groups; writes a
       mapping CSV.
    3. Phase 2 (own process): PnP.PowerShell — nest each Entra group into the matching
       "SPO - <Site>" SharePoint group to grant Full Control.

.PARAMETER TenantSitesCsv
    Path to the full tenant sites export (must have 'Url' and 'Title' columns).

.PARAMETER ExcludeUrlLike
    One or more wildcard patterns; matching sites are excluded.

.PARAMETER ClientId
    Entra app (client) ID used for both Graph and PnP connections.

.PARAMETER Owners
    Optional UPNs/object IDs added as MEMBERS of each Entra group (Phase 1).

.PARAMETER GroupOwners
    Optional UPNs/object IDs set as OWNERS of each Entra group (Phase 1).

.PARAMETER GroupType
    'Security' (default) or 'Microsoft365'.

.PARAMETER Apply
    Actually create groups and grant access. Omit for a report-only dry run.

.PARAMETER OutputPath
    Working/output directory. Default: script folder.

.EXAMPLE
    # Dry run
    ./Invoke-SPOSiteEntraOwnerGroup.ps1 -TenantSitesCsv tenant-sites.csv -ClientId <id>

.EXAMPLE
    # Apply, excluding All Company + Viva, adding an owner
    ./Invoke-SPOSiteEntraOwnerGroup.ps1 -TenantSitesCsv tenant-sites.csv -ClientId <id> `
        -ExcludeUrlLike '*/sites/allcompany','*groupforanswersinvivaengage*' `
        -Owners 'jon@contoso.com' -Apply
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantSitesCsv,

    [string[]]$ExcludeUrlLike = @('*/sites/allcompany', '*groupforanswersinvivaengage*'),

    [string]$ClientId,

    [string]$GraphClientId,

    [string[]]$Owners,

    [string[]]$GroupOwners,

    [ValidateSet('Security', 'Microsoft365')]
    [string]$GroupType = 'Security',

    [switch]$Apply,

    [string]$OutputPath = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$worker = Join-Path $here 'New-SPOSiteEntraOwnerGroup.ps1'
if (-not (Test-Path $worker)) { throw "Worker script not found: $worker" }

# ── Build filtered sites CSV ────────────────────────────────────────────────
$all = Import-Csv $TenantSitesCsv
$filtered = $all | Where-Object {
    $u = $_.Url
    ($u -like '*/sites/*') -and -not ($ExcludeUrlLike | Where-Object { $u -like $_ })
}
$filteredCsv = Join-Path $OutputPath 'spo-entra-sites-filtered.csv'
$filtered | Select-Object Url, Title | Export-Csv -Path $filteredCsv -NoTypeInformation -Encoding UTF8
Write-Host ("Filtered sites: {0} -> {1}" -f $filtered.Count, $filteredCsv) -ForegroundColor Green

$mappingCsv = Join-Path $OutputPath 'spo-entra-owner-group-mapping.csv'

# ── Phase 1 (Graph) in its own process ──────────────────────────────────────
$p1 = @('-NoProfile', '-File', $worker,
    '-Phase', 'CreateEntraGroups',
    '-SitesCsv', $filteredCsv,
    '-MappingCsv', $mappingCsv,
    '-GroupType', $GroupType,
    '-OutputPath', $OutputPath)
if ($GraphClientId) { $p1 += @('-GraphClientId', $GraphClientId) }
if ($Owners)      { $p1 += @('-Owners');      $p1 += $Owners }
if ($GroupOwners) { $p1 += @('-GroupOwners'); $p1 += $GroupOwners }
if ($Apply)       { $p1 += '-Apply' }

Write-Host ""
Write-Host "════ Launching Phase 1 (Microsoft Graph) ════" -ForegroundColor Magenta
pwsh @p1
if ($LASTEXITCODE -ne 0) { throw "Phase 1 failed (exit $LASTEXITCODE)." }

# ── Phase 2 (PnP) in its own process ────────────────────────────────────────
$p2 = @('-NoProfile', '-File', $worker,
    '-Phase', 'GrantSiteAccess',
    '-MappingCsv', $mappingCsv,
    '-GroupType', $GroupType,
    '-OutputPath', $OutputPath)
if ($ClientId) { $p2 += @('-ClientId', $ClientId) }
if ($Apply)    { $p2 += '-Apply' }

Write-Host ""
Write-Host "════ Launching Phase 2 (PnP.PowerShell) ════" -ForegroundColor Magenta
pwsh @p2
if ($LASTEXITCODE -ne 0) { throw "Phase 2 failed (exit $LASTEXITCODE)." }

Write-Host ""
Write-Host "✅ Done. Mapping: $mappingCsv" -ForegroundColor Green
