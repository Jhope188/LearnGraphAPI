#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fix duplicate trusted locations and add missing excluded groups

.DESCRIPTION
    1. Marks old duplicate locations as untrusted (keeps newest as trusted)
    2. Adds Azure-Breakglass and CA-GlobalExclusions to all policies
    3. Attempts to delete untrusted duplicates
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Connect to Graph
Write-Host "`n=== Connecting to Microsoft Graph ===" -ForegroundColor Cyan
Connect-MgGraph -Scopes 'Policy.ReadWrite.ConditionalAccess','Directory.Read.All' -NoWelcome

try {
    # Get available groups
    Write-Host "`nGetting CA groups..." -ForegroundColor Cyan
    $allGroups = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/groups?$filter=startswith(displayName,''CA-'') or startswith(displayName,''Azure-'')'
    $groupMap = @{}
    foreach ($group in $allGroups.value) {
        $groupMap[$group.displayName] = $group.id
    }

    Write-Host "Found $($groupMap.Count) CA groups" -ForegroundColor Green

    # Standard exclusions
    $standardExclusions = @(
        $groupMap['Azure-Breakglass']
        $groupMap['CA-GlobalExclusions']
    )

    Write-Host "`nStandard exclusions to add:" -ForegroundColor Yellow
    Write-Host "  - Azure-Breakglass: $($groupMap['Azure-Breakglass'])" -ForegroundColor Gray
    Write-Host "  - CA-GlobalExclusions: $($groupMap['CA-GlobalExclusions'])" -ForegroundColor Gray

    # Step 1: Fix Trusted Location Flags
    Write-Host "`n=== Step 1: Fix Trusted Location Flags ===" -ForegroundColor Cyan

    $locations = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations'
    $trustedLocations = $locations.value | Where-Object { $_.isTrusted -eq $true } | Group-Object displayName

    $locationsUnmarked = 0

    foreach ($group in $trustedLocations) {
        if ($group.Count -gt 1) {
            Write-Host "`n$($group.Name) - $($group.Count) trusted copies found" -ForegroundColor Yellow
            
            # Sort by creation date, keep newest as trusted
            $sorted = $group.Group | Sort-Object createdDateTime -Descending
            $toKeep = $sorted[0]
            $toUntrust = $sorted[1..($sorted.Count-1)]
            
            Write-Host "  Keeping as trusted: $($toKeep.id) (created $($toKeep.createdDateTime))" -ForegroundColor Green
            
            foreach ($location in $toUntrust) {
                Write-Host "  Marking as NOT trusted: $($location.id) (created $($location.createdDateTime))" -ForegroundColor Yellow
                
                try {
                    $updateBody = @{
                        isTrusted = $false
                    }
                    
                    Invoke-MgGraphRequest -Method PATCH `
                        -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$($location.id)" `
                        -Body ($updateBody | ConvertTo-Json) `
                        -ContentType "application/json" | Out-Null
                    
                    Write-Host "    ✅ Updated to isTrusted = false" -ForegroundColor Green
                    $locationsUnmarked++
                } catch {
                    Write-Host "    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }

    Write-Host "`n✅ Unmarked $locationsUnmarked duplicate locations as untrusted" -ForegroundColor Green

    # Step 2: Add Missing Excluded Groups
    Write-Host "`n=== Step 2: Add Missing Excluded Groups to Policies ===" -ForegroundColor Cyan

    $allPolicies = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
    $policiesUpdated = 0

    foreach ($policy in $allPolicies.value) {
        $currentExcludedGroups = $policy.conditions.users.excludeGroups
        $needsUpdate = $false
        $newExcludedGroups = @()
        
        if ($currentExcludedGroups) {
            $newExcludedGroups = @($currentExcludedGroups)
        }
        
        foreach ($groupId in $standardExclusions) {
            if ($groupId -and $newExcludedGroups -notcontains $groupId) {
                $newExcludedGroups += $groupId
                $needsUpdate = $true
            }
        }
        
        if ($needsUpdate) {
            Write-Host "  Updating: $($policy.displayName)" -ForegroundColor Yellow
            Write-Host "    Current exclusions: $($currentExcludedGroups.Count)" -ForegroundColor Gray
            Write-Host "    New exclusions: $($newExcludedGroups.Count)" -ForegroundColor Gray
            
            try {
                $updateBody = @{
                    conditions = @{
                        users = @{
                            includeUsers = $policy.conditions.users.includeUsers
                            excludeUsers = $policy.conditions.users.excludeUsers
                            includeGroups = $policy.conditions.users.includeGroups
                            excludeGroups = $newExcludedGroups
                            includeRoles = $policy.conditions.users.includeRoles
                            excludeRoles = $policy.conditions.users.excludeRoles
                        }
                        applications = $policy.conditions.applications
                        userRiskLevels = $policy.conditions.userRiskLevels
                        signInRiskLevels = $policy.conditions.signInRiskLevels
                        clientAppTypes = $policy.conditions.clientAppTypes
                        platforms = $policy.conditions.platforms
                        locations = $policy.conditions.locations
                        devices = $policy.conditions.devices
                    }
                }
                
                Invoke-MgGraphRequest -Method PATCH `
                    -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)" `
                    -Body ($updateBody | ConvertTo-Json -Depth 10) `
                    -ContentType "application/json" | Out-Null
                
                Write-Host "    ✅ Updated" -ForegroundColor Green
                $policiesUpdated++
            } catch {
                Write-Host "    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    Write-Host "`n✅ Updated $policiesUpdated policies with standard exclusions" -ForegroundColor Green

    # Step 3: Delete Untrusted Duplicates
    Write-Host "`n=== Step 3: Delete Untrusted Duplicate Locations ===" -ForegroundColor Cyan
    Write-Host "Waiting 3 seconds for changes to propagate..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3

    $locationsNow = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations'
    $untrustedDuplicates = $locationsNow.value | Where-Object { $_.isTrusted -eq $false } | Group-Object displayName | Where-Object { $_.Count -gt 1 }

    $deleted = 0
    foreach ($group in $untrustedDuplicates) {
        Write-Host "`n$($group.Name) - has $($group.Count) untrusted copies" -ForegroundColor Yellow
        foreach ($location in $group.Group) {
            Write-Host "  Deleting: $($location.id)" -ForegroundColor Yellow
            try {
                Invoke-MgGraphRequest -Method DELETE `
                    -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$($location.id)" | Out-Null
                Write-Host "    ✅ Deleted" -ForegroundColor Green
                $deleted++
            } catch {
                Write-Host "    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    Write-Host "`n✅ Deleted $deleted untrusted duplicate locations" -ForegroundColor Green

    # Final Summary
    Write-Host "`n=== Final Summary ===" -ForegroundColor Cyan
    $finalLocations = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations'
    $finalGrouped = $finalLocations.value | Group-Object displayName
    
    Write-Host "Total locations: $($finalLocations.value.Count)" -ForegroundColor Yellow
    Write-Host "Unique names: $($finalGrouped.Count)" -ForegroundColor Yellow
    Write-Host "Remaining duplicates: $(($finalGrouped | Where-Object { $_.Count -gt 1 }).Count)" -ForegroundColor $(if (($finalGrouped | Where-Object { $_.Count -gt 1 }).Count -eq 0) { 'Green' } else { 'Red' })
    
    Write-Host "`n✅ Fix complete!" -ForegroundColor Green

} finally {
    Disconnect-MgGraph | Out-Null
}
