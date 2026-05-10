# Microsoft 365 Baseline Security Mode — Deep Dive Guide

**Prepared by:** Jon Hope | M365 Security Configuration Management
**Last Updated:** April 2026
**Audience:** IT Administrators, Security Teams, Decision Makers
**Source:** [Microsoft Learn — Baseline Security Mode Settings](https://learn.microsoft.com/microsoft-365/baseline-security-mode/baseline-security-mode-settings)

---

## What Is Baseline Security Mode?

Baseline Security Mode is a feature in the **Microsoft 365 Admin Center** that consolidates Microsoft's recommended security settings across key M365 workloads into a single, managed interface. Previously, many of these configurations required PowerShell, Group Policy Objects (GPO), or navigating deep into individual admin portals. Baseline Security Mode surfaces them centrally under:

**Admin Center → Settings → Org Settings → Security & Privacy → Baseline Security Mode**

It covers:
- Microsoft Entra ID (identity and authentication)
- Exchange Online
- Microsoft 365 Apps (formerly Office)
- SharePoint and OneDrive
- Microsoft Teams

> **Important:** Baseline Security Mode uses **role-based access control (RBAC)**. Only administrators with the appropriate workload-specific roles (Security Administrator, SharePoint Administrator, Exchange Administrator, Teams Administrator, or Office Apps Administrator) can manage the settings within their scope. You need Conditional Access Administrator or Security Administrator roles to manage Entra-related settings.

> **Note for Tenants Active November 2025 – February 2026:** A known Microsoft bug may have created draft Conditional Access policies in a disabled state during this window. These are not a security incident. Microsoft has committed to removing any unintentionally created drafts.

---

## How to Use This Document

Each setting below is documented with:
- **What it does** — Plain-language explanation of the control
- **Why it matters** — The attack vector(s) it addresses
- **Current status** — As observed in your tenant (At Risk / Meets Standard / Not Applicable)
- **How to enable** — Where to configure it and what role is required
- **Considerations** — Known dependencies, compatibility warnings, or deployment notes
- **Framework alignment** — Relevant CIS, NIST, or Microsoft Zero Trust references

---

## Section 1: Authentication (12 Settings)

Authentication settings protect how users and applications prove their identity to Microsoft 365 services. Weaknesses in authentication are the #1 path attackers use to gain initial access to an organization.

---

### 1.1 Require Phishing-Resistant Authentication for Admins

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft Entra ID |
| **Required Role** | Security Administrator or Conditional Access Administrator |

#### What It Does
This setting creates a Conditional Access policy that requires **phishing-resistant MFA** for accounts assigned privileged administrative roles when they access Microsoft admin portals and all cloud applications. Standard MFA (SMS codes, push notifications, TOTP) is *not* sufficient for this control — it specifically requires:

- **Passkeys (FIDO2 security keys)**
- **Windows Hello for Business**
- **Microsoft Entra Certificate-Based Authentication (CBA)**
- **Passkeys in Microsoft Authenticator**

The 14 targeted admin roles include: Global Administrator, Application Administrator, Authentication Administrator, Billing Administrator, Cloud Application Administrator, Conditional Access Administrator, Exchange Administrator, Helpdesk Administrator, Password Administrator, Privileged Authentication Administrator, Privileged Role Administrator, Security Administrator, SharePoint Administrator, and User Administrator.

#### Why It Matters
Admin accounts are the highest-value targets in any M365 environment. Traditional MFA methods are increasingly defeated by:

- **Adversary-in-the-Middle (AiTM) phishing** — Real-time token harvesting tools like Evilginx2, Modlishka, and Muraena intercept session tokens even when standard MFA is completed
- **MFA fatigue / push bombing** — Attackers send repeated MFA push requests until an admin inadvertently approves
- **SIM swapping** — Bypasses SMS-based MFA entirely

Phishing-resistant methods (FIDO2, WHfB, CBA) use **hardware-bound cryptographic keys** tied to the specific origin URL. They cannot be phished remotely because the authentication ceremony requires physical possession of the credential and validates the relying party before signing.

According to Microsoft's own Secure Future Initiative data, **100% of user accounts** at Microsoft are now protected with phishing-resistant MFA. This is Microsoft's current internal standard — it should be yours too.

#### How to Enable
1. Navigate to **Entra Admin Center → Entra ID → Conditional Access → Policies → New Policy**
2. **Or** enable directly through **M365 Admin Center → Baseline Security Mode**
3. Target: Directory roles (the 14 listed above)
4. Exclude: Break-glass emergency access accounts (required — do this before enabling)
5. Grant control: **Require authentication strength → Phishing-resistant MFA strength**
6. Start in **Report-Only mode** to assess impact, then switch to **On**

#### Considerations
- **Pre-requisite:** Admins must have already registered a phishing-resistant method before policy enforcement or they will be locked out. Use **Temporary Access Pass (TAP)** to bootstrap registration.
- **External Authentication Methods** are currently incompatible with authentication strength controls. Use standard "Require MFA" grant if EAM is in use.
- Consider combining with **Privileged Identity Management (PIM)** to require phishing-resistant MFA at just-in-time role activation, not just sign-in.

#### Framework Alignment
- CIS Microsoft 365 Foundations Benchmark: Control 1.1.1
- NIST SP 800-63B: AAL3 (phishing-resistant authenticators)
- Microsoft Zero Trust: Verify Explicitly — Identity pillar

---

### 1.2 Block Legacy Authentication

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft Entra ID |
| **Required Role** | Security Administrator or Conditional Access Administrator |

#### What It Does
Creates a Conditional Access policy that **blocks all sign-in attempts using legacy authentication protocols** — older protocols that do not support modern authentication or MFA. Specifically, this targets:

- Exchange ActiveSync (EAS) clients using basic auth
- IMAP, POP3, SMTP AUTH
- Older Office clients (pre-2013) not supporting MSAL
- Any client app classified as "Other clients" in Entra sign-in logs

#### Why It Matters
Legacy authentication is the most exploited authentication vector in M365. Microsoft's telemetry is unambiguous:

- **>97% of credential stuffing attacks** use legacy authentication
- **>99% of password spray attacks** target legacy authentication protocols

The reason is simple: legacy protocols cannot present an MFA challenge. If an attacker obtains a password (through phishing, breach data, or guessing), legacy protocols let them authenticate **regardless of whether MFA is enabled**. Blocking legacy auth is the single most impactful authentication hardening step you can take.

Additionally, attackers who gain access via legacy protocols can configure email forwarding rules in Exchange, enabling persistent surveillance of mailboxes even after the password is changed.

#### How to Enable
1. First, **identify legacy auth usage**: Entra Admin Center → Sign-In Logs → filter by Client App → review "Exchange ActiveSync" and "Other clients" categories. Also check the **Legacy Authentication workbook** in Entra Monitoring & Health.
2. Create a Conditional Access policy:
   - **Users:** All users
   - **Cloud apps:** All resources
   - **Conditions → Client apps:** Exchange ActiveSync clients + Other clients (check both)
   - **Grant:** Block access
3. Start in **Report-Only mode** for at least 2 weeks
4. Exclude service accounts or legacy systems with hard dependencies (plan to migrate them)
5. Enable the policy tenant-wide when dependencies are resolved

#### Considerations
- **Certificate-Based Authentication for Exchange ActiveSync** (legacy EAS flow, not Entra CBA) stops working when this is enabled. This does not affect the modern Entra CBA flow.
- **Exchange connectors in Power Query** for Excel for Windows and Excel for the web will be impacted
- Service accounts that still use basic SMTP auth should be migrated to OAuth or replaced with managed identities
- Users on Office 2010 or earlier must upgrade — they cannot use modern auth

#### Framework Alignment
- CIS Microsoft 365 Foundations Benchmark: Control 1.1.3
- NIST SP 800-63B: Deprecation of memorized secrets over non-MFA channels
- Microsoft Zero Trust: Phase 1 deployment foundation control

---

### 1.3 Block New Password Credentials in Apps

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft Entra ID |
| **Required Role** | Security Administrator, Application Administrator, or Cloud Application Administrator |

#### What It Does
Prevents administrators and developers from adding new **password (client secret) credentials** to application registrations in Entra ID. Existing secrets are not removed, but no new secrets can be added going forward.

#### Why It Matters
Client secrets are static, long-lived passwords used by applications to authenticate to Entra ID. They represent significant security risks:

- They are often stored insecurely in code repositories, config files, or CI/CD pipelines
- They don't expire by default (or are set to very long expiry windows)
- They can be shared across environments (dev, staging, prod) creating broad blast radius
- If compromised, attackers gain application-level access, often with broad permissions to Microsoft Graph or other APIs
- Unlike human accounts, app credentials bypassed many Conditional Access controls historically

The modern replacement is **managed identities** (for Azure-hosted workloads) or **federated credentials / Workload Identity Federation** (for external workloads like GitHub Actions). Both eliminate the need for secrets entirely.

#### How to Enable
Via Baseline Security Mode in the M365 Admin Center, or via Entra Admin Center application management policies.

#### Considerations
- Audit all existing app registrations for password credentials before enabling: **Entra Admin Center → App Registrations → filter by credential type**
- Applications using client secrets must be migrated to certificate credentials or managed identities before blocking new secrets
- This setting affects new additions only — existing secrets remain until rotated or expired

#### Framework Alignment
- CIS Microsoft 365 Foundations Benchmark: Control 1.2.1
- Microsoft Secure Future Initiative: Eliminate unmanaged credentials

---

### 1.4 Turn On Restricted Management User Consent Settings

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft Entra ID |
| **Required Role** | Security Administrator or Privileged Role Administrator |

#### What It Does
Restricts the ability of end users to grant OAuth consent to third-party applications. Under this setting, users can only consent to:

- Applications created within your own tenant (single-tenant apps)
- Applications on the **Microsoft 365 Certified app list** (verified by Microsoft)
- Applications requesting only **low-risk permissions**

All other consent requests are blocked and must go through an **admin consent workflow** for approval.

#### Why It Matters
Illicit consent grant attacks (also called OAuth phishing) are a significant and underappreciated threat. In these attacks:

1. A user receives a phishing email with a link to a malicious or compromised OAuth app
2. The user is prompted to grant the app permissions (e.g., "Read your mail," "Access your files")
3. If they consent, the attacker gains persistent, token-based access to M365 data — **without ever needing the user's password or MFA**
4. Because OAuth tokens are long-lived, access persists even after the user changes their password

This attack is especially insidious because it appears as a legitimate Microsoft consent screen. Without this control, any user can grant any third-party app access to their M365 data.

#### How to Enable
1. Entra Admin Center → Enterprise Applications → Consent and Permissions → User Consent Settings
2. Select: "Allow user consent for apps from verified publishers, for selected permissions"
3. Enable the admin consent workflow so users can request approval for apps outside the allowed list
4. Review existing app consent grants via the App Governance portal or Microsoft Defender for Cloud Apps

#### Considerations
- Communicate the change to users — they will start seeing "approval required" prompts for new apps
- Review and configure the admin consent request workflow so legitimate app requests can be processed efficiently
- Use the **App Governance add-on** (included with Microsoft 365 E5 Compliance) for deeper visibility into OAuth app activity

#### Framework Alignment
- CIS Microsoft 365 Foundations Benchmark: Control 1.2.2
- MITRE ATT&CK: T1550.001 — Use Alternate Authentication Material: Application Access Token

---

### 1.5 Block Access to Exchange Web Services (EWS)

![Baseline Security Mode - EWS](https://github.com/Jhope188/LearnGraphAPI/blob/main/Baseline/M365%20Configuration/IAC-Admin-Center-Policies-JSON/Images/BaselineSecurityMode.png)

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Exchange Online |
| **Required Role** | Exchange Administrator |

#### What It Does
Disables **organization-wide access to Exchange Web Services (EWS)**, a SOAP-based API that provides programmatic access to Exchange Online data including emails, calendar items, contacts, and tasks.

#### Why It Matters
EWS is a powerful, legacy API originally designed for rich client applications and cross-platform mail integration. In modern M365 environments, it represents an unnecessarily wide attack surface:

- **Data exfiltration:** A compromised account with EWS access can silently extract entire mailboxes, calendar data, and contacts programmatically
- **Spear phishing enablement:** Attackers use harvested email content to craft highly convincing follow-on phishing emails
- **Identity spoofing:** EWS enables sending mail as other users (with sufficient permissions), facilitating business email compromise (BEC)
- **Legacy attack path:** EWS supports basic authentication in some configurations, bypassing modern auth protections

The modern replacement for EWS is **Microsoft Graph API**, which supports OAuth 2.0 and enables much more granular permission scoping.

#### How to Enable
Via Baseline Security Mode, or via Exchange Admin Center / PowerShell:
```powershell
Set-OrganizationConfig -EwsEnabled $false
```

#### Considerations
> **⚠️ High Impact Warning:** Disabling EWS will break some first-party Microsoft features.

- **Office Add-ins** (Word, Excel, PowerPoint, Outlook add-ins) may stop working on older builds. Build **16.0.19127** or later is required.
  - Current Channel: Available now
  - Monthly Enterprise Channel: October 2025
  - Semi-Annual Enterprise Channel: January 2026
- **Teams Panels** require Teams app version 1449/1.0.97.2025120101 (September 2025) or later to avoid disruption
- Run an **impact report** in Baseline Security Mode before enabling to identify affected users
- EWS access can also be scoped per-user if a blanket block is not feasible:
  ```powershell
  Set-CasMailbox -Identity user@domain.com -EwsEnabled $false
  ```

> **🍎 Apple Mail Dependency — Review Before Enabling**
>
> The BSM impact report for EWS commonly surfaces high call volumes from Application ID **`f8d98a96-0999-43f5-8af3-69971c7bb423`** — this is **Apple Internet Accounts**, the Entra-registered identity used by native Apple Mail, Calendar, and Contacts on **iOS, iPadOS, and macOS**.
>
> **Important distinction:** This application uses **modern authentication (OAuth)** — it is not a legacy auth problem. However, it still communicates over the EWS protocol rather than Microsoft Graph. Disabling EWS org-wide will **immediately break email, calendar, and contacts sync for all users relying on the native Apple mail stack**, regardless of their auth method.
>
> The SOAP actions typical of this app and what they mean:
>
> | SOAP Action | Purpose |
> |---|---|
> | `SyncFolderItems` | Continuous polling for new/changed emails across all folders |
> | `GetStreamingEvents` | Real-time push notification connection for new mail |
> | `SyncFolderHierarchy` | Syncing the folder tree (Inbox, Sent, custom folders) |
> | `GetFolder` | Reading folder properties during sync |
> | `GetItem` | Fetching email body/content after sync identifies a change |
> | `Subscribe` | Establishing streaming notification subscriptions |
>
> High call volume from a single App ID is expected and normal — each Apple device runs these sync cycles continuously in the background. 50 users with iPhones, iPads, and Macs will generate tens of thousands of EWS calls per week.
>
> **Before enabling the EWS block, choose a path:**
>
> - **Option A — Enforce Outlook:** Disable EWS and require all users to use **Outlook for iOS** and **Outlook for Mac**, which use Microsoft Graph and are unaffected. Enforce via Intune app protection policy. This is the recommended long-term posture.
> - **Option B — Scope EWS by application:** Rather than a blanket org-wide block, whitelist Apple Internet Accounts while blocking all other EWS consumers. This requires per-application EWS scoping via PowerShell.
> - **Option C — Audit scope first:** Query Entra sign-in logs filtered on App ID `f8d98a96-0999-43f5-8af3-69971c7bb423` to identify the number of distinct affected users before making any change. Navigate to **Entra Admin Center → Monitoring & Health → Sign-in Logs → Add filter: Application = Apple Internet Accounts**.
>
> Do not enable the EWS block until one of these paths is in place.

#### Framework Alignment
- Microsoft recommended hardening for Exchange Online
- CIS Microsoft 365 Foundations Benchmark: Control 6.x (Exchange hardening)

---

### 1.6 Block Basic Authentication Prompts (Microsoft 365 Apps)

| Attribute | Detail |
|-----------|--------|
| **Status** | ✅ Meets Standard |
| **Service** | Microsoft 365 Apps |

#### What It Does
Prevents Microsoft 365 desktop applications (Word, Excel, PowerPoint, Outlook, etc.) from displaying basic authentication prompts. When enabled, users will no longer see username/password dialogs that transmit credentials without MFA support.

#### Why It Matters
This is the application-layer complement to the Entra-level legacy auth block (Setting 1.2). Even if a Conditional Access policy blocks legacy auth at the token level, older clients may still prompt users for basic credentials. This setting eliminates the prompt itself, ensuring users are always directed to modern authentication flows.

Credential theft through basic auth prompts is a common attack vector, especially on unsecured networks where credentials can be intercepted in transit.

**Your tenant currently meets this standard — maintain this configuration.**

---

### 1.7 Block Files from Opening with Insecure Protocols

| Attribute | Detail |
|-----------|--------|
| **Status** | ✅ Meets Standard |
| **Service** | Microsoft 365 Apps |

#### What It Does
Prevents Microsoft 365 applications from opening files hosted at locations using **HTTP or FTP** — protocols that transmit data in plain text, without encryption.

#### Why It Matters
When a user opens a file over HTTP or FTP, all data — including the file content and any embedded credentials — is transmitted in the clear. Attackers on the same network (corporate Wi-Fi, public hotspot, or via a MITM position) can intercept and read this traffic. This is a classic **man-in-the-middle (MitM)** attack vector.

This setting enforces **HTTPS-only** file access from Microsoft 365 applications, ensuring all file transport is encrypted.

**Your tenant currently meets this standard — maintain this configuration.**

---

### 1.8 Block Files from Opening with FPRPC Protocol

| Attribute | Detail |
|-----------|--------|
| **Status** | ✅ Meets Standard |
| **Service** | Microsoft 365 Apps |

#### What It Does
Blocks Microsoft 365 applications from opening files using the **FrontPage Remote Procedure Call (FPRPC)** protocol — a legacy protocol originally used for remote web page authoring with FrontPage Server Extensions.

#### Why It Matters
FPRPC is an outdated protocol no longer in active development, but its presence in older code paths represents an exploitable attack surface. Attackers can craft malicious FPRPC payloads to:
- Execute arbitrary commands on the client
- Compromise systems through specially crafted network traffic or files

Microsoft 365 apps now default to **HTTPS** for remote file access. This setting ensures users cannot override that default and fall back to the legacy FPRPC path.

**Your tenant currently meets this standard — maintain this configuration.**

---

### 1.9 Block Legacy Browser Authentication Connections to SharePoint (RPS Protocol)

| Attribute | Detail |
|-----------|--------|
| **Status** | ✅ Meets Standard |
| **Service** | SharePoint |

#### What It Does
Prevents applications and browsers from using the **legacy Relying Party Suite (RPS)** protocol to authenticate to SharePoint and OneDrive resources in a browser context.

#### Why It Matters
RPS is a legacy SharePoint authentication mechanism that, like other legacy protocols, does not support MFA. Applications (including non-Microsoft ones) using RPS to access SharePoint are susceptible to brute-force and phishing attacks.

This setting provides impact reporting showing which users are accessing SharePoint/OneDrive via RPS, including timestamps and specific resources accessed — enabling proactive identification of legacy clients or integrations that need to be modernized.

> **Note:** Changes may take up to 24 hours to propagate.

**Your tenant currently meets this standard — maintain this configuration.**

---

### 1.10 Block IDCRL Protocol Connections to SharePoint

| Attribute | Detail |
|-----------|--------|
| **Status** | ✅ Meets Standard |
| **Service** | SharePoint |

#### What It Does
Prevents clients from using the **Identity Client Runtime Library (IDCRL)** protocol for authenticating to SharePoint and OneDrive. IDCRL is a legacy client-side authentication library used by older Office clients and Windows integrations.

#### Why It Matters
Like RPS, IDCRL does not support modern authentication or MFA, making connections using this protocol susceptible to password-based attacks. Organizations that have disabled legacy authentication in Entra ID but have not addressed legacy SharePoint protocol connections may still have exploitable paths to SharePoint data.

This setting complements the Entra-level legacy auth block by covering the SharePoint-specific legacy authentication path.

> **Note:** Changes may take up to 24 hours to propagate.

**Your tenant currently meets this standard — maintain this configuration.**

---

### 1.11 Don't Allow New Custom Scripts in OneDrive and SharePoint Sites

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | SharePoint |
| **Required Role** | SharePoint Administrator |

#### What It Does
**Permanently disables** the ability to add new custom scripts to OneDrive and SharePoint sites. Existing custom scripts will also be blocked from running. The recommended alternative is the **SharePoint Framework (SPFx)**, which provides a governed, sandboxed extension model.

#### Why It Matters
Custom scripts in SharePoint are a significant governance and security risk:

- Once custom scripts are allowed, it becomes **impossible to enforce governance** over what code runs in your SharePoint environment
- Malicious or compromised scripts can exfiltrate data, harvest credentials, modify site content, or redirect users to phishing pages
- Custom scripts run in the context of the authenticated user, meaning a script can perform any action the user can perform
- They can be introduced by any site owner or contributor who has been granted script permission — creating wide lateral risk

The SharePoint Framework provides equivalent customization capability within a secure, managed container that can be reviewed, approved, and monitored through the tenant app catalog.

> **⚠️ This is a permanent change.** Once enabled, new custom scripts cannot be added. Plan migration to SPFx before enabling.

#### How to Enable
Via Baseline Security Mode or via PowerShell:
```powershell
Set-SPOSite -Identity <siteurl> -DenyAddAndCustomizePages 1
```
For tenant-wide enforcement:
```powershell
Set-SPOTenant -DenyAddAndCustomizePages 1
```

#### Framework Alignment
- SharePoint security hardening best practices
- CIS Microsoft 365 Foundations Benchmark: SharePoint controls

---

### 1.12 Remove Access to Microsoft Store for SharePoint

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | SharePoint |
| **Required Role** | SharePoint Administrator |

#### What It Does
Removes the ability for end users to install applications directly from the **Microsoft Store** into SharePoint sites and pages.

#### Why It Matters
While the Microsoft Store does curate its apps, allowing end-users to install arbitrary Store apps into SharePoint creates governance challenges:

- **Shadow IT proliferation:** Apps installed without IT review may have broad data access permissions
- **Supply chain risk:** Even legitimate apps can be compromised after initial approval
- **Policy enforcement gaps:** Apps installed by individual site owners may not comply with organizational DLP, data residency, or compliance requirements
- **Increased attack surface:** Each installed app is a potential vector for exploitation

Best practice is to centralize app approval through the **SharePoint tenant app catalog**, where IT can review, approve, and deploy apps through a controlled pipeline.

#### How to Enable
Via Baseline Security Mode or via SharePoint Admin Center → Settings → Store settings.

---

## Section 2: Files (6 Settings)

These settings address vulnerabilities in Microsoft 365 desktop applications related to legacy file formats and dangerous object types. Many of these attack vectors have been actively exploited in the wild through spear-phishing campaigns targeting enterprise users.

---

### 2.1 Open Ancient Legacy Formats in Protected View and Disallow Editing

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft 365 Apps |
| **Required Role** | Office Apps Administrator or Security Administrator |

#### What It Does
Forces Microsoft 365 applications to open **ancient legacy file formats** (pre-Office 97 formats such as `.wk1`, `.wk3`, `.wk4`, `.wb1`, `.wb2`, `.xlc`, `.xlm`, `.dif`, `.slk`, `.prn`, and similar) in **Protected View** with editing completely disabled. Users can view the content but cannot edit or enable active content.

#### Why It Matters
Ancient legacy formats were designed decades before modern security concepts existed. They contain no memory safety protections and are riddled with unpatched memory corruption vulnerabilities. Attackers use these formats because:

- Modern antivirus engines and sandboxes often have weaker detection for very old file formats
- The parsing code for these formats in Office is rarely updated and contains known vulnerabilities
- Users may not recognize the format as potentially dangerous
- Opening with editing enabled allows embedded code or exploit payloads to execute

Protected View acts as a sandboxed read-only environment, preventing exploit code from breaking out to the operating system even if a parsing vulnerability is triggered.

#### How to Enable
Via Baseline Security Mode in the M365 Admin Center. Can also be configured via Intune (Microsoft 365 Apps security baselines) or Group Policy.

#### Considerations
- Audit whether any business processes actively require editing these ancient formats — they should be extremely rare in modern environments
- Consider running the **impact report** in Baseline Security Mode before enabling to identify affected users

#### Framework Alignment
- Microsoft 365 Apps Security Baseline (Intune): File Block settings
- CIS Microsoft 365 Foundations Benchmark: Office app hardening

---

### 2.2 Open Old Legacy Formats in Protected View and Save as Modern Format

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft 365 Apps |

#### What It Does
Forces Microsoft 365 applications to open **old legacy formats** (Office 97-2003 formats: `.doc`, `.xls`, `.ppt` and similar binary formats) in **Protected View**. Unlike Setting 2.1, editing is *allowed* — but users are prompted to save in a modern format (`.docx`, `.xlsx`, `.pptx`) when they do.

#### Why It Matters
Legacy binary formats (`.doc`, `.xls`, `.ppt`) are a frequent vehicle for malware delivery:

- These formats support embedded macros, OLE objects, and other active content that can execute malicious code
- Their binary structure is complex and inconsistently parsed, creating opportunities for memory corruption exploits
- They are heavily used in phishing campaigns because many users receive them from legitimate business contacts and open them without suspicion
- Microsoft's own Office 365 email security telemetry consistently shows `.doc` and `.xls` files among the top malware delivery formats

Opening in Protected View allows users to review the content while preventing code execution. Prompting to save in modern format gradually migrates the organization away from legacy format usage.

#### Considerations
- Some business processes or external partners may send files in these formats regularly. User communication is important.
- This setting works in conjunction with Email attachment policies in Defender for Office 365.

---

### 2.3 Block ActiveX Controls in Microsoft 365 Apps

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft 365 Apps |

#### What It Does
Enforces the **blocking of ActiveX controls** in Microsoft 365 documents and applications, preventing users from overriding the default blocked state that Microsoft introduced in 2022.

#### Why It Matters
ActiveX controls are COM-based components that can execute arbitrary native code with user-level privileges. They represent one of the most historically abused attack surfaces in Microsoft Office:

- **CVE history:** Hundreds of critical CVEs have been assigned to Office ActiveX controls over the years
- **Malware delivery:** ActiveX has been used in countless targeted attacks and mass malware campaigns
- **No sandboxing:** Unlike browser-based technologies, ActiveX runs outside any sandbox with direct OS access
- **User override risk:** Without this setting, users can click "Enable Content" on ActiveX prompts, triggering malicious payloads

Microsoft disabled ActiveX by default in 2022 (Monthly Channel). This setting ensures that enterprise users cannot re-enable it, closing a significant gap where users might enable content without understanding the risk.

#### Considerations
- Legacy forms or custom solutions using ActiveX will break. Audit usage before enabling.
- ActiveX-dependent solutions should be modernized to use Office JavaScript Add-ins (web-based, sandboxed)

#### Framework Alignment
- MITRE ATT&CK: T1559.001 — Inter-Process Communication: Component Object Model
- CIS Microsoft 365 Apps Security Baseline

---

### 2.4 Block OLE Graph and OrgChart Objects

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft 365 Apps |

#### What It Does
Blocks Microsoft 365 applications from **loading OLE Graph and OrgChart objects** embedded in documents. These are legacy Microsoft Graph and Organization Chart objects (distinct from Microsoft Graph API) that can be embedded in Office files.

#### Why It Matters
OLE (Object Linking and Embedding) Graph and OrgChart objects are legacy controls from the 1990s that:

- Have known exploitation techniques documented in MITRE ATT&CK
- Are rarely used in modern documents but remain as parseable attack vectors
- Can be weaponized in spear-phishing documents to execute arbitrary code
- Are difficult for end users to identify as potentially malicious — they appear as legitimate chart objects

Blocking these objects eliminates a specific, documented attack technique while having minimal impact on modern workflows, as these objects have been superseded by modern chart types in Microsoft 365.

#### Framework Alignment
- MITRE ATT&CK: T1559 — Inter-Process Communication (OLE exploitation)

---

### 2.5 Block Dynamic Data Exchange (DDE) Server Launch in Excel

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft 365 Apps |

#### What It Does
Prevents Microsoft Excel from **launching external DDE servers** to pull data into spreadsheets. DDE (Dynamic Data Exchange) is a legacy Windows inter-process communication mechanism that allows Excel to request data from external applications.

#### Why It Matters
DDE was heavily exploited in targeted phishing attacks, particularly between 2017 and 2020, but attacks continue today:

- A weaponized Excel file can use DDE to launch PowerShell, cmd.exe, or other executables directly — without requiring macros
- Because DDE does not use VBA macros, it bypasses macro security controls and many AV detections
- **DDEDownloader** malware (documented by Microsoft) used this technique to download and execute remote payloads
- The attack typically works by convincing the user to click through security warnings, which social engineering makes surprisingly effective

When DDE server launch is blocked, Excel cannot initiate external processes via DDE, cutting off this code execution path entirely.

#### How to Enable
Via Baseline Security Mode, Intune (Microsoft 365 Apps security baseline), or Group Policy:
```
Excel Options → Trust Center → External Content → Disable "Enable Dynamic Data Exchange Server Launch"
```

#### Framework Alignment
- MITRE ATT&CK: T1559.002 — Inter-Process Communication: Dynamic Data Exchange
- CIS Microsoft 365 Apps Security Baseline: External Content settings
- Microsoft Security Advisory 4053440

---

### 2.6 Block Microsoft Publisher

| Attribute | Detail |
|-----------|--------|
| **Status** | 🔴 At Risk |
| **Service** | Microsoft 365 Apps |

#### What It Does
Prevents **Microsoft Publisher from launching**. When this setting is enabled, Publisher cannot be opened by users.

#### Why It Matters
Microsoft has announced that Publisher will be **removed from Microsoft 365 in October 2026**. In the meantime:

- Publisher has a **large attack surface** with legacy code that is not receiving significant security investment
- It supports embedded OLE objects, Word documents (with DDE), and other active content types that can be weaponized
- Because Publisher is rarely used in most organizations, it represents unnecessary risk for a tool most users don't need
- Blocking it now reduces the attack surface and begins user transition ahead of the mandatory end-of-life

**If your organization does not use Publisher, enabling this setting has zero productivity impact and reduces risk immediately.**

#### Considerations
- Identify any users or departments actively using Publisher before enabling (check Microsoft 365 App telemetry)
- Plan migration to alternative tools (Word for newsletters, Canva, Adobe, or Designer for marketing materials)
- This aligns with Microsoft's own deprecation timeline

---

## Section 3: Room Devices and Endpoints (2 Settings)

These settings address security risks specific to **Microsoft Teams Rooms (MTR)** devices and the resource accounts they use. Teams Rooms devices present a unique security challenge: they use shared resource accounts that, if misused, could provide access to M365 data from unmanaged, potentially compromised endpoints.

---

### 3.1 Block Unmanaged Devices and Resource Account Sign-Ins to Microsoft 365 Apps

| Attribute | Detail |
|-----------|--------|
| **Status** | ⚪ Not Applicable |
| **Service** | Microsoft Teams |
| **Required Role** | Teams Administrator |

#### What It Does
Blocks **Teams resource accounts** (the service accounts used by Teams Rooms devices) from being used to sign in to Microsoft 365 applications from devices that are **not compliant, organization-managed endpoints**.

#### Why It Matters
Teams Rooms resource accounts are service accounts with access to calendars, Exchange, and sometimes SharePoint. They are often configured with broad permissions to enable meeting room functionality. Without this control:

- A compromised resource account credential could be used to sign in to Outlook, Teams, or SharePoint from any unmanaged device — anywhere in the world
- An attacker with access to a resource account could read organizational meeting data, access shared calendars, and potentially pivot to other resources
- Physical compromise of a Teams Rooms device (theft, tampering) could expose the resource account credentials stored on it

This setting ensures resource accounts can **only be used on compliant, enrolled MTR devices** — not on personal devices, attacker-controlled machines, or unmanaged endpoints.

#### Status Note
This setting shows **Not Applicable** in your tenant. This typically indicates either:
1. Your organization does not have Teams Rooms devices deployed, **or**
2. The prerequisite configuration (device compliance policies for MTR devices) has not been established

If Teams Rooms devices are deployed or planned, this setting should be evaluated and enabled.

---

### 3.2 Don't Allow Resource Accounts on Teams Rooms Devices to Access Microsoft 365 Files

| Attribute | Detail |
|-----------|--------|
| **Status** | ⚪ Not Applicable |
| **Service** | Microsoft Teams |
| **Required Role** | Teams Administrator |

#### What It Does
Removes the ability for **Teams Rooms resource accounts** to access Microsoft 365 file assets (SharePoint, OneDrive) used for meeting and collaboration purposes from Teams Rooms devices.

#### Why It Matters
Teams Rooms devices displaying shared content or accessing files in meetings use resource account permissions to do so. While this enables some convenience features, it also means:

- The resource account has file access permissions that could be abused if the account is compromised
- Physical access to the Teams Rooms device could expose organizational file content on the room display
- Unintended data disclosure could occur during meetings if files are automatically loaded or previewed

Restricting this access follows the **principle of least privilege** — resource accounts should have the minimum permissions needed to function (calendar access, meeting join) without broader file system access.

#### Status Note
As with Setting 3.1, this shows **Not Applicable** in your current tenant state. Evaluate when Teams Rooms devices are in scope.

---

## Summary: At-Risk Settings Prioritized by Impact

| Priority | Setting | Service | Action Required |
|----------|---------|---------|----------------|
| 🔴 Critical | Block Legacy Authentication | Entra ID | Deploy Conditional Access policy |
| 🔴 Critical | Require Phishing-Resistant MFA for Admins | Entra ID | Register phishing-resistant methods, then deploy CA policy |
| 🔴 High | Block New Password Credentials in Apps | Entra ID | Audit app registrations, then enable |
| 🔴 High | Turn On Restricted User Consent | Entra ID | Enable + configure admin consent workflow |
| 🔴 High | Block Access to EWS | Exchange | Run impact report first — check build requirements |
| 🔴 High | Block ActiveX Controls | M365 Apps | Audit legacy ActiveX dependencies |
| 🔴 High | Block DDE Server Launch in Excel | M365 Apps | Low compatibility risk — enable promptly |
| 🔴 High | Block Microsoft Publisher | M365 Apps | Check usage telemetry, then enable |
| 🔴 Medium | Don't Allow Custom Scripts in SharePoint | SharePoint | Audit custom script usage, migrate to SPFx |
| 🔴 Medium | Remove Microsoft Store for SharePoint | SharePoint | Low risk to enable — governance improvement |
| 🔴 Medium | Open Ancient Legacy Formats in Protected View | M365 Apps | Run impact report — likely low business impact |
| 🔴 Medium | Open Old Legacy Formats in Protected View | M365 Apps | Communication plan needed for users |
| 🔴 Medium | Block OLE Graph and OrgChart Objects | M365 Apps | Low compatibility risk — enable promptly |

---

## Recommended Deployment Approach

Baseline Security Mode provides built-in **impact reporting** for each setting. Microsoft's recommended approach:

1. **Run impact reports** for each At Risk setting before enabling
2. If an impact report shows **zero affected users**, enable the setting immediately
3. If critical dependencies exist, document them and plan remediation before enabling
4. Use a **phased rollout** by targeting pilot groups using the Conditional Access or policy scoping mechanisms before tenant-wide deployment
5. **Communicate changes** to end users affected by settings that change their experience (file format handling, authentication prompts)

This phased approach ensures a smooth transition to secure-by-default configurations without business disruption.

---

## How Inforcer Can Help

Inforcer specializes in M365 security configuration management across the full stack: Entra ID, Intune, Purview, SharePoint, Defender for Office 365, and XDR. We provide:

- **Baseline assessment** against Baseline Security Mode, CIS Benchmarks, and Microsoft Secure Score
- **Continuous configuration drift detection** — alerting when settings fall out of compliance
- **Remediation playbooks** for each At Risk setting with environment-specific guidance
- **Impact analysis** before any change is deployed to production
- **Documentation** of your security configuration state for audit and compliance purposes

---

*Document generated by Jon Hope | Based on Microsoft Learn documentation as of April 2026 | For the latest information, see [learn.microsoft.com/microsoft-365/baseline-security-mode](https://learn.microsoft.com/microsoft-365/baseline-security-mode/baseline-security-mode-settings)*
