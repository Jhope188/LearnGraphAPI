#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Users

<#
.SYNOPSIS
    Creates the standard Entra Identity & CA security groups for an M365 tenant.

.DESCRIPTION
    Creates all SG-Entra-* groups following the M365 Group Naming Standard.
    Covers: Conditional Access, Authentication Methods, Dynamic User Groups,
    Identity Governance, Self-Service, and App-Specific Access groups.

    Dynamic groups include validated membership rules for each group type.
    Review each rule comment before deploying — rules with # CUSTOMISE flags
    require adjustment to match your tenant's naming conventions or attributes.

    The signed-in user running this script is automatically set as group owner.
    To add a second owner, uncomment the $SecondOwnerUPN line below.

.PARAMETER WhatIf
    Run in preview mode — shows what would be created without making changes.

.EXAMPLE
    .\New-EntraIdentityGroups.ps1
    .\New-EntraIdentityGroups.ps1 -WhatIf

.NOTES
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Users
    Scopes:   Group.ReadWrite.All, User.Read

    Dynamic group membership rules require Entra ID P1 or P2.
    Rules are evaluated by Entra within ~5 minutes of group creation.
    Test rules in Entra portal > Groups > New Group > Dynamic > Rule builder
    before running this script in production.

    Service Plan GUIDs referenced in rules:
      Entra P1  (AAD_PREMIUM)   : 41781fb2-bc02-4b7c-bd55-b576c07bb09f
      Entra P2  (AAD_PREMIUM_P2): eec0eb4f-6444-4f95-aba0-50c24d67f998
      Teams Rooms (MEETING_ROOM): 57ff2da0-773e-42df-b2af-ffb7a2317929
      Exchange Online Plan 1    : 9aaf7827-d63c-4b61-89c3-182f06f82e5c
      Exchange Online Plan 2    : efb87545-963c-4e0d-99df-69c6916d9eb0
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#region ── Connect ─────────────────────────────────────────────────────────────

Write-Host "`n=== Entra Identity Group Provisioning ===" -ForegroundColor Cyan

$ExistingCtx = Get-MgContext
if (-not $ExistingCtx -or $ExistingCtx.Scopes -notcontains "Group.ReadWrite.All") {
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read" -NoWelcome
}

$CurrentUser = Get-MgUser -UserId (Get-MgContext).Account
$OwnerRef    = "https://graph.microsoft.com/v1.0/users/$($CurrentUser.Id)"

Write-Host "Owner: $($CurrentUser.DisplayName) ($($CurrentUser.UserPrincipalName))" -ForegroundColor Green

# ── Optional: add a second owner ───────────────────────────────────────────
# Uncomment the two lines below and set the UPN to add a second group owner.
# Suggested: a break-glass admin account or your team's shared identity account.
#
# $SecondOwnerUPN = "admin@yourdomain.com"
# $SecondOwner    = Get-MgUser -UserId $SecondOwnerUPN

#endregion

#region ── Group definitions ──────────────────────────────────────────────────

