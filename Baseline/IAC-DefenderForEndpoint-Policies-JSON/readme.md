# Microsoft Defender for Endpoint — Baseline Policy Pack

> **Platform:** Windows 10/11 · **Import method:** Microsoft Graph Beta API  
> **Endpoint:** `POST https://graph.microsoft.com/beta/deviceManagement/configurationPolicies`  
> **Assignment:** All policies target **All Devices** + **All Licensed Users** (direct assignment, no filters)

---

## Policy Inventory

| # | File | Policy Name | Template Family | Settings |
|---|------|-------------|----------------|----------|
| 1 | `ASR-Audit.json` | ASR - Audit | Attack Surface Reduction | 19 |
| 2 | `ASR-ExploitProtection.json` | Windows 11 ASR Exploit Protection | Attack Surface Reduction | 1 |
| 3 | `ASR-DeviceControl.json` | Windows 11 ASR Device Control | Attack Surface Reduction | 20 |
| 4 | `ASR-Rules.json` | Windows 11 ASR Rules | Attack Surface Reduction | 19 |
| 5 | `ASR-AppBrowserIsolation.json` | Windows 11 App Browser & Isolation | Attack Surface Reduction | 14 |
| 6 | `Firewall.json` | Windows 11 Firewall | Firewall | 10 |
| 7 | `Antivirus-SecurityExperience.json` | Windows 11 Security Experience | Antivirus | 14 |
| 8 | `SecurityBaseline.json` | Windows 11 Security Baseline | Endpoint Security Baseline | Multiple |
| 9 | `Antivirus-DefenderUpdateControls.json` | Windows 11 Anti-Virus Defender Update Controls | Antivirus | 3 |
| 10 | `Antivirus-Exclusions.json` | Windows 11 Anti-Virus Exclusions | Antivirus | 2 |
| 11 | `Antivirus-DefenderAntivirus.json` | Windows 11 Microsoft Defender Antivirus | Antivirus | 40 |

---

## Policy Details

### 1. ASR - Audit (`ASR-Audit.json`)

Sets all 19 Attack Surface Reduction rules to **audit mode** for monitoring without enforcement. Controlled Folder Access is also in audit. This is the recommended first step before enabling block mode, allowing you to assess the impact on the environment.

**Key settings:**
- All 19 ASR rules → Audit mode
- Controlled Folder Access → Audit mode

---

### 2. ASR Exploit Protection (`ASR-ExploitProtection.json`)

Prevents users from overriding Exploit Protection settings configured by the administrator.

**Key settings:**
- Disallow user override of Exploit Protection settings → Disabled (admin-managed)

---

### 3. ASR Device Control (`ASR-DeviceControl.json`)

Controls external device access and peripheral connections to reduce the attack surface from removable media and hardware.

**Key settings:**
- Removable drive scanning → Enabled
- DMA Guard / Kernel DMA Protection → Enabled
- Bluetooth pre-pairing restrictions → Enabled
- USB device restrictions → Configured
- Storage card access → Disabled
- Device installation restrictions → Configured (class-based and hardware ID)
- Custom error message for blocked device installation

---

### 4. ASR Rules — Enforcement (`ASR-Rules.json`)

The production enforcement companion to ASR-Audit. All 19 ASR rules are set to **block mode** for active threat prevention.

**Key settings:**
- All 19 ASR rules → Block mode (with one rule in audit mode with exclusion for `CursorSetup-x64-2.1.46.exe`)
- Controlled Folder Access → Enabled (block)
- Allowed application for Controlled Folder Access: `c:/intune`

> ⚠️ **Environment-specific:** The Cursor installer exclusion and `c:/intune` allowed path are intentional and tailored to this baseline.

---

### 5. App Browser & Isolation (`ASR-AppBrowserIsolation.json`)

Configures Windows Defender Application Guard (WDAG) for browser and application isolation.

