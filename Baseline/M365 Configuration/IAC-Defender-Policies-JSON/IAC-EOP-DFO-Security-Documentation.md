# IAC (Infrastructure as Code) EOP & Anti-Spam/Phishing Rules Documentation

## Overview
This document summarizes the key Exchange Online Protection (EOP) mail flow rules and IAC Business Standard anti-spam and anti-phishing policies controls. These controls are designed to align with Microsoft and CIS best practices for email security.

---

## 1. IAC Mail Flow (Transport) Rules

> **Source Tenant:** acme2m365.onmicrosoft.com  
> **Export Date:** 2026-02-27  
> **Exported Files:** `MailFlowRules/*.json`  
> **Total Rules:** 3

### 1.1 IAC - Alert External Email

| Setting | Value |
|---------|-------|
| **State** | Enabled |
| **Priority** | 0 (highest) |
| **Mode** | Enforce |
| **Condition — FromScope** | NotInOrganization |
| **Condition — SentToScope** | InOrganization |
| **Action** | Prepend HTML disclaimer |
| **Fallback Action** | Wrap (attach message to new disclaimer message) |

**Purpose:** Adds a yellow caution banner to the top of all emails received from external senders, visually alerting users that the message originated outside the organisation.

**HTML Banner:**
```html
<!-- Yellow caution banner -->
<table border=0 cellspacing=0 cellpadding=0 align="left" width="100%">
  <tr>
    <td style="background:#ffb900;padding:5pt 2pt 5pt 2pt"></td>
    <td width="100%" cellpadding="7px 6px 7px 15px"
        style="background:#fff8e5;padding:5pt 4pt 5pt 12pt;word-wrap:break-word">
      <div style="color:#222222;">
        <span style="color:#222; font-weight:bold;">Caution:</span>
        This email is from an external organization. Please take care when
        clicking links or opening attachments. When in doubt, contact your
        IT Department
      </div>
    </td>
  </tr>
</table>
```

**CIS Mapping:** CIS Control 14.8 — Social Engineering Awareness

---

### 1.2 IAC - Block External Auto-Forwarding Email

| Setting | Value |
|---------|-------|
| **State** | Enabled |
| **Priority** | 1 |
| **Mode** | Enforce |
| **Condition — HeaderMatchesMessageHeader** | `X-MS-Exchange-Inbox-Rules-Loop` |
| **Condition — HeaderMatchesPatterns** | `.` (any value) |
| **Action — SetAuditSeverity** | Medium |
| **Action — RejectMessageEnhancedStatusCode** | `5.7.1` |
| **Action — RejectMessageReasonText** | `5.7.520 Access denied, Your organization does not allow external forwarding. Please contact your administrator for further assistance. AS(7555)` |

**Purpose:** Blocks automatic forwarding of emails to external recipients by detecting the `X-MS-Exchange-Inbox-Rules-Loop` header (present when inbox rules forward mail). Prevents data exfiltration and unauthorised sharing. Returns a clear denial message to the sender.

**CIS Mapping:** CIS Control 13.8 — Protect Data from Unauthorized Transfer

---

### 1.3 IAC - Block Malware

| Setting | Value |
|---------|-------|
| **State** | Enabled |
| **Priority** | 2 |
| **Mode** | Enforce |
| **Condition** | Attachment extension matches blocked list (53 extensions) |
| **Action — RejectMessageEnhancedStatusCode** | `5.7.1` |
| **Action — RejectMessageReasonText** | Descriptive anti-malware rejection notice |

**Purpose:** Provides ransomware and malware protection by blocking emails containing attachments with untrusted or dangerous file extensions. Messages are rejected at the transport layer before delivery.

**Blocked File Extensions (53):**

| | | | | | | | | |
|---|---|---|---|---|---|---|---|---|
| ade | adp | ani | app | appx | bas | bat | cab | chm |
| cmd | com | cpl | crt | exe | hlp | ht | hta | inf |
| ins | isp | iso | jar | jnlp | job | js | jse | lib |
| link | lnk | mda | mde | mdz | msc | msi | msp | mst |
| pcd | pif | reg | scr | sct | shs | url | vb | vbe |
| vbs | wsc | wsf | wsh | xll | xz | z | | |

