# IAC Entra Policy Recreation Guide

Complete guide for exporting and recreating IAC Conditional Access policies and Named Locations between tenants.

## Overview

Two PowerShell scripts work together to backup and restore your IAC Entra ID policies:

1. **export-iac-entra-policies-json.ps1** - Exports all IAC CA policies and Named Locations to JSON
2. **recreate-iac-entra-policies.ps1** - Recreates policies from JSON files in target tenant

## File Locations

```
/Users/jon/Desktop/BaslineSetup/
│
├── Scripts/Entra/
│   ├── export-iac-entra-policies-json.ps1     ← Export script
│   ├── recreate-iac-entra-policies.ps1        ← Import/Recreate script
│   └── README-RecreateIACEntraPolicies.md     ← This file
│
└── IAC-Entra-Policies-JSON/                   ← JSON export folder
    ├── index.json                             (Summary file)
    ├── ConditionalAccess/                     (CA policies)
    └── NamedLocations/                        (Trusted/Named locations)
```

## What Gets Exported

### Conditional Access Policies
- Complete policy configuration
- All conditions (users, groups, roles, apps, platforms, locations, etc.)
- Grant controls (MFA, compliant device, hybrid join, etc.)
- Session controls (sign-in frequency, app enforced restrictions, etc.)
- Policy state (enabled/disabled/report-only)
- Assignment details with display names for easy reference

### Named Locations
- IP-based locations (IP ranges)
- Country-based locations
- Trusted/Untrusted status
- Complete configuration for recreation

## Quick Start

### Step 1: Export from Source Tenant

```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
pwsh -File export-iac-entra-policies-json.ps1
```

**What this does:**
- Connects to your current tenant
- Finds all CA policies starting with "IAC"
- Finds all Named Locations starting with "IAC"
- Exports each to its own JSON file
- Saves to `/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/`
- Includes complete configuration and assignment details

### Step 2: Recreate in Target Tenant

```powershell
# Test first (recommended)
pwsh -File recreate-iac-entra-policies.ps1 -DryRun

# Create policies
pwsh -File recreate-iac-entra-policies.ps1

# OR with ID mapping for cross-tenant
pwsh -File recreate-iac-entra-policies.ps1 -GroupIdMapping $groupMap -UserIdMapping $userMap
```

## Prerequisites

### Required Modules
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Required Permissions

**For Export (Source Tenant):**
```powershell
Connect-MgGraph -Scopes "Policy.Read.All","Application.Read.All","User.Read.All","Group.Read.All"
```

**For Import (Target Tenant):**
```powershell
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess","Application.ReadWrite.All"
```

## Detailed Usage

### Export Script

**Basic Export:**
```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
pwsh -File export-iac-entra-policies-json.ps1
```

**Custom Export Path:**
```powershell
pwsh -File export-iac-entra-policies-json.ps1 -ExportPath "/custom/path"
```

**Output Structure:**
```
IAC-Entra-Policies-JSON/
├── index.json
├── ConditionalAccess/
│   ├── IAC - CA01 - Block Legacy Auth.json
│   ├── IAC - CA02 - Require MFA for Admins.json
│   └── ...
└── NamedLocations/
    ├── IAC - Trusted Corporate Network.json
    ├── IAC - Branch Office Locations.json
    └── ...
```

### Recreate Script Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ImportPath` | String | No | `/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON` | Path to JSON export folder |
| `-DryRun` | Switch | No | False | Test mode - shows what would happen |
| `-GroupIdMapping` | Hashtable | No | Empty | Map source group IDs to target IDs |
| `-UserIdMapping` | Hashtable | No | Empty | Map source user IDs to target IDs |
| `-RoleIdMapping` | Hashtable | No | Empty | Map source role IDs to target IDs |

## Usage Examples

### 1. Test with Dry Run
```powershell
pwsh -File recreate-iac-entra-policies.ps1 -DryRun
```

Shows what would be created without making any changes.

### 2. Simple Import (Same Tenant or Identical Groups/Users)
```powershell
pwsh -File recreate-iac-entra-policies.ps1
```

Creates policies with original group/user/role IDs. Use when:
- Restoring to same tenant
- Target tenant has identical group/user IDs

