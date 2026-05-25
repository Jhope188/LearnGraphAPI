# Delete duplicate policies - keep the newer ones from today (01/20/2026)
$allPolicies = Get-MgIdentityConditionalAccessPolicy | Where-Object { $_.DisplayName -like "IAC -*" }
$grouped = $allPolicies | Group-Object DisplayName

$duplicates = $grouped | Where-Object { $_.Count -gt 1 }

foreach ($group in $duplicates) {
    Write-Host "`nProcessing: $($group.Name)" -ForegroundColor Cyan
    
    # Sort by creation date and keep the newest
    $sorted = $group.Group | Sort-Object CreatedDateTime -Descending
    $keep = $sorted[0]
    $toDelete = $sorted[1..($sorted.Count - 1)]
    
    Write-Host "  Keeping: $($keep.Id) (Created: $($keep.CreatedDateTime))" -ForegroundColor Green
    
    foreach ($policy in $toDelete) {
        Write-Host "  Deleting: $($policy.Id) (Created: $($policy.CreatedDateTime))" -ForegroundColor Yellow
        try {
            Remove-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -Confirm:$false
            Write-Host "    ✅ Deleted" -ForegroundColor Green
        }
        catch {
            Write-Host "    ❌ Failed: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Cyan
$remaining = (Get-MgIdentityConditionalAccessPolicy | Where-Object { $_.DisplayName -like "IAC -*" }).Count
Write-Host "Remaining IAC policies: $remaining" -ForegroundColor Green
