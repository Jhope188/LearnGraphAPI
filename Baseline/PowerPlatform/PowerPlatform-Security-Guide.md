# Power Platform Security Hardening Guide

> **Scope:** Power Apps · Power Automate · Power Pages · Copilot Studio · Dataverse  
> **Frameworks:** Microsoft Well-Architected Framework (Security), Microsoft Zero Trust, CIS Microsoft Dynamics 365 Power Platform Benchmark, Microsoft Cloud Security Benchmark (MCSB)  
> **Admin Portal:** [Power Platform Admin Center](https://admin.powerplatform.microsoft.com)  
> **Last Reviewed:** May 2026  
> **Updated:** Added Security Hub — Copilot Settings, Advanced Connector Policies, and Compliance/Auditing configurations (from portal review May 2026)

---

## ⚠️ Important Notes Before You Begin

- **No CIS M365 Foundations benchmark coverage for Power Platform** — the CIS M365 Foundations v7.0.0 benchmark (May 2026) does not cover Power Platform controls. Power Platform has its own separate CIS benchmark: **CIS Microsoft Dynamics 365 Power Platform Benchmark** (available via CIS SecureSuite).
- **Licensing matters** — many security controls (Managed Environments, IP firewall, Conditional Access per-app, Customer Lockbox, VNet) require **Power Apps Premium / Power Automate Premium** or **Dynamics 365** licensing. Free/M365-included entitlements do not unlock Managed Environments.
- **Default environment cannot be deleted** — it can only be restricted. Every licensed user has access. Treat it as a hostile shared space until hardened.
- **DLP ≠ Purview DLP** — Power Platform DLP (connector policies) is completely separate from Microsoft Purview DLP. Both are needed.

---

## Table of Contents

1. [Prerequisites & Roles](#1-prerequisites--roles)
2. [Step 1 — Restrict Environment Creation](#2-step-1--restrict-environment-creation)
3. [Step 2 — Harden the Default Environment](#3-step-2--harden-the-default-environment)
4. [Step 3 — Enable Managed Environments](#4-step-3--enable-managed-environments)
5. [Step 4 — Implement Tenant-Level DLP Policies](#5-step-4--implement-tenant-level-dlp-policies)
6. [Step 5 — Configure Tenant Isolation (Cross-Tenant)](#6-step-5--configure-tenant-isolation-cross-tenant)
7. [Step 6 — Apply Conditional Access to Power Platform](#7-step-6--apply-conditional-access-to-power-platform)
8. [Step 7 — Enable IP Firewall for Dataverse Environments](#8-step-7--enable-ip-firewall-for-dataverse-environments)
9. [Step 8 — Configure Environment Security Groups & RBAC](#9-step-8--configure-environment-security-groups--rbac)
10. [Step 9 — Configure Dataverse Auditing](#10-step-9--configure-dataverse-auditing)
11. [Step 10 — Enable Microsoft Sentinel Integration](#11-step-10--enable-microsoft-sentinel-integration)
12. [Step 11 — Copilot Studio (Agent) Security](#12-step-11--copilot-studio-agent-security)
13. [Step 12 — Purview Integration & Sensitivity Labels](#13-step-12--purview-integration--sensitivity-labels)
14. [Step 13 — Center of Excellence (CoE) Starter Kit](#14-step-13--center-of-excellence-coe-starter-kit)
15. [Step 14 — Secure the Power Platform Admin Role](#15-step-14--secure-the-power-platform-admin-role)
16. [Step 15 — Copilot & AI Governance Settings (Security Hub)](#16-step-15--copilot--ai-governance-settings-security-hub)
17. [Step 16 — Advanced Connector Policies (Security Hub)](#17-step-16--advanced-connector-policies-security-hub)
18. [Step 17 — Compliance & Auditing (Security Hub)](#18-step-17--compliance--auditing-security-hub)
19. [Ongoing Governance Checklist](#19-ongoing-governance-checklist)
20. [Licensing Reference](#20-licensing-reference)
21. [Reference Links](#21-reference-links)

---

## 1. Prerequisites & Roles

### Required Admin Roles

| Task | Minimum Role Required |
|---|---|
| Tenant-level DLP policies | Power Platform Administrator or Global Admin |
| Enable Managed Environments | Power Platform Administrator or Global Admin |
| Environment-level settings | Environment Admin |
| Conditional Access policies | Conditional Access Administrator |
| Purview sensitivity labels | Compliance Administrator |
| Sentinel integration | Security Administrator + Log Analytics Contributor |

### Pre-Hardening Inventory

Before changing any settings, run a discovery pass:

```powershell
# Install required modules
Install-Module -Name Microsoft.PowerApps.Administration.PowerShell -Force
Install-Module -Name Microsoft.PowerApps.PowerShell -AllowClobber -Force

# Authenticate
Add-PowerAppsAccount

# List all environments in your tenant
Get-AdminPowerAppEnvironment | Select-Object DisplayName, EnvironmentType, IsDefault, CreatedTime | Format-Table

# List all existing DLP policies
Get-AdminDlpPolicy | Select-Object DisplayName, EnvironmentFilter, CreatedTime | Format-Table

# List all tenant-level DLP policies
Get-AdminDlpPolicy | Where-Object { $_.EnvironmentFilter -eq "AllEnvironments" }

# Check current tenant isolation policy
Get-PowerAppTenantIsolationPolicy
```

**Document your current state before making changes.** Existing flows and apps may break if DLP changes are deployed without impact assessment.

---

## 2. Step 1 — Restrict Environment Creation

**Why:** By default, any user with a Power Apps or Power Automate license can create production and sandbox environments. This leads to environment sprawl, ungoverned data, and untracked apps.

**Recommendation:** Restrict environment creation to admins only. Direct makers to personal developer environments via environment routing instead.

### Portal Steps

1. Go to **Power Platform Admin Center** → **Settings** (left nav)
2. Under **Tenant settings**, find **Environment creation**
3. Set **Who can create trial environments** → `Only specific admins`
4. Set **Who can create production and sandbox environments** → `Only specific admins`
5. Select **Save**

### PowerShell

```powershell
# Restrict environment creation to admins only
$requestBody = @{
    disableEnvironmentCreationByNonAdminUsers = $true
}
Set-TenantSettings -RequestBody $requestBody
```

### Enable Environment Routing (Managed Environments prerequisite)

When environment routing is enabled, makers visiting make.powerapps.com are redirected to a personal developer environment instead of the default environment.

1. Go to **Settings** → **Tenant settings** → **Environment routing (preview)**
2. Enable **Route makers to their own personal developer environments**
3. Save

> **Note:** Environment routing requires the default environment to be a **Managed Environment**. See Step 3.

---

## 3. Step 2 — Harden the Default Environment

The default environment is the highest-risk environment in any tenant — all licensed users are members, it cannot be deleted, and it often contains years of ungoverned apps and flows.

### 2a. Rename the Default Environment

Makes the restricted intent clear to users.

1. **Power Platform Admin Center** → **Environments** → select the Default environment
2. Select **Edit** → rename to something descriptive, e.g., `Personal Productivity (Restricted)`
3. Save

### 2b. Disable "Share with Everyone"

Prevents makers from sharing apps to the entire organization.

```powershell
# Disable ability to share canvas apps with Everyone
Set-TenantSettings -RequestBody @{ disableShareWithEveryone = $true }
```

Or in the portal: **Settings** → **Tenant settings** → **Share with Everyone** → **Off**

### 2c. Limit Sharing in Default Environment

Even with "Share with Everyone" disabled, makers can share broadly. Set explicit sharing limits:

1. Enable Managed Environments on the default environment (Step 3 below)
2. Under the environment's **Managed Environments** settings → **Sharing limits**
3. Set **Exclude sharing with security groups** = **On**
4. Set maximum share count (e.g., 20 users for the default environment)

### 2d. Secure Integration with Exchange

Prevents Power Platform from sending email on behalf of users without restriction.

1. **Settings** → **Tenant settings** → **Power Automate** section
2. Review and restrict server-side sync / email sending configurations per your Exchange governance policy

### 2e. Apply a Restrictive DLP Policy to the Default Environment

See Step 4 for full DLP configuration. For the default environment specifically:

- Move all **blockable** connectors to **Blocked**
- Move **Microsoft 365 standard connectors** (SharePoint, Teams, Outlook, OneDrive) to **Business**
- Block all custom connector URL patterns (`*` → Blocked)
- Set the default group for new connectors to **Blocked**

---

## 4. Step 3 — Enable Managed Environments

**Managed Environments** is a premium suite that unlocks the security controls needed for enterprise governance. It is required for: IP Firewall, IP Cookie Binding, Sharing Limits, Usage Insights, Solution Checker enforcement, and Environment Routing.

**Licensing requirement:** Managed Environments requires at least one premium license (Power Apps Premium, Power Automate Premium, or Dynamics 365) in the environment.

### Enable via Portal

1. **Power Platform Admin Center** → **Environments** → select an environment
2. Select **Enable Managed Environments**
3. Configure the following features after enabling:

| Feature | Recommendation | Notes |
|---|---|---|
| **Sharing limits** | Enable + set max share count | Limit default env to ~20; prod envs as appropriate |
| **Solution checker** | Set to **Block** (not warn) | Prevents deployment of solutions failing security checks |
| **Maker welcome content** | Configure | Tell makers what's allowed; include link to policy docs |
| **Weekly usage insights** | Enable | Sends weekly digest of environment activity |
| **IP Firewall** | Enable for prod environments | See Step 7 |
| **IP Cookie Binding** | Enable | Prevents Dataverse session hijacking |

### Enable via PowerShell

```powershell
# Enable Managed Environments on a specific environment
$environment = Get-AdminPowerAppEnvironment -EnvironmentName "YOUR-ENVIRONMENT-ID"

# Update to Managed Environment
# Note: Use the Power Platform admin center UI for initial enablement;
# PowerShell for configuration changes post-enablement
```

---

## 5. Step 4 — Implement Tenant-Level DLP Policies

Power Platform DLP policies are **connector-based guardrails** that prevent makers from combining connectors that could cause data exfiltration. They are entirely separate from Microsoft Purview DLP.

### Core Concepts

- **Business** — connectors in this group can only interact with other Business connectors
- **Non-Business** — connectors that can only interact with other Non-Business connectors
- **Blocked** — connectors that cannot be used at all in that policy scope
- Policies stack: if multiple policies apply to an environment, the **most restrictive** wins
- Policies cannot be applied at the user level — only environment or tenant level

### Recommended Policy Architecture

Use a layered approach:

| Policy Layer | Scope | Purpose |
|---|---|---|
| **Tenant Baseline** | All environments | Blocks high-risk and external connectors globally |
| **Default Environment** | Default environment only | Allows only M365 standard connectors |
| **Production Policy** | Specific production environments | Business connectors permitted; external services case-by-case |
| **Developer Policy** | Developer environments | Broader but still no unmanaged HTTP connectors |

### Step-by-Step: Create a Tenant Baseline DLP Policy

1. **Power Platform Admin Center** → **Data policies** → **+ New policy**
2. Name it clearly, e.g., `TENANT-BASELINE-DLP-Block-External`
3. Under **Prebuilt connectors**:
   - Move all **Microsoft 365 standard connectors** to **Business** group
   - Move all **third-party and premium connectors** to **Blocked**
   - Leave Dataverse connectors in **Business**
4. Under **Custom connectors**:
   - Add pattern `*` → set to **Blocked**
   - This blocks all custom connectors not explicitly listed
5. Under **Scope** → **Add all environments** (applies to entire tenant)
6. **Set default group** for new connectors → **Blocked**
   - This ensures new connectors added by Microsoft are blocked by default until reviewed
7. Review and **Save**

### High-Risk Connectors to Explicitly Block

These connectors have been used in documented data exfiltration scenarios:

| Connector | Risk |
|---|---|
| HTTP / HTTP with Azure AD | Arbitrary outbound web requests; can exfiltrate data to any URL |
| HTTP Webhook | Inbound/outbound data relay |
| SharePoint (broad scope) | Bulk document access/copy |
| Azure Blob Storage | Large-scale data exfiltration |
| SMTP | Unauthorized email sending |
| Dropbox, Box, Google Drive | Cross-cloud data movement |
| RSS, Twitter/X | Data leakage to public platforms |

### Connector Endpoint Filtering

For HTTP, HTTP with Azure AD, HTTP Webhook, SQL Server, Azure Blob Storage, and SMTP — you can restrict **which specific endpoints** are reachable, even if the connector is allowed:

1. **Data policies** → select your policy → **Edit** → **Prebuilt connectors**
2. Select the connector → **Configure connector** → **Endpoint filtering**
3. Add allowed URL/IP patterns; all others are denied

### Desktop Flow DLP (Power Automate Desktop)

1. **Settings** → **Tenant settings** → **Desktop flow actions in DLP** → Enable
2. Once enabled, add desktop flow action groups to your DLP policies
3. Classify sensitive action groups (file system, clipboard, registry) as **Blocked** or **Business** as appropriate

> **Warning:** This setting cannot be reversed once enabled.

### PowerShell: Validate DLP Policy Coverage

```powershell
# List all DLP policies and their scope
Get-AdminDlpPolicy | Select-Object DisplayName, EnvironmentFilter, CreatedTime

# Check what connectors are classified in a specific policy
$policy = Get-AdminDlpPolicy -PolicyName "YOUR-POLICY-NAME"
$policy.ConnectorGroups

# Identify environments with NO DLP policy coverage
$allEnvs = Get-AdminPowerAppEnvironment
$coveredEnvs = (Get-AdminDlpPolicy).Environments.Id
$allEnvs | Where-Object { $_.EnvironmentName -notin $coveredEnvs } | 
    Select-Object DisplayName, EnvironmentType
```

---

## 6. Step 5 — Configure Tenant Isolation (Cross-Tenant)

Power Platform tenant isolation controls whether connectors using Azure AD authentication (SharePoint, Teams, Outlook, etc.) can connect **to or from other Azure AD tenants**. This is different from Azure AD tenant restrictions and only applies to Power Platform connectors.

**Key facts:**
- Applies to ALL environments in the tenant
- Only affects Azure AD-based connectors (not connectors using API keys or basic auth)
- Can block inbound (external users connecting to your tenant), outbound (your users connecting to other tenants), or both

### Recommended Configuration

For most organizations: **Block all cross-tenant connector flows by default, with explicit allow-list for trusted partner tenants.**

### Portal Steps

1. **Power Platform Admin Center** → **Policies** → **Tenant isolation**
2. Set **Tenant isolation** to **On**
3. Under **Allow list**, add any trusted partner tenant IDs that require connector integration
4. Set **Default rule** to **Block inbound and outbound**
5. Save

### PowerShell

```powershell
# Check current isolation policy
Get-PowerAppTenantIsolationPolicy

# Enable tenant isolation with block inbound and outbound as default
$policy = @{
    tenantIsolationSettings = @{
        isDisabled = $false
        allowedTenants = @()  # Add trusted tenant IDs here
    }
}
Set-PowerAppTenantIsolationPolicy -TenantIsolationSettings $policy
```

---

## 7. Step 6 — Apply Conditional Access to Power Platform

Standard Entra ID Conditional Access applies to the Power Platform cloud apps. This is separate from the per-app Conditional Access available in Managed Environments.

### Cloud App IDs for Power Platform

| Service | Cloud App Name in CA |
|---|---|
| Power Apps | PowerApps |
| Power Automate | Microsoft Flow |
| Power Platform Admin Center | Power Platform Admin Center |
| Dataverse | Common Data Service |
| Copilot Studio | Microsoft Copilot Studio |

### Recommended CA Policies

**Policy 1: Require MFA + Compliant Device for Power Platform**

1. **Entra Admin Center** → **Security** → **Conditional Access** → **+ New policy**
2. **Users**: All users (exclude break-glass)
3. **Target resources**: Select `PowerApps`, `Microsoft Flow`, `Common Data Service`
4. **Conditions**: No exclusions unless needed
5. **Grant**: Require MFA + Require compliant device (or Hybrid Azure AD joined)
6. **Session**: Consider sign-in frequency (8 hours for production access)
7. Enable → Save

**Policy 2: Block Power Platform Access from Non-Compliant/Non-Managed Devices**

Useful for high-sensitivity environments.

1. Target resources: Power Platform apps
2. Conditions: **Filter for devices** → `device.isCompliant -ne True -and device.trustType -ne "ServerAD"`
3. Grant: **Block**

**Policy 3: Per-App CA for Specific Production Apps (Managed Environments)**

Available as a preview in Managed Environments. Allows CA policy scoped to individual Power Apps, not just the entire service:

1. Enable Managed Environments on the target environment
2. **Power Platform Admin Center** → **Environments** → select environment → **Settings** → **Product** → **Privacy and Security**
3. Under **Conditional access** → configure per-app policies

> **Note:** Per-app CA for Power Apps requires Managed Environments (premium licensing).

---

## 8. Step 7 — Enable IP Firewall for Dataverse Environments

IP Firewall restricts Dataverse access to specific IP ranges. It works at the **network layer**, meaning it applies to both apps and direct API/SDK access. It also prevents **token replay attacks** — a stolen Dataverse access token cannot be used from outside the allowed IP range.

**Requirements:**
- Managed Environment with Dataverse
- Power Platform Administrator or Environment Admin role

### Recommended Rollout

**Phase 1: Audit Mode (minimum 1 week)**

Run in audit-only mode first to capture all IP addresses making Dataverse requests before enforcing.

1. **Power Platform Admin Center** → **Environments** → select environment
2. **Settings** → **Product** → **Privacy and Security**
3. Under **IP address settings** → **IP firewall** → Toggle **On**
4. Add your known IP ranges (office networks, VPN, trusted CIDNRs)
5. Enable **Audit-only mode** = **On**
6. Save

**Retrieve audit log to identify any missing IP ranges:**

```
GET https://[orgURI]/api/data/v9.1/audits?$select=createdon,changedata,action&$filter=action%20eq%20118&$orderby=createdon%20desc&$top=100
```

**Phase 2: Enforce**

After reviewing audit logs and confirming your IP ranges are complete:

1. Return to IP Firewall settings
2. Disable **Audit-only mode**
3. Save

**Limits:** Up to 200 IP address ranges in CIDR format (RFC 4632).

### Enable IP Cookie Binding

Prevents session hijacking in Dataverse by binding session cookies to the originating IP address.

1. Same location: **Settings** → **Product** → **Privacy and Security**
2. Enable **IP address-based cookie binding**
3. Save

---

## 9. Step 8 — Configure Environment Security Groups & RBAC

### Environment Security Groups

Assign an Azure AD security group to each environment to control which users can access it. Users not in the security group cannot access the environment, even if they have a Power Platform license.

1. **Power Platform Admin Center** → **Environments** → select environment
2. **Settings** → **Users + permissions** → **Security groups**
3. Select a security group → **Save**

**Best practices:**
- Create a dedicated security group per environment (e.g., `SG-PowerPlatform-Prod-Users`)
- Use dynamic membership rules based on department or role where appropriate
- The default environment **cannot** be fully restricted via security groups (all licensed users have access), but assigning a group limits some privileges

### Dataverse Security Roles (Least Privilege)

Do not assign the **System Administrator** role to regular users. Create custom roles:

1. **Settings** → **Users + permissions** → **Security roles** → **+ New role**
2. Define minimum privileges required for the specific app or data
3. Use **Basic (User)** access level wherever possible; avoid **Organization** scope unless necessary
4. Assign roles via security groups (Entra group teams) rather than individual user assignments for scalability

**Key principle:** Never copy the System Administrator role and assign it broadly. If users need to assign roles to others, create a custom delegated admin role with only that privilege.

### Guest User Restrictions

By default, Azure AD guest users can create Power Apps. Restrict this:

```powershell
# Check current guest/external user settings
Get-TenantSettings

# Disable guest users from creating Power Apps
Set-TenantSettings -RequestBody @{ 
    disableGuestsRunningFlows = $true
}
```

Also restrict via Entra External Collaboration settings to prevent guests from accessing Power Platform maker portals.

---

## 10. Step 9 — Configure Dataverse Auditing

Dataverse auditing captures: user access events, data read/write operations, security role changes, and admin actions. This is required for forensic investigation and compliance.

### Enable Environment-Level Auditing

1. **Power Platform Admin Center** → **Environments** → select environment
2. **Settings** → **Audit and logs** → **Audit settings**
3. Enable:
   - **Start Auditing** = On
   - **Log access** = On (captures read operations)
   - **Read Logs** = On
4. Save

### Enable Entity-Level Auditing

Auditing must also be enabled per table/entity:

1. **Settings** → **Audit and logs** → **Entity and field audit settings**
2. In the left panel, select each high-value entity (Contact, Account, custom entities with sensitive data)
3. Under **General** tab → **Data Services** → enable **Auditing**
4. Save

**Recommended entities to audit at minimum:**
- Security Role (required — capture role assignments/removals)
- User
- SystemUser
- Any entity containing PII, financial data, or health data

### Forward Audit Logs to Microsoft Purview

Power Platform activity logs (admin, maker, and user activity) flow to Microsoft Purview Audit:

1. **Microsoft Purview Compliance Portal** → **Audit** → verify Power Platform activity types are being captured
2. Activity types include: PowerAppsApp.Launch, PowerAppsApp.Edit, Flow.Run, Flow.Edit, DLP policy changes

---

## 11. Step 10 — Enable Microsoft Sentinel Integration

For organizations using Microsoft Sentinel, the **Microsoft Sentinel solution for Power Platform** provides:

- Detection of mass data deletion
- Unauthorized app execution alerts
- Suspicious connector usage
- DLP policy violation events
- Admin activity anomaly detection

### Setup

1. In **Microsoft Sentinel** → **Content Hub** → search for `Power Platform`
2. Install the **Microsoft Sentinel Solution for Power Platform**
3. Configure the data connectors:
   - Power Platform Inventory (requires Managed Environments)
   - Power Platform Admin Activity
   - Dataverse Audit Logs
4. Review and enable the included **analytics rules** and **workbooks**

### Alternative: Export to Application Insights (Managed Environments)

For environments not using Sentinel, export Dataverse telemetry to Azure Application Insights:

1. **Power Platform Admin Center** → select Managed Environment
2. **Settings** → **Product** → **Application Insights**
3. Connect your Application Insights workspace
4. Enable log export categories as needed

---

## 12. Step 11 — Copilot Studio (Agent) Security

Copilot Studio agents built on Power Platform introduce additional attack surface: they can connect to Dataverse, SharePoint, and external services, and they expose conversational interfaces that may be deployed publicly.

### Agent Authentication Configuration

**For internal agents (employees only):**

1. **Copilot Studio** → select agent → **Settings** → **Security** → **Authentication**
2. Set to **Authenticate with Microsoft** (Azure AD)
3. Require login — do not allow unauthenticated access for internal agents
4. Configure appropriate scopes

**For external/public agents:**

- Use **Manual authentication** with explicit OAuth scopes
- Apply IP Firewall if the agent connects to Dataverse
- Restrict knowledge sources to non-sensitive content

### DLP Policies Apply to Copilot Studio

DLP connector policies apply to Copilot Studio agents — the same connectors classified as Blocked in your DLP policy cannot be used by agents. This is enforced automatically.

### Generative AI (Generative Answers / Orchestration)

When agents use generative AI features that pull from knowledge sources:

- **SharePoint knowledge sources**: Only content the user has access to is returned (respects existing SharePoint permissions)
- **Dataverse knowledge sources**: Respects column-level security and Dataverse security roles
- **Sensitivity labels**: If Purview sensitivity labels are applied to content, the label is surfaced in agent responses (see Step 12)

### Disable Unapproved Agents

1. **Power Platform Admin Center** → **Copilot Studio** → review published agents
2. Use the **CoE Starter Kit** inventory to identify unmanaged agents
3. Disable agents that do not have an assigned owner or sponsor

---

## 13. Step 12 — Purview Integration & Sensitivity Labels

### Enable Sensitivity Labels for Power Platform

Purview sensitivity labels protect data accessed by Power Platform, including through Copilot Studio agents and Power Apps connected to SharePoint or Dataverse.

**Prerequisites:**
- Microsoft Purview E3/E5 or equivalent license
- Sensitivity labels published to users

**Enable for SharePoint/OneDrive (required for full agent protection):**

1. **Microsoft Purview Portal** → **Information protection** → **Labels**
2. Verify labels are published to the maker population
3. **SharePoint admin center** → verify sensitivity labels are enabled for SharePoint and OneDrive

**Dataverse sensitivity labels (GA June 2026):**

1. In **Microsoft Purview Data Map** → enable **autolabel** for target environments
2. Dataverse column-level labels are automatically applied based on SIT (sensitive information types)
3. Labels appear in Copilot Studio responses and citations

### DSPM for AI

If your organization uses Copilot Studio agents with generative AI:

1. **Microsoft Purview** → **Data Security Posture Management (DSPM) for AI**
2. Review AI interaction audit events and sensitive data exposure risks
3. Configure Insider Risk Management policies scoped to **Risky AI usage** template
4. Consider enabling Communication Compliance policies for high-risk agent scenarios

---

## 14. Step 13 — Center of Excellence (CoE) Starter Kit

The CoE Starter Kit is a free, Microsoft-provided governance toolset built on Power Platform itself. It provides:

- **Inventory of all environments, apps, flows, and connectors** across the tenant
- **Maker activity tracking** — who built what, when, and what connectors they used
- **Governance notifications** — automated emails to makers whose apps violate policies
- **Compliance reporting** — identify apps with no owners, high-risk connectors in use, etc.
- **DLP impact analysis** — evaluate the blast radius of a DLP policy change before deploying

### Installation (Requires Dedicated Environment)

1. Create a **dedicated admin/CoE environment** — do NOT install in the default environment
2. Download the [CoE Starter Kit](https://learn.microsoft.com/power-platform/guidance/coe/starter-kit)
3. Follow the [setup guide](https://learn.microsoft.com/power-platform/guidance/coe/setup) — setup takes approximately 2–4 hours
4. Configure the **Audit Log** component to connect to Microsoft Purview
5. Run the **Power BI report** for ongoing visibility

**Key components to enable:**
- Core Components (required for all others)
- Governance Components (automated maker communications, policy enforcement)
- Audit Log Components (usage tracking via Purview Audit)

---

## 15. Step 14 — Secure the Power Platform Admin Role

### Use PIM for Power Platform Administrator Role

The Power Platform Administrator role grants tenant-wide control over all environments, DLP policies, and tenant settings. It should be Just-in-Time only.

1. **Entra Admin Center** → **Identity Governance** → **Privileged Identity Management**
2. Find the **Power Platform Administrator** role
3. Configure as **Eligible** (not Permanent) with:
   - Activation duration: 4–8 hours max
   - Require MFA on activation
   - Require justification
   - Require approval (optional, for tightest control)
4. Assign admins as Eligible members

### Break-Glass for Power Platform

Ensure at least one emergency Global Admin account can access the Power Platform Admin Center in case PIM is unavailable. Document and test this access path.

### Limit System Administrator in Dataverse

The Dataverse **System Administrator** security role is the equivalent of a local admin — it can see all data, change all settings, and delete records. Audit current assignments:

1. **Power Platform Admin Center** → **Environments** → select environment → **Settings** → **Users + permissions** → **Security roles**
2. Select **System Administrator** → **Members** tab
3. Remove any accounts that don't require this level of access
4. Service accounts used by integrations should use custom minimum-privilege roles

---

## 16. Step 15 — Copilot & AI Governance Settings (Security Hub)

**Location in portal:** Power Platform Admin Center → **Copilot** (left nav) → **Settings**

This section covers the settings visible in Image 1. These are **tenant-level or environment-level controls** governing how generative AI features behave across Power Platform and Copilot Studio. Most of these default to **On** — a significant security risk for organizations that haven't reviewed them.

---

### Power Platform AI Settings

| Setting | Location | Security Recommendation | Rationale |
|---|---|---|---|
| **Copilot feedback** | Tenant-level | **Off** for regulated environments | Controls whether users can submit feedback to Microsoft from Copilot interactions. Any feedback may contain prompt/response data. Disable to minimize data leaving your tenant. |
| **Generative AI Settings** | Tenant-level | **Review and restrict** | Master toggle for AI feature availability in Power Platform products. Disable for environments where generative AI has not been risk-assessed. |
| **Preview and experimental AI models** | Tenant-level | **Off** for production environments | Preview/experimental models may process data outside your geographic region and are subject to different terms. Microsoft explicitly states these are **not meant for production use**. Only enable in isolated developer environments. |
| **AI prompts** | Tenant-level | **Off** if not governed | Controls whether makers see pre-built and custom prompts in generative AI experiences. Disable if your organization has not established an AI acceptable use policy. |
| **External models** | Tenant-level (expandable) | **Off by default; explicit opt-in only** | See below — this is a critical control. |

### ⚠️ External Models — Critical Control

**What it does:** Allows Copilot Studio agents and Power Platform flows to use third-party LLMs (currently Anthropic, Mistral, and xAI/Grok) instead of Microsoft-hosted models.

**Risk:** External models are hosted **outside Microsoft's infrastructure**. Data sent to these models is subject to each provider's own terms and data handling policies. Microsoft's own safety documentation explicitly notes that Grok (xAI) has been assessed as having **higher risk of producing harmful content and lower jailbreak resistance**.

**Recommended posture:**

1. **Power Platform Admin Center** → **Copilot** → **Settings** → expand **External models** → set to **Off**
2. Also enforce at the Microsoft 365 admin center level:
   - **M365 Admin Center** → **Copilot** → **Settings** → **AI providers for other large language models** → restrict to no groups or specific approved groups only
3. This two-layer control is required — the PPAC setting only takes effect after the M365 Admin Center allows the provider

> **For MSP clients:** Default should be **Off** for all providers unless the client has explicitly reviewed the third-party terms and accepted the risk in writing. This is a data sovereignty and compliance issue, not just a feature preference.

---

### Copilot Studio Settings

| Setting | Location | Security Recommendation | Rationale |
|---|---|---|---|
| **Computer use** | Environment-level | **Off** unless explicitly required | Allows agents to control a Windows computer via AI vision. Massive attack surface — agents can interact with arbitrary websites and desktop apps. High data exfiltration risk. Disable at the tenant level unless a specific, governed use case requires it. |
| **Entra agent identity for Copilot Studio** | Tenant-level | **Leave On** (but govern via Entra Agent ID) | This enables modern agent identity using Entra Agent ID objects. Keeping this On is the right posture — it means agents get proper identity objects that can be governed in Entra (Conditional Access, ID Protection). Disabling it forces agents back to legacy identity models. Govern the agents, don't disable the feature. |
| **Code generation and execution in Copilot Studio** | Tenant/Env-level | **Off** for production; **Off** for most clients | Allows agents to generate and execute code dynamically. This is a significant risk — dynamically executed code is difficult to audit and could be used to exfiltrate data or perform unauthorized actions. Only enable with extensive testing in isolated environments. |
| **Connected agents (Preview)** | Preview — Tenant-level | **Off** | Allows a Copilot Studio agent to invoke another agent. Preview feature. Multi-agent orchestration introduces complex trust chains that are difficult to govern. Disable until GA and until your agent governance model is mature. |
| **Hosted browser in Copilot Studio (Preview)** | Preview — Tenant-level | **Off** | Enables the Computer Use feature to run on a Microsoft-hosted browser powered by Windows 365 for Agents. The portal explicitly warns that **data flows to Windows 365 which operates outside the Azure compliance boundary**. This is a significant compliance red flag. Disable at the tenant level immediately. |
| **Knowledge sources for agents** | Tenant/Env-level | **Restrict** | Controls which types of knowledge sources agents can reference (SharePoint, Dataverse, public web, etc.). Disable **public web** as a knowledge source for agents that access sensitive data. Restrict to approved internal sources only. |
| **Skills in agents** | Tenant/Env-level | **Off** unless governed | Allows agents to use other agents as skills. Same multi-agent trust chain risk as Connected agents. |
| **Client application access control** | Environment-level | **Configure** — see below | Described as "Help prevent data exfiltration." See details below. |

### Client Application Access Control

This setting (visible at the bottom of Image 1) restricts which client applications can connect to Dataverse in the environment. This prevents data exfiltration via unauthorized clients (e.g., a user connecting Excel directly to a Dataverse environment and bulk-exporting records).

**Steps to configure:**

1. **Power Platform Admin Center** → **Environments** → select environment → **Settings** → **Product** → **Privacy and Security**
2. Under **Client application access control**, configure an allow-list of permitted client application IDs
3. Block access from unrecognized client apps

> **Note:** This requires Managed Environments.

### Disable Hosted Browser at Tenant Level (Priority Action)

```
Power Platform Admin Center → Manage → Tenant settings → 
Hosted browser in computer use → Off → Save
```

This is a one-step action that prevents any agent in your tenant from using the Microsoft-hosted browser (Windows 365 for Agents), which routes data outside the Azure compliance boundary. This should be **disabled immediately** for any regulated client.

---

## 17. Step 16 — Advanced Connector Policies (Security Hub)

**Location in portal:** Power Platform Admin Center → **Security** (left nav) → **Data and privacy**

This section covers the settings visible in Image 2. The Security Hub's Data and Privacy page now surfaces several controls that previously required navigating to different areas.

---

### Advanced Connector Policies (Preview)

**What it is:** The **next generation** of Power Platform DLP, replacing the Business/Non-Business/Blocked classification model. ACP uses a **strict allowlist** — everything is blocked unless explicitly permitted.

**Key differences vs. classic DLP:**

| Feature | Classic DLP | Advanced Connector Policies (ACP) |
|---|---|---|
| Default posture | New connectors go to default group (you set) | **Block-by-default** — new connectors are automatically blocked |
| Connector types | All connectors including virtual | **Certified connectors only** (custom + HTTP planned later) |
| Action-level control | Limited | Full — can allow/block individual triggers and actions |
| Non-blockable connectors | Cannot block M365 standard connectors | **Can block any connector** (including Teams, SharePoint, etc.) on Managed Environments |
| MCP servers | Not supported | Supported — can block entire MCP servers |
| Design-time enforcement | Runtime only | Rolling out — catches violations while makers are authoring |
| Scope | Tenant or environment | Per-environment or environment group |

**Current status (May 2026):** Preview. **Not recommended for sole governance** yet — ACP does not yet support custom connectors or HTTP connectors. Use **alongside** classic DLP policies until GA.

**Recommended approach:**

- **ACP-only mode** (using "Advanced connector policies only" toggle in Image 2) — switches the environment to evaluate ACP instead of classic DLP. Do **not** enable this until custom connector support is GA, as it would leave custom connectors ungoverned.
- For pilot environments or high-security Managed Environments: configure ACP as an **additional layer** on top of classic DLP.

**Steps to configure ACP on a single environment:**

1. **Security** → **Data and privacy** → **Advanced connector policies (preview)**
2. Select the target environment
3. The policy loads with non-blockable connectors pre-approved
4. Use **Add connectors** to explicitly allow certified connectors needed for that environment
5. Remove/block any connectors not required
6. For MCP servers: block entire MCP servers that are not approved
7. Save — the policy status shows **Applied** or **Not applied**

> **MSP guidance:** Deploy ACP on the default environment and any production Managed Environments as an additional governance layer. Do not enable ACP-only mode until custom connector support arrives.

---

### Data Policy (Classic DLP)

The **Data policy** tile in the Security Hub is a shortcut to the existing DLP policy management (covered in Step 4). No change to classic DLP behavior — this is a navigation convenience.

---

### Azure Virtual Network Policies

Allows Power Platform connectors and Dataverse plug-ins to call resources inside your Azure VNet **without exposing them over the public internet**. Requires a dedicated Azure subnet delegated to Power Platform.

**When to use:** Organizations with on-premises resources, Azure-hosted databases, or internal APIs that agents/flows need to access without public internet exposure.

**Prerequisites:** Azure subscription with VNet, Managed Environments.

**Steps:**
1. **Security** → **Data and privacy** → **Azure Virtual Network policies**
2. Connect to an existing Azure subnet that has been delegated to Power Platform
3. Configure which environments use the VNet policy

---

### Knowledge Sources for Agents (Security Hub)

Controls which types of knowledge sources are available to makers when building agents. Restrict this to prevent agents from being built that reference unsanctioned external data sources.

**Recommended:** Disable **public web** as a knowledge source at the tenant level unless specifically required. Only enable **SharePoint** and **Dataverse** as default allowed sources, and require approval for others.

---

### Skills in Copilot Studio (Preview)

Same as the Copilot Studio setting covered in Step 15. Keep **Off** until multi-agent trust governance is mature in your environment.

---

### Customer-Managed Encryption Key

**What it is:** Replaces Microsoft-managed encryption keys with keys your organization controls in Azure Key Vault. This means Microsoft cannot decrypt your Power Platform data without your key.

**When required:** Organizations with strict data sovereignty requirements (government, financial services, healthcare with contractual requirements).

**Tradeoffs:**
- If your key is revoked or lost, **data is permanently inaccessible**
- Some features are incompatible with CMK (e.g., Copilot canvas app control)
- Adds operational complexity and key rotation burden

**Recommendation:** Only configure for environments with a documented regulatory requirement. Ensure key backup and rotation procedures are in place before enabling.

---

## 18. Step 17 — Compliance & Auditing (Security Hub)

**Location in portal:** Power Platform Admin Center → **Security** → **Compliance**

This section covers Image 3 — the Auditing flyout panel and the Customer Lockbox tile visible in the Compliance section.

---

### Auditing Configuration (Image 3 Analysis)

The screenshot shows the **Auditing flyout** for the environment named `Conditional Access Tech (default)`. Current observed state:

| Setting | Observed State | Recommended State | Gap? |
|---|---|---|---|
| Turn on auditing | ✅ On | On | ✓ Correct |
| Log User sign-ins | ✅ Enabled | Enabled | ✓ Correct |
| Log Activity | ✅ Enabled | Enabled | ✓ Correct |
| Auditing covers: Common entities across Dynamics 365 | ✅ Enabled | Enabled | ✓ Correct |
| Security (org settings, roles, users, teams, BUs, column security, masking rules) | ✅ Included | Included | ✓ Correct |
| **Event log retention** | **Forever** | **Review against policy** | ⚠️ See note |

**On "Forever" retention:** Setting retention to "Forever" means logs are **never automatically deleted**. This is operationally acceptable and avoids inadvertent log loss, but be aware:
- Storage grows continuously — large environments with high activity can accumulate significant storage costs
- This setting only affects logs stored **in Dataverse** (not Purview Audit, which has its own retention)
- Changing the retention period does **not retroactively apply** to existing records — only new records created after the change inherit the new retention period
- For regulated industries, "Forever" is often appropriate; for others, align to your legal hold / retention policy (e.g., 3 years, 7 years)

**Recommended audit configuration steps (centralized via Security Hub):**

1. **Power Platform Admin Center** → **Security** → **Compliance** → **Auditing**
2. Select each environment
3. Select **Set up auditing**
4. Enable **Turn on auditing**
5. Enable both **User sign-ins** and **Activity**
6. Enable **Common entities across Dynamics 365** (covers Security entities — roles, users, teams, BUs)
7. Set **Event log retention** to match your organization's data retention policy
8. Save

> **Important:** This path via **Security → Compliance → Auditing** sets the retention policy in a way that **can apply to existing logs**, unlike the environment-level settings path. Microsoft recommends using this Security Hub path for retention policy changes.

**Environments to audit:** Enable on all production and sandbox environments. For developer environments, at minimum enable sign-in logging.

---

### Read Logs (Purview Integration)

The **Read logs** setting (available in environment-level audit settings, not shown in the screenshot but configurable in the same flyout) sends Dataverse audit logs to **Microsoft Purview Audit**. This is required for centralized, cross-tenant audit log analysis and long-term retention.

**Enable Read logs:**

1. Environment audit settings → enable **Read logs**
2. Verify in **Microsoft Purview** → **Audit** that Power Platform activity types appear
3. Activity types to confirm: `CRMEntityChangeRecord`, `CRMEntityChangeDetail`, `PowerAppsApp.*`, `Flow.*`

> **Note:** Read logs / activity logging only flows to Purview for **production environments**. Sandbox and developer environments do not forward to Purview.

---

### Customer Lockbox

The **Customer Lockbox** tile is visible in the Compliance section (Image 3). This is a Managed Environments feature.

**What it does:** On the rare occasion Microsoft support engineers need to access your Dataverse data to resolve a support issue, a **lockbox request** is sent to your Power Platform admins. Admins must **explicitly approve** before any access occurs. All access is time-limited and fully audited.

**Recommendation:** Enable for all production Managed Environments, especially those containing sensitive or regulated data.

**Steps:**

1. **Security** → **Compliance** → **Customer Lockbox**
2. Toggle **Enable lockbox policy** → On
3. Lockbox is enforced for all environments that are Managed Environments in the tenant

**Key facts:**
- Requires Managed Environments
- Does **not** apply to environments encrypted with Customer Managed Keys (CMK) — CMK is the higher tier
- Does **not** cover Azure OpenAI-powered features
- Lockbox requests have a default approval window — unanswered requests **expire and access is denied** automatically
- All approval/denial events are audited in Microsoft Purview

---

## 19. Ongoing Governance Checklist

### Monthly

- [ ] Review the **Security page** in Power Platform Admin Center and action any new recommendations
- [ ] Review the CoE Starter Kit **Power BI report** for new unmanaged apps, orphaned flows, or high-risk connector usage
- [ ] Check for new connectors added by Microsoft and classify them in your DLP policies
- [ ] Review Power Platform Administrator role assignments in PIM — remove stale eligible assignments
- [ ] Review Purview Audit for any DLP policy violation events in Power Platform

### Quarterly

- [ ] Review all DLP policies — validate connector classifications are still appropriate
- [ ] Audit environment owners and security group memberships — remove stale access
- [ ] Review all Copilot Studio agents — confirm each has an active owner and appropriate authentication
- [ ] Run the **DLP Editor tool** from CoE to simulate DLP changes before deploying
- [ ] Review Sentinel analytics rule hit rates — tune detection rules as needed

### Annually

- [ ] Re-evaluate the CIS Microsoft Dynamics 365 Power Platform Benchmark against your current configuration
- [ ] Review the Microsoft Cloud Security Benchmark (MCSB) for Power Platform updates
- [ ] Reassess environment strategy — are existing environments still needed?
- [ ] Review licensing alignment — are Managed Environment features fully utilized?

---

## 20. Licensing Reference

| Feature | Required License |
|---|---|
| Basic Power Apps / Power Automate (M365 included) | Microsoft 365 |
| DLP Policies | Included (no premium required) |
| Tenant Isolation | Included (no premium required) |
| Managed Environments | Power Apps Premium / Power Automate Premium / Dynamics 365 |
| IP Firewall | Managed Environments (premium required) |
| IP Cookie Binding | Managed Environments (premium required) |
| Advanced Connector Policies (ACP) | Managed Environments (for full non-blockable connector control); available in preview on non-Managed Environments for certified connectors |
| Customer Lockbox | Managed Environments (premium required) |
| ACP-only mode | Preview; Managed Environments recommended |
| External Models (Anthropic/Mistral/xAI) | Copilot Studio license + M365 Admin Center approval per provider |
| Computer Use / Hosted Browser | Copilot Studio license; Hosted Browser requires Windows 365 for Agents |
| Per-App Conditional Access | Managed Environments (preview) |
| VNet Integration | Managed Environments + Azure VNet |
| Customer Managed Keys | Managed Environments |
| Copilot Studio (full) | Copilot Studio license or M365 Copilot |
| Purview Sensitivity Labels | Microsoft Purview / E3+A3+ |
| DSPM for AI | Microsoft Purview add-on / E5 Compliance |
| PIM for Admin Roles | Entra ID P2 / E5 / Governance |
| Microsoft Sentinel Solution | Sentinel workspace + Managed Environments for full telemetry |

---

## 21. Reference Links

| Resource | URL |
|---|---|
| Power Platform Admin Center | https://admin.powerplatform.microsoft.com |
| Power Platform Security Overview (MS Learn) | https://learn.microsoft.com/power-platform/admin/security |
| Secure the Default Environment | https://learn.microsoft.com/power-platform/guidance/adoption/secure-default-environment |
| DLP Strategy (MS Learn) | https://learn.microsoft.com/power-platform/guidance/adoption/dlp-strategy |
| Managed Environments Overview | https://learn.microsoft.com/power-platform/admin/managed-environment-overview |
| IP Firewall | https://learn.microsoft.com/power-platform/admin/ip-firewall |
| Cross-Tenant Isolation | https://learn.microsoft.com/power-platform/admin/cross-tenant-restrictions |
| Environment Strategy | https://learn.microsoft.com/power-platform/guidance/adoption/environment-strategy |
| CoE Starter Kit | https://learn.microsoft.com/power-platform/guidance/coe/starter-kit |
| Sentinel Solution for Power Platform | https://learn.microsoft.com/azure/sentinel/business-applications/power-platform-solution-overview |
| Purview + Copilot Studio | https://learn.microsoft.com/purview/ai-copilot-studio |
| Power Platform Well-Architected Security | https://learn.microsoft.com/power-platform/well-architected/security/establish-baseline |
| CIS Dynamics 365 / Power Platform Benchmark | https://www.cisecurity.org/benchmark/microsoft_365_dyn |
| Advanced Connector Policies (ACP) | https://learn.microsoft.com/power-platform/admin/advanced-connector-policies |
| External Models / Allow LLMs | https://learn.microsoft.com/power-platform/admin/allow-llm-generative-responses |
| Administer Computer Use | https://learn.microsoft.com/microsoft-copilot-studio/administer-computer-use |
| Manage Dataverse Auditing | https://learn.microsoft.com/power-platform/admin/manage-dataverse-auditing |
| Customer Lockbox | https://learn.microsoft.com/power-platform/admin/about-lockbox |
| Copilot Studio Security & Governance | https://learn.microsoft.com/microsoft-copilot-studio/security-and-governance |
| Power Platform Zero Trust Adoption | https://learn.microsoft.com/security/zero-trust/adopt/zero-trust-adoption-overview |

---

*This guide reflects Microsoft documentation as of May 2026. Power Platform security features evolve frequently — always validate settings against current Microsoft Learn documentation before deploying in production.*
