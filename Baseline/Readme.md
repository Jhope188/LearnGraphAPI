# IAC Master Documentation

**Complete Infrastructure as Code Policy Documentation**

**Generated:** January 16, 2026 21:27:18

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Entra ID (Identity & Access)](#entra-id-identity--access)
   - [Conditional Access Policies](#conditional-access-policies)
   - [Named Locations](#named-locations)
3. [Microsoft Intune (Device Management)](#microsoft-intune-device-management)
   - [Device Configuration Policies](#device-configuration-policies)
   - [Settings Catalog Policies](#settings-catalog-policies)
   - [Compliance Policies](#compliance-policies)
   - [Administrative Templates](#administrative-templates)
   - [Endpoint Security](#endpoint-security)
   - [Scripts](#scripts)
   - [Autopilot Profiles](#autopilot-profiles)

---

## Executive Summary

This master documentation provides a comprehensive overview of all Infrastructure as Code (IAC) policies deployed across the organization. These policies are organized into two main categories:

### Entra ID (Identity & Access Management)
Identity and access control policies that govern how users authenticate and access resources:
- **Conditional Access Policies**: Dynamic access controls based on conditions
- **Named Locations**: Trusted network locations and IP ranges

### Microsoft Intune (Device & Endpoint Management)
Device configuration and compliance policies that ensure endpoints meet security standards:
- **Device Configuration**: Platform-specific settings and configurations
- **Settings Catalog**: Modern, granular policy settings
- **Compliance Policies**: Required security baseline for devices
- **Administrative Templates**: Group Policy-style settings
- **Endpoint Security**: Security-focused configurations (antivirus, firewall, disk encryption)
- **Scripts**: PowerShell scripts for automation and remediation
- **Autopilot Profiles**: Automated device enrollment and setup

---
## Entra ID (Identity & Access)

Microsoft Entra ID (formerly Azure Active Directory) policies control authentication, authorization, and access to resources.

### Conditional Access Policies

Conditional Access policies evaluate signals such as user, device, location, and risk to make real-time access decisions.

#### IAC - APP - BLOCK - SharePoint-OneDrive-NonTrustedLocations 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** 1 app(s)

**Controls:** Block Access


#### IAC - APP - SESSION - O365 - Timeoutsettings 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** Office 365


#### IAC - APP – BLOCK – AVD - Exclude - AllowedAVDUsers 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** 2 app(s)

**Controls:** Block Access


#### IAC - APP – BLOCK – AVD - NonTrustedLocations 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** 2 app(s)

**Controls:** Block Access


#### IAC - GLOBAL - BLOCK - Authentication Transfer 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Block Access


#### IAC - GLOBAL - BLOCK - Device Code Auth Flow 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Block Access


#### IAC - GLOBAL - BLOCK - Unsupported Device Platforms 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Block Access


#### IAC - GLOBAL - GRANT - MFA - AllAdmins 🔴

**State:** `disabled`
**Applies To:** 14 role(s)

**Applications:** All cloud apps

**Controls:** MFA


#### IAC - GLOBAL - GRANT - MFA - External-Guest-Users 🔴

**State:** `disabled`
**Applies To:** 

**Applications:** All cloud apps

**Controls:** MFA


#### IAC - GLOBAL – BLOCK - Legacy Authentication 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Block Access


#### IAC - GLOBAL – BLOCK – Countries not Allowed - NoExclusions 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Block Access


#### IAC - GLOBAL – BLOCK – Countries not Allowed 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Block Access


#### IAC - GLOBAL – BLOCK – Service Accounts 🔴

**State:** `disabled`
**Applies To:** 1 group(s)

**Applications:** All cloud apps

**Controls:** Block Access


#### IAC - GLOBAL – SESSION – Admin Persistence (1 Hours) 🔴

**State:** `disabled`
**Applies To:** 11 role(s)

**Applications:** All cloud apps


#### IAC - GLOBAL – SESSION – All Users Persistence (9-12 Hours) 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps


#### IAC - INTUNE - BLOCK - RequireCompliantDevice - NonTrustedLocations 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Block Access


#### IAC - INTUNE - GRANT - RequireCompliantDevice 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Compliant Device, Hybrid Azure AD Join


#### IAC - INTUNE – GRANT – Device Registration from trusted location 🔴

**State:** `disabled`
**Applies To:** All users


#### IAC - INTUNE – GRANT – Mobile Apps and Desktop Clients 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** Compliant Device


#### IAC - INTUNE – GRANT – Mobile Device Access Requirements 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** Office 365

**Controls:** Compliant Device, compliantApplication


#### IAC - INTUNE – SESSION – Block File Downloads On Unmanaged Devices 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** Office 365


#### IAC - INTUNE – SESSION – BYOD Persistence 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps


#### IAC - P2 - GLOBAL - BLOCK - RiskyUsers - RegisterSecurityInfoRequirements 🔴

**State:** `disabled`
**Applies To:** All users

**Controls:** Block Access


#### IAC - P2 - GLOBAL – GRANT – High-Risk Sign-Ins 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps


#### IAC - P2 - GLOBAL – GRANT – High-Risk Users 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** MFA, passwordChange


#### IAC - P2 - GLOBAL – GRANT – Medium-Risk Sign-Ins 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** All cloud apps

**Controls:** MFA


#### IAC - P2 - GLOBAL – GRANT – Medium-Risk Users 🔴

**State:** `disabled`
**Applies To:** All users

**Applications:** 1 app(s)

**Controls:** MFA


### Named Locations

Named Locations define trusted network locations used in Conditional Access policies.

---

## Microsoft Intune (Device Management)

Microsoft Intune policies manage device configuration, compliance, and security across Windows, iOS, Android, and macOS platforms.

### Settings Catalog Policies

#### IAC - Intune - Config Refresh
**Settings Configured:** 1

<details>
<summary>View Settings</summary>

- **{providerid}**

</details>


#### IAC - macOS - OS Updates Configuration Profile
**Settings Configured:** 1

<details>
<summary>View Settings</summary>

- **com.apple.softwareupdate**

</details>


#### IAC - macOS - Platform SSO
**Settings Configured:** 1

<details>
<summary>View Settings</summary>

- **com.apple.extensiblesso**

</details>


#### IAC - Windows - Baseline Workstation Configuration Profile
**Settings Configured:** 7

<details>
<summary>View Settings</summary>

- **devicepasswordenabled**: 0
- **allowcortana**: 0
- **donotshowfeedbacknotifications**: 1
- **showpdfdefaultrecommendationsenabled**: 0
- **hiderecentlyaddedapps**: 1
- **simplifyquicksettings**: 1
- **configuretimezone**: `Eastern Standard Time`

</details>


#### IAC - Windows - Bitlocker Encryption Policy
**Assignments:** 1 assignment(s)

**Assigned To:**
- Group: bb8dd9b9-0c9c-4af9-a5b3-5e632f8066ca

**Settings Configured:** 11

<details>
<summary>View Settings</summary>

- **requiredeviceencryption**: 1
- **allowwarningforotherdiskencryption**: 0
- **encryptionmethodbydrivetype**: 1
- **systemdrivesencryptiontype**: 1
- **systemdrivesrequirestartupauthentication**: 1
- **systemdrivesminimumpinlength**: 0
- **systemdrivesenhancedpin**: 0
- **systemdrivesrecoveryoptions**: 1
- **fixeddrivesencryptiontype**: 1
- **fixeddrivesrecoveryoptions**: 1
- **removabledrivesconfigurebde**: 1

</details>


#### IAC - Windows - Block - WindowsStore
**Settings Configured:** 1

<details>
<summary>View Settings</summary>

- **2**: 0

</details>


#### IAC - Windows - Edge Configuration Profile
**Settings Configured:** 25

*Too many settings to display inline. See detailed documentation or JSON export for full configuration.*


#### IAC - Windows - Edge Favorites Profile
**Assignments:** 1 assignment(s)

**Assigned To:**
- Group: 656e073b-f717-4a5d-9f5a-d4d35783bca9

**Settings Configured:** 2

<details>
<summary>View Settings</summary>

- **managedfavorites**: 1
- **favoritesbarenabled**: 1

</details>


#### IAC - Windows - Edge Homepage Profile
**Assignments:** 1 assignment(s)

**Assigned To:**
- Group: 0a496479-9067-4b42-b4f7-4c144151e8e1

**Settings Configured:** 3

<details>
<summary>View Settings</summary>

- **restoreonstartup**: 1
- **homepagelocation**: 1
- **restoreonstartupurls**: 1

</details>


#### IAC - Windows - Google Chrome Extensions Profile
**Settings Configured:** 1

<details>
<summary>View Settings</summary>

- **extensioninstallforcelist**: 1

</details>


#### IAC - Windows - LAPs Configuration Profile
**Settings Configured:** 1

<details>
<summary>View Settings</summary>

- **enableadministratoraccountstatus**: 1

</details>


#### IAC - Windows - LAPs Policy
**Assignments:** 1 assignment(s)

**Assigned To:**
- All Devices

**Settings Configured:** 5

<details>
<summary>View Settings</summary>

- **backupdirectory**: 1
- **passwordcomplexity**: 4
- **passwordlength**: `14`
- **postauthenticationactions**: 1
- **postauthenticationresetdelay**: `24`

</details>


#### IAC - Windows - OneDrive Profile
**Assignments:** 1 assignment(s)

**Assigned To:**
- All Devices

**Settings Configured:** 3

<details>
<summary>View Settings</summary>

- **disablepersonalsync**: 1
- **kfmoptinnowizard**: 1
- **silentaccountconfig**: 1

</details>


#### IAC - Windows - Removable Storage Access
**Assignments:** 1 assignment(s)

**Assigned To:**

**Settings Configured:** 1

<details>
<summary>View Settings</summary>

- **2**: 1

</details>


#### IAC - Windows365 - DailyReboot
**Assignments:** 1 assignment(s)

**Assigned To:**
- Group: 9b355cc3-68a2-4c3e-b94b-4d7192b12011

**Settings Configured:** 1

<details>
<summary>View Settings</summary>

- **dailyrecurrent**: `03/31/2024 02:30:00`

</details>


#### IAC - Windows365 - SessionTimeout
**Assignments:** 1 assignment(s)

**Assigned To:**
- Group: 9b355cc3-68a2-4c3e-b94b-4d7192b12011

**Settings Configured:** 2

<details>
<summary>View Settings</summary>

- **2**: 0
- **devicepasswordenabled**: 0

</details>


### Compliance Policies
*No policies in this category*


### Endpoint Security
*No policies in this category*


### Scripts
*No policies in this category*


### Device Configuration Policies

#### IAC - Chrome - GeminiSettings

#### IAC - Windows - Autopilot Hybrid Domain Join Configuration Profile
**Assignments:** 1 assignment(s)

**Assigned To:**
- Group: 132d08c7-0a4b-4ded-aefb-aa4a92923539


#### IAC - Windows - Autopilot SkipUserStatusPage Configuration Profile
**Assignments:** 1 assignment(s)

**Assigned To:**
- Group: 132d08c7-0a4b-4ded-aefb-aa4a92923539


#### IAC - Windows - Data Collection Configuration Profile

#### IAC - Windows - Disable access to Windows Update Configuration Profile

### Administrative Templates

#### IAC - Windows - Google Chrome Local Network Access

### Autopilot Profiles
*No policies in this category*


---

## Summary Statistics

### Entra ID Policies
- **Conditional Access Policies:** 27
- **Named Locations:** 0

### Intune Policies
- **Settings Catalog Policies:** 16
- **Compliance Policies:** 0
- **Endpoint Security:** 0
- **Scripts:** 0
- **Device Configuration Policies:** 5
- **Administrative Templates:** 1
- **Autopilot Profiles:** 0

---

## Policy Management

### Export Locations

**Entra Policies JSON:** `/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON`
**Intune Policies JSON:** `/Users/jon/Desktop/BaslineSetup/IAC-Intune-Policies-JSON`

### Documentation Scripts

- **Entra Export:** `/Users/jon/Desktop/BaslineSetup/Scripts/Entra/export-iac-entra-policies-json.ps1`
- **Entra Recreate:** `/Users/jon/Desktop/BaslineSetup/Scripts/Entra/recreate-iac-entra-policies.ps1`
- **Intune Export:** `/Users/jon/Desktop/BaslineSetup/Scripts/Intune/export-iac-policies-json.ps1`
- **Intune Recreate:** `/Users/jon/Desktop/BaslineSetup/Scripts/Intune/recreate-iac-policies.ps1`

### Related Documentation

- **Detailed Entra Documentation:** [IAC-Entra-Policies-Documentation.md](IAC-Entra-Policies-Documentation.md)
- **Detailed Intune Documentation:** [IAC-Intune-Policies-Documentation.md](IAC-Intune-Policies-Documentation.md)
- **Entra README:** [Scripts/Entra/README-RecreateIACEntraPolicies.md](Scripts/Entra/README-RecreateIACEntraPolicies.md)
- **Intune README:** [Scripts/Intune/README-RecreateIACPolicies.md](Scripts/Intune/README-RecreateIACPolicies.md)

---

*This master documentation provides a high-level overview. For detailed policy configurations, settings, and JSON exports, refer to the individual documentation files listed above.*

