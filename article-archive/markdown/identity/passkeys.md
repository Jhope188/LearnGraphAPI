---
title: "Passkeys: Security Only Works If People Use It"
description: "The strongest authentication method doesn't matter if adoption fails. What makes passkeys stick in real organizations."
series: "identity"
published: "2026-06-01"
canonical_url: "https://conditionalaccess.tech/articles/identity/passkeys.html"
source: "catech-branded/identity/passkeys.html"
---
# Passkeys: Security Only Works If People Use It

*Identity Security Series — Part 3 of 5*

Phishing-resistant authentication has been technically possible for years. The reason most organizations haven't deployed it isn't the technology. It's that security nobody will use isn't actually security.

Entra Authentication · June 1, 2026 · 9 min read

There's a version of this post that opens with statistics about phishing attacks, credential theft rates, and breach costs. You've read that post a hundred times. It doesn't change behavior. Here's a different opening.

Last year a user got a new iPhone. They logged into their password manager, their photos were already there, their apps restored, their contacts synced. They opened their work email, got prompted to authenticate, tapped Face ID, and were in. They texted their IT admin: *"Wait, that's it? That was easy."*

That moment — the "wait, that was easy" moment — is the entire argument for passkeys. Not the cryptography. Not the FIDO2 spec. Not the AAL2 compliance validation. The moment a user realizes the most secure way to log in is also the easiest way to log in is the moment adoption becomes possible.

> "Security that people won't use isn't a security win. It's a policy document waiting for a workaround."

## 01. What's Actually Changed

This conversation has shifted significantly in the last six months. As of March 2026, synced passkeys and passkey profiles reached General Availability in Microsoft Entra ID. This isn't a preview feature to pilot with early adopters anymore. It's production-ready infrastructure that's being auto-rolled into tenants that already have FIDO2 enabled.

More importantly: if your tenant is in scope, Microsoft's managed registration campaign has already started nudging users to register passkeys after MFA. Not sometime in the future. Right now. The question isn't whether your users will encounter this. It's whether you planned the rollout or whether your helpdesk is about to find out through tickets.

> ⚠️ **Action Required — Check Your Tenant:** If Passkeys (FIDO2) is already enabled in your tenant, automatic migration to passkey profiles is rolling through now, with completion expected by late May 2026. The Microsoft-managed registration campaign default is shifting from targeting Microsoft Authenticator to targeting passkeys directly, and the default user targeting is expanding from voice/text users to **all MFA-capable users**. Review your passkey profile configuration before that change reaches your tenant, not after.

## 02. Synced vs Device-Bound: The Right Tool for the Right Person

The most common objection to passkey deployment is "but what happens when a user gets a new phone?" It's the right question, and for years the honest answer was "it's complicated." Synced passkeys change that answer to "nothing, it's already there."

But synced and device-bound passkeys are not interchangeable, and treating them as such is where most deployment plans go wrong. The right model is a segmented assurance model: different credential types for different risk profiles, enforced through passkey profiles in Entra.

*For Standard Users*

☁️ **Synced Passkeys**

Stored in a password manager (iCloud Keychain, Google Password Manager, 1Password, Bitwarden) and synced across all of the user's devices. Change phones, the passkey is already there. Still FIDO2-based, still phishing-resistant, validated by NIST SP 800-63B Supplement 1 as meeting AAL2 requirements.

- Knowledge workers, general workforce
- BYOD and cross-device users
- Anyone who has ever asked "what happens with my new phone"
- The path to organization-wide phishing resistance at scale

*Assurance: AAL2 · passkeyType: synced*

*For Admins and Privileged Roles*

🔑 **Device-Bound Passkeys**

The private key is tied to specific hardware and never leaves it. YubiKeys, TPM chips, Windows Hello for Business on managed devices. Loss of the device means the credential is gone. Higher operational cost, higher assurance. The right answer for the accounts that attackers actually target.

- Global Admins and privileged role holders
- Break-glass and emergency access accounts
- Shared workstation environments
- Regulated environments requiring AAL3

*Assurance: AAL3 · passkeyType: deviceBound*

Passkey profiles in Entra are what make this split operationally real. You can require hardware-bound passkeys for your Global Admins while allowing synced passkeys for the rest of the organization, all within a single authentication methods policy. You don't need separate tenants, separate configurations, or separate rollouts. One policy, two profiles, two risk tiers handled cleanly.

## 03. The Bootstrapping Paradox

Here's the problem nobody talks about in passkey deployment guides: how does a brand new employee register a passkey when they have no prior credential to authenticate with in the first place?

It's a genuine chicken-and-egg problem. Passkey enrollment requires authentication. Authentication requires something the user already has. A new employee has nothing yet. The old answer was to set a temporary password, let them log in, then have them register their authenticator. Every step of that process is a security gap. The temporary password is a phishable credential. The setup flow is an opportunity for a social engineering attack. The transition period is where things go wrong.

