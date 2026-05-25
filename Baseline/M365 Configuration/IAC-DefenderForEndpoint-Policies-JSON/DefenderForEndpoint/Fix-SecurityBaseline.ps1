<#
.SYNOPSIS
    Fix and import SecurityBaseline.json by replacing the 2 invalid settingValueTemplateIds.
#>
param(
    [string]$TenantId = 'e37d43b7-ff48-444b-9d44-fbd4477c18f3'
)

$ErrorActionPreference = 'Stop'

Connect-MgGraph -TenantId $TenantId -Scopes 'DeviceManagementConfiguration.ReadWrite.All' -NoWelcome
Write-Host "✅ Connected"

$sourceJsonRaw = Get-Content '/Users/jon/Desktop/DefenderForEndpoint/SecurityBaseline.json' -Raw
$sourceLines = $sourceJsonRaw -split "`n"

$badGuids = @('80734545-f819-4571-86a3-5a264f0cadf0', 'd26fde39-5e4d-4f2f-8c49-641033edba60')

# Step 1: Find which settingDefinitionId uses each bad GUID
Write-Host "`n=== Finding settings with bad GUIDs ==="
$badGuidToDefId = @{}
foreach ($guid in $badGuids) {
    for ($i = 0; $i -lt $sourceLines.Count; $i++) {
        if ($sourceLines[$i] -match $guid) {
            # Walk backwards to find the settingDefinitionId
            for ($j = $i; $j -ge [Math]::Max(0, $i - 30); $j--) {
                if ($sourceLines[$j] -match '"settingDefinitionId"\s*:\s*"([^"]+)"') {
                    $defId = $Matches[1]
                    $badGuidToDefId[$guid] = $defId
                    Write-Host "  Bad GUID $guid → settingDefinitionId: $defId"
                    break
                }
            }
        }
    }
}

# Step 2: Fetch template settings and find the correct GUIDs
Write-Host "`n=== Fetching template settings ==="
$templateId = '66df8dce-0166-4b82-92f7-1f74e3ca17a3_4'
$uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicyTemplates/$templateId/settingTemplates?`$top=500"
$templateSettings = @()
do {
    $r = Invoke-MgGraphRequest -Method GET -Uri $uri
    $templateSettings += $r.value
    $uri = $r.'@odata.nextLink'
} while ($uri)
Write-Host "  Fetched $($templateSettings.Count) template settings"

# Build lookup from settingDefinitionId to settingValueTemplateId
# Need to search recursively for nested template settings
$defIdToValueTemplateId = @{}

function Index-Template {
    param($tmpl)
    if ($null -eq $tmpl) { return }
    
    $defId = $tmpl.settingDefinitionId
    
    # Check various value template types
    if ($tmpl.choiceSettingValueTemplate.settingValueTemplateId) {
        $defIdToValueTemplateId[$defId] = $tmpl.choiceSettingValueTemplate.settingValueTemplateId
    }
    if ($tmpl.simpleSettingValueTemplate.settingValueTemplateId) {
        $defIdToValueTemplateId[$defId] = $tmpl.simpleSettingValueTemplate.settingValueTemplateId
    }
    
    # Recurse into children
    if ($tmpl.choiceSettingValueTemplate.defaultValue.children) {
        foreach ($child in $tmpl.choiceSettingValueTemplate.defaultValue.children) { Index-Template $child }
    }
    if ($tmpl.groupSettingCollectionValueTemplate) {
        foreach ($gsv in $tmpl.groupSettingCollectionValueTemplate) {
            if ($gsv.children) {
                foreach ($child in $gsv.children) { Index-Template $child }
            }
        }
    }
    if ($tmpl.groupSettingValueTemplate.children) {
        foreach ($child in $tmpl.groupSettingValueTemplate.children) { Index-Template $child }
    }
}

foreach ($ts in $templateSettings) {
    Index-Template $ts.settingInstanceTemplate
}
Write-Host "  Indexed $($defIdToValueTemplateId.Count) settingDefinitionId → settingValueTemplateId mappings"

# Step 3: Find correct replacements
Write-Host "`n=== Replacement map ==="
$replacements = @{}
foreach ($guid in $badGuids) {
    $defId = $badGuidToDefId[$guid]
    if ($defId -and $defIdToValueTemplateId.ContainsKey($defId)) {
        $correctGuid = $defIdToValueTemplateId[$defId]
        $replacements[$guid] = $correctGuid
        Write-Host "  $guid → $correctGuid (for $defId)"
    } else {
        Write-Host "  ⚠️ No replacement found for $guid (defId: $defId)"
    }
}

