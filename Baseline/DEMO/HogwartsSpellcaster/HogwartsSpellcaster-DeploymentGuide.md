# 🪄 Hogwarts Spellcaster — Deployment & Governance Guide

> Reference document covering publishing fixes, deployment options, and governance approaches for the Hogwarts Spellcaster declarative agent.

---

## 1. Issues Fixed During Publishing

Three validation errors were blocking the agent from publishing to tenant `e37d43b7-ff48-444b-9d44-fbd4477c18f3`.

| # | Issue | Root Cause | Fix Applied |
|---|-------|-----------|-------------|
| 1 | `copilotAgents` property rejected | `manifest.json` used schema **v1.17** which doesn't define `copilotAgents` | Updated to **v1.19** |
| 2 | `EmbeddedKnowledge` capability invalid | `declarativeAgent.json` used schema **v1.3**; `EmbeddedKnowledge` is defined in v1.6 but **not yet available** | Updated to **v1.6**, replaced with `OneDriveAndSharePoint` |
| 3 | Outline icon not transparent | `outline.png` had purple pixels `(93, 27, 130)` — Teams requires white-on-transparent only | Converted all visible pixels to white `(255, 255, 255)` |

### Spellbook Knowledge Note

The `EmbeddedKnowledge` capability (local files bundled in the app package as agent knowledge) is **not yet available** from Microsoft, even in the latest v1.6 schema. To give the agent access to the spellbook:

1. Upload `spellbook.txt` to a **SharePoint site** in your tenant
2. Update `declarativeAgent.json` to scope the `OneDriveAndSharePoint` capability:

```json
{
  "name": "OneDriveAndSharePoint",
  "items_by_url": [
    {
      "url": "https://yourtenant.sharepoint.com/sites/YourSite/Documents/spellbook.txt"
    }
  ]
}
```

3. Re-provision/re-upload the agent

Without scoping, the agent can search **all** OneDrive and SharePoint content accessible to the signed-in user.

---

## 2. Deployment Options

### Option A: VS Code + Agents Toolkit (Recommended for Development)

**Best for:** Iterating on the agent, deploying to new tenants with full control.

1. Open the `HogwartsSpellcaster/` project in VS Code
2. Install the **Microsoft 365 Agents Toolkit** extension
3. Sign in to the target tenant in the Agents Toolkit sidebar
4. Click **Provision** → generates a new App ID, resolves variables, builds the zip
5. Click **Publish** → uploads to the tenant's admin center
6. Approve in **Teams Admin Center → Manage apps** → change status from Blocked to Allowed

**Pros:**
- Handles App ID generation, variable resolution, and packaging automatically
- Environment files track state per tenant
- Easy to iterate and re-deploy

**Cons:**
- Requires VS Code and the Agents Toolkit extension
- Requires Node.js v20+

---

### Option B: Upload Zip via Microsoft 365 Admin Center (No VS Code Needed)

**Best for:** Deploying a pre-built package to new tenants quickly.

1. Go to **Microsoft 365 Admin Center → Agents → Upload agent**
2. Click **Choose file** → select `HogwartsSpellcaster.zip`
3. Walk through the wizard: Upload agent → Publish to users → Review → Finish
4. Go to **Teams Admin Center → Manage apps** → find **Hogwarts Spellcaster** → change from Blocked to Allowed

**Important:** You must use the **built app package** (not the raw source folder). The built zip contains:
- `manifest.json` — with a real GUID (not `${{TEAMS_APP_ID}}`)
- `declarativeAgent.json` — with instructions inlined (not `$[file('instructions.txt')]`)
- `color.png` and `outline.png` — the app icons

A portable zip ready for upload has been saved to: `~/Desktop/HogwartsSpellcaster.zip`

**Pros:**
- No developer tools needed
- Anyone with Teams Admin access can deploy
- Fast for multi-tenant rollout

**Cons:**
- No automatic App ID generation per tenant (uses the GUID baked into the zip)
- Changes require rebuilding the zip manually or via VS Code

---

### Key Difference: Source Files vs Built Files

