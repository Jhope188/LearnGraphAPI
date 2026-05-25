
# ImportUserPhones.ps1
# Description: This script updates the MFA phone authentication methods for users in Microsoft Graph.
# https://stackoverflow.com/collectives/azure/articles/76735730/how-to-bulk-update-mfa-phone-auth-method-using-powershell
# "UPN","Number"
# Puneet@contoso.in,+91 XXXXXXXXXX
# DA@Contoso.com,+91 XXXXXXXXXX
# PS@fabrikam.com,+91 XXXXXXXXXX

# NOTES:
# Need to export users to csv to start
# Then convert csv to XLS change format of the Number table to text
# Then imput the numbers in format +1 8045551234
# Export file back out as csv format UTF-8

# Connect to Microsoft Graph with the required permissions
Connect-MgGraph -Scopes Directory.ReadWrite.All,UserAuthenticationMethod.ReadWrite.All -NoWelcome

#Export Users into csv

$mgBetaUsers = Get-MgBetaUser -All

$results = foreach ($user in $mgBetaUsers) {
    $phoneMethods = Get-MgBetaUserAuthenticationPhoneMethod -UserId $user.UserPrincipalName
    if (-not $phoneMethods) {
        [PSCustomObject]@{
            UPN = $user.UserPrincipalName
            Number       = $null
            # PhoneType         = $null
        }
    }
}

$results | Export-Csv -Path "/Users/Username/Desktop/ExportUserInfowithnophoneupdate.csv" -NoTypeInformation




# Import the csv and set the numbers for users
Write-host "++++++++++ Updating MFA Authentication Methods for all users ++++++++++" -ForegroundColor Black -BackgroundColor White
$csv = Import-Csv -Path "/Users/Username/Desktop/ExportUserInfowithnophone.csv"
Foreach ($line in $csv)
{
    $UserInfo = Get-MgBetaUserAuthenticationPhoneMethod -UserId $line.UPN | Select-Object *Phonenumber 
    If ($UserInfo -ne $null)
{
        Write-host "User "$line.UPN" already has MFA Method registered as $UserInfo" -ForegroundColor Red 
}
else
{
      New-MgBetaUserAuthenticationPhoneMethod -UserId $line.UPN -phoneType "mobile" -phoneNumber $line.Number | Out-Null
      Write-host "Updated MFA Auth Method for user "$line.UPN" with value "$Line.Number"" -ForegroundColor Green 
}
}
Write-host "++++++++++ MFA Authentication Phone Method has been updated ++++++++++" -ForegroundColor Black -BackgroundColor White




