# Microsoft 365 Copilot Readiness — CIS Policy Recommendations

**Tenant:** acme2M365 (ACME Corp Baseline)  
**Date:** 3 March 2026  
**Framework Alignment:** CIS Microsoft 365 Foundations Benchmark v6.0.0  
**Total Recommended Policies:** 59

---

## Summary

This document outlines the **recommended CIS-aligned policies** required to securely deploy Microsoft 365 Copilot. Each section identifies the policies needed, their priority, and the recommended deployment order to ensure your tenant meets security best practices before enabling Copilot.

**Total policies recommended: 55**

| Priority | Count | Description |
|----------|-------|-------------|
| 🔴 Critical | 17 | Required policies for secure Copilot deployment |
| 🟠 High | 15 | Strongly recommended policies that underpin Copilot security |
| 🟡 Medium | 19 | Supporting policies that strengthen Copilot security posture |
| 🔵 Informational | 8 | Monitoring policies for ongoing compliance |

---

## 🔴 Critical Priority — Required Copilot Readiness Policies

These policies are required before Copilot rollout to ensure a secure deployment.

### 1. MFA for All Users

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| CIS - CA01 - MFA for All Admins [L1] - M365 - v6.0.0 *(§5.2.2.1)* | Entra | **Deploy** |
| CIS - CA02 - MFA for All Users [L1] - M365 - v6.0.0 *(§5.2.2.2)* | Entra | **Deploy** |
| CIS - CA06 - Phishing-Resistant MFA for All Admins [L2] - M365 - v6.0.0 *(§5.2.2.5)* | Entra | **Deploy** |
| CIS - 5.1.2.1 - Disable Per-User MFA [L1] - M365 - v6.0.0 | Entra | **Deploy** |
| Microsoft Authenticator configuration *(§5.2.3.1)* | Entra | **Configure** |
| FIDO2 Authentication configuration | Entra | **Configure** |

**Rationale:** Copilot readiness requires MFA for all users via Conditional Access. v6.0.0 adds §5.1.2.1 requiring per-user MFA to be **disabled** in favour of CA-based MFA for consistent enforcement. §5.2.2.5 was renamed from "Strong Authentication" to "Phishing-Resistant MFA" to align with Microsoft terminology.

---

### 2. Require Managed Device for Authentication

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| CIS - CA08 - Require Managed Devices [L1] - M365 - v6.0.0 *(§5.2.2.9)* | Entra | **Deploy** |
| CIS - CA09 - Require Managed Device for MFA Registration [L1] - M365 - v6.0.0 | Entra | **Deploy** |
| Device Compliance Settings | Intune | **Configure** |

**Rationale:** Copilot can surface sensitive data through chat. Ensuring only managed, compliant devices can access Copilot prevents data leakage to unmanaged endpoints.

---

### 3. Restrict M365 Group Creation

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| Default User Role Permissions | Entra | **Configure** |

**Rationale:** Uncontrolled group creation means uncontrolled SharePoint sites and Teams — all of which Copilot can index and surface. Restricting group creation limits the blast radius of Copilot's data access.

---

### 4. Mailbox Audit Actions Configured

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| Mail Flow Security Settings | Exchange | **Enable & monitor** |
| Mail Flow General Settings | Exchange | **Enable & monitor** |

**Rationale:** Full mailbox auditing (including Copy, FolderBind, Move actions) is essential for detecting if Copilot-driven actions or data access trigger unusual mailbox activity.

---

### 5. Disable Self-Service Purchase for Copilot

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| Microsoft 365 Copilot | M365 Admin Center | **Disable self-service** |
| Microsoft 365 Copilot Pro | M365 Admin Center | **Verify disabled** |

**Rationale:** Allowing self-service purchase of Copilot licenses means users could enable Copilot before the tenant is properly secured — bypassing all readiness controls.

---

### 6. Data Loss Prevention Policies

> 🔬 **Start here — run DSPM for AI before configuring any DLP.** Purview Data Security Posture Management for AI provides an oversharing assessment showing exactly what content Copilot can currently access. Its built-in recommendations directly inform which DLP policies and label conditions to configure first.

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| DSPM for AI — oversharing assessment | Purview | **Run first — pre-requisite** 🆕 |
| Default Office 365 DLP policy | Purview | **Enable** |
| Default policy for Teams | Purview | **Enable** |
| Default policy for devices | Purview | **Enable** |
| U.S. Financial Data | Purview | **Enable** |
| Default DLP policy - Protect sensitive M365 Copilot interactions | Purview | **Enable** ⚠️ audit-only by default |
| Copilot-scoped blocking DLP policy (label + SIT conditions) | Purview | **Create & enforce** 🆕 |
| Adaptive Protection (Insider Risk + DLP) | Purview | **Enable** 🆕 |
| Communication Compliance for Copilot | Purview | **Configure** 🆕 |

