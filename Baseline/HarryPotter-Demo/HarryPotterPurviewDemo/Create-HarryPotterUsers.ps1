# Create Harry Potter Users in Entra ID
# Author: Magical IT Department
# Date: February 1, 2026

# Ensure Microsoft.Graph modules are installed
$requiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Identity.DirectoryManagement",
    "Microsoft.Graph.Users",
    "Microsoft.Graph.Users.Actions",
    "Microsoft.Graph.Groups"
)

$targetVersion = "2.36.1"

foreach ($module in $requiredModules) {
    $available = Get-Module -ListAvailable -Name $module | Sort-Object Version -Descending
    if (-not $available -or ($available | Where-Object { $_.Version -eq [version]$targetVersion }).Count -eq 0) {
        Write-Host "Installing $module version $targetVersion..." -ForegroundColor Yellow
        Install-Module $module -Scope CurrentUser -Force -RequiredVersion $targetVersion
    }

    # Import the same version to avoid mixed-version assembly conflicts
    Import-Module $module -RequiredVersion $targetVersion -Force -ErrorAction Stop
}

# Disconnect any existing Graph session first to avoid mixed-version module conflicts
Disconnect-MgGraph -ErrorAction SilentlyContinue

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All","Domain.Read.All","Group.ReadWrite.All" -NoWelcome

# Function to generate a house-coloured avatar locally (Python PIL) and set as profile photo
function Set-UserProfilePhoto {
    param(
        [string]$UserId,
        [string]$DisplayName,
        [string]$House
    )

    # House colors (hex, no leading #)
    $houseColors = @{
        "Gryffindor" = "740001"   # Scarlet red
        "Slytherin"  = "1a472a"   # Dark green
        "Ravenclaw"  = "0e1a40"   # Dark blue
        "Hufflepuff" = "f0c75e"   # Yellow
    }

    $color = $houseColors[$House]
    if (-not $color) { $color = "555555" }

    # Two-letter initials from display name
    $initials = ($DisplayName -split '\s+' | ForEach-Object { $_[0] }) -join ''
    if ($initials.Length -gt 2) { $initials = $initials.Substring(0, 2) }
    $initials = $initials.ToUpper()

    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$UserId.png")
    $pyScript = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "gen_avatar.py")

    try {
        # Write Python image-generation script to a temp file
        # Single-quoted here-string so PowerShell does not expand $ signs
        $pyCode = @'
from PIL import Image, ImageDraw, ImageFont
import sys

hex_color, initials, out = sys.argv[1], sys.argv[2], sys.argv[3]
r = int(hex_color[0:2], 16)
g = int(hex_color[2:4], 16)
b = int(hex_color[4:6], 16)

img  = Image.new("RGB", (512, 512), (r, g, b))
draw = ImageDraw.Draw(img)

brightness = (r * 299 + g * 587 + b * 114) / 1000
text_color = (0, 0, 0) if brightness > 128 else (255, 255, 255)

font = None
for fp in ["/System/Library/Fonts/Helvetica.ttc",
           "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
           "/Library/Fonts/Arial.ttf"]:
    try:
        font = ImageFont.truetype(fp, 200)
        break
    except Exception:
        pass
if font is None:
    font = ImageFont.load_default()

bbox = draw.textbbox((0, 0), initials, font=font)
w = bbox[2] - bbox[0]
h = bbox[3] - bbox[1]
draw.text(((512 - w) // 2 - bbox[0], (512 - h) // 2 - bbox[1]),
          initials, fill=text_color, font=font)
img.save(out, "PNG")
'@
        $pyCode | Set-Content -Path $pyScript -Encoding utf8 -Force

        # Generate the house-coloured avatar via Python
        python3 $pyScript $color $initials $tempFile 2>&1 | Out-Null

        if (-not (Test-Path $tempFile)) {
            throw "Python image generation failed — output file not created."
        }

        # Upload as profile photo (ContentType required by the Graph SDK)
        Set-MgUserPhotoContent -UserId $UserId -InFile $tempFile -ContentType "image/png" -ErrorAction Stop

        return $true
    }
    catch {
        Write-Host "   ⚠️  Could not set profile photo: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
    finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path $pyScript) { Remove-Item $pyScript -Force -ErrorAction SilentlyContinue }
    }
}

