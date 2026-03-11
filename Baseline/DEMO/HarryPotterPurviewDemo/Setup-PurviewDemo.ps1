##############################################################################
#  Setup-PurviewDemo.ps1
#  Hogwarts Purview Demo — Full Setup Script
#
#  What this does:
#    1. Adds Dolores Umbridge to Order of the Phoenix + Dumbledore's Army
#       sites (required for Act 1 — showing the oversharing problem)
#    2. Creates the "Order of the Phoenix — Restricted" sensitivity label
#       with encryption scoped to the Gryffindor dynamic group
#    3. Creates and publishes the label policy
#
#  Prerequisites:
#    - ExchangeOnlineManagement module v3+ (for Connect-IPPSSession)
#    - Run as Global Admin or Compliance Admin
#
#  Usage:
#    ./Setup-PurviewDemo.ps1 -TenantDomain "contoso.onmicrosoft.com"
##############################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TenantDomain,

    [string]$AdminUPN,              # Optional — if omitted, uses interactive IPPS auth

    [switch]$SkipSitePermissions,
    [switch]$SkipSensitivityLabel,
    [switch]$SkipLabelPolicy
)

# Derive SPO prefix from tenant domain (e.g. contoso.onmicrosoft.com → contoso)
$TenantPrefix      = $TenantDomain -replace '\.onmicrosoft\.com$' -replace '\..*$'

$DoloresUPN        = "dolores.umbridge@$TenantDomain"

# SharePoint site URLs (derived from tenant domain)
$OotPSiteUrl       = "https://$TenantPrefix.sharepoint.com/sites/OrderOfThePhoenix"
$DASiteUrl         = "https://$TenantPrefix.sharepoint.com/sites/DumbledoresArmy"

# M365 Group IDs — resolved by mailNickname at runtime so script works in any tenant
# (Override these as parameters if needed)
$OotPGroupId       = $null   # Resolved below via Graph
$DAGroupId         = $null   # Resolved below via Graph

# Sensitivity label settings
$LabelName         = "Order of the Phoenix — Restricted"       # Internal name (no emoji)
$LabelDisplayName  = "🛡️ Order of the Phoenix — Restricted"     # Display name shown to users
$LabelPolicyName   = "Order of the Phoenix Protection Policy"

##############################################################################
# SECTION 1 — Add Dolores Umbridge to both SharePoint sites
# Required for Act 1 of the demo (showing oversharing BEFORE labels)
##############################################################################

if (-not $SkipSitePermissions) {
    Write-Host "`n=== SECTION 1: Adding Dolores Umbridge to demo sites ===" -ForegroundColor Cyan
    Write-Host "This is required for Act 1 — Dolores must have site access to" -ForegroundColor Yellow
    Write-Host "demonstrate the oversharing problem BEFORE labels are applied." -ForegroundColor Yellow

    # Connect to Microsoft Graph to add group members
    Write-Host "`nConnecting to Microsoft Graph..." -ForegroundColor Gray
    Connect-MgGraph -Scopes "GroupMember.ReadWrite.All", "User.Read.All" -TenantId $TenantDomain -NoWelcome

    # Resolve OotP and DA group IDs by mailNickname
    Write-Host "  Resolving site group IDs..." -ForegroundColor Gray
    $OotPGroupObj = Get-MgGroup -Filter "mailNickname eq 'OrderOfThePhoenix'" -Property Id,DisplayName -ErrorAction SilentlyContinue
    $DAGroupObj   = Get-MgGroup -Filter "mailNickname eq 'DumbledoresArmy'" -Property Id,DisplayName -ErrorAction SilentlyContinue
    if ($OotPGroupObj) { $OotPGroupId = $OotPGroupObj.Id; Write-Host "  Found OotP group: $($OotPGroupObj.DisplayName)" -ForegroundColor Gray }
    else { Write-Warning "  Could not find Order of the Phoenix group (mailNickname: OrderOfThePhoenix)" }
    if ($DAGroupObj)   { $DAGroupId   = $DAGroupObj.Id;   Write-Host "  Found DA group: $($DAGroupObj.DisplayName)" -ForegroundColor Gray }
    else { Write-Warning "  Could not find Dumbledore's Army group (mailNickname: DumbledoresArmy)" }

    # Get Dolores's user ID
    try {
        $Dolores = Get-MgUser -UserId $DoloresUPN -Property Id, DisplayName
        Write-Host "Found user: $($Dolores.DisplayName) ($($Dolores.Id))" -ForegroundColor Green
    }
    catch {
        Write-Error "Could not find Dolores Umbridge ($DoloresUPN). Check the UPN and try again."
        exit 1
    }

    # Helper function to add a user to a group if not already a member
    function Add-UserToGroup {
        param(
            [string]$GroupId,
            [string]$UserId,
            [string]$FriendlyName
        )

        # Check existing membership
        $existing = Get-MgGroupMember -GroupId $GroupId -All |
                    Where-Object { $_.Id -eq $UserId }

        if ($existing) {
            Write-Host "  ✅ Already a member of $FriendlyName" -ForegroundColor Green
        }
        else {
            try {
                New-MgGroupMember -GroupId $GroupId -DirectoryObjectId $UserId
                Write-Host "  ✅ Added to $FriendlyName" -ForegroundColor Green
            }
            catch {
                Write-Warning "  ⚠️ Could not add to $FriendlyName — $($_.Exception.Message)"
                Write-Host "     Try manually: SharePoint site → Settings → Site Permissions → Add $DoloresUPN" -ForegroundColor Yellow
            }
        }
    }

    Write-Host "`nAdding Dolores to Order of the Phoenix (Group: $OotPGroupId)..."
    Add-UserToGroup -GroupId $OotPGroupId -UserId $Dolores.Id -FriendlyName "Order of the Phoenix"

    Write-Host "Adding Dolores to Dumbledore's Army HQ (Group: $DAGroupId)..."
    Add-UserToGroup -GroupId $DAGroupId -UserId $Dolores.Id -FriendlyName "Dumbledore's Army HQ"

    Write-Host "`n⏱️  Note: Group membership changes can take 5-15 minutes to propagate" -ForegroundColor Yellow
    Write-Host "    to SharePoint. Dolores may need to sign out and back in." -ForegroundColor Yellow
}

