# Connect to Microsoft Graph with admin privileges
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization"

Write-Host "`n=== Applying Complete Admin Center Security Hardening ===" -ForegroundColor Cyan
Write-Host ""

# Apply comprehensive security settings
Write-Host "Applying authorization policy and user permissions..." -ForegroundColor Yellow
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    AllowedToSignUpEmailBasedSubscriptions = $false  # Disable email-based trials
    AllowEmailVerifiedUsersToJoinOrganization = $false  # Prevent unauthorized join requests
    BlockMsolPowerShell = $true  # Block legacy PowerShell module
    DefaultUserRolePermissions = @{
        AllowedToCreateApps = $false  # Prevent unauthorized app registration
        AllowedToCreateSecurityGroups = $false  # Centralize group management
        AllowedToCreateTenants = $false  # Prevent tenant sprawl
        AllowedToReadBitlockerKeysForOwnedDevice = $true  # Keep enabled for self-service
        AllowedToReadOtherUsers = $true  # Keep enabled for collaboration
    }
}

Write-Host "✓ Authorization policy and user permissions applied" -ForegroundColor Green
Write-Host ""

# Verify the changes
Write-Host "=== Verification ===" -ForegroundColor Cyan
$authPolicy = Get-MgPolicyAuthorizationPolicy

Write-Host "Authorization Policy:" -ForegroundColor Yellow
Write-Host "  Email-based subscriptions:" ($authPolicy.AllowedToSignUpEmailBasedSubscriptions ? "ENABLED" : "DISABLED") -ForegroundColor $(if (-not $authPolicy.AllowedToSignUpEmailBasedSubscriptions) { "Green" } else { "Red" })
Write-Host "  Email verified users can join:" ($authPolicy.AllowEmailVerifiedUsersToJoinOrganization ? "ENABLED" : "DISABLED") -ForegroundColor $(if (-not $authPolicy.AllowEmailVerifiedUsersToJoinOrganization) { "Green" } else { "Red" })
Write-Host "  Block MSOL PowerShell:" ($authPolicy.BlockMsolPowerShell ? "ENABLED" : "DISABLED") -ForegroundColor $(if ($authPolicy.BlockMsolPowerShell) { "Green" } else { "Red" })

Write-Host ""
Write-Host "Default User Permissions:" -ForegroundColor Yellow
Write-Host "  Can create apps:" ($authPolicy.DefaultUserRolePermissions.AllowedToCreateApps ? "Yes" : "No") -ForegroundColor $(if (-not $authPolicy.DefaultUserRolePermissions.AllowedToCreateApps) { "Green" } else { "Red" })
Write-Host "  Can create security groups:" ($authPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups ? "Yes" : "No") -ForegroundColor $(if (-not $authPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups) { "Green" } else { "Red" })
Write-Host "  Can create tenants:" ($authPolicy.DefaultUserRolePermissions.AllowedToCreateTenants ? "Yes" : "No") -ForegroundColor $(if (-not $authPolicy.DefaultUserRolePermissions.AllowedToCreateTenants) { "Green" } else { "Red" })
Write-Host "  Can read Bitlocker keys:" ($authPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice ? "Yes" : "No") -ForegroundColor $(if ($authPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice) { "Green" } else { "Red" })
Write-Host "  Can read other users:" ($authPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers ? "Yes" : "No") -ForegroundColor $(if ($authPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers) { "Green" } else { "Red" })
Write-Host ""

# Disable all User Owned Apps and Services settings via MSCommerce
Write-Host "=== Disabling User Self-Service Purchase Policies ===" -ForegroundColor Cyan
Write-Host "Running in subprocess to avoid assembly conflicts..." -ForegroundColor Yellow

# Create temporary script for subprocess to handle all user-owned app settings
$logFile = "/tmp/mscommerce-output.log"
$tempScript = @'
Import-Module MSCommerce
Connect-MSCommerce

Write-Host ""
Write-Host "Disabling all self-service and admin-initiated trial policies..." -ForegroundColor Yellow

# Disable self-service purchases (AllowSelfServicePurchase)
Write-Host ""
Write-Host "Processing AllowSelfServicePurchase policies..." -ForegroundColor Cyan
$selfServiceProducts = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
$disabledSelfService = 0
$alreadyDisabledSelfService = 0

foreach ($product in $selfServiceProducts) {
    if ($product.PolicyValue -eq "Enabled") {
        Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase -ProductId $product.ProductId -Enabled $false
        Write-Host "  ✓ Disabled self-service: $($product.ProductName)" -ForegroundColor Green
        $disabledSelfService++
    } else {
        $alreadyDisabledSelfService++
    }
}

# Disable admin-initiated trials (AllowAdminTrialPurchase) - "Starting trials on behalf of your organization"
Write-Host ""
Write-Host "Processing AllowAdminTrialPurchase policies..." -ForegroundColor Cyan
$adminTrialProducts = Get-MSCommerceProductPolicies -PolicyId AllowAdminTrialPurchase
$disabledAdminTrial = 0
$alreadyDisabledAdminTrial = 0

