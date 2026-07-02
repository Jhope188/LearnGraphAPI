#Requires -Modules Microsoft.Graph.Groups

<#
.SYNOPSIS
    Renames existing CA-scoped Entra security groups to the new CAP naming standard.

.DESCRIPTION
    One-time migration script. For each group in the CA → CAP rename map:
      - If the OLD name exists in the tenant, renames it to the new CAP name.
      - If the OLD name is not found but the NEW name already exists, skips it.
      - If neither exists, logs it as NotFound (run New-EntraIdentityGroups.ps1 to create).

    This preserves all existing group members, owners, and policy assignments
    rather than creating empty replacement groups.

.PARAMETER WhatIf
    Preview mode — shows what would be renamed without making changes.

.EXAMPLE
    .\Rename-CAToCAPGroups.ps1
    .\Rename-CAToCAPGroups.ps1 -WhatIf

.NOTES
    Requires: Microsoft.Graph.Groups
    Scopes:   Group.ReadWrite.All
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#region ── Connect ─────────────────────────────────────────────────────────────

Write-Host "`n=== CA → CAP Group Rename Migration ===" -ForegroundColor Cyan

$ExistingCtx = Get-MgContext
if (-not $ExistingCtx -or $ExistingCtx.Scopes -notcontains "Group.ReadWrite.All") {
    Connect-MgGraph -Scopes "Group.ReadWrite.All" -NoWelcome
}

#endregion

#region ── Rename map ─────────────────────────────────────────────────────────

# OldName → NewName
$RenameMap = @(
    @{ Old = "SG-Entra-AUG-CA-BreakglassAccounts";          New = "SG-Entra-AUG-CAP-BreakglassAccounts" }
    @{ Old = "SG-Entra-AUG-CA-EmergencyAccess";             New = "SG-Entra-AUG-CAP-EmergencyAccess" }
    @{ Old = "SG-Entra-AUG-CA-GlobalExclusions";            New = "SG-Entra-AUG-CAP-GlobalExclusions" }
    @{ Old = "SG-Entra-AUG-CA-GuestExclusions";             New = "SG-Entra-AUG-CAP-GuestExclusions" }
    @{ Old = "SG-Entra-AUG-CA-ServiceAccounts";             New = "SG-Entra-AUG-CAP-ServiceAccounts" }
    @{ Old = "SG-Entra-AUG-CA-AgentAdmins";                 New = "SG-Entra-AUG-CAP-AgentAdmins" }
    @{ Old = "SG-Entra-AUG-CA-AgentUsers";                  New = "SG-Entra-AUG-CAP-AgentUsers" }
    @{ Old = "SG-Entra-AUG-CA-AzureDevOpsUsers";            New = "SG-Entra-AUG-CAP-AzureDevOpsUsers" }
    @{ Old = "SG-Entra-AUG-CA-TravelingUsers";              New = "SG-Entra-AUG-CAP-TravelingUsers" }
    @{ Old = "SG-Entra-AUG-CA-NamedLocations-TrustedUsers"; New = "SG-Entra-AUG-CAP-NamedLocations-TrustedUsers" }
    @{ Old = "SG-Entra-AUG-CA-TokenProtection-Scoped";      New = "SG-Entra-AUG-CAP-TokenProtection-Scoped" }
    @{ Old = "SG-Entra-AUG-CA-PhishingResistantMFA-Required"; New = "SG-Entra-AUG-CAP-PhishingResistantMFA-Required" }
    @{ Old = "SG-Entra-AUG-CA-DeviceCompliance-Excluded";   New = "SG-Entra-AUG-CAP-DeviceCompliance-Excluded" }
    @{ Old = "SG-Entra-ADG-CA-DeviceExclusions";            New = "SG-Entra-ADG-CAP-DeviceExclusions" }
    @{ Old = "SG-Entra-ADG-CA-MobileDeviceExclusions";      New = "SG-Entra-ADG-CAP-MobileDeviceExclusions" }
    @{ Old = "SG-Entra-DUG-CA-TeamsRoomDevices";            New = "SG-Entra-DUG-CAP-TeamsRoomDevices" }
)

#endregion

#region ── Rename loop ────────────────────────────────────────────────────────

$Results  = [System.Collections.Generic.List[PSObject]]::new()
$Renamed  = 0
$Skipped  = 0
$NotFound = 0
$Failed   = 0

foreach ($entry in $RenameMap) {

    $OldGroup = Get-MgGroup -Filter "displayName eq '$($entry.Old)'" -ErrorAction SilentlyContinue
    $NewGroup = Get-MgGroup -Filter "displayName eq '$($entry.New)'" -ErrorAction SilentlyContinue

    # Already renamed / new group already exists
    if ($NewGroup -and -not $OldGroup) {
        Write-Host "  SKIP  $($entry.New) — new name already exists" -ForegroundColor DarkYellow
        $Skipped++
        $Results.Add([PSCustomObject]@{ OldName = $entry.Old; NewName = $entry.New; Status = "Skipped — new name exists"; Id = $NewGroup.Id })
        continue
    }

    # Old group not found and new group doesn't exist either
    if (-not $OldGroup) {
        Write-Host "  MISS  $($entry.Old) — not found in tenant" -ForegroundColor DarkGray
        $NotFound++
        $Results.Add([PSCustomObject]@{ OldName = $entry.Old; NewName = $entry.New; Status = "NotFound — run New-EntraIdentityGroups.ps1"; Id = "" })
        continue
    }

    # Rename
    if ($PSCmdlet.ShouldProcess($entry.Old, "Rename to $($entry.New)")) {
        try {
            Update-MgGroup -GroupId $OldGroup.Id -DisplayName $entry.New -MailNickname ($entry.New -replace '[^a-zA-Z0-9]', '')
            Write-Host "  OK    $($entry.Old)  →  $($entry.New)" -ForegroundColor Green
            $Renamed++
            $Results.Add([PSCustomObject]@{ OldName = $entry.Old; NewName = $entry.New; Status = "Renamed"; Id = $OldGroup.Id })
        }
        catch {
            Write-Host "  FAIL  $($entry.Old) — $($_.Exception.Message)" -ForegroundColor Red
            $Failed++
            $Results.Add([PSCustomObject]@{ OldName = $entry.Old; NewName = $entry.New; Status = "Failed: $($_.Exception.Message)"; Id = $OldGroup.Id })
        }
    }
}

#endregion

#region ── Summary ────────────────────────────────────────────────────────────

Write-Host "`n─────────────────────────────────────────────────────" -ForegroundColor Cyan
Write-Host "  Renamed   : $Renamed"  -ForegroundColor Green
Write-Host "  Skipped   : $Skipped"  -ForegroundColor Yellow
Write-Host "  Not found : $NotFound" -ForegroundColor DarkGray
Write-Host "  Failed    : $Failed"   -ForegroundColor Red
Write-Host "─────────────────────────────────────────────────────`n" -ForegroundColor Cyan

$Results | Format-Table OldName, NewName, Status -AutoSize

Disconnect-MgGraph | Out-Null

#endregion
