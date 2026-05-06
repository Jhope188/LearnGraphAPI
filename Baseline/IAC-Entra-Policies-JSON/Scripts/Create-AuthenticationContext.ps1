# Create-AuthenticationContexts.ps1
# Recreates Authentication Context Class References from inforcer2M365 tenant
# Source tenant: e37d43b7-ff48-444b-9d44-fbd4477c18f3 (inforcer2M365.onmicrosoft.com)
#
# Usage: Update $TargetTenantId then run the script.
# Required scope: Policy.ReadWrite.ConditionalAccess

param (
    [string]$TargetTenantId = '86600c1e-803d-49b9-a963-036358886be9' # ConditionalAccessFans
)

Connect-MgGraph -TenantId $TargetTenantId -Scopes 'Policy.ReadWrite.ConditionalAccess' -NoWelcome
Write-Host "Connected to tenant: $TargetTenantId" -ForegroundColor Cyan

$contexts = @(
    @{ Id = 'c1'; DisplayName = 'PIM-ReAuthentication';          Description = 'PIM Reauthentication context';                                    IsAvailable = $true },
    @{ Id = 'c2'; DisplayName = 'SPO - Confidential';            Description = 'Sharepoint Online Site and Files that are confidential';          IsAvailable = $true },
    @{ Id = 'c3'; DisplayName = 'SPO - Restricted';              Description = 'Sharepoint Online Site and Files that are Restricted';            IsAvailable = $true },
    @{ Id = 'c4'; DisplayName = 'Phishing Resistant Authentication'; Description = 'Requirement for Conditional access protection';              IsAvailable = $true }
)

foreach ($ctx in $contexts) {
    Write-Host "Processing: $($ctx.DisplayName) ($($ctx.Id))..." -NoNewline

    # Check if it already exists
    $existing = Get-MgIdentityConditionalAccessAuthenticationContextClassReference -AuthenticationContextClassReferenceId $ctx.Id -ErrorAction SilentlyContinue

    if ($existing) {
        # Update existing
        Update-MgIdentityConditionalAccessAuthenticationContextClassReference `
            -AuthenticationContextClassReferenceId $ctx.Id `
            -DisplayName $ctx.DisplayName `
            -Description $ctx.Description `
            -IsAvailable:$ctx.IsAvailable
        Write-Host " Updated" -ForegroundColor Yellow
    } else {
        # Create new
        New-MgIdentityConditionalAccessAuthenticationContextClassReference `
            -Id $ctx.Id `
            -DisplayName $ctx.DisplayName `
            -Description $ctx.Description `
            -IsAvailable:$ctx.IsAvailable
        Write-Host " Created" -ForegroundColor Green
    }
}

Write-Host "`nVerifying..." -ForegroundColor Cyan
Get-MgIdentityConditionalAccessAuthenticationContextClassReference | Select-Object Id, DisplayName, Description, IsAvailable | Format-Table -AutoSize
