# GSA Microsoft traffic profile + compliant network check: macOS and Windows

Lab tenant: conditionalaccess.tech. Written 2026-10-12. macOS verified in lab. Windows NOT yet tested on a device.
Full detail, IDs and sources: GSA-Compliant-Network-Runbook.md

## Folder
- README.md (this checklist)
- GSA-Compliant-Network-Runbook.md (full runbook)
- macos/Mac-GSA-Client-Install.sh, Step4-Graph-Calls.md, Step4-Deploy-GSA-macOS-Intune.ps1
- windows/Win-GSA-Client-Install.ps1, Win-GSA-ClientSettings-Detect.ps1, Win-GSA-ClientSettings-Remediate.ps1, Win-GSA-Detection-Rule.md

## What the scripts do and do NOT do
| Item | Scripts / Graph | Manual (portal) |
|---|---|---|
| Install client (mac / Windows) | Yes | |
| macOS system-extension + transparent proxy approvals | Yes (Graph, Step4-Graph-Calls.md) | |
| Windows client registry settings | Yes (remediation scripts) | Create the remediation in Intune |
| Windows Win32 app package and upload | No | Yes (IntuneWinAppUtil + portal) |
| Windows Edge/Chrome DoH (and QUIC) policy | No (setting IDs in runbook) | Yes |
| Enable CA signaling (Adaptive access) | No | Yes |
| Enable Microsoft traffic profile | No | Yes |
| Traffic profile user/group assignment | **No** | **Yes** |
| Traffic profile device-platform assignment | **No** | **Yes** |
| Compliant network named location | Created by Microsoft when signaling is on | Confirm it exists |
| Report-only CA policy | Yes (Graph beta JSON in runbook) | |

The profile assignment (users/groups and device platforms) has no documented Graph endpoint. Nothing in these scripts targets users, devices or platforms in the traffic profile. If it is skipped the client installs and the Intune side looks fine but no traffic is tunneled.

## Manual checklist (do not skip)
Tenant, once:
- [ ] Global Secure Access > Settings > Session management > Adaptive access: enable "Enable Conditional Access Signaling for Microsoft Entra ID"
- [ ] Enable source IP restoration (Learn's compliant network tutorial says it is required to target the compliant network in CA; not confirmed done in the lab)
- [ ] CA > Named locations: "All Compliant Network locations" exists (type Network Access)
- [ ] Connect > Traffic forwarding: Microsoft 365 profile enabled
- [ ] Microsoft profile > Assignments: pilot users or group added
- [ ] Microsoft profile > Assignments: device platforms set (macOS, Windows). "No devices assigned" means no device gets the profile
- [ ] Service principals present: "ZTNA Policy Service Client" (appId ca01d00c-bfd6-46d6-ae7d-be5b5267d037). The "ZTNA Policy Service" resource SP was missing in the lab and its appId is unverified

Per OS:
- [ ] Pilot user and device groups created and populated (SG-Intune-AUG/ADG-MAC|WIN-Pilot-...)
- [ ] macOS: system-extension and proxy policies assigned BEFORE the install script, all to the device group
- [ ] Windows: Win32 app, remediation, and browser DoH policy created and assigned to the device group
- [ ] Windows: allow the reboot (script returns 3010 after setting IPv4 preferred)
- [ ] Client shows Connected; Health check passes; Traffic logs show Microsoft traffic

CA policy:
- [ ] Create it in report-only. Verify state afterwards (Graph state = enabledForReportingButNotEnforced). In the lab the policy was found set to On (enforced) and blocking Hermione
- [ ] Break-glass group excluded; Intune and Intune Enrollment excluded for any all-resources version
- [ ] Review report-only results in the sign-in logs before enforcing

## Gotchas
1. Auto-created groups: the portal creates a `_GSA_<guid>` backing group per traffic profile (lab: `_GSA_2ec642ab-...` for Microsoft 365). Do not assign these in Intune or CA. In the lab I added users to the M365 profile's backing group directly while troubleshooting; I did not prove that was needed, so assign through the profile's Assignments page instead.
2. Nested groups: Learn conflicts. The assignment page says nested groups are supported; the "disabled by your organization" troubleshooting page says they are not. Use direct members.
3. Intune: a user-group exclusion cannot be combined with a device-group assignment. Assign device-targeted policies to the device group.
4. Break-glass mode on the client = no traffic profile tunneling (e.g. no profile assigned to the user/platform). Fix: assign/enable a profile; allow up to about an hour to refresh.
5. Failure signature (macOS lab): non-interactive sign-ins from the GSA client to "ZTNA Policy Service" failed 50097 then 50187, client Partially Connected. It later connected after the platform assignment save, a refresh and creating the missing client SP. Cause not proven.
6. Secure DNS: Windows requires DoH/DoT disabled in browsers for FQDN tunneling. The macOS client bypasses secure DNS itself.
7. QUIC: supported for Microsoft 365 and Private Access traffic; not for Internet Access (disable it in browsers only if you add Internet Access).
8. Compliant network is evaluated at sign-in. Use a fresh browser session when testing; existing sessions are not re-evaluated until the next sign-in.
9. Do not disable CA signaling while compliant-network CA policies exist; delete the policies first (Learn caution).
10. Non-interactive client sign-ins only appear with the signInEventTypes/any(t: t eq 'nonInteractiveUser') filter on beta /auditLogs/signIns.
11. A different user's browser sign-in on a device whose client authenticated as another user: whether it carries the compliant network signal is unverified.

## Open items
- Replace the share link in the Intune install script description; update the script content in Intune to the cleaned version
- Pin the macOS pkg version; optional macOS client settings profile; check overlap with the Defender system-extension policy
- Test the Windows package on a device; write Windows Graph calls for remediation and settings catalog
- Confirm the "ZTNA Policy Service" resource SP appId from a verified source
- Rename the CA policy to the naming convention before production

Sources: Microsoft Learn: how-to-install-windows-client, how-to-install-macos-client, how-to-compliant-network, tutorial-microsoft-traffic-compliant-network, how-to-manage-microsoft-profile, reference-current-known-limitations.
