# Exchange Online Settings Reference

> All settings sourced from Exchange Online organization configuration. Risk levels: **OK** = recommended state, **Review** = worth evaluating, **Risk** = security concern, **Neutral** = no security impact.

---

## Admin Notifications

| Setting | Value | Risk | Description |
|---|---|---|---|
| ExchangeNotificationEnabled | true | Review | Master switch for Exchange admin notifications. Enabled here but ExchangeNotificationRecipients is empty, meaning notifications are firing into a void. No admin will receive Exchange health, compliance, or capacity alerts until recipients are configured. |
| ExchangeNotificationRecipients | [] | Review | The list of recipients for Exchange admin notifications. Empty array means no one receives notifications even though ExchangeNotificationEnabled is true. Should contain at least one admin mailbox or distribution group. |
| SiteMailboxCreationURL | null | Neutral | Defines the URL used when creating a site mailbox linked to a SharePoint site. Null means default behavior applies. Site mailboxes are a legacy feature largely replaced by shared channels and SharePoint document libraries. |

---

## Archive & Retention

| Setting | Value | Risk | Description |
|---|---|---|---|
| AutoArchivingThresholdPercentage | 96% | Review | The mailbox fullness percentage at which auto-archiving is triggered. At 96% the mailbox is nearly full before archiving kicks in, leaving very little headroom. Most orgs set this between 75–85% to give earlier relief and avoid users hitting send/receive quota limits. |
| AutoEnableArchiveMailbox | false | Review | When true, archive mailboxes are automatically provisioned for all eligible users. False means archiving must be enabled manually per mailbox. For orgs with Exchange Online Plan 2 or a compliance add-on, enabling this is a best practice — it ensures no mailbox grows unchecked without an archive safety net. |

---

## Authentication & Session

| Setting | Value | Risk | Description |
|---|---|---|---|
| ActivityBasedAuthenticationTimeoutEnabled | true | OK | Master switch for activity-based session timeout in OWA and ECP. Enabled is the correct state — without this, OWA sessions never time out regardless of inactivity, leaving unattended browser sessions permanently open. |
| ActivityBasedAuthenticationTimeoutInterval | 01:00:00 | OK | The idle timeout duration for OWA and ECP sessions. 1 hour aligns with CIS M365 Foundations guidance. Previously configured at 6 hours — aligned to baseline. |
| ActivityBasedAuthenticationTimeoutWithSingleSignOnEnabled | true | Review | When true, the activity timeout also applies to SSO sessions, meaning an idle OWA session will time out even if the user is active in other M365 apps. More secure but can cause unexpected re-auth prompts. Worth documenting for helpdesk. |
| OAuth2ClientProfileEnabled | true | OK | Enables modern authentication (OAuth2) for Exchange Online clients. True is mandatory for MFA, Conditional Access, and all current Outlook clients. Disabling this falls back to basic authentication, which is deprecated and blocked by Microsoft. |
| EnforceExoAppRbacPermissions | false | Review | Controls whether the new Exchange Online RBAC model is enforced for app permissions. False means legacy service principal permission grants are still honored. Enabling is the forward-looking posture, but requires auditing app registrations using legacy EXO permissions first to avoid breaking integrations. |
| DefaultAuthenticationPolicy | null | Review | Sets the default authentication policy applied to all mailboxes without an explicit policy assignment. Null means no default policy is enforced — authentication protocol restrictions (blocking basic auth for POP, IMAP, SMTP) are not applied by default. Should reference a policy that disables legacy auth protocols. |

---

## Delayed Delicensing

| Setting | Value | Risk | Description |
|---|---|---|---|
| (no configurable properties) | n/a | Neutral | This group has no configurable properties exposed in the policy JSON. Delayed Delicensing controls how long a user's mailbox and data are retained after their license is removed. The absence of properties means the tenant is using Microsoft's default behavior (mailbox converted to inactive after 30 days). No action required unless custom retention windows are needed. |

---

## Calendar & Meetings

