###############################################################################
# Primary use of this set of commands:
# Register (create) Enterprise Apps (Service Principals) in your tenant so they
# can be explicitly targeted by Conditional Access policies (e.g., include /
# exclude specific cloud apps).
###############################################################################

# ---------------------------------------------------------------------------
# Reference list of Microsoft first-party App IDs
# This CSV is often used to identify Microsoft apps by AppId/Name mappings.
# ---------------------------------------------------------------------------
<https://github.com/merill/microsoft-info>
<https://raw.githubusercontent.com/merill/microsoft-info/main/_info/MicrosoftApps.csv>


# ---------------------------------------------------------------------------
# COMMAND: List service principals (Enterprise Apps) in the tenant
# What it does:
# Retrieves service principals. Without parameters, this returns a default page
# of results (not all objects).
# Primary CA use:
# Helps you confirm whether a given Enterprise App already exists in the tenant.
# ---------------------------------------------------------------------------
Get-MgServicePrincipal


# ---------------------------------------------------------------------------
# COMMAND: Query service principals with a filter + count (advanced query)
# What it does:
# Uses "eventual" consistency and requests a count, then filters for apps whose
# DisplayName starts with 'a', returning only the top 5.
# Primary CA use:
# Useful for quickly searching/confirming whether a target app exists before you
# attempt to register/create it.
# ---------------------------------------------------------------------------
Get-MgServicePrincipal -ConsistencyLevel eventual -Count spCount -Filter "startsWith(DisplayName, 'a')" -Top 5


# ---------------------------------------------------------------------------
# COMMAND: Connect to Microsoft Graph (write access)
# What it does:
# Authenticates to Graph with permissions needed to create service principals.
# Primary CA use:
# Required before registering Enterprise Apps so they show up as selectable
# "Cloud apps" in Conditional Access targeting.
# ---------------------------------------------------------------------------
Connect-MgGraph -Scopes "Application.ReadWrite.All"


# ---------------------------------------------------------------------------
# COMMAND: Register/Create an Enterprise App (Service Principal) by AppId
# What it does:
# Creates a service principal in your tenant for the specified application ID.
# AppId: 16aeb910-ce68-41d1-9ac3-9e1673ac9575 (IrisFrontDoorSelector)
# Primary CA use:
# Ensures this Enterprise App exists so it can be included/excluded in a CA policy.
# ---------------------------------------------------------------------------
$ServicePrincipalBody = @{
    AppId = "16aeb910-ce68-41d1-9ac3-9e1673ac9575" # IrisFrontDoorSelector
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalBody | Format-List Id, DisplayName, AppId, SignInAudience



# ---------------------------------------------------------------------------
# COMMAND: Register/Create an Enterprise App (Service Principal) by AppId
# What it does:
# Creates a service principal in your tenant for the specified application ID.
# AppId: 499b84ac-1321-427f-aa17-267ca6975798 (Azure DevOps)
# Primary CA use:
# Common app to explicitly include/exclude in Conditional Access.
# ---------------------------------------------------------------------------
$ServicePrincipalBody = @{
    AppId = "499b84ac-1321-427f-aa17-267ca6975798" # AzureDevOps
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalBody | Format-List Id, DisplayName, AppId, SignInAudience



# ---------------------------------------------------------------------------
# NOTE (not a command):
# Azure Credential Configuration Endpoint Service
# Often referenced in passkey registration discussions.
# AppId: ea890292-c8c8-4433-b5ea-b09d0668e1a6
# Source reference:
# https://nathanmcnulty.com/blog/2025/09/improving-passkey-registration-experiences/
# ---------------------------------------------------------------------------

$ServicePrincipalBody = @{
    AppId = "ea890292-c8c8-4433-b5ea-b09d0668e1a6" # Azure Credential Configuration Endpoint Service
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalBody | Format-List Id, DisplayName, AppId, SignInAudience


# ---------------------------------------------------------------------------
# COMMAND: Register/Create an Enterprise App (Service Principal) by AppId
# What it does:
# Creates a service principal in your tenant for the specified application ID.
# AppId: d4ebce55-015a-49b5-a083-c84d1797ae8c (MicrosoftIntuneEnrollment)
# Primary CA use:
# Ensures Intune enrollment-related app exists for CA targeting decisions.
# ---------------------------------------------------------------------------
$ServicePrincipalBody = @{
    AppId = "d4ebce55-015a-49b5-a083-c84d1797ae8c" # MicrosoftIntuneEnrollment
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalBody | Format-List Id, DisplayName, AppId, SignInAudience


# ---------------------------------------------------------------------------
# COMMAND: Register/Create an Enterprise App (Service Principal) by AppId
# What it does:
# Creates a service principal in your tenant for the specified application ID.
# AppId: 44660504-c45b3-4674-a709-71951a6b0763 (Microsoft Invitation Acceptance Portal)
# Primary CA use:
# Ensures invitation acceptance flows can be targeted/handled in CA policies.
# ---------------------------------------------------------------------------
$ServicePrincipalBody = @{
    AppId = "44660504-c45b3-4674-a709-71951a6b0763" # Microsoft Invitation Acceptance Portal
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalBody | Format-List Id, DisplayName, AppId, SignInAudience


# ---------------------------------------------------------------------------
# COMMAND: Register/Create an Enterprise App (Service Principal) by AppId (alternate syntax)
# What it does:
# Same result as above, using an inline body hashtable.
# Primary CA use:
# Ensures the Enterprise App exists for Conditional Access targeting.
# ---------------------------------------------------------------------------
New-MgServicePrincipal -BodyParameter @{ AppId = "44660504-c45b3-4674-a709-71951a6b0763" }


# ---------------------------------------------------------------------------
# COMMANDS: "Create if missing" pattern for an Enterprise App (Service Principal)
# What it does:
# 1) Sets the AppId
# 2) Attempts to retrieve the service principal by AppId
# 3) Creates it only if it does not already exist
# Primary CA use:
# Avoids errors/duplicates when ensuring apps are registered for CA targeting.
# ---------------------------------------------------------------------------
$appId = "44660504-c45b3-4674-a709-71951a6b0763"
$sp = Get-MgServicePrincipal -Filter "appId eq '$appId'" -ErrorAction SilentlyContinue

if (-not $sp) {
    New-MgServicePrincipal -BodyParameter @{ AppId = $appId }
} else {
    Write-Host "Service principal already exists: $($sp.DisplayName)"
}


# ---------------------------------------------------------------------------
# COMMAND: Register/Create an Enterprise App (Service Principal) by AppId
# What it does:
# Creates a service principal in your tenant for the specified application ID.
# AppId: c2b688fe-48c0-464b-a89c-67041aa8fcb2 (MicrosoftDefenderATP MAM)
# Primary CA use:
# Ensures the app exists so you can include/exclude it in Conditional Access.
# ---------------------------------------------------------------------------
$ServicePrincipalBody = @{
    AppId = "c2b688fe-48c0-464b-a89c-67041aa8fcb2" # MicrosoftDefenderATP MAM
}
New-MgServicePrincipal -BodyParameter $ServicePrincipalBody | Format-List Id, DisplayName, AppId, SignInAudience
