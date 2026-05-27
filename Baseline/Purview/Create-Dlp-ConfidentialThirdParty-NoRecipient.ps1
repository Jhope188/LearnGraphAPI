#Requires -Version 7
<#
.SYNOPSIS
    Creates (or updates) a DLP policy that blocks external email labeled
    "Confidential - Third Parties" when no IRM protection is applied.

.DESCRIPTION
    Enforces a transport-layer backstop for misconfigured user-defined label protection.
    Logic:
      - Label = Confidential - Third Parties
      - Recipient outside organization
      - EXCEPT when MessageType = PermissionControlled

    Action:
      - Block send
      - Notify sender with policy tip
      - Generate alert

.PARAMETER TenantDomain
    Tenant domain used for Connect-IPPSSession (e.g., contoso.onmicrosoft.com).

.PARAMETER UserPrincipalName
    Optional admin UPN used for Connect-IPPSSession when no existing session is found.
    If omitted, interactive sign-in is used.

.PARAMETER DryRun
    Shows intended operations without creating/updating objects.

.EXAMPLE
    ./Create-Dlp-ConfidentialThirdParty-NoRecipient.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    ./Create-Dlp-ConfidentialThirdParty-NoRecipient.ps1 -UserPrincipalName admin@contoso.com -DryRun
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$PolicyName = "Confidential - Block External Third Party without Recipient"
$RuleName   = "Block-ConfThirdParty-NoEncryptionRecipient"
$LabelName  = "Confidential - Third Parties"

function Write-Info($Message) { Write-Host "[INFO]  $Message" -ForegroundColor Cyan }
function Write-Ok($Message)   { Write-Host "[OK]    $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[WARN]  $Message" -ForegroundColor Yellow }

function Ensure-ComplianceConnection {
    try {
        Get-Label -ErrorAction Stop | Out-Null
        Write-Ok "Already connected to Security & Compliance PowerShell"
        return
    }
    catch {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop

        Write-Info "Connecting to Security & Compliance PowerShell..."
        if ($UserPrincipalName) {
            Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop | Out-Null
        }
        elseif ($TenantDomain) {
            Connect-IPPSSession -Organization $TenantDomain -ErrorAction Stop | Out-Null
        }
        else {
            Connect-IPPSSession -ErrorAction Stop | Out-Null
        }

        Get-Label -ErrorAction Stop | Out-Null
        Write-Ok "Connected"
    }
}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host " DLP Policy Deployment: Confidential Third Party Backstop" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Warn "DRY RUN mode enabled. No changes will be applied." }
Write-Host ""

Ensure-ComplianceConnection

Write-Info "Resolving label '$LabelName'"
$label = Get-Label -Identity $LabelName -ErrorAction SilentlyContinue
if (-not $label) {
    $label = Get-Label -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $LabelName } | Select-Object -First 1
}
if (-not $label) {
    throw "Label '$LabelName' was not found. Verify it exists and is published."
}
$labelId = $label.ImmutableId
Write-Ok "Label resolved: $labelId"

$labelCondition = @{
    operator = "And"
    groups   = @(
        @{
            operator = "Or"
            name     = "Default"
            labels   = @(
                @{
                    name = $labelId
                    type = "Sensitivity"
                }
            )
        }
    )
}

$existingPolicy = Get-DlpCompliancePolicy -Identity $PolicyName -ErrorAction SilentlyContinue
if ($existingPolicy) {
    Write-Ok "Policy exists: $PolicyName"
}
elseif ($DryRun) {
    Write-Info "Would create policy: $PolicyName"
}
else {
    Write-Info "Creating policy: $PolicyName"
    New-DlpCompliancePolicy `
        -Name $PolicyName `
        -Comment "Blocks outbound Confidential-Third Parties email where IRM recipients were not configured." `
        -ExchangeLocation All `
        -Mode Enable | Out-Null
    Write-Ok "Policy created"
}

$existingRule = Get-DlpComplianceRule -Identity $RuleName -ErrorAction SilentlyContinue
if ($existingRule) {
    Write-Ok "Rule exists: $RuleName"

    if ($DryRun) {
        Write-Info "Would update existing rule to the target configuration"
    }
    else {
        Write-Info "Updating existing rule to target configuration"
        Set-DlpComplianceRule `
            -Identity                         $RuleName `
            -ContentContainsSensitiveInformation $labelCondition `
            -AccessScope                      NotInOrganization `
            -ExceptIfMessageTypeMatches       PermissionControlled `
            -BlockAccess                      $true `
            -NotifyUser                       Owner `
            -NotifyPolicyTipCustomText        "This email is labeled Confidential - Third Parties but authorized recipients have not been configured. Re-open the email, re-apply the label, and select your authorized recipients before sending." `
            -GenerateAlert                    $true `
            -AlertProperties                  @{ AggregationType = "SimpleAggregation"; Threshold = 3; TimeWindow = 60 } | Out-Null
        Write-Ok "Rule updated"
    }
}
elseif ($DryRun) {
    Write-Info "Would create rule: $RuleName"
    Write-Host "        - AccessScope: NotInOrganization" -ForegroundColor DarkGray
    Write-Host "        - ExceptIfMessageTypeMatches: PermissionControlled" -ForegroundColor DarkGray
    Write-Host "        - BlockAccess: True" -ForegroundColor DarkGray
}
else {
    Write-Info "Creating rule: $RuleName"
    New-DlpComplianceRule `
        -Name                               $RuleName `
        -Policy                             $PolicyName `
        -ContentContainsSensitiveInformation $labelCondition `
        -AccessScope                        NotInOrganization `
        -ExceptIfMessageTypeMatches         PermissionControlled `
        -BlockAccess                        $true `
        -NotifyUser                         Owner `
        -NotifyPolicyTipCustomText          "This email is labeled Confidential - Third Parties but authorized recipients have not been configured. Re-open the email, re-apply the label, and select your authorized recipients before sending." `
        -GenerateAlert                      $true `
        -AlertProperties                    @{ AggregationType = "SimpleAggregation"; Threshold = 3; TimeWindow = 60 } | Out-Null
    Write-Ok "Rule created"
}

Write-Host ""
Write-Info "Verification"
if ($DryRun) {
    Write-Warn "Dry run complete. No changes were applied."
}
else {
    Get-DlpCompliancePolicy -Identity $PolicyName | Format-List Name,Mode,ExchangeLocation
    Get-DlpComplianceRule -Identity $RuleName | Format-List Name,Disabled,AccessScope,ExceptIfMessageTypeMatches,BlockAccess
}
