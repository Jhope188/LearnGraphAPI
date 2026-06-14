# https://learn.microsoft.com/en-us/microsoft-365/solutions/manage-creation-of-groups
# MT.1055: Microsoft 365 Group (and Team) creation should be restricted to approved users.
#
# Uses Microsoft Graph Beta cmdlets.
# Run this inside an existing Maester/Graph-connected PowerShell session.

$GroupName = "M365 Group Creators"

try {
    # Prefer the exact Beta module version that matches the installed dependency set.
    Import-Module Microsoft.Graph.Authentication -RequiredVersion 2.34.0 -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Beta -RequiredVersion 2.34.0 -Force -ErrorAction Stop
} catch {
    Write-Warning "Initial Beta import failed. Removing previously loaded Graph modules and retrying with the 2.34.0 dependency set..."
    Get-Module Microsoft.Graph* | Remove-Module -Force -ErrorAction SilentlyContinue
    Import-Module Microsoft.Graph.Authentication -RequiredVersion 2.34.0 -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Beta -RequiredVersion 2.34.0 -Force -ErrorAction Stop
}

if (-not (Get-Module Microsoft.Graph.Beta -ErrorAction SilentlyContinue)) {
    throw "Microsoft.Graph.Beta is not available in this session after import. Please restart PowerShell and rerun this script."
}

if (-not (Get-MgContext -ErrorAction SilentlyContinue)) {
    throw "Authentication needed. Run Connect-MgGraph first (for example: Connect-MgGraph -Scopes Directory.ReadWrite.All,Group.ReadWrite.All)."
}

# Step 1: Get or create the allowed-creators security group
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
    Write-Host "Group.Unified setting already exists (ID: $($setting.Id)) — updating..."
    $setting = Update-MgBetaDirectorySetting -DirectorySettingId $setting.Id -BodyParameter $body
}

# Step 3: Verify
Write-Host "`n── Verification ──"
(Get-MgBetaDirectorySetting -DirectorySettingId $setting.Id -ErrorAction Stop).Values |
    Where-Object { $_.Name -in "EnableGroupCreation", "GroupCreationAllowedGroupId" } |
    Format-Table Name, Value -AutoSize

Write-Host "Done. Add members to '$GroupName' (ID: $groupId) to grant group-creation rights."