**Key settings:**
- Application Guard enabled for Edge and isolated environments
- Camera and microphone redirection → Allowed
- Clipboard → Text copy in both directions
- Printing → XPS, PDF, local, and network printers allowed
- Application Guard auditing → Enabled (block + allow events)

---

### 6. Firewall (`Firewall.json`)

Comprehensive Windows Defender Firewall configuration across all three network profiles.

**Key settings:**
- **Global:** CRL verification, stateful FTP, pre-shared key encoding, packet queuing
- **Domain profile:** Firewall enabled, inbound blocked by default, outbound allowed
- **Private profile:** Firewall enabled, inbound blocked by default, outbound allowed
- **Public profile:** Firewall enabled, inbound blocked, outbound allowed, local policy merge **disabled** (hardened)
- Firewall log: `%systemroot%\system32\LogFiles\Firewall\pfirewall.log` (max 16,384 KB)

---

### 7. Security Experience (`Antivirus-SecurityExperience.json`)

Controls the Windows Security app UI and notification behaviour shown to end users.

**Key settings:**
- All Windows Security UI sections visible (Virus & Threat, Account, Firewall, App & Browser, Device Security, Device Performance, Family)
- Enhanced notifications → Enabled
- TPM firmware update warning → Shown
- Ransomware recovery information → Displayed

---

### 8. Security Baseline (`SecurityBaseline.json`)

The Windows 11 Security Baseline default policy covering a broad range of OS-level security hardening across multiple categories.

**Key settings:**
- Hardened OS security defaults aligned with Microsoft recommended baselines
- Covers BitLocker, credential protection, device lock, audit policies, network security, and more

---

### 9. Defender Update Controls (`Antivirus-DefenderUpdateControls.json`)

Controls the update channels for the three Defender components to manage rollout timing.

**Key settings:**
- Engine updates channel → Current Channel (Broad) — `_0`
- Platform updates channel → Current Channel (Broad) — `_0`
- Security intelligence updates channel → Current Channel (Broad) — `_0`

---

### 10. Antivirus Exclusions (`Antivirus-Exclusions.json`)

Defines path and process exclusions for Microsoft Defender Antivirus to prevent interference with trusted third-party software.

