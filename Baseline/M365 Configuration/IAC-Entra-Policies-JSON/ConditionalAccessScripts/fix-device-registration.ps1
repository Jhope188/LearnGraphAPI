# Fix the Device Registration policy
$policyName = "IAC - INTUNE – GRANT – Device Registration from trusted location"
Write-Host "🔧 Fixing: $policyName" -ForegroundColor Cyan

$jsonPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccess/$policyName.json"
$policy = Get-Content $jsonPath | ConvertFrom-Json
$config = $policy.PolicyConfig

# The authenticationStrength is a built-in MFA strength (ID: 00000000-0000-0000-0000-000000000002)
# Simplify to just the ID reference
if ($config.grantControls.authenticationStrength) {
    $strengthId = $config.grantControls.authenticationStrength.id
    Write-Host "  Simplifying authentication strength to ID: $strengthId" -ForegroundColor Yellow
    
    # Replace with simple ID reference
    $config.grantControls.authenticationStrength = @{ id = $strengthId }
}

# Remove any @odata.context properties
if ($config.grantControls.PSObject.Properties.Name -contains "authenticationStrength@odata.context") {
    $config.grantControls.PSObject.Properties.Remove("authenticationStrength@odata.context")
}

Write-Host "  Creating policy in target tenant..." -ForegroundColor Yellow

try {
    $created = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" -Body ($config | ConvertTo-Json -Depth 20)
    Write-Host "  ✅ Created: $($created.id)" -ForegroundColor Green
    Write-Host "  Policy Name: $($created.displayName)" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
}
