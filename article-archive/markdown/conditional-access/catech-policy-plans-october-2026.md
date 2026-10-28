---
title: "Policy Plans Turn Conditional Access From a Flat List Into Something You Can Organize"
description: "Entra's new Conditional Access policy plans (preview) let you define targeting and exclusions once and layer scenario rules underneath, plus the Security Defaults update that blocks device code flow, and the Message Center and Roadmap items moving SMS, passkey and agent timelines this October."
series: "conditional-access"
published: "2026-10-28"
canonical_url: "https://conditionalaccess.tech/articles/conditional-access/catech-policy-plans-october-2026.html"
source: "catech-branded/conditional-access/catech-policy-plans-october-2026.html"
---
# Policy Plans Turn Conditional Access From a Flat List Into Something You Can Organize

*Conditional Access · October 2026*

Entra now lets you define targeting and exclusions once and hang scenario rules underneath. The same month moved Security Defaults, passkey registration and the SMS retirement date.

Policy plans · Preview · Security defaults · · · Microsoft MVP · Security: Identity & Access

Section 01

## Two Headline Changes, Ten Smaller Ones You Still Have to Schedule

Source: [MC1450133](https://deltapulse.app/item/MC1450133) · [MC1450134](https://deltapulse.app/item/MC1450134) · [MC1465763](https://deltapulse.app/item/MC1465763) · [MC1528000](https://deltapulse.app/item/MC1528000) · [MC1519855](https://deltapulse.app/item/MC1519855) · [MC1478962](https://deltapulse.app/item/MC1478962) · [MC1481309](https://deltapulse.app/item/MC1481309) · [MC1506733](https://deltapulse.app/item/MC1506733) · [Roadmap 571879](https://deltapulse.app/item/571879) · [Roadmap 569432](https://deltapulse.app/item/569432)

There's been so much going on that staying on top of every change to Entra, Conditional Access and Microsoft in general feels impossible. Here are some of the items around Entra and Conditional Access you may or may not have seen already.

Items below come from the Message Center and Roadmap, 28 September to 28 October. Policy plans and Security Defaults have no item there, so those two sections come from Microsoft Learn.

| Change | What happens | When | Status |
| --- | --- | --- | --- |
| [MC1450133](https://deltapulse.app/item/MC1450133) Passkey as first MFA method | Password-only users can register a passkey without first setting up SMS or voice. | Phased, Nov 2026 to Feb 2027. Timeline updated 26 Oct. | Rolling out |
| [MC1450134](https://deltapulse.app/item/MC1450134) WHfB and macOS PSSO as standalone MFA | Both count as MFA on their own, including for step-up, authentication strength and sign-in frequency checks. | Early Nov 2026. Timeline updated 27 Oct. | Rolling out |
| [MC1465763](https://deltapulse.app/item/MC1465763) SMS first-factor auto-disable | Tenants with no successful SMS first-factor sign-ins in 30 days lose the capability. SMS for MFA and password reset is unaffected. | Mid Sep to Nov 2026. Updated 28 Oct. | Timeline slipped |
| [MC1528000](https://deltapulse.app/item/MC1528000) SMS and voice retirement | Microsoft-provided SMS and voice authentication retire. | From 1 Feb 2027 | Retirement |
| [MC1519855](https://deltapulse.app/item/MC1519855) Choose your own telephony provider | Third-party provider for SMS and voice through Microsoft Security Store. Some users keep Microsoft-provided delivery until 1 Jul 2027. | GA 30 Oct 2026 | GA |
| [MC1506733](https://deltapulse.app/item/MC1506733) Agent blueprint creation | Default users can create agent blueprints unless you turn off Users can create agent blueprints. | From 4 Nov, complete late Nov 2026 | Action may be required |
| [MC1478962](https://deltapulse.app/item/MC1478962) Teams Android | Stricter Conditional Access evaluation for resource-specific policies can cause sign-in failures on app version 1449/1.0.96.2026249711. | Late Sep to mid Oct 2026 | Review exclusions |
| [MC1481309](https://deltapulse.app/item/MC1481309) Sign-in script injection | Content Security Policy on login.microsoftonline.com blocks externally injected scripts. Affects custom script-injecting tools only. | Mid Oct 2026 | Reminder |
| [Roadmap 571879](https://deltapulse.app/item/571879) Granular CA for Teams meetings | Conditional Access targeting for Teams meetings. | Not dated | In development |
| [Roadmap 569432](https://deltapulse.app/item/569432) Passkeys for B2B users | Passkey support for external users. | Not dated | In development |

> ⚠️ **Timelines moved this month:** Three of these items carried an update note in the last week saying the timeline changed. Re-check the dates in your own Message Center before you commit change windows to them.

Section 02

## Security Defaults Now Block Device Code Flow, and New Tenants Get a 24-Hour Window

Source: [Security defaults in Microsoft Entra ID](https://learn.microsoft.com/entra/fundamentals/security-defaults) · [Microsoft-managed Conditional Access policies](https://learn.microsoft.com/entra/identity/conditional-access/managed-policies)

Security Defaults is the free-tier baseline, and Learn now lists six enforced controls. Device code flow blocking is the newest. The page states that from 1 July 2026 every new Entra tenant blocks it as part of Security Defaults. That date is more than three months old, so treat it as established behavior, not as this month's news.

MFA

### Registration and prompts

All users register for MFA, administrators do MFA at every sign-in, and everyone else is prompted when Microsoft decides it is necessary.

Protocols

### Legacy auth and device code

Legacy authentication protocols are blocked, including Exchange ActiveSync basic authentication. Device code flow is blocked too.

Management plane

### Azure Resource Manager

The Azure portal, Entra admin center, Azure PowerShell and Azure CLI all require MFA for every user who reaches them.

Two details matter for tenants you hand over to customers. New tenants get Security Defaults enabled at creation but with a 24-hour grace period before enforcement. And the Directory Synchronization Accounts role is excluded from the MFA requirement.

### The upgrade path is Microsoft-managed policies

Security Defaults and Conditional Access are mutually exclusive. To move on, disable Security Defaults, then enable the Microsoft-managed Conditional Access policies that mirror it: block legacy authentication, MFA for Azure management, MFA for admins and MFA for all users. Learn says to do this immediately after disabling, because the tenant is unprotected in between.

> ⚠️ **Docs inconsistency:** The Security Defaults page lists 16 administrator roles that must do MFA. The managed-policies page describes the matching policy with 14. If you are translating Security Defaults into your own policy, compare the two lists before you rely on either.

Section 03

## A Plan Is a Container With Shared Targeting, Not a New Kind of Policy

Source: [What are Conditional Access policy plans? (preview)](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-policy-plans) · [Create a policy plan (preview)](https://learn.microsoft.com/entra/identity/conditional-access/how-to-create-conditional-access-policy-plan)

Policy plans are in preview. They group related rules under shared assignments and conditions, so you define the user population and the emergency access exclusions once and write each scenario as a rule underneath. Learn names the problem directly: separate policies for Windows, macOS, iOS and Android repeat the same targeting, and a missed exclusion is a common source of lockouts.

Part 1

### Plan details

Name, description, tags and owners. Owners record accountability and grant no permissions. Details do not affect enforcement.

Part 2

### Shared conditions

Optional include and exclude targeting that applies to every rule: identities, resources, actions, risk, platforms, locations and client apps.

Part 3

### Rules

One enforcement scenario each, with its own assignments, conditions, grant and session controls. A plan needs at least one.

### Four rules of inheritance

- A rule inherits the plan's targeting and cannot narrow it.
- Exclusions accumulate. If the plan excludes groups A and B and a rule adds C, the effective exclusions are A, B and C. A rule can never remove a plan-level exclusion.
- Identity type must be consistent. A plan that targets users cannot also target agents at plan level. Leave identities to the rules if you need both.
- All users and All resources are available at rule level only, not in shared conditions.

> Each rule is then evaluated as an independent enforcement decision in the same way as a standalone policy. Each rule appears separately in sign-in logs.

That is the part to hold on to. The plan is an authoring and change-management construct. At sign-in, a rule behaves like a policy and shows up in the logs as its own entry, so your troubleshooting workflow does not change.

### Plans sit beside your existing policies

| Capability | Existing policy | Plan and rules |
| --- | --- | --- |
| Targeting | Defined per policy and duplicated | Defined once in shared conditions, or per rule |
| Change management | Each policy updated individually | One change to shared conditions reaches every rule |
| Templates | One template per policy | Several templates in one plan, or one template per plan |
| Evaluation | Every applicable policy must be satisfied | Every applicable rule must be satisfied, with no precedence between the two |

> ⚠️ **Preview limitation:** During preview, plans that target users with Location as a condition get one-hour access tokens and no instant IP enforcement check. If a plan depends on named locations for security, read the continuous access evaluation limitations before you turn it on.

### Video walkthrough

The video below covers the same model visually and works as a companion to the Learn pages. Where the two differ, the documentation is the reference.

[Watch on YouTube](https://youtu.be/BUI5LZPoHAs)

Section 04

## Organize by Security Objective and Stop Organizing by Policy Count

Source: [Migrate policies to a policy plan (preview)](https://learn.microsoft.com/entra/identity/conditional-access/how-to-migrate-conditional-access-policy-plan) · [Create a policy plan (preview)](https://learn.microsoft.com/entra/identity/conditional-access/how-to-create-conditional-access-policy-plan)

Learn's guidance for building a plan is to pick a security objective first, put only what applies to every scenario in shared conditions, and write variations as rules. The migration page gives three ways to find candidates: group by protected resource, by persona, or by shared condition.

My read on what this means for a policy set that grew organically: the flat list has no place to record intent, so every policy carries its own copy of the exclusions and its own naming. A plan gives intent a home. A "require compliant device" plan holds one exclusion list and one owner, with a rule per platform. An "agent risk" plan holds the shared risk condition, with one rule for agent users and another for autonomous agents.

Break glass

### One exclusion, not forty

Put emergency access accounts in the plan's shared exclusions. No rule can omit them and no rule can remove them.

Ownership

### A name on every plan

Plan owners and tags give you somewhere to record who answers for a set of controls. Owners grant no edit rights, so keep your role assignments separate.

Scale

### Global Secure Access

Learn calls out hundreds of network-scoped rules that share one user population and app set as a target use case.

> ℹ️ **Naming still matters:** A plan name should state the objective, and each rule name should state what varies. Keep your existing policy naming convention on the rules so exports and sign-in log filters stay readable.

Section 05

## Migrating Is Safe Only if You Remember Both Sets Are Still Enforcing

Source: [Migrate policies to a policy plan (preview)](https://learn.microsoft.com/entra/identity/conditional-access/how-to-migrate-conditional-access-policy-plan) · [Analyze Conditional Access policy impact](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-report-only)

There is a built-in migration tool. On the Policies page, the Migrate to Conditional Access Policy plans banner starts it. It analyzes the policies you select, moves what they have in common into shared conditions, maps each policy to a rule and proposes the plan for review. Your original policies are not changed.

1

Select policies with a common intentEntra ID, Conditional Access, Policies, then Get started on the migration banner. Start with a small related group.

2

Review shared conditions and proposed rulesSettings the policies have in common become shared conditions. Every generated rule starts in the Off state.

3

Set rules to Report-onlyCompare rule results in sign-in logs against the original policies. Learn expects them to be equivalent.

4

Turn rules On, then turn the originals OffLearn says to disable the original policies only once you are confident the plan covers your intended posture. Delete after the validation period.

> 🛑 **Double enforcement:** Existing policies and plan rules accumulate independently, and every applicable one must be satisfied. Between step 4 and the original policies going Off, a user faces both. If you add a stricter rule than the original, the stricter one wins in practice. Plan that overlap window deliberately.

Section 06

## Four Dates Before the End of February

Source: [MC1506733](https://deltapulse.app/item/MC1506733) · [MC1519855](https://deltapulse.app/item/MC1519855) · [MC1450134](https://deltapulse.app/item/MC1450134) · [MC1528000](https://deltapulse.app/item/MC1528000)

| Date | Event | Your action |
| --- | --- | --- |
| 30 Oct 2026 | Choose your own telephony provider reaches GA | Decide which user populations genuinely need SMS or voice, and which can move to passkeys. |
| 4 Nov 2026 | Default users can create agent blueprints | Set Users can create agent blueprints to No if you want creation limited to admins. |
| Early Nov 2026 | WHfB and macOS PSSO count as standalone MFA | Update onboarding guidance and re-check authentication strength policies that assumed an extra passkey. |
| 1 Feb 2027 | Microsoft-provided SMS and voice retire | Finish migration or configure a customer-managed provider before this date. |

Start the audit with every policy and authentication strength that accepts SMS or voice as a method, and decide what replaces it before February.

Open questions

## The Plan Documentation Is Silent on Scale, and That Is the Question to Test

Source: [What are Conditional Access policy plans? (preview)](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-policy-plans) · [Migrate policies to a policy plan (preview)](https://learn.microsoft.com/entra/identity/conditional-access/how-to-migrate-conditional-access-policy-plan)

The plans pages do not say whether each rule counts against the per-tenant Conditional Access policy limit. Learn's limit figures also disagree between cached and live versions, so I am not quoting a number here. If rules count individually, a plan with sixty rules is sixty policies for limit purposes, and consolidation buys you tidiness but no headroom.

I am testing policy plans now and will present my own opinion on them in a deeper dive due later in November. The scale question is first on the list, along with how rules show up in sign-in logs. If you get to a lab tenant before I publish, add rules until something stops you and send me what you find.