##############################################################################
# SECTION 2 — Create the Sensitivity Label
##############################################################################

if (-not $SkipSensitivityLabel) {
    Write-Host "`n=== SECTION 2: Creating Sensitivity Label ===" -ForegroundColor Cyan

    # Connect to Security & Compliance Center
    Write-Host "Connecting to Security & Compliance Center (IPPS)..." -ForegroundColor Gray
    $ippsParams = @{}
    if ($AdminUPN) { $ippsParams['UserPrincipalName'] = $AdminUPN }
    Connect-IPPSSession @ippsParams

    # Ensure Graph is connected (needed if -SkipSitePermissions was used)
    try { Get-MgContext -ErrorAction Stop | Out-Null }
    catch {
        Write-Host "  Connecting to Microsoft Graph for group lookup..." -ForegroundColor Gray
        Connect-MgGraph -Scopes "Group.Read.All" -TenantId $TenantDomain -NoWelcome
    }
    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "Group.Read.All" -TenantId $TenantDomain -NoWelcome
    }

    # Check if label already exists
    $existingLabel = Get-Label | Where-Object { $_.Name -eq $LabelName -or $_.DisplayName -eq $LabelDisplayName }

    if ($existingLabel) {
        Write-Host "  ⚠️  Label '$LabelDisplayName' already exists (GUID: $($existingLabel.ImmutableId))" -ForegroundColor Yellow
        Write-Host "     Skipping creation. Delete it first if you want to recreate it." -ForegroundColor Yellow
    }
    else {
        Write-Host "  Creating label: $LabelDisplayName" -ForegroundColor Gray

        # Resolve the Gryffindor group by display name (portable across tenants)
        Write-Host "  Resolving Gryffindor group..." -ForegroundColor Gray
        $GryffindorGroup = Get-MgGroup -Filter "displayName eq '🦁 Gryffindor – Dynamic User Group'" `
                           -Property "Id,DisplayName,Mail" -ErrorAction SilentlyContinue
        if (-not $GryffindorGroup) {
            # Fallback: search by partial name
            $GryffindorGroup = Get-MgGroup -Search '"displayName:Gryffindor"' `
                               -ConsistencyLevel eventual -Property "Id,DisplayName,Mail" |
                               Where-Object { $_.DisplayName -match 'Gryffindor' -and $_.DisplayName -match 'Dynamic' } |
                               Select-Object -First 1
        }
        if (-not $GryffindorGroup) {
            Write-Error "Could not find Gryffindor dynamic group. Ensure it exists before running this script."
            exit 1
        }
        Write-Host "  Gryffindor group: $($GryffindorGroup.DisplayName)" -ForegroundColor Gray

        # Security groups have no mail address — enumerate members and build rights from UPNs
        # EncryptionRightsDefinitions format: "upn1:RIGHTS;upn2:RIGHTS"
        Write-Host "  Fetching Gryffindor group members for encryption rights..." -ForegroundColor Gray
        $gryffMembers = Get-MgGroupMember -GroupId $GryffindorGroup.Id -All |
                        ForEach-Object { Get-MgUser -UserId $_.Id -Property UserPrincipalName }
        if ($gryffMembers.Count -eq 0) {
            Write-Error "Gryffindor group has no members. Ensure dynamic group has populated before running."
            exit 1
        }
        Write-Host "  Members ($($gryffMembers.Count)): $($gryffMembers.UserPrincipalName -join ', ')" -ForegroundColor Gray
        $RightsDefinitions = ($gryffMembers | ForEach-Object { "$($_.UserPrincipalName):COAUTHOR" }) -join ";"

        # Create the label with encryption scoped to Gryffindor
        $NewLabel = New-Label `
            -Name $LabelName `
            -DisplayName $LabelDisplayName `
            -Comment "Encrypts content and restricts access to the Gryffindor dynamic security group. Used for Order of the Phoenix and DA sensitive documents." `
            -Tooltip "This content is restricted to members of the Order of the Phoenix (Gryffindor house members only). Do not share externally." `
            -ContentType "File, Email, Site, UnifiedGroup" `
            -EncryptionEnabled $true `
            -EncryptionProtectionType "Template" `
            -EncryptionRightsDefinitions $RightsDefinitions `
            -EncryptionOfflineAccessDays -1 `
            -EncryptionDoNotForward $false `
            -EncryptionEncryptOnly $false `
            -ApplyContentMarkingHeaderEnabled $true `
            -ApplyContentMarkingHeaderText "ORDER OF THE PHOENIX — RESTRICTED" `
            -ApplyContentMarkingHeaderFontSize 12 `
            -ApplyContentMarkingHeaderFontColor "#FF0000" `
            -ApplyContentMarkingHeaderAlignment "Center" `
            -ApplyContentMarkingFooterEnabled $true `
            -ApplyContentMarkingFooterText "Access restricted to Gryffindor members only" `
            -ApplyContentMarkingFooterFontSize 10 `
            -ApplyContentMarkingFooterFontColor "#FF0000" `
            -ApplyContentMarkingFooterAlignment "Center" `
            -ApplyWaterMarkingEnabled $true `
            -ApplyWaterMarkingText "CONFIDENTIAL — OotP" `
            -ApplyWaterMarkingFontSize 24 `
            -ApplyWaterMarkingFontColor "#FF0000" `
            -ApplyWaterMarkingLayout "Diagonal"

        Write-Host "  ✅ Label created: $($NewLabel.DisplayName)" -ForegroundColor Green
        Write-Host "     GUID: $($NewLabel.ImmutableId)" -ForegroundColor Gray
    }
}

