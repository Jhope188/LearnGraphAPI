# IAC Policy Recreation Script

This script recreates all IAC Intune policies from exported JSON files into a target tenant.

## How It Works

1. **Export Script** (`export-iac-policies-json.ps1`): Exports all IAC policies from source tenant to JSON files
2. **Recreate Script** (`recreate-iac-policies.ps1`): Imports JSON files and recreates policies in target tenant

## Folder Structure

```
/Users/jon/Desktop/BaslineSetup/
├── Scripts/
│   └── Intune/
│       ├── export-iac-policies-json.ps1      # Export policies to JSON
│       ├── recreate-iac-policies.ps1          # Recreate from JSON
│       └── README-RecreateIACPolicies.md      # This file
│
└── IAC-Policies-JSON/                         # JSON export location
    ├── index.json                             # Summary of all exports
    ├── DeviceConfiguration/                   # Device Config policies
    │   ├── IAC - Policy Name 1.json
    │   └── IAC - Policy Name 2.json
    ├── SettingsCatalog/                       # Settings Catalog policies
    │   ├── IAC - Windows - LAPS Policy.json
    │   └── IAC - Windows - OneDrive Profile.json
    ├── Compliance/                            # Compliance policies
    ├── AdminTemplates/                        # Admin Template/Group Policy
    ├── EndpointSecurity/                      # Endpoint Security Intents
    ├── Scripts/                               # PowerShell scripts
    └── Autopilot/                             # Autopilot profiles
```

Each JSON file contains:
- Complete policy configuration
- All settings (Settings Catalog, Admin Templates, Endpoint Security)
- Assignment information
- Export timestamp

## Prerequisites

1. **PowerShell 7+**
2. **Microsoft.Graph PowerShell module** installed:
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   ```
3. **Appropriate permissions** in both source and target tenants:
   - `DeviceManagementConfiguration.ReadWrite.All`
   - `DeviceManagementApps.ReadWrite.All`
4. **Exported JSON files** from source tenant (created by running export script)

## Quick Start Guide

### Step 1: Export Policies from Source Tenant

First, connect to your **source tenant** and export all IAC policies to JSON:

```powershell
# Navigate to the scripts directory
cd /Users/jon/Desktop/BaslineSetup/Scripts/Intune

# Run the export script
pwsh -File export-iac-policies-json.ps1
```

This creates the folder structure at `/Users/jon/Desktop/BaslineSetup/IAC-Policies-JSON/` with all policies exported as individual JSON files.

**Output:**
```
IAC-Policies-JSON/
├── index.json
├── DeviceConfiguration/       (5 policies)
├── SettingsCatalog/          (14 policies)
├── Compliance/               (0 policies)
├── AdminTemplates/           (1 policy)
├── EndpointSecurity/         (0 policies)
├── Scripts/                  (0 scripts)
└── Autopilot/                (0 profiles)
```

### Step 2: Transfer JSON Files (if needed)

If creating policies in a different tenant, copy the entire `IAC-Policies-JSON` folder to your target location or keep it in the same location.

### Step 3: Recreate Policies in Target Tenant

Connect to your **target tenant** and run the recreate script:

```powershell
# Disconnect from source tenant
Disconnect-MgGraph

# Navigate to scripts directory
cd /Users/jon/Desktop/BaslineSetup/Scripts/Intune

# Test first with dry run
pwsh -File recreate-iac-policies.ps1 -DryRun

# Create policies without assignments
pwsh -File recreate-iac-policies.ps1

# OR create with assignments (see usage examples below)
```

## Usage Examples

### Basic Usage (No Assignments)

Recreates all IAC policies from JSON files without assignments:

```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts/Intune
pwsh -File recreate-iac-policies.ps1
```

### Dry Run Mode

Test the script without creating any policies (recommended first step):

```powershell
pwsh -File recreate-iac-policies.ps1 -DryRun
```

### Custom Import Path

If your JSON files are in a different location:

```powershell
pwsh -File recreate-iac-policies.ps1 -ImportPath "/path/to/IAC-Policies-JSON"
```

### Include Assignments

Recreates policies with their assignments (uses same group IDs from export):

```powershell
pwsh -File recreate-iac-policies.ps1 -IncludeAssignments
```

### With Group ID Mapping

Map source group IDs to target tenant group IDs:

```powershell
$groupMapping = @{
    "aaaaaaaa-1111-2222-3333-444444444444" = "bbbbbbbb-5555-6666-7777-888888888888"
    "source-all-users-id" = "target-all-users-id"
}

pwsh -File recreate-iac-policies.ps1 -IncludeAssignments -GroupIdMapping $groupMapping
```

### Combined Example

Dry run with assignments and group mapping to test everything:

```powershell
$groupMapping = @{
    "old-group-id-1" = "new-group-id-1"
    "old-group-id-2" = "new-group-id-2"
}

