
Connect-MgGraph -Scopes "Application.ReadWrite.All"
$ServicePrincipalID=@{
"AppId" = "16aeb910‑ce68‑41d1‑9ac3‑9e1673ac9575" #IrisFrontDoorSelector
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalID | Format-List id, DisplayName, AppId, SignInAudience


Connect-MgGraph -Scopes "Application.Read.All"
Get-MgServicePrincipal -Filter "appId eq '16aeb910-ce68-41d1-9ac3-9e1673ac9575'" | Format-List Id, DisplayName, AppId, SignInAudience



Connect-MgGraph -Scopes "Application.ReadWrite.All"
$ServicePrincipalID=@{
“AppId” = “499b84ac-1321-427f-aa17-267ca6975798” #AzureDevOps
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudience


Connect-MgGraph -Scopes "Application.ReadWrite.All"
$ServicePrincipalID=@{
“AppId” = “499b84ac-1321-427f-aa17-267ca6975798” #AzureDevOps
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudience

#Update your policies to include "Azure DevOps"
# → App ID: 499b84ac-1321-427f-aa17-267ca6975798

Azure Credential Configuration Endpoint Service(Allow Passkeys: https://nathanmcnulty.com/blog/2025/09/improving-passkey-registration-experiences/ )
# → App ID: ea890292-c8c8-4433-b5ea-b09d0668e1a6

Connect-MgGraph -Scopes "Application.ReadWrite.All"
$ServicePrincipalID=@{
“AppId” = “d4ebce55-015a-49b5-a083-c84d1797ae8c” #MicrosoftIntuneEnrollment
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudience


$ServicePrincipalID=@{
“AppId” = “44660504c-45b3-4674-a709-71951a6b0763” #Microsoft Invitation Acceptance Portal 
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudienc


$ServicePrincipalID=@{
“AppId” = “44660504c-45b3-4674-a709-71951a6b0763” #Microsoft Invitation Acceptance Portal 
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudienc

New-MgServicePrincipal -BodyParameter @{ AppId = "44660504c-45b3-4674-a709-71951a6b0763" }

$appId = "44660504c-45b3-4674-a709-71951a6b0763"
$sp = Get-MgServicePrincipal -AppId $appId -ErrorAction SilentlyContinue

if (-not $sp) {
    New-MgServicePrincipal -AppId $appId
} else {
    Write-Host "Service principal already exists: $($sp.DisplayName)"
}


$ServicePrincipalID=@{
“AppId” = “c2b688fe-48c0-464b-a89c-67041aa8fcb2” #MicrosoftDefenderATP MAM
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudience
