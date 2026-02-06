# Create Harry Potter Users in Entra ID
# Author: Magical IT Department
# Date: February 1, 2026

# Ensure Microsoft.Graph module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    Write-Host "Installing Microsoft.Graph.Users module..." -ForegroundColor Yellow
    Install-Module Microsoft.Graph.Users -Scope CurrentUser -Force
}

# Connect to Microsoft Graph
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Get the domain name
$domain = (Get-MgDomain | Where-Object {$_.IsDefault -eq $true}).Id

# Default password for all users (they'll be required to change on first sign-in)
$PasswordProfile = @{
    Password = "Hogwarts2026!"
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
        Office = "Hufflepuff"
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
$failCount = 0

Write-Host "`nCreating 20 Harry Potter users..." -ForegroundColor Green
Write-Host "Default Password: Hogwarts2026! (must be changed on first sign-in)`n" -ForegroundColor Yellow

foreach ($user in $users) {
    $displayName = "$($user.GivenName) $($user.Surname)"
    $mailNickname = "$($user.GivenName).$($user.Surname)".ToLower()
    $userPrincipalName = "$mailNickname@$domain"
    
    try {
        # Check if user already exists
        $existingUser = Get-MgUser -Filter "userPrincipalName eq '$userPrincipalName'" -ErrorAction SilentlyContinue
        
        if ($existingUser) {
            Write-Host "⚠️  User already exists: $displayName ($userPrincipalName)" -ForegroundColor Yellow
            $failCount++
        } else {
            # Create the user
            $newUser = New-MgUser -DisplayName $displayName `
                -GivenName $user.GivenName `
                -Surname $user.Surname `
                -UserPrincipalName $userPrincipalName `
                -MailNickname $mailNickname `
                -JobTitle $user.JobTitle `
                -Department $user.Department `
                -OfficeLocation $user.Office `
                -UsageLocation "US" `
                -PasswordProfile $PasswordProfile `
                -AccountEnabled $true
            
            Write-Host "✅ Created: $displayName" -ForegroundColor Green
            Write-Host "   UPN: $userPrincipalName" -ForegroundColor Gray
            Write-Host "   Job Title: $($user.JobTitle)" -ForegroundColor Gray
            Write-Host "   House: $($user.Office)" -ForegroundColor Gray
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

# Summary
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "✅ Successfully created: $successCount users" -ForegroundColor Green
Write-Host "❌ Failed/Skipped: $failCount users" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`nDefault Password: Hogwarts2026!" -ForegroundColor Yellow
Write-Host "Users will be required to change password on first sign-in`n" -ForegroundColor Yellow

# Disconnect
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Cyan
