# https://github.com/jkerai1/DNSTwistToMDEIOC


#$csvPath = "$HOME/Downloads/DNSTwist/TenantAllowBlockList-Batch-1.csv"


# Import-TABL-DNSTwist.ps1
# Bulk imports TenantAllowBlockList-Batch-1.csv into TABL Sender blocks
# macOS — requires PowerShell 7+ and ExchangeOnlineManagement module

Connect-ExchangeOnline -ShowBanner:$false

$csv = Import-Csv -Path "$HOME/Downloads/DNSTwist/TenantAllowBlockList-Batch-1.csv"

foreach ($entry in $csv) {
    $domain = $entry.Value
    $notes  = $entry.Notes

    if ($entry.NeverExpire -eq "true") {
        New-TenantAllowBlockListItems `
            -Block `
            -ListType Sender `
            -Entries $domain `
            -NoExpiration `
            -Notes $notes
    } else {
        $expiry = [datetime]$entry.ExpirationDate
        New-TenantAllowBlockListItems `
            -Block `
            -ListType Sender `
            -Entries $domain `
            -ExpirationDate $expiry `
            -Notes $notes
    }

    Write-Host "Blocked: $domain"
}

Disconnect-ExchangeOnline -Confirm:$false




