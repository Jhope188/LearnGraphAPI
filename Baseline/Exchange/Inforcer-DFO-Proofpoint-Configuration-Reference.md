# Defender for Office Policy Deployment
## Proofpoint-Fronted M365 Tenants

**Configuration Deltas for Exchange Baseline Deployment**

---

## Executive Summary

This reference covers the Defender for Office (DFO) baseline when the customer tenant routes inbound mail through a third-party Secure Email Gateway (SEG) — specifically Proofpoint Essentials or Proofpoint Enterprise (TAP / URL Defense). The dominant MSP pattern is:

**`Internet → Proofpoint → M365 (via inbound connector) → Mailbox`**

Outbound mail typically also traverses Proofpoint via an M365 outbound connector.

> **Core Guidance**
> - All eight policies in the DFO baseline should be deployed. None become redundant when Proofpoint is in front of M365.
> - Two policies require configuration changes: **Safe Links** (rewrite scope) and **Inbound Spam** (Enhanced Filtering for Connectors).
> - The single most important prerequisite is **Enhanced Filtering for Connectors (skip listing)** on the Proofpoint inbound connector — without it, SPF, DMARC, and EOP's ML signals are broken.

---

## Architectural Context

### Why the policies still matter with a SEG in front

A common misconception is that a third-party SEG replaces Defender for Office. It does not. The Inforcer baseline remains applicable because Defender protects mail surfaces and scenarios Proofpoint does not cover:

- **Internal-to-internal mail** — never traverses Proofpoint; only Defender inspects it.
- **Collaboration workloads** — SharePoint Online, OneDrive for Business, and Microsoft Teams file sharing. Proofpoint TAP is email-only.
- **Outbound mail from M365 mailboxes** — evaluated by EOP before Proofpoint relay; catches compromised-account abuse.
- **Mailbox-intelligence impersonation detection** — depends on the recipient's sent/received graph inside M365 and cannot be replicated at the SEG.
- **Teams and Office app URL protection** — Safe Links time-of-click; Proofpoint URL Defense does not rewrite Teams or Office app links.
- **M365-side quarantine governance** — release-request workflows, admin review policies.

### What breaks when Proofpoint is in front

When mail is relayed through Proofpoint, EOP observes Proofpoint as the sending infrastructure. Without explicit configuration, this causes:

- SPF fails at EOP because the sending IP is Proofpoint, not the original sender.
- IP reputation and connection-level signals for EOP become meaningless.
- DMARC evaluation can fail-closed on SPF, even when DKIM aligns.
- Anti-spam ML signals degrade because envelope and header data is rewritten.

The fix is **Enhanced Filtering for Connectors (EFC)**, covered in the next section. This is the first thing to verify on any Proofpoint-fronted customer before tuning any DFO policy.

---

## Prerequisite: Enhanced Filtering for Connectors

Enhanced Filtering for Connectors (also called "skip listing") allows EOP to see the original sending IP by walking the `Received` header chain back past the SEG. It is configured on the inbound connector associated with Proofpoint.

### Configuration path

- Microsoft Defender portal → Email & collaboration → Policies & rules → Threat policies → **Enhanced filtering**.
- Select the inbound connector that receives mail from Proofpoint.
- Choose *"Automatically detect and skip the last IP address"* or explicitly list the Proofpoint egress IPs.
- Apply to all users (or scope with recipient conditions for phased rollout).

### Verification

- Send a test message from an external sender through Proofpoint.
- Inspect the message headers in the recipient mailbox.
- Confirm `X-Forefront-Antispam-Report` shows the real sender IP in `CIP` (Connecting IP) rather than a Proofpoint IP.
- Confirm SPF result reflects the original sender domain, not the Proofpoint relay.

> **⚠️ Assessment Finding Pattern**
> If EFC is not configured on a Proofpoint-fronted tenant, flag as a **high-severity finding** in the assessment. Downstream impact: spam/anti-phishing accuracy degradation, broken DMARC, and false confidence in EOP metrics.
>
> This finding is worth calling out separately in the client-facing report — it is almost always present and almost always unknown to the customer.

---

## Policy-by-Policy Decisions

The following table maps each policy in the IAC DFO baseline to a deploy/configure decision for Proofpoint-fronted tenants.

