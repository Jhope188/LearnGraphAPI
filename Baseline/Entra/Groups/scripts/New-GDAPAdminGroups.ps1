#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement

<#
.SYNOPSIS
    Creates GDAP role-assignable security groups for partner/MSP delegated access.

.DESCRIPTION
    Creates SG-Admin-AUG-GDAP-* groups following the M365 Group Naming Standard.
    All groups are created with IsAssignableToRole = true so they can be linked to
    Entra role assignments inside a GDAP relationship in Partner Center.

    Groups created:
      SG-Admin-AUG-GDAP-ApplicationAdministrator
      SG-Admin-AUG-GDAP-DirectoryWriters
      SG-Admin-AUG-GDAP-ExchangeAdministrator
      SG-Admin-AUG-GDAP-GroupsAdministrator
      SG-Admin-AUG-GDAP-HelpdeskAdministrator
      SG-Admin-AUG-GDAP-IntuneAdministrator
      SG-Admin-AUG-GDAP-PrivilegedRoleAdministrator
      SG-Admin-AUG-GDAP-SecurityAdministrator
      SG-Admin-AUG-GDAP-SharePointAdministrator
      SG-Admin-AUG-GDAP-TeamsAdministrator
      SG-Admin-AUG-GDAP-UserAdministrator

    The signed-in user running this script is automatically set as group owner.

.PARAMETER WhatIf
    Run in preview mode — shows what would be created without making changes.

.EXAMPLE
    .\New-GDAPAdminGroups.ps1
    .\New-GDAPAdminGroups.ps1 -WhatIf

.NOTES
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Users,
              Microsoft.Graph.Identity.DirectoryManagement
    Scopes:   Group.ReadWrite.All, RoleManagement.ReadWrite.Directory, User.Read

    IMPORTANT — Role-assignable groups:
      IsAssignableToRole = true is set at creation time and CANNOT be changed
      afterwards. These groups require Entra ID P2 and count against the tenant
      limit of 500 role-assignable groups per tenant.

    IMPORTANT — PrivilegedRoleAdministrator:
      This role grants the ability to assign any Entra role including Global Admin.
      Treat this group as Critical privilege. Restrict membership to named individuals
      with documented approval. Review membership monthly.

    IMPORTANT — GDAP group membership:
      Partner technicians must be members of these groups in the PARTNER TENANT,
      not this customer tenant. These groups are created here so they can be
      referenced in the GDAP role mapping in Partner Center.

    After running this script:
      1. In Partner Center, create or update the GDAP relationship for this customer.
      2. Map each group to its corresponding Entra role in the relationship.
      3. Add partner technicians to the appropriate groups in the PARTNER tenant.
      4. Audit active GDAP relationships and group membership quarterly.
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#region ── Connect ─────────────────────────────────────────────────────────────

Write-Host "`n=== GDAP Role-Assignable Group Provisioning ===" -ForegroundColor Cyan

$RequiredScopes = @("Group.ReadWrite.All", "RoleManagement.ReadWrite.Directory", "User.Read")

$ExistingCtx = Get-MgContext
$MissingScopes = $RequiredScopes | Where-Object { $ExistingCtx.Scopes -notcontains $_ }

if (-not $ExistingCtx -or $MissingScopes) {
    Connect-MgGraph -Scopes $RequiredScopes -NoWelcome
}

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

# Each entry maps directly to one Entra role.
# Privilege levels: Critical / High / Medium / Low — for documentation only,
# not enforced by this script.

