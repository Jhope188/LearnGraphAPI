# Fix and recreate the 3 failed policies

$policiesToFix = @(
    "IAC - GLOBAL – BLOCK – Countries not Allowed - NoExclusions",
    "IAC - GLOBAL – BLOCK – Service Accounts",
    "IAC - INTUNE – GRANT – Device Registration from trusted location"
)

foreach ($policyName in $policiesToFix) {
    Write-Host "`n🔧 Processing: $policyName" -ForegroundColor Cyan
    
    $jsonPath = "/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccess/$policyName.json"
    $policy = Get-Content $jsonPath | ConvertFrom-Json
    
    # Get the policy config
    $config = $policy.PolicyConfig
    
    # Remove the odata context from grantControls if it exists
    if ($config.grantControls.PSObject.Properties.Name -contains "authenticationStrength@odata.context") {
        $config.grantControls.PSObject.Properties.Remove("authenticationStrength@odata.context")
    }
    
    Write-Host "  Creating policy in target tenant..." -ForegroundColor Yellow
    
    try {
        $created = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" -Body ($config | ConvertTo-Json -Depth 20)
        Write-Host "  ✅ Created: $($created.id)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Failed: $_" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
