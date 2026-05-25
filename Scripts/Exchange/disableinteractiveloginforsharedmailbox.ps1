# Connect to Microsoft Graph with required scopes
Connect-MgGraph -Scopes "User.ReadWrite.All", "MailboxSettings.Read"

# Get all shared mailboxes from Exchange Online
Connect-ExchangeOnline
# Shared Mailbox Exclusions if needed
$sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox |
    Where-Object {
        ($_.Name -notmatch 'relay') -and ($_.Name -notmatch 'scans')
    }


# Loop through each shared mailbox and disable sign-in
foreach ($mailbox in $sharedMailboxes) {
    $userId = $mailbox.ExternalDirectoryObjectId

    # Set sign-in to blocked using Microsoft Graph
    Update-MgBetaUser -UserId $userId -AccountEnabled:$false

    Write-Output "Blocked sign-in for: $($mailbox.DisplayName) ($($mailbox.UserPrincipalName))"
}

# Disconnect sessions
Disconnect-ExchangeOnline
Disconnect-MgGraph



# Shared Mailbox Exclusions if needed
$sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox |
    Where-Object {
        ($_.Name -notmatch 'relay') -and ($_.Name -notmatch 'scans')
    }



# Export selected properties to CSV
$sharedMailboxes | Select-Object DisplayName, Name, UserPrincipalName, PrimarySmtpAddress |
    Export-Csv -Path "/Users/%username%/Desktop/FilteredSharedMailboxes.csv" -NoTypeInformation


    # Connect to Microsoft Graph with required scopes
Connect-MgGraph -Scopes "User.ReadWrite.All", "MailboxSettings.Read"

# Get all shared mailboxes from Exchange Online
Connect-ExchangeOnline
# Shared Mailbox Exclusions if needed
$sharedMailboxes = Get-Mailbox -RecipientTypeDetails SharedMailbox |
    Where-Object {
        ($_.Name -notmatch 'relay') -and ($_.Name -notmatch 'scans')
    }


# Loop through each shared mailbox and disable sign-in
foreach ($mailbox in $sharedMailboxes) {
    $userId = $mailbox.ExternalDirectoryObjectId

    # Set sign-in to blocked using Microsoft Graph
    Update-MgBetaUser -UserId $userId -AccountEnabled:$true

    Write-Output "Allowed sign-in for: $($mailbox.DisplayName) ($($mailbox.UserPrincipalName))"
}

