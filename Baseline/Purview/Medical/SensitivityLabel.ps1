<#
.SYNOPSIS
    Creates IAC sensitivity labels (does NOT publish — use Publish-SensitivityLabelPolicies.ps1).

.DESCRIPTION
    Implements the Purview Practitioner 5-group taxonomy (Personal, Public, General, Confidential, Restricted)
    with best-practice encryption, content markings, container scoping, and Teams Meetings scope.

    Labels:
        Personal          - Non-business content, no protection (File, Email only)
        Public            - No protection, external-safe
        General           - Default label, header/footer only
        Confidential (parent) - Group container (Groups & Sites scope)
            |- Confidential - Internal      - Encrypted (org-wide), markings, meetings
            |- Confidential - Third Parties - Encrypted (user-defined recipients), markings, meetings
            +- Confidential - Reporting     - Encrypted (org-wide), markings
        Restricted (parent) - Group container (Groups & Sites scope)
            |- Restricted - Internal        - Encrypted (admin-only template), markings, watermark, meetings
            +- Restricted - Third Parties   - Encrypted (user-defined recipients), markings, watermark, meetings

    CHANGES FROM PREVIOUS VERSION:
        - Removed "Inforcer-" prefix from all internal label Names
        - Added optional -LabelPrefix parameter for multi-tenant deployments
        - Added Personal label (File + Email scope only; no Site/Group/Meetings)
        - Added TeamsMeeting to ContentType on appropriate labels (not Personal, Public, Reporting, or parents)
        - Policy names updated: "IAC - *" → generic names, or prefixed if -LabelPrefix supplied

    After running this script, publish labels using:
        .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain "contoso.onmicrosoft.com"

    Reference:
        https://www.thepurviewpractitioner.com/tools/taxonomy
        https://learn.microsoft.com/purview/sensitivity-labels
        https://learn.microsoft.com/en-us/purview/default-sensitivity-labels-policies

.PARAMETER TenantDomain
    Your tenant's primary domain (e.g., contoso.onmicrosoft.com). Used to build
    encryption rights definitions for Template-encrypted labels.

.PARAMETER AdminEmail
    Admin or security group email for Restricted-Internal encryption rights.
    STRONGLY RECOMMENDED: use a mail-enabled security group, not an individual UPN.
    Defaults to admin@<TenantDomain>.

.PARAMETER LabelPrefix
    Optional short prefix for internal label Names (e.g., "Contoso").
    Produces names like "Contoso-Public", "Contoso-Confidential-Internal".
    Use this in multi-tenant MSP deployments to namespace labels per customer.
    If omitted, no prefix is applied (e.g., "Public", "Confidential-Internal").

.PARAMETER DryRun
    If specified, shows what would be created without making changes.

.EXAMPLE
    # Single-tenant (no prefix)
    .\SensitivityLabel.ps1 -TenantDomain "contoso.onmicrosoft.com"

    # Multi-tenant MSP deployment (prefixed)
    .\SensitivityLabel.ps1 -TenantDomain "contoso.onmicrosoft.com" -LabelPrefix "Contoso"

    # Dry run
    .\SensitivityLabel.ps1 -TenantDomain "contoso.onmicrosoft.com" -DryRun

.NOTES
    Author:   IAC
    Updated:  2026-06-24
    Requires: ExchangeOnlineManagement module v3+
    Role:     Compliance Administrator or Information Protection Administrator
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $false)]
    [string]$AdminEmail,

    [Parameter(Mandatory = $false)]
    [string]$LabelPrefix = "",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

