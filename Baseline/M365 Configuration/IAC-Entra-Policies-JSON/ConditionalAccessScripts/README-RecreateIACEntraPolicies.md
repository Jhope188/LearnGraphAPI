# IAC Entra Policy Recreation Guide

Complete guide for exporting and recreating IAC Conditional Access policies and Named Locations between tenants.

## Overview

This toolkit includes multiple PowerShell scripts for managing IAC Entra ID policies across tenants:

1. **export-iac-entra-policies-json.ps1** - Exports all IAC CA policies and Named Locations to JSON
2. **recreate-iac-entra-policies.ps1** - Recreates policies from JSON files in target tenant
3. **cleanup-and-map-policies.ps1** - Removes duplicates and maps old tenant group GUIDs to new tenant groups
4. **run-policy-recreation-clean.ps1** - Wrapper script that runs recreation in a clean PowerShell session

### Recommended Deployment Order

For a successful IAC policy deployment to a new tenant, follow these steps in order:

```powershell
# Step 1: Create all required groups FIRST (with correct names including spaces)
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
./create-ca-groups.ps1

# Step 2: Export from source tenant (if needed)
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts
./export-iac-entra-policies-json.ps1

# Step 3: Create policies in target tenant
./run-policy-recreation-clean.ps1
# OR directly: ./recreate-iac-entra-policies.ps1
# NOTE: This script now does AUTOMATIC location and group ID mapping!
# You only need to run this once - it will map everything automatically.

# Step 4 (OPTIONAL): Clean up duplicates if you ran recreation multiple times
# Only needed if you have duplicate policies/locations
# Run in WhatIf mode first to preview changes
./cleanup-and-map-policies.ps1 -WhatIf

# Step 5 (OPTIONAL): Execute the cleanup
./cleanup-and-map-policies.ps1
```

**Important:** If you run the recreation script only ONCE, you don't need the cleanup script. The recreation script automatically maps location IDs and group IDs by matching display names between tenants.

## File Locations

```
/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/
│
├── ConditionalAccessScripts/
│   ├── export-iac-entra-policies-json.ps1         ← Export script
│   ├── recreate-iac-entra-policies.ps1            ← Import/Recreate script
│   ├── cleanup-and-map-policies.ps1               ← Cleanup duplicates & map GUIDs
│   ├── run-policy-recreation-clean.ps1            ← Wrapper for clean session
│   └── README-RecreateIACEntraPolicies.md         ← This file
│
├── ConditionalAccess/                             ← CA policy JSON files
├── NamedLocations/                                ← Named location JSON files
├── CustomAuthenticationStrengths/                 ← Auth strength JSON files
├── SecurityAttributes/                            ← Security attribute JSON files
└── index.json                                     ← Summary file
```

## Known Issues and Solutions

### Issue 1: Trusted Named Locations Cannot Be Deleted Directly
**Problem:** When trying to delete named locations with `isTrusted = true`, you get an error requiring the location to be unmarked as trusted first.

**Solution:** Use the `delete-all-iac-policies-and-locations.ps1` script which:
1. Uses beta endpoint to update `isTrusted` to `false`
2. Waits for propagation (1-2 seconds)
3. Deletes the location using v1.0 endpoint
4. May require 2-3 iterations due to backend caching

**Manual workaround:**
```powershell
# Update location to untrusted using beta endpoint
$locationId = "your-location-id"
$location = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$locationId"
$location.isTrusted = $false
Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/namedLocations/$locationId" -Body ($location | ConvertTo-Json -Depth 10)

# Wait a moment for propagation
Start-Sleep -Seconds 2

# Delete the location
Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$locationId"
```

### Issue 2: Group Names Must Match Exactly (Including Spaces)
**Problem:** Automatic group ID mapping fails because group names don't match between JSON files and target tenant.

**Root Cause:** 
- JSON files from source tenant reference: `"CA - DeviceExclusions"` (WITH spaces)
- If target tenant has: `"CA-DeviceExclusions"` (WITHOUT spaces)
- Graph API filter for exact match fails: `displayName eq 'CA - DeviceExclusions'` doesn't find `'CA-DeviceExclusions'`

