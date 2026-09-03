# Microsoft Teams Security Reference
**CIS M365 Foundations v7.0.0 + Current Threat Intelligence**  
Last updated: September 2026

---

## How to use this document

Section 1 is the CIS v7.0.0 controls for Teams — what the benchmark says, where to configure it, and the operational impact. Section 2 is threat intelligence: real attack campaigns that have hit Teams, what they exploited, and what stops them. Some of those mitigations overlap with CIS; most don't. They're worth reviewing as a separate conversation with clients.

---

## 🚨 Recent Guidance Changes (last 6 months, reviewed Sep 2026)

Several Microsoft 365 changes directly reinforce or extend the social-engineering mitigations in Section 2 and the messaging control in 8.6.1:

1. **[MC1466296 — Report security concerns in meetings](https://deltapulse.app/item/MC1466296)** ([Roadmap 569207](https://deltapulse.app/item/569207)). New **"Report a concern"** button in the participant tile/pane during Teams meetings, letting attendees report phishing, impersonation, scams, and social engineering directly from a live meeting. Rolling out Targeted Release late September 2026, GA mid-to-late October 2026. **Enabled by default.** Reports (with meeting metadata) surface in Microsoft Defender portal (Defender for Office 365 Plan 1/2 or Defender XDR) and in Teams admin center under **Protection reports > User-reported security submissions**. This is a direct, built-in mitigation for the vishing/social-engineering pattern in **Attack 1** below — action: confirm security admins have access to these reports, update incident response docs, and brief users on when to use it vs. "Not a concern." A parallel Gov Cloud rollout is tracked separately ([Roadmap 569609](https://deltapulse.app/item/569609)).
2. **[Roadmap 566201 — Block all identified external bots automatically](https://deltapulse.app/item/566201)** and **[Roadmap 558107 — Identify bots joining your Teams meetings](https://deltapulse.app/item/558107)**. Both rolling out/GA in 2026. Extends meeting-join hardening (8.5.x controls) to cover automated/bot participants, not just anonymous human users — worth auditing alongside 8.5.1–8.5.4.
3. **[Roadmap 543239 — Brand Impersonation Protection for Teams Calling](https://deltapulse.app/item/543239)**. Rolling out 2026. Directly relevant to **Attack 3** (Midnight Blizzard MFA/impersonation phishing) — flags calls impersonating known brands/organizations. Worth confirming enrollment once GA.
4. **[Roadmap 560702 — Security Detection Report in Teams Admin Center](https://deltapulse.app/item/560702)** and **[Roadmap 536571 — User reported security signals in Teams admin center](https://deltapulse.app/item/536571)**. Both launched in 2026. Give admins a consolidated view of user-reported and system-detected security signals — pairs with the new MC1466296 capability above for end-to-end visibility.
5. **[Roadmap 536572 — External Domains Anomalies Report](https://deltapulse.app/item/536572)**. Launched. Directly supports the 8.2.1 domain-allowlist decision and **Attack 2** (Storm-0324/TeamsPhisher) — flags anomalous external domain activity even when a full allowlist isn't operationally feasible yet.

> Also monitor: **[Roadmap 536573 — Report a Suspicious Call in Microsoft Teams](https://deltapulse.app/item/536573)** (launched, pairs with Defender for Office 365) and **[Roadmap 523211 — Simplified controls to manage external collaboration](https://deltapulse.app/item/523211)** (launched, may ease the 8.2.1 allowlist rollout discussion with clients).

---

## Section 1 — CIS M365 Foundations v7.0.0: Teams Controls

All 18 controls are classified as Automated Assessment. The benchmark was released May 20, 2026.

**L1** — Required for all organisations. Inforcer enforces all L1 in baseline.  
**L2** — Enhanced. Recommended where licensing and operational tolerance allow.

---

### 8.1 Teams Settings

| ID | Level | Title | Portal Path | Impact |
|----|-------|-------|-------------|--------|
| 8.1.1 | L2 | External file sharing limited to approved cloud storage | TAC → Teams → Teams settings → Files | Medium |
| 8.1.2 | L1 | Users can't send emails to a channel email address | TAC → Teams → Teams settings → Email integration | Low |

**8.1.2 note:** The Teams Settings screenshot provided shows this is currently **On** — channel email injection is a low-effort content-delivery bypass for phishing into Teams channels. This is a quick win.

---

### 8.2 Users / External Access

| ID | Level | Title | Portal Path | Impact |
|----|-------|-------|-------------|--------|
| 8.2.1 | L2 | External domains restricted (allowlist) | TAC → Users → External access | High |
| 8.2.2 | L1 | Communication with unmanaged Teams users disabled | TAC → Users → External access | Low |
| 8.2.3 | L1 | External unmanaged users cannot initiate conversations | TAC → Users → External access | Low |
| 8.2.4 | L1 | Communication with trial Teams tenants disabled | TAC → Users → External access | Low |

**Current state from client screenshot:**
- 8.2.2 ✅ Off
- 8.2.4 ✅ Off
- 8.2.1 ⚠️ Still set to "Allow all external domains" — fails L2

**8.2.3 note:** CIS states this is superseded if 8.2.2 is already met, but confirm both are Off. The inbound-initiation sub-toggle is a separate setting.

**PowerShell verification:**
```powershell
Get-CsTenantFederationConfiguration | Select-Object AllowFederatedUsers, AllowTeamsConsumer, AllowTeamsConsumerInbound, ExternalAccessWithTrialTenants
```

---

### 8.5 Meetings

| ID | Level | Title | Portal Path | Impact |
|----|-------|-------|-------------|--------|
| 8.5.1 | L2 | Anonymous users can't join a meeting | TAC → Meetings → Meeting settings | High |
| 8.5.2 | L1 | Anonymous users and dial-in callers can't start a meeting | TAC → Meetings → Meeting settings | Low |
| 8.5.3 | L1 | Only people in my org can bypass the lobby | TAC → Meetings → Meeting policies → Meeting join & lobby | Medium |
| 8.5.4 | L1 | Dial-in users can't bypass the lobby | TAC → Meetings → Meeting policies → Meeting join & lobby | Low |
| 8.5.5 | L2 | Meeting chat blocked for anonymous users | TAC → Meetings → Meeting policies → Meeting engagement | Low |
| 8.5.6 | L2 | Only organizers and co-organizers can present | TAC → Meetings → Meeting policies → Content sharing | Medium |
| 8.5.7 | L1 | External participants can't give or request remote control | TAC → Meetings → Meeting policies → Content sharing | Low |
| 8.5.8 | L2 | External meeting chat is off | TAC → Meetings → Meeting policies → Meeting engagement | Medium |
| 8.5.9 | L2 | Meeting recording off by default | TAC → Meetings → Meeting policies → Recording & transcription | Medium |

**8.5.1 consideration:** Disabling anonymous join entirely is the hardest call for client-facing organisations. Before enforcing, confirm whether the client runs any public-facing webinars, partner events, or customer meetings where attendees don't have Microsoft identities. There's no partial scope — it's an org-wide meeting setting, not per-policy.

**8.5.7 priority:** This one gets overlooked but has direct ransomware relevance — see Section 2. Quick Assist + remote control is the primary initial access path in STAC4749.

---

### 8.6 Messaging

| ID | Level | Title | Portal Path | Impact |
|----|-------|-------|-------------|--------|
| 8.6.1 | L1 | Users can report security concerns in Teams | TAC → Messaging → Messaging policies | Low |

> 🚨 **Update — September 2026:** Microsoft is extending this capability directly into meetings. **[MC1466296](https://deltapulse.app/item/MC1466296)** adds a "Report a concern" option to the meeting participant tile/pane (Targeted Release late Sep 2026, GA Oct 2026, **on by default**), letting attendees flag phishing/impersonation/social engineering in real time. Reports surface in Defender portal and Teams admin center → Protection reports. No admin action required for enablement, but verify security admin access and update IR docs before GA.

---

### Cross-referenced controls (not in Section 8, but directly cover Teams)

| ID | Level | Title | Where it's configured |
|----|-------|-------|----------------------|
| 2.1.1 | L2 | Safe Links for Office apps (includes Teams) | Defender portal → Safe Links policy |
| 2.1.5 | L2 | Safe Attachments for SharePoint, OneDrive, and Teams | Defender portal → Safe Attachments → Global settings |
| 2.4.4 | L1 | Zero-hour auto purge (ZAP) for Teams | Defender portal → Anti-malware policy |
| 3.2.2 | L1 | DLP policies cover Teams messages and channels | Purview → DLP policies → Locations |

---

## Section 2 — Threat Intelligence: Active Teams Attack Patterns

These are not CIS controls. They're techniques currently being used against Teams-enabled organisations. The mitigations here are either configuration changes, Intune policy, or user education — depending on the attack.

---

### Attack 1: IT Support Vishing + Quick Assist → Ransomware

**Threat actors:** STAC4749, Black Basta affiliates, Midnight Blizzard  
**Active:** February–June 2026 (Sophos, Zscaler, Microsoft Q2 2026 Threat Report)  
**Status:** Ongoing and accelerating

The attack pattern:
1. Users receive a flood of spam email (inbox bombing) to create panic
2. An external Teams message arrives from an "IT support" account
3. The attacker convinces the user to open Quick Assist and share their screen
4. Remote access is used to deploy a backdoor (GoGRPC, DWAgent, AnyDesk, Matanbuchus Loader)
5. Lateral movement → Chaos ransomware, 3AM ransomware, or Sangria Tempest

Microsoft's own Q2 2026 data shows Teams vishing attempts running at **nearly 10× the mid-2025 baseline** by late June, with the heaviest targeting on weekdays between 14:00–20:00 UTC. At least three organisations in the STAC4749 campaign went from initial Teams contact to encrypted files in under 17 hours.

Attackers increasingly use generic display names ("IT Support", "Helpdesk", "Security Team") rather than spoofed company branding, because generic names bypass keyword-based filtering and leverage the inherent trust users place in a "Teams call from IT."

**What enables this:**
- External access set to Allow all domains (any M365 tenant can message your users)
- Quick Assist present and accessible on endpoints
- No user training on unsolicited IT support calls via Teams

**Mitigations (beyond CIS):**

1. **Disable or remove Quick Assist on managed endpoints via Intune.** Microsoft's own guidance states: "If your organization utilises another remote support tool such as Remote Help, disable or remove Quick Assist as a best practice, if it isn't used within your environment." The cleanest Intune approach is an App Control (WDAC) deny policy targeting the package family name `MicrosoftCorporationII.QuickAssist`. Alternatively, a Win32 app uninstall or a Settings Catalog feature restriction achieves similar results for less complexity.

2. **Migrate from Quick Assist to Intune Remote Help** for internal IT support. Remote Help enforces Conditional Access, RBAC, full session logging, and tenant isolation — none of which Quick Assist provides. This removes the attack vector rather than just blocking the tool.

3. **Add a client notification policy.** The Policies tab in TAC → Users → External access controls which *users* can exercise external comms. Consider restricting external access to a specific security group of people who actually need it, rather than leaving it open for all users.

4. **User awareness — one specific message:** "Microsoft IT will never contact you unsolicited via Teams. If you receive an unexpected Teams call from IT support, hang up and verify through the internal IT ticketing system before sharing your screen."

5. **New (Sep 2026): point users to the in-meeting "Report a concern" button.** [MC1466296](https://deltapulse.app/item/MC1466296) puts a native reporting control directly in the meeting participant pane, giving a lower-friction alternative to "hang up and call IT" when the vishing attempt happens inside an active Teams meeting rather than a cold Teams chat/call. This is enabled by default once it rolls out — fold it into the user awareness message above rather than treating it as a separate control.

---

### Attack 2: Storm-0324 + TeamsPhisher — Cross-Tenant File Delivery

**Threat actors:** Storm-0324 (initial access broker for Sangria Tempest / ransomware operators)  
**Active:** 2023–ongoing (most recent activity July 2025)  
**Documented by:** Microsoft Threat Intelligence

The attack: Storm-0324 used TeamsPhisher, a Python tool, to send phishing messages from attacker-controlled M365 tenants directly into target organisations' Teams chats. The messages contained links to malicious SharePoint-hosted ZIP files. The chats were flagged as "external" by Teams, but because external access was set to Allow all domains, they reached users directly.

Storm-0324 hands off access to ransomware operators — the July 2025 campaign delivered JSSLoader as an entry point for Sangria Tempest.

**What enabled this:** External access open to all domains. TeamsPhisher only works because the attacker controls a legitimate (if newly created) M365 tenant, so the message arrives looking like normal B2B Teams federation.

**Mitigation:** CIS 8.2.1 (L2) — restrict to an allowlist of trusted external domains. This closes the TeamsPhisher vector entirely. For clients where an allowlist isn't operationally feasible, the fallback is monitoring for external sender patterns and educating users on the external sender banner.

---

### Attack 3: Midnight Blizzard (APT29) — MFA Prompt Phishing via Teams

**Threat actor:** APT29 / Midnight Blizzard (Russian SVR-linked)  
**Active:** 2023–2025, device registration variant ongoing  
**Documented by:** Microsoft Threat Intelligence

The original technique: APT29 used stolen M365 tenants configured with `.onmicrosoft.com` domains, presenting as IT or security contacts. Users were social-engineered into approving MFA prompts — specifically Teams message prompts asking them to complete an authentication step.

The more current evolution (documented May 2026 by Microsoft): APT29 now delivers phishing links via Teams messages referencing upcoming meeting invitations. Clicking the link returns a token for the Device Registration Service, allowing the attacker's device to be registered to the victim tenant.

**Mitigations:**
- Phishing-resistant authentication (FIDO2/passkeys) removes the MFA fatigue angle entirely
- Conditional Access policy requiring authentication strength (AAL2+) for device registration
- Keep the Entra device registration MFA legacy toggle set to **No** where a CA policy enforces it (see MT.1061)
- Microsoft now flags `.onmicrosoft.com` sender domains more prominently in Teams — ensure users know to treat these as external

---

### Attack 4: Email Bombing + Teams Pivot (Black Basta playbook)

**Threat actors:** Black Basta affiliates  
**Active:** 2024–2026  
**Documented by:** Sophos MDR, multiple incident reports

The playbook: Flood the target user's inbox with thousands of subscription confirmation emails to create noise and overwhelm the inbox. Simultaneously, contact the user via Teams claiming to be IT support responding to the "mail server issue." From there, the attack follows the same Quick Assist → backdoor path as Attack 1.

The inbox flooding serves two purposes: it creates the pretext for the support call ("we're seeing an issue with your account"), and it buries any security alert emails that might arrive during the attack window.

**Mitigation specific to this pattern:**
- Exchange Online transport rules to rate-limit subscription/confirmation emails, or bulk-mail filtering tuned aggressively
- Defender for Office ZAP for Teams (CIS 2.4.4) helps on the Teams side
- The most effective single control remains: block unsolicited external Teams contacts and remove Quick Assist

---

### Attack 5: Shared Channel Exploitation

**What it is:** Microsoft's shared channels allow external users to be added to a Teams channel that exists within the host organisation's tenant. Unlike regular external access or guest access, shared channel members can access channel files, tabs, and apps with a persistent presence — without needing guest accounts in the target tenant.

**Why it matters for hardening:** CIS 8.5 controls do not cover shared channels. Users added to an external shared channel can access SharePoint-hosted files in that channel, see all tab content, and communicate with all channel members. There's no meeting lobby, no anonymous-join concern — because shared channel members are authenticated and persistent.

**The risk isn't theoretical:** A compromised account in a trusted partner organisation has direct, persistent access to any shared channel that organisation is a member of. The blast radius travels across the trust relationship.

**Mitigation:**
- Audit all active shared channels in TAC → Teams → Manage teams → [channel list]
- Review External collaboration overview page (TAC → External collaboration → Overview) if the tenant has access to the new experience shown in the screenshot
- Restrict shared channel creation: TAC → Teams → Teams policies → Create shared channels
- Consider requiring that shared channels are approved via a governance process before creation

---

### Attack 6: App Permissions Abuse via Teams Apps

**What it is:** Teams apps can be granted Graph API permissions that persist even if the user who installed the app leaves the organisation. Malicious or misconfigured apps installed from the Teams App Store or sideloaded can access messages, files, meetings, and user data depending on the permissions consented.

**CIS covers the tab heading but not the depth:** CIS 8.1.1 restricts cloud storage integration, but there's no CIS control covering Teams app permission governance broadly.

**What to check:**
- TAC → Teams apps → Manage apps — review apps with broad Graph permissions
- TAC → Teams apps → Permission policies — confirm users cannot self-install apps without approval
- Entra → Enterprise applications — look for Teams app registrations with `TeamsActivity.Send` or `ChannelMessage.Read.All` application permissions

**Microsoft's guidance:** Enable the app governance add-on (Defender for Cloud Apps) for automated detection of apps requesting sensitive permissions or showing anomalous behaviour. Note this requires Defender for Cloud Apps licensing.

---

## Summary: Quick wins vs. longer decisions

**Quick wins (low impact, do now):**
- 8.1.2 — Turn off channel email addresses (spotted as On in screenshot)
- 8.2.2/8.2.3/8.2.4 — Already done per screenshot
- 8.5.2 — Anonymous users can't start meetings
- 8.5.4 — Dial-in users held in lobby
- 8.5.7 — Block external remote control
- 8.6.1 — Enable security reporting in messaging policy
- 2.4.4 — ZAP for Teams
- 3.2.2 — Confirm DLP covers Teams locations

**Needs operational discussion:**
- 8.2.1 — Domain allowlist (big change, coordinate with client on external partners first)
- 8.5.1 — Anonymous meeting join (affects customer-facing orgs significantly)
- 8.5.3 — Lobby bypass (test with partner orgs before enforcing)
- Quick Assist removal — coordinate with IT support teams using it internally

**Structural / governance decisions:**
- Shared channel audit and creation policy
- Teams app permission governance
- Migrate from Quick Assist to Intune Remote Help

---

## Sources

| Source | URL |
|--------|-----|
| CIS M365 Foundations v7.0.0 | cisecurity.org (May 20, 2026) |
| Microsoft Q2 2026 Email Threat Landscape | microsoft.com/security/blog — July 23, 2026 |
| Sophos STAC4749 Chaos Ransomware Report | sophos.com/blog — July 2026 |
| Microsoft: Disrupting threats targeting Teams | microsoft.com/security/blog — Oct 2025 |
| Microsoft Learn: Quick Assist security guidance | learn.microsoft.com/windows/client-management |
| Microsoft Learn: External access in Teams | learn.microsoft.com/microsoftteams/trusted-organizations-external-meetings-chat |
| Zscaler: GoGRPC backdoor via Teams vishing | cybersecuritynews.com — July 2026 |
| Deltapulse MC1466296: Report security concerns in meetings | [deltapulse.app/item/MC1466296](https://deltapulse.app/item/MC1466296) |
| Deltapulse #566201: Block all identified external bots automatically | [deltapulse.app/item/566201](https://deltapulse.app/item/566201) |
| Deltapulse #543239: Brand Impersonation Protection for Teams Calling | [deltapulse.app/item/543239](https://deltapulse.app/item/543239) |
| Deltapulse #536572: External Domains Anomalies Report | [deltapulse.app/item/536572](https://deltapulse.app/item/536572) |