# ============================================================================
# MODULE VERSION CHECK
# ============================================================================
$exoVersion = (Get-Module ExchangeOnlineManagement).Version
if ($exoVersion -lt [Version]"3.0.0") {
    Write-Host "[WARN] ExchangeOnlineManagement v$exoVersion detected. v3.0.0+ required." -ForegroundColor Yellow
    Write-Host "[..] Updating module now..." -ForegroundColor Yellow
    Update-Module ExchangeOnlineManagement -Force -ErrorAction Stop
    Write-Host "[OK] Module updated. Please restart this script in a fresh PowerShell session." -ForegroundColor Green
    exit 1
} else {
    Write-Host "[OK] ExchangeOnlineManagement v$exoVersion" -ForegroundColor Green
}

# ============================================================================
# HELPER: Build label internal Name with optional prefix
# ============================================================================
function Get-LabelName {
    param([Parameter(Mandatory)][string]$BaseName)
    if ([string]::IsNullOrWhiteSpace($LabelPrefix)) {
        return $BaseName
    }
    return "$LabelPrefix-$BaseName"
}

# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  IAC Sensitivity Label Deployment" -ForegroundColor Cyan
Write-Host "  Purview Practitioner 5-Group Taxonomy" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
if ($DryRun) { Write-Host "  DRY RUN MODE - No changes will be made" -ForegroundColor Yellow }
Write-Host "  Tenant Domain : $(if ($TenantDomain) { $TenantDomain } else { '(auto-detect after sign-in)' })" -ForegroundColor Gray
Write-Host "  Admin Email   : $(if ($AdminEmail) { $AdminEmail } else { '(auto-detect after sign-in)' })" -ForegroundColor Gray
Write-Host "  Label Prefix  : $(if ($LabelPrefix) { $LabelPrefix } else { '(none)' })" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# CONNECT
# ============================================================================
try {
    Get-Label -ErrorAction Stop | Out-Null
    Write-Host "[OK] Already connected to Security & Compliance" -ForegroundColor Green
} catch {
    Write-Host "[..] Connecting to Security & Compliance PowerShell (browser sign-in)..." -ForegroundColor Yellow
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "[OK] Connected" -ForegroundColor Green
}

# Auto-detect signed-in account
$connectedUser = (Get-ConnectionInformation | Select-Object -First 1).UserPrincipalName
if (-not $AdminEmail) {
    $AdminEmail = $connectedUser
    Write-Host "[OK] AdminEmail set to signed-in account: $AdminEmail" -ForegroundColor Green
}
if (-not $TenantDomain) {
    $TenantDomain = $AdminEmail.Split('@')[1]
    Write-Host "[OK] TenantDomain derived from account: $TenantDomain" -ForegroundColor Green
}

# Validate AdminEmail is not an individual UPN — warn if it looks like one
if ($AdminEmail -notmatch "^SG-|^sg-|group|Group") {
    Write-Host "" -ForegroundColor Yellow
    Write-Host "[WARN] AdminEmail '$AdminEmail' appears to be an individual UPN." -ForegroundColor Yellow
    Write-Host "[WARN] For Restricted - Internal encryption, use a mail-enabled security group" -ForegroundColor Yellow
    Write-Host "[WARN] (e.g. SG-Restricted-Owners@$TenantDomain) to avoid single-point-of-failure." -ForegroundColor Yellow
    Write-Host "[WARN] If this account is deleted, all Restricted - Internal content becomes inaccessible." -ForegroundColor Yellow
    Write-Host ""
}

# Cache existing labels
Write-Host "[..] Fetching existing labels..." -ForegroundColor Yellow
$script:LabelCache = @(Get-Label -ErrorAction SilentlyContinue | Where-Object { $_.Mode -ne 'PendingDeletion' })
Write-Host "[OK] Found $($script:LabelCache.Count) existing label(s) (PendingDeletion excluded)" -ForegroundColor Green

# ============================================================================
# HELPERS
# ============================================================================
function Get-LabelByDisplayName {
    param([Parameter(Mandatory)][string]$DisplayName)
    $script:LabelCache | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
}

