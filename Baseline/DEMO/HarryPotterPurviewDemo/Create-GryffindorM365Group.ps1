##############################################################################
#  Create-GryffindorM365Group.ps1
#
#  Creates "🦁 Gryffindor – M365 Dynamic User Group" as a Microsoft 365
#  (Unified) Dynamic group with the same membership rule as the existing
#  security group.
#
#  WHY: Sensitivity label EncryptionRightsDefinitions requires an email
#  address to scope encryption. Security groups have no mail address.
#  M365 Unified groups have a mail address and can be used directly in
#  label encryption settings — either by email or via the Purview UI.
#
#  Membership rule: user.physicalDeliveryOfficeName -eq "Gryffindor"
#  Members (dynamic): Harry Potter, Hermione Granger, Ron Weasley,
#                     Albus Dumbledore, Minerva McGonagall, Neville Longbottom
#
#  Usage:
#    ./Create-GryffindorM365Group.ps1 -TenantDomain "contoso.onmicrosoft.com"
##############################################################################

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TenantDomain
)

$GroupDisplayName  = "🦁 Gryffindor – M365 Dynamic User Group"
$GroupMailNickname = "GryffindorM365"
$GroupDescription  = "M365 Unified dynamic group for Gryffindor house members. Used for sensitivity label encryption scoping. Membership rule: physicalDeliveryOfficeName = Gryffindor."
$MembershipRule    = '(user.physicalDeliveryOfficeName -eq "Gryffindor")'

##############################################################################
# Connect
##############################################################################

Write-Host "`n=== Gryffindor M365 Dynamic Group Setup ===" -ForegroundColor Cyan
Write-Host "  Tenant: $TenantDomain" -ForegroundColor Gray

Connect-MgGraph `
    -Scopes "Group.ReadWrite.All", "Directory.ReadWrite.All" `
    -TenantId $TenantDomain `
    -NoWelcome

##############################################################################
# Check for existing group
##############################################################################

$existing = Get-MgGroup -Filter "mailNickname eq '$GroupMailNickname'" `
            -Property "Id,DisplayName,GroupTypes,MailEnabled,Mail,MembershipRule" `
            -ErrorAction SilentlyContinue

if ($existing) {
    Write-Host "`n  ℹ️  Group already exists:" -ForegroundColor Cyan
    Write-Host "     Display name:  $($existing.DisplayName)" -ForegroundColor Gray
    Write-Host "     ID:            $($existing.Id)" -ForegroundColor Gray
    Write-Host "     Mail:          $($existing.Mail)" -ForegroundColor Gray
    Write-Host "     GroupTypes:    $($existing.GroupTypes -join ', ')" -ForegroundColor Gray
    Write-Host "     Membership:    $($existing.MembershipRule)" -ForegroundColor Gray

    $isUnified = $existing.GroupTypes -contains "Unified"
    $isDynamic = $existing.GroupTypes -contains "DynamicMembership"

    if ($isUnified -and $isDynamic) {
        Write-Host "`n  ✅ Already an M365 Dynamic group — nothing to do." -ForegroundColor Green
        Write-Host "     Use email address '$($existing.Mail)' in the sensitivity label." -ForegroundColor Yellow
        exit 0
    }
    else {
        Write-Warning "  Group exists but is NOT an M365 Unified group (GroupTypes: $($existing.GroupTypes -join ', '))"
        Write-Warning "  The existing group cannot be converted. Delete it first if you want to recreate it."
        Write-Warning "  Existing group ID: $($existing.Id)"
        exit 1
    }
}

##############################################################################
# Create the M365 Dynamic group
##############################################################################

Write-Host "`n  Creating M365 Dynamic group: $GroupDisplayName" -ForegroundColor Gray

$newGroup = New-MgGroup -BodyParameter @{
    DisplayName                   = $GroupDisplayName
    MailNickname                  = $GroupMailNickname
    Description                   = $GroupDescription
    GroupTypes                    = @("Unified", "DynamicMembership")   # Unified = M365 group; DynamicMembership = dynamic rule
    MailEnabled                   = $true
    SecurityEnabled               = $false
    MembershipRule                = $MembershipRule
    MembershipRuleProcessingState = "On"
    Visibility                    = "Private"
}

Write-Host "  ✅ Group created!" -ForegroundColor Green
Write-Host "     Display name: $($newGroup.DisplayName)" -ForegroundColor Gray
Write-Host "     Group ID:     $($newGroup.Id)" -ForegroundColor Gray

# Wait briefly then re-fetch to get the mail address (assigned after provisioning)
Write-Host "`n  Waiting for mail address to be assigned..." -ForegroundColor Gray
Start-Sleep -Seconds 10

$provisioned = Get-MgGroup -GroupId $newGroup.Id -Property "Id,DisplayName,Mail,GroupTypes,MembershipRule"

Write-Host "     Mail address: $($provisioned.Mail)" -ForegroundColor Gray
Write-Host "     GroupTypes:   $($provisioned.GroupTypes -join ', ')" -ForegroundColor Gray
Write-Host "     Rule:         $($provisioned.MembershipRule)" -ForegroundColor Gray

##############################################################################
# Summary
##############################################################################

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  COMPLETE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host @"

✅ Group:    $($provisioned.DisplayName)
   ID:       $($provisioned.Id)
   Email:    $($provisioned.Mail)
   Rule:     $($provisioned.MembershipRule)

⏱️  Dynamic membership takes up to 24 hours to fully populate.
   Check membership in Entra ID → Groups → Members tab.

NEXT STEPS — Update sensitivity label to use this group:

  Option A (Recommended) — Re-run Setup-PurviewDemo.ps1:
    The script already resolves the Gryffindor group by display name.
    Delete the existing label in Purview, then re-run:

    ./Setup-PurviewDemo.ps1 -TenantDomain "$TenantDomain" -SkipSitePermissions -SkipLabelPolicy

  Option B — Update label manually in Purview:
    1. compliance.microsoft.com → Information Protection → Labels
    2. Edit '🛡️ Order of the Phoenix — Restricted' → Encryption
    3. Remove the per-user rights entries
    4. Add permissions → search for '$GroupMailNickname' or '$($provisioned.Mail)'
    5. Set Co-Author → Save

"@ -ForegroundColor White
