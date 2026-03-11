<#
.SYNOPSIS
    Creates 20 SharePoint sites with dummy files using PnP PowerShell.

.DESCRIPTION
    Installs PnP PowerShell if needed, creates 20 diverse SharePoint sites,
    uploads varying amounts of dummy files, and shares "Super Secret.docx" 
    with the specified SharePoint Admin.
#>

# Check and install PnP PowerShell if needed
Write-Host "🔍 Checking for PnP PowerShell..." -ForegroundColor Cyan
$pnpModule = Get-Module -ListAvailable -Name "PnP.PowerShell"

if (-not $pnpModule) {
    Write-Host "⚠️  PnP PowerShell not found. Installing..." -ForegroundColor Yellow
    try {
        Install-Module -Name "PnP.PowerShell" -Scope CurrentUser -Force -AllowClobber
        Write-Host "✅ PnP PowerShell installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to install PnP PowerShell: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "✅ PnP PowerShell is already installed" -ForegroundColor Green
}

Import-Module PnP.PowerShell -ErrorAction Stop
Write-Host ""

# ─── Parameters ────────────────────────────────────────────────────────────
# Run as: ./create-sharepoint-environment.ps1 -TenantName "contoso" -AdminEmail "admin@contoso.onmicrosoft.com"
# If called without params, PowerShell will prompt interactively.
#
# NOTE: The -ClientId below points to the PnP Management Shell app registration.
#       Replace with your own App Registration if you prefer.
# ─────────────────────────────────────────────────────────────────────────
param(
    [Parameter(Mandatory)]
    [string]$TenantName,     # e.g. "contoso"
    [Parameter(Mandatory)]
    [string]$AdminEmail,     # used for the "Super Secret" sharing demo
    [string]$ClientId = "395008c6-380b-4a08-9e21-7c28233cdfb9"
)

$tenantUrl = "https://$TenantName-admin.sharepoint.com"
$tenant    = $TenantName

# Connect to SharePoint Online
    Write-Host "✅ Connected to SharePoint Online" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to connect: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Tip: Ensure you have SharePoint Admin permissions" -ForegroundColor Yellow
    exit
}

Write-Host ""

# Site definitions
$siteDefinitions = @(
    @{ Title = "Project Phoenix"; Description = "Next-generation platform initiative"; Template = "STS#3" },
    @{ Title = "Project Atlas"; Description = "Global expansion project"; Template = "STS#3" },
    @{ Title = "Project Titan"; Description = "Infrastructure modernization"; Template = "STS#3" },
    @{ Title = "Project Neptune"; Description = "Cloud migration initiative"; Template = "STS#3" },
    @{ Title = "Project Aurora"; Description = "Innovation and R&D"; Template = "STS#3" },
    @{ Title = "Project Odyssey"; Description = "Customer experience transformation"; Template = "STS#3" },
    @{ Title = "HR Department"; Description = "Human Resources workspace"; Template = "STS#3" },
    @{ Title = "Sales Team"; Description = "Sales operations and planning"; Template = "STS#3" },
    @{ Title = "Marketing Central"; Description = "Marketing campaigns and content"; Template = "STS#3" },
    @{ Title = "Finance Hub"; Description = "Financial planning and analysis"; Template = "STS#3" },
    @{ Title = "IT Operations"; Description = "IT service management"; Template = "STS#3" },
    @{ Title = "Customer Success"; Description = "Customer support and success"; Template = "STS#3" },
    @{ Title = "Product Development"; Description = "Product roadmap and development"; Template = "STS#3" },
    @{ Title = "Research Lab"; Description = "Research and development"; Template = "STS#3" },
    @{ Title = "Legal Department"; Description = "Legal and compliance"; Template = "STS#3" },
    @{ Title = "Executive Suite"; Description = "Executive leadership team"; Template = "STS#3" },
    @{ Title = "Training Portal"; Description = "Employee training and development"; Template = "STS#3" },
    @{ Title = "Operations Center"; Description = "Business operations"; Template = "STS#3" },
    @{ Title = "Quality Assurance"; Description = "QA and testing"; Template = "STS#3" },
    @{ Title = "Innovation Lab"; Description = "Innovation and experimentation"; Template = "STS#3" }
)

# File name templates
$fileTemplates = @(
    "Budget Report", "Meeting Notes", "Project Plan", "Status Update", "Quarterly Review",
    "Team Roster", "Strategy Document", "Roadmap", "Requirements", "Analysis Report",
    "Presentation", "Guidelines", "Policies", "Procedures", "Training Material",
    "Checklist", "Dashboard Data", "Performance Metrics", "Client Feedback", "Action Items",
    "Weekly Summary", "Monthly Report", "Action Plan", "Best Practices", "Lessons Learned"
)

$createdSites = @()
$secretSiteIndex = Get-Random -Minimum 0 -Maximum 20

