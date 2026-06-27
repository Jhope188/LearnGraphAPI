#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Users

<#
.SYNOPSIS
    Creates AI agent, Non-Human Identity (NHI), and Security & Admin groups for an M365 tenant.

.DESCRIPTION
    Creates SG-NHI-*, SG-Admin-*, and SG-Security-* groups following the M365 Group
    Naming Standard. Covers:
      - Service accounts, managed identities, and workload identities (NHI)
      - AI agents: Copilot Studio, Azure AI Foundry, third-party
      - Admin role groups (Global, Security, Compliance, Helpdesk, Intune, User)
      - PIM-eligible privileged roles
      - Defender XDR and security operations (SOC)
      - Attack Simulation Training scope

    The signed-in user running this script is automatically set as group owner.
    To add a second owner, uncomment the $SecondOwnerUPN line below.

.PARAMETER WhatIf
    Run in preview mode — shows what would be created without making changes.

.EXAMPLE
    .\New-AIAgentAndSecurityAdminGroups.ps1
    .\New-AIAgentAndSecurityAdminGroups.ps1 -WhatIf

.NOTES
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Users
    Scopes:   Group.ReadWrite.All, User.Read

    IMPORTANT — NHI groups and CA policy:
    Never add NHI accounts to user-facing CA groups. Create dedicated Conditional
    Access policies for workload identities and assign SG-NHI-* groups there.
    Workload Identity CA requires the Workload Identities Premium add-on licence.

    IMPORTANT — Admin role groups and PIM:
    After creating admin role groups, configure them in Entra PIM as role-assignable
    groups (requires Entra P2). Assign roles as Eligible, not Active, so admins must
    activate via PIM with justification.
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#region ── Connect ─────────────────────────────────────────────────────────────

Write-Host "`n=== AI, Agent, NHI & Security Admin Group Provisioning ===" -ForegroundColor Cyan

Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read" -NoWelcome

$CurrentUser = Get-MgUser -UserId (Get-MgContext).Account
$OwnerRef    = "https://graph.microsoft.com/v1.0/users/$($CurrentUser.Id)"

Write-Host "Owner: $($CurrentUser.DisplayName) ($($CurrentUser.UserPrincipalName))" -ForegroundColor Green

# ── Optional: add a second owner ───────────────────────────────────────────
# Uncomment the two lines below and set the UPN to add a second group owner.
# Suggested: a privileged identity admin or security architect account.
#
# $SecondOwnerUPN = "identityadmin@yourdomain.com"
# $SecondOwner    = Get-MgUser -UserId $SecondOwnerUPN

#endregion

#region ── Group definitions ──────────────────────────────────────────────────

