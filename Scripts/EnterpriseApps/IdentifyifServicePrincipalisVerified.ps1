###############################################################################
# Purpose:
# This script uses the Microsoft Graph PowerShell SDK to retrieve information
# about Enterprise Applications (Service Principals) and identify their
# verified publishers.
#
# It is commonly used for:
# - Third-party application risk reviews
# - Enterprise Application governance
# - Security and compliance audits
# - Validating app trust prior to Conditional Access enforcement
#
# This script is READ-ONLY and does not modify any tenant configuration.
###############################################################################

# ---------------------------------------------------------------------------
# Connect to Microsoft Graph with permissions required to read:
# - Enterprise Applications (Application.Read.All)
# - Directory metadata such as publisher verification (Directory.Read.All)
# ---------------------------------------------------------------------------
Connect-MgGraph -Scopes "Application.Read.All", "Directory.Read.All"

###############################################################################
# SECTION 1: Retrieve Enterprise Applications and Publisher Information
###############################################################################

# Retrieve all service principals (Enterprise Applications) and display:
# - DisplayName        : Friendly application name
# - AppId              : Globally unique application identifier
# - PublisherName      : Claimed publisher name
# - VerifiedPublisher  : Publisher verification object (null if not verified)
Get-MgServicePrincipal -All |
    Select-Object DisplayName, AppId, PublisherName, VerifiedPublisher

###############################################################################
# SECTION 2: Search for Enterprise Applications by Display Name
###############################################################################

# Retrieve all Enterprise Applications whose display name contains "apex"
# Useful for investigating a specific vendor or product
Get-MgServicePrincipal -All |
    Where-Object { $_.DisplayName -like '*apex*' }

###############################################################################
# SECTION 3: Retrieve a Specific Enterprise Application by App ID
###############################################################################

# Retrieve a single Enterprise Application using its App ID
# App IDs are globally unique and preferred over display names for accuracy
$app = Get-MgServicePrincipal -Filter "appId eq 'Sepcific ObjectID of an App'"

###############################################################################
# SECTION 4: View Raw Verified Publisher Details
###############################################################################

# Output the full VerifiedPublisher object for the selected application
# This will be null if the publisher is not Microsoft-verified
$app.VerifiedPublisher

###############################################################################
# SECTION 5: Display Verified Publisher Information in a Clean Format
###############################################################################

# Display a formatted view showing:
# - Application name
# - Application ID
# - Verified publisher display name
# - Verified publisher ID
$app | Select-Object `
    DisplayName,
    AppId,
    @{Name = "VerifiedPublisherName"; Expression = { $_.VerifiedPublisher.DisplayName }},
    @{Name = "VerifiedPublisherId"; Expression = { $_.VerifiedPublisher.VerifiedPublisherId }}

###############################################################################
# SECTION 6: Search for Applications and Display Verified Publisher Status
###############################################################################

# Retrieve all Enterprise Applications with "printix" in the name and display
# their verified publisher status
Get-MgServicePrincipal -All |
    Where-Object { $_.DisplayName -match 'printix' } |
    Select-Object `
        DisplayName,
        AppId,
        @{Name = "VerifiedPublisher"; Expression = { $_.VerifiedPublisher.DisplayName }}
