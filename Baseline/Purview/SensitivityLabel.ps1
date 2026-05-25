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
      https://learn.microsoft.com/en-us/purview/default-sensitivity-labels-policies

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
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [string]$AdminEmail,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

# ============================================================================
# MODULE VERSION CHECK - Modern label scheme requires v3.7+ for IsParentLabel
# ============================================================================
$exoVersion = (Get-Module ExchangeOnlineManagement).Version
if ($exoVersion -lt [Version]"3.0.0") {
    Write-Host "[WARN] ExchangeOnlineManagement v$exoVersion detected. v3.0.0+ required for modern label scheme." -ForegroundColor Yellow
    Write-Host "[..] Updating module now..." -ForegroundColor Yellow
    Update-Module ExchangeOnlineManagement -Force -ErrorAction Stop
    Write-Host "[OK] Module updated. Please restart this script in a fresh PowerShell session." -ForegroundColor Green
    exit 1
} else {
    Write-Host "[OK] ExchangeOnlineManagement v$exoVersion" -ForegroundColor Green
}
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IAC Sensitivity Label Deployment" -ForegroundColor Cyan
Write-Host "  Purview Practitioner 4-Group Taxonomy" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow }
Write-Host "  Tenant Domain: $(if ($TenantDomain) { $TenantDomain } else { '(auto-detect after sign-in)' })" -ForegroundColor Gray
Write-Host "  Admin Email:   $(if ($AdminEmail) { $AdminEmail } else { '(auto-detect after sign-in)' })" -ForegroundColor Gray
Write-Host ""

try {
    Get-Label -ErrorAction Stop | Out-Null
    Write-Host "[OK] Already connected to Security & Compliance" -ForegroundColor Green
} catch {
    Write-Host "[..] Connecting to Security & Compliance PowerShell (browser sign-in)..." -ForegroundColor Yellow
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "[OK] Connected" -ForegroundColor Green
}

# Auto-detect signed-in account and derive domain/email if not supplied
$connectedUser = (Get-ConnectionInformation | Select-Object -First 1).UserPrincipalName
if (-not $AdminEmail) {
    $AdminEmail = $connectedUser
    Write-Host "[OK] AdminEmail set to signed-in account: $AdminEmail" -ForegroundColor Green
}
if (-not $TenantDomain) {
    $TenantDomain = $AdminEmail.Split('@')[1]
    Write-Host "[OK] TenantDomain derived from account: $TenantDomain" -ForegroundColor Green
}

# Cache all existing labels once to avoid repeated Get-Label calls
Write-Host "[..] Fetching existing labels..." -ForegroundColor Yellow
$script:LabelCache = @(Get-Label -ErrorAction SilentlyContinue | Where-Object { $_.Mode -ne 'PendingDeletion' })
Write-Host "[OK] Found $($script:LabelCache.Count) existing label(s) (PendingDeletion excluded)" -ForegroundColor Green

# ============================================================================
# HELPERS
# ============================================================================
function Get-LabelByDisplayName {
    param([Parameter(Mandatory)] [string]$DisplayName)
    $script:LabelCache | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
}

