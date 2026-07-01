#Requires -Modules Microsoft.Graph.Groups, Microsoft.Graph.Users

<#
.SYNOPSIS
    Creates the standard Intune & device security groups for an M365 tenant.

.DESCRIPTION
    Creates all SG-Intune-* groups following the M365 Group Naming Standard.
    Covers: Windows, macOS, AVD, Windows 365, Autopilot, and WHfB groups,
    each with Pilot, Prod, and Exclusion rings where applicable.

    Every dynamic (DDG) group includes its full membership rule with inline
    documentation. Device filter expressions are included in comments for groups
    that are better targeted via Intune device filters than dynamic group rules.

    The signed-in user running this script is automatically set as group owner.
    To add a second owner, uncomment the $SecondOwnerUPN line below.

.PARAMETER WhatIf
    Run in preview mode — shows what would be created without making changes.

.EXAMPLE
    .\New-IntuneDeviceGroups.ps1
    .\New-IntuneDeviceGroups.ps1 -WhatIf

.NOTES
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Users
    Scopes:   Group.ReadWrite.All, User.Read

    ── Dynamic group rules vs Intune device filters ──────────────────────────
    Dynamic device groups (DDG) use Entra membership rules evaluated against
    device object attributes synced into Entra ID.

    Intune device filters are evaluated at policy assignment time against
    real-time device properties — they are faster, more granular, and do not
    require P1. Use filters for:
      • OS version targeting (e.g. Windows 11 only, macOS 14+)
      • Manufacturer / model targeting
      • Ownership type (Corporate vs Personal)
      • Intune compliance state at assignment time

    Device filter expressions are included as comments below each dynamic group
    so you can apply the same targeting logic in Intune policy assignments.

    ── device.deviceOSType values in Entra ──────────────────────────────────
    Windows (Intune MDM-enrolled)  : "Windows"
    macOS (Intune MDM-enrolled)    : "MacMDM"
    iOS/iPadOS                     : "iPhone" / "iPad"  (shows as "iPhone" for both in rules)
    Android                        : "AndroidForWork" (Android Enterprise) or "Android"
    Windows Server (Hybrid joined) : "Windows"
    Linux                          : "Linux"

    ── device.enrollmentType values ─────────────────────────────────────────
    Intune MDM enrolled            : "AzureMDM"
    Hybrid Entra joined            : "Hybrid"
    Entra joined (no MDM)          : "" (empty)

    ── Autopilot device.devicePhysicalIds filter ─────────────────────────────
    [ZTDId]        : device is registered in Windows Autopilot
    [OrderId]      : device has an Autopilot order / group tag
    [ZTDID]:{guid} : matches a specific Autopilot profile GUID
#>

[CmdletBinding(SupportsShouldProcess)]
param()

#region ── Connect ─────────────────────────────────────────────────────────────

Write-Host "`n=== Intune & Device Group Provisioning ===" -ForegroundColor Cyan

$ExistingCtx = Get-MgContext
if (-not $ExistingCtx -or $ExistingCtx.Scopes -notcontains "Group.ReadWrite.All") {
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read" -NoWelcome
}

$CurrentUser = Get-MgUser -UserId (Get-MgContext).Account
$OwnerRef    = "https://graph.microsoft.com/v1.0/users/$($CurrentUser.Id)"

Write-Host "Owner: $($CurrentUser.DisplayName) ($($CurrentUser.UserPrincipalName))" -ForegroundColor Green

# ── Optional: add a second owner ───────────────────────────────────────────
# Uncomment the two lines below and set the UPN to add a second group owner.
# Suggested: your Intune / endpoint administrator account.
#
# $SecondOwnerUPN = "intuneadmin@yourdomain.com"
# $SecondOwner    = Get-MgUser -UserId $SecondOwnerUPN

#endregion

#region ── Group definitions ──────────────────────────────────────────────────