**Key settings:**
- **Excluded paths (3):**
  - `%Programfiles(x86)%\MspPlatform\PME`
  - `%Programfiles(x86)%\MspPlatform\FileCacheServiceAgent`
  - `%Programfiles(x86)%\MspPlatform\RequestHandlerAgent`
  - `%ProgramData%\MspPlatform`
  - `%ProgramData%\MSPPlatform\Ecosystem Agent\`

- **Excluded processes (7):**
  - `N-able.CacheService.exe`
  - `7z.exe` (PME ThirdPartyPatch)
  - `ThirdPartyPatch.exe`
  - `CacheServiceSetup.exe`
  - `RPCServerServiceSetup.exe`
  - `PME.Diagnostics.exe`
  - `RequestHandlerAgent.exe`

> ⚠️ **Environment-specific:** These exclusions are for **N-able RMM** (MspPlatform / PME). Remove or adjust if the target tenant does not use N-able.

---

### 11. Microsoft Defender Antivirus (`Antivirus-DefenderAntivirus.json`)

The comprehensive Defender Antivirus configuration policy with 40 settings covering scanning, protection, scheduling, network protection, and threat remediation.

**Key settings:**

| Category | Setting | Value |
|----------|---------|-------|
| **Scanning** | Archive scanning | ✅ Enabled |
| | Email scanning | ✅ Enabled |
| | Script scanning | ✅ Enabled |
| | Full scan on mapped network drives | ❌ Disabled |
| | Full scan removable drives | ❌ Disabled |
| | Network file scanning | ❌ Disabled |
| **Real-time Protection** | Real-time monitoring | ✅ Enabled |
| | Behaviour monitoring | ✅ Enabled |
| | On-access protection | ✅ Enabled |
| | IOAV protection | ✅ Enabled |
| | Intrusion prevention system | ✅ Enabled |
| **Cloud** | Cloud-delivered protection | ✅ Enabled |
| | Cloud block level | Default |
| | Submit samples consent | Send safe samples automatically |
| **Network** | Network protection | ✅ Enabled (block) |
| | DNS sinkhole | ✅ Enabled |
| | DNS over TCP parsing | ✅ Enabled (not disabled) |
| | HTTP parsing | ✅ Enabled (not disabled) |
| | SSH parsing | ✅ Enabled (not disabled) |
| | TLS parsing | ✅ Enabled (not disabled) |
| **Scheduling** | Scan type | Quick scan |
| | Quick scan time | 02:00 (120 min after midnight) |
| | Scheduled scan day | Wednesday (`_4`) |
| | Scheduled scan time | 14:20 (860 min after midnight) |
| | Randomise scheduled task times | ✅ Enabled |
| | Catch-up full scan | Disabled |
| | Catch-up quick scan | Disabled |
| **PUA** | PUA protection | ✅ Enabled |
| **Threat Actions** | Severe threats | Remove |
| | High severity threats | Remove |
| | Moderate severity threats | Quarantine |
| | Low severity threats | Quarantine |
| **Other** | User UI access | ✅ Allowed |
| | Low CPU priority for scans | ❌ Disabled |
| | Metered connection updates | ❌ Disabled |
| | Local admin merge | ❌ Disabled |
| | Real-time scan direction | Both incoming and outgoing |

**Update channels** (engine, platform, security intelligence): All set to Current Channel (Broad).

---

## Importing Policies

### Prerequisites

```powershell
# Connect to target tenant with required scopes
Connect-MgGraph -TenantId '<TARGET-TENANT-ID>' -Scopes 'DeviceManagementConfiguration.ReadWrite.All'
```

### Import Script

```powershell
$policyFiles = Get-ChildItem -Path '~/Desktop/DefenderForEndpoint/*.json'

foreach ($file in $policyFiles) {
    $json = Get-Content $file.FullName -Raw | ConvertFrom-Json

    # Build the import body (strip source-tenant IDs and OData context)
    $body = @{
        name              = $json.name
        description       = $json.description
        platforms         = $json.platforms
        technologies      = $json.technologies
        roleScopeTagIds   = $json.roleScopeTagIds
        settings          = $json.settings
        templateReference = @{
            templateId = $json.templateReference.templateId
        }
    } | ConvertTo-Json -Depth 50

    # Create policy
    $policy = Invoke-MgGraphRequest -Method POST `
        -Uri 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies' `
        -Body $body -ContentType 'application/json'

    Write-Host "✅ Created: $($policy.name) → $($policy.id)" -ForegroundColor Green

    # Apply assignments (All Devices + All Licensed Users)
    foreach ($assignment in $json.assignments) {
        $assignBody = @{
            target = $assignment.target
        } | ConvertTo-Json -Depth 10

        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$($policy.id)')/assign" `
            -Body (@{ assignments = @(@{ target = $assignment.target }) } | ConvertTo-Json -Depth 10) `
            -ContentType 'application/json'
    }
    Write-Host "   📌 Assigned to All Devices + All Licensed Users" -ForegroundColor Cyan
}
```

---

## Notes

- **Recommended deployment order:** ASR-Audit first → monitor for 2–4 weeks → then deploy ASR-Rules enforcement
- **N-able exclusions:** Policy #10 contains exclusions specific to N-able RMM. Remove if not applicable.
- **Scan schedule:** Wednesday at 14:20 with quick scan at 02:00 — adjust to suit the organisation's maintenance windows
- All policies use `mdm,microsoftSense` technologies (Intune + MDE sensor)
- Source-tenant policy IDs are preserved in the JSON files for reference but are **not used** during import — new IDs are generated in the target tenant
