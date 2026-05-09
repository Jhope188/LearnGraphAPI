#Requires -Version 7.0
<#
.SYNOPSIS
  Create themed demo users (no licenses) and dynamic groups for popular franchises.
  Now tenant-proof: forces sign-in to the intended tenant and verifies the UPN domain.

.EXAMPLES
  .\Deploy-Franchise-Demo.ps1 -TenantDomain "contoso.onmicrosoft.com" -Franchise Shrek -CreateUsers -CreateGroups
  .\Deploy-Franchise-Demo.ps1 -TenantDomain "contoso.onmicrosoft.com" -Franchise LiloAndStitch -CreateGroups
  .\Deploy-Franchise-Demo.ps1 -TenantDomain "contoso.onmicrosoft.com" -Franchise DragonBallZ -CreateUsers `
      -AppOnly -TenantId "<tenant-guid>" -ClientId "<app-id>" -ClientSecret "<secret>"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$TenantDomain,

  [Parameter(Mandatory)]
  [ValidateSet('LotR','MyLittlePony','FastAndFurious','DragonBallZ','StarWars','Halo','HarryPotter','Witcher','LiloAndStitch','Shrek','StarTrek')]
  [string]$Franchise,

  [switch]$CreateUsers,
  [switch]$CreateGroups,

  [ValidatePattern('^[A-Z]{2}$')]
  [string]$UsageLocation = 'GB',

  [ValidateRange(10,128)]
  [int]$PasswordLength = 14,

  [string]$CsvPath,

  # Optional app-only auth
  [switch]$AppOnly,
  [string]$TenantId,
  [string]$ClientId,
  [string]$ClientSecret
)

# ---------- Module prep ----------
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
  Write-Host "Installing Microsoft.Graph..." -ForegroundColor Yellow
  Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber
}
Import-Module Microsoft.Graph.Users  -ErrorAction Stop
Import-Module Microsoft.Graph.Groups -ErrorAction Stop

# ---------- Robust connection & domain check ----------
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

$tenantHint = if ($TenantId) { $TenantId } else { $TenantDomain }

if ($AppOnly) {
  if (-not ($TenantId -and $ClientId -and $ClientSecret)) {
    throw "AppOnly requires -TenantId, -ClientId and -ClientSecret."
  }
  $sec  = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
  $cred = [pscredential]::new($ClientId,$sec)
  Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $cred -ContextScope Process | Out-Null
  Write-Host "Connected to Graph (AppOnly) for tenant $TenantId." -ForegroundColor Cyan
} else {
  Connect-MgGraph -TenantId $tenantHint -Scopes "User.ReadWrite.All","Directory.ReadWrite.All","Group.ReadWrite.All" -ContextScope Process | Out-Null
  $ctx = Get-MgContext
  Write-Host "Connected to Graph (Interactive). Tenant: $($ctx.TenantDomain) [$($ctx.TenantId)]" -ForegroundColor Cyan
}

# Verify the UPN domain exists and is verified
try {
  $domain = Get-MgDomain -All | Where-Object { $_.Id -ieq $TenantDomain -and $_.IsVerified }
} catch {
  throw "Could not enumerate domains. Ensure your permissions allow Directory.Read.All or use an account with sufficient rights."
}
if (-not $domain) {
  $ctx = Get-MgContext
  throw "The domain '$TenantDomain' is not verified in the signed-in tenant ($($ctx.TenantId), $($ctx.TenantDomain)). Use a verified domain owned by this tenant, or connect to the tenant that owns that domain."
}

# ---------- Helpers ----------
function New-TempPassword {
  param([int]$Length = 14)
  $lower   = @('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z')
  $upper   = @('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z')
  $digits  = @('0','1','2','3','4','5','6','7','8','9')
  $special = @('!','@','#','$','%','^','&','*','(',')','-','_','=','+')
  $chars = @()
  $chars += ( $lower   | Get-Random -Count 1 )
  $chars += ( $upper   | Get-Random -Count 1 )
  $chars += ( $digits  | Get-Random -Count 1 )
  $chars += ( $special | Get-Random -Count 1 )
  $pool = @(); $pool += $lower; $pool += $upper; $pool += $digits; $pool += $special
  $need = $Length - $chars.Count
  if ($need -gt 0) { $chars += ( $pool | Get-Random -Count $need ) }
  $chars = $chars | Get-Random -Count $chars.Count
  -join $chars
}

function Get-FranchiseRoster {
  param([Parameter(Mandatory)]
        [ValidateSet('LotR','MyLittlePony','FastAndFurious','DragonBallZ','StarWars','Halo','HarryPotter','Witcher','LiloAndStitch','Shrek','StarTrek')]$Name)
  switch ($Name) {
    'LotR' {
      @(
        @{GivenName='Aragorn'; Surname='Elessar'; DisplayName='Aragorn (Elessar)'; Alias='aragorn'; JobTitle='High King'; Department='Leadership'; OfficeLocation='Minas Tirith'}
        @{GivenName='Legolas'; Surname='Greenleaf'; DisplayName='Legolas'; Alias='legolas'; JobTitle='Chief Archer'; Department='Marksmen'; OfficeLocation='Mirkwood'}
        @{GivenName='Gimli'; Surname='Gloinson'; DisplayName='Gimli'; Alias='gimli'; JobTitle='Tunnel Ops Lead'; Department='Engineering'; OfficeLocation='Erebor'}
        @{GivenName='Frodo'; Surname='Baggins'; DisplayName='Frodo Baggins'; Alias='frodo'; JobTitle='Ringbearer'; Department='Special Projects'; OfficeLocation='The Shire'}
        @{GivenName='Samwise'; Surname='Gamgee'; DisplayName='Samwise Gamgee'; Alias='samwise'; JobTitle='Deputy Ringbearer'; Department='Special Projects'; OfficeLocation='The Shire'}
        @{GivenName='Gandalf'; Surname='TheGrey'; DisplayName='Gandalf'; Alias='gandalf'; JobTitle='Senior Advisor'; Department='Wizardry'; OfficeLocation='Middle-earth'}
        @{GivenName='Boromir'; Surname='Gondor'; DisplayName='Boromir'; Alias='boromir'; JobTitle='City Guard Captain'; Department='Defense'; OfficeLocation='Gondor'}
        @{GivenName='Galadriel'; Surname='Lorien'; DisplayName='Galadriel'; Alias='galadriel'; JobTitle='Lady of Light'; Department='Strategy'; OfficeLocation='Lothlorien'}
        @{GivenName='Elrond'; Surname='Halfelven'; DisplayName='Elrond'; Alias='elrond'; JobTitle='Chief Diplomat'; Department='Diplomacy'; OfficeLocation='Rivendell'}
        @{GivenName='Eowyn'; Surname='Rohan'; DisplayName='Éowyn'; Alias='eowyn'; JobTitle='Shieldmaiden'; Department='Operations'; OfficeLocation='Rohan'}
      )
    }
    'MyLittlePony' {
      @(
        @{GivenName='Twilight'; Surname='Sparkle'; DisplayName='Twilight Sparkle'; Alias='twilightsparkle'; JobTitle='Friendship Director'; Department='Leadership'; OfficeLocation='Ponyville'}
        @{GivenName='Rainbow'; Surname='Dash'; DisplayName='Rainbow Dash'; Alias='rainbowdash'; JobTitle='Aerial Response Lead'; Department='Flight Ops'; OfficeLocation='Cloudsdale'}
        @{GivenName='Pinkie'; Surname='Pie'; DisplayName='Pinkie Pie'; Alias='pinkiepie'; JobTitle='Culture & Events'; Department='Engagement'; OfficeLocation='Ponyville'}
        @{GivenName='Applejack'; Surname='Apple'; DisplayName='Applejack'; Alias='applejack'; JobTitle='Supply Chain Lead'; Department='Agriculture'; OfficeLocation='Sweet Apple Acres'}
        @{GivenName='Rarity'; Surname='Belle'; DisplayName='Rarity'; Alias='rarity'; JobTitle='Design Director'; Department='Creative'; OfficeLocation='Ponyville'}
        @{GivenName='Fluttershy'; Surname='Breeze'; DisplayName='Fluttershy'; Alias='fluttershy'; JobTitle='Animal Care Lead'; Department='Wildlife'; OfficeLocation='Ponyville'}
        @{GivenName='Celestia'; Surname='Princess'; DisplayName='Princess Celestia'; Alias='celestia'; JobTitle='Head of State'; Department='Royal Affairs'; OfficeLocation='Canterlot'}
        @{GivenName='Luna'; Surname='Princess'; DisplayName='Princess Luna'; Alias='luna'; JobTitle='Night Ops Director'; Department='Vigilance'; OfficeLocation='Canterlot'}
        @{GivenName='Starlight'; Surname='Glimmer'; DisplayName='Starlight Glimmer'; Alias='starlightglimmer'; JobTitle='Transformation Programs'; Department='Change Management'; OfficeLocation='Our Town'}
        @{GivenName='Spike'; Surname='Dragon'; DisplayName='Spike'; Alias='spike'; JobTitle='Communications Liaison'; Department='Diplomacy'; OfficeLocation='Ponyville'}
      )
    }
    'FastAndFurious' {
      @(
        @{GivenName='Dominic'; Surname='Toretto'; DisplayName='Dominic Toretto'; Alias='domtoretto'; JobTitle='Director, Family Ops'; Department='Operations'; OfficeLocation='Los Angeles'}
        @{GivenName='Brian'; Surname='OConnor'; DisplayName="Brian O'Conner"; Alias='brianoconnor'; JobTitle='Field Lead'; Department='Investigations'; OfficeLocation='Los Angeles'}
        @{GivenName='Letty'; Surname='Ortiz'; DisplayName='Letty Ortiz'; Alias='letty'; JobTitle='Mechanics Lead'; Department='Engineering'; OfficeLocation='Los Angeles'}
        @{GivenName='Mia'; Surname='Toretto'; DisplayName='Mia Toretto'; Alias='mia'; JobTitle='Ops Coordinator'; Department='Operations'; OfficeLocation='Los Angeles'}
        @{GivenName='Roman'; Surname='Pearce'; DisplayName='Roman Pearce'; Alias='roman'; JobTitle='Tactical Driver'; Department='Field Ops'; OfficeLocation='Miami'}
        @{GivenName='Tej'; Surname='Parker'; DisplayName='Tej Parker'; Alias='tej'; JobTitle='Systems Engineer'; Department='Technology'; OfficeLocation='Miami'}
        @{GivenName='Luke'; Surname='Hobbs'; DisplayName='Luke Hobbs'; Alias='hobbs'; JobTitle='Federal Liaison'; Department='Security'; OfficeLocation='Samoa'}
        @{GivenName='Deckard'; Surname='Shaw'; DisplayName='Deckard Shaw'; Alias='shaw'; JobTitle='Specialist'; Department='Covert Ops'; OfficeLocation='London'}
        @{GivenName='Han'; Surname='Lue'; DisplayName='Han Lue'; Alias='han'; JobTitle='Logistics Lead'; Department='Supply Chain'; OfficeLocation='Tokyo'}
        @{GivenName='Gisele'; Surname='Yashar'; DisplayName='Gisele Yashar'; Alias='gisele'; JobTitle='Intel Analyst'; Department='Intelligence'; OfficeLocation='Jerusalem'}
      )
    }
    'DragonBallZ' {
      @(
        @{GivenName='Goku'; Surname='Son'; DisplayName='Goku'; Alias='goku'; JobTitle='Combat Specialist'; Department='Martial Arts'; OfficeLocation='Mount Paozu'}
        @{GivenName='Vegeta'; Surname='Prince'; DisplayName='Vegeta'; Alias='vegeta'; JobTitle='Strategy Lead'; Department='Saiyan Affairs'; OfficeLocation='West City'}
        @{GivenName='Gohan'; Surname='Son'; DisplayName='Gohan'; Alias='gohan'; JobTitle='Research Fellow'; Department='Science'; OfficeLocation='Orange City'}
        @{GivenName='Piccolo'; Surname='Namek'; DisplayName='Piccolo'; Alias='piccolo'; JobTitle='Tactical Advisor'; Department='Defense'; OfficeLocation='The Lookout'}
        @{GivenName='Trunks'; Surname='Briefs'; DisplayName='Trunks'; Alias='trunks'; JobTitle='R&D Engineer'; Department='Technology'; OfficeLocation='West City'}
        @{GivenName='Bulma'; Surname='Briefs'; DisplayName='Bulma'; Alias='bulma'; JobTitle='CTO'; Department='Capsule Corp'; OfficeLocation='West City'}
        @{GivenName='Krillin'; Surname='Earth'; DisplayName='Krillin'; Alias='krillin'; JobTitle='Field Operative'; Department='Martial Arts'; OfficeLocation='Kame House'}
        @{GivenName='Frieza'; Surname='Emperor'; DisplayName='Frieza'; Alias='frieza'; JobTitle='External Stakeholder'; Department='Galactic Trade'; OfficeLocation='Planet 79'}
        @{GivenName='Android'; Surname='Eighteen'; DisplayName='Android 18'; Alias='android18'; JobTitle='Operations Specialist'; Department='Android Ops'; OfficeLocation='South City'}
        @{GivenName='Roshi'; Surname='Master'; DisplayName='Master Roshi'; Alias='roshi'; JobTitle='Senior Trainer'; Department='Training'; OfficeLocation='Kame House'}
      )
    }
    'StarWars' {
      @(
        @{GivenName='Luke'; Surname='Skywalker'; DisplayName='Luke Skywalker'; Alias='lukeskywalker'; JobTitle='Jedi Consultant'; Department='Defense'; OfficeLocation='Tatooine'}
        @{GivenName='Leia'; Surname='Organa'; DisplayName='Leia Organa'; Alias='leiaorgana'; JobTitle='Diplomacy Director'; Department='Diplomacy'; OfficeLocation='Alderaan'}
        @{GivenName='Han'; Surname='Solo'; DisplayName='Han Solo'; Alias='hansolo'; JobTitle='Logistics Captain'; Department='Logistics'; OfficeLocation='Corellia'}
        @{GivenName='Chewbacca'; Surname='Wookiee'; DisplayName='Chewbacca'; Alias='chewbacca'; JobTitle='Co-Pilot'; Department='Flight Ops'; OfficeLocation='Kashyyyk'}
        @{GivenName='Rey'; Surname='Skywalker'; DisplayName='Rey'; Alias='rey'; JobTitle='Field Specialist'; Department='Jedi Affairs'; OfficeLocation='Jakku'}
        @{GivenName='Finn'; Surname='FN2187'; DisplayName='Finn'; Alias='finn'; JobTitle='Security Analyst'; Department='Security'; OfficeLocation='Resistance Base'}
        @{GivenName='Poe'; Surname='Dameron'; DisplayName='Poe Dameron'; Alias='poedameron'; JobTitle='Squadron Leader'; Department='Flight Ops'; OfficeLocation='Yavin IV'}
        @{GivenName='Vader'; Surname='Darth'; DisplayName='Darth Vader'; Alias='darthvader'; JobTitle='Strategic Enforcement'; Department='Imperial Ops'; OfficeLocation='Mustafar'}
        @{GivenName='ObiWan'; Surname='Kenobi'; DisplayName='Obi-Wan Kenobi'; Alias='obiwankenobi'; JobTitle='Senior Advisor'; Department='Jedi Council'; OfficeLocation='Coruscant'}
        @{GivenName='Ahsoka'; Surname='Tano'; DisplayName='Ahsoka Tano'; Alias='ahsoka'; JobTitle='Field Advisor'; Department='Jedi Affairs'; OfficeLocation='Corvus'}
      )
    }
    'Halo' {
      @(
        @{GivenName='John'; Surname='117'; DisplayName='Master Chief (John-117)'; Alias='masterchief'; JobTitle='Spartan Lead'; Department='UNSC'; OfficeLocation='UNSC Infinity'}
        @{GivenName='Cortana'; Surname='AI'; DisplayName='Cortana'; Alias='cortana'; JobTitle='AI Advisor'; Department='AI Ops'; OfficeLocation='UNSC'}
        @{GivenName='The'; Surname='Arbiter'; DisplayName='The Arbiter'; Alias='arbiter'; JobTitle='Alliance Liaison'; Department='Covenant Affairs'; OfficeLocation='Sanghelios'}
        @{GivenName='Catherine'; Surname='Halsey'; DisplayName='Dr. Halsey'; Alias='drhalsey'; JobTitle='Chief Scientist'; Department='Science'; OfficeLocation='Reach'}
        @{GivenName='Jacob'; Surname='Keyes'; DisplayName='Captain Keyes'; Alias='captkeyes'; JobTitle='Ship Captain'; Department='Fleet Ops'; OfficeLocation='Pillar of Autumn'}
        @{GivenName='Avery'; Surname='Johnson'; DisplayName='Sgt. Johnson'; Alias='sgtjohnson'; JobTitle='Training Lead'; Department='UNSC'; OfficeLocation='Earth'}
        @{GivenName='Miranda'; Surname='Keyes'; DisplayName='Commander Miranda Keyes'; Alias='mirandakeys'; JobTitle='Operations Commander'; Department='Fleet Ops'; OfficeLocation='Earth'}
        @{GivenName='Emile'; Surname='A239'; DisplayName='Emile-A239'; Alias='emile'; JobTitle='Close-Quarters Specialist'; Department='UNSC'; OfficeLocation='Reach'}
        @{GivenName='Carter'; Surname='A259'; DisplayName='Carter-A259'; Alias='carter'; JobTitle='Noble Team Lead'; Department='UNSC'; OfficeLocation='Reach'}
        @{GivenName='Kat'; Surname='B320'; DisplayName='Kat-B320'; Alias='katb320'; JobTitle='Tactical Engineer'; Department='UNSC'; OfficeLocation='Reach'}
      )
    }
    'HarryPotter' {
      @(
        @{GivenName='Harry'; Surname='Potter'; DisplayName='Harry Potter'; Alias='harrypotter'; JobTitle='Field Specialist'; Department='Magical Security'; OfficeLocation='Hogwarts'}
        @{GivenName='Hermione'; Surname='Granger'; DisplayName='Hermione Granger'; Alias='hermione'; JobTitle='Research Director'; Department='Education'; OfficeLocation='Hogwarts'}
        @{GivenName='Ron'; Surname='Weasley'; DisplayName='Ron Weasley'; Alias='ronweasley'; JobTitle='Operations Coordinator'; Department='Magical Security'; OfficeLocation='Hogwarts'}
        @{GivenName='Albus'; Surname='Dumbledore'; DisplayName='Albus Dumbledore'; Alias='dumbledore'; JobTitle='Headmaster'; Department='Leadership'; OfficeLocation='Hogwarts'}
        @{GivenName='Severus'; Surname='Snape'; DisplayName='Severus Snape'; Alias='snape'; JobTitle='Potions Master'; Department='Education'; OfficeLocation='Hogwarts'}
        @{GivenName='Minerva'; Surname='McGonagall'; DisplayName='Minerva McGonagall'; Alias='mcgonagall'; JobTitle='Deputy Headmistress'; Department='Leadership'; OfficeLocation='Hogwarts'}
        @{GivenName='Draco'; Surname='Malfoy'; DisplayName='Draco Malfoy'; Alias='dracomalfoy'; JobTitle='Liaison, Slytherin House'; Department='Operations'; OfficeLocation='Hogwarts'}
        @{GivenName='Sirius'; Surname='Black'; DisplayName='Sirius Black'; Alias='siriusblack'; JobTitle='Advisor, Order Ops'; Department='Magical Security'; OfficeLocation='Grimmauld Place'}
        @{GivenName='Remus'; Surname='Lupin'; DisplayName='Remus Lupin'; Alias='remuslupin'; JobTitle='Defense Instructor'; Department='Education'; OfficeLocation='Hogwarts'}
        @{GivenName='Rubeus'; Surname='Hagrid'; DisplayName='Rubeus Hagrid'; Alias='hagrid'; JobTitle='Keeper of Keys & Grounds'; Department='Operations'; OfficeLocation='Hogwarts'}
      )
    }
    'Witcher' {
      @(
        @{GivenName='Geralt'; Surname='OfRivia'; DisplayName='Geralt of Rivia'; Alias='geralt'; JobTitle='Senior Contractor'; Department='Monster Ops'; OfficeLocation='Kaer Morhen'}
        @{GivenName='Yennefer'; Surname='Vengerberg'; DisplayName='Yennefer of Vengerberg'; Alias='yennefer'; JobTitle='Arcane Strategist'; Department='Sorcery'; OfficeLocation='Aretuza'}
        @{GivenName='Ciri'; Surname='Princess'; DisplayName='Cirilla (Ciri)'; Alias='ciri'; JobTitle='Special Projects Lead'; Department='Elder Blood'; OfficeLocation='Cintra'}
        @{GivenName='Triss'; Surname='Merigold'; DisplayName='Triss Merigold'; Alias='triss'; JobTitle='Senior Advisor'; Department='Sorcery'; OfficeLocation='Novigrad'}
        @{GivenName='Vesemir'; Surname='Mentor'; DisplayName='Vesemir'; Alias='vesemir'; JobTitle='Training Director'; Department='Monster Ops'; OfficeLocation='Kaer Morhen'}
        @{GivenName='Jaskier'; Surname='Bard'; DisplayName='Jaskier (Dandelion)'; Alias='jaskier'; JobTitle='Communications Lead'; Department='Culture'; OfficeLocation='Oxenfurt'}
        @{GivenName='Zoltan'; Surname='Chivay'; DisplayName='Zoltan Chivay'; Alias='zoltan'; JobTitle='Logistics Manager'; Department='Operations'; OfficeLocation='Novigrad'}
        @{GivenName='Regis'; Surname='Vampire'; DisplayName='Emiel Regis'; Alias='regis'; JobTitle='Medical Consultant'; Department='Science'; OfficeLocation='Toussaint'}
        @{GivenName='Lambert'; Surname='Witcher'; DisplayName='Lambert'; Alias='lambert'; JobTitle='Field Operative'; Department='Monster Ops'; OfficeLocation='Kaer Morhen'}
        @{GivenName='Eskel'; Surname='Witcher'; DisplayName='Eskel'; Alias='eskel'; JobTitle='Field Operative'; Department='Monster Ops'; OfficeLocation='Kaer Morhen'}
      )
    }
    'LiloAndStitch' {
      @(
        @{GivenName='Lilo'; Surname='Pelekai'; DisplayName='Lilo Pelekai'; Alias='lilo'; JobTitle='Ohana Program Lead'; Department='Ohana Relations'; OfficeLocation='Kauai'}
        @{GivenName='Nani'; Surname='Pelekai'; DisplayName='Nani Pelekai'; Alias='nani'; JobTitle='Household Ops Manager'; Department='Ohana Relations'; OfficeLocation='Kauai'}
        @{GivenName='Stitch'; Surname='626'; DisplayName='Stitch (Experiment 626)'; Alias='stitch'; JobTitle='Containment Specialist'; Department='Experiment Ops'; OfficeLocation='Kauai'}
        @{GivenName='Jumba'; Surname='Jookiba'; DisplayName='Dr. Jumba Jookiba'; Alias='jumba'; JobTitle='Chief Geneticist'; Department='Science'; OfficeLocation='Galactic HQ'}
        @{GivenName='Pleakley'; Surname='Agent'; DisplayName='Pleakley'; Alias='pleakley'; JobTitle='Galactic Liaison'; Department='Alien Affairs'; OfficeLocation='Galactic HQ'}
        @{GivenName='Cobra'; Surname='Bubbles'; DisplayName='Cobra Bubbles'; Alias='cobrabubbles'; JobTitle='Compliance Officer'; Department='Security'; OfficeLocation='Honolulu'}
        @{GivenName='David'; Surname='Kawena'; DisplayName='David Kawena'; Alias='davidkawena'; JobTitle='Rescue Swimmer'; Department='Surf & Rescue'; OfficeLocation='Kauai'}
        @{GivenName='Captain'; Surname='Gantu'; DisplayName='Captain Gantu'; Alias='gantu'; JobTitle='Enforcement Officer'; Department='Galactic Enforcement'; OfficeLocation='Galactic HQ'}
        @{GivenName='Mertle'; Surname='Edmonds'; DisplayName='Mertle Edmonds'; Alias='mertle'; JobTitle='Community Coordinator'; Department='Engagement'; OfficeLocation='Kauai'}
        @{GivenName='Victoria'; Surname='Friend'; DisplayName='Victoria'; Alias='victoria'; JobTitle='Friendship Ambassador'; Department='Engagement'; OfficeLocation='Kauai'}
      )
    }
    'Shrek' {
      @(
        @{GivenName='Shrek'; Surname='Ogre'; DisplayName='Shrek'; Alias='shrek'; JobTitle='Chief Swamp Officer'; Department='Swamp Ops'; OfficeLocation='Shreks Swamp'}
        @{GivenName='Fiona'; Surname='Princess'; DisplayName='Princess Fiona'; Alias='fiona'; JobTitle='Operations Director'; Department='Royal Affairs'; OfficeLocation='Far Far Away'}
        @{GivenName='Donkey'; Surname='Talking'; DisplayName='Donkey'; Alias='donkey'; JobTitle='Communications Lead'; Department='Outreach'; OfficeLocation='Far Far Away'}
        @{GivenName='Puss'; Surname='InBoots'; DisplayName='Puss in Boots'; Alias='pussinboots'; JobTitle='Security Specialist'; Department='Feline Ops'; OfficeLocation='Far Far Away'}
        @{GivenName='Dragon'; Surname='Keep'; DisplayName='Dragon'; Alias='dragon'; JobTitle='Air Support Lead'; Department='Air Ops'; OfficeLocation='Dragons Keep'}
        @{GivenName='Lord'; Surname='Farquaad'; DisplayName='Lord Farquaad'; Alias='farquaad'; JobTitle='City Administrator'; Department='Governance'; OfficeLocation='Duloc'}
        @{GivenName='Gingy'; Surname='Gingerbread'; DisplayName='Gingy (Gingerbread Man)'; Alias='gingy'; JobTitle='Confectionery Design Lead'; Department='Creative'; OfficeLocation='Far Far Away'}
        @{GivenName='Pinocchio'; Surname='Wooden'; DisplayName='Pinocchio'; Alias='pinocchio'; JobTitle='Compliance Analyst'; Department='Governance'; OfficeLocation='Far Far Away'}
        @{GivenName='Fairy'; Surname='Godmother'; DisplayName='Fairy Godmother'; Alias='fairygodmother'; JobTitle='Transformation Program Director'; Department='Change Management'; OfficeLocation='Far Far Away'}
        @{GivenName='Prince'; Surname='Charming'; DisplayName='Prince Charming'; Alias='princecharming'; JobTitle='Brand Ambassador'; Department='Public Relations'; OfficeLocation='Far Far Away'}
      )
    }
    'StarTrek' {
      @(
        @{GivenName='James';   Surname='Kirk';     DisplayName='James T. Kirk';        Alias='jameskirk';   JobTitle='Captain';               Department='Command';         OfficeLocation='USS Enterprise NCC-1701'}
        @{GivenName='Spock';   Surname='Spock';    DisplayName='Spock';                 Alias='spock';       JobTitle='Science Officer';       Department='Science';         OfficeLocation='USS Enterprise NCC-1701'}
        @{GivenName='Leonard'; Surname='McCoy';    DisplayName='Leonard McCoy';         Alias='mccoy';       JobTitle='Chief Medical Officer'; Department='Medical';         OfficeLocation='USS Enterprise NCC-1701'}
        @{GivenName='Montgomery';Surname='Scott';  DisplayName='Montgomery Scott';      Alias='scotty';      JobTitle='Chief Engineer';        Department='Engineering';     OfficeLocation='USS Enterprise NCC-1701'}
        @{GivenName='Nyota';   Surname='Uhura';    DisplayName='Nyota Uhura';           Alias='uhura';       JobTitle='Communications Officer';Department='Communications';  OfficeLocation='USS Enterprise NCC-1701'}
        @{GivenName='Hikaru';  Surname='Sulu';     DisplayName='Hikaru Sulu';           Alias='sulu';        JobTitle='Helmsman';              Department='Flight Ops';      OfficeLocation='USS Enterprise NCC-1701'}
        @{GivenName='Pavel';   Surname='Chekov';   DisplayName='Pavel Chekov';          Alias='chekov';      JobTitle='Navigation Officer';    Department='Flight Ops';      OfficeLocation='USS Enterprise NCC-1701'}
        @{GivenName='JeanLuc'; Surname='Picard';   DisplayName='Jean-Luc Picard';       Alias='picard';      JobTitle='Captain';               Department='Command';         OfficeLocation='USS Enterprise NCC-1701-D'}
        @{GivenName='Benjamin';Surname='Sisko';    DisplayName='Benjamin Sisko';        Alias='sisko';       JobTitle='Station Commander';     Department='Leadership';      OfficeLocation='Deep Space 9'}
        @{GivenName='Kathryn'; Surname='Janeway';  DisplayName='Kathryn Janeway';       Alias='janeway';     JobTitle='Captain';               Department='Command';         OfficeLocation='USS Voyager'}
      )
    }
  }
}

function New-FranchiseUsers {
  param(
    [Parameter(Mandatory)][string]$TenantDomain,
    [Parameter(Mandatory)][array]$Roster,
    [Parameter(Mandatory)][string]$UsageLocation,
    [int]$PasswordLength = 14,
    [string]$CsvPath
  )
  if (-not $CsvPath) { $CsvPath = "C:\Temp\DemoUsers_{0}.csv" -f $Franchise }
  if (-not (Test-Path (Split-Path $CsvPath))) { New-Item -ItemType Directory -Path (Split-Path $CsvPath) -Force | Out-Null }

  $results = @()
  foreach ($h in $Roster) {
    $local = ($h.Alias -replace '[^a-zA-Z0-9\._-]','').ToLower()
    $upn   = "$local@$TenantDomain"

    $exists = $null
    try { $exists = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ConsistencyLevel eventual } catch {}
    if ($exists) { Write-Host "Exists: $upn — skipping." -ForegroundColor Yellow; continue }

    $pwd = New-TempPassword -Length $PasswordLength
    $passwordProfile = @{ ForceChangePasswordNextSignIn = $true; Password = $pwd }

    $userParams = @{
      AccountEnabled    = $true
      DisplayName       = $h.DisplayName
      MailNickname      = $local
      UserPrincipalName = $upn
      PasswordProfile   = $passwordProfile
      GivenName         = $h.GivenName
      Surname           = $h.Surname
      JobTitle          = $h.JobTitle
      Department        = $h.Department
      OfficeLocation    = $h.OfficeLocation
      UsageLocation     = $UsageLocation
    }

    try {
      Write-Host "Creating $upn ..." -ForegroundColor Green
      New-MgUser @userParams | Out-Null
      $results += [pscustomobject]@{
        UserPrincipalName = $upn
        DisplayName       = $h.DisplayName
        GivenName         = $h.GivenName
        Surname           = $h.Surname
        JobTitle          = $h.JobTitle
        Department        = $h.Department
        OfficeLocation    = $h.OfficeLocation
        TempPassword      = $pwd
      }
    } catch {
      Write-Warning "Failed: $upn : $($_.Exception.Message)"
    }
  }

  if ($results.Count -gt 0) {
    $results | Export-Csv -Path $CsvPath -NoTypeInformation -Force
    Write-Host "Created $($results.Count) users. CSV: $CsvPath" -ForegroundColor Cyan
  } else {
    Write-Host "No new users created." -ForegroundColor Yellow
  }
}

function Upsert-DynamicGroup {
  param(
    [Parameter(Mandatory)][string]$DisplayName,
    [Parameter(Mandatory)][string]$MailNickname,
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][string]$MembershipRule
  )
  $existing = $null
  try { $existing = Get-MgGroup -Filter "displayName eq '$($DisplayName.Replace("'","''"))'" -ConsistencyLevel eventual } catch {}
  if ($existing) {
    Update-MgGroup -GroupId $existing.Id -Description $Description -MembershipRule $MembershipRule -MembershipRuleProcessingState "On"
    Write-Host "Updated: $DisplayName"
  } else {
    New-MgGroup -DisplayName $DisplayName -Description $Description -MailEnabled:$false -MailNickname $MailNickname -SecurityEnabled:$true -GroupTypes @("DynamicMembership") -MembershipRule $MembershipRule -MembershipRuleProcessingState "On" | Out-Null
    Write-Host "Created: $DisplayName"
  }
}

function New-FranchiseGroups {
  param(
    [Parameter(Mandatory)][array]$Roster,
    [Parameter(Mandatory)][string]$Franchise
  )
  $aliases   = ($Roster | ForEach-Object { ($_.Alias -replace '[^a-zA-Z0-9\._-]','').ToLower() }) | Sort-Object -Unique
  $locations = ($Roster | ForEach-Object { $_.OfficeLocation }) | Sort-Object -Unique

  function Quote-Array([string[]]$arr){ ($arr | ForEach-Object { '"{0}"' -f $_ }) -join ',' }

  # All users in this franchise
  $ruleAll = "(user.mailNickname -in [{0}])" -f (Quote-Array $aliases)
  Upsert-DynamicGroup -DisplayName "DG - $Franchise - All" -MailNickname ("dg-{0}-all" -f $Franchise.ToLower()) -Description "All $Franchise demo users." -MembershipRule $ruleAll

  # Leadership
  $ruleLeadership = '((user.department -eq "Leadership") -or (user.jobTitle -match "Director|Commander|Head|King|Queen|Princess|Captain|Headmaster|High King|CTO|Deputy Head|Station Commander"))'
  Upsert-DynamicGroup -DisplayName "DG - $Franchise - Leadership" -MailNickname ("dg-{0}-leaders" -f $Franchise.ToLower()) -Description "Leadership roles in $Franchise." -MembershipRule $ruleLeadership

  # Tech & Science
  $ruleTechSci = '((user.department -in ["Engineering","Technology","Science","AI Ops","Capsule Corp","UNSC","Sorcery","Medical"]) -or (user.jobTitle -match "Engineer|Scientist|Technolog|Systems|R&D|AI|Research|Potions|Medical"))'
  Upsert-DynamicGroup -DisplayName "DG - $Franchise - Tech & Science" -MailNickname ("dg-{0}-techsci" -f $Franchise.ToLower()) -Description "Tech and Science roles in $Franchise." -MembershipRule $ruleTechSci

  # Flight Ops & Pilots
  $ruleFlight = '((user.department -eq "Flight Ops") -or (user.jobTitle -match "Pilot|Co-Pilot|Squadron|Captain|Helmsman|Navigation Officer|Air Support"))'
  Upsert-DynamicGroup -DisplayName "DG - $Franchise - Flight Ops" -MailNickname ("dg-{0}-flight" -f $Franchise.ToLower()) -Description "Pilots and flight ops in $Franchise." -MembershipRule $ruleFlight

  # Marksmen & Covert
  $ruleCovert = '((user.department -in ["Marksmen","Covert Ops"]) -or (user.jobTitle -match "Archer|Precision|Infiltration|Assassin|Sniper|Security Specialist"))'
  Upsert-DynamicGroup -DisplayName "DG - $Franchise - Marksmen & Covert" -MailNickname ("dg-{0}-covert" -f $Franchise.ToLower()) -Description "Marksmen and Covert roles in $Franchise." -MembershipRule $ruleCovert

  # Key locations (use physicalDeliveryOfficeName)
  if ($locations.Count -gt 0) {
    $ruleLoc = "(user.physicalDeliveryOfficeName -in [{0}])" -f (Quote-Array $locations)
    Upsert-DynamicGroup -DisplayName "DG - $Franchise - Key Locations" -MailNickname ("dg-{0}-locations" -f $Franchise.ToLower()) -Description "$Franchise key office locations." -MembershipRule $ruleLoc
  }

  # Trek-specific extras
  if ($Franchise -eq 'StarTrek') {
    # Starfleet Command: Command or leadership grade titles
    $ruleCommand = '((user.department -eq "Command") -or (user.jobTitle -match "Captain|Commander|Admiral|Station Commander"))'
    Upsert-DynamicGroup -DisplayName "DG - StarTrek - Starfleet Command" -MailNickname "dg-startrek-command" -Description "Command cadre across Starfleet." -MembershipRule $ruleCommand

    # Enterprise Crew: both NCC-1701 eras
    $enterpriseLocs = @("USS Enterprise NCC-1701","USS Enterprise NCC-1701-D")
    $ruleEnterprise = "(user.physicalDeliveryOfficeName -in [{0}])" -f (Quote-Array $enterpriseLocs)
    Upsert-DynamicGroup -DisplayName "DG - StarTrek - Enterprise Crew" -MailNickname "dg-startrek-enterprise" -Description "Crew assigned to the Enterprise." -MembershipRule $ruleEnterprise
  }
}

# ---------- Execute ----------
$roster = Get-FranchiseRoster -Name $Franchise
if ($CreateUsers)  { New-FranchiseUsers -TenantDomain $TenantDomain -Roster $roster -UsageLocation $UsageLocation -PasswordLength $PasswordLength -CsvPath $CsvPath }
if ($CreateGroups) { New-FranchiseGroups -Roster $roster -Franchise $Franchise }

if (-not $CreateUsers -and -not $CreateGroups) {
  Write-Host "Nothing to do. Add -CreateUsers and/or -CreateGroups." -ForegroundColor Yellow
}
