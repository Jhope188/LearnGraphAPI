# Create Harry Potter themed SharePoint sites and files for Sensitivity Label demo
# Target tenant: inforcer2M365.onmicrosoft.com (e37d43b7-ff48-444b-9d44-fbd4477c18f3)

# Requires: PnP.PowerShell module
# Install-Module -Name PnP.PowerShell -Force -AllowClobber

param(
    [string]$TenantUrl = "https://acme2m365-admin.sharepoint.com",
    [string]$TenantName = "inforcer2m365"
)

# Connect to SharePoint Online using device login
Write-Host "Connecting to SharePoint Online..." -ForegroundColor Cyan
Write-Host "You will be prompted to authenticate in your browser..." -ForegroundColor Yellow
Connect-PnPOnline -Url $TenantUrl -DeviceLogin

# Define Harry Potter themed sites
$sites = @(
    @{
        Title = "Order of the Phoenix"
        Alias = "OrderOfThePhoenix"
        Description = "Secret headquarters for Dumbledore's resistance against Voldemort"
        Template = "STS#3" # Team site
        Files = @(
            @{ Name = "Dumbledore's Army.docx"; Content = "List of members and meeting schedule for defensive magic training." },
            @{ Name = "Meeting Minutes.docx"; Content = "Minutes from the last DA meeting at Room of Requirement." },
            @{ Name = "Patronus Training.docx"; Content = "Instructions for casting the Patronus charm." }
        )
    },
    @{
        Title = "Hogwarts School of Witchcraft and Wizardry"
        Alias = "Hogwarts"
        Description = "Official Hogwarts staff and student collaboration site"
        Template = "STS#3"
        Files = @(
            @{ Name = "House Points.xlsx"; Content = "Current house points standings." },
            @{ Name = "Staff Directory.docx"; Content = "Faculty and staff contact information." },
            @{ Name = "Term Schedule.docx"; Content = "Academic calendar and exam dates." }
        )
    },
    @{
        Title = "Ministry of Magic"
        Alias = "MinistryOfMagic"
        Description = "Official Ministry of Magic documentation and records"
        Template = "STS#3"
        Files = @(
            @{ Name = "Magical Law Enforcement.docx"; Content = "Recent cases and enforcement activities." },
            @{ Name = "International Cooperation.docx"; Content = "Updates from the International Confederation of Wizards." },
            @{ Name = "Security Protocols.docx"; Content = "CONFIDENTIAL - Ministry security procedures." }
        )
    },
    @{
        Title = "Diagon Alley Merchants"
        Alias = "DiagonAlley"
        Description = "Collaboration space for Diagon Alley shop owners"
        Template = "STS#3"
        Files = @(
            @{ Name = "Inventory - Ollivanders.xlsx"; Content = "Wand inventory and sales records." },
            @{ Name = "Marketing Campaign.docx"; Content = "Promotional plans for back-to-school season." }
        )
    },
    @{
        Title = "Quidditch League"
        Alias = "QuidditchLeague"
        Description = "Official Quidditch World Cup organization site"
        Template = "STS#3"
        Files = @(
            @{ Name = "Match Schedule.xlsx"; Content = "Upcoming Quidditch matches and standings." },
            @{ Name = "Player Stats.xlsx"; Content = "Seeker, Chaser, and Keeper statistics." }
        )
    }
)

# Create each site and upload files
foreach ($site in $sites) {
    Write-Host "`nCreating site: $($site.Title)..." -ForegroundColor Yellow
    
    $siteUrl = "https://$TenantName.sharepoint.com/sites/$($site.Alias)"
    
    try {
        # Create the site
        New-PnPSite -Type TeamSite `
            -Title $site.Title `
            -Alias $site.Alias `
            -Description $site.Description `
            -ErrorAction Stop
        
        Write-Host "✓ Site created: $siteUrl" -ForegroundColor Green
        
        # Wait a moment for site provisioning
        Start-Sleep -Seconds 5
        
        # Connect to the new site using device login
        Connect-PnPOnline -Url $siteUrl -DeviceLogin
        
        # Create temporary Word files and upload them
        foreach ($file in $site.Files) {
            Write-Host "  Creating file: $($file.Name)..." -ForegroundColor Gray
            
            # Create a temporary file
            $tempPath = [System.IO.Path]::Combine($env:TEMP, $file.Name)
            
            # Create simple text file (will be uploaded as is)
            $file.Content | Out-File -FilePath $tempPath -Encoding UTF8
            
            # Upload to Documents library
            Add-PnPFile -Path $tempPath -Folder "Shared Documents" -ErrorAction SilentlyContinue
            
            # Clean up temp file
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
            
            Write-Host "  ✓ Uploaded: $($file.Name)" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "✗ Error creating site $($site.Title): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SharePoint Demo Sites Created!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nSites created:" -ForegroundColor White
foreach ($site in $sites) {
    Write-Host "  • $($site.Title): https://$TenantName.sharepoint.com/sites/$($site.Alias)" -ForegroundColor Gray
}

Write-Host "`nSpecial site for Sensitivity Label demo:" -ForegroundColor Yellow
Write-Host "  📁 Order of the Phoenix" -ForegroundColor White
Write-Host "  📄 Dumbledore's Army.docx" -ForegroundColor White
Write-Host "`nUse these files to demonstrate sensitivity labels in Word!" -ForegroundColor Cyan

# Disconnect
Disconnect-PnPOnline
