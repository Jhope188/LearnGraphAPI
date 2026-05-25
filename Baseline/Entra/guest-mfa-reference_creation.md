# External User MFA — Where & How It's Satisfied

> Source: Microsoft Learn — Authentication and Conditional Access for External ID (verified May 2026)
> Portal labels aligned to: Entra Admin Center → Conditional Access → Users → Guest or external users

---

## How Each User Type Is Created

Understanding how each type is created is critical — it determines how the account is managed, where authentication happens, and what MFA controls apply.

### B2B Collaboration Guest — `b2bCollaborationGuest` (standard invite)

**How to create:** Send an invitation via the portal or Graph API.

1. **Entra Admin Center → Users → All Users → New user → Invite external user**
2. Enter the external user's email address, add an optional message, send
3. User receives an email invitation and redeems it — at redemption, Entra creates the user object in your directory with `UserType: Guest`

The resulting account has a UPN in the format `user_domain.com#EXT#@yourtenant.onmicrosoft.com`. Authentication is handled by the **user's home identity provider** (their Entra tenant, Microsoft Account, Google, OTP etc.) — your tenant holds the guest object but not the credentials.

This is the most common external user type — any externally invited user lands here by default.

---

### Local Guest User — `internalGuest` (manually created, no invite)

**How to create:** Create the account directly in your tenant with `UserType` set to `Guest`. No invitation is sent — no external identity provider is involved.

1. **Entra Admin Center → Users → All Users → New user → Create new user**
2. Fill in the username and password (the account is fully managed in your directory)
3. After creation, **manually set `UserType` to `Guest`** — either via the portal (User profile → Edit → User type → Guest) or via Graph API / PowerShell:

```powershell
# PowerShell
Update-MgUser -UserId "<objectId>" -UserType "Guest"
```

```http
# Graph API
PATCH /users/{id}
{ "userType": "Guest" }
```

The resulting account has a standard UPN (e.g. `supplier@yourtenant.onmicrosoft.com`), a **password managed in your directory**, and authenticates entirely against your tenant. There is no home tenant — your tenant IS the home tenant.

**Why this exists:** This is a legacy pattern predating B2B collaboration. Organisations used to create internal accounts for suppliers, contractors, and partners and mark them as `Guest` to signal they were external collaborators. Microsoft now recommends migrating these to B2B collaboration so the partner manages their own credentials and account lifecycle.

**Key distinction from B2B guest:**

| | Local Guest (`internalGuest`) | B2B Collaboration Guest (`b2bCollaborationGuest`) |
|---|---|---|
| Account created by | Your tenant admin (manual) | Invitation redemption |
| Credentials managed by | Your tenant | External user's identity provider |
| UPN format | `user@yourtenant.onmicrosoft.com` | `user_domain.com#EXT#@yourtenant.onmicrosoft.com` |
| Password reset | Your tenant admins | External IdP manages |
| MFA registration | Your tenant | Your tenant (resource tenant enforces) |
| Auth strength in CA | ✅ Full support | ⚠️ Only if Entra-backed |

---

## Portal Checkbox to Graph API Mapping

When you select **"Guest or external users"** in a CA policy, the Entra portal shows six checkboxes. This table maps each portal label to its Graph API value and CA type name used throughout this document.

| Portal Checkbox Label | Graph API value (`guestOrExternalUserTypes`) | Notes |
|---|---|---|
| ☑ **B2B collaboration guest users** | `b2bCollaborationGuest` | ⚠️ Heterogeneous — contains both Entra-backed AND non-Entra guests (Google, OTP, SAML). Use basic `mfa` only. |
| ☑ **B2B collaboration member users** | `b2bCollaborationMember` | Entra-backed only. Auth strength safe. |
| ☑ **B2B direct connect users** | `b2bDirectConnectUser` | Entra-backed only. Auth strength safe. Requires inbound trust — else blocked. |
| ☑ **Local guest users** | `internalGuest` | Lives in your directory. Auth strength safe. |
| ☑ **Service provider users** | `serviceProvider` | GDAP/CSP partners. MFA always from home tenant. Auth strength applicable. |
| ☑ **Other external users** | `otherExternalUser` | Non-Entra IdP only. Auth strength NOT supported. Basic `mfa` only. |

