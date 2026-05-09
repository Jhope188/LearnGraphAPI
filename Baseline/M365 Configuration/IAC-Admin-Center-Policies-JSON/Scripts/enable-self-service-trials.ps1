#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Re-enables self-service trials and purchases for Microsoft 365.

.DESCRIPTION
    This script re-enables user self-service trials and self-service purchases
    for all Microsoft 365 products. This allows users to sign up for trials
    and purchase subscriptions independently.

.NOTES
    Author: Infrastructure as Code Team
    Version: 1.0
    Last Updated: January 25, 2026
    
    WARNING: This reduces tenant security by allowing:
    - Users to sign up for free trials (shadow IT risk)
    - Users to purchase subscriptions with credit card (budget risk)
    
.EXAMPLE
    ./enable-self-service-trials.ps1
#>

[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = "Stop"

Write-Host "`n=== Enable Self-Service Trials and Purchases ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  WARNING: This will allow users to:" -ForegroundColor Red
Write-Host "  • Sign up for Microsoft service trials independently" -ForegroundColor Yellow
Write-Host "  • Purchase subscriptions with their credit card" -ForegroundColor Yellow
Write-Host "  • Create shadow IT and uncontrolled costs" -ForegroundColor Yellow
Write-Host ""

# Prompt for confirmation
$confirmation = Read-Host "Type 'ENABLE' to confirm enabling self-service trials (or press Enter to cancel)"

if ($confirmation -ne "ENABLE") {
    Write-Host "`n✗ Operation cancelled by user" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Connect to Microsoft Graph with admin privileges
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    $context = Get-MgContext
    if (-not $context) {
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization"
        $context = Get-MgContext
    }
    Write-Host "✓ Connected to Microsoft Graph" -ForegroundColor Green
    Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Gray
    Write-Host "  Account: $($context.Account)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Failed to connect to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Enable self-service email-based subscriptions (trials)
Write-Host "Enabling user self-service trials..." -ForegroundColor Yellow
try {
    Update-MgPolicyAuthorizationPolicy -BodyParameter @{
        allowedToSignUpEmailBasedSubscriptions = $true
    }
    Write-Host "✓ Email-based subscriptions enabled" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to enable email-based subscriptions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify the change
Write-Host ""
Write-Host "=== User Self-Service Trial Settings ===" -ForegroundColor Cyan
$authPolicy = Get-MgPolicyAuthorizationPolicy
Write-Host "AllowedToSignUpEmailBasedSubscriptions:" ($authPolicy.AllowedToSignUpEmailBasedSubscriptions ? "ENABLED" : "DISABLED") -ForegroundColor $(if ($authPolicy.AllowedToSignUpEmailBasedSubscriptions) { "Yellow" } else { "Red" })

Write-Host ""

# Install MSCommerce module if not present
Write-Host "Checking MSCommerce module..." -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable -Name MSCommerce)) {
    Write-Host "Installing MSCommerce module..." -ForegroundColor Yellow
    try {
        Install-Module -Name MSCommerce -Force -AllowClobber -Scope CurrentUser
        Write-Host "✓ MSCommerce module installed" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to install MSCommerce module: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Self-service purchases cannot be enabled without this module" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "✓ MSCommerce module already installed" -ForegroundColor Green
}

Write-Host ""

# Import MSCommerce module
Write-Host "Loading MSCommerce module..." -ForegroundColor Cyan
try {
    Import-Module MSCommerce -ErrorAction Stop
    Write-Host "✓ MSCommerce module loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load MSCommerce module: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Self-service purchases cannot be enabled" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Connect to MSCommerce
Write-Host "Connecting to MSCommerce..." -ForegroundColor Cyan
try {
    Connect-MSCommerce
    Write-Host "✓ Connected to MSCommerce" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to connect to MSCommerce: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Enable self-service purchases for all products
Write-Host "=== Enabling Self-Service Purchases for All Products ===" -ForegroundColor Cyan
Write-Host ""

try {
    $products = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
    $enabledCount = 0
    $alreadyEnabledCount = 0
    
    foreach ($product in $products) {
        if ($product.PolicyValue -eq "Disabled") {
            try {
                Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase -ProductId $product.ProductId -Enabled $true
                Write-Host "  ✓ Enabled: $($product.ProductName)" -ForegroundColor Green
                $enabledCount++
            } catch {
                Write-Host "  ✗ Failed: $($product.ProductName) - $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  • Already enabled: $($product.ProductName)" -ForegroundColor Gray
            $alreadyEnabledCount++
        }
    }
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  • Products enabled: $enabledCount" -ForegroundColor $(if ($enabledCount -gt 0) { "Yellow" } else { "Gray" })
    Write-Host "  • Products already enabled: $alreadyEnabledCount" -ForegroundColor Gray
    Write-Host "  • Total products: $($products.Count)" -ForegroundColor Gray
    
} catch {
    Write-Host "✗ Failed to enable self-service purchases: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Verify settings
Write-Host "=== Final Verification ===" -ForegroundColor Cyan
Write-Host ""

try {
    $finalProducts = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
    $enabledProducts = $finalProducts | Where-Object { $_.PolicyValue -eq "Enabled" }
    $disabledProducts = $finalProducts | Where-Object { $_.PolicyValue -eq "Disabled" }
    
    Write-Host "Self-Service Purchase Status:" -ForegroundColor Yellow
    Write-Host "  • Enabled products: $($enabledProducts.Count)" -ForegroundColor $(if ($enabledProducts.Count -gt 0) { "Yellow" } else { "Red" })
    Write-Host "  • Disabled products: $($disabledProducts.Count)" -ForegroundColor $(if ($disabledProducts.Count -eq 0) { "Green" } else { "Gray" })
    
    if ($disabledProducts.Count -gt 0) {
        Write-Host ""
        Write-Host "⚠️  Some products remain disabled:" -ForegroundColor Yellow
        $disabledProducts | Select-Object -First 5 | ForEach-Object {
            Write-Host "    - $($_.ProductName)" -ForegroundColor Gray
        }
        if ($disabledProducts.Count -gt 5) {
            Write-Host "    ... and $($disabledProducts.Count - 5) more" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "⚠️  Could not verify final status: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Self-service trials and purchases enabled!" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Security Impact:" -ForegroundColor Yellow
Write-Host "  • Users can now sign up for Microsoft service trials" -ForegroundColor Gray
Write-Host "  • Users can purchase subscriptions with their credit card" -ForegroundColor Gray
Write-Host "  • This may lead to shadow IT and uncontrolled costs" -ForegroundColor Gray
Write-Host "  • Consider monitoring user activity and purchases" -ForegroundColor Gray
Write-Host ""
Write-Host "To disable again, run: ./admincenterconfig.ps1" -ForegroundColor Cyan
Write-Host ""
