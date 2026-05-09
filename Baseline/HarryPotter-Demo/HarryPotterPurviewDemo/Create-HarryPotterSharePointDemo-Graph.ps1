# Create Harry Potter themed SharePoint sites using Microsoft Graph API
#
# Usage: ./Create-HarryPotterSharePointDemo-Graph.ps1 -TenantDomain "contoso.onmicrosoft.com"

param(
    [Parameter(Mandatory)]
    [string]$TenantDomain
)

$TenantPrefix = $TenantDomain -replace '\.onmicrosoft\.com$' -replace '\..*$'
$SPOBaseUrl   = "https://$TenantPrefix.sharepoint.com"

# Connect to Graph
Connect-MgGraph -TenantId $TenantDomain -Scopes 'Sites.ReadWrite.All', 'Group.ReadWrite.All' -NoWelcome

# Verify connection
$context = Get-MgContext
if (-not $context) {
    Write-Error "Failed to connect to Microsoft Graph for tenant $TenantDomain"
    exit 1
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
    $siteUrl = "$SPOBaseUrl/sites/$($createdSite.MailNickname)"
    Write-Host "  • $($createdSite.DisplayName)" -ForegroundColor Cyan
    Write-Host "    URL: $siteUrl" -ForegroundColor Gray
    Write-Host "    Group ID: $($createdSite.GroupId)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "⭐ Special Site for Demo:" -ForegroundColor Yellow
Write-Host "  📁 Order of the Phoenix" -ForegroundColor White
Write-Host "  🔗 $SPOBaseUrl/sites/OrderOfThePhoenix" -ForegroundColor Gray
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Wait 5-10 minutes for SharePoint sites to fully provision" -ForegroundColor White
Write-Host "  2. Navigate to the Order of the Phoenix site" -ForegroundColor White
Write-Host "  3. Create a Word document called 'Dumbledore's Army.docx'" -ForegroundColor White
Write-Host "  4. Apply sensitivity labels for your demo!" -ForegroundColor White
Write-Host ""
