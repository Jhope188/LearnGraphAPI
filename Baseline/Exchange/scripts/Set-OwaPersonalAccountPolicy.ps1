<#
.SYNOPSIS
    Audits and disables personal account access in Outlook on the web (OWA).

.DESCRIPTION
    This script:
      1. Checks the current OWA mailbox policy for personal account settings
      2. Reports whether PersonalAccountsEnabled and PersonalAccountCalendarsEnabled
         are currently enabled or disabled
      3. Optionally disables both settings on the default OWA mailbox policy

    WHY DISABLE PERSONAL ACCOUNTS IN OWA
    -------------------------------------
    When PersonalAccountsEnabled is True, users can add personal email accounts
    (Outlook.com, Gmail, Yahoo, etc.) directly into Outlook on the web and the
    new Outlook for Windows. This creates several risks:

    Data Leakage
        Users can drag-and-drop or forward corporate emails to personal accounts
        directly within the same client. DLP policies that rely on transport rules
        do not inspect client-side moves between accounts in the same session.

    Credential Exposure
        Personal accounts authenticate through the corporate Outlook session.
        If a personal account is compromised, the attacker gains a foothold
        inside the corporate client context, even if they cannot access the
        corporate mailbox directly.

    Shadow IT
        Personal calendar integration (PersonalAccountCalendarsEnabled) merges
        personal and corporate scheduling data. This leaks meeting titles,
        attendee lists, and location data into unmanaged personal accounts
        that sit outside your retention and compliance boundary.

    Compliance Boundary
        Regulated industries (financial services, healthcare, government) require
        clear separation between corporate and personal communications. Allowing
        personal accounts inside the corporate mail client blurs that boundary
        and can create audit findings.

    CIS Benchmark Alignment
        While not a numbered CIS control, disabling personal accounts aligns
        with the principle of least functionality: corporate tools should serve
        corporate purposes only.

    IMPORTANT: Changes to OWA mailbox policies may take up to 60 minutes to
    propagate. If a user has already added personal accounts before the policy
    is applied, those accounts are disabled when the policy is detected.

    Reference:
      https://learn.microsoft.com/microsoft-365-apps/outlook/manage/policy-management#allow-only-corporate-mailboxes-to-be-added
      https://learn.microsoft.com/powershell/module/exchange/set-owamailboxpolicy

.PARAMETER Remediate
    Switch. If specified, disables PersonalAccountsEnabled and
    PersonalAccountCalendarsEnabled on the default OWA mailbox policy.
    Default: audit-only (no changes made).

.PARAMETER PolicyName
    The name of the OWA mailbox policy to target.
    Default: "OwaMailboxPolicy-Default"

.EXAMPLE
    # Audit only — check current state
    .\Set-OwaPersonalAccountPolicy.ps1

    # Audit and remediate
    .\Set-OwaPersonalAccountPolicy.ps1 -Remediate

    # Target a custom policy
    .\Set-OwaPersonalAccountPolicy.ps1 -PolicyName "Executive-OWA-Policy" -Remediate
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$Remediate,
    [string]$PolicyName = "OwaMailboxPolicy-Default"
)

#region --- Helpers ---

function Write-Status {
    param([string]$Message, [string]$Color = 'White')
    Write-Host $Message -ForegroundColor $Color
}

#endregion

#region --- Connection Check ---

Write-Status "`n=== OWA Personal Account Policy Review ===" -Color Cyan
Write-Status "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color Gray

try {
    $null = Get-OrganizationConfig -ErrorAction Stop
} catch {
    Write-Status "`n[!] Not connected to Exchange Online." -Color Yellow
    $connect = Read-Host "    Connect now? (Y/N)"
    if ($connect -match '^[Yy]') {
        Connect-ExchangeOnline -ShowBanner:$false
        try {
            $null = Get-OrganizationConfig -ErrorAction Stop
        } catch {
            Write-Status "[ERROR] Connection failed. Exiting." -Color Red
            exit 1
        }
    } else {
        Write-Status "[ERROR] Cannot proceed without an Exchange Online connection." -Color Red
        exit 1
    }
}

