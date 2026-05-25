Connect-MgGraph -Scopes "Application.ReadWrite.All"
$ServicePrincipalID=@{
“AppId” = “d4ebce55-015a-49b5-a083-c84d1797ae8c” #MicrosoftIntuneEnrollment
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudience

Connect-MgGraph -Scopes "Application.ReadWrite.All"
$ServicePrincipalID=@{
“AppId” = “ea890292-c8c8-4433-b5ea-b09d0668e1a6” #Azure Credential Configuration Endpoint Service
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudience



Connect-MgGraph -Scopes "Application.ReadWrite.All"
$ServicePrincipalID=@{
“AppId” = “372140e0-b3b7-4226-8ef9-d57986796201” #Azure Windows VM Sign-In
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalId | Format-List id, DisplayName, AppId, SignInAudience