pwsh -File recreate-iac-policies.ps1 -DryRun -IncludeAssignments -GroupIdMapping $groupMapping
```

## Complete Workflow Example

### Scenario: Migrating IAC Policies to New Tenant

**Step 1: Export from Source Tenant**

```powershell
# Connect to source tenant
Connect-MgGraph -TenantId "source-tenant-id"

# Export all IAC policies
cd /Users/jon/Desktop/BaslineSetup/Scripts/Intune
pwsh -File export-iac-policies-json.ps1

# Verify export
ls /Users/jon/Desktop/BaslineSetup/IAC-Policies-JSON/
cat /Users/jon/Desktop/BaslineSetup/IAC-Policies-JSON/index.json
```

**Step 2: Prepare Group Mappings (if using assignments)**

```powershell
# Disconnect from source
Disconnect-MgGraph

# Connect to target tenant
Connect-MgGraph -TenantId "target-tenant-id"

# List groups in target tenant to get IDs
Get-MgGroup -Filter "startswith(displayName, 'IAC')" | Select-Object DisplayName, Id
Get-MgGroup -Filter "displayName eq 'All Users'" | Select-Object DisplayName, Id

# Create mapping hashtable
$groupMapping = @{
    # Source Group ID = Target Group ID
    "12345678-abcd-1234-abcd-123456789012" = "abcdefab-1234-5678-90ab-cdefabcdef12"
    "source-all-users-guid" = "target-all-users-guid"
}
```

**Step 3: Test with Dry Run**

```powershell
cd /Users/jon/Desktop/BaslineSetup/Scripts/Intune
pwsh -File recreate-iac-policies.ps1 -DryRun -IncludeAssignments -GroupIdMapping $groupMapping
```

**Step 4: Create Policies**

```powershell
# If dry run looks good, run for real
pwsh -File recreate-iac-policies.ps1 -IncludeAssignments -GroupIdMapping $groupMapping
```

**Step 5: Review Results**

```powershell
# Check the summary file
cat /Users/jon/Desktop/BaslineSetup/policy-recreation-summary.json

# Verify in Intune portal
# https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles
```

## Output

The script provides:

1. **Console Output**: Real-time progress and results
2. **Summary Report**: JSON file with created/failed policies
   - Location: `/Users/jon/Desktop/BaslineSetup/policy-recreation-summary.json`

### Summary Report Format

```json
{
  "CreatedPolicies": [
    {
      "Type": "Settings Catalog",
      "Name": "IAC - Windows - LAPS Policy",
      "SourceId": "old-policy-id",
      "NewId": "new-policy-id"
    }
  ],
  "FailedPolicies": [
    {
      "Type": "Device Configuration",
      "Name": "IAC - Some Policy",
      "Error": "Error message"
    }
  ],
  "Timestamp": "2026-01-16 18:30:00",
  "DryRun": false,
  "IncludeAssignments": true
}
```

## Important Notes

### Assignments

- If `-IncludeAssignments` is **not** specified, policies are created without assignments
- If specified without `-GroupIdMapping`, it uses the same group IDs (may fail if groups don't exist)
- Use `-GroupIdMapping` to map source group IDs to target group IDs

### Policy Types

Some policy types may require additional configuration:
- **Autopilot Profiles**: Not included (requires separate handling)
- **PowerShell Scripts**: Not included (scripts need to be uploaded separately)
- **App Protection Policies**: Not included (IAC policies typically don't include these)

### Limitations

- Filters must exist in target tenant with same IDs (or be manually mapped)
- Some complex policies may fail due to tenant-specific configurations
- Certificates and other tenant-specific resources must be configured separately

## Troubleshooting

### Authentication Errors

Ensure you have the correct permissions:
```powershell
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All", "DeviceManagementApps.ReadWrite.All"
```

### Group Assignment Failures

If assignments fail:
1. Verify groups exist in target tenant
2. Check group IDs in mapping are correct
3. Ensure groups are Entra ID security groups (not M365 groups for device policies)

### Policy Creation Failures

Check the error message in the summary report. Common issues:
- Missing templates in target tenant
- Tenant-specific settings (e.g., certificates)
- Platform version differences

## Advanced Usage

### Filter Specific Policy Types

Modify the script to only process certain policy types by commenting out sections.

### Custom Naming

Modify the script to add prefixes or change naming:

```powershell
# In each Create-* function, modify the name:
$policyBody = @{
    name = "PROD-" + $sourcePolicy.name  # Add prefix
}
```

## Support

For issues or questions:
1. Check the summary report for specific error messages
2. Review failed policies individually
3. Verify permissions and group IDs
4. Test with `-DryRun` first

## Version History

- **v1.0** (2026-01-16): Initial release
  - Support for Device Config, Settings Catalog, Compliance, Admin Templates, Endpoint Security
  - Assignment recreation with group mapping
  - Dry-run mode
  - Summary reporting