**CIS Mapping:** CIS Control 9.7 — Deploy and Maintain Email Server Anti-Malware Protections

---

## 2. IAC Anti-Spam & Anti-Phishing Policies (EOP)

### 2.1 Anti-Malware Policy
- Custom anti-malware policy enabled
- Malware detection for all attachments
- Zero-hour auto purge (ZAP) enabled
- Common malicious attachment types blocked
- Admin notifications for malware detections



### 2.2 Anti-Spam Policy (Inbound)
- Custom inbound spam policy
- Bulk mail threshold tuned
- Spoof intelligence enabled
- Allowed/blocked senders reviewed regularly
- High-confidence spam action set to quarantine

**IAC - DfO - [Anti-Spam] [Inbound] [All Domains]**

- **Bulk Moves Enabled:** NotSet
- **Quarantine Retention Period:** 30 days
- **Bulk Threshold:** 6
- **Spam Action:** MoveToJmf
- **High Confidence Spam Action:** Quarantine
- **Bulk Spam Action:** MoveToJmf
- **Phish Spam Action:** Quarantine
- **High Confidence Phish Action:** Quarantine
- **ZAP (Zero-hour Auto Purge):** Enabled
- **Inline Safety Tips:** Enabled
- **Phish/Bulk/Spam Quarantine Tags:** DefaultFullAccessPolicy
- **High Confidence Phish Quarantine Tag:** AdminOnlyAccessPolicy
- **Is Default:** False


### 2.3 Anti-Spam Policy (Outbound)
- Custom outbound spam policy
- Automatic external forwarding set to Off or restricted
- Outbound spam notifications enabled
- Automatic account restriction for suspicious activity

**IAC - DfO - [Anti-Spam] [Outbound] [All Domains]**

- **Enabled:** False
- **Recipient Limit (External/Hour):** 500
- **Recipient Limit (Internal/Hour):** 1000
- **Recipient Limit (Per Day):** 1000
- **Action When Threshold Reached:** BlockUser
- **Notify Outbound Spam:** True (Recipients: admin@acme2m365.onmicrosoft.com)
- **Auto-Forwarding Mode:** Automatic
- **Is Default:** False


### 2.4 Anti-Phishing Policy (EOP)
- Custom anti-phishing policy for all users
- Basic spoof protection enabled
- Domain and user impersonation protection configured
- Detected phishing messages quarantined or deleted


#### IAC - DfO - [Anti-Phishing] for [All Domains]

- **Enabled:** True
- **Impersonation Protection State:** Manual
- **Mailbox Intelligence:** Enabled
- **Targeted User Protection:** False
- **Mailbox Intelligence Protection:** True
- **First Contact/Similar User/Domain Safety Tips:** First Contact: True, Similar Users: True, Similar Domains: False
- **Authentication Fail Action:** Quarantine
- **Spoof Intelligence:** Enabled
- **Honor DMARC Policy:** True (Reject/Quarantine)
- **Phish Threshold Level:** 3
- **Targeted Domains to Protect:** inorcer.com
- **Quarantine Tags:** AdminOnlyAccessPolicy (Spoof/High Confidence)
- **Is Default:** False

---


## 2. External Email Awareness

### 2.1 External Sender Identification
**Status:** Required

**Configuration**
- Native External Sender banner enabled (`Set-ExternalOutlookMessage`)
- No subject tagging or HTML body injection
- Single awareness mechanism to avoid user alert fatigue
```
  Set-ExternalInOutlook -Enabled $true
```

**CIS Mapping**
- CIS Control 14.8 – Social Engineering Awareness  

---

## 3. Mail Flow & Transport Security

### 3.1 Direct Send Review and Restriction
**Status:** Required

