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

Write-Host "`n🔐 Step 2: Creating Windows LAPS Policy...`n" -ForegroundColor Cyan

# Define the Windows LAPS Policy
$policyBody = @{
    "@odata.type" = "#microsoft.graph.windows10CustomConfiguration"
    displayName = "IaC - Windows - LAPS - Policy"
    description = "Windows Local Administrator Password Solution (LAPS) configuration"
    
    # OMA-URI settings for Windows LAPS
    omaSettings = @(
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Password Age (Days)"
            description = "Maximum password age in days before rotation"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/PasswordAgeDays"
            value = 30
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
            displayName = "Password Complexity"
            description = "Password complexity: 1=Large letters, 2=Large+Small, 3=Large+Small+Numbers, 4=Large+Small+Numbers+Special"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/PasswordComplexity"
            value = 4
        },
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Administrator Account Name"
            description = "Specifies which account to manage: 1=Administrator SID, 2=Custom account name"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/AdministratorAccountName"
            value = 1
        },
        @{
            "@odata.type" = "#microsoft.graph.omaSettingInteger"
            displayName = "Backup Directory"
            description = "Where to backup passwords: 1=Azure AD only, 2=AD only, 3=Azure AD and AD"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/BackupDirectory"
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
            displayName = "Post Authentication Actions"
            description = "Actions after authentication: 1=Reset password, 3=Reset password and logoff"
            omaUri = "./Device/Vendor/MSFT/LAPS/Policies/PostAuthenticationActions"
            value = 3
        }
    )
}

Write-Host "`n🔐 Creating Windows LAPS Policy...`n" -ForegroundColor Cyan

try {
    # Create the policy
    $policy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body ($policyBody | ConvertTo-Json -Depth 10)
    
    Write-Host "✅ LAPS Policy created successfully!" -ForegroundColor Green
    Write-Host "   Policy Name: $($policy.displayName)" -ForegroundColor White
    Write-Host "   Policy ID: $($policy.id)" -ForegroundColor White
    Write-Host "`n📋 Configuration Summary:" -ForegroundColor Yellow
    Write-Host "   Password Age: 30 days" -ForegroundColor White
    Write-Host "   Password Length: 14 characters" -ForegroundColor White
    Write-Host "   Password Complexity: Large+Small+Numbers+Special" -ForegroundColor White
    Write-Host "   Backup Location: Azure AD" -ForegroundColor White
    Write-Host "   Post-Auth Actions: Reset password and logoff" -ForegroundColor White
    Write-Host "   Post-Auth Delay: 24 hours" -ForegroundColor White
    
    # Ask if user wants to assign the policy
    Write-Host "`n❓ Would you like to assign this policy to All Devices? (Y/N): " -ForegroundColor Yellow -NoNewline
    $assign = Read-Host
    
    if ($assign -eq 'Y' -or $assign -eq 'y') {
        # Create assignment for all devices
        $assignmentBody = @{
            assignments = @(
                @{
                    target = @{
                        "@odata.type" = "#microsoft.graph.allDevicesAssignmentTarget"
                    }
                }
            )
        }
        
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($policy.id)/assign" -Body ($assignmentBody | ConvertTo-Json -Depth 10)
        
        Write-Host "✅ Policy assigned to All Devices" -ForegroundColor Green
    } else {
        Write-Host "⏭️  Skipped assignment. You can assign this policy manually in the Intune portal." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Failed to create policy: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Error Details: $($_.Exception)" -ForegroundColor Red
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
