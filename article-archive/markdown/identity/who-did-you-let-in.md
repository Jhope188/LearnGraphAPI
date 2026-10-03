---
title: "Who Did You Let In?"
description: "Six external user types, one common CA mistake that silently blocks guests instead of prompting for MFA, and the stale-guest lifecycle problem nobody owns."
series: "identity"
published: "2026-06-09"
canonical_url: "https://conditionalaccess.tech/articles/identity/who-did-you-let-in.html"
source: "catech-branded/identity/who-did-you-let-in.html"
---
# Who Did You Let In?

*Identity Security Series — Part 4 of 5*

Guest identity in Microsoft Entra is more complicated than most tenants realize. The problem isn't getting guests in. It's knowing who they actually are, whether you still trust them, and whether anyone is responsible for showing them the door.

Entra External ID · June 9, 2026 · 10 min read

Think about the different people who show up at your front door and how differently you treat each one. Your best friend walks in without knocking. A contractor arrives in a marked van with a work order. A stranger knocks and you look through the peephole before deciding. You already make risk-based trust decisions every single day.

The problem is most Entra tenants don't. Once a guest account lands in the directory, it's often treated the same regardless of who they are, where they came from, how strong their home tenant's security posture actually is, or whether they should still have access at all.

> "Getting guests in is easy. Knowing what you're actually trusting when you let them in is the part most admins skip."

## 01. The Three Guest Personas

Before any configuration discussion, the trust model needs to be right. Guest accounts in Entra map directly to the kind of risk decisions you make at your front door every day.

*Trusted Partner*

🤝 **Your Best Friend**

Known relationship. Strong security posture on their side. You've configured explicit inbound trust because you've verified what they enforce at home.

B2B Collaboration Member · B2B Direct Connect

*Credential-Based Trust*

🚐 **The Contractor**

You let them in because of what they present. You're trusting the credential, not the person. And you don't know what's inside the van.

B2B Collaboration Guest · Service Provider (GDAP)

*No Prior Trust*

❓ **The Stranger**

No organizational backing. No home tenant to trust. Personal email, OTP verification only. Maximum scrutiny required before anything.

Other External Users · OTP Guests

The challenge is that Entra surfaces **six distinct external user types**, and they behave fundamentally differently in how they authenticate, where MFA completes, and what CA policy controls are safe to apply. Most tenants treat all six identically. That's where the gaps start.

## 02. Not All Guests Are the Same

When you configure a Conditional Access policy and select "Guest or external users," the portal gives you six checkboxes. Most admins check all of them and move on. That's a mistake. The populations behind those checkboxes behave fundamentally differently, and applying the wrong grant control **silently blocks users instead of prompting them for MFA**.

Entra Guest Types — CA Policy Reference

| Portal Checkbox Label | Graph API Value | Auth Strength Safe? | Notes |
| --- | --- | --- | --- |
| **B2B collaboration guest users** | b2bCollaborationGuest | ⚠ Mixed | Heterogeneous — contains both Entra-backed AND non-Entra guests (Google, OTP, SAML). Use basic mfa only. |
| **B2B collaboration member users** | b2bCollaborationMember | ✓ Safe | Entra-backed only. Auth strength safe. |
| **B2B direct connect users** | b2bDirectConnectUser | ✓ Safe | Entra-backed only. Auth strength safe. Requires inbound trust configured — else blocked entirely, no prompt, no fallback. |
| **Local guest users** | internalGuest | ✓ Safe | Lives in your directory. Credentials managed by your tenant. Full auth strength support. |
| **Service provider users** | serviceProvider | ⚠ Conditional | GDAP/CSP partners. MFA always from home tenant. Auth strength applicable — but only if partner uses native Entra MFA. DUO/Custom Controls will block. |
| **Other external users** | otherExternalUser | ✗ Not Supported | Non-Entra IdP only. Auth strength NOT supported. Basic mfa only. |

## 03. The Credential Trust Problem

This is where the contractor analogy gets sharp. When you enable **Trust MFA from home tenant** in Cross-Tenant Access Settings, you're not just trusting the person. You're trusting the entire security posture of the tenant that issued their credential. The van looks right. The uniform looks right. But you don't know what's inside.

✅

**What you think you're trusting**Partner completed MFA. Their claim passes cross-tenant. User gets seamless access.

⚠️

**What you're actually trusting**Their tenant's MFA enforcement. Which may allow SMS. Which may be inconsistently applied across their user population.