### 3. Cross-Tenant with Group Mapping
```powershell
# Get group IDs from target tenant
Connect-MgGraph -TenantId "target-tenant-id"
Get-MgGroup -Filter "startswith(displayName, 'IAC')" | Select DisplayName, Id

# Create mapping
$groupMapping = @{
    "source-all-users-guid" = "target-all-users-guid"
    "source-admins-guid" = "target-admins-guid"
    "source-exclude-guid" = "target-exclude-guid"
}

# Import with mapping
pwsh -File recreate-iac-entra-policies.ps1 -GroupIdMapping $groupMapping
```

### 4. Complete ID Mapping (Groups, Users, Roles)
```powershell
# Map groups
$groupMap = @{
    "12345678-aaaa-bbbb-cccc-111111111111" = "87654321-dddd-eeee-ffff-222222222222"
}

# Map users (e.g., break-glass accounts)
$userMap = @{
    "old-user-guid" = "new-user-guid"
}

# Map roles
$roleMap = @{
    "old-role-guid" = "new-role-guid"
}

# Import with all mappings
pwsh -File recreate-iac-entra-policies.ps1 `
    -GroupIdMapping $groupMap `
    -UserIdMapping $userMap `
    -RoleIdMapping $roleMap
```

## Complete Tenant Migration Example

### Scenario: Moving IAC policies from Production to Test tenant

**Step 1: Export from Production**
```powershell
# Connect to production
Connect-MgGraph -TenantId "prod-tenant-id" -Scopes "Policy.Read.All","Application.Read.All"

# Export policies
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
pwsh -File export-iac-entra-policies-json.ps1

# Verify export
cat /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/index.json
```

**Step 2: Identify Required Mappings**

Open an exported policy to see what needs mapping:
```powershell
cat "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccess/IAC - CA01 - Block Legacy Auth.json"
```

Look at the `AssignmentDetails` section to see which groups/users/roles are used.

**Step 3: Get Target Tenant IDs**
```powershell
# Disconnect from prod
Disconnect-MgGraph

# Connect to test
Connect-MgGraph -TenantId "test-tenant-id"

# Get groups
Get-MgGroup | Select DisplayName, Id | Out-GridView

# Get break-glass users if needed
Get-MgUser -Filter "startswith(displayName, 'Break Glass')" | Select DisplayName, Id

# Get directory roles if needed
Get-MgDirectoryRole | Select DisplayName, Id
```

**Step 4: Create Mappings**
```powershell
# Map groups
$groupMapping = @{
    # All Users group
    "prod-all-users-guid" = "test-all-users-guid"
    # Admin groups
    "prod-global-admins-guid" = "test-global-admins-guid"
    # Exclusion groups
    "prod-ca-exclusions-guid" = "test-ca-exclusions-guid"
}

# Map users (break-glass accounts)
$userMapping = @{
    "prod-breakglass1-guid" = "test-breakglass1-guid"
    "prod-breakglass2-guid" = "test-breakglass2-guid"
}

# Role mapping usually not needed (same GUIDs across tenants)
$roleMapping = @{}
```

**Step 5: Test with Dry Run**
```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
pwsh -File recreate-iac-entra-policies.ps1 -DryRun `
    -GroupIdMapping $groupMapping `
    -UserIdMapping $userMapping
```

**Step 6: Create Policies**
```powershell
# If dry run looks good
pwsh -File recreate-iac-entra-policies.ps1 `
    -GroupIdMapping $groupMapping `
    -UserIdMapping $userMapping
```

**Step 7: Verify in Portal**
```powershell
# Check summary
cat /Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json

