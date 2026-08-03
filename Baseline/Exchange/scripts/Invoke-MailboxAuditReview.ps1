<#
.SYNOPSIS
    Audits and remediates mailbox audit action configuration for all UserMailboxes.

.DESCRIPTION
    This script:
      1. Verifies org-level mailbox auditing is enabled (AuditDisabled = False)
      2. Audits each UserMailbox for AuditEnabled status and missing non-default
         audit actions (Admin/Delegate/Owner) per CIS M365 Foundations requirements
      3. Reports current state with pass/fail per mailbox
      4. Optionally remediates using full overwrite syntax to enforce exact
         compliance action sets per CIS M365 Foundations Benchmark
      5. Sets AuditLogAgeLimit = 180 on each remediated mailbox; for extended
         retention configure Purview Audit Log Retention Policies

    Based on: https://learn.microsoft.com/en-us/purview/audit-mailboxes
    CIS M365 Foundations Benchmark — Mailbox Audit Actions control (CIS 6.1.2 L1)

    WHY THESE NON-DEFAULT ACTIONS MUST BE REMEDIATED
    -------------------------------------------------
    Microsoft deliberately excluded FolderBind and MailboxLogin from defaults
    because they generate high log volume. The trade-off is justified:

    FolderBind (Admin + Delegate)
        The single most important forensic event for a BEC investigation. When an
        attacker compromises an account, their first action is browsing folders
        (inbox, sent items, finance folders). Without FolderBind logs you cannot
        determine what they accessed or read. You know the account was compromised
        but not the blast radius.

    Copy (Admin)
        Directly maps to data exfiltration. If an admin copies items out of a
        mailbox, that is auditable only with this action enabled.

    Move (Admin + Delegate + Owner)
        Attackers often move items to obscure folders or deleted items to hide
        activity or enable rules-based exfiltration. Without Move logs this is
        invisible.

    MailboxLogin (Owner)
        Tracks direct mailbox sign-ins. Critical for detecting anomalous access
        patterns, especially for high-value mailboxes.

    Bottom line: without these actions, if an account is compromised you know
    something happened but cannot reconstruct what was accessed or taken.
    CIS 6.1.2 (L1) requires these for exactly this reason: incident response
    depends on them.

    VOLUME CAVEAT
        Enabling FolderBind on all mailboxes significantly increases audit log
        volume and storage consumption. For E3 tenants with 90-day audit retention
        this accelerates log rollover. If you have Purview Audit (Premium) / E5
        this is less of a concern. Assess impact before rolling out org-wide.

.NOTES
    - Requires Exchange Online PowerShell module (ExchangeOnlineManagement)
    - Run as Global Admin or Exchange Admin
    - Uses full overwrite syntax for AuditAdmin/Delegate/Owner to enforce exact
      compliance action sets — does not rely on DefaultAuditSet auto-management
    - Sets AuditLogAgeLimit = 180 per mailbox during remediation
    - For retention beyond 180 days, configure Purview Audit Log Retention Policies

.PARAMETER Remediate
    Switch. If specified, applies remediation to all non-compliant mailboxes.
    Default: audit-only (no changes made).

.PARAMETER ExportPath
    Optional path to export CSV audit report. Defaults to current directory.

.EXAMPLE
    # Audit only
    .\Invoke-MailboxAuditReview.ps1

    # Audit and remediate
    .\Invoke-MailboxAuditReview.ps1 -Remediate

    # Audit with custom export path
    .\Invoke-MailboxAuditReview.ps1 -ExportPath "C:\Reports"
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$Remediate,
    [string]$ExportPath = "."
)

#region --- Configuration ---

# Full explicit audit action sets required for CIS M365 Foundations compliance baseline.
# Applied via full overwrite (not @{Add=}) to ensure exact conformance on every mailbox.
# Ref: https://learn.microsoft.com/en-us/purview/audit-mailboxes#mailbox-actions-for-user-mailboxes-and-shared-mailboxes

$RequiredAdminActions    = @(
    'ApplyRecord','Copy','Create','FolderBind','HardDelete','MailItemsAccessed',
    'Move','MoveToDeletedItems','Send','SendAs','SendOnBehalf','SoftDelete',
    'Update','UpdateCalendarDelegation','UpdateFolderPermissions','UpdateInboxRules'
)
$RequiredDelegateActions = @(
    'ApplyRecord','Create','FolderBind','HardDelete','MailItemsAccessed',
    'Move','MoveToDeletedItems','SendAs','SendOnBehalf','SoftDelete',
    'Update','UpdateFolderPermissions','UpdateInboxRules'
    # NOTE: 'Send' is NOT valid for Delegate — omitted intentionally
)
$RequiredOwnerActions    = @(
    'ApplyRecord','Create','HardDelete','MailboxLogin','MailItemsAccessed',
    'Move','MoveToDeletedItems','Send','SoftDelete','Update',
    'UpdateCalendarDelegation','UpdateFolderPermissions','UpdateInboxRules'
)

