# Connect to Microsoft Graph with admin privileges
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization"

# Disable self-service email-based subscriptions (trials)
Update-MgPolicyAuthorizationPolicy -BodyParameter @{
    allowedToSignUpEmailBasedSubscriptions = $false
}

# Verify the change
Write-Host "`n=== User Self-Service Trial Settings ===" -ForegroundColor Cyan
Get-MgPolicyAuthorizationPolicy | Select-Object AllowedToSignUpEmailBasedSubscriptions

# Install MSCommerce module if not present
if (-not (Get-Module -ListAvailable -Name MSCommerce)) {
    Write-Host "`nInstalling MSCommerce module..." -ForegroundColor Yellow
    Install-Module -Name MSCommerce -Force -AllowClobber
}

# Import MSCommerce module
Import-Module MSCommerce

# Connect to MSCommerce
Connect-MSCommerce

# Disable admin-initiated trials for all products
Write-Host "`n=== Disabling Admin-Initiated Trials ===" -ForegroundColor Cyan
$products = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase

foreach ($product in $products) {
    if ($product.PolicyValue -eq "Enabled") {
        Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase -ProductId $product.ProductId -Enabled $false
        Write-Host "Disabled trials for: $($product.ProductName)" -ForegroundColor Green
    }
}

# Verify admin trial settings
Write-Host "`n=== Current Admin Trial Policy Status ===" -ForegroundColor Cyan
Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase | 
    Select-Object ProductName, PolicyValue | 
    Format-Table -AutoSize