$Groups = @(

    @{
        Name        = "SG-Admin-AUG-GDAP-ApplicationAdministrator"
        Description = "GDAP partner access — Application Administrator. Full control over app registrations and enterprise applications. Privilege: High. Review membership quarterly."
        EntraRole   = "Application Administrator"
        Privilege   = "High"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-DirectoryWriters"
        Description = "GDAP partner access — Directory Writers. Can write to most directory objects; does not grant role assignment. Privilege: Medium."
        EntraRole   = "Directory Writers"
        Privilege   = "Medium"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-ExchangeAdministrator"
        Description = "GDAP partner access — Exchange Administrator. Full control of Exchange Online mailboxes, connectors, and transport rules. Privilege: Medium."
        EntraRole   = "Exchange Administrator"
        Privilege   = "Medium"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-GroupsAdministrator"
        Description = "GDAP partner access — Groups Administrator. Can create and manage all group types; no access to group content or mailboxes. Privilege: Low."
        EntraRole   = "Groups Administrator"
        Privilege   = "Low"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-HelpdeskAdministrator"
        Description = "GDAP partner access — Helpdesk Administrator. Reset passwords and manage service requests for non-admin users only. Privilege: Low."
        EntraRole   = "Helpdesk Administrator"
        Privilege   = "Low"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-IntuneAdministrator"
        Description = "GDAP partner access — Intune Administrator. Full control of Intune — device configuration, compliance policies, app deployment. Privilege: Medium."
        EntraRole   = "Intune Administrator"
        Privilege   = "Medium"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-PrivilegedRoleAdministrator"
        Description = "GDAP partner access — Privileged Role Administrator. Can assign any Entra role including Global Administrator. CRITICAL — treat as equivalent to Global Admin. Restrict to named individuals with documented approval. Review monthly."
        EntraRole   = "Privileged Role Administrator"
        Privilege   = "Critical"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-SecurityAdministrator"
        Description = "GDAP partner access — Security Administrator. Full read/write access across Defender, Sentinel, Purview, and identity protection. Privilege: High. Review membership quarterly."
        EntraRole   = "Security Administrator"
        Privilege   = "High"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-SharePointAdministrator"
        Description = "GDAP partner access — SharePoint Administrator. Full control of SharePoint Online sites, settings, and OneDrive for Business. Privilege: Medium."
        EntraRole   = "SharePoint Administrator"
        Privilege   = "Medium"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-TeamsAdministrator"
        Description = "GDAP partner access — Teams Administrator. Full control of Teams policies, settings, and meeting configuration. Privilege: Medium."
        EntraRole   = "Teams Administrator"
        Privilege   = "Medium"
    }
    @{
        Name        = "SG-Admin-AUG-GDAP-UserAdministrator"
        Description = "GDAP partner access — User Administrator. Create and manage users and groups; reset passwords for non-admin users; manage licences. Privilege: Medium."
        EntraRole   = "User Administrator"
        Privilege   = "Medium"
    }
)

#endregion

#region ── Pre-fetch Entra role definitions ───────────────────────────────────

Write-Host "`nPre-fetching Entra role definitions..." -ForegroundColor Cyan

