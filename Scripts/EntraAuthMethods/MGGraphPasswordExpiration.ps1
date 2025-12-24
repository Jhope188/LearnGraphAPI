## https://learn.microsoft.com/en-us/microsoft-365/admin/add-users/set-password-to-never-expire?view=o365-worldwide

#Connect to Graph:
Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All"



#Check Single User:
Get-MGuser -UserId conference@ssva.com -Property UserPrincipalName, PasswordPolicies | Select-Object UserPrincipalName,@{
    N="PasswordNeverExpires";E={$_.PasswordPolicies -contains "DisablePasswordExpiration"}
}


#Pull all user accounts with setting to not expire and export to HTML or CSV
Get-MGuser -All -Property UserPrincipalName, PasswordPolicies | Select-Object UserprincipalName,@{
    N="PasswordNeverExpires";E={$_.PasswordPolicies -contains "DisablePasswordExpiration"}
} | ConvertTo-Html | Out-File /Users/Directory/desktop/ReportPasswordNeverExpiresUpdated.html


Get-MGuser -All -Property UserPrincipalName, PasswordPolicies | Select-Object UserprincipalName,@{
    N="PasswordNeverExpires";E={$_.PasswordPolicies -contains "DisablePasswordExpiration"}
} | ConvertTo-Csv -NoTypeInformation | Out-File $env:userprofile\Desktop\ReportPasswordNeverExpires.csv


# Disable Password epiration for single user
Update-MgUser -UserId useraccount1@acme.com -PasswordPolicies DisablePasswordExpiration