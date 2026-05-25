# Entra Tenant Policies IAC

## Overview
Complete IAC coverage for Entra ID tenant-level policies in addition to Conditional Access policies and Named Locations.

## Exported Tenant Policies

### TenantPolicies Folder
- **AuthorizationPolicy.json** - Tenant authorization settings
  - blockMsolPowerShell: Controls legacy MSOL PowerShell access
  - allowedToSignUpEmailBasedSubscriptions: Email-based subscription signups
  - defaultUserRolePermissions: Default user permissions
  - guestUserRoleId: Guest user role configuration

- **AuthenticationMethodsPolicy.json** - Authentication methods configuration
  - registrationEnforcement.authenticationMethodsRegistrationCampaign: MFA registration nudges
  - authenticationMethodConfigurations: Enabled/disabled auth methods
  - Full MFA policy configuration

### SecurityAttributes Folder
- **ConditionalAccessTaggedAgents.json** - Custom security attributes for agents
  - Attribute: policyRequirement (String with predefined values)
  - Used to tag agents that require specific CA policies
  
- **ConditionalAccessTaggedApps.json** - Custom security attributes for apps
  - Attribute: policyRequirement (String with predefined values)
  - Allowed values: legacyAuthAllowed, requireCompliantDevice, DoNotRequireMFA, blockGuests, blockExternals
  - Used to tag applications with policy requirements

## Scripts

### export-iac-entra-tenant-policies.ps1
Exports tenant-level policies to JSON format for backup and disaster recovery.

**Required Permissions:**
- Policy.Read.All (or Policy.ReadWrite.Authorization + Policy.ReadWrite.AuthenticationMethod)

### export-iac-entra-security-attributes.ps1
Exports custom security attribute sets and their definitions to JSON format.

**Required Permissions:**
- CustomSecAttributeDefinition.Read.All

### recreate-iac-entra-policies.ps1 (Updated)
Now includes tenant policy restoration in addition to CA policies and locations.

**Required Permissions:**
- Policy.ReadWrite.ConditionalAccess
- Policy.ReadWrite.Authorization
- Policy.ReadWrite.AuthenticationMethod
- CustomSecAttributeDefinition.ReadWrite.All
- Application.ReadWrite.All

**New Parameters:**
- `-SkipTenantPolicies` - Skip tenant policy restoration (only restore CA policies and locations)
- `-SkipSecurityAttributes` - Skip security attributes restoration

## Pre-Restoration Requirements

### CRITICAL: ID Mapping Table Required

Before restoring policies to a **different tenant**, you MUST create a mapping table for tenant-specific IDs. These IDs differ between tenants and must be mapped from source to destination.

#### Required Mappings

##### 1. Group Object IDs (REQUIRED)
Map these groups from source tenant to destination tenant:

| Group Display Name | Source Tenant ID | Destination Tenant ID | Notes |
|-------------------|------------------|----------------------|-------|
| Azure-Breakglass | `822cebe7-b527-405c-8bae-834782ec74cb` | `<NEW-ID>` | Emergency access accounts exclusion |
| AVD-ExternalUsers | `21344a9f-6ef0-4181-970a-15202237ac4b` | `<NEW-ID>` | Azure Virtual Desktop external users |
| CA - GlobalExclusions | `6064391a-c4b7-4991-b87f-e7a98fcd23aa` | `<NEW-ID>` | Global policy exclusions |

**How to get destination IDs:**
```powershell
Get-MgGroup -Filter "displayName eq 'Azure-Breakglass'" | Select-Object DisplayName, Id
```

##### 2. Named Location IDs (REQUIRED)
Map named locations from source to destination:

| Location Display Name | Source Tenant ID | Destination Tenant ID | Type |
|----------------------|------------------|----------------------|------|
| AllTrusted | `<SOURCE-ID>` | `<NEW-ID>` | IP-based or Country |
| (Other locations...) | `<SOURCE-ID>` | `<NEW-ID>` | |

**Note:** Named locations may need to be created in destination tenant BEFORE running restoration script.

##### 3. Custom Authentication Strength IDs (if applicable)
If your policies reference custom authentication strengths:

| Strength Name | Source Tenant ID | Destination Tenant ID |
|---------------|------------------|----------------------|
| (Custom Strength) | `<SOURCE-ID>` | `<NEW-ID>` |

##### 4. Application IDs (Usually NOT Required)
Standard Microsoft 365 application IDs are universal and don't need mapping:
- Office 365 SharePoint Online: `00000003-0000-0ff1-ce00-000000000000`
- Office 365: Standard GUID

**Only map if you have custom line-of-business applications.**

### Pre-Restoration Checklist

Before running `recreate-iac-entra-policies.ps1`:

- [ ] **Create all required groups in destination tenant** with same display names
- [ ] **Export list of group IDs** from destination tenant
- [ ] **Create mapping table** (CSV, Excel, or PowerShell hashtable)
- [ ] **Verify all Named Locations exist** in destination (or will be created by script)
- [ ] **Confirm permissions** on destination tenant (see Required Permissions section)
- [ ] **Test with one policy first** using report-only mode
- [ ] **Have source tenant admin available** for validation

### Example Mapping Hashtable (PowerShell)

```powershell
$GroupIdMapping = @{
    '822cebe7-b527-405c-8bae-834782ec74cb' = '<destination-breakglass-id>'
    '21344a9f-6ef0-4181-970a-15202237ac4b' = '<destination-avd-id>'
    '6064391a-c4b7-4991-b87f-e7a98fcd23aa' = '<destination-globalexclusions-id>'
}

$LocationIdMapping = @{
    '<source-alltrusted-id>' = '<destination-alltrusted-id>'
}
```

### What Happens If You Don't Map?

❌ **Policies will fail to create** - Invalid group/location references will cause errors
❌ **Wrong groups may be excluded** - Policies might reference non-existent objects
❌ **Security gaps** - Breakglass accounts won't be properly excluded
❌ **Audit failures** - Policies won't match source tenant configuration

## Restoration Order
The recreate script processes in this order:
1. **Tenant Policies** (Authorization Policy, Authentication Methods Policy)
2. **Custom Security Attributes** (Attribute Sets and Definitions)
3. **Custom Authentication Strengths**
4. **Named Locations**
5. **Conditional Access Policies**

## Critical Settings Protected

### Authorization Policy
- ✅ MSOL PowerShell blocking (blockMsolPowerShell: True)
- ✅ Email subscription signup controls
- ✅ Guest user permissions
- ✅ Default user role permissions

### Authentication Methods Policy
- ✅ MFA registration campaign settings
- ✅ Enabled authentication methods
- ✅ Method configurations (SMS, Voice, Authenticator, etc.)

## Current Coverage
- ✅ Conditional Access Policies (27 user policies + 3 Microsoft-managed)
- ✅ Named Locations (5 locations)
- ✅ Custom Authentication Strengths
- ✅ Authorization Policy
- ✅ Authentication Methods Policy
- ✅ Custom Security Attributes (2 attribute sets, 2 attributes)

## Not Currently Exported
- ⚠️ Access Reviews (requires license/additional permissions)
- ⚠️ External Identities Policy (endpoint not available in this tenant)

## Last Updated
- Export Script Created: January 25, 2026
- Recreate Script Updated: January 25, 2026
- Last Export: January 25, 2026, 20:55
- Source Tenant: 44176a9d-4a62-469c-a336-ad1f8e30927c

## Validation
After restoration, verify:
1. Authorization Policy settings match source
2. Authentication Methods Policy matches source
3. All CA policies created with correct state
4. Named locations created
5. Custom authentication strengths created and referenced correctly
