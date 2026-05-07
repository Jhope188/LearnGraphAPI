# Conditional Access Configuration Export
**Tenant:** ConditionalAccess.tech  
**Export Date:** 2026-05-07  
**Exported By:** Lokka / Microsoft Graph API  
**Total CA Policies:** 34  

---

## Table of Contents

1. [CA Groups & Dynamic Queries](#1-ca-groups--dynamic-queries)
2. [Named Locations](#2-named-locations)
3. [Authentication Method Settings](#3-authentication-method-settings)
4. [Entra Security Settings](#4-entra-security-settings)
5. [Conditional Access Policies](#5-conditional-access-policies)
   - [GLOBAL — Block Policies](#global--block-policies)
   - [GLOBAL — Grant Policies](#global--grant-policies)
   - [GLOBAL — Session Policies](#global--session-policies)
   - [APP — Application Policies](#app--application-policies)
   - [INTUNE — Device Policies](#intune--device-policies)
   - [P2 — Risk-Based Policies](#p2--risk-based-policies)
   - [ZTCA — Zero Trust Policies](#ztca--zero-trust-policies)
   - [AGENT — Workload Identity Policies](#agent--workload-identity-policies)
   - [WORKLOAD — Service Account Policies](#workload--service-account-policies)
6. [Policy State Summary](#6-policy-state-summary)
7. [Enterprise Application Consent Policies](#7-enterprise-application-consent-policies)
8. [App Protection Policies (Intune MAM)](#8-app-protection-policies-intune-mam)

---

## 1. CA Groups & Dynamic Queries

### Exclusion & Structural Groups

| Group Name | Type | ID | Description |
|---|---|---|---|
| **CA - Breakglass** | Static | `b63c3682-06c6-45f0-9692-ee76b604b4f9` | Primary CA break-glass exclusion — excluded from ALL policies |
| **Azure-Breakglass** | Static | `62d67e66-2bc9-43cd-b00c-6326dae53d18` | Secondary break-glass group — excluded from most policies |
| **CA - GlobalExclusions** | Static | `e663a7ce-daec-4062-88b8-5970bfec8019` | Global exclusion group for selective policy bypass |
| **CA - TravelingUsers** | Static | `cc7f9bb7-425b-42fc-b025-311a1a3eb0f4` | Users excluded from country-block geo policy |
| **CA - ServiceAccounts** | Static | `6612d6d7-12c8-4cbd-8ad5-7460ae2a6579` | Service accounts subject to location-locked block policy |
| **CA - DeviceExclusions** | Static | `2d25c298-555e-4f26-9984-90dfb7eae325` | Users excluded from device compliance policies |
| **AVDUsers** | Static | `902993ed-96f7-4af6-825c-510dfc97b258` | Internal AVD users (excluded from AVD block policies) |
| **AVD-ExternalUsers** | Static | `9ee031a3-3551-4bc3-a81d-d6f0149ae329` | External AVD users (excluded from AVD geo/block policies) |
| **MFA-AUTH-Passkey** | Static | `1178bb5d-4f19-4b69-b33b-44eb7f5b39c9` | Users targeted for Passkey registration CA policy |

### Dynamic Groups

| Group Name | Type | ID | Dynamic Rule |
|---|---|---|---|
| **ADM-Users-Dynamic** | Dynamic | `5f96c57d-380f-4872-97ff-cfd74ef1ac1a` | `(user.userPrincipalName -contains ".adm")` |
| **CA-P1InternalLicensedUsers** | Dynamic | `2774d88c-ef93-4704-92a4-c79fb68394c6` | `(user.assignedPlans -any (assignedPlan.servicePlanId -eq "41781fb2-bc02-4b7c-bd55-b576c07bb09d" and assignedPlan.capabilityStatus -eq "Enabled"))` |
| **CA-P2InternalLicensedUsers** | Dynamic | `17adf1de-b7f1-418e-a89f-5054bd37a69e` | `(user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" and assignedPlan.capabilityStatus -eq "Enabled"))` |

> **Note on Dynamic Rules:**  
> - `ADM-Users-Dynamic` matches any UPN containing `.adm` — used as include target for the Admin Passkeys policy  
> - `CA-P1InternalLicensedUsers` targets users with Entra ID P1 (servicePlanId `41781fb2...`)  
> - `CA-P2InternalLicensedUsers` targets users with Entra ID P2 (servicePlanId `eec0eb4f...`)  

---

## 2. Named Locations

### Country Locations

| Name | ID | Type | Countries / Regions | Include Unknown |
|---|---|---|---|---|
| **IAC - AllowedCountries** | `1d421232-4f10-4436-9883-27d9bd3f64cd` | Country | 🇬🇧 GB, 🇺🇸 US | No |
| **IAC - Blocked Countries** | `1267ac22-ce4d-4a2e-ae00-fd3a3a7f4748` | Country | AF, BR, BY, CN, CU, DZ, IQ, IR, KP, NG, NL, PK, RU, SD, SY, VE, VN | **Yes** |

> **IAC - Blocked Countries** has `includeUnknownCountriesAndRegions: true` — any sign-in from an unresolvable IP is also blocked.

### IP Named Locations

| Name | ID | Trusted | IP Ranges |
|---|---|---|---|
| **IAC - Trusted Locations (IP)** | `0403d368-f07f-4e4c-b75d-aa169d5b6683` | ❌ No | `21.72.155.150/32`, `71.84.250.228/32` |
| **IAC - Inforcer (IP-US)** | `02b44e26-26f2-49fd-ad85-eb6c7af69e17` | ❌ No | `172.177.20.193/32`, `20.1.160.1/32` |
| **IAC - EntraConnect(IP)** | `0836d6a3-0a77-4a23-b6fe-c86643f1811d` | ❌ No | `128.85.196.27/32` |

> ⚠️ **Observation:** All IP named locations have `isTrusted: false`. Policies using `AllTrusted` as an exclude location will NOT match these. Policies excluding `0403d368...` by ID will work, but the "IAC - Trusted Locations" name does not benefit from the Entra "trusted" flag for risk scoring purposes.

---

## 3. Authentication Method Settings

**Policy Version:** 1.5  
**Last Modified:** 2026-05-07

### Method Status

| Method | State | Scope | Notes |
|---|---|---|---|
| **FIDO2 / Passkeys** | ✅ Enabled | All Users + `MFA-AUTH-Passkey` group | Attestation enforced; AAGUID allow-list active; two passkey profiles configured |
| **Microsoft Authenticator** | ✅ Enabled | All Users | Number matching: **Enabled** · Software OATH: enabled |
| **Temporary Access Pass (TAP)** | ✅ Enabled | All Users | Default 60 min, max 480 min; multi-use by default |
| **Software OATH** | ✅ Enabled | `CA - Breakglass` group only | Scoped to break-glass accounts |
| **Email OTP** | ✅ Enabled | External IDs only (`allowExternalIdToUseEmailOtp: enabled`) | No internal targets configured |
| **SMS** | ❌ Disabled | — | Correctly disabled (phishing risk) |
| **Voice Call** | ❌ Disabled | — | Correctly disabled |
| **Hardware OATH** | ❌ Disabled | — | |
| **X.509 Certificate (CBA)** | ❌ Disabled | — | |
| **QR Code + PIN** | ❌ Disabled | — | |
| **Verifiable Credentials** | ❌ Disabled | — | |
| **Federated Identity Credential** | ❌ Disabled | — | |

### FIDO2 Passkey Profiles

| Profile | ID | Passkey Types | Attestation | Key Restrictions |
|---|---|---|---|---|
| **Default passkey profile** | `00000000-0000-0000-0000-000000000001` | Device-bound only | Registration only | Allow-list: 2 AAGUIDs |
| **Synced-Passkey** | `090a10c7-ab99-4959-a96a-f48063788f50` | Synced (e.g. Apple/Google passkeys) | Disabled | None enforced |

**Allowed FIDO2 AAGUIDs (Default Profile):**
- `90a3ccdf-635c-4729-a248-9b709135078f`
- `de1e552d-db1d-4423-a619-566b625cdc84`

### Registration Campaign

| Setting | Value |
|---|---|
| State | `default` (Microsoft-managed) |
| Snooze Duration | 0 days |
| Enforce After Snoozes | Yes |
| Target Method | Microsoft Authenticator → All Users |

---

## 4. Entra Security Settings

| Setting | Value | Notes |
|---|---|---|
| **Security Defaults** | ❌ Disabled | Correct — CA policies are in use |
| **Authenticator Number Matching** | ✅ Enabled | All users — mitigates MFA fatigue attacks |
| **Authenticator App Information** | `default` | Not explicitly enforced |
| **Authenticator Location Display** | `default` | Not explicitly enforced |
| **Suspicious Activity Reporting** | `default` | All users |

---

## 5. Conditional Access Policies

> **Legend**
> - 🟢 **Enabled** — actively enforced
> - 🟡 **Report-Only** — logging only, not enforced
> - 🔴 **Disabled** — not active

### Custom Authentication Strength

All policies using an auth strength reference the same custom strength:

**"Modern MFA + TAP"** (`42de22a7-5339-4a58-b560-28565d53b14d`)  
Allowed combinations: `windowsHelloForBusiness`, `fido2`, `x509CertificateMultiFactor`, `temporaryAccessPassOneTime`, `temporaryAccessPassMultiUse`  
> ⚠️ This strength intentionally excludes SMS, voice, and push notifications — phishing-resistant methods only.

---

### GLOBAL — Block Policies

---

#### 🟢 IAC - GLOBAL - BLOCK - Device Code Auth Flow
`ID: 8b42eda3-6917-4ab4-afb2-e32c37520f9b` · **Enabled** · Created: 2026-05-04

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Auth Flow | `deviceCodeFlow` |
| Client App Types | All |
| Grant | **Block** |

> Blocks the OAuth 2.0 device authorization grant flow entirely. Prevents attacker-in-the-middle device code phishing.

---

#### 🟢 IAC - GLOBAL – BLOCK - Legacy Authentication
`ID: 9eab445f-7f21-479a-85c9-29769512067e` · **Enabled** · Created: 2026-05-04

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Client App Types | `exchangeActiveSync`, `other` |
| Grant | **Block** |

> Blocks all legacy authentication protocols (Basic Auth, EAS without modern auth). CIS 5.3.5 compliant.

---

#### 🟢 IAC - GLOBAL – BLOCK – Countries not Allowed
`ID: f3f4ad30-86a8-4e29-8ec9-4efab1a459f5` · **Enabled** · Created: 2026-05-04

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass`, **`CA - TravelingUsers`** |
| Applications | All Cloud Apps |
| Locations — Include | All |
| Locations — Exclude | `IAC - AllowedCountries` (GB, US) |
| Grant | **Block** |

> Blocks sign-ins from any country NOT in the allowed list. Traveling users can be excluded via `CA - TravelingUsers`.

---

#### 🟢 IAC - GLOBAL – BLOCK – Countries not Allowed - NoExclusions
`ID: 1eaf943a-abad-4c77-b101-0c5342fc1044` · **Enabled** · Created: 2026-05-04

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Locations — Include | `IAC - Blocked Countries` (17 countries + unknown IPs) |
| Locations — Exclude | None |
| Grant | **Block** |

> Hard-blocks the explicit blocked country list with no exclusions available. Acts as a second-layer geo-fence. No `CA - TravelingUsers` bypass.

---

#### 🟢 IAC - GLOBAL - BLOCK - Unsupported Device Platforms
`ID: 9e21fa64-8d9a-4e62-81da-9abce8859a0c` · **Enabled** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Platforms — Include | All |
| Platforms — Exclude | Android, iOS, Windows, macOS |
| Grant | **Block** |

> Blocks any platform that is not Android, iOS, Windows, or macOS (e.g., Linux, ChromeOS, unknown).

---

### GLOBAL — Grant Policies

---

#### 🟢 IAC - GLOBAL - GRANT - MFA - AllAdmins
`ID: f893f39f-2ab3-4f1e-a8e1-9a2b9589a9ce` · **Enabled** · Created: 2026-05-04

| Field | Value |
|---|---|
| Users — Roles | All 47 Entra admin roles (Global Admin, Privileged Auth Admin, etc.) |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Auth Strength | **Modern MFA + TAP** (phishing-resistant only) |

> Enforces phishing-resistant MFA for all privileged roles. Uses the custom "Modern MFA + TAP" strength — no SMS/push fallback.

---

#### 🟡 IAC - GLOBAL - GRANT - MFA - AllUsers
`ID: a66e8427-e5e7-4072-bfd1-7e99db7a7dc4` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - GlobalExclusions`, `CA - Breakglass` |
| Applications | All (exclude: `00000012-0000-0000-c000-000000000000`, `d4ebce55-015a-49b5-a083-c84d1797ae8c`) |
| Grant | MFA (built-in, not strength-based) |

> ⚠️ Currently **Report-Only** — MFA for all users is not being enforced yet. This is the most impactful policy to enable.

---

#### 🟡 IAC - GLOBAL - GRANT - MFA-Passkey - UserRegistration
`ID: 30a1edce-e832-456b-b2c5-4b1098d3a9b3` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users — Groups | `MFA-AUTH-Passkey` |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| User Action | Register Device (`urn:user:registerdevice`) |
| Platforms | Android, iOS only |
| Auth Strength | **Modern MFA + TAP** |

> Requires Modern MFA when passkey-targeted users register a device on mobile platforms.

---

#### 🟡 IAC - GLOBAL - GRANT - MFA-Passkeys - ADM-Users
`ID: a53c4c2b-b577-4d88-b64d-36b92f8f3ca0` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users — Groups | `ADM-Users-Dynamic` (UPN contains `.adm`) |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Auth Strength | **Modern MFA + TAP** |

> Enforces phishing-resistant MFA for all `.adm` admin accounts across all apps.

---

#### 🟡 IAC - GLOBAL - GRANT - BreakGlass - TrustedLocations
`ID: 1588fdc7-f34a-468e-8023-4d788ef5d226` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users — Include | Specific user `cec6164b-...` |
| Users — Exclude | Specific user `ebb6b745-...` |
| Applications | All Cloud Apps |
| Locations — Include | All |
| Locations — Exclude | `0403d368...` (IAC - Trusted Locations IP) |
| Auth Strength | **Modern MFA + TAP** |

> Requires phishing-resistant MFA for break-glass accounts when signing in from outside the trusted IP range.

---

#### 🟡 IAC - GLOBAL - GRANT - MFA - B2B-Guest
`ID: f25f94e0-98b6-41be-b9d6-68cb781004a4` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users — Guest Types | `internalGuest`, `b2bCollaborationMember`, `b2bDirectConnectUser`, `serviceProvider` — All external tenants |
| Exclude Groups | `CA - Breakglass` |
| Applications | All Cloud Apps |
| Auth Strength | **Modern MFA + TAP** |

> Requires phishing-resistant MFA for B2B collaboration members, internal guests, and service providers.

---

#### 🟡 IAC - GLOBAL - GRANT - MFA - Mixed-Guests
`ID: e0fabad3-bd0f-42e4-a901-51ef7ab8889c` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users — Guest Types | `b2bCollaborationGuest`, `otherExternalUser` — All external tenants |
| Exclude Groups | `CA - Breakglass` |
| Applications | All Cloud Apps |
| Grant | MFA (built-in) |

> Covers remaining guest user types (B2B collaboration guests and other external users) with standard MFA.

---

### GLOBAL — Session Policies

---

#### 🟡 IAC - GLOBAL - BLOCK - Authentication Transfer
`ID: fa005ec2-4940-49c8-b4e7-b58e66ef481c` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - GlobalExclusions`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Auth Flow | `authenticationTransfer` |
| Grant | **Block** |

> Blocks the QR-code-based authentication transfer flow (prevents session token theft via QR code relay).

---

#### 🟢 IAC - GLOBAL – SESSION – Admin Persistence (4 Hours)
`ID: 04b969aa-3e98-4e0f-8b32-2319b199b56a` · **Enabled** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users — Roles | All 47 Entra admin roles |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Client App Types | Browser |
| Sign-in Frequency | **4 hours** (primary + secondary auth) |
| Persistent Browser | **Never** |

> Admins must re-authenticate every 4 hours in browser sessions. No persistent sessions allowed.

---

#### 🟡 IAC - GLOBAL – SESSION – All Users Persistence (9-12 Hours)
`ID: ea9459a9-91b6-4d2b-b929-03781ac81d54` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Client App Types | Browser |
| Sign-in Frequency | **12 hours** (primary + secondary auth) |
| Persistent Browser | **Never** |

> Standard users re-authenticate every 12 hours; no persistent browser sessions.

---

#### 🟡 IAC - GLOBAL - SESSION - Windows - TokenProtection
`ID: 8bb25c6a-ed35-4556-bed4-b3aaa14e192b` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | Exchange Online, SharePoint Online, OneDrive, Azure Virtual Desktop (`0af06dc6...`), `9cdead84...`, Teams (`cc15fd57...`) |
| Client App Types | `mobileAppsAndDesktopClients` |
| Platform | Windows |
| Device Filter | Exclude: CloudPC devices (`device.systemLabels -contains "CloudPC" -and device.trustType -eq "AzureAD"`) |
| Session Control | Secure App Session (Token Protection) — `notEnforced` mode / enabled |

> Binds access tokens to the device on Windows for key M365 workloads. CloudPCs are excluded. Currently in `notEnforced` (report) mode.

---

### APP — Application Policies

---

#### 🟡 IAC - APP - BLOCK - SharePoint-OneDrive-NonTrustedLocations
`ID: 1f960ec9-885f-4032-a6b2-a5c559279274` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - GlobalExclusions`, `AVD-ExternalUsers`, `CA - Breakglass` |
| Applications | SharePoint Online (`00000003-0000-0ff1-ce00-000000000000`) |
| Locations | All → Exclude AllTrusted |
| Grant | **Block** |

> Blocks SharePoint/OneDrive access from untrusted locations.

---

#### 🟡 IAC - APP - inforcer - RequireMFA
`ID: 1d3a7677-a723-4c56-924c-2e1dc63df105` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | `708861da-226e-4d65-a57a-24128df64524` (Inforcer app) |
| Locations | All |
| Grant | MFA (built-in) |

> Requires MFA for all users accessing the Inforcer application from any location.

---

#### 🟡 IAC - APP – BLOCK – AVD - Exclude - AllowedAVDUsers
`ID: 9bc2ad69-4aed-4242-807d-788446196b8b` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `AVD-ExternalUsers`, `AVDUsers`, `Azure-Breakglass`, `CA - Breakglass` |
| Applications | Azure Virtual Desktop (`0af06dc6...`), `9cdead84...` |
| Grant | **Block** |

> Blocks all users from AVD except those in the `AVDUsers` or `AVD-ExternalUsers` groups.

---

#### 🟡 IAC - APP – BLOCK – AVD - NonTrustedLocations
`ID: b13dd393-f644-45c8-81bf-aa7f4032ebd3` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `AVD-ExternalUsers`, `Azure-Breakglass`, `CA - Breakglass` |
| Applications | Azure Virtual Desktop (`0af06dc6...`), `9cdead84...` |
| Locations | All → Exclude AllTrusted |
| Grant | **Block** |

> Blocks AVD access from untrusted locations. `AVD-ExternalUsers` are exempt (they connect from non-trusted IPs by design).

---

#### 🟡 IAC - APP - SESSION - O365 - Timeoutsettings
`ID: c5133041-079f-45ec-b27a-20268546077f` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `CA - Breakglass` |
| Applications | Office365 (suite) |
| Client App Types | Browser |
| Session Control | **Application Enforced Restrictions** (enabled) |

> Delegates session timeout enforcement to Office 365 (SharePoint/Exchange honour tenant-level idle timeout settings).

---

### INTUNE — Device Policies

---

#### 🟡 IAC - INTUNE - GRANT - RequireCompliantDevice
`ID: 660ab461-0de5-4b00-baea-ec7325280f60` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `CA - DeviceExclusions`, `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Locations | All → Exclude AllTrusted |
| Grant | Compliant Device **OR** Domain Joined Device |

> Requires Intune compliance or Hybrid Azure AD join when accessing from untrusted locations. `CA - DeviceExclusions` allows BYOD/exception scenarios.

---

#### 🟡 IAC - INTUNE – GRANT – Device Registration from trusted location
`ID: aeb49474-5250-4b65-8b0a-56c47127ee0f` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `CA - DeviceExclusions`, `Azure-Breakglass`, `CA - Breakglass` |
| User Action | Register Device (`urn:user:registerdevice`) |
| Auth Strength | Built-in MFA |

> Requires MFA when registering a new device. `CA - DeviceExclusions` can bypass for pre-provisioned/Autopilot scenarios.

---

### P2 — Risk-Based Policies

> All P2 risk policies are currently **Report-Only**.

---

#### 🟡 IAC - P2 - GLOBAL - GRANT - High-Risk Sign-Ins
`ID: 53a8df0b-4658-4835-ace2-100b5d287aac` · **Report-Only**

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `CA - Breakglass` |
| Sign-In Risk | **High** |
| Applications | All Cloud Apps |
| Auth Strength | **Modern MFA + TAP** |
| Sign-in Frequency | **Every time** |

---

#### 🟡 IAC - P2 - GLOBAL - GRANT - Medium-Risk Sign-Ins
`ID: 180ab5a3-d3ae-4457-9ef1-e3c06f5dfbfc` · **Report-Only**

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `CA - Breakglass` |
| Sign-In Risk | **Medium** |
| Applications | All Cloud Apps |
| Grant | MFA (built-in) |

---

#### 🟡 IAC - P2 - GLOBAL - GRANT - High-Risk Users
`ID: bb6a814e-808a-467c-9475-06f89140ce99` · **Report-Only**

| Field | Value |
|---|---|
| Users | All Users + All External/Guest types |
| Exclude Groups | `CA - Breakglass` |
| User Risk | **High** |
| Applications | All Cloud Apps |
| Grant | MFA **AND** Password Change |
| Sign-in Frequency | **Every time** |

---

#### 🟡 IAC - P2 - GLOBAL - GRANT - Medium-Risk Users
`ID: 7475b373-0544-4ee8-8827-cff35009136d` · **Report-Only**

| Field | Value |
|---|---|
| Users | All Users + All External/Guest types |
| Exclude Groups | `CA - Breakglass` |
| User Risk | **Medium** |
| Applications | All Cloud Apps |
| Grant | MFA **AND** Password Change |

---

#### 🟡 IAC - P2 - GLOBAL - BLOCK - RiskyUsers - RegisterSecurityInfo
`ID: 768858bd-a5ad-47de-8acb-5e815cde0857` · **Report-Only**

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `CA - Breakglass` |
| User Risk | High, Medium |
| User Action | Register Security Info (`urn:user:registersecurityinfo`) |
| Grant | **Block** |

> Prevents risky users from registering new authentication methods (attacker cannot add their own MFA method).

---

#### 🟡 IAC - P2 - APP - SESSION - PIM - Reauthentication
`ID: a6b3b754-9079-48f0-abb2-9e79b2f41095` · **Report-Only**

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `CA - Breakglass` |
| Authentication Context | `c1` (PIM role activation context) |
| Auth Strength | **Modern MFA + TAP** |
| Sign-in Frequency | **Every time** |

> Triggers on PIM authentication context `c1` — requires phishing-resistant MFA re-authentication every time a PIM role is activated.

---

### ZTCA — Zero Trust Policies

---

#### 🟡 IAC - ZTCA - GLOBAL – BLOCK – Admin Portal
`ID: fafaa50c-0b61-4ac6-a589-f9a1120b2f9e` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - GlobalExclusions`, `CA - Breakglass` |
| Exclude Guest/External | `serviceProvider` from tenant `d747311f-f098-4814-8432-ed58c58d2a9b` |
| Applications — Include | Inforcer (`708861da...`), Azure Mgmt (`797f4846...`), `MicrosoftAdminPortals`, `fd642066...`, `ba9ff945...` |
| Applications — Exclude | Azure AD (`00000002-...`), `0000000c-...`, `1b912ec3-...`, `8c59ead7-...` |
| Grant | **Block** |

> Blocks access to admin portals for all non-excluded users. Service providers from the Inforcer tenant are excluded. Specific first-party apps that would break if blocked are excluded.

---

#### 🟡 IAC - ZTCA - INTUNE - BLOCK - AllApps - ExcludeTrustedLocation
`ID: 2dd84b12-7900-40f0-b192-027c20aaa83f` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Guest/External | All service providers (all external tenants) |
| Exclude Groups | `Azure-Breakglass`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Locations | All → Exclude AllTrusted |
| Device Filter | Exclude: `device.isCompliant -eq True -or device.trustType -eq "ServerAD" -or device.trustType -eq "Workplace"` |
| Grant | **Block** |

> Blocks any non-compliant, non-domain-joined, non-registered device from outside trusted locations. Compliant/hybrid-joined/Workplace devices are exempt.

---

#### 🟡 IAC- ZTCA - GLOBAL - BLOCK - AllApps -Exclude CA-Global
`ID: 8417ec17-17f5-44c1-b937-85b1917f5d9e` · **Report-Only** · Created: 2026-05-06

| Field | Value |
|---|---|
| Users | All Users |
| Exclude Groups | `Azure-Breakglass`, `CA - GlobalExclusions`, `CA - Breakglass` |
| Applications | All Cloud Apps |
| Grant | **Block** |

> Catch-all block policy — blocks all users from all apps unless in the `CA - GlobalExclusions` group. Intended as a Zero Trust foundation ("default deny") once all other policies are enabled.

---

### AGENT — Workload Identity Policies

> Both Agent policies are **Report-Only** and target `includeUsers: None` — they are placeholders for workload identity (service principal) CA policies, pending configuration.

---

#### 🟡 IAC - AGENT - BLOCK - HighRiskAgent
`ID: 0ab1380f-3863-40a5-ab97-24250e1cf44e` · **Report-Only**

| Field | Value |
|---|---|
| Users | None |
| Client Applications | `includeServicePrincipals: []` (not yet configured) |
| Applications | All Cloud Apps |
| Grant | **Block** |

---

#### 🟡 IAC - AGENT - BLOCK - NonTrustedAgents
`ID: 1d8beea4-2ea1-4758-8e22-d6310a60220a` · **Report-Only**

| Field | Value |
|---|---|
| Users | None |
| Client Applications | `includeServicePrincipals: []` (not yet configured) |
| Applications | All Cloud Apps |
| Grant | **Block** |

---

### WORKLOAD — Service Account Policies

---

#### 🔴 IAC - WORKLOAD - BLOCK - EntraConnectIDSync - ExcludeEntraConnectIP
`ID: f950dbf3-6b9e-4d05-b8d6-a32c430ae97f` · **Disabled** · Created: 2026-05-07

| Field | Value |
|---|---|
| Users | None (user scope placeholder) |
| Locations — Include | All |
| Locations — Exclude | None configured yet |
| Grant | **Block** |

> Policy template for locking the Entra Connect Sync account to a specific IP. Currently disabled and the user scope/IP exclusion are not fully configured.

---

#### 🔴 IAC - WORKLOAD - BLOCK - RiskyServicePrincipals
`ID: f93c5ed2-ae8b-460e-aa07-6529528d6ac5` · **Disabled** · Created: 2026-05-07

| Field | Value |
|---|---|
| Users | None |
| Sign-In Risk | High, Medium |
| Applications | All Cloud Apps |
| Grant | **Block** |

> Policy for blocking service principals with elevated risk scores. Disabled — requires Workload Identities Premium license and SP targeting configuration.

---

## 6. Policy State Summary

### By State

| State | Count | Policies |
|---|---|---|
| 🟢 **Enabled** | 6 | Block Device Code, Block Legacy Auth, Block Countries (both), Block Unsupported Platforms, Admin Session 4hr |
| 🟡 **Report-Only** | 26 | All other active policies |
| 🔴 **Disabled** | 2 | EntraConnect Workload, RiskyServicePrincipals |

### By Category

| Category | Count |
|---|---|
| GLOBAL Block | 5 |
| GLOBAL Grant / MFA | 7 |
| GLOBAL Session | 4 |
| APP (Application) | 5 |
| INTUNE (Device) | 2 |
| P2 Risk-Based | 6 |
| ZTCA Zero Trust | 3 |
| AGENT (Workload Identity) | 2 |
| WORKLOAD (Service Accounts) | 2 |

### Key Observations

1. **26 of 34 policies are Report-Only** — the security posture is extensively designed but not yet enforced. The primary next step is progressively enabling policies starting with low-impact ones.
2. **AllUsers MFA (`a66e8427`) is Report-Only** — the single most impactful policy to enable.
3. **All P2 risk policies are Report-Only** — high/medium risk sign-in protection is monitoring but not blocking.
4. **ZTCA catch-all block (`8417ec17`) is Report-Only** — the "default deny" Zero Trust posture is not enforced.
5. **Agent policies have empty service principal scopes** — they will not match any workload identity until configured.
6. **IAC - Trusted Locations is not marked as Trusted** (`isTrusted: false`) — does not contribute to Entra risk reduction.

---

---

## 7. Enterprise Application Consent Policies

### Authorization Policy (User Default Role Permissions)

These settings define what standard member users can do by default in the tenant without admin intervention.

| Setting | Value | Security Assessment |
|---|---|---|
| **Users can register applications** | ❌ `false` | ✅ Good — prevents users from creating app registrations |
| **Users can create security groups** | ❌ `false` | ✅ Good — group creation is admin-controlled |
| **Users can create tenants** | ❌ `false` | ✅ Good — prevents shadow tenant creation |
| **Users can read BitLocker keys for own device** | ❌ `false` | ✅ Good — BitLocker key access is admin-only |
| **Users can read other users** | ✅ `true` | ⚠️ Default — normal for directory, but review if internal org chart exposure is a concern |
| **Users can consent for risky apps** | `null` (not set) | ✅ Falls back to tenant consent policy; not explicitly allowed |
| **Block MSOL / legacy PowerShell** | ❌ `false` | ⚠️ MSOnline/AzureAD PowerShell modules still allowed — consider blocking as they are deprecated |
| **Guest user role** | `10dae51f-b6af-4016-8d66-8c2a99b929b3` (Guest User) | ✅ Standard restricted guest role |
| **Allow invites from** | `adminsAndGuestInviters` | ✅ Good — only admins and the Guest Inviter role can invite |
| **Allow email-verified users to join org** | ✅ `true` | ⚠️ Allows unmanaged Microsoft accounts to join — consider disabling |
| **Allowed to use SSPR** | ❌ `false` | Acceptable if SSPR is not deployed |
| **Allow email-based self-service signup** | ✅ `true` | ⚠️ Allows viral self-service signup — evaluate if intentional |

**Assigned Permission Grant Policies (Default User Role):**
- `ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-chat`
- `ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-team`

> Users can grant resource-specific consent for Teams chats and teams they own — this is the Microsoft-managed RSC policy, not a broad consent grant.

---

### Admin Consent Request Workflow

| Setting | Value | Assessment |
|---|---|---|
| **Admin consent workflow enabled** | ❌ `false` | ⚠️ **Gap** — users blocked from consenting have no escalation path; requests fail silently without this enabled |
| **Notify reviewers** | `false` | N/A (workflow disabled) |
| **Reminders enabled** | `false` | N/A (workflow disabled) |
| **Request duration** | 0 days | N/A (workflow disabled) |
| **Reviewers configured** | None | N/A (workflow disabled) |

> **Recommendation:** Enable the admin consent workflow. Without it, when a user tries to consent to an app that requires admin approval, they receive an error with no path forward. This creates helpdesk noise and may push users to find workarounds. Configure at least one reviewer group (typically the Application Administrator role group).

---

### Permission Grant Policies

These policies define who can consent to what. The **active tenant consent setting** is determined by which policy ID is assigned to the default user role in the Authorization Policy.

Currently assigned to default users:
- `ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-chat`
- `ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-team`

> This means **users cannot grant tenant-wide delegated consent** — only resource-specific consent for Teams/Chat resources they own. This is a strong, intentional posture.

#### Microsoft Built-in Policies Reference

| Policy ID | Display Name | Scope | Who Can Use | Risk Level |
|---|---|---|---|---|
| `microsoft-user-default-low` | Default User Low Risk | Tenant | Users | 🟢 Low — low-risk delegated perms from verified publishers + own-tenant apps |
| `microsoft-user-default-legacy` | Default User Legacy | Tenant | Users | 🔴 High — any developer-marked non-admin delegated permission |
| `microsoft-user-default-recommended` | Microsoft Recommended | Tenant | Users | 🟡 Medium — all delegated perms excluding sensitive Graph/EXO scopes |
| `microsoft-user-default-allow-consent-apps` | Allow Consent for Specific Apps | Tenant | Users | 🟡 Medium — specific trusted app IDs only (e.g. Apple, mobile clients) |
| `microsoft-application-admin` | Application Admin | Tenant | App Admins | Admin-scoped — all app+delegated perms, excludes MS Graph & AAD app perms |
| `microsoft-company-admin` | Company Admin | Tenant | Global Admins | Full — all app + delegated perms for any API |
| `microsoft-all-application-permissions` | All App Permissions | Tenant | (Admin-only) | 🔴 Highest — all application permissions for any client |
| `microsoft-all-application-permissions-verified` | All App Perms (Verified Publisher) | Tenant | (Admin-only) | 🟡 Scoped to verified publishers or own-tenant apps |
| `microsoft-dynamically-managed-permissions-for-chat` | RSC Chat Policy | Chat | Users (owned) | 🟢 Teams RSC only |
| `microsoft-dynamically-managed-permissions-for-team` | RSC Team Policy | Team | Users (owned) | 🟢 Teams RSC only |

#### `microsoft-user-default-low` — Active Detail

This is Microsoft's recommended user consent setting. Users in this tenant are **not** assigned this policy directly, but it documents what the recommended posture would be:

**Includes:**
- Low-risk delegated permissions from **verified publishers** (all external tenants)
- Low-risk delegated permissions from **apps registered in this tenant**

> If you want to permit controlled user consent in future, `microsoft-user-default-low` scoped to verified publishers is the Microsoft-recommended minimum-risk option.

#### `microsoft-application-admin` — Exclusions (important)

The Application Admin policy **excludes** application permissions for:
- Microsoft Graph (`00000003-0000-0000-c000-000000000000`) — all app perms
- Azure Active Directory Graph (`00000002-0000-0000-c000-000000000000`) — all app perms

> Application Administrators **cannot** grant Graph application permissions (e.g. `Directory.ReadWrite.All`, `Mail.ReadWrite`) — those require Global Admin or Cloud Application Administrator consent. This is a strong control.

---

### Registered Enterprise Applications

The following non-Microsoft integrated applications are registered in the tenant:

| Display Name | App ID | Publisher | Verified Publisher | App Assignment Required |
|---|---|---|---|---|
| **Inforcer Integration** | `708861da-226e-4d65-a57a-24128df64524` | Conditional Access Tech | ❌ Not verified | ❌ No |
| **ca-policy-analyzer** | `b8fe9cbf-f32d-4af7-87ae-0781bc0126c7` | Inforcer2M365 | ❌ Not verified | ❌ No |
| **Lokka** | `a9bac4c3-af0d-4292-9453-9da89e390140` | Merill / Jozra | ✅ Verified (Jozra) | ❌ No |
| **Apple Internet Accounts** | `f8d98a96-0999-43f5-8af3-69971c7bb423` | Apple Inc. | ✅ Verified (Apple Inc.) | ❌ No |
| **Microsoft Graph Command Line Tools** | `14d82eec-204b-4c2f-b7e8-296a70dab67e` | PRDTRS01 | ✅ Verified (Microsoft) | ❌ No |

> ⚠️ **Inforcer Integration** and **ca-policy-analyzer** do not have a verified publisher. As first-party/internal tooling apps this is common, but it means they cannot benefit from `clientApplicationsFromVerifiedPublisherOnly` consent policies. Consider registering a verified publisher identity if these apps are distributed to other tenants.

> ⚠️ **App assignment required is `false` on all apps** — any user in the tenant can access these applications. Consider enabling assignment required on Inforcer Integration and ca-policy-analyzer so only authorized users/groups can authenticate to them.

---

## 8. App Protection Policies (Intune MAM)

### Current Status

Graph API queries were executed against all Intune MAM policy endpoints:

| Endpoint | Result |
|---|---|
| `managedAppPolicies` | **No policies found** |
| `iosManagedAppProtections` | **No policies found** |
| `androidManagedAppProtections` | **No policies found** |
| `windowsManagedAppProtections` | **No policies found** |
| `mdmWindowsInformationProtectionPolicies` | **No policies found** |
| `targetedManagedAppConfigurations` | **No policies found** |
| `managedAppRegistrations` | **No registrations found** |

**No Intune App Protection Policies (APP) are configured in this tenant.**

---

### What This Means

Intune App Protection Policies (MAM) control how managed app data is handled on devices — including enrolled (MDM) and unenrolled (BYOD) devices. Without APP policies:

| Risk | Impact |
|---|---|
| No data leakage controls | Users can copy/paste M365 data from Outlook, Teams, or OneDrive into personal unmanaged apps |
| No PIN/biometric enforcement on apps | M365 mobile apps can be opened without any authentication gate |
| No selective wipe capability | If a device is lost/stolen or a user leaves, app-level data cannot be wiped without full device wipe |
| No jailbreak/root detection | Compromised mobile devices have unrestricted access to corporate data in apps |
| No minimum OS/app version enforcement | Users on outdated, vulnerable OS or app versions are not blocked |
| CA App-enforced restrictions | The `IAC - APP - SESSION - O365 - Timeoutsettings` policy uses Application Enforced Restrictions — for mobile, this depends on MAM policies being present |

---

### Recommended Baseline App Protection Policies

Microsoft and CIS recommend deploying APP policies for iOS and Android at minimum. Below is the recommended baseline aligned to Microsoft's default APP templates and CIS M365 Foundations:

#### iOS / Android — Baseline (Level 1 / CIS L1 equivalent)

| Setting Category | Recommended Value |
|---|---|
| **Data Transfer** | |
| Send org data to other apps | Policy managed apps only |
| Receive data from other apps | Policy managed apps only |
| Save copies of org data | Block (OneDrive for Business, SharePoint allowed) |
| Restrict cut/copy/paste | Policy managed apps + paste in |
| **Access Requirements** | |
| PIN for access | Require (numeric, min 6 digits) |
| Biometrics instead of PIN | Allow |
| Recheck access requirements after | 30 minutes of inactivity |
| **Conditional Launch** | |
| Min OS version | iOS 16 / Android 9.0 |
| Jailbroken/rooted devices | Block access |
| Max PIN attempts | 5 (then wipe) |
| Offline grace period | 720 hours, then wipe |
| **Assignments** | All Users |

#### Windows — MAM (Unmanaged / BYOD)

Windows MAM (without MDM enrollment) is available for Edge browser scenarios. As the tenant has Windows device policies via CA, this is lower priority but worth evaluating for BYOD contractors accessing web-based M365.

---

### Next Steps

1. **Create iOS and Android APP policies** in Intune → Apps → App protection policies using the Microsoft-provided templates as a starting point
2. **Target All Users** initially in report-only / audit mode to assess impact
3. **Assign to the same user population** as the `IAC - INTUNE - GRANT - RequireCompliantDevice` CA policy to ensure parity between managed and unmanaged device controls
4. **Enable assignment required** on the Inforcer and ca-policy-analyzer enterprise apps before or alongside APP deployment

---

*Generated from Microsoft Graph API via Lokka · ConditionalAccess.tech · 2026-05-07*

