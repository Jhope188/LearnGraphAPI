# M365 Healthcare Compliance Pack
**CIS Controls v8.1 × HIPAA Security / Privacy Rules × Microsoft 365**  
*M365 Healthcare Compliance Pack — Assessment Reference*

---

> **How to use this guide:**  
> This is a process-oriented assessment. Most HIPAA controls are administrative or operational — technology implements the guard rails, but people and documented processes are what OCR auditors actually review. Each section maps the CIS safeguard → HIPAA citation → M365 implementation → evidence you should collect.  
> 
> **Scoring:** Rate each item `✅ Implemented` / `⚠️ Partial` / `❌ Gap` / `N/A`.  
> Start with Implementation Group 1 (IG1) — these are baseline and non-negotiable. IG2 and IG3 add maturity.

---

## Assessment Scope

| Area | Microsoft 365 Surface |
|---|---|
| Identity & Access | Entra ID, Conditional Access, PIM, MFA |
| Information Protection | Microsoft Purview — Sensitivity Labels, DLP, AIP |
| Device Management | Intune — Compliance, Configuration Profiles |
| Threat Protection | Defender XDR, Defender for Office 365 |
| Audit & Monitoring | Microsoft Sentinel / Purview Audit, Activity Explorer |
| Backup & Recovery | M365 Backup, retention policies |
| Awareness & Training | Process-only — no M365 implementation |

---

## Section 1 — Asset Inventory and Data Governance

### CIS 1.1 — Enterprise Asset Inventory *(IG1)*
**HIPAA:** §164.310(d)(2)(iii) — Device and Media Controls  
**Requirement:** Maintain an accurate, up-to-date inventory of all assets that store or process PHI. Review bi-annually.

**M365 Implementation:**
- Intune device inventory — all enrolled devices visible in Intune admin center
- Entra ID — All Devices blade shows registered and compliant devices
- Defender for Endpoint — asset inventory with exposure scores

**Assessment Questions:**
- [ ] Is there a documented device inventory that includes all endpoints accessing PHI?
- [ ] Are mobile devices enrolled in Intune or equivalent MDM?
- [ ] Is the inventory reviewed at least bi-annually and records updated?
- [ ] Are non-managed devices blocked from accessing PHI via Conditional Access (require compliant device)?

**Evidence to Collect:**
- Intune → Devices → All Devices export
- Entra ID → Devices export
- Conditional Access policy requiring compliant/hybrid joined device for Exchange/SharePoint

---

### CIS 3.2 — Data Inventory *(IG1)*
**HIPAA:** §164.310(d)(2)(iii)  
**Requirement:** Inventory sensitive data (PHI). Review annually.

**M365 Implementation:**
- Purview Content Explorer — scans for sensitive information types across M365 workloads
- Purview Activity Explorer — shows where labeled content lives and how it moves
- Auto-labeling policies — scan SharePoint/OneDrive/Exchange for PHI SITs

**Assessment Questions:**
- [ ] Has a PHI data discovery scan been run in Purview Content Explorer?
- [ ] Are sensitivity labels deployed that classify PHI content (Healthcare - Confidential, Privileged, Research)?
- [ ] Is there a documented data flow map showing where PHI is created, stored, and transmitted?
- [ ] Is the data inventory reviewed annually?

**Evidence to Collect:**
- Purview → Content Explorer screenshot (sensitive data volume by location)
- Label report from Activity Explorer
- Healthcare label policy scope (confirm NOT org-wide — clinical staff only)

---

### CIS 3.3 — Data Access Control Lists *(IG1)*
**HIPAA:** §164.308(a)(3)(i), §164.308(a)(3)(ii)(A), §164.312(a)(1) — Access Control  
**Requirement:** Configure access based on need-to-know. Apply to file systems, databases, and applications.

**M365 Implementation:**
- Sensitivity label encryption — Healthcare - Privileged restricts decryption to `Purview-Medical-Privileged` group only
- Healthcare - Research restricts to `Purview-Medical-Research` group
- SharePoint site permissions aligned to clinical roles
- Entra ID groups with documented membership criteria

**Assessment Questions:**
- [ ] Is access to PHI SharePoint sites restricted to authorized clinical roles?
- [ ] Are the `Purview-Medical-Privileged` and `Purview-Medical-Research` groups populated with minimal standing membership?
- [ ] Is PIM for Groups configured so clinical staff activate JIT access rather than having standing membership to privileged label groups?
- [ ] Are access control lists reviewed periodically (recommended: quarterly)?

**Evidence to Collect:**
- `Purview-Medical-Privileged` group membership export
- PIM for Groups configuration screenshot
- SharePoint site permission reports for PHI repositories

> ⚠️ **PIM Note:** Standing membership in `Purview-Medical-Privileged` for anyone beyond the compliance lead and privacy officer is a gap. Clinical staff should activate JIT via PIM for a bounded time window.

---

### CIS 3.5 — Secure Data Disposal *(IG1)*
**HIPAA:** §164.310(d)(2)(i)  
**Requirement:** Dispose of data in a manner commensurate with its sensitivity.

