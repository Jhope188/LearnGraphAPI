#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Users

<#
.SYNOPSIS
    Creates the Purview Information Protection Super User group in Entra ID
    and configures the AIP Super User feature.

.DESCRIPTION
    Creates DG-Purview-AUG-Admin-AIPSuperUsers as a mail-enabled security group
    in Entra ID, following the M365 Group Naming Standard (Section 7.6 — Purview
    admin roles).

    The Purview Information Protection Super User feature grants members of this
    group the ability to decrypt ANY RMS/MIP-protected content in the tenant —
    regardless of who originally encrypted it, what rights template was used, or
    whether the original owner's account still exists.

    This is a CRITICAL data governance capability required for:
      - Recovering documents when the original encryptor's account is deleted or disabled
      - eDiscovery and legal hold content review
      - Label migration and bulk re-encryption at scale
      - Forensic and HR compliance content review
      - Recovering content encrypted under broken or deleted encryption templates

    ⚠️  For this label taxonomy specifically:
      The Restricted - Internal label encrypts content using $adminRights = "<AdminEmail>:OWNER".
      If that admin account is ever deleted or its UPN changes, every Restricted - Internal
      document becomes permanently inaccessible — unless a Super User group is configured.
      This script addresses that single-point-of-failure risk.

    What this script does:
      1. Creates DG-Purview-AUG-Admin-AIPSuperUsers (mail-enabled security group)
         — mail-enabled is required by Add-AipServiceSuperUserGroup
      2. Sets the signed-in user as group owner
      3. Installs and imports the AIPService module if needed
      4. Connects to the AIP Service
      5. Enables the Super User feature
      6. Assigns the group as the Super User group
      7. Disables the Super User feature (re-enable on demand only)

    The group assignment persists while the feature is disabled. Re-enable quickly
    when needed — the group does not need to be reassigned each time.

.PARAMETER TenantDomain
    Your *.onmicrosoft.com tenant domain (e.g. M365x93722695.onmicrosoft.com).
    Used to build the group's mail address for Add-AipServiceSuperUserGroup.

.PARAMETER WhatIf
    Run in preview mode — shows what would be created without making any changes.

.EXAMPLE
    .\New-AIPSuperUserGroup.ps1 -TenantDomain "M365x93722695.onmicrosoft.com"
    .\New-AIPSuperUserGroup.ps1 -TenantDomain "M365x93722695.onmicrosoft.com" -WhatIf

.NOTES
    Requires:     Microsoft.Graph.Groups, Microsoft.Graph.Users, AIPService
    Graph Scopes: Group.ReadWrite.All, User.Read
    AIP Role:     Global Administrator or Azure Information Protection Administrator

    IMPORTANT — Mail-enabled security group:
      Add-AipServiceSuperUserGroup requires a mail-enabled security group. This
      script creates the group with MailEnabled = $true and GroupTypes = @()
      (plain security group — NOT a Microsoft 365 group). Exchange Online must
      be provisioned in the tenant for the mail alias to resolve.

    IMPORTANT — Membership (after script runs):
      Add members manually in Entra ID. Approved roles only:
        ✅ Information Protection Administrator
        ✅ Legal / eDiscovery team lead
        ✅ CISO or Deputy CISO
        ❌ General helpdesk or IT admins — too broad, too risky

    IMPORTANT — Feature lifecycle:
      The feature is DISABLED after this script runs. Enable on demand:
        Connect-AipService
        Enable-AipServiceSuperUserFeature
      Disable after use:
        Disable-AipServiceSuperUserFeature

    IMPORTANT — Audit:
      All Super User decryption events are written to the AIP audit log and the
      Microsoft Purview unified audit log. Review quarterly.

    Idempotent: safe to re-run. If the group already exists the script will skip
    creation and proceed directly to AIP Super User feature configuration.

    Reference: Purview readme.md — Section 13 (Purview Information Protection Super User)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$TenantDomain
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region ── Connect — Microsoft Graph ──────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Purview AIP Super User Group — Provisioning Script" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$RequiredScopes = @("Group.ReadWrite.All", "User.Read")

$ExistingCtx = Get-MgContext -ErrorAction SilentlyContinue
$ExistingScopes = @()

if ($ExistingCtx -and $ExistingCtx.PSObject.Properties.Name -contains 'Scopes') {
    $ExistingScopes = @($ExistingCtx.Scopes)
}

$MissingScopes = $RequiredScopes | Where-Object { $ExistingScopes -notcontains $_ }

if (-not $ExistingCtx -or $MissingScopes) {
    Connect-MgGraph -Scopes $RequiredScopes -NoWelcome
}