**Rationale:** The five default Microsoft DLP policies detect but do not block — they run in audit-only mode by default. For Copilot readiness you need at minimum one **blocking** policy explicitly scoped to the Microsoft 365 Copilot location, using label-based conditions (more reliable than SIT scanning alone) and set to Active enforcement mode. DSPM for AI tells you what to protect before you build the policies.

---

#### How to configure DSPM for AI

1. Go to **Microsoft Purview portal** → **Solutions** → **Data Security Posture Management**
2. Select the **AI Hub** tab → review the **Oversharing** tile — this shows files labelled Confidential or Restricted that Copilot can currently access without any restriction
3. Review the **Recommendations** tab — Purview will suggest specific DLP policies and label conditions based on your actual content exposure
4. Export the oversharing report to inform which SITs and labels to target in your blocking DLP policy (configured below)
5. Review **Activity explorer** → filter by **Copilot** to see what Copilot interactions are already occurring and what content is being surfaced

> ℹ️ Requires Purview Information Protection P2 or Microsoft 365 E5 Compliance licence.

---

#### How to configure the Copilot-scoped blocking DLP policy

1. Go to **Microsoft Purview portal** → **Data loss prevention** → **Policies** → **+ Create policy**
2. Select **Custom policy** → name it e.g. `Block sensitive content in Copilot interactions`
3. **Choose locations:** Select **Microsoft 365 Copilot** (also add Teams chat, SharePoint, OneDrive, and Exchange for full coverage)
4. **Define Rule 1 — label-based:**
   - Condition: **Content is labelled** → select your `Confidential` and `Restricted` sensitivity labels
   - Action: **Block everyone** (or **Block with override** if users need to provide a business justification to proceed)
   - User notification: enable and explain why the content was blocked
5. **Define Rule 2 — SIT-based:**
   - Condition: **Content contains** → add Sensitive Information Types relevant to your org (e.g. Credit Card Number, UK National Insurance Number, Azure storage keys, passwords/credentials)
   - Confidence level: **High confidence** | Instance count: **1 or more**
   - Action: **Block with override** (requiring justification reduces false positive friction while maintaining an audit trail)
6. **Policy mode:** Set to **Simulation** first — review the matches report for 48 hours to baseline the false positive rate, then switch to **Active enforcement**
7. Save and publish — allow up to 24 hours for full propagation across all locations

> ⚠️ Do not skip the simulation step. The Microsoft 365 Copilot location does not support all DLP rule conditions available in other locations — verify your rules behave as expected before going Active.

---

#### How to configure Adaptive Protection

1. Go to **Microsoft Purview portal** → **Insider Risk Management** → **Adaptive Protection** → toggle **On**
2. Insider Risk Management will begin assigning risk levels (Minor / Moderate / Elevated) to users based on their behaviour signals (e.g. bulk downloads, unusual sharing, departing employee indicators)
3. Go to **Data loss prevention** → open your Copilot blocking DLP policy → **Edit**
4. Add a new rule (place above your existing rules so it takes priority):
   - Condition: **Insider risk level is** → **Elevated**
   - Action: **Block** (no override — stricter than the business-justification rule for normal users)
5. Optionally add a second rule for **Moderate** risk with a **Block with override** action
6. Save and publish — users with elevated risk scores will now automatically receive stricter DLP enforcement across all locations including Copilot interactions

> ℹ️ Requires Microsoft 365 E5 Compliance or the Insider Risk Management add-on.

---

#### How to configure Communication Compliance for Copilot

1. Go to **Microsoft Purview portal** → **Communication Compliance** → **Policies** → **+ Create policy**
2. Select the **Monitor Copilot interactions** template from the list — if the template is not available in your tenant, create a **Custom policy** and manually scope it to Microsoft 365 Copilot
3. **Scope:** Set supervised users to all Copilot licence holders (or a pilot group initially to tune the policy before broad rollout)
4. **Conditions to monitor:**
   - Sensitive information types: add your key SITs (credentials, financial data, health information, PII)
   - Keywords: add terms relevant to your environment (e.g. confidential project names, `bypass`, `ignore previous instructions`, `as an AI ignore`)
   - Optionally enable the **Threat**, **Targeted harassment**, or **Offensive language** classifiers
