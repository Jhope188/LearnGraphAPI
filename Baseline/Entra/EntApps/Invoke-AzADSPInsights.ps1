<#
.SYNOPSIS
    Runs AzADServicePrincipalInsights to export all Service Principals from the tenant.
    https://github.com/JulianHayward/AzADServicePrincipalInsights

.DESCRIPTION
    Clones (or updates) the AzADServicePrincipalInsights repo from GitHub, installs
    required modules, then executes the collection script and writes HTML/JSON/CSV
    output to a timestamped folder under .\Output.

.NOTES
    Prerequisites
    ─────────────
    • PowerShell 7.0.3 or later
    • Az.Accounts module             (Install-Module Az.Accounts)
    • AzAPICall module               (installed automatically by the script below)
    • Microsoft.Graph.Authentication (installed automatically by the script below)
    • Entra ID permissions on the identity you connect with:
        - Application.Read.All
        - Group.Read.All
        - RoleManagement.Read.Directory
        - User.Read.All
    • Azure resource-side collection is disabled — no Azure RBAC role needed.

.EXAMPLE
    # Interactive login (your own account):
    .\Invoke-AzADSPInsights.ps1

.EXAMPLE
    # Service Principal login:
    $cred = Get-Credential   # ClientId as username, secret as password
    .\Invoke-AzADSPInsights.ps1 -ServicePrincipal -TenantId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -Credential $cred
#>

[CmdletBinding()]
param (
    # Your Entra tenant ID. Defaults to the tenant of the current Az context.
    [string]$TenantId,

    # Connect as a Service Principal instead of interactively.
    [switch]$ServicePrincipal,

    # PSCredential for SP login (ClientId = username, secret = password).
    [System.Management.Automation.PSCredential]$Credential,

    # Management Group to scope the run to. Defaults to Tenant Root MG.
    [string[]]$ManagementGroupId,

    # Where to write the output files. Defaults to .\Output\<timestamp>.
    [string]$OutputPath,

    # CSV column delimiter. Default: ';'
    [string]$CsvDelimiter = ';',

    # Only report on SPs that have an RBAC role assignment within the MG scope.
    [switch]$OnlyProcessSPsThatHaveARoleAssignmentInTheRelevantMGScopes,

    # Opt out of anonymous usage statistics sent to the tool author.
    [switch]$StatsOptOut,

    # Enable transcript logging.
    [switch]$DoTranscript,

    # Warn on secrets expiring within N days (default 14).
    [int]$ApplicationSecretExpiryWarning = 14,

    # Warn on certs expiring within N days (default 14).
    [int]$ApplicationCertificateExpiryWarning = 14
)

#requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 0. Resolve paths ──────────────────────────────────────────────────────────
$repoUrl   = 'https://github.com/JulianHayward/AzADServicePrincipalInsights.git'
$repoDir   = Join-Path $PSScriptRoot 'AzADServicePrincipalInsights'
$scriptPath = Join-Path $repoDir 'pwsh' 'AzADServicePrincipalInsights.ps1'

if (-not $OutputPath) {
    $timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $OutputPath = Join-Path $PSScriptRoot 'Output' $timestamp
}

New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

# ── 1. Clone or update the repo ───────────────────────────────────────────────
if (Test-Path (Join-Path $repoDir '.git')) {
    Write-Host '⟳  Updating AzADServicePrincipalInsights repo...' -ForegroundColor Cyan
    git -C $repoDir pull --ff-only
}
else {
    Write-Host '⬇  Cloning AzADServicePrincipalInsights repo...' -ForegroundColor Cyan
    git clone $repoUrl $repoDir
}

if (-not (Test-Path $scriptPath)) {
    throw "Script not found at expected path: $scriptPath"
}

# ── 2. Install / update required modules ─────────────────────────────────────

# Ensure PowerShellGet is modern enough to reliably install from PSGallery
if ((Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1).Version -lt [version]'2.2.5') {
    Write-Host '📦 Updating PowerShellGet...' -ForegroundColor Yellow
    Install-Module -Name PowerShellGet -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
    Write-Host '⚠  PowerShellGet updated — you may need to restart this session if installs fail below.' -ForegroundColor Yellow
}

