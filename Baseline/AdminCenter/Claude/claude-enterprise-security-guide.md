# Securing Claude Enterprise in a Microsoft 365 Tenant

**Scope:** Force the sanctioned Claude Enterprise organization, block personal Claude accounts, limit access to an Entra group, secure the Claude add-ins and connector for M365, and control unsanctioned AI with Defender for Cloud Apps (DFCA), Global Secure Access (GSA), Intune and Purview.
**Last verified:** 2026-11-06 against Anthropic Help Center and Microsoft Learn (links per section). Anthropic ships fast; re-verify anything older than 3 months.
**Naming:** Groups and CA policies below follow the lab conventions (`SG-[Pillar]-[Type]-[Scope]-[Env]-[Name]`, `IAC - [SCOPE] - [CONTROLTYPE] - [Descriptor]`). Names are proposals; adjust to your tenant.

**Status legend:** `[GA]` source does not label it preview/beta | `[BETA]` / `[PREVIEW]` source says so | `[UNVERIFIED]` not confirmed by a source this session, test before relying on it.

---

## 1. The problem, stated honestly

There is **no single switch** that forces Enterprise Claude and disables personal Claude. Personal accounts are separate identities on the same website, so the block has to happen at several layers. Each layer closes a different hole.

| Layer | Control | What it stops | What it does NOT stop |
|---|---|---|---|
| Identity (Claude) | Verified domain, Restrict organization creation, Require SSO, Domain capture | New or existing personal accounts on **your verified email domain** | A personal `@gmail.com` account (not on your domain) |
| Identity (Entra) | Enterprise app with Assignment required, group assignment, CA | Non-group members signing in to the Enterprise org via SSO | Anyone using a personal Claude login (never touches Entra) |
| Client | `forceLoginOrgUUID` (Desktop), Claude for Intune (iOS) | Signing in to the wrong org inside the managed app | Browser use, add-ins, other platforms |
| **Network** | **`anthropic-allowed-org-ids` header via GSA or proxy** | **Any non-allowlisted Claude org, including personal `@gmail.com` accounts, on devices whose traffic you inspect** | Devices or networks that bypass the client/proxy |
| Endpoint / data | DFCA unsanctioning, Purview Endpoint DLP | Other (non-Claude) AI apps; sensitive data pasted to AI sites | Cannot tell Enterprise Claude from personal Claude on the same domain |

**Key conclusion:** the network-layer header is the only control that distinguishes "our Claude org" from "someone's personal Claude account" when the personal account is not on your domain. Everything else narrows the problem. Anthropic's domain-capture documentation covers accounts on your verified domain only.

**Critical trap:** Do **not** mark Claude as *Unsanctioned* in DFCA. Unsanctioning syncs the app's domains to Defender for Endpoint and blocks them on onboarded devices. Learn describes no Enterprise-vs-personal distinction, so expect it to block your Enterprise org too `[UNVERIFIED inference, test in pilot]`. Use DFCA to unsanction *other* AI apps and use the network header for Claude.

---

## 2. Prerequisites and licensing

