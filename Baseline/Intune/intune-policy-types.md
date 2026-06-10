# Intune Policy Types: CSP · OMA-URI · Settings Catalog · DDM

> **Know your methods — and which one to actually use.**
>
> A practical reference for Microsoft Intune admins covering the four main policy delivery mechanisms, their relationships, deprecation timelines, and the recommended approach as of June 2026.

---

## Quick Reference

| Method | What it is | Status | Recommended? |
|--------|-----------|--------|--------------|
| **CSP** | Windows OS-level configuration framework | ✅ Active (always) | Foundation — not an admin choice |
| **OMA-URI (Custom Profile)** | Manual CSP path entry | ⚠️ Available — use minimally | Last resort only |
| **Settings Catalog** | Searchable UI over CSPs + Apple payloads | ✅ Active — primary investment | ✅ Yes — default for all new policies |
| **Administrative Templates (ADMX)** | Legacy Group Policy surfaced in Intune | 🚫 Retired Dec 2024 | ❌ No — migrate to Settings Catalog |
| **DDM (Apple / Windows WinDC)** | Device-autonomous declarative protocol | ✅ Active — expanding | ✅ Yes — required for Apple OS 26+ |

---

## How They Relate

These are **not competing alternatives at the same layer** — understanding the architecture prevents misconfiguration.

