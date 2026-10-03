---
title: "Groups: The Connective Tissue"
description: "Every MFA policy, CA exclusion, app assignment, and privileged role is enforced through group membership. Get groups wrong and everything else fails quietly."
series: "identity"
published: "2026-06-16"
canonical_url: "https://conditionalaccess.tech/articles/identity/groups-connective-tissue.html"
source: "catech-branded/identity/groups-connective-tissue.html"
---
# Groups: The Connective Tissue

*Identity Security Series: Part 5 of 5*

Everything in this series, authentication methods, passkeys, CA policy, guest access, is enforced through group membership. Get groups wrong and everything else you built starts failing quietly in the background.

Entra Identity · June 16, 2026 · 10 min read

We've covered why identity is the perimeter, how authentication methods differ, why passkeys finally solve the friction problem, and how guest identities introduce trust problems most tenants haven't thought through. All of that work, every policy, every control, every phishing-resistant credential, gets enforced through group membership. Groups are where the strategy meets reality.

Get groups right and your identity posture scales. Get them wrong and you spend the next three years fighting access gaps, stale memberships, CA exclusions nobody can explain, and a growing dependency on an AD environment you were supposed to be moving away from.

> "Identity lives and dies by groups. Every MFA policy, every CA exclusion, every app assignment, every privileged role. It's all groups underneath. The cleaner your groups, the more your security controls actually work."

## 01. Why Groups Are the Control Plane

Look at everything covered in this series through the lens of group membership and a pattern emerges.

🔑

**Authentication Method Targeting** When you enable passkeys or restrict SMS OTP in the unified Authentication Methods Policy, you scope it to groups. The rollout is only as clean as the group membership.

📋

**Conditional Access Policies** Every CA policy has an include and an exclude. Both are groups. The exclude group is where exceptions live, and where ungoverned groups create the gaps attackers look for.

👤

**Passkey Profiles** Device-bound for admins, synced for standard users. That segmentation is enforced through group-based passkey profile targeting. No clean groups, no clean segmentation.

🤝

**Guest Access Scoping** What a guest can reach inside your tenant is determined by the groups they're added to. Stale group membership is stale access. Access review scope is a group.

🛡️

**PIM Role Assignments** Privileged Identity Management activates roles through group membership. The security of your admin tier is only as strong as the integrity of those groups.

Groups aren't a supporting character in this story. Groups are the shield around identity. Every control in this series, every policy, every method, every access boundary, is only as strong as the group membership behind it. A group with stale membership silently undermines every policy that targets it.

## 02. The AD Dependency Problem

Most organizations in the SMB and MSP space sit somewhere on a spectrum between "still fully on-prem AD" and "genuinely cloud-native." Very few are at either extreme. The majority are in a hybrid middle ground that they've been trying to move out of for years without a clear path.

The honest reason hybrid stays sticky isn't technology. It's group dependency. Every time a new app gets provisioned with an AD security group, every time a new printer gets configured with a domain group, every time a new share gets NTFS permissions from an AD object, you're building another dependency on the on-prem directory that makes leaving harder. Not impossible. Just harder, and more expensive to unwind later.

> 🛑 **The Hidden Cost of AD Group Sprawl:** Every AD group with no Entra equivalent is a dependency that ties at least one workflow to on-prem infrastructure. Over time these accumulate quietly: a shared drive here, a legacy app there, a printer group that nobody can touch. The cost isn't visible until you try to decommission a domain controller and realize how many things still depend on it. The time to audit is now, not when you're forced to.

## 03. The Groups-First Migration Strategy

The path out of hybrid dependency isn't a single migration event. It's a gradual shift of group ownership from AD to Entra, one persona and one workflow at a time. Stop building new things that depend on AD groups. Start moving existing workflows to Entra groups as the opportunity arises.

The key is identifying personas, the logical groupings of users by what they need access to, and building those as clean Entra groups from the start. Not AD groups written back. Native Entra groups managed in Entra.

*Start Here*

🏗️ **New Apps First**

Every new SaaS app, every new integration, every new tool gets provisioned with Entra groups. Printix, not print server groups. Teams channels, not AD distribution lists. Each new deployment is an AD dependency you never built.