# Actions that ARE valid per sign-in type (used for validation only)
$ValidAdminActions    = @(
    'ApplyRecord','AttachmentAccess','Copy','Create','FolderBind','HardDelete',
    'MailItemsAccessed','MessageBind','Move','MoveToDeletedItems','RecordDelete',
    'Send','SendAs','SendOnBehalf','SoftDelete','Update','UpdateCalendarDelegation',
    'UpdateFolderPermissions','UpdateInboxRules'
)
$ValidDelegateActions = @(
    'ApplyRecord','AttachmentAccess','Create','FolderBind','HardDelete',
    'MailItemsAccessed','Move','MoveToDeletedItems','RecordDelete',
    'SendAs','SendOnBehalf','SoftDelete','Update','UpdateFolderPermissions',
    'UpdateInboxRules'
    # NOTE: 'Send' is NOT valid for Delegate — Admin and Owner only
)
$ValidOwnerActions    = @(
    'ApplyRecord','AttachmentAccess','Create','HardDelete','MailboxLogin',
    'MailItemsAccessed','Move','MoveToDeletedItems','RecordDelete',
    'SearchQueryInitiated','Send','SoftDelete','Update','UpdateCalendarDelegation',
    'UpdateFolderPermissions','UpdateInboxRules'
)

#endregion

#region --- Helpers ---

function Test-MissingActions {
    param (
        [string[]]$Required,
        [string[]]$Current
    )
    $Required | Where-Object { $_ -notin $Current }
}

function Write-Status {
    param([string]$Message, [string]$Color = 'White')
    Write-Host $Message -ForegroundColor $Color
}

#endregion

#region --- Connection Check ---

Write-Status "`n=== Mailbox Audit Review ===" -Color Cyan
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

#region --- Step 1: Org-Level Audit Check ---

Write-Status "`n[STEP 1] Checking org-level mailbox audit status..." -Color Cyan

$OrgConfig = Get-OrganizationConfig | Select-Object AuditDisabled
if ($OrgConfig.AuditDisabled -eq $true) {
    Write-Status "[FAIL] Organization-level mailbox auditing is DISABLED (AuditDisabled = True)" -Color Red
    Write-Status "       Run: Set-OrganizationConfig -AuditDisabled `$false" -Color Yellow
    Write-Status "       Remediation cannot proceed until org-level auditing is re-enabled." -Color Yellow
    exit 1
} else {
    Write-Status "[PASS] Organization-level mailbox auditing is ENABLED (AuditDisabled = False)" -Color Green
}

#endregion

#region --- Step 2: Per-Mailbox Audit ---

Write-Status "`n[STEP 2] Retrieving all UserMailboxes..." -Color Cyan

$Mailboxes = @(Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox -PropertySets Audit)

$TotalCount     = $Mailboxes.Count
$PassCount      = 0
$FailCount      = 0
$RemediatedCount = 0
$AuditResults   = [System.Collections.Generic.List[PSCustomObject]]::new()

Write-Status "Found $TotalCount UserMailbox(es). Auditing..." -Color Gray