$Groups = @(

    # ══════════════════════════════════════════════════════════════════════════
    # WINDOWS — ASSIGNED RINGS
    # Pilot and Prod device rings are Assigned so you control promotion manually.
    # Add devices to Pilot first, validate, then promote to Prod.
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Intune-ADG-WIN-Pilot-Devices"
        Description = "Windows devices in the Intune pilot ring. Target new configuration profiles, compliance policies, and apps here before Prod rollout."
        Type        = "Assigned"
        Rule        = $null
        # ── Intune device filter equivalent ──────────────────────────────────
        # (device.operatingSystem -eq "Windows") and (device.deviceOwnership -eq "Company")
        # Apply this filter on Intune policy assignments to further restrict to corporate-owned.
    }
    @{
        Name        = "SG-Intune-AUG-WIN-Pilot-Users"
        Description = "Users in the Windows Intune pilot ring. Pair with SG-Intune-ADG-WIN-Pilot-Devices for user-targeted policies."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-ADG-WIN-Prod-Devices"
        Description = "Windows devices in the production Intune ring. Policies deploy here after successful pilot validation."
        Type        = "Assigned"
        Rule        = $null
        # ── Intune device filter equivalent ──────────────────────────────────
        # (device.operatingSystem -eq "Windows") and (device.deviceOwnership -eq "Company")
    }
    @{
        Name        = "SG-Intune-AUG-WIN-Prod-Users"
        Description = "Users in the Windows production ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-ADG-WIN-Exclusion-Devices"
        Description = "Windows devices excluded from standard Intune policies. Requires documented justification per device. Review membership quarterly."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-ADG-WIN-Exclusion-USBDevices"
        Description = "Windows devices excluded from the USB restriction policy — lab machines, AV/recording equipment, specialised hardware."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-WIN-DeviceAdmins"
        Description = "Users who are local device administrators on managed Windows endpoints. Assigned via Intune Account protection > Local users and groups profile."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-WIN-MultiAdminApprovers"
        Description = "Approvers for Intune multi-admin approval (MAA) workflows — retire, wipe, delete device actions."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══════════════════════════════════════════════════════════════════════════
    # WINDOWS — DYNAMIC GROUPS
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Intune-DDG-WIN-Prod-AllDevices"
        Description = "Dynamic — all Windows devices currently enrolled in Intune MDM. Broad catch-all; use pilot/prod assigned rings for policy targeting."
        Type        = "Dynamic"
        # device.deviceOSType eq "Windows" matches all Windows 10/11 MDM-enrolled devices.
        # device.managementType eq "MDM" ensures only Intune-managed devices are included;
        # excludes Entra-joined-only (no Intune) and hybrid-joined devices with no MDM.
        # Remove the managementType clause if you also want hybrid joined / co-managed devices.
        Rule        = '(device.deviceOSType -eq "Windows") -and (device.managementType -eq "MDM")'
    }
    @{
        Name        = "SG-Intune-DDG-WIN-Prod-HotpatchDevices"
        Description = "Dynamic — Windows devices eligible for Hotpatch (no-reboot security updates). Requires Windows 11 22H2+ Enterprise with Azure Arc or Intune management."
        Type        = "Dynamic"
        # Targets Windows MDM-enrolled devices.
        # Hotpatch eligibility is enforced by the Hotpatch policy itself — this group
        # provides the assignment scope. Use an Intune device filter to further restrict
        # to Windows 11 only at assignment time (filter shown below).
        # Intune device filter:
        #   (device.operatingSystem -eq "Windows") and
        #   (device.osVersion -startsWith "10.0.22") and
        #   (device.deviceOwnership -eq "Company")
        Rule        = '(device.deviceOSType -eq "Windows") -and (device.managementType -eq "MDM")'
    }
    @{
        Name        = "SG-Intune-DDG-WIN-CorporateOwned"
        Description = "Dynamic — all corporate-owned Windows devices enrolled in Intune. Excludes BYOD (personal) Windows devices."
        Type        = "Dynamic"
        # device.deviceOwnership eq "Company" matches corporate devices.
        # "Personal" matches BYOD. "Unknown" matches devices not yet categorised.
        Rule        = '(device.deviceOSType -eq "Windows") -and (device.deviceOwnership -eq "Company") -and (device.managementType -eq "MDM")'
    }

    # ══════════════════════════════════════════════════════════════════════════
    # AUTOPILOT
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Intune-DDG-WIN-Autopilot-AllDevices"
        Description = "Dynamic — all Windows devices registered in Windows Autopilot. Used to target Autopilot Enrollment Status Page (ESP) and deployment profiles."
        Type        = "Dynamic"
        # device.devicePhysicalIds -any _ -contains "[ZTDId]" matches devices with
        # an Autopilot hardware hash registered in the Autopilot service.
        # This is the standard Microsoft-recommended rule for Autopilot groups.
        # The square brackets in [ZTDId] are literal — include them in the rule.
        Rule        = '(device.devicePhysicalIds -any _ -contains "[ZTDId]")'
    }
    @{
        Name        = "SG-Intune-ADG-WIN-Autopilot-Pilot"
        Description = "Assigned — subset of Autopilot devices in the pilot deployment profile. Manually add devices to test new ESP or OOBE configuration before Prod."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-DDG-WIN-Autopilot-GroupTag"
        Description = "Dynamic — Autopilot devices with a specific Autopilot group tag. Edit the rule to match your group tag value."
        Type        = "Dynamic"
        # device.devicePhysicalIds -any _ -eq "[OrderId]:YOUR_GROUP_TAG" matches devices
        # with a specific Autopilot group tag (OrderId). Replace YOUR_GROUP_TAG with your value.
        # Example: "[OrderId]:HQ-Corporate" or "[OrderId]:Kiosk"
        # CUSTOMISE: Replace YOUR_GROUP_TAG with your actual Autopilot group tag.
        Rule        = '(device.devicePhysicalIds -any _ -eq "[OrderId]:YOUR_GROUP_TAG")'
    }
    @{
        Name        = "SG-Intune-ADG-WIN-Autopilot-Exclusions"
        Description = "Assigned — Autopilot-registered devices excluded from the standard deployment profile. Add exceptions here."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══════════════════════════════════════════════════════════════════════════
    # WINDOWS HELLO FOR BUSINESS
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Intune-ADG-WIN-WHfB-PilotDevices"
        Description = "Assigned — Windows devices in the WHfB pilot ring. Target the WHfB provisioning configuration profile (Identity Protection) here first."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-ADG-WIN-WHfB-ProdDevices"
        Description = "Assigned — Windows devices in the WHfB production ring. Full WHfB rollout via Intune Identity Protection profile."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-WIN-WHfB-ExcludedUsers"
        Description = "Assigned — users excluded from WHfB enforcement. Kiosk accounts, shared devices, service accounts without interactive sign-in."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══════════════════════════════════════════════════════════════════════════
    # macOS
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Intune-ADG-MAC-Pilot-Devices"
        Description = "Assigned — macOS devices in the Intune pilot ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-MAC-Pilot-Users"
        Description = "Assigned — users in the macOS Intune pilot ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-ADG-MAC-Prod-Devices"
        Description = "Assigned — macOS devices in the production Intune ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-MAC-Prod-Users"
        Description = "Assigned — users in the macOS production ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-ADG-MAC-Exclusion-Devices"
        Description = "Assigned — macOS devices excluded from standard Intune policies."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-DDG-MAC-AllDevices"
        Description = "Dynamic — all macOS devices enrolled in Intune MDM."
        Type        = "Dynamic"
        # device.deviceOSType eq "MacMDM" matches macOS devices enrolled via Intune MDM.
        # Note: "MacMDM" is the correct value — not "macOS" or "Mac".
        # device.managementType eq "MDM" further restricts to MDM-managed only
        # (excludes devices registered but not MDM-enrolled).
        Rule        = '(device.deviceOSType -eq "MacMDM") -and (device.managementType -eq "MDM")'
    }
    @{
        Name        = "SG-Intune-DDG-MAC-CorporateOwned"
        Description = "Dynamic — corporate-owned macOS devices enrolled in Intune. Excludes BYOD / personal macOS."
        Type        = "Dynamic"
        # Combines OS type, ownership, and MDM management filters.
        # Intune device filter equivalent for additional targeting:
        #   (device.operatingSystem -eq "macOS") and (device.deviceOwnership -eq "Company")
        Rule        = '(device.deviceOSType -eq "MacMDM") -and (device.deviceOwnership -eq "Company") -and (device.managementType -eq "MDM")'
    }

    # ══════════════════════════════════════════════════════════════════════════
    # AZURE VIRTUAL DESKTOP
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Intune-ADG-AVD-Pilot-Devices"
        Description = "Assigned — AVD session host VMs in the pilot ring. Target pilot configuration profiles here."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-AVD-Pilot-Users"
        Description = "Assigned — users in the AVD pilot ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-ADG-AVD-Prod-Devices"
        Description = "Assigned — AVD session host VMs in the production ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-AVD-Prod-Users"
        Description = "Assigned — users accessing the AVD production environment."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-AVD-Prod-ExternalUsers"
        Description = "Assigned — external or vendor users accessing AVD. May require a dedicated CA policy with named location conditions."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-DDG-AVD-AllHostDevices"
        Description = "Dynamic — all Azure Virtual Desktop session host VMs enrolled in Intune."
        Type        = "Dynamic"
        # AVD session hosts run Windows 10/11 Enterprise multi-session (OS SKU: ServerRdsh).
        #
        # INTUNE DEVICE FILTER (recommended for policy assignments):
        #   (device.operatingSystemSKU -eq "ServerRdsh")
        #   This is definitive — ServerRdsh is exclusive to AVD multi-session hosts.
        #   Use this filter on Intune policy assignments rather than targeting this group.
        #
        # DYNAMIC GROUP RULE NOTE: operatingSystemSKU is not available as a dynamic group
        # membership rule property in Entra. For the group rule, use one of:
        #
        # Option 1 (RECOMMENDED) — Enrollment profile name
        #   Set a dedicated Intune enrollment profile prefixed "AVD" (e.g. "AVD-SessionHost-Prod").
        #   Rule: '(device.enrollmentProfileName -startsWith "AVD") -and (device.managementType -eq "MDM")'
        #
        # Option 2 — extensionAttribute set at VM provisioning
        #   Set extensionAttribute2 = "AVD" on session host device objects via Graph API.
        #   Rule: '(device.extensionAttribute2 -eq "AVD") -and (device.managementType -eq "MDM")'
        #
        # CUSTOMISE: Switch to Option 1 if you use a dedicated AVD enrollment profile.
        Rule        = '(device.deviceOSType -eq "Windows") -and (device.managementType -eq "MDM") -and (device.extensionAttribute2 -eq "AVD")'
    }
    @{
        Name        = "SG-Intune-ADG-AVD-Exclusion-Devices"
        Description = "Assigned — AVD devices excluded from standard Intune policy assignments."
        Type        = "Assigned"
        Rule        = $null
    }

    # ══════════════════════════════════════════════════════════════════════════
    # WINDOWS 365
    # ══════════════════════════════════════════════════════════════════════════

    @{
        Name        = "SG-Intune-ADG-W365-Pilot-Devices"
        Description = "Assigned — Windows 365 Cloud PCs in the pilot ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-W365-Pilot-Users"
        Description = "Assigned — users in the Windows 365 pilot ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-ADG-W365-Prod-Devices"
        Description = "Assigned — Windows 365 Cloud PCs in the production ring."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-AUG-W365-Prod-Users"
        Description = "Assigned — users accessing Windows 365 production Cloud PCs."
        Type        = "Assigned"
        Rule        = $null
    }
    @{
        Name        = "SG-Intune-DDG-W365-AllCloudPCs"
        Description = "Dynamic — all Windows 365 Cloud PC devices enrolled in Intune."
        Type        = "Dynamic"
        # device.model is NOT a valid Entra dynamic membership rule property — it is only
        # available as an Intune device filter. Dynamic rules must use supported properties.
        #
        # RECOMMENDED — set extensionAttribute1 = 'CloudPC' on Cloud PC device objects
        # at provisioning time (via Graph API or Intune enrollment profile script), then use:
        #   (device.extensionAttribute1 -eq "CloudPC") -and (device.managementType -eq "MDM")
        #
        # INTUNE DEVICE FILTER (for policy assignments — no group required):
        #   (device.model -startsWith "Cloud PC")
        #   This is the preferred targeting method for W365 in Intune.
        #
        # CUSTOMISE: Set extensionAttribute1 = "CloudPC" at provisioning, or
        # adjust the attribute/value to match your environment.
        Rule        = '(device.extensionAttribute1 -eq "CloudPC") -and (device.managementType -eq "MDM")'
    }
    @{
        Name        = "SG-Intune-DDG-W365-FrontlineDevices"
        Description = "Dynamic — Windows 365 Frontline Cloud PCs enrolled in Intune."
        Type        = "Dynamic"
        # Same note as above — device.model is not valid in dynamic group rules.
        # Use extensionAttribute2 = 'CloudPCFrontline' set at provisioning, or
        # scope these via Intune device filter: (device.model -startsWith "Cloud PC Frontline")
        #
        # CUSTOMISE: Adjust attribute and value to match your provisioning tagging.
        Rule        = '(device.extensionAttribute1 -eq "CloudPC") -and (device.extensionAttribute2 -eq "Frontline") -and (device.managementType -eq "MDM")'
    }
    @{
        Name        = "SG-Intune-ADG-W365-Exclusion-Devices"
        Description = "Assigned — Windows 365 Cloud PCs excluded from standard Intune policies."
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

Write-Host "Dynamic group notes:" -ForegroundColor Cyan
Write-Host "  • Groups with 'CUSTOMISE' comments require rule edits before deployment" -ForegroundColor Yellow
Write-Host "  • SG-Intune-DDG-WIN-Autopilot-GroupTag: replace YOUR_GROUP_TAG with your Autopilot group tag value" -ForegroundColor Yellow
Write-Host "  • SG-Intune-DDG-AVD-AllHostDevices: use Intune device filter (device.operatingSystemSKU -eq 'ServerRdsh') for policy assignments; update the group rule to use enrollment profile name if available" -ForegroundColor Yellow
Write-Host "  • Run in -WhatIf first, then verify dynamic group rules in Entra portal before full deployment" -ForegroundColor White

Disconnect-MgGraph | Out-Null

#endregion