$CurrentUser = Get-MgUser -UserId (Get-MgContext).Account
$OwnerRef    = "https://graph.microsoft.com/v1.0/users/$($CurrentUser.Id)"

Write-Host "Connected : $($CurrentUser.DisplayName) ($($CurrentUser.UserPrincipalName))" -ForegroundColor Green
Write-Host ""

#endregion

#region ── Group definition ───────────────────────────────────────────────────

# Name follows M365 Group Naming Standard — Section 7.6 (Purview admin roles)
# Pattern: DG-Purview-AUG-Admin-[Role]
#
# DG       = Data Governance Group (Purview service)
# Purview  = Pillar / service
# AUG      = All Users Group type code
# Admin    = Policy area (admin roles)
# AIPSuperUsers = Role descriptor

$GroupName        = "DG-Purview-AUG-Admin-AIPSuperUsers"
$GroupMailAlias   = "DGPurviewAUGAdminAIPSuperUsers"     # Mail alias — no hyphens
$GroupEmail       = "$GroupMailAlias@$TenantDomain"
$GroupDescription = "Purview Information Protection Super User group (Section 7.6 — Purview admin roles). " +
                    "Members can decrypt ANY RMS/MIP-protected content in the tenant regardless of the original encryptor. " +
                    "CRITICAL privilege — restrict to Information Protection Admins, Legal/eDiscovery lead, and CISO only. " +
                    "Review membership quarterly. Enable AIP Super User feature on demand; disable after each use. " +
                    "Reference: Purview readme.md Section 13."

#endregion

#region ── Create Entra group ────────────────────────────────────────────────

$GroupId = $null

Write-Host "[1/3] Creating Entra security group..." -ForegroundColor Yellow

$Existing = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue

