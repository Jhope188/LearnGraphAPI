# https://learn.microsoft.com/en-us/previous-versions/microsoft-365/solutions/manage-creation-of-groups
# MT.1055: Microsoft 365 Group (and Team) creation should be restricted to approved users.
#
# Restricts M365 Group creation to members of "M365 Group Creators" security group.
# Uses Microsoft Graph Beta sub-modules (specific packages, not the monolithic Microsoft.Graph.Beta).

$GroupName       = "SG-Entra-AUG-Identity-M365GroupCreators"
$ExistingGroupId = $null   # Set to a GUID to skip lookup and use a known group ID directly
$TargetVersion   = "2.37.0"
$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Beta.Groups",
    "Microsoft.Graph.Beta.Identity.DirectoryManagement"
)

# Remove any previously loaded Graph modules to avoid mixed-version assembly conflicts
Get-Module Microsoft.Graph* | Remove-Module -Force -ErrorAction SilentlyContinue

foreach ($mod in $RequiredModules) {
    Import-Module $mod -RequiredVersion $TargetVersion -Force -ErrorAction Stop
    Write-Host "  ✅ Loaded $mod $TargetVersion" -ForegroundColor DarkGray
}

# Re-use an existing Graph session or prompt for sign-in
$ctx = Get-MgContext -ErrorAction SilentlyContinue
if (-not $ctx) {
    Write-Host "No active Graph session — connecting..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes "Directory.ReadWrite.All","Group.ReadWrite.All" -NoWelcome
    $ctx = Get-MgContext
}

if (-not $ctx) {
    throw "Failed to connect to Microsoft Graph. Run Connect-MgGraph manually and retry."
}
Write-Host "Connected as $($ctx.Account) | Tenant: $($ctx.TenantId)`n" -ForegroundColor Cyan

# Step 1: Get or create the allowed-creators security group
if ($ExistingGroupId) {
    $group = Get-MgBetaGroup -GroupId $ExistingGroupId -ErrorAction Stop
    Write-Host "Using existing group '$($group.DisplayName)' (ID: $($group.Id))"
} else {
    $group = Get-MgBetaGroup -Filter "displayName eq '$GroupName'" -All -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $group) {
        Write-Host "Creating security group '$GroupName'..."
        $group = New-MgBetaGroup -DisplayName $GroupName `
            -MailEnabled:$false `
            -MailNickname "M365GroupCreators" `
            -SecurityEnabled:$true `
            -Description "Members of this group are allowed to create Microsoft 365 Groups and Teams."
        Write-Host "  Created group ID: $($group.Id)"
    } else {
        Write-Host "Group '$GroupName' already exists (ID: $($group.Id))"
    }
}

$groupId = $group.Id

# Step 2: Get or create the Group.Unified directory setting
$setting = Get-MgBetaDirectorySetting -All -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq "Group.Unified" } |
    Select-Object -First 1

$body = @{
    templateId = "62375ab9-6b52-47ed-826b-58e47e0e304b"
    values     = @(
        @{ name = "EnableGroupCreation"; value = "False" }
        @{ name = "GroupCreationAllowedGroupId"; value = $groupId }
        @{ name = "EnableMSStandardBlockedWords"; value = "true" }
    )
}

if (-not $setting) {
    Write-Host "Group.Unified setting not found — creating it..."
    $setting = New-MgBetaDirectorySetting -BodyParameter $body
    Write-Host "  Created setting ID: $($setting.Id)"
} else {
    $settingId = $setting.Id
    Write-Host "Group.Unified setting already exists (ID: $settingId) — updating..."
    Update-MgBetaDirectorySetting -DirectorySettingId $settingId -BodyParameter $body
    # Re-fetch after update (Update-MgBetaDirectorySetting returns void)
    $setting = Get-MgBetaDirectorySetting -DirectorySettingId $settingId -ErrorAction Stop
}

# Step 3: Verify
Write-Host "`n── Verification ──"
$setting.Values |
    Where-Object { $_.Name -in "EnableGroupCreation", "GroupCreationAllowedGroupId" } |
    Format-Table Name, Value -AutoSize

Write-Host "Done. Add members to '$GroupName' (ID: $groupId) to grant group-creation rights."

# ── Full settings dump (uncomment to inspect all Group.Unified values) ──────
# Shows every key/value in the Group.Unified directory setting for the tenant.
# Useful to verify the full policy state beyond just EnableGroupCreation.
#
#   (Get-MgBetaDirectorySetting -DirectorySettingId $setting.Id).Values | Format-Table Name, Value -AutoSize
#
# Standalone verification (works in a fresh session, no script variables required):
#   $s = Get-MgBetaDirectorySetting -All | Where-Object DisplayName -eq "Group.Unified" | Select-Object -First 1
#   $s.Values | Format-Table Name, Value -AutoSize
#
# Quick check (expected: EnableGroupCreation=False and GroupCreationAllowedGroupId=<your group id>):
#   $s.Values | Where-Object Name -in "EnableGroupCreation","GroupCreationAllowedGroupId" | Format-Table Name, Value -AutoSize
# Example output:
#   Name                              Value
#   ----                              -----
#   EnableGroupCreation               False
#   GroupCreationAllowedGroupId       1ecf21dc-eb30-47ef-8ed1-ddc0765fbbd4
#   EnableMSStandardBlockedWords      true
#   AllowGuestsToBeGroupOwner         false
#   AllowGuestsToAccessGroups         true
#   GuestUsageGuidelinesUrl
#   GroupCreationAllowedGroupId       (group object ID)
#   AllowToAddGuests                  true
#   UsageGuidelinesUrl
#   ClassificationDescriptions
#   DefaultClassification
#   PrefixSuffixNamingRequirement
#   CustomBlockedWordsList
#   EnableMIPLabels                   false