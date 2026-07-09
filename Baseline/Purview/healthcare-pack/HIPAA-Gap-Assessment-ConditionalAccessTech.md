# M365 Healthcare Compliance — HIPAA Gap Assessment

**CIS Controls v8.1 × HIPAA Security & Privacy Rules × Microsoft 365**

---

| Field | Value |
|---|---|
| **Tenant** | Conditional Access Tech (conditionalaccess.tech) |
| **Tenant ID** | 86600c1e-803d-49b9-a963-036358886be9 |
| **Assessment Date** | July 9, 2026 |
| **Assessed By** | Jon Hope, M365 Solutions Architect |
| **Data Source** | Microsoft Graph API via Lokka (interactive session) |
| **Framework** | CIS Controls v8.1 × HIPAA Security Rule 45 CFR §164 |

> **IMPORTANT:** This assessment covers Microsoft 365 technical controls only. HIPAA compliance also requires administrative safeguards, physical safeguards, documented policies, training records, and signed Business Associate Agreements that cannot be assessed via API.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Section 1 — Conditional Access](#section-1--identity--access-conditional-access)
3. [Section 2 — Authentication Methods](#section-2--authentication-methods)
4. [Section 3 — Privileged Access Management](#section-3--privileged-access-management)
5. [Section 4 — Device Compliance Policies](#section-4--device-compliance-policies)
6. [Section 5 — Device Configuration](#section-5--device-configuration)
7. [Section 6 — Purview: DLP, Labels, and Audit](#section-6--purview-dlp-labels-and-audit)
8. [Section 7 — HIPAA Control Scorecard](#section-7--hipaa-control-scorecard)
9. [Section 8 — Immediate Action Plan](#section-8--immediate-action-plan)
10. [Appendix — API Scope Limitations](#appendix--api-scope-limitations)
11. [References](#references)

---

## Executive Summary

This assessment evaluated the Microsoft 365 security configuration of the Conditional Access Tech tenant against CIS Controls v8.1 as mapped to the HIPAA Security Rule. Data was collected directly from Microsoft Graph API covering Entra ID, Intune, and admin policy endpoints. **49 Conditional Access policies**, **2 Intune compliance policies**, **38+ Intune configuration profiles**, and Entra authentication method settings were reviewed.

Purview DLP policies and sensitivity labels require portal-level verification throughout this report, as those APIs require additional delegated scopes not present in the assessment session token.

### Overall Posture by Area

| Area | Status | Key Finding |
|---|---|---|
| Conditional Access | ⚠️ Partial | 19 of 49 policies in report-only mode including critical device compliance requirement |
| Authentication Methods | ✅ Strong | FIDO2 enabled, MFA anti-fatigue active; Software OATH (phishable) enabled for one group |
| Privileged Access / PIM | ❌ Gap | 3 permanent Global Admins and 1 permanent Privileged Role Admin at tenant root |
| Intune Compliance Policies | ⚠️ Partial | BitLocker and AV required; screen lock, Defender RTP, and Secure Boot not enforced |
| Intune Device Configuration | ✅ Strong | BitLocker XTS-AES 256, LAPS, ASR, WHfB, USB block all deployed and assigned |
| Purview DLP | ❓ Unverified | Cannot query via current API scopes; must verify Enforce mode in Purview portal |
| Sensitivity Labels | ❓ Unverified | Cannot query via current API scopes; must verify in Purview portal |
| Audit & Reporting | ⚠️ Partial | `displayConcealedNames=true` hides identities; audit retention not verifiable via Graph |

### Top Priority Gaps

1. **`IAC - INTUNE - GRANT - RequireCompliantDevice` is REPORT-ONLY** — unmanaged devices can reach all apps including PHI. Highest single HIPAA risk item.
2. **3 permanent Global Administrator assignments** at tenant root. Should be just-in-time only (except break-glass).
3. **No screen lock inactivity timeout** enforced on physical Windows or macOS endpoints. HIPAA §164.312(a)(2)(iii) automatic logoff requirement not met.
4. **Phishing-resistant MFA for admin daily logins is REPORT-ONLY** — admins use standard Authenticator push, not FIDO2/passkey for general access.
5. **Audit log retention not verified** — default 90-day retention violates HIPAA §164.530(j) 6-year documentation requirement.

---

## Section 1 — Identity & Access: Conditional Access

49 Conditional Access policies were retrieved from the tenant and analysed for HIPAA alignment.

### 1.1 Legacy Authentication Block — CIS 4.8 / HIPAA §164.312(d)

> ✅ **IMPLEMENTED** — `IAC - GLOBAL – BLOCK - Legacy Authentication` (ENABLED)

- Policy targets `clientAppTypes: ["exchangeActiveSync","other"]` across All apps for All users. Grant: block.
- No exclusions observed that would permit legacy protocol bypass.
- A secondary Microsoft-managed "Baseline Security Mode: Block legacy authentication" exists but is report-only; the custom IAC policy provides active enforcement.
- **Action:** Confirm no service accounts or connectors depend on Basic Auth / SMTP AUTH before treating this as fully closed.

---

### 1.2 MFA for All Users — CIS 6.3 / HIPAA §164.312(d)

> ✅ **IMPLEMENTED** — `IAC - GLOBAL - GRANT - MFA - AllUsers` (ENABLED)

- Scope: All users, All apps, all client app types. Grant: `mfa`.
- Admin MFA: `IAC - GLOBAL - GRANT - MFA - AllAdmins` (enabled).
- Guest MFA: `IAC - GLOBAL - GRANT - MFA - B2B-Guest` and `IAC - GLOBAL - GRANT - MFA - Mixed-Guests` (both enabled).

---

### 1.3 Phishing-Resistant MFA — CIS 6.3 / HIPAA §164.308(a)(5)(ii)(C)

> ⚠️ **PARTIAL** — Enforced for protected actions only; admin daily access is report-only

- `IAC - GLOBAL - GRANT - PhishResist - ProtectedActions-CA`: **ENABLED** — phishing-resistant MFA required for CA policy modifications only.
- `IAC - GLOBAL - GRANT - MFA-Passkeys - ADM-Users`: **REPORT-ONLY** — phishing-resistant MFA for all admin logins not enforced.
- Microsoft-managed Baseline policy for admin phishing-resistant MFA: **REPORT-ONLY**.

> 🔴 **HIPAA Action:** Promote `IAC - GLOBAL - GRANT - MFA-Passkeys - ADM-Users` from report-only to enabled. Admins with PHI system access should authenticate with FIDO2 or passkeys for all sessions, not only CA policy changes.

---

### 1.4 Compliant/Managed Device Requirement — CIS 1.1 / HIPAA §164.310(d)(2)(iii)

> ❌ **GAP** — `IAC - INTUNE - GRANT - RequireCompliantDevice` is REPORT-ONLY

- Policy scope: All users, All apps. Grant: `compliantDevice OR domainJoinedDevice`.
- MAM for Office 365 mobile IS enforced (`IAC - INTUNE - GRANT - MAM - Protection`: enabled) — mobile email/Teams is protected.
- SharePoint managed-device requirement is also report-only.
- **Effect:** Users can access Exchange Online and SharePoint from personal, unmanaged PCs with only MFA — no device health check performed.

> 🔴 **HIPAA Critical Gap:** This is the highest-priority item. Enforce `RequireCompliantDevice` after validating that all active users have enrolled, compliant devices. A phased rollout (pilot group first) is strongly recommended to avoid productivity disruption.

---

### 1.5 Session Controls & Sign-In Frequency — CIS 4.3 / HIPAA §164.312(a)(2)(iii)

> ✅ **IMPLEMENTED** — Multiple enforced session frequency policies

| Policy | State | Control Value |
|---|---|---|
| IAC - GLOBAL – SESSION – Admin Persistence (4 Hours) | Enabled | signInFrequency: 4 hours — all admins |
| IAC - GLOBAL – SESSION – All Users Persistence (9-12 Hours) | Enabled | signInFrequency: 12 hours — all users |
| IAC - APP - SESSION - O365 - Timeoutsettings | Enabled | everyTime + persistentBrowser=never — O365 browser |
| IAC - P2 - APP - SESSION - PIM - Reauthentication | Enabled | signInFrequency: everyTime — PIM activations |
| IAC - GLOBAL - SESSION - Windows - TokenProtection | **Report-Only** | Token binding to device — NOT enforced |

- CA session policies cover web/browser sessions. Physical device screen lock is a separate Intune requirement — see Section 4.
- Token protection remains report-only. Tokens stolen from Windows devices can be replayed from other machines — a meaningful PHI exfiltration risk.

---

### 1.6 Risk-Based Conditional Access — CIS 8.11 / HIPAA §164.308(a)(1)(ii)

> ✅ **IMPLEMENTED** — All five Entra ID P2 risk policies enabled

| Policy | Risk Trigger | Response | State |
|---|---|---|---|
| IAC - P2 - GLOBAL - GRANT - High-Risk Sign-Ins | signInRisk: high | MFA AND riskRemediation (AND operator) | Enabled |
| IAC - P2 - GLOBAL - GRANT - Medium-Risk Sign-Ins | signInRisk: medium | MFA required | Enabled |
| IAC - P2 - GLOBAL - BLOCK - High-Risk Users | userRisk: high | Block (immediate) | Enabled |
| IAC - P2 - GLOBAL - GRANT - Medium-Risk Users | userRisk: medium | MFA required | Enabled |
| IAC - P2 - GLOBAL - BLOCK - RiskyUsers - RegisterSecurityInfo | userRisk: high+medium | Block security info registration | Enabled |

- High-risk sign-in uses AND operator (MFA + riskRemediation) — stronger than MFA alone; forces SSPR remediation flow.
- High-risk users are immediately blocked outright — appropriate for HIPAA environments.

---

### 1.7 Additional Attack Vector Blocks

> ✅ **IMPLEMENTED** — Device Code, Auth Transfer, Unsupported Platforms, Country Block all enforced

- **Device code flow:** BLOCKED (enabled) — prevents adversary-in-the-middle device code phishing.
- **Authentication transfer:** BLOCKED (enabled) — prevents cross-device session hand-off abuse.
- **Unsupported device platforms:** BLOCKED (enabled).
- **Country block:** Two enabled policies — geographic restriction active. Validate allowed country list is tightly scoped to operational locations.

---

### 1.8 Report-Only and Disabled Policy Gaps

> ❌ **GAP** — Security-critical policies not yet enforced

| Policy Name | State | HIPAA Risk if Not Enforced |
|---|---|---|
| IAC - ZTCA - GLOBAL – BLOCK – Admin Portal | Report-Only | Admin portals accessible from untrusted/personal networks |
| IAC - APP - SESSION - SPO - AllowLimitedAccess | Report-Only | PHI documents downloadable from unmanaged browser sessions |
| IAC - INTUNE - SESSION - BlockFileDownloads-UnmanagedDevices | Report-Only | No MCAS file-download blocking on unmanaged browsers |
| IAC - APP - BLOCK - SPO - NonTrustedLocations | Report-Only | SharePoint accessible from any network location |
| IAC - GLOBAL - SESSION - Windows - TokenProtection | Report-Only | Token replay attacks possible from stolen tokens |
| IAC - GLOBAL - GRANT - MFA - RegisterSecurityInfo | Report-Only | Users can change MFA methods without existing MFA challenge |
| IAC - WORKLOAD - BLOCK - RiskyServicePrincipals | Disabled | Risky service principals not blocked — PHI integration risk |
| IAC - WORKLOAD - BLOCK - EntraConnectIDSync IP | Disabled | Sync account not IP-restricted — hybrid identity attack surface |

---

## Section 2 — Authentication Methods

**CIS 6.3 / HIPAA §164.308(a)(5)**

| Method | State | Assessment |
|---|---|---|
| FIDO2 / Passkeys | Enabled — All Users | ✅ Phishing-resistant. Device-bound and synced passkey profiles. Attestation enforced at registration. Key restriction AAGUIDs configured. |
| Microsoft Authenticator | Enabled — All Users | ✅ Number matching enabled. Display location info enabled. Companion app disabled. Anti-fatigue controls maximally configured. |
| TAP (Temporary Access Pass) | Enabled — One-time, 60 min | ✅ One-time use only — appropriate for onboarding and recovery flows. |
| Hardware OATH | Enabled — All Users | ✅ Physical token support available for high-security clinical roles. |
| Software OATH (TOTP apps) | Enabled — one group | ⚠️ TOTP apps are phishable unlike FIDO2. Investigate which group has this enabled and migrate to FIDO2 or restrict further. |
| SMS OTP | Disabled | ✅ SIM-swap and SS7 attack vector eliminated. |
| Voice Call | Disabled | ✅ Vishing attack vector eliminated. |
| Email OTP | Disabled | ✅ Correctly disabled. |
| Certificate-Based Auth (CBA) | Disabled | Neutral — evaluate for privileged/clinical users with smart cards or PIV credentials. |
| SSPR Registration Campaign | Enabled — targets all users for FIDO2 | ✅ Enforced registration after snooze limit. Two accounts excluded — verify these are break-glass/service accounts only. |

---

## Section 3 — Privileged Access Management

**CIS 6.8 / HIPAA §164.308(a)(3)**

### 3.1 Permanent Privileged Role Assignments

> ❌ **GAP** — Standing Global Admin and Privileged Role Admin at tenant root

| Role | Role Definition ID | Permanent Assignments | HIPAA Risk Level |
|---|---|---|---|
| Global Administrator | 62e90394-69f5-4237-9190-012177145e10 | 3 at tenant root | CRITICAL — full tenant control, can access all PHI data and audit logs |
| Privileged Role Administrator | e8611ab8-c189-46e8-94e1-60213ab1f814 | 2 at tenant root | CRITICAL — can elevate any user to Global Admin, same blast radius as GA |
| Exchange Administrator | 29232cdf-9323-42fd-ade2-1d097af3e4de | 2 at tenant root | HIGH — full mailbox access including PHI communications |
| Compliance Administrator | 17315797-102d-40b4-93e0-432062caca18 | 1 at tenant root | HIGH — Purview audit data, DLP policies, label settings |
| Security Administrator | baf37b3a-610e-45da-9e62-d9d1e5e8914b | 1 at tenant root | HIGH — can modify Defender and Sentinel alerting |
| SharePoint Administrator | 9360feb5-f418-4baa-8175-e2a00bac4301 | 1 at tenant root | HIGH — full SharePoint including PHI document libraries |
| Intune Administrator | 729827e3-9c14-49f7-bb1b-9608f156bbb8 | 1 at tenant root | HIGH — can modify device compliance to bypass CA controls |
| Application Administrator | 9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3 | 1 at tenant root | MEDIUM — can create service principals accessing PHI |

> ⚠️ **PIM Verification Note:** The API token for this session did not include `RoleManagement.Read.Directory`. PIM eligible assignments could not be confirmed. Some accounts above may also have PIM eligible assignments — verify in Entra ID > Identity Governance > Privileged Identity Management > Azure AD Roles > Assignments.

#### PIM Remediation Guidance

- Break-glass accounts (maximum 2) may retain permanent Global Admin. All others must be PIM-eligible only.
- Privileged Role Administrator permanent assignments must be PIM-eligible — this role has the same blast radius as Global Admin.
- Exchange, Compliance, Security, SharePoint, and Intune Admins should be eligible with maximum 4–8 hour activation windows requiring MFA and justification.
- Consider requiring phishing-resistant MFA as the activation requirement for Global Admin and Privileged Role Admin PIM activations.
- Configure quarterly access reviews for all privileged roles via Entra ID Governance.

---

### 3.2 Authorization Policy Review

| Setting | Value | Assessment |
|---|---|---|
| allowedToCreateApps | false | ✅ Users cannot register app registrations — reduces shadow IT PHI integration risk |
| allowedToCreateSecurityGroups | false | ✅ Prevents self-service group-based access expansion |
| allowedToCreateTenants | false | ✅ |
| guestUserRoleId | Member-equivalent (2af84b1e) | ⚠️ Guests have member-level directory permissions. Restrict to limited guest access for HIPAA. |
| blockMsolPowerShell | false | ❌ Legacy MSOL PowerShell not blocked — uses basic auth, bypasses modern auth controls. Set to true. |
| allowUserConsentForRiskyApps | false | ✅ Users cannot consent to risky third-party apps |
| allowedToReadBitlockerKeysForOwnedDevice | false | ✅ Only IT/admin can retrieve BitLocker recovery keys |

---

## Section 4 — Device Compliance Policies

**CIS 7.1 / HIPAA §164.310(d)**

### 4.1 Windows Compliance Policy — `IAC - Win - Baseline - Compliance - Policy`

| Setting | Configured Value | Assessment |
|---|---|---|
| OS Minimum Version | 10.0.19045 (Win10 22H2) | ✅ Minimum patch baseline enforced |
| BitLocker Required | true | ✅ HIPAA §164.312(a)(2)(iv) encryption at rest |
| Storage Encryption | true | ✅ |
| TPM Required | true | ✅ Hardware security root of trust |
| Password Required | true | ✅ |
| Password Block Simple | true | ✅ |
| Password Required to Unlock from Idle | true | ✅ Re-authentication on resume |
| **Password Minutes of Inactivity Before Lock** | **null (not configured)** | **❌ HIPAA §164.312(a)(2)(iii): No screen lock timeout in compliance policy.** |
| Password Expiration Days | 730 (2 years) | ⚠️ CIS recommends max 365 days. NIST 800-63B allows longer/no expiry when strong MFA is enforced. |
| Antivirus Required | true | ✅ Vendor-agnostic antivirus required |
| Defender Enabled (specific) | false | ⚠️ Defender specifically not required; any AV satisfies antivirus requirement. Consider `defenderEnabled=true`. |
| Defender Real-Time Protection | false | ⚠️ RTP not required by compliance — Intune config profiles enforce Defender separately but this is a defence-in-depth gap. |
| Secure Boot | false | ⚠️ Secure Boot not required. Should be enabled for HIPAA-class endpoints. |
| Code Integrity (HVCI) | false | ⚠️ Memory Integrity not required. Protects against kernel-level malware targeting PHI. |
| LAPS Compliance Script | Configured (custom) | ✅ Validates Windows LAPS is processing on device |

---

### 4.2 macOS Compliance Policy — `macOS - D - Compliance`

| Setting | Configured Value | Assessment |
|---|---|---|
| OS Minimum Version | 14.0 (Sonoma) | ✅ Current major release enforced |
| Storage Encryption (FileVault) | true | ✅ HIPAA encryption at rest |
| Password Required | true | ✅ |
| Firewall Enabled | true | ✅ |
| **Password Inactivity Lock** | **null (not configured)** | **❌ Same gap as Windows — no screen lock timeout in macOS compliance.** |
| System Integrity Protection (SIP) | false | ⚠️ SIP not required; prevents unsigned kernel extensions and rootkits |
| Gatekeeper | notConfigured | ⚠️ Should be set to `macAppStore` or `macAppStoreAndIdentifiedDevelopers` |
| Device Threat Protection (MDE level) | false | ⚠️ MDE threat protection level not enforced by compliance policy |

---

## Section 5 — Device Configuration

**CIS 3.9, 10.1 / HIPAA §164.310(d)**

### 5.1 BitLocker Encryption (Windows)

> ✅ **IMPLEMENTED** — `Win - Security - D - Bitlocker`: assigned, XTS-AES 256 all drive types

| Setting | Configured Value | Assessment |
|---|---|---|
| OS Drive Encryption | Full disk (XTS-AES 256) | ✅ HIPAA §164.312(a)(2)(iv), strongest Windows encryption |
| Fixed Drive Encryption | Full disk (XTS-AES 256) | ✅ |
| Removable Drive | BitLocker required for write access | ✅ HIPAA §164.310(d)(1) removable media encrypted |
| TPM Authentication | TPM-only (no startup PIN) | Acceptable for managed fleet; consider TPM+PIN for highest-sensitivity PHI workstations |
| Recovery Password Rotation | Enabled for AAD-joined devices | ✅ Recovery keys rotate after use |
| Recovery Escrow | AAD/AD backup configured | ✅ Recovery keys backed up for IT access |
| Silent Encryption | true (no user prompt) | ✅ |
| Require Device Encryption | true | ✅ |
| Encryption Method | XTS-AES 256 (OS, fixed, removable) | ✅ NIST recommended, exceeds minimum HIPAA requirement |

> ⚠️ **Note:** `IAC - Windows - Bitlocker Encryption Policy` (a separate configuration policy) exists but is **NOT assigned**. This is a duplicate policy — review and either remove or merge to avoid configuration drift.

---

### 5.2 Removable Media Controls

> ✅ **IMPLEMENTED** — Windows and macOS USB controls deployed and assigned

- **Windows:** `IAC - Windows - Removable Storage Access` (assigned) — controls removable storage access.
- **macOS:** `Mac - Security - D - BlockUsbDevice` (assigned) — DDM Disk Management External Storage set to Disallowed; blocks all external USB/removable volumes on macOS 14+ supervised devices.
- **Missing:** No explicit Autorun/Autoplay disable policy found. CIS 10.3 requires Autorun disabled. Verify this is covered in the Windows 11 Security Baseline (37 settings) or add an explicit Settings Catalog item.

---

### 5.3 Endpoint Protection and Anti-Malware

> ✅ **IMPLEMENTED** — Comprehensive Defender stack deployed for Windows and macOS

| Profile | Platform | Assigned | Notes |
|---|---|---|---|
| Win - Defender - D - Next-Gen Protection Default | Windows | Yes | ✅ 27 settings, real-time protection defaults, HIPAA §164.308(a)(5)(ii)(B) |
| **Win - Defender - D - Disable Next-Gen Protection** | Windows | **Yes** | ⚠️ **REVIEW REQUIRED** — this policy disables next-gen protection. Verify target group excludes all PHI-capable devices. |
| Windows 11 Microsoft Defender Antivirus | Windows | Yes | ✅ 40 settings, comprehensive AV configuration |
| Windows 11 ASR Rules | Windows | Yes | ✅ Attack surface reduction rules enforced |
| Windows 11 Firewall | Windows | Yes | ✅ 10 settings, host-based firewall enforced |
| Windows 11 Security Baseline | Windows | Yes | ✅ 37 settings baseline applied |
| Win - Defender - D - ASR Audit | Windows | Yes | ✅ Audit mode data collection active |
| Mac - Security - D - Defender for Endpoint Preferences | macOS | Yes | ✅ MDE configured on macOS |
| Mac - Security - D - MDE Onboarding - Package | macOS | Yes | ✅ MDE onboarded to macOS fleet |

> 🔴 **Action Required:** `Win - Defender - D - Disable Next-Gen Protection` is assigned with 15 settings. Review target group immediately. If any PHI-capable device is in scope, this is a HIPAA §164.308(a)(5)(ii)(B) violation.

---

### 5.4 Screen Lock / Automatic Logoff — HIPAA §164.312(a)(2)(iii)

> ❌ **GAP** — No screen lock timeout for physical Windows or macOS endpoints

- `IAC - Windows365 - SessionTimeout` (assigned): 30-minute inactivity timeout for **Windows 365 Cloud PCs ONLY**. Physical devices are not covered.
- HIPAA §164.312(a)(2)(iii) requires automatic logoff. CIS 4.3 specifies maximum 15 minutes for workstations, 2 minutes for mobile.
- Both Intune compliance policies have `passwordMinutesOfInactivityBeforeLock = null` — devices are not marked non-compliant for having no screen lock timeout.

> 🔴 **Remediation Required:** Create a Settings Catalog policy targeting physical Windows endpoints with Machine Inactivity Limit set to 900 seconds (15 minutes). Create a macOS Restrictions profile with the equivalent timeout. Update both compliance policies to enforce the screen lock requirement.

---

### 5.5 Identity and Credential Security

> ✅ **IMPLEMENTED** — WHfB, LAPS, and Platform SSO configured and assigned

- `Win - Authentication - D - WHfB` (assigned): Windows Hello for Business with TPM required and cloud trust — phishing-resistant on-device authentication.
- `Win - Access Control - D - LAPS` (assigned): 6 settings — Local Administrator Password Solution managing local admin credentials.
- `Mac - System - Platform SSO` (assigned): Centralises macOS login through Entra ID credentials.

---

## Section 6 — Purview: DLP, Labels, and Audit

**HIPAA §164.312(b)**

> ⚠️ **API Scope Limitation:** Purview DLP policies and sensitivity labels are not accessible via Microsoft Graph with the current delegated token. The scopes `eDiscovery.Read.All` and `InformationProtectionPolicy.Read.All` were not present. All items below require manual verification in the Purview portal (https://compliance.microsoft.com).

---

### 6.1 DLP Policies — CIS 3.13 / HIPAA §164.312(e)(2)

Verify in **Purview portal > Data loss prevention > Policies:**

| Expected Policy | What to Check | Required State |
|---|---|---|
| HIPAA - PHI Exfiltration Prevention | Mode field | Enforce (not `TestWithNotifications` or `TestWithoutNotifications`) |
| HIPAA - Privileged PHI Controls | Mode field | Enforce — blocks all external sharing for Healthcare - Privileged label |
| HIPAA - Copilot PHI Boundary | Mode field AND label conditions in portal | Enforce — AND verify label conditions were manually added in portal post-deployment (API limitation) |
| Any HIPAA policy | Locations scoped | Must include Exchange, SharePoint, OneDrive, Teams, and Endpoint (devices) |
| DLP Alerts | Alert review cadence documented | Alerts reviewed at minimum weekly per CIS 8.11 |

Run in Security & Compliance PowerShell to verify:

```powershell
Get-DlpCompliancePolicy | Where-Object { $_.Name -like 'HIPAA*' } | Select-Object Name, Mode, Enabled | Format-Table -AutoSize
```

---

### 6.2 Sensitivity Labels — CIS 3.3 / HIPAA §164.312(a)(1)

Verify in **Purview portal > Information protection > Labels:**

- **Healthcare - Confidential:** Encryption enabled, scoped to authenticated clinical staff, auto-labeling configured for PHI SITs (SSN + Medical Terms).
- **Healthcare - Privileged:** Encryption enabled, decryption restricted to `Purview-Medical-Privileged` group ONLY. PIM for Groups configured so clinical staff activate JIT membership.
- **Healthcare - Research:** Encryption enabled, restricted to `Purview-Medical-Research` group.
- **Label policies:** Labels NOT published org-wide — scoped to clinical staff only.
- **`Purview-Medical-Privileged` group membership:** Export and verify. Standing members beyond the Compliance Lead and Privacy Officer are a least-privilege gap requiring PIM for Groups remediation.

Run in PowerShell to check label encryption:

```powershell
Get-Label | Where-Object { $_.DisplayName -like 'Healthcare*' } | Select-Object DisplayName, EncryptionEnabled, EncryptionProtectionType | Format-Table
```

---

### 6.3 Audit Configuration — CIS 8.1–8.2 / HIPAA §164.312(b)

> ⚠️ **PARTIAL** — `displayConcealedNames=true` observed; full audit config requires PowerShell

| Control | Observed / Required | Assessment |
|---|---|---|
| displayConcealedNames (M365 Reports) | **TRUE** (observed via Graph) | ⚠️ User identities hidden in M365 usage/activity reports. Impedes HIPAA audit reviews. Set to false or ensure Compliance Admins can override. |
| UnifiedAuditLogIngestionEnabled | Not verifiable via Graph | ❌ Run `Get-AdminAuditLogConfig` in Exchange Online PowerShell. Must be `True`. |
| Audit Log Retention | Not verifiable via Graph | ❌ Default is 90 days. HIPAA §164.530(j) requires 6 years. Must have Audit Premium + custom retention policy, or Sentinel/Log Analytics long-term retention. |
| Purview Audit Premium | Not verifiable via Graph | ❌ Audit Premium required for >1 year retention (extendable to 10 years with custom policy). |
| Microsoft Sentinel | Not verified in this assessment | ⚠️ Sentinel with M365 Defender, Entra ID, and Office 365 connectors and HIPAA/HITRUST workbook should be confirmed in Azure portal. |

> 🔴 **Common HIPAA Gap:** Default M365 audit log retention of 90 days is the most frequently cited HIPAA gap in M365 assessments. If Audit Premium has not been enabled with a retention policy of at least 6 years, this is a direct documentation compliance violation under HIPAA §164.530(j).

---

## Section 7 — HIPAA Control Scorecard

| CIS Control | HIPAA Citation | IG | Status | Priority Action |
|---|---|---|---|---|
| 1.1 Asset Inventory | §164.310(d)(2)(iii) | 1 | ⚠️ Partial | Verify Intune enrollment = 100% of PHI-capable devices |
| 3.2 Data Inventory | §164.310(d)(2)(iii) | 1 | ❓ Unverified | Run Purview Content Explorer PHI scan |
| 3.3 Access Control Lists | §164.308(a)(3), §164.312(a)(1) | 1 | ⚠️ Partial | Verify Purview-Medical-Privileged membership + PIM for Groups |
| 3.5 Data Disposal | §164.310(d)(2)(i) | 1 | ❓ Unverified | Verify Purview retention policies with Healthcare label scope |
| 3.9 Removable Media Encryption | §164.310(d)(1) | 2 | ✅ Implemented | BitLocker + Mac USB block enforced; validate compliance report |
| 3.10 Encrypt in Transit | §164.312(e) | 2 | ✅ Implemented | TLS + label encryption in transit; verify DLP email encryption rule |
| 3.11 Encrypt at Rest | §164.312(a)(2)(iv) | 2 | ✅ Implemented | BitLocker XTS-AES 256 + FileVault + label AIP encryption |
| 3.13 DLP Solution | §164.312(e)(2) | 3 | ❓ Unverified | Verify HIPAA DLP policies in Enforce mode in Purview portal |
| 3.14 Log Data Access | §164.312(b), §164.312(c) | 3 | ⚠️ Partial | Verify Audit Premium + 6-year retention policy |
| 4.3 Session Locking | §164.312(a)(2)(iii) | 1 | ❌ Gap | Add screen lock policy max 15 min for physical Windows + macOS |
| 5.1 Account Inventory | §164.312(a)(2)(i) | 1 | ⚠️ Partial | Configure quarterly access reviews for healthcare groups |
| 6.1 Access Granting | §164.312(a)(2)(i) | 1 | ⚠️ Partial | Verify Entitlement Management access packages for clinical roles |
| 6.2 Access Revoking | §164.308(a)(3)(ii)(C) | 1 | ⚠️ Partial | Verify Lifecycle Workflows leaver process removes PHI group memberships |
| 6.8 RBAC | §164.308(a)(3–4) | 3 | ❌ Gap | Convert permanent privileged roles to PIM eligible (8+ roles) |
| 7.1 Vuln Management Process | §164.308(a)(1)(ii) | 1 | ✅ Implemented | Intune compliance + CA compliant device (once enforced) |
| 7.2 Remediation Process | §164.308(a)(1)(ii) | 1 | ⚠️ Partial | Document remediation SLA by severity (Critical/High/Medium) |
| 8.1 Audit Log Process | §164.312(b) | 1 | ❌ Gap | Verify audit retention 6+ years and Unified Audit Log enabled |
| 8.2 Collect Audit Logs | §164.312(b) | 1 | ❓ Unverified | Verify `Get-AdminAuditLogConfig` and all workload audit events |
| 8.11 Audit Log Reviews | §164.308(a)(1)(ii)(D) | 2 | ⚠️ Partial | Sentinel analytics rules needed for PHI-specific anomaly alerting |
| 10.1 Anti-Malware | §164.308(a)(5)(ii)(B) | 1 | ✅ Implemented | Defender stack deployed; review Disable Next-Gen Protection scope |
| 10.3 Disable Autorun | §164.310(d)(1) | 1 | ❓ Unverified | Verify Autorun disabled in Windows 11 Security Baseline or add policy |
| 10.4 Scan Removable Media | §164.310(d)(1) | 2 | ✅ Implemented | USB block + removable storage access controls deployed |
| 11.1 Data Recovery Process | §164.308(a)(7) | 1 | ❓ Unverified | Verify M365 Backup configured and restore tested with documentation |
| 11.2 Automated Backups | §164.308(a)(7)(ii)(A) | 1 | ❓ Unverified | Verify M365 Backup automated schedule and failure alerting |
| 13.1 SIEM/Alerting | §164.312(b) | 2 | ❓ Unverified | Confirm Sentinel with HIPAA/HITRUST workbook deployed |
| 14.1 Security Awareness | §164.308(a)(5)(i) | 1 | Process only | Document training program with HIPAA modules + completion records |
| 14.3 Auth Best Practices | §164.308(a)(5)(ii)(C–D) | 1 | ✅ Implemented | MFA enforced technically; verify training covers passkeys/phishing |
| 14.4 Data Handling Training | §164.310(d)(2)(i) | 1 | Process only | Verify sensitivity label training for clinical staff |
| 14.6 Incident Reporting Training | §164.308(a)(6)(ii) | 1 | Process only | Document breach reporting procedure accessible to all workforce |
| 15.4 Vendor Contracts / BAA | §164.308(b) | 2 | ⚠️ Verify | Confirm Microsoft HIPAA BAA accepted in Microsoft Admin Center |
| 15.5 Assess Service Providers | §164.308(a)(8) | 3 | Process only | Document annual SOC 2 review for PHI-touching vendors |
| 17.1 IR Personnel | §164.308(a)(2) | 1 | Process only | Document named HIPAA Security Officer with Purview/Sentinel access |
| 17.3 IR Reporting Process | §164.308(a)(6)(ii) | 1 | Process only | Document and test incident reporting procedure |
| 17.4 IR Process | §164.308(a)(6–7) | 2 | Process only | IR plan must reference 60-day HIPAA breach notification timeline |
| 17.7 IR Exercises | §164.308(a)(7)(ii)(D) | 2 | Process only | Annual PHI breach tabletop with documented corrective actions |
| 17.8 Post-Incident Reviews | §164.308(a)(8) | 2 | Process only | After-action review process with lessons-learned tracking |
| 18.1 Pen Test Program | §164.308(a)(8) | 2 | Process only | Pen test scope to include M365/cloud attack surface |
| 18.3 Remediate Pen Test Findings | §164.308(a)(1)(ii)(B) | 2 | Process only | Findings tracked to closure with severity SLAs |

---

## Section 8 — Immediate Action Plan

### Priority 1 — Act Within 30 Days (Critical HIPAA Gaps)

| # | Action Item | Portal / Tool | HIPAA Citation |
|---|---|---|---|
| 1 | Enforce `RequireCompliantDevice` CA policy (switch from report-only to enabled after validating device compliance rates; pilot group first) | Entra CA Portal | §164.310(d)(2)(iii), §164.312(d) |
| 2 | Add screen lock inactivity policy (max 15 min) for physical Windows and macOS endpoints via Intune Settings Catalog; update compliance policies | Intune Configuration | §164.312(a)(2)(iii) |
| 3 | Verify/enable Purview Audit Premium and configure retention policy ≥6 years, or confirm Sentinel Log Analytics long-term retention | Purview Audit + Sentinel | §164.530(j), §164.312(b) |
| 4 | Verify `UnifiedAuditLogIngestionEnabled = True` via Exchange Online PowerShell | Exchange Online PS | §164.312(b) |
| 5 | Accept the Microsoft HIPAA BAA in Microsoft Admin Center (Settings > Org Settings > Security & Privacy > HIPAA BAA) | Microsoft Admin Center | §164.308(b) — most-cited violation |
| 6 | Convert all non-break-glass permanent Global Admin and Privileged Role Admin assignments to PIM eligible | Entra PIM Portal | §164.308(a)(3)(ii)(B), CIS 6.8 |

---

### Priority 2 — Act Within 60 Days (High Risk)

| # | Action Item | Portal / Tool | HIPAA Citation |
|---|---|---|---|
| 7 | Enforce phishing-resistant MFA for all admin logins (promote `IAC - GLOBAL - GRANT - MFA-Passkeys - ADM-Users` from report-only to enabled) | Entra CA Portal | §164.308(a)(5)(ii)(C) |
| 8 | Enforce admin portal block on untrusted locations (`IAC - ZTCA - GLOBAL – BLOCK – Admin Portal`) | Entra CA Portal | §164.308(a)(3) |
| 9 | Verify all HIPAA DLP policies are in Enforce mode via PowerShell | Purview Compliance PS | §164.312(e)(2) |
| 10 | Verify Copilot PHI Boundary DLP policy has label conditions added manually in portal | Purview DLP Portal | §164.312(e)(2)(i) |
| 11 | Re-enable `IAC - WORKLOAD - BLOCK - RiskyServicePrincipals` once Workload ID licensing confirmed | Entra CA Portal | §164.308(a)(1)(ii) |
| 12 | Restrict guest user role from member-equivalent to limited guest in External Identities settings | Entra External Identities | §164.312(a)(1) |
| 13 | Set `blockMsolPowerShell = true` in Entra Authorization Policy | Entra Admin / Graph API | §164.312(d) |
| 14 | Review `Win - Defender - D - Disable Next-Gen Protection` target group — ensure no PHI-capable devices are scoped | Intune Configuration | §164.308(a)(5)(ii)(B) |

---

### Priority 3 — Act Within 90 Days (Process and Administrative Controls)

- Document joiner/mover/leaver process for clinical staff with PHI access (CIS 6.1, 6.2).
- Configure Entra ID Governance Access Reviews for PHI-access groups on quarterly cadence.
- Document HIPAA Security Officer designation and test incident reporting procedure.
- Draft IR plan with explicit 60-day breach notification workflow referencing Defender XDR and Purview Audit as forensic tools.
- Schedule annual HIPAA tabletop exercise covering PHI breach scenario and document results.
- Verify M365 Backup is configured for Exchange, SharePoint, and OneDrive and document last successful restore test.
- Confirm Sentinel is deployed with M365 Defender, Entra ID, and Office 365 connectors and HIPAA/HITRUST workbook active.
- Document security awareness training program with HIPAA-specific modules and LMS completion record retention.
- Verify all third-party ISVs with access to PHI have signed BAAs on file.

---

## Appendix — API Scope Limitations

### Scopes Present in This Assessment

| Scope | Data Accessed |
|---|---|
| Policy.Read.All | Conditional Access policies, Authentication Methods policy, Authorization policy |
| DeviceManagementConfiguration.Read.All | Intune configuration policies, compliance policies, enrollment configs |
| DeviceManagementEndpointSecurity.Read.All | Intune endpoint security profiles |
| Directory.Read.All | Entra ID users, groups, role assignments, service principals |
| ReportSettings.Read.All | Admin report settings (`displayConcealedNames` value) |

### Scopes Missing — Data Not Assessed

| Missing Scope | Data Not Assessed |
|---|---|
| RoleManagement.Read.Directory | PIM eligible assignments — could not verify JIT vs. permanent via Graph |
| InformationProtectionPolicy.Read.All | Purview sensitivity labels and label policies |
| eDiscovery.Read.All | Purview DLP policies, compliance score, HIPAA Compliance Manager assessment |
| SecurityEvents.Read.All | Sentinel workspace connection status and analytics rules |

These gaps can be closed by re-running the assessment with an account that has Global Reader or equivalent permissions, or by running the dedicated PowerShell assessments referenced in this document.

---

## References

- [CIS Controls v8.1](https://www.cisecurity.org/controls/v8)
- [HIPAA Security Rule — HHS](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [HIPAA Privacy Rule — HHS](https://www.hhs.gov/hipaa/for-professionals/privacy/index.html)
- [Microsoft HIPAA BAA](https://www.microsoft.com/en-us/trust-center/compliance/hipaa)
- [Purview DLP Policy Reference](https://learn.microsoft.com/en-us/purview/dlp-policy-reference)
- [Sensitivity Label Encryption](https://learn.microsoft.com/en-us/purview/encryption-sensitivity-labels)
- [Purview Audit Premium](https://learn.microsoft.com/en-us/purview/audit-premium)
- [Sentinel HIPAA/HITRUST Workbook](https://learn.microsoft.com/en-us/azure/sentinel/sentinel-solution)
- [Entra PIM Documentation](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/)
- [NIST SP 800-63B Authentication Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)

---

*M365 Healthcare Compliance Pack v1.0 | July 2026*