5. **Reviewers:** Assign at least two compliance reviewers who will triage flagged Copilot interactions — a single reviewer creates a bottleneck and a conflict-of-interest risk
6. **Alerts:** Start with a **Weekly digest** alert to reviewers to avoid alert fatigue on initial deployment; increase cadence once the policy is tuned
7. Review the **Reports** tab regularly — Communication Compliance provides trend data on policy violations by user, policy, and time period

> ℹ️ Communication Compliance captures both Copilot prompts (what users ask) and responses (what Copilot surfaces) — this is the primary control for detecting prompt injection attempts, systematic data extraction via Copilot, and policy circumvention.

---

### 7. Guest Sharing Controls

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| Guest item sharing settings | SharePoint | **Configure** |
| External sharing settings | SharePoint | **Configure** |
| Guest user access and invite settings | Entra | **Configure** |

**Rationale:** If guests can reshare items they don't own, Copilot-indexed content could be exposed to external users through sharing chains.

---

### 8. Sensitivity Labels on SharePoint Sites

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| CIS - Base Label Policy | Purview | **Verify published** |
| CIS - Restricted Label Policy | Purview | **Verify published** |
| CIS - Confidential Label Policy | Purview | **Verify published** |
| Confidential (label group) | Purview | **Apply to sites** |
| Restricted (label group) | Purview | **Apply to sites** |

**Rationale:** Sensitivity labels on SharePoint sites control what Copilot can access. Without labels applied at the site level, Copilot treats all content equally — no classification boundary exists.

---

## 🟠 High Priority — Strongly Recommended Policies

These policies are strongly recommended to underpin the critical policies above and close security gaps.

### 9. Block Legacy Authentication

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| CIS - CA03 - Block Legacy Authentication [L1] - M365 - v6.0.0 *(§5.2.2.3)* | Entra | **Deploy** |

**Rationale:** Legacy auth bypasses MFA. The CIS baseline policy ensures comprehensive coverage across all apps and client types.

---

### 10. External Sharing & Default Link Type

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| SharePoint External Sharing | SharePoint | **Monitor** |
| Allow syncing only on computers joined to specific domains | SharePoint | **Configure** |

**Rationale:** External sharing settings and default link types control how easily Copilot-accessible content can leak externally. Organisation links should be the default, not "Anyone" links.

---

### 11. Sensitivity Label Policies Published

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| CIS - Base Label Policy | Purview | **Verify user coverage** |
| CIS - Restricted Label Policy | Purview | **Verify user coverage** |
| CIS - Confidential Label Policy | Purview | **Verify user coverage** |

**Rationale:** Labels must be published to all users and sites. Copilot respects sensitivity labels only when they're actually applied.

---

### 12. Supporting Conditional Access & Authentication Policies

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| CIS - CA05 - Restrict Entra Admin Center [L1] *(§5.1.2.4)* | Entra | **Deploy** |
| CIS - CA13 - Block Device Code Flow [L1] *(§5.2.2.12)* | Entra | **Deploy** |
| CIS - CA04 - Sign-In Frequency & Non-Persistent Browser for Admins [L1] | Entra | **Deploy** |
| CIS - CA07 - Idle Session Timeout for Unmanaged Devices [L1] | Entra | **Deploy** |
| CIS - CA11 - Protect High Risk Sign-Ins [L1] - P2 *(§5.2.2.7)* | Entra | **Deploy** |
| CIS - CA12 - Block Medium Risk Sign-Ins [L2] - P2 *(§5.2.2.8)* | Entra | **Deploy** |
| CIS - CA10 - Protect High Risk Users [L1] - P2 *(§5.2.2.6)* | Entra | **Deploy** |
| CIS - CA14 - Intune Enrollment Sign-In Frequency [L1] | Entra | **Deploy** |
| CIS - 5.2.3.5 - Disable Weak Authentication Methods [L1] - v6.0.0 | Entra | **Deploy** |
| CIS - 5.2.3.6 - Enable System-Preferred MFA [L1] - v6.0.0 | Entra | **Deploy** |
| CIS - 5.3.3 - Access Reviews for Privileged Roles [L1] - v6.0.0 | Entra | **Deploy** |

