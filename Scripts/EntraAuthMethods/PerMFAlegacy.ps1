#Connet to Microsoft Graph
Connect-MgGraph -Scope Policy.ReadWrite.AuthenticationMethod

#Get all users and select only required properties
$allUsers = Get-MgUser -all -select Id, UserPrincipalName

#initialise array
$allUsersPerUserMFAState = [System.Collections.Generic.List[Object]]::new()

#Loop through each user and add results to array
Foreach ($user in $allusers){
    $pumfa = Invoke-MgGraphRequest -Method GET -Uri "/beta/users/$($user.id)/authentication/requirements" -OutputType PSObject
    $obj = [PSCustomObject][ordered]@{
        "User" = $user.UserPrincipalName
        "Per-user MFA State" = $pumfa.PerUserMfaState
    }
    $allUsersPerUserMFAState.Add($obj)
}

#output in grid view
$allUsersPerUserMFAState | Export-Csv -Path "C:\clientapps\RMGPerMFASetting.csv" -NoTypeInformation

Write-Output "Export completed successfully."
