# Microsoft 365 Copilot Readiness — CIS Policy Recommendations

**Tenant:** inforcer2M365 (ACME Corp Baseline)  
**Date:** 3 March 2026  
**Framework Alignment:** CIS Microsoft 365 Foundations Benchmark v6.0.0  
**Total Recommended Policies:** 55

---

## Summary

This document outlines the **recommended CIS-aligned policies** required to securely deploy Microsoft 365 Copilot. Each section identifies the policies needed, their priority, and the recommended deployment order to ensure your tenant meets security best practices before enabling Copilot.

**Total policies recommended: 55**

| Priority | Count | Description |
|----------|-------|-------------|
| 🔴 Critical | 15 | Required policies for secure Copilot deployment |
| 🟠 High | 14 | Strongly recommended policies that underpin Copilot security |
| 🟡 Medium | 18 | Supporting policies that strengthen Copilot security posture |
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

| Policy Name | Product | Recommendation |
|------------|---------|----------------|
| Default Office 365 DLP policy | Purview | **Enable** |
| Default policy for Teams | Purview | **Enable** |
| Default policy for devices | Purview | **Enable** |
| U.S. Financial Data | Purview | **Enable** |
| Default DLP policy - Protect sensitive M365 Copilot interactions | Purview | **Enable** |

**Rationale:** DLP policies are the primary control preventing Copilot from surfacing or generating sensitive data (PII, financial data, credentials) in chat responses. The Copilot-specific DLP policy should be enabled before rollout.

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

## Quick-Reference: All 55 Recommended CIS Policies

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

### Purview (9 policies)

| # | Policy | Priority |
|---|--------|----------|
| 31 | Default Office 365 DLP policy | 🔴 Critical |
| 32 | Default policy for Teams | 🔴 Critical |
| 33 | Default policy for devices | 🔴 Critical |
| 34 | U.S. Financial Data | 🔴 Critical |
| 35 | Default DLP policy - Protect sensitive M365 Copilot interactions | 🔴 Critical |
| 36 | CIS - Base Label Policy *(§3.3.1)* | 🔴 Critical |
| 37 | CIS - Restricted Label Policy *(§3.3.1)* | 🔴 Critical |
| 38 | CIS - Confidential Label Policy *(§3.3.1)* | 🔴 Critical |
| 39 | Unified Audit Logging *(§6.1.1)* | 🔵 Informational |

### SharePoint (6 policies)

| # | Policy | Priority |
|---|--------|----------|
| 40 | Guest item sharing settings *(§7.2.5)* | 🔴 Critical |
| 41 | External sharing settings *(§7.2.3)* | 🔴 Critical |
| 42 | Allow syncing only on computers joined to specific domains *(§7.3.2)* | 🟠 High |
| 43 | CIS - 7.2.9 - Guest Access Auto-Expiration [L1] 🆕 | 🟡 Medium |
| 44 | SharePoint External Sharing | 🔵 Informational |
| 45 | Idle session sign-out | 🔵 Informational |

### Exchange (2 policies)

| # | Policy | Priority |
|---|--------|----------|
| 46 | Mail Flow Security Settings *(§6.1.2)* | 🔴 Critical |
| 47 | Mail Flow General Settings *(§6.1.1/§6.1.3)* | 🔴 Critical |

### M365 Admin Center (4 policies)

| # | Policy | Priority |
|---|--------|----------|
| 48 | Microsoft 365 Copilot (Self-Service) | 🔴 Critical |
| 49 | Microsoft 365 Copilot Pro (Self-Service) | 🔴 Critical |
| 50 | Organization Technical Contact | 🟡 Medium |
| 51 | Guest user directory access | 🟡 Medium |

### Teams (4 policies)

| # | Policy | Priority |
|---|--------|----------|
| 52 | Global (Meeting policy) | 🟡 Medium |
| 53 | TiB - Meeting Recording Settings | 🟡 Medium |
| 54 | CIS - 8.2.2 - Block Unmanaged Teams Users [L1] 🆕 | 🟡 Medium |
| 55 | CIS - 8.2.3 - Block External Teams Conversations [L1] 🆕 | 🟡 Medium |

### Intune (1 policy)

| # | Policy | Priority |
|---|--------|----------|
| 56 | Device Compliance Settings *(§4.1)* | 🔴 Critical |

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
7. ✅ **Enable** all 5 DLP policies (especially the Copilot-specific one)
8. ✅ Apply sensitivity labels to all SharePoint sites
9. ✅ Verify label publishing policies cover all users
10. ✅ Fix guest sharing settings (SharePoint + Entra) + enable guest access auto-expiration (§7.2.9)

### Phase 3 — Hardening (Week 3-4)
11. ✅ Deploy remaining CA policies (CA05, CA07, CA10-14)
12. ✅ Configure access reviews for privileged roles (§5.3.3)
13. ✅ Fix Exchange mailbox audit actions (add Copy, FolderBind, Move)
14. ✅ Restrict Teams external communications (§8.2.2, §8.2.3)
15. ✅ Remediate Teams meeting recording settings
16. ✅ Address consent settings, password protection, and dynamic guest group

### Phase 4 — Validate & Enable
17. ✅ Re-run Copilot Readiness check — target all checks passed
18. ✅ Apply "Copilot Readiness" tags to all 55 policies in Inforcer
19. ✅ Enable Copilot licenses for pilot group
20. ✅ Monitor audit logs and DLP alerts for 2 weeks before broader rollout

---

*CIS Microsoft 365 Foundations Benchmark v6.0.0 — Copilot Readiness Policy Recommendations — inforcer2M365 tenant.*
