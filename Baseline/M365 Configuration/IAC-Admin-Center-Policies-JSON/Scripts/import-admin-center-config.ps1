<#
.SYNOPSIS
    Imports and applies Microsoft 365 Administrative Center configuration from JSON export.

.DESCRIPTION
    This script reads a previously exported Admin-Center-Configuration.json file and applies
    all settings to the current tenant including:
    - Authorization policy settings (email subscriptions, MSOL blocking, user permissions)
    - Self-service purchase policies for all products
    
    Supports dry-run mode to preview changes before applying them.

.PARAMETER ImportPath
    Path to the JSON configuration file to import. 
    Default: ../Admin-Center-Configuration.json

.PARAMETER DryRun
    When specified, shows what would be changed without actually applying changes.
    Useful for testing and validation.

.PARAMETER SkipAuthorizationPolicy
    Skip applying authorization policy settings (user permissions, MSOL blocking, etc.)

.PARAMETER SkipSelfServicePurchase
    Skip applying self-service purchase policies

.EXAMPLE
    .\import-admin-center-config.ps1
    # Imports and applies all configuration settings

.EXAMPLE
    .\import-admin-center-config.ps1 -DryRun
    # Shows what would be changed without making actual changes

.EXAMPLE
    .\import-admin-center-config.ps1 -ImportPath "C:\Config\admin-config.json"
    # Imports configuration from custom path

.EXAMPLE
    .\import-admin-center-config.ps1 -SkipSelfServicePurchase
    # Only applies authorization policy settings

.NOTES
    Author: IAC Automation Team
    Version: 1.0
    Last Updated: 2025-01-17
    
    Requires: 
    - Microsoft.Graph.Identity.SignIns module
    - MSCommerce module
    - Policy.ReadWrite.Authorization scope for Graph
    - Global Administrator or Privileged Role Administrator role
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ImportPath = "$PSScriptRoot/../Admin-Center-Configuration.json",
    
    [Parameter()]
    [switch]$DryRun,
    
    [Parameter()]
    [switch]$SkipAuthorizationPolicy,
    
    [Parameter()]
    [switch]$SkipSelfServicePurchase
)

# Resolve full path
$ImportPath = Resolve-Path $ImportPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path

