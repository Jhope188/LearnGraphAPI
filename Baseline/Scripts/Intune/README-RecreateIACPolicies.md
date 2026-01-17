Script Parameters

### recreate-iac-policies.ps1

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-ImportPath` | String | No | `/Users/jon/Desktop/BaslineSetup/IAC-Policies-JSON` | Path to folder containing exported JSON files |
| `-DryRun` | Switch | No | `$false` | Test mode - shows what would be created without making changes |
| `-IncludeAssignments` | Switch | No | `$false` | Recreate policy assignments from JSON files |
| `-GroupIdMapping` | Hashtable | No | `@{}` | Maps source group IDs to target group IDs |

### export-iac-policies-json.ps1

No parameters required. Exports to: `/Users/jon/Desktop/BaslineSetup/IAC-Policies-JSON/