$i = 0
foreach ($MBX in $Mailboxes) {
    $i++
    Write-Progress -Activity "Auditing mailboxes" -Status "$i of $TotalCount : $($MBX.UserPrincipalName)" -PercentComplete (($i / $TotalCount) * 100)

    $Issues      = [System.Collections.Generic.List[string]]::new()
    $Remediated  = $false

    # Check AuditEnabled
    if (-not $MBX.AuditEnabled) {
        $Issues.Add("AuditEnabled is False")
    }

    # Capture DefaultAuditSet for reporting
    $DefaultAuditSet = $MBX.DefaultAuditSet

    # Check missing non-default actions
    $CurrentAdmin    = @($MBX.AuditAdmin)
    $CurrentDelegate = @($MBX.AuditDelegate)
    $CurrentOwner    = @($MBX.AuditOwner)

    $MissingAdmin    = Test-MissingActions -Required $RequiredAdminActions    -Current $CurrentAdmin
    $MissingDelegate = Test-MissingActions -Required $RequiredDelegateActions -Current $CurrentDelegate
    $MissingOwner    = Test-MissingActions -Required $RequiredOwnerActions    -Current $CurrentOwner

    if ($MissingAdmin)    { $Issues.Add("Missing Admin actions: $($MissingAdmin -join ', ')") }
    if ($MissingDelegate) { $Issues.Add("Missing Delegate actions: $($MissingDelegate -join ', ')") }
    if ($MissingOwner)    { $Issues.Add("Missing Owner actions: $($MissingOwner -join ', ')") }

    $Status = if ($Issues.Count -eq 0) { 'PASS' } else { 'FAIL' }

    if ($Status -eq 'PASS') {
        $PassCount++
    } else {
        $FailCount++
        Write-Status "  [FAIL] $($MBX.UserPrincipalName) — $($Issues -join ' | ')" -Color Red

        # --- Remediation ---
        if ($Remediate) {
            try {
                $SetParams = @{
                    Identity         = $MBX.Identity
                    AuditEnabled     = $true
                    AuditLogAgeLimit = 180
                    AuditAdmin       = $RequiredAdminActions
                    AuditDelegate    = $RequiredDelegateActions
                    AuditOwner       = $RequiredOwnerActions
                }

                if ($PSCmdlet.ShouldProcess($MBX.UserPrincipalName, "Set-Mailbox audit remediation")) {
                    Set-Mailbox @SetParams
                    $Remediated  = $true
                    $RemediatedCount++
                    Write-Status "  [FIXED] $($MBX.UserPrincipalName)" -Color Green
                }
            } catch {
                Write-Status "  [ERROR] Failed to remediate $($MBX.UserPrincipalName): $($_.Exception.Message)" -Color Red
            }
        }
    }

    $AuditResults.Add([PSCustomObject]@{
        UserPrincipalName  = $MBX.UserPrincipalName
        DisplayName        = $MBX.DisplayName
        AuditEnabled       = $MBX.AuditEnabled
        DefaultAuditSet    = ($DefaultAuditSet -join ', ')
        CurrentAdminAudit  = ($CurrentAdmin -join ', ')
        CurrentDelegateAudit = ($CurrentDelegate -join ', ')
        CurrentOwnerAudit  = ($CurrentOwner -join ', ')
        MissingAdmin       = ($MissingAdmin -join ', ')
        MissingDelegate    = ($MissingDelegate -join ', ')
        MissingOwner       = ($MissingOwner -join ', ')
        Status             = $Status
        Remediated         = $Remediated
        Issues             = ($Issues -join ' | ')
    })
}

Write-Progress -Activity "Auditing mailboxes" -Completed

#endregion

#region --- Step 3: Summary ---

Write-Status "`n=== SUMMARY ===" -Color Cyan
Write-Status "Total mailboxes reviewed : $TotalCount" -Color White
Write-Status "Passed                   : $PassCount"  -Color Green
Write-Status "Failed                   : $FailCount"  -Color $(if ($FailCount -gt 0) { 'Red' } else { 'Green' })

if ($Remediate) {
    Write-Status "Remediated               : $RemediatedCount" -Color $(if ($RemediatedCount -gt 0) { 'Yellow' } else { 'White' })
}

#endregion

#region --- Step 4: Audit Retention Note ---

Write-Status "`n=== AUDIT RETENTION NOTE ===" -Color Yellow
Write-Status "AuditLogAgeLimit is set to 180 days per mailbox as part of remediation." -Color Yellow
Write-Status "For retention beyond 180 days, configure Purview Audit Log Retention Policies:" -Color Yellow
Write-Status "  https://learn.microsoft.com/en-us/purview/audit-log-retention-policies" -Color Gray
Write-Status "Recommended: Create a 180-day Purview policy scoped to Exchange mailbox activities." -Color Yellow

#endregion

#region --- Step 5: Export CSV ---

$Timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$ExportFile = Join-Path $ExportPath "MailboxAuditReport_$Timestamp.csv"

try {
    $AuditResults | Export-Csv -Path $ExportFile -NoTypeInformation -Encoding UTF8
    Write-Status "`n[EXPORT] Report saved to: $ExportFile" -Color Cyan
} catch {
    Write-Status "`n[WARN] Could not export CSV: $($_.Exception.Message)" -Color Yellow
}

#endregion

#region --- Step 6: Purview Retention Reminder ---

Write-Status "`n=== NEXT STEPS ===" -Color Cyan
Write-Status "1. Review the exported CSV for all FAIL entries." -Color White
Write-Status "2. Re-run with -Remediate to fix missing audit actions." -Color White
Write-Status "3. Create a Purview Audit Retention Policy for 180 days:" -Color White
Write-Status "   Purview Portal > Audit > Retention Policies > New Policy" -Color Gray
Write-Status "   Scope: Exchange mailbox activities | Duration: 180 days" -Color Gray
Write-Status "4. Verify DefaultAuditSet = 'Admin, Delegate, Owner' post-remediation" -Color White
Write-Status "   Run: Get-Mailbox -ResultSize Unlimited | Select UPN,DefaultAuditSet | Where DefaultAuditSet -ne 'Admin, Delegate, Owner'" -Color Gray
Write-Status "`nDone: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color Gray

#endregion