| Setting | Value | Risk | Description |
|---|---|---|---|
| OnlineMeetingsByDefaultEnabled | null | Review | Controls whether new meetings default to online (Teams) meetings. Null means not configured — falls back to per-user preference. In hybrid or Teams-first orgs this causes inconsistent meeting creation behavior across users. |
| ShortenEventScopeDefault | None | Neutral | Defines the default scope for the 'shorten meetings' feature. None means users must opt in individually. No security impact. |
| DefaultMinutesToReduceShortEventsBy | 5 | Neutral | When meeting shortening is active, events under a threshold are reduced by this many minutes (e.g. 30 min becomes 25 min). No security relevance. |
| DefaultMinutesToReduceLongEventsBy | 10 | Neutral | Same as above but for longer events (typically 60+ minutes). No security relevance. |
| HybridRSVPEnabled | true | OK | Allows attendees to indicate in-person vs. remote attendance on meeting invites. Useful for hybrid workplace planning. No security impact. |
| VisibleMeetingUpdateProperties | Location,AllProperties:15 | Review | Controls which property changes in a meeting update trigger attendee notifications. The ':15' suffix means changes within 15 minutes of the meeting trigger full notifications. Can leak meeting metadata to external attendees if not scoped properly. |
| MatchSenderOrganizerProperties | false | Review | When true, Exchange validates that the sender of a meeting update matches the original organizer. False means spoofed meeting updates are not validated — a vector for calendar phishing attacks. |

---

## Compliance & Auditing

| Setting | Value | Risk | Description |
|---|---|---|---|
| ElcProcessingDisabled | false | OK | ELC (Email Lifecycle / Managed Folder Assistant) enforces retention policies and litigation hold. False means ELC is running — this is the correct state. Disabling it prevents retention tags and hold processing from executing. |
| ReadTrackingEnabled | false | Neutral | When enabled, senders receive automatic read receipts. Disabled by default to protect recipient privacy. Enabling org-wide is discouraged and can be perceived as surveillance. |
| AuditDisabled | false | OK | Controls whether mailbox audit logging is active tenant-wide. False means auditing is ON — the correct state. Required by CIS and Microsoft best practices; feeds Purview audit and Defender XDR. |
| DLPWaitOnSendEnabled | false | Review | When enabled, outbound messages are held while DLP policies evaluate them before delivery. Disabled means DLP operates in detect mode — policy tips appear but messages are not blocked at send time. |
| DLPWaitOnSendTimeout | 9999 | Review | Timeout in seconds for the DLP hold-on-send evaluation window. 9999 seconds (~2.7 hours) is effectively unlimited. Since WaitOnSend is disabled above this value is dormant — but if WaitOnSend were enabled, this would cause extreme mail flow delays. |

---

## Connectors & Actionable Messages

| Setting | Value | Risk | Description |
|---|---|---|---|
| ConnectorsEnabled | true | Review | Master switch for Office 365 connectors across the tenant. Microsoft has been deprecating connectors in Teams in favor of Power Automate — leaving enabled exposes a legacy integration surface that is harder to audit. |
| ConnectorsActionableMessagesEnabled | true | Review | Allows actionable message buttons (approve/reject) in emails to trigger actions in external services. This surface has been used in phishing attacks where malicious emails render convincing action buttons that exfiltrate tokens or trigger unauthorized actions. |
| SmtpActionableMessagesEnabled | true | Risk | Extends actionable messages to emails received via SMTP — not just native Exchange. This allows external senders to embed actionable message markup in inbound email, significantly widening the phishing attack surface. |
| ConnectorsEnabledForOutlook | true | Review | Permits connector configuration within Outlook clients. Reduces visibility into active connectors since users configure them client-side rather than in the admin center. |
| ConnectorsEnabledForTeams | true | Review | Allows Teams connectors (legacy). Microsoft has announced deprecation in favor of Power Automate workflows. Leaving enabled perpetuates a legacy path that won't receive security updates. |
| ConnectorsEnabledForSharepoint | true | Review | Allows connectors to post into SharePoint. Largely superseded by Power Automate. Same deprecation concern as Teams connectors. |
| ConnectorsEnabledForYammer | true | Neutral | Allows connectors for Viva Engage (Yammer). Relevant only if the org actively uses Viva Engage. No additional risk beyond the general connector surface. |

---

## Distribution Groups & M365 Groups

