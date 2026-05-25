# Create Harry Potter GUEST Users in Entra ID (B2B Invitations)
# Author: Magical IT Department
# Date: March 5, 2026
# Description: Invites Harry Potter characters from external wizarding schools
#              and organisations as B2B guest users in the tenant.

# ═══════════════════════════════════════════════════════════════
# MODULE CHECK
# ═══════════════════════════════════════════════════════════════
$requiredModules = @(
    "Microsoft.Graph.Users",
    "Microsoft.Graph.Identity.SignIns",
    "Microsoft.Graph.Groups"
)
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module module..." -ForegroundColor Yellow
        Install-Module $module -Scope CurrentUser -Force
    }
}

# ═══════════════════════════════════════════════════════════════
# CONNECT TO MICROSOFT GRAPH
# ═══════════════════════════════════════════════════════════════
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.Invite.All","User.ReadWrite.All","Directory.ReadWrite.All","Group.ReadWrite.All" -NoWelcome

# Get the default domain for display purposes
$domain = (Get-MgDomain | Where-Object { $_.IsDefault -eq $true }).Id
Write-Host "Target tenant: $domain`n" -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Set-GuestProfilePhoto {
    param(
        [string]$UserId,
        [string]$DisplayName,
        [string]$Organisation
    )

    # Organisation accent colours
    $orgColors = @{
        "Beauxbatons Academy"     = "6BA4D9"  # Powder blue
        "Durmstrang Institute"    = "8B0000"  # Blood red
        "Ilvermorny School"       = "9B1B30"  # Cranberry
        "Ministry of Magic (FR)"  = "002395"  # French blue
        "Ministry of Magic (BG)"  = "00966E"  # Bulgarian green
        "MACUSA"                  = "B8860B"  # Dark goldenrod
        "Magical Congress"        = "B8860B"  # Same as MACUSA
    }

    $color = $orgColors[$Organisation]
    if (-not $color) { $color = "555555" }

    $avatarUrl = "https://ui-avatars.com/api/?name=$($DisplayName.Replace(' ','+'))&size=512&background=$color&color=fff&bold=true&format=png"

    try {
        $tempFile = [System.IO.Path]::GetTempFileName() + ".png"
        Invoke-WebRequest -Uri $avatarUrl -OutFile $tempFile -ErrorAction Stop
        Set-MgUserPhotoContent -UserId $UserId -InFile $tempFile -ErrorAction Stop
        Remove-Item $tempFile -Force
        return $true
    }
    catch {
        Write-Host "   ⚠️  Could not set profile photo: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

# ═══════════════════════════════════════════════════════════════
# DEFINE GUEST USERS
# External characters from other wizarding schools & organisations
# Each needs a fake external email (the invitation target)
# ═══════════════════════════════════════════════════════════════

$guestUsers = @(
    # ── Beauxbatons Academy of Magic (France) ──
    @{
        GivenName    = "Fleur"
        Surname      = "Delacour"
        Email        = "fleur.delacour@beauxbatons.edu"
        JobTitle     = "Triwizard Champion & Curse Breaker"
        Department   = "Beauxbatons Alumni"
        Organisation = "Beauxbatons Academy"
        CompanyName  = "Beauxbatons Academy of Magic"
    },
    @{
        GivenName    = "Gabrielle"
        Surname      = "Delacour"
        Email        = "gabrielle.delacour@beauxbatons.edu"
        JobTitle     = "Junior Liaison Officer"
        Department   = "International Magical Cooperation"
        Organisation = "Beauxbatons Academy"
        CompanyName  = "Beauxbatons Academy of Magic"
    },
    @{
        GivenName    = "Olympe"
        Surname      = "Maxime"
        Email        = "olympe.maxime@beauxbatons.edu"
        JobTitle     = "Headmistress"
        Department   = "Beauxbatons Administration"
        Organisation = "Beauxbatons Academy"
        CompanyName  = "Beauxbatons Academy of Magic"
    },

    # ── Durmstrang Institute (Northern Europe) ──
    @{
        GivenName    = "Viktor"
        Surname      = "Krum"
        Email        = "viktor.krum@durmstrang.edu"
        JobTitle     = "Triwizard Champion & Professional Seeker"
        Department   = "Durmstrang Alumni"
        Organisation = "Durmstrang Institute"
        CompanyName  = "Durmstrang Institute"
    },
    @{
        GivenName    = "Igor"
        Surname      = "Karkaroff"
        Email        = "igor.karkaroff@durmstrang.edu"
        JobTitle     = "Former Headmaster"
        Department   = "Durmstrang Administration"
        Organisation = "Durmstrang Institute"
        CompanyName  = "Durmstrang Institute"
    },

    # ── Ilvermorny School of Witchcraft and Wizardry (USA) ──
    @{
        GivenName    = "Porpentina"
        Surname      = "Goldstein"
        Email        = "tina.goldstein@ilvermorny.edu"
        JobTitle     = "Senior Auror"
        Department   = "MACUSA Law Enforcement"
        Organisation = "Ilvermorny School"
        CompanyName  = "Ilvermorny School of Witchcraft and Wizardry"
    },
    @{
        GivenName    = "Queenie"
        Surname      = "Goldstein"
        Email        = "queenie.goldstein@ilvermorny.edu"
        JobTitle     = "Legilimens Specialist"
        Department   = "MACUSA Intelligence"
        Organisation = "Ilvermorny School"
        CompanyName  = "Ilvermorny School of Witchcraft and Wizardry"
    },
    @{
        GivenName    = "Newt"
        Surname      = "Scamander-US"
        Email        = "newt.scamander@macusa.gov"
        JobTitle     = "Visiting Magizoologist"
        Department   = "International Magical Cooperation"
        Organisation = "MACUSA"
        CompanyName  = "Magical Congress of the United States"
    },

    # ── Other External Collaborators ──
    @{
        GivenName    = "Nicolas"
        Surname      = "Flamel"
        Email        = "nicolas.flamel@alchemy-guild.eu"
        JobTitle     = "Master Alchemist"
        Department   = "Alchemical Research"
        Organisation = "Beauxbatons Academy"
        CompanyName  = "European Alchemy Guild"
    },
    @{
        GivenName    = "Gellert"
        Surname      = "Grindelwald"
        Email        = "gellert.grindelwald@durmstrang.edu"
        JobTitle     = "Dark Arts Historian (Monitored)"
        Department   = "Historical Research"
        Organisation = "Durmstrang Institute"
        CompanyName  = "Durmstrang Institute"
    },
    @{
        GivenName    = "Bathilda"
        Surname      = "Bagshot"
        Email        = "bathilda.bagshot@magical-history.eu"
        JobTitle     = "Magical Historian"
        Department   = "Historical Research"
        Organisation = "Beauxbatons Academy"
        CompanyName  = "European Magical History Society"
    },
    @{
        GivenName    = "Seraphina"
        Surname      = "Picquery"
        Email        = "seraphina.picquery@macusa.gov"
        JobTitle     = "Former MACUSA President"
        Department   = "Magical Governance"
        Organisation = "MACUSA"
        CompanyName  = "Magical Congress of the United States"
    }
)

# ═══════════════════════════════════════════════════════════════
# CREATE GUEST USERS VIA B2B INVITATION
# ═══════════════════════════════════════════════════════════════

$successCount = 0
$skipCount = 0
$failCount = 0

Write-Host "═══════════════════════════════════════" -ForegroundColor Magenta
Write-Host "Inviting $($guestUsers.Count) Harry Potter Guest Users..." -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════`n" -ForegroundColor Magenta

foreach ($guest in $guestUsers) {
    $displayName = "$($guest.GivenName) $($guest.Surname)"

    try {
        # Check if a guest with this email already exists
        $encodedEmail = $guest.Email.Replace("'", "''")
        $existingGuest = Get-MgUser -Filter "mail eq '$encodedEmail' or otherMails/any(m:m eq '$encodedEmail')" -ErrorAction SilentlyContinue

        if ($existingGuest) {
            Write-Host "⏭️  Skipping (already exists): $displayName ($($guest.Email))" -ForegroundColor Gray
            Write-Host ""
            $skipCount++
            continue
        }

        # Send the B2B invitation
        $invitationParams = @{
            InvitedUserDisplayName  = $displayName
            InvitedUserEmailAddress = $guest.Email
            InviteRedirectUrl       = "https://myapplications.microsoft.com"
            SendInvitationMessage   = $false  # Don't send email (fake addresses)
            InvitedUserType         = "Guest"
        }

        $invitation = New-MgInvitation -BodyParameter $invitationParams
        $guestUserId = $invitation.InvitedUser.Id

        Write-Host "✅ Invited: $displayName" -ForegroundColor Green
        Write-Host "   Email: $($guest.Email)" -ForegroundColor Gray
        Write-Host "   User ID: $guestUserId" -ForegroundColor Gray
        Write-Host "   Company: $($guest.CompanyName)" -ForegroundColor Gray

        # Update the guest user's profile with job details
        $updateParams = @{
            GivenName      = $guest.GivenName
            Surname        = $guest.Surname
            JobTitle       = $guest.JobTitle
            Department     = $guest.Department
            CompanyName    = $guest.CompanyName
            OfficeLocation = $guest.Organisation
        }

        Update-MgUser -UserId $guestUserId -BodyParameter $updateParams
        Write-Host "   📝 Profile updated (Job: $($guest.JobTitle))" -ForegroundColor Cyan

        # Set profile photo
        Write-Host "   📸 Setting profile photo..." -ForegroundColor Cyan
        Start-Sleep -Seconds 2  # Brief pause for user provisioning to complete
        $photoSet = Set-GuestProfilePhoto -UserId $guestUserId -DisplayName $displayName -Organisation $guest.Organisation
        if ($photoSet) {
            Write-Host "   ✅ Profile photo set!" -ForegroundColor Green
        }
        Write-Host ""

        $successCount++
    }
    catch {
        Write-Host "❌ Failed to invite: $displayName" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        $failCount++
    }
}

# ═══════════════════════════════════════════════════════════════
# CREATE DYNAMIC GROUP FOR ALL GUEST USERS
# ═══════════════════════════════════════════════════════════════

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Magenta
Write-Host "Creating Guest User Dynamic Groups..." -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════`n" -ForegroundColor Magenta

$guestGroups = @(
    @{
        DisplayName    = "🌍 External Wizarding Guests – All"
        Description    = "Dynamic group containing all B2B guest users (external wizarding school collaborators)."
        MailNickname   = "external-wizarding-guests"
        MembershipRule = '(user.userType -eq "Guest")'
    },
    @{
        DisplayName    = "🏔️ Beauxbatons Guests"
        Description    = "Dynamic group for guest users from Beauxbatons Academy of Magic."
        MailNickname   = "beauxbatons-guests"
        MembershipRule = '(user.userType -eq "Guest") and (user.companyName -eq "Beauxbatons Academy of Magic")'
    },
    @{
        DisplayName    = "⛵ Durmstrang Guests"
        Description    = "Dynamic group for guest users from Durmstrang Institute."
        MailNickname   = "durmstrang-guests"
        MembershipRule = '(user.userType -eq "Guest") and (user.companyName -eq "Durmstrang Institute")'
    },
    @{
        DisplayName    = "🦅 Ilvermorny & MACUSA Guests"
        Description    = "Dynamic group for guest users from Ilvermorny School and MACUSA."
        MailNickname   = "ilvermorny-macusa-guests"
        MembershipRule = '(user.userType -eq "Guest") and ((user.companyName -eq "Ilvermorny School of Witchcraft and Wizardry") or (user.companyName -eq "Magical Congress of the United States"))'
    }
)

$groupSuccessCount = 0
$groupSkipCount = 0
$groupFailCount = 0

foreach ($group in $guestGroups) {
    try {
        $existingGroup = Get-MgGroup -Filter "displayName eq '$($group.DisplayName)'" -ErrorAction SilentlyContinue

        if ($existingGroup) {
            Write-Host "⚠️  Group already exists: $($group.DisplayName)" -ForegroundColor Yellow
            Write-Host "   ID: $($existingGroup.Id)" -ForegroundColor Gray
            Write-Host ""
            $groupSkipCount++
        }
        else {
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

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Guest User Summary:" -ForegroundColor Cyan
Write-Host "  ✅ Invited: $successCount guests" -ForegroundColor Green
Write-Host "  ⏭️  Skipped (already existed): $skipCount guests" -ForegroundColor Gray
Write-Host "  ❌ Failed: $failCount guests" -ForegroundColor Red
Write-Host "" -ForegroundColor Cyan
Write-Host "Dynamic Groups Summary:" -ForegroundColor Magenta
Write-Host "  ✅ Created: $groupSuccessCount groups" -ForegroundColor Green
Write-Host "  ⚠️  Already existed: $groupSkipCount groups" -ForegroundColor Yellow
Write-Host "  ❌ Failed: $groupFailCount groups" -ForegroundColor Red
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "📧 Note: Invitation emails were NOT sent (SendInvitationMessage = false)" -ForegroundColor Yellow
Write-Host "   Guest users can accept by visiting: https://myapplications.microsoft.com" -ForegroundColor Yellow
Write-Host "   Or they will be prompted when accessing any shared resource in the tenant." -ForegroundColor Yellow
Write-Host ""

# Disconnect
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Cyan
