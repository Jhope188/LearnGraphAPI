# IAC Master Documentation

**Complete Infrastructure as Code Policy Documentation**

**Last Updated:** January 20, 2026  
**Deployed to Tenant:** 44176a9d-4a62-469c-a336-ad1f8e30927c (M365x93722695.onmicrosoft.com) 

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Entra ID (Identity & Access)](#entra-id-identity--access)
   - [Conditional Access Policies](#conditional-access-policies)
   - [Named Locations](#named-locations)
3. [Defender for Office 365 (Email Security)](#defender-for-office-365-email-security)
   - [Anti-Phishing Policies](#anti-phishing-policies)
   - [Anti-Spam Policies](#anti-spam-policies)
   - [Anti-Malware Policies](#anti-malware-policies)
   - [Safe Links Policies](#safe-links-policies)
   - [Safe Attachments Policies](#safe-attachments-policies)
4. [Admin Center Configuration (Tenant Settings)](#admin-center-configuration-tenant-settings)
   - [Authorization Policy Settings](#authorization-policy-settings)
   - [Self-Service Purchase Policies](#self-service-purchase-policies)
   - [Default User Role Permissions](#default-user-role-permissions)
5. [Microsoft Intune (Device Management)](#microsoft-intune-device-management)
   - [Device Configuration Policies](#device-configuration-policies)
   - [Settings Catalog Policies](#settings-catalog-policies)
   - [Compliance Policies](#compliance-policies)
   - [Administrative Templates](#administrative-templates)
   - [Endpoint Security](#endpoint-security)
   - [Scripts](#scripts)
   - [Autopilot Profiles](#autopilot-profiles)


---

## Executive Summary

This master documentation provides a comprehensive overview of all Infrastructure as Code (IAC) policies deployed across the organization. These policies are organized into four main categories:

### Entra ID (Identity & Access Management)
Identity and access control policies that govern how users authenticate and access resources:
- **Conditional Access Policies**: 27 policies - Dynamic access controls based on conditions
- **Named Locations**: 4 locations - Trusted network locations and IP ranges
- **Custom Authentication Strengths**: 1 custom strength - Advanced MFA methods

### Defender for Office 365 (Email Security)
Email security policies that protect against malicious content and phishing attacks:
- **Anti-Phishing**: Protection against impersonation and spoofing attempts
- **Anti-Spam**: Content filtering for inbound and outbound email
- **Anti-Malware**: Attachment scanning and malware protection
- **Safe Links**: URL detonation and time-of-click protection
- **Safe Attachments**: File sandboxing and zero-day protection

### Admin Center Configuration (Tenant Settings)
Tenant-wide administrative settings that control user capabilities and security features:
- **Authorization Policy**: Controls for email-based subscriptions, tenant creation, and legacy MSOL PowerShell
- **Self-Service Purchases**: Management of user-initiated product purchases (27 products)
- **Default User Permissions**: User capabilities for app registration, security group creation, Bitlocker key access, and directory reading

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

**Total Policies:** 27  
**Deployment Date:** January 20, 2026  
**Target Tenant:** 44176a9d-4a62-469c-a336-ad1f8e30927c (M365x93722695.onmicrosoft.com)

---

#### 1. IAC - APP - BLOCK - SharePoint-OneDrive-NonTrustedLocations 🔴

**Policy ID:** `109d4155-3d19-4f57-9814-3c5afad470aa`  
**State:** Disabled  
**Category:** Application Protection  
**Purpose:** Block SharePoint and OneDrive access from non-trusted locations

---

#### 2. IAC - APP - SESSION - O365 - Timeoutsettings 🔴

**Policy ID:** `6756b8f6-def1-49c5-a04d-89ea91597cb5`  
**State:** Disabled  
**Category:** Session Management  
**Purpose:** Configure session timeout settings for Office 365 applications

---

#### 3. IAC - APP – BLOCK – AVD - Exclude - AllowedAVDUsers 🔴

**Policy ID:** `a291c604-da60-4967-9102-5e8a067f74d1`  
**State:** Disabled  
**Category:** Azure Virtual Desktop Protection  
**Purpose:** Block AVD access except for allowed users

---

#### 4. IAC - APP – BLOCK – AVD - NonTrustedLocations 🔴

**Policy ID:** `70f46445-89e8-43c0-b5e6-c7ca504137b8`  
**State:** Disabled  
**Category:** Azure Virtual Desktop Protection  
**Purpose:** Block AVD access from non-trusted network locations

---

#### 5. IAC - GLOBAL - BLOCK - Authentication Transfer 🔴

**Policy ID:** `6f37138a-a838-4b2d-bade-f81cbec243a7`  
**State:** Disabled  
**Category:** Security Baseline  
**Purpose:** Block authentication transfer attacks

---

#### 6. IAC - GLOBAL - BLOCK - Device Code Auth Flow 🔴

**Policy ID:** `e34f605a-c20e-451c-bfd3-62e3693868ba`  
**State:** Disabled  
**Category:** Security Baseline  
**Purpose:** Block device code authentication flow to prevent phishing attacks

---

#### 7. IAC - GLOBAL - BLOCK - Unsupported Device Platforms 🔴

**Policy ID:** `403645fd-9e97-4d6b-a66e-9c863586241e`  
**State:** Disabled  
**Category:** Device Management  
**Purpose:** Block access from unsupported device platforms

---

#### 8. IAC - GLOBAL - GRANT - MFA - AllAdmins 🔴

**Policy ID:** `a138dcd3-f878-4f0d-a9ad-45e6c38e9c09`  
**State:** Disabled  
**Category:** Administrator Protection  
**Purpose:** Require MFA for all administrative roles

---

#### 9. IAC - GLOBAL - GRANT - MFA - External-Guest-Users 🔴

**Policy ID:** `0dad2669-ecfc-41e0-9488-f898001006ea`  
**State:** Disabled  
**Category:** Guest User Protection  
**Purpose:** Require MFA for external and guest users

---

#### 10. IAC - GLOBAL – BLOCK - Legacy Authentication 🔴

**Policy ID:** `d210a4e3-c9ac-44de-b13-e045743983f5`  
**State:** Disabled  
**Category:** Security Baseline  
**Purpose:** Block legacy authentication protocols

---

#### 11. IAC - GLOBAL – BLOCK – Countries not Allowed 🔴

**Policy ID:** `6bfbd7ba-fb48-424a-bdfb-b0934275c980`  
**State:** Disabled  
**Category:** Geographic Restriction  
**Purpose:** Block access from restricted countries (with exclusions)

---

#### 12. IAC - GLOBAL – BLOCK – Countries not Allowed - NoExclusions 🔴

**Policy ID:** `d9fe9d51-f837-479c-90f0-446b57939ac1`  
**State:** Disabled  
**Category:** Geographic Restriction  
**Purpose:** Block access from restricted countries (no exclusions)

---

#### 13. IAC - GLOBAL – BLOCK – Service Accounts 🔴

**Policy ID:** `ee06dc06-7f8f-42e7-9948-0eeeb829fa79`  
**State:** Disabled  
**Category:** Service Account Protection  
**Purpose:** Block service accounts from non-trusted locations

---

#### 14. IAC - GLOBAL – SESSION – Admin Persistence (1 Hours) 🔴

**Policy ID:** `ae7669ef-8ce7-4473-9b7a-c91e8071c53f`  
**State:** Disabled  
**Category:** Session Management  
**Purpose:** Set 1-hour session persistence for administrators

---

#### 15. IAC - GLOBAL – SESSION – All Users Persistence (9-12 Hours) 🔴

**Policy ID:** `f610c72d-e0de-4328-b3ed-4f88cbeea4e5`  
**State:** Disabled  
**Category:** Session Management  
**Purpose:** Set 9-12 hour session persistence for all users

---

#### 16. IAC - INTUNE - BLOCK - RequireCompliantDevice - NonTrustedLocations 🔴

**Policy ID:** `0a5ccb36-ae98-4cce-95e8-29590509444b`  
**State:** Disabled  
**Category:** Device Compliance  
**Purpose:** Block non-compliant devices from non-trusted locations

---

#### 17. IAC - INTUNE - GRANT - RequireCompliantDevice 🔴

**Policy ID:** `0e7033c0-6543-4be2-948c-93596700fae2`  
**State:** Disabled  
**Category:** Device Compliance  
**Purpose:** Require compliant or hybrid Azure AD joined devices

---

#### 18. IAC - INTUNE – GRANT – Device Registration from trusted location 🔴

**Policy ID:** `dff33769-98c3-4c58-85b3-7e1e59774e6d`  
**State:** Disabled  
**Category:** Device Registration  
**Purpose:** Require MFA for device registration from trusted locations  
**Authentication Strength:** Multifactor authentication (Built-in)

---

#### 19. IAC - INTUNE – GRANT – Mobile Apps and Desktop Clients 🔴

**Policy ID:** `a77f93c3-8ea1-44fe-b2f2-ff093949e8e1`  
**State:** Disabled  
**Category:** Device Compliance  
**Purpose:** Require compliant devices for mobile and desktop clients

---

#### 20. IAC - INTUNE – GRANT – Mobile Device Access Requirements 🔴

**Policy ID:** `f4a8ac7b-4106-498a-9376-36afdf429a7f`  
**State:** Disabled  
**Category:** Mobile Device Management  
**Purpose:** Require compliant devices for Office 365 mobile access

---

#### 21. IAC - INTUNE – SESSION – Block File Downloads On Unmanaged Devices 🔴

**Policy ID:** `76f93b1d-d34c-40aa-a10c-193c7214d3c8`  
**State:** Disabled  
**Category:** Data Protection  
**Purpose:** Block file downloads on unmanaged devices

---

#### 22. IAC - INTUNE – SESSION – BYOD Persistence 🔴

**Policy ID:** `5b4c6c9d-4960-4b1e-997f-7d155483053a`  
**State:** Disabled  
**Category:** Session Management  
**Purpose:** Configure session persistence for BYOD devices

---

#### 23. IAC - P2 - GLOBAL - BLOCK - RiskyUsers - RegisterSecurityInfoRequirements 🔴

**Policy ID:** `f14f2321-e8b9-413f-b313-2357925e13ce`  
**State:** Disabled  
**Category:** Identity Protection  
**Purpose:** Block risky users from registering security information  
**Requires:** Entra ID P2 license

---

#### 24. IAC - P2 - GLOBAL – GRANT – High-Risk Sign-Ins 🔴

**Policy ID:** `80c58aa4-2fe4-42a0-983a-df2b8b8c6978`  
**State:** Disabled  
**Category:** Identity Protection  
**Purpose:** Require strong authentication for high-risk sign-ins  
**Authentication Strength:** Modern MFA + TAP (Custom)  
**Requires:** Entra ID P2 license

---

#### 25. IAC - P2 - GLOBAL – GRANT – High-Risk Users 🔴

**Policy ID:** `ea8a2827-e3f1-49b6-a042-766c2a692ad8`  
**State:** Disabled  
**Category:** Identity Protection  
**Purpose:** Require MFA and password change for high-risk users  
**Requires:** Entra ID P2 license

---

#### 26. IAC - P2 - GLOBAL – GRANT – Medium-Risk Sign-Ins 🔴

**Policy ID:** `1c1bd898-4011-486f-89c6-f73137df3d87`  
**State:** Disabled  
**Category:** Identity Protection  
**Purpose:** Require MFA for medium-risk sign-ins  
**Requires:** Entra ID P2 license

---

#### 27. IAC - P2 - GLOBAL – GRANT – Medium-Risk Users 🔴

**Policy ID:** `d1cbbdd9-ee1f-4582-9970-59560e1ff378`  
**State:** Disabled  
**Category:** Identity Protection  
**Purpose:** Require MFA for medium-risk users  
**Requires:** Entra ID P2 license

---

### Custom Authentication Strengths

Custom authentication strengths define specific combinations of authentication methods required for access.

#### Modern MFA + TAP

**Authentication Strength ID:** `3c62472b-475e-4674-b63d-1cabdf66e656`  
**Type:** Custom  
**Purpose:** Enhanced MFA with Temporary Access Pass support  
**Allowed Methods:** 5 authentication combinations

<details>
<summary>View Allowed Combinations</summary>

- **Windows Hello for Business** - Biometric or PIN-based authentication
- **FIDO2 Security Key** - Hardware security key authentication
- **X.509 Certificate (Multi-Factor)** - Certificate-based authentication
- **Temporary Access Pass (One-Time)** - Single-use time-limited pass
- **Temporary Access Pass (Multi-Use)** - Reusable time-limited pass

</details>

**Used By Policies:**
- IAC - P2 - GLOBAL – GRANT – High-Risk Sign-Ins


---

### Named Locations

Named Locations define trusted network locations and geographic regions used in Conditional Access policies.

**Total Locations:** 4  
**Deployment Date:** January 20, 2026  
**Target Tenant:** 44176a9d-4a62-469c-a336-ad1f8e30927c (M365x93722695.onmicrosoft.com)

---

#### IP-Based Named Locations (3)

##### 1. IAC - Trusted Locations (IP)

**Location ID:** `06eef006-9dac-4711-a42c-4203e381251a`  
**Type:** IP Named Location  
**Trusted:** Yes  
**Purpose:** Trusted IP ranges for IAC infrastructure and office locations  
**Used By Policies:**
- IAC - GLOBAL – BLOCK – Service Accounts (exclusion)
- Other location-based access policies

---

##### 2. IAC - Inforcer (IP)

**Location ID:** `06569a1d-f02c-477e-a9e8-2e20d9f9221b`  
**Type:** IP Named Location  
**Trusted:** Yes  
**Purpose:** IP ranges for IAC Inforcer service infrastructure  
**Used By Policies:**
- Service account authentication policies
- Infrastructure access policies

---

##### 3. IAC - EntraConnect(IP)

**Location ID:** `00b95f30-bd7f-4a93-b1f9-0b70101f66e8`  
**Type:** IP Named Location  
**Trusted:** Yes  
**Purpose:** IP addresses for IAC Entra Connect synchronization servers  
**Used By Policies:**
- Directory synchronization access policies
- Service account authentication policies

---

#### Country-Based Named Locations (1)

##### 4. IAC - Blocked Countries

**Location ID:** `18abd940-3aa0-4903-9457-8c8ff9ace93d`  
**Type:** Country Named Location  
**Purpose:** List of countries blocked for security and compliance reasons  
**Include Unknown Regions:** Configurable  
**Used By Policies:**
- IAC - GLOBAL – BLOCK – Countries not Allowed
- IAC - GLOBAL – BLOCK – Countries not Allowed - NoExclusions

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

#### IAC - Win - Baseline - Compliance - Policy
**Platform:** Windows 10 and later

Standard Windows compliance policy that enforces baseline security requirements for managed devices.

**Location:** `/Users/jon/Desktop/BaslineSetup/IAC-Intune-Policies-JSON/Compliance/IAC-Win-Baseline-Compliance-Policy.json`

### Custom Compliance Policies

#### LAPS Compliance Policy
**Platform:** Windows 10 and later  
**Policy Type:** Custom Compliance (Discovery Script)

**Purpose:** Validates that Windows Local Administrator Password Solution (LAPS) is actively processing on managed devices by checking for recent password rotation events.

**How It Works:**
- **Detection Script** (`LAPSComplianceScript.ps1`): Queries Windows event log for LAPS successful password rotation events (Event ID 10004) within the last 2 days
- **Compliance Rule** (`LAPSCompliance.json`): Requires the `WindowsLAPSProcessing` setting to return `true`, indicating active LAPS management
- **Remediation:** If LAPS isn't processing, devices are marked non-compliant and users receive guidance to check LAPS configuration

**Files:**
- **Detection Script:** `/Users/jon/Desktop/BaslineSetup/IAC-Intune-Policies-JSON/CustomPolicy/LAPSComplianceScript.ps1`
- **Compliance JSON:** `/Users/jon/Desktop/BaslineSetup/IAC-Intune-Policies-JSON/CustomPolicy/LAPSCompliance.json`

**Reference:** [Microsoft Learn - Windows LAPS Overview](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-overview)

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
- **Named Locations:** 4 (3 IP-based, 1 Country-based)

### Intune Policies
- **Settings Catalog Policies:** 16
- **Compliance Policies:** 1
- **Custom Compliance Policies:** 1 (LAPS)
- **Endpoint Security:** 0
- **Scripts:** 0
- **Device Configuration Policies:** 5
- **Administrative Templates:** 1
- **Autopilot Profiles:** 0

---

## Defender for Office 365 (Email Security)


Defender for Office 365 policies provide advanced threat protection for email and collaboration tools.

### Anti-Phishing Policies

Anti-phishing policies protect against impersonation attacks and spoofing attempts.

#### IAC - DfO - [Anti-Phishing] for [All Domains] 🟢

- **Enabled:** True
- **Priority:** 0
- **Phishing Threshold:** 1
- **Mailbox Intelligence:** Enabled
- **Applies To Domains:** M365x37845673.onmicrosoft.com

### Anti-Spam Policies

Anti-spam policies define actions for different types of spam and bulk email.

#### IAC - DfO - [Anti-Spam] [Inbound] [All Domains]

- **Priority:** 0
- **Spam Action:** MoveToJmf
- **High Confidence Spam Action:** MoveToJmf
- **Bulk Threshold:** 7
- **Applies To Domains:** M365x37845673.onmicrosoft.com

#### IAC - DfO - [Anti-Spam] [Outbound] [All Domains]

- **Priority:** 1
- **Recipient Limit (External/Hour):** 500
- **Recipient Limit (Internal/Hour):** 1000
- **Recipient Limit (Per Day):** 1000
- **Action When Threshold Reached:** BlockUserForToday
- **Auto-Forwarding Mode:** Off
- **Applies To Domains:** M365x37845673.onmicrosoft.com

### Anti-Malware Policies

Anti-malware policies scan attachments and provide zero-hour auto purge (ZAP) for malware.

#### IAC - DfO - [Anti-Malware] for [All Domains] 🟢

- **ZAP Enabled:** True
- **Priority:** 0
- **File Filter:** Enabled
- **Applies To Domains:** M365x37845673.onmicrosoft.com

### Safe Links Policies

Safe Links policies provide time-of-click protection and URL rewriting for malicious links.

#### IAC - DfO - [Safe Links] for [All Domains]

- **Priority:** 0
- **Scan URLs:** True
- **Internal Senders:** True

### Safe Attachments Policies

Safe Attachments policies sandbox unknown attachments in a virtual environment before delivery.

#### IAC - DfO - [Safe Attachments] for [All Domains] 🔴

- **Enabled:** False
- **Priority:** 0
- **Action:** Allow


---

# Microsoft 365 Administrative Center Configuration Documentation

**Last Updated:** January 17, 2026

This document describes the Microsoft 365 Administrative Center features and their current configuration status for your tenant.

---

## Table of Contents

1. [Authorization Policy Settings](#authorization-policy-settings)
2. [Self-Service Purchase Policies](#self-service-purchase-policies)
3. [Default User Role Permissions](#default-user-role-permissions)
4. [Management Scripts](#management-scripts)

---

## Authorization Policy Settings

These settings control tenant-wide user capabilities related to self-service features and trials.

### Email-Based Subscriptions (Self-Service Trials)

**Setting:** `AllowedToSignUpEmailBasedSubscriptions`

**Description:** Controls whether users can sign up for email-based subscriptions and trials using their organizational email address.

**Recommended Value:** `False` (Disabled)

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can sign up for Microsoft services trials independently
- When **Disabled**: Prevents users from creating trial subscriptions, giving IT full control over service adoption

**Management:**
```powershell
# Disable self-service email-based subscriptions
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    allowedToSignUpEmailBasedSubscriptions = $false
}

# Enable self-service email-based subscriptions
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    allowedToSignUpEmailBasedSubscriptions = $true
}
```

---

### Email Verified Users Can Join Organization

**Setting:** `AllowEmailVerifiedUsersToJoinOrganization`

**Description:** Controls whether users with verified email addresses can join the organization without an invitation.

**Recommended Value:** `False` (Disabled) for most organizations

**Current Status:** ⚠️ `True` (Enabled) - **Does NOT match recommendation**

**Impact:**
- When **Enabled**: Any user with a verified email can request to join your organization
- When **Disabled**: Only invited users can join the organization (recommended for security)

---

### Block Legacy MSOL PowerShell

**Setting:** `BlockMsolPowerShell`

**Description:** Controls whether the legacy MSOnline (MSOL) PowerShell module can be used to manage your tenant.

**Recommended Value:** `True` (Enabled) - blocks legacy module, forces modern Microsoft Graph

**Current Status:** ⚠️ `False` (Disabled) - **Does NOT match recommendation**

**Impact:**
- When **Enabled**: Forces use of modern Microsoft Graph PowerShell cmdlets (recommended)
- When **Disabled**: Allows continued use of deprecated MSOnline module

**Security Note:** Microsoft recommends blocking MSOL PowerShell and transitioning to Microsoft Graph PowerShell for improved security and functionality.

---

## Self-Service Purchase Policies

Self-service purchase allows users to purchase subscriptions directly using their corporate credit card, without IT approval. These policies can be controlled per product.

### Policy: AllowSelfServicePurchase

**Description:** Controls whether users can make self-service purchases of Microsoft products.

**Recommended Value:** `Disabled` for most products in enterprise environments

**Current Status:** ✅ All 27 products are **Disabled** - **Matches recommendation**

**Products Currently Configured:**

| Product Name | Current Setting | Status |
|-------------|----------------|--------|
| Power Apps per user | ✅ Disabled | Matches recommendation |
| Power Automate per user | ✅ Disabled | Matches recommendation |
| Power Automate RPA | ✅ Disabled | Matches recommendation |
| Power Automate Per User with Attended RPA | ✅ Disabled | Matches recommendation |
| Power BI Pro | ✅ Disabled | Matches recommendation |
| Power BI Premium per user | ✅ Disabled | Matches recommendation |
| Project Plan 1 | ✅ Disabled | Matches recommendation |
| Project Plan 3 | ✅ Disabled | Matches recommendation |
| Visio Plan 1 | ✅ Disabled | Matches recommendation |
| Visio Plan 2 | ✅ Disabled | Matches recommendation |
| Microsoft 365 F3 | ✅ Disabled | Matches recommendation |
| Microsoft 365 Copilot | ✅ Disabled | Matches recommendation |
| Windows 365 Enterprise | ✅ Disabled | Matches recommendation |
| Windows 365 Business | ✅ Disabled | Matches recommendation |
| Windows 365 Business with Windows Hybrid Benefit | ✅ Disabled | Matches recommendation |
| Viva Learning | ✅ Disabled | Matches recommendation |
| Viva Goals | ✅ Disabled | Matches recommendation |
| Dynamics 365 Marketing | ✅ Disabled | Matches recommendation |
| Dynamics 365 Marketing Attach | ✅ Disabled | Matches recommendation |
| Dynamics 365 Marketing Additional Application | ✅ Disabled | Matches recommendation |
| Dynamics 365 Marketing Additional Non-Prod Application | ✅ Disabled | Matches recommendation |
| Teams Exploratory | ✅ Disabled | Matches recommendation |
| Teams Essentials | ✅ Disabled | Matches recommendation |
| Teams Premium | ✅ Disabled | Matches recommendation |
| Python in Excel | ✅ Disabled | Matches recommendation |
| Microsoft Purview Discovery | ✅ Disabled | Matches recommendation |
| Microsoft ClipChamp | ✅ Disabled | Matches recommendation |

**Management:**

```powershell
# Disable self-service purchase for a specific product
Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
    -ProductId <ProductId> -Enabled $false

# Enable self-service purchase for a specific product
Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
    -ProductId <ProductId> -Enabled $true

# View all product policies
Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase | 
    Select-Object ProductName, PolicyValue | 
    Format-Table -AutoSize
```

**To Disable All Products:**
```powershell
# Get all products and disable self-service purchase
$products = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
foreach ($product in $products) {
    if ($product.PolicyValue -eq "Enabled") {
        Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
            -ProductId $product.ProductId -Enabled $false
        Write-Host "Disabled: $($product.ProductName)"
    }
}
```

---

## Default User Role Permissions

These settings define what standard (non-admin) users can do in your Microsoft 365 tenant.

### Can Create Applications

**Setting:** `AllowedToCreateApps`

**Description:** Controls whether users can register applications in Azure AD.

**Recommended Value:** `False` for most enterprises

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Any user can register applications that can access tenant resources
- When **Disabled**: Only administrators can register applications (recommended for security)

---

### Can Create Security Groups

**Setting:** `AllowedToCreateSecurityGroups`

**Description:** Controls whether users can create security groups.

**Recommended Value:** `False` for most enterprises

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can create security groups and manage membership
- When **Disabled**: Only administrators can create security groups (recommended for governance)

---

### Can Create Tenants

**Setting:** `AllowedToCreateTenants`

**Description:** Controls whether users can create new Azure AD tenants.

**Recommended Value:** `True` (typically allowed as it doesn't affect current tenant security)

**Current Status:** ⚠️ `False` (Disabled) - **More restrictive than recommendation**

**Impact:**
- When **Enabled**: Users can create their own separate Azure AD tenants
- When **Disabled**: Prevents tenant creation by standard users

**Note:** Creating a new tenant is a separate environment and doesn't impact your organization's security. Your current setting is more restrictive but acceptable.

---

### Can Read Bitlocker Keys for Owned Devices

**Setting:** `AllowedToReadBitlockerKeysForOwnedDevice`

**Description:** Controls whether users can view their own device's Bitlocker recovery keys in Azure AD.

**Recommended Value:** `True` (Enabled) - allows self-service recovery

**Current Status:** ✅ `True` (Enabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can retrieve their own Bitlocker keys without contacting helpdesk
- When **Disabled**: Only administrators can view Bitlocker keys (increases helpdesk burden)

---

### Can Read Other Users

**Setting:** `AllowedToReadOtherUsers`

**Description:** Controls whether users can view information about other users in the directory.

**Recommended Value:** `True` for most organizations (enables collaboration)

**Current Status:** ✅ `True` (Enabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can search for and view other users' profiles (useful for collaboration)
- When **Disabled**: Users cannot see other users in the directory (limits collaboration)

---

## Management Scripts

### Available Scripts

1. **admincenterconfig.ps1** - Sets administrative center configuration (disables trials)
2. **export-admin-center-config.ps1** - Exports current configuration to JSON

### Usage

**To Configure Admin Center (Disable Trials):**
```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts
./admincenterconfig.ps1
```

**To Export Current Configuration:**
```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts
./export-admin-center-config.ps1
```

This will create: `/Users/jon/Desktop/BaslineSetup/Admin-Center-Configuration.json`

---

## Quick Reference: Recommended Settings for Enterprise

**Last Updated:** January 17, 2026 16:10:41

| Setting | Recommended | Current | Status |
|---------|------------|---------|--------|
| Email-based subscriptions | ❌ Disabled | ❌ Disabled | ✅ Match |
| Email verified users can join | ❌ Disabled | ✅ Enabled | ⚠️ **Action Required** |
| Block legacy MSOL PowerShell | ✅ Enabled | ❌ Disabled | ⚠️ **Action Required** |
| Self-service purchases (27 products) | ❌ Disabled (all) | ❌ Disabled (all) | ✅ Match |
| Users can create apps | ❌ Disabled | ❌ Disabled | ✅ Match |
| Users can create security groups | ❌ Disabled | ❌ Disabled | ✅ Match |
| Users can create tenants | ✅ Enabled | ❌ Disabled | ℹ️ More restrictive |
| Users can read Bitlocker keys | ✅ Enabled | ✅ Enabled | ✅ Match |
| Users can read other users | ✅ Enabled | ✅ Enabled | ✅ Match |

**Legend:**
- ✅ Match = Current setting matches recommendation
- ⚠️ **Action Required** = Current setting does not match recommendation (security/compliance concern)
- ℹ️ More restrictive = Current setting is more restrictive than recommendation (acceptable)

### Summary
- **7 of 9 settings** match recommendations (78% compliance)
- **2 settings require action** to align with security best practices
- **0 critical security gaps** (self-service purchases are properly disabled)

---

## Security & Governance Impact

### High Priority (Disable Recommended)
- **Self-service trials** - Prevents shadow IT and uncontrolled costs
- **Self-service purchases** - Prevents unmanaged licensing and budget overruns
- **User app registration** - Prevents potential security vulnerabilities

### Medium Priority (Configure Based on Needs)
- **Security group creation** - Balance between governance and user autonomy
- **Block MSOL PowerShell** - Forces modern authentication and improved security

### Low Priority (Usually Enable)
- **Bitlocker key self-service** - Reduces helpdesk burden
- **Read other users** - Enables collaboration and communication

---

## Compliance Considerations

- **Data Governance:** Disabling self-service purchases helps maintain data governance policies
- **Cost Control:** Prevents users from making unauthorized purchases on corporate accounts
- **Shadow IT Prevention:** Disabling trials prevents users from creating unmanaged workloads
- **Audit Trail:** Centralized IT management enables better audit logging and compliance reporting

---

## Next Steps

### ⚠️ Actions Required

**Priority 1: Address Security Gaps**

1. **Disable Email Verified Users to Join Organization**
   ```powershell
   Update-MgPolicyAuthorizationPolicy -BodyParameter @{
       AllowEmailVerifiedUsersToJoinOrganization = $false
   }
   ```
   **Risk:** Currently allows any user with verified email to request org access

2. **Enable Block for Legacy MSOL PowerShell**
   ```powershell
   Update-MgPolicyAuthorizationPolicy -BodyParameter @{
       BlockMsolPowerShell = $true
   }
   ```
   **Risk:** Legacy module lacks modern security features and is deprecated

**Priority 2: Optional - Allow Tenant Creation**
   ```powershell
   Update-MgPolicyAuthorizationPolicy -BodyParameter @{
       DefaultUserRolePermissions = @{
           AllowedToCreateTenants = $true
       }
   }
   ```
   **Note:** This is optional - your current setting is more restrictive but acceptable

### ✅ Validated Settings (No Action Needed)

- Email-based subscriptions: Properly disabled
- Self-service purchases: All 27 products properly disabled
- User app registration: Properly disabled
- Security group creation: Properly disabled
- Bitlocker self-service: Properly enabled
- User directory reading: Properly enabled

### Documentation Tasks

1. ✅ Export completed (January 17, 2026 16:10:41)
2. ✅ Configuration reviewed against recommendations
3. ⏭️ Apply fixes for 2 security gaps
4. ⏭️ Re-export configuration to verify changes
5. ⏭️ Document in change management system
6. ⏭️ Include in master IAC documentation

---

## Security Best Practices: Why These Two Settings Matter

### 🔒 Why Block Legacy MSOL PowerShell (MSOnline Module)

**Security & Compliance Reasons:**

1. **Deprecated Authentication Methods**
   - MSOL uses legacy authentication protocols that don't support modern security features
   - No support for Conditional Access policies during authentication
   - Cannot enforce Multi-Factor Authentication (MFA) requirements
   - Lacks certificate-based authentication options

2. **Limited Security Controls**
   - No support for Privileged Identity Management (PIM)
   - Cannot leverage Azure AD Identity Protection risk detections
   - Missing audit logging capabilities available in Microsoft Graph
   - No support for Continuous Access Evaluation (CAE)

3. **Operational Risk**
   - Microsoft has officially deprecated the MSOnline module
   - No new features or security updates being developed
   - Will eventually be retired completely by Microsoft
   - Scripts using MSOL will break without warning when service ends

4. **Compliance & Audit Trail**
   - Limited logging compared to Microsoft Graph API calls
   - Harder to track who did what and when
   - Insufficient detail for compliance audits (SOX, ISO 27001, etc.)
   - Cannot differentiate between automated scripts and interactive sessions

5. **Zero Trust Architecture Incompatibility**
   - Zero Trust requires continuous verification of identity and device state
   - MSOL's authentication model doesn't align with Zero Trust principles
   - Modern Graph API supports identity-driven security controls

**Migration Path:** Microsoft Graph PowerShell provides all MSOL functionality plus modern security features. Blocking MSOL forces adoption of better security practices.

**Real-World Impact:** Organizations that don't block MSOL often have:
- Service accounts using stored credentials with no MFA
- Scripts running with excessive permissions
- No visibility into automated operations
- Higher risk of credential compromise

---

### 🚪 Why Disable "Allow Email Verified Users to Join Organization"

**Security & Identity Governance Reasons:**

1. **Uncontrolled External Access**
   - When enabled, anyone with a verified email address (Gmail, Yahoo, Hotmail, etc.) can request to join your organization
   - Creates a backdoor for unauthorized access attempts
   - IT has no advance control over who can even request access
   - Increases attack surface for social engineering

2. **Identity & Access Management (IAM) Bypass**
   - Circumvents your formal user provisioning process
   - Users gain access before proper background checks or approval workflows
   - Breaks integration with HR systems and automated provisioning
   - Creates "shadow accounts" outside normal user lifecycle management

3. **Guest vs Member Confusion**
   - Users added through email verification often have incorrect account types
   - May receive higher privileges than intended (Member instead of Guest)
   - Difficult to audit and track these "self-invited" accounts
   - Compliance frameworks require formal approval for all access

4. **Data Exfiltration Risk**
   - Malicious actors can use this to gain initial foothold
   - Once in, they can potentially access shared resources
   - Can use insider position to conduct reconnaissance
   - Harder to detect as they appear as "legitimate" joined users

5. **Regulatory Compliance Issues**
   - GDPR: Cannot properly validate data processing lawful basis
   - HIPAA: Violates access control requirements (§164.312(a)(1))
   - SOX: Lacks segregation of duties and approval controls
   - ISO 27001: Fails access control policy requirements

6. **License & Cost Impact**
   - Self-joined users may automatically consume licenses
   - No budget approval or cost center assignment
   - Can lead to unexpected Azure AD Premium consumption
   - Difficult to charge back to proper departments

**Proper Alternative:** Use Azure AD B2B guest invitations where:
- IT/managers explicitly invite external users
- Access is time-limited and purpose-specific
- Full audit trail of who invited whom and why
- Automatic expiration and periodic access reviews

**Real-World Attack Scenario:**
1. Attacker identifies your domain (company.com)
2. Attacker creates realistic external email (john.smith.contractor@gmail.com)
3. Attacker requests to join using company knowledge from LinkedIn/website
4. If approved manually without verification, attacker gains initial access
5. Attacker explores shared resources, Teams channels, SharePoint sites
6. Lateral movement to more sensitive resources using social engineering

**Best Practice:** Keep this disabled and use formal invitation-based processes for all external collaboration. Every user account should be traceable to a formal business justification and approval.

---

## References

- [Microsoft 365 admin center documentation](https://learn.microsoft.com/microsoft-365/admin/)
- [Manage self-service purchases](https://learn.microsoft.com/microsoft-365/commerce/subscriptions/manage-self-service-purchases-admins)
- [Authorization policy in Azure AD](https://learn.microsoft.com/graph/api/resources/authorizationpolicy)
- [MSCommerce PowerShell module](https://www.powershellgallery.com/packages/MSCommerce)
- [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/powershell/microsoftgraph/)
- [Retirement of MSOnline and AzureAD PowerShell modules](https://techcommunity.microsoft.com/t5/microsoft-entra-azure-ad-blog/important-azure-ad-graph-retirement-and-powershell-module/ba-p/3848270)
- [Azure AD B2B collaboration](https://learn.microsoft.com/azure/active-directory/external-identities/what-is-b2b)
- [Zero Trust security model](https://learn.microsoft.com/security/zero-trust/)




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

