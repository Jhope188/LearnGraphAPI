#Requires -Modules Microsoft.Graph.Beta.Identity.DirectoryManagement
<#
.SYNOPSIS
    Creates a Restricted Management Administrative Unit (RMAU) with HiddenMembership visibility.

.DESCRIPTION
    Both isMemberManagementRestricted and visibility are immutable after creation.
    Neither can be set via the Entra portal — Graph API or PowerShell only.

    Required role: Privileged Role Administrator (tenant scope)
    Required permission: AdministrativeUnit.ReadWrite.All

.NOTES
    Author: Jon Hope | conditionalaccess.tech
    Reference: https://learn.microsoft.com/en-us/graph/api/directory-post-administrativeunits?view=graph-rest-beta
#>

# ---------------------------------------------------------------------------
# PROMPT for RMAU details
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "New Restricted Management Administrative Unit (RMAU)" -ForegroundColor Cyan
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan

do {
    $DisplayName = (Read-Host "Display Name").Trim()
} while ([string]::IsNullOrWhiteSpace($DisplayName))

do {
    $Description = (Read-Host "Description").Trim()
} while ([string]::IsNullOrWhiteSpace($Description))

Write-Host ""
# ---------------------------------------------------------------------------

# Connect using beta profile (required for isMemberManagementRestricted)
Write-Host "Connecting to Microsoft Graph (beta)..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "AdministrativeUnit.ReadWrite.All" -NoWelcome

# Confirm the signed-in context
$context = Get-MgContext
Write-Host "Signed in as : $($context.Account)" -ForegroundColor Green
Write-Host "Tenant ID    : $($context.TenantId)" -ForegroundColor Green
Write-Host ""

# Build the parameter hashtable
$params = @{
    displayName                  = $DisplayName
    description                  = $Description
    isMemberManagementRestricted = $true
    visibility                   = "HiddenMembership"
}

# Confirm before creating
Write-Host "About to create RMAU with the following settings:" -ForegroundColor Yellow
Write-Host "  Display Name              : $DisplayName"
Write-Host "  Description               : $Description"
Write-Host "  isMemberManagementRestricted : true  (PERMANENT - cannot be changed)"
Write-Host "  Visibility                : HiddenMembership  (PERMANENT - cannot be changed)"
Write-Host ""
$confirm = Read-Host "Proceed? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "Aborted." -ForegroundColor Red
    exit
}

# Create the RMAU
try {
    $rmau = New-MgBetaDirectoryAdministrativeUnit -BodyParameter $params

    Write-Host ""
    Write-Host "RMAU created successfully." -ForegroundColor Green
    Write-Host "  ID           : $($rmau.Id)"
    Write-Host "  Display Name : $($rmau.DisplayName)"
    Write-Host "  Visibility   : $($rmau.Visibility)"
    Write-Host "  Restricted   : $($rmau.AdditionalProperties['isMemberManagementRestricted'])"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Add members : https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AdminUnitObjectMenuBlade/~/Members/adminUnitId/$($rmau.Id)"
    Write-Host "  2. Assign roles: https://entra.microsoft.com/#view/Microsoft_AAD_IAM/AdminUnitObjectMenuBlade/~/Roles/adminUnitId/$($rmau.Id)"
}
catch {
    Write-Host "Failed to create RMAU:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}
finally {
    Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Gray
}