function Ensure-Label {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$Tooltip,
        [string]$Comment,
        [string]$ParentImmutableId,
        [switch]$IsParentLabel,
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
            Write-Host "  [ERROR] '$DisplayName' exists but is NOT a label group." -ForegroundColor Red
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
    if ($Comment)      { $params["Comment"]     = $Comment }
    if ($ContentType)  { $params["ContentType"] = $ContentType }
    if ($ParentImmutableId) {
        if ([string]::IsNullOrWhiteSpace($ParentImmutableId)) {
            Write-Error "ParentImmutableId is empty for $DisplayName."
            return $null
        }
        $params["ParentId"] = $ParentImmutableId
    }

    # Content markings
    if ($HeaderText) {
        $params["ApplyContentMarkingHeaderEnabled"]    = $true
        $params["ApplyContentMarkingHeaderText"]       = $HeaderText
        $params["ApplyContentMarkingHeaderFontSize"]   = 10
        $params["ApplyContentMarkingHeaderFontColor"]  = "#FF0000"
        $params["ApplyContentMarkingHeaderAlignment"]  = "Center"
    }
    if ($FooterText) {
        $params["ApplyContentMarkingFooterEnabled"]    = $true
        $params["ApplyContentMarkingFooterText"]       = $FooterText
        $params["ApplyContentMarkingFooterFontSize"]   = 8
        $params["ApplyContentMarkingFooterFontColor"]  = "#FF0000"
        $params["ApplyContentMarkingFooterAlignment"]  = "Center"
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
        if ($EncryptionProtectionType)   { $params["EncryptionProtectionType"]   = $EncryptionProtectionType }
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
        if ($IsParentLabel) {
            try {
                $params["IsLabelGroup"] = $true
                $params.Remove("ContentType") | Out-Null  # parent labels don't take ContentType
                $result = New-Label @params
            } catch {
                if ($_.Exception.Message -like '*IsLabelGroup*' -or $_.Exception.Message -like '*not recognized*') {
                    Write-Host "  [ERROR] IsLabelGroup not supported by module v$exoVersion. Update and restart." -ForegroundColor Red
                    return $null
                }
                Write-Host "  [ERROR] Failed to create label group '$DisplayName': $_" -ForegroundColor Red
                return $null
            }

            # Validate group was created correctly
            Start-Sleep -Seconds 3
            $check = Get-Label -Identity $result.ImmutableId
            if (-not $check.IsLabelGroup) {
                Write-Host "  [ERROR] '$DisplayName' created but IsLabelGroup=False. Delete and recreate via Purview portal." -ForegroundColor Red
                $script:LabelCache += $result
                return $null
            }
            Write-Host "  [OK] '$DisplayName' created as label group (IsLabelGroup=True)" -ForegroundColor Green
        } else {
            $result = New-Label @params
        }

        $script:LabelCache += $result
        Start-Sleep -Seconds 2
        return $result

    } catch {
        if ($_.Exception.Message -like '*already exists*') {
            Write-Host "  [EXISTS - RECOVERED] $DisplayName already in Purview, fetching..." -ForegroundColor Yellow
            $result = Get-Label | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
            if ($result) {
                $script:LabelCache += $result
                return $result
            }
            Write-Host "  [WARN] Could not retrieve existing label '$DisplayName'" -ForegroundColor Red
            return $null
        } else {
            Write-Host "  [ERROR] Failed to create '$DisplayName': $_" -ForegroundColor Red
            return $null
        }
    }
}

# ============================================================================
# BUILD ENCRYPTION RIGHTS
# ============================================================================
# Template-encrypted labels: org-wide Co-Author rights
$orgWideRights = "$($TenantDomain):VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL"

# Restricted-Internal: should be a MESG, not an individual UPN
# Replace $AdminEmail with SG-Restricted-Owners@domain.com before production deployment
$adminRights = "$($AdminEmail):OWNER"

Write-Host ""
Write-Host "--- Creating Labels ---" -ForegroundColor Magenta
Write-Host ""

