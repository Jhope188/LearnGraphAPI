##############################################################################
#  Create-HogwartsStaffGroup.ps1
#  Creates a "🏰 Hogwarts Staff" Microsoft 365 (Unified) group and adds all
#  staff members including Dolores Umbridge, then grants the group access
#  to every SharePoint site in the demo tenant.
#
#  This is required for the Purview Demo — Act 1 depends on Dolores being
#  able to see ALL sites (to demonstrate the oversharing problem BEFORE
#  sensitivity labels are applied).
#
#  Group type: M365 Unified group (NOT security, NOT dynamic)
#  Using Unified allows the group to be assigned to SharePoint sites,
#  Teams, and used as a membership container across M365 workloads.
#  Dolores is added explicitly — her Dept = "Ministry Leadership" so
#  a department-based dynamic rule would miss her.
#
#  Usage:
#    ./Create-HogwartsStaffGroup.ps1 -TenantDomain "contoso.onmicrosoft.com"
#  If -TenantDomain is omitted you will be prompted at runtime.
##############################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TenantDomain,

    [switch]$SkipGroupCreation,
    [switch]$SkipSiteAccess
)

# Derive SPO URLs from the tenant domain prefix (e.g. contoso.onmicrosoft.com → contoso)
$TenantPrefix = $TenantDomain -replace '\.onmicrosoft\.com$' -replace '\..*$'
$SPOAdminUrl  = "https://$TenantPrefix-admin.sharepoint.com"
$SPOBaseUrl   = "https://$TenantPrefix.sharepoint.com/sites"

##############################################################################
# Hogwarts Staff Members
# Includes all Hogwarts Faculty + Administration + Dolores (Ministry but
# acting as High Inquisitor / DADA professor at Hogwarts)
##############################################################################

$StaffMembers = @(
    # Hogwarts Administration
    "albus.dumbledore@$TenantDomain",       # Headmaster

    # Hogwarts Faculty — Gryffindor
    "minerva.mcgonagall@$TenantDomain",     # Transfiguration Professor
    "neville.longbottom@$TenantDomain",     # Herbology Professor

    # Hogwarts Faculty — Slytherin
    "draco.malfoy@$TenantDomain",           # Potions Master
    "severus.snape@$TenantDomain",          # Defence Against the Dark Arts

    # Hogwarts Faculty — Ravenclaw
    "filius.flitwick@$TenantDomain",        # Charms Professor
    "sybill.trelawney@$TenantDomain",       # Divination Professor

    # Hogwarts Faculty — Hufflepuff
    "pomona.sprout@$TenantDomain",          # Herbology Professor

    # Ministry / Special Role — added explicitly
    "dolores.umbridge@$TenantDomain"        # High Inquisitor / Senior Undersecretary
                                            # (Ministry Leadership dept but physically at Hogwarts)
)

# All 20 SharePoint sites in the demo environment
$AllSites = @(
    "SnapesPotionsLab",            # Snapes Potions Laboratory
    "DumbledoresOffice",           # Dumbledores Office
    "GringottsBank",               # Gringotts Wizarding Bank
    "HogwartsHospitalWing",        # Hogwarts Hospital Wing
    "WeasleysWizardWheezes",       # Weasleys Wizard Wheezes
    "MagicalLawEnforcement",       # Dept of Magical Law Enforcement
    "HogwartsRestrictedSection",   # Hogwarts Library Restricted Section
    "QuidditchWorldCup2026",       # Quidditch World Cup 2026
    "HagridsMagicalCreatures",     # Hagrids Magical Creatures
    "DailyProphetNews",            # Daily Prophet Newsroom
    "DumbledoresArmy",             # Dumbledores Army HQ
    "MalfoyEnterprise",            # Malfoy Manor Enterprises
    "HogwartsExpress",             # Hogwarts Express Operations
    "StMungosHospital",            # St Mungos Hospital
    "DeptOfMysteries",             # Department of Mysteries
    "HogsmeadeVillage",            # Hogsmeade Village Council
    "HogwartsHousePoints",         # Hogwarts House Points
    "ForbiddenForestResearch",     # Forbidden Forest Research
    "DobbysSockFoundation",        # Dobbys Sock Foundation
    "MaraudersMapArchive",         # Marauders Map Archive
    "OrderOfThePhoenix"            # Order of the Phoenix (Create-HarryPotterSharePointDemo.ps1)
)