**M365 Implementation:**
- Purview retention policies — define hold and delete lifecycle for PHI content
- Purview disposition reviews — manual approval before destruction of PHI records
- Intune — Remote Wipe / Selective Wipe for device offboarding

**Assessment Questions:**
- [ ] Are retention policies in place that govern PHI lifecycle (hold period + deletion schedule)?
- [ ] Are disposition reviews configured for Healthcare labeled content before deletion?
- [ ] Is there a documented process for revoking access and wiping devices when clinical staff leave?

**Evidence to Collect:**
- Purview → Data Lifecycle Management → Retention policies scoped to Healthcare labels
- Intune remote wipe policy documentation

---

### CIS 3.9 — Encrypt Data on Removable Media *(IG2)*
**HIPAA:** §164.310(d)(1)  
**Requirement:** Encrypt data on removable media.

**M365 Implementation:**
- Intune — Endpoint Security → BitLocker policy for OS drives
- Intune DLP or Defender for Endpoint — block or audit removable media
- Purview DLP — "HIPAA - PHI Exfiltration Prevention" policy includes endpoint scope

**Assessment Questions:**
- [ ] Is BitLocker enforced on all managed Windows endpoints?
- [ ] Is there a removable media policy (block or encrypt-required) via Intune?
- [ ] Does the DLP policy cover endpoint to catch PHI copied to USB?

**Evidence to Collect:**
- Intune BitLocker compliance report
- Defender for Endpoint → Device configuration → Removable media policy

---

### CIS 3.10 — Encrypt Data in Transit *(IG2)*
**HIPAA:** §164.312(a)(2)(iv), §164.312(e)(1), §164.312(e)(2)(ii)  
**Requirement:** Encrypt sensitive data in transit.

**M365 Implementation:**
- Sensitivity label encryption travels with the file and email — enforced end-to-end
- Exchange Online — TLS enforced by default; mail flow rules for PHI destinations
- Defender for Office 365 — Safe Attachments + Safe Links scan encrypted content
- Purview DLP — "HIPAA - PHI Exfiltration Prevention" encrypts outbound email containing PHI

**Assessment Questions:**
- [ ] Is TLS enforced for email transmission to external domains that receive PHI? (mail flow connector)
- [ ] Does the Healthcare - Confidential label apply encryption to emails containing standard PHI?
- [ ] Is there a DLP policy that encrypts outbound email matching PHI SITs?

**Evidence to Collect:**
- Exchange Admin Center → Mail flow → Connectors (TLS enforcement)
- DLP rule review: "Encrypt outbound email" action configured in HIPAA PHI Exfiltration Prevention

---

### CIS 3.11 — Encrypt Data at Rest *(IG2)*
**HIPAA:** §164.312(a)(2)(iv), §164.312(e)(2)(ii)  
**Requirement:** Encrypt sensitive data at rest.

**M365 Implementation:**
- SharePoint/OneDrive — Microsoft-managed encryption at rest (service-side, always on)
- Exchange Online — mailbox encryption at rest (always on)
- Sensitivity labels — add client-side AIP encryption layered on top of service encryption
- BitLocker — endpoint disk encryption
- Double Key Encryption (DKE) — available for highest-sensitivity PHI where customer controls the key

**Assessment Questions:**
- [ ] Is BitLocker enforced on all endpoints that cache PHI locally?
- [ ] Are Healthcare - Privileged and Research labels using named-group AIP encryption (not just service-side)?
- [ ] For the most sensitive PHI (42 CFR Part 2), has DKE been evaluated?

**Evidence to Collect:**
- Intune BitLocker status report
- Label encryption settings: `Get-Label | Where DisplayName -like 'Healthcare*' | Select DisplayName, EncryptionEnabled, EncryptionProtectionType`

---

### CIS 3.13 — Deploy a DLP Solution *(IG3)*
**HIPAA:** §164.312(e)(2)(i), §164.312(e)(2)(ii)  
**Requirement:** Automated tool to identify sensitive data stored, processed, or transmitted.

**M365 Implementation — Healthcare Pack:**

| Policy | Trigger | Action |
|---|---|---|
| HIPAA - PHI Exfiltration Prevention | SSN + Medical Terms (AND logic) | Block external, encrypt email, alert compliance |
| HIPAA - Privileged PHI Controls | Healthcare - Privileged label | Block ALL external, immediate alert, block Teams |
| HIPAA - Copilot PHI Boundary | Healthcare - Confidential or Privileged label | Block Copilot processing |

**Assessment Questions:**
- [ ] Are all three HIPAA DLP policies deployed and in Enforce mode (not Audit)?
- [ ] Are DLP alerts being reviewed in Purview Alerts at least weekly?
- [ ] Is the Copilot PHI Boundary policy verified in the portal with label conditions set? (Cannot be set via PowerShell — requires manual portal step)
- [ ] Has the DLP policy been tested for false positives and tuned after audit period?

> ⚠️ **Important:** The Copilot PHI Boundary policy requires label conditions to be added manually in the Purview portal after script deployment. This is a documented API limitation — sensitivity label conditions in DLP rules cannot be combined with SIT conditions in the same rule.

