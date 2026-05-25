# Microsoft Entra Registration Campaign — Snooze Cadence & Configuration

## Sources

| Source | Type | URL |
|---|---|---|
| MS Learn — Registration Campaign | Official Microsoft Documentation | [link](https://learn.microsoft.com/entra/identity/authentication/how-to-mfa-registration-campaign) |
| MS Learn — Authentication Methods Activity Report | Official Microsoft Documentation | [link](https://learn.microsoft.com/entra/identity/authentication/howto-authentication-methods-activity) |
| MC1279092 — Passkeys in Registration Campaigns Update | Official Microsoft Message Center (via DeltaPulse) | [link](https://deltapulse.app/item/MC1279092) |
| Daniel Bradley — Registration Campaign Delays Explained | Community / Microsoft MVP Blog | [link](https://ourcloudnetwork.com/microsoft-entra-passkeys-registration-campaign-delays-explained/) |
| Daniel Bradley — Free Interactive Entra Authentication Methods Report | Community / Microsoft MVP Blog | [link](https://ourcloudnetwork.com/create-a-free-interactive-entra-authentication-methods-report/) |

---

## How the Snooze Cadence Actually Works

The snooze duration is **time-based, not MFA-attempt-based**.

> *"Days allowed to snooze sets the period between two successive interrupt prompts. For example, if it's set to 3 days, users who skipped registration don't get prompted again until after 3 days."*
> — MS Learn

**This means:** if you set 3 days, the user will not see the nudge again for 3 calendar days regardless of how many times they sign in with MFA during that period. After 3 days have elapsed, the nudge will appear on their **next MFA sign-in**.

**The trigger sequence is:**
1. User completes MFA sign-in
2. Nudge appears
3. User clicks "Skip for now" → snooze clock starts
4. User is **not nudged again** until both conditions are true:
   - The configured number of days has elapsed
   - The user performs another MFA sign-in

---

## Snooze Configuration Options

| Setting | Range / Values | Default | What it Does |
|---|---|---|---|
| `snoozeDurationInDays` | 0–14 days | **1 day** | Calendar days before the next nudge after a skip. If set to **0**, user is nudged on **every MFA attempt** |
| `enforceRegistrationAfterAllowedSnoozes` | true / false | **true** | If true: user is forced to register after 3 snoozes. If false: user can snooze indefinitely and never be forced |
| Limited number of snoozes (portal) | Enabled / Disabled | — | Enabled = max 3 skips then forced. Disabled = unlimited skips forever |

---

## Does Microsoft Recommend Setting to 0 or 1?

**Honest answer: No explicit recommendation for 0 or 1 is stated in the MS Learn documentation.**

What MS Learn does state:
- The **default is 1 day**
- Setting to **0** means the user is prompted on **every single MFA attempt** until they register
- The **example JSON samples** throughout the documentation all use `"snoozeDurationInDays": 1`

The use of `1` in all sample configurations implies it as the Microsoft-suggested starting point, but there is no explicit statement in the docs saying "we recommend 0 or 1." The documentation describes the behaviour and leaves the choice to the admin.

> ⚠️ **This is important to be accurate about with clients** — if you advise "Microsoft recommends 0 or 1," that is not directly supported by the MS Learn page. The correct framing is: *Microsoft defaults to 1 day and uses 1 day in all sample configurations. In practice I always left this to 1*

---

## Practical Implications by Snooze Duration

| Setting | Real-World Cadence | Risk |
|---|---|---|
| 0 days | Prompted on every MFA sign-in until registered | High friction — user sees it daily if they sign in daily |
| 1 day (default) | Prompted next sign-in after 24hrs has elapsed | Reasonable pressure |
| 3 days | Prompted next sign-in after 3 calendar days — could easily be 1–2 weeks if user doesn't sign in frequently | Low pressure, slow adoption |
| 14 days | Maximum delay — user could go 2 weeks between nudges | Very slow, not recommended for active campaigns |

---

## What Happens After 3 Snoozes

If **Limited number of snoozes** is **Enabled**:
- After 3 skips, registration is **required** at next sign-in — the user cannot proceed without completing setup
- Closing the browser counts the same as a snooze — the counter still applies

If **Limited number of snoozes** is **Disabled**:
- Users can skip indefinitely and will **never** be forced to register

> **MS Learn default for `enforceRegistrationAfterAllowedSnoozes` is `true`** — enforcement after 3 snoozes is on by default.

---

## What Suppresses the Nudge Entirely

These will silently prevent the nudge from appearing regardless of your configuration:

- CA policy blocks access to the **Register Security Information** page
- A **Terms of Use** screen is shown during sign-in
- **CA custom controls** redirect the user during sign-in
- User is in an active **SSO session** (no fresh MFA required)
- User is signing in on **Android or iOS mobile** — nudge is not supported on mobile
- User just completed MFA registration in the **same sign-in session**

---

## Key Gaps Not Covered in MS Learn

- No explicit Microsoft recommendation for a specific snooze value beyond using `1` in all samples
- No guidance on what snooze value is appropriate for different user populations (e.g. high-frequency vs low-frequency sign-in users)

---

## Admin Recommendation — Choosing Your Snooze Duration

Microsoft does not prescribe a single correct snooze value. Admins should consider their own environment, user sign-in frequency, and tolerance for friction before deciding. The following guidance is based on the available configuration options and practical implications:

- **For most organisations, 1 day with Limited Snoozes enabled is a sensible starting point.** It mirrors the Microsoft default, keeps pressure consistent without feeling aggressive, and enforcement kicks in after 3 skips.
- **For faster campaigns** (e.g. a defined rollout window or high-risk user populations), consider **0 days** — users are nudged on every MFA sign-in until they register. This is the most aggressive option and should be used with clear user communication to avoid help desk load.
- **Avoid values of 7 days or higher** for active campaigns — users who sign in infrequently may not be nudged for weeks, making adoption tracking very slow.
- **The snooze duration is a tenant-wide setting** — you cannot set different values for different user groups. Factor this in if you have a mix of power users and occasional users in scope.

> ⚠️ Whatever value you choose, **monitor progress actively**. Don't set it and forget it.

### Monitoring Authenticator Registration Progress

Admins should track campaign effectiveness using the **Microsoft Entra Authentication Methods Activity report**, available at:

**Entra ID > Authentication Methods > Activity**

The Registration tab provides:
- **Users capable of MFA** — how many users have a strong authentication method registered and enabled by policy
- **Users registered by authentication method** — breakdown per method including Microsoft Authenticator, FIDO2, TAP, etc.
- **Recent registration by authentication method** — succeeded and failed registrations over time, filterable by method
- **User registration details** — per-user view showing MFA capable status, passwordless capable status, and every registered method

> 📌 **Note:** The report updates for most users within 36 hours. A Microsoft Entra ID P1 or P2 licence is required to access the Usage and Insights reporting. Per MS Learn, this is the recommended dashboard to measure and drive adoption progress.

For deeper analysis, registration events can also be found in the **Sign-in logs** (filter by MFA required) and exported to Microsoft Sentinel or a SIEM for longer retention beyond the 30-day default.

---

## Upcoming Changes — Passkeys in Registration Campaigns (May–June 2026)

> **Sources:** Official Microsoft Message Center MC1279092 (updated April 23, 2026) and Daniel Bradley, Our Cloud Network (April 14, 2026 — Microsoft MVP, community blog)

### What Is Changing

Microsoft is adding **Passkeys (FIDO2)** as a targeted authentication method within Registration Campaigns, rolling out in two tracks:

| Track | Status | Timeline |
|---|---|---|
| **Microsoft-managed state** | Confirmed GA | Mid-May to late June 2026 |
| **Enabled state** | Confirmed continuing to GA — logic refinement ongoing | Timeline not yet specified |

**Important note on the Enabled state:** Microsoft initially paused GA for the Enabled state in early April 2026 due to poor user experience with edge cases involving passkey profile restrictions. As of the April 23 update to MC1279092, Microsoft has **reversed this position** — passkeys in the Enabled state will continue to GA. However, Microsoft has acknowledged that initially the nudge logic may not handle all edge cases optimally where users have passkey profile restrictions (e.g. device-bound only or AAGUID restrictions). This is being improved incrementally.

### Microsoft-Managed State — Eligibility Criteria

Your tenant will **automatically** be updated to target passkeys if **all** of the following are true:

- ✅ Passkeys (FIDO2) authentication method policy is **Enabled**
- ✅ Allow self-service setup is **Enabled**
- ✅ **No AAGUID restrictions** configured (Target specific AAGUIDs must NOT be selected)
- ✅ Registration Campaign state is set to **Microsoft-managed**
- ✅ Tenant has at least one user enabled for **both synced and device-bound passkeys**

Individual users only receive the passkey nudge if they are enabled for **both synced and device-bound passkeys** with **no passkey profile restrictions** (no attestation enforcement or AAGUID restrictions).

### What Gets Automatically Changed for Eligible Tenants

If your tenant qualifies, Microsoft will automatically update the following Registration Campaign settings:

| Setting | Before | After | Configurable? |
|---|---|---|---|
| Targeted authentication method | Microsoft Authenticator | Passkeys (FIDO2) | — |
| Days allowed to snooze | 3 days | **1 day** | ❌ No longer configurable |
| Limited number of snoozes | Enabled | **Disabled** | ❌ No longer configurable |
| Default user targeting | Voice call / text message users | **All MFA-capable users** | — |

> ⚠️ **The snooze settings become locked** for affected tenants — admins will not be able to change them once Microsoft applies the passkey campaign settings.

### What This Means for Clients with AAGUID Restrictions

If a client has configured passkey profiles with specific AAGUID restrictions (e.g. Microsoft Authenticator passkeys only), they **will not** meet the Microsoft-managed eligibility criteria and will not be auto-enrolled. This is protective — it prevents unexpected nudges that could confuse users who cannot use the broader passkey options.

### Practical Alternatives While Waiting for Enabled State GA

Daniel Bradley (Our Cloud Network) recommends not waiting for the Enabled state to return before driving passkey adoption. Three practical approaches:

1. **Conditional Access + Authentication Strengths (Strongest)** — Create a CA policy requiring the *Phishing-Resistant MFA* authentication strength. Users without a passkey are forced to register one to gain access. No snooze escape hatch.
2. **Temporary Access Pass (TAP) for Onboarding** — Issue a TAP and direct users to `aka.ms/mysecurityinfo` to register a passkey without needing a password. Ideal for new user onboarding and recovery.
3. **Direct User Communications** — Send users a direct link to their Security Info page with internal setup documentation. If issuing physical FIDO2 keys, include the setup guide with the key.

### No Action Required Right Now

Per MC1279092, no immediate action is required. If you want to prepare for or prevent the Microsoft-managed rollout:

- **To be included:** Ensure users are enabled for both synced and device-bound passkeys, remove AAGUID restrictions, and set the campaign to Microsoft-managed
- **To be excluded:** Configure AAGUID restrictions or set the campaign to Enabled (once GA) or Disabled