$Groups = @(

    # ══════════════════════════════════════════════════════════════════════════
    # CONDITIONAL ACCESS POLICY (CAP) GROUPS
    # All assigned — membership is intentionally manual for CAP exclusion groups.
    # Never use dynamic rules for CAP exclusion; manual curation is required.
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Entra-AUG-CAP-BreakglassAccounts"
        Description = "Emergency break-glass accounts excluded from ALL Conditional Access policies. One group only — tightly controlled. Members: two cloud-only admin accounts, no MFA, monitored via alert."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-GlobalExclusions"
        Description = "Users permanently excluded from standard CA policies — automation accounts, service principals, legacy integration accounts."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-GuestExclusions"
        Description = "Guest users excluded from specific CA policies where guest-specific policies are applied instead."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-ServiceAccounts"
        Description = "Service accounts excluded from MFA and device compliance CA policies. Use alongside SG-NHI-AUG-ServiceAccounts-All."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-AgentAdmins"
        Description = "Admin identities managing Copilot/AI agent platforms — scoped CA policy separate from standard admin policy."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-AgentUsers"
        Description = "End users accessing AI agent applications — targeted CA policy for agent app registration."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-AzureDevOpsUsers"
        Description = "DevOps users requiring specific CA policy for PAT authentication and pipeline sign-in conditions."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-TravelingUsers"
        Description = "Users permitted to authenticate from locations outside defined named locations."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-NamedLocations-TrustedUsers"
        Description = "Users allowed to authenticate from specific trusted named locations defined in Entra CA."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-TokenProtection-Scoped"
        Description = "Users enrolled in Conditional Access token binding / token protection policy."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-PhishingResistantMFA-Required"
        Description = "Users required to authenticate using phishing-resistant MFA only (FIDO2 passkey or Windows Hello for Business)."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-CAP-DeviceCompliance-Excluded"
        Description = "Short-term exclusion from device compliance CA policy. Requires documented approval. Review membership weekly."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-ADG-CAP-DeviceExclusions"
        Description = "Specific devices excluded from device-based Conditional Access policies."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-ADG-CAP-MobileDeviceExclusions"
        Description = "Mobile devices excluded from mobile-specific Conditional Access policies."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══════════════════════════════════════════════════════════════════════════
    # CAP — DYNAMIC GROUPS
    # These are safe to make dynamic as they target identity/licence attributes,
    # not CAP exclusion logic.
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Entra-DUG-CAP-TeamsRoomDevices"
        Description = "Dynamic — Teams Room system accounts across all Teams Rooms SKUs. Excluded from user-facing CA policies."
        Type        = "Dynamic"
        # Targets accounts with any of the three Teams Rooms service plans:
        #   8081ca9c-188c-4b49-a8e5-c23b5e9463a8  — Microsoft Teams Rooms Pro
        #   ec17f317-f4bc-451e-b2da-0167e5c260f9  — Microsoft Teams Rooms Basic
        #   92c6b761-01de-457a-9dd9-793a975238f7  — Microsoft Teams Rooms Standard (legacy)
        # All three are included so the group remains accurate regardless of which SKU
        # has been assigned. capabilityStatus eq Enabled excludes suspended licence seats.
        Rule        = '((user.assignedPlans -any (assignedPlan.servicePlanId -eq "8081ca9c-188c-4b49-a8e5-c23b5e9463a8" -and assignedPlan.capabilityStatus -eq "Enabled")) -or (user.assignedPlans -any (assignedPlan.servicePlanId -eq "ec17f317-f4bc-451e-b2da-0167e5c260f9" -and assignedPlan.capabilityStatus -eq "Enabled")) -or (user.assignedPlans -any (assignedPlan.servicePlanId -eq "92c6b761-01de-457a-9dd9-793a975238f7" -and assignedPlan.capabilityStatus -eq "Enabled")))'
    }

    # ══════════════════════════════════════════════════════════════════════════
    # LICENCE GROUPS — DYNAMIC
    # Used to scope CA policies and features to users who hold specific licences.
    # Rules target service plan GUIDs which are stable across SKU bundles
    # (e.g. P1 is included in M365 E3, M365 BP, and standalone AAD P1).
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Entra-DUG-License-P1InternalUsers"
        Description = "Dynamic — all internal (Member) users with Entra ID P1 licence assigned and active. Used to scope P1 features like CA and SSPR."
        Type        = "Dynamic"
        # Service plan GUID: 41781fb2-bc02-4b7c-bd55-b576c07bb09f (AAD_PREMIUM / Entra P1)
        # -and userType eq Member excludes guests from this group.
        # capabilityStatus eq Enabled excludes suspended/deprovisioned licence seats.
        Rule        = '(user.assignedPlans -any (assignedPlan.servicePlanId -eq "41781fb2-bc02-4b7c-bd55-b576c07bb09f" -and assignedPlan.capabilityStatus -eq "Enabled")) -and (user.userType -eq "Member")'
    }
    @{
        Name        = "SG-Entra-DUG-License-P2InternalUsers"
        Description = "Dynamic — all internal (Member) users with Entra ID P2 licence assigned and active. Used to scope PIM, Identity Protection, and Access Reviews."
        Type        = "Dynamic"
        # Service plan GUID: eec0eb4f-6444-4f95-aba0-50c24d67f998 (AAD_PREMIUM_P2 / Entra P2)
        Rule        = '(user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" -and assignedPlan.capabilityStatus -eq "Enabled")) -and (user.userType -eq "Member")'
    }
    @{
        Name        = "SG-Entra-DUG-License-TeamsRooms"
        Description = "Dynamic — all accounts with any Teams Rooms licence assigned and active. Covers Teams Rooms Pro, Basic, and Standard (legacy)."
        Type        = "Dynamic"
        # Same three-plan rule as SG-Entra-DUG-CAP-TeamsRoomDevices.
        #   8081ca9c-188c-4b49-a8e5-c23b5e9463a8  — Microsoft Teams Rooms Pro
        #   ec17f317-f4bc-451e-b2da-0167e5c260f9  — Microsoft Teams Rooms Basic
        #   92c6b761-01de-457a-9dd9-793a975238f7  — Microsoft Teams Rooms Standard (legacy)
        Rule        = '((user.assignedPlans -any (assignedPlan.servicePlanId -eq "8081ca9c-188c-4b49-a8e5-c23b5e9463a8" -and assignedPlan.capabilityStatus -eq "Enabled")) -or (user.assignedPlans -any (assignedPlan.servicePlanId -eq "ec17f317-f4bc-451e-b2da-0167e5c260f9" -and assignedPlan.capabilityStatus -eq "Enabled")) -or (user.assignedPlans -any (assignedPlan.servicePlanId -eq "92c6b761-01de-457a-9dd9-793a975238f7" -and assignedPlan.capabilityStatus -eq "Enabled")))'
    }

    # ══════════════════════════════════════════════════════════════════════════
    # LICENCE GROUPS — ASSIGNED (GROUP-BASED LICENSING)
    #
    # These groups have a Microsoft 365 or Entra licence assigned DIRECTLY to
    # the group in Entra. Adding a user to the group licenses them automatically;
    # removing them reclaims the licence.
    #
    # This is the OPPOSITE direction from the DUG-License-* groups above, which
    # detect users who already have a licence. Do not confuse the two:
    #   AUG-License-[SKU]          = assigns licence → user (group-based licensing)
    #   DUG-License-[SKU]Users     = detects already-licensed users (read-only scoping)
    #
    # After creating these groups, assign the licence product in:
    #   Entra admin centre > Billing > Licences > [Product] > Licensed groups > Assign
    #
    # Only create groups for licence SKUs active in your tenant.
    # Monitor the group's Licensing blade for assignment errors (e.g. no available seats).
    # Requires Entra ID P1 for group-based licensing to work.
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Entra-AUG-License-M365BP"
        Description = "Group-based licensing — Microsoft 365 Business Premium. Add users to this group to assign an M365 Business Premium licence. Monitor the Licensing blade for assignment errors."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-License-M365E3"
        Description = "Group-based licensing — Microsoft 365 E3. Add users to this group to assign an M365 E3 licence. Monitor the Licensing blade for assignment errors."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-License-M365E5"
        Description = "Group-based licensing — Microsoft 365 E5. Add users to this group to assign an M365 E5 licence. Monitor the Licensing blade for assignment errors."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-License-IntuneP1"
        Description = "Group-based licensing — Microsoft Intune Plan 1 (standalone). Add users to this group to assign a standalone Intune licence."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-License-EntraP2"
        Description = "Group-based licensing — Entra ID P2 (standalone). Add users to this group to assign a standalone Entra ID P2 licence for PIM, Identity Protection, and Access Reviews."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══════════════════════════════════════════════════════════════════════════
    # AUTHENTICATION METHOD GROUPS — ASSIGNED
    # These scope the Authentication Methods policy in Entra.
    # Navigate to: Entra portal > Protection > Authentication methods > [Method]
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Entra-AUG-MFA-AuthPasskey"
        Description = "Users enabled for FIDO2 passkey authentication. Assign in Authentication methods > FIDO2 security key > Include groups."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-MFA-AuthEAM"
        Description = "Users enabled for External Authentication Method (third-party MFA provider). Assign in Authentication methods > External auth method."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-MFA-AuthSMS"
        Description = "Users permitted to use SMS OTP as an MFA method. Assign in Authentication methods > SMS > Include groups."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-MFA-PasskeyPilotUsers"
        Description = "Pilot group for FIDO2 passkey rollout. Staged before full SG-Entra-AUG-MFA-AuthPasskey deployment."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-SSPR-EnabledUsers"
        Description = "Users enabled for Self-Service Password Reset. Assign in Entra > Protection > Password reset > Selected group."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══════════════════════════════════════════════════════════════════════════
    # DYNAMIC IDENTITY & LIFECYCLE GROUPS
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Entra-DUG-Admins-AllAdminUsers"
        Description = "Dynamic — all user accounts whose UPN starts with your admin account prefix. Used for targeting admin-specific CA policies and monitoring."
        Type        = "Dynamic"
        # CUSTOMISE: Replace 'adm-' with your admin account UPN prefix convention.
        # Common patterns: adm-, admin-, priv-, pa-, svc-
        # Alternative: use an extensionAttribute set on admin accounts during provisioning:
        #   (user.extensionAttribute1 -eq "AdminAccount")
        # Do NOT use jobTitle contains "Admin" — too broad and unreliable.
        Rule        = '(user.userPrincipalName -startsWith "adm-")'
    }
    @{
        Name        = "SG-Entra-DUG-Lifecycle-DisabledUsers"
        Description = "Dynamic — all accounts where accountEnabled is false. Useful for offboarding monitoring, licence reclamation checks, and cleanup workflows."
        Type        = "Dynamic"
        # Targets all disabled accounts regardless of type (member or guest).
        # Add -and (user.userType -eq "Member") to exclude disabled guests if needed.
        Rule        = '(user.accountEnabled -eq false)'
    }
    @{
        Name        = "SG-Entra-DUG-DFO-AllInternalUsers"
        Description = "Dynamic — all enabled internal Member accounts. Used to scope Defender for Office 365 policies to all internal users."
        Type        = "Dynamic"
        # Targets enabled internal users only — excludes guests and disabled accounts.
        # Add a department or licence filter if you need to scope DFO policies more narrowly.
        Rule        = '(user.userType -eq "Member") -and (user.accountEnabled -eq true)'
    }
    @{
        Name        = "SG-Entra-DUG-Identity-GuestUsers"
        Description = "Dynamic — all B2B guest users in the tenant regardless of invite state. Used to scope guest-specific CA and access policies."
        Type        = "Dynamic"
        # userType eq Guest captures all B2B collaboration users.
        # To also capture B2B Direct Connect users, no additional rule change is needed —
        # they appear as guests in Entra. Internal guest accounts (userType Member but
        # onPremisesUserPrincipalName differs) are NOT captured by this rule.
        Rule        = '(user.userType -eq "Guest")'
    }

    # ══════════════════════════════════════════════════════════════════════════
    # IDENTITY GOVERNANCE & SELF-SERVICE — ASSIGNED
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Entra-AUG-Identity-M365GroupCreators"
        Description = "Users permitted to create Microsoft 365 Groups (Teams, SharePoint sites, Planner). Restrict this to prevent group sprawl. Assign in Entra > Groups > Settings > Restrict group creation."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-Identity-RestrictedGuests"
        Description = "Guest users assigned the restricted permissions profile — cannot see directory, other users, or groups. Assign in Entra > External Identities > External collaboration settings."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-SelfService-AppUsers"
        Description = "Users enabled for self-service application access requests via My Apps portal."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Entra-AUG-SelfService-GroupUsers"
        Description = "Users enabled for self-service group management via My Groups / My Access portal."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══════════════════════════════════════════════════════════════════════════
    # APP-SPECIFIC ACCESS — ASSIGNED TEMPLATE
    # Duplicate and rename for each enterprise application that needs group-based
    # access control. Use SG-Entra-AUG-App-[AppName]-Users naming.
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Entra-AUG-App-Template-Users"
        Description = "TEMPLATE — rename to SG-Entra-AUG-App-[AppName]-Users before assigning. Users assigned access to a specific enterprise application via app assignment."
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
                DisplayName     = $g.Name
                Description     = $g.Description
                SecurityEnabled = $true
                MailEnabled     = $false
                MailNickname    = $g.Name -replace '[^a-zA-Z0-9]', ''
                GroupTypes      = @()
            }

            if ($g.Type -eq "Dynamic") {
                $Params.GroupTypes                    = @("DynamicMembership")
                $Params.MembershipRule                = $g.Rule
                $Params.MembershipRuleProcessingState = "On"
            }

            $NewGroup = New-MgGroup -BodyParameter $Params

            # Add owner separately — Owners@odata.bind is not reliably
            # serialised inside BodyParameter in SDK v2.
            New-MgGroupOwnerByRef -GroupId $NewGroup.Id -OdataId $OwnerRef -ErrorAction SilentlyContinue

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
Write-Host "  1. Assign licence products to SG-Entra-AUG-License-* groups:" -ForegroundColor White
Write-Host "     Entra admin centre > Billing > Licences > [Product] > Licensed groups > Assign" -ForegroundColor White
Write-Host "     Only assign the SKUs that are active in this tenant." -ForegroundColor Yellow
Write-Host "  2. Monitor the Licensing blade on each group for assignment errors" -ForegroundColor White
Write-Host "     (errors appear when no seats are available or a service plan conflicts)" -ForegroundColor White
Write-Host "  3. Customise SG-Entra-DUG-Admins-AllAdminUsers rule — replace 'adm-' with" -ForegroundColor White
Write-Host "     your admin account UPN prefix convention" -ForegroundColor White
Write-Host "  4. Configure dynamic group rules requiring Entra P1 before adding members" -ForegroundColor White

Disconnect-MgGraph | Out-Null

#endregion
