<#
.SYNOPSIS
  Step 4: deploy the Global Secure Access client to a macOS pilot group through Intune (Graph beta).

.DESCRIPTION
  Creates (or finds) four Intune objects, named to the conditionalaccess.tech convention
  "[Platform] - [Scope] - [D/U] - [Feature]", and assigns them ALL to one group:

    Mac - System  - D - GSA System Extensions   Settings catalog: Allowed System Extensions   (approval, no prompt)
    Mac - Network - D - GSA Transparent Proxy   Custom profile, device channel                (approval, no prompt)
    Mac - Network - D - GSA Client Settings     Preference file com.microsoft.globalsecureaccess (menu buttons)
    Mac - Network - D - GSA Client Install      Shell script (Mac-GSA-Client-Install.sh)      (the install)

  The shell script only installs. The security prompts are suppressed by the two approval profiles, so the
  script will NOT create/assign the install script unless the system extension policy and the proxy profile exist.

  Targeting: Learn says these profiles can be assigned to "a group of macOS devices or users", and the system
  extension settings apply to user-approved (BYOD) and automated device enrollment.
    https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-install-macos-client
    https://learn.microsoft.com/intune/device-configuration/templates/ref-kernel-extensions-settings-macos
  Use ONE group for all four objects so a Mac never gets the install without the approvals.

  Verification status (checked 2026-10-12):
    VERIFIED  macOSCustomConfiguration (payloadName, payloadFileName, payload) - Graph docs
    VERIFIED  macOSCustomAppConfiguration (bundleId, fileName, configurationXml) - Graph docs (beta)
    VERIFIED  deviceShellScript properties (runAsAccount, retryCount, executionFrequency, blockExecutionNotifications)
    VERIFIED  extension IDs, team ID, transparent proxy payload, Hide* keys - Learn macOS client page
    UNVERIFIED deploymentChannel property on macOSCustomConfiguration (not in the Graph doc listing).
               Check the created profile shows "Device channel" in the portal.
    UNVERIFIED the /assign request bodies (the script reads assignments back and fails if empty)
    UNVERIFIED the Settings catalog definition IDs used by -CreateSystemExtensionPolicy (not verified against Graph docs).
               Safer: build that one policy in the portal (steps in the reply), then rerun this script without the switch.

.EXAMPLE
  .\Step4-Deploy-GSA-macOS-Intune.ps1 -TenantId <guid> -WhatIf
  .\Step4-Deploy-GSA-macOS-Intune.ps1 -TenantId <guid>
  .\Step4-Deploy-GSA-macOS-Intune.ps1 -TenantId <guid> -TargetGroupName SG-Intune-ADG-MAC-Pilot-Devices
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [string]$ExpectedDomain = 'conditionalaccess.tech',
    [string]$TargetGroupName = 'SG-Intune-AUG-MAC-Pilot-Users',
    [string]$NameSuffix = '',                       # e.g. ' [LAB]' if you want the lab suffix from the convention
    [string]$InstallScriptPath = $(if ($PSScriptRoot) { Join-Path $PSScriptRoot 'Mac-GSA-Client-Install.sh' } else { '.\Mac-GSA-Client-Install.sh' }),
    [switch]$LockDownClient,                         # hide Disable/Pause buttons. Leave OFF while testing the CA policy.
    [switch]$CreateSystemExtensionPolicy,            # UNVERIFIED payload, see help
    [switch]$UpdateExisting,                         # PATCH content of objects that already exist (name match)
    [switch]$AllowEmptyGroup,
    # Excluded from every assignment. Intune supports user-group exclusions only when the target is a USER group
    # (https://learn.microsoft.com/intune/device-configuration/assign-device-profile#exclude-groups-from-a-policy-assignment).
    # Pass -ExcludeGroupName '' to skip.
    [string]$ExcludeGroupName = 'SG-Entra-AUG-CAP-BreakglassAccounts',
    [string[]]$PilotUserUpn,                         # e.g. the one test user; the script reports who will really be targeted
    [switch]$StrictPilot                             # throw if anyone other than -PilotUserUpn would be targeted
)

$ErrorActionPreference = 'Stop'
$Graph = 'https://graph.microsoft.com/beta'
Connect-MgGraph -TenantId $TenantId -NoWelcome -Scopes 'DeviceManagementConfiguration.ReadWrite.All', 'DeviceManagementScripts.ReadWrite.All', 'Group.Read.All', 'Organization.Read.All'