if ($Existing) {
    Write-Host "  SKIP  $GroupName — group already exists" -ForegroundColor DarkYellow
    Write-Host "        Id    : $($Existing.Id)" -ForegroundColor DarkYellow
    Write-Host "        Proceeding to AIP Super User configuration..." -ForegroundColor DarkYellow
    $GroupId = $Existing.Id
}
elseif ($PSCmdlet.ShouldProcess($GroupName, "Create mail-enabled security group")) {
    try {
        $Params = @{
            DisplayName     = $GroupName
            Description     = $GroupDescription
            SecurityEnabled = $true
            MailEnabled     = $true    # Required by Add-AipServiceSuperUserGroup
            MailNickname    = $GroupMailAlias
            GroupTypes      = @()      # Plain security group — NOT Microsoft 365 group
        }

        $NewGroup = New-MgGroup -BodyParameter $Params
        $GroupId  = $NewGroup.Id

        # Add owner
        New-MgGroupOwnerByRef -GroupId $GroupId -OdataId $OwnerRef -ErrorAction SilentlyContinue

        Write-Host "  OK    $GroupName" -ForegroundColor Green
        Write-Host "        Id    : $GroupId" -ForegroundColor Green
        Write-Host "        Email : $GroupEmail" -ForegroundColor Green
        Write-Host ""
        Write-Host "  ⚠️  Group is EMPTY — add members in Entra ID before enabling the feature." -ForegroundColor Yellow
        Write-Host "     Approved roles: Information Protection Admin, Legal/eDiscovery lead, CISO" -ForegroundColor Yellow
    }
    catch {
        Write-Host "  FAIL  $GroupName" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

#endregion

#region ── Configure AIP Super User feature ──────────────────────────────────

Write-Host ""
Write-Host "[2/3] Configuring AIP Super User feature..." -ForegroundColor Yellow

# ── Platform check ────────────────────────────────────────────────────────────
# AIPService module requires Windows PowerShell on Windows.
# On macOS/Linux we skip the module steps and print manual instructions instead.

if (-not $IsWindows) {
    Write-Host ""
    Write-Host "  ⚠️  Platform: macOS / Linux detected." -ForegroundColor Yellow
    Write-Host "  The AIPService module requires Windows PowerShell 5.1 on Windows." -ForegroundColor Yellow
    Write-Host "  The Entra group was created successfully above." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Complete the AIP Super User configuration from a Windows machine:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "    Install-Module -Name AIPService -Scope CurrentUser -Force" -ForegroundColor DarkGray
    Write-Host "    Import-Module AIPService" -ForegroundColor DarkGray
    Write-Host "    Connect-AipService" -ForegroundColor DarkGray
    Write-Host "    Enable-AipServiceSuperUserFeature" -ForegroundColor DarkGray
    Write-Host "    Add-AipServiceSuperUserGroup -GroupEmailAddress '$GroupEmail'" -ForegroundColor DarkGray
    Write-Host "    Get-AipServiceSuperUserGroup   # verify assignment" -ForegroundColor DarkGray
    Write-Host "    Disable-AipServiceSuperUserFeature" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Alternatively, configure via the Purview portal:" -ForegroundColor Cyan
    Write-Host "    https://purview.microsoft.com → Settings → Information Protection → Super User" -ForegroundColor DarkGray
    Write-Host ""
}
else {
    # ── Windows path — use the AIPService module ──────────────────────────────
    if (-not (Get-Module -ListAvailable -Name AIPService)) {
        Write-Host "  AIPService module not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name AIPService -Scope CurrentUser -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not install AIPService module automatically."
            Write-Warning "Run manually: Install-Module -Name AIPService -Scope CurrentUser -Force"
            Write-Warning "Then re-run this script, or complete AIP configuration manually:"
            Write-Warning "  Connect-AipService"
            Write-Warning "  Enable-AipServiceSuperUserFeature"
            Write-Warning "  Add-AipServiceSuperUserGroup -GroupEmailAddress '$GroupEmail'"
            Write-Warning "  Disable-AipServiceSuperUserFeature"
            exit 1
        }
    }

    try {
        Import-Module AIPService -ErrorAction Stop
    }
    catch {
        Write-Host "  FAIL  Unable to import AIPService." -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  This is often an architecture mismatch. Try:" -ForegroundColor Yellow
        Write-Host "    Install-Module -Name AIPService -Scope CurrentUser -Force" -ForegroundColor Yellow
        exit 1
    }

    if ($PSCmdlet.ShouldProcess("AIP Super User Feature", "Connect to AIP Service, enable feature, assign group, then disable")) {

        Write-Host "  Connecting to AIP Service (browser sign-in may appear)..." -ForegroundColor White
        Connect-AipService -ErrorAction Stop

        # Step 1: Enable the feature (disabled by default in all tenants)
        Enable-AipServiceSuperUserFeature
        $FeatureState = Get-AipServiceSuperUserFeature
        Write-Host "  Feature state  : $FeatureState" -ForegroundColor Green

        # Step 2: Assign the Super User group
        Add-AipServiceSuperUserGroup -GroupEmailAddress $GroupEmail
        $AssignedGroup = Get-AipServiceSuperUserGroup
        Write-Host "  Assigned group : $AssignedGroup" -ForegroundColor Green

        # Check for legacy individual Super Users
        $IndividualUsers = Get-AipServiceSuperUser
        if ($IndividualUsers) {
            Write-Host "  ⚠️  Individual Super Users also present (legacy): $($IndividualUsers -join ', ')" -ForegroundColor Yellow
            Write-Host "     Consider removing with: Remove-AipServiceSuperUser -EmailAddress '<upn>'" -ForegroundColor Yellow
        }

        # Step 3: Disable — enable on demand only
        Disable-AipServiceSuperUserFeature
        $FeatureState = Get-AipServiceSuperUserFeature
        Write-Host "  Feature state  : $FeatureState (disabled until needed)" -ForegroundColor Yellow

        Write-Host ""
        Write-Host "[3/3] Disconnecting from AIP Service..." -ForegroundColor Yellow
        Disconnect-AipService | Out-Null
    }
}

#endregion

#region ── Summary ────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Provisioning complete" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Group   : $GroupName" -ForegroundColor Green
Write-Host "  Email   : $GroupEmail" -ForegroundColor Green
Write-Host "  Feature : Disabled — enable on demand" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Add approved members to '$GroupName' in Entra ID:" -ForegroundColor White
Write-Host "       ✅ Information Protection Administrator" -ForegroundColor White
Write-Host "       ✅ Legal / eDiscovery team lead" -ForegroundColor White
Write-Host "       ✅ CISO or Deputy CISO" -ForegroundColor White
Write-Host "       ❌ General helpdesk or IT admins" -ForegroundColor Red
Write-Host ""
Write-Host "  2. To enable Super User rights when needed:" -ForegroundColor White
Write-Host "       Connect-AipService" -ForegroundColor DarkGray
Write-Host "       Enable-AipServiceSuperUserFeature" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. To disable after use:" -ForegroundColor White
Write-Host "       Disable-AipServiceSuperUserFeature" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  4. Review group membership and AIP audit logs quarterly." -ForegroundColor White
Write-Host "     Audit query:" -ForegroundColor White
Write-Host "       Get-AipServiceUserLog -Path 'C:\AIPLogs' -FromDate (Get-Date).AddDays(-90)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  5. Full operational runbook: Purview readme.md — Section 13" -ForegroundColor White
Write-Host ""

Disconnect-MgGraph | Out-Null

#endregion
