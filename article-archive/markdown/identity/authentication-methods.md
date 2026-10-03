---
title: "Authentication Methods"
description: "From SMS OTP to phishing-resistant MFA. Understanding the full range of Entra authentication methods and when each one matters."
series: "identity"
published: "2026-05-25"
canonical_url: "https://conditionalaccess.tech/articles/identity/authentication-methods.html"
source: "catech-branded/identity/authentication-methods.html"
---
# Authentication Methods

*Identity Security Series — Part 2 of 5*

Not all locks are created equal. The method you use to prove your identity determines what attacks you're vulnerable to — not just whether you're secure or not.

Entra Authentication · May 26, 2026 · 9 min read

In the last post we established that identity is your perimeter and MFA is the deadbolt. But we skipped over something important: not all deadbolts are the same. A combination lock, a keyed padlock, a high-security deadbolt, and a biometric lock all keep the door closed. They don't all keep a determined attacker out.

Authentication methods work exactly the same way. The question isn't just "do you have MFA?" It's what kind of MFA, and what does it actually fail against.

> "Most organizations think they have MFA. What they actually have is the illusion of MFA — methods that stop casual attacks but fail the moment a threat actor is paying attention."

## 01. The Lock Analogy, Extended

In the physical world, we understand intuitively that locks have different failure modes. A padlock fails to bolt cutters. A combination lock fails to someone watching over your shoulder. A key fails when someone makes a copy. We don't treat all locks as equally secure just because they all "lock."

Authentication methods have the same structure. Each one fails against a specific class of attack. Understanding that isn't a technical exercise — it's the same risk judgment you already apply to your front door.

🔓

**Password only** The combination lock on a school locker. Anyone watching over your shoulder has everything they need. Spray it across a breach database and it works everywhere the user reused it.

Fails to: phishing, spray, breach replay

📱

**SMS / Voice OTP** A key you can copy. The code exists somewhere in transit — the phone network — and can be intercepted. SIM swapping moves the number to an attacker's device. Real attacks, not theoretical ones.

Fails to: SIM swap, SS7 intercept, real-time phishing

🔢

**OATH TOTP (authenticator app codes)** A key stamped "Do Not Duplicate." Harder to copy, but the code is still a code. A convincing fake login page captures it in real time and replays it before it expires. Phishable.

Fails to: real-time phishing, adversary-in-the-middle

🔔

**Microsoft Authenticator push + number matching** A high-security deadbolt. Number matching broke the MFA fatigue attack — you can't approve a push you didn't initiate by accident. Still not phishing-resistant but significantly harder to abuse.

Fails to: sophisticated AiTM phishing at scale

🔐

**FIDO2 / Windows Hello for Business / Passkeys** The biometric lock. The credential is cryptographically bound to the specific origin it was created for and never leaves your device. A fake login page gets nothing useful. Cannot be phished. Full stop.

Phishing-resistant

## 02. The Full Spectrum

Here's the full picture across every method Microsoft supports in Entra today. Two things to read in this table: how phishable the method is, and what the real-world friction looks like once it's deployed. The counterintuitive finding is that the most secure methods aren't always the highest friction — which matters when you're planning a migration.

Authentication Methods — Entra ID Reference

| Method | Phishable? | SIM / Intercept Risk | User Friction | Entra Policy Name |
| --- | --- | --- | --- | --- |
| **Password only** | Yes | N/A | Low to set, high to manage | Legacy auth |
| **SMS / Voice OTP** | Yes | Yes | Low | SMS |
| **OATH TOTP (app codes)** | Yes | No | Medium | Software OATH token |
| **Authenticator push** | Reduced | No | Low | Microsoft Authenticator |
| **Authenticator + number matching** | Harder | No | Low | Microsoft Authenticator |
| ⚠ Phishing-Resistant Line  Methods below cannot be intercepted or replayed |  |  |  |  |
| **CBA (Certificate-Based Auth)** | No | No | Medium-High | Certificate-based authentication |
| **FIDO2 security key** | No | No | Medium (hardware required) | FIDO2 security key |
| **Windows Hello for Business** | No | No | Very low once enrolled | Windows Hello for Business |
| **Passkeys** | No | No | Low | Passkey (device-bound / synced) |

## 03. The Phishing-Resistant Line

That dividing line in the table is the most important concept in this entire post. Everything above it can be intercepted by a convincing fake login page. Everything below it cannot — and the reason is worth understanding, because it's not magic.

When you register a FIDO2 key or Windows Hello credential, the private key is generated on your device and never leaves it. When you authenticate, your device performs a cryptographic challenge-response that is **bound to the exact origin** it was created for. A fake Microsoft login page receives a challenge from a different origin. The credential refuses. The attack gets nothing useful.

The physical world equivalent: imagine a master key that only works on one specific door in the entire world, and the lock verifies the key is genuine before opening. You cannot trick it with a replica door. The credential knows the difference.

