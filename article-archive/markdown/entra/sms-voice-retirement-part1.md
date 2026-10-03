---
title: "SMS and Voice Are Retiring Still Here. Microsoft Just Stopped Paying the Phone Bill."
description: "Microsoft is not removing SMS and Voice from Entra ID. It is ending Microsoft-provided telephony. What changed on September 1, what happens February 1, 2027, and how MSPs find and move their SMS and Voice users."
series: "entra"
published: ""
canonical_url: "https://conditionalaccess.tech/articles/entra/sms-voice-retirement-part1.html"
source: "catech-branded/entra/sms-voice-retirement-part1.html"
---
# SMS and Voice Are Retiring Still Here. Microsoft Just Stopped Paying the Phone Bill.

*Authentication Methods · SMS and Voice Retirement · Part 1*

What changed on September 1, what breaks on February 1, 2027, and how MSPs find every SMS and Voice user before the passkey prompt stops being skippable.

Entra ID · Passkeys · MSP · · · Jon Hope · Microsoft MVP · Security: Identity & Access

Section 01

## Microsoft Stopped Paying for the Texts. SMS and Voice Stay.

Source: [Passkeys by default and retirement of Microsoft-provided SMS and voice](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement) · [SMS and voice retirement FAQ](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement-faq) · [MC1426371 (Message Center)](https://mc.merill.net/message/MC1426371)

I've been on more calls than I can count over the past few weeks, and the same question keeps coming up: what is actually happening with SMS and Voice in Entra? There's a misconception doing the rounds, so let me add some context.

Microsoft is retiring **Microsoft-provided telephony delivery** for SMS and Voice. The methods themselves stay in Entra ID. If you have a business, regulatory, or technical reason to keep SMS and Voice after the retirement date, you can. You configure a telephony provider through Microsoft Security Store and pay that provider for the messages and calls.

> Microsoft still enforces the policy. Someone else sends the text, and you get the invoice.

### The road beyond SMS and Voice

Most of the confusion I hear comes from people collapsing this into one date. There are five, all from Microsoft's Message Center post MC1426371, and the yellow marker shows where we are today.

![Microsoft Entra: The Road Beyond SMS and Voice. Timeline: September 1, 2026 passkey registration nudges begin. September 18, 2026 provider and pricing details. October 30, 2026 telecom provider configuration in Microsoft Security Store. February 1, 2027 Microsoft-provided SMS and Voice ends for all users except Global Admins and external users. July 1, 2027 Microsoft-provided SMS and Voice ends for Global Admins and external users.](../../images/entra/sms-voice-retirement-part1/sms-voice-retirement-part1-01.webp)
*Click to open full size. The marker moves with today's date.*

> ⚠️ **Two details the graphic can't fit:** The blocking prompt only hits users whose *only* MFA method is SMS or Voice. And "external users" in the July 1 group doesn't include internal guests. They stay on February 1.

> ⚠️ **Public cloud only:** This timeline applies to public cloud tenants. Microsoft says other cloud environments follow on a later schedule. Azure AD B2C is out of scope, and Entra External ID gets its own announcement.

Section 02

## Bring Your Own Telecom Keeps SMS Alive, With Fine Print

Source: [Choose a telephony provider for SMS and voice](https://learn.microsoft.com/entra/identity/authentication/concept-phone-providers) · [Telephony providers FAQ](https://learn.microsoft.com/entra/identity/authentication/phone-providers-faq) · [Costs and routing function](https://learn.microsoft.com/entra/identity/authentication/phone-providers-faq#how-much-does-choose-your-own-telephony-provider-cost)

Microsoft calls it Choose Your Own Telephony Provider. You pick a provider in Security Store, sign their agreement, configure them for Entra ID, and monitor the service. Entra keeps enforcing your authentication methods policy and runs the sign-in experience. The provider delivers the SMS or places the call. Private preview

### What it covers

- SMS and Voice as MFA methods, delivered by your provider
- SSPR over SMS and Voice (the retirement applies to SSPR too)
- One provider per channel: one for SMS, one for Voice
- Users migrated to the provider skip the blocking passkey prompt

### What it doesn't

- SMS sign-in as a primary method. That retires either way.
- Entra External ID and Azure AD B2C tenants
- Users you left on Microsoft-provided SMS. They still get the prompt.
- Free delivery. Pricing varies by provider, region, and usage.

Microsoft positions this for user segments with a documented requirement, and asks you to confirm a phishing-resistant method can't meet it first. For most MSP customers, that's a short list: a shared-device frontline team, a regulated workflow that mandates an out-of-band SMS. Everyone else should land on passkeys, which cost nothing extra.

> ℹ️ **MSP angle:** Setup includes deploying a **routing function in an Azure subscription** that connects Entra ID to the provider, and it carries standard Azure consumption charges on top of what the provider bills. Microsoft expects those Azure costs to be minimal next to the telephony charges, but somebody still has to own the resource. For every customer that needs SMS, decide who owns the provider contract and whose Azure subscription hosts that function before October 30, not after.

Section 03

## September 1 Already Happened in Your Tenants. Go Check.

Source: [Move users to passkeys](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement#2-move-users-to-passkeys) · [Enable passkeys (FIDO2)](https://learn.microsoft.com/entra/identity/authentication/how-to-authentication-passkeys-fido2) · [Plan a passkey deployment](https://learn.microsoft.com/entra/identity/authentication/how-to-deploy-phishing-resistant-passwordless-authentication)

Unless a tenant opted out beforehand, its SMS and Voice users were auto-enabled for passkeys on September 1 and put into a passkey profile that allows **all passkey types**. The Registration Campaign was set to Microsoft Managed, targeting passkeys. The next time those users complete MFA, they see a prompt to register a passkey. By default they can snooze it forever.

Unlimited snoozes sound harmless. They aren't, because users who snooze until February 1 hit the same prompt with the snooze button gone. Confused end users become angry end users fast, and the helpdesk ticket lands on you.

Run these against every customer tenant:

- Is **Passkey (FIDO2)** enabled, and does the passkey profile your users landed in match what you actually want? If you restrict to device-bound passkeys or specific AAGUIDs, the auto-created profile allows all types.
- Are your SMS and Voice users in a group that can actually register passkeys, or are they excluded somewhere else in the policy?
- Is the **Registration Campaign** now Microsoft Managed, and did you expect that?
- Have users been told what the prompt is before they see it? Microsoft publishes [end-user communication templates](https://aka.ms/mfatemplates) for exactly this.

Section 04

## Not Ready? Pause the Nudge Before It Becomes a Ticket Queue

Source: [Temporarily opt out of automatic passkey enablement](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement#temporarily-opt-out-of-the-automatic-passkey-enablement) · [Roy Klooster: The setting you won't find in the portal](https://rksolutions.nl/posts/microsoft-entra-passkey-dynamic-migration/)

What you do next depends on where you are with your passkey rollout. If you haven't enabled FIDO2 properly or haven't identified your SMS and Voice users, pause the automatic enablement first. Get sorted, then turn the nudge back on when you're ready for the questions.

Inforcer's own [Roy Klooster](https://www.linkedin.com/in/roy-klooster/) was one of the first people I know to write about this. The man lives in Graph, and he was quick to surface the property Microsoft uses. There's no portal toggle. It's a Graph PATCH against the authentication methods policy, and it needs Policy.ReadWrite.AuthenticationMethod.

```
PATCH https://graph.microsoft.com/beta/policies/authenticationmethodspolicy
Content-Type: application/json

{
  "optOutSettings": {
    "passkeyDynamicMigration": true
  }
}
```

> ⚠️ **Read before you run it:** This is a **beta** endpoint. The opt-out is temporary and covers the September 1, 2026 to February 1, 2027 changes only. On February 1 the standard timeline applies regardless of this setting. It buys you time. It doesn't move the deadline.

> 🛑 **Verify in each tenant:** Microsoft documents the opt-out as excluding the tenant from automatic passkey enablement and the Registration Campaign rollout. The docs don't say whether applying it *after* September 1 reverts a passkey profile or campaign state that was already changed. After you PATCH, check the passkey policy and Registration Campaign in the portal and correct them by hand if needed.

Section 05

## Nudge Is Off. Now Find Everyone Still Using SMS and Voice.

Source: [Find users enabled for SMS or Voice](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement#1-find-users-enabled-for-sms-or-voice) · [entra-sms-voice-usage-analyzer](https://github.com/microsoft/entra-sms-voice-usage-analyzer) · [CA report-only mode](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-report-only) · [Troubleshoot authentication strengths](https://learn.microsoft.com/entra/identity/authentication/troubleshoot-authentication-strengths)

This is where most of the questions are sitting right now. There are three ways in. I use all of them, because each one catches people the others miss.

### Microsoft's analyzer script

Microsoft publishes a [PowerShell script](https://github.com/microsoft/entra-sms-voice-usage-analyzer) for this. It needs Global Reader, Authentication Policy Administrator, or Security Reader. Microsoft's own guidance is blunt: any non-zero result means the tenant is in scope.

### Daniel Bradley's Authentication Methods report

[Daniel Bradley](https://www.linkedin.com/in/danielbradley2/)'s free, interactive [Entra Authentication Methods report](https://lnkd.in/e_yB23Ki) is a great place to start.

### Authentication Strength + Conditional Access, in report-only

There's also a native approach that works well for catching the people who are actually signing in with SMS and Voice. Big shoutout to [Nathan McNulty](https://www.linkedin.com/in/nathanmcnulty/) for the idea.

1

Build a custom authentication strength with SMS and VoiceThis is how you detect it. Include only the SMS and Voice combinations and leave out every other MFA method, so any successful sign-in against this strength is a signal SMS or Voice is still in use.

2

Create a CA policy in report-onlyAll users (exclude break-glass), all resources, grant with *Require authentication strength* set to the strength from step 1.

3

Let it collect sign-insReport-only evaluates on every sign-in and enforces nothing, so users see no change.

4

Read the resultsUse the policy impact view or the Report-only tab in the sign-in logs. The Authentication Details tab shows the method used, so you can confirm the SMS and Voice sign-ins.

When you're ready to enforce, the same policy moves from report-only to on. You've already done the testing. I walk through all of this in the video in section 07.

Section 06

## Still Need More? Bring in the Big Guns.

Source: [Jan Bakker: A guide to stay calm](https://janbakker.tech/passkeys-by-default-and-retirement-of-microsoft-provided-sms-and-voice-authentication-a-guide-to-stay-calm/) · [Threatscape prep content](https://lnkd.in/eNiPyvcH) · [Kenneth van Surksum deep dive](https://lnkd.in/ec5fT4eS)

I didn't figure all of this out alone. These are the resources I've gone back to most while working through it.

The definitive guide

### [Jan Bakker](https://www.linkedin.com/in/jan-bakker/)

My go-to throughout this whole process. I appreciate the calm, steady approach he takes to the entire timeline.

[Read on janbakker.tech](https://janbakker.tech/passkeys-by-default-and-retirement-of-microsoft-provided-sms-and-voice-authentication-a-guide-to-stay-calm/)

For video people

### [Ru Campbell & Threatscape](https://www.linkedin.com/in/rlcam/)

Solid prep content covering what you need to know, if you'd rather watch than read.

[Watch the prep content](https://lnkd.in/eNiPyvcH)

The technical deep dive

### [Kenneth van Surksum](https://www.linkedin.com/in/kennethvansurksum/)

An in-depth look at the entire situation. Grab a coffee before you start. It's thorough.

[Read the deep dive](https://lnkd.in/ec5fT4eS)

Section 07

## The Passkey Rollout, With a Side of Ramble

Source: [conditionalaccess.tech on YouTube](https://youtu.be/GdrHX0T95pw) · [Plan a passkey deployment](https://learn.microsoft.com/entra/identity/authentication/how-to-deploy-phishing-resistant-passwordless-authentication)

If you're OK listening to me ramble a bit, I walk through the passkey rollout end to end: finding the users, the Authentication Strength approach, and what the experience looks like from the user's side.

Video not loading? [Watch it on YouTube](https://youtu.be/GdrHX0T95pw).

Closing

## Stop Planning Around September 1. Plan Around February 1.

Source: [After retirement](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement#5-after-retirement) · [Are customers going to get locked out?](https://learn.microsoft.com/entra/identity/authentication/concept-sms-voice-retirement-faq#are-customers-going-to-get-locked-out-of-their-accounts-on-the-retirement-date) · [MC1426371 (Message Center)](https://mc.merill.net/message/MC1426371)

Nobody gets locked out on February 1. Microsoft is clear on that. What happens instead is quieter and, for an MSP, more expensive: every user still relying on Microsoft-provided SMS or Voice gets a passkey registration prompt they can't skip, on whatever device they happen to be holding, on a Monday morning. There's no opt out for that behavior.

The telephony provider option doesn't open until October 30, and it's still in private preview. Microsoft's Message Center post recommends finishing setup **at least 4 weeks before February 1**, which puts the real target at January 4, 2027. That's about nine weeks after configuration opens, with the holidays in the middle, to pick a provider, sign a contract, and migrate the users who need one. If you're waiting to see what the preview looks like before deciding, you've already used a chunk of that window.

[Part 2](https://conditionalaccess.tech/articles/entra/sms-voice-retirement-part2.html) picks up from here: what went wrong after September 1, and what SMS costs now.
