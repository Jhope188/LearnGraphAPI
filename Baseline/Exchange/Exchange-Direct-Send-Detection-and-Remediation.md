# Exchange Online — Direct Send: Detection, Risk, and Remediation

**Platform:** Exchange Online  
**Admin Portal:** Exchange Admin Center → Settings → Mail flow; PowerShell via `Set-OrganizationConfig`  
**Last Reviewed:** April 2026  
**Status:** Public Preview (RejectDirectSend control)

---

## What Is Direct Send?

Direct Send is a mail submission method that allows devices, applications, or on-premises systems to send email by connecting **anonymously on port 25 to the Exchange Online Protection (EOP) SMTP host published in the domain's MX record** — no credentials, no connector, and no authentication required. Exchange Online accepts the message as long as the recipient address belongs to an accepted domain in the tenant.

The SMTP host is in the format `[domain]-[tld].mail.protection.outlook.com` (for example, `contoso-com.mail.protection.outlook.com` for `contoso.com`). This address is publicly discoverable by anyone via a standard DNS MX lookup — it is not an internal or private endpoint. An attacker identifies it with:

```
nslookup -type=MX contoso.com
→ contoso-com.mail.protection.outlook.com
```

They then connect directly to that hostname on port 25 with no credentials required.

It is distinct from the other two Exchange Online submission methods:

| Method | Auth Required | Supports External Recipients | Connector Required |
|---|---|---|---|
| Direct Send (MX, port 25) | No | No (internal only) | No |
| SMTP AUTH (port 587) | Yes | Yes | No |
| SMTP Relay (inbound connector) | No (IP-scoped) | Yes | Yes |

The core problem: the MX endpoint is publicly resolvable, and Direct Send has no authentication gate. This makes it a well-known abuse path for anyone who knows how Exchange Online mail submission works.

---

## CIS Benchmark Alignment

**CIS Microsoft 365 Foundations Benchmark v6.0.0**

| Control ID | Level | Title | Assessment |
|---|---|---|---|
| 6.5.5 | L2 | Direct Send submissions are rejected | Automated |
| 6.5.4 | L1 | SMTP AUTH is disabled | Automated |
| 2.1.8 | L1 | SPF records published for all Exchange Online domains | Automated |
| 2.1.9 | L1 | DKIM is enabled for all Exchange Online domains | Automated |
| 2.1.10 | L1 | DMARC records for all Exchange Online domains are published | Automated |
| 5.2.2.3 | L1 | CA policies block legacy authentication | Automated |

**CIS 6.5.5 Rationale:** Unauthenticated Direct Send submissions can be used by external parties to spoof internal domains, bypassing SPF/DMARC enforcement and delivering mail that appears trusted to internal recipients. Rejecting Direct Send removes an open, unauthenticated submission path that serves no legitimate purpose for most organizations.

**Note on L2 Classification:** CIS rates 6.5.5 as L2 because some organizations have legacy dependencies on Direct Send (printers, MFDs, line-of-business apps). However, given the active exploitation of this path in BEC and phishing campaigns, Inforcer should treat this as a **high-priority L2 control** and track it as part of baseline hardening for all tenants.

---

## Why Direct Send Is in Use (and Why It Persisted)

Direct Send was never designed as a long-term architecture — it was an easy path that required zero tenant-side configuration. Common reasons it exists in environments today:

- **MFDs and printers** (copiers, scanners) that only support anonymous SMTP to an MX endpoint and cannot store credentials or use TLS client authentication
- **Legacy line-of-business applications** written before modern auth existed — ERP systems, HR platforms, old ticketing tools
- **On-premises monitoring and alerting tools** (Nagios, PRTG, SolarWinds, etc.) sending alerts to internal mailboxes
- **Legacy SaaS vendors** configured years ago to send notifications from your domain via your MX record
- **IT convenience** — no connector or credential management required at setup time, so it was used as a shortcut that was never revisited

---

## How SPF, DKIM, and DMARC Relate to Direct Send

Understanding the email authentication stack is essential here, because a common assumption is that DMARC `p=reject` alone is sufficient to stop Direct Send abuse. It is not — and the reasons why matter for how you layer controls.

### SPF and Direct Send