> ✅ **Phishing-Resistant — What It Actually Means:** Phishing-resistant authentication methods (FIDO2, WHfB, CBA, Passkeys) use **asymmetric cryptography bound to the authenticating origin**. The private key never leaves the device. There is no code, no token, no credential to intercept in transit. An adversary-in-the-middle attack captures nothing of value. This is fundamentally different from "harder to phish" — it is architecturally impossible to phish.

> ℹ️ **Certificate-Based Authentication — Quick Note:** CBA sits in the same phishing-resistant tier as FIDO2 and WHfB and is the right answer for government, healthcare, and regulated environments already running smart card or PKI infrastructure. For most SMB and MSP environments without that foundation already in place, FIDO2 and passkeys are the more practical path. If your org issues PIV cards or has an existing PKI — CBA is worth a serious look. If it doesn't — keep moving.

## 04. The Number Matching Moment

Before we get to the migration, this one deserves its own section because it's recent, it's actionable, and it changed something real.

MFA fatigue attacks became a mainstream threat after a handful of high-profile breaches demonstrated the pattern: an attacker obtains a valid username and password, then hammers the target's phone with Authenticator push notifications at 2 AM until a tired or confused user approves one. Simple. Effective. Devastatingly low-tech.

> ⚠️ **MFA Fatigue — How It Works:** The attacker has your credentials. They don't need your MFA code. They just need you to approve a push notification you didn't initiate. Spam enough of them and eventually someone approves one — by accident, by confusion, or by frustration. **Number matching removes that attack surface entirely.** The user must type a number shown on the sign-in screen into the Authenticator app. You cannot approve a push you didn't initiate because you don't have the number to type.

Microsoft enabled number matching by default across Authenticator in 2023. If your tenant predates that rollout and you haven't verified the setting, check it today. It costs nothing, requires no hardware, and eliminates one of the most common attack patterns against MFA-enabled organizations.

## 05. The Config Problem Most Tenants Don't Know They Have

Here's the practitioner reality that doesn't show up in most documentation: **most tenants have two places where authentication methods are configured**, and they frequently contradict each other.

The **unified Authentication Methods Policy** lives under Entra ID Protection and is where all modern method configuration should happen. It gives you per-method control, group-based targeting, and a single source of truth. This is the right place to work.

The **legacy MFA portal** predates the unified policy and still exists in most tenants that predate 2022. It was the only option before the unified policy existed. Many organizations configured it years ago and haven't touched it since. The problem is that when both are active, they can silently override each other — a method you disabled in the unified policy may still be available because a legacy setting allows it, or a method you enabled isn't working because an old legacy block is still in place.

> 🛑 **Critical — Audit Before You Migrate:** **Before you change any authentication method configuration, audit both locations.** Entra Admin Center → Protection → Authentication Methods is the unified policy. The legacy portal is accessible via the old per-user MFA admin page. The migration path is to consolidate everything into the unified policy and disable the legacy settings — not manage both in parallel. Running both creates unpredictable behavior and makes troubleshooting a genuine pain. Your IT team needs to check this before any phishing-resistant rollout will be reliable.

---

## → The Migration Ladder

You're not starting from zero. Most organizations have a mix — some users on SMS, some on the Authenticator app, a handful with hardware keys, and a long tail of legacy methods that nobody has cleaned up. The migration isn't a single step. It's a ladder, and the rungs matter.

1

**Get Everyone Off SMS and Voice OTP**

This is the most common attack surface and the easiest win. SMS and voice OTP are the methods most frequently abused in real-world attacks. They're also the methods most organizations enabled first because they required no hardware and users understood them. That logic made sense in 2018. It doesn't hold now. Migrate these users to Authenticator push first — same friction, significantly better security posture.

2

**Set Authenticator + Number Matching as the Floor**

Once SMS is gone, Authenticator with number matching becomes the minimum bar for every user in the organization. It's not phishing-resistant, but it eliminates MFA fatigue attacks and it's deployable today without any hardware procurement or device enrollment dependency. Verify number matching is enforced — not just enabled — across your tenant before calling this step done.

3

**Plan Your Phishing-Resistant Rollout**

This is where most organizations pause because the options feel complicated. Hardware FIDO2 keys work but require procurement, distribution, and a backup plan. Windows Hello for Business is low-friction but depends on managed device enrollment. Passkeys are the path that finally makes phishing-resistant MFA accessible for a general user population — and that's exactly what the next post in this series covers.

## → The Takeaway

Authentication methods are not interchangeable. The method you choose determines what attacks you're exposed to, not just whether the door is locked. SMS MFA is better than nothing. It is not better than a phishing attack targeting your CFO on a Friday afternoon.

The good news is the migration path is clearer than it's ever been. Get off SMS. Put number matching on as the floor. Then plan the phishing-resistant rollout with methods that actually fit your user population — which means understanding what passkeys are, how they work, and why they finally solve the friction problem that held phishing-resistant MFA back for years.

That's next.