🚫

**What breaks silently**FIDO2, WHfB, and CBA are home-tenant-only methods for external users. You cannot enforce phishing-resistant MFA from the resource tenant side. Full stop.

> 🛑 **Critical — Custom Controls Gap:** **Custom Controls are not trusted cross-tenant.** If a partner's home tenant uses DUO, RSA, or Silverfort via Custom Controls, their MFA claim cannot pass to the resource tenant. The user completes MFA at home and still gets blocked at your door. No prompt, no meaningful error message. This is the most common source of GDAP access failures in MSP environments and almost nobody plans for it in advance.

## 04. The Two-Policy Reality

Most tenants run one guest CA policy. The right answer is two. Because b2bCollaborationGuest is a mixed population — Entra-backed AND non-Entra guests all land in the same bucket — applying authentication strength to it silently blocks non-Entra guests instead of prompting them for MFA.

Policy 1 — Entra-Backed

Authentication Strength

- B2B collaboration member users
- B2B direct connect users
- Local guest users
- Service provider users *

Grant: Modern MFA + TAP (WHfB, FIDO2, CBA, TAP)

Policy 2 — Mixed Population

Basic MFA Only

- B2B collaboration guest users
- Other external users

Grant: Basic mfa — NOT authentication strength

> ⚠️ **MSP / CSP Environments:** If any of your GDAP partners use DUO, RSA, Silverfort, or any Custom Controls MFA in their home tenant, exclude serviceProvider from authentication strength policies entirely. Scope the exclusion to specific known partner tenant IDs, not AllExternalTenants. This is the least-privilege approach and the one Microsoft documents in the GDAP FAQ.

## 05. The Lifecycle Problem

Your best friend still has a key to your house from a project three years ago. You forgot they had it. They forgot they had it. But technically, they could still walk in.

This is the stale guest problem, and it exists in almost every tenant. The project ended, the contract finished, the partnership went quiet — but the accounts stayed. No one owns the offboarding. Nobody is watching the door after the visit ends.

The questions most organizations cannot answer: Who invited this guest? Does that person still work here? Is there a process for cleanup when the relationship ends? In most tenants, at least one of those answers is unknown.

> ℹ️ **Identity Governance:** **Entra ID Governance access reviews** are the mechanism for automating the "does this person still need access?" question. Scoped to guest accounts, they require a sponsor or manager to periodically confirm access and auto-revoke on no response. If you're not running these, stale guests are accumulating right now. Set an expiration policy. Define who reviews it. Own the process for showing guests out when the relationship ends.

---

## → Practical Checklist

**Audit Cross-Tenant Access Settings** Most tenants have never touched these from default. By default MFA and device claims from external orgs are not trusted — that's actually the safer starting point. Change it deliberately per partner, not globally.

**Implement the two-policy split** Basic MFA for the mixed population (b2bCollaborationGuest + otherExternalUser). Authentication strength for Entra-backed types. Stop applying one policy across all six types.

**If you're an MSP: audit GDAP partners for Custom Controls MFA** DUO, RSA, Silverfort via Custom Controls will silently block partner technicians. Check this before your next partner onboards. Exclude serviceProvider from auth strength and scope to known partner tenant IDs.

**Set up Entra ID Governance access reviews for guests** Scope to guest accounts. Require a sponsor to confirm access. Auto-revoke on no response. This is how stale guests get cleaned up at scale.

**Set guest expiration policies** Perpetual guest access is a governance failure waiting to surface. Define a reasonable window tied to the nature of the relationship and require active renewal.

**Know your guest population by type, not just by count** Export and sort by guestOrExternalUserTypes. Knowing you have 400 guests is far less useful than knowing how many are Entra-backed vs OTP vs Google federation and whether each population is covered by the right policy.

## → The Takeaway

The people you let into your house aren't all the same, and your security posture for external identities shouldn't treat them like they are. Guest identity is where the "identity is the perimeter" principle gets stress-tested by people entirely outside your control.

Getting this right means understanding what type of credential you're actually trusting, whether that trust is still warranted given the partner's security posture, and whether anyone owns the process for showing guests the door when the relationship ends.

This connects directly to everything else in this series. The CA policies that govern your own users have gaps when external identities enter the picture. The authentication methods you've invested in for your workforce don't automatically carry over. And groups, which we'll cover in the final post, are where guest access gets scoped and where the gaps compound when membership isn't maintained.
