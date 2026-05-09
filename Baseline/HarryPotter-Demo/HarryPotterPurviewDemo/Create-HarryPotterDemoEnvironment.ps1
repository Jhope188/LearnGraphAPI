<#
.SYNOPSIS
    Creates a comprehensive Harry Potter themed SharePoint demo environment.
.DESCRIPTION
    Creates 20 SharePoint team sites (via M365 Groups) and uploads 3-6 realistic
    documents (.docx, .pptx, .xlsx) per site using Microsoft Graph.
    Auto-detects tenant from the current Graph session - works against any tenant.
.NOTES
    Requires: Microsoft.Graph PowerShell SDK
    Scopes: Sites.ReadWrite.All, Group.ReadWrite.All, Files.ReadWrite.All
    Usage:  Connect-MgGraph -Scopes "Group.ReadWrite.All","Sites.ReadWrite.All","Files.ReadWrite.All"
            .\Create-HarryPotterDemoEnvironment.ps1
#>

# ─────────────────────────────────────────────
# HELPER: Create a minimal .docx in memory
# ─────────────────────────────────────────────
function New-MinimalDocx {
    param([string]$TextContent, [string]$Title)
    
    $docXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
            xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
            xmlns:o="urn:schemas-microsoft-com:office:office"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
            xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
            xmlns:v="urn:schemas-microsoft-com:vml"
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
            xmlns:w10="urn:schemas-microsoft-com:office:word"
            xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml">
  <w:body>
    <w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t>$Title</w:t></w:r></w:p>
    <w:p><w:r><w:t>$TextContent</w:t></w:r></w:p>
  </w:body>
</w:document>
"@

    $contentTypesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
"@

    $relsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"@

    $tempPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".docx")
    
    # Build zip (docx is a zip)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($tempPath, 'Create')
    
    $entry = $zip.CreateEntry("[Content_Types].xml")
    $writer = [System.IO.StreamWriter]::new($entry.Open())
    $writer.Write($contentTypesXml)
    $writer.Close()
    
    $entry = $zip.CreateEntry("_rels/.rels")
    $writer = [System.IO.StreamWriter]::new($entry.Open())
    $writer.Write($relsXml)
    $writer.Close()
    
    $entry = $zip.CreateEntry("word/document.xml")
    $writer = [System.IO.StreamWriter]::new($entry.Open())
    $writer.Write($docXml)
    $writer.Close()
    
    $zip.Dispose()
    return $tempPath
}

# ─────────────────────────────────────────────
# HELPER: Create a minimal .xlsx in memory
# ─────────────────────────────────────────────
function New-MinimalXlsx {
    param([string[]]$Headers, [string[][]]$Rows)
    
    # Build shared strings
    $allStrings = @()
    $allStrings += $Headers
    foreach ($row in $Rows) { $allStrings += $row }
    
    $ssEntries = ($allStrings | ForEach-Object { "<si><t>$_</t></si>" }) -join ""
    $sharedStringsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="$($allStrings.Count)" uniqueCount="$($allStrings.Count)">
$ssEntries
</sst>
"@

    # Build sheet data
    $cols = @("A","B","C","D","E","F","G","H","I","J")
    $sheetRows = "<row r=`"1`">"
    $idx = 0
    for ($c = 0; $c -lt $Headers.Count; $c++) {
        $sheetRows += "<c r=`"$($cols[$c])1`" t=`"s`"><v>$idx</v></c>"
        $idx++
    }
    $sheetRows += "</row>"
    
    for ($r = 0; $r -lt $Rows.Count; $r++) {
        $rowNum = $r + 2
        $sheetRows += "<row r=`"$rowNum`">"
        for ($c = 0; $c -lt $Rows[$r].Count; $c++) {
            $sheetRows += "<c r=`"$($cols[$c])$rowNum`" t=`"s`"><v>$idx</v></c>"
            $idx++
        }
        $sheetRows += "</row>"
    }

    $sheetXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
           xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheetData>$sheetRows</sheetData>
</worksheet>
"@

    $workbookXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>
"@

    $wbRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>
"@

    $contentTypesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>
"@

    $relsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
"@

    $tempPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".xlsx")
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($tempPath, 'Create')
    
    foreach ($item in @(
        @("[Content_Types].xml", $contentTypesXml),
        @("_rels/.rels", $relsXml),
        @("xl/workbook.xml", $workbookXml),
        @("xl/_rels/workbook.xml.rels", $wbRelsXml),
        @("xl/worksheets/sheet1.xml", $sheetXml),
        @("xl/sharedStrings.xml", $sharedStringsXml)
    )) {
        $entry = $zip.CreateEntry($item[0])
        $writer = [System.IO.StreamWriter]::new($entry.Open())
        $writer.Write($item[1])
        $writer.Close()
    }
    $zip.Dispose()
    return $tempPath
}