**Evidence to Collect:**
- `Get-DlpCompliancePolicy | Where Name -like 'HIPAA*' | FT Name, Mode, Enabled`
- Purview DLP Alerts dashboard screenshot
- Copilot policy rule conditions screenshot from portal

---

### CIS 3.14 — Log Sensitive Data Access *(IG3)*
**HIPAA:** §164.312(b) — Audit Controls; §164.312(c)(1) — Integrity  
**Requirement:** Log access, modification, and disposal of sensitive data.

**M365 Implementation:**
- Purview Audit (Premium) — logs label application, removal, and document access
- Purview Activity Explorer — visual timeline of label activity per user
- SharePoint audit logs — file access and permission changes
- Microsoft Sentinel — aggregate and alert on anomalous PHI access patterns

**Assessment Questions:**
- [ ] Is Purview Audit (Premium) enabled for the tenant? (Required for long-term audit log retention — up to 10 years)
- [ ] Are audit logs retained for a minimum of 6 years to satisfy HIPAA §164.530(j)?
- [ ] Is Activity Explorer reviewed periodically to detect unexpected label removal or downgrade?
- [ ] Are Sentinel analytics rules in place to alert on bulk PHI access or label stripping?

**Evidence to Collect:**
- Purview → Audit → Search capability confirmation
- Audit retention policy settings
- Sentinel workspace connected to M365 Defender data connector

---

## Section 2 — Identity and Access Management

### CIS 5.1 — Account Inventory *(IG1)*
**HIPAA:** §164.312(a)(2)(i) — Unique User Identification  
**Requirement:** Inventory of all user, admin, and service accounts. Validate quarterly.

**M365 Implementation:**
- Entra ID — All Users with licensed status, last sign-in, MFA status
- Entra ID — Service principals and managed identities inventory
- Entra ID Governance — Access Reviews for PHI-access groups

**Assessment Questions:**
- [ ] Is there a process to review active accounts quarterly?
- [ ] Are stale accounts (no sign-in > 90 days) identified and disabled?
- [ ] Are access reviews configured for `Purview-Medical-Privileged` and `Purview-Medical-Research` groups?
- [ ] Are service accounts and shared mailboxes that access PHI documented?

**Evidence to Collect:**
- Entra ID Governance → Access Reviews — confirm reviews scoped to healthcare groups
- Sign-in logs export for stale account identification

---

### CIS 6.1 — Access Granting Process *(IG1)*
**HIPAA:** §164.312(a)(2)(i)  
**Requirement:** Documented process for granting access at hire or role change.

**M365 Implementation:**
- Entra ID Governance — Entitlement Management for access package provisioning
- Lifecycle Workflows — automate day-0 provisioning and offboarding
- PIM — require approval workflow for privileged role activation

**Assessment Questions:**
- [ ] Is there a documented joiner/mover/leaver process for clinical staff who need PHI access?
- [ ] Are access packages in Entitlement Management used to provision clinical role access?
- [ ] Is there an approval workflow for adding members to `Purview-Medical-Privileged`?

**Evidence to Collect:**
- Entitlement Management → Access packages for clinical staff roles
- PIM approval workflow for healthcare group membership

---

### CIS 6.2 — Access Revoking Process *(IG1)*
**HIPAA:** §164.308(a)(3)(ii)(C) — Termination Procedures  
**Requirement:** Revoke access immediately upon termination.

**M365 Implementation:**
- Lifecycle Workflows — offboarding workflow: disable account, revoke sessions, remove group memberships
- Conditional Access — requires compliant device + MFA (revoked session = immediate lockout)
- Intune — remote wipe of enrolled device on termination

**Assessment Questions:**
- [ ] Does the offboarding process include immediate Entra account disable and session revocation?
- [ ] Are Lifecycle Workflows configured to remove clinical group membership on termination?
- [ ] Is there a signed-off SLA for completing offboarding steps (recommended: same business day)?

**Evidence to Collect:**
- Lifecycle Workflows → Leaver workflow configuration
- Policy documentation for HR-to-IT termination notification process

---

### CIS 4.3 — Session Locking *(IG1)*
**HIPAA:** §164.312(a)(2)(iii) — Automatic Logoff  
**Requirement:** Auto session lock after inactivity. ≤15 min for workstations, ≤2 min for mobile.

**M365 Implementation:**
- Intune → Settings Catalog — `Interactive logon: Machine inactivity limit` (Windows)
- Intune → Device Restrictions — screen lock timeout for iOS/Android
- Conditional Access — Sign-in frequency policy for web sessions (recommend 1-4 hours for PHI access)

**Assessment Questions:**
- [ ] Is screen lock enforced via Intune at ≤15 minutes for Windows workstations?
- [ ] Is screen lock enforced at ≤2 minutes for mobile devices?
- [ ] Is Conditional Access Sign-in Frequency configured for applications accessing PHI?

**Evidence to Collect:**
- Intune → Configuration profiles → Screen lock settings
- CA policy: Sign-in Frequency for Exchange Online / SharePoint Online

---