# Open Entra portal
# https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies
```

## Output & Results

### Export Script Output

**Console:**
- List of CA policies found and exported
- List of Named Locations found and exported
- Total counts

**Files Created:**
- `index.json` - Summary with all exported items
- Individual JSON files for each policy/location

**Sample index.json:**
```json
{
  "ExportDate": "2026-01-16 18:45:00",
  "TenantId": "44176a9d-4a62-469c-a336-ad1f8e30927c",
  "ConditionalAccessPolicies": [
    {
      "Name": "IAC - CA01 - Block Legacy Auth",
      "Id": "abc123...",
      "State": "enabled",
      "FileName": "IAC - CA01 - Block Legacy Auth.json"
    }
  ],
  "NamedLocations": [
    {
      "Name": "IAC - Trusted Corporate Network",
      "Id": "xyz789...",
      "Type": "IP Location",
      "IsTrusted": true,
      "FileName": "IAC - Trusted Corporate Network.json"
    }
  ],
  "TotalPolicies": 28,
  "TotalLocations": 3
}
```

### Recreate Script Output

**Console:**
- Real-time progress for each policy/location
- ✅ Success or ❌ Failure indicators
- New IDs created in target tenant

**Summary File:** `/Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json`
```json
{
  "CreatedPolicies": [
    {
      "Name": "IAC - CA01 - Block Legacy Auth",
      "SourceId": "abc123...",
      "NewId": "xyz789...",
      "State": "enabled"
    }
  ],
  "CreatedLocations": [
    {
      "Name": "IAC - Trusted Corporate Network",
      "SourceId": "old-guid",
      "NewId": "new-guid",
      "Type": "IP Location"
    }
  ],
  "FailedPolicies": [],
  "FailedLocations": [],
  "Timestamp": "2026-01-16 18:50:00",
  "DryRun": false
}
```

## Important Notes

### ✅ Best Practices

1. **Always run with `-DryRun` first** to verify mappings
2. **Export regularly** for disaster recovery
3. **Version control** JSON files in Git
4. **Test in non-production** first
5. **Document ID mappings** for future reference
6. **Review policy states** - policies are created in their original state (enabled/disabled/report-only)

### ⚠️ Important Considerations

**Policy States:**
- Policies are created in their **original state** (enabled/disabled/report-only)
- Consider creating all as "report-only" first, then enable after testing
- You can manually edit JSON files to change state before import

**Named Locations:**
- Must be created before CA policies that reference them
- Script creates Named Locations first, then CA policies
- IP ranges and country lists are preserved exactly

**ID Mappings:**
- **Groups/Users**: Almost always need mapping for cross-tenant
- **Roles**: Usually same GUIDs across tenants (no mapping needed)
- **Special Values**: `All`, `GuestsOrExternalUsers`, `None` are preserved automatically
- **Applications**: Cloud app IDs (Office365, etc.) are the same across tenants

**Applications in Policies:**
- Most cloud apps have same IDs across tenants (no mapping needed)
- Custom line-of-business apps need to exist in target tenant
- Enterprise apps (SAML, OAuth) may need separate registration

### 🔒 Security Considerations

**Sensitive Data:**
- JSON files contain complete policy configurations
- May include IP ranges, user IDs, group memberships
- Store securely with appropriate access controls

**Policy States:**
- Newly created policies are created in their original state
- Enabled policies take effect immediately
- Review before creating in production

**Break-Glass Accounts:**
- Always map break-glass account exclusions correctly
- Verify exclusions exist before enabling policies
- Test break-glass access after migration

**Policy Testing:**
- Use report-only mode first
- Test with non-admin accounts
- Verify MFA, device compliance, location conditions work
- Check sign-in logs after enabling

## Troubleshooting

### Export Issues

**Problem: No policies exported**
```powershell
# Verify connection
Get-MgContext

# Check for IAC policies
Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" |
    Select -ExpandProperty value |
    Where displayName -like "IAC*"
```

**Problem: Permission errors**
```powershell
# Reconnect with correct scopes
Disconnect-MgGraph
Connect-MgGraph -Scopes "Policy.Read.All","Application.Read.All"
```

### Import Issues

**Problem: Policy creation fails with "Invalid users"**
- Check that group/user/role IDs exist in target tenant
- Verify ID mappings are correct
- Ensure special values (`All`, `GuestsOrExternalUsers`) aren't being mapped

**Problem: "Referenced named location doesn't exist"**
- Named Locations must exist before CA policies
- Script creates them in correct order
- Check if import actually created the locations first

**Problem: Policy created but doesn't work**
- Verify application IDs exist in target tenant
- Check that conditions (locations, platforms) are valid
- Review grant controls (device compliance requires Intune)

### Validation Commands

**Verify policies created:**
```powershell
Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" |
    Select -ExpandProperty value |
    Where displayName -like "IAC*" |
    Select displayName, state, id
```

**Verify named locations:**
```powershell
Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations" |
    Select -ExpandProperty value |
    Where displayName -like "IAC*" |
    Select displayName, isTrusted, '@odata.type'
