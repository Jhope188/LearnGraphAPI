# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   RENAME NAMED LOCATIONS: NCT → IAC" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Get all Named Locations
Write-Host "🔍 Step 1: Retrieving Named Locations...`n" -ForegroundColor Yellow

try {
    $locations = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations").value
    
    # Filter locations that start with "NCT"
    $nctLocations = $locations | Where-Object { $_.displayName -like "NCT*" }
    
    if ($nctLocations.Count -eq 0) {
        Write-Host "No named locations found starting with 'NCT'" -ForegroundColor Yellow
        Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
        exit
    }
    
    Write-Host "Found $($nctLocations.Count) location(s) to rename:`n" -ForegroundColor White
    
    # Display locations that will be renamed
    foreach ($location in $nctLocations) {
        $newName = $location.displayName -replace "^NCT", "IAC"
        Write-Host "  • $($location.displayName)" -ForegroundColor Cyan
        Write-Host "    → $newName" -ForegroundColor Green
    }
    
    # Confirm before proceeding
    Write-Host "`n❓ Do you want to proceed with renaming? (Y/N): " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host
    
    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Host "`n⏭️  Operation cancelled.`n" -ForegroundColor Yellow
        exit
    }
    
    # Get all Conditional Access policies
    Write-Host "`n🔍 Step 2: Retrieving Conditional Access policies...`n" -ForegroundColor Yellow
    $policies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies").value
    
    # Process each location
    $successCount = 0
    $failCount = 0
    
    foreach ($location in $nctLocations) {
        $newName = $location.displayName -replace "^NCT", "IAC"
        $locationId = $location.id
        
        Write-Host "`n📍 Processing: $($location.displayName)" -ForegroundColor Cyan
        
        # Find policies that reference this location
        $affectedPolicies = @()
        foreach ($policy in $policies) {
            $includesLocation = $false
            $excludesLocation = $false
            
            # Check if location is in includeLocations
            if ($policy.conditions.locations.includeLocations -contains $locationId) {
                $includesLocation = $true
            }
            
            # Check if location is in excludeLocations
            if ($policy.conditions.locations.excludeLocations -contains $locationId) {
                $excludesLocation = $true
            }
            
            if ($includesLocation -or $excludesLocation) {
                $affectedPolicies += @{
                    Policy = $policy
                    IncludesLocation = $includesLocation
                    ExcludesLocation = $excludesLocation
                }
                Write-Host "   Found in policy: $($policy.displayName)" -ForegroundColor Gray
            }
        }
        
        try {
            # Step 1: Remove location from all affected policies
            if ($affectedPolicies.Count -gt 0) {
                Write-Host "`n   🔄 Removing location from $($affectedPolicies.Count) policy/policies..." -ForegroundColor Yellow
                
                foreach ($item in $affectedPolicies) {
                    $policy = $item.Policy
                    
                    # Get current policy
                    $currentPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)"
                    
                    # Build new location arrays without the current location
                    $newIncludeLocations = $currentPolicy.conditions.locations.includeLocations | Where-Object { $_ -ne $locationId }
                    $newExcludeLocations = $currentPolicy.conditions.locations.excludeLocations | Where-Object { $_ -ne $locationId }
                    
                    # Construct clean update body
                    $updatePolicyBody = @{
                        conditions = @{
                            locations = @{
                                includeLocations = if ($newIncludeLocations) { @($newIncludeLocations) } else { @() }
                                excludeLocations = if ($newExcludeLocations) { @($newExcludeLocations) } else { @() }
                            }
                        }
                    }
                    
                    # Update policy
                    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)" -Body ($updatePolicyBody | ConvertTo-Json -Depth 20)
                    Write-Host "      ✓ Removed from: $($policy.displayName)" -ForegroundColor Gray
                }
            }
            
            # Step 2: Rename the location
            Write-Host "`n   🏷️  Renaming location..." -ForegroundColor Yellow
            $updateBody = @{
                displayName = $newName
            }
            
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$($locationId)" -Body ($updateBody | ConvertTo-Json -Depth 10)
            Write-Host "      ✓ Renamed to: $newName" -ForegroundColor Gray
            
            # Step 3: Re-add location to affected policies
            if ($affectedPolicies.Count -gt 0) {
                Write-Host "`n   🔄 Re-adding location to policies..." -ForegroundColor Yellow
                
                foreach ($item in $affectedPolicies) {
                    $policy = $item.Policy
                    
                    # Get current policy again
                    $currentPolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)"
                    
                    # Build new location arrays with the renamed location
                    $newIncludeLocations = @($currentPolicy.conditions.locations.includeLocations)
                    $newExcludeLocations = @($currentPolicy.conditions.locations.excludeLocations)
                    
                    if ($item.IncludesLocation) {
                        $newIncludeLocations += $locationId
                    }
                    
                    if ($item.ExcludesLocation) {
                        $newExcludeLocations += $locationId
                    }
                    
                    # Construct clean update body
                    $updatePolicyBody = @{
                        conditions = @{
                            locations = @{
                                includeLocations = if ($newIncludeLocations) { @($newIncludeLocations) } else { @() }
                                excludeLocations = if ($newExcludeLocations) { @($newExcludeLocations) } else { @() }
                            }
                        }
                    }
                    
                    # Update policy
                    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)" -Body ($updatePolicyBody | ConvertTo-Json -Depth 20)
                    Write-Host "      ✓ Re-added to: $($policy.displayName)" -ForegroundColor Gray
                }
            }
            
            Write-Host "`n✅ Successfully renamed: $($location.displayName) → $newName" -ForegroundColor Green
            $successCount++
            
        } catch {
            Write-Host "`n❌ Failed to rename '$($location.displayName)': $($_.Exception.Message)" -ForegroundColor Red
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
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