| Need | Why | Status / source |
|---|---|---|
| Claude **Enterprise** plan | SCIM, domain claiming/capture, Tenant Restrictions header, Compliance API. Team plans can verify a domain and block *new* personal accounts but cannot claim existing ones | [Domain claiming](https://support.claude.com/en/articles/14625619-claim-and-migrate-accounts-on-your-domain), [Tenant Restrictions](https://support.claude.com/en/articles/13198485-enforce-network-level-access-control-with-tenant-restrictions) |
| Entra ID P1/P2 | SCIM provisioning (Anthropic's requirement) and group-based app assignment (Learn) | [Anthropic Entra SSO](https://support.claude.com/en/articles/13917889-microsoft-entra-id-sso-setup), [Learn: assign users/groups](https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-or-group-access-portal) |
| Entra **Internet Access** license (not just P1/P2) | Internet Access profile, web filtering, custom headers. P1/P2 covers only the Microsoft traffic profile, UTR, and compliant network | [GSA licensing table](https://learn.microsoft.com/entra/global-secure-access/overview-what-is-global-secure-access#licensing-overview) |
| GSA client (Windows, macOS, iOS, Android) + TLS inspection | Header injection requires the client (or remote network/EFP) and TLS inspection | [Custom headers](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-custom-headers) |
| Defender for Endpoint with Cloud Protection + Network Protection | DFCA unsanctioned-app blocking | [Govern discovered apps](https://learn.microsoft.com/defender-cloud-apps/governance-discovery) |
| DFCA/Cloud Discovery licensing tier | Enforcement vs visibility-only split | `[UNVERIFIED]` not confirmed this session. Verify with the m365-licensing skill before quoting E3/Business Premium vs E5 behavior |

---

## 3. Groups (create first)

| Group | Type | Purpose |
|---|---|---|
| `SG-Entra-AUG-CLAUDE-Prod-Users` | Assigned (or dynamic), **no nested groups** | Everyone allowed to use Enterprise Claude. Assigned to the Entra Claude app, M365 connector apps, add-in deployment, GSA security profile CA policy, SCIM role group |
| `SG-Entra-AUG-CLAUDE-Prod-Admins` | Assigned | Maps to Claude Owner/Admin role |
| `SG-Entra-AUG-CLAUDE-Pilot-Users` | Assigned | Pilot first; swap for Prod group at cutover |
| `SG-Entra-AUG-CAP-BreakglassAccounts` | Existing | Exclude from every user-targeted CA policy |
| `SG-Intune-ADG-WIN/MAC-Claude-Devices` | Device group | Intune assignments for Desktop config (device-targeted policies go to device groups) |

**Nested groups are not supported** for application assignment ([Learn](https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-or-group-access-portal)) or for M365 centralized add-in deployment (top-level groups only, per the [centralized deployment FAQ](https://learn.microsoft.com/microsoft-365/admin/manage/centralized-deployment-faq?view=o365-worldwide)). Use direct members or dynamic rules.

Anthropic recommends an `anthropic-claude-` / `anthropic-console-` name fragment for groups mapped to Claude roles (not required). Decide whether your convention or theirs wins before creating.

---

## 4. Phase 1: Claude Enterprise organization

Source: [Set up SSO](https://support.claude.com/en/articles/13132885-set-up-single-sign-on-sso) | [Entra SSO setup](https://support.claude.com/en/articles/13917889-microsoft-entra-id-sso-setup) | [JIT/SCIM](https://support.claude.com/en/articles/13133195-set-up-jit-or-scim-provisioning) | [Domain claiming](https://support.claude.com/en/articles/14625619-claim-and-migrate-accounts-on-your-domain) `[GA]` (no preview label; pages dated Aug-Sep 2026)

Admin URLs: `claude.ai/admin-settings/organization`, `/identity`, `/groups`, `/roles`, `/connectors`, `/capabilities`.

### 4.1 Verify the domain
1. Organization settings > Organization and access > **Domains** > "Add or edit domains".
2. Add all domains first (one claim covers only domains verified at the moment you start it).
3. Add the TXT record (`anthropic-domain-verification-...`) at the **root** of the domain. **Save the full value before leaving the screen**: it is not shown again once Pending.

### 4.2 Restrict organization creation
After verification, **Security > Restrict organization creation** appears. Turning it on blocks anyone creating a Claude or Console organization, including personal accounts, with your verified domains. It is also a prerequisite for domain capture.

### 4.3 Configure SSO (Entra SAML)
1. Entra > Enterprise applications > New application > search "Claude" (or Create your own, non-gallery). Name it consistently (the CA and Defender policies below target this app).
2. Single sign-on > SAML. Entity ID and Reply URL come from the WorkOS setup flow in Claude's Identity settings. Sign-on URL: `https://claude.ai/login`.
3. Attributes & Claims: email claim = `user.mail` (or whichever attribute you will also use for SCIM). **The SSO email and SCIM email attributes must be identical**; Anthropic calls mismatch the most common login failure.
4. Upload Federation Metadata XML in the WorkOS flow, then run **Test sign-in**.

### 4.4 Provisioning: SCIM + group mappings (how "only an Entra group" works inside Claude)
| Mode | Behavior with group mappings |
|---|---|
| JIT + mappings | Users in a mapped group are provisioned at login; removal from all mapped groups removes them at next login. Unassigning them from the app blocks login but leaves them in the member list holding a seat until an admin removes them |
| **SCIM + mappings** (recommended) | Users in at least one mapped group are provisioned with the mapped role; removal from groups removes them automatically |

Steps:
1. Entra app > Provisioning > Automatic; enter Tenant URL and Secret Token from the Claude SCIM setup; **Test Connection**; confirm the email mapping; set status **On**.
2. Claude > Organization and access > **User provisioning** > SCIM directory sync. **Do not save until every intended user is assigned to the Entra app**: unassigned users are deprovisioned on save. Review the sync preview and removal count before confirming.
3. Enable group mappings. Map `SG-Entra-AUG-CLAUDE-Prod-Admins` to Owner/Admin and `SG-Entra-AUG-CLAUDE-Prod-Users` to User. **Every user must be in a role group** or they are not provisioned.
4. Make sure at least one admin is in an Owner/Admin-mapped group **before** saving, or you can lock yourself out (Primary Owner is exempt from SCIM reconciliation, but Owners and Admins are not).
5. Custom roles with SCIM need a two-pass setup (save with mappings off, let the first sync finish, assign synced groups to custom roles, then enable mappings).
6. Entra pushes SCIM changes about every 40 minutes; use **Sync** to force.

### 4.5 Require SSO
Organization and access > Authentication > **Require SSO for Claude**. Test with a pilot user first. If your SAML signing certificate expires while this is on, nobody can sign in; set a calendar reminder to rotate it.

### 4.6 Domain capture (do this last)
Prerequisites: Restrict organization creation on, domain verified, **SSO enforced**, JIT or SCIM on. Then Security > **Migrate accounts using your domain**.
- **One-way door.** It cannot be reversed.
- 30-day migration window (fixed). At the deadline remaining personal accounts on the domain are deactivated, Pro/Max subscriptions are cancelled with a prorated refund, and people who did not choose get a fresh Enterprise account.
- Anyone not in the IdP is locked out. Export the CSV and reconcile before confirming.
- Do not run SCIM and JIT simultaneously (SCIM wins).
- App Store subscribers must cancel through Apple themselves.

### 4.7 Other org settings to set now
| Setting | Location | Why |
|---|---|---|
| **Restrict verified-domain connectors to your enterprise** | Org settings > Connectors > Connector domain restriction | Only Claude accounts in your Enterprise org can connect supported connectors using an email on your verified domains. Stops a personal Claude account from connecting your work Microsoft 365 account. One-directional: Enterprise members can still connect personal services. Reversible (unlike domain capture) ([source](https://support.claude.com/en/articles/15402193-restrict-verified-domain-connectors-to-your-enterprise)) |
| **Limit Claude Desktop to allowed organizations (shadow IT)** `[BETA]` | Org settings > Organization and access > Security | Blocks personal accounts and other orgs in Desktop after a member signs in. Not permanent: ends after 30 days without using your org on that computer, and anyone using the computer can remove it. Use the MDM key below for a hard block |
| Record the **Organization ID** | Settings > Account, or Org settings > Organization (bottom) | Needed for the network header and `forceLoginOrgUUID` |

---

## 5. Phase 2: Entra controls for the Claude apps

### 5.1 Restrict the Claude SAML app to the group
1. Entra > Enterprise apps > *Claude* > **Properties** > **Assignment required? = Yes**.
2. **Users and groups** > add `SG-Entra-AUG-CLAUDE-Prod-Users` and the Admins group.
3. Grant tenant-wide admin consent where needed; Learn notes apps requiring assignment do not allow user consent.

**Flag, ambiguity for human review:**
- Anthropic's Entra page says "only assigned people and groups will be provisioned and allowed to SSO" but never tells you to set Assignment required. Learn says the setting applies to SAML apps, and one Learn scenario page says it is on by default for SAML apps. **Confirm the value on your app** rather than assuming either.
- **Global Administrators bypass user assignment** per [Learn](https://learn.microsoft.com/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users#update-the-app-to-require-user-assignment). A Microsoft Q&A answer reports other admin roles also bypass it in testing; that is community-level evidence, not documentation. Mitigate with CA (below) and Claude-side SSO enforcement.

### 5.2 Conditional Access
Report-only first, break-glass excluded.

| Policy | Target | Grant / session |
|---|---|---|
| `IAC - APP - GRANT - Claude-RequireCompliantDeviceMFA` | Claude SAML app; users = Claude group | Require authentication strength (MFA) + compliant device. Applies at **sign-in**; test how long existing Claude sessions persist `[UNVERIFIED]` |
| `IAC - APP - GRANT - ClaudeM365Connector-RequireCompliantDevice` | Both "M365 MCP ... for Claude" apps | Same grant. Anthropic confirms the connector supports group scoping, MFA, device compliance, and network restrictions |

CA does not see personal Claude logins (they never reach Entra). It governs the Enterprise path only.

### 5.3 Microsoft 365 connector (separate from the add-ins)
Source: [Set up the M365 connector](https://support.claude.com/en/articles/12542951-set-up-the-microsoft-365-connector), [security guide](https://support.claude.com/en/articles/12684923-microsoft-365-connector-security-guide)
1. Claude org Owner enables the connector (Org settings > Connectors).
2. Entra Global Admin grants tenant consent (via Claude's connect flow or the manual admin-consent URLs in Anthropic's article).
3. **Set Assignment required = Yes on BOTH enterprise apps:** *M365 MCP Server for Claude* and *M365 MCP Client for Claude*, then assign the Claude group.
4. Turn on **Restrict verified-domain connectors to your enterprise** (section 4.7).
5. Optionally revoke Graph permissions you do not want (Enterprise app > Permissions > Admin consent). Permissions are delegated and read-only by default; the connector searches the whole tenant with the user's own rights (site-level scoping unsupported).

The connector is available on **all** Claude plans including Free, and requires a work Entra tenant (personal Microsoft accounts cannot connect). Steps 3 and 4 matter: without them, a personal Claude account could connect to your tenant if the user has a work account.

---

## 6. Phase 3: Claude add-ins for Excel, PowerPoint, Word, Outlook (M365 admin center)

Sources: [Anthropic overview](https://claude.com/docs/office-agents/overview.md), [Outlook admin steps](https://claude.com/docs/office-agents/outlook.md), [Learn: deploy add-ins](https://learn.microsoft.com/microsoft-365/admin/manage/manage-deployment-of-add-ins?view=o365-worldwide), [Centralized deployment FAQ](https://learn.microsoft.com/microsoft-365/admin/manage/centralized-deployment-faq?view=o365-worldwide)

| Add-in | Status |
|---|---|
| Excel, PowerPoint, Word | `[GA]` since May 7, 2026 (Anthropic announcement) |
| Outlook | `[BETA]` public beta; separate AppSource listing; not included in Enterprise audit logs, included in Compliance API (public beta) |

### 6.1 Deploy
1. M365 admin center > Settings > Org settings > **User owned apps and services** > "Let users access the Office Store" (needed for the store-based path; see 6.2).
2. Settings > **Integrated apps** > find the listing (Excel/PowerPoint/Word = one listing; Outlook = separate) > **Deploy** to `SG-Entra-AUG-CLAUDE-Prod-Users` (or Pilot first).
3. Allow up to 24 hours for new deployments and up to 72 hours for changes/updates to appear.
4. If your org blocks the Store: upload the manifest (`https://pivot.claude.ai/manifest-outlook.xml` for Outlook) via Integrated apps > Upload custom apps > Office Add-in.
5. **Outlook only:** a Global Admin must grant Graph consent once (permissions `Mail.ReadWrite`, `Calendars.Read`, `User.Read`, `offline_access`; the consent URL with client ID `c2995f31-11e7-4882-b7a7-ef9def0a0266` is in Anthropic's Outlook page). Alternative: register your own **single-tenant** Entra app and add its client ID to the manifest so approval and CA live entirely in your tenant. The add-in never requests `Mail.Send`.
6. **PIM caveat (Outlook doc):** the Integrated apps page does not recognize PIM-activated roles (Microsoft tracking ID 11126536); deploy from an account with the role permanently active.

### 6.2 What this does and does NOT control
- Assignment scopes **who sees the add-in**, not **which Claude account they sign in with**. Users sign in to the add-in with a Claude account; Pro/Max accounts are eligible plans, so a personal Claude account can sign in unless blocked elsewhere. No Entra app was identified for Excel/Word/PowerPoint in the sources reviewed, so Entra group assignment cannot gate them. `[Gap]`
- Enforcement for add-ins is therefore the **network header** (section 8), since the add-in host is `pivot.claude.ai` and sign-in uses `claude.ai` and `api.anthropic.com` ([network table](https://support.claude.com/en/articles/13945233)). Whether Anthropic's tenant-restriction doc explicitly covers the add-in surface is **not stated** (it lists web, desktop/app, API key, OAuth). `[UNVERIFIED for add-ins, test: sign in to the add-in with a personal account on a GSA-protected device]`
- Users can self-install from AppSource unless the Store is blocked. Disabling "Let users access the Office Store" tightens that, but Anthropic warns admin-deployed add-ins may then not appear; the fix is the manifest upload path. Learn also notes the Marketplace toggle applies to all apps **except Outlook**.

### 6.3 Alternative: no Claude accounts at all
The add-ins can route through Amazon Bedrock, Vertex AI, Azure AI Foundry, or an LLM gateway, in which case **users do not need Claude accounts** ([third-party platforms](https://support.claude.com/en/articles/13945233)). That removes the personal-account question for the add-ins but is a different product path (no Claude Enterprise seat, different usage tracking and audit). Present it as a design choice, not a default.

Out of scope: Claude models inside Microsoft 365 Copilot (separate Microsoft-managed path).

---

## 7. Phase 4: Client controls

### 7.1 Claude Desktop (macOS and Windows) `[GA]`
Source: [Enterprise configuration](https://support.claude.com/en/articles/12622667-enterprise-configuration-for-claude-desktop), [Deploy for macOS](https://support.claude.com/en/articles/12611117-deploy-claude-desktop-for-macos)

Hard-block personal and foreign orgs before anyone signs in with `forceLoginOrgUUID`:
- **macOS:** configuration profile for preference domain `com.anthropic.claudefordesktop`, key `forceLoginOrgUUID`. A single UUID string also pre-selects the org at login. Multiple orgs: a **string** containing JSON, for example `["<uuid-1>","<uuid-2>"]`.
- **Windows:** `HKLM\SOFTWARE\Policies\Claude`, value `forceLoginOrgUUID` as **REG_SZ** (not REG_MULTI_SZ). Machine-level beats user-level.

```powershell
New-Item -Path 'HKLM:\SOFTWARE\Policies\Claude' -Force
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Claude' -Name forceLoginOrgUUID `
  -PropertyType String -Value '<your-claude-org-uuid>' -Force
```

- Deploy the PKG (macOS, recommended) via Intune; Anthropic names Jamf, Kandji and Intune as supported MDMs. The pages give the domain and key but **no complete sample .mobileconfig**; build the custom profile per standard macOS managed-preferences practice and test. `[UNVERIFIED payload structure]`
- Claude Desktop reads the setting at launch. Verify under **Help > Troubleshooting > Generate Diagnostic Report**.
- Other relevant keys: `isDesktopExtensionEnabled`, `isDesktopExtensionDirectoryEnabled`, `isLocalDevMcpEnabled`, `secureVmFeaturesEnabled` (Cowork), `isClaudeCodeForDesktopEnabled`, `disableAutoUpdates`. Machine policy wins over Organization settings when both set a key, even if less strict.
- `forceLoginOrgUUID` for the **Claude Code CLI** and **Claude in Chrome** was not verified in this pass. `[Gap]`

### 7.2 iOS: Claude for Intune
Source: [Set up Claude for Intune](https://support.claude.com/en/articles/17203415-set-up-claude-for-intune)
- Separate App Store app ("Claude Intune"), **Microsoft sign-in only**, supports Intune app protection and Entra CA. Requires Enterprise plan, iOS/iPadOS 18+, and Anthropic enabling Microsoft sign-in for your domains (ask your Anthropic account team).
- Admin consent (required for every org): `https://login.microsoftonline.com/{tenant}/adminconsent?client_id=bb747f0e-002b-4882-9960-916fe00a2b90`. Confirm "Claude for Intune (Public)" appears under Enterprise applications.
- App protection policy: add bundle ID `com.anthropic.claudeforintune` as a custom app (not yet in Microsoft's protected apps list). Assign to a **user** group and do not limit it to managed devices.
- CA: target **All resources** with *Require app protection policy*. A rule naming only Office 365 or Claude SSO does **not** cover this app.
- Pair with an Intune control that stops users installing the standard Claude app on managed devices `[UNVERIFIED for Claude specifically; see Learn's shadow-AI step 2 for the generic Intune approach]`.
- Android: no equivalent was found in sources reviewed. `[Gap]`

---

## 8. Phase 5: Network enforcement, the control that blocks personal accounts

Sources: [Anthropic Tenant Restrictions](https://support.claude.com/en/articles/13198485-enforce-network-level-access-control-with-tenant-restrictions) | [GSA custom headers](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-custom-headers) | [Web filtering v2](https://learn.microsoft.com/entra/global-secure-access/concept-web-filtering)

### 8.1 How it works
Your network layer injects `anthropic-allowed-org-ids: <your-org-uuid>` on requests to Claude. Anthropic validates it and returns **403** with `tenant_restriction_violation` for any org not listed. Covers web, desktop/app, API key and OAuth token auth, and artifacts including Claude Docs. Limits: up to 10 header lines and 500 UUIDs; the proxy must **overwrite** the header, not append (duplicates return 400). **TLS inspection is required.**

Microsoft's Learn page lists Claude as a built-in example for GSA custom headers, with these FQDNs: `claude.ai`, `*.claude.ai`, `claude.com`, `*.claude.com`, `anthropic.com`, `*.anthropic.com`, `api.anthropic.com`, `*.api.anthropic.com`.

**Flags, for human review:**
1. Anthropic's supported-proxy list names Cato, Cloudflare, Netskope, Palo Alto Prisma Access, Zscaler and "generic HTTPS proxies with header injection". **Microsoft GSA is not named by Anthropic**, although Microsoft documents it. GSA likely falls under "generic" but this is an ambiguity; run the validation in 8.4 before trusting it.
2. Learn says the value is "found in the Anthropic Console organization settings"; Anthropic says Enterprise members find the **Organization ID** under Settings > Account or Organization settings, and Console orgs under Settings > Organization. These are different org types. Include the **Enterprise (claude.ai) org UUID** and, if you use the API, also your **Console org UUID**, comma-separated, no spaces.
3. Status of GSA custom headers and TLS inspection is **not labeled** in the pages fetched. The web filtering v2 `Continue` default action is **[PREVIEW]**. Confirm in your portal.

### 8.2 Build in GSA (portal; Global Secure Access Administrator role)
Prereqs: Internet Access profile enabled and assigned, GSA client on devices, TLS inspection policy with the destinations above set to **Inspect**, root cert trusted on test devices.

1. **Secure > TLS inspection policies:** add a rule for the Claude FQDNs, action **Inspect**.
2. **Secure > Web filtering policies (V2):** create `Claude-Enterprise-Allow`. Add a rule: destinations = Claude FQDNs, **Rule action = Allow**, **Configure custom headers** = `anthropic-allowed-org-ids` : `<org-uuid>[,<console-org-uuid>]`. Set the policy default action to **Continue** `[PREVIEW]` so non-matching traffic falls through to the baseline.
3. **Secure > Security profiles:** create `Claude-Enterprise` and link the V2 policy (only one V2 policy per profile).
4. **Conditional Access:** create a policy targeting `SG-Entra-AUG-CLAUDE-Prod-Users` (exclude break-glass), resource **All internet resources with Global Secure Access**, **Session > Use Global Secure Access security profile** = `Claude-Enterprise`. Name: `IAC - GLOBAL - SESSION - GSA-ClaudeEnterpriseProfile`.
5. **Baseline profile:** add a V2 policy with a **Block** rule for Claude FQDNs. Learn's own example uses this pattern ("Claude override" profile with Allow + `Continue`, baseline with Block). A matching Allow stops V2 evaluation before the baseline, so group members get Allow + header and everyone else is blocked from Claude entirely. The baseline applies to all Internet Access traffic even without a CA link.
6. Allow **60-90 minutes** for a newly applied security profile (token claim); changes to an existing profile take effect near real time. Revoke the test user's sessions to speed testing.

### 8.3 Known limits that affect Claude traffic (verify each in pilot)
- **QUIC is not supported for Internet Access**; disable QUIC in browsers so traffic falls back to TCP.
- **TLS inspection does not support HTTP/2**; most sites fall back to HTTP/1.1, but add a TLS bypass if anything breaks.
- GSA client tunnels **IPv4 only**; set adapters to IPv4 preferred. UDP unsupported.
- macOS client: supported for Internet Access (licensing table). No secure-DNS change needed on macOS (client bypasses it).
- Whether Claude Desktop and Claude Code trust the GSA TLS root (certificate pinning or a custom trust store) is **not documented**. `[UNVERIFIED, test]`
- Traffic in the Microsoft profile cannot also be acquired by the Internet Access profile; keep your existing Microsoft profile and compliant-network work in mind when scoping.

### 8.4 Validation (do before enforcing)
| Test | Expected |
|---|---|
| Group member, GSA client on, signs in to Enterprise Claude in browser | Works |
| Same device, signs in with a personal `@gmail.com` Claude account | **403** `tenant_restriction_violation` |
| Same, in Claude Desktop with the MDM key set | Login blocked by Desktop before the network |
| Same, in the Excel/Word add-in | Blocked `[UNVERIFIED]` |
| Non-member on a GSA device opens claude.ai | Blocked by baseline |
| Device **without** the GSA client | Not covered by this control (state this to stakeholders) |

Check **GSA > Monitor > Traffic logs > Transactions** and add the **Custom Headers** column to confirm injection. Test the Anthropic side directly with your org's API key from a restricted network (curl example in Anthropic's article).

### 8.5 If you use a third-party SSE instead
Create the same header rule in your product (Zscaler Cloud App Control, Netskope Header Insertion, Prisma Access SaaS App Management, Cato Tenant Restriction, Cloudflare Gateway HTTP policy). Remove any client-supplied header first, then set yours.

---

## 9. Phase 6: DFCA / Defender for Cloud Apps and unsanctioned AI

Sources: [Govern discovered apps (MDE)](https://learn.microsoft.com/defender-cloud-apps/mde-govern) | [Govern discovered apps](https://learn.microsoft.com/defender-cloud-apps/governance-discovery) | [Purview shadow-AI step 2](https://learn.microsoft.com/purview/deploymentmodels/depmod-data-leak-shadow-ai-step2) | [GSA + DFCA coexistence](https://learn.microsoft.com/entra/global-secure-access/reference-microsoft-defender-cloud-apps-coexistence)

1. **Prereqs:** Cloud Protection and Network Protection on in Defender for Endpoint; Microsoft Defender Browser Protection add-on in non-Microsoft browsers.
2. Defender portal > Settings > Cloud apps > Cloud discovery > **Microsoft Defender for Endpoint** > **Enforce app access** (up to ~30 min). In Defender XDR > Settings > Endpoints > Advanced features, enable **Custom network indicators**.
3. Cloud apps > Cloud discovery, filter **Category = Generative AI**. Tag **other** AI apps as **Unsanctioned**. **Leave Claude out** (see section 1). Optionally tag Claude **Sanctioned** to keep it visible and to keep discovery policies from auto-unsanctioning it.
4. Review any **app discovery policy** with the governance action "Tag app as unsanctioned": Learn states this *automatically blocks* matching apps, so a category-wide "risky generative AI" policy can sweep in Claude. Exclude Claude via a custom app tag.
5. Scope with **Scoped profiles** (Settings > Cloud apps > Cloud discovery > App tags > Scoped profiles; Include or Exclude MDE device groups) when you need exceptions.
6. Set a **block page URL** (Settings > Cloud apps > Cloud discovery > Defender for Endpoint > Notification URL for blocked apps) pointing at your "approved AI" page.
7. **Latency:** up to **3 hours** from unsanction to enforcement on the device.
8. **Limits:** unmanaged devices and personal networks are not covered by this block (Learn says so). Defender Cloud Apps session policies do **not** apply to AI apps that are not sanctioned Enterprise Apps (per the GSA/DFCA coexistence page).
9. macOS Network Protection coverage for this block was **not confirmed this session**. `[UNVERIFIED]` Check before promising Mac enforcement.

**Optional, test first `[UNVERIFIED]`:** Because Claude Enterprise uses Entra SAML, it may be eligible for Conditional Access App Control session policies (monitor, block download/upload). Learn says SAML interactive SSO apps are supported, but whether Claude is in the DFCA app catalog and whether session proxying breaks Claude was not verified. Learn also says to pick **one** product to own the inline session experience per app.

Other options Learn documents for AI-specific blocking: Entra Internet Access with Adaptive Protection (block elevated-risk users from AI apps), and Intune to block installation of unsanctioned AI apps.

---

## 10. Phase 7: Purview (data side)

Sources: [Endpoint DLP settings](https://learn.microsoft.com/purview/dlp-configure-endpoint-settings) | [Paste to browsers](https://learn.microsoft.com/purview/endpoint-dlp-create-policy-restrict-paste-in-browsers) | [Paste diagnostics](https://learn.microsoft.com/troubleshoot/microsoft-365/purview/data-loss-prevention/diagnose-paste-to-supported-browser-issues) | [Supported AI sites](https://learn.microsoft.com/purview/ai-microsoft-purview-supported-sites)

- **Sensitive service domain groups** (Purview > DLP > Settings > Endpoint DLP settings > Browser and domain restrictions) are required for **Paste to supported browsers**; the flat Service domains list does not drive that action. Keep the global Service domains action at **Block** (Learn warns Allow can cause erratic behavior).
- Paste to browser works only with **Content contains > Sensitive info types** using standard SITs. EDM, trainable classifiers, named entities and credential classifiers do not trigger on paste.
- The built-in **Generative AI websites** group includes `*.claude.ai` and `*.anthropic.com` but, in the list fetched today, **not `*.claude.com`**. It cannot be edited. Because it contains Claude, a policy using it would also affect your sanctioned Enterprise Claude. Build your **own** group of *unsanctioned* AI sites if you want Claude exempt. `[Design decision for human review]`
- **macOS:** Edge, Chrome, Firefox and Safari are natively supported for Endpoint DLP paste without an extension; the Purview Chrome/Firefox extension is **Windows-only**.
- **Mac ceiling for DSPM for AI** (from prior verified notes, 2026-09-30; re-check if stale): browser signal detection is not supported on non-Windows devices, so third-party AI site visibility and the *Risky AI usage* IRM template contribute no browsing signal from Macs. Endpoint DLP device activity still works natively on macOS.
- Promotion path per your DLP convention: `SIM` for about 1 week, then `WARN`, then `BLOCK`. Policy changes can take about 60 minutes to reach devices; group membership changes up to about 24 hours.
- Purview DLP for Microsoft 365 Copilot is a Copilot-only location; it does **not** cover Claude.

---

## 11. Monitoring and audit

| Source | What to watch |
|---|---|
| Entra sign-in logs (Claude SAML app, M365 MCP apps) | Success/failure by user; users not assigned |
| GSA traffic logs (Custom Headers column) | Header injected on Claude transactions; baseline block hits |
| DFCA Cloud Discovery | New Generative AI apps by volume and users |
| Claude admin console | Seat/usage analytics, Enterprise Analytics API, **Compliance API** (also covers Outlook add-in sessions, public beta) |
| Add-in telemetry | Custom OpenTelemetry collector (Enterprise only); spans include prompt and document content, so scope access and retention accordingly. Collector must allow CORS from `https://pivot.claude.ai` |
| GSA alerts | Alert if the traffic profile, CA signaling, or custom header rule is disabled (Learn's operate guidance) |

---

## 12. Recommended rollout order

1. Pilot group and break-glass exclusions ready. Everything below is report-only/simulation first where available.
2. Claude: verify domain(s), turn on Restrict organization creation, record Org ID.
3. Entra: create Claude SAML app, set Assignment required, assign the Pilot group. Configure SSO (do **not** require it yet). Test sign-in.
4. Claude: SCIM + group mappings (review the preview; ensure admins are mapped).
5. Claude: Require SSO. Verify a pilot user and an Owner can still sign in.
6. M365 connector: consent, Assignment required on both apps, Restrict verified-domain connectors.
7. Add-ins: deploy to the Pilot group; Outlook Graph consent.
8. Clients: `forceLoginOrgUUID` via Intune; Claude for Intune (iOS) if in scope.
9. GSA: TLS inspection, header rule, security profile, CA (pilot), baseline block. Validate with section 8.4.
10. DFCA: unsanction other AI apps (not Claude); Purview DLP in SIM.
11. Swap Pilot group for Prod group everywhere. Switch CA from report-only to on.
12. **Last:** domain capture, after reconciling the personal-account CSV against the IdP.

**Rollback:** CA policies to disabled; remove the GSA security profile link; clear `forceLoginOrgUUID`; toggle Require SSO off (Manage SSO > Reset connection ends all sessions). **Domain capture cannot be rolled back.**

---

## 13. Open items and gaps (not verified in this guide)

- Add-in sign-in behavior under the tenant-restriction header (is the add-in surface covered?).
- Claude Code CLI and Claude in Chrome organization enforcement keys.
- Android Claude with Intune MAM; blocking the standard iOS Claude app via Intune.
- Whether Claude is in the DFCA catalog, how Defender scopes the Claude entry, and macOS Network Protection behavior for unsanctioned-app blocks.
- DFCA/Cloud Discovery licensing tiers (E3, Business Premium, E5, standalone).
- GA/preview labels for GSA custom headers and TLS inspection.
- Whether GSA client TLS inspection works cleanly with Claude Desktop and Claude Code.
- Complete macOS `.mobileconfig` for `com.anthropic.claudefordesktop`.
- Entra "Assignment required" default state on the Claude SAML app and which admin roles bypass it.
- Existing Claude session lifetime vs CA re-evaluation.

---

## 14. Sources

**Anthropic**
- [Set up SSO](https://support.claude.com/en/articles/13132885-set-up-single-sign-on-sso)
- [Microsoft Entra ID SSO setup](https://support.claude.com/en/articles/13917889-microsoft-entra-id-sso-setup)
- [Set up JIT or SCIM provisioning](https://support.claude.com/en/articles/13133195-set-up-jit-or-scim-provisioning)
- [Claim and migrate accounts on your domain](https://support.claude.com/en/articles/14625619-claim-and-migrate-accounts-on-your-domain)
- [Restrict verified-domain connectors](https://support.claude.com/en/articles/15402193-restrict-verified-domain-connectors-to-your-enterprise)
- [Tenant Restrictions](https://support.claude.com/en/articles/13198485-enforce-network-level-access-control-with-tenant-restrictions)
- [Enterprise configuration for Claude Desktop](https://support.claude.com/en/articles/12622667-enterprise-configuration-for-claude-desktop)
- [Deploy Claude Desktop for macOS](https://support.claude.com/en/articles/12611117-deploy-claude-desktop-for-macos)
- [Set up Claude for Intune](https://support.claude.com/en/articles/17203415-set-up-claude-for-intune)
- [Microsoft 365 connector setup](https://support.claude.com/en/articles/12542951-set-up-the-microsoft-365-connector) and [security guide](https://support.claude.com/en/articles/12684923-microsoft-365-connector-security-guide)
- [Claude for M365 overview](https://claude.com/docs/office-agents/overview.md), [Outlook](https://claude.com/docs/office-agents/outlook.md), [Security and audit](https://claude.com/docs/office-agents/enterprise-readiness.md), [Third-party platforms and network table](https://support.claude.com/en/articles/13945233)

**Microsoft Learn**
- [Restrict an Entra app to a set of users](https://learn.microsoft.com/entra/identity-platform/howto-restrict-your-app-to-a-set-of-users)
- [Manage users and groups assignment](https://learn.microsoft.com/entra/identity/enterprise-apps/assign-user-or-group-access-portal)
- [Deploy Office Add-ins in the admin center](https://learn.microsoft.com/microsoft-365/admin/manage/manage-deployment-of-add-ins?view=o365-worldwide) and [Centralized deployment FAQ](https://learn.microsoft.com/microsoft-365/admin/manage/centralized-deployment-faq?view=o365-worldwide)
- [GSA custom headers](https://learn.microsoft.com/entra/global-secure-access/how-to-configure-custom-headers)
- [Web filtering in GSA (V2)](https://learn.microsoft.com/entra/global-secure-access/concept-web-filtering)
- [GSA known limitations](https://learn.microsoft.com/entra/global-secure-access/reference-current-known-limitations)
- [GSA licensing overview](https://learn.microsoft.com/entra/global-secure-access/overview-what-is-global-secure-access#licensing-overview)
- [GSA and DFCA coexistence](https://learn.microsoft.com/entra/global-secure-access/reference-microsoft-defender-cloud-apps-coexistence)
- [Govern discovered apps using MDE](https://learn.microsoft.com/defender-cloud-apps/mde-govern)
- [Purview: Block access to unsanctioned AI apps](https://learn.microsoft.com/purview/deploymentmodels/depmod-data-leak-shadow-ai-step2)
- [Endpoint DLP settings](https://learn.microsoft.com/purview/dlp-configure-endpoint-settings), [Paste to browsers](https://learn.microsoft.com/purview/endpoint-dlp-create-policy-restrict-paste-in-browsers), [Supported AI sites](https://learn.microsoft.com/purview/ai-microsoft-purview-supported-sites)
