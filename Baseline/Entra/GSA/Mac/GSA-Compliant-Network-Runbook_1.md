# GSA Microsoft Traffic Profile + Compliant Network Check: macOS and Windows runbook
Tenant: conditionalaccess.tech (86600c1e-803d-49b9-a963-036358886be9). Written 2026-10-12. Status: macOS verified in lab; Windows scripts adapted from the Microsoft Learn samples but NOT yet tested on a device (PowerShell syntax check not run: pwsh not available in the build container).
Preview note: the compliant network check in Conditional Access is a preview feature (Graph beta only; v1.0 returns error 1038). Re-check Learn if this runbook is older than 3 months.

## 0. Principles
- Pilot only. Report-only CA first. Enforce only after report-only results show the expected network location.
- Break-glass group SG-Entra-AUG-CAP-BreakglassAccounts (5628ad67-f9d1-4495-abe3-99dc8f9074f1) excluded from every user-targeted CA policy.
- Learn's all-resources compliant-network policy excludes Microsoft Intune and Microsoft Intune Enrollment (avoids a circular dependency). GSA traffic profiles and the GSA policy service are auto-excluded by Learn when compliant network is used, so no manual exclusion is needed (this may explain the SP-less ZTNA sign-ins showing no CA policy).
- Break-glass mode on the client = every traffic profile off/not tunneling. Fix: enable a profile, allow ~1 hour to refresh.

## 1. Tenant (portal, once) - Entra > Global Secure Access
1. Global Secure Access > Settings > Session management > Adaptive access: enable "Enable Conditional Access Signaling for Microsoft Entra ID" (Learn: how-to-compliant-network). Learn's compliant network tutorial also states source IP restoration must be enabled to target the compliant network in CA (tutorial-microsoft-traffic-source-ip-restoration). Check this was done in the lab; I have not confirmed it. Then confirm CA > Named locations has "All Compliant Network locations" (type Network Access). Do not disable signaling later while compliant-network CA policies exist; delete the policies first (Learn caution).
2. Connect > Traffic forwarding: enable the Microsoft 365 traffic profile.
3. Open the Microsoft profile > Assignments (no documented Graph endpoint; portal only). Assign pilot users/group AND set Device platforms (macOS, Windows). "No devices assigned" for a platform means no device of that platform gets the profile. Portal creates a `_GSA_<guid>` backing group per profile; do not assign it.
   - Learn is inconsistent on nested groups (assignment page: supported; troubleshooting page: not). Use direct members.
4. Verify service principals exist (Graph): "ZTNA Policy Service Client" appId ca01d00c-bfd6-46d6-ae7d-be5b5267d037 (created in lab, objectId 27bc03fe-1129-41ed-915c-669619896494). The resource "ZTNA Policy Service" SP was missing in the lab and its appId is unverified. Do not guess it.

## 2. Groups (naming convention SG-[Pillar]-[TypeCode]-[Scope]-[Env]-[Name])
| Purpose | macOS | Windows |
|---|---|---|
| Pilot users | SG-Intune-AUG-MAC-Pilot-Users (06a38404-74cc-46ed-9f46-dfb85330ff14) | SG-Intune-AUG-WIN-Pilot-Users (create) |
| Pilot devices | SG-Intune-ADG-MAC-Pilot-Devices (eeb0447d-8918-416e-950d-1d7323d37d6f) | SG-Intune-ADG-WIN-Pilot-Devices (create) |
Intune rule: assign device-targeted policies to the device group. A user-group exclusion cannot be combined with a device-group assignment.

