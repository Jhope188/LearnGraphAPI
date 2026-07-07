# M365 Group Naming Standard

> **Version:** 1.0  
> **Scope:** Microsoft Entra ID, Intune, SharePoint Online, Microsoft Purview, AI & Agent Identities  
> **Applies to:** All security groups, governance groups, and non-human identity groups created in the tenant

---

## Table of contents

1. [Overview](#1-overview)
2. [Prefix conventions](#2-prefix-conventions)
3. [Type codes](#3-type-codes)
4. [Acronym glossary](#4-acronym-glossary)
5. [Entra & identity groups](#5-entra--identity-groups)
6. [Intune & device groups](#6-intune--device-groups)
7. [Data governance — Purview](#7-data-governance--purview)
8. [Data governance — SharePoint Online](#8-data-governance--sharepoint-online)
9. [AI, agents & non-human identities](#9-ai-agents--non-human-identities)
10. [Security & admin role groups](#10-security--admin-role-groups)
11. [Naming rules & constraints](#11-naming-rules--constraints)
12. [Dynamic membership rules reference](#12-dynamic-membership-rules-reference)
13. [GDAP groups — partner access](#13-gdap-groups--partner-access)

---

## 1. Overview

All groups in this tenant follow one of two root prefixes:

| Prefix | Purpose | Used for |
|--------|---------|----------|
| `SG` | Security Group | Identity, CA policy, Intune, device management, admin roles, security operations, AI/agent identities |
| `DG` | Data Governance Group | SharePoint site access, Purview DLP, sensitivity labels, retention, compliance |

Every group name follows the pattern:

```
SG-[Pillar]-[TypeCode]-[Scope]-[Env]-[Name]
DG-[Service]-[TypeCode]-[Policy/Site]-[Role]
```

Fields are separated by hyphens. PascalCase is used within each segment. No spaces, no emojis, no special characters.

---

## 2. Prefix conventions

### SG — Security Group

```
SG-[Pillar]-[TypeCode]-[Scope]-[Env]-[Name]
```

| Field | Description | Examples |
|-------|-------------|---------|
| `Pillar` | Technology area | `Entra` `Intune` `Admin` `Security` `NHI` |
| `TypeCode` | Group membership type | `AUG` `DUG` `ADG` `DDG` |
| `Scope` | Platform, policy area, or function | `WIN` `MAC` `CA` `MFA` `AVD` |
| `Env` *(optional)* | Deployment ring | `Pilot` `Prod` |
| `Name` | Specific purpose | `DeviceAdmins` `GlobalExclusions` |

**Examples:**

```
SG-Entra-AUG-CAP-GlobalExclusions
SG-Entra-DUG-License-P1InternalUsers
SG-Intune-ADG-WIN-Pilot-Devices
SG-Intune-AUG-MAC-Prod-Users
SG-Intune-DDG-AVD-Prod-HostDevices
SG-Admin-AUG-SecurityAdmins
SG-NHI-AUG-Agents-CopilotStudio-Prod
```

### DG — Data Governance Group

```
DG-[Service]-[TypeCode]-[Policy/Site]-[Role]
```

| Field | Description | Examples |
|-------|-------------|---------|
| `Service` | M365 service | `SPO` `Purview` |
| `TypeCode` | Group membership type | `AUG` `DUG` |
| `Policy/Site` | DLP policy, label name, or site name | `DLP` `Label` `Finance-BudgetPlanning` |
| `Role` | Access level or policy direction | `Owners` `Members` `Visitors` `Included` `Excluded` |

**Examples:**

```
DG-SPO-Finance-BudgetPlanning-Owners
DG-SPO-HR-Onboarding-Members
DG-Purview-AUG-DLP-BrowserProtection-Excluded
DG-Purview-AUG-Label-Confidential-Users
DG-Purview-AUG-InsiderRisk-ScopedUsers
```

---

## 3. Type codes

Type codes describe how group membership is managed in Entra ID.

| Code | Full name | Membership | When to use |
|------|-----------|-----------|-------------|
| `AUG` | Assigned User Group | Manual — admin assigns members | Named users, role assignments, CA exclusions, app access |
| `DUG` | Dynamic User Group | Automatic — Entra rule evaluates user attributes | License groups, department-based groups, lifecycle states |
| `ADG` | Assigned Device Group | Manual — admin assigns devices | Pilot device rings, exclusion groups, specific hardware sets |
| `DDG` | Dynamic Device Group | Automatic — Entra rule evaluates device attributes | All devices of a platform, Autopilot profiles, compliance rings |

> **Entra ID P1 licence is required for dynamic group rules.** If you are assigning a `DUG` or `DDG`, confirm P1 or P2 is available before creating it.

---

## 4. Acronym glossary

| Acronym | Full term | Context |
|---------|-----------|---------|
| `AUG` | Assigned User Group | Group type code |
| `DUG` | Dynamic User Group | Group type code |
| `ADG` | Assigned Device Group | Group type code |
| `DDG` | Dynamic Device Group | Group type code |
| `CA` | Conditional Access | Entra ID policy engine controlling access based on signals |
| `CAP` | Conditional Access Policy | Used as the `Scope` segment in Entra group names for CA policy groups |
| `MFA` | Multi-Factor Authentication | Second factor verification at sign-in |
| `SSPR` | Self-Service Password Reset | User-initiated password reset without helpdesk |
| `WHfB` | Windows Hello for Business | Passwordless authentication using PIN or biometrics on Windows |
| `EAM` | External Authentication Method | Third-party MFA provider integrated with Entra |
| `DFO` | Defender for Office 365 | Anti-phishing, safe links, safe attachments, and threat protection for Exchange Online |
| `PIM` | Privileged Identity Management | Just-in-time activation of privileged Entra roles |
| `GDAP` | Granular Delegated Admin Privileges | Microsoft Partner Center feature that grants partner/MSP technicians scoped, time-bound access to customer tenants via specific Entra roles |
| `NHI` | Non-Human Identity | Any identity that is not a human user — service accounts, managed identities, app registrations, AI agents |
| `SPO` | SharePoint Online | Microsoft SharePoint cloud service |
| `DLP` | Data Loss Prevention | Purview policy that detects and restricts sensitive data movement |
| `IRM` | Insider Risk Management | Purview solution for detecting internal data risk signals |
| `AVD` | Azure Virtual Desktop | Microsoft hosted virtual desktop infrastructure |
| `W365` | Windows 365 | Cloud PC — persistent Windows virtual machine assigned per user |
| `SOC` | Security Operations Centre | Team responsible for monitoring and responding to security threats |

---

## 5. Entra & identity groups

### 5.1 Conditional Access groups

CA groups scope who is included in, excluded from, or subject to specific CA policies. Every CA policy should reference named groups rather than using broad directory assignments.

```
SG-Entra-[TypeCode]-CAP-[Name]
```

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Entra-AUG-CAP-BreakglassAccounts` | AUG | Emergency accounts excluded from all CA policies. One group only — tightly controlled |
| `SG-Entra-AUG-CAP-GlobalExclusions` | AUG | Users permanently excluded from standard CA policies (automation accounts etc.) |
| `SG-Entra-AUG-CAP-GuestExclusions` | AUG | Guests excluded from specific CA policies |
| `SG-Entra-AUG-CAP-ServiceAccounts` | AUG | Service accounts excluded from MFA/device compliance policies |
| `SG-Entra-AUG-CAP-AgentAdmins` | AUG | Admin identities managing Copilot/agent platforms — scoped CA policy |
| `SG-Entra-AUG-CAP-AgentUsers` | AUG | End users accessing AI agent applications |
| `SG-Entra-AUG-CAP-AzureDevOpsUsers` | AUG | DevOps users requiring specific CA policy (PAT, pipeline conditions) |
| `SG-Entra-AUG-CAP-TravelingUsers` | AUG | Users permitted to sign in from locations outside named locations |
| `SG-Entra-AUG-CAP-NamedLocations-TrustedUsers` | AUG | Users allowed to authenticate from specific trusted named locations |
| `SG-Entra-AUG-CAP-TokenProtection-Scoped` | AUG | Users enrolled in CA token binding / token protection policy |
| `SG-Entra-AUG-CAP-PhishingResistantMFA-Required` | AUG | Users required to use phishing-resistant MFA (passkey or WHfB) only |
| `SG-Entra-AUG-CAP-DeviceCompliance-Excluded` | AUG | Short-term exclusion from device compliance CA — requires documented approval |
| `SG-Entra-ADG-CAP-DeviceExclusions` | ADG | Specific devices excluded from device-based CA policies |
| `SG-Entra-ADG-CAP-MobileDeviceExclusions` | ADG | Mobile devices excluded from mobile-specific CA policies |
| `SG-Entra-DUG-CAP-TeamsRoomDevices` | DUG | Teams Room accounts (dynamic) — excluded from user-facing CA |
| `SG-Entra-DUG-License-P1InternalUsers` | DUG | Dynamic — all internal users with Entra P1 licence |
| `SG-Entra-DUG-License-P2InternalUsers` | DUG | Dynamic — all internal users with Entra P2 licence |

### 5.2 Authentication method groups

Groups that scope who can register or use specific authentication methods via the Authentication Methods policy in Entra.

```
SG-Entra-[TypeCode]-MFA-[Method]
SG-Entra-[TypeCode]-SSPR-[Name]
SG-Entra-[TypeCode]-WHfB-[Name]     (see also Intune section)
```

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Entra-AUG-MFA-AuthPasskey` | AUG | Users enabled for passkey (FIDO2) authentication |
| `SG-Entra-AUG-MFA-AuthEAM` | AUG | Users enabled for External Authentication Method (third-party MFA) |
| `SG-Entra-AUG-MFA-AuthSMS` | AUG | Users permitted to use SMS as an MFA method |
| `SG-Entra-AUG-MFA-PasskeyPilotUsers` | AUG | Pilot group for passkey rollout |
| `SG-Entra-AUG-SSPR-EnabledUsers` | AUG | Users enabled for self-service password reset |

### 5.3 Dynamic identity & lifecycle groups

```
SG-Entra-DUG-[Scope]-[Name]
```

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Entra-DUG-Admins-AllAdminUsers` | DUG | Dynamic — all users holding any admin role |
| `SG-Entra-DUG-Lifecycle-DisabledUsers` | DUG | Dynamic — disabled/offboarded user accounts |
| `SG-Entra-DUG-DFO-AllInternalUsers` | DUG | Dynamic — all licensed internal users for Defender for Office 365 policy scope |
| `SG-Entra-DUG-Identity-GuestUsers` | DUG | Dynamic — all B2B guest users |
| `SG-Entra-DUG-License-TeamsRooms` | DUG | Dynamic — Teams Rooms licence assigned accounts |

### 5.4 Identity governance & self-service

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Entra-AUG-Identity-M365GroupCreators` | AUG | Users permitted to create M365 Groups (Teams, SharePoint sites) |
| `SG-Entra-AUG-Identity-RestrictedGuests` | AUG | Guests with restricted permissions profile |
| `SG-Entra-AUG-SelfService-AppUsers` | AUG | Users enabled for self-service application access |
| `SG-Entra-AUG-SelfService-GroupUsers` | AUG | Users enabled for self-service group management |

### 5.5 App-specific access

```
SG-Entra-AUG-App-[AppName]-[Role]
```

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Entra-AUG-App-[AppName]-Users` | AUG | Users assigned access to a specific enterprise application |
| `SG-Entra-AUG-App-[AppName]-Admins` | AUG | Admins/owners of a specific enterprise application |

Replace `[AppName]` with the application's short identifier (e.g. `Salesforce`, `ServiceNow`, `Workday`).

---

### 5.6 Group-based licensing

Group-based licensing groups are **assigned** (`AUG`) groups that have a Microsoft 365 or Entra licence assigned directly to the group in Entra. When a user is added to the group they automatically receive the licence; when they are removed the licence is reclaimed.

This is distinct from the `DUG-License-*` groups in section 5.3, which are **read-only dynamic groups** used to detect users who already hold a licence for policy scoping. Do not confuse the two:

| Group type | Direction | Use |
|---|---|---|
| `SG-Entra-AUG-License-[SKU]` | Assigns licence → user | Group-based licensing — add user to group to license them |
| `SG-Entra-DUG-License-[SKU]InternalUsers` | Detects licensed users | CA/feature scoping — read-only, do not use to assign licences |

> **Entra P1 requirement:** Group-based licensing requires Entra ID P1 on the tenant. If a licence cannot be assigned (e.g. no available seats), the user is flagged with a licensing error in the group's **Licensing** blade — monitor this regularly.

```
SG-Entra-AUG-License-[SKU]
```

| Group name | Purpose |
|---|---|
| `SG-Entra-AUG-License-M365BP` | Assigns Microsoft 365 Business Premium licence to members |
| `SG-Entra-AUG-License-M365E3` | Assigns Microsoft 365 E3 licence to members |
| `SG-Entra-AUG-License-M365E5` | Assigns Microsoft 365 E5 licence to members |
| `SG-Entra-AUG-License-IntuneP1` | Assigns standalone Intune Plan 1 licence to members |
| `SG-Entra-AUG-License-EntraP2` | Assigns standalone Entra ID P2 licence to members |

Create only the groups that correspond to licences active in your tenant. Replace `[SKU]` with the short name of the licence bundle (no spaces, PascalCase).

> **One group per SKU.** Do not assign the same licence product to multiple groups — if a user is in both, Entra will only assign the licence once, but it creates unnecessary confusion in the licensing audit trail.

---

Device groups follow the platform segment pattern. Every platform should have a pilot ring, production ring, and an exclusion group.

```
SG-Intune-[TypeCode]-[Platform]-[Env]-[Name]
```

| Platform code | Description |
|--------------|-------------|
| `WIN` | Windows (Intune managed) |
| `MAC` | macOS (Intune managed) |
| `AVD` | Azure Virtual Desktop host sessions |
| `W365` | Windows 365 Cloud PCs |

### 6.1 Windows

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Intune-ADG-WIN-Pilot-Devices` | ADG | Windows devices in pilot/test ring |
| `SG-Intune-AUG-WIN-Pilot-Users` | AUG | Users in Windows pilot ring |
| `SG-Intune-ADG-WIN-Prod-Devices` | ADG | Windows devices in production ring |
| `SG-Intune-AUG-WIN-Prod-Users` | AUG | Users in Windows production ring |
| `SG-Intune-ADG-WIN-Exclusion-Devices` | ADG | Windows devices excluded from standard policies |
| `SG-Intune-ADG-WIN-Exclusion-USBDevices` | ADG | Devices excluded from USB restriction policy |
| `SG-Intune-AUG-WIN-DeviceAdmins` | AUG | Local device administrators on Windows endpoints |
| `SG-Intune-AUG-WIN-MultiAdminApprovers` | AUG | Approvers for multi-admin approval workflows in Intune |
| `SG-Intune-DDG-WIN-Prod-HotpatchDevices` | DDG | Dynamic — devices eligible for Windows Hotpatch |

### 6.2 Autopilot

```
SG-Intune-DDG-WIN-Autopilot-[Name]
```

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Intune-DDG-WIN-Autopilot-Devices` | DDG | All Autopilot-registered Windows devices (dynamic — Autopilot tag) |
| `SG-Intune-ADG-WIN-Autopilot-Pilot` | ADG | Subset of Autopilot devices in pilot deployment profile |
| `SG-Intune-ADG-WIN-Autopilot-Exclusions` | ADG | Autopilot devices excluded from standard profile assignment |

### 6.3 Windows Hello for Business

```
SG-Intune-[TypeCode]-WIN-WHfB-[Name]
```

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Intune-ADG-WIN-WHfB-PilotDevices` | ADG | Devices in WHfB pilot — provisioning profile targeted here |
| `SG-Intune-ADG-WIN-WHfB-ProdDevices` | ADG | Devices in WHfB production — full rollout |
| `SG-Intune-AUG-WIN-WHfB-ExcludedUsers` | AUG | Users excluded from WHfB enforcement (kiosk accounts etc.) |

### 6.4 macOS

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Intune-ADG-MAC-Pilot-Devices` | ADG | macOS devices in pilot ring |
| `SG-Intune-AUG-MAC-Pilot-Users` | AUG | Users in macOS pilot ring |
| `SG-Intune-ADG-MAC-Prod-Devices` | ADG | macOS devices in production ring |
| `SG-Intune-AUG-MAC-Prod-Users` | AUG | Users in macOS production ring |
| `SG-Intune-ADG-MAC-Exclusion-Devices` | ADG | macOS devices excluded from standard policies |
| `SG-Intune-DDG-MAC-Prod-Devices` | DDG | Dynamic — all macOS devices in Intune |

### 6.5 Azure Virtual Desktop

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Intune-ADG-AVD-Pilot-Devices` | ADG | AVD host VMs in pilot ring |
| `SG-Intune-AUG-AVD-Pilot-Users` | AUG | Users in AVD pilot ring |
| `SG-Intune-ADG-AVD-Prod-Devices` | ADG | AVD host VMs in production ring |
| `SG-Intune-AUG-AVD-Prod-Users` | AUG | Users accessing AVD production environment |
| `SG-Intune-AUG-AVD-Prod-ExternalUsers` | AUG | External/vendor users accessing AVD |
| `SG-Intune-DDG-AVD-Prod-HostDevices` | DDG | Dynamic — all AVD host session devices |
| `SG-Intune-ADG-AVD-Exclusion-Devices` | ADG | AVD devices excluded from standard policies |

### 6.6 Windows 365

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Intune-ADG-W365-Pilot-Devices` | ADG | W365 Cloud PCs in pilot ring |
| `SG-Intune-AUG-W365-Pilot-Users` | AUG | Users in W365 pilot ring |
| `SG-Intune-ADG-W365-Prod-Devices` | ADG | W365 Cloud PCs in production ring |
| `SG-Intune-AUG-W365-Prod-Users` | AUG | Users accessing W365 production Cloud PCs |
| `SG-Intune-DDG-W365-Prod-Devices` | DDG | Dynamic — all W365 Cloud PC devices |
| `SG-Intune-ADG-W365-Exclusion-Devices` | ADG | W365 devices excluded from standard policies |

---

## 7. Data governance — Purview

Purview groups use the `DG-Purview` prefix and scope users into or out of data protection policies.

```
DG-Purview-AUG-[PolicyArea]-[PolicyName]-[Direction]
```

### 7.1 DLP groups

| Group name | Purpose |
|-----------|---------|
| `DG-Purview-AUG-DLP-BrowserProtection-Included` | Users in scope for Endpoint DLP browser upload restriction |
| `DG-Purview-AUG-DLP-BrowserProtection-Excluded` | Users excluded from browser DLP (dev, security tooling) |
| `DG-Purview-AUG-DLP-EmailProtection-Included` | Users in scope for outbound email DLP policy |
| `DG-Purview-AUG-DLP-EmailProtection-Excluded` | Users excluded from email DLP (e.g. helpdesk, automated mailers) |
| `DG-Purview-AUG-DLP-EndpointProtection-Excluded` | Devices/users excluded from endpoint DLP — requires documented justification |

### 7.2 Sensitivity label groups

Sensitivity label policies can be scoped to specific groups so labels are only visible and selectable by relevant users.

| Group name | Purpose |
|-----------|---------|
| `DG-Purview-AUG-Label-Confidential-Users` | Users who can apply the Confidential sensitivity label |
| `DG-Purview-AUG-Label-HighlyConfidential-Users` | Users who can apply the Highly Confidential label |
| `DG-Purview-AUG-Label-Internal-Users` | Users scoped to internal-only label policies |

### 7.3 Insider Risk Management

IRM scoping is critical — exclude legal, HR leadership, and executive roles from standard IRM policies and manage them separately if required.

| Group name | Purpose |
|-----------|---------|
| `DG-Purview-AUG-InsiderRisk-ScopedUsers` | Users actively in scope for IRM policy monitoring |
| `DG-Purview-AUG-InsiderRisk-ExcludedUsers` | Users excluded from IRM (legal, execs, privileged roles) |

### 7.4 Retention & legal hold

| Group name | Purpose |
|-----------|---------|
| `DG-Purview-AUG-Retention-LegalHold` | Users under active legal hold — content preserved regardless of retention policy |

### 7.5 eDiscovery & communications compliance

| Group name | Purpose |
|-----------|---------|
| `DG-Purview-AUG-eDiscovery-Managers` | Users assigned eDiscovery Manager role scope |
| `DG-Purview-AUG-CommunicationsCompliance-Scoped` | Users in scope for communications compliance policy review |

### 7.6 Admin roles

| Group name | Purpose |
|-----------|---------|
| `DG-Purview-AUG-Admin-DataAdmins` | Purview data administrators — policy creation and management |

---

## 8. Data governance — SharePoint Online

SPO groups follow the Owners / Members / Visitors role model. Every SharePoint site should have all three groups.

```
DG-SPO-[Dept]-[Project]-[Role]
```

| Role | SharePoint permission level | Who belongs here |
|------|---------------------------|-----------------|
| `Owners` | Full control | Site owners, IT admins responsible for the site |
| `Members` | Edit | Active contributors — can add and edit content |
| `Visitors` | Read | Stakeholders who need read access only |

### Example — Finance department

| Group name | Role |
|-----------|------|
| `DG-SPO-Finance-BudgetPlanning-Owners` | Owners |
| `DG-SPO-Finance-BudgetPlanning-Members` | Members |
| `DG-SPO-Finance-BudgetPlanning-Visitors` | Visitors |
| `DG-SPO-Finance-AuditReporting-Owners` | Owners |
| `DG-SPO-Finance-AuditReporting-Members` | Members |
| `DG-SPO-Finance-AuditReporting-Visitors` | Visitors |
| `DG-SPO-Finance-Procurement-Owners` | Owners |
| `DG-SPO-Finance-Procurement-Members` | Members |
| `DG-SPO-Finance-Procurement-Visitors` | Visitors |

### Example — HR department

| Group name | Role |
|-----------|------|
| `DG-SPO-HR-Onboarding-Owners` | Owners |
| `DG-SPO-HR-Onboarding-Members` | Members |
| `DG-SPO-HR-Onboarding-Visitors` | Visitors |
| `DG-SPO-HR-PoliciesHandbook-Owners` | Owners |
| `DG-SPO-HR-PoliciesHandbook-Members` | Members |
| `DG-SPO-HR-PoliciesHandbook-Visitors` | Visitors |
| `DG-SPO-HR-RecruitmentPipeline-Owners` | Owners |
| `DG-SPO-HR-RecruitmentPipeline-Members` | Members |

> **Note:** HR Recruitment does not have a Visitors group — restrict read access to members only given the sensitivity of hiring data.

### Example — Sales department

| Group name | Role |
|-----------|------|
| `DG-SPO-Sales-AccountPlanning-Owners` | Owners |
| `DG-SPO-Sales-AccountPlanning-Members` | Members |
| `DG-SPO-Sales-AccountPlanning-Visitors` | Visitors |
| `DG-SPO-Sales-Proposals-Owners` | Owners |
| `DG-SPO-Sales-Proposals-Members` | Members |
| `DG-SPO-Sales-Proposals-Visitors` | Visitors |
| `DG-SPO-Sales-CompetitiveIntel-Owners` | Owners |
| `DG-SPO-Sales-CompetitiveIntel-Members` | Members |
| `DG-SPO-Sales-CompetitiveIntel-Visitors` | Visitors |

---

## 9. AI, agents & non-human identities

### What is a Non-Human Identity (NHI)?

A **Non-Human Identity (NHI)** is any Entra ID identity that is not a human user. NHIs include:

- **Service accounts** — traditional accounts used by applications or scheduled tasks to authenticate
- **Managed identities** — Azure-native identities assigned to resources (VMs, App Services, Logic Apps) — no credentials to manage
- **App registrations / service principals** — identities representing applications in Entra ID
- **Workload identities** — federated identities for external workloads (GitHub Actions, Kubernetes pods)
- **AI agents** — autonomous software agents (Copilot Studio, AI Foundry, third-party LLM agents) that authenticate to M365 services and APIs

NHIs require their own group structure because they need to be:

1. Excluded from user-facing CA policies (device compliance, MFA prompts)
2. Enrolled in their own CA policies (IP restrictions, workload identity CA)
3. Tracked for lifecycle management (rotation, decommission)
4. Separated by risk level (agent-to-human vs agent-to-agent flows)

### 9.1 Group structure

```
SG-NHI-AUG-[IdentityType]-[Platform/Scope]-[Env]
```

| Identity type code | Description |
|-------------------|-------------|
| `ServiceAccounts` | Traditional service/automation accounts |
| `ManagedIdentities` | Azure managed identities |
| `WorkloadIdentities` | Federated/workload identities |
| `Agents` | AI agents and autonomous digital workers |

### 9.2 Service accounts

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-NHI-AUG-ServiceAccounts-All` | AUG | All service accounts — primary CA exclusion group |
| `SG-NHI-AUG-ServiceAccounts-Privileged` | AUG | Service accounts with elevated permissions — separate monitoring |
| `SG-NHI-AUG-ServiceAccounts-LegacyAuth` | AUG | Service accounts still using basic/legacy authentication — remediation target |

### 9.3 Managed & workload identities

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-NHI-AUG-ManagedIdentities-All` | AUG | All Azure managed identities requiring policy scoping |
| `SG-NHI-AUG-WorkloadIdentities-All` | AUG | Federated workload identities (GitHub, Kubernetes etc.) |
| `SG-NHI-AUG-WorkloadIdentities-CIpipelines` | AUG | CI/CD pipeline identities — DevOps, GitHub Actions |

### 9.4 AI agents

AI agents in Entra (via Entra Agent ID) are registered as application principals. They should be grouped by platform and deployment environment so CA and governance policies can be targeted precisely.

```
SG-NHI-AUG-Agents-[Platform]-[Env]
```

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-NHI-AUG-Agents-CopilotStudio-Pilot` | AUG | Copilot Studio agents in pilot / testing |
| `SG-NHI-AUG-Agents-CopilotStudio-Prod` | AUG | Copilot Studio agents in production |
| `SG-NHI-AUG-Agents-AIFoundry-Pilot` | AUG | Azure AI Foundry agents in pilot |
| `SG-NHI-AUG-Agents-AIFoundry-Prod` | AUG | Azure AI Foundry agents in production |
| `SG-NHI-AUG-Agents-ThirdParty-Prod` | AUG | Third-party AI agents approved for production |
| `SG-NHI-AUG-Agents-CAPolicyExclusion` | AUG | Agents excluded from user-facing CA policies — enrol in workload identity CA instead |
| `SG-NHI-AUG-Agents-HighPrivilege` | AUG | Agents with Graph API permissions or admin-level delegated access — highest scrutiny |

> **Licensing note:** Workload Identity CA policies require the **Workload Identities Premium** add-on licence in addition to Entra P1/P2.

---

## 10. Security & admin role groups

### 10.1 Admin role groups

These groups scope Entra role assignments. Every privileged role should be backed by a group, not direct user assignment, to enable PIM and auditing.

```
SG-Admin-AUG-[RoleName]
```

| Group name | Type | Entra role mapped |
|-----------|------|------------------|
| `SG-Admin-AUG-GlobalAdmins` | AUG | Global Administrator — maximum privilege, tightly controlled |
| `SG-Admin-AUG-SecurityAdmins` | AUG | Security Administrator |
| `SG-Admin-AUG-ComplianceAdmins` | AUG | Compliance Administrator |
| `SG-Admin-AUG-HelpdeskAdmins` | AUG | Helpdesk Administrator |
| `SG-Admin-AUG-IntuneAdmins` | AUG | Intune Administrator |
| `SG-Admin-AUG-UserAdmins` | AUG | User Administrator |
| `SG-Admin-AUG-PIMEligible-PrivilegedRoles` | AUG | Users eligible to activate privileged roles via PIM |

> **Best practice:** Assign all privileged roles as **eligible** in PIM rather than **active**. Members of `SG-Admin-AUG-GlobalAdmins` should not have standing Global Admin access — they should activate via PIM with justification and approval.

### 10.2 Security operations (Defender)

```
SG-Security-AUG-[Product]-[Role]
```

| Group name | Type | Purpose |
|-----------|------|---------|
| `SG-Security-AUG-DefenderXDR-Admins` | AUG | Defender XDR portal administrators — full configuration access |
| `SG-Security-AUG-DefenderXDR-Analysts` | AUG | SOC analysts — investigate and respond, no configuration |
| `SG-Security-AUG-DefenderVuln-RemediationOwners` | AUG | Asset owners responsible for Defender Vulnerability Management remediation |
| `SG-Security-AUG-AttackSimulation-TargetUsers` | AUG | Users included in Attack Simulation Training phishing campaigns |
| `SG-Security-AUG-AttackSimulation-Excluded` | AUG | Users excluded from simulations — executives, legal, comms teams |

---

## 11. Naming rules & constraints

| Rule | Detail |
|------|--------|
| **Hyphens only** | No spaces, underscores, dots, or slashes |
| **PascalCase per segment** | `BudgetPlanning` not `budgetplanning` or `Budget_Planning` |
| **No emojis** | Emojis in group names break Graph API queries, CSV exports, and some admin portals |
| **No special characters** | Avoid `&` `(` `)` `/` `\` `'` `"` `@` |
| **Max ~70 characters** | Entra supports up to 256 but long names reduce readability in portals and scripts |
| **One breakglass group** | `SG-Entra-AUG-CA-BreakglassAccounts` — do not duplicate |
| **No duplicate scopes** | Each group should have one clear owner pillar — do not replicate the same group across pillars |
| **Env segment is optional** | Only include `Pilot`/`Prod` when the group targets a specific deployment ring |
| **Dynamic groups need P1** | Always confirm Entra P1 or P2 licence is available before creating DUG or DDG |
| **NHI groups get dedicated CA** | Never include NHI accounts in user CA groups — create separate workload identity policies |

---

## 12. Dynamic membership rules reference

This section is the single source of truth for all dynamic group membership rules (`DUG` and `DDG`) used in this tenant. Update this section whenever a rule is modified in the Entra portal.

> **How to review a rule in the portal:**  
> Entra admin centre → Groups → [Group name] → Membership rules → View rule  
> Copy the rule text back here after any change and update the *Last reviewed* date.

---

### 12.1 How to read the rule syntax

Entra dynamic membership rules use a simple property-operator-value pattern:

```
(user.propertyName -operator "value") -and/or (user.propertyName -operator "value")
```

| Operator | Meaning |
|----------|---------|
| `-eq` | Equals |
| `-ne` | Not equals |
| `-startsWith` | String starts with value |
| `-contains` | String contains value |
| `-match` | Regex match |
| `-any` | At least one item in a collection satisfies the condition |
| `-all` | All items in a collection satisfy the condition |
| `-in` | Value exists in a list |

**User properties** use the `user.` prefix. **Device properties** use the `device.` prefix.  
Rules for user groups and device groups cannot be mixed in a single group.

---

### 12.2 Service plan GUIDs

Dynamic licence rules use Entra service plan GUIDs rather than product names. GUIDs are stable across licence bundle changes (e.g. the P1 GUID is the same whether it comes from M365 E3, M365 Business Premium, or a standalone AAD P1 licence).

| Service plan | GUID | Included in |
|---|---|---|
| Entra ID P1 (`AAD_PREMIUM`) | `41781fb2-bc02-4b7c-bd55-b576c07bb09f` | M365 E3, M365 BP, EMS E3, standalone P1 |
| Entra ID P2 (`AAD_PREMIUM_P2`) | `eec0eb4f-6444-4f95-aba0-50c24d67f998` | M365 E5, EMS E5, standalone P2 |
| Microsoft Teams Rooms Pro (`TEAMS_ROOMS_PRO`) | `8081ca9c-188c-4b49-a8e5-c23b5e9463a8` | Teams Rooms Pro standalone |
| Microsoft Teams Rooms Basic (`TEAMS_ROOMS_BASIC`) | `ec17f317-f4bc-451e-b2da-0167e5c260f9` | Teams Rooms Basic standalone |
| Microsoft Teams Rooms Standard — legacy (`MEETING_ROOM`) | `92c6b761-01de-457a-9dd9-793a975238f7` | Legacy Teams Rooms Standard SKU |
| Exchange Online Plan 1 | `9aaf7827-d63c-4b61-89c3-182f06f82e5c` | M365 BP, M365 E3 |
| Exchange Online Plan 2 | `efb87545-963c-4e0d-99df-69c6916d9eb0` | M365 E5 |
| Microsoft Intune | `c1ec4a95-1f05-45b3-a911-aa3fa01094f5` | M365 E3/E5, M365 BP, standalone Intune |
| Defender for Endpoint P2 | `e430a580-3d73-4f81-9b19-8d5f30dba2e9` | M365 E5, Defender for Business |
| Workload Identities Premium | `98961bca-8548-4e59-b7c2-0f3d059a76fa` | Standalone add-on |

> **Finding a GUID:** Run `Get-MgSubscribedSku | Select SkuPartNumber, ServicePlans | ConvertTo-Json -Depth 3` in PowerShell to list all service plans and GUIDs active in your tenant.

---

### 12.3 Device property reference

Used in `DDG` (Dynamic Device Group) rules.

| Property | Values / notes |
|---|---|
| `device.deviceOSType` | `"Windows"` · `"MacMDM"` · `"iPhone"` (iOS + iPadOS) · `"AndroidForWork"` · `"Linux"` |
| `device.operatingSystemSKU` | `"ServerRdsh"` (AVD multi-session) · `"Enterprise"` (Win 10/11 Ent) · `"Professional"` (Win 10/11 Pro) · `"ServerStandard"` · `"ServerDatacenter"` |
| `device.deviceOwnership` | `"Company"` (corporate-enrolled) · `"Personal"` (BYOD) · `"Unknown"` |
| `device.managementType` | `"MDM"` (Intune-managed) · `"EAS"` (Exchange ActiveSync only) · `""` (not managed) |
| `device.enrollmentType` | `"AzureMDM"` (cloud-only Intune) · `"Hybrid"` (hybrid Entra join) |
| `device.model` | Free text — device model name as reported by the device |
| `device.manufacturer` | Free text — manufacturer name (e.g. `"Microsoft"`, `"Apple"`, `"Dell"`) |
| `device.displayName` | Device display name in Entra |
| `device.extensionAttribute1–15` | Custom attributes — set via Graph API or during provisioning |
| `device.devicePhysicalIds` | Collection — used for Autopilot tags (`[ZTDId]`, `[OrderId]:value`) |
| `device.isCompliant` | `true` · `false` — Intune compliance state |
| `device.accountEnabled` | `true` · `false` — whether the device object is enabled in Entra |
| `device.deviceCategory` | Custom category set in Intune — e.g. `"Corporate"`, `"Kiosk"` |

---

### 12.4 User property reference

Used in `DUG` (Dynamic User Group) rules.

| Property | Values / notes |
|---|---|
| `user.userType` | `"Member"` (internal) · `"Guest"` (B2B guest) |
| `user.accountEnabled` | `true` · `false` |
| `user.userPrincipalName` | Full UPN — supports `-startsWith`, `-contains`, `-match` |
| `user.mail` | Primary email address |
| `user.department` | Department attribute from HR/Entra |
| `user.jobTitle` | Job title — avoid for role-based rules; use extensionAttribute instead |
| `user.companyName` | Company name — useful in multi-entity tenants |
| `user.country` | ISO country code (e.g. `"GB"`, `"US"`) |
| `user.usageLocation` | Two-letter usage location required for licence assignment |
| `user.assignedPlans` | Collection of assigned service plans — use with `-any` and plan GUID |
| `user.proxyAddresses` | SMTP proxy addresses collection |
| `user.extensionAttribute1–15` | Custom attributes — populated via HR sync, on-prem AD, or Graph API |
| `user.onPremisesSyncEnabled` | `true` (synced from on-prem AD) · `null` (cloud-only) |
| `user.createdDateTime` | ISO timestamp — can be used for new-hire targeting |

---

### 12.5 Entra identity dynamic rules

| Group | Type | Current rule | Last reviewed |
|---|---|---|---|
| `SG-Entra-DUG-CAP-TeamsRoomDevices` | DUG | `((user.assignedPlans -any (assignedPlan.servicePlanId -eq "8081ca9c-188c-4b49-a8e5-c23b5e9463a8" -and assignedPlan.capabilityStatus -eq "Enabled")) -or (user.assignedPlans -any (assignedPlan.servicePlanId -eq "ec17f317-f4bc-451e-b2da-0167e5c260f9" -and assignedPlan.capabilityStatus -eq "Enabled")) -or (user.assignedPlans -any (assignedPlan.servicePlanId -eq "92c6b761-01de-457a-9dd9-793a975238f7" -and assignedPlan.capabilityStatus -eq "Enabled")))` | 2026-06-27 |
| `SG-Entra-DUG-License-P1InternalUsers` | DUG | `(user.assignedPlans -any (assignedPlan.servicePlanId -eq "41781fb2-bc02-4b7c-bd55-b576c07bb09f" -and assignedPlan.capabilityStatus -eq "Enabled")) -and (user.userType -eq "Member")` | 2026-06-27 |
| `SG-Entra-DUG-License-P2InternalUsers` | DUG | `(user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" -and assignedPlan.capabilityStatus -eq "Enabled")) -and (user.userType -eq "Member")` | 2026-06-27 |
| `SG-Entra-DUG-License-TeamsRooms` | DUG | `((user.assignedPlans -any (assignedPlan.servicePlanId -eq "8081ca9c-188c-4b49-a8e5-c23b5e9463a8" -and assignedPlan.capabilityStatus -eq "Enabled")) -or (user.assignedPlans -any (assignedPlan.servicePlanId -eq "ec17f317-f4bc-451e-b2da-0167e5c260f9" -and assignedPlan.capabilityStatus -eq "Enabled")) -or (user.assignedPlans -any (assignedPlan.servicePlanId -eq "92c6b761-01de-457a-9dd9-793a975238f7" -and assignedPlan.capabilityStatus -eq "Enabled")))` | 2026-06-27 |
| `SG-Entra-DUG-Admins-AllAdminUsers` | DUG | `(user.userPrincipalName -startsWith "adm-")` | 2026-06-27 |
| `SG-Entra-DUG-Lifecycle-DisabledUsers` | DUG | `(user.accountEnabled -eq false)` | 2026-06-27 |
| `SG-Entra-DUG-DFO-AllInternalUsers` | DUG | `(user.userType -eq "Member") -and (user.accountEnabled -eq true)` | 2026-06-27 |
| `SG-Entra-DUG-Identity-GuestUsers` | DUG | `(user.userType -eq "Guest")` | 2026-06-27 |

> **Note — `SG-Entra-DUG-Admins-AllAdminUsers`:** Rule uses UPN prefix `adm-`. Update this to match your admin account naming convention, or replace with an extensionAttribute rule if admin accounts are tagged at provisioning.

---

### 12.6 Intune device dynamic rules

#### Windows

| Group | Type | Current rule | Last reviewed |
|---|---|---|---|
| `SG-Intune-DDG-WIN-Prod-AllDevices` | DDG | `(device.deviceOSType -eq "Windows") -and (device.managementType -eq "MDM")` | 2026-06-27 |
| `SG-Intune-DDG-WIN-Prod-HotpatchDevices` | DDG | `(device.deviceOSType -eq "Windows") -and (device.managementType -eq "MDM")` | 2026-06-27 |
| `SG-Intune-DDG-WIN-CorporateOwned` | DDG | `(device.deviceOSType -eq "Windows") -and (device.deviceOwnership -eq "Company") -and (device.managementType -eq "MDM")` | 2026-06-27 |

#### Autopilot

| Group | Type | Current rule | Notes | Last reviewed |
|---|---|---|---|---|
| `SG-Intune-DDG-WIN-Autopilot-AllDevices` | DDG | `(device.devicePhysicalIds -any _ -contains "[ZTDId]")` | Standard Autopilot rule — do not modify | 2026-06-27 |
| `SG-Intune-DDG-WIN-Autopilot-GroupTag` | DDG | `(device.devicePhysicalIds -any _ -eq "[OrderId]:YOUR_GROUP_TAG")` | ⚠️ Replace `YOUR_GROUP_TAG` before deploying | 2026-06-27 |

#### macOS

| Group | Type | Current rule | Last reviewed |
|---|---|---|---|
| `SG-Intune-DDG-MAC-AllDevices` | DDG | `(device.deviceOSType -eq "MacMDM") -and (device.managementType -eq "MDM")` | 2026-06-27 |
| `SG-Intune-DDG-MAC-CorporateOwned` | DDG | `(device.deviceOSType -eq "MacMDM") -and (device.deviceOwnership -eq "Company") -and (device.managementType -eq "MDM")` | 2026-06-27 |

#### Azure Virtual Desktop

| Group | Type | Current rule | Notes | Last reviewed |
|---|---|---|---|---|
| `SG-Intune-DDG-AVD-AllHostDevices` | DDG | `(device.deviceOSType -eq "Windows") -and (device.managementType -eq "MDM") -and (device.extensionAttribute2 -eq "AVD")` | Dynamic group rule uses extensionAttribute. For Intune policy assignments, use the device filter `(device.operatingSystemSKU -eq "ServerRdsh")` instead — see section 12.7. | 2026-06-27 |

#### Windows 365

| Group | Type | Current rule | Last reviewed |
|---|---|---|---|
| `SG-Intune-DDG-W365-AllCloudPCs` | DDG | `(device.model -startsWith "Cloud PC") -and (device.managementType -eq "MDM")` | 2026-06-27 |
| `SG-Intune-DDG-W365-FrontlineDevices` | DDG | `(device.model -startsWith "Cloud PC Frontline") -and (device.managementType -eq "MDM")` | 2026-06-27 |

---

### 12.7 Intune device filter expressions

Device filters are applied at **policy assignment time** in Intune rather than as group membership rules. They are evaluated against real-time device properties and do not require Entra P1. Use filters to further narrow the scope of a policy beyond what a group targets.

> Navigate to: Intune admin centre → Devices → Filters → Create filter

#### Common filter expressions

**Windows 11 only (for Hotpatch targeting)**
```
(device.operatingSystem -eq "Windows") and (device.osVersion -startsWith "10.0.22")
```

**Windows 10 only**
```
(device.operatingSystem -eq "Windows") and (device.osVersion -startsWith "10.0.19")
```

**Corporate-owned devices only**
```
(device.deviceOwnership -eq "Company")
```

**Personal / BYOD devices only**
```
(device.deviceOwnership -eq "Personal")
```

**macOS 14 Sonoma and above**
```
(device.operatingSystem -eq "macOS") and (device.osVersion -startsWith "14.")
```

**macOS corporate-owned only**
```
(device.operatingSystem -eq "macOS") and (device.deviceOwnership -eq "Company")
```

**Windows 365 Cloud PCs only**
```
(device.model -startsWith "Cloud PC")
```

**AVD session hosts — OS SKU filter (recommended, most precise)**
```
(device.operatingSystemSKU -eq "ServerRdsh")
```
> `ServerRdsh` is the Windows 10/11 Enterprise multi-session OS SKU used exclusively by AVD session hosts. This is the correct and definitive Intune device filter for AVD — it matches only multi-session hosts and nothing else. No provisioning steps, model strings, or extensionAttributes required.

**AVD session hosts — corporate-owned multi-session only**
```
(device.operatingSystemSKU -eq "ServerRdsh") and (device.deviceOwnership -eq "Company")
```
> Adds an ownership check on top of the OS SKU filter. Useful if you want to explicitly exclude any personal-enrolled multi-session devices from policy scope.

**AVD session hosts — production ring (combine with group)**
```
(device.operatingSystemSKU -eq "ServerRdsh") and (device.enrollmentProfileName -startsWith "AVD-Prod")
```
> Combine the OS SKU filter with an enrollment profile name prefix to differentiate pilot from production session hosts at policy assignment time without needing separate groups.

**Specific manufacturer (e.g. Surface devices)**
```
(device.manufacturer -eq "Microsoft") and (device.operatingSystem -eq "Windows")
```

**Compliant devices only**
```
(device.isCompliant -eq "True")
```

**Non-compliant devices (for targeted remediation policy)**
```
(device.isCompliant -eq "False") and (device.deviceOwnership -eq "Company")
```

---

### 12.8 Review cadence

| Trigger | Action |
|---|---|
| **Quarterly** | Review all dynamic group membership counts in Entra — flag unexpected spikes or drops |
| **Licence change** | Verify service plan GUIDs in section 12.2 still match current SKUs after any licence tier change |
| **New platform rollout** | Add new DDG group and rule to section 12.6 before deploying |
| **Admin naming convention change** | Update `SG-Entra-DUG-Admins-AllAdminUsers` rule in section 12.5 |
| **Autopilot group tag added** | Clone and update `SG-Intune-DDG-WIN-Autopilot-GroupTag` rule with new tag value |
| **OS major version release** | Review Hotpatch and version-specific filter expressions in section 12.7 |
| **Rule modified in portal** | Copy updated rule text back to the relevant table in this document and update Last reviewed date |

---

## 13. GDAP groups — partner access

GDAP (Granular Delegated Admin Privileges) groups grant partner/MSP technicians scoped, time-bound access to a customer tenant via specific Entra roles. Each security group maps to exactly one Entra role. When a GDAP relationship is established in Partner Center, the group is assigned the role in the customer tenant and partner technicians are added to the group in the **partner's own tenant** — not in the customer tenant.

GDAP groups follow the standard `SG-Admin-AUG-` pattern with `GDAP` as the scope segment:

```
SG-Admin-AUG-GDAP-[RoleName]
```

> **Naming note:** `GDAP` is the scope segment that identifies this group as a partner delegated access group. The role name is written in PascalCase with no hyphens within the name segment. This keeps GDAP groups consistent with all other `SG-Admin-AUG-*` role groups in the tenant.

> **Role-assignable requirement:** All GDAP groups **must** be created with `IsAssignableToRole = true`. This is set at creation time and cannot be changed afterwards. Role-assignable groups require **Entra ID P2** and count against the tenant limit of 500 role-assignable groups.

> **Security note:** Partner technicians never have standing access. Access is scoped to the roles listed below and is activated only for the duration of an active GDAP relationship. Audit all active GDAP relationships quarterly in Partner Center and review the assigned roles against the principle of least privilege.

---

### 13.1 GDAP security groups

| Group name | Entra role assigned | Privilege | Notes |
|---|---|---|---|
| `SG-Admin-AUG-GDAP-ApplicationAdministrator` | Application Administrator | 🔴 High | Full control over app registrations and enterprise applications — broad credential and permission scope |
| `SG-Admin-AUG-GDAP-DirectoryWriters` | Directory Writers | 🟡 Medium | Can write to most directory objects; does not grant role assignment but can modify group and user attributes |
| `SG-Admin-AUG-GDAP-ExchangeAdministrator` | Exchange Administrator | 🟡 Medium | Full control of Exchange Online mailboxes, connectors, and transport rules |
| `SG-Admin-AUG-GDAP-GroupsAdministrator` | Groups Administrator | 🟢 Low | Can create and manage all types of groups; no access to group content or mailboxes |
| `SG-Admin-AUG-GDAP-HelpdeskAdministrator` | Helpdesk Administrator | 🟢 Low | Reset passwords and manage service requests for non-admin users only |
| `SG-Admin-AUG-GDAP-IntuneAdministrator` | Intune Administrator | 🟡 Medium | Full control of Intune — device configuration, compliance policies, app deployment |
| `SG-Admin-AUG-GDAP-PrivilegedRoleAdministrator` | Privileged Role Administrator | 🚨 Critical | Can assign any Entra role including Global Administrator — treat as equivalent to Global Admin; restrict to named individuals only |
| `SG-Admin-AUG-GDAP-SecurityAdministrator` | Security Administrator | 🔴 High | Full read/write access across Defender, Sentinel, Purview, and identity protection |
| `SG-Admin-AUG-GDAP-SharePointAdministrator` | SharePoint Administrator | 🟡 Medium | Full control of SharePoint Online sites, settings, and OneDrive for Business |
| `SG-Admin-AUG-GDAP-TeamsAdministrator` | Teams Administrator | 🟡 Medium | Full control of Teams policies, settings, and meeting configuration |
| `SG-Admin-AUG-GDAP-UserAdministrator` | User Administrator | 🟡 Medium | Create and manage users and groups; reset passwords for non-admin users; manage licences |

---

### 13.2 Privilege level reference

| Level | Indicator | Meaning |
|---|---|---|
| Critical | 🚨 | Role can assign other privileged roles — equivalent to Global Admin in practice. Maximum scrutiny, named approval required |
| High | 🔴 | Broad data or credential access. Limit membership; review quarterly |
| Medium | 🟡 | Significant service control. Assign only to technicians with active responsibility for that workload |
| Low | 🟢 | Limited blast radius. Appropriate for general helpdesk or junior technicians |

---

### 13.3 Governance requirements

| Requirement | Detail |
|---|---|
| **One group per role** | Never assign multiple roles to a single GDAP group — one group, one role, one audit trail |
| **No standing membership** | Partner technicians must be added to GDAP groups only for the duration of an active engagement; remove promptly when the engagement ends |
| **Privileged-Role-Administrator** | Membership must be individually approved and documented — treat as Critical at all times |
| **Quarterly review** | Audit active GDAP relationships and group membership in Partner Center each quarter |
| **CA policy** | GDAP partner sign-ins traverse Entra CA in the customer tenant — confirm CA policies do not inadvertently block partner access (use a named location or dedicated exclusion group if required) |
| **Audit logging** | Partner actions under GDAP are recorded in the customer tenant's Entra audit log — confirm Purview or Sentinel is ingesting these logs |

---

*Last updated: 2026-06-27*
