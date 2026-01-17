# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   RENAME NCT TO IAC - INTUNE POLICIES" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$renamedCount = 0

# 1. Device Configuration Policies
Write-Host "🔍 Processing Device Configuration Policies..." -ForegroundColor Yellow
try {
    $deviceConfigs = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $deviceConfigs += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    foreach ($policy in $deviceConfigs) {
        if ($policy.displayName -like "NCT*") {
            $newName = $policy.displayName -replace "^NCT", "IAC"
            Write-Host "   Renaming: $($policy.displayName) → $newName" -ForegroundColor Cyan
            
            try {
                # Get full policy and update only displayName
                $updateBody = @{
                    "@odata.type" = $policy.'@odata.type'
                    displayName = $newName
                } | ConvertTo-Json -Depth 10
                
                Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($policy.id)" -Body $updateBody -ContentType "application/json"
                $renamedCount++
                Write-Host "   ✅ Renamed successfully" -ForegroundColor Green
            } catch {
                Write-Host "   ⚠️  Skipping - Error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Settings Catalog Policies
Write-Host "`n🔍 Processing Settings Catalog Policies..." -ForegroundColor Yellow
try {
    $settingsCatalog = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $settingsCatalog += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    foreach ($policy in $settingsCatalog) {
        if ($policy.name -like "NCT*") {
            $newName = $policy.name -replace "^NCT", "IAC"
            Write-Host "   Renaming: $($policy.name) → $newName" -ForegroundColor Cyan
            
            $body = @{
                name = $newName
            }
            
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($policy.id)" -Body ($body | ConvertTo-Json)
            $renamedCount++
            Write-Host "   ✅ Renamed successfully" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Compliance Policies
Write-Host "`n🔍 Processing Compliance Policies..." -ForegroundColor Yellow
try {
    $compliancePolicies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies").value
    
    foreach ($policy in $compliancePolicies) {
        if ($policy.displayName -like "NCT*") {
            $newName = $policy.displayName -replace "^NCT", "IAC"
            Write-Host "   Renaming: $($policy.displayName) → $newName" -ForegroundColor Cyan
            
            $body = @{
                displayName = $newName
            }
            
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($policy.id)" -Body ($body | ConvertTo-Json)
            $renamedCount++
            Write-Host "   ✅ Renamed successfully" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Administrative Templates
Write-Host "`n🔍 Processing Administrative Templates..." -ForegroundColor Yellow
try {
    $adminTemplates = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations").value
    
    foreach ($template in $adminTemplates) {
        if ($template.displayName -like "NCT*") {
            $newName = $template.displayName -replace "^NCT", "IAC"
            Write-Host "   Renaming: $($template.displayName) → $newName" -ForegroundColor Cyan
            
            $body = @{
                displayName = $newName
            }
            
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($template.id)" -Body ($body | ConvertTo-Json)
            $renamedCount++
            Write-Host "   ✅ Renamed successfully" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Endpoint Security Intents
Write-Host "`n🔍 Processing Endpoint Security Policies..." -ForegroundColor Yellow
try {
    $intents = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/intents").value
    
    foreach ($policy in $intents) {
        if ($policy.displayName -like "NCT*") {
            $newName = $policy.displayName -replace "^NCT", "IAC"
            Write-Host "   Renaming: $($policy.displayName) → $newName" -ForegroundColor Cyan
            
            $body = @{
                displayName = $newName
            }
            
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/intents/$($policy.id)" -Body ($body | ConvertTo-Json)
            $renamedCount++
            Write-Host "   ✅ Renamed successfully" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Autopilot Profiles
Write-Host "`n🔍 Processing Autopilot Profiles..." -ForegroundColor Yellow
try {
    $autopilotProfiles = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles").value
    
    foreach ($profile in $autopilotProfiles) {
        if ($profile.displayName -like "NCT*") {
            $newName = $profile.displayName -replace "^NCT", "IAC"
            Write-Host "   Renaming: $($profile.displayName) → $newName" -ForegroundColor Cyan
            
            $body = @{
                displayName = $newName
            }
            
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles/$($profile.id)" -Body ($body | ConvertTo-Json)
            $renamedCount++
            Write-Host "   ✅ Renamed successfully" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Red
}

# 7. PowerShell Scripts
Write-Host "`n🔍 Processing PowerShell Scripts..." -ForegroundColor Yellow
try {
    $psScripts = @()
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts"
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        $psScripts += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri)
    
    foreach ($script in $psScripts) {
        if ($script.displayName -like "NCT*") {
            $newName = $script.displayName -replace "^NCT", "IAC"
            Write-Host "   Renaming: $($script.displayName) → $newName" -ForegroundColor Cyan
            
            $body = @{
                displayName = $newName
            }
            
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($script.id)" -Body ($body | ConvertTo-Json)
            $renamedCount++
            Write-Host "   ✅ Renamed successfully" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   ⚠️  Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

Write-Host "✅ Total policies renamed: $renamedCount" -ForegroundColor Green
Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
