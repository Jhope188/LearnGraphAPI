# 1. Install the MSCommerce module (if not already installed)
Install-Module -Name MSCommerce -Scope CurrentUser -Force

# 2. Import the module
Import-Module MSCommerce

# 3. Connect to MSCommerce (requires sign-in with admin rights)
Connect-MSCommerce

# 4. Get and display all currently enabled SSP products
$enabledProducts = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase |
    Where-Object { $_.PolicyValue -eq "Enabled" }

if ($enabledProducts) {
    Write-Host "`n✅ Found the following products with SSP enabled:`n"
    $enabledProducts | Format-Table ProductName, ProductId, PolicyValue

    # 5. Disable SSP for each product
    foreach ($product in $enabledProducts) {
        Write-Host "Disabling SSP for: $($product.ProductName) ($($product.ProductId))"
        Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase -ProductId $product.ProductId -Enabled $false
    }

    Write-Host "`n✅ Self-service purchase disabled for all listed products.`n"
} else {
    Write-Host "`n✔️ No products found with Self-Service Purchase enabled.`n"
}

# 6. Confirm changes
Write-Host "🔍 Verifying updated policy status:"
Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase |
    Format-Table ProductName, ProductId, PolicyValue
