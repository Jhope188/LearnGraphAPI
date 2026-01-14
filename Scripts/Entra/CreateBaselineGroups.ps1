# Connect to Microsoft Graph with admin privileges
Connect-MgGraph -Scopes "Group.ReadWrite.All"

# Define the groups to create
$groupsToCreate = @(
    @{ Name = "CA-DeviceExclusions"; Description = "Conditional Access - Device Exclusions" }
    @{ Name = "CA-GlobalExclusions"; Description = "Conditional Access - Global Exclusions" }
    @{ Name = "CA-GuestExclusions"; Description = "Conditional Access - Guest Exclusions" }
    @{ Name = "CA-ServiceAccounts"; Description = "Conditional Access - Service Accounts" }
    @{ Name = "CA-TravelingUsers"; Description = "Conditional Access - Traveling Users" }
    @{ Name = "CA-Azure-DevOps-Users"; Description = "Conditional Access - Azure DevOps Users" }
    @{ Name = "CA-P1InternalLicensedUsers"; Description = "Conditional Access - P1 Internal Licensed Users" }
    @{ Name = "CA-P2InternalLicensedUsers"; Description = "Conditional Access - P2 Internal Licensed Users" }
    @{ Name = "Azure-Breakglass"; Description = "Emergency Break Glass Accounts" }
    @{ Name = "MFA-AUTH-SMS"; Description = "MFA Authentication - SMS" }
    @{ Name = "MFA-AUTH-Call"; Description = "MFA Authentication - Phone Call" }
    @{ Name = "MFA-AUTH-Passkey"; Description = "MFA Authentication - Passkey" }
    @{ Name = "ADM-Users-Dynamic"; Description = "Dynamic group for Admin Users" }
    @{ Name = "Executives-Users-Dynamic"; Description = "Dynamic group for Executive Users" }
    @{ Name = "Guest-Users-Dynamic"; Description = "Dynamic group for Guest Users" }
    @{ Name = "AVD-Host-Dynamic"; Description = "Dynamic group for AVD Hosts" }
    @{ Name = "Azure-Resources-Dynamic"; Description = "Dynamic group for Azure Resources" }
)

Write-Host "`n🔍 Checking which groups already exist...`n" -ForegroundColor Cyan

# Get all existing groups
$existingGroups = Get-MgGroup -All | Select-Object DisplayName, Id

# Create groups that don't exist
$created = 0
$skipped = 0

foreach ($group in $groupsToCreate) {
    $groupName = $group.Name
    $existing = $existingGroups | Where-Object { $_.DisplayName -eq $groupName }
    
    if ($existing) {
        Write-Host "⏭️  Skipped: $groupName (already exists)" -ForegroundColor Yellow
        $skipped++
    } else {
        try {
            $params = @{
                displayName = $groupName
                description = $group.Description
                mailEnabled = $false
                mailNickname = $groupName
                securityEnabled = $true
            }
            
            New-MgGroup -BodyParameter $params | Out-Null
            Write-Host "✅ Created: $groupName" -ForegroundColor Green
            $created++
        } catch {
            Write-Host "❌ Failed to create: $groupName - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n📊 Summary:" -ForegroundColor Cyan
Write-Host "   ✅ Created: $created groups" -ForegroundColor Green
Write-Host "   ⏭️  Skipped: $skipped groups (already existed)" -ForegroundColor Yellow
Write-Host ""

# Display all matching groups
Write-Host "🔍 All CA/MFA/Dynamic Groups:" -ForegroundColor Cyan
Get-MgGroup -All | Where-Object { 
    $_.DisplayName -like "CA-*" -or 
    $_.DisplayName -like "MFA-*" -or 
    $_.DisplayName -like "*-Dynamic" -or 
    $_.DisplayName -eq "Azure-Breakglass"
} | Select-Object DisplayName, Id, Description | Format-Table -AutoSize