$RoleCache = @{}
$Groups | Select-Object -ExpandProperty EntraRole -Unique | ForEach-Object {
    $RoleDef = Get-MgRoleManagementDirectoryRoleDefinition `
        -Filter "displayName eq '$_'" -ErrorAction SilentlyContinue
    if ($RoleDef) {
        $RoleCache[$_] = $RoleDef.Id
        Write-Host "  FOUND  $_" -ForegroundColor DarkGreen
    } else {
        Write-Warning "  Role definition not found: $_"
    }
}

#endregion

#region ── Create groups ──────────────────────────────────────────────────────

$Results = [System.Collections.Generic.List[PSObject]]::new()
$Created = 0
$Skipped = 0
$Failed  = 0

foreach ($g in $Groups) {

    $Existing = Get-MgGroup -Filter "displayName eq '$($g.Name)'" -ErrorAction SilentlyContinue

    if ($Existing) {
        Write-Host "  SKIP  $($g.Name) — group already exists, checking role assignment..." -ForegroundColor DarkYellow
        $Skipped++

        # Check whether the role is already assigned to this group
        $RoleDefId       = $RoleCache[$g.EntraRole]
        $ExistingRoleAssigned = $false
        $ExistingStatus  = "Skipped — already exists"

        if ($RoleDefId) {
            $ExistingAssignment = Get-MgRoleManagementDirectoryRoleAssignment `
                -Filter "principalId eq '$($Existing.Id)' and roleDefinitionId eq '$RoleDefId'" `
                -ErrorAction SilentlyContinue

            if ($ExistingAssignment) {
                Write-Host "  ROLE  $($g.EntraRole) already assigned" -ForegroundColor DarkCyan
                $ExistingStatus = "Skipped — already exists + role already assigned"
            } else {
                try {
                    New-MgRoleManagementDirectoryRoleAssignment `
                        -PrincipalId      $Existing.Id `
                        -RoleDefinitionId $RoleDefId `
                        -DirectoryScopeId "/" | Out-Null
                    $ExistingRoleAssigned = $true
                    Write-Host "  ROLE  $($g.EntraRole) assigned to existing group" -ForegroundColor Cyan
                    $ExistingStatus = "Skipped — already exists + role now assigned"
                } catch {
                    Write-Warning "  Role assignment failed for existing group $($g.Name): $($_.Exception.Message)"
                    $ExistingStatus = "Skipped — already exists (role assignment failed)"
                }
            }
        }

        $Results.Add([PSCustomObject]@{
            Name      = $g.Name
            Role      = $g.EntraRole
            Privilege = $g.Privilege
            Status    = $ExistingStatus
            Id        = $Existing.Id
        })
        continue
    }

    if ($PSCmdlet.ShouldProcess($g.Name, "Create role-assignable security group")) {
        try {
            $Params = @{
                DisplayName         = $g.Name
                Description         = $g.Description
                SecurityEnabled     = $true
                MailEnabled         = $false
                MailNickname        = $g.Name -replace '[^a-zA-Z0-9]', ''
                GroupTypes          = @()
                # IsAssignableToRole must be set at creation — cannot be changed later.
                # Required for GDAP role mapping in Partner Center.
                # Requires Entra ID P2 and RoleManagement.ReadWrite.Directory scope.
                IsAssignableToRole  = $true
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

            # ── Assign Entra role to group ────────────────────────────────
            $RoleAssigned = $false
            $RoleDefId    = $RoleCache[$g.EntraRole]
            if ($RoleDefId) {
                try {
                    New-MgRoleManagementDirectoryRoleAssignment `
                        -PrincipalId      $NewGroup.Id `
                        -RoleDefinitionId $RoleDefId `
                        -DirectoryScopeId "/" | Out-Null
                    $RoleAssigned = $true
                    Write-Host "  ROLE  $($g.EntraRole)" -ForegroundColor Cyan
                } catch {
                    Write-Warning "  Role assignment failed for $($g.Name): $($_.Exception.Message)"
                }
            } else {
                Write-Warning "  Role definition not found for '$($g.EntraRole)' — role not assigned"
            }

            $PrivColour = switch ($g.Privilege) {
                "Critical" { "Magenta" }
                "High"     { "Red" }
                "Medium"   { "Yellow" }
                "Low"      { "Green" }
                default    { "White" }
            }

            Write-Host "  OK    $($g.Name) " -ForegroundColor Green -NoNewline
            Write-Host "[$($g.Privilege)]" -ForegroundColor $PrivColour

            $Created++
            $Results.Add([PSCustomObject]@{
                Name      = $g.Name
                Role      = $g.EntraRole
                Privilege = $g.Privilege
                Status    = if ($RoleAssigned) { "Created + Role Assigned" } else { "Created (role not assigned)" }
                Id        = $NewGroup.Id
            })
        }
        catch {
            Write-Host "  FAIL  $($g.Name) — $($_.Exception.Message)" -ForegroundColor Red
            $Failed++
            $Results.Add([PSCustomObject]@{
                Name      = $g.Name
                Role      = $g.EntraRole
                Privilege = $g.Privilege
                Status    = "Failed: $($_.Exception.Message)"
                Id        = ""
            })
        }
    }
}

#endregion

#region ── Summary ────────────────────────────────────────────────────────────

Write-Host "`n─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Created : $Created" -ForegroundColor Green
Write-Host "  Skipped : $Skipped" -ForegroundColor Yellow
Write-Host "  Failed  : $Failed"  -ForegroundColor Red
Write-Host "─────────────────────────────────────────────────────────────`n" -ForegroundColor Cyan

$Results | Format-Table Name, Role, Privilege, Status -AutoSize

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Entra roles have been assigned to each group by this script" -ForegroundColor White
Write-Host "  2. In Partner Center, create or update the GDAP relationship for this customer" -ForegroundColor White
Write-Host "  3. Map each SG-Admin-AUG-GDAP-* group to its Entra role in the relationship" -ForegroundColor White
Write-Host "  4. Add partner technicians to the appropriate groups in the PARTNER tenant" -ForegroundColor White
Write-Host "  5. Do NOT add members in this customer tenant — groups are empty here" -ForegroundColor Yellow
Write-Host "  6. Restrict SG-Admin-AUG-GDAP-PrivilegedRoleAdministrator to named individuals" -ForegroundColor Magenta
Write-Host "     with individual approval — this role can elevate to Global Admin" -ForegroundColor Magenta
Write-Host "  7. Audit GDAP relationships and group membership quarterly in Partner Center" -ForegroundColor White

Disconnect-MgGraph | Out-Null

#endregion
