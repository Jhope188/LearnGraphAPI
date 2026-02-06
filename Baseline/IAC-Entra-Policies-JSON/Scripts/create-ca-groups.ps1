# Connect to Microsoft Graph with admin privileges
Connect-MgGraph -Scopes "Group.ReadWrite.All"

# Define the groups to create
$groupsToCreate = @(
    # Static Security Groups
    @{ Name = "CA-DeviceExclusions"; Description = "Conditional Access - Device Exclusions"; IsDynamic = $false }
    @{ Name = "CA-GlobalExclusions"; Description = "Conditional Access - Global Exclusions"; IsDynamic = $false }
    @{ Name = "CA-GuestExclusions"; Description = "Conditional Access - Guest Exclusions"; IsDynamic = $false }
    @{ Name = "CA-ServiceAccounts"; Description = "Conditional Access - Service Accounts"; IsDynamic = $false }
    @{ Name = "CA-TravelingUsers"; Description = "Conditional Access - Traveling Users"; IsDynamic = $false }
    @{ Name = "CA-Azure-DevOps-Users"; Description = "Conditional Access - Azure DevOps Users"; IsDynamic = $false }
    @{ Name = "CA-Agent-Users"; Description = "Users able to use AI Agents"; IsDynamic = $false }
    @{ Name = "CA-Agent-Admins"; Description = "Users able to approve Agents in Admin Center"; IsDynamic = $false }
    @{ Name = "Azure-Breakglass"; Description = "Emergency Break Glass Accounts"; IsDynamic = $false }
    @{ Name = "MFA-AUTH-SMS"; Description = "MFA Authentication - SMS"; IsDynamic = $false }
    @{ Name = "MFA-AUTH-EAM"; Description = "MFA Authentication - EAM"; IsDynamic = $false }
    @{ Name = "MFA-AUTH-Passkey"; Description = "MFA Authentication - Passkey"; IsDynamic = $false }
   
    
    # Dynamic Security Groups
    @{ 
        Name = "CA-P1InternalLicensedUsers"
        Description = "Conditional Access - P1 Internal Licensed Users (Dynamic)"
        IsDynamic = $true
        MembershipRule = '(user.assignedPlans -any (assignedPlan.servicePlanId -eq "41781fb2-bc02-4b7c-bd55-b576c07bb09d" and assignedPlan.capabilityStatus -eq "Enabled"))'
    }
    @{ 
        Name = "CA-P2InternalLicensedUsers"
        Description = "Conditional Access - P2 Internal Licensed Users (Dynamic)"
        IsDynamic = $true
        MembershipRule = '(user.assignedPlans -any (assignedPlan.servicePlanId -eq "eec0eb4f-6444-4f95-aba0-50c24d67f998" and assignedPlan.capabilityStatus -eq "Enabled"))'
    }
    @{ 
        Name = "ADM-Users-Dynamic"
        Description = "Dynamic group for Admin Users"
        IsDynamic = $true
        MembershipRule = '(user.userPrincipalName -contains ".adm")'
    }
    @{ 
        Name = "Disabled-Users-Dynamic"
        Description = "Dynamic group for Disabled Users"
        IsDynamic = $true
        MembershipRule = '(user.accountEnabled -eq false)'
    }
    @{ 
        Name = "Guest-Users-Dynamic"
        Description = "Dynamic group for Guest Users"
        IsDynamic = $true
        MembershipRule = '(user.userType -eq "Guest")'
    }
    @{ 
        Name = "AVD-Host-Dynamic"
        Description = "Dynamic group for AVD Hosts"
        IsDynamic = $true
        MembershipRule = '(device.displayName -startsWith "AVD-")'
    }
    @{ 
        Name = "W365-Devices-Dynamic"
        Description = "Dynamic group for Azure Cloud PC Devices"
        IsDynamic = $true
        MembershipRule = '(device.deviceModel -contains "Cloud PC")'
    }
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
            
            # Add dynamic membership settings if this is a dynamic group
            if ($group.IsDynamic) {
                $params.groupTypes = @("DynamicMembership")
                $params.membershipRule = $group.MembershipRule
                $params.membershipRuleProcessingState = "On"
            }
            
            New-MgGroup -BodyParameter $params | Out-Null
            
            if ($group.IsDynamic) {
                Write-Host "✅ Created (Dynamic): $groupName" -ForegroundColor Green
            } else {
                Write-Host "✅ Created (Static): $groupName" -ForegroundColor Green
            }
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