# Ensure PSGallery is trusted so installs don't prompt interactively
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
    Write-Host '🔓 Trusting PSGallery for this session...' -ForegroundColor Cyan
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

foreach ($module in @('Az.Accounts', 'AzAPICall', 'Microsoft.Graph.Authentication')) {
    $installed = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $installed) {
        Write-Host "📦 Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "✔  Installed: $module" -ForegroundColor Green
    }
    else {
        Write-Host "✔  Module present: $module (v$($installed.Version))" -ForegroundColor Green
    }
    Import-Module -Name $module -ErrorAction Stop
}

# ── 3. Authenticate ───────────────────────────────────────────────────────────
Write-Host '🔑 Connecting to Azure...' -ForegroundColor Cyan

if ($ServicePrincipal) {
    if (-not $Credential) {
        $Credential = Get-Credential -Message 'Enter Service Principal ClientId (username) and secret (password)'
    }
    if ($TenantId) {
        Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential | Out-Null
    }
    else {
        Connect-AzAccount -ServicePrincipal -Credential $Credential | Out-Null
    }
}
else {
    if ($TenantId) {
        Connect-AzAccount -TenantId $TenantId | Out-Null
    }
    else {
        Connect-AzAccount | Out-Null
    }
}

Write-Host "✔  Connected as: $((Get-AzContext).Account.Id)" -ForegroundColor Green

# ── 3b. Connect to Microsoft Graph ───────────────────────────────────────────
$graphScopes = @(
    'Application.Read.All'
    'Group.Read.All'
    'RoleManagement.Read.Directory'
    'User.Read.All'
)

Write-Host '🔑 Connecting to Microsoft Graph...' -ForegroundColor Cyan

if ($ServicePrincipal) {
    # SP login — use client secret credential
    Connect-MgGraph -ClientSecretCredential $Credential -TenantId (Get-AzContext).Tenant.Id | Out-Null
}
else {
    Connect-MgGraph -Scopes $graphScopes -TenantId (Get-AzContext).Tenant.Id | Out-Null
}

Write-Host "✔  Graph connected as: $((Get-MgContext).Account)" -ForegroundColor Green

# ── 4. Build the parameter splat ─────────────────────────────────────────────
$params = @{
    OutputPath                   = $OutputPath
    CsvDelimiter                 = $CsvDelimiter
    ApplicationSecretExpiryWarning      = $ApplicationSecretExpiryWarning
    ApplicationCertificateExpiryWarning = $ApplicationCertificateExpiryWarning
}

# Azure resource-side collection is always disabled — Graph-only run
$params['NoAzureResourceSideRelations'] = $true

if ($ManagementGroupId)                                         { $params['ManagementGroupId']                                         = $ManagementGroupId }
if ($OnlyProcessSPsThatHaveARoleAssignmentInTheRelevantMGScopes){ $params['OnlyProcessSPsThatHaveARoleAssignmentInTheRelevantMGScopes'] = $true }
if ($StatsOptOut)                                               { $params['StatsOptOut']                                               = $true }
if ($DoTranscript)                                              { $params['DoTranscript']                                              = $true }

# ── 5. Run the insights script ────────────────────────────────────────────────
Write-Host ''
Write-Host "▶  Running AzADServicePrincipalInsights..." -ForegroundColor Cyan
Write-Host "   Output path: $OutputPath" -ForegroundColor Gray
Write-Host ''

# Disable strict mode before calling the inner script — it sets its own rules
# and our StrictMode -Version Latest would otherwise propagate and break
# property access on null collections inside the tool.
Set-StrictMode -Off

# The inner script resolves permissionClassification.json and other assets
# using relative paths, so we must run it from within its own directory.
Push-Location $repoDir
try {
    & $scriptPath @params
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host "✅ Done. Output files written to: $OutputPath" -ForegroundColor Green
Write-Host '   Open the .html file in a browser for the full interactive report.'