## 3. Client deployment
### 3a. macOS (built, working)
Min macOS 14. Device must be registered via Company Portal; Platform SSO healthy (`app-sso platform -s`).
| Intune object | Id | Notes |
|---|---|---|
| Mac - System - D - GSA System Extensions | 390f9c9e-d11d-4269-9a5e-a9c5f3617113 | Allows com.microsoft.globalsecureaccess.tunnel and com.microsoft.globalsecureaccess, team UBF8T346G9 |
| Mac - Network - D - GSA Transparent Proxy | 43c0dfba-aea1-4335-b43f-d5bc44e5f057 | macOSCustomConfiguration, GlobalSecureAccessProxy.mobileconfig, device channel |
| Mac - Network - D - GSA Client Install | c7f77c66-2c5e-4aaa-a3c1-d0c159a8d58a | Shell script, run as root, retry 3; file macos/Mac-GSA-Client-Install.sh |
Graph call list: macos/Step4-Graph-Calls.md. Check overlap with the Defender system-extension policy.
Open item: the description of the live install script in Intune contains a claude.ai share link; replace it with a plain description.

### 3b. Windows (to build; files in windows/)
Prereqs (Learn): 64-bit Windows 10 (LTSC 2021+)/11, or the separate Arm64 installer (aka.ms/GlobalSecureAccess-WindowsOnArm). Entra joined / hybrid joined (registered = Private Access only). AVD multi-session unsupported. Local admin to install.
1. Download client: Entra > Global Secure Access > Connect > Client download. Save as `GlobalSecureAccessClient.exe` (exact name).
2. Folder with the .exe + windows/Win-GSA-Client-Install.ps1. Run IntuneWinAppUtil.exe: source folder, setup file = the .ps1, output folder, answer N to catalog.
3. Intune > Apps > Windows > Add > Windows app (Win32). Name `Win - Network - D - GSA Client Install`, Publisher Microsoft, version = client version.
   - Install: `powershell.exe -ExecutionPolicy Bypass -File Win-GSA-Client-Install.ps1`
   - Uninstall: `"GlobalSecureAccessClient.exe" /uninstall /quiet /norestart`; Allow available uninstall: No
   - Install behavior: System; restart: determine by return codes: 0 success, 3010 soft reboot, 1618 retry
   - Requirements: 64-bit, minimum Windows 10 LTSC 2021 (pick per your fleet)
   - Detection: windows/Win-GSA-Detection-Rule.md (file version >=)
   - Assignment: Required to SG-Intune-ADG-WIN-Pilot-Devices; restart grace period Enabled.
4. The script sets HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters DisabledComponents=0x20 (prefer IPv4) and returns 3010. That reboot is part of the Learn sample, not optional.
5. Client settings: Intune > Devices > Scripts and remediations > create `Win - Network - D - GSA Client Settings` with windows/Win-GSA-ClientSettings-Detect.ps1 and -Remediate.ps1, run in 64-bit PowerShell, as SYSTEM. Values = Learn sample (HideSignOutButton 1, HideDisablePrivateAccessButton 1, HideDisableButton 0, RestrictNonPrivilegedUsers 0). Use HideDisableButton 0 / Restrict 0 during the pilot so testers can disable the client; tighten after.
6. Browser policies (needed for FQDN tunneling): Windows secure DNS must be disabled. Settings catalog profile `Win - Network - D - GSA Browser DoH` (Edge + Chrome DoH mode Disabled). QUIC is only required to be disabled if you add Internet Access (see section 7). Setting definition ids from the Intune settings catalog:
   - Edge QUIC: device_vendor_msft_policy_config_microsoft_edge~policy~microsoft_edge_quicallowed
   - Chrome QUIC: device_vendor_msft_policy_config_chromeintunev1~policy~googlechrome_quicallowed
   - Edge DoH: device_vendor_msft_policy_config_microsoft_edgev83diff~policy~microsoft_edge_dnsoverhttpsmode
   - Chrome DoH: device_vendor_msft_policy_config_chromeintunev1~policy~googlechrome_dnsoverhttpsmode
   Build in the portal (Learn steps: Settings catalog, search QUIC / DNS-over-HTTPS, set Disabled). Graph JSON choice-value ids not verified here.
   Learn also lists a DNS-over-TCP mitigation: BuiltInDnsClientEnabled=0 for Edge/Chrome.
7. Firefox: Learn provides detection/remediation scripts that write policies.json (network.http.http3.enable false, network.trr.mode 0). Only if Firefox is in scope.

