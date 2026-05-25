###############################################################################
# Purpose:
# Manage visibility of Enterprise Applications (Service Principals) in the
# Microsoft "My Apps" portal by adding or removing the "HideApp" tag.
#
# - Hide all Enterprise Apps from My Apps
# - Hide a single Enterprise App (for testing)
# - Unhide all Enterprise Apps
#
# Notes:
# - Adding the "HideApp" tag hides the app from the My Apps portal
# - This does NOT disable the application or affect sign-in
# - Users can still access the app directly if assigned
#
# Required Permissions:
# - Application.ReadWrite.All (hide/unhide)
# - Application.Read.All (read-only verification)
###############################################################################

# ---------------------------------------------------------------------------
# Install Microsoft Graph PowerShell module (run once per user)
# ---------------------------------------------------------------------------
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# ---------------------------------------------------------------------------
# Connect to Microsoft Graph with permissions required to modify apps
# ---------------------------------------------------------------------------
Connect-MgGraph -Scopes "Application.ReadWrite.All"

###############################################################################
# SECTION 1: Hide ALL Enterprise Applications from My Apps
###############################################################################

# Retrieve all Enterprise Applications (Service Principals)
$servicePrincipals = Get-MgServicePrincipal -All

foreach ($sp in $servicePrincipals) {
    # Add the "HideApp" tag to hide the app from My Apps
    Update-MgServicePrincipal `
        -ServicePrincipalId $sp.Id `
        -AccountEnabled:$true `
        -Tags @("HideApp")

    Write-Output "Hidden app: $($sp.DisplayName)"
}

Write-Output "Completed hiding all Enterprise Applications from My Apps."

###############################################################################
# SECTION 2: Hide a SINGLE Enterprise Application (Test / Validation)
###############################################################################

# Define the Display Name of the Enterprise App to hide
$servicePrincipalName = "Graph Explorer"

# Retrieve the specific Service Principal
$servicePrincipal = Get-MgServicePrincipal -Filter "displayName eq '$servicePrincipalName'"

if ($servicePrincipal) {
    # Add the "HideApp" tag
    Update-MgServicePrincipal `
        -ServicePrincipalId $servicePrincipal.Id `
        -AccountEnabled:$true `
        -Tags @("HideApp")

    Write-Output "Hidden app: $($servicePrincipal.DisplayName)"
}
else {
    Write-Output "Service principal '$servicePrincipalName' not found."
}

###############################################################################
# SECTION 3: Review which Enterprise Apps are hidden
###############################################################################

# Retrieve all Service Principals and show HideApp status
Get-MgServicePrincipal -All |
    Select-Object `
        DisplayName,
        @{Name = "IsHiddenFromMyApps"; Expression = { $_.Tags -contains "HideApp" }},
        Tags |
    Format-Table -AutoSize

###############################################################################
# SECTION 4: Unhide ALL Enterprise Applications
###############################################################################

# Loop through all Service Principals
$servicePrincipals = Get-MgServicePrincipal -All

foreach ($sp in $servicePrincipals) {
    if ($sp.Tags -contains "HideApp") {

        # Remove the HideApp tag while preserving any other tags
        $updatedTags = $sp.Tags | Where-Object { $_ -ne "HideApp" }

        # Update the Service Principal
        Update-MgServicePrincipal `
            -ServicePrincipalId $sp.Id `
            -Tags $updatedTags

        Write-Output "Unhidden app: $($sp.DisplayName)"
    }
}

Write-Output "Completed unhiding all Enterprise Applications."

###############################################################################
# SECTION 5: Final Verification
###############################################################################

Get-MgServicePrincipal -All |
    Select-Object `
        DisplayName,
        @{Name = "IsHiddenFromMyApps"; Expression = { $_.Tags -contains "HideApp" }} |
    Format-Table -AutoSize
