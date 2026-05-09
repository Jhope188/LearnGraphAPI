# Harry Potter SharePoint Demo Setup
# Connects to whichever tenant you authenticate against — no hardcoded tenant IDs

Write-Host "=== Harry Potter SharePoint Demo Setup ===" -ForegroundColor Cyan

# Step 1: Connect to Microsoft Graph
Write-Host "`n[1/3] Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes 'Sites.ReadWrite.All', 'Group.ReadWrite.All', 'SharePointTenantSettings.ReadWrite.All', 'Domain.Read.All' -NoWelcome

$context = Get-MgContext
Write-Host "Connected as: $($context.Account)" -ForegroundColor Green
Write-Host "Tenant ID: $($context.TenantId)" -ForegroundColor Green

# Derive the SharePoint tenant prefix from the default .onmicrosoft.com domain
$defaultDomain = (Get-MgDomain -All | Where-Object { $_.Id -like '*.onmicrosoft.com' -and $_.Id -notlike '*.mail.onmicrosoft.com' }).Id
$spTenantPrefix = $defaultDomain -replace '\.onmicrosoft\.com$',''
$spBaseUrl = "https://$spTenantPrefix.sharepoint.com/sites"

Write-Host "Tenant domain: $defaultDomain" -ForegroundColor Green
Write-Host "SharePoint base URL: $spBaseUrl" -ForegroundColor Green

# Step 2: Create SharePoint Sites
Write-Host "`n[2/3] Creating Harry Potter themed SharePoint sites..." -ForegroundColor Cyan

$sites = @(
    @{
        DisplayName = "Order of the Phoenix"
        MailNickname = "OrderOfThePhoenix"
        Description = "Secret organization dedicated to fighting dark forces and protecting Hogwarts"
    },
    @{
        DisplayName = "Hogwarts School"
        MailNickname = "Hogwarts"
        Description = "Hogwarts School of Witchcraft and Wizardry - Excellence in magical education"
    },
    @{
        DisplayName = "Ministry of Magic"
        MailNickname = "MinistryOfMagic"
        Description = "Official governing body of the magical community"
    },
    @{
        DisplayName = "Diagon Alley"
        MailNickname = "DiagonAlley"
        Description = "The premier shopping district for all your magical needs"
    },
    @{
        DisplayName = "Quidditch League"
        MailNickname = "QuidditchLeague"
        Description = "Official Quidditch League - Following matches, standings, and team news"
    }
)

$createdSites = @()

foreach ($site in $sites) {
    try {
        Write-Host "  Creating: $($site.DisplayName)..." -ForegroundColor Yellow
        
        $group = New-MgGroup -DisplayName $site.DisplayName `
                             -MailNickname $site.MailNickname `
                             -Description $site.Description `
                             -MailEnabled:$true `
                             -SecurityEnabled:$false `
                             -GroupTypes @("Unified") `
                             -Visibility "Private"
        
        $siteUrl = "$spBaseUrl/$($site.MailNickname)"
        
        $createdSites += [PSCustomObject]@{
            Name = $site.DisplayName
            GroupId = $group.Id
            SiteUrl = $siteUrl
        }
        
        Write-Host "    ✓ Created: $siteUrl" -ForegroundColor Green
    }
    catch {
        Write-Host "    ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n  SharePoint sites created (allow 5-10 minutes for full provisioning):" -ForegroundColor Green
$createdSites | Format-Table -AutoSize

# Step 3: Enable Sensitivity Labels for SharePoint
Write-Host "`n[3/3] Enabling sensitivity labels for SharePoint and OneDrive..." -ForegroundColor Cyan

try {
    Invoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -Body '{"isSensitivityLabelsEnabled":true}'
    
    # Verify
    $settings = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings'
    
    if ($settings.isSensitivityLabelsEnabled) {
        Write-Host "  ✓ Sensitivity labels enabled successfully!" -ForegroundColor Green
        Write-Host "    Note: Setting propagates within minutes (up to 24 hours max)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ✗ Failed to enable sensitivity labels: $($_.Exception.Message)" -ForegroundColor Red
}

# Summary
Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Wait 5-10 minutes for SharePoint sites to finish provisioning"
Write-Host "2. Navigate to: $spBaseUrl/OrderOfThePhoenix"
Write-Host "3. Create 'Dumbledore's Army.docx' with the member roster"
Write-Host "4. Apply sensitivity labels from Word ribbon"
Write-Host "`nMember roster file available at: /Users/jon/Desktop/BaslineSetup/HarryPotterPurviewDemo/Dumbledores Army.docx"

Disconnect-MgGraph
Write-Host "`nDisconnected from Microsoft Graph" -ForegroundColor Gray
