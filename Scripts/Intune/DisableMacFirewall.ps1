# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"

# Define the macOS Endpoint Protection policy (Firewall DISABLED)
$policyBody = @{
    "@odata.type" = "#microsoft.graph.macOSEndpointProtectionConfiguration"
    displayName = "ACME - Disable- MacOS - Firewall"
    description = "Disables macOS firewall settings"
    
    # FileVault settings (keeping same as original)
    fileVaultEnabled = $true
    fileVaultAllowDeferralUntilSignOut = $true
    fileVaultDisablePromptAtSignOut = $false
    fileVaultHidePersonalRecoveryKey = $false
    fileVaultNumberOfTimesUserCanIgnore = $null
    fileVaultPersonalRecoveryKeyHelpMessage = "Please log into company portal to find your encryption key."
    fileVaultPersonalRecoveryKeyRotationInMonths = 3
    fileVaultSelectedRecoveryKeyTypes = "personalRecoveryKey"
    
    # Firewall settings (ALL DISABLED)
    firewallEnabled = $false
    firewallBlockAllIncoming = $false
    firewallEnableStealthMode = $false
    firewallApplications = @()
    
    # Gatekeeper settings (keeping same as original)
    gatekeeperAllowedAppSource = "notConfigured"
    gatekeeperBlockOverride = $false
    
    # Advanced Threat Protection settings (keeping same as original)
    advancedThreatProtectionRealTime = "notConfigured"
    advancedThreatProtectionCloudDelivered = "notConfigured"
    advancedThreatProtectionAutomaticSampleSubmission = "notConfigured"
    advancedThreatProtectionDiagnosticDataCollection = "notConfigured"
    advancedThreatProtectionExcludedExtensions = @()
    advancedThreatProtectionExcludedFiles = @()
    advancedThreatProtectionExcludedFolders = @()
    advancedThreatProtectionExcludedProcesses = @()
}

Write-Host "`n🔧 Creating macOS Endpoint Protection Policy with Firewall DISABLED...`n" -ForegroundColor Cyan

try {
    # Create the policy
    $policy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body ($policyBody | ConvertTo-Json -Depth 10)
    
    Write-Host "✅ Policy created successfully!" -ForegroundColor Green
    Write-Host "   Policy Name: $($policy.displayName)" -ForegroundColor White
    Write-Host "   Policy ID: $($policy.id)" -ForegroundColor White
    Write-Host "   Firewall Enabled: $($policy.firewallEnabled)" -ForegroundColor Red
    Write-Host "   Stealth Mode: $($policy.firewallEnableStealthMode)" -ForegroundColor Red
    Write-Host "   Block All Incoming: $($policy.firewallBlockAllIncoming)" -ForegroundColor Red
    
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
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
