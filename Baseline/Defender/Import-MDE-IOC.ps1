# https://github.com/jkerai1/DNSTwistToMDEIOC
#
# Import-MDE-IOC.ps1
# Bulk imports MDE-IOC-Batch-1.csv into Microsoft Defender for Endpoint
# as Custom Indicators (Threat Intelligence Indicators / tiIndicators) via
# the Microsoft Graph Security API.
#
# Companion script to Import-TABL-DNSTwist.ps1 (DNSTwist.ps1) which blocks
# the same typosquat domains at the Exchange Online Tenant Allow/Block List
# (sender) layer. This script blocks them at the endpoint/network layer so
# devices cannot resolve or connect to the domains even outside of mail flow.
#
# macOS — requires PowerShell 7+ and the Microsoft.Graph.Authentication module
#
# Required Graph scope: ThreatIndicators.ReadWrite.OwnedBySource
#
# CSV columns expected (as produced by DNSTwistToMDEIOC's MDE-IOC generator):
#   IndicatorType,IndicatorValue,ExpirationTime,Action,Severity,Title,
#   Description,RecommendedActions,RbacGroups,Category,MitreTechniques,GenerateAlert
#
# Note: Microsoft Graph tiIndicators enforces a 500 IOC-per-request limit and
# the DNSTwistToMDEIOC tooling already batches output into 500-row files
# (…Batch-1.csv, …Batch-2.csv, etc.) — run this script once per batch file.

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$CsvPath = "$HOME/Downloads/DNSTwist/MDE-IOC-Batch-1.csv",

    # Fallback expiration (days from now) used only when the CSV's
    # ExpirationTime column is blank.
    [Parameter()]
    [int]$DefaultExpirationDays = 30,

    # Traffic Light Protocol level applied to every indicator.
    [Parameter()]
    [ValidateSet('white', 'green', 'amber', 'red')]
    [string]$TlpLevel = 'amber',

    # Threat classification applied to every indicator.
    [Parameter()]
    [string]$ThreatType = 'phishing'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -Path $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

# --- Connect to Microsoft Graph -------------------------------------------------
try {
    $null = Get-MgContext -ErrorAction Stop
    if (-not (Get-MgContext)) { throw 'No active Graph session' }
    Write-Host "Using existing Microsoft Graph session: $((Get-MgContext).Account)" -ForegroundColor Cyan
}
catch {
    Write-Host 'Connecting to Microsoft Graph...' -ForegroundColor Cyan
    Connect-MgGraph -Scopes 'ThreatIndicators.ReadWrite.OwnedBySource' -NoWelcome
}

# Map DNSTwistToMDEIOC's textual severity to the Graph tiIndicator 0-5 int scale.
function Convert-Severity {
    param([string]$Severity)
    switch -Regex ($Severity) {
        'Informational' { return 0 }
        'Low'           { return 1 }
        'Medium'        { return 3 }
        'High'          { return 5 }
        default         { return 1 }
    }
}

# Map CSV IndicatorType -> the Graph tiIndicator observable property name.
function Get-ObservablePropertyName {
    param([string]$IndicatorType)
    switch ($IndicatorType) {
        'DomainName' { return 'domainName' }
        'Url'        { return 'url' }
        'FileSha256' { return 'fileHashValue' }
        'FileSha1'   { return 'fileHashValue' }
        'FileMd5'    { return 'fileHashValue' }
        'IpAddress'  { return 'networkIPv4' }
        default      { throw "Unsupported IndicatorType: $IndicatorType" }
    }
}

$rows = Import-Csv -Path $CsvPath
Write-Host "Loaded $($rows.Count) indicator(s) from $CsvPath" -ForegroundColor Cyan

if ($rows.Count -gt 500) {
    Write-Warning "This file contains $($rows.Count) rows. Microsoft Graph tiIndicators enforces a 500 IOC limit per submission — split the CSV before continuing."
}

$defaultExpiration = (Get-Date).AddDays($DefaultExpirationDays).ToString('yyyy-MM-ddTHH:mm:ssZ')

$success = 0
$failed  = 0

foreach ($row in $rows) {

    $observableProperty = Get-ObservablePropertyName -IndicatorType $row.IndicatorType

    $expirationDateTime = if ([string]::IsNullOrWhiteSpace($row.ExpirationTime)) {
        $defaultExpiration
    }
    else {
        ([datetime]$row.ExpirationTime).ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    $body = @{
        action              = $row.Action.ToLower()
        threatType          = $ThreatType
        tlpLevel            = $TlpLevel
        targetProduct       = 'Microsoft Defender ATP'
        expirationDateTime  = $expirationDateTime
        severity            = Convert-Severity -Severity $row.Severity
        title               = $row.Title
        description         = $row.Description
        recommendedActions  = $row.RecommendedActions
        passiveOnly         = $false
        $observableProperty = $row.IndicatorValue
    }

    if (-not [string]::IsNullOrWhiteSpace($row.GenerateAlert)) {
        $body.additionalInformation = "GenerateAlert: $($row.GenerateAlert)"
    }

    if ($PSCmdlet.ShouldProcess($row.IndicatorValue, "Create MDE custom indicator ($($row.Action))")) {
        try {
            $null = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/security/tiIndicators' -Body ($body | ConvertTo-Json -Depth 5)
            Write-Host "Blocked: $($row.IndicatorValue)" -ForegroundColor Green
            $success++
        }
        catch {
            Write-Warning "Failed to create indicator for $($row.IndicatorValue): $($_.Exception.Message)"
            $failed++
        }
    }
}

Write-Host ''
Write-Host "Done. Success: $success  Failed: $failed" -ForegroundColor Cyan