| Setting | Value | Risk | Description |
|---|---|---|---|
| DistributionGroupDefaultOU | null | Neutral | Defines where in Active Directory new distribution groups are created (hybrid only). Null means default OU placement. Relevant only in hybrid Exchange environments. |
| DistributionGroupNameBlockedWordsList | [] | Review | A list of words prohibited from appearing in distribution group names. An empty list means no naming guardrails — groups could be named to mimic privileged accounts (e.g. 'IT-Admins', 'Security-Team'). |
| DistributionGroupNamingPolicy | (empty) | Review | Enforces a naming convention for distribution groups. Empty means group names are unconstrained, making it harder to identify group purpose or ownership at scale in large tenants. |
| DirectReportsGroupAutoCreationEnabled | false | Neutral | When enabled, automatically creates an M365 Group for each manager containing their direct reports. Disabled avoids group sprawl. Low security impact. |
| DefaultGroupAccessType | Private | OK | Sets the default privacy for new M365 Groups to Private — content is not discoverable by non-members. This is the recommended setting. Public groups expose content and membership to the entire tenant by default. |
| IsGroupFoldersAndRulesEnabled | false | Neutral | Controls whether M365 Groups can have shared folders and inbox rules. Enabling can improve collaboration workflows but adds complexity to group mailbox management. |
| EndUserDLUpgradeFlowsDisabled | false | Review | When false, end users can upgrade classic distribution lists to M365 Groups without admin involvement. This can result in uncontrolled group creation and SharePoint site provisioning. |
| IsGroupMemberAllowedToEditContent | false | OK | Controls whether regular members (not owners) can edit shared group content. False means only owners can edit — appropriate for most orgs. |

---

## EWS & REST API Access

| Setting | Value | Risk | Description |
|---|---|---|---|
| EwsEnabled | null | Review | Master switch for Exchange Web Services API access. Null means not explicitly configured — EWS defaults to enabled. EWS is a legacy SOAP API that should be explicitly set and restricted via application access policies. |
| EwsApplicationAccessPolicy | null | Review | Controls which applications can access Exchange data via EWS. Null means no restriction — any app with valid credentials can access any mailbox. Should be set to EnforceAllowList or EnforceBlockList with explicit app entries for least-privilege API access. |
| EwsAllowList | null | Neutral | Allowlist of user agent strings permitted to access EWS. Only relevant when EwsApplicationAccessPolicy is set to EnforceAllowList. |
| EwsBlockList | null | Neutral | Blocklist of user agent strings denied EWS access. Only relevant when EwsApplicationAccessPolicy is set to EnforceBlockList. |
| EwsAllowOutlook | null | Neutral | Controls whether the classic Outlook client can use EWS. Null inherits from EwsEnabled. Relevant for orgs forcing modern auth. |
| EwsAllowMacOutlook | null | Neutral | Same as above but scoped to Outlook for Mac. Null inherits from EwsEnabled. |
| EwsAllowEntourage | null | Neutral | Controls EWS access for the legacy Entourage client. Effectively obsolete — no modern deployment uses Entourage. |

---

## FindTime (Meeting Polls)

| Setting | Value | Risk | Description |
|---|---|---|---|
| FindTimeAttendeeAuthenticationEnabled | false | Risk | When false, external attendees can participate in FindTime polls without authenticating. Anyone with the poll link can respond — no validation of who is actually responding. This can expose attendee availability or allow time slot manipulation. |
| FindTimeOnlineMeetingOptionDisabled | false | Neutral | When false, FindTime polls can include an option to make the resulting meeting online (Teams). Generally fine and improves usability for hybrid orgs. |
| FindTimeAutoScheduleDisabled | false | Review | When false, FindTime can automatically schedule the meeting once a consensus is reached without organizer confirmation. Auto-scheduling without organizer review can result in meetings being booked without explicit organizer knowledge. |
| FindTimeLockPollForAttendeesEnabled | false | Neutral | When false, attendees can continue to change their availability responses after submitting. Enabling locking prevents response manipulation after submission. Low risk either way. |

---

## Hybrid / Directory Sync

| Setting | Value | Risk | Description |
|---|---|---|---|
| AutodiscoverPartialDirSync | false | Neutral | Used in hybrid Exchange deployments where Autodiscover points to on-premises for some users. False means all Autodiscover is handled cloud-side. Only relevant for active hybrid Exchange coexistence. |

---

## Mail Flow & Addressing