---

## Recommended Two-Policy Split

The six types cannot all share the same grant control because `b2bCollaborationGuest` and `otherExternalUser` cannot safely use authentication strength — applying it blocks them silently instead of prompting for MFA.

### Policy 1 — `IAC - GLOBAL - GRANT - MFA - B2B-Guests` (Authentication Strength)

**Portal selections — Guest or external users — Include:**

| Checkbox | Select? | Reason |
|---|---|---|
| B2B collaboration guest users | ☐ **No** | Heterogeneous — non-Entra guests would be blocked by auth strength |
| B2B collaboration member users | ☑ **Yes** | Entra-backed only, auth strength safe |
| B2B direct connect users | ☑ **Yes** | Entra-backed only — confirm inbound trust configured first |
| Local guest users | ☑ **Yes** | Local directory account, full method set |
| Service provider users | ☑ **Yes** | GDAP home tenant MFA auto-trusted |
| Other external users | ☐ **No** | Non-Entra only — auth strength not supported |

**Grant control:** Authentication strength → `Modern MFA + TAP` (WHfB, FIDO2, CBA, TAP)

> ✅ This matches the screenshot configuration — 5 selected with **B2B collaboration guest users unchecked**. That is the correct selection for this policy.

---

### Policy 2 — `IAC - GLOBAL - GRANT - MFA - Mixed-Guests` (Basic MFA)

**Portal selections — Guest or external users — Include:**

| Checkbox | Select? | Reason |
|---|---|---|
| B2B collaboration guest users | ☑ **Yes** | Mixed population — basic MFA works for both Entra and non-Entra guests |
| B2B collaboration member users | ☐ **No** | Covered by Policy 1 |
| B2B direct connect users | ☐ **No** | Covered by Policy 1 |
| Local guest users | ☐ **No** | Covered by Policy 1 |
| Service provider users | ☐ **No** | Covered by Policy 1 |
| Other external users | ☑ **Yes** | Non-Entra only — basic MFA is the only supported control |

**Grant control:** Basic `mfa` (NOT authentication strength)

---

## Per-Type Reference

---

### B2B collaboration guest users — `b2bCollaborationGuest`

- **Portal label:** B2B collaboration guest users
- **UserType in directory:** Guest
- **Who:** Any user invited or redeemed via B2B collaboration. Includes **both** Entra-backed guests (external Entra tenant) and non-Entra guests (Google, Facebook, email OTP, SAML/WS-Fed). CA cannot distinguish between them.
- **MFA enforced by:** Either (resource tenant default; home tenant if inbound MFA trust configured) — for Entra-backed only. Non-Entra always uses resource tenant.

| Where MFA completes | Supported methods |
|---|---|
| **Resource tenant** | Authenticator push, OATH software token, SMS, Voice |
| **Home tenant** (trust required, Entra-backed only) | Authenticator push, Authenticator phone sign-in, OATH software, OATH hardware, FIDO2, Windows Hello for Business, CBA, SMS, Voice |

**Authentication strength support:** ❌ NOT safe for mixed populations. Auth strength will block non-Entra guests instead of prompting them.
**Assign to:** Policy 2 — basic `mfa`

---

### B2B collaboration member users — `b2bCollaborationMember`

- **Portal label:** B2B collaboration member users
- **UserType in directory:** Member
- **Who:** External Entra users with member-level access. Always Entra-backed — no non-Entra variant.
- **MFA enforced by:** Either (resource tenant default; home tenant if inbound MFA trust configured)

| Where MFA completes | Supported methods |
|---|---|
| **Resource tenant** | Authenticator push, OATH software token, SMS, Voice |
| **Home tenant** (trust required) | Authenticator push, Authenticator phone sign-in, OATH software, OATH hardware, FIDO2, Windows Hello for Business, CBA, SMS, Voice |

**Authentication strength support:** ✅ Supported — Entra-backed only, no heterogeneity concern.
**Assign to:** Policy 1 — auth strength

---

### B2B direct connect users — `b2bDirectConnectUser`

