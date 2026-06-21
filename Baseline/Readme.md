# Baseline — M365 Security Reference

**Jon Hope · Microsoft MVP · Security: Identity & Access**  
A living collection of baseline configurations, Graph API references, deployment scripts, and security best practices for Microsoft 365.

> ⚠️ All scripts should be tested in a non-production environment before deployment. Use at your own risk.

---

## 🗺️ Quick Navigation

| Area | Deep Dive | What's Inside |
|---|---|---|
| [Admin Center](#️-admin-center) | [AdminCenter/readme.md](AdminCenter/readme.md) | Tenant config, Copilot settings, security hardening |
| [Entra ID](#-entra-id) | [Entra/readme.md](Entra/readme.md) | CA scripts, guest MFA, auth methods |
| [Defender for Office 365](#️-defender-for-office-365) | [Defender/readme.md](Defender/readme.md) | MDE deployment, EOP/DFO policies |
| [Exchange](#-exchange) | [Exchange/readme.md](Exchange/readme.md) | Mail flow, direct send, Proofpoint |
| [Intune](#-intune) | [Intune/readme.md](Intune/readme.md) | Policy types, CSP, Settings Catalog, DDM |
| [Purview](#️-purview) | [Purview/readme.md](Purview/readme.md) | Sensitivity labels, DLP, adaptive protection |
| [SharePoint & OneDrive](#-sharepoint--onedrive) | [Sharepoint/Sharepoint-configuration.md](Sharepoint/Sharepoint-configuration.md) | Sharing, access control, governance |
| [Power Platform](#-power-platform) | [PowerPlatform/readme.md](PowerPlatform/readme.md) | Security hardening, DLP, Managed Environments |
| [M365 Configuration (IAC)](#️-m365-configuration--iac-policies) | [M365 Configuration/](M365%20Configuration/) | Exportable JSON policy baselines + deploy scripts |
| [Scripts](#-scripts) | [../Scripts/readme.md](../Scripts/readme.md) | Entra, Intune, Exchange, runbook scripts |
| [Graph API Reference](#-graph-api-reference) | [../graphapi/readme.md](../graphapi/readme.md) | Endpoint cheat sheet, copy-ready Graph calls |
| [Harry Potter Demo](#-harry-potter-demo) | [HarryPotter-Demo/readme.md](HarryPotter-Demo/readme.md) | Purview + Copilot demo environment |

---

## 🏛️ Admin Center

**[→ Deep Dive: AdminCenter/readme.md](AdminCenter/readme.md)**

Tenant-level security hardening and Copilot configuration references.

| File | What it covers |
|---|---|
| [Admin-Center-Configuration-Guide.md](AdminCenter/Admin-Center-Configuration-Guide.md) | Full Admin Center configuration walkthrough |
| [M365-AdminCenter-Security-Hardening-Walkthrough.md](AdminCenter/M365-AdminCenter-Security-Hardening-Walkthrough.md) | Step-by-step security hardening |
| [M365-Baseline-Security-Mode-Deep-Dive.md](AdminCenter/M365-Baseline-Security-Mode-Deep-Dive.md) | Baseline Security Mode explained |
| [Copilot-Settings-Baseline-Guide.md](AdminCenter/Copilot-Settings-Baseline-Guide.md) | Copilot for M365 settings baseline |

**Scripts** (`M365 Configuration/IAC-Admin-Center-Policies-JSON/Scripts/`):

| Script | Purpose |
|---|---|
| `admincenterconfig.ps1` | Apply Admin Center baseline configuration |
| `export-admin-center-config.ps1` | Export current settings to JSON |
| `import-admin-center-config.ps1` | Import baseline JSON config |
| `Disable-BasicAuth.ps1` | Disable legacy auth protocols |
| `Disable-SelfServiceTrials.ps1` | Block self-service trial sign-ups |

---

## 🔐 Entra ID

**[→ Deep Dive: Entra/readme.md](Entra/readme.md)**

Identity configuration references, Conditional Access scripts, and authentication method guidance.

| File | What it covers |
|---|---|
| [guest-mfa-reference_table.md](Entra/guest-mfa-reference_table.md) | Guest MFA behaviour reference table |
| [guest-mfa-reference_creation.md](Entra/guest-mfa-reference_creation.md) | How to create guest MFA policies |
| [registration-campaign-snooze-summaryrecommendation.md](Entra/registration-campaign-snooze-summaryrecommendation.md) | Registration campaign snooze guidance |

**Conditional Access Scripts** (`M365 Configuration/IAC-Entra-Policies-JSON/ConditionalAccessScripts/`):

| Script | Purpose |
|---|---|
| `recreate-iac-entra-policies.ps1` | Recreate full CA policy baseline from JSON |
| `export-iac-entra-policies-json.ps1` | Export current CA policies to JSON |
| `export-ca-documentation.ps1` | Generate CA policy documentation |
| `create-ca-groups.ps1` | Create required CA exclusion and assignment groups |
| `update-ca-policy-exclusions.ps1` | Update exclusions across all policies |
| `cleanup-duplicates.ps1` | Remove duplicate policy entries |
| `fix-device-registration.ps1` | Fix device registration issues |
| `check-security-attributes.ps1` | Audit custom security attribute assignments |
| `delete-all-iac-policies-and-locations.ps1` | ⚠️ Full teardown — use carefully |

**Entra Scripts** (`Scripts/Entra/`):

| Script | Purpose |
|---|---|
| `create-ca-groups.ps1` | Create CA exclusion/assignment groups |
| `create-entra-settings.ps1` | Apply Entra tenant settings |
| `get-entra-settings.ps1` | Export current Entra settings |
| `export-entra-documentation.ps1` | Generate Entra documentation |
| `CreateBaselineGroups.ps1` | Create baseline security groups |
| `DisableM365Groupcreation.ps1` | Restrict M365 Group creation to admins |
| `rename-ca-policies.ps1` | Rename CA policies to IAC naming convention |

**IAC Documentation** (`M365 Configuration/IAC-Entra-Policies-JSON/`):

| File | What it covers |
|---|---|
| [IAC-Entra-Policies-Documentation.md](M365%20Configuration/IAC-Entra-Policies-JSON/IAC-Entra-Policies-Documentation.md) | Full CA policy export and documentation |
| [TENANT-POLICIES-README.md](M365%20Configuration/IAC-Entra-Policies-JSON/TENANT-POLICIES-README.md) | Tenant-level policy reference |
| [IAC-O365-BLOCK-NonWorkingHours-Documentation.md](M365%20Configuration/IAC-Entra-Policies-JSON/IAC-O365-BLOCK-NonWorkingHours-Documentation.md) | Non-working hours block policy |
| [README-RecreateIACEntraPolicies.md](M365%20Configuration/IAC-Entra-Policies-JSON/ConditionalAccessScripts/README-RecreateIACEntraPolicies.md) | Deployment instructions |

---

## 🛡️ Defender for Office 365

**[→ Deep Dive: Defender/readme.md](Defender/readme.md)**

Microsoft Defender for Endpoint deployment and Defender for Office 365 email security policies.

| File | What it covers |
|---|---|
| [MDE_Deployment_Guide.md](Defender/MDE_Deployment_Guide.md) | Full MDE deployment and configuration guide |
| [DFO-Proofpoint-configurationguide.md](Defender/DFO-Proofpoint-configurationguide.md) | Proofpoint → DFO migration guide |
| [IAC-EOP-DFO-Security-Documentation.md](M365%20Configuration/IAC-Defender-Policies-JSON/IAC-EOP-DFO-Security-Documentation.md) | EOP + DFO policy documentation |

**IAC Policy JSON Baselines** (`M365 Configuration/IAC-Defender-Policies-JSON/`):

| Folder | Policy |
|---|---|
| `AntiPhishing/` | Anti-phishing for all domains |
| `AntiSpam/` | Inbound + outbound anti-spam |
| `AntiMalware/` | Anti-malware for all domains |
| `SafeLinks/` | Safe Links for all domains |
| `SafeAttachments/` | Safe Attachments for all domains |
| `MailFlowRules/` | Block external forwarding, alert external email, block malware |
| `ConnectionFilter/` | Default connection filter |

| Script | Purpose |
|---|---|
| `recreate-iac-defender-policies.ps1` | Recreate DFO baseline from JSON |

**Defender for Endpoint** (`M365 Configuration/IAC-DefenderForEndpoint-Policies-JSON/`):

| File | Purpose |
|---|---|
| `Import-DefenderPolicies.ps1` | Import MDE Intune policies from JSON |
| `Import-SecurityBaseline.ps1` | Import MDE security baseline |
| `Fix-SecurityBaseline.ps1` | Fix baseline drift |
| [README.md](M365%20Configuration/IAC-DefenderForEndpoint-Policies-JSON/DefenderForEndpoint/README.md) | Deployment instructions |

---

## 📧 Exchange

**[→ Deep Dive: Exchange/readme.md](Exchange/readme.md)**

Exchange Online configuration, mail flow security, and Proofpoint integration reference.

| File | What it covers |
|---|---|
| [exchange-settings-reference.md](Exchange/exchange-settings-reference.md) | CIS Exchange settings reference |
| [Exchange-Direct-Send-Detection-and-Remediation.md](Exchange/Exchange-Direct-Send-Detection-and-Remediation.md) | Detect and remediate direct send abuse |
| [IAC-DFO-Proofpoint-Configuration-Reference.md](Exchange/IAC-DFO-Proofpoint-Configuration-Reference.md) | Proofpoint + DFO configuration reference |

**Scripts** (`Exchange/scripts/`):

| Script | Purpose |
|---|---|
| `Invoke-MailboxAuditReview.ps1` | Run and export mailbox audit report |
| `IAC-DFO-MALWARE-AttachmentFilter-L2.ps1` | Level 2 malware attachment filter |

| Script (root Scripts/Exchange/) | Purpose |
|---|---|
| `disableinteractiveloginforsharedmailbox.ps1` | Disable interactive login on shared mailboxes |

---

## 📱 Intune

**[→ Deep Dive: Intune/readme.md](Intune/readme.md)**

Intune policy type reference and IAC policy baselines.

| File | What it covers |
|---|---|
| [intune-policy-types.md](Intune/intune-policy-types.md) | CSP · OMA-URI · Settings Catalog · DDM reference |
| [intune-policy-types.html](Intune/intune-policy-types.html) | Interactive policy types reference |

**Scripts** (`Scripts/Intune/`):

| Script | Purpose |
|---|---|
| `list-all-intune-policies.ps1` | List all current Intune policies |
| `export-iac-policies-json.ps1` | Export policies to JSON |
| `export-iac-policies-documentation.ps1` | Generate policy documentation |
| `recreate-iac-policies.ps1` | Recreate IAC baseline policies from JSON |
| `rename-intune-policies.ps1` | Rename policies to IAC naming convention |
| `create-windows-laps-policy.ps1` | Create Windows LAPS policy |
| `DisableMacFirewall.ps1` | macOS firewall policy script |
| `ExportPowershellPlatformScripts.ps1` | Export Intune PowerShell platform scripts |

**IAC Baseline** (`M365 Configuration/IAC-Intune-Policies-JSON/`): See [README-RecreateIACPolicies.md](M365%20Configuration/IAC-Intune-Policies-JSON/CreateIntunePolicyScripts/README-RecreateIACPolicies.md)

---

## 🗂️ Purview

**[→ Deep Dive: Purview/readme.md](Purview/readme.md)**

Sensitivity label taxonomy, DLP policies, and adaptive protection configuration.

| File | What it covers |
|---|---|
| [IAC-Sensitivity-Labels-Documentation.md](Purview/IAC-Sensitivity-Labels-Documentation.md) | Full sensitivity label configuration and best practices |
| [Sensitivity-Label-Taxonomy-Comparison.md](Purview/Sensitivity-Label-Taxonomy-Comparison.md) | Label taxonomy comparison and selection guide |
| [DLP-Confidential-ThirdParty-Block-NoRecipient.md](Purview/DLP-Confidential-ThirdParty-Block-NoRecipient.md) | DLP policy for blocking third-party confidential sharing |

**Scripts** (`Purview/`):

| Script | Purpose |
|---|---|
| `Enable-SensitivityLabelsPrerequisites.ps1` | Enable sensitivity label prerequisites |
| `SensitivityLabel.ps1` | Create and configure sensitivity labels |
| `Publish-SensitivityLabelPolicies.ps1` | Publish label policies to users |
| `Connect-ConditionalAccessTech-And-CreateDlp.ps1` | Create DLP policy with CA integration |
| `Create-Dlp-ConfidentialThirdParty-NoRecipient.ps1` | Create third-party confidential DLP rule |

---

## 🌐 SharePoint & OneDrive

SharePoint and OneDrive security configuration aligned to CIS benchmarks.

| File | What it covers |
|---|---|
| [Sharepoint-configuration.md](Sharepoint/Sharepoint-configuration.md) | CIS settings reference, sharing controls, access governance |

**Scripts** (`Scripts/Sharepoint/`):

| Script | Purpose |
|---|---|
| `New-SPOSiteOwnerGroup.ps1` | Create owner group for SPO site |
| `New-SPOSiteEntraOwnerGroup.ps1` | Create Entra-backed owner group |
| `Invoke-SPOSiteEntraOwnerGroup.ps1` | Apply Entra owner group to existing site |
| `Rename-SPOSiteGroups.ps1` | Rename SharePoint site groups to standard naming |

**IAC Policies** (`M365 Configuration/IAC-Sharepoint-Policies-JSON/`): See [readme.md](M365%20Configuration/IAC-Sharepoint-Policies-JSON/readme.md)

---

## ⚡ Power Platform

**[→ Deep Dive: PowerPlatform/readme.md](PowerPlatform/readme.md)**

Security hardening for Power Apps, Power Automate, Power Pages, Copilot Studio, and Dataverse — aligned to Well-Architected Framework, Zero Trust, and CIS Dynamics 365 benchmarks.

| File | What it covers |
|---|---|
| [PowerPlatform-Security-Guide.md](PowerPlatform/PowerPlatform-Security-Guide.md) | Full security hardening guide |

| Script (PowerPlatform/Scripts/) | Purpose |
|---|---|
| `Review-And-Resume-SuspendedFlows.ps1` | Audit and resume suspended Power Automate flows |

---

## 🗃️ M365 Configuration — IAC Policies

Exportable JSON baselines for every major M365 workload. Deploy with the corresponding recreate scripts.

| Folder | Contents | Deploy Script |
|---|---|---|
| `IAC-Entra-Policies-JSON/` | CA policies, named locations, security attributes | `recreate-iac-entra-policies.ps1` |
| `IAC-Defender-Policies-JSON/` | EOP + DFO email security policies | `recreate-iac-defender-policies.ps1` |
| `IAC-DefenderForEndpoint-Policies-JSON/` | MDE Intune + security baseline policies | `Import-DefenderPolicies.ps1` |
| `IAC-Intune-Policies-JSON/` | Full Intune device management baseline | `recreate-iac-policies.ps1` |
| `IAC-Admin-Center-Policies-JSON/` | Admin Center tenant settings | `import-admin-center-config.ps1` |
| `IAC-Sharepoint-Policies-JSON/` | SharePoint governance policies | — |

---

## 📜 Scripts

**[→ Scripts/readme.md](../Scripts/readme.md)**

General-purpose operational scripts organized by workload. See the subfolder readmes for detail.

| Folder | What's inside |
|---|---|
| `Scripts/AzureRunbooks/` | CA Group Monitor, Traveling User CA, SAML cert expiration alerts |
| `Scripts/EnterpriseApps/` | Service principal registration, verification, hide flag management |
| `Scripts/Entra/` | Baseline groups, CA groups, Entra settings, CA documentation export |
| `Scripts/EntraAuthMethods/` | TAP creation, phone import, MFA per-user legacy, unused auth methods audit |
| `Scripts/EntraIDSecurity/` | Diagnostic logs, disable SSPR for admins |
| `Scripts/Exchange/` | Shared mailbox interactive login control |
| `Scripts/Intune/` | Policy export, LAPS, recreate baseline, documentation |
| `Scripts/Sharepoint/` | SPO site owner group management |
| `Scripts/AdminCenter/` | Self-service trial enable/disable |

---

## 📡 Graph API Reference

**[→ graphapi/readme.md](../graphapi/readme.md)**

A practical engineer-focused cheat sheet for Microsoft Graph endpoints covering Entra ID, identity, groups, authentication methods, devices, and more. Copy-ready calls with real examples and explanations.

---

## 🎩 Harry Potter Demo

**[→ HarryPotter-Demo/readme.md](HarryPotter-Demo/readme.md)**

A full Microsoft 365 demo environment built around Harry Potter characters. Demonstrates Purview sensitivity labels, Copilot agents, SharePoint, guest identities, and authentication methods end-to-end.

| Sub-folder | What it contains |
|---|---|
| [HarryPotterPurviewDemo/](HarryPotter-Demo/HarryPotterPurviewDemo/) | Full provisioning scripts — users, groups, SharePoint, labels, TAPs |
| [Copilot/](HarryPotter-Demo/Copilot/) | Copilot agent definitions (HogwartsSpellcaster, SortingHat classifier) |
| [HogwartsSpellcaster/](HarryPotter-Demo/HogwartsSpellcaster/) | Teams app package + deployment guide |

---

## ⚙️ Prerequisites

See [PreRequisites/readme.md](PreRequisites/readme.md) for module and permission requirements before running any baseline scripts.

---

*Last updated: June 2026 · Jon Hope · Microsoft MVP · Security: Identity & Access*
