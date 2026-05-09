#!/usr/bin/env pwsh
Connect-MgGraph -Scopes 'Policy.Read.All' -NoWelcome

Write-Host "`nRetrieving all Conditional Access policies..." -ForegroundColor Cyan

$policies = Get-MgIdentityConditionalAccessPolicy | Select-Object Id, DisplayName, State | Sort-Object DisplayName

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Total Policies: $($policies.Count)" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

$policies | Format-Table -AutoSize

Disconnect-MgGraph | Out-Null