```
┌─────────────────────────────────────────────────────┐
│              Intune Admin Center (UI)               │
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ Settings     │  │ OMA-URI      │  │ Templates │ │
│  │ Catalog      │  │ Custom       │  │ (retired) │ │
│  └──────┬───────┘  └──────┬───────┘  └─────┬─────┘ │
│         └─────────────────┴────────────────┘        │
│                           │                         │
│              ┌────────────▼────────────┐            │
│              │   CSP (Windows OS)      │            │
│              │   Configuration Service │            │
│              │   Provider Framework    │            │
│              └─────────────────────────┘            │
│                                                     │
│  ┌──────────────────────────────────────────────┐   │
│  │  DDM (Apple) / Declared Config (Windows)     │   │
│  │  Device-side autonomous enforcement          │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

**CSP is the engine, not an admin choice.** OMA-URI, Settings Catalog, and Templates all call the same underlying CSP paths — they are different admin surfaces with different discoverability, reporting, and support trajectories.

---

## 1. CSP — Configuration Service Provider

**What it is:** The Windows OS-level framework that receives and applies MDM configurations. Think of it as the middleman between Intune and the device — it intercepts policy, compares against current state, and applies changes (typically via Registry keys or OS feature APIs).

**Key points:**
- Every other Windows policy method ultimately resolves to a CSP path
- CSPs define scope: **Device** (applies regardless of who is logged in) vs **User** (applies to a specific user)
- The scope dictates the OMA-URI prefix: `./Device/...` or `./User/...`
- Microsoft publishes the full [CSP reference on Microsoft Learn](https://learn.microsoft.com/en-us/windows/client-management/mdm/configuration-service-provider-reference)

**You don't "choose" CSP** — it's the underlying protocol. You choose how you interact with it.

---

## 2. OMA-URI — Custom Profile

**What it is:** Open Mobile Alliance Uniform Resource Identifier. A manual method where you write the exact CSP path, data type, and value yourself in the Intune admin center.

**Path format:**
```
Device: ./Device/Vendor/MSFT/Policy/Config/[Area]/[PolicyName]
User:   ./User/Vendor/MSFT/Policy/Config/[Area]/[PolicyName]
```

**Example:**
```
./Device/Vendor/MSFT/Policy/Config/RemoteDesktopServices/AllowUsersToConnectRemotely
```

**When to use it:**
- Only when the setting genuinely does not exist in the Settings Catalog
- Microsoft is actively restricting OMA-URI to settings absent from the catalog

**Risks:**
- No conflict detection — silent misconfigurations are common
- Basic pass/fail reporting only
- A typo in the path silently fails with no error surfaced to the admin
- Requires knowing exact CSP path, data type (String, Integer, Boolean, etc.), and scope

> ⚠️ **Always verify the CSP path and scope** in the [Microsoft CSP reference](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-configuration-service-provider) before deploying. Do not guess data types.

---

## 3. Settings Catalog

**What it is:** A searchable UI layer over CSPs (Windows) and Apple payload keys (macOS/iOS). Microsoft's current standard and primary investment. As of 5/27/2026: **18,000+ settings** across Windows, macOS, iOS/iPadOS, Android, and Linux.

**Why it replaced everything else:**
- Administrative Templates (ADMX) retired for new creation in December 2024 — all ADMX settings now exist in the Settings Catalog
- Built-in conflict detection and per-setting reporting
- Cross-platform parity in a single interface
- DDM settings for Apple devices are **surfaced here** — there is no separate DDM blade

**Portal path:** `Devices > Manage devices > Configuration > Create > New policy > [Platform] > Settings catalog`

**Useful tool — community-built viewer (no Intune access required):**

> 🔗 **[intunesettings.app](https://intunesettings.app/)** — Browse, search, and explore all Settings Catalog definitions across every platform. View OMA-URI paths, allowed values, default options, and parent/child relationships. Includes a [changelog](https://intunesettings.app/changelog/) that tracks additions, removals, and modifications over time. Data pulled read-only from Microsoft Graph API — never writes to your environment.

**Key categories to know:**
| Category | Settings count | Notes |
|----------|---------------|-------|
| Administrative Templates | 2,512 | All former ADMX settings — migrated here |
| Microsoft Edge | 523 (Windows) / 524 (macOS) | Includes deprecated settings — filter with the Deprecated toggle |
| Declarative Device Management (DDM) | 111 (macOS), 136 (all platforms) | Apple DDM lives here, not in a separate blade |
| Microsoft Defender | 80 | MDE settings |
| Authentication | 138–148 | Platform-dependent |

---

## 4. Administrative Templates (ADMX) — Retired

**What it was:** Legacy Group Policy ADMX settings surfaced in the Intune admin center under `Templates > Administrative Templates`.

**Current status:** 🚫 **Retired for new creation as of December 2024 (service release 2412).**

- You **cannot create new** Administrative Template profiles
- Existing profiles **continue to work** and can be edited or deleted
- All settings have been migrated to the Settings Catalog

**Action required:** If you have existing Admin Template policies, they will continue to function. However, any net-new configuration should use the Settings Catalog. When rebuilding in Settings Catalog, you'll often find additional granularity that wasn't available in the template view.

---

## 5. DDM — Declarative Device Management

**What it is:** Apple's modern management protocol that shifts from server-driven commands to device-autonomous declarations. The device declares its desired state and self-enforces it — including when offline.

### MDM vs DDM Model

| Aspect | Traditional MDM | DDM |
|--------|----------------|-----|
| Model | Server sends commands, polls for status | Device declares state, self-enforces |
| Offline behavior | Commands queue, wait for connectivity | Device enforces desired state independently |
| Status reporting | Server must poll device repeatedly | Device proactively pushes real-time status |
| Race conditions | Common with conflicting policies | Avoided — device-side resolution |
| Update example | Intune sends "install update" command, polls every 8 hours | Intune declares "target OS = 15.5 by deadline", device manages the rest |

### DDM in Intune

DDM settings are configured via the **Settings Catalog** — look for the **"Declarative Device Management (DDM)"** category in the left navigation when filtered to macOS or iOS/iPadOS.

**Supported areas (as of June 2026):** Software updates (primary use case), disk management, passcode, screen time, and others. Microsoft adds DDM coverage in each monthly Intune release.

### ⚠️ Apple OS 26 — Action Required

> **Apple deprecated all legacy MDM software update commands at WWDC June 2025.**
>
> iOS 26, iPadOS 26, and macOS 26 **will remove these commands entirely** — not just deprecate them. Devices running OS 26+ will **ignore** your existing MDM update policies if DDM policies are enforced. If no DDM policy exists when OS 26 ships, you lose all managed software update control.

**Reference:** [MC1113111](https://admin.microsoft.com/AdminPortal/Home#/MessageCenter) · Apple WWDC 2025 Session 258 · [Microsoft Intune Customer Success blog](https://techcommunity.microsoft.com/blog/intunecustomersuccess/support-tip-move-to-declarative-device-management-for-apple-software-updates/4432177)

**Migration deadline:** Before Apple OS 26 GA — expected **autumn 2026.**

---

## Deprecation & Migration Timeline

| Date | Event |
|------|-------|
| **August 2024 (2408)** | macOS Endpoint Protection and System Extensions templates deprecated. Migrate to Settings Catalog (FileVault, Firewall, Gatekeeper payloads). |
| **December 2024 (2412)** | Administrative Templates retired for new creation. Settings Catalog is the replacement path. Existing policies remain functional. |
| **April 2025** | Custom profiles for Android Enterprise personally owned work profile devices retired. |
| **June 2025 (WWDC)** | Apple announces MDM software update commands deprecated in OS 26. DDM required for Apple update management going forward. |
| **August 2025 (2508)** | Intune adds near-real-time per-device DDM update reporting for Apple devices. |
| **Autumn 2026** | Apple OS 26 expected GA. Legacy MDM update commands fully removed. DDM migration must be complete. |

---

## Decision Guide

### Which method should I use?

**Creating a new Windows policy?**
→ **Settings Catalog first.** Search by setting name, description, or CSP path. Only fall back to OMA-URI if the setting genuinely isn't in the catalog.

**Managing Apple software updates?**
→ **DDM via Settings Catalog.** Legacy MDM update commands are deprecated — OS 26 removes them entirely. Migrate before autumn 2026.

**Have existing Administrative Template policies?**
→ **Keep them** — they still work and can be edited. But rebuild any new equivalent policies in Settings Catalog.

**Need a setting that's not in Settings Catalog?**
→ **Custom OMA-URI** using the exact CSP path from the [Microsoft CSP reference](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-configuration-service-provider). Always verify Device vs User scope before deploying.

**Managing macOS or iOS at scale?**
→ **Settings Catalog + DDM for update management.** Use the DDM category in Settings Catalog for software updates, and standard catalog settings for everything else.

---

## References

| Resource | URL |
|----------|-----|
| Intune Settings Catalog Viewer (community tool) | [intunesettings.app](https://intunesettings.app/) |
| Settings Catalog Changelog | [intunesettings.app/changelog](https://intunesettings.app/changelog/) |
| Microsoft CSP Reference | [learn.microsoft.com — CSP reference](https://learn.microsoft.com/en-us/windows/client-management/mdm/configuration-service-provider-reference) |
| Settings Catalog — Microsoft Learn | [learn.microsoft.com — Settings catalog](https://learn.microsoft.com/en-us/intune/intune-service/configuration/settings-catalog) |
| OMA-URI deployment guide | [learn.microsoft.com — Deploy OMA-URIs](https://learn.microsoft.com/en-us/troubleshoot/mem/intune/device-configuration/deploy-oma-uris-to-target-csp-via-intune) |
| DDM migration blog (Microsoft) | [techcommunity.microsoft.com](https://techcommunity.microsoft.com/blog/intunecustomersuccess/support-tip-move-to-declarative-device-management-for-apple-software-updates/4432177) |
| Admin Templates retirement announcement | [techcommunity.microsoft.com](https://techcommunity.microsoft.com/blog/intunecustomersuccess/support-tip-windows-device-configuration-policies-migrating-to-unified-settings-/4189665) |

---

*Last updated: June 2026 · Jon Hope — Microsoft MVP, M365 Solutions Architect*
*[linkedin.com/in/jhope188](https://linkedin.com/in/jhope188) · [conditionalaccess.tech](https://conditionalaccess.tech)*