SPF defines which IP addresses are authorized to send email on behalf of your domain. Any sender using Direct Send whose IP is **not** listed in your SPF record will fail SPF validation. However:

- Microsoft recommends configuring SPF with a **soft fail** (`~all`) rather than a hard fail (`-all`) to avoid breaking legitimate routing scenarios. With `~all`, a failing message is marked suspicious but not outright rejected — it can still be delivered based on other signals.
- Even with `-all` (hard fail), SPF enforcement alone doesn't block the Direct Send path at the SMTP level. The message is accepted for processing and only rejected later if all other signals also fail.
- SPF is the **first indicator** of unauthorized Direct Send — any IP not in SPF is an undocumented sender. This makes your SPF record a useful inventory tool: authorized Direct Send senders should be listed, and unknown senders in message trace that aren't in SPF are your risk surface.

### DKIM and Direct Send

DKIM cryptographically signs messages to prove they originated from your organization and have not been tampered with. A message sent via Direct Send by an unauthorized external party will not carry a valid DKIM signature from your domain — they do not have access to your private DKIM key.

- A missing or invalid DKIM signature contributes to DMARC failure, but does not independently block delivery.
- Legitimate Direct Send senders (your own authorized devices) also typically lack DKIM signatures, since Direct Send bypasses the Exchange Online signing infrastructure. This is another reason Direct Send is architecturally weak — even "legitimate" use fails DKIM.

### DMARC and Direct Send — The Critical Nuance

DMARC aligns SPF and DKIM results against the `From:` header domain and applies the published policy (`p=none`, `p=quarantine`, or `p=reject`) when both fail alignment.

A common assumption is that publishing `p=reject` will stop Direct Send abuse targeting your internal users. **This is not reliable, for two specific reasons:**

**1. Honor DMARC is on by default — but it is conditional on Spoof Intelligence, which composite auth can bypass.**

As of Microsoft's 2024 DMARC policy handling updates, the default anti-phishing policy in Exchange Online Protection **does** honor the sender's DMARC policy by default. When a message is detected as a spoof and the sender's DMARC policy is `p=reject`, EOP will reject it. When it is `p=quarantine`, EOP will quarantine it.

However, there is a critical dependency in the enforcement chain: **Honor DMARC only fires when Spoof Intelligence has first classified the message as a spoof.** If Spoof Intelligence does not flag it, Honor DMARC never activates — regardless of what the DMARC policy says.

This is where composite authentication creates the gap. If composite auth assigns `compauth=pass reason=002` to the message (implicit signals override the explicit DMARC failure), Spoof Intelligence may not classify it as a spoof, and the Honor DMARC enforcement chain is never entered.

DMARC `p=reject` also primarily protects *external* recipients — it signals to other organizations' mail servers to reject spoofed mail from your domain. The inbound enforcement path on your own tenant depends on the Spoof Intelligence → Honor DMARC chain described above.

**2. Exchange Online's composite authentication (implicit auth) can override DMARC failure.**

Exchange Online uses an implicit email authentication mechanism that evaluates additional signals beyond SPF, DKIM, and DMARC — things like sender reputation, message patterns, and historical data. If these signals give the message a pass, the DMARC failure can be overridden and the message delivered anyway. This is by design to reduce false positives, but it means DMARC `p=reject` is not a guaranteed gate even when properly honored.

### What This Means in Practice

Even with a fully compliant email authentication stack — SPF published, DKIM enabled, DMARC `p=reject`, Spoof Intelligence on, Honor DMARC enabled — Direct Send abuse can still reach internal inboxes in edge cases where composite authentication assigns a passing verdict. This has been demonstrated in lab testing.

`RejectDirectSend` operates at a completely different layer: it rejects the SMTP connection **before** any authentication evaluation occurs. The message never enters Exchange Online for processing. This is why it is the definitive fix, and why SPF/DKIM/DMARC should be understood as **complementary detection layers**, not replacements for closing the submission path.

| Control | What It Does | Stops Direct Send Abuse? |
|---|---|---|
| SPF `~all` | Marks unauthorized IPs as suspicious | No — soft fail still delivers |
| SPF `-all` | Hard fails unauthorized IPs | Partially — still subject to implicit auth override |
| DKIM | Validates message signing | No — missing signature ≠ rejection |
| DMARC `p=reject` (DNS only) | Signals to external receivers | No — does not self-enforce on EXO inbound |
| DMARC + Spoof Intelligence + Honor DMARC | EXO honors p=reject for detected spoofs | Partially — composite auth can still override |
| `RejectDirectSend = $true` | Rejects at SMTP handshake layer | Yes — definitive closure |

