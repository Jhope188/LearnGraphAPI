#Requires -Modules MSCommerce
<#
.SYNOPSIS
    Disables all self-service purchase and trial policies in Microsoft 365.

.DESCRIPTION
    Uses the MSCommerce module to enumerate every product that supports
    self-service purchase or trial sign-up and sets all of them to Disabled.
    This prevents users from starting trials or purchasing licences without
    admin approval — enforcing central licence governance.

.NOTES
    Module required : MSCommerce
    Install         : Install-Module -Name MSCommerce -Force
    Permissions     : Global Admin or Billing Admin
    Docs            : https://learn.microsoft.com/en-us/microsoft-365/commerce/subscriptions/allowselfservicepurchase-powershell

.EXAMPLE
    .\Disable-SelfServiceTrials.ps1
    .\Disable-SelfServiceTrials.ps1 -WhatIf        # Preview only, no changes
    .\Disable-SelfServiceTrials.ps1 -Verbose        # Show each product processed
#>

[CmdletBinding(SupportsShouldProcess)]
param()

# ── 1. Ensure MSCommerce module is available ────────────────────────────────
if (-not (Get-Module -ListAvailable -Name MSCommerce)) {
    Write-Host "MSCommerce module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name MSCommerce -Force -AllowClobber
}

Import-Module MSCommerce -ErrorAction Stop

# ── 2. Connect to MSCommerce ────────────────────────────────────────────────
Write-Host "`nConnecting to MSCommerce..." -ForegroundColor Cyan
Connect-MSCommerce

# ── 3. Retrieve all self-service policies ──────────────────────────────────
Write-Host "Retrieving all self-service purchase/trial policies...`n" -ForegroundColor Cyan

$policies = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase

if (-not $policies) {
    Write-Warning "No self-service policies found or unable to retrieve them."
    exit
}

Write-Host ("Found {0} product policies." -f $policies.Count) -ForegroundColor White

# ── 4. Disable each policy ─────────────────────────────────────────────────
$results = @()

foreach ($policy in $policies) {
    $productName = $policy.ProductName
    $productId   = $policy.ProductId
    $current     = $policy.PolicyValue

    if ($current -eq "Disabled") {
        Write-Verbose "Already disabled: $productName"
        $results += [PSCustomObject]@{
            Product = $productName
            Status  = "Already Disabled"
            Changed = $false
        }
        continue
    }

    if ($PSCmdlet.ShouldProcess($productName, "Disable self-service purchase/trial")) {
        try {
            Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase `
                -ProductId $productId -Value "Disabled" -ErrorAction Stop

            Write-Host "  ✅  Disabled: $productName" -ForegroundColor Green
            $results += [PSCustomObject]@{
                Product = $productName
                Status  = "Disabled"
                Changed = $true
            }
        }
        catch {
            Write-Warning "  ⚠️  Failed to disable: $productName — $($_.Exception.Message)"
            $results += [PSCustomObject]@{
                Product = $productName
                Status  = "Error: $($_.Exception.Message)"
                Changed = $false
            }
        }
    }
}

# ── 5. Summary ─────────────────────────────────────────────────────────────
Write-Host "`n─────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "  Summary" -ForegroundColor White
Write-Host "─────────────────────────────────────────────" -ForegroundColor Gray

$changed       = ($results | Where-Object { $_.Changed -eq $true }).Count
$alreadyOff    = ($results | Where-Object { $_.Status -eq "Already Disabled" }).Count
$errors        = ($results | Where-Object { $_.Status -like "Error*" }).Count

Write-Host "  Newly disabled  : $changed" -ForegroundColor Green
Write-Host "  Already disabled: $alreadyOff" -ForegroundColor Gray
Write-Host "  Errors          : $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Gray" })
Write-Host "─────────────────────────────────────────────`n" -ForegroundColor Gray

# Output full results table
$results | Format-Table -AutoSize

# ── 6. Verify final state ───────────────────────────────────────────────────
Write-Host "Final policy state verification:" -ForegroundColor Cyan
Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase |
    Select-Object ProductName, PolicyValue |
    Sort-Object ProductName |
    Format-Table -AutoSize
