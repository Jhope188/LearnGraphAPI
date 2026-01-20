# IAC Master Documentation

**Complete Infrastructure as Code Policy Documentation**

**Generated:** January 16, 2026 

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
- **Conditional Access Policies**: Dynamic access controls based on conditions
- **Named Locations**: Trusted network locations and IP ranges

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

#### IP-Based Named Locations (3)

##### IAC - Trusted Locations (IP)
**Type:** IP Named Location  
**Trusted:** Yes  
**Purpose:** Trusted IP ranges for IAC infrastructure

##### IAC - Inforcer (IP)
**Type:** IP Named Location  
**Trusted:** Yes  
**Purpose:** IAC Inforcer service IP ranges

##### IAC - EntraConnect(IP)
**Type:** IP Named Location  
**Trusted:** Yes  
**Purpose:** IAC Entra Connect synchronization servers

#### Country-Based Named Locations (1)

##### IAC - Blocked Countries
**Type:** Country Named Location  
**Purpose:** Countries blocked for IAC security policies  
**Include Unknown Regions:** Configurable

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
- **Named Locations:** 4 (3 IP-based, 1 Country-based)

### Intune Policies
- **Settings Catalog Policies:** 16
- **Compliance Policies:** 0
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

**Enabled:** True
**Priority:** 0
**Phishing Threshold:** 1
**Mailbox Intelligence:** Enabled
**Applies To Domains:** M365x37845673.onmicrosoft.com

### Anti-Spam Policies

Anti-spam policies define actions for different types of spam and bulk email.

#### IAC - DfO - [Anti-Spam] [Inbound] [All Domains]

**Priority:** 0
**Spam Action:** MoveToJmf
**High Confidence Spam Action:** MoveToJmf
**Bulk Threshold:** 7
**Applies To Domains:** M365x37845673.onmicrosoft.com

#### IAC - DfO - [Anti-Spam] [Outbound] [All Domains]

**Priority:** 1
**Recipient Limit (External/Hour):** 500
**Recipient Limit (Internal/Hour):** 1000
**Recipient Limit (Per Day):** 1000
**Action When Threshold Reached:** BlockUserForToday
**Auto-Forwarding Mode:** Off
**Applies To Domains:** M365x37845673.onmicrosoft.com

### Anti-Malware Policies

Anti-malware policies scan attachments and provide zero-hour auto purge (ZAP) for malware.

#### IAC - DfO - [Anti-Malware] for [All Domains] 🟢

**ZAP Enabled:** True
**Priority:** 0
**File Filter:** Enabled
**Applies To Domains:** M365x37845673.onmicrosoft.com

### Safe Links Policies

Safe Links policies provide time-of-click protection and URL rewriting for malicious links.

#### IAC - DfO - [Safe Links] for [All Domains]

**Priority:** 0
**Scan URLs:** True
**Internal Senders:** True

### Safe Attachments Policies

Safe Attachments policies sandbox unknown attachments in a virtual environment before delivery.

#### IAC - DfO - [Safe Attachments] for [All Domains] 🔴

**Enabled:** False
**Priority:** 0
**Action:** Allow


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

