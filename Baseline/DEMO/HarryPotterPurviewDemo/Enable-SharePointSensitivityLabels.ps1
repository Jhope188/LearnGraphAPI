# Enable Sensitivity Labels for SharePoint Online and OneDrive
# This allows users to apply sensitivity labels to Office files in SharePoint and OneDrive

# Import the SharePoint Online module
Write-Host "Importing SharePoint Online module..." -ForegroundColor Cyan
Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop

# Connect to SharePoint Online (if not already connected)
Write-Host "Connecting to SharePoint Online..." -ForegroundColor Cyan
Connect-SPOService -Url "https://inforcer2m365-admin.sharepoint.com"

# Enable sensitivity labels for SharePoint and OneDrive
Write-Host "`nEnabling sensitivity labels for SharePoint and OneDrive..." -ForegroundColor Yellow

try {
    # Enable the feature at tenant level
    Set-SPOTenant -EnableAIPIntegration $true
    
    Write-Host "✓ Sensitivity labels enabled for SharePoint and OneDrive!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: It may take up to 24 hours for this change to propagate across all sites." -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Verify the setting
Write-Host "Current setting:" -ForegroundColor Cyan
Get-SPOTenant | Select-Object EnableAIPIntegration

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "  1. Wait for propagation (up to 24 hours)" -ForegroundColor White
Write-Host "  2. Users can now apply sensitivity labels in Word, Excel, PowerPoint" -ForegroundColor White
Write-Host "  3. Labels will appear in the Sensitivity button on the ribbon" -ForegroundColor White

# Disconnect
Disconnect-SPOService