**Solution:**
1. Use the provided `create-ca-groups.ps1` script which creates groups with correct names
2. Verify group names match exactly:
```powershell
# Check what JSON files expect
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccess
grep -h '"DisplayName":' *.json | grep 'CA -' | sort -u

# Check what exists in tenant
Get-MgGroup -All | Where-Object { $_.DisplayName -like 'CA*' } | Select DisplayName
```
3. Names must match character-for-character including spaces around hyphens

### Issue 3: mailNickname Validation Errors When Creating Groups
**Problem:** Creating groups with spaces in names fails with "Invalid value specified for property 'mailNickname'".

**Root Cause:** Azure AD mailNickname property cannot contain spaces or special characters.

**Solution:** The `create-ca-groups.ps1` script sanitizes mailNickname:
```powershell
# displayName can have spaces: "CA - DeviceExclusions"
# mailNickname must not: "CA-DeviceExclusions" or "CADeviceExclusions"
$sanitizedNickname = $groupName -replace '[^a-zA-Z0-9-]', ''
```

### Issue 4: Duplicate Policies After Running Recreation Multiple Times
**Problem:** Running the recreation script multiple times creates duplicate policies with identical names.

**Solution:** 
- **Prevention:** Only run the recreation script ONCE per tenant
- **Cleanup:** If you have duplicates:
  ```powershell
  # Use delete-all script to remove everything
  cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts
  echo "DELETE ALL" | ./delete-all-iac-policies-and-locations.ps1
  
  # Then run recreation script once
  ./run-policy-recreation-clean.ps1
  ```
- **Alternative:** Use cleanup-and-map-policies.ps1 to remove duplicates (keeps most recent)

### Issue 5: Policy Creation Fails with "BadRequest" Errors
**Problem:** Policies fail to create with generic BadRequest errors.

**Common Causes:**
1. **Missing group:** Group referenced in policy doesn't exist in target tenant
2. **Missing location:** Named location referenced in policy doesn't exist
3. **Invalid GUID:** Old tenant GUID wasn't remapped (should be automatic now)

**Solution:**
1. Check all required groups exist: `Get-MgGroup -Filter "startswith(displayName,'CA')"`
2. Check all locations exist: `Get-MgConditionalAccessNamedLocation`
3. Review summary JSON for specific errors
4. Ensure groups were created BEFORE running recreation script

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

### Complete Deployment to New Tenant

This is the **recommended workflow** for deploying IAC policies to a new tenant:

#### Step 1: Export from Source Tenant (if needed)

```powershell
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts
pwsh -NoProfile -File export-iac-entra-policies-json.ps1
```

**What this does:**
- Connects to your current tenant
- Exports all CA policies starting with "IAC"
- Exports all Named Locations starting with "IAC"  
- Exports Custom Authentication Strengths
- Exports Custom Security Attributes
- Saves everything to JSON files

#### Step 2: Create Required Groups in Target Tenant FIRST

**CRITICAL:** Create all groups with correct names (including spaces) BEFORE running recreation script!

```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
pwsh -NoProfile -File create-ca-groups.ps1
```

**What this does:**
- Creates all 13 required groups with correct names
- Group names include spaces where needed: "CA - DeviceExclusions" (note space before and after hyphen)
- mailNickname automatically sanitized to remove spaces
- Skips groups that already exist

**Verify groups created:**
```powershell
Get-MgGroup -All | Where-Object { $_.DisplayName -match '^CA' } | Select DisplayName | Sort DisplayName
```

You should see:
- CA - Agent-Admins
- CA - Agent-Users
- CA - Azure-DevOps-Users
- CA - DeviceExclusions
- CA - GlobalExclusions
- CA - GuestExclusions
- CA - ServiceAccounts
- CA - TravelingUsers
- CA-P1InternalLicensedUsers
- CA-P2InternalLicensedUsers

#### Step 3: Create Policies in Target Tenant

```powershell
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts

# Option A: Using clean session wrapper (recommended if experiencing module issues)
pwsh -NoProfile -File run-policy-recreation-clean.ps1

# Option B: Direct execution
pwsh -NoProfile -File recreate-iac-entra-policies.ps1
```

**What this does:**
- **Creates Named Locations FIRST** (policies depend on these)
- **Builds Location ID Mapping:** Automatically maps old tenant location IDs → new tenant location IDs
- **Builds Group ID Mapping:** Automatically scans JSON files and looks up groups by displayName
- **Creates Custom Authentication Strengths**
- **Creates Conditional Access Policies** with all IDs correctly mapped
- **Saves summary** to `/Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json`