**Rationale:** These CA and authentication policies form the Zero Trust foundation that Copilot security depends on. Device code flow blocking prevents token theft; session controls limit exposure windows; risk-based policies catch compromised accounts before Copilot can be abused.

> **⚠️ v6.0.0 Changes:**
> - **CA05** (Restrict Entra Admin Center) was elevated from **L2 → L1** — now a baseline requirement.
> - **§5.2.3.5** (NEW) — Weak authentication methods (SMS, voice) must be disabled.
> - **§5.2.3.6** (NEW) — System-preferred MFA ensures the strongest available method is used.
> - **§5.3.3** (NEW) — Access reviews for privileged roles required at L1.

---

## 🟡 Medium Priority — Supporting Copilot Posture

These policies strengthen the overall security context around Copilot and are recommended for a robust deployment.

| Policy Name | Product | Copilot Relevance |
|------------|---------|-------------------|
| Entra Enterprise Application Admin Consent settings | Entra | Controls which apps (including Copilot plugins) admins can consent to |
| Entra Enterprise Application User Consent settings | Entra | Prevents users consenting to risky apps that Copilot could interact with |
| Registration Campaign | Entra | Drives MFA adoption — needed before Copilot rollout |
| Password Protection | Entra | Weak passwords + Copilot = easy account compromise + data access |
| Software OATH tokens Authentication configuration | Entra | Ensure strong auth methods available for Copilot users |
| CIS - 5.1.3.1 - Dynamic Group for Guest Users [L1] - v6.0.0 | Entra | Ensures guest lifecycle management — Copilot respects group-based access |
| INF - Client Approved IP Range | Entra | Named locations underpin CA policy enforcement |
| INF-NL01 - Approved Countries | Entra | Named locations underpin CA policy enforcement |
| INF - MSP Service Center | Entra | Named locations underpin CA policy enforcement |
| TiB - Allowed Countries | Entra | Named locations underpin CA policy enforcement |
| Organization Technical Contact | M365 Admin Center | Ensures proper communication channel for Copilot-related notifications |
| Guest user directory access | M365 Admin Center | Controls what guests can discover via directory — Copilot respects directory permissions |
| CIS - 7.2.9 - Guest Access Auto-Expiration [L1] - v6.0.0 | SharePoint | Automatically expires stale guest access to Copilot-indexed content |
| Global (Meeting policy) | Teams | Controls Copilot in Teams Meetings behaviour |
| TiB - Meeting Recording Settings | Teams | Copilot uses meeting transcripts — recording settings matter |
| Meeting Record Settings | Teams | Controls Copilot transcript access |
| CIS - 8.2.2 - Block Unmanaged Teams Users [L1] - v6.0.0 | Teams | Prevents data leakage through Copilot-accessible Teams conversations |
| CIS - 8.2.3 - Block External Teams Conversations [L1] - v6.0.0 | Teams | Blocks unsolicited external contact that Copilot could index |
| Communication Compliance for Copilot 🆕 | Purview | Monitors Copilot prompts and responses for policy violations, prompt injection attempts, and sensitive data extraction |

---

## 🔵 Informational — Ongoing Monitoring Policies

These policies should be in place and monitored for drift to maintain Copilot readiness.

| Policy Name | Product | Copilot Relevance |
|------------|---------|-------------------|
| Unified Audit Logging | Purview | Audit log search enabled |
| Mail Flow Security Settings | Exchange | AuditBypassEnabled not set |
| Mail Flow General Settings | Exchange | AuditDisabled is False |
| SharePoint External Sharing | SharePoint | Org-level sharing compliant |
| OneDrive Retention | SharePoint | Data governance |
| Idle session sign-out | SharePoint | Session security |
| SharePoint Site Creation settings | SharePoint | Site governance |
| Password Expiration Policy | M365 Admin Center | Account security baseline |

---

## Quick-Reference: All 59 Recommended CIS Policies

### Entra (30 policies)