if (-not $ImportPath -or -not (Test-Path $ImportPath)) {
    Write-Host "✗ Configuration file not found: $ImportPath" -ForegroundColor Red
    Write-Host "  Please run export-admin-center-config.ps1 first or specify correct path." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== Importing Microsoft 365 Admin Center Configuration ===" -ForegroundColor Cyan
Write-Host "Import Path: $ImportPath"
if ($DryRun) {
    Write-Host "Mode: DRY RUN (no changes will be applied)" -ForegroundColor Yellow
} else {
    Write-Host "Mode: LIVE (changes will be applied)" -ForegroundColor Green
}
Write-Host ""

# Load configuration
try {
    Write-Host "Loading configuration file..." -ForegroundColor Yellow
    $config = Get-Content $ImportPath | ConvertFrom-Json
    Write-Host "✓ Configuration loaded successfully" -ForegroundColor Green
    Write-Host "  Export Date: $($config.ExportDate)" -ForegroundColor Gray
    Write-Host "  Source Tenant: $($config.TenantInfo.TenantId)`n" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to load configuration: $_" -ForegroundColor Red
    exit 1
}

# Statistics
$stats = @{
    AuthPolicyAttempted = 0
    AuthPolicySuccess = 0
    AuthPolicyFailed = 0
    SelfServiceAttempted = 0
    SelfServiceSuccess = 0
    SelfServiceFailed = 0
}

#region Connect to Microsoft Graph

if (-not $SkipAuthorizationPolicy) {
    try {
        Write-Host "Checking Microsoft Graph connection..." -ForegroundColor Yellow
        $mgContext = Get-MgContext
        
        if (-not $mgContext) {
            Write-Host "Not connected to Microsoft Graph. Connecting..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization", "Organization.Read.All" -NoWelcome
            $mgContext = Get-MgContext
        }
        
        # Check if we have required scope
        if ($mgContext.Scopes -notcontains "Policy.ReadWrite.Authorization") {
            Write-Host "⚠️ Warning: Current connection may lack Policy.ReadWrite.Authorization scope" -ForegroundColor Yellow
            Write-Host "  Attempting to reconnect with required scopes..." -ForegroundColor Yellow
            Disconnect-MgGraph | Out-Null
            Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization", "Organization.Read.All" -NoWelcome
            $mgContext = Get-MgContext
        }
        
        Write-Host "✓ Connected to Microsoft Graph" -ForegroundColor Green
        Write-Host "  Target Tenant: $($mgContext.TenantId)" -ForegroundColor Gray
        Write-Host "  Account: $($mgContext.Account)`n" -ForegroundColor Gray
        
        # Warn if applying to different tenant
        if ($mgContext.TenantId -ne $config.TenantInfo.TenantId) {
            Write-Host "⚠️ WARNING: Applying configuration from different tenant!" -ForegroundColor Yellow
            Write-Host "  Source: $($config.TenantInfo.TenantId)" -ForegroundColor Yellow
            Write-Host "  Target: $($mgContext.TenantId)" -ForegroundColor Yellow
            if (-not $DryRun) {
                $confirm = Read-Host "Continue? (yes/no)"
                if ($confirm -ne "yes") {
                    Write-Host "Import cancelled by user." -ForegroundColor Yellow
                    exit 0
                }
            }
            Write-Host ""
        }
    }
    catch {
        Write-Host "✗ Failed to connect to Microsoft Graph: $_" -ForegroundColor Red
        exit 1
    }
}

#endregion

#region Apply Authorization Policy Settings

if (-not $SkipAuthorizationPolicy -and $config.AuthorizationPolicy) {
    Write-Host "`n=== Applying Authorization Policy Settings ===" -ForegroundColor Cyan
    
    try {
        # Get current settings for comparison
        Write-Host "Retrieving current authorization policy..." -ForegroundColor Yellow
        $currentPolicy = Get-MgPolicyAuthorizationPolicy
        
        # Build update parameters
        $updateParams = @{}
        $changes = @()
        
        # Check AllowedToSignUpEmailBasedSubscriptions
        if ($config.AuthorizationPolicy.AllowedToSignUpEmailBasedSubscriptions -ne $currentPolicy.AllowedToSignUpEmailBasedSubscriptions) {
            $updateParams['AllowedToSignUpEmailBasedSubscriptions'] = $config.AuthorizationPolicy.AllowedToSignUpEmailBasedSubscriptions
            $changes += "  • Email-based subscriptions: $($currentPolicy.AllowedToSignUpEmailBasedSubscriptions) → $($config.AuthorizationPolicy.AllowedToSignUpEmailBasedSubscriptions)"
            $stats.AuthPolicyAttempted++
        }
        
        # Check BlockMsolPowerShell
        if ($config.AuthorizationPolicy.BlockMsolPowerShell -ne $currentPolicy.BlockMsolPowerShell) {
            $updateParams['BlockMsolPowerShell'] = $config.AuthorizationPolicy.BlockMsolPowerShell
            $changes += "  • Block MSOL PowerShell: $($currentPolicy.BlockMsolPowerShell) → $($config.AuthorizationPolicy.BlockMsolPowerShell)"
            $stats.AuthPolicyAttempted++
        }
        
        # Check AllowEmailVerifiedUsersToJoinOrganization
        if ($config.AuthorizationPolicy.AllowEmailVerifiedUsersToJoinOrganization -ne $currentPolicy.AllowEmailVerifiedUsersToJoinOrganization) {
            $updateParams['AllowEmailVerifiedUsersToJoinOrganization'] = $config.AuthorizationPolicy.AllowEmailVerifiedUsersToJoinOrganization
            $changes += "  • Email verified users can join: $($currentPolicy.AllowEmailVerifiedUsersToJoinOrganization) → $($config.AuthorizationPolicy.AllowEmailVerifiedUsersToJoinOrganization)"
            $stats.AuthPolicyAttempted++
        }
        
        # Check DefaultUserRolePermissions
        $userRoleChanges = @()
        $userRoleParams = @{}
        
        if ($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateApps -ne $currentPolicy.DefaultUserRolePermissions.AllowedToCreateApps) {
            $userRoleParams['AllowedToCreateApps'] = $config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateApps
            $userRoleChanges += "    - Create apps: $($currentPolicy.DefaultUserRolePermissions.AllowedToCreateApps) → $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateApps)"
        }
        
        if ($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups -ne $currentPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups) {
            $userRoleParams['AllowedToCreateSecurityGroups'] = $config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups
            $userRoleChanges += "    - Create security groups: $($currentPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups) → $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups)"
        }
        
        if ($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateTenants -ne $currentPolicy.DefaultUserRolePermissions.AllowedToCreateTenants) {
            $userRoleParams['AllowedToCreateTenants'] = $config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateTenants
            $userRoleChanges += "    - Create tenants: $($currentPolicy.DefaultUserRolePermissions.AllowedToCreateTenants) → $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToCreateTenants)"
        }
        
        if ($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice -ne $currentPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice) {
            $userRoleParams['AllowedToReadBitlockerKeysForOwnedDevice'] = $config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice
            $userRoleChanges += "    - Read Bitlocker keys: $($currentPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice) → $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice)"
        }
        
        if ($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers -ne $currentPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers) {
            $userRoleParams['AllowedToReadOtherUsers'] = $config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers
            $userRoleChanges += "    - Read other users: $($currentPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers) → $($config.AuthorizationPolicy.DefaultUserRolePermissions.AllowedToReadOtherUsers)"
        }
        
        if ($userRoleParams.Count -gt 0) {
            $updateParams['DefaultUserRolePermissions'] = $userRoleParams
            $changes += "  • Default user role permissions:"
            $changes += $userRoleChanges
            $stats.AuthPolicyAttempted++
        }
        
        # Apply changes
        if ($changes.Count -gt 0) {
            Write-Host "`nChanges to be applied:" -ForegroundColor White
            $changes | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
            Write-Host ""
            
            if ($DryRun) {
                Write-Host "[DRY RUN] Would apply authorization policy changes" -ForegroundColor Yellow
                $stats.AuthPolicySuccess = $stats.AuthPolicyAttempted
            } else {
                Write-Host "Applying authorization policy changes..." -ForegroundColor Yellow
                Update-MgPolicyAuthorizationPolicy -BodyParameter $updateParams
                Write-Host "✓ Authorization policy updated successfully" -ForegroundColor Green
                $stats.AuthPolicySuccess = $stats.AuthPolicyAttempted
            }
        } else {
            Write-Host "✓ Authorization policy already matches configuration (no changes needed)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "✗ Failed to apply authorization policy: $_" -ForegroundColor Red
        $stats.AuthPolicyFailed = $stats.AuthPolicyAttempted - $stats.AuthPolicySuccess
    }
}

#endregion

#region Apply Self-Service Purchase Policies

if (-not $SkipSelfServicePurchase -and $config.SelfServicePurchasePolicies) {
    Write-Host "`n=== Applying Self-Service Purchase Policies ===" -ForegroundColor Cyan
    
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
            $currentPolicies = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase -ErrorAction Stop
        }
        catch {
            # If not connected, connect now
            Connect-MSCommerce
            $currentPolicies = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase
        }
        Write-Host "✓ Connected to MSCommerce" -ForegroundColor Green
        
        Write-Host "`nAnalyzing self-service purchase policy differences..." -ForegroundColor Yellow
        
        $productChanges = @()
        
        foreach ($configProduct in $config.SelfServicePurchasePolicies) {
            $currentProduct = $currentPolicies | Where-Object { $_.ProductId -eq $configProduct.ProductId }
            
            if ($currentProduct) {
                if ($currentProduct.PolicyValue -ne $configProduct.PolicyValue) {
                    $stats.SelfServiceAttempted++
                    $productChanges += @{
                        ProductId = $configProduct.ProductId
                        ProductName = $configProduct.ProductName
                        CurrentValue = $currentProduct.PolicyValue
                        TargetValue = $configProduct.PolicyValue
                    }
                }
            } else {
                Write-Host "  ⚠️ Product not found in current tenant: $($configProduct.ProductName)" -ForegroundColor Yellow
            }
        }
        
        if ($productChanges.Count -gt 0) {
            Write-Host "`nProducts to be updated ($($productChanges.Count)):" -ForegroundColor White
            foreach ($change in $productChanges) {
                Write-Host "  • $($change.ProductName): $($change.CurrentValue) → $($change.TargetValue)" -ForegroundColor Gray
            }
            Write-Host ""
            
            if ($DryRun) {
                Write-Host "[DRY RUN] Would update $($productChanges.Count) product policies" -ForegroundColor Yellow
                $stats.SelfServiceSuccess = $stats.SelfServiceAttempted
            } else {
                Write-Host "Applying self-service purchase policy changes..." -ForegroundColor Yellow
                
                foreach ($change in $productChanges) {
                    try {
                        $enabled = $change.TargetValue -eq "Enabled"
                        Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
                            -ProductId $change.ProductId -Enabled $enabled
                        Write-Host "  ✓ Updated: $($change.ProductName)" -ForegroundColor Green
                        $stats.SelfServiceSuccess++
                    }
                    catch {
                        Write-Host "  ✗ Failed: $($change.ProductName) - $_" -ForegroundColor Red
                        $stats.SelfServiceFailed++
                    }
                }
                
                Write-Host "`n✓ Self-service purchase policies updated" -ForegroundColor Green
            }
        } else {
            Write-Host "✓ Self-service purchase policies already match configuration (no changes needed)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "✗ Failed to apply self-service purchase policies: $_" -ForegroundColor Red
        $stats.SelfServiceFailed = $stats.SelfServiceAttempted - $stats.SelfServiceSuccess
    }
}

#endregion

#region Summary

Write-Host "`n=== Import Summary ===" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipAuthorizationPolicy) {
    Write-Host "Authorization Policy:" -ForegroundColor White
    Write-Host "  Settings Attempted: $($stats.AuthPolicyAttempted)"
    if ($stats.AuthPolicySuccess -gt 0) {
        Write-Host "  Succeeded: $($stats.AuthPolicySuccess)" -ForegroundColor Green
    }
    if ($stats.AuthPolicyFailed -gt 0) {
        Write-Host "  Failed: $($stats.AuthPolicyFailed)" -ForegroundColor Red
    }
    if ($stats.AuthPolicyAttempted -eq 0) {
        Write-Host "  No changes needed (already configured)" -ForegroundColor Gray
    }
}