### CIS 6.8 — Role-Based Access Control *(IG3)*
**HIPAA:** §164.308(a)(3)(ii)(B), §164.308(a)(4)(i), §164.308(a)(4)(ii)(C) — Role-based access  
**Requirement:** Define and maintain RBAC. Access control reviews annually.

**M365 Implementation:**
- Entra ID RBAC — built-in roles (Global Admin, Compliance Admin, Security Reader, etc.)
- PIM — eligible role assignment with approval and justification
- Purview label encryption — access controlled by named security groups (RBAC at content level)
- Access Reviews — annual reviews for privileged Entra roles and clinical groups

**Assessment Questions:**
- [ ] Are Entra admin roles assigned via PIM (eligible, not permanent)?
- [ ] Is there no standing Global Admin other than break-glass accounts?
- [ ] Are access reviews scheduled for all privileged Entra roles annually?
- [ ] Is the principle of least privilege documented and enforced for clinical data access?

**Evidence to Collect:**
- PIM → Role assignments (confirm no permanent Global Admin other than break-glass)
- Entra ID Governance → Access Reviews for privileged roles

---

## Section 3 — Vulnerability and Patch Management

### CIS 7.1 — Vulnerability Management Process *(IG1)*
**HIPAA:** §164.308(a)(1)(ii)(A) — Risk Analysis; §164.308(a)(1)(ii)(B) — Risk Management  
**Requirement:** Documented vulnerability management process. Review annually.

**M365 Implementation:**
- Defender for Endpoint — Threat & Vulnerability Management (TVM)
- Intune — compliance policies flag unpatched devices as non-compliant
- Conditional Access — non-compliant devices blocked from PHI access

**Assessment Questions:**
- [ ] Is there a documented vulnerability management policy that defines scan frequency, severity SLAs, and remediation tracking?
- [ ] Is Defender TVM enabled and reviewed regularly?
- [ ] Does Intune compliance policy mark devices non-compliant if OS patches are out of date?
- [ ] Are non-compliant devices automatically blocked from accessing PHI via Conditional Access?

**Evidence to Collect:**
- Intune → Compliance policies → OS version / security patch requirements
- CA policy requiring compliant device for Exchange and SharePoint
- Defender TVM dashboard screenshot

---

### CIS 7.2 — Remediation Process *(IG1)*
**HIPAA:** §164.308(a)(1)(ii)(A), §164.308(a)(1)(ii)(B)  
**Requirement:** Risk-based remediation strategy. Monthly reviews.

**Assessment Questions:**
- [ ] Are remediation timelines defined by severity (e.g., Critical: 7 days, High: 30 days)?
- [ ] Is there a documented process for tracking vulnerability remediation to closure?
- [ ] Are remediation metrics reviewed monthly by a designated owner?

> This is a process control — no M365 tooling implements it automatically. Requires documented policy and governance cadence.

---

## Section 4 — Audit Logging and Monitoring

### CIS 8.1 — Audit Log Management Process *(IG1)*
**HIPAA:** §164.312(b) — Audit Controls  
**Requirement:** Documented logging requirements, collection, review, and retention. Review annually.

**M365 Implementation:**
- Purview Audit (Standard vs. Premium) — unified audit log across M365 workloads
- Microsoft Sentinel — SIEM for centralized collection and retention
- Diagnostic settings — route Entra sign-in and audit logs to Log Analytics

**Assessment Questions:**
- [ ] Is there a documented audit log management policy?
- [ ] Is Purview Audit enabled for all M365 workloads?
- [ ] Are audit logs retained for at least 6 years (HIPAA §164.530(j) requires 6 years for documentation)?
- [ ] Are logs exported to Sentinel or Log Analytics to meet retention requirements beyond standard 90-day M365 default?

> ⚠️ **Retention Gap:** Default Purview Audit Standard retains logs for 90 days. HIPAA requires documentation retained for 6 years. Audit Premium extends to 1 year; custom retention policies can extend to 10 years. This is a common gap.

**Evidence to Collect:**
- Purview Audit → Retention policies configuration
- Sentinel data connector status for M365 Defender

---

### CIS 8.2 — Collect Audit Logs *(IG1)*
**HIPAA:** §164.312(b)  
**Requirement:** Logging enabled across enterprise assets.

**Assessment Questions:**
- [ ] Is unified audit logging enabled in the M365 tenant? (`Get-AdminAuditLogConfig | Select UnifiedAuditLogIngestionEnabled`)
- [ ] Are Entra ID sign-in and audit logs streaming to Log Analytics?
- [ ] Are Exchange, SharePoint, Teams, and Purview audit events all enabled?

**Evidence to Collect:**
- `Get-AdminAuditLogConfig` output confirming `UnifiedAuditLogIngestionEnabled: True`
- Log Analytics workspace → M365 data connector status

---

### CIS 8.11 — Audit Log Reviews *(IG2)*
**HIPAA:** §164.308(a)(1)(ii)(D) — Information System Activity Review; §164.312(b)  
**Requirement:** Weekly review of audit logs for anomalies.