Entra Security Group · Dynamic where possible

*Map and Move*

🗺️ **Persona Migration**

Map your org by business unit and role. Create clear Entra group structures for each persona. For every group you create in Entra, ask: what on-prem resource still requires the AD version? Then make that list your migration backlog.

Group Writeback v2 · Source of Authority transfer

*Clean as You Go*

🧹 **Remove Stale Dependency**

Every share that moves to SharePoint is an NTFS permission group you can retire. Every printer that moves to Printix is a domain group you can delete. Every legacy app that modernizes is another thread cut. AD fades when you stop feeding it.

Access Reviews · Ownership assignment · Lifecycle policy

## 04. The Hybrid Bridge: Group Writeback v2

For organizations that still have legitimate on-prem dependencies, Group Writeback v2 via Entra Cloud Sync is the bridge that makes an AD-minimized design possible without going cold turkey. It lets Entra-managed groups write back into AD, so you can manage membership in Entra while still satisfying the NTFS permissions and legacy app requirements that haven't moved yet.

The key word is bridge. Writeback isn't a permanent architecture. It's a transitional tool that lets you establish Entra as the home for group membership today while the on-prem dependencies are still being wound down. The goal is to shrink the list of things that need writeback, not keep it alive forever.

> ℹ️ **Source of Authority Transfer:** **Group Source of Authority (SOA)** in Entra lets legacy AD groups transition to cloud ownership without breaking workflows that still depend on them. Combined with the recently GA'd ability to convert individual users from on-premises to cloud-managed, you can transfer control piece by piece rather than in one high-stakes cutover. Every group you move to cloud SOA is a group that no longer needs a functioning AD environment behind it.

## 05. Group Hygiene: The Part Most Orgs Skip

Clean group strategy and clean group hygiene are different problems. Strategy is about what groups you create and where. Hygiene is about whether those groups stay accurate over time. Most organizations have a reasonable strategy and almost no hygiene. Groups that were accurate when created get increasingly wrong as people leave, roles change, and projects end.

1

**Every Group Needs an Owner**

Mystery groups, groups with no assigned owner, no documentation, no clear purpose, are where your access review process breaks down. If nobody owns a group, nobody is responsible for its accuracy. Assign ownership at creation and enforce it. No owner, no group should exist.

2

**Use Dynamic Membership Where the Logic Is Stable**

If the rule for group membership is predictable (department equals Finance, job title contains Manager, assigned license includes Intune) dynamic groups are more reliable than manually maintained ones because the membership stays accurate without human intervention. The logic is the source of truth, not someone's last bulk import.

3

**Run Access Reviews on Security-Sensitive Groups**

Passkey profile groups, CA exclusion groups, PIM role assignment groups. These are the groups where stale membership has direct security consequences. Scope access reviews to them specifically. Require the group owner to confirm membership periodically. Auto-revoke on no response. The same access review mechanism from the guest post applies here.

4

**CA Exclusion Groups Deserve Special Attention**

The exclusion list in a Conditional Access policy is where the attack surface lives. Every account in a CA exclusion group bypasses whatever that policy enforces. These groups should have the smallest possible membership, clear justification for every member, regular review cycles, and ideally PIM-scoped access to be added to them at all. This is the handoff point into the CA Foundations series.

---

What Comes Next

### The M365 Governance Series

This series established the why and the what of identity security: why identity is the perimeter, what authentication methods actually protect you against, how passkeys make phishing resistance accessible, how guest identities introduce trust you haven't examined, and how groups are the mechanism that makes all of it real.

But knowing the controls exist and maintaining them are different problems entirely. The M365 Governance series picks up exactly here, with the question of why groups fail over time even in tenants that built them correctly, and what it looks like to own identity governance as a continuous operating model rather than a periodic audit event.

The first post in that series starts with the same problem this post ends on: nobody owns the scissors. Groups accumulate without owners. Dynamic rules drift without audits. Access reviews produce approvals instead of decisions. The governance series is about closing that gap in a way that actually sticks.

[Continue to the Governance Series](https://medium.com/@jhope188) [Back to Home](https://conditionalaccess.tech)
