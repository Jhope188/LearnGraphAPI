<#
.SYNOPSIS
    Creates IAC sensitivity labels (does NOT publish — use Publish-SensitivityLabelPolicies.ps1).

.DESCRIPTION
    Implements the Purview Practitioner 4-group taxonomy (Public, General, Confidential, Restricted)
    with best-practice encryption, content markings, and container scoping.

    Labels:
      Public                          - No protection, external-safe
      General                         - Default label, header/footer only
      Confidential (parent)           - Group container (Groups & Sites scope)
        |- Confidential - Internal    - Encrypted (org-wide), markings
        |- Confidential - Third Parties - Encrypted (user-defined recipients), markings
        +- Confidential - Reporting   - Encrypted (org-wide), markings
      Restricted (parent)             - Group container (Groups & Sites scope)
        |- Restricted - Internal      - Encrypted (admin-only template), markings
        +- Restricted - Third Parties - Encrypted (user-defined recipients), markings

    After running this script, publish labels using:
      .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain "acme2m365.onmicrosoft.com"

    Reference:
      https://www.thepurviewpractitioner.com/tools/taxonomy
      https://learn.microsoft.com/purview/sensitivity-labels

.PARAMETER TenantDomain
    Your tenant's primary domain (e.g., contoso.onmicrosoft.com). Used to build
    encryption rights definitions for Template-encrypted labels.

.PARAMETER AdminEmail
    Admin or security group email for Restricted-Internal encryption rights.
    Defaults to admin@<TenantDomain>.

.PARAMETER DryRun
    If specified, shows what would be created without making changes.

.EXAMPLE
    .\SensitivityLabel.ps1 -TenantDomain "acme2m365.onmicrosoft.com"
    .\SensitivityLabel.ps1 -TenantDomain "acme2m365.onmicrosoft.com" -DryRun

.NOTES
    Author: IAC
    Date: 2026-02-27
    Requires: ExchangeOnlineManagement module v3+
    Role: Compliance Administrator or Information Protection Administrator
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [string]$AdminEmail,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Build admin email from domain if not provided
if (-not $AdminEmail) {
    $AdminEmail = "admin@$TenantDomain"
}

Import-Module ExchangeOnlineManagement -ErrorAction Stop

# ============================================================================
# CONNECT
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IAC Sensitivity Label Deployment" -ForegroundColor Cyan
Write-Host "  Purview Practitioner 4-Group Taxonomy" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow }
Write-Host "  Tenant Domain: $TenantDomain" -ForegroundColor Gray
Write-Host "  Admin Email:   $AdminEmail" -ForegroundColor Gray
Write-Host ""

try {
    Get-Label -ErrorAction Stop | Out-Null
    Write-Host "[OK] Already connected to Security & Compliance" -ForegroundColor Green
} catch {
    Write-Host "[..] Connecting to Security & Compliance PowerShell..." -ForegroundColor Yellow
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "[OK] Connected" -ForegroundColor Green
}

# ============================================================================
# HELPERS
# ============================================================================
function Get-LabelByDisplayName {
    param([Parameter(Mandatory)] [string]$DisplayName)
    Get-Label -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $DisplayName } |
        Select-Object -First 1
}