function Ensure-Label {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$DisplayName,
        [Parameter(Mandatory)] [string]$Tooltip,
        [string]$Comment,
        [string]$ParentImmutableId,

        # Mark this label as a parent/group so sub-labels can be created under it
        [switch]$IsParentLabel,

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
        if ($IsParentLabel -and -not $existing.IsLabelGroup) {
            Write-Host "  [ERROR] '$DisplayName' exists but is NOT a label group. Cannot create sub-labels under it." -ForegroundColor Red
            Write-Host "  [ERROR] Delete this label and re-run, or create it as a Label Group via the Purview portal." -ForegroundColor Red
            return $null
        } else {
            Write-Host "  [EXISTS] $DisplayName" -ForegroundColor Gray
            return $existing
        }
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
    try {
        # For modern label scheme, IsParentLabel must be set at creation time
        if ($IsParentLabel) {
            try {
                $params["IsLabelGroup"] = $true
                # Label groups do not support ContentType parameter — remove it
                $params.Remove("ContentType") | Out-Null
                $result = New-Label @params
            } catch {
                if ($_.Exception.Message -like '*IsLabelGroup*' -or $_.Exception.Message -like '*not recognized*') {
                    Write-Host "  [ERROR] IsLabelGroup parameter not supported by this module version (v$exoVersion)." -ForegroundColor Red
                    Write-Host "  [ERROR] Run: Update-Module ExchangeOnlineManagement -Force  then restart PowerShell." -ForegroundColor Red
                    return $null
                }
                Write-Host "  [ERROR] Failed to create label group '$DisplayName': $_" -ForegroundColor Red
                return $null
            }
            # Validate the label group was actually created correctly
            Start-Sleep -Seconds 3
            $check = Get-Label -Identity $result.ImmutableId
            if (-not $check.IsLabelGroup) {
                Write-Host "  [ERROR] '$DisplayName' was created but IsLabelGroup=False. Sub-labels cannot be created under it." -ForegroundColor Red
                Write-Host "  [ERROR] Delete this label, then create it as a Label Group via the Purview portal." -ForegroundColor Red
                $script:LabelCache += $result
                return $null
            }
            Write-Host "  [OK] '$DisplayName' created as label group (IsLabelGroup=True)" -ForegroundColor Green
        } else {
            $result = New-Label @params
        }
        $script:LabelCache += $result   # keep cache current
        Start-Sleep -Seconds 2  # Allow Purview to propagate
        return $result
    } catch {
        if ($_.Exception.Message -like '*already exists*') {
            Write-Host "  [EXISTS - RECOVERED] $DisplayName already in Purview, fetching..." -ForegroundColor Yellow
            $result = Get-Label | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
            if ($result) {
                $script:LabelCache += $result
                return $result
            } else {
                Write-Host "  [WARN] Could not retrieve existing label '$DisplayName'" -ForegroundColor Red
                return $null
            }
        } else {
            Write-Host "  [ERROR] Failed to create '$DisplayName': $_" -ForegroundColor Red
            return $null
        }
    }
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
    -Name "Inforcer-Public" `
    -DisplayName "Public" `
    -Tooltip "No protection required. Safe to share externally." `
    -Comment "Information intended for public consumption. No restrictions." `
    -ContentType @("File", "Email", "Site", "UnifiedGroup")

# ============================================================================
# 2. GENERAL - Default label, light markings, no encryption
# ============================================================================
Write-Host "[2/4] General" -ForegroundColor Cyan
$general = Ensure-Label `
    -Name "Inforcer-General" `
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
    -Name "Inforcer-Confidential" `
    -DisplayName "Confidential" `
    -Tooltip "Select a sub-label. Encryption and markings applied based on audience." `
    -Comment "Sensitive business data. Select the appropriate sub-label." `
    -ContentType @("Site", "UnifiedGroup") `
    -IsParentLabel

# 3.1 Confidential / Internal - Encrypted to entire org
Write-Host "  +-- Confidential - Internal" -ForegroundColor Cyan
$confInternal = Ensure-Label `
    -Name "Inforcer-Confidential-Internal" `
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
    -Name "Inforcer-Confidential-ThirdParties" `
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
    -Name "Inforcer-Confidential-Reporting" `
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
    -Name "Inforcer-Restricted" `
    -DisplayName "Restricted" `
    -Tooltip "Select a sub-label. Highest protection - full encryption and markings." `
    -Comment "Highly sensitive data. Significant business impact if leaked." `
    -ContentType @("Site", "UnifiedGroup") `
    -IsParentLabel

# 4.1 Restricted / Internal - Template-encrypted to admin/named group only
Write-Host "  +-- Restricted - Internal" -ForegroundColor Cyan
$restInternal = Ensure-Label `
    -Name "Inforcer-Restricted-Internal" `
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
    -Name "Inforcer-Restricted-ThirdParties" `
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