The layered recommendation: publish DMARC `p=reject`, enable Spoof Intelligence and Honor DMARC in the anti-phishing policy, **and** enable `RejectDirectSend`. All four controls together close the gap.

---

## How the Attack Works — P1/P2 and the Disguise Mechanism

Understanding exactly how an attacker disguises a Direct Send message is important context for why standard email authentication fails to catch it reliably.

Every email has two distinct sender addresses that serve completely different purposes:

| | Technical Name | Where It Lives | What Checks It | What the Recipient Sees |
|---|---|---|---|---|
| **P1** | Envelope sender (`MAIL FROM`) | SMTP session only — never in the message | SPF | Never — invisible to recipient |
| **P2** | Header From (`From:`) | Message header | DMARC alignment | Always — displayed in inbox |

The attacker exploits the gap between these two. In a Direct Send phishing attack the SMTP session looks like this:

```
SMTP session (invisible to recipient):
  MAIL FROM: <attacker@phishing.com>     ← P1 envelope — SPF checks this domain
  RCPT TO:   <employee@contoso.com>      ← target internal recipient

Message header (what the recipient sees):
  From: CEO Name <ceo@contoso.com>       ← P2 header — displayed in inbox
  Subject: Urgent: please action this
```

The victim opens the email and sees it from `ceo@contoso.com`. They never see `attacker@phishing.com` anywhere.

**Why authentication fails to stop this cleanly:**