**M365 Implementation:**
- Sentinel analytics rules — automated alerts for anomalous sign-ins, bulk downloads, label stripping
- Purview Activity Explorer — PHI label activity timeline
- Defender XDR incidents — correlated alerts across identity, endpoint, and email

**Assessment Questions:**
- [ ] Is there a designated person responsible for reviewing audit alerts weekly?
- [ ] Are Sentinel analytics rules configured to detect: bulk PHI downloads, label removal, impossible travel, MFA bypass attempts?
- [ ] Are Purview DLP alerts reviewed weekly?
- [ ] Is there a documented process for escalating anomalous activity?

**Evidence to Collect:**
- Sentinel → Analytics rules list (confirm PHI/identity-focused rules active)
- DLP Alerts dashboard showing review history

---

### CIS 13.1 — Centralize Security Event Alerting *(IG2)*
**HIPAA:** §164.312(b)  
**Requirement:** SIEM or log analytics platform with security-relevant correlation alerts.

**M365 Implementation:**
- Microsoft Sentinel — SIEM with M365 Defender, Entra, and Purview connectors
- Defender XDR — native correlation across Microsoft security stack
- Sentinel Workbooks — HIPAA/HITRUST compliance workbook available

**Assessment Questions:**
- [ ] Is Microsoft Sentinel deployed and connected to M365 data sources?
- [ ] Is the HIPAA/HITRUST Sentinel workbook deployed and reviewed?
- [ ] Are incident response workflows integrated with Sentinel incidents?

**Evidence to Collect:**
- Sentinel → Data connectors — confirm M365 Defender, Entra ID, Office 365 connectors enabled
- Sentinel → Workbooks → HIPAA HITRUST workbook

---

## Section 5 — Malware and Endpoint Protection

### CIS 10.1 — Anti-Malware *(IG1)*
**HIPAA:** §164.308(a)(5)(ii)(B) — Protection from Malicious Software  
**Requirement:** Deploy and maintain anti-malware on all enterprise assets.

**M365 Implementation:**
- Defender for Endpoint — next-gen anti-malware + EDR on all managed endpoints
- Intune compliance policy — require Defender real-time protection enabled
- Intune → Endpoint Security → Antivirus profiles

**Assessment Questions:**
- [ ] Is Defender for Endpoint deployed on all Windows/macOS/iOS/Android devices accessing PHI?
- [ ] Does Intune compliance policy mark devices non-compliant if anti-malware is disabled?
- [ ] Is Defender for Endpoint in Active mode (not Passive)?

**Evidence to Collect:**
- Defender portal → Devices → Onboarded devices count vs. Intune enrolled devices count
- Intune compliance policy → Defender real-time protection requirement

---

### CIS 10.3 / 10.4 — Removable Media Controls *(IG1 / IG2)*
**HIPAA:** §164.310(d)(1) — Device and Media Controls  
**Requirement:** Disable autorun; configure automatic scanning of removable media.

**M365 Implementation:**
- Intune → Settings Catalog — Disable Autorun/Autoplay
- Defender for Endpoint — Device control policy for removable media
- Purview DLP — endpoint policy blocks PHI copy to removable media

**Assessment Questions:**
- [ ] Is Autorun/Autoplay disabled via Intune Settings Catalog on all managed Windows endpoints?
- [ ] Is Defender for Endpoint device control policy configured to audit or block USB storage?
- [ ] Does the HIPAA DLP endpoint policy prevent copying Healthcare - Confidential content to removable media?

---

## Section 6 — Backup and Recovery

### CIS 11.1 — Data Recovery Process *(IG1)*
**HIPAA:** §164.308(a)(7)(ii)(A), §164.308(a)(7)(ii)(B), §164.310(d)(2)(iv) — Contingency Plan  
**Requirement:** Documented data recovery process with scope, prioritization, and security of backups.

**M365 Implementation:**
- M365 Backup — point-in-time restore for Exchange, SharePoint, OneDrive
- Purview retention policies — preserve content even if user deletes (compliance hold)
- Litigation hold — preserve all mailbox content for legal hold scenarios

**Assessment Questions:**
- [ ] Is M365 Backup configured for Exchange, SharePoint Online, and OneDrive?
- [ ] Are backup retention periods documented and aligned to HIPAA contingency plan requirements?
- [ ] Is there a tested recovery procedure? (Tabletop exercise or actual restore test)
- [ ] Are backups themselves encrypted and access-controlled (not accessible to regular clinical staff)?

**Evidence to Collect:**
- M365 Backup policy configuration
- Last restore test documentation (date, scope, result)

---

### CIS 11.2 — Automated Backups *(IG1)*
**HIPAA:** §164.308(a)(7)(ii)(A)  
**Requirement:** Automated backups weekly at minimum; more frequent for sensitive data.

**Assessment Questions:**
- [ ] Is M365 Backup running on an automated schedule (not manual)?
- [ ] Is backup frequency appropriate for PHI data (recommend daily or continuous for Exchange)?
- [ ] Are backup completion/failure alerts configured?

---

## Section 7 — Vendor and Third-Party Management