| Setting | Value | Risk | Description |
|---|---|---|---|
| DisablePlusAddressInRecipients | false | Review | Plus addressing (user+tag@domain.com) is enabled. While useful for filtering, it can be abused by senders to probe mailbox existence or bypass simple address-based filtering rules. |
| SendFromAliasEnabled | false | Neutral | Allows users to send email as one of their proxy addresses. Disabled by default. Enabling improves alias usability but means outbound mail From address may not match user expectation. |
| SharedDomainEmailAddressFlowEnabled | true | Review | Enables mail flow for addresses shared across tenants. If your org doesn't intentionally share a domain across tenants, having this enabled is unexpected and worth investigating. |
| InRegionRoutingEnabled | false | Neutral | Ensures mail between users in the same geographic region is routed within that region. Primarily a data residency and latency concern. False means standard global routing. |
| ByteEncoderTypeFor7BitCharsets | 0 | Neutral | Controls encoding for 7-bit character sets in outbound SMTP. Value 0 is the default (QP encoding). Only relevant for specific legacy system interoperability issues. |

---

## MailTips

| Setting | Value | Risk | Description |
|---|---|---|---|
| MailTipsAllTipsEnabled | true | OK | Master switch enabling MailTips — the warning bar in Outlook that alerts senders before sending a potentially problematic message. Enabling is a CIS and Microsoft best practice. |
| MailTipsExternalRecipientsTipsEnabled | true | OK | Shows a MailTip when addressing external recipients. Helps prevent accidental data disclosure to external parties. Strongly recommended enabled. |
| MailTipsGroupMetricsEnabled | true | OK | Shows recipient count when addressing a distribution list. Helps users understand the scope of their message before sending to large groups. |
| MailTipsLargeAudienceThreshold | 25 | Review | The recipient count at which the 'large audience' MailTip triggers. 25 is the default but many orgs set this lower (10–15) to catch accidental broad sends earlier. Consider tuning based on org size. |
| MailTipsMailboxSourcedTipsEnabled | true | OK | Shows MailTips sourced from mailbox-level settings such as Out-of-Office status or moderated mailbox warnings. Recommended enabled. |

---

## Message Recall

| Setting | Value | Risk | Description |
|---|---|---|---|
| MessageRecallEnabled | null | Review | Controls whether cloud-based message recall is available. Null means not explicitly configured. Microsoft has been rolling out cloud recall as a default-on feature — leaving null means behavior may vary by rollout state. |
| MessageRecallMaxRecallableAge | 365 days | Review | Sets how far back a sender can attempt to recall a message. 365 days is unusually long — standard practice is 30 days. A 365-day window means a compromised account could attempt to recall messages sent up to a year ago, potentially destroying evidence. |
| RecallReadMessagesEnabled | null | Review | Controls whether recall attempts are made against messages already read by the recipient. Null means the platform default applies. |
| MessageRecallAlertRecipientsEnabled | false | Review | When false, recipients are not notified when a recall is attempted against their mailbox. A sender or attacker with access can silently attempt to pull back messages without the recipient knowing a recall was tried. |
| AutomaticForcedReadReceiptEnabled | false | OK | When true, read receipts are forced on recalled messages. False is appropriate — forced read receipts on recalls can cause unintended privacy implications. |

---

## Microsoft Bookings

