# Microsoft Defender for Endpoint — Deployment & Configuration Guide
**Windows & macOS | Jon Hope | Microsoft MVP — M365 Security**
Version 1.0 | April 2026 | Jon Hope | Microsoft MVP — M365 Security

---

## Table of Contents

1. [Overview](#1-overview)
   - 1.1 Why Microsoft Defender for Endpoint Matters
   - 1.2 Left of Boom and Right of Boom: A Complete Security Posture
   - 1.3 Business Premium SKU — Maximum Value Activation
   - 1.4 Copilot Readiness and Shadow AI Detection
   - 1.5 Transitioning from SentinelOne or Another Third-Party AV
2. [Prerequisites](#2-prerequisites)
   - 2.1 Licensing Requirements
   - 2.2 Prerequisite Execution Order — Full Checklist
   - 2.3 Step-by-Step: Prerequisite Details
   - 2.4 Recommended Policies to Deploy
   - 2.5 Settings Catalog Only — Additional Configuration Required
   - 2.6 macOS-Specific Prerequisites
3. [Policy Naming Conventions](#3-policy-naming-conventions)
   - 3.1 Naming Convention Format
   - 3.2 Windows Policy Naming — Full Reference
   - 3.3 macOS Policy Naming — Full Reference
   - 3.4 Rollback Policy Naming Convention
4. [Onboard Endpoints — Windows & macOS](#4-onboard-endpoints--windows--macos)
   - 4.1 Windows Onboarding via Intune
   - 4.2 macOS Onboarding via Intune
   - 4.3 Device Group Strategy
   - 4.4 Windows Server Onboarding — Intune Cannot Onboard Servers
5. [Order of Operations](#5-order-of-operations)
6. [Next Generation Protection — AV Configuration](#6-next-generation-protection--av-configuration)
   - 6.1 The Three-Level Architecture — Level-Based Policy Design
   - 6.2 AV Policy Settings — Level 1 Baseline
   - 6.3 Update Ring Architecture — 3-Ring Deployment Model
7. [Endpoint Detection and Response — EDR Configuration](#7-endpoint-detection-and-response--edr-configuration)
   - 7.1 Windows EDR Policy
   - 7.2 macOS EDR Policy
   - 7.3 Automated Investigation and Remediation (AIR)
8. [Attack Surface Reduction Rules](#8-attack-surface-reduction-rules)
   - 8.1 ASR Philosophy and Lifecycle
   - 8.2 Recommended ASR Rules — Deployment Reference
   - 8.3 Per-Persona ASR Exclusions
9. [Exclusions Management](#9-exclusions-management)
   - 9.1 Core Principle: Start at Zero
   - 9.2 Exclusion Types
   - 9.3 Exclusion Governance Process
10. [Rollback Plan](#10-rollback-plan)
    - 10.1 Rollback Triggers
    - 10.2 Windows Rollback Procedure
    - 10.3 macOS Rollback Procedure
    - 10.4 Toggle Policies — Separate Rollback Policy Required
    - 10.5 Emergency — Complete MDE Removal
11. [Technical Troubleshooting](#11-technical-troubleshooting)
    - 11.1 Is It Defender? — The First Question
    - 11.2 MDE Troubleshooting Mode
    - 11.3 Effective Settings — The Primary Diagnostic Tool
    - 11.4 Policy Conflict Sources
    - 11.5 Event Log Locations
    - 11.6 macOS Diagnostic Commands
    - 11.7 MDEValidator — Automated Configuration Validation
12. [Things to Consider](#12-things-to-consider)
- [Additional Resources](#additional-resources)
- [Appendix A — Intune Policy Reference](#appendix-a--intune-policy-reference)
- [Appendix B — macOS Profile Checklist](#appendix-b--macos-profile-checklist)

---

## 1. Overview

### 1.1 Why Microsoft Defender for Endpoint Matters

Microsoft Defender for Endpoint (MDE) is not simply an antivirus replacement — it is a full Extended Detection and Response (XDR) platform native to the Microsoft 365 ecosystem. For organizations operating on Microsoft 365 Business Premium, MDE is already licensed and represents one of the most underutilized security investments available to SMB and mid-market customers.

Microsoft processes more than 78 trillion security signals per day across identities, endpoints, email, cloud apps, and infrastructure. No third-party endpoint detection and response product has access to this cross-workload telemetry. The integration of endpoint signals with identity signals, email signals, and cloud app signals is what makes MDE's detection and automated response capabilities fundamentally different from standalone EDR tools.

> **Signal Advantage:** A standalone EDR alert is endpoint-only context. A Defender XDR incident is endpoint + identity + email + cloud app context — correlated automatically.

### 1.2 Left of Boom and Right of Boom: A Complete Security Posture

| Posture | Capability | MDE / Entra Component |
|---|---|---|
| Left of Boom (Prevent) | Next Generation Protection — block malware, ransomware, zero-day before execution | Defender AV, Cloud-Delivered Protection, Block at First Sight |
| Left of Boom (Prevent) | Attack Surface Reduction rules | ASR Rules (Intune managed) |
| Left of Boom (Prevent) | Identity-based pre-attack blocking via Conditional Access | Entra ID Protection + Conditional Access |
| Left of Boom (Prevent) | Network Protection — block C2 infrastructure connections | MDE Network Protection |
| Right of Boom (Detect/Respond) | EDR — behavioral detections, threat hunting, automated investigation | MDE EDR + AIR |
| Right of Boom (Detect/Respond) | Attack Disruption — automatically contain compromised identities and devices | Defender XDR Automatic Attack Disruption |
| Right of Boom (Detect/Respond) | Advanced Hunting — proactive threat hunting using KQL | Defender XDR Advanced Hunting |

### 1.3 Business Premium SKU — Maximum Value Activation

Microsoft 365 Business Premium is the most cost-effective security SKU in the market. Activating Defender for Endpoint is not an additional purchase — it is a capability that already exists in the tenant.

| License | MDE Included | Key Capabilities |
|---|---|---|
| M365 Business Premium | MDE Plan 1 + Defender for Business | AV, EDR lite, Firewall, ASR, basic Threat & Vulnerability Management |
| M365 E3 | MDE Plan 1 | AV, Firewall, ASR, basic EDR |
| M365 E5 / Defender for Business add-on | MDE Plan 2 | Full EDR, AIR, Threat & Vulnerability Management, Advanced Hunting, Attack Disruption |

### 1.4 Copilot Readiness and Shadow AI Detection

Every endpoint onboarded to MDE immediately begins contributing to Shadow AI visibility in Defender for Cloud Apps. Defender for Cloud Apps — included with Business Premium — requires endpoints to be onboarded to MDE before it can detect Shadow AI activity. As employees use consumer AI tools (ChatGPT, Gemini, Perplexity, and others), organizations face data exfiltration risk through these unmanaged channels. Once endpoints are onboarded and the MDE–Cloud Apps integration is enabled, the platform automatically surfaces these applications through the Cloud App Catalog.

### 1.5 Transitioning from SentinelOne or Another Third-Party AV

#### 1.5.1 The Dual-AV Problem

When a third-party AV is actively installed on a Windows device, Windows Security Center places Microsoft Defender Antivirus into **Passive Mode**. In Passive Mode:

- Defender AV does **not** block or quarantine threats
- Real-time protection is suspended
- Tamper Protection cannot fully protect settings in Passive Mode
- EDR can still function independently (EDR in Block Mode is the recommended setting)

> ⚠️ **Passive Mode is not protection.** Passive Mode is a detection-only observer state. Your transition plan must account for the window between uninstalling the legacy AV and Defender entering Active Mode.

#### 1.5.2 macOS Passive Mode During Transition

On macOS, if running a non-Microsoft antivirus alongside Defender for Endpoint, explicitly set `passiveMode: true` in the MDE configuration profile (`com.microsoft.wdav`). Failing to do this will result in system performance degradation and detection conflicts.

#### 1.5.3 Exclusion Migration Warning

Never migrate legacy AV exclusions wholesale. Start with zero exclusions in Defender and add only when a specific, documented performance or compatibility issue is confirmed through testing. Every exclusion is a risk acceptance decision and must be ticketed.

---

## 2. Prerequisites

All prerequisites must be completed in order before deploying any policies.

### 2.1 Licensing Requirements

| Requirement | Minimum License | Notes |
|---|---|---|
| MDE Plan 1 (AV, ASR, Firewall) | M365 Business Premium / E3 | Included — no add-on needed |
| MDE Plan 2 (Full EDR, AIR, Advanced Hunting) | M365 E5 / Defender for Business add-on | Required for full EDR incident response |
| Defender for Cloud Apps (Shadow AI) | M365 Business Premium | Requires MDE onboarding |
| macOS Endpoint Support | MDE Plan 1 or 2 | macOS 12 (Monterey) minimum |
| Intune Device Management | Intune Plan 1 (included in BP) | Required for policy deployment |
| Defender for Servers (Azure/Server workloads) | Microsoft Defender for Cloud — Plan 1 or 2 | Separate license, not in Business Premium |

### 2.2 Prerequisite Execution Order — Full Checklist

| Step | Prerequisite | Portal |
|---:|---|---|
| 1 | Create Intune Enrollment + Azure Credential Configuration Endpoint Service enterprise apps | Entra |
| 2 | Configure MDM user scope for automatic enrollment | Entra |
| 3 | Enable Exchange organization customization (dehydrated tenants) | Exchange Online |
| **4** | **Provision Microsoft Defender for Endpoint — navigate to Assets > Devices. Wait for the coffee cup / provisioning state to clear before proceeding.** | **Defender portal** |
| **5** | **Verify Tamper Protection is On (Settings > Endpoints only appears AFTER Step 4 is complete)** | **Defender portal** |
| 6 | Enable Microsoft Defender for Endpoint connector — two-sided toggle (Defender portal + Intune) | Defender + Intune |
| 7 | Enable MDE to Cloud Apps integration — separate toggle from Step 6 (enables Cloud Discovery / Shadow AI) | Defender portal |
| 8 | Review Intune platform restrictions baseline — block personal devices unless required | Intune |
| 9 | Set Windows Hello for Business to Not configured | Intune |
| 10 | Enable Windows diagnostic data for Intune | Intune |
| 11 | Exclude break-glass accounts from all Conditional Access policies | Entra |
| 12 | *(Optional)* Configure named locations — Blocked Countries and Allowed Countries | Entra |

### 2.3 Step-by-Step: Prerequisite Details

#### Step 1 — Create Required Enterprise Applications (Entra)

Three service principals must exist before configuring Conditional Access and Defender MAM so they appear as targetable cloud apps. These are not always auto-created in new tenants.

- **Microsoft Intune Enrollment** (`d4ebce55-015a-49b5-a083-c84d1797ae8c`): Without this, "Intune Enrollment" does not appear in Conditional Access cloud app selectors.
- **Azure Credential Configuration Endpoint Service** (`ea890292-c8c8-4433-b5ea-b09d0668e1a6`): Required for passkey registration in Microsoft Authenticator. Must be excluded from device compliance / APP-enforcing CA policies.
- **MicrosoftDefenderATP MAM** (`c2b688fe-48c0-464b-a89c-67041aa8fcb2`): Required for Defender for Endpoint Mobile Application Management (MAM) scenarios — enables MDE to function on MAM-enrolled devices without requiring full MDM enrollment. Register on the Defender portal side.

```powershell
Connect-MgGraph -Scopes "Application.ReadWrite.All"

New-MgServicePrincipal -AppId "d4ebce55-015a-49b5-a083-c84d1797ae8c"  # Microsoft Intune Enrollment
New-MgServicePrincipal -AppId "ea890292-c8c8-4433-b5ea-b09d0668e1a6"  # Azure Credential Configuration Endpoint Service
New-MgServicePrincipal -AppId "c2b688fe-48c0-464b-a89c-67041aa8fcb2"  # MicrosoftDefenderATP MAM
```

Verify: Entra admin center > Enterprise applications — confirm all three apps appear.

#### Step 2 — Configure MDM User Scope (Entra)

**Path:** Entra admin center > Devices > Enrollment > Microsoft Intune
Set MDM user scope to **All** or **Some** (with the correct group scoped). Without this, devices will not automatically enroll into Intune and will not receive Defender policies.

#### Step 3 — Enable Exchange Organization Customization

Exchange tenants are often dehydrated by default. Check and enable before applying any Exchange configuration changes.

```powershell
Connect-ExchangeOnline
Get-OrganizationConfig | Select IsDehydrated  # Should return False
Enable-OrganizationCustomization               # Run only if IsDehydrated = True

Set-OrganizationConfig -AuditDisabled $false `
    -OAuth2ClientProfileEnabled $true `
    -MailTipsAllTipsEnabled $true `
    -RejectDirectSend $true
```

#### Step 4 — Provision Defender for Endpoint — The Coffee Cup

> ⚠️ **CRITICAL:** This step is the most commonly skipped and most commonly causes confusion. If you attempt to configure **Settings > Endpoints** before provisioning is complete, the Endpoints menu item will not exist. Do not proceed to Steps 5–7 until provisioning is confirmed complete.

Navigate to **https://security.microsoft.com** as a Global Administrator or Security Administrator. Go to **Assets > Devices**. If the tenant has not previously used Defender for Endpoint, the portal will show a provisioning animation — informally known as the **coffee cup state** — while the Defender backend provisions the tenant's MDE workspace.

| State | What to Do |
|---|---|
| ☕ Coffee cup / provisioning animation visible | **Wait.** Provisioning typically takes 5–30 minutes for a new tenant. Do not attempt to configure any Endpoints settings until provisioning completes. |
| Provisioning complete — Assets > Devices shows device list or empty state | Proceed to Step 5. Settings > Endpoints is now accessible. |
| Settings > Endpoints does not appear after provisioning | Confirm the signed-in account has Security Administrator or Global Administrator role. The Endpoints submenu is role-gated. |

#### Step 5 — Verify Tamper Protection

**Path:** Defender portal > Settings > Endpoints > Advanced features
Confirm **Tamper Protection** is set to **On**. Tamper Protection is enabled by default for enterprise tenants but must be verified before deploying AV policies.

> Note: Settings > Endpoints only appears after Step 4 provisioning is complete. If you cannot see Endpoints under Settings, return to Step 4 and wait for provisioning to finish.

#### Step 6 — Enable the MDE to Intune Connector (Two-Sided)

This is a **two-sided connection** — both sides must be enabled independently.

| Side | Action |
|---|---|
| Defender portal side | Settings > Endpoints > Advanced features > Microsoft Intune connection > toggle **On** > Save preferences |
| Intune side | Intune admin center > Endpoint security > Microsoft Defender for Endpoint > confirm Connection status shows **Enabled**. Allow up to 15 minutes for status to update. |

#### Step 7 — Enable MDE to Defender for Cloud Apps Integration

This is a **separate toggle** from the Intune connector in Step 6. It routes endpoint network traffic data from MDE into Defender for Cloud Apps, enabling the **Cloud Discovery Shadow IT dashboard**.

**Path:** Defender portal > Settings > Cloud Apps > Microsoft Defender for Endpoint > toggle "Enable Microsoft Defender for Endpoint integration with Microsoft Defender for Cloud Apps" > **Save**

Without this toggle, Cloud Discovery shows an empty screen even if MDE is fully provisioned. Dependency chain: (1) Devices enrolled in Intune, (2) Intune ↔ MDE connector enabled, (3) MDE → Cloud Apps toggle enabled. Allow up to **2 hours** for the first discovery data to appear.

#### Step 8 — Review Intune Platform Restrictions

**Path:** Intune admin center > Devices > Device onboarding > Enrollment > Device platform restriction
Confirm required platforms (Windows, macOS) are set to **Allow**. Set personal device enrollment to **Block** unless the organization explicitly permits BYOD.

#### Step 9 — Windows Hello for Business

**Path:** Intune admin center > Devices > Enrollment > Windows Hello for Business
Set to **Not configured**. Managing Windows Hello at the enrollment policy level conflicts with Conditional Access-based identity protection policies.

#### Step 10 — Enable Windows Diagnostic Data

**Path:** Intune admin center > Tenant administration > Connectors and tokens > Windows data
Enable features requiring Windows diagnostic data. Required for Endpoint Analytics and some Intune reporting features.

#### Step 11 — Break-Glass Account Exclusions

Exclude emergency access accounts from **all** Conditional Access policies before deploying any CA configuration. Break-glass accounts must not be subject to MFA, device compliance, or other access controls.

#### Step 12 — Named Locations (Optional but Recommended)

Create the following named locations in Entra before enabling CA policies that reference country-based controls:

| Named Location | Purpose |
|---|---|
| IAC – Blocked Countries | Countries from which sign-ins should be blocked by CA policy |
| IAC – Allowed Countries | Explicit allowlist for allowlist-only CA model |

### 2.4 Recommended Policies to Deploy

Once all 12 prerequisite steps are confirmed complete, deploy the following via Intune:

- Defender Update Controls (Ring 1, Ring 2, Ring 3 policies)
- Microsoft Defender Antivirus policy (AV settings, Cloud Block Level, scanning)
- Microsoft Defender Antivirus Exclusions policy
- Windows EDR policy
- ASR Rules policy (Audit and Block versions)
- Windows Security Experience policy
- Windows Firewall policy
- macOS Antivirus policy (Mac AV)
- macOS EDR policy
- macOS FileVault policy
- macOS Firewall policy
- BitLocker (Windows)
- Exploit Protection

### 2.5 Settings Catalog Only — Additional Configuration Required

The following settings are **not** available in Endpoint Security policy templates. They must be configured via Intune **Settings Catalog** policies:

| Setting | Recommended Value | Risk if Not Configured |
|---|---|---|
| EnableFileHashComputation | Enabled | Reduced IOC matching reliability |
| Network Protection (Servers) | Enabled Block mode | Not auto-applied to servers via Endpoint Security templates |
| HideExclusionsFromLocalAdmins | Enabled (value: 1) | Local admins can view exclusion paths — reconnaissance risk |
| Quick Scan Include Exclusions | Enabled | Exclusion paths skipped during Quick Scan |
| Performance Mode Status (Dev Drive) | Enabled if using Win11 Dev Drive | Required for Dev Drive workloads |

> Create these as separate Intune Settings Catalog policies and assign to the same device groups used for your Endpoint Security policies.

### 2.6 macOS-Specific Prerequisites

Deploy profiles in the **exact order** listed before deploying the Defender app.

| Order | Profile | Purpose |
|---:|---|---|
| 1 | System Extensions (Settings Catalog) | Approves com.microsoft.wdav.epsext and com.microsoft.wdav.netext |
| 2 | Network Filter (netfilter.mobileconfig) | EDR socket traffic inspection. Only ONE network filter allowed — a second causes connectivity issues |
| 3 | Full Disk Access (fulldisk.mobileconfig) | Required for Defender to scan all files |
| 4 | Background Services (background_services.mobileconfig) | macOS 13+ requires explicit MDM approval for background daemons |
| 5 | Notifications (notif.mobileconfig) | Enables threat notifications in macOS UI |
| 6 | Accessibility (accessibility.mobileconfig) | Required for macOS 10.13.6+ |
| 7 | Bluetooth (bluetooth.mobileconfig) | Required for macOS 14+ (Sonoma) Device Control |
| 8 | Microsoft AutoUpdate (com.microsoft.autoupdate2.mobileconfig) | Controls Defender update channel |
| 9 | AV + EDR Configuration | AV settings, passiveMode flag, EDR configuration |
| 10 | Onboarding Package (WindowsDefenderATPOnboarding.xml) | Licenses the device to the tenant |
| 11 | Deploy Defender App (Intune App — macOS) | Deploy wdav.pkg via Intune Apps > macOS |

> ⚠️ **CRITICAL:** Deploying the onboarding package or Defender app before Full Disk Access and System Extensions are approved results in incomplete installation that may not self-heal without re-enrollment.

---

## 3. Policy Naming Conventions

All policies follow the pattern: **`{Platform} - {Category} - D - {Policy Name}`**

### 3.1 Naming Convention Format

| Segment | Values | Example |
|---|---|---|
| Platform | Win \| Mac | Win |
| Category | Security \| Updates \| Network \| System | Security |
| Product Prefix | D (Defender) | D |
| Policy Name | Descriptive name of the component | Defender Antivirus |

> Full format: `Win - Security - D - Defender Antivirus` | `Mac - Network - D - Firewall` | `Win - Updates - D - Defender Update Controls (Ring 1 Pilot)`

### 3.2 Windows Policy Naming — Full Reference

| Policy Name | Category | Tier / Ring | Notes |
|---|---|---|---|
| **Win - Security - D - Defender Antivirus (Level 1 Baseline)** | Security | Tier 1 | Cloud Block Level: High. Deployed to all endpoints first. |
| Win - Security - D - Defender Antivirus (Level 2 Elevated) | Security | Tier 2 | Cloud Block Level: High Plus. Finance, HR, legal, exec. |
| Win - Security - D - Defender Antivirus (Level 3 High Security) | Security | Tier 3 | Cloud Block Level: Zero Tolerance. Privileged devices only. |
| Win - Security - D - Defender AV Exclusions | Security | Tier 1 | Central exclusion management. Keep separate from AV settings policy. |
| **Win - Updates - D - Defender Update Controls (Ring 1 Pilot)** | Updates | Ring 1 | Current Channel Preview. IT staff and test devices. |
| Win - Updates - D - Defender Update Controls (Ring 2 Standard) | Updates | Ring 2 | Current Channel Broad. Majority of endpoints. |
| Win - Updates - D - Defender Update Controls (Ring 3 Critical) | Updates | Ring 3 | Critical Time Delay. Servers, DCs, critical assets. |
| **Win - Security - D - MDE Onboarding** | Security | Tier 1 | EDR onboarding policy. |
| Win - Security - D - ASR Rules (Audit) | Security | Audit | All ASR rules in Audit mode. Deploy first. |
| **Win - Security - D - ASR Rules (Block)** | Security | Block | Separate policy from Audit — assign after validation. |
| **Win - Network - D - Firewall** | Network | Tier 1 | See rollback note in Section 10. |
| Win - Security - D - Exploit Protection | Security | Tier 1 | |
| Win - Security - D - Audit Device Control | Security | Audit | |
| Win - Security - D - Device Control (Block) | Security | Block | Separate policy promoted after Audit validation. |
| Win - Security - D - BitLocker | Security | Tier 1 | See rollback note — requires separate offboarding policy. |
| Win - Security - D - Windows Security Experience | Security | Tier 1 | Controls visibility of Windows Security app to end users. |
| Win - Security - D - LAPS | Security | Tier 1 | Local Administrator Password Solution. |
| **DefenderForEndpointSettings** | All | Tier 1 | Portal-level settings policy. |

### 3.3 macOS Policy Naming — Full Reference

| Policy Name | Category | Notes |
|---|---|---|
| **Mac - Security - D - Defender Antivirus** | Security | Primary Mac AV policy. Includes passiveMode flag during transition. |
| **Mac - Security - D - MDE Onboarding** | Security | EDR onboarding policy for macOS. |
| Mac - Security - D - FileVault | Security | FileVault encryption management. |
| **Mac - Network - D - Firewall** | Network | Separate from Windows Firewall policy. |
| **Mac - System - D - System Extensions** | System | Intune Settings Catalog. Approves wdav.epsext and wdav.netext. |
| Mac - Network - D - Network Filter | Network | Intune Custom template (netfilter.mobileconfig). |
| Mac - Security - D - Full Disk Access | Security | Intune Custom template (fulldisk.mobileconfig). |
| Mac - System - D - Background Services | System | Required for macOS 13+ (Ventura). |
| Mac - System - D - Notifications | System | Intune Custom template (notif.mobileconfig). |
| Mac - System - D - Accessibility | System | Intune Custom template (accessibility.mobileconfig). |
| Mac - System - D - Bluetooth | System | Required for macOS 14+ (Sonoma) Device Control. |
| **Mac - Updates - D - AutoUpdate** | Updates | Controls Defender update channel (Production/Preview/Beta). |

### 3.4 Rollback Policy Naming Convention

For any policy that requires an explicit 'off' state rather than simply removing the assignment, a dedicated rollback policy must exist **before** the main policy is deployed.

| Initial Policy | Rollback Policy Required? | Rollback Policy Name |
|---|---|---|
| Win - Network - D - Firewall | ⚠️ Yes — firewall state persists after policy removal | Win - Network - D - Firewall (Rollback) |
| Win - Security - D - BitLocker | ⚠️ Yes — encryption persists; decryption requires explicit policy | Win - Security - D - BitLocker (Rollback) |
| Win - Security - D - ASR Rules (Block) | Assign back to Audit policy | Win - Security - D - ASR Rules (Audit) |
| Win - Security - D - Device Control (Block) | Assign back to Audit policy | Win - Security - D - Audit Device Control |
| Win - Security - D - Defender Antivirus (Level 1) | Remove assignment or assign previous version | No separate rollback policy needed |
| Mac - Security - D - Defender Antivirus | Set passiveMode: true in policy | Mac - Security - D - Defender Antivirus (Passive Mode) |
| Mac - Network - D - Firewall | ⚠️ Yes — firewall state persists on macOS | Mac - Network - D - Firewall (Rollback) |

---

## 4. Onboard Endpoints — Windows & macOS

### 4.1 Windows Onboarding via Intune

1. In the Intune admin center, go to **Endpoint Security > Microsoft Defender for Endpoint** and verify the connector status shows **Connected**.
2. In the Defender portal, confirm Intune is selected as the deployment method.
3. In Intune, navigate to **Endpoint security > Endpoint detection and response** and apply the MDE onboarding policy to the target Windows device group.
4. Devices receive the onboarding configuration at next Intune check-in (typically within 15 minutes).
5. Verify in Defender portal > Assets > Devices. Newly onboarded devices appear within 24 hours of first telemetry.

| Verification Check | Expected Result |
|---|---|
| Device appears in Defender portal | Status: Active, Onboarding Status: Onboarded |
| Sensor health | Active (not Inactive or No Sensor Data) |
| AV status | Up to date, Real-time protection: On |
| MDE mode | Active (not Passive — after legacy AV removed) |
| Tamper Protection | Enabled |

### 4.2 macOS Onboarding via Intune

Deploy profiles in the order from Section 2.6. After all profiles are applied and the Defender app is installed:

1. Open **System Settings > General > Device Management** and confirm ALL mobileconfig profiles are present and show as **Verified**.
2. Verify the Microsoft Defender shield icon appears in the macOS menu bar.
3. In Terminal: run `mdatp health` to confirm onboarded status and real-time protection.
4. Test AV detection: download the EICAR test file from eicar.org.
5. Test EDR detection: use the EDR detection test per Microsoft's guidance.
6. Verify device appears in Defender portal > Assets > Devices with Active sensor status.

> Note: If running co-existence with an existing Mac AV, set `passiveMode: true` in the com.microsoft.wdav configuration profile.

### 4.3 Device Group Strategy

| Group Name | Target Devices | Policy Ring Assignment |
|---|---|---|
| MDE-Pilot | IT staff, low-risk devices, test machines | Ring 1 — Current Channel Preview |
| MDE-Standard | Majority of user endpoints (Windows + Mac) | Ring 2 — Current Channel Broad |
| MDE-Critical | High-impact user devices — finance, executive, legal | Ring 3 — Critical Time Delay |
| MDE-Servers | Windows Server workloads — on-prem and Azure | Ring 3 + Server-specific exclusions |
| MDE-Mac | All macOS endpoints | Mac AV + EDR policies |
| MDE-AzureVMs | Azure-native VMs managed via Defender for Cloud | Managed via Defender for Cloud — not Intune groups |

### 4.4 Windows Server Onboarding — Intune Cannot Onboard Servers

> **Key fact:** Intune MDM does not support Windows Server enrollment. Servers require a dedicated onboarding method. However, once servers are onboarded via any of the methods below, **MDE Security Settings Management** allows MDE to manage AV and EDR settings for those servers directly from the Defender portal.

#### Method 1: Azure VMs — Defender for Cloud (Recommended for Azure)

| Item | Detail |
|---|---|
| License required | Microsoft Defender for Cloud — Defender for Servers Plan 1 or Plan 2 |
| Licensing note | NOT included in M365 Business Premium. Billed per server per hour in Azure. |
| How to enable | Azure portal > Defender for Cloud > Environment settings > select subscription > enable Defender for Servers |
| How onboarding happens | Defender for Cloud automatically deploys the MDE extension to all running VMs in scope via the Azure Guest Agent. No onboarding script or Intune policy required. |
| Management after onboarding | AV and EDR settings via MDE Security Settings Management (Defender portal). Apply DefenderForEndpointSettings via the Defender portal. Do NOT apply Intune endpoint security policies to Azure VM device groups. |
| Verification | Azure portal > Defender for Cloud > Inventory — all VMs should show Defender for Servers: Healthy. Defender portal > Assets > Devices — VMs appear with Active sensor status. |

#### Method 2: Non-Azure / On-Premises — Azure Arc + Defender for Cloud

| Item | Detail |
|---|---|
| Prerequisites | Azure Arc Connected Machine Agent deployed on each server |
| Arc agent deployment | Azure portal > Azure Arc > Servers > Add servers > Generate script. Script handles download, registration, and proxy configuration. |
| After Arc agent installed | Server appears in Azure Arc > Servers as Connected. Enable Defender for Servers at subscription level in Defender for Cloud. Defender for Cloud deploys the MDE extension via Arc extension framework. |
| Management after onboarding | Identical to Method 1 — via MDE Security Settings Management / DefenderForEndpointSettings. Not via Intune. |
| Why Arc over script? | Arc provides a full management plane: Defender for Cloud, Azure Policy, Update Manager, and Defender for Servers — all through Arc. Script-only onboarding provides only MDE telemetry. |

#### Method 3: Script-Based Onboarding (No Arc, No Azure)

| Item | Detail |
|---|---|
| Download location | Defender portal > Settings > Endpoints > Device Management > Onboarding > select OS > select Local Script or Group Policy / SCCM |
| Windows Server 2019 / 2022 / 2025 | Use the standard onboarding script. No additional prerequisites. |
| **Windows Server 2012 R2 / 2016** ⚠️ | **These versions require the MDE Unified Agent (md4ws.msi) — not the legacy MMA-based agent. Without the Unified Agent, EDR functionality will be incomplete.** |
| Deployment at scale | GPO (startup script) or SCCM (package/task sequence) or PowerShell Remoting |
| Management after onboarding | AV and EDR settings via MDE Security Settings Management in Defender portal. Settings Catalog Intune policies do NOT apply to script-onboarded servers. |

#### Post-Onboarding: MDE Security Settings Management for Servers

**Path:** Defender portal > Endpoints > Configuration management > Endpoint security policies > Create new policy > select Windows Server as platform.

| Server Scenario | Recommended Management Approach |
|---|---|
| Azure VMs via Defender for Cloud | MDE Security Settings Management. Apply DefenderForEndpointSettings via the Defender portal. |
| Arc-connected on-prem via Defender for Cloud | MDE Security Settings Management. Apply DefenderForEndpointSettings via the Defender portal. |
| Script-onboarded servers (no Arc) | MDE Security Settings Management. Some settings require local GPO for advanced configuration. |
| Windows Server 2012 R2 / 2016 (Unified Agent) | MDE Security Settings Management after Unified Agent install. GPO for advanced settings. |

---

## 5. Order of Operations

| Phase | Component | Action | Gate Before Next Phase |
|---|---|---|---|
| 1 | Portal Setup | MDE Advanced Features, Device Groups, Automation Level, Tamper Protection (tenant) | All portal prerequisites confirmed complete |
| 2 | Update Controls | Deploy Ring 1/2/3 Defender Update Control policies via Intune | Pilot devices showing correct update channel |
| 3 | **NGP / AV (Windows)** | Deploy Defender AV policy to Pilot group (Level 1 baseline, Passive Mode if legacy AV present) | No false positives or performance issues on Pilot for 48–72 hours |
| 4 | **macOS Profiles + AV** | Deploy all mobileconfig profiles in order. Then deploy Mac AV policy via Intune. Set passiveMode: true if co-existing. | All profiles verified applied. mdatp health shows active. |
| 5 | Legacy AV Removal | Uninstall SentinelOne / third-party AV. Confirm Defender exits Passive Mode and enters Active Mode. | Defender shows Active mode in portal. No protection gap confirmed. |
| 6 | **EDR (Windows + Mac)** | Deploy Windows EDR and macOS EDR policies via Intune to Pilot. Validate AIR automation, live response. | EDR events appearing in Defender portal. AIR completing remediations. |
| 7 | Expand to Standard Group | Promote policies from Pilot to MDE-Standard | 72-hour clean pilot window |
| 8 | **ASR Rules — Audit Mode** | Deploy ASR rules in Audit mode across all Windows devices. Review Advanced Hunting for false positive events. | 2-week audit window minimum |
| 9 | **ASR Rules — Block Mode** | Promote ASR rules to Block mode. Exclude per-persona devices as needed. | All identified false positives addressed. |
| 10 | Critical Group Expansion | Deploy all policies to MDE-Critical and MDE-Servers. Heightened change window caution. | Dedicated maintenance window. Rollback plan ready. |

---

## 6. Next Generation Protection — AV Configuration

### 6.1 The Three-Level Architecture — Level-Based Policy Design

| Level | Cloud Block Level | Target Devices | Key Characteristic |
|---|---|---|---|
| **Level 1** | High | All devices — baseline | Broad deployment. Balances protection with low false-positive risk. Starting point. |
| **Level 2** | High Plus | Elevated risk profile devices | Finance, HR, legal, executive assistants — high-value targets. |
| **Level 3** | Zero Tolerance | Locked-down privileged devices | Only known-good executables per Microsoft ISG. Use only with Application Control in place. |

### 6.2 AV Policy Settings — Level 1 Baseline (All Devices)

Configure via Intune: **Endpoint security > Antivirus > Create policy > Windows > Microsoft Defender Antivirus**

| Setting | Recommended Value | Notes |
|---|---|---|
| **Cloud-Delivered Protection** | Enabled | Non-negotiable. Underpins Block at First Sight and many ASR rules. Never disable. |
| **Cloud Block Level** | High (Level 1) | Set explicitly — do not leave as Not Configured. |
| **Cloud Extended Timeout** | 50 seconds | Gives Block at First Sight maximum analysis time. Max is 60 (10 are built in). |
| **Submit Samples Consent** | Send Safe Samples Automatically | Avoids user prompts. Never Send breaks Block at First Sight. |
| Behavior Monitoring | Enabled | Fundamental to real-time protection |
| Real-Time Monitoring | Enabled | Never disable under any circumstances |
| Allow Archive Scanning | Allow (Enabled) | Performance trade-off — enable unless specific high-archive scenario |
| Email Scanning | Enabled | Applies to legacy PST clients. Enable for thoroughness. |
| Scan Mapped Network Drives | Not Allowed (Disabled) | For client devices — causes serious performance issues. Enable on servers. |
| Allow Full Scan Removable Drive | Allow | Enable unless specific high-volume removable storage scenario |
| Allow Scanning Network Files | Allow | Default is Off. Set Allow; claw back if server performance issues. |
| Script Scanning | Allow | Always on |
| Intrusion Prevention | Enabled | Deprecated but still recommended — belt-and-suspenders |
| Allow Scanning Downloaded Files & Attachments | Allow | Important for browser-downloaded content |
| **Network Protection** | Block Mode | Start in Audit if cautious. Required for custom indicators to function. |
| **PUA Protection** | Block (Audit first) | Use Audit Mode with Advanced Hunting to confirm no legitimate apps are caught. |
| Real-Time Scan Detection | Bidirectional | Most thorough. Reduce to incoming-only on servers with performance constraints. |
| **Disable Local Admin Merge** | Yes | Prevents local admins adding their own exclusions. |
| Threat Actions (Low/Medium/High/Severe) | Quarantine (all) | Never Allow. Clean is deprecated. |
| Schedule Full Scan | Disabled | Real-time protection covers ongoing risk. |
| Schedule Quick Scan | Every day | Complements real-time protection |
| Disable Catchup Quick Scan | Enabled (double-negative) | Watch the logic inversion — enabling this setting = catchup is disabled |
| Check for Signatures Before Scan | Enabled | Always update signatures before scan runs |
| Signature Update Interval | 1 hour | Smaller delta updates. Faster recovery from bad signature. |
| Signature Update Fallback Order | MU first, then file share | Use file share fallback for VDI. Move away from WSUS for signatures. |
| Disable Defender Core Service | Do NOT disable | Sends anomaly data to Microsoft for fix feedback loop. |

### 6.3 Update Ring Architecture — 3-Ring Deployment Model

Configure via Intune: **Devices > Windows > Configuration profiles > Settings Catalog** (search "Defender Update")

| Ring | Platform Channel | Engine Channel | SIU Channel | Target |
|---|---|---|---|---|
| **Ring 1 — Pilot** | Current Channel Preview | Current Channel Preview | Not Configured | IT staff, test devices |
| **Ring 2 — Standard** | Current Channel Broad | Current Channel Broad | Current Channel Broad | Majority of endpoints |
| **Ring 3 — Critical** | Critical Time Delay | Critical Time Delay | Current Channel Broad | DCs, servers, critical assets |

> ⚠️ Never leave update channels as 'Not Configured' for Ring 2 and Ring 3. Not Configured can place devices as early as Beta channel position in Microsoft's gradual rollout model. Always set explicitly.
>
> For SMB customers (Business Premium), a 2-ring model is sufficient: Standard (Current Channel Broad) and Critical (Critical Time Delay).

---

## 7. Endpoint Detection and Response — EDR Configuration

### 7.1 Windows EDR Policy

Configure via Intune: **Endpoint security > Endpoint detection and response**

| Setting | Recommended Value | Notes |
|---|---|---|
| **EDR in Block Mode** | Enabled | Allows MDE to block malicious artifacts even when a third-party AV is primary. Essential during co-existence transition. |
| **Sample Sharing** | Enabled | Required for Microsoft analysis. Supports Block at First Sight. |
| **Telemetry Reporting Frequency** | Expedited | Faster incident detection. Use Standard only if bandwidth-constrained. |
| Automated Investigation and Remediation | Full — remediate threats automatically | Full AIR is the recommended setting. Never 'No automated response'. |
| Live Response | Enabled | Required for incident response. Ensure RBAC is scoped. |
| Live Response for Servers | Enabled if servers are onboarded | Separate toggle — easy to miss. |
| Unsigned Script Execution in Live Response | Disabled (Blocked) | Prevents unsigned scripts via Live Response — reduces compromised-analyst risk. |

### 7.2 macOS EDR Policy

Configure via Intune: **Endpoint security > Endpoint detection and response > macOS**

| Setting | Recommended Value | Notes |
|---|---|---|
| Tags (device tagging) | Configure environment/group tags | Used for device group targeting and RBAC scoping |
| groupIds | Match to MDE device group | Links macOS device to correct MDE device group |
| **passiveMode (during transition)** | true if legacy AV present; false once legacy AV removed | CRITICAL: Must be true during co-existence with another Mac AV. |
| Enable real-time protection | true | Set explicitly |
| Enable cloud-delivered protection | true | Required for BAFS and threat intelligence |
| EDR early preview | Enabled | Faster threat detection improvements on macOS |

### 7.3 Automated Investigation and Remediation (AIR)

> ⚠️ Setting AIR to 'No automated response' does not just slow down remediation — it **disables Automatic Attack Disruption**. Never disable AIR.

| AIR Level | Behavior | Recommendation |
|---|---|---|
| **Full — remediate automatically** | All threat-family remediations occur without analyst approval | **Recommended for all device groups. Enables Attack Disruption.** |
| Semi — require approval for core folders | Remediations in user/temp folders automatic; core OS/program folders require approval | Acceptable for organizations with a dedicated SOC |
| Semi — require approval for non-temp folders | Most remediations require approval | Not recommended — slows response |
| **No automated response** | No automated investigation or remediation. **Attack Disruption disabled.** | **Never use.** |

---

## 8. Attack Surface Reduction Rules

### 8.1 ASR Philosophy and Lifecycle

| Mode | Behavior | When to Use |
|---|---|---|
| **Audit** | Events logged. No blocking. | Always start here. Minimum 2 weeks before promoting. |
| **Warn** | Action blocked but user can override. | Optional intermediate step. |
| **Block** | Action blocked. User cannot override. | End state for all ASR rules. |
| Disabled | Rule inactive. | Only for rules with confirmed, documented business conflicts. |

### 8.2 Recommended ASR Rules — Deployment Reference

Configure via Intune: **Endpoint security > Attack surface reduction**

| ASR Rule | Target Mode | Notes |
|---|---|---|
| Block executable content from email client and webmail | Block | High-value rule. Low false-positive risk. |
| **Block all Office applications from creating child processes** | Block | Covers macro-to-PowerShell attack chains. Most impactful single ASR rule. |
| Block Office applications from creating executable content | Block | Prevents Office apps writing executables to disk |
| Block Office applications from injecting code into other processes | Block | Blocks process injection from Office |
| Block JavaScript or VBScript from launching downloaded executable content | Block | Blocks drive-by download execution chains |
| Block execution of potentially obfuscated scripts | Block (Audit first — high FP risk in dev environments) | Can catch legitimate obfuscated PowerShell. Audit carefully. |
| Block Win32 API calls from Office macros | Block | Blocks macro-based Win32 API abuse |
| **Block credential stealing from Windows LSASS** | Block | Critical rule — prevents Mimikatz-style credential theft. High priority. |
| Block process creations originating from PSExec and WMI commands | Warn / Block (Audit first) | Can conflict with legitimate admin tooling. Audit carefully. |
| Block untrusted and unsigned processes that run from USB | Block | Removable media attack vector. Low false-positive risk. |
| Use advanced protection against ransomware | Block | Broad ransomware behavioral detection. |
| Block Adobe Reader from creating child processes | Block | PDF-based exploitation vector. |
| Block Office communication application from creating child processes | Block | Covers Teams and Outlook spawning child processes |
| Block abuse of exploited vulnerable signed drivers | Block | Requires recent Intune policy type. Verify your Intune template version supports this rule. |

### 8.3 Per-Persona ASR Exclusions

| Persona | Rules to Exclude / Disable | Justification |
|---|---|---|
| Software Developers | Block obfuscated scripts, Block Win32 API calls from macros | Legitimate build scripts and tooling |
| IT Administrators | PSExec and WMI block | Admin tooling (PsTools, WMI-based management) |
| Legal / Finance (specific apps) | Rule-specific exclusion for known application path | Documented child process or API usage |

---

## 9. Exclusions Management

### 9.1 Core Principle: Start at Zero

Start with zero exclusions and add only when a specific, documented performance or compatibility issue is confirmed. Never migrate legacy AV exclusions wholesale.

### 9.2 Exclusion Types

| Type | Scope | Risk Level |
|---|---|---|
| File path exclusion | Excludes a specific file or folder from scanning | **HIGH** — broad; an attacker who places a malicious file in the excluded path evades detection |
| Process exclusion | Excludes files opened by a specific process | **MEDIUM** — scoped to process context |
| File extension exclusion | Excludes all files with a specific extension | **VERY HIGH** — should almost never be used |
| ASR per-rule exclusion | Excludes a specific path/process from one ASR rule only | **LOW** — targeted, does not affect AV scanning or other ASR rules |

### 9.3 Exclusion Governance Process

1. Performance or compatibility issue is reported. Ticket created.
2. MDE Troubleshooting Mode is activated on the affected device (see Section 11).
3. Confirm the issue is Defender-related.
4. Identify the minimum-scope exclusion that resolves the issue.
5. Exclusion added in Intune: **Endpoint security > Antivirus > Microsoft Defender Antivirus Exclusions**.
6. Document: exclusion path/process/extension, application name, business owner, date added, review date.
7. Review exclusion list quarterly. Remove any that cannot be justified.

---

## 10. Rollback Plan

### 10.1 Rollback Triggers

- Critical business application blocked or crashes across multiple devices simultaneously
- Widespread performance degradation (>20% CPU utilization increase attributable to Defender)
- Critical server goes offline due to a Defender-related conflict
- Mass false-positive event where legitimate files are quarantined at scale
- ASR Block mode rule causing broad user disruption that cannot be resolved with exclusions within SLA

### 10.2 Windows Rollback Procedure

| Step | Action | Detail |
|---|---|---|
| 1 | Identify scope | Determine if issue is specific to a device group or policy. Check Defender portal for alerts/events correlated with the change window. |
| 2 | Revert policy in Intune | For AV issues: revert Defender Antivirus policy to previous version or remove from affected group. For ASR: set offending rule(s) back to Audit mode. |
| 3 | Verify policy rollback applied | Use Defender portal > Device page > Configuration management > Effective Settings to verify. |
| 4 | Clear Quarantine if needed | Defender portal > Action Center > Quarantine. Review and restore false-positive quarantined files. |
| 5 | Document root cause | Identify what triggered the issue. Update exclusion list or policy before re-deploying. |
| 6 | Re-deploy with fix | Re-deploy the policy with the corrected exclusion or setting. Monitor for 48 hours. |

### 10.3 macOS Rollback Procedure

| Step | Action | Detail |
|---|---|---|
| 1 | Identify scope | Use `mdatp health` on affected device to confirm Defender state. |
| 2 | Set passiveMode: true | Update the Mac AV policy to set passiveMode: true — returns Defender to observer state without removing it. |
| 3 | Revert Mac AV or EDR policy in Intune | Devices receive update at next MDM check-in. |
| 4 | Force MDM sync if needed | System Settings > General > Device Management > select profile > Check for updates. Or Intune: Devices > All Devices > device > Sync. |
| 5 | If uninstall required | Use Intune to deploy an uninstall command. Do not uninstall manually — re-enrollment will be needed. |
| 6 | Document and re-deploy | Identify root cause (FDA missing? System extension conflict? passiveMode not set?). Fix and redeploy in correct order. |

### 10.4 Toggle Policies — Separate Rollback Policy Required

Certain policies place the endpoint in a state that **persists even if the policy assignment is removed**. A dedicated rollback policy must be created **before** the initial policy is deployed.

#### Windows Firewall

| Policy | Configuration |
|---|---|
| Win - Network - D - Firewall (Initial) | Domain/Private/Public: Enabled \| Inbound: Block by default \| Outbound: Allow by default |
| Win - Network - D - Firewall (Rollback) | Set profiles to Not Configured — OR — explicitly set lower-restriction state as required |

Rollback: in Intune, unassign the initial firewall policy and assign the rollback policy to the same group. Do not simply unassign without assigning the rollback policy.

#### BitLocker

| Policy | Configuration |
|---|---|
| Win - Security - D - BitLocker (Initial) | Require device encryption: Yes \| Recovery key backup: Entra ID \| Block recovery key from local storage: Yes |
| Win - Security - D - BitLocker (Rollback) | Require device encryption: Not Configured — suspends enforcement but does NOT decrypt drives |

> ⚠️ Never deploy BitLocker without first confirming recovery key escrow to Entra ID is working in the Pilot group. Validate: Entra portal > Devices > BitLocker Keys.

#### ASR Rules — Re-Assignment Model

To roll back from Block to Audit: unassign **Win - Security - D - ASR Rules (Block)** and assign **Win - Security - D - ASR Rules (Audit)** to the same group. No separate rollback policy is needed — the Audit policy already exists from the initial deployment phase.

#### macOS Firewall

| Policy | Configuration |
|---|---|
| Mac - Network - D - Firewall (Initial) | Enable Firewall: true \| Block All Incoming: false \| Enable Stealth Mode: true |
| Mac - Network - D - Firewall (Rollback) | Enable Firewall: false |

#### macOS Passive Mode — Re-Assignment Model

Two versions of the Mac AV policy should exist:
- **Mac - Security - D - Defender Antivirus**: `passiveMode: false` (standard production state post-migration)
- **Mac - Security - D - Defender Antivirus (Passive Mode)**: `passiveMode: true` (used during co-existence and as rollback if AV conflict detected)

### 10.5 Emergency — Complete MDE Removal (Last Resort)

1. Open a P1 case with Microsoft Support before removing MDE from production servers or critical assets.
2. Confirm rollback of all Intune MDE policies (AV, EDR, ASR, Firewall) before any uninstall is attempted.
3. **Windows:** Use Intune or SCCM to deploy the MDE offboarding package. Do not use Add/Remove Programs — offboarding must go through the proper channel to deregister the device from the portal.
4. **macOS:** Deploy uninstall via Intune shell script or use the `mdatp uninstall` command via a managed endpoint.
5. Confirm device no longer appears as Active in Defender portal within 24 hours.
6. Re-engage the legacy AV solution if available, or deploy an alternative protection layer.
7. Schedule re-onboarding with root cause resolution documented.

---

## 11. Technical Troubleshooting

### 11.1 Is It Defender? — The First Question

Before adding any exclusion or making any configuration change, confirm the issue is actually caused by Defender. MDE Troubleshooting Mode provides a structured, reversible method to answer this question without permanently weakening endpoint protection.

### 11.2 MDE Troubleshooting Mode

Troubleshooting Mode activates a temporary **4-hour window** on a specific device where Tamper Protection can be overridden via PowerShell. All changes revert automatically when the window expires. No permanent configuration changes result from this process.

**Prerequisites:**
- Endpoint must be onboarded to MDE
- Troubleshooting Mode must be activated via the Defender portal BEFORE running any PowerShell
- Elevated PowerShell session required
- Changes auto-revert after 4 hours

#### Step 0 — Activate Troubleshooting Mode

1. Defender portal > Assets > Devices > select target device
2. Three-dot menu > **Turn on troubleshooting mode**
3. Confirm **Troubleshooting mode: On** status on the device tile
4. On the device, open elevated PowerShell and run:

```powershell
Set-MpPreference -DisableTamperProtection $true
```

5. Capture baseline before making any changes:

```powershell
Get-MpPreference | Select-Object CloudBlockLevel, CloudExtendedTimeout, ScanAvgCPULoadFactor, DisableScanningNetworkFiles, EnableFileHashComputation, PUAProtection, DisableRealtimeMonitoring, DisableBehaviorMonitoring, DisableBlockAtFirstSeen, DisableIOAVProtection, EnableNetworkProtection | Format-List | Out-File "C:\Temp\MDE_Baseline.txt"
```

#### Step 1 — Performance Tuning (Try This First)

Reduces performance impact without disabling core protections. If the issue resolves, do **NOT** proceed to Step 2.

| Setting Applied | Value | Purpose |
|---|---|---|
| CloudBlockLevel | 0 | Temporarily reduces cloud blocking aggressiveness |
| CloudExtendedTimeout | 10 | Reduces cloud timeout to minimum |
| ScanAvgCPULoadFactor | 20 | Limits scanner CPU consumption |
| DisableScanningNetworkFiles | True | Removes network file scanning overhead |
| EnableFileHashComputation | False | Reduces per-file hash computation overhead |
| PUAProtection | Disabled | Removes PUA detection overhead |

After applying Step 1 settings, test for 30–60 minutes. If performance issue resolves: identify the specific Step 1 setting causing the issue and create a targeted exclusion or configuration adjustment for that setting only.

#### Step 2 — Full Protection Disable (Only If Step 1 Fails)

> ⚠️ Step 2 removes all active protections. Use ONLY when Step 1 does not resolve the issue. Do not leave endpoints in Step 2 state. The 4-hour auto-revert is your safety net.

| Setting Disabled | Value | What It Removes |
|---|---|---|
| DisableRealtimeMonitoring | True | Real-time file scanning |
| DisableBehaviorMonitoring | True | Behavioral detection engine |
| DisableBlockAtFirstSeen | True | Cloud-based zero-day blocking |
| DisableIOAVProtection | True | Download and attachment scanning |
| EnableNetworkProtection | 0 (Disabled) | Network-level malicious URL/IP blocking |

**Known Limitation:** If `HideExclusionsFromLocalAdmins` is enforced via Intune policy, even with Troubleshooting Mode active you cannot query exclusions added via policy. The exclusions remain active and enforced but are invisible to `Get-MpPreference`.

### 11.3 Effective Settings — The Primary Diagnostic Tool

**Location:** Defender portal > Assets > Devices > select device > Configuration management tab > **Effective Settings** tab

Shows for each Defender AV setting: current effective value, source (Intune, GPO, MDE-Management, Default), policy type, and any conflicting values that did NOT take effect.

| What to Look For | What It Means |
|---|---|
| Source = GPO for settings you expect to be Intune-managed | A Group Policy Object is overriding your Intune policy. Resolve at the GPO source. |
| Additional configuration attempts showing a different value | A conflicting policy exists. Identify and remove the losing source. |
| Source = Default for critical settings like Cloud Block Level | The setting is not being applied from any management source. Policy may not be assigned to the device's group. |
| Source = MDE-Management | The setting is managed directly via the Defender portal. Confirm this is intentional. |

### 11.4 Policy Conflict Sources

Policy precedence in a hybrid-managed environment (highest to lowest):

| Order | Source | Notes |
|---|---|---|
| **1** | **Domain GPO** | **Overrides everything — including Intune MDM policies.** If a GPO exists for Defender settings, it will win. Remove Defender GPO settings from domain policy. |
| 2 | Intune MDM | Second priority. Wins over local policy and PowerShell unless GPO is present. |
| 3 | Local Group Policy | Third. Overridden by Intune. |
| 4 | PowerShell / Set-MpPreference | Overridden at next GP refresh. Not a reliable management method. |
| 5 | Registry edits | Often overridden. Not reliable. |

### 11.5 Event Log Locations

**Windows:** Event Viewer > Applications and Services Logs > Microsoft > Windows > Windows Defender > Operational

| Event ID | Meaning |
|---|---|
| 5007 | Configuration change applied — shows what changed and from what source |
| 5010 | Policy application failed — indicates a settings conflict or schema issue |
| 2001 / 2004 | ASR rule applied or triggered |
| 1006 | Scan completed |
| 1116 | Malware detected |
| 1117 | Action taken on malware (quarantine, remove, etc.) |

### 11.6 macOS Diagnostic Commands

| Command | Purpose |
|---|---|
| `mdatp health` | Full health status — onboarded, real-time protection, cloud connectivity, engine version |
| `mdatp health --field real_time_protection_enabled` | Quick check of RTP status only |
| `mdatp health --field cloud_enabled` | Confirm cloud-delivered protection is active |
| `mdatp health --field passive_mode_enabled` | Confirm whether passive mode is active |
| `mdatp config real-time-protection --value enabled` | Enable RTP via command line (requires sudo) |
| `mdatp exclusion list` | List all active exclusions on the device |
| `mdatp threat list` | Show threats detected on the device |
| `sudo mdatp diagnostic create` | Generate a full diagnostic bundle for Microsoft Support |

### 11.7 MDEValidator — Automated Configuration Validation

**GitHub:** [https://github.com/NateHutch365/MDEValidator](https://github.com/NateHutch365/MDEValidator)

MDEValidator is a PowerShell module by Nate Hutchinson that runs a comprehensive set of validation checks against MDE configuration on a Windows endpoint. It is the fastest way to confirm whether a device's Defender settings match your intended policy — and to produce a shareable report for documentation or escalation. Pair it with Nate's troubleshooting video (see Additional Resources) for a complete isolation workflow when Defender is suspected of causing performance issues.

**Install and run:**

```powershell
# Clone or download the repo, then:
Import-Module .\MDEValidator\MDEValidator.psd1

# Console report — all checks
Get-MDEValidationReport

# Include onboarding status
Get-MDEValidationReport -IncludeOnboarding

# HTML report (ideal for documentation or client reporting)
Get-MDEValidationReport -OutputFormat HTML -OutputPath "C:\Reports\MDEReport.html"

# Return PowerShell objects for filtering
$results = Get-MDEValidationReport -OutputFormat Object
$results | Where-Object { $_.Status -eq 'Fail' }
```

**What MDEValidator checks:**

| Check Category | What It Validates |
|---|---|
| Service Status | Windows Defender service running and set to auto-start |
| Passive Mode | Whether Defender is in Active or Passive Mode |
| Core Protections | Real-time protection, behavior monitoring, cloud-delivered protection, Block at First Sight |
| Cloud Block Level | Explicit check for High / High Plus / Zero Tolerance setting |
| Cloud Extended Timeout | Validates the 50-second timeout is configured |
| Sample Submission | Confirms automatic sample submission is enabled (warns if set to "Always Prompt") |
| Network Protection | Block mode vs Audit vs Disabled |
| PUA Protection | Block vs Audit vs Disabled |
| ASR Rules | Lists all rules and their mode (Audit / Block / Disabled) — flags if all are Audit-only |
| Tamper Protection | Main Tamper Protection + Tamper Protection for Exclusions (separate check) |
| Exclusion Visibility | Validates `HideExclusionsFromLocalAdmins` and local user exclusion visibility |
| Disable Local Admin Merge | Confirms `DisableLocalAdminMerge` is set |
| File Hash Computation | Validates `EnableFileHashComputation` is on |
| Signature Update Settings | Interval and fallback order |
| MDE Onboarding Status | Confirms device is onboarded to tenant |
| Device Tags | Lists locally applied MDE tags |
| Edge SmartScreen | SmartScreen enabled, PUA blocking, user override controls |
| Policy Registry Verification | Optional cross-check of `Get-MpPreference` values against registry for Intune/GPO/SCCM |

> ⚠️ **Known limitation with `HideExclusionsFromLocalAdmins`:** When this setting is enforced via Intune, it restricts access to the entire Intune Policy Manager registry path (`HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager`). Running `-IncludePolicyVerification` on these devices will return Access Denied for policy registry sub-tests. This is expected behavior — the setting is working correctly.

**When to use MDEValidator:**

- After initial MDE deployment on the Pilot group — confirm all settings applied correctly before promoting to Standard
- After any AV or EDR policy change — verify effective settings match intended configuration
- When a user reports a security tool conflict or performance issue — run before opening exclusions
- For quarterly compliance reporting — generate HTML reports as evidence of configuration state
- When a device is flagged as misconfigured in the Defender portal — run locally to compare effective settings vs. portal view

---

## 12. Things to Consider

### 12.1 MDE Is Not Set and Forget

Microsoft continuously releases new features, new ASR rules, new detection capabilities, and new configuration options. An environment configured 12 months ago is likely missing significant protection capabilities. Establish a regular review cadence: monthly Threat Analytics review, weekly Action Center review, quarterly ASR audit event review, and quarterly Advanced Features review.

### 12.2 Tamper Protection for Exclusions

Tamper Protection for Exclusions is a separate setting from Tamper Protection for AV settings, and is frequently missed. When enabled, it prevents local admins from modifying the exclusion list even with local administrator rights. Configure via both the Intune policy (`DisableLocalAdminMerge`) and the Defender portal Advanced Features (Tamper Protection for Exclusions).

### 12.3 Windows Server Considerations

- Windows Server 2012 R2 and 2016 require the Unified Agent migration (KB5005292 for EDR sensor). The legacy MMA-based agent is not equivalent.
- Scan Mapped Network Drives should remain Disabled for client devices but may need to be enabled selectively on servers.
- Network Protection requires additional configuration steps on servers — use Settings Catalog.
- Linux MDE onboarding defaults to Passive Mode — explicit activation to Active Mode is required. Configure via Intune: **Devices > Linux > Configuration profiles**.
- Azure Arc on Domain Controllers creates a privileged access risk — Arc admins can achieve Domain Admin equivalent access via Custom Script Extension. Tag Tier-0 devices and create dedicated restricted resource groups.

### 12.4 MDI and Identity Integration

The most powerful MDE deployments are paired with Microsoft Defender for Identity (MDI). MDI provides domain controller-level identity telemetry that feeds into Attack Disruption. Without MDI, Attack Disruption has limited identity context. For organizations on Business Premium without MDI licensing, Entra ID Protection Conditional Access policies provide a partial substitute.

### 12.5 Sentinel Migration Deadline (July 2026)

The Sentinel experience in the Azure portal retires on **July 1, 2026** and moves to the Defender portal. This requires migration preparation including custom detection rules, automation rules, and alert correlation configuration. Begin migration planning now.

### 12.6 Device Discovery and Enterprise IoT

Enable Standard Discovery mode once MDE is deployed (not Basic). Standard Discovery mode is a prerequisite for Attack Disruption to contain unmanaged devices. Enable Enterprise IoT discovery when licensed — each E5 license includes 5 EIoT device licenses.

### 12.7 Copilot and App Governance

App Governance is a Defender for Cloud Apps feature included in the license that is almost universally ignored during initial deployments. Enable App Governance and activate the preset/template policies immediately — they exist with no action configured by default. Location: Defender XDR > Settings > Cloud Apps > App Governance > Turn on.

### 12.8 Co-Management Conflict Avoidance

If the environment uses both SCCM/ConfigMgr and Intune (co-management), Defender AV settings can receive conflicting values from both channels. Manage all Defender settings from a single source. Prefer Intune as the authoritative source. Move Defender workloads in SCCM to Intune authority as part of the MDE deployment project.

---

## Additional Resources

### Configuration Reference Videos

| Title | Author | Link | What It Covers |
|---|---|---|---|
| Hackers Love Your Default Defender Setup [Fix: Copy These Settings] | Ru Campbell | [Watch on YouTube](https://www.youtube.com/watch?v=R8btJ_SjwVk&t=243s) | Why default Defender AV settings leave endpoints exposed and the specific settings to harden — AV, NGP, and ASR best practices. Directly aligned with the Level 1 baseline in Section 6 of this guide. |

### Troubleshooting and Validation Videos

| Title | Author | Link | What It Covers |
|---|---|---|---|
| Defender Causing Performance Issues? [How to Test It] | Nate Hutchinson | [Watch on YouTube](https://www.youtube.com/watch?v=QIdPLoUiZso) | Step-by-step walkthrough of using MDE Troubleshooting Mode to isolate whether Defender is the cause of a performance or compatibility issue — directly aligned with Section 11.2 of this guide. |

### Troubleshooting and Validation Tools

| Tool | Author | Link | What It Does |
|---|---|---|---|
| MDEValidator | Nate Hutchinson | [github.com/NateHutch365/MDEValidator](https://github.com/NateHutch365/MDEValidator) | PowerShell module that validates MDE configuration settings on a Windows endpoint. Outputs Pass/Fail/Warn status per setting with console and HTML reporting. See Section 11.7 for full usage. |

---

## Appendix A — Intune Policy Reference

| What You Need to Configure | Intune Policy Location | Notes |
|---|---|---|
| AV settings (Windows) | Defender for Endpoint > Windows > Microsoft Defender Antivirus | Core AV settings, cloud block level, scanning, PUA, network protection |
| AV exclusions (Windows) | Defender for Endpoint > Windows > Microsoft Defender Antivirus Exclusions | Central exclusion management. Disable local admin merge here. |
| EDR (Windows) | Defender for Endpoint > Windows > EDR | EDR in Block Mode, sample sharing, telemetry frequency |
| ASR Rules (Windows) | Defender for Endpoint > Windows > ASR Rules | Deploy in Audit first. One policy per rule level. |
| Update Controls (All) | Defender for Endpoint > All > Defender Update Controls | 3 policies: Ring 1, Ring 2, Ring 3 |
| AV (macOS) | Defender for Endpoint > macOS > Antivirus | passiveMode, enforcement level, cloud protection |
| EDR (macOS) | Defender for Endpoint > macOS > EDR | Tags, group IDs, early preview |
| BitLocker | Defender for Endpoint > Windows > BitLocker | |
| Windows Firewall | Defender for Endpoint > Windows > Windows Firewall | |
| Windows Security Experience | Defender for Endpoint > Windows > Windows Security Experience | Controls end-user Windows Security app visibility |
| Settings Catalog — Advanced Settings | Intune > Devices > Windows > Configuration profiles > Settings Catalog | Not available in Endpoint Security policy templates — EnableFileHashComputation, HideExclusionsFromLocalAdmins, Network Protection servers |

---

## Appendix B — macOS Profile Checklist

| ✓ | Profile | Intune Profile Type | Source File |
|---|---|---|---|
| ☐ | System Extensions | Settings Catalog — System Configuration > System Extensions | Configure via Settings Catalog (not mobileconfig import) |
| ☐ | Network Filter | Templates > Custom | netfilter.mobileconfig (GitHub: microsoft/mdatp-xplat) |
| ☐ | Full Disk Access | Templates > Custom | fulldisk.mobileconfig |
| ☐ | Background Services | Templates > Custom | background_services.mobileconfig |
| ☐ | Notifications | Templates > Custom | notif.mobileconfig |
| ☐ | Accessibility | Templates > Custom | accessibility.mobileconfig |
| ☐ | Bluetooth (macOS 14+) | Templates > Custom | bluetooth.mobileconfig |
| ☐ | Microsoft AutoUpdate | Templates > Custom | com.microsoft.autoupdate2.mobileconfig |
| ☐ | AV + EDR Config | Defender Portal or Intune Custom (com.microsoft.wdav) | macOS AV/EDR policy (com.microsoft.wdav profile) |
| ☐ | Onboarding Package | Templates > Custom | WindowsDefenderATPOnboarding.xml (from Defender portal download) |
| ☐ | Deploy Defender App | Apps > macOS > Microsoft Defender for Endpoint | Intune App deployment — not a profile |

---

*Document prepared by Jon Hope | Microsoft MVP — M365 Security*
*Version 1.0 | April 2026*
