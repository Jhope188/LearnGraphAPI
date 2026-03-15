# Copilot Readiness — Policy Tag Recommendations

**Tenant:** acme2M365 (ACME Corp Baseline)  
**Date:** 3 March 2026  
**Alignment Score:** 23.45% (290 policies)  
**Copilot Readiness Checks:** 21 (8 Failed, 5 Warning, 8 Passed)

---

## Summary

This document cross-references the **Copilot Readiness report** (21 checks) against the **Tenant Alignment export** (290 policies) to identify which specific policies in Inforcer should receive a **"Copilot Readiness"** tag. Tagging these policies enables you to filter, prioritise, and track the policies that directly impact your organisation's readiness to deploy Microsoft 365 Copilot securely.

**Total policies recommended for Copilot Readiness tag: 52**

| Priority | Count | Description |
|----------|-------|-------------|
| 🔴 Critical | 18 | Directly maps to a **Failed** Copilot readiness check |
| 🟠 High | 12 | Directly maps to a **Warning** check or underpins a critical failure |
| 🟡 Medium | 14 | Supporting policies that strengthen Copilot security posture |
| 🔵 Informational | 8 | Passed checks — tag for ongoing monitoring |

---

## 🔴 Critical Priority — Failed Copilot Readiness Checks

These policies map directly to the **8 failed** Copilot readiness checks. They must be deployed or remediated before Copilot rollout.

### 1. MFA for All Users *(Failed — Medium)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| CIS - CA01 - MFA for All Admins [L1] - M365 - v5.0.0 | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA02 - MFA for All Users [L1] - M365 - v5.0.0 | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA06 - Strong Authentication MFA for All Admins [L2] - M365 - v5.0.0 | Entra | Recommended from Baseline | **Deploy** |
| IAC - GLOBAL - GRANT - MFA - AllUsers | Entra | Existing Customer Policy | **Verify enabled** |
| IAC - GLOBAL - GRANT - MFA - AllAdmins | Entra | Existing Customer Policy | **Verify enabled** |
| Microsoft Authenticator configuration | Entra | Unaccepted Deviation | **Remediate** |
| FIDO2 Authentication configuration | Entra | Unaccepted Deviation | **Remediate** |

**Rationale:** Copilot readiness requires MFA for all users. Without it, Copilot-generated content accessed from unverified sessions is a data exposure risk.

---

### 2. Require Managed Device for Authentication *(Failed — Medium)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| CIS - CA08 - Require Managed Devices [L1] - M365 - v5.0.0 | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA09 - Require Managed Device for MFA Registration [L1] - M365 - v5.0.0 | Entra | Recommended from Baseline | **Deploy** |
| IAC - INTUNE - BLOCK - RequireCompliantDevice - NonTrustedLocations | Entra | Existing Customer Policy | **Verify enabled** |
| IAC - INTUNE - GRANT - RequireCompliantDevice | Entra | Existing Customer Policy | **Verify enabled** |
| Device Compliance Settings | Intune | Unaccepted Deviation | **Remediate** |

**Rationale:** Copilot can surface sensitive data through chat. Ensuring only managed, compliant devices can access Copilot prevents data leakage to unmanaged endpoints.

---

### 3. Users Can't Create M365 Groups *(Failed — Medium)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| Default User Role Permissions | Entra | Unaccepted Deviation | **Remediate** |

**Rationale:** Uncontrolled group creation means uncontrolled SharePoint sites and Teams — all of which Copilot can index and surface. Restricting group creation limits the blast radius of Copilot's data access.

---

### 4. Mailbox Audit Actions Configured *(Failed — High)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| Mail Flow Security Settings | Exchange | Aligned | **Tag for monitoring** |
| Mail Flow General Settings | Exchange | Aligned | **Tag for monitoring** |

**Rationale:** Full mailbox auditing (including Copy, FolderBind, Move actions) is essential for detecting if Copilot-driven actions or data access trigger unusual mailbox activity.

---

