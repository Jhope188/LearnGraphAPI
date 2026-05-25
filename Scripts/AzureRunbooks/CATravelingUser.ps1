Import-Module Microsoft.Graph.Authentication
# Connect to Microsoft Graph
Connect-MgGraph -Identity

# Set your group name
$groupName = "CA - TravelingUsers"  # Replace with your actual group name

# Step 1: Find the group by name
$group = Get-MgGroup -Filter "displayName eq '$groupName'" -ConsistencyLevel eventual -CountVariable count

if (-not $group) {
    Write-Host "Group '$groupName' not found." -ForegroundColor Red
    return
}

$groupId = $group.Id
$thresholdDate = (Get-Date).AddDays(-14)

# Step 2: Get current members of the group
$members = Get-MgGroupMember -GroupId $groupId -All
# Step 3: Get all 'Add member to group' audit logs
$auditLogs = Get-MgAuditLogDirectoryAudit -Filter "activityDisplayName eq 'Add member to group'" -All

# Step 4: Filter logs where the group ID appears in any TargetResource
$groupLogs = $auditLogs | Where-Object {
    $_.TargetResources | Where-Object { $_.Id -eq $groupId }
}

# Step 5: Match members with logs and filter those added more than 14 days ago
$filteredMembers = @()

foreach ($member in $members) {
    $memberId = $member.Id

    $log = $groupLogs | Where-Object {
        $_.TargetResources | Where-Object { $_.Id -eq $memberId }
    } | Sort-Object ActivityDateTime -Descending | Select-Object -First 1

    if ($log -and $log.ActivityDateTime -lt $thresholdDate) {
        $filteredMembers += [PSCustomObject]@{
            DisplayName = $member.AdditionalProperties.displayName
            UserId      = $member.Id
            AddedOn     = $log.ActivityDateTime
        }
    }
}

# Step 6: Output the results
$filteredMembers | Format-Table -AutoSize
 