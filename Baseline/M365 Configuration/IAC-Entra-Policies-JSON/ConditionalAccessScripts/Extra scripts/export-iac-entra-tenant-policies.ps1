<#
.SYNOPSIS
    Exports IAC Entra tenant-level policies to JSON files.

.DESCRIPTION
    This script exports tenant-level policies including Authorization Policy and
    Authentication Methods Policy for IAC backup and disaster recovery purposes.
    Exported JSON files can be restored using recreate-iac-entra-policies.ps1

.PARAMETER ExportPath
    Path to export JSON files to. Default is TenantPolicies subfolder.
    Default: /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/TenantPolicies

.EXAMPLE
    .\export-iac-entra-tenant-policies.ps1
    Export all tenant policies to default location

.EXAMPLE
    .\export-iac-entra-tenant-policies.ps1 -ExportPath "C:\Backup\TenantPolicies"
    Export to custom path

.NOTES
    Author: GitHub Copilot
    Date: 2026-01-25
    Requires: Microsoft.Graph PowerShell Module
    Permissions: Policy.Read.All, Policy.ReadWrite.Authorization, Policy.ReadWrite.AuthenticationMethod
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/TenantPolicies"
)

#Requires -Modules Microsoft.Graph.Authentication

# Main execution
try {
    Write-Host "`n=== IAC Entra Tenant Policy Export ===" -ForegroundColor Cyan
    Write-Host "Export Path: $ExportPath`n" -ForegroundColor Gray
    
    # Verify Graph connection
    $context = Get-MgContext
    if (-not $context) {
        Write-Host "❌ Not connected to Microsoft Graph. Please run Connect-MgGraph first." -ForegroundColor Red
        Write-Host "   Required scopes: Policy.Read.All (or Policy.ReadWrite.Authorization, Policy.ReadWrite.AuthenticationMethod)" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "✅ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
    Write-Host "   Account: $($context.Account)`n" -ForegroundColor Gray
    
    # Create export directory if it doesn't exist
    if (-not (Test-Path $ExportPath)) {
        Write-Host "📁 Creating export directory: $ExportPath" -ForegroundColor Yellow
        New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
    }
    
    # Initialize results tracking
    $results = @{
        ExportedPolicies = @()
        FailedPolicies = @()
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        SourceTenantId = $context.TenantId
        ExportPath = $ExportPath
    }
    
    # ===== Export Authorization Policy =====
    Write-Host "--- Exporting Authorization Policy ---" -ForegroundColor Cyan
    try {
        Write-Host "  🔍 Querying Authorization Policy..." -ForegroundColor White
        
        $authzPolicy = Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy"
        
        $authzExport = @{
            PolicyType = "AuthorizationPolicy"
            ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            SourceTenantId = $context.TenantId
            PolicyId = $authzPolicy.id
            PolicyConfig = $authzPolicy
            Notes = @{
                Description = "Tenant authorization policy controlling default user permissions, guest access, and PowerShell access"
                CriticalSettings = @(
                    "blockMsolPowerShell - Blocks legacy MSOL PowerShell module"
                    "allowedToSignUpEmailBasedSubscriptions - Email-based subscription signups"
                    "allowEmailVerifiedUsersToJoinOrganization - Email-verified user join"
                    "defaultUserRolePermissions - Default permissions for users"
                )
            }
        }
        
        $exportFile = Join-Path $ExportPath "AuthorizationPolicy.json"
        $authzExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportFile -Encoding utf8
        
        Write-Host "  ✅ Exported Authorization Policy" -ForegroundColor Green
        Write-Host "     blockMsolPowerShell: $($authzPolicy.blockMsolPowerShell)" -ForegroundColor Gray
        Write-Host "     allowedToSignUpEmailBasedSubscriptions: $($authzPolicy.allowedToSignUpEmailBasedSubscriptions)" -ForegroundColor Gray
        Write-Host "     File: $exportFile" -ForegroundColor Gray
        
        $results.ExportedPolicies += @{
            PolicyType = "AuthorizationPolicy"
            Id = $authzPolicy.id
            FilePath = $exportFile
            KeySettings = @{
                blockMsolPowerShell = $authzPolicy.blockMsolPowerShell
                allowedToSignUpEmailBasedSubscriptions = $authzPolicy.allowedToSignUpEmailBasedSubscriptions
            }
        }
        
    } catch {
        Write-Host "  ❌ Failed to export Authorization Policy: $($_.Exception.Message)" -ForegroundColor Red
        $results.FailedPolicies += @{
            PolicyType = "AuthorizationPolicy"
            Error = $_.Exception.Message
        }
    }
    
    # ===== Export Authentication Methods Policy =====
    Write-Host "`n--- Exporting Authentication Methods Policy ---" -ForegroundColor Cyan
    try {
        Write-Host "  🔍 Querying Authentication Methods Policy..." -ForegroundColor White
        
        $authMethodsPolicy = Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy"
        
        $authMethodsExport = @{
            PolicyType = "AuthenticationMethodsPolicy"
            ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            SourceTenantId = $context.TenantId
            PolicyId = $authMethodsPolicy.id
            PolicyConfig = $authMethodsPolicy
            Notes = @{
                Description = "Authentication methods policy controlling MFA methods, registration campaign, and authentication requirements"
                CriticalSettings = @(
                    "registrationEnforcement.authenticationMethodsRegistrationCampaign - MFA registration nudges"
                    "authenticationMethodConfigurations - Enabled/disabled auth methods"
                    "policyVersion - Policy configuration version"
                )
            }
        }
        
        $exportFile = Join-Path $ExportPath "AuthenticationMethodsPolicy.json"
        $authMethodsExport | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportFile -Encoding utf8
        
        Write-Host "  ✅ Exported Authentication Methods Policy" -ForegroundColor Green
        
        if ($authMethodsPolicy.registrationEnforcement.authenticationMethodsRegistrationCampaign) {
            $regCampaign = $authMethodsPolicy.registrationEnforcement.authenticationMethodsRegistrationCampaign
            Write-Host "     Registration Campaign State: $($regCampaign.state)" -ForegroundColor Gray
        }
        
        Write-Host "     File: $exportFile" -ForegroundColor Gray
        
        $results.ExportedPolicies += @{
            PolicyType = "AuthenticationMethodsPolicy"
            Id = $authMethodsPolicy.id
            FilePath = $exportFile
            KeySettings = @{
                registrationCampaignState = $authMethodsPolicy.registrationEnforcement.authenticationMethodsRegistrationCampaign.state
            }
        }
        
    } catch {
        Write-Host "  ❌ Failed to export Authentication Methods Policy: $($_.Exception.Message)" -ForegroundColor Red
        $results.FailedPolicies += @{
            PolicyType = "AuthenticationMethodsPolicy"
            Error = $_.Exception.Message
        }
    }
    
    # Save results summary
    Write-Host "`n--- Saving Export Summary ---" -ForegroundColor Cyan
    $summaryPath = Join-Path $ExportPath "export-summary.json"
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryPath -Encoding utf8
    Write-Host "✅ Summary saved to: $summaryPath" -ForegroundColor Green
    
    # Final summary
    Write-Host "`n=== Export Complete ===" -ForegroundColor Cyan
    Write-Host "📊 Summary:" -ForegroundColor White
    Write-Host "   Policies Exported: $($results.ExportedPolicies.Count)" -ForegroundColor Green
    Write-Host "   Policies Failed: $($results.FailedPolicies.Count)" -ForegroundColor $(if ($results.FailedPolicies.Count -gt 0) { 'Red' } else { 'Gray' })
    
    if ($results.FailedPolicies.Count -gt 0) {
        Write-Host "`n⚠️  Some policies failed to export. Check the summary file for details." -ForegroundColor Yellow
    } else {
        Write-Host "`n✅ All tenant policies exported successfully!" -ForegroundColor Green
    }
    
    Write-Host "`n💡 Next Steps:" -ForegroundColor Cyan
    Write-Host "   1. Review exported JSON files in: $ExportPath" -ForegroundColor Gray
    Write-Host "   2. Use recreate-iac-entra-policies.ps1 to restore these policies to another tenant`n" -ForegroundColor Gray
    
} catch {
    Write-Host "`n❌ Export failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
