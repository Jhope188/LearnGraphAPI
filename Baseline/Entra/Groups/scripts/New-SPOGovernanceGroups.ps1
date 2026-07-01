#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Users

<#
.SYNOPSIS
    Creates SharePoint Online (SPO) access groups following the DG-SPO naming standard.

.DESCRIPTION
    Creates DG-SPO-[Dept]-[Project]-[Role] groups for SharePoint site access management.
    Each site gets three groups: Owners, Members, and Visitors.

    This script ships with Finance, HR, and Sales examples. Edit the $SiteMappings
    array to match your organisation's actual departments and site names.

    The signed-in user running this script is automatically set as group owner.
    To add a second owner, uncomment the $SecondOwnerUPN line below.

.PARAMETER WhatIf
    Run in preview mode — shows what would be created without making changes.

.EXAMPLE
    .\New-SPOGovernanceGroups.ps1
    .\New-SPOGovernanceGroups.ps1 -WhatIf

.NOTES
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Users
    Scopes:   Group.ReadWrite.All, User.Read

    After creation, assign the groups to SharePoint site permissions:
    SPO Admin Centre > Active sites > [Site] > Membership > [Role]
    
    Or via PnP PowerShell:
    Set-PnPGroupPermissions -Identity "DG-SPO-Finance-BudgetPlanning-Owners" -AddRole "Full Control"
    Set-PnPGroupPermissions -Identity "DG-SPO-Finance-BudgetPlanning-Members" -AddRole "Edit"
    Set-PnPGroupPermissions -Identity "DG-SPO-Finance-BudgetPlanning-Visitors" -AddRole "Read"
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#region ── Connect ─────────────────────────────────────────────────────────────

Write-Host "`n=== SharePoint Governance Group Provisioning ===" -ForegroundColor Cyan

$ExistingCtx = Get-MgContext
if (-not $ExistingCtx -or $ExistingCtx.Scopes -notcontains "Group.ReadWrite.All") {
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read" -NoWelcome
}

$CurrentUser = Get-MgUser -UserId (Get-MgContext).Account
$OwnerRef    = "https://graph.microsoft.com/v1.0/users/$($CurrentUser.Id)"

Write-Host "Owner: $($CurrentUser.DisplayName) ($($CurrentUser.UserPrincipalName))" -ForegroundColor Green

# ── Optional: add a second owner ───────────────────────────────────────────
# Uncomment the two lines below and set the UPN to add a second group owner.
# Suggested: your SharePoint administrator or department site owner.
#
# $SecondOwnerUPN = "spoadmin@yourdomain.com"
# $SecondOwner    = Get-MgUser -UserId $SecondOwnerUPN

#endregion

#region ── Site mappings ──────────────────────────────────────────────────────
#
# ── HOW TO CUSTOMISE ──────────────────────────────────────────────────────────
# Add or remove entries in $SiteMappings to match your organisation.
# Each entry defines:
#   Dept      — department short code   (e.g. Finance, HR, Sales, IT, Legal)
#   Project   — site/project name       (e.g. BudgetPlanning, Onboarding)
#   NoVisitors — set $true to skip creating a Visitors group (sensitive sites)
#
# The script generates DG-SPO-[Dept]-[Project]-Owners/Members/Visitors for each.
# ─────────────────────────────────────────────────────────────────────────────

$SiteMappings = @(

    # ── Finance ──────────────────────────────────────────────────────────────
    @{ Dept = "Finance"; Project = "BudgetPlanning";   NoVisitors = $false }
    @{ Dept = "Finance"; Project = "AuditReporting";   NoVisitors = $false }
    @{ Dept = "Finance"; Project = "Procurement";      NoVisitors = $false }

    # ── HR ───────────────────────────────────────────────────────────────────
    @{ Dept = "HR"; Project = "Onboarding";             NoVisitors = $false }
    @{ Dept = "HR"; Project = "PoliciesHandbook";       NoVisitors = $false }
    @{ Dept = "HR"; Project = "RecruitmentPipeline";    NoVisitors = $true  }
    # NoVisitors = $true on Recruitment — hiring data is sensitive

    # ── Sales ─────────────────────────────────────────────────────────────────
    @{ Dept = "Sales"; Project = "AccountPlanning";    NoVisitors = $false }
    @{ Dept = "Sales"; Project = "Proposals";          NoVisitors = $false }
    @{ Dept = "Sales"; Project = "CompetitiveIntel";   NoVisitors = $false }

    # ── Add your own departments below ────────────────────────────────────────
    # @{ Dept = "IT";     Project = "InfrastructureDocs"; NoVisitors = $false }
    # @{ Dept = "Legal";  Project = "ContractManagement"; NoVisitors = $true  }
    # @{ Dept = "Comms";  Project = "BrandAssets";        NoVisitors = $false }
)

#endregion

#region ── Build group list ───────────────────────────────────────────────────

$Groups = [System.Collections.Generic.List[hashtable]]::new()

foreach ($site in $SiteMappings) {
    $base = "DG-SPO-$($site.Dept)-$($site.Project)"

    $Groups.Add(@{
        Name        = "$base-Owners"
        Description = "Full control — site owners for $($site.Dept) / $($site.Project) SharePoint site."
    })
    $Groups.Add(@{
        Name        = "$base-Members"
        Description = "Edit access — active contributors for $($site.Dept) / $($site.Project) SharePoint site."
    })

    if (-not $site.NoVisitors) {
        $Groups.Add(@{
            Name        = "$base-Visitors"
            Description = "Read-only access — stakeholders for $($site.Dept) / $($site.Project) SharePoint site."
        })
    }
    else {
        Write-Host "  NOTE  Visitors group skipped for $base (NoVisitors = true)" -ForegroundColor DarkYellow
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

            $NewGroup = New-MgGroup -BodyParameter $Params

            # Add owner separately — Owners@odata.bind is not reliably
            # serialised inside BodyParameter in SDK v2.
            New-MgGroupOwnerByRef -GroupId $NewGroup.Id -OdataId $OwnerRef -ErrorAction SilentlyContinue

            # ── Optional second owner ─────────────────────────────────────
            # Uncomment below if $SecondOwner was set above
            #
            # New-MgGroupOwnerByRef -GroupId $NewGroup.Id -OdataId "https://graph.microsoft.com/v1.0/users/$($SecondOwner.Id)"

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
Write-Host "  1. Assign Owners groups to SPO sites with Full Control permission" -ForegroundColor White
Write-Host "  2. Assign Members groups with Edit permission" -ForegroundColor White
Write-Host "  3. Assign Visitors groups with Read permission" -ForegroundColor White
Write-Host "  4. Remove default 'Everyone except external users' from sites where needed" -ForegroundColor White

Disconnect-MgGraph | Out-Null

#endregion
