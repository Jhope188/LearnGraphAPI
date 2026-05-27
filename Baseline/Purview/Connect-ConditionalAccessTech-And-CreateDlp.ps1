#Requires -Version 7
<#
.SYNOPSIS
    Connects to conditionalaccess.tech tenant and deploys the DLP policy.

.DESCRIPTION
    Connects to Security & Compliance PowerShell and deploys the DLP policy.
    Note: Purview DLP policy creation is performed via IPPS cmdlets, not PnP.

.PARAMETER AdminUpn
    Optional admin UPN in conditionalaccess.tech tenant.
    If omitted, interactive sign-in is used.

.PARAMETER DryRun
    Validates connections and shows what would be changed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AdminUpn,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "[INFO] Ensuring modules..." -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
}

Import-Module ExchangeOnlineManagement -ErrorAction Stop

Write-Host "[INFO] Connecting to Security & Compliance PowerShell" -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($AdminUpn)) {
    Connect-IPPSSession | Out-Null
}
else {
    Connect-IPPSSession -UserPrincipalName $AdminUpn | Out-Null
}
Write-Host "[OK] Security & Compliance connected" -ForegroundColor Green

$scriptPath = Join-Path $PSScriptRoot "Create-Dlp-ConfidentialThirdParty-NoRecipient.ps1"

if ($DryRun) {
    if ([string]::IsNullOrWhiteSpace($AdminUpn)) {
        & $scriptPath -DryRun
    }
    else {
        & $scriptPath -UserPrincipalName $AdminUpn -DryRun
    }
} else {
    if ([string]::IsNullOrWhiteSpace($AdminUpn)) {
        & $scriptPath
    }
    else {
        & $scriptPath -UserPrincipalName $AdminUpn
    }
}