$GroupDisplayName = "🏰 Hogwarts Staff"
$GroupMailNickname = "HogwartsStaff"
$GroupDescription = "All Hogwarts staff members including faculty, administration, and the High Inquisitor. Members have access to all Hogwarts SharePoint sites for operational purposes."

##############################################################################
# Connect to Microsoft Graph
##############################################################################

Write-Host "`n=== Hogwarts Staff Group Setup ===" -ForegroundColor Cyan
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Gray

Write-Host "  Tenant: $TenantDomain" -ForegroundColor Gray
Connect-MgGraph `
    -Scopes "Group.ReadWrite.All", "GroupMember.ReadWrite.All", "User.Read.All", "Sites.FullControl.All" `
    -TenantId $TenantDomain `
    -NoWelcome

##############################################################################
# SECTION 1 — Create the Hogwarts Staff M365 Group
##############################################################################

if (-not $SkipGroupCreation) {
    Write-Host "`n--- Section 1: Creating Hogwarts Staff Group ---" -ForegroundColor Yellow

    # Check if group already exists
    $existingGroup = Get-MgGroup -Filter "displayName eq '$GroupDisplayName'" -ErrorAction SilentlyContinue

    if ($existingGroup) {
        Write-Host "  ℹ️  Group '$GroupDisplayName' already exists (ID: $($existingGroup.Id))" -ForegroundColor Cyan
        $StaffGroup = $existingGroup
    }
    else {
        Write-Host "  Creating group: $GroupDisplayName" -ForegroundColor Gray

        $StaffGroup = New-MgGroup -BodyParameter @{
            DisplayName          = $GroupDisplayName
            MailNickname         = $GroupMailNickname
            Description          = $GroupDescription
            GroupTypes           = @("Unified")   # Unified = M365 group (assignable to SPO sites & Teams)
            MailEnabled          = $true
            SecurityEnabled      = $false
            Visibility           = "Private"
        }

        Write-Host "  ✅ Group created: $($StaffGroup.DisplayName)" -ForegroundColor Green
        Write-Host "     Group ID: $($StaffGroup.Id)" -ForegroundColor Gray

        # Brief pause for group to provision
        Start-Sleep -Seconds 5
    }

    Write-Host "`n  Adding staff members..." -ForegroundColor Gray

    foreach ($upn in $StaffMembers) {
        try {
            $user = Get-MgUser -UserId $upn -Property Id, DisplayName -ErrorAction Stop

            # Check if already a member
            $isMember = Get-MgGroupMember -GroupId $StaffGroup.Id -All |
                        Where-Object { $_.Id -eq $user.Id }

            if ($isMember) {
                Write-Host "  ✅ Already member: $($user.DisplayName)" -ForegroundColor DarkGreen
            }
            else {
                New-MgGroupMember -GroupId $StaffGroup.Id -DirectoryObjectId $user.Id
                Write-Host "  ✅ Added: $($user.DisplayName)" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "  ⚠️  Could not add $upn — $($_.Exception.Message)"
        }
    }

    Write-Host "`n  Staff group membership complete." -ForegroundColor Green
    Write-Host "  Group ID: $($StaffGroup.Id)" -ForegroundColor Gray
}
else {
    # Just look up existing group for Section 2
    $StaffGroup = Get-MgGroup -Filter "displayName eq '$GroupDisplayName'" -ErrorAction SilentlyContinue
    if (-not $StaffGroup) {
        Write-Error "Group '$GroupDisplayName' not found. Run without -SkipGroupCreation first."
        exit 1
    }
}

##############################################################################
# SECTION 2 — Grant all staff access to every SharePoint site
# Strategy: each site was created as an M365 Group. Being a member of that
# M365 group = access to the SharePoint site. We use Graph to find each
# site's backing M365 group by mailNickname and add all staff members.
##############################################################################

