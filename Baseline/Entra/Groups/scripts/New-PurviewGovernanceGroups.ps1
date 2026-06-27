#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Users

<#
.SYNOPSIS
    Creates the standard Microsoft Purview data governance groups for an M365 tenant.

.DESCRIPTION
    Creates all DG-Purview-* groups following the M365 Group Naming Standard.
    Covers: DLP scoping, sensitivity label scoping, Insider Risk Management,
    retention/legal hold, eDiscovery, communications compliance, and admin roles.

    The signed-in user running this script is automatically set as group owner.
    To add a second owner, uncomment the $SecondOwnerUPN line below.

.PARAMETER WhatIf
    Run in preview mode — shows what would be created without making changes.

.EXAMPLE
    .\New-PurviewGovernanceGroups.ps1
    .\New-PurviewGovernanceGroups.ps1 -WhatIf

.NOTES
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Users
    Scopes:   Group.ReadWrite.All, User.Read

    After creation, assign these groups in the Microsoft Purview portal:
    - DLP policies   → Purview > Data Loss Prevention > Policies > [Policy] > Locations
    - Sensitivity labels → Purview > Information Protection > Label policies > [Policy] > Users/groups
    - IRM policies   → Purview > Insider Risk Management > Policies > [Policy] > Users
    - Legal hold     → Purview > eDiscovery > Cases > [Case] > Hold
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#region ── Connect ─────────────────────────────────────────────────────────────

Write-Host "`n=== Purview Data Governance Group Provisioning ===" -ForegroundColor Cyan

Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read" -NoWelcome

$CurrentUser = Get-MgUser -UserId (Get-MgContext).Account
$OwnerRef    = "https://graph.microsoft.com/v1.0/users/$($CurrentUser.Id)"

Write-Host "Owner: $($CurrentUser.DisplayName) ($($CurrentUser.UserPrincipalName))" -ForegroundColor Green

# ── Optional: add a second owner ───────────────────────────────────────────
# Uncomment the two lines below and set the UPN to add a second group owner.
# Suggested: your Compliance Administrator or Purview Data Admin account.
#
# $SecondOwnerUPN = "complianceadmin@yourdomain.com"
# $SecondOwner    = Get-MgUser -UserId $SecondOwnerUPN

#endregion

#region ── Group definitions ──────────────────────────────────────────────────

$Groups = @(

    # ── Admin ───────────────────────────────────────────────────────────────
    @{
        Name        = "DG-Purview-AUG-Admin-DataAdmins"
        Description = "Purview data administrators with policy creation and management permissions."
        Type        = "Assigned"
    }

    # ── DLP ─────────────────────────────────────────────────────────────────
    @{
        Name        = "DG-Purview-AUG-DLP-BrowserProtection-Included"
        Description = "Users in scope for Endpoint DLP browser upload restriction policy."
        Type        = "Assigned"
    }
    @{
        Name        = "DG-Purview-AUG-DLP-BrowserProtection-Excluded"
        Description = "Users excluded from DLP browser protection — security tooling, dev environments."
        Type        = "Assigned"
    }
    @{
        Name        = "DG-Purview-AUG-DLP-EmailProtection-Included"
        Description = "Users in scope for outbound email DLP policy monitoring."
        Type        = "Assigned"
    }
    @{
        Name        = "DG-Purview-AUG-DLP-EmailProtection-Excluded"
        Description = "Users excluded from email DLP — automated mailers, helpdesk shared mailboxes."
        Type        = "Assigned"
    }
    @{
        Name        = "DG-Purview-AUG-DLP-EndpointProtection-Excluded"
        Description = "Users/devices excluded from Endpoint DLP policy. Requires documented justification and review cycle."
        Type        = "Assigned"
    }

    # ── Sensitivity Labels ──────────────────────────────────────────────────
    @{
        Name        = "DG-Purview-AUG-Label-Internal-Users"
        Description = "Users scoped to the Internal sensitivity label policy."
        Type        = "Assigned"
    }
    @{
        Name        = "DG-Purview-AUG-Label-Confidential-Users"
        Description = "Users who can view and apply the Confidential sensitivity label."
        Type        = "Assigned"
    }
    @{
        Name        = "DG-Purview-AUG-Label-HighlyConfidential-Users"
        Description = "Users who can view and apply the Highly Confidential sensitivity label. Restrict to need-to-know roles."
        Type        = "Assigned"
    }

    # ── Insider Risk Management ──────────────────────────────────────────────
    @{
        Name        = "DG-Purview-AUG-InsiderRisk-ScopedUsers"
        Description = "Users actively in scope for Insider Risk Management policy monitoring."
        Type        = "Assigned"
    }
    @{
        Name        = "DG-Purview-AUG-InsiderRisk-ExcludedUsers"
        Description = "Users excluded from IRM policies — legal, executives, HR leadership, privileged roles. Managed separately if required."
        Type        = "Assigned"
    }

    # ── Retention & Legal Hold ───────────────────────────────────────────────
    @{
        Name        = "DG-Purview-AUG-Retention-LegalHold"
        Description = "Users under active legal hold. Content is preserved regardless of retention policy. Managed by legal/compliance team."
        Type        = "Assigned"
    }

    # ── eDiscovery ───────────────────────────────────────────────────────────
    @{
        Name        = "DG-Purview-AUG-eDiscovery-Managers"
        Description = "Users assigned the eDiscovery Manager role scope in Purview. Can create and manage cases."
        Type        = "Assigned"
    }

    # ── Communications Compliance ────────────────────────────────────────────
    @{
        Name        = "DG-Purview-AUG-CommunicationsCompliance-Scoped"
        Description = "Users in scope for Communications Compliance policy review — Teams, email, Viva Engage."
        Type        = "Assigned"
    }
)