# ─────────────────────────────────────────────
# HELPER: Create a minimal .pptx in memory
# ─────────────────────────────────────────────
function New-MinimalPptx {
    param([string]$Title, [string]$Subtitle, [string[]]$BulletPoints)
    
    $bullets = ($BulletPoints | ForEach-Object { "<a:p><a:r><a:rPr lang=`"en-US`" dirty=`"0`"/><a:t>$_</a:t></a:r></a:p>" }) -join ""
    
    $slideXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
       xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
       xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
      <p:grpSpPr/>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="457200" y="274638"/><a:ext cx="8229600" cy="1143000"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US" dirty="0"/><a:t>$Title</a:t></a:r></a:p></p:txBody>
      </p:sp>
      <p:sp>
        <p:nvSpPr><p:cNvPr id="3" name="Content"/><p:cNvSpPr><a:spLocks noGrp="1"/></p:cNvSpPr><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="457200" y="1600200"/><a:ext cx="8229600" cy="4525963"/></a:xfrm></p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/>$bullets</p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>
"@

    $presXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldMasterIdLst/>
  <p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000" type="screen4x3"/>
  <p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>
"@

    $presRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>
"@

    $contentTypesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>
"@

    $relsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>
"@

    $tempPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".pptx")
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($tempPath, 'Create')
    
    foreach ($item in @(
        @("[Content_Types].xml", $contentTypesXml),
        @("_rels/.rels", $relsXml),
        @("ppt/presentation.xml", $presXml),
        @("ppt/_rels/presentation.xml.rels", $presRelsXml),
        @("ppt/slides/slide1.xml", $slideXml)
    )) {
        $entry = $zip.CreateEntry($item[0])
        $writer = [System.IO.StreamWriter]::new($entry.Open())
        $writer.Write($item[1])
        $writer.Close()
    }
    $zip.Dispose()
    return $tempPath
}

# ─────────────────────────────────────────────
# HELPER: Upload file to site's document library
# ─────────────────────────────────────────────
function Upload-ToSharePoint {
    param(
        [string]$GroupId,
        [string]$FilePath,
        [string]$FileName
    )
    
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $url = "https://graph.microsoft.com/v1.0/groups/$GroupId/drive/root:/$($FileName):/content"
    
    Invoke-MgGraphRequest -Method PUT -Uri $url -Body $fileBytes -ContentType "application/octet-stream" -OutputType Json | Out-Null
}

# ════════════════════════════════════════════════════════
#  20 HARRY POTTER THEMED SHAREPOINT SITES + DOCUMENTS
# ════════════════════════════════════════════════════════

$siteDefs = @(
    # ── 1. SNAPE'S POTIONS LABORATORY ──
    @{
        DisplayName  = "Snapes Potions Laboratory"
        MailNickname = "SnapesPotionsLab"
        Description  = "Professor Snape's private potions research, recipes, and ingredient inventory for Hogwarts School of Witchcraft and Wizardry"
        Documents    = @(
            @{ Name = "Polyjuice Potion - Full Recipe.docx"; Type = "docx"
               Title = "Polyjuice Potion - Complete Brewing Instructions"
               Content = "CLASSIFIED - N.E.W.T. LEVEL ONLY. Ingredients: Lacewing flies (stewed 21 days), leeches, powdered bicorn horn, knotgrass, fluxweed (picked at full moon), shredded Boomslang skin, and a bit of the person one wishes to become. Brewing time: One month. Step 1: Add 3 measures of fluxweed to the cauldron. Step 2: Add 2 bundles of knotgrass. Step 3: Stir 4 times clockwise. Step 4: Wave wand over cauldron. Step 5: Leave to brew for 24 hours. WARNING: This potion is restricted by the Ministry of Magic under Decree 227B. Misuse carries a minimum 6-month sentence in Azkaban." },
            @{ Name = "Advanced Potions Syllabus 2026.xlsx"; Type = "xlsx"
               Headers = @("Potion","Year Level","Difficulty","Duration","Key Ingredient","Professor Rating")
               Rows = @(
                   @("Draught of Living Death","6th Year","Extremely Difficult","2 hours","Sopophorous Bean","Outstanding"),
                   @("Felix Felicis","7th Year","N.E.W.T.","6 months","Ashwinder Egg","Beyond Outstanding"),
                   @("Wolfsbane Potion","7th Year","N.E.W.T.","1 week","Aconite","Exceeds Expectations"),
                   @("Amortentia","6th Year","Advanced","3 hours","Rose Thorns","Outstanding"),
                   @("Veritaserum","7th Year","N.E.W.T.","1 month","Jobberknoll Feathers","Outstanding"),
                   @("Pepperup Potion","4th Year","Moderate","45 minutes","Bicorn Horn","Acceptable"),
                   @("Shrinking Solution","3rd Year","Intermediate","1 hour","Shrivelfig","Acceptable"),
                   @("Wiggenweld Potion","2nd Year","Easy","30 minutes","Lionfish Spines","Acceptable")
               ) },
            @{ Name = "Potion Ingredient Inventory Q1 2026.xlsx"; Type = "xlsx"
               Headers = @("Ingredient","Quantity","Unit","Supplier","Cost (Galleons)","Reorder Level","Expiry")
               Rows = @(
                   @("Boomslang Skin","47","strips","Slug and Jiggers","12","20","Sep 2026"),
                   @("Lacewing Flies","2300","count","Diagon Alley Imports","8","500","Dec 2026"),
                   @("Bicorn Horn (powdered)","15","jars","Knockturn Alley","45","5","Jul 2026"),
                   @("Ashwinder Eggs","6","frozen","Restricted Registry","200","2","Mar 2026"),
                   @("Bezoars","23","stones","Slug and Jiggers","35","10","No Expiry"),
                   @("Dragon Blood (12 uses)","4","vials","Romanian Reserve","150","2","Jun 2026"),
                   @("Moonstone","89","grams","Quality Potions Supply","18","30","No Expiry")
               ) },
            @{ Name = "Veritaserum Brewing Log - CONFIDENTIAL.docx"; Type = "docx"
               Title = "Veritaserum Brewing Log - MINISTRY RESTRICTED"
               Content = "CONFIDENTIAL - Ministry Authorization Required. Current batch: VER-2026-003. Started: January 15, 2026. Status: Day 47 of lunar cycle fermentation. The three drops of Veritaserum must be administered within 4 hours of final distillation for maximum efficacy. Current stock: 2 vials (Ministry-approved). Authorized users: Albus Dumbledore, Severus Snape. Note from Snape: Potter will NOT be given access to this log under ANY circumstances." },
            @{ Name = "Antidote Research Presentation.pptx"; Type = "pptx"
               Title = "Universal Antidote Research - Golpalotts Third Law"
               Subtitle = "Department of Potions - Hogwarts"
               Bullets = @("Golpalotts Third Law: The antidote for a blended poison is more than the sum of antidotes for each component","Current research: Bezoar effectiveness on compound hexes","Test results from 47 controlled trials (approved by Dumbledore)","Breakthrough: Phoenix tears as universal catalyst","Next steps: Ministry approval for clinical trials","Budget request: 340 Galleons for Q2 2026") }
        )
    },

    # ── 2. DUMBLEDORE'S OFFICE ──
    @{
        DisplayName  = "Dumbledores Office"
        MailNickname = "DumbledoresOffice"
        Description  = "Headmaster Dumbledore's personal files, lemon drop inventory, and correspondence with the Ministry of Magic"
        Documents    = @(
            @{ Name = "Lemon Drop Supplier Contracts.xlsx"; Type = "xlsx"
               Headers = @("Supplier","Flavour","Qty per Month","Cost (Galleons)","Contract Expires","Rating")
               Rows = @(
                   @("Honeydukes","Classic Lemon","500","12","Dec 2026","Outstanding"),
                   @("Honeydukes","Sherbet Lemon","300","15","Dec 2026","Exceeds Expectations"),
                   @("Sugar Plum's Sweets","Fizzing Lemon","200","18","Jun 2026","Acceptable"),
                   @("Weasleys Wizard Wheezes","Trick Lemon (tongue-colour)","50","8","Ongoing","Troll")
               ) },
            @{ Name = "Correspondence - Minister for Magic.docx"; Type = "docx"
               Title = "Confidential Correspondence - Minister for Magic"
               Content = "Dear Minister, I write to you once more regarding the situation at the Department of Mysteries. As I have stated in my previous 47 letters, the prophecy must remain protected at all costs. I urge you to increase the guard rotation to every 4 hours. The Order of the Phoenix stands ready to assist should you require additional personnel. I also wish to remind you that Dolores Umbridge's appointment as High Inquisitor at Hogwarts is both unprecedented and deeply counterproductive. Yours in service, Albus Percival Wulfric Brian Dumbledore, Order of Merlin First Class, Headmaster of Hogwarts." },
            @{ Name = "Hogwarts Staff Meeting Minutes.docx"; Type = "docx"
               Title = "Hogwarts Staff Meeting - February 2026 Minutes"
               Content = "Attendees: A. Dumbledore (Chair), M. McGonagall, S. Snape, F. Flitwick, P. Sprout, R. Hagrid, S. Trelawney, A. Sinistra. Item 1: Budget allocation for new broomsticks (Quidditch) - APPROVED 340 Galleons. Item 2: Snape requests restriction of student access to the Restricted Section after the Polyjuice incident - APPROVED. Item 3: Hagrid's request to introduce Blast-Ended Skrewts to 4th year curriculum - DENIED (McGonagall objected, motion failed 6-2). Item 4: Trelawney predicts doom for next Tuesday - NOTED. Item 5: Dumbledore's proposal for inter-house unity dance - TABLED for further discussion. Next meeting: March 15, 2026." },
            @{ Name = "Pensieve Memory Catalog.xlsx"; Type = "xlsx"
               Headers = @("Memory ID","Date Stored","Subject","Classification","Extracted From","Status")
               Rows = @(
                   @("PEN-001","1943","Tom Riddle - Orphanage Visit","TOP SECRET","A. Dumbledore","Active"),
                   @("PEN-002","1944","Slughorn - Horcrux Conversation","TOP SECRET - TAMPERED","H. Slughorn","Modified"),
                   @("PEN-003","1981","Prophecy - Trelawney","RESTRICTED","A. Dumbledore","Active"),
                   @("PEN-004","1945","Grindelwald Duel","PERSONAL","A. Dumbledore","Active"),
                   @("PEN-005","1938","Young Tom Riddle - First Meeting","CLASSIFIED","A. Dumbledore","Active")
               ) },
            @{ Name = "Annual Address to Students.pptx"; Type = "pptx"
               Title = "Welcome to Hogwarts - Start of Year Address"
               Subtitle = "Headmaster Albus Dumbledore"
               Bullets = @("Welcome back to another year at Hogwarts!","A few start-of-term notices: The Forbidden Forest is strictly off-limits","Mr Filch has added Fanged Frisbees to the banned items list (now 967 items)","Quidditch trials begin in the second week of term","New this year: Inter-house study groups (mandatory for 1st years)","And finally: Nitwit! Blubber! Oddment! Tweak!") }
        )
    },

    # ── 3. GRINGOTTS WIZARDING BANK ──
    @{
        DisplayName  = "Gringotts Wizarding Bank"
        MailNickname = "GringottsBank"
        Description  = "Gringotts financial records, vault management, and goblin banking operations"
        Documents    = @(
            @{ Name = "Vault Holdings Report Q1 2026.xlsx"; Type = "xlsx"
               Headers = @("Vault Number","Account Holder","Galleons","Sickles","Knuts","Security Level","Last Access")
               Rows = @(
                   @("687","Harry Potter","74,382","11","7","Dragon-Guarded","Jan 2026"),
                   @("711","Weasley Family","23","7","4","Standard","Feb 2026"),
                   @("713","Dumbledore (Philosopher Stone)","EMPTIED","0","0","Maximum","Jul 1991"),
                   @("832","Malfoy Family","1,247,893","0","0","Jinx-Protected","Mar 2026"),
                   @("512","Lestrange Family","FROZEN","FROZEN","FROZEN","Dragon + Thief's Downfall","SEIZED"),
                   @("903","Hogwarts School Fund","89,445","342","18","High Security","Feb 2026")
               ) },
            @{ Name = "Currency Exchange Rates.docx"; Type = "docx"
               Title = "Gringotts Official Exchange Rates - March 2026"
               Content = "Current exchange rates as of 1 March 2026: 1 Galleon = 17 Sickles. 1 Sickle = 29 Knuts. 1 Galleon = 493 Knuts. Muggle Currency Conversion (STRICTLY CONFIDENTIAL): 1 Galleon = approximately 4.97 GBP (subject to Muggle inflation adjustments). Exchange limits: Muggle-born families may exchange up to 500 GBP per visit. All Muggle currency transactions require Form G-17 (Declaration of Muggle Monetary Origin). Bulk conversions over 1000 Galleons require Goblin Senior Manager approval." },
            @{ Name = "Break-In Incident Report 1991.docx"; Type = "docx"
               Title = "SECURITY INCIDENT REPORT - Vault 713 Break-In"
               Content = "Date: 31 July 1991. Vault: 713. Status: EMPTIED SAME DAY by Rubeus Hagrid on orders of Albus Dumbledore. Incident: Unknown intruder(s) breached Vault 713 security. No items were taken as the vault had been emptied hours prior. Damage: Minor (vault door forced). Suspects: CLASSIFIED - Ministry investigation ongoing. Security recommendations: Upgrade all high-security vaults to dragon-level protection. Install additional Thief's Downfall waterfalls. Review goblin guard rotation schedules. Signed: Ragnok, Head Goblin." }
        )
    },

    # ── 4. HOGWARTS HOSPITAL WING ──
    @{
        DisplayName  = "Hogwarts Hospital Wing"
        MailNickname = "HogwartsHospitalWing"
        Description  = "Madam Pomfrey's patient records, treatment protocols, and medical supply tracking"
        Documents    = @(
            @{ Name = "Patient Admissions Log 2025-2026.xlsx"; Type = "xlsx"
               Headers = @("Date","Patient","Year","Injury/Condition","Treatment","Days in Ward","Discharge Status")
               Rows = @(
                   @("Sep 2025","N. Longbottom","6th","Broken wrist (Herbology)","Skele-Gro","1","Discharged"),
                   @("Oct 2025","H. Potter","6th","Quidditch - Bludger arm","Skele-Gro (regrow bones)","3","Discharged"),
                   @("Oct 2025","C. Creevey","5th","Petrification","Mandrake Restorative","47","Discharged"),
                   @("Nov 2025","R. Weasley","6th","Poisoning (mead)","Bezoar + Antidote","5","Discharged"),
                   @("Jan 2026","K. Bell","7th","Cursed necklace","St Mungos Transfer","90","Ongoing"),
                   @("Feb 2026","D. Malfoy","6th","Sectumsempra wounds","Dittany + Counter-curse","7","Discharged")
               ) },
            @{ Name = "Medical Supplies Order Form.docx"; Type = "docx"
               Title = "Quarterly Medical Supplies Order - Q2 2026"
               Content = "TO: Slug and Jiggers Apothecary, Diagon Alley. FROM: Poppy Pomfrey, Matron, Hogwarts Hospital Wing. Priority Order: Skele-Gro (24 bottles - we keep running out thanks to Quidditch), Pepperup Potion (48 doses), Essence of Dittany (12 vials), Calming Draught (36 doses), Sleeping Draught (24 doses), Bruise-Healing Paste (18 jars), Mandrake Restorative Draught (6 doses - URGENT given recent petrification incidents). Special request: 4 additional bezoars for emergency stock. Total budget approved: 180 Galleons (signed: Dumbledore)." },
            @{ Name = "Treatment Protocols - Dark Arts Injuries.pptx"; Type = "pptx"
               Title = "Emergency Treatment Protocols - Dark Arts Injuries"
               Subtitle = "Hogwarts Hospital Wing - Restricted Staff Only"
               Bullets = @("Protocol 1: Unforgivable Curse exposure - immediate St Mungos transfer","Protocol 2: Sectumsempra - apply Dittany, sing counter-curse (Vulnera Sanentur)","Protocol 3: Basilisk petrification - Mandrake Restorative Draught only","Protocol 4: Cursed objects - DO NOT TOUCH, contain with Hover Charm, call Dumbledore","Protocol 5: Dementor exposure - Chocolate (minimum 3 blocks), Patronus if available","Protocol 6: Dragon burns - Dr Ubblys Oblivious Unction + Burn-Healing Paste") }
        )
    },

    # ── 5. WEASLEYS' WIZARD WHEEZES ──
    @{
        DisplayName  = "Weasleys Wizard Wheezes"
        MailNickname = "WeasleysWizardWheezes"
        Description  = "Product development, sales tracking, and R&D for 93 Diagon Alley's premier joke shop"
        Documents    = @(
            @{ Name = "Product Catalog Spring 2026.xlsx"; Type = "xlsx"
               Headers = @("Product","Category","Price (Galleons)","Stock","Age Restriction","Best Seller")
               Rows = @(
                   @("Extendable Ears","Spy & Surveillance","2.5","340","None","Yes"),
                   @("Skiving Snackboxes","Illness Inducers","5","890","12+","Yes"),
                   @("Peruvian Instant Darkness Powder","Defence","8","120","15+","No"),
                   @("Pygmy Puffs","Pets","3","67","None","Yes"),
                   @("Decoy Detonators","Diversions","4","445","None","Yes"),
                   @("Puking Pastilles","Illness Inducers","1.5","1200","None","No"),
                   @("Shield Hats","Defence","12","89","None","No"),
                   @("WonderWitch Love Potions","Romance","6","234","16+","Yes"),
                   @("Headless Hats","Novelty","7","56","None","No"),
                   @("Canary Creams","Transformation","1","780","None","No")
               ) },
            @{ Name = "R&D Project Pipeline.pptx"; Type = "pptx"
               Title = "Weasleys Wizard Wheezes - 2026 R&D Pipeline"
               Subtitle = "CONFIDENTIAL - Fred and George Weasley"
               Bullets = @("Project Marauder: Self-updating map products (licensing pending)","Project Patronus: Pocket-sized happiness generators","Project Boggart: Scare-your-friends kits with shape-shifting technology","Project Galleon: Enchanted coins for secure messaging (based on DA design)","Budget: 2,400 Galleons approved by Gringotts business loan","Target launch: Hogwarts Easter holidays 2026") },
            @{ Name = "Sales Report FY2025.docx"; Type = "docx"
               Title = "Weasleys Wizard Wheezes - Annual Sales Report FY2025"
               Content = "Total Revenue: 47,832 Galleons (up 23% YoY). Top selling category: Skiving Snackboxes (32% of revenue). Fastest growing: Defence products (Shield Hats, Darkness Powder) up 145% since Ministry acknowledgment of You-Know-Who's return. Mail order now represents 41% of total sales. Hogsmeade weekend sales peak: 3,200 Galleons in single Saturday. Key metric: Zero product liability claims (unlike Zonko's - 14 claims). Outlook 2026: Expanding to mail-order-only International division (Beauxbatons and Durmstrang markets identified)." }
        )
    },

    # ── 6. MINISTRY OF MAGIC - DEPARTMENT OF MAGICAL LAW ENFORCEMENT ──
    @{
        DisplayName  = "Dept of Magical Law Enforcement"
        MailNickname = "MagicalLawEnforcement"
        Description  = "Official records for the Department of Magical Law Enforcement including Auror operations and Wizengamot proceedings"
        Documents    = @(
            @{ Name = "Most Wanted List - March 2026.xlsx"; Type = "xlsx"
               Headers = @("Name","Alias","Last Known Location","Threat Level","Bounty (Galleons)","Status","Assigned Auror")
               Rows = @(
                   @("Bellatrix Lestrange","None","Unknown","EXTREME","10,000","At Large","Tonks, N."),
                   @("Fenrir Greyback","The Werewolf","Northern Scotland","HIGH","5,000","At Large","Shacklebolt, K."),
                   @("Antonin Dolohov","None","Eastern Europe","HIGH","5,000","At Large","Moody, A."),
                   @("Augustus Rookwood","None","Unknown","MEDIUM","3,000","At Large","Dawlish, J."),
                   @("Peter Pettigrew","Wormtail","Unknown","HIGH","7,500","At Large","Unassigned")
               ) },
            @{ Name = "Auror Training Manual - Chapter 7 Counter-Jinxes.docx"; Type = "docx"
               Title = "Auror Training Manual - Chapter 7: Advanced Counter-Jinxes"
               Content = "MINISTRY RESTRICTED - Auror Cadets Only. Chapter 7 covers defensive spell-chains used in field operations. Key sequences: 1) Shield-and-Strike: Protego into immediate Stupefy (reaction time target: 0.3 seconds). 2) Displacement Defence: Apparate 2 metres left, cast Impedimenta, Apparate back. 3) Group Formation: Triangle formation with rotating Protego Totalum coverage. 4) Anti-Dark Mark Protocol: Upon sighting the Dark Mark, secure perimeter (400m radius), send Patronus messenger to HQ, do NOT engage alone. Remember: Constant Vigilance! (attributed to A. Moody, Senior Auror, Retired)." },
            @{ Name = "Wizengamot Case Log 2026.pptx"; Type = "pptx"
               Title = "Wizengamot - Active Cases Summary 2026"
               Subtitle = "Department of Magical Law Enforcement"
               Bullets = @("Case WZ-2026-001: Mundungus Fletcher - Theft of enchanted objects (Trial: March 20)","Case WZ-2026-002: Stan Shunpike - Death Eater association (under Imperius defence)","Case WZ-2026-003: Muggle-baiting incidents in Devon (4 defendants)","Case WZ-2026-004: Illegal dragon egg trafficking ring (7 defendants)","Case WZ-2026-005: Underage magic - 3 warnings issued this term","Backlog: 23 cases pending from 2025 (Wizengamot scheduling constraints)") }
        )
    },

    # ── 7. HOGWARTS LIBRARY - RESTRICTED SECTION ──
    @{
        DisplayName  = "Hogwarts Library Restricted Section"
        MailNickname = "HogwartsRestrictedSection"
        Description  = "Madam Pince's catalog of restricted books, access logs, and preservation records"
        Documents    = @(
            @{ Name = "Restricted Books Catalog.xlsx"; Type = "xlsx"
               Headers = @("Book Title","Author","Subject","Danger Level","Signed Permission Required","Last Borrowed","Condition")
               Rows = @(
                   @("Moste Potente Potions","Phineas Bourne","Advanced Potions","High","Professor + Headmaster","Oct 2025 (Granger, H.)","Fair - screams when opened"),
                   @("Secrets of the Darkest Art","Owle Bullock","Horcruxes","EXTREME","Headmaster ONLY","NEVER CIRCULATED","Chained to shelf"),
                   @("Magick Moste Evile","Godelot","Dark Arts Survey","Very High","Professor","Sep 2024","Good - bites"),
                   @("Fifteenth Century Fiends","Unknown","Dark Creatures","Medium","Professor","Jan 2026","Excellent"),
                   @("The Invisible Book of Invisibility","Unknown","Concealment","Low","None (if you can find it)","Unknown","Invisible")
               ) },
            @{ Name = "Book Preservation Schedule.docx"; Type = "docx"
               Title = "Library Preservation and Restoration Schedule 2026"
               Content = "Priority restorations for 2026: 1) Moste Potente Potions - rebinding required (spine cracked, pages attempting escape). 2) Monster Book of Monsters - 4 copies need new restraining belts. 3) Sonnets of a Sorcerer - re-enchant anti-reading-aloud charm (3 students hospitalised last term). 4) The Tales of Beedle the Bard (original edition) - parchment preservation charm renewal. Budget: 45 Galleons approved. Note from Madam Pince: If ONE MORE STUDENT dog-ears a page in ANY book, there will be consequences. The library is a sacred space, not a Quidditch pitch." }
        )
    },

    # ── 8. QUIDDITCH WORLD CUP ORGANIZATION ──
    @{
        DisplayName  = "Quidditch World Cup 2026"
        MailNickname = "QuidditchWorldCup2026"
        Description  = "Official planning and logistics for the 2026 Quidditch World Cup tournament"
        Documents    = @(
            @{ Name = "Team Rankings and Seedings.xlsx"; Type = "xlsx"
               Headers = @("Rank","Team","Country","Wins","Losses","Points","Star Player","Odds")
               Rows = @(
                   @("1","Irish National Team","Ireland","14","1","145","Troy, K.","3/1"),
                   @("2","Bulgarian National Team","Bulgaria","13","2","138","Krum, V.","4/1"),
                   @("3","Brazilian Quidditch Team","Brazil","12","3","127","Santos, G.","6/1"),
                   @("4","Japanese National Team","Japan","11","3","122","Tanaka, Y.","8/1"),
                   @("5","English National Team","England","10","4","109","(Manager: dispute)","10/1"),
                   @("6","Norwegian National Team","Norway","9","5","98","Berg, O.","15/1")
               ) },
            @{ Name = "Stadium Construction Plan.pptx"; Type = "pptx"
               Title = "Quidditch World Cup 2026 - Stadium and Logistics"
               Subtitle = "Department of Magical Games and Sports"
               Bullets = @("Venue: Bodmin Moor (same as 1994 - proven Muggle-Repelling Charms)","Capacity: 100,000 (enchanted seating, expandable to 120,000)","Campsite: 47 fields with pre-pitched magical tents","Security: 500 Ministry officials, Anti-Apparition jinxes within stadium","Muggle deterrent: Signs reading DANGEROUS BUILDING - DO NOT ENTER","Ticket sales: 87% sold (Top Box: SOLD OUT, General: 12,400 remaining)") },
            @{ Name = "Anti-Cheating Protocols.docx"; Type = "docx"
               Title = "Anti-Cheating and Fair Play Protocols - 2026 World Cup"
               Content = "All players subject to: 1) Pre-match wand inspection (Priori Incantatem check for performance-enhancing spells). 2) Broom inspection (Comet Trading Company certified, no aftermarket modifications over 10%). 3) Random Felix Felicis testing (zero tolerance - lifetime ban). 4) Referee enchantments: Impartial Reflex Charm applied before each match. 5) Anti-Confundus wards on all referees and linesmen. 6) Snitch release protocol: Triple-sealed by three independent officials from different countries. Any violations will result in forfeiture and referral to the International Confederation of Wizards." }
        )
    },

    # ── 9. HAGRID'S HUT - CARE OF MAGICAL CREATURES ──
    @{
        DisplayName  = "Hagrids Magical Creatures"
        MailNickname = "HagridsMagicalCreatures"
        Description  = "Rubeus Hagrid's creature care notes, lesson plans, and breeding program documentation"
        Documents    = @(
            @{ Name = "Creature Inventory - Hogwarts Grounds.xlsx"; Type = "xlsx"
               Headers = @("Creature","Quantity","Location","Danger Rating","Ministry Classification","Diet","Hagrid Rating")
               Rows = @(
                   @("Hippogriffs","12","Paddock (east)","XXX","Moderate","Ferrets, dead birds","Lovely"),
                   @("Thestrals","~30","Forbidden Forest","XXXX","Dangerous","Raw meat","Misunderstood"),
                   @("Blast-Ended Skrewts","0 (thankfully)","N/A (extinct batch)","XXXXX","EXTREME","Everything","Beautiful babies"),
                   @("Flobberworms","200+","Greenhouse 3","X","Harmless","Lettuce","Bit boring"),
                   @("Unicorns","~8","Deep Forbidden Forest","XXXX","Protected","Golden apples","Magnificent"),
                   @("Acromantulas","COLONY","Forbidden Forest - DO NOT ENTER","XXXXX","EXTREME","Anything that moves","Aragog was a friend"),
                   @("Nifflers","6","Secure pen (reinforced)","XXX","Moderate","Shiny things","Cheeky little fellas")
               ) },
            @{ Name = "Lesson Plans - Term 2.docx"; Type = "docx"
               Title = "Care of Magical Creatures - Lesson Plans Spring 2026"
               Content = "Week 1-2: Nifflers (practical - hide galleons in grounds, students recover). Week 3-4: Bowtruckles (theory + identification). Week 5-6: Hippogriff approach and respect protocol (MANDATORY safety briefing after the Malfoy incident). Week 7-8: Thestrals (sensitive topic - only visible to those who've witnessed death, handle with care). Week 9-10: Unicorns (4th years and above, girls approach first per traditional method). Week 11-12: EXAM - practical creature identification and safe handling. NOTE TO SELF: Do NOT bring Aragog's descendants into the classroom again. Dumbledore was very clear about this." },
            @{ Name = "Dragon Breeding Research - CONFIDENTIAL.pptx"; Type = "pptx"
               Title = "Dragon Species Conservation - Classified Research"
               Subtitle = "R. Hagrid (with C. Weasley, Romanian Reserve)"
               Bullets = @("Species studied: Norwegian Ridgeback, Hungarian Horntail, Common Welsh Green","Breeding success rate: 23% in captivity (up from 12% in 2020)","Norbert(a) update: Successfully integrated into Romanian colony","Key finding: Dragon eggs require constant temperature of 500F","Collaboration with Charlie Weasley's team at Romanian Dragon Sanctuary","REMINDER: Dragon breeding is ILLEGAL in Britain (but research is permitted)") }
        )
    },

    # ── 10. DAILY PROPHET NEWSROOM ──
    @{
        DisplayName  = "Daily Prophet Newsroom"
        MailNickname = "DailyProphetNews"
        Description  = "The Daily Prophet editorial offices, story drafts, and publication schedules"
        Documents    = @(
            @{ Name = "Editorial Calendar March 2026.xlsx"; Type = "xlsx"
               Headers = @("Date","Headline","Reporter","Section","Status","Editor Approval")
               Rows = @(
                   @("Mar 1","Ministry Increases Auror Recruitment Budget","Clearwater, P.","Politics","Published","Yes"),
                   @("Mar 3","Puddlemere United Sign New Keeper","Boot, T.","Quidditch","Published","Yes"),
                   @("Mar 5","Hogwarts Introduces Muggle Studies Reform","Skeeter, R.","Education","Under Review","Pending"),
                   @("Mar 8","Gringotts Reports Record Vault Applications","Unknown","Finance","Draft","No"),
                   @("Mar 10","EXCLUSIVE: Is He-Who-Must-Not-Be-Named Really Back?","Skeeter, R.","Front Page","KILLED","Editor Override"),
                   @("Mar 15","St Mungos Opens New Spell Damage Ward","Johnson, A.","Health","Assigned","N/A")
               ) },
            @{ Name = "Rita Skeeter - Employment Warning Letter.docx"; Type = "docx"
               Title = "PRIVATE AND CONFIDENTIAL - Formal Warning"
               Content = "Dear Ms Skeeter, This letter constitutes a FINAL WRITTEN WARNING regarding your continued use of unregistered Quick-Quotes Quills during interviews. You have been warned on three previous occasions (see: March 2024, September 2024, January 2025). Additionally, the Ministry of Magic has noted your unregistered Animagus status (beetle form) is pending investigation. Any further breaches of journalistic standards will result in immediate termination of your contract with The Daily Prophet. Furthermore, your profile piece on Harry Potter contained 27 factual inaccuracies. This is below our editorial standards. Signed: Barnabas Cuffe, Editor-in-Chief, The Daily Prophet." }
        )
    },

    # ── 11. ROOM OF REQUIREMENT - DUMBLEDORE'S ARMY ──
    @{
        DisplayName  = "Dumbledores Army HQ"
        MailNickname = "DumbledoresArmy"
        Description  = "Secret training materials and membership records for Dumbledore's Army (DA)"
        Documents    = @(
            @{ Name = "DA Membership Roster.xlsx"; Type = "xlsx"
               Headers = @("Name","House","Year","Patronus Form","Skill Level","Attendance Rate","Galleon Coin Number")
               Rows = @(
                   @("Harry Potter","Gryffindor","5th","Stag","Instructor","100%","001"),
                   @("Hermione Granger","Gryffindor","5th","Otter","Advanced","100%","002"),
                   @("Ron Weasley","Gryffindor","5th","Jack Russell Terrier","Intermediate","85%","003"),
                   @("Neville Longbottom","Gryffindor","5th","(In progress)","Improving Rapidly","95%","004"),
                   @("Luna Lovegood","Ravenclaw","4th","Hare","Intermediate","90%","005"),
                   @("Ginny Weasley","Gryffindor","4th","Horse","Advanced","92%","006"),
                   @("Cho Chang","Ravenclaw","6th","Swan","Intermediate","60%","007")
               ) },
            @{ Name = "DA Training Curriculum.pptx"; Type = "pptx"
               Title = "Dumbledores Army - Defence Training Curriculum"
               Subtitle = "Instructor: Harry Potter - Room of Requirement"
               Bullets = @("Week 1-2: Expelliarmus (Disarming Charm) - foundation of all duelling","Week 3-4: Impedimenta and Stupefy - stopping opponents","Week 5-6: Reducto - destruction of obstacles under pressure","Week 7-8: Patronus Charm (ADVANCED) - Dementor defence","Week 9-10: Shield Charms - Protego and Protego Totalum","Final Assessment: Full duelling tournament (bracketed, non-lethal spells only)") },
            @{ Name = "The DA Charter - KEEP SECRET.docx"; Type = "docx"
               Title = "Dumbledores Army - Official Charter"
               Content = "We the undersigned hereby pledge to learn and practise Defence Against the Dark Arts under the instruction of Harry Potter, in defiance of Educational Decree Number Twenty-Four. We agree to: 1) Never reveal the existence of the DA to any member of the Inquisitorial Squad or Dolores Umbridge. 2) Attend all scheduled sessions in the Room of Requirement. 3) Practise assigned spells between sessions. 4) Support fellow members regardless of House. JINX WARNING: This parchment has been enchanted by Hermione Granger. Any member who betrays the DA will suffer consequences. (See: Marietta Edgecombe - SNEAK)." }
        )
    },

    # ── 12. MALFOY MANOR ENTERPRISES ──
    @{
        DisplayName  = "Malfoy Manor Enterprises"
        MailNickname = "MalfoyEnterprise"
        Description  = "Malfoy family business holdings, property management, and political donations"
        Documents    = @(
            @{ Name = "Property Portfolio.xlsx"; Type = "xlsx"
               Headers = @("Property","Location","Value (Galleons)","Status","Annual Income","Tenants")
               Rows = @(
                   @("Malfoy Manor","Wiltshire","2,500,000","Primary Residence","N/A","Family"),
                   @("Borgin and Burkes (silent partner)","Knockturn Alley","180,000","Investment","12,000","Mr Borgin"),
                   @("Diagon Alley - 47-49","Diagon Alley","340,000","Commercial Let","24,000","Various shops"),
                   @("Hogsmeade Cottage","Hogsmeade","95,000","Holiday Home","N/A","Vacant"),
                   @("French Chateau","Provence","450,000","Holiday Home","N/A","House-elves (3)")
               ) },
            @{ Name = "Political Donation Records.docx"; Type = "docx"
               Title = "Malfoy Family - Charitable and Political Donations FY2025"
               Content = "PRIVATE AND CONFIDENTIAL. Ministry of Magic - General Fund: 5,000 Galleons. St Mungos Hospital Wing Renovation: 10,000 Galleons. Minister Fudge Re-Election Campaign: 15,000 Galleons (anonymous). Hogwarts School Governors Fund: 8,000 Galleons. Slytherin House Quidditch Equipment (Nimbus 2001 brooms x7): 4,900 Galleons. Department of International Magical Cooperation: 3,000 Galleons. Note from Lucius: Ensure all donations are recorded as charitable for tax purposes. The Minister was most appreciative of our continued support. Narcissa's garden party raised an additional 7,200 Galleons for the Governors." }
        )
    },

    # ── 13. HOGWARTS EXPRESS OPERATIONS ──
    @{
        DisplayName  = "Hogwarts Express Operations"
        MailNickname = "HogwartsExpress"
        Description  = "Platform 9 3/4 logistics, train maintenance schedules, and passenger manifests"
        Documents    = @(
            @{ Name = "Train Maintenance Schedule 2026.xlsx"; Type = "xlsx"
               Headers = @("Component","Last Service","Next Service","Engineer","Status","Priority")
               Rows = @(
                   @("Steam Engine (enchanted)","Jan 2026","Jul 2026","Grimshaw, T.","Operational","Normal"),
                   @("Invisibility Booster","Dec 2025","Jun 2026","Weasley, A. (consulted)","Operational","High"),
                   @("Food Trolley (enchanted refill)","Feb 2026","Apr 2026","Honeydukes Contract","Operational","Normal"),
                   @("Platform 9 3/4 Barrier","Weekly","Weekly","Ministry Maintenance","Operational","Critical"),
                   @("Compartment Heating Charms","Oct 2025","Sep 2026","Flitwick, F. (annual)","Operational","Normal"),
                   @("Emergency Braking Charm","Mar 2026","Sep 2026","Grimshaw, T.","RENEWED","Critical")
               ) },
            @{ Name = "Passenger Safety Procedures.pptx"; Type = "pptx"
               Title = "Hogwarts Express - Safety and Emergency Procedures"
               Subtitle = "Platform 9 3/4 Operations Team"
               Bullets = @("All students must be seated when the train crosses magical boundary zones","Prefects patrol corridors every 30 minutes (2 per carriage)","Emergency stop: Pull red chain OR cast Arresto Momentum on brake lever","Dementor protocol: Seal compartments, chocolate distribution, Patronus-capable staff to front","Lost pet procedure: Owl Post to Hogsmeade station for collection","Platform barrier closes at 11:00 AM SHARP - no exceptions (see: Potter/Weasley flying car incident 1992)") }
        )
    },

    # ── 14. ST MUNGO'S HOSPITAL ──
    @{
        DisplayName  = "St Mungos Hospital"
        MailNickname = "StMungosHospital"
        Description  = "St Mungo's Hospital for Magical Maladies and Injuries - ward records and treatment guidelines"
        Documents    = @(
            @{ Name = "Ward Occupancy Report.xlsx"; Type = "xlsx"
               Headers = @("Ward","Floor","Speciality","Beds","Occupancy","Head Healer","Waiting List")
               Rows = @(
                   @("Dai Llewellyn","Ground","Creature Injuries","40","85%","Healer Smethwyck","12 patients"),
                   @("Janus Thickey","4th","Permanent Spell Damage","20","100%","Healer Strout","8 patients"),
                   @("Potion and Plant Poisoning","3rd","Toxicology","30","60%","Healer Pye","None"),
                   @("Magical Bugs","2nd","Infectious Diseases","35","45%","Healer Augustus","3 patients"),
                   @("Artifact Accidents","1st","Cursed Objects","25","70%","Healer Miriam","5 patients")
               ) },
            @{ Name = "Spell Damage Research Paper.docx"; Type = "docx"
               Title = "Long-Term Effects of Memory Charm Overexposure - A Case Study"
               Content = "Patient: Gilderoy Lockhart (admitted 1993, ongoing). Diagnosis: Catastrophic Memory Charm backfire resulting in permanent retrograde and anterograde amnesia. Treatment attempts: 1) Standard Memory Restoration Potion - no effect. 2) Pensieve memory re-integration - partial success (can now sign autographs). 3) Experimental Remembrall-enhanced therapy - ongoing. Prognosis: Permanent residency in Janus Thickey Ward. The patient remains cheerful and continues to sign photographs for visitors. This case demonstrates the extreme danger of performing Memory Charms with a damaged wand. Published with permission of St Mungos Ethics Board." }
        )
    },

    # ── 15. DEPARTMENT OF MYSTERIES ──
    @{
        DisplayName  = "Department of Mysteries"
        MailNickname = "DeptOfMysteries"
        Description  = "CLASSIFIED - Unspeakable research division of the Ministry of Magic"
        Documents    = @(
            @{ Name = "Time Turner Decommission Log.xlsx"; Type = "xlsx"
               Headers = @("Serial Number","Manufacture Date","Last Assigned To","Hours Used","Status","Destruction Method","Witness")
               Rows = @(
                   @("TT-1847-A","1847","CLASSIFIED","Unknown","DESTROYED","Battle of Dept of Mysteries","Unspeakable Bode"),
                   @("TT-1903-B","1903","CLASSIFIED","3,400","DESTROYED","Battle of Dept of Mysteries","Unspeakable Croaker"),
                   @("TT-1993-C","1993","Granger, H. (Hogwarts)","~200","DESTROYED","Battle of Dept of Mysteries","N/A"),
                   @("TT-1956-D","1956","CLASSIFIED","CLASSIFIED","DESTROYED","Battle of Dept of Mysteries","Unspeakable Saul")
               ) },
            @{ Name = "Prophecy Registry - Active.docx"; Type = "docx"
               Title = "Hall of Prophecy - Active Registry (CLASSIFIED)"
               Content = "CLASSIFICATION: TOP SECRET - UNSPEAKABLE ACCESS ONLY. Total prophecies stored: 3,247. Prophecies fulfilled: 1,892. Prophecies pending: 1,355. PRIORITY PROPHECY - Row 97: S.P.T. to A.P.W.B.D. regarding Dark Lord and the one with the power to vanquish him. Status: PARTIALLY FULFILLED. Shelf destroyed during Battle of the Department of Mysteries (June 1996). Audio recording: LOST. Only known witnesses to full prophecy: Albus Dumbledore, Sybill Trelawney. WARNING: Multiple unauthorised access attempts detected. Security upgraded to Level 9 clearance required." }
        )
    },

    # ── 16. HOGSMEADE VILLAGE COUNCIL ──
    @{
        DisplayName  = "Hogsmeade Village Council"
        MailNickname = "HogsmeadeVillage"
        Description  = "Hogsmeade village governance, business licensing, and Hogwarts weekend coordination"
        Documents    = @(
            @{ Name = "Business Directory 2026.xlsx"; Type = "xlsx"
               Headers = @("Business","Owner","Type","License Expiry","Annual Fee","Hogwarts Discount")
               Rows = @(
                   @("Three Broomsticks","Madam Rosmerta","Pub/Inn","Dec 2026","120 Galleons","10% (Butterbeer only)"),
                   @("Honeydukes","Ambrosius Flume","Sweet Shop","Mar 2027","95 Galleons","5%"),
                   @("Zonkos Joke Shop","CLOSED","Joke Shop","N/A","N/A","N/A"),
                   @("Hogs Head Inn","Aberforth Dumbledore","Pub","Dec 2026","80 Galleons","None"),
                   @("Madam Puddifoots","Madam Puddifoot","Tea Shop","Jun 2026","60 Galleons","Valentines Special"),
                   @("Dervish and Banges","Mr Dervish","Magical Equipment","Sep 2026","100 Galleons","15%"),
                   @("Scrivenshafts","Mr Scrivenshaft","Quill Shop","Dec 2026","55 Galleons","10%"),
                   @("Gladrags Wizardwear","Unknown","Clothing","Dec 2026","90 Galleons","None")
               ) },
            @{ Name = "Hogsmeade Weekend Schedule.docx"; Type = "docx"
               Title = "Hogwarts Visit Weekends - Spring 2026 Schedule"
               Content = "Approved Hogsmeade weekends for Spring Term: March 8, April 5, May 10, June 7. Regulations: 1) 3rd year and above only (signed permission slip required). 2) Students must return by 6:00 PM. 3) The Shrieking Shack remains OFF LIMITS. 4) Maximum of 3 Butterbeers per student (Madam Rosmerta's request). 5) Filch will check all bags upon return for Zonko's contraband. 6) Teachers on patrol duty: March - Snape and Flitwick, April - McGonagall and Sprout, May - Hagrid and Sinistra, June - Lupin (if available) and Vector." }
        )
    },

    # ── 17. HOGWARTS HOUSE POINTS ADMINISTRATION ──
    @{
        DisplayName  = "Hogwarts House Points"
        MailNickname = "HogwartsHousePoints"
        Description  = "Official house points tracking, professor allocation records, and annual cup results"
        Documents    = @(
            @{ Name = "House Points Standings 2025-2026.xlsx"; Type = "xlsx"
               Headers = @("House","Points Earned","Points Deducted","Net Points","Leading Professor (Awards)","Leading Professor (Deductions)","Rank")
               Rows = @(
                   @("Gryffindor","1,247","389","858","Dumbledore (last-minute)","Snape (312 of 389)","2nd"),
                   @("Slytherin","1,198","142","1,056","Snape","McGonagall","1st"),
                   @("Ravenclaw","987","178","809","Flitwick","Snape","3rd"),
                   @("Hufflepuff","934","98","836","Sprout","Snape","4th (but 1st in our hearts)")
               ) },
            @{ Name = "Points Dispute Resolution Policy.docx"; Type = "docx"
               Title = "House Points - Dispute Resolution and Fair Allocation Policy"
               Content = "Following multiple complaints (primarily from Gryffindor House), the following policy is in effect: 1) No professor may deduct more than 50 points from a single student in one incident. 2) Points awarded after the House Cup feast are limited to genuine exceptional circumstances. 3) Professor Snape has been reminded that 'breathing too loudly in my classroom' is not grounds for a 10-point deduction. 4) All deductions over 20 points must be logged with the Deputy Headmistress. 5) End-of-year bonus points require Headmaster approval. Signed: M. McGonagall, Deputy Headmistress. Countersigned (reluctantly): S. Snape." }
        )
    },

    # ── 18. FORBIDDEN FOREST RESEARCH STATION ──
    @{
        DisplayName  = "Forbidden Forest Research"
        MailNickname = "ForbiddenForestResearch"
        Description  = "Ecological research and creature conservation within the Forbidden Forest"
        Documents    = @(
            @{ Name = "Forest Census 2026.xlsx"; Type = "xlsx"
               Headers = @("Species","Estimated Population","Sector","Conservation Status","Threat to Students","Last Survey")
               Rows = @(
                   @("Centaurs (Herd)","~50","Central-North","Self-Governing","Low (avoid)","Jan 2026"),
                   @("Acromantulas","200-400","Deep East (Aragog's Hollow)","Thriving","EXTREME","Sep 2025"),
                   @("Unicorns","8-12","West Clearings","Protected","None","Feb 2026"),
                   @("Thestrals","28-35","Throughout","Stable","None (invisible to most)","Dec 2025"),
                   @("Bowtruckles","100+","Oak groves","Abundant","Very Low","Mar 2026"),
                   @("Werewolves","0-2 (transient)","Perimeter (full moon)","N/A","HIGH","Monthly patrol")
               ) },
            @{ Name = "Centaur Relations - Diplomatic Notes.docx"; Type = "docx"
               Title = "Centaur-Hogwarts Relations - Diplomatic Summary"
               Content = "Current status: STRAINED. The centaur herd, led by Magorian, has expressed displeasure at: 1) The appointment of Firenze as Divination professor (considered betrayal). 2) Increased student incursions during Care of Magical Creatures lessons. 3) The Umbridge incident (they do NOT wish to discuss it). Positive developments: Hagrid maintains cordial relations with Ronan and Bane. Centaurs agreed to alert castle of any Dark creature movement in the forest. Dumbledore's annual gift of enchanted star charts was well received. Recommendation: Maintain respectful distance. Do NOT enter the forest without Hagrid escort." }
        )
    },

    # ── 19. DOBBY'S SOCK FOUNDATION ──
    @{
        DisplayName  = "Dobbys Sock Foundation"
        MailNickname = "DobbysSockFoundation"
        Description  = "Charitable organization for house-elf welfare, founded in memory of Dobby the Free Elf"
        Documents    = @(
            @{ Name = "Sock Donation Tracker.xlsx"; Type = "xlsx"
               Headers = @("Donor","Socks Donated","Type","Recipient Elf","Freedom Achieved","Location")
               Rows = @(
                   @("Hermione Granger","147","Knitted (S.P.E.W.)","Various Hogwarts","No (they hid from them)","Hogwarts"),
                   @("Harry Potter","2","Mismatched","Dobby","YES (2nd time)","Malfoy Manor / Hogwarts"),
                   @("Albus Dumbledore","12","Thick woollen","Requested (declined)","N/A","Hogwarts"),
                   @("Ron Weasley","1","Maroon (Weasley jumper spare)","Unnamed","No","Hogwarts"),
                   @("Dobby (self-purchased)","43","Every colour and pattern","Self","Already Free","Various shops")
               ) },
            @{ Name = "S.P.E.W. Campaign Brief.pptx"; Type = "pptx"
               Title = "Society for the Promotion of Elfish Welfare"
               Subtitle = "Founded by Hermione Granger - 2 Sickles membership"
               Bullets = @("Mission: Secure fair wages and working conditions for house-elves","Current membership: 3 (Hermione, Harry - reluctant, Neville - pity)","Campaigns: Stop the Outrageous Abuse of Our Fellow Magical Creatures","Key demand: Sick leave, holidays, and pension rights for all house-elves","Challenge: Most house-elves do not WANT to be freed (cultural consideration)","Next steps: Petition the Ministry (signatures needed: 1,000 - current: 3)") }
        )
    },

    # ── 20. MARAUDER'S MAP PROJECT ──
    @{
        DisplayName  = "Marauders Map Archive"
        MailNickname = "MaraudersMapArchive"
        Description  = "Historical archive of the Marauder's Map creation, including enchantment research and Hogwarts cartography"
        Documents    = @(
            @{ Name = "Original Enchantment Research.docx"; Type = "docx"
               Title = "The Marauders Map - Enchantment Documentation"
               Content = "Authors: Moony (Remus Lupin), Wormtail (Peter Pettigrew), Padfoot (Sirius Black), Prongs (James Potter). Created: 1975-1978. Core enchantments: 1) Homonculous Charm - tracks every person within Hogwarts grounds in real-time. 2) Insult-generating charm (responds to Snape specifically with customised messages). 3) Concealment: Appears as blank parchment unless activated. Activation: 'I solemnly swear that I am up to no good.' Deactivation: 'Mischief managed.' The map shows every classroom, corridor, and secret passage including 7 passages to Hogsmeade. It CANNOT be fooled by Animagi, Invisibility Cloaks, or Polyjuice Potion." },
            @{ Name = "Hogwarts Secret Passages.xlsx"; Type = "xlsx"
               Headers = @("Passage","Entrance","Exit","Status","Discovered By","Known Users")
               Rows = @(
                   @("One-Eyed Witch","3rd floor (behind statue)","Honeydukes cellar","OPEN","Marauders","Potter, Weasley twins"),
                   @("Whomping Willow","Base of tree (knot)","Shrieking Shack","OPEN (dangerous)","Marauders","Lupin, Black, Pettigrew"),
                   @("4th Floor","Behind mirror","Hogsmeade (unknown exit)","CAVED IN","Marauders","None currently"),
                   @("Gregory the Smarmy","Behind statue","Unknown exit","CAVED IN","Unknown","Historical only"),
                   @("Room of Requirement","7th floor corridor","Hogs Head Inn","OPEN","Neville Longbottom","DA members"),
                   @("Vanishing Cabinet","Room of Requirement","Borgin and Burkes","REPAIRED (compromised)","Draco Malfoy","Death Eaters")
               ) },
            @{ Name = "Marauders Map Replication Study.pptx"; Type = "pptx"
               Title = "Can the Marauders Map Be Replicated? - Charms Research"
               Subtitle = "Professor Flitwick - Advanced Charms Seminar"
               Bullets = @("The Homonculous Charm is considered lost magic - no modern equivalent exists","Closest attempt: Ministry tracking charms (limited to 50m radius)","Key challenge: Real-time tracking of 1000+ individuals simultaneously","Theoretical requirement: Intimate knowledge of EVERY room in the target building","The Marauders spent 3 YEARS mapping Hogwarts including 7 secret passages","Conclusion: Replication would require comparable genius and comparable disregard for rules") }
        )
    }
)

# ═══════════════════════════════════════════
#  EXECUTION
# ═══════════════════════════════════════════

# ── Verify Graph connection & auto-detect tenant ──
$context = Get-MgContext
if (-not $context) {
    Write-Host "⚠️  Not connected to Microsoft Graph. Connecting now..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Group.ReadWrite.All","Sites.ReadWrite.All","Files.ReadWrite.All" -NoWelcome
    $context = Get-MgContext
    if (-not $context) {
        Write-Error "Failed to connect to Microsoft Graph. Exiting."
        exit 1
    }
}

# Auto-detect tenant ID from session
$TenantId = $context.TenantId

# Auto-detect signed-in user as owner
$me = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me?`$select=id,userPrincipalName,mail" -OutputType PSObject
$ownerId = $me.id
$OwnerUPN = $me.userPrincipalName

# Auto-detect SharePoint tenant domain from the org's verified domains
$org = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization?`$select=verifiedDomains" -OutputType PSObject
$onmicrosoft = ($org.value[0].verifiedDomains | Where-Object { $_.name -like "*.onmicrosoft.com" -and $_.name -notlike "*.mail.onmicrosoft.com" }).name
if ($onmicrosoft) {
    $TenantDomain = $onmicrosoft -replace '\.onmicrosoft\.com$',''
} else {
    # Fallback: derive from UPN domain
    $TenantDomain = ($OwnerUPN -split '@')[1] -replace '\.onmicrosoft\.com$',''
}

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🏰 HARRY POTTER SHAREPOINT DEMO ENVIRONMENT SETUP 🏰  ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Tenant ID:     $TenantId" -ForegroundColor Gray
Write-Host "   Tenant Domain: $TenantDomain.onmicrosoft.com" -ForegroundColor Gray
Write-Host "   SharePoint:    https://$TenantDomain.sharepoint.com" -ForegroundColor Gray
Write-Host "   Owner:         $OwnerUPN ($ownerId)" -ForegroundColor Gray
Write-Host ""

$totalSites = $siteDefs.Count
$siteNum = 0
$results = @()

foreach ($siteDef in $siteDefs) {
    $siteNum++
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "[$siteNum/$totalSites] 📁 Creating: $($siteDef.DisplayName)" -ForegroundColor Yellow
    
    # ── Create M365 Group ──
    try {
        $groupParams = @{
            DisplayName     = $siteDef.DisplayName
            MailNickname    = $siteDef.MailNickname
            Description     = $siteDef.Description
            MailEnabled     = $true
            SecurityEnabled = $false
            GroupTypes      = @("Unified")
            Visibility      = "Private"
            "Members@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$ownerId")
            "Owners@odata.bind"  = @("https://graph.microsoft.com/v1.0/users/$ownerId")
        }
        
        # Check if group already exists (re-run safe)
        $existingGroup = Get-MgGroup -Filter "mailNickname eq '$($siteDef.MailNickname)'" -ErrorAction SilentlyContinue
        if ($existingGroup) {
            $group = $existingGroup
            Write-Host "   ↺ Group already exists: $($group.Id) — skipping creation" -ForegroundColor DarkCyan
        } else {
            $group = New-MgGroup -BodyParameter $groupParams
            Write-Host "   ✓ Group created: $($group.Id)" -ForegroundColor Green
        }
        
        # Wait for SharePoint site provisioning (poll until drive is ready)
        Write-Host "   ⏳ Waiting for SharePoint provisioning..." -ForegroundColor DarkYellow
        $driveReady = $false
        $maxRetries = 12  # up to 60 seconds
        for ($retry = 1; $retry -le $maxRetries; $retry++) {
            try {
                $driveCheck = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$($group.Id)/drive" -OutputType PSObject -ErrorAction Stop
                if ($driveCheck.id) {
                    $driveReady = $true
                    Write-Host "   ✓ SharePoint drive ready (took ~$($retry * 5)s)" -ForegroundColor Green
                    break
                }
            } catch {
                # Drive not provisioned yet
            }
            Start-Sleep -Seconds 5
        }
        
        if (-not $driveReady) {
            Write-Host "   ⚠️ Drive not ready after 60s — uploading with retry..." -ForegroundColor DarkYellow
        }
        
        # ── Upload documents (with per-file retry) ──
        $docCount = 0
        foreach ($doc in $siteDef.Documents) {
            $docCount++
            try {
                $tempFile = $null
                
                switch ($doc.Type) {
                    "docx" {
                        $tempFile = New-MinimalDocx -Title $doc.Title -TextContent $doc.Content
                    }
                    "xlsx" {
                        $tempFile = New-MinimalXlsx -Headers $doc.Headers -Rows $doc.Rows
                    }
                    "pptx" {
                        $tempFile = New-MinimalPptx -Title $doc.Title -Subtitle $doc.Subtitle -BulletPoints $doc.Bullets
                    }
                }
                
                if ($tempFile -and (Test-Path $tempFile)) {
                    $uploaded = $false
                    for ($uploadRetry = 1; $uploadRetry -le 3; $uploadRetry++) {
                        try {
                            Upload-ToSharePoint -GroupId $group.Id -FilePath $tempFile -FileName $doc.Name
                            Write-Host "   📄 [$docCount/$($siteDef.Documents.Count)] $($doc.Name)" -ForegroundColor Gray
                            $uploaded = $true
                            break
                        } catch {
                            if ($uploadRetry -lt 3) { Start-Sleep -Seconds 5 }
                        }
                    }
                    if (-not $uploaded) {
                        Write-Host "   ⚠️ Failed to upload $($doc.Name) after 3 retries" -ForegroundColor DarkYellow
                    }
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            } catch {
                Write-Host "   ⚠️ Failed to create $($doc.Name): $($_.Exception.Message)" -ForegroundColor DarkYellow
            }
        }
        
        $siteUrl = "https://$TenantDomain.sharepoint.com/sites/$($siteDef.MailNickname)"
        $results += [PSCustomObject]@{
            Site      = $siteDef.DisplayName
            URL       = $siteUrl
            GroupId   = $group.Id
            Documents = $siteDef.Documents.Count
            Status    = "✅ Success"
        }
        
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Site      = $siteDef.DisplayName
            URL       = "N/A"
            GroupId   = "N/A"
            Documents = 0
            Status    = "❌ Failed"
        }
    }
}

# ═══════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              📊 DEPLOYMENT SUMMARY                      ║" -ForegroundColor White
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -AutoSize

$succeeded = ($results | Where-Object { $_.Status -like "*Success*" }).Count
$failed = ($results | Where-Object { $_.Status -like "*Failed*" }).Count
$totalDocs = ($results | Measure-Object -Property Documents -Sum).Sum

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Sites created: $succeeded / $totalSites" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "Documents uploaded: $totalDocs" -ForegroundColor Green
Write-Host "Sites failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "🏰 Your Hogwarts demo environment is ready!" -ForegroundColor Cyan
Write-Host "   SharePoint Home: https://$TenantDomain.sharepoint.com" -ForegroundColor Gray
Write-Host ""