| Defender for Office Policy | Deploy? | Configuration Guidance for Proofpoint-Fronted Tenants |
|---|---|---|
| **Anti-Phishing Policy** | ✅ Yes | Deploy as-is. Impersonation protection, mailbox intelligence, and spoof intelligence evaluate against the recipient's M365 mailbox context — Proofpoint cannot replicate this. Arguably more important with a SEG in front since connection-level signals to EOP are degraded. |
| **Anti-Malware Policy** | ✅ Yes | Deploy as-is. Defender runs on all mail that reaches the mailbox including internal-to-internal traffic that never traverses Proofpoint. Common Attachment Types Filter (CIS 2.1.2, L1) remains essential regardless of SEG. |
| **Safe Attachments Policy** | ⚠️ Yes — tune | Deploy, accept the overlap with Proofpoint TAP. Safe Attachments covers internal mail (no Proofpoint traversal). Pair with Safe Attachments for SharePoint/OneDrive/Teams (CIS 2.1.5) which Proofpoint does not cover. Keep action at **Block** unless the MSP has explicit latency concerns. |
| **Safe Links Policy** | 🔧 Yes — reconfigure | Deploy but **disable URL rewriting for external email** to avoid double-wrapping with Proofpoint URL Defense. Keep rewriting enabled for Teams, Office 365 apps, and internal mail — Proofpoint does not touch these surfaces. Time-of-click protection stays on. |
| **Inbound Spam Filter Policy** | ⚠️ Yes — with EFC | Deploy, but **Enhanced Filtering for Connectors** (skip listing) must be configured on the Proofpoint inbound connector. Without EFC, EOP sees Proofpoint's IP as the source — SPF, DMARC, and IP reputation evaluation are broken. Tune bulk/spam thresholds conservatively; Defender is the second layer. |
| **Outbound Spam Filter Policy** | ✅ Yes | Deploy as-is. Protects against compromised-account abuse, auto-forwarding, and outbound volume limits (CIS 2.1.15, L1). These are M365-native concerns Proofpoint cannot enforce on mail originating from M365 mailboxes. |
| **Alert External Emails (Transport Rule)** | ✅ Yes | Deploy as-is. Mail flow rule adds an external-sender banner; applies regardless of upstream routing and runs within Exchange Online after inbound connector processing. |
| **LimitedAccess-RequestByUser (Quarantine Policy)** | ✅ Yes | Deploy as-is. Governs end-user actions on items in the Defender quarantine (release requests, preview). Purely M365-side governance — Proofpoint operates its own separate quarantine. |

---

## Safe Links — The URL Rewrite Conflict

Safe Links and Proofpoint URL Defense both rewrite URLs in email. Running both in their default configurations produces double-wrapped URLs that can:

- Break click-tracking analytics in marketing platforms.
- Produce visually ugly or suspicious-looking URLs that reduce user trust.
- In rare cases, cause sandbox loop conditions where Proofpoint detonates a Safe Links URL that Proofpoint itself rewrote.

### Recommended Safe Links configuration

- **Email** — Disable URL rewriting (set "Do not rewrite URLs" or scope the policy so external email is excluded). Proofpoint URL Defense handles external mail.
- **Teams** — Enable Safe Links for Teams. Proofpoint does not inspect Teams chat links.
- **Office 365 apps** — Enable Safe Links for Office apps (Word, Excel, PowerPoint, OneNote). Proofpoint does not cover in-document links.
- **Click protection settings** — Keep "Track user clicks" and "Apply real-time URL scanning for suspicious links" enabled — these do not require rewriting to function.
- **Do not let users click through to the original URL** — Keep enabled for Office app scope.

> **✅ CIS Alignment**
> CIS M365 Foundations v6.0.0 control **2.1.1 (L2)** requires Safe Links for Office applications to be enabled. The Proofpoint-aware configuration still meets this control — Safe Links is enabled, only the email rewrite scope is adjusted.

---

## Anti-Spam Tuning for Proofpoint-Fronted Environments

With EFC configured correctly, EOP regains the ability to evaluate spam based on the original sender. However, the posture should be tuned because Proofpoint has already filtered the bulk of junk mail.

### Recommended tuning

- **Bulk complaint threshold (BCL):** Set to **6** (default is 7). Proofpoint usually filters the worst bulk mail; BCL 6 catches borderline commercial mail that slipped through.
- **Spam action:** Quarantine (not Move to Junk). Provides admin visibility for missed-spam post-mortems.
- **High-confidence spam action:** Quarantine with admin notification.
- **Phishing action:** Quarantine.
- **High-confidence phishing action:** Quarantine, 30-day retention.
- **Zero-hour auto purge (ZAP):** Enabled for spam, phishing, and malware.
- **Allowed/blocked sender and domain lists:** Empty. Per CIS 2.1.14 (L1), no allowed domains. Use Tenant Allow/Block List for exceptions with expiration.
- **Do not allowlist Proofpoint IPs in Connection Filter.** Use EFC instead.

