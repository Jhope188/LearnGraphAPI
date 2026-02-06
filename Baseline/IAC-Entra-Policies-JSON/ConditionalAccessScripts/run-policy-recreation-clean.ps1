<#
.SYNOPSIS
    Wrapper script to run IAC policy recreation in a clean PowerShell session without module corruption.

.DESCRIPTION
    This script launches a new PowerShell process to avoid Exchange Online module corruption issues.
    It connects to Microsoft Graph and runs the policy recreation script.

.NOTES
    This bypasses the Exchange Online formatting file corruption by running in a fresh process.
#>

Write-Host "`n=== IAC Entra Policy Recreation (Clean Session) ===" -ForegroundColor Cyan
Write-Host "Launching in new PowerShell session to avoid module corruption...`n" -ForegroundColor Yellow

# Create a script block that will run in the new session
$scriptBlock = @'
# Navigate to script directory
Set-Location "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccessScripts"

# Force remove Exchange module before loading anything
Remove-Module ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue

Write-Host "`n=== Connecting to Microsoft Graph ===" -ForegroundColor Cyan
Write-Host "Required permissions:" -ForegroundColor Yellow
Write-Host "  - Policy.ReadWrite.ConditionalAccess" -ForegroundColor Gray
Write-Host "  - Policy.ReadWrite.Authorization" -ForegroundColor Gray
Write-Host "  - Application.ReadWrite.All" -ForegroundColor Gray
Write-Host "  - Directory.ReadWrite.All" -ForegroundColor Gray
Write-Host "  - Policy.Read.All" -ForegroundColor Gray
Write-Host "  - RoleManagement.ReadWrite.Directory" -ForegroundColor Gray
Write-Host ""

Connect-MgGraph -Scopes @(
    'Policy.ReadWrite.ConditionalAccess',
    'Policy.ReadWrite.Authorization',
    'Application.ReadWrite.All',
    'Directory.ReadWrite.All',
    'Policy.Read.All',
    'RoleManagement.ReadWrite.Directory'
) -NoWelcome

$context = Get-MgContext
Write-Host "✅ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
Write-Host "   Account: $($context.Account)`n" -ForegroundColor Gray

# Import required modules explicitly
Write-Host "Loading Microsoft Graph modules..." -ForegroundColor Yellow
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
Write-Host "✅ Modules loaded successfully`n" -ForegroundColor Green

# Run the recreation script
Write-Host "=== Running IAC Policy Recreation Script ===" -ForegroundColor Cyan
./recreate-iac-entra-policies.ps1

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@

# Write the script block to a temporary file
$tempScript = "/tmp/run-iac-policies-$([Guid]::NewGuid()).ps1"
$scriptBlock | Out-File -FilePath $tempScript -Encoding UTF8

try {
    # Launch new PowerShell session with the script
    pwsh -NoProfile -File $tempScript
} finally {
    # Clean up temp file
    Remove-Item -Path $tempScript -ErrorAction SilentlyContinue
}