- **Portal label:** B2B direct connect users
- **UserType in directory:** No user object — no presence in your directory
- **Who:** External Entra users accessing Teams Connect shared channels (only current use case)
- **MFA enforced by:** Home tenant — **MANDATORY**. Cannot complete MFA in resource tenant. Without inbound trust configured, user is **blocked entirely** — no prompt, no fallback.

| Where MFA completes | Supported methods |
|---|---|
| **Resource tenant** | ❌ Not possible — no user object in resource directory |
| **Home tenant** (trust REQUIRED) | Authenticator push, Authenticator phone sign-in, OATH software, OATH hardware, FIDO2, Windows Hello for Business, CBA, SMS, Voice |

**Authentication strength support:** ✅ Supported — home tenant methods only. Ensure allowed combinations include methods the partner tenant has enabled.
**Prerequisite before enabling:** Confirm inbound cross-tenant MFA trust is configured at **Entra ID → External Identities → Cross-tenant access settings → Inbound trust** for each partner tenant using Teams Connect.
**Assign to:** Policy 1 — auth strength

---

### Local guest users — `internalGuest`

- **Portal label:** Local guest users
- **UserType in directory:** Guest — but credentials live in your own directory
- **Who:** Legacy pre-B2B pattern. Account exists and is managed entirely in your tenant. No external home tenant.
- **MFA enforced by:** Resource tenant — **always**

| Where MFA completes | Supported methods |
|---|---|
| **Resource tenant** | All methods your tenant supports — full set including FIDO2, WHfB, CBA |
| **Home tenant** | ❌ Not applicable — no external home tenant |

**Authentication strength support:** ✅ Fully supported — account is local, no cross-tenant trust needed.
**Assign to:** Policy 1 — auth strength

---

### Service provider users — `serviceProvider`

- **Portal label:** Service provider users
- **UserType in directory:** External — isServiceProvider = true
- **Who:** GDAP/CSP partner technicians administering your tenant
- **MFA enforced by:** Home tenant — always required. However, "always trusted" only applies to **native Microsoft Entra MFA claims**. Non-native methods (DUO, RSA, Silverfort via Custom Controls) are NOT trusted cross-tenant and will block the user.

| Where MFA completes | Supported methods |
|---|---|
| **Resource tenant** | ❌ Not applicable — resource tenant MFA registration not supported for GDAP users |
| **Home tenant** (auto-trusted for native Entra MFA only) | SMS, Voice, Authenticator push, Authenticator phone sign-in, OATH software/hardware, FIDO2, WHfB, CBA — native Entra methods only |

**Authentication strength support:** ⚠️ Applicable in theory — but this is the most common source of GDAP partner blockage in practice. See warning below.

**Assign to:** Policy 1 (auth strength) — **only if** partner tenants use native Entra MFA methods. If any partner uses DUO or another Custom Control EAM, exclude `serviceProvider` entirely or use basic `mfa` grant.

> ⚠️ **Why GDAP partners get blocked — verified from MS Learn:**
>
> **1. Custom Controls (DUO, RSA, Silverfort) are not trusted cross-tenant.**
> MS Learn explicitly states: *"Custom Controls with Conditional Access are not supported for cross-tenant trusts."* If a partner's home tenant uses DUO or another External Authentication Method via Custom Controls, their MFA claim cannot be passed across to the resource tenant. The user completes MFA in their home tenant but the resource tenant CA policy cannot verify the Custom Control claim — result: **blocked**.
>
> **2. Authentication strength method mismatch blocks access.**
> If the resource tenant CA policy requires `Modern MFA + TAP` (WHfB, FIDO2, CBA, TAP) and the partner's technicians don't have any of those registered in their home tenant, they are blocked — even though home tenant MFA is technically "trusted."
>
> **3. The "always trusted" rule only applies to native Entra MFA claims.**
> Cross-tenant trust evaluates whether the home tenant MFA claim satisfies the resource tenant's CA policy. The claim must come from a native Entra method. Custom Controls, federated MFA, and non-native methods do not produce claims that can be evaluated cross-tenant.