foreach ($product in $adminTrialProducts) {
    if ($product.PolicyValue -eq "Enabled") {
        Update-MSCommerceProductPolicy -PolicyId AllowAdminTrialPurchase -ProductId $product.ProductId -Enabled $false
        Write-Host "  ✓ Disabled admin trial: $($product.ProductName)" -ForegroundColor Green
        $disabledAdminTrial++
    } else {
        $alreadyDisabledAdminTrial++
    }
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Self-Service Purchases:" -ForegroundColor Yellow
Write-Host "    Newly disabled: $disabledSelfService" -ForegroundColor Green
Write-Host "    Already disabled: $alreadyDisabledSelfService" -ForegroundColor Gray
Write-Host "  Admin-Initiated Trials:" -ForegroundColor Yellow
Write-Host "    Newly disabled: $disabledAdminTrial" -ForegroundColor Green
Write-Host "    Already disabled: $alreadyDisabledAdminTrial" -ForegroundColor Gray
Write-Host "  Total products: $($selfServiceProducts.Count)" -ForegroundColor White

# Verify all are disabled
Write-Host ""
Write-Host "Final Verification:" -ForegroundColor Cyan
$finalSelfService = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase | Where-Object { $_.PolicyValue -eq "Enabled" }
$finalAdminTrial = Get-MSCommerceProductPolicies -PolicyId AllowAdminTrialPurchase | Where-Object { $_.PolicyValue -eq "Enabled" }

if ($finalSelfService.Count -eq 0) {
    Write-Host "  ✅ All self-service purchases DISABLED" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Warning: $($finalSelfService.Count) self-service purchases still enabled" -ForegroundColor Red
    $finalSelfService | ForEach-Object { Write-Host "    - $($_.ProductName)" -ForegroundColor Red }
}

if ($finalAdminTrial.Count -eq 0) {
    Write-Host "  ✅ All admin-initiated trials DISABLED" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Warning: $($finalAdminTrial.Count) admin trials still enabled" -ForegroundColor Red
    $finalAdminTrial | ForEach-Object { Write-Host "    - $($_.ProductName)" -ForegroundColor Red }
}
'@

$tempScript | Out-File -FilePath "/tmp/disable-purchases-subprocess.ps1" -Encoding UTF8

# Run subprocess and capture output
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = "pwsh"
$processInfo.Arguments = "-NoProfile -File /tmp/disable-purchases-subprocess.ps1"
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true
$processInfo.UseShellExecute = $false
$processInfo.CreateNoWindow = $false

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo
$process.Start() | Out-Null
$output = $process.StandardOutput.ReadToEnd()
$errors = $process.StandardError.ReadToEnd()
$process.WaitForExit()

# Display the output
Write-Host $output
if ($errors) {
    Write-Host "Errors:" -ForegroundColor Red
    Write-Host $errors -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Admin Center Security Complete ===" -ForegroundColor Green
Write-Host "All automated security settings have been applied." -ForegroundColor White
Write-Host ""

# Manual configuration instructions
Write-Host "=== Manual Configuration Required ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  MANUAL ACTION REQUIRED:" -ForegroundColor Yellow
Write-Host "The following settings must be configured manually in the M365 Admin Center:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. User Owned Apps and Services:" -ForegroundColor White
Write-Host "   Navigate to: Settings > Org settings > Services > 'User owned apps and services'" -ForegroundColor Gray
Write-Host "   Uncheck:" -ForegroundColor White
Write-Host "   ☐ Let users access the Office Store" -ForegroundColor Red
Write-Host "   ☐ Let admins start trials on behalf of their users" -ForegroundColor Red
Write-Host ""
Write-Host "2. Copilot Agent Settings:" -ForegroundColor White
Write-Host "   Navigate to: Copilot > Settings > Data access > Agents" -ForegroundColor Gray
Write-Host "   Configure:" -ForegroundColor White
Write-Host "   • Who can access agents: Specific users/groups (recommended)" -ForegroundColor Yellow
Write-Host "   • Who can share agents: Specific users (recommended)" -ForegroundColor Yellow
Write-Host "   • Which types of apps/agents users are allowed to install:" -ForegroundColor Yellow
Write-Host "     ☐ Allow apps and agents created by Microsoft" -ForegroundColor Red
Write-Host "     ☐ Allow apps and agents created by external publishers" -ForegroundColor Red
Write-Host "     ☑ Allow apps and agents built by your organization" -ForegroundColor Green
Write-Host ""
Write-Host "Note: These settings require special API authentication (admin.microsoft.com or" -ForegroundColor Gray
Write-Host "      TeamworkAppSettings.ReadWrite.All scope) and cannot be automated via standard" -ForegroundColor Gray
Write-Host "      Graph API or PowerShell cmdlets with current authentication." -ForegroundColor Gray