| # | Policy | Priority |
|---|--------|----------|
| 1 | CIS - CA01 - MFA for All Admins [L1] *(§5.2.2.1)* | 🔴 Critical |
| 2 | CIS - CA02 - MFA for All Users [L1] *(§5.2.2.2)* | 🔴 Critical |
| 3 | CIS - CA06 - Phishing-Resistant MFA for Admins [L2] *(§5.2.2.5)* | 🔴 Critical |
| 4 | CIS - 5.1.2.1 - Disable Per-User MFA [L1] | 🔴 Critical |
| 5 | CIS - CA08 - Require Managed Devices [L1] *(§5.2.2.9)* | 🔴 Critical |
| 6 | CIS - CA09 - Require Managed Device for MFA Registration [L1] | 🔴 Critical |
| 7 | Microsoft Authenticator configuration *(§5.2.3.1)* | 🔴 Critical |
| 8 | FIDO2 Authentication configuration | 🔴 Critical |
| 9 | Default User Role Permissions | 🔴 Critical |
| 10 | Guest user access and invite settings *(§5.1.6.2)* | 🔴 Critical |
| 11 | CIS - CA03 - Block Legacy Authentication [L1] *(§5.2.2.3)* | 🟠 High |
| 12 | CIS - CA05 - Restrict Entra Admin Center [L1] *(§5.1.2.4)* ⬆️ | 🟠 High |
| 13 | CIS - CA13 - Block Device Code Flow [L1] *(§5.2.2.12)* | 🟠 High |
| 14 | CIS - CA04 - Sign-In Frequency for Admins [L1] | 🟠 High |
| 15 | CIS - CA07 - Idle Session Timeout [L1] | 🟠 High |
| 16 | CIS - CA11 - Protect High Risk Sign-Ins [L1] *(§5.2.2.7)* | 🟠 High |
| 17 | CIS - CA12 - Block Medium Risk Sign-Ins [L2] *(§5.2.2.8)* | 🟠 High |
| 18 | CIS - CA10 - Protect High Risk Users [L1] *(§5.2.2.6)* | 🟠 High |
| 19 | CIS - CA14 - Intune Enrollment Sign-In Frequency [L1] | 🟠 High |
| 20 | CIS - 5.2.3.5 - Disable Weak Auth Methods [L1] 🆕 | 🟠 High |
| 21 | CIS - 5.2.3.6 - System-Preferred MFA [L1] 🆕 | 🟠 High |
| 22 | CIS - 5.3.3 - Access Reviews for Privileged Roles [L1] 🆕 | 🟠 High |
| 23 | Entra Enterprise Application Admin Consent settings | 🟡 Medium |
| 24 | Entra Enterprise Application User Consent settings | 🟡 Medium |
| 25 | Registration Campaign | 🟡 Medium |
| 26 | Password Protection *(§5.2.3.2/§5.2.3.3)* | 🟡 Medium |
| 27 | Software OATH tokens Authentication configuration | 🟡 Medium |
| 28 | CIS - 5.1.3.1 - Dynamic Group for Guest Users [L1] 🆕 | 🟡 Medium |
| 29 | INF - Client Approved IP Range | 🟡 Medium |
| 30 | INF-NL01 - Approved Countries + TiB - Allowed Countries + INF - MSP Service Center | 🟡 Medium |

### Purview (13 policies)

| # | Policy | Priority |
|---|--------|----------|
| 31 | Default Office 365 DLP policy | 🔴 Critical |
| 32 | Default policy for Teams | 🔴 Critical |
| 33 | Default policy for devices | 🔴 Critical |
| 34 | U.S. Financial Data | 🔴 Critical |
| 35 | Default DLP policy - Protect sensitive M365 Copilot interactions ⚠️ audit-only | 🔴 Critical |
| 36 | DSPM for AI — oversharing assessment 🆕 | 🔴 Critical |
| 37 | Copilot-scoped blocking DLP policy (label + SIT conditions) 🆕 | 🔴 Critical |
| 38 | CIS - Base Label Policy *(§3.3.1)* | 🔴 Critical |
| 39 | CIS - Restricted Label Policy *(§3.3.1)* | 🔴 Critical |
| 40 | CIS - Confidential Label Policy *(§3.3.1)* | 🔴 Critical |
| 41 | Adaptive Protection (Insider Risk + DLP) 🆕 | 🟠 High |
| 42 | Communication Compliance for Copilot 🆕 | 🟡 Medium |
| 43 | Unified Audit Logging *(§6.1.1)* | 🔵 Informational |

### SharePoint (6 policies)