# Get the domain name
$domain = (Get-MgDomain | Where-Object {$_.IsDefault -eq $true}).Id

# Generate a random password for all users (displayed once at runtime, never stored in script)
function New-RandomPassword {
    $upper  = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lower  = 'abcdefghijklmnopqrstuvwxyz'
    $digits = '0123456789'
    $special = '!@#$%&*?'
    
    # Ensure at least one of each required type
    $password  = $upper[(Get-Random -Maximum $upper.Length)]
    $password += $lower[(Get-Random -Maximum $lower.Length)]
    $password += $digits[(Get-Random -Maximum $digits.Length)]
    $password += $special[(Get-Random -Maximum $special.Length)]
    
    # Fill remaining 12 chars from all character sets
    $allChars = $upper + $lower + $digits + $special
    for ($i = 0; $i -lt 12; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }
    
    # Shuffle the password so required chars aren't always at the start
    return -join ($password.ToCharArray() | Get-Random -Count $password.Length)
}

$generatedPassword = New-RandomPassword

$PasswordProfile = @{
    Password = $generatedPassword
    ForceChangePasswordNextSignIn = $true
}

# Define Harry Potter users with magical job titles and houses
$users = @(
    @{
        GivenName = "Harry"
        Surname = "Potter"
        JobTitle = "Chief Auror"
        Department = "Magical Law Enforcement"
        Office = "Gryffindor"
    },
    @{
        GivenName = "Hermione"
        Surname = "Granger"
        JobTitle = "Minister of Magic"
        Department = "Ministry Leadership"
        Office = "Gryffindor"
    },
    @{
        GivenName = "Ron"
        Surname = "Weasley"
        JobTitle = "Senior Auror"
        Department = "Magical Law Enforcement"
        Office = "Gryffindor"
    },
    @{
        GivenName = "Albus"
        Surname = "Dumbledore"
        JobTitle = "Headmaster"
        Department = "Hogwarts Administration"
        Office = "Gryffindor"
    },
    @{
        GivenName = "Minerva"
        Surname = "McGonagall"
        JobTitle = "Transfiguration Professor"
        Department = "Hogwarts Faculty"
        Office = "Gryffindor"
    },
    @{
        GivenName = "Draco"
        Surname = "Malfoy"
        JobTitle = "Potions Master"
        Department = "Hogwarts Faculty"
        Office = "Slytherin"
    },
    @{
        GivenName = "Severus"
        Surname = "Snape"
        JobTitle = "Defense Against Dark Arts Professor"
        Department = "Hogwarts Faculty"
        Office = "Slytherin"
    },
    @{
        GivenName = "Bellatrix"
        Surname = "Lestrange"
        JobTitle = "Dark Arts Specialist"
        Department = "Azkaban Reformed Division"
        Office = "Slytherin"
    },
    @{
        GivenName = "Lucius"
        Surname = "Malfoy"
        JobTitle = "Wizengamot Council Member"
        Department = "Magical Governance"
        Office = "Slytherin"
    },
    @{
        GivenName = "Horace"
        Surname = "Slughorn"
        JobTitle = "Potions Research Director"
        Department = "Magical Research"
        Office = "Slytherin"
    },
    @{
        GivenName = "Dolores"
        Surname = "Umbridge"
        JobTitle = "Senior Undersecretary to the Minister"
        Department = "Ministry Leadership"
        Office = "Slytherin"
    },
    @{
        GivenName = "Luna"
        Surname = "Lovegood"
        JobTitle = "Magizoologist"
        Department = "Magical Creatures Division"
        Office = "Ravenclaw"
    },
    @{
        GivenName = "Cho"
        Surname = "Chang"
        JobTitle = "Quidditch League Commissioner"
        Department = "Magical Sports"
        Office = "Ravenclaw"
    },
    @{
        GivenName = "Filius"
        Surname = "Flitwick"
        JobTitle = "Charms Professor"
        Department = "Hogwarts Faculty"
        Office = "Ravenclaw"
    },
    @{
        GivenName = "Gilderoy"
        Surname = "Lockhart"
        JobTitle = "Memory Charm Researcher"
        Department = "St. Mungo's Hospital"
        Office = "Ravenclaw"
    },
    @{
        GivenName = "Sybill"
        Surname = "Trelawney"
        JobTitle = "Divination Professor"
        Department = "Hogwarts Faculty"
        Office = "Ravenclaw"
    },
    @{
        GivenName = "Neville"
        Surname = "Longbottom"
        JobTitle = "Herbology Professor"
        Department = "Hogwarts Faculty"
        Office = "Gryffindor"
    },
    @{
        GivenName = "Cedric"
        Surname = "Diggory"
        JobTitle = "Triwizard Tournament Coordinator"
        Department = "Magical Games & Sports"
        Office = "Hufflepuff"
    },
    @{
        GivenName = "Newt"
        Surname = "Scamander"
        JobTitle = "Chief Magizoologist"
        Department = "Magical Creatures Division"
        Office = "Hufflepuff"
    },
    @{
        GivenName = "Pomona"
        Surname = "Sprout"
        JobTitle = "Herbology Research Director"
        Department = "Hogwarts Faculty"
        Office = "Hufflepuff"
    },
    @{
        GivenName = "Nymphadora"
        Surname = "Tonks"
        JobTitle = "Metamorphmagus Specialist"
        Department = "Magical Law Enforcement"
        Office = "Hufflepuff"
    }
)

