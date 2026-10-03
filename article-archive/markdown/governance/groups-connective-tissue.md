---
title: "Groups Are the Connective Tissue"
description: "Every CA policy, every SharePoint site, every Teams workspace, every guest invitation eventually resolves to a group. Most tenants have hundreds of them with no verified owner. That’s not a cleanup problem. That’s a structural control failure."
series: "governance"
published: "2026-07-06"
canonical_url: "https://conditionalaccess.tech/articles/governance/groups-connective-tissue.html"
source: "catech-branded/governance/groups-connective-tissue.html"
---
# Groups Are the Connective Tissue

*M365 Governance Series — Part 1 of 5*

Every CA policy, every SharePoint site, every Teams workspace, every guest invitation eventually resolves to a group. Most tenants have hundreds of them with no verified owner. That's not a cleanup problem. That's a structural control failure.

Entra ID Governance · June 23, 2026 · 12 min read

**A note on inspiration:** This series grew out of field experience across dozens of M365 environments, but the governance framing was sharpened by an episode of the [M365 FM podcast](https://www.m365.fm/governance-illusion-microsoft-365/) hosted by **Mirko Peters** — "The Governance Illusion: Why Your Tenant Is Beyond Control." The concepts here are original and practitioner-driven, but Mirko's framing of governance as an operating discipline rather than a deployment project is worth an hour of your time in its own right.

If you ask most M365 admins what controls access in their tenant, they'll point to Conditional Access policies. That's the right answer for the authentication layer. But CA policies tell you who can get through the door under what conditions. They don't tell you what the person can do once they're inside, and they don't tell you who else is already inside the room.

Groups answer those questions. Every permission boundary in M365 is ultimately grounded in group membership. SharePoint sites scope access through them. Teams workspaces are built on them. CA policy exclusions are managed through them. Guest identities persist inside them. Dynamic group rules silently re-scope them overnight.

> "A group with no verified owner isn't just an administrative loose end. It's an open authorization surface that will persist, drift, and outlive the project that created it."

And here's the thing that catches most organizations off guard: the M365 group object isn't just a membership list. It's a connected set of resources. When a group gets created, a stack of dependent workloads comes with it, each with its own permission model, its own lifecycle, and its own way of quietly accumulating exposure over time.

## 01. The M365 Group Is Not a Membership List

This is the mental model most governance conversations miss. When someone creates a Microsoft 365 group, they're not adding a row to a directory. They're creating a connected set of resources that spans the entire workload stack. Everything grounded in that group inherits its membership, its permissions, and its access state. Including its guests.

🔗

Microsoft 365 Group Object

One creation event. Multiple dependent resources. One shared authorization surface.

💬

Teams Workspace

Channels, chats, meeting artifacts, apps, agents. The front door most people see.

Creation surface

📁

SharePoint Site

Created automatically. Files live here. Sharing links, inheritance breaks, and guest access accumulate here silently.

Exposure surface

📧

Exchange Mailbox

Group inbox and calendar. Receives mail as a distribution list. Often forgotten entirely.

Data residency

✅

Planner Board

Task and project data. Persists long after the project ends. Membership controls who can read it.

Data lifecycle

📓

OneNote Notebook

Meeting notes, project documentation, anything copy-pasted in over years of use.

Data lifecycle

🤖

Copilot / Agents

AI surfaces now land here. Copilot queries across whatever the membership allows. This is new. Most governance models haven't caught up.

New AI surface

**The governance implication:** When you lose ownership of a group, you don't lose ownership of a membership list. You lose accountability for everything grounded in that group: every file in the SharePoint site, every guest in the workspace, every task in the planner board, and every AI query that now runs across all of it.

This is why the question "who owns this group?" is not a metadata question. It's an operational question with a direct line to your risk posture. Every enforcement action, every access review, every expiration decision requires a human to root it to. No owner means no one to attest. No one to attest means the system can only report the problem, never resolve it.

## 02. How Groups Break: The Four Ownership Failure Modes

Ownership isn't a binary. It doesn't just exist or not exist. It degrades through predictable patterns that every organization with real adoption will eventually encounter. Naming them makes them preventable.

🚪

**The Departing Owner**

The most common failure. A group gets created by an employee who later leaves. M365 doesn't enforce minimum ownership. It doesn't block offboarding when active group ownership exists. The group continues. The SharePoint site continues. Any guests the owner invited continue. Nobody inherited the responsibility because nobody designed the handoff.

Most Common

👤

**The Nominal Owner**

The group has two owners on paper, because someone once told you to always have two. But neither of them actually manages the group. They inherited it when someone left, or they were added as a backup and forgot. When an access review arrives, they approve everything because they don't know what's safe to remove. Ownership on paper is not ownership in practice.

Silent Risk

🔄

**The Dynamic Rule That Drifted**

Dynamic membership groups are powerful and genuinely the right tool for large populations. But the rule that scopes them gets written once, by someone who understood the business context at the time, and then it runs forever. When departments reorganize, when job titles change, when contractor attributes get updated differently than employees, the rule quietly includes or excludes people it was never meant to touch. Nobody gets an alert. The membership just shifts.

Structural

♾️

**The Ownerless Guest Container**

The intersection of the guest problem from the last post and the group problem from this one. A guest gets added to a group for a project. The project ends. The owner leaves. Nobody runs a cleanup. The guest account is now in a group with no verified owner, attached to a SharePoint site nobody is actively managing, with files that may or may not still be relevant. This is the configuration that keeps compliance teams awake.

High Risk

## 03. Dynamic vs. Assigned: The Right Tool for the Right Problem

The dynamic vs. assigned debate is often framed as a preference. It isn't. The choice between them has direct implications for what breaks when the underlying data changes, and for what CA policies targeting that group actually enforce.

Dynamic Membership

Rule-Based

- Membership managed automatically by attribute rules
- Scales without manual intervention for large populations
- Correct when identity attributes are accurate and stable
- Right choice for department-wide or role-wide policies
- Requires audit of the rule itself, not just the members
- Rule drift happens when HR attributes change schema or convention

Risk: The rule, not the roster. Audit: quarterly rule review against current attribute schema.

Assigned Membership

Manual

- Explicit control over who is in scope
- Required for exception-based or project-scoped groups
- Correct for CA policy exclusions (break-glass, service accounts)
- Scales poorly without lifecycle enforcement
- Stale members accumulate if access reviews don't run
- Guest members especially prone to indefinite persistence

Risk: The roster, not the rule. Audit: recurring access reviews with consequence on non-response.

> ⚠️ **Dynamic Groups and CA Exclusions — Be Deliberate:** **Dynamic groups in CA exclusions aren't automatically wrong, but they need to be intentional and tightly controlled.** There are legitimate use cases. A dynamic query scoped to Teams-certified devices is a common and reasonable way to handle device code flow exclusions without manually maintaining a membership list. The rule is specific, the scope is narrow, and the attribute driving it is controlled. The risk is when exclusion groups use dynamic rules tied to attributes that users or attackers can influence. If someone can add the right attribute to an account, a department field, a job title, an extension attribute, they can dynamically qualify for an exclusion from an otherwise intentional control without anyone approving it. That's not a theoretical risk. It's a bypass vector that bypasses the entire point of the exclusion group model. The rule of thumb: dynamic queries in CA exclusions are fine when the qualifying attribute is controlled by IT and not writable by the user or an attacker with partial access. Assigned groups are the safer default for anything where that condition isn't clearly met. And either way, exclusion groups need a quarterly review and documented justification for every member or rule in them.

## 04. Entra Access Reviews: Enforcement, Not Reporting

Entra ID Governance access reviews get deployed in most organizations as a compliance checkbox. Run the review quarterly, export the results, close the ticket. That's not governance. It's a scheduled reporting event. The value of access reviews isn't the report they produce. It's the consequence that fires when the owner doesn't respond.

A review with no enforced outcome is a survey. A review where no response means removal is an access control. That's the difference, and most environments are running the first one while thinking they're running the second.

1

**Scope the review correctly**

Separate reviews for guests and internal members. Separate reviews for high-risk groups (CA exclusions, privileged roles, sensitive data sites) vs. general collaboration groups. Don't run one review across everything. Reviewer fatigue kills the process.

guestOrExternalUserTypes: b2bCollaborationGuest, otherExternalUser

2

**Assign the right reviewer — not just the owner**

For guest reviews, the person who invited the guest (the sponsor) is better positioned than the group owner to confirm whether the relationship is still active. For internal members, managers are often more current than group owners. Use the right scope for each population.

3

**Set the auto-apply outcome — this is the enforcement layer**

No response within the review window should mean removal, not approval. "Approve on no response" defeats the entire purpose of the review. The review only has teeth if non-engagement has a consequence.

onAccessReviewCompletion: removeAccess (not keepAccess)

4

**Enforce reassignment when owners go missing**

If a group has no valid owner at review time, escalate to a defined fallback, a manager, a department head, a security team queue. Don't leave the review open indefinitely. The review is how you detect ownerless groups and force a decision on them.

5

**Pair reviews with expiration policies for guest accounts**

Access reviews handle group membership. Expiration policies handle the guest account itself. Both are needed. A guest removed from a group but not disabled can still authenticate and potentially find other paths in. Lifecycle has to close both loops.

guestUserExpirationPolicy: review every 90 days, auto-disable on no renewal

> 🛑 **When Reviews Stop Meaning Anything:** **Review fatigue produces the same outcome as no review.** When owners are assigned too many groups to review, when the review interface provides no context about what the group actually controls, when approving is one click and investigating is thirty minutes of work, reviewers approve. Every time. The organization converts uncertainty into permanent access, quarter after quarter, until nobody can distinguish a deliberate decision from something that just never got questioned.

## 05. What "Two Owners" Actually Means in Practice

Microsoft's recommendation to require a minimum of two owners per group is correct but routinely misunderstood. Two owners is a minimum threshold against the departing-owner failure mode. It is not a governance model. Two nominal owners who inherited the group when the original owner left, and who both approve everything in every review, don't provide meaningful oversight. They provide audit cover.

Ownership governance requires three things that "two owners" doesn't guarantee on its own:

Ownership Requirements That Survive Turnover

| Requirement | What It Means | How It Fails Without Enforcement |
| --- | --- | --- |
| **Verified owners** | Owners are active employees who actually know the group's purpose and can make informed access decisions | Inherited owners approve everything in reviews because they don't have context. Departed owners leave stale ownership records that block automated enforcement. |
| **Enforced minimum** | minimumOwners: 2 enforced with automated detection and escalation when ownership drops below threshold | Without enforcement, groups naturally drift to single owner or no owner as people leave. Nobody gets an alert until a review fails. |
| **Documented purpose** | Each group has a description that tells a reviewer what it's for, who should be in it, and what it controls access to | Reviewers can't make informed decisions about membership they don't understand. Everything gets approved by default. |
| **Enforced reassignment** | When an owner leaves, a defined process reassigns ownership before the account is disabled, not after the next review cycle | Offboarding processes handle user accounts. They almost never handle group ownership dependencies. The gap is where ownerless groups come from. |

---

## → Practical Checklist

**Audit groups for ownership right now** Export all M365 groups and filter for zero or one owner. In most tenants this list is longer than expected. Ownerless groups aren't anomalies, they're the predictable output of offboarding processes that handle accounts but not group dependencies.

**Enforce minimum owners with automated detection** Two owners is the floor. Build detection into your offboarding workflow so that when a user is disabled, any group they're a sole owner of surfaces for reassignment before the account closes, not in the next quarterly review.

**Audit dynamic group rules against current attribute schema** Run a point-in-time review of every dynamic group used in CA policy scope or exclusion. Confirm the rule is still evaluating the intended population. Attribute convention drift is silent and rarely detected until a policy mismatch surfaces an incident.

**Be deliberate about dynamic groups in CA exclusions** Dynamic queries in CA exclusions can be legitimate. Scoping an exclusion to Teams-certified devices via a device attribute is a real and reasonable pattern. The question is whether the qualifying attribute is controlled by IT or writable by someone else. If a user or attacker can self-assign the attribute that qualifies an account for the exclusion, that exclusion is a bypass vector. Assigned groups are the safer default. When dynamic rules are used, document the justification and review the rule quarterly.

**Configure access reviews with removal as the no-response outcome** "Approve on no response" defeats the purpose of the review. Build the review so that non-engagement has a consequence: removal or escalation. Then design the review to be answerable: include context about what the group controls so reviewers can make informed decisions.

**Know your group population by type and purpose** Microsoft 365 groups, security groups, mail-enabled security groups, and distribution lists have different capabilities and different governance requirements. Knowing you have 800 groups is far less useful than knowing what types they are, what they control, and which ones have a verified owner.

**Close both loops on stale guests: group membership AND account lifecycle** Removing a guest from a group leaves their account active. Disabling the account without removing group membership leaves data access footprint. Access reviews handle membership. Expiration policies handle accounts. Both need to run and both need enforced outcomes.

## → The Takeaway

Groups are where identity governance stops being an identity problem and starts being a data governance problem. The CA policies from your last project define the conditions for access. The groups underneath them define the scope. And the ownership model for those groups determines whether any of it stays aligned with intent once the project is over.

The pattern that kills M365 governance isn't a bad configuration decision. It's the gap between where policies are written and where work actually happens. Settings live in admin centers. People create Teams from Planner, share files from OneDrive, add guests because the project needs it today. Groups accumulate without owners. Dynamic rules drift without audits. Guests persist without sponsors. The tenant keeps running, generating no errors, no alarms, quietly becoming a record of every access decision that was ever made minus the ones someone chose to clean up.

In the next post, we examine why this happens even in tenants that think they've done governance right: the difference between configuration and control, and what it looks like when the place where work happens grows faster than the place where settings are managed.
