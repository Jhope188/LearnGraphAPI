---
title: "The Cleanup Campaign That Never Ends"
description: ""
series: "governance"
published: ""
canonical_url: "https://conditionalaccess.tech/articles/governance/lifecycle-sprawl-countermeasure.html"
source: "catech-branded/governance/lifecycle-sprawl-countermeasure.html"
---
# The Cleanup Campaign That Never Ends

*M365 Governance Series — Part 3 of 5*

Most organizations respond to M365 sprawl the same way: a periodic cleanup effort that finds the quiet workspaces, archives what looks dead, and closes out. Six months later it's back. Not because the work was poor. A one-time fix applied to a system that never stops accumulating isn't a solution. It's a cycle.

M365 Governance · July 7, 2026 · 12 min read

Walk into most M365 tenants that have been running for three or more years and you'll find the same thing: a cleanup effort in progress, or recently completed, or just about to be scoped. Teams workspaces nobody remembers creating. SharePoint sites from projects that closed before half the current team was hired. Guest accounts from vendors, contractors, and partners who finished their work and moved on. Their access didn't.

The cleanup gets funded, it gets done, and six months later the tenant is roughly back to where it was. Not because the work was poor. Because a cleanup is a one-time correction applied to a system that never stopped accumulating. You cleared the backlog. The backlog started over.

> "Inactivity means nobody posted. It does not mean nobody can access. It does not mean the guest access expired. It does not mean the sharing links stopped working. And it absolutely does not mean the SharePoint site stopped being an exposure surface."

The only way to change that math is lifecycle: treating every workspace, group, and automation as something with a defined end, not an indefinite default. Not a better cleanup process. A model where resources have to prove they're still needed, or they don't stay active.

## 01. The Five Erosion Patterns

M365 tenants don't fall apart randomly. They fall apart in ways that are entirely predictable once you've seen enough of them. The same failure patterns show up across organizations of different sizes, industries, and maturity levels. They're not caused by admin mistakes. They're caused by how the platform is built. Creation is fast and easy. Retirement is slow and manual. The gaps that result are structural, not accidental.

01 **Sprawl**

Resources multiply faster than anyone manages them. Teams, groups, sites, channels, plans, shared chats, agents. Each one created for a real reason at the time, most of them never formally retired. Restrict creation through one path and it reappears through another. The platform has too many creation surfaces for any single policy to cover them all, and most organizations discover this after the fact.

Root cause: Creation is fast and distributed. Cleanup is slow and centralized.

02 **Sharing Drift**

A workspace starts clean and gradually accumulates access at the file and folder level: links shared quickly, inheritance broken for a one-off request, a document shared to an external partner that never got cleaned up. No single moment causes it. Time does. Every collaboration event deposits a small amount of access that nobody explicitly removes, and over months it compounds into a permission state nobody designed.

Root cause: Sharing happens at file level. Governance applies at site level. The gap between them is where drift lives.

03 **Exfiltration Pathways**

Data leaves through legitimate channels: sync clients, email attachments, Power Automate flows, third-party integrations. It leaves in ways that are indistinguishable from normal business activity until something goes wrong. The problem isn't that these pathways exist. It's that most organizations can't tell you which ones were approved, who approved them, and whether the approval is still valid. Intent and access diverge silently over time.

Root cause: Integration is a feature, not a risk. Most orgs treat it that way until it isn't.

04 **Ownerless Resources**

When the person who created a workspace leaves, the workspace stays. The SharePoint site keeps serving files. The guest accounts they invited keep authenticating. The flow they built keeps running. Identity offboarding closes the account. It almost never closes the resource graph the account was responsible for. That gap is where ownerless workspaces come from. Not negligence, just a process that was never designed to look beyond the user object.

Root cause: Offboarding ends at the account. The resource graph stays open.

05 **AI Exposure**

Copilot doesn't create new access problems. It makes the ones you already have impossible to ignore. A three-year-old procedure document sitting in a forgotten SharePoint site becomes a Copilot result. Outdated policy language gets surfaced in employee queries. Sensitive data from completed projects shows up in responses to routine questions. The content was always there. AI just removed the effort required to find it, and removed the friction that was quietly masking the governance gap. More on this in Part 4.

Root cause: AI queries what permissions allow. Stale content is just as reachable as current content.

These five don't stay separate. Sprawl creates more locations for sharing drift to accumulate. Sharing drift makes the overpermission surface larger. Ownerless resources mean nobody cleans any of it up. And when Copilot arrives, it queries everything that drift and sprawl left accessible, surfaces it instantly, and exposes in seconds what manual discovery would have taken weeks to find, if anyone was even looking.

