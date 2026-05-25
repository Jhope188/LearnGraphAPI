# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All", "Policy.ReadWrite.DeviceConfiguration"

Write-Host "`n🔧 Step 1: Enabling LAPS in Entra ID Device Settings...`n" -ForegroundColor Cyan

try {
    # Get current device registration policy
    $currentPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy"
    
    # Enable LAPS for Azure AD joined devices
    $deviceRegistrationBody = @{
        localAdminPassword = @{
            isEnabled = $true
        }
    }
    
    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/policies/deviceRegistrationPolicy" -Body ($deviceRegistrationBody | ConvertTo-Json -Depth 10)
    
    Write-Host "✅ LAPS enabled in Entra ID Device Settings" -ForegroundColor Green
    Write-Host "   Local Admin Password backup: Enabled`n" -ForegroundColor White
    
} catch {
    Write-Host "⚠️  Warning: Could not enable LAPS in Entra ID: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   You may need to enable this manually in Entra ID > Devices > Device settings`n" -ForegroundColor Yellow
}

Write-Host "`n🔐 Step 2: Creating Windows LAPS Custom Configuration Policy...`n" -ForegroundColor Cyan

# Define the Windows LAPS Custom Policy using OMA-URI
$lapsPolicy = @{
    "@odata.type" = "#microsoft.graph.windows10CustomConfiguration"
    displayName = "IaC - Windows - LAPS - Policy"
    description = "Windows Local Administrator Password Solution (LAPS) configuration"
    omaSettings = @(
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Backup Directory"
            description = "Backup the password to Microsoft Entra ID only"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/BackupDirectory"
            value = 1
        },
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Password Age Days"
            description = "Maximum password age in days before rotation"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/PasswordAgeDays"
            value = 10
        },
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Password Complexity"
            description = "Large letters + small letters + numbers + special characters"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/PasswordComplexity"
            value = 4
        },
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Password Length"
            description = "Length of the generated password"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/PasswordLength"
            value = 14
        },
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Post Authentication Actions"
            description = "Reset password upon expiry of the grace period"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/PostAuthenticationActions"
            value = 1
        },
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Post Authentication Reset Delay"
            description = "Hours to wait after authentication before resetting password"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/PostAuthenticationResetDelay"
            value = 24
        },
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Enable Administrator Account"
            description = "Enable the built-in Administrator account"
            omaUri = "./Device/Vendor/MSFT/Policy/Config/LocalPoliciesSecurityOptions/Accounts_EnableAdministratorAccountStatus"
            value = 1
        }
    )
}

try {
    # Create the LAPS Custom Configuration policy
    $policy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body ($lapsPolicy | ConvertTo-Json -Depth 20)
    
    Write-Host "✅ LAPS Custom Configuration Policy created successfully!" -ForegroundColor Green
    Write-Host "   Policy Name: $($policy.displayName)" -ForegroundColor White
    Write-Host "   Policy ID: $($policy.id)" -ForegroundColor White
    Write-Host "`n📋 Configuration Summary:" -ForegroundColor Yellow
    Write-Host "   Backup Directory: Azure AD only" -ForegroundColor White
    Write-Host "   Password Age: 10 days" -ForegroundColor White
    Write-Host "   Password Length: 14 characters" -ForegroundColor White
    Write-Host "   Password Complexity: Large+Small+Numbers+Special" -ForegroundColor White
    Write-Host "   Post-Auth Actions: Reset password upon expiry" -ForegroundColor White
    Write-Host "   Post-Auth Delay: 24 hours" -ForegroundColor White
    Write-Host "   Local Administrator Account: Enabled" -ForegroundColor White
    
    # Ask if user wants to assign the LAPS policy
    Write-Host "`n❓ Would you like to assign the LAPS policy to All Devices? (Y/N): " -ForegroundColor Yellow -NoNewline
    $assign = Read-Host
    
    if ($assign -eq 'Y' -or $assign -eq 'y') {
        # Create assignment for all devices
        $assignmentBody = @{
            deviceConfigurationGroupAssignments = @(
                @{
                    targetGroupId = "all_devices"
                }
            )
        }
        
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($policy.id)/assign" -Body (@{ assignments = @(@{ target = @{ "@odata.type" = "#microsoft.graph.allDevicesAssignmentTarget" } }) } | ConvertTo-Json -Depth 10)
        
        Write-Host "✅ LAPS policy assigned to All Devices" -ForegroundColor Green
    } else {
        Write-Host "⏭️  Skipped assignment." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Failed to create LAPS policy: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Error Details: $($_.Exception)" -ForegroundColor Red
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
