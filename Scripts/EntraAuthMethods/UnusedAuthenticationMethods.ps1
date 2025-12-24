#This was a sample Script provided by Daniel Bradley
#https://www.linkedin.com/posts/danielbradley2_entra-microsoft-security-activity-7389567486922334209-1s8t?utm_source=share&utm_medium=member_desktop&rcm=ACoAABJBcYQB6kxKHyUpBmUPeqQAj2fCa91rDhc
#I just updated for full support on MAC environment

#Connect to Microsoft Graph
Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All", "User.Read.All"

#Get all users including sign-in and assigned license information
$uri = "beta/users?`$select=Id,DisplayName,UserPrincipalName"
$Result = Invoke-MgGraphRequest -Uri $Uri -OutputType PSObject
$AllUsers = $Result.value
$NextLink = $Result."@odata.nextLink"
while ($NextLink -ne $null) {
    $Result = Invoke-MgGraphRequest -Method GET -Uri $NextLink -OutputType PSObject
    $AllUsers += $Result.value
    $NextLink = $Result."@odata.nextLink"
}

#Create data array
$authMethodsReport = [System.Collections.Generic.List[Object]]::new()
foreach ($user in $allusers) {
    $uri = "Beta/users/$($user.Id)/authentication/methods"
    $methods = Invoke-MgGraphRequest -Uri $uri -OutputType PSObject | Select -Expand Value
    $obj = [PSCustomObject]@{
        UserPrincipalName         = $user.UserPrincipalName
        Email                     = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.emailAuthenticationMethod" }).lastUsedDateTime
        External                  = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.externalAuthenticationMethod" }).lastUsedDateTime
        Fido2                     = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.fido2AuthenticationMethod" }).lastUsedDateTime
        Password                  = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.passwordAuthenticationMethod" }).lastUsedDateTime
        Authenticator             = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" }).lastUsedDateTime
        AuthenticatorPasswordless = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" }).lastUsedDateTime
        HardwareOath              = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.hardwareOathAuthenticationMethod" }).lastUsedDateTime
        Phone                     = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.phoneAuthenticationMethod" }).lastUsedDateTime
        SoftwareOath              = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.softwareOathAuthenticationMethod" }).lastUsedDateTime
        TemporaryAccessPass       = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.temporaryAccessPassAuthenticationMethod" }).lastUsedDateTime
        WindowsHello              = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" }).lastUsedDateTime
        PlatformCredential        = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.platformCredentialAuthenticationMethod" }).lastUsedDateTime
        QRCodePIN                 = ($methods | Where-Object { $_."@odata.type" -eq "#microsoft.graph.qrCodePinAuthenticationMethod" }).lastUsedDateTime
    }
    $authMethodsReport.Add($obj)
}

# Generate HTML Report
$reportDate = Get-Date -Format "MMMM dd, yyyy"
$reportTime = Get-Date -Format "HH:mm:ss"