| Aspect | Source Files (`appPackage/`) | Built Files (`appPackage/build/` or zip) |
|--------|------------------------------|------------------------------------------|
| App ID | `${{TEAMS_APP_ID}}` (variable) | `d9d840b9-2c6f-...` (resolved GUID) |
| Instructions | `$[file('instructions.txt')]` (file reference) | Full instructions inlined (~7KB) |
| Can upload directly? | ❌ No — variables won't resolve | ✅ Yes — self-contained |

---

## 3. Governance & Access Control Options

### Teams Admin Center (Primary — Available Now)

The main governance mechanism for declarative agents. Declarative agents published via the Teams app catalog are managed entirely within the M365/Teams app management layer.

| Control | How |
|---------|-----|
| **Block/Allow** the app | Teams Admin Center → Manage apps → App status |
| **Scope to users/groups** | Teams Admin Center → Permission policies → assign to specific users/groups |
| **Pre-install for users** | Teams Admin Center → Setup policies → add the app |

✅ **Per-agent granularity**
✅ **Available now**

---

### Conditional Access with Custom Security Attributes

Custom Security Attributes can be assigned to Enterprise Applications (Service Principals) in Entra ID, then targeted in Conditional Access policies to enforce MFA, device compliance, etc.

#### ⚠️ Limitation for Declarative Agents

Declarative agents published through the Teams app catalog **do not create a Service Principal in Entra ID**. Without a Service Principal, there is no object to assign a custom security attribute to.

> *"When you don't have a service principal listed in your tenant, it can't be targeted."*
> — [Microsoft: Filter for applications in Conditional Access](https://learn.microsoft.com/entra/identity/conditional-access/concept-filter-for-applications)

---

### Conditional Access for Agent ID (Preview)

Microsoft has a preview feature specifically for agent governance. It requires the agent to have an **Agent Identity** provisioned through:

- **Microsoft Foundry** — auto-provisions agent identities
- **Copilot Studio** — can auto-assign agent identities when enabled
- **Teams Developer Portal** — can create agent identity blueprints

A plain declarative agent deployed via the Agents Toolkit **does not** get an agent identity automatically.

✅ **Per-agent granularity**
⚠️ **Preview only — requires Copilot Studio or Foundry**

---

### Conditional Access on the M365 Copilot Service Principal

Since the agent runs inside Microsoft 365 Copilot, you can apply Conditional Access to the Copilot service itself:

1. Entra ID → Enterprise applications → search **Microsoft 365 Copilot**
2. Assign a custom security attribute
3. Create a CA policy filtering on that attribute

⚠️ **Gates all of Copilot, not just the Spellcaster agent**

---

### Comparison Summary

| Approach | Granularity | Available Now? | Requires |
|----------|-------------|----------------|----------|
| **Teams Admin Center** (block/allow + permission policies) | Per-agent | ✅ Yes | Teams Admin role |
| **Conditional Access for Agent ID** | Per-agent identity | ⚠️ Preview | Copilot Studio or Foundry |
| **CA on M365 Copilot service principal** | All of Copilot | ✅ Yes | CA Admin + Attribute roles |
| **CA with custom security attribute on the app** | Per-app | ❌ Not possible | No Service Principal exists |

---

### Required Entra ID Roles for Custom Security Attributes

If you do use custom security attributes (e.g., on the M365 Copilot service principal):

| Role | Purpose |
|------|---------|
| **Attribute Definition Administrator** | Create attribute sets and definitions |
| **Attribute Assignment Administrator** | Assign attribute values to enterprise apps |
| **Conditional Access Administrator** | Create/edit CA policies |

> **Important:** Global Administrator does **not** automatically have custom security attribute permissions. These roles must be explicitly assigned.

---

## 4. Quick Reference

| Item | Value |
|------|-------|
| **App Name** | Hogwarts Spellcaster |
| **Tenant ID** | `e37d43b7-ff48-444b-9d44-fbd4477c18f3` |
| **Teams App ID (dev)** | `d9d840b9-2c6f-4039-99c9-11bc5bc06ec7` |
| **Portable Zip GUID** | `0620e112-a9f8-4d59-b9db-725eefa0ee6a` |
| **Manifest Schema** | v1.19 |
| **Agent Schema** | v1.6 |
| **Portable Zip Location** | `~/Desktop/HogwartsSpellcaster.zip` |
| **Admin Approval URL** | https://aka.ms/teamsfx-mtac |
