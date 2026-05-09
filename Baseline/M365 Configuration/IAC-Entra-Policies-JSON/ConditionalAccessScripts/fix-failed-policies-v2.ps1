# Fix and recreate the 3 failed policies with proper ID mapping

# Build location ID mapping from summary
$summary = Get-Content "/Users/jon/Desktop/BaslineSetup/entra-policy-recreation-summary.json" | ConvertFrom-Json
$locationMapping = @{}
foreach ($loc in $summary.CreatedLocations) {
    $locationMapping[$loc.SourceId] = $loc.NewId
}

# Add the Blocked Countries mapping (policy references a non-IAC location ID, map to IAC - Blocked Countries)
$blockedCountriesNewId = ($summary.CreatedLocations | Where-Object { $_.Name -eq "IAC - Blocked Countries" }).NewId
$locationMapping["19895061-779a-4200-9524-36bccf61f684"] = $blockedCountriesNewId

Write-Host "=== Named Location ID Mappings ===" -ForegroundColor Cyan
$locationMapping.GetEnumerator() | ForEach-Object {
    Write-Host "$($_.Key) -> $($_.Value)"
}

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
    if ($config.grantControls -and ($config.grantControls.PSObject.Properties.Name -contains "authenticationStrength@odata.context")) {
        Write-Host "  Removing @odata.context from grantControls..." -ForegroundColor Yellow
        $config.grantControls.PSObject.Properties.Remove("authenticationStrength@odata.context")
    }
    
    # Map Named Location IDs
    if ($config.conditions.locations) {
        Write-Host "  Mapping Named Location IDs..." -ForegroundColor Yellow
        
        # Map includeLocations
        if ($config.conditions.locations.includeLocations) {
            for ($i = 0; $i -lt $config.conditions.locations.includeLocations.Count; $i++) {
                $oldId = $config.conditions.locations.includeLocations[$i]
                if ($locationMapping.ContainsKey($oldId)) {
                    $newId = $locationMapping[$oldId]
                    Write-Host "    Include: $oldId -> $newId" -ForegroundColor Green
                    $config.conditions.locations.includeLocations[$i] = $newId
                }
            }
        }
        
        # Map excludeLocations
        if ($config.conditions.locations.excludeLocations) {
            for ($i = 0; $i -lt $config.conditions.locations.excludeLocations.Count; $i++) {
                $oldId = $config.conditions.locations.excludeLocations[$i]
                if ($locationMapping.ContainsKey($oldId)) {
                    $newId = $locationMapping[$oldId]
                    Write-Host "    Exclude: $oldId -> $newId" -ForegroundColor Green
                    $config.conditions.locations.excludeLocations[$i] = $newId
                }
            }
        }
    }
    
    Write-Host "  Creating policy in target tenant..." -ForegroundColor Yellow
    
    try {
        $created = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" -Body ($config | ConvertTo-Json -Depth 20)
        Write-Host "  ✅ Created: $($created.id)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
        # Show more details
        if ($_.Exception.Response) {
            $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "  Response: $responseBody" -ForegroundColor Red
        }
    }
}