# ============================================================================
# MEETINGS SCOPE NOTE
# ============================================================================
# TeamsMeeting scope requires Teams Premium licensing to enforce meeting-level
# sensitivity label controls (watermarks, lobby settings, etc.).
# Labels that include "TeamsMeeting" will still appear in Office apps and
# Outlook calendar on tenants without Teams Premium, but meeting-specific
# settings (if configured) will not be enforced.
#
# Meetings scope is intentionally EXCLUDED from:
#   - Personal   : Non-business content should not label org meetings
#   - Public     : Public webinars rarely need sensitivity label controls
#   - Reporting  : Report-specific label; doesn't map to meeting context
#   - Parent containers (Confidential, Restricted): container-only labels

# ============================================================================
# 1. PERSONAL - Non-business content, no protection
#    Scope: File + Email ONLY (no Site, UnifiedGroup, TeamsMeeting)
#    Rationale: Personal content should not be applied to org containers or meetings.
#    This label sits above Public in priority order (lowest = least sensitive).
# ============================================================================
Write-Host "[1/5] Personal" -ForegroundColor Cyan
$personal = Ensure-Label `
    -Name        (Get-LabelName "Personal") `
    -DisplayName "Personal" `
    -Tooltip     "Non-business personal content. Not subject to corporate retention or DLP policies." `
    -Comment     "Personal or non-business data. No protection, classification, or markings applied." `
    -ContentType @("File", "Email")

# ============================================================================
# 2. PUBLIC - No protection, safe for external sharing
# ============================================================================
Write-Host "[2/5] Public" -ForegroundColor Cyan
$public = Ensure-Label `
    -Name        (Get-LabelName "Public") `
    -DisplayName "Public" `
    -Tooltip     "No protection required. Safe to share externally." `
    -Comment     "Information intended for public consumption. No restrictions." `
    -ContentType @("File", "Email", "Site", "UnifiedGroup")

# ============================================================================
# 3. GENERAL - Default label, light markings, no encryption
# ============================================================================
Write-Host "[3/5] General" -ForegroundColor Cyan
$general = Ensure-Label `
    -Name        (Get-LabelName "General") `
    -DisplayName "General" `
    -Tooltip     "Default label for everyday business content." `
    -Comment     "Business data not intended for public consumption." `
    -ContentType @("File", "Email", "Site", "UnifiedGroup", "TeamsMeeting") `
    -HeaderText  "General" `
    -FooterText  "General - Business Use"

# ============================================================================
# 4. CONFIDENTIAL - Parent container only
#    Scope: Groups & Sites (no file/email/meetings — children handle those)
#    Container: Private, guests allowed
# ============================================================================
Write-Host "[4/5] Confidential" -ForegroundColor Cyan
$confidential = Ensure-Label `
    -Name          (Get-LabelName "Confidential") `
    -DisplayName   "Confidential" `
    -Tooltip       "Select a sub-label. Encryption and markings applied based on audience." `
    -Comment       "Sensitive business data. Select the appropriate sub-label." `
    -ContentType   @("Site", "UnifiedGroup") `
    -IsParentLabel

# 4.1 Confidential / Internal
# Encrypted org-wide. Meetings scope ON — strategy, planning, and internal review calls.
Write-Host "  +-- Confidential - Internal" -ForegroundColor Cyan
$confInternal = Ensure-Label `
    -Name                        (Get-LabelName "Confidential-Internal") `
    -DisplayName                 "Confidential - Internal" `
    -Tooltip                     "Encrypted for internal employees only. Content cannot leave the organisation unprotected." `
    -Comment                     "Confidential content encrypted for all internal users." `
    -ParentImmutableId           $confidential.ImmutableId `
    -ContentType                 @("File", "Email", "Site", "UnifiedGroup", "TeamsMeeting") `
    -HeaderText                  "Confidential - Internal Only" `
    -FooterText                  "Confidential - Internal Only" `
    -EncryptionEnabled           $true `
    -EncryptionProtectionType    "Template" `
    -EncryptionRightsDefinitions $orgWideRights