**Configuration**
- Review `Set-OrganizationConfig -RejectDirectSend $true`
- Identify legacy devices or applications using Direct Send
- Require IP-restricted connectors and SPF alignment for approved senders

> ⚠️ **NOTE:** This needs to be evaluated on a case-by-case basis as this could halt the use of multi-function copiers and other devices that may rely on Direct Send for older on-premise hardware to Exchange communication.

📖 **Reference:** [Introducing more control over Direct Send in Exchange Online](https://techcommunity.microsoft.com/blog/exchange/introducing-more-control-over-direct-send-in-exchange-online/4408790)

**CIS Mapping**
- CIS Control 4.8 – Disable Unnecessary Services  
- CIS Control 12.3 – Secure Network Infrastructure  

---

### 3.2 External Auto-Forwarding Controls
**Status:** Required

**Configuration**
- External auto-forwarding disabled via outbound spam policy
- Exceptions require documented approval
- Periodic review of forwarding exceptions

**Check AutoForwarding Rule:**

`Get-Mailbox -ResultSize Unlimited | Get-MailboxAutoReplyConfiguration | Where-Object {$_.AutoForwardEnabled -eq $true} | Select-Object Identity, AutoForwardAddress`

**Set AutoForwarding Rule to off:**

`Set-HostedOutboundSpamFilterPolicy -Identity "IAC - DfO - [Anti-Spam] [Outbound] [All Domains]" -AutoForwardingMode Off`


**CIS Mapping**
- CIS Control 8.7 – Centralize Audit Logs  
- CIS Control 13.8 – Protect Data from Unauthorized Transfer  

---

## 4. Authentication & Legacy Protocol Hardening

### 4.1 Legacy Authentication
**Status:** Required

**Configuration**
- Legacy authentication disabled tenant-wide
- Enforced using Security Defaults

**CIS Mapping**
- CIS Control 6.2 – Maintain Secure Authentication Practices  

---

### 4.2 SMTP AUTH
**Status:** Required

**Configuration**
- SMTP AUTH disabled globally
- Enabled only per mailbox where explicitly required
- All exceptions documented and reviewed

**CIS Mapping**
- CIS Control 4.8 – Disable Unnecessary Services  
- CIS Control 6.3 – Require MFA for Externally-Exposed Services  

---

### 4.3 POP / IMAP
**Status:** Required

**Configuration**
- POP and IMAP disabled globally
- Enabled only by documented exception

**1. Connect to Exchange Online**
```powershell
Connect-ExchangeOnline
```
> Establishes a session with Exchange Online to run mailbox and organization-level commands.

**2. Check Global POP/IMAP Status**
```powershell
Get-OrganizationConfig | Select-Object AllowPopConnections, AllowImapConnections
```
> Shows whether POP and IMAP are enabled or disabled tenant-wide. If set to `False`, legacy protocols are blocked for all users unless enabled per mailbox.

**3. Check Mailbox-Level POP/IMAP Status**
```powershell
Get-CASMailbox | Select-Object Name, PopEnabled, ImapEnabled
```
> Lists all mailboxes and shows whether POP and IMAP are enabled for each user. Use this to identify and restrict legacy protocol access on a per-user basis.

**4. Disable POP/IMAP at Mailbox Level (All Users)**
```powershell
Get-CASMailbox -ResultSize Unlimited | Set-CASMailbox -PopEnabled $false -ImapEnabled $false
```
> Force-disables POP and IMAP on every mailbox in the tenant. Run after verifying no legitimate exceptions exist.

**CIS Mapping**
- CIS Control 4.8 – Disable Unnecessary Services  

---



## References

- [Microsoft: EOP Anti-Spam Policies](https://learn.microsoft.com/exchange/antispam-and-antimalware/antispam-protection)
- [Microsoft: Anti-Phishing Policies](https://learn.microsoft.com/exchange/antispam-and-antimalware/anti-phishing-policies)
- [CIS Microsoft 365 Foundations Benchmark](https://www.cisecurity.org/benchmark/microsoft_365)
