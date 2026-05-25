<#
.SYNOPSIS
    Exports Custom Security Attributes from Entra ID to JSON files.

.DESCRIPTION
    This script exports Custom Security Attribute Sets and their definitions
    for Infrastructure as Code (IAC) backup and disaster recovery.
    
    Exports include:
    - Attribute Sets (containers for attributes)
    - Attribute Definitions (individual attributes with their configurations)
    - Allowed Values (for attributes with predefined values)

.PARAMETER OutputPath
    Path where JSON exports will be saved.
    Default: /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/SecurityAttributes

.EXAMPLE
    .\export-iac-entra-security-attributes.ps1
    Export all security attributes to default location

.NOTES
    Author: GitHub Copilot
    Date: 2026-01-25
    Requires: Microsoft.Graph PowerShell Module
    Permissions: CustomSecAttributeDefinition.Read.All
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/SecurityAttributes"
)

#Requires -Modules Microsoft.Graph.Authentication

# Verify Graph connection
$context = Get-MgContext
if (-not $context) {
    Write-Host "❌ Not connected to Microsoft Graph. Please run Connect-MgGraph first." -ForegroundColor Red
    Write-Host "   Required scope: CustomSecAttributeDefinition.Read.All" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n=== Exporting Custom Security Attributes ===" -ForegroundColor Cyan
Write-Host "Source Tenant: $($context.TenantId)" -ForegroundColor Gray
Write-Host "Output Path: $OutputPath`n" -ForegroundColor Gray

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "✅ Created output directory: $OutputPath" -ForegroundColor Green
}

# Initialize results tracking
$results = @{
    ExportedAttributeSets = @()
    ExportedAttributes = @()
    FailedItems = @()
    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    SourceTenantId = $context.TenantId
}

try {
    # Get all attribute sets
    Write-Host "--- Fetching Attribute Sets ---" -ForegroundColor Cyan
    $attributeSets = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/attributeSets"
    
    Write-Host "Found $($attributeSets.value.Count) attribute set(s)`n" -ForegroundColor Yellow
    
    foreach ($set in $attributeSets.value) {
        try {
            Write-Host "  📦 Processing: $($set.id)" -ForegroundColor White
            
            # Get all attribute definitions for this set
            $definitions = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions?`$filter=attributeSet eq '$($set.id)'"
            
            # For each attribute definition, get allowed values if applicable
            $enrichedDefinitions = @()
            foreach ($def in $definitions.value) {
                $enrichedDef = $def | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                
                # If attribute uses predefined values, get them
                if ($def.usePreDefinedValuesOnly -eq $true) {
                    try {
                        $allowedValues = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directory/customSecurityAttributeDefinitions/$($def.id)/allowedValues"
                        $enrichedDef | Add-Member -MemberType NoteProperty -Name 'allowedValues' -Value $allowedValues.value -Force
                        Write-Host "     - $($def.name) (with $($allowedValues.value.Count) allowed values)" -ForegroundColor Gray
                    } catch {
                        Write-Host "     ⚠️  Could not fetch allowed values for $($def.name)" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "     - $($def.name) (free-form values)" -ForegroundColor Gray
                }
                
                $enrichedDefinitions += $enrichedDef
            }
            
            # Create export object
            $exportData = @{
                ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                SourceTenantId = $context.TenantId
                AttributeSetId = $set.id
                AttributeSetConfig = $set
                AttributeDefinitions = $enrichedDefinitions
                Notes = @{
                    Description = "Custom Security Attribute Set export for IAC"
                    AttributeCount = $enrichedDefinitions.Count
                    ExportedBy = $context.Account
                }
            }
            
            # Save to JSON file
            $fileName = "$($set.id).json"
            $filePath = Join-Path $OutputPath $fileName
            
            $exportData | ConvertTo-Json -Depth 20 | Out-File -FilePath $filePath -Encoding utf8
            
            Write-Host "     ✅ Exported: $fileName" -ForegroundColor Green
            Write-Host "        Attributes: $($enrichedDefinitions.Count)" -ForegroundColor Gray
            
            $results.ExportedAttributeSets += @{
                AttributeSetId = $set.id
                AttributeCount = $enrichedDefinitions.Count
                FilePath = $filePath
            }
            
            foreach ($def in $enrichedDefinitions) {
                $results.ExportedAttributes += @{
                    AttributeSetId = $set.id
                    AttributeName = $def.name
                    Type = $def.type
                    Status = $def.status
                    UsesPredefinedValues = $def.usePreDefinedValuesOnly
                }
            }
            
        } catch {
            Write-Host "     ❌ Failed to export attribute set: $($_.Exception.Message)" -ForegroundColor Red
            $results.FailedItems += @{
                ItemType = "AttributeSet"
                ItemId = $set.id
                Error = $_.Exception.Message
            }
        }
        
        Write-Host ""
    }
    
    # Save summary
    Write-Host "--- Saving Export Summary ---" -ForegroundColor Cyan
    $summaryPath = Join-Path $OutputPath "export-summary.json"
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryPath -Encoding utf8
    Write-Host "✅ Summary saved: $summaryPath`n" -ForegroundColor Green
    
    # Final summary
    Write-Host "=== Export Complete ===" -ForegroundColor Cyan
    Write-Host "📊 Summary:" -ForegroundColor White
    Write-Host "   Attribute Sets Exported: $($results.ExportedAttributeSets.Count)" -ForegroundColor Green
    Write-Host "   Total Attributes: $($results.ExportedAttributes.Count)" -ForegroundColor Green
    Write-Host "   Failed Items: $($results.FailedItems.Count)" -ForegroundColor $(if ($results.FailedItems.Count -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "   Output Location: $OutputPath`n" -ForegroundColor Gray
    
    if ($results.ExportedAttributeSets.Count -gt 0) {
        Write-Host "✅ Custom Security Attributes exported successfully!" -ForegroundColor Green
        Write-Host "   Ready for IAC backup and disaster recovery.`n" -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Export failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
