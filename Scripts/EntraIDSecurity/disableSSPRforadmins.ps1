#https://www.matej.guru/p/switching-off-self-service-password

#Module requirements
Import-Module Microsoft.Graph.Identity.SignIns

#Graph scope requirements
Connect-MgGraph -Scopes Policy.ReadWrite.Authorization


#check if SSPR for admins is enabled value should read false, true indicates it enabled
Get-MgPolicyAuthorizationPolicy | select AllowedToUseSspr

#Set SSPR for Admins to False
$params = @{
allowedToUseSSPR = $false
}
Update-MgPolicyAuthorizationPolicy -BodyParameter $params