## 02. Teams Sprawl: It's an Architecture Problem, Not a User Problem

The conversation about Teams sprawl almost always goes the same direction: someone says users are creating too many workspaces and the fix is restricting creation. That's the wrong diagnosis. The problem isn't that people create workspaces. It's that the platform never asks whether they still need them.

When someone creates a Team, they're not just creating a chat window. The underlying Microsoft 365 group brings a SharePoint site, a mailbox, a Planner board, a OneNote notebook, and increasingly an AI surface. Each of those inherits the same membership and permission state. When the project ends and nobody archives the workspace, all of those surfaces stay live. Files stay accessible. Guests stay in the membership. Sharing links keep resolving. The workspace gets quiet. The access doesn't.

Restricting Team creation in the Teams admin center doesn't close that loop. Users create M365 groups through Outlook, Planner, Viva Engage, and a half-dozen app integrations that all provision the same underlying primitives. The creation surface is too broad for any single restriction to contain. The answer isn't to lock the front door more aggressively. It's to build in an end state so the accumulation can't continue indefinitely.

> ⚠️ **The Naming Policy Trap:** **Naming policies feel like governance because they produce visible order.** A consistent prefix looks like control. It isn't. A well-named Teams workspace with no verified owner, stale guest access, and a SharePoint site full of anyone-with-the-link files is exactly as risky as an identically named one. Naming tells you the name. It tells you nothing about ownership, membership currency, or permission state. It's the governance equivalent of organizing the silverware drawer while the front door is unlocked.

## 03. The Lifecycle Model That Actually Scales

Lifecycle governance treats workspaces, groups, and automations like assets, not indefinite resources. Every asset has a start state, an active use phase, a review trigger, and an end-of-life event. The model doesn't rely on humans remembering. It operates on time and on event triggers. The only human decision required is re-attestation: confirm the asset is still needed, or it transitions to the next state automatically.

Active

In use. Owner confirmed.

Resource is in active use. Owner is verified. Membership is current. Guest access is within an unexpired review window. The resource is producing value and its permission state is intentional.

Trigger: Creation → requires owner assignment and purpose documentation before provisioning completes

Review

Lifecycle window triggered.

Activity threshold crossed or review window reached. Owner receives attestation request. No response within window means automatic transition to next state, not an extension. Reviewers must confirm relevance, not just existence. Guest-specific reviews run in parallel on a shorter cadence.

Trigger: 90-day inactivity OR renewal window expiry → owner attestation required

Expired

No owner response.

Owner did not respond to attestation within window. Resource transitions to expired state automatically. Access is restricted. Owner escalation goes to defined fallback (manager, department head, IT queue). No one-click extension available. Someone must make an active decision about the resource before it is restored or proceeds to archive.

Trigger: No response → access restriction + escalation to defined fallback owner

Archived

End of life. Read-only.

No decision made within escalation window. Resource is archived: read-only, external access removed, no new content can be added. Data is retained per retention policy but the resource is no longer an active authorization surface. Restoration requires a deliberate decision and a new owner assignment.

Trigger: Escalation window expires → auto-archive, external access removed, retention policy applied

## 04. Inactivity Is Not Safety — The Risk Persistence Problem

This is the assumption that kills more M365 governance programs than any other: if nobody is posting, nothing bad can happen. The UI gets quiet. The risk doesn't.

What "Inactive" Actually Means Across the Asset Graph

| Signal | What It Indicates | What It Does NOT Indicate | Risk While Inactive |
| --- | --- | --- | --- |
| **No messages in 90 days** | No Teams channel activity | Files not accessed, guest access expired, sharing links inactive | Persistent |
| **No SharePoint activity** | No file views or edits via SharePoint UI | Files not accessed via sync client, OneDrive, or direct link | Underreported |
| **No owner login in 60 days** | Owner account inactive | Group policies are enforced, reviews can run, resource is governed | Ownerless |
| **Guest account not recently active** | Guest hasn't logged in recently | Guest access revoked, guest cannot authenticate, membership removed | Access Persists |
| **No DLP hits in reporting period** | No policy-detected data movement | Data hasn't moved via sync client, email attachment, or external app connector | Blind Spot |