**Important:** This script does **automatic ID mapping** - no manual mapping files needed! Just ensure groups were created in Step 2 with correct names.

**Expected Results:**
- 28 CA policies created successfully
- 5 named locations created successfully
- All group and location IDs correctly mapped
- 0 failures (if all prerequisites met)

#### Step 4 (OPTIONAL): Clean Up Duplicates

**Only needed if you ran the recreation script multiple times and have duplicate policies!**

If you ran recreation only once, skip this step - everything is already correct.

#### Step 3: Clean Up and Map Group GUIDs (DEPRECATED - Now Automatic)

```powershell
# IMPORTANT: Run in WhatIf mode first to preview changes
pwsh -NoProfile -File cleanup-and-map-policies.ps1 -WhatIf

# Review the output, then execute for real
pwsh -NoProfile -File cleanup-and-map-policies.ps1
```

**What this does:**
- **Removes duplicate policies** - Keeps most recent copy if the script ran multiple times
- **Removes duplicate named locations** - Keeps most recent copy
- **Removes invalid group GUIDs** - Cleans up old tenant group references
- **Maps to new tenant groups** - Identifies and uses groups in the new tenant:
  - Azure-Breakglass
  - CA-GlobalExclusions
  - CA-DeviceExclusions  
  - CA-ServiceAccounts
  - CA-GuestExclusions
  - CA-TravelingUsers
  - CA-Azure-DevOps-Users
  - CA-P1InternalLicensedUsers
  - CA-P2InternalLicensedUsers
  - CA-Agent-Admins
  - CA-Agent-Users

**Required Groups:**
Before running cleanup, ensure these groups exist in your target tenant. The script will automatically find them by name and update the policy exclusions.

#### Step 4: Verify Deployment

```powershell
# Check the summary
cat /Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json

# Verify in Entra portal
# https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies
```

### Alternative: Export Only (Backup)

```powershell
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts
pwsh -NoProfile -File export-iac-entra-policies-json.ps1
```

## Prerequisites

### Required Modules
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Required Permissions

**For Export (Source Tenant):**
```powershell
Connect-MgGraph -Scopes @(
    'Policy.Read.All',
    'Application.Read.All',
    'User.Read.All',
    'Group.Read.All',
    'Directory.Read.All'
) -NoWelcome
```

**For Import/Recreation (Target Tenant):**
```powershell
Connect-MgGraph -Scopes @(
    'Policy.ReadWrite.ConditionalAccess',
    'Policy.ReadWrite.Authorization',
    'Application.ReadWrite.All',
    'Directory.ReadWrite.All',
    'Policy.Read.All',
    'RoleManagement.ReadWrite.Directory'
) -NoWelcome
```

**For Cleanup and Mapping (Target Tenant):**
```powershell
Connect-MgGraph -Scopes @(
    'Policy.ReadWrite.ConditionalAccess',
    'Directory.ReadWrite.All',
    'Policy.Read.All',
    'Group.Read.All',
    'CustomSecAttributeDefinition.ReadWrite.All'  # For security attributes
) -NoWelcome
```

**Note on Custom Security Attributes:**
Creating Custom Security Attributes requires one of these **Entra ID directory roles**:
- Attribute Administrator
- Attribute Definition Administrator
- Global Administrator

If you don't have these roles, the cleanup script will skip attribute creation (other functions still work).

### Required Groups in Target Tenant

**CRITICAL:** Group names must match EXACTLY (including spaces) for automatic ID mapping to work!

Before running the recreation script, ensure these groups exist with the **correct names**:

**Core Groups (Always Required):**
- **Azure-Breakglass** - Emergency access accounts (no spaces in this name)
- **CA - DeviceExclusions** - Device-based exclusions (note: space before and after hyphen)
- **CA - GlobalExclusions** - Global policy exclusions (note: space before and after hyphen)
- **CA - ServiceAccounts** - Service account exclusions (note: space before and after hyphen)
- **CA - GuestExclusions** - Guest user exclusions (note: space before and after hyphen)

**Optional Groups (Feature-specific):**
- **CA - TravelingUsers** - Users traveling outside normal locations
- **CA - Azure-DevOps-Users** - Azure DevOps users
- **CA - Agent-Admins** - Agent administrators
- **CA - Agent-Users** - Agent users