#endregion

#region --- Step 1: Audit Current State ---

Write-Status "`n[STEP 1] Checking OWA mailbox policies..." -Color Cyan

$Policies = Get-OwaMailboxPolicy | Select-Object Name, PersonalAccountsEnabled, PersonalAccountCalendarsEnabled

if (-not $Policies) {
    Write-Status "[ERROR] No OWA mailbox policies found." -Color Red
    exit 1
}

Write-Status ""
$Policies | ForEach-Object {
    $name    = $_.Name
    $pa      = $_.PersonalAccountsEnabled
    $pac     = $_.PersonalAccountCalendarsEnabled

    $paStatus  = if ($pa)  { "[FAIL] Enabled"  } else { "[PASS] Disabled" }
    $pacStatus = if ($pac) { "[FAIL] Enabled"  } else { "[PASS] Disabled" }
    $paColor   = if ($pa)  { 'Red' } else { 'Green' }
    $pacColor  = if ($pac) { 'Red' } else { 'Green' }

    Write-Status "  Policy: $name" -Color White
    Write-Status "    PersonalAccountsEnabled          : $paStatus" -Color $paColor
    Write-Status "    PersonalAccountCalendarsEnabled   : $pacStatus" -Color $pacColor
    Write-Status ""
}

#endregion

#region --- Step 2: Remediate ---

$TargetPolicy = $Policies | Where-Object { $_.Name -eq $PolicyName }

if (-not $TargetPolicy) {
    Write-Status "[WARN] Policy '$PolicyName' not found. Available policies:" -Color Yellow
    $Policies | ForEach-Object { Write-Status "  - $($_.Name)" -Color Gray }
    exit 1
}

$NeedsRemediation = $TargetPolicy.PersonalAccountsEnabled -or $TargetPolicy.PersonalAccountCalendarsEnabled

if (-not $NeedsRemediation) {
    Write-Status "[PASS] Policy '$PolicyName' already has personal accounts disabled. No action needed." -Color Green
} elseif ($Remediate) {
    Write-Status "[STEP 2] Remediating policy '$PolicyName'..." -Color Cyan

    if ($PSCmdlet.ShouldProcess($PolicyName, "Disable PersonalAccountsEnabled and PersonalAccountCalendarsEnabled")) {
        try {
            Set-OwaMailboxPolicy -Identity $PolicyName `
                -PersonalAccountsEnabled $false `
                -PersonalAccountCalendarsEnabled $false `
                -ErrorAction Stop

            Write-Status "[REMEDIATED] PersonalAccountsEnabled          = False" -Color Green
            Write-Status "[REMEDIATED] PersonalAccountCalendarsEnabled   = False" -Color Green
            Write-Status ""
            Write-Status "[NOTE] Changes may take up to 60 minutes to propagate." -Color Yellow
            Write-Status "[NOTE] Users who already added personal accounts will have them disabled" -Color Yellow
            Write-Status "       when the updated policy is detected by their client." -Color Yellow
        } catch {
            Write-Status "[ERROR] Failed to update policy: $($_.Exception.Message)" -Color Red
            exit 1
        }
    }
} else {
    Write-Status "[ACTION REQUIRED] Policy '$PolicyName' has personal accounts enabled." -Color Yellow
    Write-Status "  Run with -Remediate to disable:" -Color Yellow
    Write-Status "  .\Set-OwaPersonalAccountPolicy.ps1 -Remediate" -Color Cyan
}

#endregion

#region --- Summary ---

Write-Status "`n=== REFERENCE ===" -Color Cyan
Write-Status "  OWA Policy Management    : https://learn.microsoft.com/microsoft-365-apps/outlook/manage/policy-management" -Color Gray
Write-Status "  Set-OwaMailboxPolicy     : https://learn.microsoft.com/powershell/module/exchange/set-owamailboxpolicy" -Color Gray
Write-Status "  Supported Account Types  : https://learn.microsoft.com/microsoft-365-apps/outlook/get-started/supported-account-types" -Color Gray
Write-Status ""

#endregion