| # | Policy | Priority |
|---|--------|----------|
| 44 | Guest item sharing settings *(§7.2.5)* | 🔴 Critical |
| 45 | External sharing settings *(§7.2.3)* | 🔴 Critical |
| 46 | Allow syncing only on computers joined to specific domains *(§7.3.2)* | 🟠 High |
| 47 | CIS - 7.2.9 - Guest Access Auto-Expiration [L1] 🆕 | 🟡 Medium |
| 48 | SharePoint External Sharing | 🔵 Informational |
| 49 | Idle session sign-out | 🔵 Informational |

### Exchange (2 policies)

| # | Policy | Priority |
|---|--------|----------|
| 50 | Mail Flow Security Settings *(§6.1.2)* | 🔴 Critical |
| 51 | Mail Flow General Settings *(§6.1.1/§6.1.3)* | 🔴 Critical |

### M365 Admin Center (4 policies)

| # | Policy | Priority |
|---|--------|----------|
| 52 | Microsoft 365 Copilot (Self-Service) | 🔴 Critical |
| 53 | Microsoft 365 Copilot Pro (Self-Service) | 🔴 Critical |
| 54 | Organization Technical Contact | 🟡 Medium |
| 55 | Guest user directory access | 🟡 Medium |

### Teams (4 policies)

| # | Policy | Priority |
|---|--------|----------|
| 56 | Global (Meeting policy) | 🟡 Medium |
| 57 | TiB - Meeting Recording Settings | 🟡 Medium |
| 58 | CIS - 8.2.2 - Block Unmanaged Teams Users [L1] 🆕 | 🟡 Medium |
| 59 | CIS - 8.2.3 - Block External Teams Conversations [L1] 🆕 | 🟡 Medium |

### Intune (1 policy)

| # | Policy | Priority |
|---|--------|----------|
| 60 | Device Compliance Settings *(§4.1)* | 🔴 Critical |

---

## Recommended Deployment Order

Before enabling Copilot licenses, address these in order:

### Phase 1 — Identity & Access (Week 1-2)
1. ✅ Disable per-user MFA and deploy CA-based MFA policies (CA01, CA02, CA06) + Authenticator/FIDO2 config
2. ✅ Deploy CIS-CA08 (Managed Devices) + fix Device Compliance Settings
3. ✅ Block legacy auth (CA03)
4. ✅ Disable weak auth methods (§5.2.3.5) + enable system-preferred MFA (§5.2.3.6)
5. ✅ Restrict M365 group creation (Default User Role Permissions)
6. ✅ Disable Copilot self-service purchase

### Phase 2 — Data Protection (Week 2-3)
7. ✅ Run **DSPM for AI** oversharing assessment — identify what content Copilot can currently access before any DLP blocking is in place
8. ✅ **Enable** all 5 default DLP policies; note the Copilot-specific policy is **audit-only by default** — do not rely on it to block
9. ✅ Create **Copilot-scoped blocking DLP policy** — label-based + SIT conditions; run in **Simulation mode for 48 hours** to baseline false positives, then switch to **Active enforcement**
10. ✅ Enable **Adaptive Protection** in Insider Risk Management → add elevated-risk condition to the Copilot blocking DLP policy
11. ✅ Apply sensitivity labels to all SharePoint sites
12. ✅ Verify label publishing policies cover all users
13. ✅ Fix guest sharing settings (SharePoint + Entra) + enable guest access auto-expiration (§7.2.9)

### Phase 3 — Hardening (Week 3-4)
14. ✅ Deploy remaining CA policies (CA05, CA07, CA10-14)
15. ✅ Configure access reviews for privileged roles (§5.3.3)
16. ✅ Fix Exchange mailbox audit actions (add Copy, FolderBind, Move)
17. ✅ Restrict Teams external communications (§8.2.2, §8.2.3)
18. ✅ Remediate Teams meeting recording settings
19. ✅ Address consent settings, password protection, and dynamic guest group
20. ✅ Configure **Communication Compliance** policy scoped to Copilot licence holders

### Phase 4 — Validate & Enable
21. ✅ Re-run Copilot Readiness check — target all checks passed
22. ✅ Apply "Copilot Readiness" tags to all 59 policies in Inforcer
23. ✅ Enable Copilot licenses for pilot group
24. ✅ Monitor audit logs, DLP alerts, and Communication Compliance matches for 2 weeks before broader rollout

---

*CIS Microsoft 365 Foundations Benchmark v6.0.0 — Copilot Readiness Policy Recommendations — inforcer2M365 tenant.*
