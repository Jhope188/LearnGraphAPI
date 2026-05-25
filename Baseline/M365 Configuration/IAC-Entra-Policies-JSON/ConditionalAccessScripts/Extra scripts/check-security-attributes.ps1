<#
.SYNOPSIS
    Checks for Custom Security Attributes in the tenant.

.DESCRIPTION
    Queries the tenant for Custom Security Attribute Sets and their definitions.
    Requires CustomSecAttributeDefinition.Read.All permission.
#>

#Requires -Modules Microsoft.Graph.Authentication

try {
    # Check current connection
    $context = Get-MgContext
    if (-not $context) {
        Write-Host "❌ Not connected to Microsoft Graph. Please run Connect-MgGraph first." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Current tenant: $($context.TenantId)" -ForegroundColor Gray
    Write-Host "Current scopes: $($context.Scopes -join ', ')" -ForegroundColor Gray
    Write-Host ""
    
    # Try to query security attributes
    Write-Host "=== Checking for Custom Security Attributes ===" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Check attribute sets
        $attributeSets = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/attributeSets"
        
        Write-Host "✅ Found $($attributeSets.value.Count) attribute set(s)" -ForegroundColor Green
        
        if ($attributeSets.value.Count -gt 0) {
            foreach ($set in $attributeSets.value) {
                Write-Host ""
                Write-Host "📦 Attribute Set: $($set.id)" -ForegroundColor Cyan
                Write-Host "   Description: $($set.description)" -ForegroundColor Gray
                Write-Host "   Max Attributes: $($set.maxAttributesPerSet)" -ForegroundColor Gray
                
                # Get definitions in this set
                $definitions = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions?`$filter=attributeSet eq '$($set.id)'"
                Write-Host "   Attributes: $($definitions.value.Count)" -ForegroundColor Gray
                
                if ($definitions.value.Count -gt 0) {
                    foreach ($def in $definitions.value) {
                        Write-Host "      - $($def.name) ($($def.type)) - Status: $($def.status)" -ForegroundColor White
                        if ($def.description) {
                            Write-Host "        Description: $($def.description)" -ForegroundColor DarkGray
                        }
                        if ($def.usePreDefinedValuesOnly) {
                            Write-Host "        Uses predefined values: $($def.usePreDefinedValuesOnly)" -ForegroundColor DarkGray
                        }
                    }
                }
            }
            
            Write-Host ""
            Write-Host "✅ Security attributes are configured in this tenant" -ForegroundColor Green
            Write-Host "   Ready to export!" -ForegroundColor Green
            
        } else {
            Write-Host ""
            Write-Host "⚠️  No custom security attributes found in tenant" -ForegroundColor Yellow
            Write-Host "   This is normal if security attributes haven't been configured yet." -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "❌ Error querying security attributes: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        
        if ($_.Exception.Message -like "*Forbidden*" -or $_.Exception.Message -like "*Insufficient privileges*") {
            Write-Host "This is likely due to missing permissions." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Required permission: CustomSecAttributeDefinition.Read.All" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "To add this permission, run:" -ForegroundColor White
            Write-Host "  Connect-MgGraph -Scopes 'CustomSecAttributeDefinition.Read.All'" -ForegroundColor Gray
        } else {
            Write-Host "Possible reasons:" -ForegroundColor Yellow
            Write-Host "  1. Missing permissions (CustomSecAttributeDefinition.Read.All required)" -ForegroundColor Gray
            Write-Host "  2. Security attributes feature not available in this tenant/license" -ForegroundColor Gray
            Write-Host "  3. Network or API issue" -ForegroundColor Gray
        }
    }
    
} catch {
    Write-Host "❌ Script error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