### CIS 15.4 — Service Provider Contracts *(IG2)*
**HIPAA:** §164.308(a)(4)(ii)(A), §164.308(b)(1-3) — **Business Associate Agreements (BAA)**  
**Requirement:** Service provider contracts must include security requirements.

> This is one of the most commonly cited HIPAA violations. A missing BAA with a vendor who touches PHI is a direct violation.

**M365 Implementation:**
- Microsoft HIPAA BAA — must be explicitly accepted in Microsoft Admin Center (M365 Trust Center)
- BAA covers: Exchange Online, SharePoint Online, OneDrive, Teams, Purview, Intune, Defender
- Third-party ISVs that touch PHI in M365 pipelines need their own BAAs

**Assessment Questions:**
- [ ] Is the Microsoft HIPAA BAA signed and on record? (Microsoft Admin Center → Settings → Org Settings → Security & Privacy → HIPAA BAA)
- [ ] Is there a vendor inventory of all third-party tools that touch PHI?
- [ ] Does each PHI-touching vendor have a signed BAA on file?
- [ ] Are BAAs reviewed when contracts renew?

**Evidence to Collect:**
- Microsoft HIPAA BAA acceptance confirmation screenshot
- Vendor inventory with BAA status for each PHI-touching vendor

> **E5 / E5 Compliance — Compliance Manager:**  
> If the tenant is licensed for Microsoft 365 E5 or E5 Compliance, run the **HIPAA/HITECH assessment** in Microsoft Purview Compliance Manager. Compliance Manager maps Microsoft's built-in controls and your own implemented actions directly to the HIPAA regulation text, generates an overall compliance score, and surfaces improvement actions ranked by impact.  
> **Path:** Purview portal → Compliance Manager → Assessments → Add Assessment → HIPAA/HITECH  
> Review the improvement actions list and cross-reference against the gaps identified in this guide. Any action marked "Microsoft managed" is covered by Microsoft's responsibility under the BAA; any action marked "Customer managed" is your responsibility to implement and document.

---

### CIS 15.5 — Assess Service Providers *(IG3)*
**HIPAA:** §164.308(a)(8) — Evaluation  
**Requirement:** Assess vendors annually via SOC 2, questionnaire, or equivalent.

**Assessment Questions:**
- [ ] Are SOC 2 Type II reports obtained from PHI-touching vendors annually?
- [ ] Is there a formal vendor risk assessment process?
- [ ] Are vendor assessments triggered when a vendor announces a security incident or product change?

---

## Section 8 — Security Awareness and Training

### CIS 14.1 — Security Awareness Program *(IG1)*
**HIPAA:** §164.308(a)(5)(i) — Security Awareness Training  
**Requirement:** Training at hire and annually. Review annually.

> No M365 tooling replaces this — it is a process and people control.

**Assessment Questions:**
- [ ] Is there a documented security awareness training program?
- [ ] Is HIPAA-specific training conducted at hire and annually for all workforce members?
- [ ] Are training completion records maintained (required under HIPAA §164.530(j))?
- [ ] Does training content cover PHI handling, sensitivity label use, and how to report a breach?

**Evidence to Collect:**
- Training completion records (LMS export or equivalent)
- Training content showing HIPAA-specific modules
- Policy document for training program

---

### CIS 14.3 — Authentication Best Practices Training *(IG1)*
**HIPAA:** §164.308(a)(5)(ii)(C), §164.308(a)(5)(ii)(D) — Password Management  
**Requirement:** Train workforce on MFA, password composition, credential management.

**M365 Implementation (technical enforcement):**
- Entra ID → Conditional Access — require MFA for all users, especially PHI access
- Entra ID → Authentication Methods — enforce phishing-resistant MFA (Passkeys, FIDO2, CBA) for clinical staff
- Microsoft Entra Password Protection — block common passwords
- Disable legacy authentication via CA policy

**Assessment Questions:**
- [ ] Is MFA enforced via Conditional Access for ALL users (not just admins)?
- [ ] Is legacy authentication blocked via CA policy?
- [ ] Is phishing-resistant MFA (FIDO2, passkey, or CBA) deployed for clinical staff with PHI access?
- [ ] Does security training include a module specifically on credential security and phishing recognition?

**Evidence to Collect:**
- CA policy: Block Legacy Authentication — confirm `Enabled` and no gaps in exclusions
- CA policy: Require MFA for All Users — confirm scope includes clinical staff
- Authentication methods policy showing phishing-resistant methods enabled

---

### CIS 14.4 — Data Handling Training *(IG1)*
**HIPAA:** §164.310(d)(2)(i)  
**Requirement:** Train on storing, transferring, archiving, and destroying sensitive data. Clear screen/desk.

**Assessment Questions:**
- [ ] Does training cover sensitivity label application (when and how to apply Healthcare labels)?
- [ ] Are users trained on which channels are appropriate for PHI (e.g., Teams vs. personal email)?
- [ ] Is there a clean desk / clear screen policy enforced for clinical workstations?

---

### CIS 14.6 — Incident Recognition and Reporting Training *(IG1)*
**HIPAA:** §164.308(a)(6)(ii) — Response and Reporting  
**Requirement:** Train workforce to recognize and report potential incidents.

