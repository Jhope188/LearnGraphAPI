#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Delete ALL IAC Conditional Access policies and named locations

.DESCRIPTION
    This script deletes all IAC-prefixed CA policies and IAC-named locations
    to allow for a clean re-import from scratch.
    
.NOTES
    WARNING: This will delete ALL IAC policies and locations!
    
.EXAMPLE
    ./delete-all-iac-policies-and-locations.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "`n=== DELETE ALL IAC POLICIES AND LOCATIONS ===" -ForegroundColor Red
Write-Host "⚠️  WARNING: This will delete ALL IAC-prefixed policies and locations!" -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Type 'DELETE ALL' to confirm (or press Enter to cancel)"

if ($confirmation -ne "DELETE ALL") {
    Write-Host "`n✗ Operation cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Connect to Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes 'Policy.ReadWrite.ConditionalAccess' -NoWelcome

try {
    $context = Get-MgContext
    Write-Host "✓ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
    Write-Host "  Account: $($context.Account)" -ForegroundColor Gray
    Write-Host ""

    # Delete all IAC policies
    Write-Host "=== Deleting IAC Conditional Access Policies ===" -ForegroundColor Cyan
    
    $allPolicies = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
    $iacPolicies = $allPolicies.value | Where-Object { $_.displayName -like "IAC *" }
    
    Write-Host "Found $($iacPolicies.Count) IAC policies to delete" -ForegroundColor Yellow
    
    $deletedPolicies = 0
    foreach ($policy in $iacPolicies) {
        Write-Host "  Deleting: $($policy.displayName)" -ForegroundColor Yellow
        
        try {
            Invoke-MgGraphRequest -Method DELETE `
                -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)" | Out-Null
            Write-Host "    ✅ Deleted" -ForegroundColor Green
            $deletedPolicies++
        } catch {
            Write-Host "    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n✅ Deleted $deletedPolicies IAC policies" -ForegroundColor Green

    # Delete all IAC named locations
    Write-Host "`n=== Deleting IAC Named Locations ===" -ForegroundColor Cyan
    
    $allLocations = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations'
    $iacLocations = $allLocations.value | Where-Object { $_.displayName -like "IAC *" }
    
    Write-Host "Found $($iacLocations.Count) IAC locations to delete" -ForegroundColor Yellow
    
    $deletedLocations = 0
    foreach ($location in $iacLocations) {
        Write-Host "  Deleting: $($location.displayName)" -ForegroundColor Yellow
        
        try {
            Invoke-MgGraphRequest -Method DELETE `
                -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$($location.id)" | Out-Null
            Write-Host "    ✅ Deleted" -ForegroundColor Green
            $deletedLocations++
        } catch {
            Write-Host "    ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n✅ Deleted $deletedLocations IAC locations" -ForegroundColor Green

    # Final verification
    Write-Host "`n=== Final Verification ===" -ForegroundColor Cyan
    
    $remainingPolicies = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies'
    $remainingIACPolicies = $remainingPolicies.value | Where-Object { $_.displayName -like "IAC *" }
    
    $remainingLocations = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations'
    $remainingIACLocations = $remainingLocations.value | Where-Object { $_.displayName -like "IAC *" }
    
    Write-Host "Remaining IAC policies: $($remainingIACPolicies.Count)" -ForegroundColor $(if ($remainingIACPolicies.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Remaining IAC locations: $($remainingIACLocations.Count)" -ForegroundColor $(if ($remainingIACLocations.Count -eq 0) { 'Green' } else { 'Red' })
    
    if ($remainingIACPolicies.Count -eq 0 -and $remainingIACLocations.Count -eq 0) {
        Write-Host "`n✅ All IAC policies and locations successfully deleted!" -ForegroundColor Green
        Write-Host "`nYou can now run the recreate script to import fresh policies:" -ForegroundColor Cyan
        Write-Host "  ./run-policy-recreation-clean.ps1" -ForegroundColor Yellow
    } else {
        Write-Host "`n⚠️  Some items could not be deleted" -ForegroundColor Yellow
        
        if ($remainingIACPolicies.Count -gt 0) {
            Write-Host "`nRemaining policies:" -ForegroundColor Yellow
            $remainingIACPolicies | ForEach-Object { Write-Host "  - $($_.displayName)" -ForegroundColor Gray }
        }
        
        if ($remainingIACLocations.Count -gt 0) {
            Write-Host "`nRemaining locations:" -ForegroundColor Yellow
            $remainingIACLocations | ForEach-Object { Write-Host "  - $($_.displayName)" -ForegroundColor Gray }
        }
    }

} finally {
    Disconnect-MgGraph | Out-Null
}

Write-Host ""
