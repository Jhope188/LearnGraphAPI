# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   RENAME CONDITIONAL ACCESS POLICIES: NCT → IAC" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Get all Conditional Access policies
Write-Host "🔍 Retrieving Conditional Access policies...`n" -ForegroundColor Yellow

try {
    $policies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies").value
    
    # Filter policies that start with "NCT"
    $nctPolicies = $policies | Where-Object { $_.displayName -like "NCT*" }
    
    if ($nctPolicies.Count -eq 0) {
        Write-Host "No policies found starting with 'NCT'" -ForegroundColor Yellow
        Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
        exit
    }
    
    Write-Host "Found $($nctPolicies.Count) policy/policies to rename:`n" -ForegroundColor White
    
    # Display policies that will be renamed
    foreach ($policy in $nctPolicies) {
        $newName = $policy.displayName -replace "^NCT", "IAC"
        Write-Host "  • $($policy.displayName)" -ForegroundColor Cyan
        Write-Host "    → $newName" -ForegroundColor Green
    }
    
    # Confirm before proceeding
    Write-Host "`n❓ Do you want to proceed with renaming? (Y/N): " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host
    
    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Host "`n⏭️  Operation cancelled.`n" -ForegroundColor Yellow
        exit
    }
    
    Write-Host "`n🔄 Renaming policies...`n" -ForegroundColor Yellow
    
    # Rename each policy
    $successCount = 0
    $failCount = 0
    
    foreach ($policy in $nctPolicies) {
        $newName = $policy.displayName -replace "^NCT", "IAC"
        
        try {
            $updateBody = @{
                displayName = $newName
            }
            
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)" -Body ($updateBody | ConvertTo-Json -Depth 10)
            
            Write-Host "✅ Renamed: $($policy.displayName) → $newName" -ForegroundColor Green
            $successCount++
            
        } catch {
            Write-Host "❌ Failed to rename '$($policy.displayName)': $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "❌ Error retrieving policies: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
