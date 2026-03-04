
# IAC Agent Identity Configuration Guide

## Microsoft Entra Agent ID — Harry Potter Demo Tenant

| Property | Value |
|----------|-------|
| **Tenant** | acme2m365.onmicrosoft.com |
| **Tenant ID** | `e37d43b7-ff48-444b-9d44-fbd4477c18f3` |
| **Sponsor** | Jon Hope (`d5f7d3fe-f83b-4d14-a45f-5b106348ce10`) |
| **Feature** | Microsoft Entra Agent ID (Preview) |
| **API Version** | Microsoft Graph Beta |
| **Created** | July 2025 |

---

## Table of Contents

1. [What Is Microsoft Entra Agent ID?](#what-is-microsoft-entra-agent-id)
2. [Architecture Overview](#architecture-overview)
3. [Deployed Blueprints & Agent Identities](#deployed-blueprints--agent-identities)
4. [How Each Agent Can Be Used](#how-each-agent-can-be-used)
5. [Can Agents Be Added to Teams?](#can-agents-be-added-to-teams)
6. [Can Agents Query Hogwarts Data?](#can-agents-query-hogwarts-data)
7. [Agent Users — Digital Workers in Teams & Outlook](#agent-users--digital-workers-in-teams--outlook)
8. [Conditional Access for Agents](#conditional-access-for-agents)
9. [Security & Governance Controls](#security--governance-controls)
10. [Known Limitations (Preview)](#known-limitations-preview)
11. [Management & Lifecycle](#management--lifecycle)
12. [Prerequisites](#prerequisites)
13. [References](#references)

---

## What Is Microsoft Entra Agent ID?

Microsoft Entra Agent ID is a **preview feature** that extends Entra ID to provide dedicated identity management for AI agents. It solves a fundamental problem: existing identity models (user accounts and app registrations) were never designed for the dynamic, ephemeral nature of AI agents.

Agent ID introduces a purpose-built identity type that allows organisations to:

- **Distinguish** AI agent operations from human and workload identities
- **Right-size** access — agents get exactly the permissions they need
- **Prevent** agents from gaining privileged administrative roles
- **Scale** identity management to thousands of agents created and destroyed dynamically
- **Audit** all agent activity separately in sign-in and audit logs

### Identity Hierarchy

```
Agent Identity Blueprint (Application)
    └── Blueprint Principal (Service Principal in tenant)
         └── Agent Identity (ServiceIdentity — the actual "agent")
              └── Agent User (Optional — for Teams, mailbox, etc.)
```

---

## Architecture Overview

Each agent is built from a **three-tier architecture**:

### Tier 1 — Agent Identity Blueprint

A reusable template (an application registration with `@odata.type = Microsoft.Graph.AgentIdentityBlueprint`) that defines the *kind* of agent. Think of it as a class definition. Blueprints capture:

- Display name and description
- Owner and sponsor (accountable human)
- OAuth2 scopes and identifier URIs
- Client credentials for autonomous operation

### Tier 2 — Blueprint Principal

A tenant-level service principal (`graph.agentIdentityBlueprintPrincipal`) that activates the blueprint in your tenant. This is what makes the blueprint usable and allows Conditional Access policies to target it.

### Tier 3 — Agent Identity

The actual agent instance (a service principal with `servicePrincipalType = ServiceIdentity`) created *by* the blueprint using its own `client_credentials` token. Each blueprint can create many agent identities — like instantiating objects from a class.

```
┌─────────────────────────────────────────────────────────────┐
│                  ENTRA AGENT ID ARCHITECTURE                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────┐    ┌───────────────────┐            │
│  │ 🎩 Sorting Hat    │    │ 🛡️ Auror Sentinel  │  ...       │
│  │   (Blueprint)     │    │   (Blueprint)      │            │
│  └────────┬──────────┘    └────────┬───────────┘            │
│           │                        │                        │
│  ┌────────▼──────────┐    ┌────────▼───────────┐            │
│  │  Blueprint        │    │  Blueprint         │            │
│  │  Principal (SP)   │    │  Principal (SP)    │            │
│  └────────┬──────────┘    └────────┬───────────┘            │
│           │                        │                        │
│  ┌────────▼──────────┐    ┌────────▼───────────┐            │
│  │ The Sorting Hat   │    │ Mad-Eye Moody      │            │
│  │ (Agent Identity)  │    │ (Agent Identity)   │            │
│  │ ServiceIdentity   │    │ ServiceIdentity    │            │
│  └───────────────────┘    └────────────────────┘            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Deployed Blueprints & Agent Identities

### Blueprints (Agent Registry)

| Blueprint | AppId | Identifier URI | OAuth Scope |
|-----------|-------|----------------|-------------|
| **Hogwarts Sorting Hat** | `cfec31f2-6e56-4b4c-91ca-b18e739c2082` | `api://cfec31f2-6e56-4b4c-91ca-b18e739c2082` | `access_agent` |
| **Auror Department Sentinel** | `0f9bca3a-b325-4837-82f3-a3973952874b` | `api://0f9bca3a-b325-4837-82f3-a3973952874b` | `access_agent` |
| **Hogwarts Library Keeper** | `a954848c-6553-4949-b64e-bdf71f551a59` | `api://a954848c-6553-4949-b64e-bdf71f551a59` | `access_agent` |
| **Ministry Owl Post** | `9f2ca896-b1d7-4901-bb41-452f63e423b9` | `api://9f2ca896-b1d7-4901-bb41-452f63e423b9` | `access_agent` |
| **Potions Lab Cauldron** | `6e48c97f-de9b-46f3-b799-149529a1a1a4` | `api://6e48c97f-de9b-46f3-b799-149529a1a1a4` | `access_agent` |

### Agent Identities (Active Agents)

| Agent Identity | SP Object ID | Blueprint | Purpose |
|----------------|-------------|-----------|---------|
| 🎩 **The Sorting Hat** | `abe80e72-5f15-4f3f-a65d-e861a4b640d4` | Hogwarts Sorting Hat | Autonomous classification — evaluates traits and assigns Hogwarts houses |
| 🛡️ **Mad-Eye Moody** | `1aea4bc4-93e7-41f1-9ed0-e966821990c0` | Auror Department Sentinel | CONSTANT VIGILANCE! Real-time threat detection and security monitoring |
| 📚 **Madam Pince** | `21afab1e-e9d7-4a8f-83ce-3c10bd3fcc5d` | Hogwarts Library Keeper | Knowledge retrieval with strict access controls and citation tracking |
| 🦉 **Hedwig** | `06a0f791-8bc3-4b27-b024-13d76c5a6f44` | Ministry Owl Post | Reliable communications routing with end-to-end encryption |
| ⚗️ **Professor Snape's Cauldron** | `5bcda6f1-cfc0-4373-878b-0081a6154a44` | Potions Lab Cauldron | Formula analysis and quality control — no dunderheads allowed |

---

## How Each Agent Can Be Used

### 🎩 The Sorting Hat — Classification Agent

**Real-world parallel:** Document classification, data labelling, user onboarding routing.

An agent that evaluates inputs against criteria and assigns categories. In a production scenario this could:

- Automatically classify incoming documents using sensitivity labels
- Route new user onboarding to the correct department/group
- Triage support tickets by severity and department
- Apply Microsoft Purview Information Protection labels based on content analysis

### 🛡️ Mad-Eye Moody — Security Sentinel

**Real-world parallel:** Threat detection, compliance monitoring, alert triage.

A security-focused agent performing continuous monitoring. Could be configured to:

- Monitor sign-in logs for anomalous behaviour and raise alerts
- Review Conditional Access policy effectiveness
- Scan for risky users/workloads and recommend remediation
- Integrate with Microsoft Sentinel or Defender for automated response

### 📚 Madam Pince — Knowledge Retrieval Agent

**Real-world parallel:** RAG-based Q&A, document search, knowledge base management.

A retrieval agent with strict access boundaries. Could:

- Search SharePoint document libraries and return citations
- Enforce sensitivity label restrictions — only surface content the requestor can access
- Query the Hogwarts SharePoint sites for library content, course materials, and policies
- Integrate with Microsoft 365 Copilot as a governed knowledge source

### 🦉 Hedwig — Communications Agent

**Real-world parallel:** Notification routing, email automation, message brokering.

A communications-focused agent. Could:

- Route notifications to the correct Teams channels
- Send scheduled email digests via Exchange Online
- Broker messages between users and other agents
- Manage communication preferences and delivery tracking

### ⚗️ Professor Snape's Cauldron — Analysis Agent

**Real-world parallel:** Data validation, formula/calculation engine, QA pipeline.

A quality-control and analysis agent. Could:

- Validate data inputs against business rules
- Run compliance checks on submitted reports
- Perform calculations and return structured results
- Flag anomalies in datasets for human review

---

## Can Agents Be Added to Teams?

### Short Answer: **Yes — but it requires an Agent User**

Agent identities on their own are service principals (`ServiceIdentity` type). They can authenticate to APIs and access Microsoft Graph resources, but they **cannot** directly join Teams channels, send chat messages, or have a mailbox.

To enable Teams participation, you need to create an **Agent User** — a special Entra user account paired 1:1 with an agent identity. This is a separate, optional step.

### What Agent Users Enable

| Capability | Agent Identity Only | With Agent User |
|------------|:------------------:|:---------------:|
| Authenticate to Graph API | ✅ | ✅ |
| Access web services autonomously | ✅ | ✅ |
| Have a mailbox | ❌ | ✅ |
| Join Teams and send chat messages | ❌ | ✅ |
| Appear in Teams as a participant | ❌ | ✅ |
| Be @mentioned in Teams/Outlook | ❌ | ✅ |
| Be added to Entra groups | ❌ | ✅ |
| Be assigned licences | ❌ | ✅ |
| Receive and respond to Word comments | ❌ | ✅ |
| Be added to administrative units | ❌ | ✅ |

### How to Create an Agent User

1. **Grant the blueprint** the `AgentIdUser.ReadWrite.IdentityParentedBy` application permission
2. **Create the agent user** via the beta Graph API, specifying the parent agent identity
3. **Assign a Microsoft 365 licence** (required for mailbox/Teams provisioning)
4. The agent user is then available in Teams, Outlook, and collaborative workflows

```powershell
# Example: Create an agent user for "The Sorting Hat"
# First: Blueprint needs AgentIdUser.ReadWrite.IdentityParentedBy permission

$agentUserBody = @{
    displayName         = "The Sorting Hat"
    agentIdentityId     = "abe80e72-5f15-4f3f-a65d-e861a4b640d4"   # Agent identity SP ID
    "sponsors@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$sponsorId")
} | ConvertTo-Json -Depth 5

# Use the blueprint's client_credentials token
Invoke-RestMethod -Method POST `
    -Uri "https://graph.microsoft.com/beta/users/graph.agentUser" `
    -Headers @{
        "Authorization" = "Bearer $blueprintToken"
        "Content-Type"  = "application/json"
        "OData-Version" = "4.0"
    } `
    -Body $agentUserBody
```

### Agent 365 SDK (For Full Teams Integration)

Microsoft's **Agent 365 SDK** provides the richest Teams integration for agents. With it, agents can:

- Use **@mentions** in Teams, Word, Outlook
- Receive and respond to notifications from Teams channels, Outlook emails, and Word comments
- Access governed **MCP (Model Context Protocol) servers** for SharePoint, Mail, Calendar, Teams data
- Gain full **OpenTelemetry** observability for audited, traceable interactions

> **Note:** Agent 365 SDK requires the Frontier preview programme and a Microsoft 365 Copilot licence.

---

## Can Agents Query Hogwarts Data?

### Short Answer: **Yes — with the right permissions**

The agent identities we've created can access Microsoft Graph and other APIs using their blueprint's `client_credentials` flow. To query Hogwarts-related data (SharePoint sites, user profiles, groups, etc.), you need to:

### 1. Grant Microsoft Graph Permissions to the Blueprint

The blueprint principal needs API permissions consented by an admin. Common permissions for querying Hogwarts data:

| Permission | Type | What It Enables |
|------------|------|-----------------|
| `Sites.Read.All` | Application | Read all SharePoint sites (Hogwarts houses, library, etc.) |
| `Sites.ReadWrite.All` | Application | Read/write SharePoint content |
| `User.Read.All` | Application | Read all user profiles (Harry Potter characters) |
| `Group.Read.All` | Application | Read Entra groups (house groups: Gryffindor, Slytherin, etc.) |
| `Files.Read.All` | Application | Read files in SharePoint/OneDrive |
| `Mail.Read` | Application | Read mailboxes (requires agent user) |
| `ChannelMessage.Read.All` | Application | Read Teams channel messages |

### 2. Example: Querying Hogwarts SharePoint Sites

```powershell
# Authenticate as the Madam Pince blueprint (Library Keeper)
$tokenBody = @{
    client_id     = "a954848c-6553-4949-b64e-bdf71f551a59"
    scope         = "https://graph.microsoft.com/.default"
    client_secret = "<Library Keeper Secret>"
    grant_type    = "client_credentials"
}
$token = (Invoke-RestMethod -Method POST `
    -Uri "https://login.microsoftonline.com/e37d43b7-ff48-444b-9d44-fbd4477c18f3/oauth2/v2.0/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $tokenBody).access_token

# Search for Hogwarts sites
$sites = Invoke-RestMethod `
    -Uri "https://graph.microsoft.com/v1.0/sites?search=Hogwarts" `
    -Headers @{ Authorization = "Bearer $token" }

$sites.value | ForEach-Object { Write-Host "$($_.displayName) — $($_.webUrl)" }
```

### 3. Example: Listing Hogwarts House Members

```powershell
# Using the Sorting Hat agent's blueprint credentials
# Query the dynamic house groups

$groups = Invoke-RestMethod `
    -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=startswith(displayName,'Hogwarts')" `
    -Headers @{ Authorization = "Bearer $token" }

foreach ($group in $groups.value) {
    Write-Host "`n$($group.displayName):" -ForegroundColor Yellow
    $members = Invoke-RestMethod `
        -Uri "https://graph.microsoft.com/v1.0/groups/$($group.id)/members?`$select=displayName,jobTitle" `
        -Headers @{ Authorization = "Bearer $token" }
    foreach ($m in $members.value) {
        Write-Host "  $($m.displayName) — $($m.jobTitle)"
    }
}
```

### What Hogwarts Data Is Available

Based on the demo tenant setup, these agents could query:

| Data Source | Type | Example Content |
|-------------|------|-----------------|
| Harry Potter users (21 characters) | Entra ID Users | Names, departments, job titles, houses |
| Hogwarts House groups | Dynamic Entra Groups | Gryffindor, Hufflepuff, Ravenclaw, Slytherin |
| SharePoint sites | SharePoint Online | House sites, library, Dumbledore's Army docs |
| Sensitivity labels | Microsoft Purview | Hogwarts tiered classification labels |
| Document libraries | SharePoint/OneDrive | Course materials, restricted section docs |

---

## Agent Users — Digital Workers in Teams & Outlook

Agent users are the key to making agents appear as team members in Microsoft 365 collaborative apps.

### Agent User Capabilities

- **Added to Entra groups** — inherit permissions from group membership (excluding role-assignable groups)
- **Assigned licences** — needed for mailbox and Teams provisioning
- **Added to administrative units** — same as human users
- **Cannot have passwords** — only authenticate through their parent agent identity's credentials
- **Cannot be assigned privileged admin roles** — security boundary prevents privilege escalation

### Security Model

```
Agent Identity Blueprint (has client_credentials)
    │
    ├── Creates → Agent Identity (ServiceIdentity SP)
    │                 │
    │                 └── Creates → Agent User (Entra User, type: agent)
    │                                   │
    │                                   ├── Mailbox
    │                                   ├── Teams presence
    │                                   ├── Group membership
    │                                   └── Licence assignments
    │
    └── Authenticates → Token (idtyp=app)
                             │
                             └── Can impersonate → Agent User Token (idtyp=user)
```

### Scenario: Adding "The Sorting Hat" to a Teams Channel

1. Create an agent user for The Sorting Hat (see example above)
2. Assign a Microsoft 365 licence to the agent user
3. Wait for mailbox/Teams provisioning (~minutes)
4. Add the agent user to a Team as a member
5. The Sorting Hat can now send/receive messages in that Team's channels
6. Users can @mention The Sorting Hat to invoke it

---

## Conditional Access for Agents

Microsoft Entra Agent ID integrates with Conditional Access, allowing you to apply adaptive policies to agents:

### What You Can Do

- **Block high-risk agents** — Microsoft-managed policies automatically block agents flagged as risky
- **Require compliant network** — enforce agents only operate from approved network locations
- **Target by blueprint** — apply policies to all instances of a specific agent type
- **Use custom security attributes** — deploy policies at scale across agent collections
- **Token lifetime controls** — restrict how long agent tokens are valid

### Example Policy: Restrict Agents to Corporate Network

| Setting | Value |
|---------|-------|
| **Assignment** | All ServiceIdentity principals |
| **Condition** | Location NOT in "Trusted corporate IPs" |
| **Grant** | Block access |

---

## Security & Governance Controls

### What Agents Cannot Do

- ❌ Be assigned **privileged administrator roles** (Global Admin, etc.)
- ❌ Have **passwords or passkeys** — only client_credentials or federated identity credentials
- ❌ **Interactively sign in** — agents cannot complete browser-based auth flows
- ❌ Be added to **role-assignable groups**
- ❌ Use **custom role assignments** (preview limitation)

### What Admins Can Do

- ✅ View all agents in the **Agent Registry** (Entra admin centre)
- ✅ Apply **Conditional Access policies** to all agents or specific blueprints
- ✅ **Disable** all agents of a given type by disabling the blueprint principal
- ✅ **Revoke permissions** at the blueprint level (affects all child agents)
- ✅ View agent **sign-in and audit logs** separately from human activity
- ✅ Use **Identity Protection** risk signals for agents
- ✅ Manage agents via **agent collections** for grouped governance

### Audit & Monitoring

All agent operations are recorded in Entra sign-in logs and clearly marked as AI agent activity. This enables:

- Separate reporting on agent vs. human operations
- Detection of anomalous agent behaviour
- Compliance evidence for regulatory requirements
- Integration with Microsoft Sentinel for SIEM/SOAR workflows

---

## Known Limitations (Preview)

| Limitation | Impact | Workaround |
|-----------|--------|------------|
| **No delegated permission for agent deletion** | Agent identities and blueprint principals cannot be deleted using delegated auth | Use app permissions or the Entra admin centre portal |
| **Rapid blueprint creation causes BadRequest** | Creating blueprints in quick succession (<30s) fails intermittently | Use ≥30-second delays between creation calls |
| **Agent users require additional permissions** | `AgentIdUser.ReadWrite.IdentityParentedBy` must be explicitly granted | Request authorisation from tenant admin |
| **Orphaned SPs after blueprint deletion** | Deleting a blueprint app leaves orphaned SPs (principals + agent identities) | Non-functional but persistent — clean up via admin centre |
| **Frontier programme required** | Agent ID requires M365 Copilot licence + Frontier enabled | Enable via M365 Admin → Copilot → Settings → User access → Copilot Frontier |
| **Teams chat limitation** | Some agent patterns only support 1:1 chats (not group chats or channel threads) | Depends on agent implementation and SDK used |

---

## Management & Lifecycle

### Viewing Agents in the Entra Admin Centre

- **Agent identities tab:** [https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AllAgents.MenuView](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AllAgents.MenuView)
- **Agent registry:** [https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AllAgents.MenuView/~/agentRegistry](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AllAgents.MenuView/~/agentRegistry)

### Listing Agents via PowerShell

```powershell
# Connect with required scopes
Connect-MgGraph -Scopes "Application.Read.All" -TenantId "e37d43b7-ff48-444b-9d44-fbd4477c18f3"

# List all blueprints
$apps = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/applications?`$select=id,appId,displayName,identifierUris&`$top=200" `
    -OutputType PSObject
$apps.value | Where-Object { $_.identifierUris -match "^api://" } |
    Format-Table displayName, appId, @{L='URI';E={$_.identifierUris -join ','}}

# List all agent identities
$sps = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/servicePrincipals?`$filter=servicePrincipalType eq 'ServiceIdentity'&`$select=id,displayName,servicePrincipalType" `
    -OutputType PSObject
$sps.value | Format-Table displayName, id, servicePrincipalType
```

### Rotating Secrets

Blueprint secrets expire after 6 months (as configured). To rotate:

```powershell
# Add new secret
$newSecret = Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/applications/<AppId>/addPassword" `
    -Body (@{ passwordCredential = @{ displayName = "AgentSecret-Rotated"; endDateTime = (Get-Date).AddMonths(6).ToString("yyyy-MM-ddTHH:mm:ssZ") } } | ConvertTo-Json) `
    -ContentType "application/json" -OutputType PSObject

# Remove old secret (by keyId)
Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/applications/<AppId>/removePassword" `
    -Body (@{ keyId = "<old-key-id>" } | ConvertTo-Json) `
    -ContentType "application/json"
```

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Licence** | Microsoft 365 Copilot |
| **Frontier Programme** | Enabled via M365 Admin → Copilot → Settings → Copilot Frontier |
| **Entra Role** | Agent ID Developer or Agent ID Administrator |
| **PowerShell** | 7.0+ with `Microsoft.Graph.Beta.Applications` module |
| **Graph API** | Beta endpoint (`https://graph.microsoft.com/beta/`) |
| **Required Scopes** | `AgentIdentityBlueprint.Create`, `AgentIdentityBlueprint.ReadWrite.All`, `AgentIdentityBlueprint.AddRemoveCreds.All`, `AgentIdentityBlueprintPrincipal.Create`, `Application.Read.All`, `User.Read` |

---

## References

| Resource | URL |
|----------|-----|
| What is Microsoft Entra Agent ID? | [learn.microsoft.com/entra/agent-id/identity-professional/microsoft-entra-agent-identities-for-ai-agents](https://learn.microsoft.com/entra/agent-id/identity-professional/microsoft-entra-agent-identities-for-ai-agents) |
| What are agent identities? | [learn.microsoft.com/entra/agent-id/identity-platform/what-is-agent-id](https://learn.microsoft.com/entra/agent-id/identity-platform/what-is-agent-id) |
| Agent users | [learn.microsoft.com/entra/agent-id/identity-platform/agent-users](https://learn.microsoft.com/entra/agent-id/identity-platform/agent-users) |
| Create a blueprint | [learn.microsoft.com/entra/agent-id/identity-platform/create-blueprint](https://learn.microsoft.com/entra/agent-id/identity-platform/create-blueprint) |
| Create agent identities | [learn.microsoft.com/entra/agent-id/identity-platform/create-delete-agent-identities](https://learn.microsoft.com/entra/agent-id/identity-platform/create-delete-agent-identities) |
| Agent 365 SDK | [learn.microsoft.com/microsoft-agent-365/developer/agent-365-sdk](https://learn.microsoft.com/microsoft-agent-365/developer/agent-365-sdk) |
| Request agent user tokens | [learn.microsoft.com/entra/agent-id/identity-platform/autonomous-agent-request-agent-user-tokens](https://learn.microsoft.com/entra/agent-id/identity-platform/autonomous-agent-request-agent-user-tokens) |
| Preview known issues | [learn.microsoft.com/entra/agent-id/identity-platform/preview-known-issues](https://learn.microsoft.com/entra/agent-id/identity-platform/preview-known-issues) |
| Conditional Access for agents | [learn.microsoft.com/entra/identity/conditional-access/agent-id](https://learn.microsoft.com/entra/identity/conditional-access/agent-id) |
| Creation script | `Create-HarryPotterAgents.ps1` in `BaslineSetup/HarryPotterPurviewDemo/` |

---

> **Document Version:** 1.0 · **Last Updated:** February 2026 · **Author:** IAC Baseline Automation