**Assessment Questions:**
- [ ] Are all workforce members trained on what constitutes a potential HIPAA breach?
- [ ] Is there a clearly communicated, documented process for reporting suspected PHI disclosure?
- [ ] Is the reporting process tested (e.g., phishing simulation, tabletop exercise)?

**Evidence to Collect:**
- Incident reporting procedure document
- Phishing simulation results (Defender for Office 365 → Attack Simulator)

---

## Section 9 — Incident Response

### CIS 17.1 — Designate Incident Handling Personnel *(IG1)*
**HIPAA:** §164.308(a)(2) — Assigned Security Responsibility  
**Requirement:** Designated person (+ backup) to manage incident handling.

**Assessment Questions:**
- [ ] Is there a named HIPAA Security Officer and a backup?
- [ ] Is the Security Officer designation documented and current?
- [ ] Does the Security Officer have access to Purview Audit, Sentinel, and Defender portals?

---

### CIS 17.3 — Incident Reporting Process *(IG1)*
**HIPAA:** §164.308(a)(6)(ii)  
**Requirement:** Documented process for workforce to report security incidents.

**Assessment Questions:**
- [ ] Is there a documented incident reporting procedure accessible to all workforce?
- [ ] Is the reporting mechanism tested at least annually?
- [ ] Are DLP alerts and Sentinel incidents routed to the Security Officer?

---

### CIS 17.4 — Incident Response Process *(IG2)*
**HIPAA:** §164.308(a)(6)(i), §164.308(a)(7)(i) — Incident Response and Contingency Plan  
**Requirement:** Documented IR process with roles, compliance requirements, and communication plan.

**M365 Implementation:**
- Defender XDR — incident management with automated investigation
- Purview Audit — forensic evidence for breach scope determination
- HIPAA Breach Notification Rule — 60-day notification requirement to HHS and affected individuals

**Assessment Questions:**
- [ ] Does the IR plan specifically address HIPAA breach notification timelines (60 days to HHS, prompt individual notification)?
- [ ] Is there a documented PHI breach assessment procedure?
- [ ] Are Defender XDR and Purview Audit explicitly referenced in the IR runbook as forensic tools?
- [ ] Is the IR plan reviewed annually?

**Evidence to Collect:**
- IR plan document showing HIPAA-specific breach notification procedure
- Defender XDR → Incidents review process documentation

---

### CIS 17.7 — IR Exercises *(IG2)*
**HIPAA:** §164.308(a)(7)(ii)(D) — Testing and Revision  
**Requirement:** Annual IR exercise testing communication, decision-making, and workflows.

**Assessment Questions:**
- [ ] Is there a documented annual tabletop exercise for PHI breach scenarios?
- [ ] Does the exercise test the HIPAA breach notification workflow?
- [ ] Are exercise results documented with corrective actions tracked to closure?

---

### CIS 17.8 — Post-Incident Reviews *(IG2)*
**HIPAA:** §164.308(a)(8) — Evaluation  
**Requirement:** Post-incident reviews to capture lessons learned.

**Assessment Questions:**
- [ ] Is there a documented after-action review process following any security incident?
- [ ] Are lessons learned incorporated into updated policies, training, or technical controls?

---

## Section 10 — Penetration Testing

### CIS 18.1 — Penetration Testing Program *(IG2)*
**HIPAA:** §164.308(a)(8) — Evaluation  
**Requirement:** Documented pen test program with scope, frequency, and remediation.

**Assessment Questions:**
- [ ] Is there a documented penetration testing program?
- [ ] Does the scope include M365 / cloud attack surface (identity, email, SharePoint)?
- [ ] Is pen testing conducted at least annually or after significant environment changes?

---

### CIS 18.3 — Remediate Pen Test Findings *(IG2)*
**HIPAA:** §164.308(a)(1)(ii)(B) — Risk Management  
**Requirement:** Remediate findings per documented vulnerability remediation process.

**Assessment Questions:**
- [ ] Are pen test findings tracked in a formal remediation register?
- [ ] Are critical/high findings remediated within defined SLAs?
- [ ] Are pen test results and remediation status reviewed by leadership?

---

## Summary Scorecard Template