### 5. Self-Service Purchase Disabled for Copilot *(Failed — Low)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| Microsoft 365 Copilot | M365 Admin Center | Unaccepted Deviation | **Remediate** |
| Microsoft 365 Copilot Pro | M365 Admin Center | Aligned with Variables | **Verify disabled** |

**Rationale:** Allowing self-service purchase of Copilot licenses means users could enable Copilot before the tenant is properly secured — bypassing all readiness controls.

---

### 6. Data Loss Prevention Enabled *(Failed — High)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| Default Office 365 DLP policy | Purview | Existing Customer Policy | **Enable** |
| Default policy for Teams | Purview | Existing Customer Policy | **Enable** |
| Default policy for devices | Purview | Existing Customer Policy | **Enable** |
| U.S. Financial Data | Purview | Existing Customer Policy | **Enable** |
| Default DLP policy - Protect sensitive M365 Copilot interactions | Purview | Existing Customer Policy | **Enable** |

**Rationale:** DLP policies are the primary control preventing Copilot from surfacing or generating sensitive data (PII, financial data, credentials) in chat responses. The Copilot-specific DLP policy exists but is **not enabled**.

---

### 7. Guest Sharing Controls *(Failed — Medium)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| Guest item sharing settings | SharePoint | Unaccepted Deviation | **Remediate** |
| External sharing settings | SharePoint | Unaccepted Deviation | **Remediate** |
| Guest user access and invite settings | Entra | Unaccepted Deviation | **Remediate** |

**Rationale:** If guests can reshare items they don't own, Copilot-indexed content could be exposed to external users through sharing chains.

---

### 8. Sensitivity Labels on SharePoint Sites *(Failed — Medium)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| IAC - Base Label Policy | Purview | Existing Customer Policy | **Verify published** |
| IAC - Restricted Label Policy | Purview | Existing Customer Policy | **Verify published** |
| IAC - Confidential Label Policy | Purview | Existing Customer Policy | **Verify published** |
| Confidential (label group) | Purview | Existing Customer Policy | **Apply to sites** |
| Restricted (label group) | Purview | Existing Customer Policy | **Apply to sites** |

**Rationale:** Sensitivity labels on SharePoint sites control what Copilot can access. Without labels applied at the site level, Copilot treats all content equally — no classification boundary exists.

---

## 🟠 High Priority — Warning Checks & Supporting Policies

These map to **Warning** readiness checks (compliant but with gaps) or underpin critical failures.

### 9. Block Legacy Authentication *(Warning — High)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| CIS - CA03 - Block Legacy Authentication [L1] - M365 - v5.0.0 | Entra | Recommended from Baseline | **Deploy** |
| IAC - GLOBAL – BLOCK - Legacy Authentication | Entra | Existing Customer Policy | **Verify all covered** |

**Rationale:** Legacy auth bypasses MFA. Even if existing IAC policies cover some scenarios, the CIS baseline policy ensures comprehensive coverage across all apps and client types.

---

### 10. External Sharing & Default Link Type *(Warning — Medium)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| SharePoint External Sharing | SharePoint | Aligned | **Tag for monitoring** |
| Allow syncing only on computers joined to specific domains | SharePoint | Unaccepted Deviation | **Remediate** |

**Rationale:** External sharing settings and default link types control how easily Copilot-accessible content can leak externally. Organisation links should be the default, not "Anyone" links.

---

### 11. Sensitivity Label Policies Published *(Warning — Medium)*

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| IAC - Base Label Policy | Purview | Existing Customer Policy | **Verify user coverage** |
| IAC - Restricted Label Policy | Purview | Existing Customer Policy | **Verify user coverage** |
| IAC - Confidential Label Policy | Purview | Existing Customer Policy | **Verify user coverage** |

**Rationale:** Labels exist but the warning suggests not all users or sites are covered. Copilot respects sensitivity labels only when they're actually applied.

---

### 12. Supporting Conditional Access Policies