$Groups = @(

    # ══ NON-HUMAN IDENTITIES (NHI) ════════════════════════════════════════════
    #
    # NHI = any Entra identity that is not a human user:
    #   - Service accounts (traditional app/scheduled task accounts)
    #   - Managed identities (Azure-native, no credentials)
    #   - App registrations / service principals
    #   - Workload identities (GitHub Actions, Kubernetes, federated)
    #   - AI agents (Copilot Studio, AI Foundry, third-party LLM agents)
    #
    # NHI groups should be used to EXCLUDE these identities from user-facing
    # Conditional Access policies and ENROL them in workload identity CA policies.

    # ── Service Accounts ──────────────────────────────────────────────────────
    @{
        Name        = "SG-NHI-AUG-ServiceAccounts-All"
        Description = "All service and automation accounts. Primary CA exclusion group — add to CA GlobalExclusions or a dedicated NHI CA policy."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-ServiceAccounts-Privileged"
        Description = "Service accounts with elevated or admin-level permissions. Separate monitoring and access review required."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-ServiceAccounts-LegacyAuth"
        Description = "Service accounts still using basic or legacy authentication. Remediation target — track and migrate to modern auth or managed identities."
        Type        = "Assigned"
        Rule        = $null
    }

    # ── Managed & Workload Identities ─────────────────────────────────────────
    @{
        Name        = "SG-NHI-AUG-ManagedIdentities-All"
        Description = "Azure managed identities (system and user-assigned) requiring policy scoping or governance tracking."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-WorkloadIdentities-All"
        Description = "All federated workload identities — GitHub Actions, Kubernetes pods, external CI/CD pipelines."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-WorkloadIdentities-CIPipelines"
        Description = "CI/CD pipeline identities — Azure DevOps, GitHub Actions. May require specific IP-restricted CA policies."
        Type        = "Assigned"
        Rule        = $null
    }

    # ── AI Agents ─────────────────────────────────────────────────────────────
    # AI agents are registered in Entra as application principals (Entra Agent ID).
    # Group by platform and environment so CA and governance policies can be targeted.

    @{
        Name        = "SG-NHI-AUG-Agents-CopilotStudio-Pilot"
        Description = "Copilot Studio agents in pilot or test environment. Use for pre-production CA policy and monitoring scope."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-Agents-CopilotStudio-Prod"
        Description = "Copilot Studio agents in production. Apply production-grade CA and Workload Identity policies."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-Agents-AIFoundry-Pilot"
        Description = "Azure AI Foundry agents in pilot environment."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-Agents-AIFoundry-Prod"
        Description = "Azure AI Foundry agents in production. Includes agents with Graph API or M365 service access."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-Agents-ThirdParty-Prod"
        Description = "Approved third-party AI agents with Entra application registrations in production."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-Agents-CAPolicyExclusion"
        Description = "AI agents excluded from user-facing CA policies. These identities should be enrolled in a dedicated Workload Identity CA policy instead."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-NHI-AUG-Agents-HighPrivilege"
        Description = "AI agents with Graph API permissions, admin-level delegated access, or sensitive data access. Highest scrutiny — regular access review required."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══ SECURITY & ADMIN ROLE GROUPS ══════════════════════════════════════════
    #
    # These groups back Entra role assignments. Using groups (rather than direct
    # user assignment) enables PIM, access reviews, and audit trails.
    # After creation, configure in Entra PIM > Groups as role-assignable groups.
    # Assign all privileged roles as Eligible — not Active — in PIM.

    @{
        Name        = "SG-Admin-AUG-GlobalAdmins"
        Description = "Global Administrator role group. Maximum privilege — absolute minimum membership. All access via PIM activation with approval."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Admin-AUG-SecurityAdmins"
        Description = "Security Administrator role group. Manages Defender, Purview, and security policies."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Admin-AUG-ComplianceAdmins"
        Description = "Compliance Administrator role group. Manages Purview compliance policies, DLP, and retention."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Admin-AUG-HelpdeskAdmins"
        Description = "Helpdesk Administrator role group. Password reset and basic user support — no licence or group management."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Admin-AUG-IntuneAdmins"
        Description = "Intune Administrator role group. Full Intune and Endpoint Manager administration."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Admin-AUG-UserAdmins"
        Description = "User Administrator role group. User lifecycle management, licence assignment, group management."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Admin-AUG-PIMEligible-PrivilegedRoles"
        Description = "Users eligible to activate privileged Entra roles via PIM. All privileged role holders must be in this group."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══ SECURITY OPERATIONS ════════════════════════════════════════════════════

    @{
        Name        = "SG-Security-AUG-DefenderXDR-Admins"
        Description = "Defender XDR portal administrators — full configuration, policy, and incident management access."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Security-AUG-DefenderXDR-Analysts"
        Description = "SOC analysts — investigate and respond to incidents, no configuration permissions."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Security-AUG-DefenderVuln-RemediationOwners"
        Description = "Asset owners responsible for vulnerability remediation tasks in Defender Vulnerability Management."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Security-AUG-AttackSimulation-TargetUsers"
        Description = "Users included in Attack Simulation Training phishing and social engineering campaigns."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Security-AUG-AttackSimulation-Excluded"
        Description = "Users excluded from Attack Simulation Training — executives, legal, communications teams, PR roles."
        Type        = "Assigned"
        Rule        = $null
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
            $Params = @{
                DisplayName         = $g.Name
                Description         = $g.Description
                SecurityEnabled     = $true
                MailEnabled         = $false
                MailNickname        = $g.Name -replace '[^a-zA-Z0-9]', ''
                GroupTypes          = @()
                "Owners@odata.bind" = @($OwnerRef)
            }

            # All groups in this script are Assigned — no dynamic rules needed.
            # NHI agent groups must be manually curated for security reasons.

            $NewGroup = New-MgGroup -BodyParameter $Params

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
Write-Host "  1. Configure SG-Admin-* groups as role-assignable in Entra PIM (requires P2)" -ForegroundColor White
Write-Host "  2. Assign Entra roles to SG-Admin-* groups as Eligible (not Active) in PIM" -ForegroundColor White
Write-Host "  3. Exclude SG-NHI-AUG-Agents-CAPolicyExclusion from user CA policies" -ForegroundColor White
Write-Host "  4. Create a dedicated Workload Identity CA policy scoped to SG-NHI-* groups" -ForegroundColor White
Write-Host "     (requires Workload Identities Premium licence)" -ForegroundColor White
Write-Host "  5. Enrol SG-Admin-* groups in Entra Access Reviews for periodic review" -ForegroundColor White

Disconnect-MgGraph | Out-Null

#endregion