# 4.2 Confidential / Third Parties
# User-defined recipients + Do Not Forward. Meetings scope ON — vendor/partner calls.
Write-Host "  +-- Confidential - Third Parties" -ForegroundColor Cyan
$confThird = Ensure-Label `
    -Name                     (Get-LabelName "Confidential-ThirdParties") `
    -DisplayName              "Confidential - Third Parties" `
    -Tooltip                  "User selects authorised external recipients at time of sharing." `
    -Comment                  "Confidential content shared with named external recipients." `
    -ParentImmutableId        $confidential.ImmutableId `
    -ContentType              @("File", "Email", "Site", "UnifiedGroup", "TeamsMeeting") `
    -HeaderText               "Confidential - Authorised Recipients" `
    -FooterText               "Confidential - Authorised Recipients" `
    -EncryptionEnabled        $true `
    -EncryptionProtectionType "UserDefined" `
    -EncryptionPromptUser     $true `
    -EncryptionDoNotForward   $true

# 4.3 Confidential / Reporting
# Encrypted org-wide. Meetings scope OFF — reports don't map naturally to meeting context.
# Separate label enables independent Activity Explorer reporting on financial/analytical content.
Write-Host "  +-- Confidential - Reporting" -ForegroundColor Cyan
$confReporting = Ensure-Label `
    -Name                        (Get-LabelName "Confidential-Reporting") `
    -DisplayName                 "Confidential - Reporting" `
    -Tooltip                     "Confidential reports and analytics. Encrypted for internal use." `
    -Comment                     "Reports, dashboards, and analytics - internal only." `
    -ParentImmutableId           $confidential.ImmutableId `
    -ContentType                 @("File", "Email", "Site", "UnifiedGroup") `
    -HeaderText                  "Confidential - Reporting" `
    -FooterText                  "Confidential - Reporting" `
    -EncryptionEnabled           $true `
    -EncryptionProtectionType    "Template" `
    -EncryptionRightsDefinitions $orgWideRights

# ============================================================================
# 5. RESTRICTED - Parent container only
#    Scope: Groups & Sites (children handle file/email/meetings)
#    Container: Private, guests BLOCKED
# ============================================================================
Write-Host "[5/5] Restricted" -ForegroundColor Cyan
$restricted = Ensure-Label `
    -Name          (Get-LabelName "Restricted") `
    -DisplayName   "Restricted" `
    -Tooltip       "Select a sub-label. Highest protection - full encryption and markings." `
    -Comment       "Highly sensitive data. Significant business impact if leaked." `
    -ContentType   @("Site", "UnifiedGroup") `
    -IsParentLabel

# 5.1 Restricted / Internal
# Admin/security group template. Meetings scope ON — board, exec, and HR-sensitive calls.
# IMPORTANT: Replace $AdminEmail with a mail-enabled security group before production deployment.
# Single UPN here = single point of failure for all Restricted - Internal documents.
Write-Host "  +-- Restricted - Internal" -ForegroundColor Cyan
$restInternal = Ensure-Label `
    -Name                        (Get-LabelName "Restricted-Internal") `
    -DisplayName                 "Restricted - Internal" `
    -Tooltip                     "Encrypted for specific internal recipients only." `
    -Comment                     "Restricted content - admin-controlled access only. Use a security group for $adminRights." `
    -ParentImmutableId           $restricted.ImmutableId `
    -ContentType                 @("File", "Email", "Site", "UnifiedGroup", "TeamsMeeting") `
    -HeaderText                  "RESTRICTED - Internal Only" `
    -FooterText                  "RESTRICTED - Internal Only" `
    -WatermarkText               "RESTRICTED" `
    -EncryptionEnabled           $true `
    -EncryptionProtectionType    "Template" `
    -EncryptionRightsDefinitions $adminRights

# 5.2 Restricted / Third Parties
# User-defined + Do Not Forward. Meetings scope ON — legal, M&A, regulatory calls.
Write-Host "  +-- Restricted - Third Parties" -ForegroundColor Cyan
$restThird = Ensure-Label `
    -Name                     (Get-LabelName "Restricted-ThirdParties") `
    -DisplayName              "Restricted - Third Parties" `
    -Tooltip                  "User selects authorised recipients. Do Not Forward enforced." `
    -Comment                  "Restricted content shared with named external recipients." `
    -ParentImmutableId        $restricted.ImmutableId `
    -ContentType              @("File", "Email", "Site", "UnifiedGroup", "TeamsMeeting") `
    -HeaderText               "RESTRICTED - Authorised Recipients" `
    -FooterText               "RESTRICTED - Authorised Recipients" `
    -WatermarkText            "RESTRICTED" `
    -EncryptionEnabled        $true `
    -EncryptionProtectionType "UserDefined" `
    -EncryptionPromptUser     $true `
    -EncryptionDoNotForward   $true