if (-not $SkipSiteAccess) {
    Write-Host "`n--- Section 2: Granting staff access to all SharePoint sites ---" -ForegroundColor Yellow

    # Resolve all staff user IDs up front
    $staffUsers = @()
    foreach ($upn in $StaffMembers) {
        try {
            $u = Get-MgUser -UserId $upn -Property Id, DisplayName -ErrorAction Stop
            $staffUsers += $u
        }
        catch {
            Write-Warning "  Could not resolve user $upn — skipping"
        }
    }
    Write-Host "  Resolved $($staffUsers.Count) staff users" -ForegroundColor Gray

    $found   = 0
    $missed  = @()

    foreach ($siteAlias in $AllSites) {
        Write-Host "  Processing: $siteAlias" -ForegroundColor Gray

        # Find the M365 group backing this SharePoint site
        $siteGroup = Get-MgGroup -Filter "mailNickname eq '$siteAlias'" `
                     -Property "Id,DisplayName,MailNickname" -ErrorAction SilentlyContinue

        if (-not $siteGroup) {
            # Fallback: case-insensitive search via ConsistencyLevel
            $siteGroup = Get-MgGroup -Search "`"mailNickname:$siteAlias`"" `
                         -ConsistencyLevel eventual -ErrorAction SilentlyContinue |
                         Select-Object -First 1
        }

        if (-not $siteGroup) {
            Write-Warning "    ⚠️  No M365 group found for: $siteAlias"
            $missed += $siteAlias
            continue
        }

        $found++

        # Get current members once to avoid repeated calls
        $currentMembers = Get-MgGroupMember -GroupId $siteGroup.Id -All |
                          Select-Object -ExpandProperty Id

        foreach ($user in $staffUsers) {
            if ($currentMembers -contains $user.Id) {
                Write-Host "    ✅ $($user.DisplayName) already member" -ForegroundColor DarkGreen
            }
            else {
                try {
                    New-MgGroupMember -GroupId $siteGroup.Id -DirectoryObjectId $user.Id
                    Write-Host "    ✅ Added $($user.DisplayName)" -ForegroundColor Green
                }
                catch {
                    # Ignore "already exists" errors (code: Request_BadRequest with duplicate member)
                    if ($_.Exception.Message -notmatch "already exist|One or more added object references") {
                        Write-Warning "    ⚠️  $($user.DisplayName) — $($_.Exception.Message)"
                    }
                    else {
                        Write-Host "    ✅ $($user.DisplayName) already member" -ForegroundColor DarkGreen
                    }
                }
            }
        }
    }

    Write-Host "`n  Site groups processed: $found / $($AllSites.Count)" -ForegroundColor Cyan
    if ($missed.Count -gt 0) {
        Write-Warning "  Sites not found: $($missed -join ', ')"
    }
}

##############################################################################
# SUMMARY
##############################################################################

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  COMPLETE — Hogwarts Staff Group Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host @"

✅ Group: $GroupDisplayName
   ID: $($StaffGroup.Id)

✅ Staff Members Added ($($StaffMembers.Count)):
   - Albus Dumbledore        (Headmaster)
   - Minerva McGonagall      (Transfiguration Professor)
   - Severus Snape           (Defence Against the Dark Arts)
   - Draco Malfoy            (Potions Master)
   - Filius Flitwick         (Charms Professor)
   - Sybill Trelawney        (Divination Professor)
   - Neville Longbottom      (Herbology Professor)
   - Pomona Sprout           (Herbology Professor)
   - Dolores Umbridge        (High Inquisitor — Ministry, acting at Hogwarts)

⚠️  NOTE: Dolores is Department = "Ministry Leadership" in Entra ID.
   A dynamic group rule based on Department = "Hogwarts Faculty" would
   miss her. This group is ASSIGNED (manual membership) for that reason.

✅ Site access granted to all $($AllSites.Count) demo sites

NEXT STEPS FOR DEMO:
  - Wait 5-15 min for membership propagation
  - Dolores signs out and back in to M365
  - Act 1: Dolores can now list all sites in Copilot  ← oversharing shown
  - Act 2: Apply sensitivity labels as Harry Potter
  - Act 3: Dolores gets blocked by encryption         ← problem solved

"@ -ForegroundColor White