$htmlHeader = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Authentication Methods Usage Report</title>
    <style>
        * {

            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.4;
            color: #1a1a1a;
            background-color: #f8f9fa;
            padding: 16px;
        }
        
        .container {
            max-width: 100%;
            margin: 0 auto;
            background-color: #ffffff;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
            border-radius: 4px;
            overflow: hidden;
        }
        
        .header {
            background-color: #2d3748;
            color: #ffffff;
            padding: 20px 24px;
            border-bottom: 1px solid #1a202c;
        }
        
        .header h1 {
            font-size: 22px;
            font-weight: 600;
            margin-bottom: 4px;
        }
        
        .header .meta {
            font-size: 13px;
            color: #cbd5e0;
        }
        
        .header .credit {
            font-size: 11px;
            margin-top: 8px;
            color: #cbd5e0;
        }
        
        .header .credit a {
            color: #e2e8f0;
            text-decoration: none;
            font-weight: 500;
        }
        
        .header .credit a:hover {
            color: #ffffff;
            text-decoration: underline;
        }
        
        .controls {
            padding: 16px 24px;
            background-color: #f7fafc;
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            align-items: center;
        }
        
        .controls .filter-group {
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .controls label {
            display: inline-flex;
            align-items: center;
            font-size: 13px;
            color: #4a5568;
            cursor: pointer;
            user-select: none;
            margin: 0;
        }
        
        .controls input[type="checkbox"] {
            margin-right: 6px;
            cursor: pointer;
        }
        
        .controls input[type="text"],
        .controls input[type="number"],
        .controls select {
            padding: 6px 10px;
            border: 1px solid #cbd5e0;
            border-radius: 4px;
            font-size: 13px;
            color: #2d3748;
            background-color: #ffffff;
        }
        
        .controls input[type="text"]:focus,
        .controls input[type="number"]:focus,
        .controls select:focus {
            outline: none;
            border-color: #4a5568;
        }
        
        .controls .divider {
            width: 1px;
            height: 24px;
            background-color: #cbd5e0;
        }
        
        .filter-label {
            font-size: 12px;
            font-weight: 600;
            color: #2d3748;
        }
        
        .hidden-row {
            display: none !important;
        }
        
        .summary {
            padding: 16px 24px;
            background-color: #f7fafc;
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            gap: 24px;
            align-items: center;
        }
        
        .stat-item {
            font-size: 13px;
            color: #4a5568;
        }
        
        .stat-item .label {
            font-weight: 500;
        }
        
        .stat-item .value {
            font-weight: 600;
            color: #1a202c;
        }
        
        .table-container {
            padding: 0;
            overflow-x: auto;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 13px;
        }
        
        thead {
            background-color: #edf2f7;
            position: sticky;
            top: 0;
            z-index: 10;
        }
        
        th {
            padding: 10px 8px;
            text-align: left;
            font-weight: 600;
            color: #2d3748;
            font-size: 12px;
            border-bottom: 2px solid #cbd5e0;
            white-space: nowrap;
        }
        
        tbody tr {
            border-bottom: 1px solid #e2e8f0;
        }
        
        tbody tr:hover {
            background-color: #f7fafc;
        }
        
        tbody tr:last-child {
            border-bottom: none;
        }
        
        td {
            padding: 8px;
            color: #2d3748;
            white-space: nowrap;
        }
        
        td:first-child {
            font-weight: 500;
            color: #1a202c;
            position: sticky;
            left: 0;
            background-color: #ffffff;
            max-width: 280px;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        
        tbody tr:hover td:first-child {
            background-color: #f7fafc;
        }
        
        .date-cell {
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 12px;
            color: #4a5568;
        }
        
        .never-used {
            color: #a0aec0;
            font-style: italic;
            font-size: 12px;
        }
        
        .footer {
            padding: 12px 24px;
            background-color: #f7fafc;
            border-top: 1px solid #e2e8f0;
            text-align: center;
            font-size: 12px;
            color: #718096;
        }
        
        .hidden-column {
            display: none;
        }
        
        @media print {
            body {
                background-color: white;
                padding: 0;
            }
            
            .container {
                box-shadow: none;
            }
            
            .controls {
                display: none;
            }
            
            tbody tr:hover {
                background-color: transparent;
            }
            
            tbody tr:hover td:first-child {
                background-color: transparent;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Authentication Methods Usage Report</h1>
            <div class="meta">Generated on $reportDate at $reportTime</div>
            <div class="credit">Made by <a href="https://www.linkedin.com/in/danielbradley2/" target="_blank">Daniel Bradley</a></div>
        </div>
        
        <div class="controls">
            <div class="filter-group">
                <label>
                    <input type="checkbox" id="hideEmptyColumns" checked onchange="toggleEmptyColumns()">
                    Hide empty columns
                </label>
            </div>
            
            <div class="divider"></div>
            
            <div class="filter-group">
                <span class="filter-label">Search:</span>
                <input type="text" id="searchInput" placeholder="Search users..." onkeyup="applyFilters()" style="width: 200px;">
            </div>
            
            <div class="divider"></div>
            
            <div class="filter-group">
                <span class="filter-label">Inactive for:</span>
                <select id="inactivityFilter" onchange="applyFilters()">
                    <option value="">All users</option>
                    <option value="30">30+ days</option>
                    <option value="60">60+ days</option>
                    <option value="90">90+ days</option>
                    <option value="180">180+ days</option>
                    <option value="365">1+ year</option>
                    <option value="never">Never used any method</option>
                </select>
            </div>
            
            <div class="divider"></div>
            
            <div class="filter-group">
                <span class="filter-label">Method:</span>
                <select id="methodFilter" onchange="applyFilters()">
                    <option value="">All methods</option>
                    <option value="Email">Email</option>
                    <option value="External">External</option>
                    <option value="Fido2">FIDO2</option>
                    <option value="Password">Password</option>
                    <option value="Authenticator">Authenticator</option>
                    <option value="AuthenticatorPasswordless">Auth Passwordless</option>
                    <option value="HardwareOath">Hardware OATH</option>
                    <option value="Phone">Phone</option>
                    <option value="SoftwareOath">Software OATH</option>
                    <option value="TemporaryAccessPass">Temp Access Pass</option>
                    <option value="WindowsHello">Windows Hello</option>
                    <option value="PlatformCredential">Platform Credential</option>
                    <option value="QRCodePIN">QR Code PIN</option>
                </select>
            </div>
            
            <div class="filter-group">
                <select id="methodStatusFilter" onchange="applyFilters()">
                    <option value="">Any status</option>
                    <option value="has">Has been used</option>
                    <option value="never">Never used</option>
                </select>
            </div>
        </div>
        
        <div class="summary">
            <div class="stat-item">
                <span class="label">Total Users:</span>
                <span class="value" id="totalUsers">$($authMethodsReport.Count)</span>
            </div>
            <div class="stat-item">
                <span class="label">Visible:</span>
                <span class="value" id="visibleUsers">$($authMethodsReport.Count)</span>
            </div>
            <div class="stat-item">
                <span class="label">Authentication Methods:</span>
                <span class="value">$($authMethodsReport[0].PSObject.Properties.Name.Count - 1)</span>
            </div>
        </div>
        
        <div class="table-container">
            <table id="dataTable">
                <thead>
                    <tr>
                        <th data-column="0">User Principal Name</th>
                        <th data-column="1">Email</th>
                        <th data-column="2">External</th>
                        <th data-column="3">FIDO2</th>
                        <th data-column="4">Password</th>
                        <th data-column="5">Authenticator</th>
                        <th data-column="6">Auth Passwordless</th>
                        <th data-column="7">Hardware OATH</th>
                        <th data-column="8">Phone</th>
                        <th data-column="9">Software OATH</th>
                        <th data-column="10">Temp Access Pass</th>
                        <th data-column="11">Windows Hello</th>
                        <th data-column="12">Platform Credential</th>
                        <th data-column="13">QR Code PIN</th>
                    </tr>
                </thead>
                <tbody>
"@

$htmlBody = ""
foreach ($user in $authMethodsReport) {
    $htmlBody += "                    <tr>`n"
    $htmlBody += "                        <td data-column='0'>$($user.UserPrincipalName)</td>`n"
    
    # Process each authentication method
    $properties = @('Email', 'External', 'Fido2', 'Password', 'Authenticator', 'AuthenticatorPasswordless', 
                    'HardwareOath', 'Phone', 'SoftwareOath', 'TemporaryAccessPass', 'WindowsHello', 
                    'PlatformCredential', 'QRCodePIN')
    
    $colIndex = 1
    foreach ($prop in $properties) {
        $value = $user.$prop
        if ([string]::IsNullOrWhiteSpace($value)) {
            $htmlBody += "                        <td class='never-used' data-column='$colIndex'>Never</td>`n"
        } else {
            $formattedDate = ([DateTime]$value).ToString("yyyy-MM-dd HH:mm")
            $htmlBody += "                        <td class='date-cell' data-column='$colIndex'>$formattedDate</td>`n"
        }
        $colIndex++
    }
    
    $htmlBody += "                    </tr>`n"
}

$htmlFooter = @"
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>Authentication Methods Report | Microsoft Graph API</p>
        </div>
    </div>
    
    <script>
        const columnMapping = {
            1: 'Email',
            2: 'External',
            3: 'Fido2',
            4: 'Password',
            5: 'Authenticator',
            6: 'AuthenticatorPasswordless',
            7: 'HardwareOath',
            8: 'Phone',
            9: 'SoftwareOath',
            10: 'TemporaryAccessPass',
            11: 'WindowsHello',
            12: 'PlatformCredential',
            13: 'QRCodePIN'
        };
        
        function parseDate(dateStr) {
            if (!dateStr || dateStr === 'Never') return null;
            return new Date(dateStr);
        }
        
        function daysSince(dateStr) {
            const date = parseDate(dateStr);
            if (!date) return Infinity;
            const now = new Date();
            return Math.floor((now - date) / (1000 * 60 * 60 * 24));
        }
        
        function applyFilters() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            const inactivityDays = document.getElementById('inactivityFilter').value;
            const selectedMethod = document.getElementById('methodFilter').value;
            const methodStatus = document.getElementById('methodStatusFilter').value;
            
            const table = document.getElementById('dataTable');
            const rows = table.querySelectorAll('tbody tr');
            let visibleCount = 0;
            
            rows.forEach(row => {
                let show = true;
                const cells = row.querySelectorAll('td');
                const userPrincipalName = cells[0].textContent.toLowerCase();
                
                // Search filter
                if (searchTerm && !userPrincipalName.includes(searchTerm)) {
                    show = false;
                }
                
                // Inactivity filter
                if (show && inactivityDays) {
                    if (inactivityDays === 'never') {
                        // Check if all methods are "Never"
                        let hasAnyMethod = false;
                        for (let i = 1; i < cells.length; i++) {
                            if (!cells[i].classList.contains('never-used')) {
                                hasAnyMethod = true;
                                break;
                            }
                        }
                        if (hasAnyMethod) show = false;
                    } else {
                        // Find the most recent activity across all methods
                        let mostRecentDays = Infinity;
                        for (let i = 1; i < cells.length; i++) {
                            const cellText = cells[i].textContent;
                            const days = daysSince(cellText);
                            if (days < mostRecentDays) {
                                mostRecentDays = days;
                            }
                        }
                        if (mostRecentDays < parseInt(inactivityDays)) {
                            show = false;
                        }
                    }
                }
                
                // Method-specific filter
                if (show && selectedMethod && methodStatus) {
                    // Find the column index for the selected method
                    let methodColumnIndex = -1;
                    for (let [colIdx, methodName] of Object.entries(columnMapping)) {
                        if (methodName === selectedMethod) {
                            methodColumnIndex = parseInt(colIdx);
                            break;
                        }
                    }
                    
                    if (methodColumnIndex !== -1) {
                        const methodCell = cells[methodColumnIndex];
                        const isNeverUsed = methodCell.classList.contains('never-used');
                        
                        if (methodStatus === 'has' && isNeverUsed) {
                            show = false;
                        } else if (methodStatus === 'never' && !isNeverUsed) {
                            show = false;
                        }
                    }
                }
                
                if (show) {
                    row.classList.remove('hidden-row');
                    visibleCount++;
                } else {
                    row.classList.add('hidden-row');
                }
            });
            
            // Update visible count
            document.getElementById('visibleUsers').textContent = visibleCount;
        }
        
        function toggleEmptyColumns() {
            const checkbox = document.getElementById('hideEmptyColumns');
            const table = document.getElementById('dataTable');
            const shouldHide = checkbox.checked;
            
            // Get all columns (excluding the first one which is UserPrincipalName)
            const totalColumns = table.querySelector('thead tr').children.length;
            
            // Check each column (starting from 1 to skip UserPrincipalName)
            for (let colIndex = 1; colIndex < totalColumns; colIndex++) {
                let hasData = false;
                
                // Check all tbody cells in this column
                const cells = table.querySelectorAll('tbody td[data-column="' + colIndex + '"]');
                for (let cell of cells) {
                    if (!cell.classList.contains('never-used')) {
                        hasData = true;
                        break;
                    }
                }
                
                // Hide/show column based on whether it has data
                const headers = table.querySelectorAll('th[data-column="' + colIndex + '"]');
                const dataCells = table.querySelectorAll('td[data-column="' + colIndex + '"]');
                
                if (shouldHide && !hasData) {
                    headers.forEach(h => h.classList.add('hidden-column'));
                    dataCells.forEach(c => c.classList.add('hidden-column'));
                } else {
                    headers.forEach(h => h.classList.remove('hidden-column'));
                    dataCells.forEach(c => c.classList.remove('hidden-column'));
                }
            }
        }
        
        // Run on page load
        window.addEventListener('DOMContentLoaded', function() {
            toggleEmptyColumns();
            applyFilters();
        });
    </script>
</body>
</html>
"@

# Combine all HTML parts
$htmlReport = $htmlHeader + $htmlBody + $htmlFooter

# Prompt user for save location
# Cross-platform output (macOS / Windows / Linux)

$desktopPath = [Environment]::GetFolderPath("Desktop")
$reportFileName = "AuthenticationMethodsReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$reportPath = Join-Path $desktopPath $reportFileName

# Write file
$htmlReport | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "HTML report generated successfully:" -ForegroundColor Green
Write-Host $reportPath -ForegroundColor Cyan

# Ask if user wants to open the report
$open = Read-Host "Would you like to open the report now? (Y/N)"
if ($open -match '^[Yy]') {
    Invoke-Item $reportPath
}