- **SPF** checks the P1 domain (`phishing.com`) — not the P2 domain the victim sees. If the attacker controls `phishing.com` and has configured its SPF record correctly, SPF actually **passes**. The attacker's IP is authorized to send for their own domain. SPF has no awareness of the From: header.
- **DKIM** — the message carries no valid DKIM signature from `contoso.com` (the attacker doesn't have the private key), but may carry a valid signature from `phishing.com`. That passes DKIM for `phishing.com`, which is meaningless for the impersonation.
- **DMARC** detects the misalignment — P1 (`phishing.com`) doesn't match P2 (`contoso.com`) — and the `p=reject` policy should apply. But as covered in the section above, Exchange Online's composite authentication can override this verdict before the Honor DMARC enforcement chain is ever entered.

The MX endpoint the attacker targets is publicly discoverable via a standard DNS lookup:

```
nslookup -type=MX contoso.com
→ contoso-com.mail.protection.outlook.com
```

The format is always `[domain]-[tld].mail.protection.outlook.com`. This is not an internal address — it is a fully public-facing SMTP endpoint that anyone on the internet can connect to on port 25. The attacker submits the message directly to this endpoint with no credentials required.

---

## Composite Authentication (compauth) — Why It Can Override DMARC p=reject

Composite authentication is a **proprietary Microsoft 365 mechanism** that combines explicit email authentication results (SPF, DKIM, DMARC) with implicit signals — sender IP reputation, historical sending patterns, recipient interaction history, and machine learning — into a single verdict. The result is stamped into every inbound message header:

```
Authentication-Results: spf=fail; dkim=none; dmarc=fail action=reject;
  compauth=pass reason=002
```

The key reason code for Direct Send abuse is **`reason=002`**: explicit authentication failed (SPF, DKIM, and DMARC all failed) but implicit signals passed the message anyway. Exchange Online delivers it.

**The full override chain:**

```
DMARC p=reject fails alignment (P1 ≠ P2 domain)
       ↓
compauth=pass reason=002
  (attacker IP has general reputation; sending pattern looks superficially normal)
       ↓
Spoof Intelligence: message not classified as SPOOF
  (because compauth passed)
       ↓
"Honor DMARC policy" in anti-phishing: never triggered
  (it only fires when Spoof Intelligence has already classified a message as SPOOF)
       ↓
Message delivered to internal inbox
```

This is why `RejectDirectSend` is the definitive control. It operates at the **SMTP handshake layer** — the connection is refused with a `550 5.7.68` error before the message body is accepted, before composite auth runs, before Spoof Intelligence evaluates anything. The entire authentication evaluation chain never executes.

---

## Security Risks

### Active Exploitation
Cisco Talos has documented active BEC and phishing campaigns specifically exploiting Direct Send as a submission path. JUMPSEC's research has characterized it as a "phishing abuse primitive" — it is well-understood by threat actors and actively targeted. Lab research (vand3rlinden.com, Aug 2025) has demonstrated successful Direct Send phishing delivery even against tenants with Spoof Intelligence enabled when the DMARC policy was `p=none`.

### DMARC Bypass
Even with DMARC `p=reject` published, unauthorized Direct Send messages can reach internal inboxes if Exchange Online's composite authentication assigns them a passing verdict — which it can, based on reputation signals beyond SPF/DKIM/DMARC. The implicit auth mechanism is intentionally designed to reduce false positives, and this has the side effect of allowing some DMARC-failing Direct Send messages through.

### Quarantine Self-Release Risk
When Spoof Intelligence catches a Direct Send message and quarantines it, the default quarantine policy (`DefaultFullAccessWithNotificationPolicy`) allows end users to release messages themselves without admin approval. A user receiving a notification about a quarantined "legitimate-looking" message may release it directly. Restricting quarantine release to admins is a separate hardening step required to fully close this vector even when Spoof Intelligence is working correctly.

### No Authentication, No Attribution
There is no credential or identity attached to a Direct Send submission. If abuse occurs, there is no user account, app registration, or connector to trace back to. This makes forensic investigation significantly harder.

### Internal Trust Exploitation
Because the messages arrive via Exchange Online's own infrastructure, they often appear as trusted to internal recipients and may bypass suspicion filters that would catch external mail.

### MDDR 2025 Threat Context
The Microsoft Digital Defense Report 2025 screens 5 billion emails daily and identifies BEC as a high-impact, identity-driven attack class. MDDR Top 10 Recommendation #4 ("Defend your perimeter") specifically calls out email security posture — SPF, DKIM, DMARC, and authenticated submission paths — as a foundational perimeter control. Leaving an unauthenticated submission path open (Direct Send) undermines all email authentication investments.

---

## How to Detect Direct Send Usage in a Tenant

> Microsoft has confirmed a dedicated Direct Send traffic report is in development. Until it ships, use the methods below.

### Method 1: Inbound Messages Report (Exchange Admin Center)

1. Go to **Exchange Admin Center → Reports → Mail flow → Inbound messages report**
2. Click **Request report** and set your date range
3. Set **TLS version** filter to **No TLS**
4. Review results — messages arriving without a connector attribution and without TLS are the primary candidates for Direct Send traffic

This report is limited to the last 90 days.

### Method 2: PowerShell — Historical Message Trace

Use `Get-MessageTrace` to pull all inbound messages from your accepted domain and review for unauthenticated senders:

```powershell
Get-MessageTrace -StartDate (Get-Date).AddDays(-90) -EndDate (Get-Date) |
  Where-Object { $_.Status -eq "Delivered" -and $_.SenderAddress -like "*@yourdomain.com" } |
  Select-Object Received, SenderAddress, RecipientAddress, Subject, MessageId |
  Export-Csv DirectSendAudit.csv -NoTypeInformation
```

Review the output and correlate sending IPs from message headers. Any IP not belonging to a known device or connector in your environment is a candidate for Direct Send abuse or an undocumented legacy sender.

### Method 3: SMTP AUTH Clients Report (Cross-Reference)

In **EAC → Reports → Mail flow → SMTP AUTH clients report**, you can see which devices and clients are using *authenticated* SMTP submission (port 587). Devices appearing here are using the correct path. Known senders that appear in message trace but **not** in the SMTP AUTH report are your Direct Send candidates.

### Method 4: SPF Record Review

Your SPF record should enumerate every authorized sending source for your domain. Any device or application using Direct Send that is NOT listed in SPF is already failing SPF checks and likely landing in spam. Run an SPF lookup against your domain:

```
nslookup -type=TXT yourdomain.com
```

Cross-reference the authorized IPs against what you find in message trace. Gaps represent undocumented Direct Send senders.

### Method 5: Message Header Analysis

For suspicious messages, inspect headers for:

- **`X-MS-Exchange-CrossTenant-Id`** — should match your tenant ID. If missing or mismatched, it is external abuse.
- **Absence of connector name** in `Received` headers — legitimate relay connectors stamp the connector name.
- **No `X-MS-Exchange-Organization-SCL`** from a trusted connector source.

### EAC Reports That Support Direct Send Investigation

| Report | Usefulness | Notes |
|---|---|---|
| Inbound messages report | **Primary** — filter No TLS to surface Direct Send traffic | Main detection method today |
| SMTP AUTH clients report | **Complement** — shows who IS using authenticated submission | Cross-reference to find who isn't |
| Exchange Transport Rule report | **Conditional** — useful if ETRs have been created to tag Direct Send | Only relevant if rules already exist |
| Non-delivery details report | **Post-remediation** — shows blocked Direct Send after RejectDirectSend is enabled | Monitor after fix |
| Change Optics report | **Governance** — audit trail for when RejectDirectSend was enabled and connector changes | Good for compliance evidence |
| Mail flow map report | **Supplementary** — may surface anomalous submission patterns | Low specificity for Direct Send |

---

## Remediation: Enabling RejectDirectSend

Microsoft released the `RejectDirectSend` control in **public preview in 2025**. When enabled, any unauthenticated Direct Send attempt from an accepted domain that is not attributed to a configured inbound connector is rejected with:

```
550 5.7.68 TenantInboundAttribution; Direct Send not allowed for this organization from unauthorized sources
```

### Prerequisites Before Enabling

1. Complete the detection steps above — identify all sources currently using Direct Send
2. For each legitimate source, determine the correct migration path (see table below)
3. Create inbound connectors scoped to the IP addresses of any sources that cannot be migrated immediately
4. Validate mail flow for all identified sources before enabling the toggle

### Enabling the Control

```powershell
# Enable RejectDirectSend (requires Organization Configuration role)
Set-OrganizationConfig -RejectDirectSend $true

# Verify current state
Get-OrganizationConfig | Select-Object RejectDirectSend
```

Propagation takes approximately **30 minutes** across the Exchange Online service.

**Confirm connector attribution is working correctly after enabling:**

```powershell
# Verify a partner email is correctly attributed to an inbound connector
Get-MessageTrace -SenderAddress partner@externaldomain.com -StartDate (Get-Date).AddMinutes(-30) -EndDate (Get-Date) |
  Get-MessageTraceDetail | Select-Object Date, Event, Detail
```

### Platform Limitations

- `RejectDirectSend` is currently **not available** for GCC-High, DoD, USNat, or USSec environments
- Microsoft has stated that **new tenants will have this enabled by default** in the future, with no ability to disable — this is the long-term direction of travel
- Required admin role: **Organization Configuration**

---

## Migration Paths for Legitimate Direct Send Senders

| Sender Type | Recommended Path | Priority |
|---|---|---|
| Printer/MFD with credential support | Migrate to **SMTP AUTH on port 587** with a dedicated service account | High |
| Printer/MFD — no auth support | Create **IP-scoped inbound connector** (transitional); plan device refresh | Medium |
| On-premises app (can be updated) | Migrate to **Microsoft Graph API** (`Mail.Send` with app registration) | High |
| Legacy app (cannot be updated) | IP-scoped inbound connector as a long-term accommodation | Low |
| Third-party SaaS vendor | Require vendor to send from **their own domain** or use an authenticated connector | High |
| On-premises Exchange hybrid | Update OnPremises inbound connector to use **certificate-based domain verification** (not IP) | High |

---

## Inforcer Implementation Notes

- **Managed in Inforcer:** No — `RejectDirectSend` is not currently a managed control in Inforcer. Enforcement and monitoring must be handled manually via PowerShell or the Exchange Admin Center.
- **Policy type:** Exchange Online Organization Configuration
- **CIS mapping:** CIS M365 v6.0.0 — Control 6.5.5 (L2), with supporting controls 2.1.8, 2.1.9, 2.1.10
- **Drift risk:** Because this is not managed by Inforcer, there is no automated drift detection. If `RejectDirectSend` is toggled back to `$false` by an admin accommodating a legacy sender, the tenant is re-exposed with no alert. Manual periodic review via `Get-OrganizationConfig | Select RejectDirectSend` is recommended until this control is onboarded.
- **Future consideration:** `RejectDirectSend` is a boolean org config setting that is readable via `Get-OrganizationConfig`, making it a straightforward candidate for Inforcer management. A pre-check workflow (detect Direct Send usage → prompt connector creation → enforce the control) would be the recommended onboarding pattern.

---

## Key References and Articles

| Resource | Author/Source | Notes |
|---|---|---|
| [Introducing more control over Direct Send in Exchange Online](https://techcommunity.microsoft.com/blog/exchange/introducing-more-control-over-direct-send-in-exchange-online/4408790) | Microsoft Tech Community (2025) | Official announcement of RejectDirectSend public preview; includes PowerShell cmdlet and FAQ |
| [What is Direct Send and how to secure it](https://techcommunity.microsoft.com/blog/exchange/what-is-direct-send-and-how-to-secure-it/4439865) | Microsoft Tech Community (2025) | Microsoft's own explainer on the feature and hardening steps |
| [How to Identify Email Sent via Direct Send in Microsoft 365](https://blog.admindroid.com/how-to-check-exchange-online-direct-send-email-activities/) | AdminDroid (Aug 2025) | Practical walkthrough: message trace, PowerShell, EAC report methods |
| [How to Disable Direct Send Feature in Microsoft 365](https://blog.admindroid.com/how-to-enable-reject-direct-send-in-microsoft-365/) | AdminDroid (2025) | Step-by-step guide to enabling RejectDirectSend |
| [Reducing abuse of Microsoft 365 Exchange Online's Direct Send](https://blog.talosintelligence.com/reducing-abuse-of-microsoft-365-exchange-onlines-direct-send/) | Cisco Talos | Threat intelligence: active BEC/phishing campaigns exploiting Direct Send; remediation recommendations |
| [Microsoft Direct Send — Phishing Abuse Primitive](https://www.jumpsec.com/guides/microsoft-direct-send-phishing-abuse-primitive/) | JUMPSEC | Security research detailing how attackers use Direct Send to bypass trust controls |
| [Ongoing Campaign Abuses Microsoft 365's Direct Send to Deliver Phishing Emails](https://www.varonis.com/blog/direct-send-exploit) | Varonis | Real-world phishing campaign analysis using Direct Send |
| [Microsoft Direct Send Risks & the Case for Secure Email Relay](https://www.proofpoint.com/us/blog/email-and-cloud-threats/microsoft-direct-send-risks-need-for-secure-email-relay) | Proofpoint | Vendor perspective on risks and relay architecture alternatives |
| [Microsoft Introduces Reject Direct Send Block for Exchange Online](https://office365itpros.com/2025/04/30/reject-send-exo/) | Office365ITPros / Tony Redmond (Apr 2025) | Practical analysis of the new control; connector requirements and edge cases |
| [Exchange Online: Reject Direct Send](https://vand3rlinden.com/post/exo-reject-direct-send/) | vand3rlinden.com (Aug 2025) | Lab-confirmed attack demo showing Direct Send phishing delivery and quarantine self-release; validates composite auth bypass and RejectDirectSend as definitive fix |
| [The M365 Direct Send Vulnerability That Bypasses DMARC](https://albaspot.com/blog/m365-direct-send-vulnerability-dmarc-bypass-msp/) | Albaspot | MSP-focused breakdown of DMARC bypass mechanics |
| [How to set up a multifunction device or application to send email using Microsoft 365](https://learn.microsoft.com/en-us/exchange/mail-flow-best-practices/how-to-set-up-a-multifunction-device-or-application-to-send-email-using-microsoft-365-or-office-365) | Microsoft Learn | Official Microsoft guidance on all three sending options (Direct Send, SMTP AUTH, SMTP Relay) with decision criteria |
| [Updated requirements for SMTP Relay in Exchange Online](https://learn.microsoft.com/en-us/exchange/mail-flow-best-practices/updated-requirements-smtp-relay) | Microsoft Learn | Requirements for inbound connector-based relay (the recommended replacement for Direct Send) |

---

*Maintained by: Inforcer M365 Solutions Architecture*  
*Framework: CIS Microsoft 365 Foundations Benchmark v6.0.0*  
*Threat Reference: Microsoft Digital Defense Report 2025*