function Invoke-Graph {
    param([string]$Method = 'GET', [string]$Uri, $Body)
    $P = @{ Method = $Method; Uri = $Uri; OutputType = 'PSObject' }
    if ($null -ne $Body) { $P.Body = ($Body | ConvertTo-Json -Depth 20); $P.ContentType = 'application/json' }
    Invoke-MgGraphRequest @P
}
function Get-GraphAll([string]$Uri) {
    $All = @(); while ($Uri) { $Pg = Invoke-Graph -Uri $Uri; $All += @($Pg.value); $Uri = $Pg.'@odata.nextLink' }; $All
}
function ConvertTo-B64([string]$Text) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text)) }

# --- guard: right tenant
$Org = (Invoke-Graph -Uri "$Graph/organization").value | Select-Object -First 1
if (@($Org.verifiedDomains.name) -notcontains $ExpectedDomain) { throw "Tenant '$($Org.displayName)' lacks verified domain '$ExpectedDomain'. Stopping." }
Write-Host "Tenant: $($Org.displayName) ($TenantId)"

# --- target group
$Safe = $TargetGroupName.Replace("'", "''")
$Groups = @((Invoke-Graph -Uri "$Graph/groups?`$filter=displayName eq '$Safe'&`$select=id,displayName").value)
if ($Groups.Count -ne 1) { throw "Expected exactly one group named '$TargetGroupName', found $($Groups.Count)." }
$Group = $Groups[0]
$Members = @(Get-GraphAll "$Graph/groups/$($Group.id)/members?`$select=id,displayName,userPrincipalName&`$top=999")
$Types = ($Members | ForEach-Object { $_.'@odata.type' -replace '#microsoft.graph.', '' } | Group-Object | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', '
Write-Host "Target group: $($Group.displayName) ($($Group.id)); members: $(if ($Types) { $Types } else { 'none' })"
if (-not $Members -and -not $AllowEmptyGroup) { throw 'Target group has no members. Add the pilot user/device first (or use -AllowEmptyGroup).' }

# --- exclusion group (break-glass) and overlap check
$ExcludeGroup = $null; $XMembers = @()
if ($ExcludeGroupName) {
    $SafeX = $ExcludeGroupName.Replace("'", "''")
    $XG = @((Invoke-Graph -Uri "$Graph/groups?`$filter=displayName eq '$SafeX'&`$select=id,displayName").value)
    if ($XG.Count -ne 1) { throw "Expected exactly one exclusion group named '$ExcludeGroupName', found $($XG.Count). Fix the name or pass -ExcludeGroupName '' to skip." }
    $ExcludeGroup = $XG[0]
    $XMembers = @(Get-GraphAll "$Graph/groups/$($ExcludeGroup.id)/members?`$select=id,displayName,userPrincipalName&`$top=999")
    Write-Host "Exclusion group: $($ExcludeGroup.displayName) ($($XMembers.Count) members)"
    $TargetHasDevices = [bool]($Members  | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.device' })
    $ExcludeHasUsers  = [bool]($XMembers | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' })
    if ($TargetHasDevices -and $ExcludeHasUsers) {
        throw "Target group contains devices but the exclusion group contains users. Intune does not support excluding user groups from a device-group assignment (devices of excluded users are not excluded). Use a USER target group, or pass -ExcludeGroupName ''."
    }
    $Overlap = @($Members | Where-Object { $XMembers.id -contains $_.id })
    if ($Overlap) { Write-Warning ("In BOTH target and exclusion group, so they will NOT receive these profiles: " + (($Overlap | ForEach-Object { if ($_.userPrincipalName) { $_.userPrincipalName } else { $_.displayName } }) -join '; ')) }
}
$Effective = @($Members | Where-Object { $XMembers.id -notcontains $_.id })
Write-Host ("Effective targets (target minus exclusion): " + (($Effective | ForEach-Object { if ($_.userPrincipalName) { $_.userPrincipalName } else { $_.displayName } }) -join '; '))
if ($PilotUserUpn) {
    foreach ($U in $PilotUserUpn) { if (-not ($Effective | Where-Object { $_.userPrincipalName -eq $U })) { Write-Warning "Pilot user $U is NOT an effective target (not in the target group, or excluded)." } }
    $Others = @($Effective | Where-Object { $PilotUserUpn -notcontains $_.userPrincipalName })
    if ($Others) {
        $Msg = "Effective targets other than -PilotUserUpn: " + (($Others | ForEach-Object { if ($_.userPrincipalName) { $_.userPrincipalName } else { $_.displayName } }) -join '; ')
        if ($StrictPilot) { throw $Msg } else { Write-Warning $Msg }
    }
}

# --- names (conditionalaccess.tech Intune convention)
$N = @{
    SysExt  = "Mac - System - D - GSA System Extensions$NameSuffix"
    Proxy   = "Mac - Network - D - GSA Transparent Proxy$NameSuffix"
    Client  = "Mac - Network - D - GSA Client Settings$NameSuffix"
    Install = "Mac - Network - D - GSA Client Install$NameSuffix"
}

function Set-Assignment([string]$Kind, [string]$Id) {
    if (-not $Id) { return }
    $Existing = @((Invoke-Graph -Uri "$Graph/deviceManagement/$Kind/$Id/assignments").value)
    if ($Existing | Where-Object { $_.target.groupId -eq $Group.id }) { Write-Host "  assignment: already on $($Group.displayName)"; return }
    if ($Existing.Count -gt 0) { Write-Warning "  $Kind/$Id already has other assignments; not overwriting (assign replaces). Add the group in the portal."; return }
    $Targets = @(@{ target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $Group.id } })
    if ($ExcludeGroup) { $Targets += @{ target = @{ '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'; groupId = $ExcludeGroup.id } } }
    $Body = if ($Kind -eq 'deviceShellScripts') { @{ deviceManagementScriptAssignments = $Targets } } else { @{ assignments = $Targets } }
    if ($PSCmdlet.ShouldProcess("$Kind/$Id", "assign to $($Group.displayName)")) {
        Invoke-Graph -Method POST -Uri "$Graph/deviceManagement/$Kind/$Id/assign" -Body $Body | Out-Null
        $Check = @((Invoke-Graph -Uri "$Graph/deviceManagement/$Kind/$Id/assignments").value)
        if (-not ($Check | Where-Object { $_.target.groupId -eq $Group.id })) { throw "Assignment read-back failed for $Kind/$Id. The /assign body may be wrong; assign in the portal and tell me." }
        if ($ExcludeGroup -and -not ($Check | Where-Object { $_.target.groupId -eq $ExcludeGroup.id })) { throw "Exclusion read-back failed for $Kind/$Id. Add the exclusion in the portal and tell me." }
        Write-Host "  assignment: include $($Group.displayName)$(if ($ExcludeGroup) { ", exclude $($ExcludeGroup.displayName)" }) (verified by read-back)"
    }
}
function Find-ByName([string]$Kind, [string]$NameProp, [string]$Name) {
    Get-GraphAll "$Graph/deviceManagement/$Kind" | Where-Object { $_.$NameProp -eq $Name } | Select-Object -First 1
}

# ============ 1. System extensions policy (approval) ============
Write-Host "`n[1/4] $($N.SysExt)"
$SysExt = Find-ByName 'configurationPolicies' 'name' $N.SysExt
$SysExtReady = [bool]$SysExt
if ($SysExt) { Write-Host "  exists: $($SysExt.id)" }
elseif ($CreateSystemExtensionPolicy) {
    $Str = { param($V) @{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationStringSettingValue'; value = $V } }
    $Body = @{
        name = $N.SysExt; description = 'Allows the Global Secure Access system extensions without a user prompt.'; platforms = 'macOS'; technologies = 'mdm'; roleScopeTagIds = @('0')
        settings = @(@{
            '@odata.type'   = '#microsoft.graph.deviceManagementConfigurationSetting'
            settingInstance = @{
                '@odata.type'               = '#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance'
                settingDefinitionId         = 'com.apple.system-extension-policy_allowedsystemextensions'
                groupSettingCollectionValue = @(@{
                    '@odata.type' = '#microsoft.graph.deviceManagementConfigurationGroupSettingValue'
                    children      = @(
                        @{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance'; settingDefinitionId = 'com.apple.system-extension-policy_allowedsystemextensions_generickey_keytobereplaced'; simpleSettingValue = (& $Str 'UBF8T346G9') }
                        @{ '@odata.type' = '#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance'; settingDefinitionId = 'com.apple.system-extension-policy_allowedsystemextensions_generickey'; simpleSettingCollectionValue = @((& $Str 'com.microsoft.globalsecureaccess.tunnel'), (& $Str 'com.microsoft.globalsecureaccess')) }
                    )
                })
            }
        })
    }
    if ($PSCmdlet.ShouldProcess($N.SysExt, 'create Settings catalog policy (UNVERIFIED payload)')) {
        $SysExt = Invoke-Graph -Method POST -Uri "$Graph/deviceManagement/configurationPolicies" -Body $Body
        Write-Host "  created: $($SysExt.id)"; $SysExtReady = $true
    } elseif ($WhatIfPreference) { $SysExtReady = $true }
} else {
    Write-Warning "  NOT FOUND. Create it in the portal (Devices > Configuration > Create > macOS > Settings catalog > System Configuration > System Extensions > Allowed System Extensions):"
    Write-Warning "    com.microsoft.globalsecureaccess.tunnel = UBF8T346G9  and  com.microsoft.globalsecureaccess = UBF8T346G9, then rerun. The install script will not be deployed without it."
}
if ($SysExt) { Set-Assignment 'configurationPolicies' $SysExt.id }

# ============ 2. Transparent proxy profile (approval) ============
Write-Host "`n[2/4] $($N.Proxy)"
$ProxyPlist = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>PayloadUUID</key>
    <string>87cbb424-6af7-4748-9d43-f1c5dda7a0a6</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadOrganization</key>
    <string>Microsoft Corporation</string>
    <key>PayloadIdentifier</key>
    <string>com.microsoft.globalsecureaccess</string>
    <key>PayloadDisplayName</key>
    <string>Global Secure Access Proxy Configuration</string>
    <key>PayloadDescription</key>
    <string>Add Global Secure Access Proxy Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadEnabled</key>
    <true/>
    <key>PayloadRemovalDisallowed</key>
    <true/>
    <key>PayloadScope</key>
    <string>System</string>
    <key>PayloadContent</key>
    <array>
      <dict>
        <key>PayloadUUID</key>
        <string>04e13063-2bb8-4b72-b1ed-45290f91af68</string>
        <key>PayloadType</key>
        <string>com.apple.vpn.managed</string>
        <key>PayloadOrganization</key>
        <string>Microsoft Corporation</string>
        <key>PayloadIdentifier</key>
        <string>com.microsoft.globalsecureaccess</string>
        <key>PayloadDisplayName</key>
        <string>Global Secure Access Proxy Configuration</string>
        <key>PayloadDescription</key>
        <string/>
        <key>PayloadVersion</key>
        <integer>1</integer>
        <key>TransparentProxy</key>
        <dict>
          <key>AuthenticationMethod</key>
          <string>Password</string>
          <key>Order</key>
          <integer>1</integer>
          <key>ProviderBundleIdentifier</key>
          <string>com.microsoft.globalsecureaccess.tunnel</string>
          <key>ProviderDesignatedRequirement</key>
          <string>identifier "com.microsoft.globalsecureaccess.tunnel" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = UBF8T346G9</string>
          <key>ProviderType</key>
          <string>app-proxy</string>
          <key>RemoteAddress</key>
          <string>100.64.0.0</string>
        </dict>
        <key>UserDefinedName</key>
        <string>Global Secure Access Proxy Configuration</string>
        <key>VPNSubType</key>
        <string>com.microsoft.globalsecureaccess</string>
        <key>VPNType</key>
        <string>TransparentProxy</string>
      </dict>
    </array>
  </dict>
</plist>
'@
$ProxyBody = @{
    '@odata.type' = '#microsoft.graph.macOSCustomConfiguration'; displayName = $N.Proxy
    description = 'Approves the Global Secure Access transparent app proxy (Learn macOS client page).'
    payloadName = 'Global Secure Access Proxy Configuration'; payloadFileName = 'GlobalSecureAccessProxy.mobileconfig'
    payload = (ConvertTo-B64 $ProxyPlist); deploymentChannel = 'deviceChannel'   # deploymentChannel: UNVERIFIED in Graph docs
}
$Proxy = Find-ByName 'deviceConfigurations' 'displayName' $N.Proxy
$ProxyReady = [bool]$Proxy
if ($Proxy) {
    Write-Host "  exists: $($Proxy.id)"
    if ($UpdateExisting -and $PSCmdlet.ShouldProcess($N.Proxy, 'update payload')) { Invoke-Graph -Method PATCH -Uri "$Graph/deviceManagement/deviceConfigurations/$($Proxy.id)" -Body $ProxyBody | Out-Null; Write-Host '  updated' }
} elseif ($PSCmdlet.ShouldProcess($N.Proxy, 'create custom macOS profile')) {
    $Proxy = Invoke-Graph -Method POST -Uri "$Graph/deviceManagement/deviceConfigurations" -Body $ProxyBody
    Write-Host "  created: $($Proxy.id)  (portal check: Deployment channel must read 'Device channel')"; $ProxyReady = $true
} elseif ($WhatIfPreference) { $ProxyReady = $true }
if ($Proxy) { Set-Assignment 'deviceConfigurations' $Proxy.id }

# ============ 3. Client settings preference file ============
Write-Host "`n[3/4] $($N.Client)"
$B = if ($LockDownClient) { '<true/>' } else { '<false/>' }
$ClientPlist = "<?xml version=`"1.0`" encoding=`"UTF-8`"?><!DOCTYPE plist PUBLIC `"-//Apple//DTD PLIST 1.0//EN`" `"http://www.apple.com/DTDs/PropertyList-1.0.dtd`"><plist version=`"1.0`"><dict><key>HideDisableButton</key>$B<key>HidePauseButton</key>$B<key>HideDisablePrivateAccessButton</key><true/><key>HideQuitButton</key><true/></dict></plist>"
$ClientBody = @{
    '@odata.type' = '#microsoft.graph.macOSCustomAppConfiguration'; displayName = $N.Client
    description = "Global Secure Access client menu settings. LockDownClient=$([bool]$LockDownClient)"
    bundleId = 'com.microsoft.globalsecureaccess'; fileName = 'com.microsoft.globalsecureaccess.plist'; configurationXml = (ConvertTo-B64 $ClientPlist)
}
$Client = Find-ByName 'deviceConfigurations' 'displayName' $N.Client
if ($Client) {
    Write-Host "  exists: $($Client.id)"
    if ($UpdateExisting -and $PSCmdlet.ShouldProcess($N.Client, 'update settings')) { Invoke-Graph -Method PATCH -Uri "$Graph/deviceManagement/deviceConfigurations/$($Client.id)" -Body $ClientBody | Out-Null; Write-Host '  updated' }
} elseif ($PSCmdlet.ShouldProcess($N.Client, 'create preference file profile')) {
    $Client = Invoke-Graph -Method POST -Uri "$Graph/deviceManagement/deviceConfigurations" -Body $ClientBody
    Write-Host "  created: $($Client.id)"
}
if ($Client) { Set-Assignment 'deviceConfigurations' $Client.id }

# ============ 4. Install shell script (only after the approvals exist) ============
Write-Host "`n[4/4] $($N.Install)"
if (-not ($SysExtReady -and $ProxyReady)) {
    Write-Warning '  SKIPPED: the system extension policy and the transparent proxy profile must exist first, or users get approval prompts.'
} else {
    if (-not (Test-Path $InstallScriptPath)) { throw "Install script not found: $InstallScriptPath" }
    $ScriptText = (Get-Content $InstallScriptPath -Raw) -replace "`r`n", "`n"
    $ShellBody = @{
        '@odata.type' = '#microsoft.graph.deviceShellScript'; displayName = $N.Install
        description = 'Installs the Global Secure Access client. Approvals come from the two GSA MDM profiles.'
        fileName = 'Mac-GSA-Client-Install.sh'; runAsAccount = 'system'; retryCount = 3; blockExecutionNotifications = $true
        executionFrequency = 'P1D'; scriptContent = (ConvertTo-B64 $ScriptText)
    }
    $Shell = Find-ByName 'deviceShellScripts' 'displayName' $N.Install
    if ($Shell) {
        Write-Host "  exists: $($Shell.id)"
        if ($UpdateExisting -and $PSCmdlet.ShouldProcess($N.Install, 'update script')) { Invoke-Graph -Method PATCH -Uri "$Graph/deviceManagement/deviceShellScripts/$($Shell.id)" -Body $ShellBody | Out-Null; Write-Host '  updated' }
    } elseif ($PSCmdlet.ShouldProcess($N.Install, 'create shell script')) {
        $Shell = Invoke-Graph -Method POST -Uri "$Graph/deviceManagement/deviceShellScripts" -Body $ShellBody
        Write-Host "  created: $($Shell.id)"
    }
    if ($Shell) { Set-Assignment 'deviceShellScripts' $Shell.id }
}

Write-Host "`nDone. On the Mac: sync in Company Portal, then check Settings > Privacy & Security / VPN & Filters for the GSA entries and run 'systemextensionsctl list' (expect UBF8T346G9 ... globalsecureaccess)."
Write-Host "Install log on the Mac: /var/log/gsa-client-install.log"