# Create each user
$successCount = 0
$skipCount = 0
$failCount = 0

Write-Host "`nCreating 21 Harry Potter users..." -ForegroundColor Green
Write-Host "Default Password: $generatedPassword (must be changed on first sign-in)`n" -ForegroundColor Yellow

foreach ($user in $users) {
    $displayName = "$($user.GivenName) $($user.Surname)"
    $mailNickname = "$($user.GivenName).$($user.Surname)".ToLower()
    $userPrincipalName = "$mailNickname@$domain"
    
    try {
        # Check if user already exists
        $existingUser = Get-MgUser -Filter "userPrincipalName eq '$userPrincipalName'" -ErrorAction SilentlyContinue
        
        if ($existingUser) {
            Write-Host "⏭️  Already exists: $displayName — updating photo..." -ForegroundColor Gray
            $photoSet = Set-UserProfilePhoto -UserId $existingUser.Id -DisplayName $displayName -House $user.Office
            if ($photoSet) {
                Write-Host "   ✅ House photo set!" -ForegroundColor Green
            }
            Write-Host ""
            $skipCount++
        } else {
            # Create the user
            $userParams = @{
                DisplayName = $displayName
                GivenName = $user.GivenName
                Surname = $user.Surname
                UserPrincipalName = $userPrincipalName
                MailNickname = $mailNickname
                JobTitle = $user.JobTitle
                Department = $user.Department
                OfficeLocation = $user.Office
                UsageLocation = "US"
                PasswordProfile = $PasswordProfile
                AccountEnabled = $true
            }
            
            $newUser = New-MgUser @userParams
            
            Write-Host "✅ Created: $displayName" -ForegroundColor Green
            Write-Host "   UPN: $userPrincipalName" -ForegroundColor Gray
            Write-Host "   Job Title: $($user.JobTitle)" -ForegroundColor Gray
            Write-Host "   House: $($user.Office)" -ForegroundColor Gray
            
            # Set profile photo
            Write-Host "   📸 Setting profile photo..." -ForegroundColor Cyan
            $photoSet = Set-UserProfilePhoto -UserId $newUser.Id -DisplayName $displayName -House $user.Office
            if ($photoSet) {
                Write-Host "   ✅ Profile photo set!" -ForegroundColor Green
            }
            Write-Host ""
            
            $successCount++
        }
    }
    catch {
        Write-Host "❌ Failed to create: $displayName" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        $failCount++
    }
}