| Setting | Value | Risk | Description |
|---|---|---|---|
| BookingsEnabled | true | Review | Master switch enabling Microsoft Bookings. Bookings pages are externally accessible by default, exposing staff calendars and availability to the public without additional restrictions. |
| BookingsAuthEnabled | false | Risk | When false, customers can book appointments without authenticating. Anonymous users can book time with any Bookings-enabled staff member. Enabling authentication restricts booking to known/signed-in users. |
| BookingsExposureOfStaffDetailsRestricted | false | Risk | When false, staff names, photos, and availability details are visible to anyone viewing a public Bookings page. A significant privacy and social engineering risk — enumerates internal staff to external actors. |
| BookingsSocialSharingRestricted | false | Review | When false, Bookings pages can be shared on social media platforms, distributing pages that expose staff availability and business information. |
| BookingsSearchEngineIndexDisabled | false | Review | When false, Bookings pages are indexable by search engines. Staff names and availability can appear in public search results. Should be true for most enterprise orgs. |
| BookingsAddressEntryRestricted | false | Neutral | When false, customers can enter any address when booking. Primarily a data quality concern. |
| BookingsPhoneNumberEntryRestricted | false | Neutral | When false, customers can enter any phone number. Same data quality concern as address restriction. |
| BookingsNamingPolicyEnabled | false | Review | When false, staff can name their Bookings pages freely. Enabling a naming policy prevents misleading or unofficial-sounding page names. |
| BookingsPaymentsEnabled | false | Neutral | Controls whether Bookings can collect payments. Disabled means no payment processing. Fine as-is if the org never uses paid bookings. |
| BookingsSmsMicrosoftEnabled | true | Review | When true, Microsoft can send SMS reminders to customers on behalf of your Bookings pages. Customer phone numbers are transmitted to Microsoft's SMS infrastructure. Review data handling obligations for regulated industries. |
| BookingsMembershipApprovalRequired | false | Neutral | Controls whether membership approval is required for Bookings. No significant security impact in most deployments. |
| BookingsCreationOfCustomQuestionsRestricted | false | Neutral | When false, staff can add custom questions to booking forms. Data quality and form governance concern rather than security. |
| BookingsNotesEntryRestricted | false | Neutral | When false, customers can add free-text notes when booking. Minimal security impact. |
| BookingsNamingPolicyPrefixEnabled | false | Neutral | Prefix enforcement for Bookings naming policy. Inactive since naming policy is disabled. |
| BookingsNamingPolicySuffixEnabled | false | Neutral | Suffix enforcement for Bookings naming policy. Inactive since naming policy is disabled. |
| BookingsBlockedWordsEnabled | false | Neutral | Blocked words list for Bookings page names. Inactive since naming policy is disabled. |

---

## Mobile & Workspace

| Setting | Value | Risk | Description |
|---|---|---|---|
| OutlookPayEnabled | true | Review | Enables payment request functionality within Outlook. Allows users to send and receive payment requests via email. In most enterprise environments this capability is unnecessary and represents a financial transaction surface within email. |
| OutlookMobileGCCRestrictionsEnabled | false | Neutral | Enforces additional restrictions for Outlook Mobile in GCC environments. Only relevant for GCC tenants. |
| WorkspaceTenantEnabled | true | Neutral | Enables room booking and hot-desk/workspace reservation capabilities. Benign unless the org has specific physical security requirements around desk booking visibility. |

---

## Outlook Experience

| Setting | Value | Risk | Description |
|---|---|---|---|
| AppsForOfficeEnabled | true | Review | Enables Office Add-ins in Outlook. Add-ins execute in the context of the user's mailbox and can read email content — a significant data exfiltration risk if not governed via the Add-ins admin policy. |
| LinkPreviewEnabled | true | Review | Allows Outlook to generate rich link previews for URLs in emails. Preview generation requires Outlook to call out to the linked URL, which can confirm link viability to malicious senders and may leak metadata about the recipient's environment. |
| AsyncSendEnabled | true | OK | Allows Outlook to run add-in checks (like DLP or MailTips) asynchronously before sending. True is the correct state — enables pre-send policy checks without blocking the user experience. |
| WebSuggestedRepliesDisabled | false | Neutral | When false, Outlook on the Web shows AI-generated suggested replies. Disabling is a privacy preference — content is processed by Microsoft's inference infrastructure. Consider disabling for regulated or sensitive orgs. |
| OutlookTextPredictionDisabled | false | Neutral | When false, Outlook shows inline text completion suggestions. Same privacy consideration as suggested replies. Consider disabling for regulated environments. |
| PublicComputersDetectionEnabled | false | Review | When enabled, Exchange detects OWA access from public/shared computers and adjusts session security (e.g. shorter timeouts). Disabling means all sessions are treated the same regardless of device trust. |
| DefaultFolderPermissionRestricted | false | Review | When false, users can grant others access to their default folders (Inbox, Calendar) without admin oversight. Enabling restriction prevents inadvertent over-sharing of sensitive mailbox folders. |
| FocusedInboxOn | null | Neutral | Controls Focused Inbox feature tenant-wide. Null means not forced — users control it per-mailbox. Acceptable in most cases. |
| EnableOutlookEvents | false | Neutral | When enabled, Outlook auto-detects events like flights and package deliveries from email content and adds them to the calendar. Disabled is a privacy-positive choice for sensitive environments. |
| LeanPopoutEnabled | false | Neutral | When enabled, opens emails in a lightweight pop-out window in OWA. Disabled means the standard reading pane is used. No security impact. |
| WebPushNotificationsDisabled | false | Neutral | When false, OWA can send browser push notifications for new email. No security impact — user preference setting. |
| MobileAppEducationEnabled | true | Neutral | Shows prompts encouraging users to install Outlook Mobile. No security impact. |
| OutlookGifPickerDisabled | false | Neutral | When false, users can insert GIFs from the built-in GIF picker. No security impact. |
| MessageRemindersEnabled | true | Neutral | Enables follow-up reminders for messages. No security impact. |
| MessageHighlightsEnabled | true | Neutral | Highlights important messages in the inbox. No security impact. |
| PostponeRoamingSignaturesUntilLater | false | Neutral | Controls when roaming email signatures are synced. No security impact. |
| TwoClickMailPreviewEnabled | false | Neutral | Requires two clicks to preview email content. Minor UX setting, no security impact. |
| ActionableMessagesExtenalAccessTokenEnabled | false | OK | When false, actionable messages cannot use external access tokens. Keeping this false reduces the risk of actionable message token abuse by external senders. |