| Policy Name | Product | Current Status | Action |
|------------|---------|---------------|--------|
| CIS - CA05 - Block Admin Portals for Non-Admins [L2] | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA13 - Block Device Code Flow [L1] | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA04 - Sign-In Frequency & Non-Persistent Browser for Admins [L1] | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA07 - Idle Session Timeout for Unmanaged Devices [L1] | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA11 - Protect High Risk Sign-Ins [L1] - P2 | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA12 - Block Medium Risk Sign-Ins [L2] - P2 | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA10 - Protect High Risk Users [L1] - P2 | Entra | Recommended from Baseline | **Deploy** |
| CIS - CA14 - Intune Enrollment Sign-In Frequency [L1] | Entra | Recommended from Baseline | **Deploy** |

**Rationale:** These CA policies form the Zero Trust foundation that Copilot security depends on. Device code flow blocking prevents token theft; session controls limit exposure windows; risk-based policies catch compromised accounts before Copilot can be abused.

---

## 🟡 Medium Priority — Strengthening Copilot Posture

These policies don't map to a specific Copilot readiness check but significantly improve the security context around Copilot.

| Policy Name | Product | Current Status | Copilot Relevance |
|------------|---------|---------------|-------------------|
| Entra Enterprise Application Admin Consent settings | Entra | Unaccepted Deviation | Controls which apps (including Copilot plugins) admins can consent to |
| Entra Enterprise Application User Consent settings | Entra | Unaccepted Deviation | Prevents users consenting to risky apps that Copilot could interact with |
| Registration Campaign | Entra | Unaccepted Deviation | Drives MFA adoption — needed before Copilot rollout |
| Password Protection | Entra | Unaccepted Deviation | Weak passwords + Copilot = easy account compromise + data access |
| Software OATH tokens Authentication configuration | Entra | Unaccepted Deviation | Ensure strong auth methods available for Copilot users |
| INF - Client Approved IP Range | Entra | Recommended from Baseline | Named locations underpin CA policy enforcement |
| INF-NL01 - Approved Countries | Entra | Recommended from Baseline | Named locations underpin CA policy enforcement |
| INF - MSP Service Center | Entra | Recommended from Baseline | Named locations underpin CA policy enforcement |
| TiB - Allowed Countries | Entra | Recommended from Baseline | Named locations underpin CA policy enforcement |
| Organization Technical Contact | M365 Admin Center | Unaccepted Deviation | Ensures proper communication channel for Copilot-related notifications |
| Guest user directory access | M365 Admin Center | Unaccepted Deviation | Controls what guests can discover via directory — Copilot respects directory permissions |
| Global (Meeting policy) | Teams | Unaccepted Deviation | Controls Copilot in Teams Meetings behaviour |
| TiB - Meeting Recording Settings | Teams | Unaccepted Deviation | Copilot uses meeting transcripts — recording settings matter |
| Meeting Record Settings | Teams | Recommended from Baseline | **Deploy** — controls Copilot transcript access |

---

## 🔵 Informational — Passed Checks (Tag for Monitoring)

These are already compliant but should be tagged so any drift is immediately visible.

| Policy Name | Product | Current Status | Copilot Check |
|------------|---------|---------------|---------------|
| Unified Audit Logging | Purview | Aligned | Audit log search enabled |
| Mail Flow Security Settings | Exchange | Aligned | AuditBypassEnabled not set |
| Mail Flow General Settings | Exchange | Aligned | AuditDisabled is False |
| SharePoint External Sharing | SharePoint | Aligned | Org-level sharing compliant |
| OneDrive Retention | SharePoint | Aligned | Data governance |
| Idle session sign-out | SharePoint | Aligned | Session security |
| SharePoint Site Creation settings | SharePoint | Aligned | Site governance |
| Password Expiration Policy | M365 Admin Center | Aligned | Account security baseline |

---

## Quick-Reference: All 52 Policies to Tag as "Copilot Readiness"

### Entra (30 policies)