**Dynamic License Groups (P1/P2):**
- **CA-P1InternalLicensedUsers** - Premium P1 licensed users (no spaces in this name)
- **CA-P2InternalLicensedUsers** - Premium P2 licensed users (no spaces in this name)

**AVD Groups (If using Azure Virtual Desktop policies):**
- **AVDUsers** - AVD internal users (no spaces)
- **AVD-ExternalUsers** - AVD external users

**Use the provided script to create all groups:**
```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
pwsh -NoProfile -File create-ca-groups.ps1
```

The recreation script will **automatically find these groups by display name** and map old tenant IDs to new tenant IDs. No manual mapping files required!

## Detailed Script Reference

### 1. export-iac-entra-policies-json.ps1

**Purpose:** Export IAC policies from source tenant to JSON files

**Usage:**
```powershell
pwsh -NoProfile -File export-iac-entra-policies-json.ps1
```

**What it exports:**
- Conditional Access policies (prefix: "IAC")
- Named Locations (prefix: "IAC")
- Custom Authentication Strengths
- Custom Security Attributes (if configured)

**Output:** JSON files in `/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/`

---

### 2. recreate-iac-entra-policies.ps1

**Purpose:** Import and recreate policies in target tenant from JSON files with **automatic ID mapping**

**Usage:**
```powershell
# Basic import
pwsh -NoProfile -File recreate-iac-entra-policies.ps1

# Using clean session wrapper (recommended)
pwsh -NoProfile -File run-policy-recreation-clean.ps1
```

**What it creates (in order):**
1. **Named Locations FIRST** (policies depend on these)
   - Builds location ID mapping: Old source tenant location IDs → New target tenant location IDs
2. **Group ID Mapping** (automatic)
   - Scans all policy JSON files for group references
   - Looks up each group in target tenant by displayName
   - Builds group ID mapping: Old source tenant group IDs → New target tenant group IDs
3. **Custom Authentication Strengths**
4. **Custom Security Attributes**
5. **Conditional Access Policies**
   - Applies location ID mapping to all location references
   - Applies group ID mapping to all group references
   - Creates policies with correct IDs for the target tenant

**Important Notes:**
- **Automatic ID Mapping:** Script automatically maps location and group IDs - no manual mapping files needed!
- **Run Once:** Only run this script once per tenant - it does all mapping automatically
- Creates summary file: `/Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json`
- All policies created in "disabled" state for safety - enable after verification

**Prerequisites:**
- All required groups must exist in target tenant BEFORE running
- Group names must match exactly (including spaces like "CA - DeviceExclusions")
- Use `create-ca-groups.ps1` to create all groups with correct names

**Common Issues:**
- **Group not found errors:** Group names don't match exactly - check for missing/extra spaces
- **Location not found errors:** Named locations weren't created first (script handles this automatically now)
- **Duplicate policies:** Don't run this script multiple times - use delete-all script to start fresh if needed

---

### 3. cleanup-and-map-policies.ps1 (OPTIONAL - Only if you have duplicates)

**Purpose:** Clean up duplicate policies and locations if recreation script was run multiple times

**When to use:**
- ❌ **NOT NEEDED:** If you ran recreation script only once (automatic mapping handles everything)
- ✅ **NEEDED:** If you ran recreation script multiple times and have duplicate policies/locations
- ✅ **NEEDED:** If you want to clean up old/test policies

**Alternative:** Use `delete-all-iac-policies-and-locations.ps1` to remove everything and start fresh

**Usage:**
```powershell
# Preview changes (RECOMMENDED FIRST)
pwsh -NoProfile -File cleanup-and-map-policies.ps1 -WhatIf

# Execute cleanup
pwsh -NoProfile -File cleanup-and-map-policies.ps1
```

**What it does:**

**Step 1: Remove Duplicate CA Policies**
- If recreate script ran multiple times, you'll have duplicate policies
- Keeps the most recent copy of each policy (by creation date)
- Deletes older duplicates

**Step 2: Remove Duplicate Named Locations**
- Same logic as policies
- Keeps most recent, deletes older copies

**Step 3: Import Custom Security Attributes**
- Looks for `SecurityAttributes/` directory
- Creates any custom security attribute sets defined in JSON
- Skips if directory doesn't exist