#endregion

#region ── Create groups ──────────────────────────────────────────────────────

$Results = [System.Collections.Generic.List[PSObject]]::new()
$Created = 0
$Skipped = 0
$Failed  = 0

foreach ($g in $Groups) {

    $Existing = Get-MgGroup -Filter "displayName eq '$($g.Name)'" -ErrorAction SilentlyContinue

    if ($Existing) {
        Write-Host "  SKIP  $($g.Name)" -ForegroundColor DarkYellow
        $Skipped++
        $Results.Add([PSCustomObject]@{ Name = $g.Name; Status = "Skipped — already exists"; Id = $Existing.Id })
        continue
    }

    if ($PSCmdlet.ShouldProcess($g.Name, "Create security group")) {
        try {
            $NewGroup = New-MgGroup -BodyParameter @{
                DisplayName         = $g.Name
                Description         = $g.Description
                SecurityEnabled     = $true
                MailEnabled         = $false
                MailNickname        = $g.Name -replace '[^a-zA-Z0-9]', ''
                GroupTypes          = @()
                "Owners@odata.bind" = @($OwnerRef)
            }

            # ── Optional second owner ─────────────────────────────────────
            # Uncomment below if $SecondOwner was set above
            #
            # New-MgGroupOwnerByRef -GroupId $NewGroup.Id -BodyParameter @{
            #     "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($SecondOwner.Id)"
            # }

            Write-Host "  OK    $($g.Name)" -ForegroundColor Green
            $Created++
            $Results.Add([PSCustomObject]@{ Name = $g.Name; Status = "Created"; Id = $NewGroup.Id })
        }
        catch {
            Write-Host "  FAIL  $($g.Name) — $($_.Exception.Message)" -ForegroundColor Red
            $Failed++
            $Results.Add([PSCustomObject]@{ Name = $g.Name; Status = "Failed: $($_.Exception.Message)"; Id = "" })
        }
    }
}

#endregion

#region ── Summary ────────────────────────────────────────────────────────────

Write-Host "`n─────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Created : $Created" -ForegroundColor Green
Write-Host "  Skipped : $Skipped" -ForegroundColor Yellow
Write-Host "  Failed  : $Failed"  -ForegroundColor Red
Write-Host "─────────────────────────────────────────`n" -ForegroundColor Cyan

$Results | Format-Table Name, Status -AutoSize

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Assign DG-Purview-AUG-DLP-* groups in Purview > Data Loss Prevention > Policies" -ForegroundColor White
Write-Host "  2. Assign DG-Purview-AUG-Label-* groups in Purview > Information Protection > Label policies" -ForegroundColor White
Write-Host "  3. Assign DG-Purview-AUG-InsiderRisk-* in Purview > Insider Risk Management > Policies" -ForegroundColor White
Write-Host "  4. Assign DG-Purview-AUG-Retention-LegalHold in Purview > eDiscovery cases" -ForegroundColor White

Disconnect-MgGraph | Out-Null

#endregion