| # | Policy | Status | Priority |
|---|--------|--------|----------|
| 1 | CIS - CA01 - MFA for All Admins [L1] | Recommended from Baseline | 🔴 Critical |
| 2 | CIS - CA02 - MFA for All Users [L1] | Recommended from Baseline | 🔴 Critical |
| 3 | CIS - CA06 - Strong Auth MFA for All Admins [L2] | Recommended from Baseline | 🔴 Critical |
| 4 | CIS - CA08 - Require Managed Devices [L1] | Recommended from Baseline | 🔴 Critical |
| 5 | CIS - CA09 - Require Managed Device for MFA Registration [L1] | Recommended from Baseline | 🔴 Critical |
| 6 | Microsoft Authenticator configuration | Unaccepted Deviation | 🔴 Critical |
| 7 | FIDO2 Authentication configuration | Unaccepted Deviation | 🔴 Critical |
| 8 | Default User Role Permissions | Unaccepted Deviation | 🔴 Critical |
| 9 | Guest user access and invite settings | Unaccepted Deviation | 🔴 Critical |
| 10 | IAC - GLOBAL - GRANT - MFA - AllUsers | Existing Customer Policy | 🔴 Critical |
| 11 | IAC - GLOBAL - GRANT - MFA - AllAdmins | Existing Customer Policy | 🔴 Critical |
| 12 | CIS - CA03 - Block Legacy Authentication [L1] | Recommended from Baseline | 🟠 High |
| 13 | IAC - GLOBAL – BLOCK - Legacy Authentication | Existing Customer Policy | 🟠 High |
| 14 | CIS - CA05 - Block Admin Portals for Non-Admins [L2] | Recommended from Baseline | 🟠 High |
| 15 | CIS - CA13 - Block Device Code Flow [L1] | Recommended from Baseline | 🟠 High |
| 16 | CIS - CA04 - Sign-In Frequency for Admins [L1] | Recommended from Baseline | 🟠 High |
| 17 | CIS - CA07 - Idle Session Timeout [L1] | Recommended from Baseline | 🟠 High |
| 18 | CIS - CA11 - Protect High Risk Sign-Ins [L1] | Recommended from Baseline | 🟠 High |
| 19 | CIS - CA12 - Block Medium Risk Sign-Ins [L2] | Recommended from Baseline | 🟠 High |
| 20 | CIS - CA10 - Protect High Risk Users [L1] | Recommended from Baseline | 🟠 High |
| 21 | CIS - CA14 - Intune Enrollment Sign-In Frequency [L1] | Recommended from Baseline | 🟠 High |
| 22 | IAC - INTUNE - BLOCK - RequireCompliantDevice - NonTrustedLocations | Existing Customer Policy | 🔴 Critical |
| 23 | IAC - INTUNE - GRANT - RequireCompliantDevice | Existing Customer Policy | 🔴 Critical |
| 24 | Entra Enterprise Application Admin Consent settings | Unaccepted Deviation | 🟡 Medium |
| 25 | Entra Enterprise Application User Consent settings | Unaccepted Deviation | 🟡 Medium |
| 26 | Registration Campaign | Unaccepted Deviation | 🟡 Medium |
| 27 | Password Protection | Unaccepted Deviation | 🟡 Medium |
| 28 | Software OATH tokens Authentication configuration | Unaccepted Deviation | 🟡 Medium |
| 29 | INF - Client Approved IP Range | Recommended from Baseline | 🟡 Medium |
| 30 | INF-NL01 - Approved Countries + TiB - Allowed Countries + INF - MSP Service Center | Recommended from Baseline | 🟡 Medium |

### Purview (9 policies)