**Step 4: Map Group GUIDs**
- Scans all CA policies for group exclusions
- Removes invalid GUIDs from old tenant
- Automatically finds new tenant groups by name:
  - Azure-Breakglass
  - CA-GlobalExclusions
  - CA-DeviceExclusions
  - CA-ServiceAccounts
  - CA-GuestExclusions
  - CA-TravelingUsers
  - CA-Azure-DevOps-Users

**Note:** This script is now mostly obsolete since the recreation script does automatic mapping. Only use it to clean up duplicates from multiple recreation runs.

---

### 4. delete-all-iac-policies-and-locations.ps1

**Purpose:** Delete all IAC policies and named locations to start fresh

**When to use:**
- ✅ You want to start fresh and re-run the recreation script
- ✅ You have duplicate policies/locations and want a clean slate
- ✅ You're testing and need to reset the tenant
- ❌ Don't use if you just want to update a few policies - use Entra portal instead

**Usage:**
```powershell
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts
echo "DELETE ALL" | ./delete-all-iac-policies-and-locations.ps1
```

**What it does:**
1. **Confirms deletion** - Requires you to type "DELETE ALL" to proceed
2. **Deletes all IAC policies** - Any policy with "IAC" in display name
3. **Deletes all IAC named locations** - Any location with "IAC" in display name
   - Handles trusted locations: Automatically unmarks as trusted before deletion
   - Iterates 2-3 times due to backend caching
4. **Shows summary** - Reports how many items deleted

**Important Notes:**
- This is **PERMANENT** - deleted policies cannot be recovered
- Use `-WhatIf` parameter to preview what would be deleted (if available)
- Trusted locations require beta endpoint to unmark - script handles this automatically
- May take 30-60 seconds due to iteration required for trusted locations

**After cleanup:**
```powershell
# Verify everything deleted
Get-MgConditionalAccessPolicy | Where-Object { $_.DisplayName -like '*IAC*' }
Get-MgConditionalAccessNamedLocation | Where-Object { $_.DisplayName -like '*IAC*' }

# Should return nothing

# Now safe to run recreation script again
./run-policy-recreation-clean.ps1
```
  - Plus others (see prerequisites)

**Output:**
- Console shows progress for each action
- Summary of deletions and updates at the end
- Errors are reported with details

**Example Output:**
```
===================================================
  Cleanup and Mapping Summary
===================================================
Duplicate policies deleted:  36
Duplicate locations deleted: 2
Attribute sets created:      0
Policies updated (GUIDs):    16
Errors encountered:          0
```

---

### 4. run-policy-recreation-clean.ps1

**Purpose:** Wrapper that runs recreation in a clean PowerShell session

**Usage:**
```powershell
pwsh -NoProfile -File run-policy-recreation-clean.ps1
```

**Why use this:**
- Avoids module conflicts (especially Exchange Online module corruption)
- Runs in isolated PowerShell process with `-NoProfile`
- Automatically removes problematic modules before loading Graph modules
- Useful when you get "Could not find file" errors related to Exchange module

**What it does:**
1. Creates a temporary script with all commands
2. Launches new PowerShell process with `-NoProfile`
3. Connects to Microsoft Graph with required scopes
4. Runs recreate-iac-entra-policies.ps1
5. Waits for user to review before closing

---

## Best Practices and Prevention Tips

### 1. Always Create Groups First
**BEFORE** running the recreation script, create all required groups with correct names:
```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts/Entra
./create-ca-groups.ps1
```

Verify groups exist:
```powershell
Get-MgGroup -All | Where-Object { $_.DisplayName -match '^CA' } | Select DisplayName
```

### 2. Run Recreation Script Only Once
The recreation script does **automatic ID mapping** - you only need to run it once per tenant:
- ✅ Location IDs are mapped automatically
- ✅ Group IDs are mapped automatically
- ✅ No manual mapping files required
- ❌ Don't run multiple times - creates duplicates

If you need to start over, use the delete-all script:
```powershell
echo "DELETE ALL" | ./delete-all-iac-policies-and-locations.ps1
./run-policy-recreation-clean.ps1
```

### 3. Verify Group Names Match Exactly
Group names must be **character-for-character identical** between JSON and tenant:
- ✅ Correct: `"CA - DeviceExclusions"` (space before and after hyphen)
- ❌ Wrong: `"CA-DeviceExclusions"` (no spaces)
- ❌ Wrong: `"CA  -  DeviceExclusions"` (too many spaces)

