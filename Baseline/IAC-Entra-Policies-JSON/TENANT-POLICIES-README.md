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
