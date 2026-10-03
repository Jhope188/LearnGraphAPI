---
title: "Big Drop. Bigger Gaps Found."
description: "What changed in the latest CA Policy Analyzer update and how to use it to validate exclusions, gaps, and policy coverage faster."
series: "conditional-access"
published: "2026-05-07"
canonical_url: "https://conditionalaccess.tech/articles/conditional-access/ca-policy-analyzer/ca-policy-analyzer-update.html"
source: "catech-branded/conditional-access/ca-policy-analyzer-update.html"
---
# Big Drop. Bigger Gaps Found.

*CA Policy Analyzer — Release Update — May 2026*

Four major additions to the CA Policy Analyzer: persona-based coverage mapping, GitHub import for two popular Zero Trust frameworks, a Zero Trust baseline diff, and a rebuilt scoring engine. All live, all browser-based, no install required.

Conditional Access · May 2026 · Free Tool

You pull down a Conditional Access framework and have no idea if you forgot a setting or if you're even working from the latest best practices. Today the next step is making sure the personas are protected too. This is a deep framework that makes sure every person in the org is accounted for and limited by Conditional Access to the resources they actually need on devices that are allowed to touch company data.

I was recently a guest on the **Not Another Tech Podcast**, where we dug into exactly that problem. Before we get into the changelog, watch the episode. It covers how I think about CA at scale, some of the gaps I see repeatedly across customer environments, and a walkthrough of the tool itself.

## 00. Not Another Tech Podcast

▶ Watch Episode 11 — Conditional Access: Some Assembly Required — with Nate, Andy, Steve & Jon Hope

[Not Another Tech Podcast · Episode 11 — Click to watch on YouTube](https://youtu.be/nSAEzmWoutk)

During that conversation, Nate, Identity and SecOps Lead at **Threatscape**, raised something that stuck with me. He made the case that the real question isn't "do you have MFA policies" — it's "which personas have which controls enforced." Persona-based CA is how Threatscape structures their deployments, and it's a model that makes the coverage question answerable. Admins, standard users, guests, workload identities. Distinct populations with distinct risk profiles, and most tenants can't answer coverage questions per persona without manually working through every policy.

> "The question isn't whether you have MFA policies. It's whether the right controls are enforced for every identity persona in your tenant."

He also wanted the ability to **import directly from a real-world CA framework on GitHub**, rather than comparing against a generic template set. Both of those ideas are in this release.

## 01. Tool Walkthrough

▶ Watch CA Policy Analyzer — Full Feature Walkthrough (May 2026 Update)

[CA Policy Analyzer Walkthrough — Click to watch on YouTube](https://youtu.be/sSwVG03IqDY)

## 02. What's New

Updated

**Gap Analysis & Persona Baselines — Major Overhaul**

The template library was rebuilt around the persona model. Templates are now organized by identity type so you can see whether each persona population (admins, standard users, guests, workload identities) has the expected controls in place. Matching logic was tightened and partial match scoring was recalibrated across all 39 templates. This is the foundation the new Personas tab builds on.

Templates Tab

New

**Zero Trust Persona × Control Coverage**

The feature that came directly out of Nate's feedback. A cross-referenced matrix of your major user personas against the core CA control categories: MFA enforcement, authentication strength, device compliance, sign-in risk, legacy auth block, and more. **Shows exactly where you have coverage, where you have gaps, and where controls exist but are partial**, per persona. No more inferring coverage from a flat findings list.

New Tab — Personas

New

**Diff Against a Zero Trust Baseline**

Pulls in one of the two community CA frameworks below and runs a structural diff against your tenant's current policies. Not a score, not a checklist — an explicit line-by-line comparison of **what the framework requires versus what you have configured**. Each gap is explained with remediation guidance. Particularly useful when you're doing a customer-facing review and need to show your work, not just hand over a number.

New Tab — Baseline Gap

New

**Zero Trust Logic & Scorecard**

The scoring model was rewritten with **three weighted pillars**: CIS Benchmark Alignment (50 pts), Template Coverage (25 pts), and Configuration Quality (25 pts). CIS is the dominant factor because it's the most defensible baseline. The Configuration Quality pillar applies per-severity deductions with caps per category, so findings move the score meaningfully without collapsing it. The scorecard now shows which pillar is dragging the number and why.

Scoring Engine

## 03. GitHub Import — Two Frameworks

The Baseline Gap tab loads directly from two of the most-referenced community CA frameworks. One click pulls the full policy set from GitHub and diffs it against your tenant. Both are built on Claus Jespersen's persona framework, both are actively maintained.

Kenneth van Surksum

`kennethvs/cabaseline202510`

Community-maintained Zero Trust persona baseline, **refreshed quarterly**. The go-to reference for production-grade tenant hardening. Built around Claus Jespersen's framework structure with named exclusion groups, named locations, and a migration table.

[↗ GitHub](https://github.com/kennethvs/cabaseline202510)

Joey Verlinden

`j0eyv/ConditionalAccessBaseline`

Persona-based baseline aligned with Microsoft's Zero Trust guidance. Includes **67 CA policies, 33 exclusion groups, named location allow-lists**, and a full DCToolbox-style restore bundle. Regularly updated, including Agent persona support added in recent versions.

[↗ GitHub](https://github.com/j0eyv/ConditionalAccessBaseline)

> ℹ️ **Why these two:** Both frameworks are grounded in the same Claus Jespersen persona model that underpins the Personas tab, which means the diff is meaningful rather than structural noise. If your tenant is modeled after either of these baselines, or you're considering adopting one, the gap output maps directly to what you'd need to implement.

## 04. The Scoring Pillars

The old model fed everything into one bucket and returned a number. The new model separates CIS compliance, best-practice coverage, and configuration quality because they represent different things. A tenant can pass every CIS control and still have a Swiss cheese CA policy set — the three-pillar model surfaces that.

50

CIS Alignment

19 controls from CIS M365 v7. L1 controls carry 3× weight. The dominant pillar because CIS is the most defensible baseline in the field.

25

Template Coverage

Priority-weighted across 39 best-practice templates. High-priority controls (MFA, legacy auth block, device compliance) contribute more than optional hardening.

25

Config Quality

Starts at 25. Per-severity deductions with category caps. Two critical findings won't zero the pillar, but they will move it hard.

## 05. Try It

Runs entirely in your browser. No install, no backend, no data leaves your machine. Connects to Microsoft Graph with your own delegated credentials and reads your CA policies directly. Minimum role to run it is **Security Reader** once an admin has granted tenant-wide consent.

[↗ jhope188.github.io/ca-policy-analyzer](https://jhope188.github.io/ca-policy-analyzer) [↗ GitHub Source](https://github.com/Jhope188/ca-policy-analyzer)

Connect, run analysis, then start with the **Personas** tab if you want the coverage map, or **Baseline Gap** if you're doing a customer review. Dashboard gives you the score breakdown. CIS and Templates tabs sit behind the numbers.