### 4. Review Summary File After Recreation
Check for errors:
```powershell
cat /Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json
```

Look for:
- `"Status": "Failed"` - Policy creation failed
- `"LocationsCreated"` - Should match expected count (5)
- `"PoliciesCreated"` - Should match expected count (28)
- `"Errors"` - Should be empty array

### 5. Keep Policies Disabled Until Verified
All policies are created in "disabled" state for safety:
1. Review each policy in Entra portal
2. Verify group exclusions applied correctly
3. Verify location references resolved correctly
4. Enable policies one at a time
5. Test user access after enabling

### 6. Backup Before Making Changes
Export current state before running cleanup/delete:
```powershell
# Export current tenant state
./export-iac-entra-policies-json.ps1

# Rename export folder with date
mv /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON-backup-$(date +%Y%m%d)
```

### 7. Test in Non-Production First
Before deploying to production:
1. Test in dev/test tenant first
2. Verify all policies work as expected
3. Test user scenarios
4. Monitor for issues
5. Only then deploy to production

---

## Common Workflows

### Complete New Tenant Deployment

```powershell
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts

# 1. Export from source (if needed)
./export-iac-entra-policies-json.ps1

# 2. Create policies in target
./run-policy-recreation-clean.ps1

# 3. Preview cleanup
./cleanup-and-map-policies.ps1 -WhatIf

# 4. Execute cleanup
./cleanup-and-map-policies.ps1

# 5. Verify
cat /Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json
```

### Fix Duplicate Policies (After Multiple Imports)

```powershell
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts

# Preview what will be deleted
./cleanup-and-map-policies.ps1 -WhatIf

# Execute deletion
./cleanup-and-map-policies.ps1
```

### Update Group Mappings Only

```powershell
# The cleanup script always checks and updates group GUIDs
# Run it anytime you need to refresh group mappings
./cleanup-and-map-policies.ps1
```

### Backup Current Policies

```powershell
cd /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts

# Export to JSON
./export-iac-entra-policies-json.ps1

# Copy to timestamped backup
$date = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -Recurse "../" "/Backups/IAC-Entra-$date"
```

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

## Important Notes

### ✅ Best Practices

1. **Always use the recommended deployment order:**
   - Export → Recreate → Cleanup (with -WhatIf first)
2. **Preview cleanup changes** with `-WhatIf` before executing
3. **Ensure required groups exist** in target tenant before cleanup
4. **Export regularly** for disaster recovery
5. **Version control** JSON files in Git
6. **Test in non-production** first
7. **Review cleanup summary** for errors after execution

### ⚠️ Important Considerations

**Group GUID Mapping:**
- The recreate script will create policies with **invalid group GUIDs** from the source tenant
- This is **expected behavior** - the cleanup script fixes this automatically
- The cleanup script finds groups by **display name**, not GUID
- **Required groups must exist** before running cleanup:
  - Azure-Breakglass
  - CA-GlobalExclusions
  - CA-DeviceExclusions
  - CA-ServiceAccounts
  - CA-GuestExclusions
  - CA-TravelingUsers
  - CA-Azure-DevOps-Users
  - CA-P1InternalLicensedUsers
  - CA-P2InternalLicensedUsers
  - CA-Agent-Admins
  - CA-Agent-Users

**Duplicate Policies:**
- Running recreate script multiple times creates duplicates
- Cleanup script removes duplicates (keeps most recent)
- **Always run cleanup after recreation** to ensure clean state

**Policy States:**
- Policies are created in their **original state** (enabled/disabled/report-only)
- Consider manually setting all to "report-only" first for testing
- Review and enable policies incrementally

**Named Locations:**
- Must be created before CA policies that reference them
- Recreate script handles this automatically (creates locations first)
- Some duplicate locations may fail to delete if in use by policies (this is safe to ignore)

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

### Recreate Script Issues

**Problem: Module loading errors / "Could not find file" errors**
```powershell
# Use the clean session wrapper instead
pwsh -NoProfile -File run-policy-recreation-clean.ps1

# OR manually remove Exchange module first
Remove-Module ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue
pwsh -NoProfile -File recreate-iac-entra-policies.ps1
```

