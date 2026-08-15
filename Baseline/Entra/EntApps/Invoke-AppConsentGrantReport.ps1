# ============================================================
# App Consent Grant Report — MSIdentityTools
# https://azuread.github.io/MSIdentityTools/
# ============================================================

# Install module if missing
if (-not (Get-Module -ListAvailable -Name MSIdentityTools)) {
    Write-Host "📦 Installing MSIdentityTools..." -ForegroundColor Yellow
    Install-Module -Name MSIdentityTools -Scope CurrentUser -Repository PSGallery -Force
}

Import-Module MSIdentityTools

# Connect to Graph with required scopes
Connect-MgGraph -Scopes "Application.Read.All", "DelegatedPermissionGrant.Read.All", "Directory.Read.All" | Out-Null
Write-Host "✔  Connected as: $((Get-MgContext).Account)" -ForegroundColor Green

$outputPath = "$HOME/Desktop/tenantappreport.xlsx"

Export-MsIdAppConsentGrantReport -ReportOutputType ExcelWorkbook -ExcelWorkbookPath $outputPath

Write-Host "✔  Report saved to: $outputPath" -ForegroundColor Green
