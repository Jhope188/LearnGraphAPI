# Connect to Microsoft Graph with required permissions
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess" -NoWelcome

Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   DELETE CONDITIONAL ACCESS POLICIES: CIS / ACME" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Get all Conditional Access policies
Write-Host "🔍 Retrieving Conditional Access policies...`n" -ForegroundColor Yellow

try {
    $policies = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies").value
    
    # Filter policies that contain "CIS" or "ACME" in the name
    $policiesToDelete = $policies | Where-Object { $_.displayName -like "*CIS*" -or $_.displayName -like "*ACME*" }
    
    if ($policiesToDelete.Count -eq 0) {
        Write-Host "No policies found containing 'CIS' or 'ACME'" -ForegroundColor Yellow
        Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
        exit
    }
    
    Write-Host "Found $($policiesToDelete.Count) policy/policies to delete:`n" -ForegroundColor White
    
    # Display policies that will be deleted
    foreach ($policy in $policiesToDelete) {
        Write-Host "  • $($policy.displayName)" -ForegroundColor Red
        Write-Host "    ID: $($policy.id)" -ForegroundColor Gray
        Write-Host "    State: $($policy.state)" -ForegroundColor Gray
    }
    
    # Confirm before proceeding
    Write-Host "`n⚠️  WARNING: This action cannot be undone!`n" -ForegroundColor Red
    Write-Host "❓ Do you want to proceed with deletion? (Y/N): " -ForegroundColor Yellow -NoNewline
    $confirm = Read-Host
    
    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
        Write-Host "`n⏭️  Operation cancelled.`n" -ForegroundColor Yellow
        exit
    }
    
    Write-Host "`n🗑️  Deleting policies...`n" -ForegroundColor Yellow
    
    # Delete each policy
    $successCount = 0
    $failCount = 0
    
    foreach ($policy in $policiesToDelete) {
        try {
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)"
            
            Write-Host "✅ Deleted: $($policy.displayName)" -ForegroundColor Green
            $successCount++
            
        } catch {
            Write-Host "❌ Failed to delete '$($policy.displayName)': $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
        }
    }
    
    # Summary
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "✅ DELETE OPERATION COMPLETE!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "`nSummary:" -ForegroundColor Yellow
    Write-Host "  Successfully deleted: $successCount" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "  Failed: $failCount" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n✨ Done!`n" -ForegroundColor Cyan
