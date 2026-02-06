# Remove corrupted Exchange Online module if present
Remove-Module ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue

# Verify required modules can load
try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop
} catch {
    Write-Host "❌ Error loading required modules: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Try running: Remove-Module ExchangeOnlineManagement -Force" -ForegroundColor Yellow
    exit 1
}

# Connect to Microsoft Graph
try {
    Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess", "Group.Read.All" -ErrorAction Stop
} catch {
    Write-Host "❌ Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Updating CA Policy Exclusion Groups ===" -ForegroundColor Cyan
Write-Host ""

# Get the correct group IDs from current tenant
$groups = @{
    "Azure-Breakglass" = (Get-MgGroup -Filter "displayName eq 'Azure-Breakglass'").Id
    "CA-GlobalExclusions" = (Get-MgGroup -Filter "displayName eq 'CA-GlobalExclusions'").Id
    "CA-DeviceExclusions" = (Get-MgGroup -Filter "displayName eq 'CA-DeviceExclusions'").Id
    "CA-ServiceAccounts" = (Get-MgGroup -Filter "displayName eq 'CA-ServiceAccounts'").Id
    "CA-GuestExclusions" = (Get-MgGroup -Filter "displayName eq 'CA-GuestExclusions'").Id
    "CA-TravelingUsers" = (Get-MgGroup -Filter "displayName eq 'CA-TravelingUsers'").Id
    "CA-Azure-DevOps-Users" = (Get-MgGroup -Filter "displayName eq 'CA-Azure-DevOps-Users'").Id
}

Write-Host "Found groups:" -ForegroundColor Yellow
foreach ($key in $groups.Keys) {
    Write-Host "  $key : $($groups[$key])" -ForegroundColor White
}
Write-Host ""

# Old GUIDs from source tenant (to be replaced)
$oldGuids = @(
    '822cebe7-b527-405c-8bae-834782ec74cb',
    '21344a9f-6ef0-4181-970a-15202237ac4b',
    '6064391a-c4b7-4991-b87f-e7a98fcd23aa',
    'c07caedd-cc1f-483e-8ff9-332f6aad189b',
    '063f926c-a676-4880-9edd-78a0ee7d5ff4',
    '33a0d7cd-c3b2-4252-b441-3697e7453046',
    '8782b8eb-5554-4d69-a496-1106cf10aac4',
    '0007f38d-c059-4dac-91bf-ed108dda8d02'
)

# Mapping of old GUIDs to new group names (based on CA policy JSON structure)
$guidMapping = @{
    '822cebe7-b527-405c-8bae-834782ec74cb' = $groups["Azure-Breakglass"]  # Break glass account
    '21344a9f-6ef0-4181-970a-15202237ac4b' = $groups["CA-ServiceAccounts"]  # Service accounts
    '6064391a-c4b7-4991-b87f-e7a98fcd23aa' = $groups["CA-GlobalExclusions"]  # Global exclusions
    'c07caedd-cc1f-483e-8ff9-332f6aad189b' = $groups["CA-GuestExclusions"]  # Guest exclusions
    '063f926c-a676-4880-9edd-78a0ee7d5ff4' = $groups["CA-TravelingUsers"]  # Traveling users
    '33a0d7cd-c3b2-4252-b441-3697e7453046' = $groups["CA-DeviceExclusions"]  # Device exclusions
    '8782b8eb-5554-4d69-a496-1106cf10aac4' = $groups["CA-DeviceExclusions"]  # Device exclusions (alternate)
    '0007f38d-c059-4dac-91bf-ed108dda8d02' = $groups["CA-Azure-DevOps-Users"]  # Azure DevOp users
}

Write-Host "Updating all CA policies..." -ForegroundColor Yellow
$policies = Get-MgIdentityConditionalAccessPolicy
$updatedCount = 0

foreach ($policy in $policies) {
    $needsUpdate = $false
    $newExcludeGroups = @()
    
    if ($policy.Conditions.Users.ExcludeGroups) {
        foreach ($oldGuid in $policy.Conditions.Users.ExcludeGroups) {
            if ($guidMapping.ContainsKey($oldGuid)) {
                $newExcludeGroups += $guidMapping[$oldGuid]
                $needsUpdate = $true
            } else {
                # Keep any groups that aren't in our mapping
                $newExcludeGroups += $oldGuid
            }
        }
        
        # Remove duplicates
        $newExcludeGroups = $newExcludeGroups | Select-Object -Unique
        
        if ($needsUpdate) {
            Write-Host "  Updating: $($policy.DisplayName)" -ForegroundColor Cyan
            Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -BodyParameter @{
                Conditions = @{
                    Users = @{
                        ExcludeGroups = $newExcludeGroups
                    }
                }
            }
            $updatedCount++
        }
    }
}

Write-Host ""
Write-Host "✅ Updated $updatedCount policies with correct group IDs" -ForegroundColor Green

Write-Host "`n=== Verification ===" -ForegroundColor Cyan
$policiesWithMissingGroups = 0
foreach ($policy in Get-MgIdentityConditionalAccessPolicy) {
    if ($policy.Conditions.Users.ExcludeGroups) {
        $hasMissing = $false
        foreach ($groupId in $policy.Conditions.Users.ExcludeGroups) {
            $group = Get-MgGroup -GroupId $groupId -ErrorAction SilentlyContinue
            if (-not $group) {
                $hasMissing = $true
                break
            }
        }
        if ($hasMissing) {
            $policiesWithMissingGroups++
        }
    }
}

if ($policiesWithMissingGroups -eq 0) {
    Write-Host "✅ All CA policies have valid exclusion groups!" -ForegroundColor Green
} else {
    Write-Host "⚠️ $policiesWithMissingGroups policies still have invalid group references" -ForegroundColor Red
}
