# Standalone Group.Unified settings checker
# Run this in pwsh after connecting to Microsoft Graph.
# Does not depend on any other script variables.

Get-Module Microsoft.Graph* | Remove-Module -Force -ErrorAction SilentlyContinue

Import-Module Microsoft.Graph.Authentication -RequiredVersion 2.37.0 -Force -ErrorAction Stop
Import-Module Microsoft.Graph.Beta.Identity.DirectoryManagement -RequiredVersion 2.37.0 -Force -ErrorAction Stop

$ctx = Get-MgContext -ErrorAction SilentlyContinue
if (-not $ctx) {
    Connect-MgGraph -Scopes "Directory.Read.All","Group.Read.All" -NoWelcome
    $ctx = Get-MgContext
}

Write-Host "Connected as $($ctx.Account) | Tenant: $($ctx.TenantId)" -ForegroundColor Cyan

$s = Get-MgBetaDirectorySetting -All -ErrorAction Stop |
    Where-Object { $_.DisplayName -eq "Group.Unified" } |
    Select-Object -First 1

if (-not $s) {
    Write-Host "Group.Unified setting not found. Run DisableM365Groupcreaton.ps1 first." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nSetting ID: $($s.Id)" -ForegroundColor Cyan
Write-Host "`n── All Group.Unified values ──`n"
$s.Values | Sort-Object Name | Format-Table Name, Value -AutoSize

Write-Host "`n── Key policy values ──`n"
$s.Values |
    Where-Object { $_.Name -in "EnableGroupCreation","GroupCreationAllowedGroupId","EnableMSStandardBlockedWords" } |
    Format-Table Name, Value -AutoSize
