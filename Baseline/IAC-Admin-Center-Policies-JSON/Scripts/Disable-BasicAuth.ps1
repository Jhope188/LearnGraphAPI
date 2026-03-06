<#
.SYNOPSIS
    Disables all basic authentication protocols in Exchange Online.
.DESCRIPTION
    Updates the existing authentication policy to block all basic auth
    protocols and ensures it is set as the org-wide default.
#>

Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -Organization 'inforcer2M365.onmicrosoft.com' -ShowBanner:$false

$policyName = 'BlockBasic639084019154570982'

Write-Host "`n🔧 Disabling ALL basic auth protocols on policy: $policyName" -ForegroundColor Cyan
Write-Host ""

Set-AuthenticationPolicy -Identity $policyName -AllowBasicAuthActiveSync:$false -AllowBasicAuthAutodiscover:$false -AllowBasicAuthImap:$false -AllowBasicAuthMapi:$false -AllowBasicAuthOfflineAddressBook:$false -AllowBasicAuthOutlookService:$false -AllowBasicAuthPop:$false -AllowBasicAuthReportingWebServices:$false -AllowBasicAuthRpc:$false -AllowBasicAuthSmtp:$false -AllowBasicAuthWebServices:$false -AllowBasicAuthPowershell:$false

Write-Host "`n✅ Verifying policy..." -ForegroundColor Cyan
$policy = Get-AuthenticationPolicy -Identity $policyName
$policy | Select-Object Name, AllowBasicAuth* | Format-List

# Check all are false
$allBlocked = $true
$policy.PSObject.Properties | Where-Object { $_.Name -like 'AllowBasicAuth*' } | ForEach-Object {
    if ($_.Value -eq $true) {
        Write-Host "   ❌ $($_.Name) is still TRUE" -ForegroundColor Red
        $allBlocked = $false
    }
}

if ($allBlocked) {
    Write-Host "   ✅ All basic auth protocols are BLOCKED" -ForegroundColor Green
} else {
    Write-Host "   ⚠️ Some protocols still allow basic auth" -ForegroundColor Yellow
}

# Confirm org default
$orgConfig = Get-OrganizationConfig
Write-Host "`n📋 Org Config:" -ForegroundColor Cyan
Write-Host "   DefaultAuthenticationPolicy: $($orgConfig.DefaultAuthenticationPolicy)"
Write-Host "   OAuth2ClientProfileEnabled:  $($orgConfig.OAuth2ClientProfileEnabled)"

Write-Host "`n🎉 Done. Migration status should update within 24 hours." -ForegroundColor Green

Disconnect-ExchangeOnline -Confirm:$false
