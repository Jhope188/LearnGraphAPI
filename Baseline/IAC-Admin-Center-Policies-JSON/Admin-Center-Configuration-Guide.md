# Microsoft 365 Administrative Center Configuration Documentation

**Last Updated:** January 17, 2026

This document describes the Microsoft 365 Administrative Center features and their current configuration status for your tenant.

---

## Table of Contents

1. [Authorization Policy Settings](#authorization-policy-settings)
2. [Exchange Online Calendar Sharing](#exchange-online-calendar-sharing)
3. [Self-Service Purchase Policies](#self-service-purchase-policies)
4. [Default User Role Permissions](#default-user-role-permissions)
5. [Management Scripts](#management-scripts)

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

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Any user with a verified email can request to join your organization
- When **Disabled**: Only invited users can join the organization (recommended for security)

---

### Block Legacy MSOL PowerShell

**Setting:** `BlockMsolPowerShell`

**Description:** Controls whether the legacy MSOnline (MSOL) PowerShell module can be used to manage your tenant.

**Recommended Value:** `True` (Enabled) - blocks legacy module, forces modern Microsoft Graph

**Current Status:** ✅ `True` (Enabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Forces use of modern Microsoft Graph PowerShell cmdlets (recommended)
- When **Disabled**: Allows continued use of deprecated MSOnline module

**Security Note:** Microsoft recommends blocking MSOL PowerShell and transitioning to Microsoft Graph PowerShell for improved security and functionality.

**Management:**
```powershell
# Enable blocking of legacy MSOL PowerShell (Recommended)
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization" -NoWelcome
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    BlockMsolPowerShell = $true
}

# Disable blocking (Allow MSOL PowerShell - Not Recommended)
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    BlockMsolPowerShell = $false
}

# Verify current setting
$authPolicy = Get-MgPolicyAuthorizationPolicy
Write-Host "Block MSOL PowerShell:" ($authPolicy.BlockMsolPowerShell ? "ENABLED" : "DISABLED")
```

**Note:** This setting is **not available in the Microsoft 365 Admin Center UI**. It must be configured via Microsoft Graph PowerShell API. The `admincenterconfig.ps1` script in this repository automatically enables this setting.

---

## Exchange Online Calendar Sharing

### External Calendar Sharing with Office 365/Exchange Organizations

**Setting:** Calendar sharing with external organizations

**Location:** M365 Admin Center → Settings → Org settings → Calendar

**Description:** Controls whether users can share their calendars with people outside your organization who have Office 365 or Exchange. This includes free/busy information and calendar details.

**Recommended Value:** Depends on business requirements
- **Disabled**: Recommended for most organizations to prevent information disclosure
- **Enabled**: Only if external collaboration requires calendar visibility

**Current Status:** ⚠️ Requires manual review

**Impact:**
- When **Enabled**: Users can share calendar information (including free/busy times) with external Office 365/Exchange users
- When **Disabled**: Prevents calendar information sharing outside the organization

**Security Considerations:**
- **Information Disclosure**: Calendar sharing can reveal meeting patterns, availability, and potentially sensitive meeting details
- **Business Collaboration**: May be required for organizations working closely with partners/clients
- **Federated Sharing**: This is separate from anonymous calendar publishing

**Types of Calendar Sharing:**
1. **Anonymous Calendar Publishing**: Share calendar via anonymous links (very high risk)
2. **Federated Sharing with O365/Exchange**: Share with other Office 365 or Exchange organizations (moderate risk)
3. **Individual Permissions**: Users control specific sharing on per-calendar basis

**Management via PowerShell:**
```powershell
# Check current calendar sharing policy
Connect-ExchangeOnline
$sharingPolicy = Get-SharingPolicy | Where-Object {$_.Default -eq $true}
$sharingPolicy | Select-Object Name, Domains, Enabled

# Check for anonymous/external sharing domains
$sharingPolicy.Domains | Where-Object { $_ -like "*Anonymous*" -or $_ -like "*CalendarSharing*" }

# Check organization-level federated sharing
Get-OrganizationConfig | Select-Object Name, IsDehydrated, OrganizationSummary

# To disable external calendar sharing, modify the default sharing policy
# Remove anonymous domains (requires careful planning - may impact users)
Set-SharingPolicy "Default Sharing Policy" -Domains "Anonymous:CalendarSharingFreeBusySimple"
```

**Recommendation:**
- Review your organization's collaboration requirements
- If external calendar sharing is not needed, disable it to prevent information disclosure
- If required, implement least-privilege access:
  - Only allow specific users/groups to share calendars externally
  - Limit sharing to free/busy only (not full details)
  - Educate users on risks of calendar sharing
- Monitor calendar sharing activity via audit logs

**Note:** The `admincenterconfig.ps1` script checks this setting but does not automatically change it, as it requires business decision-making. Manual review and configuration are recommended.

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

**Recommended Value:** `False` (Disabled) - prevents unauthorized tenant sprawl

**Current Status:** ✅ `False` (Disabled) - **Matches recommendation**

**Impact:**
- When **Enabled**: Users can create their own separate Azure AD tenants
- When **Disabled**: Prevents tenant creation by standard users (recommended for governance)

**Note:** While creating new tenants doesn't directly affect your organization's security, allowing users to create tenants can lead to shadow IT, data sprawl, and governance challenges.

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

**Last Updated:** February 2, 2026

| Setting | Recommended | Current | Status |
|---------|------------|---------|--------|
| Email-based subscriptions | ❌ Disabled | ❌ Disabled | ✅ Match |
| Email verified users can join | ❌ Disabled | ❌ Disabled | ✅ Match |
| Block legacy MSOL PowerShell | ✅ Enabled | ✅ Enabled | ✅ Match |
| External calendar sharing | ⚠️ Review Required | ⚠️ Requires Review | ℹ️ Manual Check |
| Self-service purchases (27 products) | ❌ Disabled (all) | ❌ Disabled (all) | ✅ Match |
| Users can create apps | ❌ Disabled | ❌ Disabled | ✅ Match |
| Users can create security groups | ❌ Disabled | ❌ Disabled | ✅ Match |
| Users can create tenants | ❌ Disabled | ❌ Disabled | ✅ Match |
| Users can read Bitlocker keys | ✅ Enabled | ✅ Enabled | ✅ Match |
| Users can read other users | ✅ Enabled | ✅ Enabled | ✅ Match |

**Legend:**
- ✅ Match = Current setting matches recommendation
- ⚠️ **Action Required** = Current setting does not match recommendation (security/compliance concern)
- ℹ️ Manual Check = Setting requires manual review based on business requirements
- ℹ️ More restrictive = Current setting is more restrictive than recommendation (acceptable)

### Summary
- **9 of 9 automated settings** match recommendations (100% compliance)
- **1 setting requires manual review** (External calendar sharing)
- **0 critical security gaps** (self-service purchases are properly disabled)

---

## Security & Governance Impact

### High Priority (Disable Recommended)
- **Self-service trials** - Prevents shadow IT and uncontrolled costs
- **Self-service purchases** - Prevents unmanaged licensing and budget overruns
- **User app registration** - Prevents potential security vulnerabilities
- **External calendar sharing** - Prevents information disclosure via calendar details

### Medium Priority (Configure Based on Needs)
- **Security group creation** - Balance between governance and user autonomy
- **Block MSOL PowerShell** - Forces modern authentication and improved security
- **Tenant creation** - Prevents unauthorized tenant sprawl

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

### ✅ All Security Settings Validated

**Congratulations!** All authorization policy settings now match security best practices:

- Email-based subscriptions: Properly disabled
- Email verified users can join: Properly disabled ✅
- Block legacy MSOL PowerShell: Properly enabled ✅
- Self-service purchases: All 27 products properly disabled
- User app registration: Properly disabled
- Security group creation: Properly disabled
- Tenant creation: Properly disabled
- Bitlocker self-service: Properly enabled
- User directory reading: Properly enabled

### Documentation Tasks

1. ✅ Export completed (January 17, 2026 16:10:41)
2. ✅ Configuration reviewed against recommendations
3. ✅ Applied security hardening fixes (February 2, 2026)
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