```

**Check policy details:**
```powershell
$policyId = "your-policy-guid"
Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$policyId"
```

## Advanced Usage

### Manual JSON Editing

Edit policies before import (e.g., change state to report-only):
```powershell
# Open policy JSON
code "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccess/IAC - CA01 - Block Legacy Auth.json"

# Change state in PolicyConfig section:
# "state": "enabledForReportingButNotEnforced"

# Save and import
pwsh -File recreate-iac-entra-policies.ps1
```

### Selective Import

Import only CA policies (skip Named Locations):
```powershell
# Temporarily rename folder
mv IAC-Entra-Policies-JSON/NamedLocations IAC-Entra-Policies-JSON/NamedLocations.skip

# Import (only CA policies)
pwsh -File recreate-iac-entra-policies.ps1

# Restore folder
mv IAC-Entra-Policies-JSON/NamedLocations.skip IAC-Entra-Policies-JSON/NamedLocations
```

### Create All as Report-Only First

```powershell
# Method 1: Edit each JSON manually before import
# Change "state": "enabled" to "state": "enabledForReportingButNotEnforced"

# Method 2: Use PowerShell to batch edit
$caFolder = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccess"
Get-ChildItem $caFolder -Filter "*.json" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw | ConvertFrom-Json
    $content.PolicyConfig.state = "enabledForReportingButNotEnforced"
    $content | ConvertTo-Json -Depth 10 | Out-File $_.FullName -Encoding utf8
}

# Then import
pwsh -File recreate-iac-entra-policies.ps1
```

### Backup Automation

Schedule regular exports:
```powershell
# Create backup script
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
pwsh -File export-iac-entra-policies-json.ps1

# Copy to timestamped backup
$date = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -Recurse "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON" `
    "/Backups/Entra/IAC-Entra-$date"
```

## Supported Policy Types

| Policy Type | Export | Recreate | Notes |
|-------------|--------|----------|-------|
| Conditional Access | ✅ | ✅ | All conditions, controls, states |
| IP Named Locations | ✅ | ✅ | IP ranges, trusted status |
| Country Named Locations | ✅ | ✅ | Country codes, include/exclude |

## ID Mapping Reference

### What Needs Mapping (Cross-Tenant)

| Object Type | Needs Mapping | Notes |
|-------------|---------------|-------|
| Groups | ✅ Always | Different GUIDs across tenants |
| Users | ✅ Usually | For specific user exclusions |
| Directory Roles | ❌ Rarely | Same GUIDs across tenants |
| Applications (Cloud) | ❌ No | Office365, etc. same everywhere |
| Applications (Custom) | ⚠️ Maybe | Must exist in target tenant |
| Named Locations | ❌ No | Created by script |

### Special Values (Never Map)

- `All` - All users
- `GuestsOrExternalUsers` - Guest users
- `None` - No selection
- `AllApplications` - All cloud apps
- `Office365` - Office 365 suite

## Related Scripts

**Other IAC Management Scripts:**
- [Intune Policy Export/Import](../Intune/README-RecreateIACPolicies.md)
- [Entra Documentation Export](export-entra-documentation.ps1)
- [CA Policy Rename](rename-ca-policies.ps1)
- [Named Location Rename](rename-named-locations.ps1)

## Support & Documentation

**Script Locations:**
- Export: `/Users/jon/Desktop/BaslineSetup/Scripts/Entra/export-iac-entra-policies-json.ps1`
- Import: `/Users/jon/Desktop/BaslineSetup/Scripts/Entra/recreate-iac-entra-policies.ps1`

**Output Locations:**
- JSON Files: `/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/`
- Summary: `/Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json`

**Microsoft Graph Permissions:**
- Export: `Policy.Read.All`, `Application.Read.All`
- Import: `Policy.ReadWrite.ConditionalAccess`, `Application.ReadWrite.All`

**Microsoft Documentation:**
- [Conditional Access Overview](https://learn.microsoft.com/entra/identity/conditional-access/overview)
- [Named Locations](https://learn.microsoft.com/entra/identity/conditional-access/location-condition)
- [Graph API Reference](https://learn.microsoft.com/graph/api/resources/conditionalaccesspolicy)

## Version History

**v1.0** (2026-01-16) - Initial Release
- Export CA policies and Named Locations to JSON
- Import with ID mapping support
- Dry-run testing capability
- Complete documentation