Windows Graph automation: Win32 app content upload (encrypted .intunewin upload) is not covered by a verified call list here. Use the portal for step 3; remediation scripts and settings catalog profiles can be created through Graph (deviceHealthScripts, configurationPolicies) but are not written/tested yet.

## 4. Compliant network named location + CA policy (same for both OS)
- Location object "All Compliant Network locations": id 3d46dbda-8382-466a-856d-eb00cbc6b910 (compliantNetworkNamedLocation).
- Report-only policy (Graph beta POST /identity/conditionalAccess/policies), lab version used for Hermione only:
{"displayName":"CATech - DEMO - GSA - BLOCK - NonCompliantNetwork","state":"enabledForReportingButNotEnforced","conditions":{"clientAppTypes":["all"],"users":{"includeUsers":["b694af5a-e473-41a0-80c0-2a677d944f19"],"excludeGroups":["5628ad67-f9d1-4495-abe3-99dc8f9074f1"]},"applications":{"includeApplications":["Office365"]},"locations":{"includeLocations":["All"],"excludeLocations":["3d46dbda-8382-466a-856d-eb00cbc6b910"]}},"grantControls":{"operator":"OR","builtInControls":["block"]}}
  Policy id in lab: 599e2203-3a03-4677-8f85-03bf6c5f2d52.
- Production-shaped version (Learn design): users = pilot group, exclude break-glass; resources = all, excluding Intune and Intune Enrollment; locations any, exclude compliant network; Block; report-only first. Name per convention, e.g. `IAC - Network - Block - AllApps - NonCompliantNetwork - Exclude-Breakglass`.
- The lab policy name uses the `CATech - DEMO -` prefix, which is not in the naming convention.

## 5. Validation (both OS)
1. Client icon: Connected (Windows tray / macOS menu bar). Advanced Diagnostics > Forwarding profile shows the Microsoft profile; Health check passes.
2. Entra > Global Secure Access > Monitor > Traffic logs: Microsoft 365 / Entra traffic for the device.
3. Sign in to office.com as the pilot user; pull the sign-in (beta /auditLogs/signIns). Check network location shows "All Compliant Network locations" and the report-only result of the CA policy.
   - Non-interactive client sign-ins need filter signInEventTypes/any(t: t eq 'nonInteractiveUser'); avoid appDisplayName filter combos (Unsupported Query).
4. Disable the client, sign in again: report-only should show the policy would have blocked.
5. Only then consider enforcing.

## 6. Known issues / lab findings
- Failure seen on macOS: client non-interactive sign-ins to "ZTNA Policy Service" failed 50097 then 50187 (DeviceInformationNotProvided) with blank device fields; client was Partially Connected. It later became Connected after the platform assignment was saved, a refresh, and creation of the missing client SP. Which one fixed it is not proven.
- Unverified: whether the compliant network signal applies to a different user's browser sign-in than the one the client authenticated as; which identity the macOS client uses; the appId of the "ZTNA Policy Service" resource SP.
- Forwarding profile Graph GET returned 403 in lab (needs NetworkAccess.ReadWrite.All, beta).

## 7. Optional: Internet Access later
QUIC is not supported for Internet Access (supported for Microsoft 365 and Private Access traffic). If you add that profile, disable QUIC in Edge/Chrome with the settings above. Learn warns against blocking Intune endpoints in an Internet Access compliance policy (bypass them).

## 8. Rollback
- Set CA policy to disabled / delete it; unassign users in the portal profile; remove the Intune assignments (uninstall command above for Windows; macOS: remove the app via the GSA uninstaller and the three Mac - ... policies). Reconnect check: client may take about an hour to refresh.

## Sources
- https://learn.microsoft.com/en-us/entra/global-secure-access/how-to-install-windows-client
- https://learn.microsoft.com/entra/global-secure-access/reference-current-known-limitations
- https://learn.microsoft.com/entra/global-secure-access/troubleshoot-global-secure-access-client-diagnostics-health-check
- https://learn.microsoft.com/entra/global-secure-access/how-to-manage-microsoft-profile
- https://learn.microsoft.com/entra/global-secure-access/concept-universal-conditional-access
