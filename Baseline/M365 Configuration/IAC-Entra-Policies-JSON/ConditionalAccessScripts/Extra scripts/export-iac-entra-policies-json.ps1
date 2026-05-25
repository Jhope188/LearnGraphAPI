<#
.SYNOPSIS
    Exports IAC Conditional Access policies and Named Locations to JSON files.

.DESCRIPTION
    This script exports all Conditional Access policies and Named Locations that start with "IAC"
    to individual JSON files in an organized folder structure. Perfect for backup, documentation,
    and tenant migration scenarios.

.PARAMETER ExportPath
    Path where JSON files will be exported. Defaults to /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON

.EXAMPLE
    .\export-iac-entra-policies-json.ps1
    Exports all IAC Entra policies to the default location

.EXAMPLE
    .\export-iac-entra-policies-json.ps1 -ExportPath "C:\Backup\Entra"
    Exports to a custom location

.NOTES
    Author: GitHub Copilot
    Date: 2026-01-16
    Requires: Microsoft.Graph PowerShell Module
    Permissions: Policy.Read.All, Application.Read.All
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ExportPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON"
)

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.SignIns

# Helper function to clean properties for export
function Remove-ReadOnlyProperties {
    param($Object)
    
    $cleanObject = $Object | Select-Object * -ExcludeProperty `
        '@odata.context', '@odata.type', 'id', 'createdDateTime', 'modifiedDateTime'
    
    return $cleanObject
}

# Helper function to get group/user/role display names
function Get-AssignmentDetails {
    param($Conditions)
    
    $details = @{
        IncludeUsers = @()
        ExcludeUsers = @()
        IncludeGroups = @()
        ExcludeGroups = @()
        IncludeRoles = @()
        ExcludeRoles = @()
    }
    
    if ($Conditions.users) {
        # Users
        if ($Conditions.users.includeUsers) {
            foreach ($userId in $Conditions.users.includeUsers) {
                if ($userId -eq 'All' -or $userId -eq 'GuestsOrExternalUsers' -or $userId -eq 'None') {
                    $details.IncludeUsers += @{ Id = $userId; DisplayName = $userId }
                } else {
                    try {
                        $user = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$userId" -ErrorAction SilentlyContinue
                        $details.IncludeUsers += @{ Id = $userId; DisplayName = $user.displayName; UPN = $user.userPrincipalName }
                    } catch {
                        $details.IncludeUsers += @{ Id = $userId; DisplayName = "Unknown" }
                    }
                }
            }
        }
        
        if ($Conditions.users.excludeUsers) {
            foreach ($userId in $Conditions.users.excludeUsers) {
                if ($userId -eq 'All' -or $userId -eq 'GuestsOrExternalUsers' -or $userId -eq 'None') {
                    $details.ExcludeUsers += @{ Id = $userId; DisplayName = $userId }
                } else {
                    try {
                        $user = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$userId" -ErrorAction SilentlyContinue
                        $details.ExcludeUsers += @{ Id = $userId; DisplayName = $user.displayName; UPN = $user.userPrincipalName }
                    } catch {
                        $details.ExcludeUsers += @{ Id = $userId; DisplayName = "Unknown" }
                    }
                }
            }
        }
        
        # Groups
        if ($Conditions.users.includeGroups) {
            foreach ($groupId in $Conditions.users.includeGroups) {
                try {
                    $group = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$groupId" -ErrorAction SilentlyContinue
                    $details.IncludeGroups += @{ Id = $groupId; DisplayName = $group.displayName }
                } catch {
                    $details.IncludeGroups += @{ Id = $groupId; DisplayName = "Unknown" }
                }
            }
        }
        
        if ($Conditions.users.excludeGroups) {
            foreach ($groupId in $Conditions.users.excludeGroups) {
                try {
                    $group = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$groupId" -ErrorAction SilentlyContinue
                    $details.ExcludeGroups += @{ Id = $groupId; DisplayName = $group.displayName }
                } catch {
                    $details.ExcludeGroups += @{ Id = $groupId; DisplayName = "Unknown" }
                }
            }
        }
        
        # Roles
        if ($Conditions.users.includeRoles) {
            foreach ($roleId in $Conditions.users.includeRoles) {
                try {
                    $role = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryRoles/$roleId" -ErrorAction SilentlyContinue
                    $details.IncludeRoles += @{ Id = $roleId; DisplayName = $role.displayName }
                } catch {
                    $details.IncludeRoles += @{ Id = $roleId; DisplayName = "Unknown" }
                }
            }
        }
        
        if ($Conditions.users.excludeRoles) {
            foreach ($roleId in $Conditions.users.excludeRoles) {
                try {
                    $role = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/directoryRoles/$roleId" -ErrorAction SilentlyContinue
                    $details.ExcludeRoles += @{ Id = $roleId; DisplayName = $role.displayName }
                } catch {
                    $details.ExcludeRoles += @{ Id = $roleId; DisplayName = "Unknown" }
                }
            }
        }
    }
    
    return $details
}

# Main execution
try {
    Write-Host "`n=== IAC Entra Policy Export ===" -ForegroundColor Cyan
    Write-Host "Export Path: $ExportPath`n" -ForegroundColor Gray
    
    # Verify Graph connection
    $context = Get-MgContext
    if (-not $context) {
        Write-Host "❌ Not connected to Microsoft Graph. Please run Connect-MgGraph first." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
    Write-Host "   Account: $($context.Account)`n" -ForegroundColor Gray
    
    # Create export directory structure
    $exportFolders = @{
        Root = $ExportPath
        ConditionalAccess = Join-Path $ExportPath "ConditionalAccess"
        NamedLocations = Join-Path $ExportPath "NamedLocations"
    }
    
    foreach ($folder in $exportFolders.Values) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
            Write-Host "📁 Created folder: $folder" -ForegroundColor Gray
        }
    }
    
    # Initialize summary
    $summary = @{
        ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        TenantId = $context.TenantId
        ExportedBy = $context.Account
        ConditionalAccessPolicies = @()
        NamedLocations = @()
        TotalPolicies = 0
        TotalLocations = 0
    }
    
    # ===== Export Conditional Access Policies =====
    Write-Host "`n--- Exporting Conditional Access Policies ---" -ForegroundColor Cyan
    
    try {
        $allCAPolicies = @()
        $caUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
        
        do {
            $caResponse = Invoke-MgGraphRequest -Method GET -Uri $caUri
            $allCAPolicies += $caResponse.value
            $caUri = $caResponse.'@odata.nextLink'
        } while ($caUri)
        
        $iacCAPolicies = $allCAPolicies | Where-Object { $_.displayName -like "IAC*" }
        
        Write-Host "Found $($iacCAPolicies.Count) IAC Conditional Access policies" -ForegroundColor Yellow
        
        foreach ($policy in $iacCAPolicies) {
            try {
                Write-Host "  📄 Exporting: $($policy.displayName)" -ForegroundColor White
                
                # Get assignment details
                $assignmentDetails = Get-AssignmentDetails -Conditions $policy.conditions
                
                # Build export object
                $exportData = @{
                    SourcePolicyId = $policy.id
                    PolicyConfig = Remove-ReadOnlyProperties -Object $policy
                    AssignmentDetails = $assignmentDetails
                    ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    SourceTenantId = $context.TenantId
                }
                
                # Save to JSON file
                $fileName = "$($policy.displayName).json" -replace '[\\/:*?"<>|]', '_'
                $filePath = Join-Path $exportFolders.ConditionalAccess $fileName
                $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding utf8
                
                # Add to summary
                $summary.ConditionalAccessPolicies += @{
                    Name = $policy.displayName
                    Id = $policy.id
                    State = $policy.state
                    FileName = $fileName
                }
                
                Write-Host "     ✅ Saved to: $fileName" -ForegroundColor Green
                
            } catch {
                Write-Host "     ❌ Failed to export: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        $summary.TotalPolicies = $iacCAPolicies.Count
        
    } catch {
        Write-Host "❌ Error exporting Conditional Access policies: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # ===== Export Named Locations =====
    Write-Host "`n--- Exporting Named Locations ---" -ForegroundColor Cyan
    
    try {
        $allLocations = @()
        $locUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations"
        
        do {
            $locResponse = Invoke-MgGraphRequest -Method GET -Uri $locUri
            $allLocations += $locResponse.value
            $locUri = $locResponse.'@odata.nextLink'
        } while ($locUri)
        
        $iacLocations = $allLocations | Where-Object { $_.displayName -like "IAC*" }
        
        Write-Host "Found $($iacLocations.Count) IAC Named Locations" -ForegroundColor Yellow
        
        foreach ($location in $iacLocations) {
            try {
                Write-Host "  📍 Exporting: $($location.displayName)" -ForegroundColor White
                
                # Determine location type
                $locationType = if ($location.'@odata.type' -eq '#microsoft.graph.ipNamedLocation') {
                    "IP Location"
                } elseif ($location.'@odata.type' -eq '#microsoft.graph.countryNamedLocation') {
                    "Country Location"
                } else {
                    "Unknown"
                }
                
                # Build export object
                $exportData = @{
                    SourceLocationId = $location.id
                    LocationType = $locationType
                    ODataType = $location.'@odata.type'
                    LocationConfig = Remove-ReadOnlyProperties -Object $location
                    ExportDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    SourceTenantId = $context.TenantId
                }
                
                # Save to JSON file
                $fileName = "$($location.displayName).json" -replace '[\\/:*?"<>|]', '_'
                $filePath = Join-Path $exportFolders.NamedLocations $fileName
                $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding utf8
                
                # Add to summary
                $summary.NamedLocations += @{
                    Name = $location.displayName
                    Id = $location.id
                    Type = $locationType
                    IsTrusted = $location.isTrusted
                    FileName = $fileName
                }
                
                Write-Host "     ✅ Saved to: $fileName" -ForegroundColor Green
                
            } catch {
                Write-Host "     ❌ Failed to export: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        $summary.TotalLocations = $iacLocations.Count
        
    } catch {
        Write-Host "❌ Error exporting Named Locations: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Save summary index
    Write-Host "`n--- Saving Export Summary ---" -ForegroundColor Cyan
    $indexPath = Join-Path $ExportPath "index.json"
    $summary | ConvertTo-Json -Depth 10 | Out-File -FilePath $indexPath -Encoding utf8
    Write-Host "✅ Summary saved to: index.json`n" -ForegroundColor Green
    
    # Final summary
    Write-Host "`n=== Export Complete ===" -ForegroundColor Cyan
    Write-Host "📊 Summary:" -ForegroundColor White
    Write-Host "   Conditional Access Policies: $($summary.TotalPolicies)" -ForegroundColor Yellow
    Write-Host "   Named Locations: $($summary.TotalLocations)" -ForegroundColor Yellow
    Write-Host "   Export Location: $ExportPath" -ForegroundColor Gray
    Write-Host "`n✅ All IAC Entra policies exported successfully!`n" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Export failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