# ═══════════════════════════════════════════════════════════════
# Create Harry Potter Dynamic Groups (one per Hogwarts house)
# ═══════════════════════════════════════════════════════════════
Write-Host "`n═══════════════════════════════════════" -ForegroundColor Magenta
Write-Host "Creating Hogwarts House Dynamic Groups..." -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════`n" -ForegroundColor Magenta

$dynamicGroups = @(
    @{
        DisplayName    = "🦁 Gryffindor – Dynamic User Group"
        Description    = "Dynamic group for all Gryffindor house members. Membership is based on Office = Gryffindor."
        MailNickname   = "gryffindor-dynamic"
        MembershipRule = '(user.physicalDeliveryOfficeName -eq "Gryffindor")'
    },
    @{
        DisplayName    = "🐍 Slytherin – Dynamic User Group"
        Description    = "Dynamic group for all Slytherin house members. Membership is based on Office = Slytherin."
        MailNickname   = "slytherin-dynamic"
        MembershipRule = '(user.physicalDeliveryOfficeName -eq "Slytherin")'
    },
    @{
        DisplayName    = "🦅 Ravenclaw – Dynamic User Group"
        Description    = "Dynamic group for all Ravenclaw house members. Membership is based on Office = Ravenclaw."
        MailNickname   = "ravenclaw-dynamic"
        MembershipRule = '(user.physicalDeliveryOfficeName -eq "Ravenclaw")'
    },
    @{
        DisplayName    = "🦡 Hufflepuff – Dynamic User Group"
        Description    = "Dynamic group for all Hufflepuff house members. Membership is based on Office = Hufflepuff."
        MailNickname   = "hufflepuff-dynamic"
        MembershipRule = '(user.physicalDeliveryOfficeName -eq "Hufflepuff")'
    }
)

$groupSuccessCount = 0
$groupSkipCount = 0
$groupFailCount = 0

foreach ($group in $dynamicGroups) {
    try {
        # Check if the group already exists
        $existingGroup = Get-MgGroup -Filter "displayName eq '$($group.DisplayName)'" -ErrorAction SilentlyContinue
        
        if ($existingGroup) {
            Write-Host "⚠️  Group already exists: $($group.DisplayName)" -ForegroundColor Yellow
            Write-Host "   ID: $($existingGroup.Id)" -ForegroundColor Gray
            Write-Host ""
            $groupSkipCount++
        } else {
            $groupParams = @{
                DisplayName                   = $group.DisplayName
                Description                   = $group.Description
                MailEnabled                   = $false
                MailNickname                  = $group.MailNickname
                SecurityEnabled               = $true
                GroupTypes                    = @("DynamicMembership")
                MembershipRule                = $group.MembershipRule
                MembershipRuleProcessingState = "On"
            }

            $newGroup = New-MgGroup -BodyParameter $groupParams
            Write-Host "✅ Created: $($group.DisplayName)" -ForegroundColor Green
            Write-Host "   ID: $($newGroup.Id)" -ForegroundColor Gray
            Write-Host "   Rule: $($group.MembershipRule)" -ForegroundColor Gray
            Write-Host ""
            $groupSuccessCount++
        }
    }
    catch {
        Write-Host "❌ Failed to create: $($group.DisplayName)" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        $groupFailCount++
    }
}

Write-Host "Dynamic Groups Summary:" -ForegroundColor Magenta
Write-Host "  ✅ Created: $groupSuccessCount" -ForegroundColor Green
Write-Host "  ⚠️  Already existed: $groupSkipCount" -ForegroundColor Yellow
Write-Host "  ❌ Failed: $groupFailCount" -ForegroundColor Red
Write-Host ""

# Summary
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "✅ Created: $successCount users" -ForegroundColor Green
Write-Host "⏭️  Skipped (already existed): $skipCount users" -ForegroundColor Gray
Write-Host "❌ Failed: $failCount users" -ForegroundColor Red
Write-Host "✅ Dynamic groups created/verified: $($groupSuccessCount + $groupSkipCount)" -ForegroundColor Green
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
if ($successCount -gt 0) {
    Write-Host "`nDefault Password: $generatedPassword" -ForegroundColor Yellow
    Write-Host "⚠️  SAVE THIS PASSWORD NOW - it is not stored anywhere!" -ForegroundColor Red
    Write-Host "Users will be required to change password on first sign-in`n" -ForegroundColor Yellow
} else {
    Write-Host "`nNo new users created — no password to save.`n" -ForegroundColor Gray
}

# Disconnect
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Cyan