> ✅ **Recommended approach for MSP/CSP tenants:**
> Exclude `serviceProvider` from CA policies that enforce authentication strength or complex grant controls. Per the GDAP FAQ on MS Learn: *"Customers can exclude CSPs from conditional access policy so that partners can transition to GDAP without getting blocked."* Use `excludeGuestsOrExternalUsers` with `guestOrExternalUserTypes: "serviceProvider"` scoped to your known partner tenant IDs — not `AllExternalTenants` — to maintain least-privilege exclusions.

> ℹ️ GDAP home tenant MFA is auto-trusted by Microsoft — no cross-tenant trust settings configuration is required. But auto-trust only applies to native Entra MFA methods. It does not bypass CA policy grant control requirements.

---

### Other external users — `otherExternalUser`

- **Portal label:** Other external users
- **UserType in directory:** External — does not fit any other category
- **Who:** External users not covered by the above types — typically non-Entra IdP users without a formal B2B invitation
- **MFA enforced by:** Resource tenant — **always**. No cross-tenant trust available.

| Where MFA completes | Supported methods |
|---|---|
| **Resource tenant** | Authenticator push, OATH software token, SMS, Voice |
| **Home tenant** | ❌ Not applicable |

**Authentication strength support:** ❌ NOT supported. Must use basic `mfa` grant control. Authentication strength will block these users.
**Assign to:** Policy 2 — basic `mfa`

---

## Authentication Strength — Accepted Methods by Location

Per Microsoft Learn (Authentication strength MFA methods for external users):

| Authentication method | Home tenant (trusted) | Resource tenant |
|---|---|---|
| SMS as second factor | ✅ | ✅ |
| Voice call | ✅ | ✅ |
| Microsoft Authenticator push notification | ✅ | ✅ |
| Microsoft Authenticator phone sign-in | ✅ | ❌ |
| OATH software token | ✅ | ✅ |
| OATH hardware token | ✅ | ❌ |
| FIDO2 security key | ✅ | ❌ |
| Windows Hello for Business | ✅ | ❌ |
| Certificate-based authentication (CBA) | ✅ | ❌ |

> FIDO2, WHfB, OATH hardware, and CBA are **home tenant only**. To enforce phishing-resistant methods, inbound MFA trust must be configured so the home tenant path is used.

---

## Quick Decision Reference

| Portal checkbox | Auth Strength safe? | Basic MFA safe? | Assign to |
|---|---|---|---|
| B2B collaboration guest users | ⚠️ Mixed — NOT safe | ✅ Yes | Policy 2 |
| B2B collaboration member users | ✅ Yes | ✅ Yes | Policy 1 |
| B2B direct connect users | ✅ Yes (home tenant) | ✅ Yes | Policy 1 |
| Local guest users | ✅ Yes (full set) | ✅ Yes | Policy 1 |
| Service provider users | ⚠️ Only if partner uses native Entra MFA — DUO/Custom Controls will block | ✅ Yes | Policy 1 or **exclude entirely** if partners use DUO/EAM |
| Other external users | ❌ NOT supported | ✅ Yes | Policy 2 |

> ⚠️ **MSP/CSP tenants:** If any of your GDAP partners use DUO, RSA, Silverfort, or any other Custom Control / External Authentication Method in their home tenant, those users will be blocked by CA policies regardless of grant control type. Custom Controls are not supported for cross-tenant trust evaluation (MS Learn verified). The safest approach is to exclude `serviceProvider` from CA policies entirely and scope the exclusion to specific known partner tenant IDs.

---

## References

- [Authentication and Conditional Access for External ID](https://learn.microsoft.com/entra/external-id/authentication-conditional-access)
- [Require authentication strength for external users](https://learn.microsoft.com/entra/identity/conditional-access/policy-guests-mfa-strength)
- [Manage cross-tenant access settings for B2B collaboration](https://learn.microsoft.com/entra/external-id/cross-tenant-access-settings-b2b-collaboration)
- [B2B direct connect overview](https://learn.microsoft.com/entra/external-id/b2b-direct-connect-overview)
- [Microsoft Entra B2B best practices](https://learn.microsoft.com/entra/external-id/b2b-fundamentals)