##############################################################################
# SECTION 3 — Create and Publish the Label Policy
##############################################################################

if (-not $SkipLabelPolicy) {
    Write-Host "`n=== SECTION 3: Creating and Publishing Label Policy ===" -ForegroundColor Cyan

    # Make sure we're still connected to IPPS
    if (-not (Get-Command Get-LabelPolicy -ErrorAction SilentlyContinue)) {
        Write-Host "Reconnecting to Security & Compliance Center..." -ForegroundColor Gray
        $ippsParams = @{}
        if ($AdminUPN) { $ippsParams['UserPrincipalName'] = $AdminUPN }
        Connect-IPPSSession @ippsParams
    }

    # Check if policy already exists
    $existingPolicy = Get-LabelPolicy | Where-Object { $_.Name -eq $LabelPolicyName }

    if ($existingPolicy) {
        Write-Host "  ⚠️  Policy '$LabelPolicyName' already exists." -ForegroundColor Yellow
        Write-Host "     Skipping creation. Use Set-LabelPolicy to modify if needed." -ForegroundColor Yellow
    }
    else {
        # Get the label we just created — match on Name (internal, no emoji)
        $theLabel = Get-Label | Where-Object { $_.Name -eq $LabelName }

        if (-not $theLabel) {
            Write-Error "Could not find label '$LabelDisplayName'. Make sure Section 2 completed successfully."
            exit 1
        }

        Write-Host "  Creating label policy: $LabelPolicyName" -ForegroundColor Gray

        $NewPolicy = New-LabelPolicy `
            -Name $LabelPolicyName `
            -Labels $theLabel.Name `
            -ExchangeLocation "All" `
            -SharePointLocation "All" `
            -OneDriveLocation "All" `
            -ModernGroupLocation "All" `
            -Settings @{
                requiredowngradejustification = $true
                siteandgroupmandatory         = $false
                outlookdefaultlabel           = "None"
            }

        Write-Host "  ✅ Label policy created and published: $($NewPolicy.Name)" -ForegroundColor Green
    }

    Write-Host "`n⏱️  Label policies take up to 24 hours to propagate to all clients." -ForegroundColor Yellow
    Write-Host "    For demo use, Word/Excel Online should reflect the label within ~1 hour." -ForegroundColor Yellow
}

##############################################################################
# SUMMARY
##############################################################################

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  SETUP COMPLETE — Purview Demo Pre-flight Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host @"

✅ Dolores Umbridge added to:
   - Order of the Phoenix  ($OotPSiteUrl)
   - Dumbledore's Army HQ  ($DASiteUrl)

✅ Sensitivity Label created:
   - '$LabelDisplayName'
   - Scope: Files, Email, Sites, Groups
   - Encryption: Gryffindor group only (Co-Author)
   - Content marking: Header + Footer + Watermark

✅ Label Policy published:
   - '$LabelPolicyName'
   - Published to: All users

NEXT STEPS:
  1. Wait 5–15 min for Dolores's group membership to propagate
  2. Dolores should sign out of M365 and sign back in
  3. Dolores can now visit both sites directly — Act 1 demo ready ✅
  4. Wait up to 1 hr for label to appear in Word/Excel Online
  5. Run Act 2: Apply label to DA Charter + OotP docs as Harry Potter
  6. Run Act 3: Show Dolores is blocked by encryption

"@ -ForegroundColor White

Write-Host "Walkthrough: /HarryPotterPurviewDemo/Purview/Purview-Demo-Walkthrough.md" -ForegroundColor Gray
