# Add Dumbledore's Army Word document to Order of the Phoenix SharePoint site
# Requires: Microsoft.Graph module with Sites.ReadWrite.All scope

# Site details
$siteUrl = "https://inforcer2m365.sharepoint.com/sites/OrderOfThePhoenix"
$fileName = "Dumbledores-Army.docx"

# Content for the Word document
$documentContent = @"
DUMBLEDORE'S ARMY - MEMBER ROSTER
==================================

LEADERSHIP
----------
• Harry Potter - Founder & Lead Instructor
• Hermione Granger - Co-founder & Organizer
• Ron Weasley - Tactical Advisor

GRYFFINDOR MEMBERS
------------------
• Neville Longbottom
• Ginny Weasley
• Fred Weasley
• George Weasley
• Dean Thomas
• Seamus Finnigan
• Lavender Brown
• Parvati Patil
• Colin Creevey
• Dennis Creevey

RAVENCLAW MEMBERS
-----------------
• Luna Lovegood
• Cho Chang
• Terry Boot
• Michael Corner
• Anthony Goldstein
• Padma Patil

HUFFLEPUFF MEMBERS
------------------
• Hannah Abbott
• Susan Bones
• Justin Finch-Fletchley
• Ernie Macmillan
• Zacharias Smith

TRAINING SCHEDULE
-----------------
Meetings: Every Wednesday, 8:00 PM
Location: Room of Requirement (7th Floor)
Password: "I need a place to practice defensive magic"

SKILLS COVERED
--------------
✓ Stunning Spell (Stupefy)
✓ Disarming Charm (Expelliarmus)
✓ Patronus Charm (Expecto Patronum)
✓ Reductor Curse (Reducto)
✓ Shield Charm (Protego)
✓ Body-Bind Curse (Petrificus Totalus)

IMPORTANT NOTES
---------------
⚠️ CONFIDENTIAL - Do not discuss with Umbridge or Ministry officials
⚠️ Practice only in designated areas
⚠️ Report any suspicious activity immediately

"For light and freedom" - Harry Potter
"@

Write-Host "Creating Dumbledore's Army document..." -ForegroundColor Yellow
Write-Host ""

try {
    # Create a temporary text file first
    $tempFile = [System.IO.Path]::Combine($env:TEMP, $fileName.Replace('.docx', '.txt'))
    $documentContent | Out-File -FilePath $tempFile -Encoding UTF8
    
    Write-Host "✓ Temporary file created: $tempFile" -ForegroundColor Green
    
    # Get the site
    Write-Host "Getting SharePoint site..." -ForegroundColor Cyan
    $site = Get-MgSite -Search "OrderOfThePhoenix" | Where-Object { $_.WebUrl -like "*OrderOfThePhoenix*" } | Select-Object -First 1
    
    if (-not $site) {
        Write-Host "✗ Could not find Order of the Phoenix site. Please wait for site provisioning to complete (5-10 minutes)" -ForegroundColor Red
        exit
    }
    
    Write-Host "✓ Found site: $($site.WebUrl)" -ForegroundColor Green
    Write-Host "  Site ID: $($site.Id)" -ForegroundColor Gray
    
    # Get the default document library (drive)
    Write-Host "Getting Documents library..." -ForegroundColor Cyan
    $drive = Get-MgSiteDrive -SiteId $site.Id | Where-Object { $_.Name -eq "Documents" } | Select-Object -First 1
    
    if (-not $drive) {
        Write-Host "✗ Could not find Documents library. Site may still be provisioning." -ForegroundColor Red
        exit
    }
    
    Write-Host "✓ Found Documents library" -ForegroundColor Green
    Write-Host "  Drive ID: $($drive.Id)" -ForegroundColor Gray
    
    # Upload the file
    Write-Host "Uploading document to SharePoint..." -ForegroundColor Cyan
    
    $uploadParams = @{
        DriveId = $drive.Id
        DriveItemId = "root"
        InFile = $tempFile
        OutFile = $null
    }
    
    # Note: We're uploading as .txt, user can rename or convert in SharePoint
    New-MgDriveItemUploadSession -DriveId $drive.Id -DriveItemId "root:/$fileName" -InFile $tempFile
    
    Write-Host "✓ Document uploaded successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Document Created!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📄 File: $fileName" -ForegroundColor White
    Write-Host "📁 Location: $($site.WebUrl)/Shared Documents" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Open the document in Word Online or Desktop" -ForegroundColor White
    Write-Host "  2. Convert to .docx format if needed" -ForegroundColor White
    Write-Host "  3. Apply sensitivity labels for your demo!" -ForegroundColor White
    Write-Host ""
    
    # Clean up temp file
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  • SharePoint site is still provisioning (wait 5-10 minutes)" -ForegroundColor Gray
    Write-Host "  • Insufficient permissions (need Sites.ReadWrite.All)" -ForegroundColor Gray
    Write-Host "  • Not connected to Microsoft Graph" -ForegroundColor Gray
}