> 🛑 **The Compounding Effect:** **These patterns amplify each other in a specific sequence.** Sprawl creates more places for sharing drift to accumulate. Sharing drift creates more files with overly broad permissions. Ownerless resources ensure those files never get reviewed. Copilot then surfaces them instantly to anyone with tenant access. Each pattern alone is manageable. Together, they make your existing authorization debt discoverable at AI speed before you've had a chance to clean it up. The right time to address lifecycle was before Copilot was deployed. The second best time is before you expand Copilot access to more users.

## 05. Lifecycle Closes Both Loops: Groups AND Guests

The guest problem from Part 1 of the Identity series and the lifecycle problem here are the same problem expressed at different layers. A guest account lifecycle and a group lifecycle both need to be managed, and they're not the same event. Removing someone from a group and disabling their account are two separate steps that do not automatically trigger each other.

👤

**Guest is added to a group for a project**

Invited by an owner. Correct process, intentional access. The project starts.

📅

**Project ends. Nobody initiates offboarding.**

The relationship is over but neither the guest account nor the group membership has an expiration trigger. The system has no context for "this was project-scoped."

🚪

**Group owner leaves the organization**

Owner account is disabled as part of standard offboarding. Group transitions to ownerless state. Nobody detects this because resource lifecycle isn't wired into offboarding workflows.

🔇

**Workspace goes quiet. Inactivity detected.**

90-day inactivity threshold fires. But there's no owner to send the attestation to. The review bounces. The system extends the deadline. Nothing changes.

🤖

**Copilot surfaces the content**

Someone in the organization asks Copilot a question related to the project domain. It returns results from the SharePoint site, which the guest can still access, because their membership was never removed and the site's permissions were never reviewed. The authorization model preserved state perfectly. The state was wrong.

Closing this loop requires two parallel tracks: group lifecycle (does the resource still need to exist, and who is responsible for it?) and guest account lifecycle (does this external identity still have a legitimate reason to authenticate to your tenant?). Access reviews handle membership. Expiration policies handle accounts. Both need to run. Both need enforced outcomes on non-response.

---

## → Practical Checklist

**Enable Microsoft 365 Group expiration policy** Set a renewal window (90, 180, or 365 days depending on your organization's tolerance). Require owner re-attestation. Configure the outcome for non-response: auto-delete for groups past a threshold, or archive and escalate. Without this, groups accumulate indefinitely.

**Wire resource lifecycle into the offboarding workflow** When a user is disabled, surface every group they own as sole owner before the account closes. Force reassignment as a blocking step. This is the single most impactful change most organizations can make to reduce ownerless resource accumulation.

**Set sharing link expiration across SharePoint and OneDrive** Anonymous links: maximum 30 days. Anyone-with-link: enforce expiration at tenant level. Review inherited anyone-with-link files on sites that have been inactive for 90 days. These links survive workspace inactivity and are the most common source of unintended external exposure.

**Separate guest account lifecycle from group lifecycle** Access reviews remove guests from groups. Expiration policies disable guest accounts. Both are necessary. Run guest access reviews on a 90-day cadence with removal as the no-response outcome. Set guest account expiration at 180 days with active renewal required.

**Inventory ownerless groups before expanding Copilot access** Run a Graph query against your tenant: all Microsoft 365 groups with zero or one owner. This is the baseline of your Copilot readiness problem. Every ownerless group with a SharePoint site is an authorization surface Copilot will traverse with no governance layer to constrain it.

**Design lifecycle reviews that are answerable, not just schedulable** Include resource purpose, last active date, member count, and guest count in review notifications. Reviewers can't make informed decisions about resources they don't recognize. Context is what separates a meaningful review from a box-checking exercise.

## → The Takeaway

Lifecycle works where cleanup campaigns don't because it doesn't depend on anyone remembering to schedule the work. Time passes, a review window fires, someone confirms the resource is still needed or it moves toward archive. The accumulation can't continue unchecked because the model doesn't allow indefinite defaults. That's the difference. Not effort, not intent, just whether the system has a defined end or not.

Sprawl, sharing drift, exfiltration pathways, ownerless resources, and AI exposure. None of these require anything to go wrong. They're the natural output of a platform that creates easily and retires reluctantly. Lifecycle governance doesn't eliminate them. It removes the conditions that let them stack up quietly for years before anyone has to deal with them.

The next post takes the AI exposure pattern and examines it directly: what Copilot readiness actually requires, why it's a governance audit most organizations haven't completed, and why the organizations that have already cleaned up their authorization model are significantly better positioned than the ones that are trying to do it after deployment.