function Ensure-Label {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$DisplayName,
        [Parameter(Mandatory)] [string]$Tooltip,
        [string]$Comment,
        [string]$ParentImmutableId,

        # Scoping - parent labels can protect containers
        [string[]]$ContentType,

        # Content markings
        [string]$HeaderText,
        [string]$FooterText,
        [string]$WatermarkText,

        # Encryption
        [bool]$EncryptionEnabled = $false,
        [ValidateSet("Template", "UserDefined", "RemoveProtection")]
        [string]$EncryptionProtectionType,
        [bool]$EncryptionPromptUser = $false,
        [bool]$EncryptionEncryptOnly = $false,
        [bool]$EncryptionDoNotForward = $false,
        [string]$EncryptionRightsDefinitions
    )

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        Write-Error "DisplayName cannot be empty."
        return $null
    }

    $existing = Get-LabelByDisplayName -DisplayName $DisplayName
    if ($existing) {
        Write-Host "  [EXISTS] $DisplayName" -ForegroundColor Gray
        return $existing
    }

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create: $DisplayName" -ForegroundColor Yellow
        return @{ ImmutableId = "DRYRUN-$Name"; DisplayName = $DisplayName }
    }

    $params = @{
        Name        = $Name
        DisplayName = $DisplayName
        Tooltip     = $Tooltip
    }

    if ($Comment)     { $params["Comment"] = $Comment }
    if ($ContentType) { $params["ContentType"] = $ContentType }
    if ($ParentImmutableId) {
        if ([string]::IsNullOrWhiteSpace($ParentImmutableId)) {
            Write-Error "ParentImmutableId is empty for $DisplayName. Parent label may have failed."
            return $null
        }
        $params["ParentId"] = $ParentImmutableId
    }

    # Content markings
    if ($HeaderText) {
        $params["ApplyContentMarkingHeaderEnabled"]   = $true
        $params["ApplyContentMarkingHeaderText"]      = $HeaderText
        $params["ApplyContentMarkingHeaderFontSize"]  = 10
        $params["ApplyContentMarkingHeaderFontColor"] = "#FF0000"
        $params["ApplyContentMarkingHeaderAlignment"] = "Center"
    }
    if ($FooterText) {
        $params["ApplyContentMarkingFooterEnabled"]   = $true
        $params["ApplyContentMarkingFooterText"]      = $FooterText
        $params["ApplyContentMarkingFooterFontSize"]  = 8
        $params["ApplyContentMarkingFooterFontColor"] = "#FF0000"
        $params["ApplyContentMarkingFooterAlignment"] = "Center"
    }
    if ($WatermarkText) {
        $params["ApplyWaterMarkingEnabled"]  = $true
        $params["ApplyWaterMarkingText"]     = $WatermarkText
        $params["ApplyWaterMarkingFontSize"] = 48
        $params["ApplyWaterMarkingLayout"]   = "Diagonal"
    }

    # Encryption
    if ($EncryptionEnabled) {
        $params["EncryptionEnabled"] = $true
        if ($EncryptionProtectionType) {
            $params["EncryptionProtectionType"] = $EncryptionProtectionType
        }
        if ($EncryptionProtectionType -eq "UserDefined") {
            $params["EncryptionPromptUser"] = [bool]$EncryptionPromptUser
        }
        if ($EncryptionProtectionType -eq "Template" -and $EncryptionRightsDefinitions) {
            $params["EncryptionRightsDefinitions"] = $EncryptionRightsDefinitions
        }
        if ($EncryptionEncryptOnly)  { $params["EncryptionEncryptOnly"]  = $true }
        if ($EncryptionDoNotForward) { $params["EncryptionDoNotForward"] = $true }
    }

    Write-Host "  [CREATING] $DisplayName" -ForegroundColor Green
    $result = New-Label @params
    Start-Sleep -Seconds 2  # Allow Purview to propagate
    return $result
}

# ============================================================================
# BUILD ENCRYPTION RIGHTS
# ============================================================================
# Template-encrypted labels: org gets Co-Author, admin gets Owner
$orgWideRights = "$($TenantDomain):VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL"
$adminRights   = "$($AdminEmail):OWNER"

Write-Host ""
Write-Host "--- Creating Labels ---" -ForegroundColor Magenta
Write-Host ""

# ============================================================================
# 1. PUBLIC - No protection, safe for external sharing
# ============================================================================
Write-Host "[1/4] Public" -ForegroundColor Cyan
$public = Ensure-Label `
    -Name "Public" `
    -DisplayName "Public" `
    -Tooltip "No protection required. Safe to share externally." `
    -Comment "Information intended for public consumption. No restrictions." `
    -ContentType @("File", "Email", "Site", "UnifiedGroup")

# ============================================================================
# 2. GENERAL - Default label, light markings, no encryption
# ============================================================================
Write-Host "[2/4] General" -ForegroundColor Cyan
$general = Ensure-Label `
    -Name "General" `
    -DisplayName "General" `
    -Tooltip "Default label for everyday business content." `
    -Comment "Business data not intended for public consumption." `
    -ContentType @("File", "Email", "Site", "UnifiedGroup") `
    -HeaderText "General" `
    -FooterText "General - Business Use"

# ============================================================================
# 3. CONFIDENTIAL - Parent container only (no encryption, no markings)
#    Scoped to Groups & Sites so it can protect Teams/SPO containers
# ============================================================================
Write-Host "[3/4] Confidential" -ForegroundColor Cyan
$confidential = Ensure-Label `
    -Name "Confidential" `
    -DisplayName "Confidential" `
    -Tooltip "Select a sub-label. Encryption and markings applied based on audience." `
    -Comment "Sensitive business data. Select the appropriate sub-label." `
    -ContentType @("Site", "UnifiedGroup")

# 3.1 Confidential / Internal - Encrypted to entire org
Write-Host "  +-- Confidential - Internal" -ForegroundColor Cyan
$confInternal = Ensure-Label `
    -Name "Confidential-Internal" `
    -DisplayName "Confidential - Internal" `
    -Tooltip "Encrypted for internal employees only. Content cannot leave the organisation unprotected." `
    -Comment "Confidential content encrypted for all internal users." `
    -ParentImmutableId $confidential.ImmutableId `
    -ContentType @("File", "Email", "Site", "UnifiedGroup") `
    -HeaderText "Confidential - Internal Only" `
    -FooterText "Confidential - Internal Only" `
    -EncryptionEnabled $true `
    -EncryptionProtectionType "Template" `
    -EncryptionRightsDefinitions $orgWideRights