**Problem: Permission errors during creation**
```powershell
# Reconnect with all required scopes
Disconnect-MgGraph
Connect-MgGraph -Scopes @(
    'Policy.ReadWrite.ConditionalAccess',
    'Policy.ReadWrite.Authorization',
    'Application.ReadWrite.All',
    'Directory.ReadWrite.All',
    'Policy.Read.All',
    'RoleManagement.ReadWrite.Directory'
) -NoWelcome
```

**Problem: Policies created multiple times (duplicates)**
```powershell
# This is expected if you ran the script multiple times
# Run cleanup script to remove duplicates
./cleanup-and-map-policies.ps1 -WhatIf   # Preview first
./cleanup-and-map-policies.ps1           # Execute
```

### Cleanup Script Issues

**Problem: "BadRequest" errors when deleting named locations**
```
# This happens when locations are still referenced by policies
# Safe to ignore - the location is in use and shouldn't be deleted
# The script keeps the most recent copy anyway
```

**Problem: Group mapping finds no groups**
```powershell
# Verify groups exist in tenant
Connect-MgGraph -Scopes 'Group.Read.All'
Get-MgGroup | Where-Object {$_.DisplayName -like 'CA-*' -or $_.DisplayName -like 'Azure-*'} | 
    Select-Object DisplayName, Id

# Create missing groups if needed
# Groups must exist with exact names for mapping to work
```

**Problem: Policies updated but still have no exclusions**
```powershell
# The cleanup script only removes invalid GUIDs
# It doesn't add new groups - it just cleans up old ones
# You may need to manually add the correct groups via Entra portal
# Or use a separate script to bulk-add exclusions
```

### Export Script Issues

**Problem: No policies exported**
```powershell
# Verify connection
Get-MgContext

# Check for IAC policies
Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" |
    Select-Object -ExpandProperty value |
    Where-Object displayName -like "IAC*"
```

**Problem: Permission errors**
```powershell
# Reconnect with correct scopes
Disconnect-MgGraph
Connect-MgGraph -Scopes @(
    'Policy.Read.All',
    'Application.Read.All',
    'Directory.Read.All'
) -NoWelcome
```

### Validation Commands

**Check current policies:**
```powershell
# Count total policies
$policies = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
Write-Host "Total CA policies: $($policies.value.Count)"

# List IAC policies
$policies.value | Where-Object {$_.displayName -like "IAC*"} |
    Select-Object displayName, state, id | Format-Table -AutoSize
```

**Check for duplicate policies:**
```powershell
$policies = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
$policies.value | Group-Object displayName | Where-Object Count -gt 1 | 
    Select-Object Name, Count | Format-Table -AutoSize
```

**Verify named locations:**
```powershell
$locations = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations"
$locations.value | Where-Object {$_.displayName -like "IAC*"} |
    Select-Object displayName, '@odata.type', id | Format-Table -AutoSize
```

**Check for duplicate locations:**
```powershell
$locations = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations"
$locations.value | Group-Object displayName | Where-Object Count -gt 1 |
    Select-Object Name, Count | Format-Table -AutoSize
```

**Verify group mappings in policies:**
```powershell
# Check if policies have valid group exclusions
$policies = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
$policies.value | Where-Object {$_.displayName -like "IAC*" -and $_.conditions.users.excludeGroups} | 
    ForEach-Object {
        Write-Host "`nPolicy: $($_.displayName)"
        Write-Host "Excluded Groups: $($_.conditions.users.excludeGroups.Count)"
        # Try to resolve each group
        foreach ($groupId in $_.conditions.users.excludeGroups) {
            try {
                $group = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$groupId"
                Write-Host "  ✅ $($group.displayName) ($groupId)" -ForegroundColor Green
            } catch {
                Write-Host "  ❌ Invalid GUID: $groupId" -ForegroundColor Red
            }
        }
    }
```

**Check recreation summary:**
```powershell
cat /Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
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

**v2.0** (2026-02-04) - Major Update
- Added cleanup-and-map-policies.ps1 for duplicate removal and GUID mapping
- Added run-policy-recreation-clean.ps1 wrapper for clean session execution
- Updated deployment workflow with recommended step-by-step process
- Added automatic group mapping by display name
- Improved documentation with detailed script reference
- Added troubleshooting for common deployment scenarios
- Added validation commands for checking duplicates and group mappings

**v1.0** (2026-01-16) - Initial Release
- Export CA policies and Named Locations to JSON
- Import with ID mapping support
- Dry-run testing capability
- Complete documentation