Write-Host "🏗️  Creating 20 SharePoint sites with files..." -ForegroundColor Cyan
Write-Host ""

for ($i = 0; $i -lt 20; $i++) {
    $siteDef = $siteDefinitions[$i]
    $siteAlias = ($siteDef.Title -replace '[^a-zA-Z0-9]', '').ToLower()
    $siteUrl = "https://$tenant.sharepoint.com/sites/$siteAlias"
    $fileCount = Get-Random -Minimum 3 -Maximum 25
    $isSecretSite = ($i -eq $secretSiteIndex)
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "[$($i+1)/20] Creating: $($siteDef.Title)" -ForegroundColor White
    Write-Host "        URL: $siteUrl" -ForegroundColor Gray
    Write-Host "        Files: $fileCount $(if ($isSecretSite) { '+ Super Secret.docx 🔒' } )" -ForegroundColor Gray
    
    try {
        # Create the site (using Communication Site which works better)
        $newSite = New-PnPSite -Type CommunicationSite -Title $siteDef.Title -Url $siteUrl -Description $siteDef.Description -ErrorAction Stop
        Write-Host "        ✅ Site created" -ForegroundColor Green
        
        # Wait a moment for provisioning
        Start-Sleep -Seconds 5
        
        # Connect to the new site
        $clientId = "395008c6-380b-4a08-9e21-7c28233cdfb9"
        Connect-PnPOnline -Url $siteUrl -Interactive -ClientId $clientId -WarningAction SilentlyContinue
        
        # Upload dummy files
        $uploadedFiles = 0
        
        # Create Super Secret file if this is the secret site
        if ($isSecretSite) {
            $secretContent = "CONFIDENTIAL - TOP SECRET`n`nProject Codename: BLACKBIRD`n`nThis document contains highly sensitive information about our upcoming product launch.`n`nAccess restricted to executive leadership only."
            Add-PnPFile -FileName "Super Secret.docx" -Folder "Shared Documents" -Content $secretContent -ErrorAction SilentlyContinue | Out-Null
            Write-Host "        🔒 Created: Super Secret.docx" -ForegroundColor Yellow
        }
        
        # Create regular files
        for ($f = 0; $f -lt $fileCount; $f++) {
            $fileName = "$($fileTemplates[$f % $fileTemplates.Count]) $(Get-Random -Minimum 1 -Maximum 100).txt"
            $content = "Document: $fileName`nSite: $($siteDef.Title)`nCreated: $(Get-Date)`n`nThis is a dummy file created for demonstration purposes."
            
            try {
                Add-PnPFile -FileName $fileName -Folder "Shared Documents" -Content $content -ErrorAction SilentlyContinue | Out-Null
                $uploadedFiles++
            } catch {
                # Silently continue if file upload fails
            }
        }
        
        Write-Host "        📄 Uploaded: $uploadedFiles files" -ForegroundColor Cyan
        
        # Share Super Secret file externally if this is the secret site
        if ($isSecretSite) {
            try {
                $secretFile = Get-PnPFile -Url "/sites/$siteAlias/Shared Documents/Super Secret.docx" -AsListItem
                $shareLink = Grant-PnPSiteFileShareLink -FileUrl "/sites/$siteAlias/Shared Documents/Super Secret.docx" -Type View -Scope Anonymous
                
                # Send sharing invitation
                Set-PnPFileUserSharingLink -FileUrl "/sites/$siteAlias/Shared Documents/Super Secret.docx" -Users $AdminEmail -SendInvitation
                
                Write-Host "        🔗 Shared with: $AdminEmail" -ForegroundColor Green
                Write-Host "        Link: $shareLink" -ForegroundColor Gray
            } catch {
                Write-Host "        ⚠️  Warning: Could not share file externally: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        
        $createdSites += @{
            Title = $siteDef.Title
            Url = $siteUrl
            Files = $uploadedFiles
            HasSecret = $isSecretSite
        }
        
    } catch {
        Write-Host "        ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Reconnect to admin center for next site creation
    $clientId = "395008c6-380b-4a08-9e21-7c28233cdfb9"
    Connect-PnPOnline -Url $tenantUrl -Interactive -ClientId $clientId -WarningAction SilentlyContinue
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Summary
Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "   ✅ Sites created: $($createdSites.Count)" -ForegroundColor Green
Write-Host "   📄 Total files: $(($createdSites | Measure-Object -Property Files -Sum).Sum)" -ForegroundColor Cyan
$secretSiteInfo = $createdSites | Where-Object { $_.HasSecret -eq $true }
if ($secretSiteInfo) {
    Write-Host "   🔒 Secret file site: $($secretSiteInfo.Title)" -ForegroundColor Yellow
    Write-Host "      URL: $($secretSiteInfo.Url)" -ForegroundColor Gray
    Write-Host "      Shared with: $AdminEmail" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "✅ All SharePoint sites created successfully!" -ForegroundColor Green

Disconnect-PnPOnline
