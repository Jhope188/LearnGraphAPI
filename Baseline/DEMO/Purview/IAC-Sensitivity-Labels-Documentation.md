# IAC Sensitivity Labels — Configuration & Best Practices

> **Author:** IAC  
> **Date:** 27 February 2026  
> **Tenant:** acme2m365.onmicrosoft.com  
> **Reference:** [Purview Practitioner Taxonomy](https://www.thepurviewpractitioner.com/tools/taxonomy) · [Microsoft Learn — Sensitivity Labels](https://learn.microsoft.com/purview/sensitivity-labels)

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
9. [Day-2 Operations](#9-day-2-operations)

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
| `SensitivityLabel.ps1` | Creates all 9 labels and publishes the unified label policy. **Run second.** |
| `IAC-Sensitivity-Labels-Documentation.md` | This document |

---

## 2. Prerequisites

Before creating labels, the following prerequisites must be enabled. The `Enable-SensitivityLabelsPrerequisites.ps1` script handles all three:

| # | Prerequisite | What It Does | How to Verify |
|---|-------------|--------------|---------------|
| 1 | **EnableMIPLabels = True** | Allows sensitivity labels to be applied to M365 Groups | `Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/groupSettings'` → check `EnableMIPLabels` value |
| 2 | **isSensitivityLabelsEnabled = True** | Enables sensitivity labels in SharePoint Online | `Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings'` → check `isSensitivityLabelsEnabled` |
| 3 | **Execute-AzureADLabelSync** | Syncs Purview labels to Entra ID so they appear in Teams/SharePoint admin | Run via Connect-IPPSSession |

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
| **Encryption** | Template — admin-only |
| **Rights** | `<AdminEmail>`: OWNER (full control) |
| **Header** | "RESTRICTED - Internal Only" (10pt, red, centred) |
| **Footer** | "RESTRICTED - Internal Only" (8pt, red, centred) |
| **Watermark** | "RESTRICTED" (48pt, diagonal) |
| **Tooltip** | Encrypted for specific internal recipients only. |
| **Use Case** | Executive compensation, M&A documents, legal hold materials, security incident reports |

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

#### Option A: Single Unified Policy (Current IAC Deployment)

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

#### Option B: Tiered Policy Architecture (Recommended for Granular Control)

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
│                                              │
│  → Everyone gets Public + General            │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  Policy 2: IAC - Confidential Policy         │
│  ─────────────────────────────────────       │
│  Labels:    Confidential (parent + children) │
│  Scope:     All Users                        │
│             EXCEPT: SG-Contractors           │
│  Default:   None (inherits from Policy 1)    │
│  Mandatory: No (inherits from Policy 1)      │
│                                              │
│  → Internal staff see Confidential labels    │
│  → Contractors do not                        │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  Policy 3: IAC - Restricted Policy           │
│  ─────────────────────────────────────       │
│  Labels:    Restricted (parent + children)   │
│  Scope:     SG-Restricted-Users              │
│             (e.g., Executives, Legal, HR)    │
│  Default:   None                             │
│  Mandatory: No (inherits from Policy 1)      │
│                                              │
│  → Only named groups see Restricted labels   │
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

### 5.4 How to Convert from Single to Tiered (Future Migration)

If you start with Option A and later need to split:

```powershell
# 1. Create the new targeted policies FIRST (they won't conflict yet)
New-LabelPolicy -Name "IAC - Restricted Policy" `
    -Labels "Restricted","Restricted - Internal","Restricted - Third Parties" `
    -ExchangeLocation "SG-Restricted-Users" `
    -Comment "Restricted labels for authorised users only"

# 2. Remove Restricted labels from the unified policy
Set-LabelPolicy -Identity "IAC - All Users Label Policy" `
    -RemoveLabels "Restricted","Restricted - Internal","Restricted - Third Parties"

# 3. Verify the split
Get-LabelPolicy | Format-List Name, Labels
```

**Wait 24 hours** between creating the new policy and removing labels from the old one, to avoid a window where Restricted labels are invisible to everyone.

---

## 6. Publishing Walkthrough

### Step-by-Step: Publishing with the Single Unified Policy

#### Step 1: Run Prerequisites (One-Time)

```powershell
cd ~/Desktop/BaslineSetup/Purview
pwsh ./Enable-SensitivityLabelsPrerequisites.ps1 -TenantId "<your-tenant-id>"
```

Wait **24 hours** for propagation.

#### Step 2: Dry Run

```powershell
./SensitivityLabel.ps1 -TenantDomain "acme2m365.onmicrosoft.com" -DryRun
```

Review the output. Confirm:
- All 9 labels detected or would be created
- Policy name and settings look correct
- Admin email is correct (defaults to `admin@<TenantDomain>`)

#### Step 3: Create Labels Only (No Policy)

```powershell
./SensitivityLabel.ps1 -TenantDomain "acme2m365.onmicrosoft.com" -SkipPolicies
```

After running, verify in the **Purview portal**:
1. Go to [purview.microsoft.com](https://purview.microsoft.com) → **Information Protection** → **Labels**
2. Confirm the hierarchy: Public, General, Confidential (3 children), Restricted (2 children)
3. Click each child → verify encryption type and content markings
4. Confirm parent labels show Groups & Sites protection

#### Step 4: Publish the Label Policy

```powershell
./SensitivityLabel.ps1 -TenantDomain "acme2m365.onmicrosoft.com"
```

The script creates **"IAC - All Users Label Policy"** with:

| Setting | Value |
|---------|-------|
| Default Label | General |
| Mandatory Labelling | Yes |
| Downgrade Justification | Yes |
| Power BI Mandatory | Yes |
| Exchange Location | All |

#### Step 5: Wait for Propagation

Label policies propagate over **up to 24 hours** across:

| App | Typical Propagation |
|-----|-------------------|
| Outlook Web | 1–4 hours |
| Outlook Desktop | 4–12 hours |
| Word/Excel/PowerPoint | 4–12 hours |
| Teams | 12–24 hours |
| SharePoint Online | 12–24 hours |
| Power BI | 12–24 hours |

#### Step 6: Verify End-User Experience

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
SensitivityLabel.ps1

  -TenantDomain  [Required]  Your *.onmicrosoft.com domain
  -AdminEmail    [Optional]  Admin email for Restricted-Internal encryption
                             Defaults to admin@<TenantDomain>
  -DryRun        [Optional]  Show what would happen without making changes
  -SkipPolicies  [Optional]  Create labels only, skip policy publishing
```

### 7.2 What the Script Does (Idempotent)

The script is **safe to re-run**. For each label:
- If the label **exists** → skips it (`[EXISTS]`)
- If the label **doesn't exist** → creates it (`[CREATING]`)

For the policy:
- If the policy **exists** → skips it
- If the policy **doesn't exist** → creates it

### 7.3 What the Script Does NOT Do

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

# Label policy settings
Get-LabelPolicy | Format-List Name, Labels, Settings, ExchangeLocation

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

# PowerShell: re-publish the policy (triggers fresh sync)
Set-LabelPolicy -Identity "IAC - All Users Label Policy" -Settings @{} 

# SharePoint: force site-level sync
Set-SPOSite -Identity "https://acme2m365.sharepoint.com/sites/yoursite" -SensitivityLabel ""
```

---

## 9. Day-2 Operations

### 9.1 Adding a New Label

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

# Then add it to the relevant policy
Set-LabelPolicy -Identity "IAC - All Users Label Policy" -AddLabels "Confidential - Financial"
```

### 9.2 Removing a Duplicate or Unwanted Label

```powershell
# Find the label's ImmutableId
Get-Label | Where-Object { $_.DisplayName -eq "Label Name" } | Format-List ImmutableId, ParentId

# Remove it (label enters "pending deletion" state in Purview backend)
Remove-Label -Identity "<ImmutableId>" -Confirm:$false
```

> **Note:** Removed labels enter a "pending deletion" state and may still appear in `Get-Label` output for several hours. This is normal Purview behaviour.

### 9.3 Changing Encryption Rights on an Existing Label

```powershell
# Example: Give the security team access to Restricted - Internal
Set-Label -Identity "Restricted - Internal" `
    -EncryptionRightsDefinitions "securityteam@acme2m365.onmicrosoft.com:OWNER"
```

### 9.4 Converting to Tiered Policies

See [Section 5.4](#54-how-to-convert-from-single-to-tiered-future-migration) for the step-by-step migration from single to tiered policy architecture.

### 9.5 Auditing Label Usage

```powershell
# Purview Audit Log — label application events
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) `
    -Operations "SensitivityLabelApplied","SensitivityLabelUpdated","SensitivityLabelRemoved" `
    -ResultSize 100 |
    Select-Object CreationDate, UserIds, Operations, AuditData
```

### 9.6 Emergency: Remove All Policies

If you need to roll back and remove mandatory labelling urgently:

```powershell
# Remove the unified policy (labels remain but are unpublished)
Remove-LabelPolicy -Identity "IAC - All Users Label Policy" -Confirm:$false

# Labels still exist — they're just not visible to users
# Re-publish when ready by re-running SensitivityLabel.ps1
```

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

**Policy:** IAC - All Users Label Policy → All 9 labels, Default=General, Mandatory=Yes, Downgrade Justification=Yes