---

## Public Folders

| Setting | Value | Risk | Description |
|---|---|---|---|
| PublicFoldersEnabled | Local | Review | Public folders are enabled and hosted in Exchange Online. A legacy collaboration feature with limited modern governance controls. Their presence should be documented — they can contain sensitive data accessible to large groups with minimal audit visibility. |
| DefaultPublicFolderDeletedItemRetention | 30 days | OK | Deleted items are retained for 30 days before permanent deletion. 30 days is a reasonable default allowing recovery of accidentally deleted content. |
| DefaultPublicFolderMovedItemRetention | 7 days | Neutral | Items moved between public folders are retained in a recoverable state for 7 days. Default value — acceptable for most orgs. |
| DefaultPublicFolderIssueWarningQuota | 1.7 GB | Neutral | Sends a warning when a public folder reaches 1.7 GB. Default value — acceptable. |
| DefaultPublicFolderProhibitPostQuota | 2 GB | Neutral | Prevents new posts to a public folder once it reaches 2 GB. Default value — acceptable. |
| DefaultPublicFolderMaxItemSize | Unlimited | Review | No maximum size restriction per item. Unlimited item size means users can post arbitrarily large attachments to public folders, potentially consuming significant storage and making quota management harder. |
| DefaultPublicFolderAgeLimit | null | Neutral | No age limit configured for public folder items. Items persist indefinitely unless a retention policy is applied. Acceptable if covered by an org-wide retention policy. |
| PublicFolderShowClientControl | false | Neutral | When false, Outlook clients do not show a toggle to enable/disable public folder access from the client side. Default and acceptable. |
| RemotePublicFolderMailboxes | [] | Neutral | No remote public folder mailboxes configured. Expected for cloud-only or non-hybrid deployments. |

---

## Security & Anti-Spoofing

| Setting | Value | Risk | Description |
|---|---|---|---|
| RejectDirectSend | true | OK | Blocks unauthenticated direct SMTP sends — where a device sends email directly to Exchange Online without an authorized relay or connector. A common attack vector: without this, an attacker who knows your MX record can inject mail directly into your tenant. Strongly recommended enabled. The trade-off: any legacy device (printers, scanners, MFPs) using direct send will break and must be reconfigured to use an authenticated SMTP relay. |
| MaskClientIpInReceivedHeadersEnabled | true | OK | Removes the originating client IP address from email headers on outbound mail. Prevents external recipients from seeing internal network IPs and reduces reconnaissance information in email headers. Recommended enabled. |
| IPListBlocked | [] | Review | A tenant-level IP blocklist for inbound mail. Empty means no manual IP-based blocking is configured. EOP/Defender handles most IP reputation blocking automatically, but this list allows enforcement of known bad IPs not yet caught by Microsoft's intelligence feeds. |
| UnblockUnsafeSenderPromptEnabled | true | Review | When true, users can override Exchange's unsafe sender classifications directly from Outlook. Gives end users the ability to unblock malicious senders — consider disabling to enforce admin-only unblock actions. |

---

*Generated from Exchange Online organization configuration — review against current Microsoft documentation and CIS M365 Foundations benchmark for authoritative guidance.*