### Outbound spam

Outbound spam policy applies to mail leaving M365 mailboxes before it reaches any relay. Deploy the Inforcer baseline as-is:

- External recipient limit: **500/hour** (CIS 2.1.15 L1 requires outbound limits).
- Internal recipient limit: **1000/hour**.
- Daily limit: **1000**.
- Action when limit reached: Restrict user from sending mail until next day + alert.
- Automatic forwarding to external recipients: **Off** (CIS requires block).

---

## CIS Benchmark Alignment Reference

The table below maps each policy in the Inforcer baseline to the relevant CIS Microsoft 365 Foundations v6.0.0 controls, with notes on how the Proofpoint-fronted configuration still satisfies them.

| Control ID | Level | Policy | Notes for Proofpoint-Fronted Environments |
|---|---|---|---|
| CIS 2.1.1 | L2 | Safe Links | Control is still met — Safe Links is enabled. Rewrite scope adjusted to avoid collision with Proofpoint URL Defense; Teams and Office app coverage is the primary value. |
| CIS 2.1.2 | **L1** | Anti-Malware | Common Attachment Types Filter — required regardless of SEG. Internal mail never touches Proofpoint. |
| CIS 2.1.3 | **L1** | Anti-Malware | Internal-user malware notification — catches compromised M365 accounts Proofpoint cannot see on outbound internal paths. |
| CIS 2.1.4 / 2.1.5 | L2 | Safe Attachments | 2.1.5 (SPO/OneDrive/Teams) is the non-negotiable piece — Proofpoint TAP does not scan collaboration workloads. |
| CIS 2.1.6 | **L1** | Spam Policy | Admin notification requirement still applies; ensures M365-side policy triggers are visible to the MSP SOC. |
| CIS 2.1.7 | L2 | Anti-Phishing | Impersonation protection must run in M365 — depends on mailbox-level graph and cannot be outsourced to the SEG. |
| CIS 2.1.8 – 2.1.10 | **L1** | SPF / DKIM / DMARC | Auth records published for sending domains. Ensure DMARC alignment accounts for Proofpoint-relayed outbound mail (SPF include + DKIM signing by Proofpoint if configured). |
| CIS 2.1.12 – 2.1.14 | **L1** | Connection / Spam Filter Hygiene | No IP allowlists, safe list off, no allowed-domain bypass. **Critical:** do not allowlist the Proofpoint egress IPs in Connection Filter — use Enhanced Filtering for Connectors (EFC) instead so original sender IP is evaluated. |
| CIS 2.1.15 | **L1** | Outbound Spam | Outbound limits — applies to mail leaving M365 mailboxes before Proofpoint relay or direct send. |

> **Inforcer Deployment Note**
> All **L1 controls** in CIS Section 2.1 must be enforced regardless of SEG presence. **L2 controls** (Safe Links, Safe Attachments, Anti-Phishing) are the Inforcer default for Defender P1 / P2 customers. **Licensing constraint:** Safe Attachments and Safe Links require Defender for Office P1 minimum.

---

## Verification & Assessment Checklist

Use this checklist when delivering an Inforcer security assessment against a Proofpoint-fronted tenant. Findings flagged as critical should be remediated before any baseline policy deployment.

### Critical verifications

- [ ] Enhanced Filtering for Connectors is enabled on the Proofpoint inbound connector.
- [ ] Proofpoint IPs are **not** allowlisted in EOP Connection Filter (IP allow list).
- [ ] SPF record for the customer's primary sending domain includes Proofpoint's sending infrastructure (if Proofpoint relays outbound).
- [ ] DKIM signing is enabled for all Exchange Online domains — signed by both M365 and Proofpoint where applicable (dual DKIM acceptable).
- [ ] DMARC policy is published (minimum `p=none` with `rua` reporting; target `p=quarantine` or `p=reject` for mature tenants).

### Policy verifications