# Step 4: Do a simple string replace on the JSON
Write-Host "`n=== Applying replacements ==="
$fixedJson = $sourceJsonRaw
foreach ($kv in $replacements.GetEnumerator()) {
    $fixedJson = $fixedJson -replace $kv.Key, $kv.Value
    Write-Host "  Replaced $($kv.Key) → $($kv.Value)"
}

# Step 5: Parse and build policy body
$json = $fixedJson | ConvertFrom-Json

$body = [ordered]@{
    name            = $json.name
    description     = $json.description
    platforms       = $json.platforms
    technologies    = $json.technologies
    roleScopeTagIds = $json.roleScopeTagIds
    settings        = $json.settings
    templateReference = [ordered]@{
        templateId = $json.templateReference.templateId
    }
}

# Strip setting IDs and auditRuleInformation
function Clean-Setting {
    param($obj)
    if ($null -eq $obj) { return }
    
    if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        foreach ($item in $obj) { Clean-Setting $item }
    }
    elseif ($obj.PSObject) {
        if ($obj.PSObject.Properties['id']) { $obj.PSObject.Properties.Remove('id') }
        if ($obj.PSObject.Properties['auditRuleInformation']) { $obj.PSObject.Properties.Remove('auditRuleInformation') }
        foreach ($prop in $obj.PSObject.Properties) {
            if ($prop.Value -is [PSCustomObject] -or ($prop.Value -is [System.Collections.IEnumerable] -and $prop.Value -isnot [string])) {
                Clean-Setting $prop.Value
            }
        }
    }
}

foreach ($s in $body.settings) {
    Clean-Setting $s
}

$jsonBody = $body | ConvertTo-Json -Depth 50 -Compress
Write-Host "`n📤 Creating policy ($($jsonBody.Length) chars)..."

try {
    $result = Invoke-MgGraphRequest -Method POST `
        -Uri 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies' `
        -Body $jsonBody -ContentType 'application/json'
    
    Write-Host "✅ Security Baseline created → ID: $($result.id)" -ForegroundColor Green
    
    # Assign
    Write-Host "📌 Assigning to All Devices + All Licensed Users..."
    $assignBody = @{
        assignments = @(
            @{ target = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget'; deviceAndAppManagementAssignmentFilterId = $null; deviceAndAppManagementAssignmentFilterType = 'none' } },
            @{ target = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget'; deviceAndAppManagementAssignmentFilterId = $null; deviceAndAppManagementAssignmentFilterType = 'none' } }
        )
    } | ConvertTo-Json -Depth 10
    
    Invoke-MgGraphRequest -Method POST `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($result.id)/assign" `
        -Body $assignBody -ContentType 'application/json' | Out-Null
    
    Write-Host "✅ Assigned → All Devices + All Licensed Users" -ForegroundColor Green
    Write-Host "`n🎉 Windows 11 Security Baseline imported successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails) {
        $errMsg = $_.ErrorDetails.Message
        # Extract the inner Message
        if ($errMsg -match '"Message"\s*:\s*"(.*?)",' ) {
            $inner = $Matches[1] -replace '\\n', "`n" -replace '\\r', '' -replace '\\\\n', "`n"
            Write-Host "`nInner Error:" -ForegroundColor Yellow
            Write-Host $inner
        }
    }
}
