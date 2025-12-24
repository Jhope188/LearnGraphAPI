# Install Microsoft Graph PowerShell module if not already installed
Install-Module -Name Microsoft.Graph -Scope CurrentUser

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All", "Group.Read.All" -NoWelcome

# Define the group ID
$groupId = "Entra Group to target"

# Define the CSV file name
$csvFile = "tap_results.csv"

# Get all members in the group
$members = Get-MgGroupMember -GroupId $groupId -All -ConsistencyLevel eventual

# Initialize an array to store user details
$csv = @()

# Iterate through each member and get user details if it's a user

foreach ($member in $members) {
    $additionalProperties = $member.AdditionalProperties
    if ($additionalProperties.'@odata.type' -eq "#microsoft.graph.user") {
        $user = Get-MgUser -UserId $member.Id
        
        # Enable TAP for the user
        $tap = @{
            isUsableOnce = $false
            lifetimeInMinutes = 1440 # 1 day
        }
        $tapResult = New-MgUserAuthenticationTemporaryAccessPassMethod -UserId $user.Id -BodyParameter $tap
        
        # Add the user's TAP details to the CSV data
        $csv += [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            TemporaryAccessPass = $tapResult.TemporaryAccessPass
            ExpirationDate = (Get-Date).AddDays(1)
        }
    }
}


# Export the CSV data to a file
$csv | Export-Csv -Path $csvFile -NoTypeInformation

Write-Output "The TAP results have been written to $csvFile."