- [ ] **Anti-Phishing Policy:** Mailbox intelligence enabled, impersonation protection configured with customer VIP list.
- [ ] **Anti-Malware Policy:** Common Attachment Types Filter enabled with full Inforcer extension list.
- [ ] **Safe Attachments:** Applied to email with Block action; Safe Attachments for SPO/OneDrive/Teams enabled.
- [ ] **Safe Links:** Rewrite disabled for email, enabled for Teams and Office apps; time-of-click protection on.
- [ ] **Inbound Spam Filter:** Quarantine as default action; no allowed domains; bulk threshold tuned to 6.
- [ ] **Outbound Spam Filter:** Volume limits enforced; external auto-forwarding blocked.
- [ ] **Quarantine policy** (LimitedAccess-RequestByUser) applied to end-user-visible quarantine categories.

### Operational verifications

- [ ] Quarantine admin notifications enabled and routed to MSP SOC (CIS 2.1.6 L1).
- [ ] Internal sender malware notifications enabled (CIS 2.1.3 L1).
- [ ] Tenant Allow/Block List reviewed — no stale entries, all exceptions have expiration dates.
- [ ] Defender for Office submission workflow documented and users trained.

---

## Appendix A: Common Objections & Responses

### "We already have Proofpoint, why pay for Defender for Office P1/P2?"

Proofpoint and Defender for Office cover different surfaces. Proofpoint is an email-only gateway; Defender for Office covers Teams, SharePoint, OneDrive, internal mail, and mailbox-intelligence impersonation. Removing Defender leaves the collaboration workloads and internal mail paths unprotected. The correct framing is not "choose one" but "layered defense with configuration tuned to avoid duplicate work."

### "Safe Links breaks our Proofpoint click-tracking."

This is solved by disabling Safe Links URL rewriting for email while keeping Safe Links enabled for Teams and Office apps. The feature still satisfies CIS 2.1.1 and provides click-time protection in surfaces Proofpoint does not cover.

### "Why can't we just allowlist Proofpoint IPs and trust them?"

Allowlisting violates CIS 2.1.12 (L1) and degrades EOP's ability to detect compromised Proofpoint-to-M365 scenarios. Enhanced Filtering for Connectors achieves the correct outcome (respecting Proofpoint's filtering verdict while preserving EOP's visibility into the original sender) without the allowlist risk.

### "Anti-spam with Proofpoint in front is just noise."

Without EFC configured, this is true — EOP is flying blind. With EFC, EOP evaluates mail based on the original sender and provides a genuine second-layer judgement. The Inforcer recommendation is always: configure EFC first, then tune anti-spam conservatively so Defender catches what Proofpoint missed without re-classifying mail Proofpoint already passed.

---

## Appendix B: SEG Terminology Reference

**SEG = Secure Email Gateway** (not Secure Exchange Gateway). A generic industry category for products that sit between the internet and mail systems to filter inbound and outbound mail before it reaches the mailbox. The term predates and is independent of Microsoft Exchange.

### Common SEG products

- **Proofpoint** (Essentials, Enterprise/TAP) — primary focus of this document.
- **Mimecast** — very common in MSP environments, especially in EMEA.
- **Barracuda Email Security Gateway / Email Protection.**
- **Cisco Secure Email** (formerly IronPort).
- **Trend Micro Email Security.**
- **Sophos Email.**

### SEG vs ICES

**ICES = Integrated Cloud Email Security.** A newer Gartner-defined category for API-based products that plug into M365 or Google Workspace via Graph API and sit *alongside* EOP rather than in front of it via MX record.

| Pattern | Architecture | DFO Implications |
|---|---|---|
| **Traditional SEG** | `Internet → SEG → M365` (MX-based) | EFC required, Safe Links rewrite collision, anti-spam tuning needed. **This document applies.** |
| **ICES** | `Internet → M365`, with API inspection post-delivery | No EFC requirement, no Safe Links collision, Defender sees original sender natively. **This document does not apply** — deploy Inforcer DFO baseline as-is. |

Common ICES products: **Abnormal Security, Avanan (Check Point), IRONSCALES, Material Security.** When assessing a customer, always confirm the architecture pattern before applying SEG-specific guidance — ask whether mail flows through an MX-based relay or via API inspection.

---

## Document Metadata

*Document type:* Defender for Office configuration reference
*Scope:* MSP customers with Proofpoint Essentials or Proofpoint Enterprise fronting M365
*Baseline source:* IAC DFO policy set (Anti-Phishing, Anti-Malware, Safe Attachments, Safe Links, Inbound Spam, Outbound Spam, External Email Alert, LimitedAccess-RequestByUser)
*Framework alignment:* CIS Microsoft 365 Foundations Benchmark v6.0.0, Section 2.1
