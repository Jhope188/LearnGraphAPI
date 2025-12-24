<#
.SYNOPSIS
    Lists SAML certificates expiring in next 60 days (HTML output).
.DESCRIPTION
    Uses Automation Account Managed Identity to authenticate to Microsoft Graph.
    Queries all Enterprise Applications and outputs an HTML table of SAML certs
    expiring within the next 60 days.
    Required Permissions:
        Directory.Read.All , Application.Read.All
#>

# ============================================
# 1. Acquire Managed Identity Token for Graph
# ============================================
# Write-Output "Requesting Managed Identity token..."

$resource = "https://graph.microsoft.com"
$tokenUri = $env:IDENTITY_ENDPOINT + "?resource=$resource&api-version=2019-08-01"

$tokenHeaders = @{
    "X-IDENTITY-HEADER" = $env:IDENTITY_HEADER
    "Metadata"          = "true"
}

try {
    $tokenResponse = Invoke-RestMethod -Method GET -Uri $tokenUri -Headers $tokenHeaders
    $accessToken = $tokenResponse.access_token
    # Write-Output "Managed Identity Token acquired."
}
catch {
    Write-Output "<p style='color:red;'>ERROR: Could not acquire Managed Identity token.</p>"
    Write-Output $_
    break
}

$authHeader = @{ Authorization = "Bearer $accessToken" }


# ============================================
# 2. Fetch ALL Enterprise Applications
# ============================================
# Write-Output "Fetching all Enterprise Applications..."

$allSPs = @()
$uri = "https://graph.microsoft.com/v1.0/servicePrincipals"

do {
    $resp = Invoke-RestMethod -Uri $uri -Headers $authHeader -Method GET
    $allSPs += $resp.value
    $uri = $resp.'@odata.nextLink'
} while ($uri)

# Write-Output "Total Enterprise Apps Found: $($allSPs.Count)"


# ============================================
# 3. Filter SAML Certificates Expiring in next 60 days
# ============================================
# Write-Output "Filtering SAML certificates expiring within 60 days..."

$today = Get-Date
$expiring = @()

foreach ($sp in $allSPs) {

    $certs = $sp.keyCredentials
    if ($certs -and $certs.Count -gt 0) {

        foreach ($cert in $certs) {

            # Only SAML signing certs
            if ($cert.usage -ne "Sign") { continue }

            $end  = Get-Date $cert.endDateTime
            $days = ($end - $today).Days

            # Only show certs expiring within next 60 days
            if ($days -le 60 -and $days -gt 0) {

                $expiring += [PSCustomObject]@{
                    AppName      = $sp.displayName
                    KeyId        = $cert.keyId
                    EndDate      = $end
                    DaysToExpiry = $days
                }
            }
        }
    }
}

# ============================================
# 4. If none found → show clean HTML message
# ============================================
if ($expiring.Count -eq 0) {
    Write-Output "<p>No SAML certificates are expiring in the next 60 days.</p>"
    break
}

# ============================================
# 5. Build HTML Table Output (with BLUE merged top header)
# ============================================
$html = @"
<table style='width: 95%; border-collapse: collapse; font-family: Arial;'>

    <thead>

        <!-- FIRST ROW: BLUE MERGED HEADER -->
        <tr>
            <th colspan='4' style='background-color: #0078D4; color: #ffffff;
                text-align: center; font-size: 18px; padding: 10px; border: 1px solid black;'>
                SAML Certificates Expiring in Next 60 Days
            </th>
        </tr>

        <!-- SECOND ROW: COLUMN HEADERS -->
        <tr style='background-color: #333333; color: #ffffff; text-align: center;'>
            <th style='border: 1px solid black;'>Application Name</th>
            <th style='border: 1px solid black;'>Key ID</th>
            <th style='border: 1px solid black;'>Expiry Date</th>
            <th style='border: 1px solid black;'>Days Remaining</th>
        </tr>

    </thead>

    <tbody>
"@

foreach ($row in $expiring | Sort-Object DaysToExpiry) {

    $html += @"
        <tr style='text-align: center;'>
            <td style='border: 1px solid black;'>$($row.AppName)</td>
            <td style='border: 1px solid black;'>$($row.KeyId)</td>
            <td style='border: 1px solid black;'>$($row.EndDate.ToString("yyyy-MM-dd HH:mm"))</td>
            <td style='border: 1px solid black;'>$($row.DaysToExpiry)</td>
        </tr>
"@
}

$html += "</tbody></table>"

# Output final HTML only
Write-Output $html
 