> ℹ️ **The Answer — Temporary Access Pass:** **Temporary Access Pass (TAP)** is a time-limited, single-use passcode that lets a new employee register their passkey without ever setting a password. An admin generates a TAP, the user redeems it once to bootstrap their authentication setup, and the TAP expires. No persistent password in the tenant, no phishable credential left behind. This is the correct onboarding flow for a passwordless organization — and most admins haven't deployed it yet. If your onboarding process still starts with "here's your temporary password," TAP is the fix.

TAP also solves the recovery scenario. User loses their phone or their hardware key. They can't log in. You generate a TAP, they use it once to register a new passkey, and they're back. No password reset, no SMS fallback, no regression to a weaker method. The recovery path is as strong as the initial enrollment path.

## 04. The Mental Model Problem

Ask a non-technical user what a passkey is. Then ask them what a security key is. Then a hardware key. A YubiKey. Passwordless. Windows Hello. Windows Hello for Business. Phone sign-in. Authenticator. They are not the same thing. To most users, they are completely indistinguishable words that IT keeps using interchangeably.

This is not a user failure. It's a communication failure. And it's one of the biggest practical barriers to passkey adoption that doesn't show up in any technical deployment guide.

❌

**What IT says** "We're rolling out FIDO2-based phishing-resistant passkeys via the Microsoft Authenticator app and supporting device-bound credentials through Windows Hello for Business on managed endpoints."

🤔

**What the user hears** Something about passwords and Windows. There's probably a ticket to open.

✅

**What actually works** "Next time you log in, you'll tap your fingerprint instead of typing a password. That's it. It works on your phone, your laptop, and if you get a new phone, it's already there."

The "unlock" concept is what lands. Users understand unlocking their phone. They do it dozens of times a day. Passkeys are just that same gesture applied to work logins. Once the mental model clicks, the resistance largely disappears. The job of the rollout communication isn't to explain cryptography. It's to make the new thing feel familiar before anyone is asked to use it.

## 05. The Assurance Question

The most common pushback from security-conscious admins when synced passkeys came up was "but are they really as secure as a hardware key?" It's a fair question and it deserves a straight answer: no, not quite. And that's fine, because the alternative for most users isn't a hardware key. It's Authenticator push or, worse, SMS OTP.

NIST SP 800-63B Supplement 1 validated synced passkeys as meeting AAL2 requirements. That's phishing-resistant enough for general workforce use. The private key is encrypted within the cloud provider's sync fabric. Compromising a synced passkey requires compromising both the user's cloud provider account and the device. For standard users, that's a dramatically higher bar than any legacy MFA method.

> ℹ️ **The Segmented Assurance Model:** The right question isn't "which passkey type is more secure." It's "which passkey type is right for this risk profile." **Standard users: synced passkeys at AAL2.** Still phishing-resistant, deployable at scale, zero hardware logistics. **Admins and privileged roles: device-bound at AAL3.** Hardware-rooted, non-exportable, the highest assurance level available. You don't need everyone on a YubiKey. You need the accounts attackers actually target on the strongest credential available, and everyone else on something that's still phishing-resistant and that they will actually use.

---

## → Deployment Checklist

**Check your tenant's auto-migration status** If FIDO2 is already enabled, passkey profile migration is rolling now. Review MC1221452 in your Message Center. Know what your current settings will migrate into before Microsoft does it for you.

**Configure passkey profiles before auto-migration completes** Create at least two profiles: device-bound for admins and privileged roles, synced for general workforce. Use group-based targeting. Don't leave this as a single default profile covering everyone.

**Deploy Temporary Access Pass for onboarding and recovery** TAP should be the start of every new employee's authentication journey and the recovery path when credentials are lost. If your onboarding still starts with a temporary password, fix that first.

**Write user communication in unlock language, not security language** Fingerprint, Face ID, tap to log in. Not FIDO2, not phishing-resistant, not passkey profile. The technical framing is for your deployment docs. The user-facing message is "logging in just got easier."

**Plan helpdesk for the new-device scenario before rollout** The most common support request will be "I got a new phone, how do I log in?" The answer should be TAP-driven re-enrollment, not a password reset. Train your helpdesk on the flow before users encounter it.

**Require device-bound passkeys for all admin and privileged accounts** Scope a passkey profile with passkeyType: deviceBound to your Global Admin, Privileged Role Administrator, and security-sensitive groups. These are the accounts that matter most to attackers. They should have the strongest credentials available.

## → The Takeaway

Passkeys are no longer a preview feature, a future roadmap item, or something to evaluate next quarter. They're generally available, they're being auto-rolled into tenants, and the users in your organization are about to start seeing registration prompts whether you planned for it or not.

The good news is the deployment model is cleaner than it's ever been. Synced passkeys handle the scale problem — every knowledge worker with a phone or a laptop can be phishing-resistant without a YubiKey in the mail. Device-bound passkeys handle the admin problem — the accounts that actually matter to attackers get hardware-rooted credentials. TAP handles the bootstrapping problem. Passkey profiles handle the policy separation.

The only thing left is making sure users understand that the most secure way to log in is also the easiest way to log in. That's the story worth telling.