if (-not $SkipSelfServicePurchase) {
    Write-Host "`nSelf-Service Purchase Policies:" -ForegroundColor White
    Write-Host "  Products Attempted: $($stats.SelfServiceAttempted)"
    if ($stats.SelfServiceSuccess -gt 0) {
        Write-Host "  Succeeded: $($stats.SelfServiceSuccess)" -ForegroundColor Green
    }
    if ($stats.SelfServiceFailed -gt 0) {
        Write-Host "  Failed: $($stats.SelfServiceFailed)" -ForegroundColor Red
    }
    if ($stats.SelfServiceAttempted -eq 0) {
        Write-Host "  No changes needed (already configured)" -ForegroundColor Gray
    }
}

Write-Host ""

$totalAttempted = $stats.AuthPolicyAttempted + $stats.SelfServiceAttempted
$totalSuccess = $stats.AuthPolicySuccess + $stats.SelfServiceSuccess
$totalFailed = $stats.AuthPolicyFailed + $stats.SelfServiceFailed

if ($DryRun) {
    Write-Host "✓ Dry run completed successfully!" -ForegroundColor Green
    Write-Host "  $totalAttempted change(s) would be applied" -ForegroundColor Yellow
    Write-Host "  Run without -DryRun to apply changes`n" -ForegroundColor Yellow
} elseif ($totalFailed -eq 0 -and $totalAttempted -gt 0) {
    Write-Host "✅ Import completed successfully!" -ForegroundColor Green
    Write-Host "  $totalSuccess change(s) applied`n" -ForegroundColor Green
} elseif ($totalAttempted -eq 0) {
    Write-Host "✅ Configuration already matches - no changes needed!`n" -ForegroundColor Green
} else {
    Write-Host "⚠️ Import completed with errors" -ForegroundColor Yellow
    Write-Host "  Succeeded: $totalSuccess" -ForegroundColor Green
    Write-Host "  Failed: $totalFailed`n" -ForegroundColor Red
}

#endregion