| # | Policy | Status | Priority |
|---|--------|--------|----------|
| 31 | Default Office 365 DLP policy | Existing Customer Policy | 🔴 Critical |
| 32 | Default policy for Teams | Existing Customer Policy | 🔴 Critical |
| 33 | Default policy for devices | Existing Customer Policy | 🔴 Critical |
| 34 | U.S. Financial Data | Existing Customer Policy | 🔴 Critical |
| 35 | Default DLP policy - Protect sensitive M365 Copilot interactions | Existing Customer Policy | 🔴 Critical |
| 36 | IAC - Base Label Policy | Existing Customer Policy | 🔴 Critical |
| 37 | IAC - Restricted Label Policy | Existing Customer Policy | 🔴 Critical |
| 38 | IAC - Confidential Label Policy | Existing Customer Policy | 🔴 Critical |
| 39 | Unified Audit Logging | Aligned | 🔵 Informational |

### SharePoint (5 policies)

| # | Policy | Status | Priority |
|---|--------|--------|----------|
| 40 | Guest item sharing settings | Unaccepted Deviation | 🔴 Critical |
| 41 | External sharing settings | Unaccepted Deviation | 🔴 Critical |
| 42 | Allow syncing only on computers joined to specific domains | Unaccepted Deviation | 🟠 High |
| 43 | SharePoint External Sharing | Aligned | 🔵 Informational |
| 44 | Idle session sign-out | Aligned | 🔵 Informational |

### Exchange (2 policies)

| # | Policy | Status | Priority |
|---|--------|--------|----------|
| 45 | Mail Flow Security Settings | Aligned | 🔴 Critical |
| 46 | Mail Flow General Settings | Aligned | 🔴 Critical |

### M365 Admin Center (4 policies)

| # | Policy | Status | Priority |
|---|--------|--------|----------|
| 47 | Microsoft 365 Copilot (Self-Service) | Unaccepted Deviation | 🔴 Critical |
| 48 | Microsoft 365 Copilot Pro (Self-Service) | Aligned with Variables | 🔴 Critical |
| 49 | Organization Technical Contact | Unaccepted Deviation | 🟡 Medium |
| 50 | Guest user directory access | Unaccepted Deviation | 🟡 Medium |

### Teams (2 policies)

| # | Policy | Status | Priority |
|---|--------|--------|----------|
| 51 | Global (Meeting policy) | Unaccepted Deviation | 🟡 Medium |
| 52 | TiB - Meeting Recording Settings | Unaccepted Deviation | 🟡 Medium |

### Intune (1 policy)

| # | Policy | Status | Priority |
|---|--------|--------|----------|
| 53 | Device Compliance Settings | Unaccepted Deviation | 🔴 Critical |

---

## Recommended Deployment Order

Before enabling Copilot licenses, address these in order:

### Phase 1 — Identity & Access (Week 1-2)
1. ✅ Remediate MFA policies (CA01, CA02, CA06) + Authenticator/FIDO2 config
2. ✅ Deploy CIS-CA08 (Managed Devices) + fix Device Compliance Settings
3. ✅ Block legacy auth (CA03) — verify IAC policy covers all gaps
4. ✅ Restrict M365 group creation (Default User Role Permissions)
5. ✅ Disable Copilot self-service purchase

### Phase 2 — Data Protection (Week 2-3)
6. ✅ **Enable** all 5 DLP policies (especially the Copilot-specific one)
7. ✅ Apply sensitivity labels to all SharePoint sites
8. ✅ Verify label publishing policies cover all users
9. ✅ Fix guest sharing settings (SharePoint + Entra)

### Phase 3 — Hardening (Week 3-4)
10. ✅ Deploy remaining CA policies (CA05, CA07, CA10-14)
11. ✅ Fix Exchange mailbox audit actions (add Copy, FolderBind, Move)
12. ✅ Remediate Teams meeting recording settings
13. ✅ Address consent settings and password protection

### Phase 4 — Validate & Enable
14. ✅ Re-run Copilot Readiness check — target 21/21 passed
15. ✅ Apply "Copilot Readiness" tags to all 52 policies in Inforcer
16. ✅ Enable Copilot licenses for pilot group
17. ✅ Monitor audit logs and DLP alerts for 2 weeks before broader rollout

---

*Generated by cross-referencing Inforcer Copilot Readiness Report against Tenant Alignment Export — inforcer2M365 tenant.*
