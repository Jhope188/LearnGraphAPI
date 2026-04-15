# Microsoft 365 Copilot Settings —  Baseline Configuration Guide

**Document Version:** 1.1
**Last Updated:** April 2026
**Changelog:** v1.1 — Added EU/EFTA-specific setting: Flexible inferencing during peak load periods (effective April 17, 2026)
**Source Reference:** Microsoft Learn — [Manage Microsoft 365 Copilot scenarios in the Microsoft 365 admin center](https://learn.microsoft.com/copilot/microsoft-365/microsoft-365-copilot-page)
**Admin Role Required:** AI Administrator (to view and configure); Global Reader (view-only)
**Navigation:** Microsoft 365 admin center → Copilot → Settings → View all

---

## Overview

This guide documents every setting visible in the **Copilot Settings → View all** page of the Microsoft 365 admin center. For each setting, it describes what the control does, the security and compliance relevance, and the  recommended baseline value with rationale.

Settings are grouped into four functional categories matching the admin center tabs:

1. [User Access](#1-user-access)
2. [Data Access](#2-data-access)
3. [Copilot Actions](#3-copilot-actions)
4. [Other Settings](#4-other-settings)

> **Note on Visibility:** The admin center only shows settings for services licensed in your tenant. Not all settings below will appear in every customer environment.
>
> **⚠️ EU/EFTA Tenants Only:** The **Flexible inferencing during peak load periods** setting (Section 1.5) is exclusively visible to tenants with a sign-up country in the EU or EFTA. It does not appear in non-EU tenants. This setting became a high-priority action item as of April 17, 2026 when Microsoft changed the default to **enabled** for existing tenants. EU customers must review and make a deliberate choice.

---

## Prerequisites for Copilot Readiness

Before configuring these settings, the following foundations must be in place:

- **MFA enforced** for all users via Entra Conditional Access (phishing-resistant preferred)
- **Microsoft Purview Audit** enabled at the tenant level
- **Sensitivity labels** deployed and applied to high-value content
- **SharePoint oversharing** remediated (disable "Everyone except external users" at tenant level; review SAM Access Review reports)
- **Entra roles** reviewed — use the AI Administrator role rather than Global Administrator for Copilot management tasks

---

## 1. User Access

Settings in this tab control who can access Copilot across Microsoft products and services.

---

### 1.1 Web Search for Microsoft 365 Copilot and Microsoft 365 Copilot Chat

| Field | Value |
|---|---|
| **Admin Location** | Configured via Cloud Policy in Microsoft 365 Apps admin center (link from this setting) |
| **Applies to** | Microsoft 365 Copilot, Microsoft 365 Copilot Chat |
| **Default State** | Enabled |

**What it does:** When enabled, Copilot can augment its responses with content retrieved from public web search (Bing). This enhances the quality and currency of answers but means Copilot queries may include organizational context in web-facing search requests.

**Security/Compliance Relevance:** Enterprise data protection (EDP) applies to prompts and responses when users are signed in with a Microsoft Entra account. However, web-grounded queries do leave the Microsoft 365 trust boundary to reach Bing. Data sent as part of grounding requests is subject to Microsoft's [Bing search privacy statement](https://privacy.microsoft.com/en-us/privacystatement).

**Baseline Recommendation:** **Enable with monitoring**

Web search is a core productivity value of Copilot Chat and is expected to be on by default in most deployments. The risk is low for organizations with EDP, as the Entra-authenticated session provides enterprise protections. Organizations handling classified or highly sensitive data may choose to disable it via Cloud Policy. Audit Copilot interaction logs in Purview to confirm data patterns.

---

### 1.2 Pin Microsoft 365 Copilot Chat

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → User access → Pin Copilot Chat |
| **Applies to** | Microsoft 365 Copilot Chat, Microsoft 365 Copilot app, Microsoft 365 |
| **Default State** | Off (may be pinned by default with Copilot license) |

**What it does:** Pins Microsoft 365 Copilot Chat to the navigation bar in Teams, Outlook, and the Microsoft 365 Copilot app, providing users quick access.

**Security/Compliance Relevance:** Low direct security impact. However, surfacing Copilot Chat prominently increases usage volume, which in turn increases the importance of having Purview audit enabled and data governance controls in place before rollout.

** Baseline Recommendation:** **Enable only after Purview audit and sensitivity labels are deployed**

Pinning accelerates adoption. This is a rollout readiness gate — enable it once the organization is ready to support Copilot usage at scale. Premature enablement without data governance foundations may surface oversharing risks.

---

### 1.3 Pin Microsoft 365 Copilot Apps to the Windows Taskbar

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → User access → Pin Copilot Chat |
| **Applies to** | Microsoft 365 Copilot, Windows |
| **Default State** | Off |

**What it does:** Pins the Microsoft 365 Copilot app to the Windows taskbar for quick user access.

**Security/Compliance Relevance:** Minimal direct security impact. Increases surface area of Copilot interaction across the device experience.

** Baseline Recommendation:** **Enable at discretion after governance readiness confirmed**

This is an end-user adoption control. Apply the same readiness gate as 1.2 — confirm Purview audit, sensitivity labels, and SharePoint governance are in place before broadly enabling taskbar pinning.

---

### 1.4 Opal (Frontier)

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → User access → Opal (Frontier) |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | Off (no users have access by default) |

**What it does:** Opal is an experimental, isolated browsing agent that runs on Microsoft-managed Cloud PCs. It allows Copilot to perform multi-step web-based tasks in a sandboxed environment. Admins must grant access to specific security groups and configure an allow-list of permitted websites via the Opal Admin Portal. All browsing outside the allow-list is blocked by default.

**Security/Compliance Relevance:** High — Opal provisions Windows 365 Cloud PCs in your tenant via Intune. The initial setup creates device groups and policies that **must not be modified**. Opal represents an expanded attack surface: it is an agentic AI with the ability to browse the web and interact with external sites on behalf of users. Website allow-listing is the primary control.

** Baseline Recommendation:** **Disabled (default) — Enable only for approved pilot groups with explicit allow-list governance**

Opal is a Frontier (experimental) capability. It should not be deployed broadly until the organization has a mature AI governance program, acceptable use policies for agentic AI, and a documented allow-list review process. Do not enable for all users. If piloting, restrict to a named security group and audit all Opal sessions.

---

### 1.5 Flexible Inferencing During Peak Load Periods *(EU/EFTA Tenants Only)*

> **⚠️ EU/EFTA Exclusive Setting** — This setting is only visible in tenants whose sign-up country/region is in the EU or EFTA. It will not appear in US, UK, or other non-EU tenant admin centers. Tenants with multi-geo licenses are also excluded.

![Flexible inferencing setting visible in the Contoso Electronics EU tenant Copilot Settings page](./copilot-eu-flex-routing-setting.png)
*The "Flexible inferencing during peak load periods" setting appearing in an EU-tenanted Microsoft 365 admin center (Contoso Electronics example). This setting does not appear in non-EU tenants.*

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → Flexible inferencing during peak load periods |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | **On** for tenants created after March 25, 2026; **On** for existing tenants from April 17, 2026 (unless individually opted out) |
| **Eligibility** | EU and EFTA sign-up country tenants only; not available to multi-geo tenants |
| **Microsoft Docs** | [Flex routing (EU and EFTA)](https://learn.microsoft.com/en-us/microsoft-365/copilot/copilot-flex-routing) |

**What it does:** When enabled, Microsoft may route Copilot LLM inferencing workloads to data centers **outside the EU Data Boundary** — specifically to the United States, Canada, or Australia — during periods of peak EU GPU capacity demand. Inferencing is the actual AI processing step: executing a user's prompt to produce a Copilot response (e.g., summarizing an email, drafting a document).

This is not a data storage change. Data at rest continues to reside within the EU Data Boundary. However, during inferencing, the prompt payload — which may include email content, document excerpts, meeting transcripts, system prompts, and metadata — is processed on infrastructure outside the EU boundary. A limited amount of pseudonymized data may also be stored outside the EU for security and operational purposes.

When disabled (opt-out), LLM inferencing remains within the EU Data Boundary at all times, even during peak periods, accepting potential latency or throttling instead.

**Security/Compliance Relevance:** **Critical for EU/EFTA customers.** This setting has direct implications for:

- **GDPR compliance** — Transfer of personal data in prompts to third countries (US, Canada, Australia) requires a legal transfer mechanism (e.g., adequacy decision, Standard Contractual Clauses). Microsoft's EU Data Boundary commitment is suspended for inferred data when flex routing is active.
- **NIS2 and DORA** — Organizations subject to NIS2 (critical infrastructure operators) or DORA (financial sector) face sector-specific data localization or resilience requirements that may be incompatible with cross-boundary inferencing.
- **Internal data governance policies** — Many European organizations have data governance policies requiring processing to stay within specific geographic boundaries regardless of legal adequacy.
- **Sector-specific regulation** — Healthcare (GDPR + national health data laws), financial services, and public sector organizations often face additional restrictions.

Microsoft's position: Data remains **encrypted in transit and at rest**, and full data residency commitments continue to apply to stored data. The EU Data Boundary compliance framework is maintained except for the transient inferencing step.

**Key nuance for :** This is a default-enabled opt-**out** model as of April 17, 2026 — a reversal from the historically conservative approach of requiring EU customers to explicitly opt in to cross-boundary processing. This means EU customer tenants that have not actively reviewed this setting may already be routing inferencing outside the EU without realizing it.

** Baseline Recommendation:** **Disabled ("Do not allow flex routing") for regulated industries and all customers with explicit EU data residency commitments**

The default-on posture is a meaningful compliance risk for European customers. The  baseline for EU/EFTA tenants is to:

1. **Audit all EU customer tenants immediately** — Check whether this setting is currently enabled (On) or disabled (Off)
2. **Default to disabled** for any customer operating in financial services, healthcare, public sector, or any organization with documented EU data residency requirements
3. **Engage DPO/Legal** — The decision to allow or disallow flex routing should be a documented legal/privacy decision, not a technical one made in isolation
4. **Document the decision** — Whichever state is chosen, record the business and legal rationale as part of the organization's AI governance documentation (supports GDPR accountability principle and EU AI Act obligations)
5. **Monitor for performance impact** — If flex routing is disabled and users experience significant Copilot degradation, that is the expected Microsoft-documented trade-off; performance concerns do not override compliance requirements

For customers where performance is critical and legal has cleared cross-boundary processing via applicable transfer mechanisms (e.g., Microsoft's SCCs / EU-US Data Privacy Framework adequacy decision), enabling flex routing with documented approval is acceptable.

---

### 1.6 Microsoft Copilot for Security

| Field | Value |
|---|---|
| **Admin Location** | Shortcut to [https://securitycopilot.microsoft.com](https://securitycopilot.microsoft.com) |
| **Applies to** | Microsoft Copilot for Security |
| **Default State** | N/A (shortcut — configured in Security Copilot portal) |

**What it does:** This is a direct shortcut to the Microsoft Security Copilot portal. Configuration (capacity provisioning, role assignment, audit log enablement) is performed inside the Security Copilot portal by a Security Administrator with the Owner role.

**Security/Compliance Relevance:** Security Copilot is a standalone product licensed via Security Compute Units (SCUs). Access is role-controlled. Organizations should enable Purview audit logging within Security Copilot (Owner Settings → Logging audit data in Microsoft Purview) to capture all prompts, responses, and admin actions.

** Baseline Recommendation:** **Configure audit logging in Purview from day one; use RBAC to limit who has the Copilot Owner role**

At minimum: enable audit logging, assign the Security Copilot Analyst and Owner roles to named individuals (not broad groups), and review the Security Copilot Cost Estimator before committing SCU capacity.

---

### 1.7 Microsoft 365 Copilot Self-Service Purchases

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → User access → Microsoft 365 Copilot self-service purchases |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | Allow |

**What it does:** Controls whether end users can purchase or trial Microsoft 365 Copilot licenses without admin approval. Three options: **Allow**, **Allow trials only**, or **Do not allow**.

**Security/Compliance Relevance:** Medium — self-service purchases can result in unlicensed or shadow AI usage that bypasses organizational governance controls. Users who self-provision Copilot may not have completed required AI awareness training and may begin using Copilot against ungoverned data.

** Baseline Recommendation:** **Set to "Do not allow"**

Self-service license procurement bypasses procurement governance and may result in users accessing Copilot before data governance (Purview, SharePoint oversharing remediation) is in place. Organizations should manage Copilot rollout deliberately, assigning licenses only after readiness prerequisites are confirmed. If piloting demand sensing is needed, use "Allow trials only" temporarily with a defined review process.

---

### 1.8 Microsoft 365 Copilot in Admin Centers

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → User access → Microsoft 365 Copilot in admin centers |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | On (for all admins with a Copilot license) |

**What it does:** Allows admin users to use Microsoft 365 Copilot within the M365 admin center, Exchange admin center, SharePoint admin center, and Teams admin center. The feature respects RBAC — Copilot only surfaces information and controls the admin user already has permission to see. Copilot does not make configuration changes autonomously.

**Security/Compliance Relevance:** Low-to-medium. Admins using Copilot in admin centers generate audit log entries. The feature does not expand any permissions beyond what the admin already holds. To exclude specific admins, add them to a security group named **CopilotForM365AdminExclude**.

** Baseline Recommendation:** **Enable; restrict via CopilotForM365AdminExclude group where needed**

This is a legitimate productivity feature for admins. The RBAC enforcement is a meaningful security control. If your organization has privileged access workstations (PAWs) or just-in-time admin policies, verify those controls are enforced before this feature is broadly used.

---

### 1.9 Copilot Frontier

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → User access → Copilot Frontier |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | No access (no users have access by default) |

**What it does:** Grants access to experimental and preview Copilot features across web apps (M365 Copilot app, Word, PowerPoint, Excel web), desktop/mobile apps (via the M365 Insider Beta Channel), and experimental Microsoft-built agents. Frontier features are pre-release and subject to change without notice.

**Security/Compliance Relevance:** High. Frontier features are not production-grade and have not completed full security/compliance review. They may process organizational data using capabilities not yet covered by standard data protection commitments.

** Baseline Recommendation:** **Disabled for all users (default); pilot only via named security group if required**

Frontier access should be limited to a small, defined group (e.g., IT innovation team, Copilot champions) and never enabled tenant-wide. Before enabling, confirm that Frontier features are covered by your Microsoft Enterprise Agreement data processing terms.

---

### 1.10 Copilot in Edge

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → User access → Copilot in Edge (shortcut to Edge configuration policy) |
| **Applies to** | Microsoft Edge |
| **Default State** | Available by default in Edge for signed-in users |

**What it does:** This is a shortcut to create a Microsoft Edge configuration policy via the M365 admin center (Settings → Microsoft Edge → Configuration policies). Admins can use Edge management policies to control Copilot features in Edge, including whether users can access Copilot in the Edge sidebar.

**Security/Compliance Relevance:** Medium. Copilot in Edge can surface organizational data and browser content in Copilot responses. For managed devices, configuring Edge policies via Intune or the Edge Management Service ensures consistent Copilot behavior across the fleet.

** Baseline Recommendation:** **Configure Edge management policy to align with organizational AI use policy; ensure Entra account sign-in is enforced so enterprise data protection applies**

At minimum, deploy an Edge configuration policy that requires users to be signed in with their work account (to get EDP), and review whether sidebar Copilot access is appropriate for your organization's risk profile.

---

### 1.11 Copilot in Bing, Edge, and Windows

| Field | Value |
|---|---|
| **Admin Location** | Informational — not configurable in M365 admin center |
| **Applies to** | Bing, Microsoft Edge, Windows |
| **Default State** | Automatically available |

**What it does:** Describes Microsoft 365 Copilot Chat availability in Bing, Edge, and Windows. When users sign in with their Microsoft Entra work account, they receive enterprise data protection (EDP) for all Copilot Chat prompts and responses. Consumer Copilot (personal accounts) does not have EDP.

**Security/Compliance Relevance:** High awareness item. EDP is only active when the user is signed in with their Entra account. Organizations must enforce that work browsers use work accounts (via Entra device registration or Conditional Access browser policies) to ensure EDP coverage.

** Baseline Recommendation:** **Enforce Entra account sign-in in Edge via Conditional Access and Edge policies; educate users on the difference between work and personal Copilot sessions**

Use Conditional Access to require compliant devices for M365 access. Deploy an Edge policy (EnforceBrowserSignin or similar) to require work account sign-in. This ensures Copilot Chat in the browser always operates under EDP.

---

### 1.12 Copilot Pay-as-You-Go Billing

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → User access → Copilot pay-as-you-go billing |
| **Applies to** | Microsoft 365 Copilot Chat |
| **Default State** | Not configured by default |

**What it does:** Allows organizations to configure pay-as-you-go billing for Copilot Chat, enabling access for users without a full Microsoft 365 Copilot license on a consumption model.

**Security/Compliance Relevance:** Medium. Pay-as-you-go access grants Copilot Chat capabilities to users who have not gone through formal Copilot readiness or training. Billing policies must be defined to control cost exposure.

** Baseline Recommendation:** **Disable unless explicitly required; if used, apply a billing policy scoped to specific user groups**

Organizations without a broad Copilot license deployment should avoid open-ended pay-as-you-go unless they have the governance structures to support it. Unrestricted pay-as-you-go is both a financial risk and a potential governance gap.

---

## 2. Data Access

Settings in this tab control how Copilot accesses and handles organizational information.

---

### 2.1 Web Search for Microsoft 365 Copilot and Microsoft 365 Copilot Chat

*(Covered in section 1.1 — this setting appears in the Data Access view as well)*

---

### 2.2 People Skills in Microsoft 365 Copilot

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → Data access → People Skills (shortcut to Settings → Viva → Data management → People Skills) |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | Off by default; opt-in |

**What it does:** An AI-powered service that builds skill profiles for employees based on their work activity in Microsoft 365 (documents authored, meetings attended, etc.). These inferred skills are used to personalize Copilot experiences and can surface employees as subject matter experts.

**Security/Compliance Relevance:** High — People Skills generates inferred personal data about employees (skill profiles). Organizations must assess whether this processing is permissible under applicable employment laws (GDPR, local labor regulations). Employees may have rights to access or correct their inferred skill data.

** Baseline Recommendation:** **Disabled until a DPIA (Data Protection Impact Assessment) or equivalent review is completed**

This is one of the higher-sensitivity data features in the Copilot ecosystem. Do not enable without HR, Legal, and Privacy sign-off. If enabled, configure retention policies for skills data and communicate clearly to employees about how inferred skills are generated and used.

---

### 2.3 Data Security and Compliance

| Field | Value |
|---|---|
| **Admin Location** | Shortcut to Microsoft Purview portal |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | N/A — shortcut to Purview |

**What it does:** This entry is a navigation shortcut to the Microsoft Purview portal, specifically to DSPM for AI (Data Security Posture Management for AI). It surfaces the Purview capabilities that directly govern Copilot data handling: DSPM for AI, Insider Risk Management, Sensitivity Labels, Retention Policies, Communication Compliance, Audit, and eDiscovery.

**Security/Compliance Relevance:** Critical. This is the entry point for the entire Copilot data governance layer.

** Baseline Recommendation:** **Complete all Purview Copilot readiness steps before enabling Copilot broadly**

The minimum Purview baseline for Copilot readiness includes:

1. Enable Microsoft Purview Unified Audit Log
2. Activate DSPM for AI and complete the onboarding assessment
3. Apply sensitivity labels to at least high-value/confidential content
4. Configure a Communication Compliance policy to detect risky Copilot interactions (E5 license)
5. Configure Copilot interaction retention policies in Data Lifecycle Management
6. Run the DSPM for AI "one-click policies" to capture prompts/responses for review

---

### 2.4 Copilot in Power Platform and Dynamics 365

| Field | Value |
|---|---|
| **Admin Location** | Shortcut to Power Platform admin center |
| **Applies to** | Microsoft 365 Copilot, Power Platform, Dynamics 365 |
| **Default State** | N/A — shortcut |

**What it does:** Navigates to the Power Platform admin center where admins control Copilot, generative AI, and agent settings for Power Apps, Power Automate, Power Pages, Copilot Studio, and Dynamics 365.

**Security/Compliance Relevance:** Medium-to-high. Power Platform Copilot features can access organizational data through Dataverse, SharePoint connectors, and other integrations. Copilot Studio agents can be built by end users if maker permissions are not restricted.

** Baseline Recommendation:** **Review and restrict Copilot features in Power Platform through the Power Platform admin center; apply DLP policies to prevent sensitive connector use in Copilot-enabled flows**

Key actions: restrict who can create Copilot Studio agents (limit to licensed makers), apply Data Loss Prevention (DLP) policies to block sensitive connectors from being used in AI-powered automations, and review the Copilot generative AI settings per-environment.

---

### 2.5 AI Providers Operating as Microsoft Subprocessors

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → Data access → AI providers for other large language models |
| **Applies to** | Microsoft 365 Copilot Chat, Copilot Studio |
| **Default State** | Available to configure; off by default for non-Microsoft LLMs |

**What it does:** Allows administrators to connect third-party large language models (e.g., Claude by Anthropic, GPT variants) for use within Copilot Chat and Copilot Studio. These providers operate as Microsoft subprocessors under the Microsoft Online Services Terms.

**Security/Compliance Relevance:** High. Enabling third-party LLMs means organizational data (prompts, context) may be sent to non-Microsoft models. The subprocessor relationship means Microsoft contractually governs data handling with these providers, but organizations should review the specific data flow, residency, and retention terms for each connected LLM.

** Baseline Recommendation:** **Disabled by default; enable only upon legal/privacy review and specific business justification**

Each third-party LLM connection should be reviewed against your data classification policies. Do not allow access to third-party LLMs for workflows that process regulated data (PII, financial, health information) without a documented data processing assessment. Review the [Microsoft AI subprocessors list](https://aka.ms/AISubprocessors) for current approved providers.

---

### 2.6 Agents

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → Data access → Agents |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | Enabled; users can access agents by default |

**What it does:** Controls access to Copilot agents — AI assistants that focus on specific tasks and can be built internally or installed from the Microsoft 365 app store. Admins can restrict who can access agents and what types of agents (Microsoft-built, partner-built, custom) users can install.

**Security/Compliance Relevance:** High. Agents can access organizational data through Microsoft Graph, SharePoint, Exchange, and third-party connectors. Poorly governed agent deployment is a significant data exfiltration and oversharing risk. Agents built in Copilot Studio by end users (if maker permissions are unrestricted) can expose sensitive data.

** Baseline Recommendation:** **Restrict agent access to IT-vetted agents only; disable user self-installation of third-party agents**

Configure the Agents page to:
- Allow only Microsoft-built agents by default
- Require admin approval for partner/ISV agents (via Integrated Apps in admin center)
- Restrict Copilot Studio maker permissions to licensed, trained staff
- Monitor agent usage via Purview DSPM for AI and the Copilot usage reports

---

## 3. Copilot Actions

Settings in this tab control what Copilot can generate or do in response to user prompts.

---

### 3.1 Copilot Image Generation

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → Copilot actions → Copilot image generation |
| **Applies to** | Designer integrations across Microsoft 365 Copilot |
| **Default State** | Enabled |

**What it does:** When enabled, users can prompt Copilot to generate, design, and edit images using AI (powered by Microsoft Designer / DALL-E). Images can be added to M365 apps and Designer. When disabled, Copilot returns stock or brand images instead.

**Security/Compliance Relevance:** Medium. AI image generation can produce content that violates acceptable use policies, creates legal risk (copyright, deepfakes, inappropriate content), or generates material inconsistent with brand guidelines. Microsoft applies content safety filters, but organizational policies must address acceptable use of AI-generated imagery.

** Baseline Recommendation:** **Enable with acceptable use policy in place; consider disabling for regulated industries (financial services, healthcare, legal)**

If enabled, publish a clear acceptable use policy for AI-generated images. For organizations in highly regulated industries, or those where image content could be used in regulated communications, consider disabling this feature until content governance controls are established.

---

### 3.2 Copilot Video Generation

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → Copilot actions → Copilot video generation |
| **Applies to** | Video content generated by AI across Microsoft 365 |
| **Default State** | Enabled (where licensed) |

**What it does:** Controls whether users can create AI-generated videos using Microsoft Copilot. This capability integrates with Microsoft tools (such as Clipchamp) to allow AI-assisted video creation from prompts or existing content.

**Security/Compliance Relevance:** Medium-to-high. AI video generation carries risks similar to image generation but amplified: deepfake potential, brand misuse, and generation of synthetic media featuring people. Additionally, video creation workflows may involve uploading proprietary media content to AI processing pipelines.

** Baseline Recommendation:** **Disable until acceptable use policies, legal review, and content governance controls are in place**

AI video generation is a newer, higher-risk capability than image generation. The potential for synthetic media misuse (deepfakes of executives, fabricated corporate announcements) warrants a conservative default. Enable only after documented acceptable use policies and legal review.

---

### 3.3 Copilot in Teams Meetings

| Field | Value |
|---|---|
| **Admin Location** | Shortcut to Microsoft Teams admin center (Teams meeting policies) |
| **Applies to** | Copilot in Microsoft Teams |
| **Default State** | Varies by Teams meeting policy |

**What it does:** Controls how Copilot interacts with Teams meetings — specifically whether Copilot can be used only during a meeting (no transcript required) or during and after a meeting (transcript required for post-meeting access). Configured per Teams meeting policy using the `-Copilot` parameter:
- `Enabled` — during meeting only
- `EnabledWithTranscriptDefaultOn` — during and after; transcript on by default
- `Disabled` — Copilot off

**Security/Compliance Relevance:** High. Meeting transcripts are stored in Exchange Online and subject to eDiscovery, retention policies, and compliance holds. The choice to enable "during and after" implicitly enables transcript creation, which creates discoverable records of meeting content. Transcripts containing sensitive discussions are subject to your organization's information protection policies.

** Baseline Recommendation:** **Set default to "Enabled" (during meeting only) for general population; "EnabledWithTranscriptDefaultOn" for roles where meeting summaries add significant value**

Avoid enabling transcript-dependent Copilot features for all users without first confirming that:
1. Retention policies for Teams transcripts are configured in Purview
2. eDiscovery holds will capture transcripts
3. Sensitivity labels can be applied to meeting recordings/transcripts
4. Employees have been informed that meeting content is captured

---

## 4. Other Settings

---

### 4.1 Copilot Custom Dictionary

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → Other settings → Copilot custom dictionary |
| **Applies to** | Copilot in Microsoft Teams (meeting transcription) |
| **Default State** | No dictionary uploaded |

**What it does:** Allows admins to upload custom vocabulary files (proper nouns, technical jargon, product names, abbreviations) to improve Copilot's accuracy when transcribing Teams meetings. The dictionary helps Copilot correctly recognize organization-specific terminology.

**Security/Compliance Relevance:** Low. The dictionary file contains organizational vocabulary, not sensitive content. However, it should be treated as internal data and the upload process should follow change management practices.

** Baseline Recommendation:** **Configure for organizations with extensive technical or industry-specific vocabulary**

This is a quality-of-life setting. Upload a dictionary after piloting Teams meeting transcription to identify recurring mis-transcriptions. Review and update periodically as organizational vocabulary evolves.

---

### 4.2 Copilot Diagnostic Logs

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → Other settings → Copilot diagnostic logs |
| **Applies to** | Microsoft 365 Copilot |
| **Default State** | Available to admins |

**What it does:** Allows administrators to submit Copilot diagnostic feedback logs to Microsoft on behalf of users who are experiencing issues and cannot submit logs themselves. Log data includes user prompts, generated responses, relevant content samples, and log files. When used, it temporarily overrides the user-level feedback policy.

**Security/Compliance Relevance:** Medium-to-high. Log submission sends actual user prompt data and AI responses (which may contain confidential organizational content) to Microsoft for diagnostic purposes. Admins must be aware that this action processes potentially sensitive data and should be used judiciously.

** Baseline Recommendation:** **Use only for active support incidents; document each use; communicate to affected user before submitting**

Establish an internal process requiring: (1) user awareness/consent before log submission, (2) Helpdesk ticket reference for each submission, and (3) a check that the prompts/responses in the logs do not contain classified or heavily regulated information before submitting.

---

### 4.3 Copilot AI Disclaimer

| Field | Value |
|---|---|
| **Admin Location** | Copilot → Settings → View all → Copilot AI disclaimer |
| **Applies to** | AI disclaimer integrated across Microsoft 365 (Word, Excel, PowerPoint, Outlook, OneNote, M365 Copilot app) |
| **Default State** | Off — must be explicitly enabled |

**What it does:** When enabled, displays the message "AI-generated content may be inaccurate" within supported M365 apps wherever Copilot has generated content. Admins can choose between standard or bold font for the disclaimer and optionally add a custom URL linking to their organization's internal AI policy.

Not displayed in: SharePoint, OneDrive, Whiteboard, or Forms.

**Security/Compliance Relevance:** Medium — primarily a governance and regulatory compliance control. Many industries and jurisdictions increasingly require disclosure of AI-generated content. Enabling this setting creates a user-facing acknowledgment that supports AI accountability frameworks (ISO 42001, EU AI Act obligations, etc.).

** Baseline Recommendation:** **Enable with bold font and a custom link to the organization's AI acceptable use policy**

This is a low-friction, high-value governance control. It reduces liability risk, manages user expectations about Copilot accuracy, and creates the foundation for AI literacy across the organization. Configuring a custom URL requires an internal AI policy page to exist — create one before enabling.

---

## 5. Summary Baseline Table

| # | Setting | Category |  Baseline | Priority | EU/EFTA Only |
|---|---|---|---|---|---|
| 1 | Web search for Microsoft 365 Copilot | User Access / Data Access | Enable with monitoring | Medium | No |
| 2 | Pin Microsoft 365 Copilot Chat | User Access | Enable post-governance readiness | Low | No |
| 3 | Pin Copilot apps to Windows taskbar | User Access | Enable post-governance readiness | Low | No |
| 4 | Opal (Frontier) | User Access | **Disabled** | High | No |
| 5 | **Flexible inferencing during peak load periods** | User Access | **Disabled** (Do not allow) for regulated orgs | **Critical** | **Yes** |
| 6 | Microsoft Copilot for Security | User Access | Configure audit in Security Copilot portal | High | No |
| 7 | M365 Copilot self-service purchases | User Access | **Do not allow** | High | No |
| 8 | M365 Copilot in admin centers | User Access | Enable; exclude via security group if needed | Medium | No |
| 9 | Copilot Frontier | User Access | **Disabled** | High | No |
| 10 | Copilot in Edge | User Access | Configure Edge policy; enforce Entra sign-in | Medium | No |
| 11 | Copilot in Bing, Edge, and Windows | User Access | Enforce Entra sign-in for EDP | High | No |
| 12 | Copilot pay-as-you-go billing | User Access | **Disable** unless scoped billing policy exists | High | No |
| 13 | People Skills | Data Access | **Disabled** until DPIA/legal review | High | No |
| 14 | Data security and compliance | Data Access | Complete all Purview readiness steps | Critical | No |
| 15 | Copilot in Power Platform and Dynamics 365 | Data Access | Restrict makers; apply DLP policies | High | No |
| 16 | AI providers (subprocessors) | Data Access | **Disabled** until legal/privacy review | High | No |
| 17 | Agents | Data Access | Restrict to vetted agents only | High | No |
| 18 | Copilot image generation | Copilot Actions | Enable with acceptable use policy | Medium | No |
| 19 | Copilot video generation | Copilot Actions | **Disabled** until legal/governance review | High | No |
| 20 | Copilot in Teams meetings | Copilot Actions | Enabled (during only) for general users | Medium | No |
| 21 | Copilot custom dictionary | Other Settings | Configure for terminology-heavy orgs | Low | No |
| 22 | Copilot diagnostic logs | Other Settings | Use only for active support incidents | Medium | No |
| 23 | Copilot AI disclaimer | Other Settings | **Enable (Bold) + custom policy URL** | High | No |

---

## 6. Copilot Readiness Prerequisites Checklist

Before enabling Copilot broadly, confirm each of the following:

- [ ] Entra MFA enforced for all users (phishing-resistant MFA preferred for privileged accounts)
- [ ] Microsoft Purview Unified Audit Log enabled
- [ ] DSPM for AI onboarding completed in Purview portal
- [ ] Sensitivity labels deployed and applied to high-value content
- [ ] "Everyone except external users" sharing disabled at SharePoint tenant level
- [ ] SharePoint Advanced Management oversharing assessment completed
- [ ] Copilot interaction retention policies configured in Data Lifecycle Management
- [ ] Copilot AI disclaimer enabled with link to internal AI use policy
- [ ] Self-service purchase setting set to "Do not allow"
- [ ] Agent governance policy established (vetted agents list maintained)
- [ ] Teams meeting policy reviewed and Copilot transcript behavior configured
- [ ] AI acceptable use policy published and communicated to users
- [ ] Training completed for Copilot users (Microsoft Copilot adoption hub or equivalent)
- [ ] **[EU/EFTA only]** Flexible inferencing setting audited and documented — default changed to **On** April 17, 2026; disable for regulated industries unless DPO/legal has approved cross-boundary processing with documented transfer mechanism

---

## 7. References

- [Manage Microsoft 365 Copilot scenarios in the Microsoft 365 admin center](https://learn.microsoft.com/copilot/microsoft-365/microsoft-365-copilot-page)
- [Configure a secure and governed foundation for Microsoft 365 Copilot](https://learn.microsoft.com/copilot/microsoft-365/configure-secure-governed-data-foundation-microsoft-365-copilot)
- [Microsoft Purview data security and compliance protections for generative AI apps](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)
- [Data, privacy, and security for Microsoft 365 Copilot](https://learn.microsoft.com/copilot/microsoft-365/microsoft-365-copilot-privacy)
- [Turn on AI disclaimers in Microsoft 365 Copilot](https://learn.microsoft.com/copilot/microsoft-365/microsoft-365-ai-disclaimers)
- [Get started with Opal in Microsoft 365 Copilot](https://learn.microsoft.com/copilot/microsoft-365/opal-settings-manage)
- [Manage agents in the Microsoft 365 admin center](https://learn.microsoft.com/en-us/microsoft-365/admin/manage/manage-copilot-agents-integrated-apps)
- [Manage Microsoft 365 Copilot in Teams meetings and events](https://learn.microsoft.com/en-us/microsoftteams/copilot-teams-transcription)
- [Flex routing (EU and EFTA) — Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/copilot/copilot-flex-routing)
- [Flex Routing Dilemma for European Copilot Customers — Office 365 IT Pros](https://office365itpros.com/2026/04/07/flex-routing-copilot-europe/)
- [EU Data Boundary countries and datacenter locations](https://learn.microsoft.com/en-us/privacy/eudb/eu-data-boundary-learn#eu-data-boundary-countries-and-datacenter-locations)
- [Ongoing partial data transfers — EU Data Boundary](https://learn.microsoft.com/en-us/privacy/eudb/eu-data-boundary-ongoing-partial-transfers)
