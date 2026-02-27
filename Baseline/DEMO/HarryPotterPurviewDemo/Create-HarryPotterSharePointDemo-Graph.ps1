# Create Harry Potter themed SharePoint sites using Microsoft Graph API
# Target tenant: inforcer2M365.onmicrosoft.com (e37d43b7-ff48-444b-9d44-fbd4477c18f3)

# Requires: Microsoft.Graph module and active Graph connection
# Connect-MgGraph -TenantId 'e37d43b7-ff48-444b-9d44-fbd4477c18f3' -Scopes 'Sites.ReadWrite.All', 'Group.ReadWrite.All'

# Verify connection
$context = Get-MgContext
if (-not $context) {
    Write-Host "❌ Not connected to Microsoft Graph. Please run:" -ForegroundColor Red
    Write-Host "Connect-MgGraph -TenantId 'e37d43b7-ff48-444b-9d44-fbd4477c18f3' -Scopes 'Sites.ReadWrite.All', 'Group.ReadWrite.All'" -ForegroundColor Yellow
    exit
}

Write-Host "✓ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
Write-Host ""

# Define Harry Potter themed sites
$sites = @(
    @{
        DisplayName = "Order of the Phoenix"
        MailNickname = "OrderOfThePhoenix"
        Description = "Secret headquarters for Dumbledore's resistance against Voldemort"
    },
    @{
        DisplayName = "Hogwarts School"
        MailNickname = "Hogwarts"
        Description = "Official Hogwarts staff and student collaboration site"
    },
    @{
        DisplayName = "Ministry of Magic"
        MailNickname = "MinistryOfMagic"
        Description = "Official Ministry of Magic documentation and records"
    },
    @{
        DisplayName = "Diagon Alley Merchants"
        MailNickname = "DiagonAlley"
        Description = "Collaboration space for Diagon Alley shop owners"
    },
    @{
        DisplayName = "Quidditch League"
        MailNickname = "QuidditchLeague"
        Description = "Official Quidditch World Cup organization site"
    }
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating Harry Potter SharePoint Sites" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$createdSites = @()

foreach ($site in $sites) {
    Write-Host "Creating site: $($site.DisplayName)..." -ForegroundColor Yellow
    
    try {
        # Create Microsoft 365 Group (which creates a SharePoint site automatically)
        $groupParams = @{
            DisplayName = $site.DisplayName
            MailNickname = $site.MailNickname
            Description = $site.Description
            MailEnabled = $true
            SecurityEnabled = $false
            GroupTypes = @("Unified")
            Visibility = "Private"
        }
        
        $group = New-MgGroup -BodyParameter $groupParams
        
        Write-Host "✓ Group created: $($group.Id)" -ForegroundColor Green
        
        # Store site info
        $createdSites += @{
            DisplayName = $site.DisplayName
            GroupId = $group.Id
            MailNickname = $site.MailNickname
        }
        
        Start-Sleep -Seconds 2
        
    } catch {
        Write-Host "✗ Error creating $($site.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sites Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Created Sites:" -ForegroundColor White
foreach ($createdSite in $createdSites) {
    $siteUrl = "https://inforcer2m365.sharepoint.com/sites/$($createdSite.MailNickname)"
    Write-Host "  • $($createdSite.DisplayName)" -ForegroundColor Cyan
    Write-Host "    URL: $siteUrl" -ForegroundColor Gray
    Write-Host "    Group ID: $($createdSite.GroupId)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "⭐ Special Site for Demo:" -ForegroundColor Yellow
Write-Host "  📁 Order of the Phoenix" -ForegroundColor White
Write-Host "  🔗 https://inforcer2m365.sharepoint.com/sites/OrderOfThePhoenix" -ForegroundColor Gray
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Wait 5-10 minutes for SharePoint sites to fully provision" -ForegroundColor White
Write-Host "  2. Navigate to the Order of the Phoenix site" -ForegroundColor White
Write-Host "  3. Create a Word document called 'Dumbledore's Army.docx'" -ForegroundColor White
Write-Host "  4. Apply sensitivity labels for your demo!" -ForegroundColor White
Write-Host ""
