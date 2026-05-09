<#
.SYNOPSIS
    Exports current Microsoft 365 Administrative Center configuration settings.

.DESCRIPTION
    This script documents the current state of administrative center features including:
    - User self-service trial settings
    - Self-service purchase policies per product
    - Authorization policies
    
    Outputs to both console and a JSON file for documentation purposes.

.PARAMETER OutputPath
    Path where the JSON configuration file will be saved. 
    Default: ../Admin-Center-Configuration.json

.EXAMPLE
    .\export-admin-center-config.ps1
    # Exports configuration using default output path

.EXAMPLE
    .\export-admin-center-config.ps1 -OutputPath "C:\Config\admin-config.json"
    # Exports configuration to custom path

.NOTES
    Author: IAC Automation Team
    Version: 1.0
    Last Updated: 2025-01-17
    
    Requires: 
    - Microsoft.Graph.Identity.SignIns module
    - MSCommerce module
    - Connected to Microsoft Graph with Policy.Read.All scope
    - Connected to MSCommerce
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "$PSScriptRoot/../Admin-Center-Configuration.json"
)

Write-Host "`n=== Exporting Microsoft 365 Admin Center Configuration ===" -ForegroundColor Cyan
Write-Host "Output Path: $OutputPath`n"

$config = @{
    ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    TenantInfo = @{}
    AuthorizationPolicy = @{}
    SelfServicePurchasePolicies = @()
}

#region Connect to Microsoft Graph

try {
    Write-Host "Checking Microsoft Graph connection..." -ForegroundColor Yellow
    $mgContext = Get-MgContext
    
    if (-not $mgContext) {
        Write-Host "Not connected to Microsoft Graph. Connecting..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "Policy.Read.All", "Organization.Read.All" -NoWelcome
        $mgContext = Get-MgContext
    }
    
    $config.TenantInfo = @{
        TenantId = $mgContext.TenantId
        Account = $mgContext.Account
        Scopes = $mgContext.Scopes
    }
    
    Write-Host "✓ Connected to Microsoft Graph" -ForegroundColor Green
    Write-Host "  Tenant ID: $($mgContext.TenantId)" -ForegroundColor Gray
    Write-Host "  Account: $($mgContext.Account)`n" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to connect to Microsoft Graph: $_" -ForegroundColor Red
    exit 1
}

#endregion

#region Get Authorization Policy (Self-Service Trials)

try {
    Write-Host "Retrieving authorization policy settings..." -ForegroundColor Yellow
    $authPolicy = Get-MgPolicyAuthorizationPolicy
    
    $config.AuthorizationPolicy = @{
        Id = $authPolicy.Id
        DisplayName = $authPolicy.DisplayName
        Description = $authPolicy.Description
        AllowedToSignUpEmailBasedSubscriptions = $authPolicy.AllowedToSignUpEmailBasedSubscriptions
        AllowedToUseSSPR = $authPolicy.AllowedToUseSSPR
        AllowEmailVerifiedUsersToJoinOrganization = $authPolicy.AllowEmailVerifiedUsersToJoinOrganization
        BlockMsolPowerShell = $authPolicy.BlockMsolPowerShell
        DefaultUserRolePermissions = @{
            AllowedToCreateApps = $authPolicy.DefaultUserRolePermissions.AllowedToCreateApps
            AllowedToCreateSecurityGroups = $authPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups
            AllowedToCreateTenants = $authPolicy.DefaultUserRolePermissions.AllowedToCreateTenants
            AllowedToReadBitlockerKeysForOwnedDevice = $authPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice
            AllowedToReadOtherUsers = $authPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers
        }
    }
    
    Write-Host "✓ Authorization policy retrieved" -ForegroundColor Green
    Write-Host "  Email-based subscriptions allowed: $($authPolicy.AllowedToSignUpEmailBasedSubscriptions)" -ForegroundColor Gray
    Write-Host "  Block MSOL PowerShell: $($authPolicy.BlockMsolPowerShell)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "✗ Failed to retrieve authorization policy: $_" -ForegroundColor Red
    $config.AuthorizationPolicy = @{ Error = $_.Exception.Message }
}

#endregion

#region Get Self-Service Purchase Policies

