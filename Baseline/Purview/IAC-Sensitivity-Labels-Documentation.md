# IAC Sensitivity Labels — Configuration & Best Practices

> **Author:** IAC  
> **Date:** 27 February 2026  
> **Tenant:** acme2m365.onmicrosoft.com  
> **Reference:** [Purview Practitioner Taxonomy](https://www.thepurviewpractitioner.com/tools/taxonomy) · [Microsoft Learn — Sensitivity Labels](https://learn.microsoft.com/purview/sensitivity-labels)  
> **Video:** [Ewelina's Sensitivity Label Deep Dive](https://www.youtube.com/watch?v=6TaVptqv_V8) *(recommended viewing before deployment)*

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Label Taxonomy](#3-label-taxonomy)
4. [Label Configuration Details](#4-label-configuration-details)
5. [Label Policy Architecture & Best Practices](#5-label-policy-architecture--best-practices)
6. [Publishing Walkthrough](#6-publishing-walkthrough)
7. [Deployment Runbook](#7-deployment-runbook)
8. [Verification & Troubleshooting](#8-verification--troubleshooting)
9. [DLP Integration](#9-dlp-integration)
10. [Auto-Labeling](#10-auto-labeling)
11. [Adaptive Protection](#11-adaptive-protection)
12. [Day-2 Operations](#12-day-2-operations)

---

## 1. Overview

This document describes the IAC sensitivity label taxonomy deployed to the Microsoft 365 tenant. The taxonomy follows the **Purview Practitioner 4-Group** model and aligns with CIS Microsoft 365 Foundations Benchmark v6.0.0 labelling controls.

### Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Least-privilege by default** | "General" is the default label — no encryption, light markings |
| **Parent labels are containers only** | Confidential and Restricted parents carry no file/email encryption — only Groups & Sites protection |
| **Encryption lives on child labels** | Each audience (Internal, Third Parties, Reporting) gets its own encryption scope |
| **Mandatory labelling** | Users must choose a label before saving or sending |
| **Downgrade justification** | Users must explain why they're lowering a classification |
| **Groups & Sites protection** | Parent labels protect Teams, SharePoint sites, and M365 Groups with privacy and guest access controls |

### Scope Design Rationale: Container vs. Content Protection

Microsoft Purview has **two independent protection layers** that serve different purposes:

| Layer | Scope | What It Protects | Applied To |
|-------|-------|-----------------|------------|
| **Container** | Site, UnifiedGroup | Privacy, guest access, sharing controls on the **Team/Site/Group itself** | The Team or SharePoint site as a whole |
| **Content** | File, Email | Encryption, content markings on **individual files and emails** | Each document or message inside a container |

These layers are independent — you label the **container** with a parent or top-level label, and label **files inside it** with child labels.

**Why parent labels don't carry encryption:**

Parent labels (Confidential, Restricted) are designed as **containers only**. They protect the "room" — setting the Team to Private, blocking guest access, etc. The child labels protect the "filing cabinets inside the room" — encrypting individual files with specific rights for specific audiences.

If a parent label carried encryption, every file inside that Team would inherit the same encryption template, which is too rigid. Different files within the same Confidential Team may need different audiences (internal-only vs. third-party sharing).

**Example workflow:**

```
User creates a Team → Purview prompts "What label for this Team?"
  → User picks "Confidential"  ← parent label (container scope)
  → Team is Private, guests allowed, sharing restricted

User creates a document INSIDE that Team → Purview prompts "Label this file?"
  → User picks "Confidential - Internal"  ← child label (file/email scope)
  → File is encrypted with org-wide rights + content markings

User creates another document to send to a vendor:
  → User picks "Confidential - Third Parties"  ← different child
  → User is prompted to select recipients, Do Not Forward applied
```

**Why General and Public have ALL scopes (File, Email, Site, UnifiedGroup):**

These are top-level labels (not parents with children), so they need to work everywhere — a user should be able to label a Team as "General" AND label a document as "General." Since they carry no encryption, there is no conflict between container and content protection.

**Why the Purview portal may show "Groups & sites" unchecked on parent labels:**

For parent labels (`IsParent=True`), Purview stores `ContentType` as "None" because parents delegate file/email scope to their children. The portal UI reads the `ContentType` field to render checkboxes, so it may display Groups & Sites as unchecked even when the `protectgroup` and `protectsite` LabelActions are correctly configured in the backend.

To verify the backend state, use:

```powershell
# Check if protectgroup and protectsite are present and enabled
(Get-Label -Identity "Confidential").LabelActions
# Should show: {"Type":"protectgroup"... "disabled":"false"} and {"Type":"protectsite"... "disabled":"false"}
```

If you need to ensure the checkbox appears checked in the portal, open the label in the Purview portal editor, check "Groups & sites", and re-save — this forces the UI and backend into sync.

### Files in This Package

| File | Purpose |
|------|---------|
| `Enable-SensitivityLabelsPrerequisites.ps1` | Enables MIP labels in Entra ID, SharePoint, and runs AzureADLabelSync. **Run first.** |
| `SensitivityLabel.ps1` | Creates all 9 labels (does NOT publish). **Run second.** |
| `Publish-SensitivityLabelPolicies.ps1` | Publishes labels via 3 tiered policies. **Run third.** |
| `IAC-Sensitivity-Labels-Documentation.md` | This document |

---

## 2. Prerequisites

Before creating labels, the following prerequisites must be enabled. The `Enable-SensitivityLabelsPrerequisites.ps1` script handles all three:

| # | Prerequisite | What It Does | How to Verify |
|---|-------------|--------------|---------------|
| 1 | **EnableMIPLabels = True** | Allows sensitivity labels to be applied to M365 Groups | `Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/groupSettings'` → check `EnableMIPLabels` value |
| 2 | **isSensitivityLabelsEnabled = True** | Enables sensitivity labels in SharePoint Online | `Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings'` → check `isSensitivityLabelsEnabled` |
| 3 | **Execute-AzureADLabelSync** | Syncs Purview labels to Entra ID so they appear in Teams/SharePoint admin | Run via Connect-IPPSSession |
| 4 | **Co-authoring for encrypted files** | Enables real-time co-authoring on Office files protected by sensitivity label encryption. Without this, two users cannot simultaneously edit an encrypted document — the second user receives a read-only lock. | Purview portal → **Settings** → **Co-authoring for files with sensitivity labels** → toggle **On** |

> **Co-authoring note:** Co-authoring requires Microsoft 365 Apps version 2107 or later and applies only to files stored in SharePoint Online or OneDrive for Business. On-premises file shares and non-Microsoft storage do not support co-authoring with label encryption. Enable this setting before deploying encrypted labels to end users to avoid unexpected edit conflicts.

**Required Roles:**

- Compliance Administrator **or** Information Protection Administrator (for labels)
- SharePoint Administrator (for SharePoint settings)
- Global Administrator **or** Groups Administrator (for Group.Unified settings)

**Required Modules:**

- `ExchangeOnlineManagement` v3+ (REST-based)
- `Microsoft.Graph.Authentication`

**Propagation Warning:** After running prerequisites, allow **up to 24 hours** for the "Groups & Sites" scope checkbox to appear in the Purview label editor.

---

## 3. Label Taxonomy

```
┌─────────────────────────────────────────────────────────────────────┐
│                    IAC Label Taxonomy                               │
│                    Purview Practitioner 4-Group Model               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  PUBLIC                                                             │
│  └── No protection. Safe for external sharing.                     │
│      Scope: File, Email, Site, UnifiedGroup                        │
│                                                                     │
│  GENERAL  ← Default Label                                          │
│  └── Header/footer markings. No encryption.                        │
│      Scope: File, Email, Site, UnifiedGroup                        │
│      Container: Privacy Unspecified │ Guests: Allowed              │
│                                                                     │
│  CONFIDENTIAL (parent container)                                    │
│  │   Scope: Groups & Sites only (protectgroup + protectsite)       │
│  │   Privacy: Private │ Guests: Allowed                            │
│  │                                                                  │
│  ├── Confidential - Internal                                       │
│  │   Encryption: Template (org-wide Co-Author rights)              │
│  │   Scope: File, Email                                            │
│  │                                                                  │
│  ├── Confidential - Third Parties                                  │
│  │   Encryption: User-Defined + Do Not Forward                     │
│  │   Scope: File, Email                                            │
│  │                                                                  │
│  └── Confidential - Reporting                                      │
│      Encryption: Template (org-wide Co-Author rights)              │
│      Scope: File, Email                                            │
│                                                                     │
│  RESTRICTED (parent container)                                      │
│  │   Scope: Groups & Sites only (protectgroup + protectsite)       │
│  │   Privacy: Private │ Guests: Blocked                            │
│  │                                                                  │
│  ├── Restricted - Internal                                         │
│  │   Encryption: Template (admin-only Owner rights)                │
│  │   Watermark: "RESTRICTED"                                       │
│  │   Scope: File, Email                                            │
│  │                                                                  │
│  └── Restricted - Third Parties                                    │
│      Encryption: User-Defined + Do Not Forward                     │
│      Watermark: "RESTRICTED"                                       │
│      Scope: File, Email                                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Label Configuration Details

### 4.1 Public

| Setting | Value |
|---------|-------|
| **Scope** | File, Email, Site, UnifiedGroup |
| **Encryption** | None |
| **Content Markings** | None |
| **Tooltip** | No protection required. Safe to share externally. |
| **Use Case** | Marketing materials, public-facing documents, press releases |

### 4.2 General (Default Label)

| Setting | Value |
|---------|-------|
| **Scope** | File, Email, Site, UnifiedGroup |
| **Encryption** | None |
| **Container Protection** | Privacy: Unspecified, Guests: Allowed, Full Access: Yes |
| **Header** | "General" (10pt, red, centred) |
| **Footer** | "General - Business Use" (8pt, red, centred) |
| **Tooltip** | Default label for everyday business content. |
| **Use Case** | Internal emails, day-to-day documents, meeting notes |

### 4.3 Confidential (Parent — Container Only)

| Setting | Value |
|---------|-------|
| **Scope** | Site, UnifiedGroup (Groups & Sites) |
| **Privacy** | Private |
| **Guest Access** | Allowed |
| **Guest Email** | Allowed |
| **Encryption/Markings** | None — parent is a container label |
| **Tooltip** | Select a sub-label. Encryption and markings applied based on audience. |

#### 4.3.1 Confidential - Internal

| Setting | Value |
|---------|-------|
| **Scope** | File, Email, Site, UnifiedGroup |
| **Container Protection** | Privacy: Private, Guests: Allowed, Full Access: Yes |
| **Encryption** | Template — org-wide |
| **Rights** | `<TenantDomain>`: VIEW, VIEWRIGHTSDATA, DOCEDIT, EDIT, PRINT, EXTRACT, REPLY, REPLYALL, FORWARD, OBJMODEL |
| **Header** | "Confidential - Internal Only" (10pt, red, centred) |
| **Footer** | "Confidential - Internal Only" (8pt, red, centred) |
| **Tooltip** | Encrypted for internal employees only. |
| **Use Case** | Internal project plans, HR policy drafts, financial summaries |

#### 4.3.2 Confidential - Third Parties

| Setting | Value |
|---------|-------|
| **Scope** | File, Email, Site, UnifiedGroup |
| **Container Protection** | Privacy: Private, Guests: Allowed, Full Access: Yes |
| **Encryption** | User-Defined — user selects recipients |
| **Protection** | Do Not Forward enforced |
| **Header** | "Confidential - Authorised Recipients" (10pt, red, centred) |
| **Footer** | "Confidential - Authorised Recipients" (8pt, red, centred) |
| **Tooltip** | User selects authorised external recipients at time of sharing. |
| **Use Case** | Contracts sent to vendors, partner-shared project docs, NDA materials |

#### 4.3.3 Confidential - Reporting

| Setting | Value |
|---------|-------|
| **Scope** | File, Email, Site, UnifiedGroup |
| **Container Protection** | Privacy: Private, Guests: Allowed, Full Access: Yes |
| **Encryption** | Template — org-wide |
| **Rights** | Same as Confidential - Internal |
| **Header** | "Confidential - Reporting" (10pt, red, centred) |
| **Footer** | "Confidential - Reporting" (8pt, red, centred) |
| **Tooltip** | Confidential reports and analytics. Encrypted for internal use. |
| **Use Case** | Financial reports, board packs, analytics dashboards, audit reports |

> **Design rationale — why this label exists separately from Confidential - Internal:** The encryption rights are intentionally identical to Confidential - Internal (org-wide Co-Author). The differentiation is operational rather than technical: having a distinct "Reporting" label allows Activity Explorer and audit logs to track classification of financial and analytical content separately from general internal content. This matters for compliance reporting (e.g., demonstrating that board packs are consistently classified) and for future scoping of auto-labeling rules that target financial SITs (credit card numbers, bank account numbers) specifically to this label. If the organisation later needs to restrict reporting content to a smaller audience (e.g., Finance + Board only), the encryption rights on this label can be narrowed independently without affecting Confidential - Internal documents already in circulation.

### 4.4 Restricted (Parent — Container Only)

| Setting | Value |
|---------|-------|
| **Scope** | Site, UnifiedGroup (Groups & Sites) |
| **Privacy** | Private |
| **Guest Access** | Blocked |
| **Guest Email** | Blocked |
| **Encryption/Markings** | None — parent is a container label |
| **Tooltip** | Select a sub-label. Highest protection — full encryption and markings. |

#### 4.4.1 Restricted - Internal

| Setting | Value |
|---------|-------|
| **Scope** | File, Email, Site, UnifiedGroup |
| **Container Protection** | Privacy: Private, Guests: Blocked, Full Access: No |
| **Encryption** | Template — named principals only |
| **Rights** | `<AdminEmail or Security Group>`: OWNER (full control) |
| **Header** | "RESTRICTED - Internal Only" (10pt, red, centred) |
| **Footer** | "RESTRICTED - Internal Only" (8pt, red, centred) |
| **Watermark** | "RESTRICTED" (48pt, diagonal) |
| **Tooltip** | Encrypted for specific internal recipients only. |
| **Use Case** | Executive compensation, M&A documents, legal hold materials, security incident reports |

> **⚠️ Operational risk — use a security group, not a single admin account:** The `SensitivityLabel.ps1` script defaults `$adminRights` to the signed-in admin's UPN (e.g., `admin@domain.com:OWNER`). This creates a **single point of failure**: if that account is deleted, disabled, or its UPN changes, every document encrypted with this label becomes inaccessible — including M&A files, legal hold materials, and executive compensation records. Before production deployment, replace the individual admin UPN with a **role-based mail-enabled security group** (e.g., `SG-Restricted-Owners@domain.com`) containing the appropriate privileged users. Set a formal access review for group membership. The encryption rights string to use in the script would be:
>
> ```powershell
> $adminRights = "SG-Restricted-Owners@yourdomain.com:OWNER"
> ```
>
> The security group membership should be reviewed quarterly and ownership assigned to a named role (e.g., CISO or Legal Counsel), not an individual.

#### 4.4.2 Restricted - Third Parties

| Setting | Value |
|---------|-------|
| **Scope** | File, Email, Site, UnifiedGroup |
| **Container Protection** | Privacy: Private, Guests: Blocked, Full Access: No |
| **Encryption** | User-Defined — user selects recipients |
| **Protection** | Do Not Forward enforced |
| **Header** | "RESTRICTED - Authorised Recipients" (10pt, red, centred) |
| **Footer** | "RESTRICTED - Authorised Recipients" (8pt, red, centred) |
| **Watermark** | "RESTRICTED" (48pt, diagonal) |
| **Tooltip** | User selects authorised recipients. Do Not Forward enforced. |
| **Use Case** | Legal matter sharing with external counsel, regulator submissions |

---

## 5. Label Policy Architecture & Best Practices

### 5.1 Single Policy vs. Multiple Policies

Microsoft Purview supports two approaches to publishing labels. The right choice depends on your governance requirements.

#### Option A: Single Unified Policy (Simple Alternative)

```
┌──────────────────────────────────────────────┐
│  IAC - All Users Label Policy                │
│  ─────────────────────────────────────       │
│  Labels:    All 9 labels                     │
│  Scope:     ExchangeLocation = All           │
│  Default:   General                          │
│  Mandatory: Yes                              │
│  Downgrade: Justification required           │
└──────────────────────────────────────────────┘
```

**Pros:**
- Simple to manage — one policy covers everyone
- Consistent label experience across the organisation
- Easier to audit and troubleshoot
- Recommended for SMB tenants (< 500 users)

**Cons:**
- Cannot exclude specific groups from individual labels
- All-or-nothing approach — if a user is in scope, they see all labels

**Best for:** Small-to-medium organisations where all users need access to the full taxonomy.

---

#### Option B: Tiered Policy Architecture (Current IAC Deployment)

If you need to **exclude certain groups from specific label classifications** (e.g., contractors shouldn't see Restricted labels, or the finance team needs a special "Confidential - Financial" label), use multiple policies:

```
┌──────────────────────────────────────────────┐
│  Policy 1: IAC - Base Label Policy           │
│  ─────────────────────────────────────       │
│  Labels:    Public, General                  │
│  Scope:     All Users                        │
│  Default:   General                          │
│  Mandatory: Yes                              │
│  Downgrade: Justification required           │
│  Power BI:  Mandatory                        │
│                                              │
│  → Everyone gets Public + General            │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  Policy 2: IAC - Confidential Label Policy   │
│  ─────────────────────────────────────       │
│  Labels:    Confidential children only       │
│             (parent auto-included)           │
│  Scope:     All Users                        │
│             (exclude via -ExcludeFrom...)    │
│  Default:   None (inherits from Policy 1)    │
│  Mandatory: No (inherits from Policy 1)      │
│                                              │
│  → Internal staff see Confidential labels    │
│  → Can exclude contractors later             │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  Policy 3: IAC - Restricted Label Policy     │
│  ─────────────────────────────────────       │
│  Labels:    Restricted children only         │
│             (parent auto-included)           │
│  Scope:     All Users                        │
│             (exclude via -ExcludeFrom...)    │
│  Default:   None                             │
│  Mandatory: No (inherits from Policy 1)      │
│                                              │
│  → All users see Restricted by default       │
│  → Can restrict to named groups later        │
└──────────────────────────────────────────────┘
```

**Pros:**
- Granular control over who sees which labels
- Can exclude contractors, guests, or external users from sensitive labels
- Can add department-specific labels (e.g., "Confidential - Financial") to specific groups only
- Can set different default labels per group
- Can enforce different mandatory labelling rules per audience

**Cons:**
- More policies to manage
- Policy conflicts resolved by priority (higher priority wins)
- Must test policy layering carefully
- More complex troubleshooting when labels don't appear

**Best for:** Organisations with contractors, multiple departments, or regulatory requirements that restrict label visibility by role.

---

### 5.2 Policy Conflict Resolution Rules

When a user is in scope of **multiple label policies**, Microsoft Purview resolves conflicts as follows:

| Setting | Resolution Rule |
|---------|----------------|
| **Label visibility** | Labels from ALL matching policies are **merged** — user sees the union of all labels |
| **Default label** | The policy with the **highest priority** (lowest number) wins |
| **Mandatory labelling** | If **any** matching policy sets mandatory=true, labelling is mandatory |
| **Downgrade justification** | If **any** matching policy requires it, justification is required |
| **Policy priority** | Lower number = higher priority. Set via `Set-LabelPolicy -Identity "name" -Priority 0` |

> **Key insight:** You cannot use policies to **hide** a label from a user who receives it from another policy. If Policy 1 publishes "Confidential - Internal" to All Users and Policy 2 publishes it to a smaller group, **all users still see it**. To restrict label visibility, you must **not publish that label in the broad policy** — only include it in the targeted policy.

### 5.3 Recommended Approach

| Tenant Size | Recommendation |
|-------------|----------------|
| **< 100 users, single entity** | Option A — Single unified policy |
| **100–500 users, some contractors** | Option A with plan to move to Option B when needed |
| **500+ users, contractors, departments** | Option B — Tiered policies from day one |
| **Regulated industry (finance, healthcare, legal)** | Option B — With department-specific restricted labels |

### 5.4 New-LabelPolicy Gotchas (Lessons Learned)

These were discovered during deployment and are baked into `Publish-SensitivityLabelPolicies.ps1`:

| Gotcha | Detail |
|--------|--------|
| **Parent labels can't be explicitly published** | `New-LabelPolicy -Labels "Confidential"` fails with `"Label group(s) can not be published"`. Parent labels are auto-included as navigation headers when any of their children are published. Only list child labels. |
| **Use internal Name, not DisplayName** | `New-LabelPolicy -Labels "Confidential - Internal"` fails. The `-Labels` parameter requires the internal `Name` property (e.g. `Confidential-Internal`). Check with `Get-Label \| FT Name, DisplayName`. |
| **Advanced settings must be applied separately** | `New-LabelPolicy -Settings` doesn't accept a hashtable for settings like `mandatory`, `defaultlabelid`, etc. Create the policy first, then apply via `Set-LabelPolicy -Identity "name" -AdvancedSettings @{ mandatory="true" }`. |
| **Policy priority is auto-assigned** | Policies get `Priority` values in creation order (0, 1, 2). Create the Base policy first to ensure it gets Priority 0 (highest). |

---

## 6. Publishing Walkthrough

### Step-by-Step: Tiered Policy Deployment

#### Step 1: Run Prerequisites (One-Time)

```powershell
cd ~/Desktop/BaslineSetup/Purview
pwsh ./Enable-SensitivityLabelsPrerequisites.ps1 -TenantId "<your-tenant-id>"
```

Wait **24 hours** for propagation.

#### Step 2: Dry Run Labels

```powershell
./SensitivityLabel.ps1 -TenantDomain "acme2m365.onmicrosoft.com" -DryRun
```

Review the output. Confirm:
- All 9 labels detected or would be created
- Admin email is correct (defaults to `admin@<TenantDomain>`)

#### Step 3: Create Labels

```powershell
./SensitivityLabel.ps1 -TenantDomain "acme2m365.onmicrosoft.com"
```

After running, verify in the **Purview portal**:
1. Go to [purview.microsoft.com](https://purview.microsoft.com) → **Information Protection** → **Labels**
2. Confirm the hierarchy: Public, General, Confidential (3 children), Restricted (2 children)
3. Click each child → verify encryption type and content markings
4. Confirm parent labels show Groups & Sites protection

#### Step 4: Dry Run Policies

```powershell
./Publish-SensitivityLabelPolicies.ps1 -TenantDomain "acme2m365.onmicrosoft.com" -DryRun
```

Confirm:
- All 9 labels resolve (`[OK]`)
- 3 policies would be created with correct label assignments
- No exclusions unless you passed `-ExcludeFromConfidential` or `-ExcludeFromRestricted`

#### Step 5: Publish Policies

```powershell
./Publish-SensitivityLabelPolicies.ps1 -TenantDomain "acme2m365.onmicrosoft.com"
```

The script creates 3 tiered policies:

| Policy | Labels | Priority | Settings |
|--------|--------|----------|----------|
| IAC - Base Label Policy | Public, General | 0 | Default=General, Mandatory=Yes, Downgrade=Yes, PowerBI=Yes |
| IAC - Confidential Label Policy | Confidential children (parent auto-included) | 1 | Scope: All Users |
| IAC - Restricted Label Policy | Restricted children (parent auto-included) | 2 | Scope: All Users |

#### Step 5a: Publish with Exclusions (Optional)

```powershell
./Publish-SensitivityLabelPolicies.ps1 -TenantDomain "acme2m365.onmicrosoft.com" `
    -ExcludeFromConfidential @("SG-Contractors@acme2m365.onmicrosoft.com") `
    -ExcludeFromRestricted @("SG-Contractors@acme2m365.onmicrosoft.com")
```

#### Step 6: Wait for Propagation

Label policies propagate over **up to 24 hours** across:

| App | Typical Propagation |
|-----|-------------------|
| Outlook Web | 1–4 hours |
| Outlook Desktop | 4–12 hours |
| Word/Excel/PowerPoint | 4–12 hours |
| Teams | 12–24 hours |
| SharePoint Online | 12–24 hours |
| Power BI | 12–24 hours |

#### Step 7: Verify End-User Experience

After propagation:

1. **Outlook** — Compose new email → Sensitivity button should show all labels → General should be pre-selected
2. **Word** — New document → Sensitivity bar should show labels → Try saving without a label (should block)
3. **Downgrade test** — Apply "Confidential - Internal" → change to "General" → must prompt for justification
4. **Encryption test** — Apply "Restricted - Third Parties" → should prompt for recipients → recipients receive Do Not Forward protection
5. **Container test** — Create a new Team → should prompt for a sensitivity label → Confidential/Restricted parents should appear

---

## 7. Deployment Runbook

### 7.1 Script Parameters

```
SensitivityLabel.ps1  (Label Creation Only)

  -TenantDomain  [Required]  Your *.onmicrosoft.com domain
  -AdminEmail    [Optional]  Admin email for Restricted-Internal encryption
                             Defaults to admin@<TenantDomain>
  -DryRun        [Optional]  Show what would happen without making changes
```

```
Publish-SensitivityLabelPolicies.ps1  (Policy Publishing)

  -TenantDomain             [Required]  Your *.onmicrosoft.com domain
  -ExcludeFromConfidential  [Optional]  Group emails to exclude from Confidential policy
  -ExcludeFromRestricted    [Optional]  Group emails to exclude from Restricted policy
  -DryRun                   [Optional]  Show what would happen without making changes
```

### 7.2 What the Scripts Do (Idempotent)

Both scripts are **safe to re-run**.

**SensitivityLabel.ps1** — For each label:
- If the label **exists** → skips it (`[EXISTS]`)
- If the label **doesn't exist** → creates it (`[CREATING]`)

**Publish-SensitivityLabelPolicies.ps1** — For each policy:
- If the policy **exists** → skips it (`[EXISTS]`)
- If the policy **doesn't exist** → creates it (`[CREATING]`)
- Advanced settings (mandatory, default label, etc.) are applied via `Set-LabelPolicy -AdvancedSettings` after creation

### 7.3 What the Scripts Do NOT Do

- **SensitivityLabel.ps1 does not publish** — use `Publish-SensitivityLabelPolicies.ps1` separately
- **Does not modify existing labels** — if you need to change encryption or markings on an existing label, use `Set-Label` manually
- **Does not delete labels** — label deletion must be done manually via `Remove-Label`
- **Does not handle the duplicate Restricted label** — that was a one-time cleanup (see Section 9.2)
- **Does not run prerequisites** — run `Enable-SensitivityLabelsPrerequisites.ps1` first

---

## 8. Verification & Troubleshooting

### 8.1 Verification Commands

```powershell
# All labels with priority and encryption status
Get-Label | Sort-Object Priority | Format-Table DisplayName, Priority, EncryptionEnabled, ContentType

# All policies with labels and settings
Get-LabelPolicy | Sort-Object Name | Format-Table Name, Labels, ExchangeLocation, ExchangeLocationException -AutoSize -Wrap

# Base policy advanced settings (default label, mandatory, etc.)
Get-LabelPolicy -Identity "IAC - Base Label Policy" | Format-List Settings

# Check a specific label's encryption rights
Get-Label -Identity "Confidential - Internal" | Format-List EncryptionRightsDefinitions

# Check parent label's container protection
$label = Get-Label -Identity "Confidential"
$label.LabelActions  # Should show protectgroup + protectsite JSON
```

### 8.2 Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Labels don't appear in Office apps | Policy not yet propagated | Wait 24 hours. Check policy scope with `Get-LabelPolicy` |
| "Groups & Sites" checkbox greyed out in Purview portal | Prerequisites not run | Run `Enable-SensitivityLabelsPrerequisites.ps1` and wait 24 hours |
| User can't see Restricted labels | Not in scope of the Restricted policy | Check `Get-LabelPolicy` → verify user is in `ExchangeLocation` |
| Mandatory labelling not enforced | Policy settings not propagated | Verify `Settings` in `Get-LabelPolicy` contains `mandatory=true` |
| Encrypted email can't be opened by recipient | Recipient not in encryption rights | For Template-encrypted labels, only org domain has rights. Use "Third Parties" labels for external sharing |
| ContentType shows "None" on parent labels | Normal behaviour for parent/group labels | Verify `LabelActions` contains `protectgroup`/`protectsite` JSON instead |

### 8.3 Force Policy Re-Sync

If labels aren't appearing after 24 hours:

```powershell
# Office apps: force policy download
# User can manually trigger from File → Account → Update Labels

# PowerShell: re-publish a policy (triggers fresh sync)
Set-LabelPolicy -Identity "IAC - Base Label Policy" -AdvancedSettings @{}
Set-LabelPolicy -Identity "IAC - Confidential Label Policy" -AdvancedSettings @{}
Set-LabelPolicy -Identity "IAC - Restricted Label Policy" -AdvancedSettings @{}

# SharePoint: force site-level sync
Set-SPOSite -Identity "https://acme2m365.sharepoint.com/sites/yoursite" -SensitivityLabel ""
```

---

## 9. DLP Integration

Sensitivity labels define classification and apply encryption, but they do not by themselves enforce data movement controls. DLP policies are the complementary layer that monitors and restricts how labelled content is shared, moved, or transmitted. Labels and DLP should be designed together — a label that carries no corresponding DLP action provides classification visibility but no enforcement at the data-flow level.

### 9.1 Label-as-Condition DLP Policy Design

Microsoft Purview DLP supports sensitivity labels as policy conditions via **"Content is labelled"**. This is distinct from "content contains sensitive info type" — the label condition checks the label metadata applied to the item, not the textual content of the document.

> **Important limitation (from Welka's World):** DLP "content contains: sensitive info type" does **not** detect metadata tags. It detects the document body, headers/footers, and Office document properties only. If you intend DLP to act on labelled content, always use the **"Content is labelled"** condition, not a SIT condition, to avoid false negatives on encrypted documents where the body is not scannable.

**Recommended baseline DLP policies to accompany this label taxonomy:**

| Policy | Condition | Action | Rationale |
|--------|-----------|--------|-----------|
| Restricted - Block External Sharing | Label = Restricted - Internal **or** Restricted - Third Parties | Block sharing with external users; notify admin | Restricted content must never leave the org uncontrolled |
| Restricted - Block Upload to Unmanaged Apps | Label = Restricted-* | Endpoint DLP: block upload to non-corporate cloud apps | Prevents exfiltration via browser |
| Confidential - Warn on External Email | Label = Confidential - Internal | Warn user; require business justification override | Confidential - Internal is org-wide encrypted; external email is likely an error |
| Confidential - Block External Third Party without Recipient | Label = Confidential - Third Parties **and** no encryption recipients set | Block send | Catches misconfigured label application |
| General - Monitor External Sharing | Label = General | Audit only; no block | Baseline visibility into what is classified as General and shared externally |

### 9.2 DLP Policy Deployment Approach

Follow the same progressive enforcement model used for labels — deploy new DLP policies in **test mode** first, review Activity Explorer and DLP reports for 1–2 weeks, then move to **warn mode**, then **block mode**. Never deploy block-mode DLP to all users on day one.

```powershell
# Check DLP policy status
Get-DlpCompliancePolicy | Format-Table Name, Mode, Workload

# Move a policy from TestWithNotifications to Enable (enforce)
Set-DlpCompliancePolicy -Identity "Restricted - Block External Sharing" -Mode Enable
```

### 9.3 Endpoint DLP Considerations

For Restricted labels specifically, consider enabling Endpoint DLP to enforce controls at the device level, including:

- Blocking copy to USB removable media
- Blocking upload to personal cloud storage (OneDrive personal, Dropbox, Google Drive)
- Blocking print to non-corporate printers
- Blocking clipboard copy to unmanaged apps

Endpoint DLP requires Microsoft Purview compliance licensing (E5 or equivalent) and devices onboarded to Microsoft Defender for Endpoint.

---

## 10. Auto-Labeling

Manual labelling relies on users making correct classification decisions. Auto-labeling applies labels automatically based on content inspection, reducing human error and extending coverage to existing unclassified content.

Microsoft Purview supports two distinct auto-labeling mechanisms:

| Type | Where It Runs | How It Works | Scope |
|------|--------------|-------------|-------|
| **Client-side auto-labeling** | In Office apps (Word, Excel, Outlook) | Recommends or applies a label based on SIT matches in the document as the user works | New and edited documents |
| **Service-side auto-labeling** | In SharePoint Online and Exchange | Scans existing content at rest; applies labels without user interaction | Existing libraries and mailboxes |

### 10.1 Recommended Auto-Labeling Targets for This Taxonomy

| Label | Auto-Labeling Trigger | SIT Examples |
|-------|----------------------|-------------|
| Confidential - Reporting | Financial SITs detected in document body | Credit card numbers, bank account numbers, ABA routing numbers |
| Confidential - Internal | PII SITs (names + govt IDs in combination) | UK National Insurance Number, passport numbers |
| Restricted - Internal | High-confidence sensitive data combinations | Medical records, legal privilege indicators |

> **Deployment warning:** Always run service-side auto-labeling policies in **simulation mode** first. Use Activity Explorer to review what would be labelled before enabling enforcement. Overly broad SIT rules will label large volumes of incorrectly classified content, and re-labelling at scale is disruptive.

### 10.2 Setting Up a Service-Side Auto-Labeling Policy

Auto-labeling policies are created in the Purview portal under **Information Protection → Auto-labeling**, not as part of label policy publishing. They are a separate configuration step after labels and manual policies are deployed and stable.

---

## 11. Adaptive Protection

Adaptive Protection integrates Microsoft Purview Insider Risk Management (IRM) with DLP to dynamically adjust enforcement strictness based on a user's current risk level. Rather than applying the same DLP rules to everyone equally, Adaptive Protection can:

- Apply **tighter DLP controls** to users flagged as elevated or high risk by IRM (e.g., users who have recently triggered data exfiltration alerts, users in the offboarding risk indicator window)
- Apply **standard or relaxed controls** to low-risk users to avoid unnecessary friction

### 11.1 How It Interacts with This Label Taxonomy

For organisations deploying Restricted labels for high-sensitivity scenarios (M&A, legal hold, executive compensation), Adaptive Protection adds a meaningful additional layer:

- A high-risk user attempting to access or share Restricted-labelled content can be automatically subjected to more aggressive DLP blocks without a policy change
- Low-risk users retain normal enforcement, reducing helpdesk burden

### 11.2 Prerequisites

- Microsoft Purview Insider Risk Management must be configured with at least one active policy
- Adaptive Protection requires Microsoft 365 E5 Compliance or equivalent add-on licensing
- Adaptive Protection is enabled in Purview portal → **Insider Risk Management** → **Adaptive Protection**

> **Maturity path:** Adaptive Protection is typically a Phase 2 or Phase 3 addition after the label taxonomy and baseline DLP policies are stable and generating reliable signal. Do not attempt to configure Adaptive Protection before DLP enforcement is established.

---

## 12. Day-2 Operations

### 12.1 Label Governance Framework

Labels require ongoing ownership to prevent the common failure pattern of taxonomy decay — unused labels accumulating, users defaulting to the wrong label, and no one accountable for reviewing changes.

**Ownership model:**

| Role | Responsibility |
|------|----------------|
| **Label Owner** (e.g., Information Protection Admin) | Approves new label requests, manages taxonomy changes, reviews quarterly |
| **DLP Policy Owner** (e.g., Compliance team) | Maintains DLP policy alignment with label changes, reviews DLP reports monthly |
| **Business Stakeholders** | Request new labels via a defined process; receive Activity Explorer reports on label usage for their data |

**Quarterly label review checklist:**

- Review Activity Explorer: are all 9 labels being used? Are any labels with zero usage candidates for removal?
- Review audit log for label downgrade events: are justifications reasonable?
- Review membership of `SG-Restricted-Owners` (or equivalent security group used in Restricted - Internal rights)
- Review auto-labeling simulation reports if applicable
- Confirm co-authoring setting is still enabled after any tenant configuration changes
- Review any new Microsoft Purview feature releases that affect label behaviour

**Label change request process:**

New sub-labels or changes to existing encryption rights should go through a lightweight approval process involving the Label Owner and a business stakeholder. Changes to encryption rights on existing labels affect documents already in circulation — users who received encrypted files under the old rights may lose access. Test any encryption rights changes in a non-production tenant or with a small pilot group first.

---

### 12.2 Adding a New Label

```powershell
# Example: Add "Confidential - Financial" for the finance team
New-Label -Name "Confidential-Financial" `
    -DisplayName "Confidential - Financial" `
    -ParentId (Get-Label -Identity "Confidential").ImmutableId `
    -ContentType @("File","Email") `
    -Tooltip "Financial data - encrypted for finance team" `
    -EncryptionEnabled $true `
    -EncryptionProtectionType "Template" `
    -EncryptionRightsDefinitions "finance-team@acme2m365.onmicrosoft.com:VIEW,EDIT,PRINT" `
    -ApplyContentMarkingHeaderEnabled $true `
    -ApplyContentMarkingHeaderText "Confidential - Financial"

# Then add it to the Confidential policy
Set-LabelPolicy -Identity "IAC - Confidential Label Policy" -AddLabels "Confidential-Financial"
```

### 12.3 Removing a Duplicate or Unwanted Label

```powershell
# Find the label's ImmutableId
Get-Label | Where-Object { $_.DisplayName -eq "Label Name" } | Format-List ImmutableId, ParentId

# Remove it (label enters "pending deletion" state in Purview backend)
Remove-Label -Identity "<ImmutableId>" -Confirm:$false
```

> **Note:** Removed labels enter a "pending deletion" state and may still appear in `Get-Label` output for several hours. This is normal Purview behaviour.

### 12.4 Changing Encryption Rights on an Existing Label

```powershell
# Example: Give the security team access to Restricted - Internal
Set-Label -Identity "Restricted - Internal" `
    -EncryptionRightsDefinitions "securityteam@acme2m365.onmicrosoft.com:OWNER"
```

### 12.5 Modifying Policy Scope (Exclusions)

```powershell
# Exclude contractors from Confidential labels
Set-LabelPolicy -Identity "IAC - Confidential Label Policy" `
    -AddExchangeLocationException "SG-Contractors@acme2m365.onmicrosoft.com"

# Exclude contractors from Restricted labels
Set-LabelPolicy -Identity "IAC - Restricted Label Policy" `
    -AddExchangeLocationException "SG-Contractors@acme2m365.onmicrosoft.com"

# Remove an exclusion later
Set-LabelPolicy -Identity "IAC - Confidential Label Policy" `
    -RemoveExchangeLocationException "SG-Contractors@acme2m365.onmicrosoft.com"

# Verify current exclusions
Get-LabelPolicy | Format-Table Name, ExchangeLocationException -AutoSize
```

### 12.6 Auditing Label Usage

```powershell
# Purview Audit Log — label application events
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) `
    -Operations "SensitivityLabelApplied","SensitivityLabelUpdated","SensitivityLabelRemoved" `
    -ResultSize 100 |
    Select-Object CreationDate, UserIds, Operations, AuditData
```

### 12.7 Emergency: Remove All Policies

If you need to roll back and remove mandatory labelling urgently:

```powershell
# Remove all 3 tiered policies (labels remain but are unpublished)
Remove-LabelPolicy -Identity "IAC - Base Label Policy" -Confirm:$false
Remove-LabelPolicy -Identity "IAC - Confidential Label Policy" -Confirm:$false
Remove-LabelPolicy -Identity "IAC - Restricted Label Policy" -Confirm:$false

# Labels still exist — they're just not visible to users
# Re-publish when ready by re-running Publish-SensitivityLabelPolicies.ps1
```

---

## 13. Purview Information Protection Super User

> **References:**
> - [Microsoft Learn — Configure super users for Azure Information Protection](https://learn.microsoft.com/en-us/azure/information-protection/configure-super-users)
> - [Microsoft Learn — AIPService PowerShell module](https://learn.microsoft.com/en-us/powershell/module/aipservice/)
> - [Microsoft Learn — Enable-AipServiceSuperUserFeature](https://learn.microsoft.com/en-us/powershell/module/aipservice/enable-aipservicesuperuserfeature)
> - [Microsoft Learn — Add-AipServiceSuperUserGroup](https://learn.microsoft.com/en-us/powershell/module/aipservice/add-aipservicesuperusergroup)

### 13.1 What Is It?

The **Purview Information Protection Super User** is a tenant-level capability that grants designated users or a designated security group the ability to **decrypt any RMS/MIP-protected content in the tenant** — regardless of who originally encrypted it, what rights template was used, or whether the original owner's account still exists.

**Naming history — same feature, same cmdlets, three names:**

| Era | Branding | Notes |
|-----|----------|-------|
| Pre-2018 | **RMS Super User** | Azure Rights Management Service era |
| 2018–2023 | **AIP Super User** | Azure Information Protection rebranding |
| 2023–present | **Purview Information Protection Super User** | Microsoft Purview rebranding |

The PowerShell cmdlets (`Enable-AipServiceSuperUserFeature`, `Add-AipServiceSuperUserGroup`) retain the `AipService` prefix regardless of current branding. The module is `AIPService`, not `Purview` — this is consistent with how Microsoft has preserved cmdlet names across rebrands to avoid breaking existing scripts.

**What it can do:**

- Open and read any document or email protected with any sensitivity label encryption in the tenant
- Re-encrypt or re-protect content (decrypt → apply new label → re-encrypt)
- Recover content when the original owner's account has been deleted or disabled
- Unlock content encrypted under labels whose rights definitions no longer include any active principals
- Act as a forensic or compliance tool to review encrypted content for legal, HR, or regulatory purposes

**What it cannot do:**

- Bypass Microsoft 365 RBAC or SharePoint/Teams permissions — Super User is an AIP/RMS-layer capability only
- Access unencrypted content the user doesn't otherwise have SharePoint or Exchange permissions to read
- Operate without audit logging — all Super User decryption events are logged

---

### 13.2 Why Do You Need It as a Purview Administrator?

Without a configured Super User group, the following scenarios create **permanent data loss or business-critical blockages**:

| Scenario | Risk Without Super User |
|----------|------------------------|
| **Employee leaves or is terminated** | Files encrypted under `Restricted - Internal` with that user's personal key become permanently inaccessible if no Super User can recover them |
| **`Restricted - Internal` admin key changes** | If `$adminRights` was set to a single UPN and that account is deleted, all Restricted - Internal documents are locked forever |
| **Legal hold or eDiscovery** | Legal team needs to read encrypted Restricted documents for a regulatory investigation but lacks decryption rights |
| **Label migration** | Re-encrypting a large volume of documents during a label taxonomy change requires Super User rights to decrypt first |
| **Broken encryption template** | An encryption template deleted or corrupted in Entra ID (via the AIP/RMS service) leaves documents encrypted against a non-existent template — only a Super User can recover them |
| **HR investigation** | HR needs to read encrypted files on a device being reviewed — the file owner may not be cooperative |

> **For this taxonomy specifically:** The `Restricted - Internal` label encrypts content using `$adminRights = "<AdminEmail>:OWNER"`. If that admin account is ever deleted or its UPN changes, every document ever encrypted under Restricted - Internal becomes permanently inaccessible — unless a Super User group is configured. This is the single most important operational risk in this entire label deployment.

---

### 13.3 How to Configure

#### Prerequisites

- **Role required:** Global Administrator or Azure Information Protection Administrator
- **Module required:** `AIPService` PowerShell module
- **Security group:** A mail-enabled security group in Entra ID (e.g., `SG-AIP-SuperUsers@domain.com`) — membership should be tightly controlled and reviewed quarterly

```powershell
# Install the AIPService module if not already installed
Install-Module -Name AIPService -Scope CurrentUser -Force
Import-Module AIPService
```

#### Step 1: Connect to the AIP Service

```powershell
Connect-AipService
# Browser sign-in will prompt — use Global Admin or AIP Admin credentials
```

#### Step 2: Enable the Super User Feature

The feature is **disabled by default** in all tenants. It must be explicitly enabled before any group can be assigned.

```powershell
Enable-AipServiceSuperUserFeature

# Verify it's enabled
Get-AipServiceSuperUserFeature
# Expected output: Enabled
```

> ⚠️ **Enable only when needed.** Microsoft's guidance is to enable the feature when you need it and disable it when the task is complete. Leaving it permanently enabled with a broad group increases the blast radius if a Super User account is compromised.

#### Step 3: Assign the Super User Group

Microsoft recommends using a **group** rather than individual users, so that membership can be audited and changed without re-running the cmdlet.

```powershell
# Assign a mail-enabled security group
Add-AipServiceSuperUserGroup -GroupEmailAddress "SG-AIP-SuperUsers@M365x93722695.onmicrosoft.com"

# Verify the assignment
Get-AipServiceSuperUserGroup
# Returns the group email address

# To check if any individual Super Users are also set (legacy approach)
Get-AipServiceSuperUser
```

> ℹ️ **Group vs. individual:** `Add-AipServiceSuperUserGroup` assigns a group. `Add-AipServiceSuperUser` assigns an individual UPN. Microsoft recommends the group approach — it separates the capability grant from the access grant, and group membership changes are audited in Entra ID.

#### Step 4: Disable When Not in Use (Recommended)

```powershell
# Disable after use
Disable-AipServiceSuperUserFeature

# The group assignment is retained — re-enable quickly when needed without re-assigning
Enable-AipServiceSuperUserFeature
```

#### Full Setup Script

```powershell
# Super-User-Setup.ps1
# One-time setup for AIP/Purview Super User group

param(
    [Parameter(Mandatory)]
    [string]$SuperUserGroupEmail  # e.g. "SG-AIP-SuperUsers@M365x93722695.onmicrosoft.com"
)

Import-Module AIPService -ErrorAction Stop
Connect-AipService -ErrorAction Stop

# Enable feature
Enable-AipServiceSuperUserFeature
Write-Host "Feature state: $(Get-AipServiceSuperUserFeature)" -ForegroundColor Green

# Assign group
Add-AipServiceSuperUserGroup -GroupEmailAddress $SuperUserGroupEmail
Write-Host "Super User Group: $(Get-AipServiceSuperUserGroup)" -ForegroundColor Green

# Disable until needed
Disable-AipServiceSuperUserFeature
Write-Host "Feature disabled. Re-enable with: Enable-AipServiceSuperUserFeature" -ForegroundColor Yellow
```

---

### 13.4 How to Use It (Operational Runbook)

#### Scenario A: Recover a Restricted - Internal Document

A Restricted - Internal document was encrypted against `admin@M365x93722695.onmicrosoft.com:OWNER` and that account has been deleted. A Super User member needs to recover it.

```powershell
# 1. Enable the feature
Connect-AipService
Enable-AipServiceSuperUserFeature

# 2. The Super User logs into the machine as themselves (their own account must be a
#    member of the SG-AIP-SuperUsers group)

# 3. Open the document in an Office app or use the AIP client to decrypt:
#    Right-click the file → Sensitivity → Remove Sensitivity Label
#    OR use the AIP Unified Labeling Client (if installed):
#    Right-click → Classify and protect → Remove protection

# 4. Re-protect with appropriate label or new encryption rights
#    (e.g., apply "Restricted - Internal" with updated $adminRights pointing to
#    the new admin or security group)

# 5. Disable the feature when done
Disable-AipServiceSuperUserFeature
```

#### Scenario B: Bulk Decrypt for eDiscovery

The compliance team needs to scan Restricted documents for a regulatory audit. Using the AIP Unified Labeling Scanner or Content Explorer with Super User rights:

```powershell
# Enable Super User
Connect-AipService
Enable-AipServiceSuperUserFeature

# Run your eDiscovery or compliance scan (Content Search, Compliance Manager,
# or the AIP Scanner in discovery mode)
# Super User rights allow the scanner to open encrypted files for inspection

# When complete
Disable-AipServiceSuperUserFeature
```

#### Scenario C: Label Migration (Re-Encrypt at Scale)

Changing encryption rights on `Restricted - Internal` for all existing documents:

```powershell
# 1. Enable Super User
Enable-AipServiceSuperUserFeature

# 2. Use Get-AipFileStatus + Set-AipFileLabel to bulk re-label
#    (requires AIP Unified Labeling Client installed)
Get-ChildItem -Path "\\fileserver\restricted" -Recurse -File |
    ForEach-Object {
        Set-AipFileLabel -Path $_.FullName -LabelId "<new-label-guid>" -JustificationMessage "Label migration"
    }

# 3. Disable when migration complete
Disable-AipServiceSuperUserFeature
```

---

### 13.5 Governance & Audit

**Who should be in the Super User group:**

| Role | Justification |
|------|---------------|
| Information Protection Administrator | Operational label management and recovery |
| Legal / eDiscovery team lead | Regulated content access for investigations |
| CISO or Deputy CISO | Emergency access and incident response |
| **NOT** general helpdesk or IT admins | Super User is high-privilege — limit to named individuals with a business need |

**Audit logging:**

All Super User decryption events are written to the **Azure Information Protection audit log**. Query via:

```powershell
# AIP usage log (requires AIPService module)
Get-AipServiceUserLog -Path "C:\AIPLogs" -FromDate (Get-Date).AddDays(-30)

# Also visible in Microsoft Purview Audit (unified audit log)
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) `
    -Operations "SensitivityLabelApplied","RMSDecrypt" -ResultSize 100
```

**Quarterly review checklist:**

- Verify `Get-AipServiceSuperUserFeature` returns `Disabled` (only enable on demand)
- Review `Get-AipServiceSuperUserGroup` — confirm group is still correct
- Review group membership in Entra ID — ensure no stale members
- Review AIP audit logs for unexpected Super User decryption activity

---

## Appendix: Tenant Label Inventory (Post-Deployment)

| # | Label | Priority | Scope | Encryption | Parent |
|---|-------|----------|-------|------------|--------|
| 1 | Public | 0 | File, Email, Site, UnifiedGroup | None | — |
| 2 | General | 1 | File, Email, Site, UnifiedGroup | None | — |
| 3 | Confidential | 2 | Groups & Sites (container) | None | — |
| 4 | Confidential - Internal | 3 | File, Email, Site, UnifiedGroup | Template (org-wide) | Confidential |
| 5 | Confidential - Reporting | 4 | File, Email, Site, UnifiedGroup | Template (org-wide) | Confidential |
| 6 | Confidential - Third Parties | 5 | File, Email, Site, UnifiedGroup | UserDefined + DNF | Confidential |
| 7 | Restricted | 6 | Groups & Sites (container) | None | — |
| 8 | Restricted - Third Parties | 7 | File, Email, Site, UnifiedGroup | UserDefined + DNF | Restricted |
| 9 | Restricted - Internal | 8 | File, Email, Site, UnifiedGroup | Template (admin-only) | Restricted |

**Tiered Policies:**

| # | Policy | Labels | Priority | Settings |
|---|--------|--------|----------|----------|
| 1 | IAC - Base Label Policy | Public, General | 0 | Default=General, Mandatory=Yes, Downgrade=Yes, PowerBI=Yes |
| 2 | IAC - Confidential Label Policy | Confidential-Internal, Confidential-ThirdParties, Confidential-Reporting (parent auto-included) | 1 | Scope: All Users |
| 3 | IAC - Restricted Label Policy | Restricted-Internal, Restricted-ThirdParties (parent auto-included) | 2 | Scope: All Users |