| CIS Control | HIPAA Citation | IG | Status | Owner | Due Date | Notes |
|---|---|---|---|---|---|---|
| 1.1 Asset Inventory | §164.310(d)(2)(iii) | 1 | | | | |
| 3.2 Data Inventory | §164.310(d)(2)(iii) | 1 | | | | |
| 3.3 Access Control Lists | §164.308(a)(3), §164.312(a)(1) | 1 | | | | |
| 3.5 Data Disposal | §164.310(d)(2)(i) | 1 | | | | |
| 3.9 Removable Media Encryption | §164.310(d)(1) | 2 | | | | |
| 3.10 Encrypt in Transit | §164.312(e) | 2 | | | | |
| 3.11 Encrypt at Rest | §164.312(a)(2)(iv) | 2 | | | | |
| 3.13 DLP Solution | §164.312(e)(2) | 3 | | | | |
| 3.14 Log Data Access | §164.312(b), §164.312(c) | 3 | | | | |
| 4.3 Session Locking | §164.312(a)(2)(iii) | 1 | | | | |
| 5.1 Account Inventory | §164.312(a)(2)(i) | 1 | | | | |
| 6.1 Access Granting | §164.312(a)(2)(i) | 1 | | | | |
| 6.2 Access Revoking | §164.308(a)(3)(ii)(C) | 1 | | | | |
| 6.8 RBAC | §164.308(a)(3-4) | 3 | | | | |
| 7.1 Vuln Management Process | §164.308(a)(1)(ii) | 1 | | | | |
| 7.2 Remediation Process | §164.308(a)(1)(ii) | 1 | | | | |
| 8.1 Audit Log Process | §164.312(b) | 1 | | | | |
| 8.2 Collect Audit Logs | §164.312(b) | 1 | | | | |
| 8.11 Audit Log Reviews | §164.308(a)(1)(ii)(D) | 2 | | | | |
| 10.1 Anti-Malware | §164.308(a)(5)(ii)(B) | 1 | | | | |
| 10.3 Disable Autorun | §164.310(d)(1) | 1 | | | | |
| 10.4 Scan Removable Media | §164.310(d)(1) | 2 | | | | |
| 11.1 Data Recovery Process | §164.308(a)(7) | 1 | | | | |
| 11.2 Automated Backups | §164.308(a)(7)(ii)(A) | 1 | | | | |
| 13.1 SIEM/Alerting | §164.312(b) | 2 | | | | |
| 14.1 Security Awareness | §164.308(a)(5)(i) | 1 | | | | |
| 14.3 Auth Best Practices Training | §164.308(a)(5)(ii)(C-D) | 1 | | | | |
| 14.4 Data Handling Training | §164.310(d)(2)(i) | 1 | | | | |
| 14.6 Incident Reporting Training | §164.308(a)(6)(ii) | 1 | | | | |
| 15.4 Vendor Contracts / BAA | §164.308(b) | 2 | | | | |
| 15.5 Assess Service Providers | §164.308(a)(8) | 3 | | | | |
| 17.1 IR Personnel | §164.308(a)(2) | 1 | | | | |
| 17.3 IR Reporting Process | §164.308(a)(6)(ii) | 1 | | | | |
| 17.4 IR Process | §164.308(a)(6-7) | 2 | | | | |
| 17.7 IR Exercises | §164.308(a)(7)(ii)(D) | 2 | | | | |
| 17.8 Post-Incident Reviews | §164.308(a)(8) | 2 | | | | |
| 18.1 Pen Test Program | §164.308(a)(8) | 2 | | | | |
| 18.3 Remediate Pen Test Findings | §164.308(a)(1)(ii)(B) | 2 | | | | |

---

## Key Gaps to Validate First (IG1 Process Controls That Are Frequently Missing)

These IG1 controls are commonly found as gaps in M365 healthcare assessments because they are **process-only** — no tooling implements them automatically:

1. **Microsoft HIPAA BAA not signed** — Check first. Direct violation if missing.
2. **Audit log retention < 6 years** — Default M365 is 90 days. Must extend via Audit Premium + custom policy or Sentinel.
3. **No documented termination / offboarding procedure** — CIS 6.2, HIPAA §164.308(a)(3)(ii)(C).
4. **Training records not maintained** — HIPAA requires documentation of all training under §164.530(j).
5. **DLP policies in Audit mode, never promoted to Enforce** — Common after deployment; requires follow-up.
6. **Copilot PHI Boundary policy not verified in portal** — Label conditions cannot be set via PowerShell; requires manual portal step post-script.
7. **PIM not configured for `Purview-Medical-Privileged`** — Standing membership for clinical staff is a least-privilege violation.

---

## References

- [CIS Controls v8.1](https://www.cisecurity.org/controls/v8)
- [HIPAA Security Rule — HHS](https://www.hhs.gov/hipaa/for-professionals/security/index.html)
- [HIPAA Privacy Rule — HHS](https://www.hhs.gov/hipaa/for-professionals/privacy/index.html)
- [42 CFR Part 2 — SAMHSA](https://www.samhsa.gov/about-us/who-we-are/laws-regulations/confidentiality-regulations-faqs)
- [Microsoft HIPAA BAA](https://www.microsoft.com/en-us/trust-center/compliance/hipaa)
- [Microsoft Purview DLP Policy Reference](https://learn.microsoft.com/en-us/purview/dlp-policy-reference)
- [Sensitivity Label Encryption — Microsoft Learn](https://learn.microsoft.com/en-us/purview/encryption-sensitivity-labels)
- [Purview Audit Premium](https://learn.microsoft.com/en-us/purview/audit-premium)
- [Sentinel HIPAA/HITRUST Workbook](https://learn.microsoft.com/en-us/azure/sentinel/sentinel-solution)
- [M365 Healthcare Compliance Pack — README](./README-HealthcarePack.md)

---

*M365 Healthcare Compliance Pack v1.0 | July 2026*
