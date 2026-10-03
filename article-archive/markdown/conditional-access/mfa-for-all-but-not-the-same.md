---
title: "MFA for All… But Not the Same."
description: "One foundational policy. Four excluded service principals. And the production scars that explain every decision."
series: "conditional-access"
published: "2026-02-10"
canonical_url: "https://conditionalaccess.tech/articles/conditional-access/mfa-for-all-but-not-the-same.html"
source: "catech-branded/conditional-access/mfa-for-all-but-not-the-same.html"
---
# MFA for All… But Not the Same.

*Conditional Access Series · February 2026*

The foundational policy looks simple. One name. One rule. But behind ACME — GLOBAL — GRANT — MFA — All-Users is a decade of trial, error, and production scars.

Conditional Access · Feb 16, 2026 · 7 min read · ✅ Entra News #137

Last week I was recording some videos on pushing out Conditional Access policies and ran into something familiar: [a missing service principal](https://share.vidyard.com/watch/kocjRP4syUjq2kWtvtGKQy).

That failure forced me to revisit one of my foundational policies — the one I've used for years. And instead of just fixing it quietly, I decided to document it.

Because if you've worked in Microsoft Entra ID long enough, you've felt the pain:

A device failing to join Intune. A MAM policy breaking due to Defender. Passkey enrollment failing. A Conditional Access policy that looked perfect but didn't deploy. We've all discovered the hard way that **identity is unforgiving**.

> "Over time, I built a standard approach for 'MFA for All Users.' I'm not saying it's best practice. I'm saying it's what I adopted through trial, error, and production scars."

## 01. Examining the Policy

The policy name tells the full story:

> ℹ️ **Policy Name Convention:** **ACME — GLOBAL — GRANT — MFA — All-Users**  
  
 **GLOBAL** → Targets all users and all apps  
 **GRANT** → Requires something (MFA)  
 **Foundation Policy** → One of the six every tenant should have

This is the baseline. Everything builds from here.

![Conditional Access layered approach: Foundations, Baseline, Apps/Devices, P2 and ZTCA](https://conditionalaccess.tech/articles/conditional-access/images/CALayers.png)

## 02. User Exclusions — The Easy Part

First stop: excluded groups.

**Breakglass accounts are excluded.** This is intentional and aligned with best practice — see [Not Another Breakglass](https://medium.com/@jhope188/securecloudfoundation-not-another-breakglass-b631b5e95e05). This is one of a couple policies to include the CA — GlobalExclusions group. You have to be careful that you don't treat this like breakglass and end up adding one person to a group and then they bypass everything.

Next: **directory synchronization accounts**.

Most hybrid environments use Microsoft Entra Connect to sync on-prem identities to Entra. If that sync identity is forced through MFA, synchronization breaks. This approach was reinforced the first time I ran Maester — specifically test [MT.1020](https://maester.dev/docs/tests/MT.1020/), which recommends excluding service accounts like the Microsoft Entra Connect Sync Account from Conditional Access policies.

Instead of manually hunting sync accounts in every tenant, I standardized the exclusion. Is direct assignment cleaner? Possibly. Does this approach prevent human error across multiple tenants? Absolutely.

A great piece of feedback I received came from [Jay](https://github.com/jkerai1/):

J

Jay · GitHub: jkerai1

"You shouldn't need to exclude the directory synchronization account anymore — as long as Entra Connect is up to date."

That stopped me for a minute. Because for years, excluding the sync account from Conditional Access was considered standard practice. So what changed?

## 03. What Changed in Version 2.5.76.0

> ℹ️ **🔄 Updated Content:** Starting with Entra Connect version **2.5.76.0**, Microsoft moved synchronization to Application-Based Authentication (ABA) by default when upgrading from legacy configurations. [Reference: Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/reference-connect-version-history#25760)

This means sync no longer relies on a username/password user account. It uses a service principal instead. Authentication is certificate-based, non-interactive, and **not subject to user-targeted Conditional Access policies**.

In other words: *the original reason we excluded the directory sync user may no longer apply in modern deployments*. This needs to be evaluated on a case-by-case basis.

## 04. The Real Issue: Missing Service Principal

The policy failed because one of four excluded service principals didn't exist in the tenant. That's when the troubleshooting began.

Here are the excluded apps — use [aka.ms/AppNames](https://aka.ms/AppNames) to find app names by GUID:

```
// Excluded from ACME — GLOBAL — GRANT — MFA — All-Users
"excludeApplications": [
  "00000012-0000-0000-c000-000000000000", // Microsoft Rights Management Services
  "d4ebce55-015a-49b5-a083-c84d1797ae8c", // Microsoft Intune Enrollment
  "372140e0-b3b7-4226-8ef9-d57986796201", // Azure Windows VM Sign-In
  "0000000a-0000-0000-c000-000000000000"   // Microsoft Intune (Legacy — Removed)
]
```

| Application | Purpose | Status |
| --- | --- | --- |
| Microsoft Rights Management Services 00000012-0000-0000-c000-000000000000 | Encryption, IRM, sensitivity label enforcement | Keep |
| Microsoft Intune Enrollment d4ebce55-015a-49b5-a083-c84d1797ae8c | Azure AD Join, Autopilot, Company Portal, MDM bootstrap | Review |
| Azure Windows VM Sign-In 372140e0-b3b7-4226-8ef9-d57986796201 | RDP to Entra-joined Azure VMs, AVD flows | Review |
| Microsoft Intune 0000000a-0000-0000-c000-000000000000 | Device policy sync, compliance, app deployment (post-enrollment) | Removed |

## 05. Microsoft Rights Management Services

If you're using Purview sensitivity labels, this exclusion is often required. Encryption and IRM flows authenticate through this service principal, and blocking it with MFA can break label enforcement silently.

Tony Redmond has an excellent breakdown: [office365itpros.com — Conditional Access MFA & Email](https://office365itpros.com/2024/02/12/conditional-access-mfa-email/)

## 06. Microsoft Intune Enrollment

This is the operationally necessary exclusion and the one that caused my failure. Intune Enrollment handles:

Azure AD Join · Autopilot · Company Portal enrollment · Initial MDM bootstrap

If MFA blocks this flow, **enrollment fails**. This was the missing service principal in my tenant. In my case, the principal had never been instantiated — it simply didn't exist.

> ℹ️ **🔄 Updated — CIS Guidance:** [Henrik Piecha](https://www.linkedin.com/in/henrik-piecha/) pointed out that updated CIS guidance now leans in the opposite direction — specifically recommending **stronger protection** of Microsoft Intune Enrollment, including sign-in frequency controls.  
  
 Reference: [CIS Microsoft 365 Foundations v5.0.0](https://www.tenable.com/audits/items/CIS_Microsoft_365_Foundations_v5.0.0_L1_E3.audit:ae279571f175251c280c8ea1e670c846)

I've previously excluded Intune Enrollment due to legacy workflows, hybrid join complexity, Autopilot edge cases, and troubleshooting scenarios. But guidance evolves. Platforms mature. And what once required exclusion may now deserve intentional hardening instead.

## 07. Microsoft Intune — Removed

This handles post-enrollment traffic: device policy sync, compliance checks, app deployment, configuration updates. This exclusion is legacy in my environment. Honestly? **I would remove this today unless absolutely necessary.**

In hindsight, this was likely added during troubleshooting. I suspect many environments have similar historical exclusions that were never revisited. The more critical exclusion is Intune Enrollment above.

## 08. Azure Windows VM Sign-In

Used when RDP-ing into Entra-joined Azure VMs, using the Azure AD Login extension, or in certain AVD flows. Originally excluded after running into MFA issues when testing Entra-joined VMs. [Microsoft documentation](https://learn.microsoft.com/en-us/entra/identity/devices/howto-vm-sign-in-azure-ad-windows) even suggests excluding it in some scenarios.

Was it architecturally ideal? Probably not. But it fixed the problem quickly.

## 09. The Bigger Design Question

Excluding an app is easy. But is it the right approach? I explored whether a device filter would be cleaner:

```
device.trustType -ne "AzureAD"
```

The idea: instead of excluding Azure Windows VM Sign-In from the policy, conditionally allow only trusted, Entra-joined devices and keep everything else enforced. Architecturally, that feels more mature than a blanket exclusion.

However, [Microsoft documentation](https://learn.microsoft.com/en-us/entra/identity/devices/howto-vm-sign-in-azure-ad-windows?pivots=identity-extension-vm) introduces an important limitation:

> ⚠️ **Platform Limitation:** When a Conditional Access policy requires a compliant device for the Azure Windows VM Sign-In resource and the connection is initiated from a **Windows Server device**, compliance evaluation isn't supported. OS-based filtering becomes unreliable for this flow.

What looked like a cleaner alternative now has technical constraints. It's not just about what we *want* Conditional Access to enforce — it's about what the platform can realistically evaluate for that specific resource.

> "Not all exclusions are equal. And not all Conditional Access controls apply uniformly across every workload."

## 10. The Swiss Cheese Effect

Fabian Bader wrote an excellent article on FOCI (Family of Client IDs): [cloudbrothers.info — Conditional Access Bypasses](https://cloudbrothers.info/en/conditional-access-bypasses/)

Some applications are part of token families. **Excluding one can implicitly allow others.** That creates a Swiss cheese effect in Conditional Access — each exclusion punches a hole, and holes compound.

> ℹ️ **Good News:** Azure Windows VM Sign-In is **not FOCI-based**. But the lesson remains: one exclusion can create multiple unintended allowances. Before excluding any app, check: [entrascopes.com](https://entrascopes.com/)

For a deep dive on the topic, [this video](https://www.youtube.com/watch?v=yYQBeDFEkps&list=PLuPHrE2HRFpOpFWfE0XLE3LsuMh0_8-Kr&index=97) covers it well. I've also added the relevant links to my [CA Repo on GitHub](https://github.com/Jhope188/ConditionalAccessPolicies/blob/main/README.md).

## 11. Recreating Missing Service Principals

If any of the service principals above don't exist in your tenant, run the script below to instantiate them. I've included all potential apps just in case:

```
Connect-MgGraph -Scopes "Application.ReadWrite.All"

# Microsoft Intune Enrollment
New-MgServicePrincipal -AppId "d4ebce55-015a-49b5-a083-c84d1797ae8c"

# Azure Windows VM Sign-In
New-MgServicePrincipal -AppId "372140e0-b3b7-4226-8ef9-d57986796201"

# Microsoft Rights Management Services
New-MgServicePrincipal -AppId "00000012-0000-0000-c000-000000000000"
```

---

## → Final Thought

"MFA for All Users" sounds simple. It isn't.

What this experience reinforced:

**Global policies are foundations, not finished architecture.** Exclusions accumulate over time. Service principals evolve. Documentation changes. And yesterday's quick fix can become today's blind spot.

Conditional Access isn't about making MFA universal. It's about making it *contextual*.

The real maturity in identity isn't enabling MFA everywhere. It's continuously reevaluating why you excluded something in the first place. Because in identity, **every exception tells a story**. And eventually, you have to revisit it.

With Audience Reporting in Conditional Access, we now have far better visibility into how policies affect users and workloads. That makes testing safer, analysis faster, and decisions more informed.

Every exclusion should be questioned. Every legacy workaround should be retested. Because in identity architecture, the right answer five years ago might not be the right answer today.