# ============================================================================
# NEXT STEP
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "  Labels created. To publish, run:" -ForegroundColor Yellow
$domainArg = if ($TenantDomain) { "`"$TenantDomain`"" } else { "`"<your-tenant>.onmicrosoft.com`"" }
$prefixArg = if ($LabelPrefix)  { " -LabelPrefix `"$LabelPrefix`"" } else { "" }
Write-Host "  .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain $domainArg$prefixArg" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Deployment Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Label Prefix   : $(if ($LabelPrefix) { $LabelPrefix } else { '(none)' })" -ForegroundColor Gray
Write-Host "  Tenant Domain  : $TenantDomain" -ForegroundColor Gray
Write-Host "  Admin Rights   : $AdminEmail" -ForegroundColor Gray
Write-Host ""
Write-Host "  Labels:" -ForegroundColor White
Write-Host "    Personal                  - No protection (File + Email only)" -ForegroundColor White
Write-Host "    Public                    - No protection" -ForegroundColor White
Write-Host "    General                   - Header/footer + Meetings" -ForegroundColor White
Write-Host "    Confidential (container)  - Groups & Sites scope" -ForegroundColor White
Write-Host "      +- Internal             - Encrypted (org-wide) + Meetings" -ForegroundColor White
Write-Host "      +- Third Parties        - Encrypted (user-defined) + Meetings" -ForegroundColor White
Write-Host "      +- Reporting            - Encrypted (org-wide), no Meetings" -ForegroundColor White
Write-Host "    Restricted (container)    - Groups & Sites scope, guests blocked" -ForegroundColor White
Write-Host "      +- Internal             - Encrypted (admin template) + Meetings" -ForegroundColor White
Write-Host "      +- Third Parties        - Encrypted (user-defined) + Meetings" -ForegroundColor White
Write-Host ""
Write-Host "  Priority order (lowest = least sensitive):" -ForegroundColor Gray
Write-Host "    Personal → Public → General → Confidential children → Restricted children" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Label Creation Complete" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Verify labels  : Get-Label | Sort-Object Priority | FT DisplayName, Priority, EncryptionEnabled, ContentType" -ForegroundColor Gray
Write-Host "  Check parents  : (Get-Label -Identity 'Confidential').LabelActions" -ForegroundColor Gray
Write-Host "  Check parents  : (Get-Label -Identity 'Restricted').LabelActions" -ForegroundColor Gray
Write-Host "  Publish        : .\Publish-SensitivityLabelPolicies.ps1 -TenantDomain `"$TenantDomain`"$prefixArg" -ForegroundColor Gray
Write-Host "  Disconnect     : Disconnect-ExchangeOnline -Confirm:`$false" -ForegroundColor Gray
Write-Host ""