try {
    Write-Host "Checking MSCommerce module..." -ForegroundColor Yellow
    
    if (-not (Get-Module -ListAvailable -Name MSCommerce)) {
        Write-Host "  MSCommerce module not found. Installing..." -ForegroundColor Yellow
        Install-Module -Name MSCommerce -Force -AllowClobber -Scope CurrentUser
    }
    
    Import-Module MSCommerce -ErrorAction Stop
    Write-Host "✓ MSCommerce module loaded" -ForegroundColor Green
    
    Write-Host "`nConnecting to MSCommerce..." -ForegroundColor Yellow
    try {
        # Try to get policies without connecting (if already connected)
        $products = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase -ErrorAction Stop
    }
    catch {
        # If not connected, connect now
        Connect-MSCommerce
        $products = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
    }
    
    Write-Host "✓ Connected to MSCommerce" -ForegroundColor Green
    Write-Host "`nRetrieving self-service purchase policies..." -ForegroundColor Yellow
    
    foreach ($product in $products) {
        $config.SelfServicePurchasePolicies += @{
            ProductId = $product.ProductId
            ProductName = $product.ProductName
            PolicyId = $product.PolicyId
            PolicyValue = $product.PolicyValue
        }
    }
    
    $enabledCount = ($products | Where-Object { $_.PolicyValue -eq "Enabled" }).Count
    $disabledCount = ($products | Where-Object { $_.PolicyValue -eq "Disabled" }).Count
    
    Write-Host "✓ Self-service purchase policies retrieved" -ForegroundColor Green
    Write-Host "  Total products: $($products.Count)" -ForegroundColor Gray
    Write-Host "  Enabled: $enabledCount" -ForegroundColor Gray
    Write-Host "  Disabled: $disabledCount`n" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to retrieve self-service purchase policies: $_" -ForegroundColor Red
    $config.SelfServicePurchasePolicies = @(@{ Error = $_.Exception.Message })
}

#endregion

#region Export Configuration

try {
    Write-Host "Exporting configuration to JSON..." -ForegroundColor Yellow
    $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "✓ Configuration exported successfully" -ForegroundColor Green
    Write-Host "  Output: $OutputPath`n" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to export configuration: $_" -ForegroundColor Red
    exit 1
}

#endregion

#region Display Summary

Write-Host "=== Configuration Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Authorization Policy:" -ForegroundColor White
Write-Host "  • Email-based subscriptions (trials): " -NoNewline
if ($config.AuthorizationPolicy.AllowedToSignUpEmailBasedSubscriptions) {
    Write-Host "ENABLED" -ForegroundColor Red
} else {
    Write-Host "DISABLED" -ForegroundColor Green
}

Write-Host "  • Email verified users can join: " -NoNewline
if ($config.AuthorizationPolicy.AllowEmailVerifiedUsersToJoinOrganization) {
    Write-Host "ENABLED" -ForegroundColor Red
} else {
    Write-Host "DISABLED" -ForegroundColor Green
}

Write-Host "  • Block legacy MSOL PowerShell: " -NoNewline
if ($config.AuthorizationPolicy.BlockMsolPowerShell) {
    Write-Host "ENABLED" -ForegroundColor Green
} else {
    Write-Host "DISABLED" -ForegroundColor Red
}

Write-Host "`nDefault User Permissions:" -ForegroundColor White
Write-Host "  • Can create apps: $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateApps)"
Write-Host "  • Can create security groups: $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups)"
Write-Host "  • Can create tenants: $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateTenants)"
Write-Host "  • Can read Bitlocker keys: $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice)"
Write-Host "  • Can read other users: $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers)"

Write-Host "`nSelf-Service Purchase Policies:" -ForegroundColor White
$enabledProducts = $config.SelfServicePurchasePolicies | Where-Object { $_.PolicyValue -eq "Enabled" }
$disabledProducts = $config.SelfServicePurchasePolicies | Where-Object { $_.PolicyValue -eq "Disabled" }

if ($enabledProducts.Count -gt 0) {
    Write-Host "  Enabled Products ($($enabledProducts.Count)):" -ForegroundColor Red
    foreach ($product in ($enabledProducts | Sort-Object ProductName)) {
        Write-Host "    • $($product.ProductName)" -ForegroundColor Red
    }
}

if ($disabledProducts.Count -gt 0) {
    Write-Host "  Disabled Products ($($disabledProducts.Count)):" -ForegroundColor Green
    foreach ($product in ($disabledProducts | Sort-Object ProductName)) {
        Write-Host "    • $($product.ProductName)" -ForegroundColor Gray
    }
}

Write-Host "`n✅ Export complete!`n" -ForegroundColor Green

#endregion
