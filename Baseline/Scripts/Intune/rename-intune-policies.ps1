# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   RENAME INTUNE POLICIES: NCT → IAC" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$policiesToRename = @()

# Get Device Configuration Policies (OMA-URI, Templates, etc.)
Write-Host "🔍 Step 1: Retrieving Device Configuration Policies...`n" -ForegroundColor Yellow

try {
    $deviceConfigs = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations").value
    
    $nctDeviceConfigs = $deviceConfigs | Where-Object { $_.displayName -like "NCT*" }
    
    if ($nctDeviceConfigs.Count -gt 0) {
        Write-Host "Found $($nctDeviceConfigs.Count) Device Configuration policy/policies:" -ForegroundColor White
        foreach ($policy in $nctDeviceConfigs) {
            $newName = $policy.displayName -replace "^NCT", "IAC"
            $policiesToRename += @{
                Type = "DeviceConfiguration"
                Policy = $policy
                NewName = $newName
            }
            Write-Host "  • $($policy.displayName)" -ForegroundColor Cyan
            Write-Host "    → $newName" -ForegroundColor Green
        }
        Write-Host ""
    } else {
        Write-Host "No Device Configuration policies found starting with 'NCT'`n" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "⚠️  Error retrieving Device Configuration policies: $($_.Exception.Message)`n" -ForegroundColor Yellow
}

# Get Settings Catalog Policies
Write-Host "🔍 Step 2: Retrieving Settings Catalog Policies...`n" -ForegroundColor Yellow

try {
    $settingsCatalog = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies").value
    
    $nctSettingsCatalog = $settingsCatalog | Where-Object { $_.name -like "NCT*" }
    
    if ($nctSettingsCatalog.Count -gt 0) {
        Write-Host "Found $($nctSettingsCatalog.Count) Settings Catalog policy/policies:" -ForegroundColor White
        foreach ($policy in $nctSettingsCatalog) {
            $newName = $policy.name -replace "^NCT", "IAC"
            $policiesToRename += @{
                Type = "SettingsCatalog"
                Policy = $policy
                NewName = $newName
            }
            Write-Host "  • $($policy.name)" -ForegroundColor Cyan
            Write-Host "    → $newName" -ForegroundColor Green
        }
        Write-Host ""
    } else {
        Write-Host "No Settings Catalog policies found starting with 'NCT'`n" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "⚠️  Error retrieving Settings Catalog policies: $($_.Exception.Message)`n" -ForegroundColor Yellow
}

# Get Compliance Policies
Write-Host "🔍 Step 3: Retrieving Compliance Policies...`n" -ForegroundColor Yellow

try {
    $compliancePolicies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies").value
    
    $nctCompliancePolicies = $compliancePolicies | Where-Object { $_.displayName -like "NCT*" }
    
    if ($nctCompliancePolicies.Count -gt 0) {
        Write-Host "Found $($nctCompliancePolicies.Count) Compliance policy/policies:" -ForegroundColor White
        foreach ($policy in $nctCompliancePolicies) {
            $newName = $policy.displayName -replace "^NCT", "IAC"
            $policiesToRename += @{
                Type = "Compliance"
                Policy = $policy
                NewName = $newName
            }
            Write-Host "  • $($policy.displayName)" -ForegroundColor Cyan
            Write-Host "    → $newName" -ForegroundColor Green
        }
        Write-Host ""
    } else {
        Write-Host "No Compliance policies found starting with 'NCT'`n" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "⚠️  Error retrieving Compliance policies: $($_.Exception.Message)`n" -ForegroundColor Yellow
}

# Check if any policies found
if ($policiesToRename.Count -eq 0) {
    Write-Host "No Intune policies found starting with 'NCT'" -ForegroundColor Yellow
    Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
    exit
}

# Confirm before proceeding
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Total policies to rename: $($policiesToRename.Count)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "❓ Do you want to proceed with renaming? (Y/N): " -ForegroundColor Yellow -NoNewline
$confirm = Read-Host

if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "`n⏭️  Operation cancelled.`n" -ForegroundColor Yellow
    exit
}

Write-Host "`n🔄 Renaming policies...`n" -ForegroundColor Yellow

# Rename each policy
$successCount = 0
$failCount = 0

foreach ($item in $policiesToRename) {
    $policy = $item.Policy
    $newName = $item.NewName
    $type = $item.Type
    
    try {
        switch ($type) {
            "DeviceConfiguration" {
                $updateBody = @{
                    displayName = $newName
                }
                Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($policy.id)" -Body ($updateBody | ConvertTo-Json -Depth 10)
                Write-Host "✅ [Device Config] Renamed: $($policy.displayName) → $newName" -ForegroundColor Green
            }
            
            "SettingsCatalog" {
                $updateBody = @{
                    name = $newName
                }
                Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)" -Body ($updateBody | ConvertTo-Json -Depth 10)
                Write-Host "✅ [Settings Catalog] Renamed: $($policy.name) → $newName" -ForegroundColor Green
            }
            
            "Compliance" {
                $updateBody = @{
                    displayName = $newName
                }
                Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($policy.id)" -Body ($updateBody | ConvertTo-Json -Depth 10)
                Write-Host "✅ [Compliance] Renamed: $($policy.displayName) → $newName" -ForegroundColor Green
            }
        }
        
        $successCount++
        
    } catch {
        $policyName = if ($type -eq "SettingsCatalog") { $policy.name } else { $policy.displayName }
        Write-Host "❌ [$type] Failed to rename '$policyName': $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

# Summary
Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ RENAME OPERATION COMPLETE!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`nSummary:" -ForegroundColor Yellow
Write-Host "  Successfully renamed: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Failed: $failCount" -ForegroundColor Red
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
