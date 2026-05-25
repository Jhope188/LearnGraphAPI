Connect-AzAccount
# Connect-MgGraph not needed for this ARM call

#old Code broke
#This is almost certainly the Az 14 / Az.Accounts 5 breaking change: Get-AzAccessToken now returns the token as a SecureString by default, so your header ends up effectively being Bearer System.Security.SecureString (or otherwise not a real plaintext JWT), and ARM rejects it. 

#Fix option A (best if you’re on PowerShell 7+): use -Authentication Bearer -Token
#PowerShell’s Invoke-RestMethod can take a SecureString token directly: System.Security.SecureString

$subid = (Get-AzContext).Subscription.Id
$clientId = "ACME"
$region   = "AZE2"

$secureToken = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token

$categoriesEndpoint = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettingsCategories?api-version=2017-04-01-preview"
$categoriesResponse = Invoke-RestMethod -Uri $categoriesEndpoint -Method Get -Authentication Bearer -Token $secureToken

$logs = foreach ($cat in $categoriesResponse.value) {
  @{ category = $cat.name; enabled = $true }
}

$body = @{
  properties = @{
    logs        = $logs
    metrics     = @()
    workspaceId = "/subscriptions/$subid/resourceGroups/$clientId-$region-RG1/providers/Microsoft.OperationalInsights/workspaces/$clientId-$region-AAD-LAW"
  }
} | ConvertTo-Json -Depth 8

$apiEndpoint = "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/$clientId-AAD-LOGS?api-version=2017-04-01-preview"
$response = Invoke-RestMethod -Uri $apiEndpoint -Method Put -Authentication Bearer -Token $secureToken -ContentType "application/json" -Body $body

"Diagnostic setting created successfully."