# 3.2 Confidential / Third Parties - User picks recipients
Write-Host "  +-- Confidential - Third Parties" -ForegroundColor Cyan
$confThird = Ensure-Label `
    -Name "Confidential-ThirdParties" `
    -DisplayName "Confidential - Third Parties" `
    -Tooltip "User selects authorised external recipients at time of sharing." `
    -Comment "Confidential content shared with named external recipients." `
    -ParentImmutableId $confidential.ImmutableId `
    -ContentType @("File", "Email", "Site", "UnifiedGroup") `
    -HeaderText "Confidential - Authorised Recipients" `
    -FooterText "Confidential - Authorised Recipients" `
    -EncryptionEnabled $true `
    -EncryptionProtectionType "UserDefined" `
    -EncryptionPromptUser $true `
    -EncryptionDoNotForward $true

# 3.3 Confidential / Reporting - Encrypted to entire org
Write-Host "  +-- Confidential - Reporting" -ForegroundColor Cyan
$confReporting = Ensure-Label `
    -Name "Confidential-Reporting" `
    -DisplayName "Confidential - Reporting" `
    -Tooltip "Confidential reports and analytics. Encrypted for internal use." `
    -Comment "Reports, dashboards, and analytics - internal only." `
    -ParentImmutableId $confidential.ImmutableId `
    -ContentType @("File", "Email", "Site", "UnifiedGroup") `
    -HeaderText "Confidential - Reporting" `
    -FooterText "Confidential - Reporting" `
    -EncryptionEnabled $true `
    -EncryptionProtectionType "Template" `
    -EncryptionRightsDefinitions $orgWideRights

# ============================================================================
# 4. RESTRICTED - Parent container only (no encryption, no markings)
#    Scoped to Groups & Sites so it can protect Teams/SPO containers
# ============================================================================
Write-Host "[4/4] Restricted" -ForegroundColor Cyan
$restricted = Ensure-Label `
    -Name "Restricted" `
    -DisplayName "Restricted" `
    -Tooltip "Select a sub-label. Highest protection - full encryption and markings." `
    -Comment "Highly sensitive data. Significant business impact if leaked." `
    -ContentType @("Site", "UnifiedGroup")

# 4.1 Restricted / Internal - Template-encrypted to admin/named group only
Write-Host "  +-- Restricted - Internal" -ForegroundColor Cyan
$restInternal = Ensure-Label `
    -Name "Restricted-Internal" `
    -DisplayName "Restricted - Internal" `
    -Tooltip "Encrypted for specific internal recipients only." `
    -Comment "Restricted content - admin-controlled access only." `
    -ParentImmutableId $restricted.ImmutableId `
    -ContentType @("File", "Email", "Site", "UnifiedGroup") `
    -HeaderText "RESTRICTED - Internal Only" `
    -FooterText "RESTRICTED - Internal Only" `
    -WatermarkText "RESTRICTED" `
    -EncryptionEnabled $true `
    -EncryptionProtectionType "Template" `
    -EncryptionRightsDefinitions $adminRights

# 4.2 Restricted / Third Parties - User picks recipients
Write-Host "  +-- Restricted - Third Parties" -ForegroundColor Cyan
$restThird = Ensure-Label `
    -Name "Restricted-ThirdParties" `
    -DisplayName "Restricted - Third Parties" `
    -Tooltip "User selects authorised recipients. Do Not Forward enforced." `
    -Comment "Restricted content shared with named external recipients." `
    -ParentImmutableId $restricted.ImmutableId `
    -ContentType @("File", "Email", "Site", "UnifiedGroup") `
    -HeaderText "RESTRICTED - Authorised Recipients" `
    -FooterText "RESTRICTED - Authorised Recipients" `
    -WatermarkText "RESTRICTED" `
    -EncryptionEnabled $true `
    -EncryptionProtectionType "UserDefined" `
    -EncryptionPromptUser $true `
    -EncryptionDoNotForward $true

# ============================================================================
# NEXT STEP: Publish labels using the separate publishing script
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  Labels created. To publish, run:" -ForegroundColor Yellow
Write-Host "  .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain `"$TenantDomain`"" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Labels:" -ForegroundColor White
Write-Host "    Public                          - No protection" -ForegroundColor White
Write-Host "    General                         - Header/footer, no encryption" -ForegroundColor White
Write-Host "    Confidential (container)        - Groups & Sites scope" -ForegroundColor White
Write-Host "      +- Internal                   - Encrypted (org-wide)" -ForegroundColor White
Write-Host "      +- Third Parties              - Encrypted (user-defined)" -ForegroundColor White
Write-Host "      +- Reporting                  - Encrypted (org-wide)" -ForegroundColor White
Write-Host "    Restricted (container)          - Groups & Sites scope" -ForegroundColor White
Write-Host "      +- Internal                   - Encrypted (admin template)" -ForegroundColor White
Write-Host "      +- Third Parties              - Encrypted (user-defined)" -ForegroundColor White
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Label Creation Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

# Do NOT auto-disconnect - user may want to verify or publish
Write-Host ""
Write-Host "  To verify labels:  Get-Label | Sort-Object Priority | FT DisplayName, Priority, EncryptionEnabled, ContentType" -ForegroundColor Gray
Write-Host "  To publish:        .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain `"$TenantDomain`"" -ForegroundColor Gray
Write-Host "  To disconnect:     Disconnect-ExchangeOnline -Confirm:`$false" -ForegroundColor Gray
Write-Host ""

