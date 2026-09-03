# Silver Fox Counterfeit Installer Campaign

**Last updated:** September 2026
**Source:** [Counterfeit installers to system compromise: Tracking a deceptive software download campaign](https://www.microsoft.com/en-us/security/blog/2026/09/01/counterfeit-installers-system-compromise-tracking-deceptive-software-download-campaign/) — Microsoft Security Blog, September 1, 2026

---

## 🚨 What it is

Microsoft Defender Experts identified an active malware campaign that uses **counterfeit software-download websites** to impersonate trusted vendors (Razer, Microsoft Edge, Kaspersky, Calibre, Baidu Netdisk, and dozens more) and distribute malicious installers. Microsoft assesses with **moderate confidence** that this activity is consistent with the publicly reported **Silver Fox** campaign (also known as **Yinhu, 银狐**), though it has not been attributed to a nation-state actor.

- **Who's affected:** Primarily China-based operations of multinational organizations and Chinese-speaking users. Victims observed across healthcare, manufacturing, gaming, technology, logistics, government, and education sectors.
- **How it starts:** A user searches for popular software and lands on a spoofed vendor page hosted on look-alike `.com.cn` / `.hl.cn` domains (e.g. `pc-razerzone.com.cn`). Clicking "Download" pulls a ZIP archive from a small set of dedicated delivery hosts.
- **Key evasion trick:** The archive **keeps the same filename but the hash changes on every download** — the payload is generated server-side, per request. This defeats simple hash-based blocklists; behavioral detection is required.
- **What it does once run:**
  - Deploys a wrapped installer that drops a randomized stage-one payload into world-writable paths (`C:\Users\Public\<random>\`, `C:\Program Files (x86)\<random>\`).
  - Masquerades payloads with fabricated version metadata (e.g. impersonating a "Philips Speech Driver").
  - Establishes persistence via disguised Scheduled Tasks (names like "Deadline Mission Target") with a **~60-second re-execution cadence**.
  - Escalates privileges using a throwaway `SCHTASKS` job running as `SYSTEM` (`/RL HIGHEST /RU "SYSTEM"`) to write Microsoft Defender exclusions, then deletes itself.
  - Disables host protections: adds sweeping `Add-MpPreference -ExclusionPath` exclusions, deletes volume shadow copies (`vssadmin delete shadows /all /quiet`), and stops/disables Windows Update services (`wuauserv`, `UsoSvc`, `uhssvc`, `WaaSMedicSvc`).
  - Performs process injection into legitimate applications.
  - Communicates with C2 over non-standard ports (5090, 7031–7090, 8050, 28290, 28300) and abuses Alibaba Cloud OSS buckets for payload staging.
  - In some environments, hands-on-keyboard activity followed automated execution — Microsoft's Attack Disruption engaged automatically to contain compromised devices/accounts.

---

## 🛡️ How to defend against it

### 1. User behavior / policy controls
- Block downloads of software from unofficial/unverified sources. Direct users to vetted internal software catalogs (Company Portal / Intune) instead of open web search for common utilities.
- Treat archives named `app_setup.*`, `zinst.*`, `zintall.*`, `intsoft.*`, `innstll.*` from `*.com.cn` / `*.hl.cn` domains as malicious in web and mail flow.

### 2. Enforce Tamper Protection
Tamper Protection blocks exclusion and registry writes to Microsoft Defender **even when the payload runs as SYSTEM** — this directly counters the throwaway SYSTEM-scheduled-task technique this campaign relies on. Confirm it's enabled tenant-wide:

- Microsoft 365 Defender portal → **Settings → Endpoints → Advanced features → Tamper Protection**, or enforce via Intune (see below).

### 3. Enable Microsoft Defender XDR hardening
Microsoft confirmed customers with the following Attack Surface Reduction (ASR) rules enabled were able to **mitigate the attack in its initial stages** and prevent hands-on-keyboard follow-on activity:

| ASR Rule | GUID |
| --- | --- |
| [Block executable files from running unless they meet a prevalence, age, or trusted list criterion](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference#block-executable-files-from-running-unless-they-meet-a-prevalence-age-or-trusted-list-criterion) | `01443614-cd74-433a-b99e-2ecdc07bfc25` |
| [Block execution of potentially obfuscated scripts](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference#block-execution-of-potentially-obfuscated-scripts) | `5beb7efe-fd9a-4556-801d-275e5ffc04cc` |
| [Block use of copied or impersonated system tools](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference#block-use-of-copied-or-impersonated-system-tools) | `c0033c00-d16d-4114-a5a0-dc9b3a7d2ceb` |
| [Use advanced protection against ransomware](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference#use-advanced-protection-against-ransomware) | `c1db55ab-c21a-4637-bb3f-a12568109d35` |

Also ensure standard baseline protections are on:
- Microsoft Defender **SmartScreen** (blocks fake download landing pages)
- **Network Protection** (blocks connections to malicious/uncategorized domains)
- **Web content filtering** (categorize/block `.com.cn` / `.hl.cn` where not business-required)
- **Cloud-delivered protection** + **behavior monitoring** for the AV engine

### 4. Hunt behavior, not filenames
Because filenames and hashes rotate per download, pivot on:
- Executables dropped into randomized folders under `C:\Users\Public\`, `C:\ProgramData\`, or `C:\Program Files (x86)\`
- SYSTEM-context Scheduled Tasks writing to `HKLM\...\Windows Defender\Exclusions\Paths` followed by self-deletion
- `vssadmin delete shadows /all /quiet`
- Services `wuauserv`, `UsoSvc`, `uhssvc`, `WaaSMedicSvc` being stopped/disabled/renamed
- `msiexec.exe -Embedding` spawning a randomized executable from `C:\Users\Public\`

Advanced Hunting (KQL) queries for all of the above patterns are published in the [source blog post](https://www.microsoft.com/en-us/security/blog/2026/09/01/counterfeit-installers-system-compromise-tracking-deceptive-software-download-campaign/#advanced-hunting) — copy them into Defender XDR / Sentinel for proactive detection.

---

## 📱 Intune policies to deploy

| Control | Where | Purpose |
| --- | --- | --- |
| **ASR rules** (table above) in **Audit → Block** | Intune → Endpoint security → Attack surface reduction → Attack surface reduction rules profile | Blocks the initial-stage installer execution and obfuscated script/system-tool abuse this campaign relies on |
| **Tamper Protection = On** | Intune → Endpoint security → Antivirus → Windows security experience profile (or Security baseline) | Prevents the malware's throwaway-SYSTEM-task exclusion writes from succeeding |
| **Cloud-delivered protection + Real-time protection = On, Cloud block level = High** | Intune → Endpoint security → Antivirus → Microsoft Defender Antivirus profile | Ensures fast cloud lookups catch the server-side-regenerated payload hashes |
| **Network Protection = Block** | Intune → Endpoint security → Attack surface reduction → Web protection / ASR profile | Blocks outbound connections to the C2 domains/IPs below at the network layer |
| **Web content filtering / Microsoft Defender for Endpoint indicators** | Security.microsoft.com → Settings → Endpoints → Indicators (or Intune-managed via Endpoint Security → **Custom Indicators**) | Enforces the domain/IP/file-hash blocklist in `silver-fox-indicators.csv` (see below) |
| **App Control for Business (WDAC) — reputation-based execution / managed installer** | Intune → Endpoint security → App Control for Business | Restricts execution to known-good, digitally signed installers; blocks the wrapper/stage-one binaries even if names/hashes rotate |
| **Restrict local admin rights / LAPS** | Intune → Endpoint security → Account protection | Limits the blast radius of the SYSTEM-level privilege escalation technique used to write Defender exclusions |
| **Block user write access to `C:\Users\Public` execution (where feasible via AppLocker/WDAC path rules)** | Intune → App Control for Business (custom policy) | Directly targets the campaign's consistent drop-path pattern (`C:\Users\Public\<random>\<random>.exe`) |

> 💡 Deploy ASR rules in **Audit mode** first against a pilot group, review Advanced Hunting for false positives over ~1 week, then promote to **Block** tenant-wide.

---

## 🔎 Defender IOCs (Indicators of Compromise)

Full IOC tables (lure domains, delivery hosts, C2 domains/IPs, and payload SHA-256 hashes) are published in the blog's [Indicators of compromise (IOC)](https://www.microsoft.com/en-us/security/blog/2026/09/01/counterfeit-installers-system-compromise-tracking-deceptive-software-download-campaign/#indicators-of-compromise-ioc) section. Highlights:

- **Lure domains:** `pc-razerzone.com.cn`, `app-microsoft-edge.com.cn`, `kaspersky-lab.hl.cn`, `calibre-ebook.com.cn`, and more (all `.com.cn` / `.hl.cn` brand impersonation domains)
- **Delivery hosts:** `gehie246.com`, `yimxg25tiy.com`, `cc8ttkv35b.com`, `n7b8t85zsg.com`, `mebx78e02.com`, `qwjre1487.com`
- **Cloud staging:** Alibaba OSS buckets `upitem.oss-cn-hangzhou.aliyuncs.com`, `newopt001.oss-cn-hongkong.aliyuncs.com`
- **C2 domains:** `iualef.net`, `oijfwe.net`, `euioxu.net`, `czijbh.net`, `wfmwsj.net`, `tbdqxq.net`
- **C2 IPs:** `202.95.14.237` (primary hub, AS152194), `47.239.232.245`, `47.243.218.255`, `103.156.25.35`, `103.183.3.162`, `43.99.100.248`, `47.239.175.163`, `47.86.205.97`, `161.248.87.157`
- **Payload SHA-256 hashes:** stage-one loader, Philips-masquerade later-stage payload, networking payload, persistent/process-injection payload, TrueUpdate loader, supporting sideloaded DLL (full list in CSV below)

### ✅ Import to prevent it

All of the above indicators are pre-formatted for direct import into **Microsoft Defender for Endpoint**:

📄 **[`silver-fox-indicators.csv`](./silver-fox-indicators.csv)**

**To deploy:**
1. Go to **security.microsoft.com** → **Settings** → **Endpoints** → **Indicators**
2. Select the relevant tab (**Domains**, **IP addresses**, or **Files**) — the CSV mixes all three indicator types, so you may need to filter/split by `IndicatorType` column before each import, or use the [Import indicators](https://learn.microsoft.com/en-us/defender-endpoint/import-export-exclusions) bulk-import feature which accepts the full file.
3. Verify **Action = Block** and **GenerateAlert = True** are applied for all rows (already set in the CSV).
4. Confirm the indicators are scoped to **all device groups** unless you have a specific RBAC segmentation need (the `RbacGroups` column is currently blank = tenant-wide).
5. Re-run periodically — Microsoft may publish updated IOC sets if the campaign's infrastructure rotates.

---

## 🧩 MITRE ATT&CK techniques observed

| Tactic | Technique | ID |
| --- | --- | --- |
| Resource Development | Acquire Infrastructure: Domains / Web Services | T1583.001 / T1583.006 |
| Execution | User Execution: Malicious File | T1204.002 |
| Execution | Command and Scripting Interpreter: PowerShell / Windows Command Shell | T1059.001 / T1059.003 |
| Execution | System Binary Proxy Execution: Msiexec | T1218.007 |
| Persistence / Privilege Escalation | Scheduled Task/Job: Scheduled Task | T1053.005 |
| Defense Evasion | Impair Defenses: Disable or Modify Tools | T1562.001 |
| Defense Evasion | Masquerading: Match Legitimate Name or Location | T1036.005 |
| Defense Evasion | Hijack Execution Flow: DLL Side-Loading | T1574.002 |
| Defense Evasion | Process Injection | T1055 |
| Defense Evasion | File and Directory Permissions Modification | T1222.001 |
| Defense Evasion | Modify Registry | T1112 |
| Lateral Movement | Remote Services: SMB/Windows Admin Shares | T1021.002 |
| Impact | Inhibit System Recovery | T1490 |
| Impact | Service Stop | T1489 |
| Command and Control | Ingress Tool Transfer | T1105 |
| Command and Control | Application Layer Protocol / Non-Standard Port | T1071 / T1571 |

---

## 📚 References

- [Counterfeit installers to system compromise: Tracking a deceptive software download campaign](https://www.microsoft.com/en-us/security/blog/2026/09/01/counterfeit-installers-system-compromise-tracking-deceptive-software-download-campaign/) — Microsoft Security Blog (primary source, Sep 1, 2026)
- [Attack surface reduction rules reference](https://learn.microsoft.com/en-us/defender-endpoint/attack-surface-reduction-rules-reference) — Microsoft Learn
- [Import indicators to Microsoft Defender for Endpoint](https://learn.microsoft.com/en-us/defender-endpoint/import-export-exclusions) — Microsoft Learn
- [TweetFeed community indicator feed](https://github.com/0xDanielLopez/TweetFeed/blob/master/week.csv) — prior Silver Fox OSINT
- [AlienVault OTX pulse — campaign delivery infrastructure and C2 indicators](https://otx.alienvault.com/pulse/6a36fe5a3c1568785b59c4d7)
- [LGSRC public indicator repository](https://github.com/Lingggao/LGSRC) — prior Silver Fox OSINT
- Local IOC file: [`silver-fox-indicators.csv`](./silver-fox-indicators.csv)
