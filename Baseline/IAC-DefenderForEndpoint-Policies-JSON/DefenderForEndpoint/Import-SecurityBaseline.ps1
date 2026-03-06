<#
.SYNOPSIS
    Imports the Security Baseline policy with template reference remapping.
.DESCRIPTION
    The Security Baseline template has strict validation on settingInstanceTemplateReference
    and settingValueTemplateReference GUIDs. When importing from a different tenant, these 
    must be remapped to match the target tenant's template definition.
    
    This script:
    1. Fetches the complete template definition from the target tenant
    2. Builds a deep recursive lookup of ALL template references (including nested children)
    3. Remaps the SecurityBaseline.json settings to use correct references
    4. Creates the policy via Graph Beta API
    5. Assigns to All Devices + All Licensed Users
#>
param(
    [Parameter(Mandatory)]
    [string]$TenantId,
    
    [string]$PolicyFile = (Join-Path $PSScriptRoot 'SecurityBaseline.json')
)

$ErrorActionPreference = 'Stop'

# ─── Connect ────────────────────────────────────────────────────────
Write-Host "`n🔌 Connecting to Graph..." -ForegroundColor Cyan
Connect-MgGraph -TenantId $TenantId -Scopes 'DeviceManagementConfiguration.ReadWrite.All' -NoWelcome
Write-Host "   ✅ Connected to tenant: $TenantId"

# ─── Load source policy ────────────────────────────────────────────
Write-Host "`n📄 Loading $PolicyFile..."
$sourcePolicy = Get-Content $PolicyFile -Raw | ConvertFrom-Json
$templateId = $sourcePolicy.templateReference.templateId
Write-Host "   Template: $templateId"
Write-Host "   Name: $($sourcePolicy.name)"

# ─── Fetch ALL template setting definitions (recursive) ────────────
Write-Host "`n📥 Fetching template definitions from target tenant..."
$uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicyTemplates/$templateId/settingTemplates?`$top=500"
$templateSettingsList = @()
do {
    $result = Invoke-MgGraphRequest -Method GET -Uri $uri
    $templateSettingsList += $result.value
    $uri = $result.'@odata.nextLink'
} while ($uri)
Write-Host "   Found $($templateSettingsList.Count) top-level template settings"

# ─── Build DEEP lookup: settingDefinitionId -> full template data ──
# This recursively indexes all nested children so group settings,
# choice children, etc. are all accessible by settingDefinitionId
$templateLookup = @{}

function Index-TemplateRecursive {
    param($templateObj)
    
    if ($null -eq $templateObj) { return }
    
    # Index this template by its settingDefinitionId
    $defId = $templateObj.settingDefinitionId
    if ($defId) {
        $templateLookup[$defId] = $templateObj
    }
    
    # Recurse into all possible child locations based on @odata.type
    $odataType = $templateObj.'@odata.type'
    
    # Choice setting children (in defaultValue.children)
    if ($templateObj.choiceSettingValueTemplate) {
        $csv = $templateObj.choiceSettingValueTemplate
        if ($csv.defaultValue -and $csv.defaultValue.children) {
            foreach ($child in $csv.defaultValue.children) {
                Index-TemplateRecursive $child
            }
        }
    }
    
    # Group setting collection children
    if ($templateObj.groupSettingCollectionValueTemplate) {
        foreach ($gsv in $templateObj.groupSettingCollectionValueTemplate) {
            if ($gsv.children) {
                foreach ($child in $gsv.children) {
                    Index-TemplateRecursive $child
                }
            }
        }
    }
    
    # Group setting (non-collection) children
    if ($templateObj.groupSettingValueTemplate) {
        if ($templateObj.groupSettingValueTemplate.children) {
            foreach ($child in $templateObj.groupSettingValueTemplate.children) {
                Index-TemplateRecursive $child
            }
        }
    }
    
    # Simple setting collection
    if ($templateObj.simpleSettingCollectionValueTemplate) {
        foreach ($item in $templateObj.simpleSettingCollectionValueTemplate) {
            if ($item.children) {
                foreach ($child in $item.children) {
                    Index-TemplateRecursive $child
                }
            }
        }
    }
    
    # Simple setting children
    if ($templateObj.simpleSettingValueTemplate) {
        if ($templateObj.simpleSettingValueTemplate.children) {
            foreach ($child in $templateObj.simpleSettingValueTemplate.children) {
                Index-TemplateRecursive $child
            }
        }
    }
}

# Index all top-level templates and their recursive children
foreach ($ts in $templateSettingsList) {
    Index-TemplateRecursive $ts.settingInstanceTemplate
}
Write-Host "   Indexed $($templateLookup.Count) total setting definitions (including nested)"

# ─── Remap function ───────────────────────────────────────────────
function Remap-SettingInstance {
    param($si)
    
    if ($null -eq $si) { return }
    
    $defId = $si.settingDefinitionId
    $tmpl = $templateLookup[$defId]
    
    # Remap settingInstanceTemplateReference
    if ($tmpl -and $tmpl.settingInstanceTemplateId) {
        $si.settingInstanceTemplateReference = @{
            settingInstanceTemplateId = $tmpl.settingInstanceTemplateId
        }
    } elseif ($si.PSObject.Properties['settingInstanceTemplateReference']) {
        # Remove invalid reference if no template match
        $si.PSObject.Properties.Remove('settingInstanceTemplateReference')
    }
    
    # Remove auditRuleInformation (read-only)
    if ($si.PSObject.Properties['auditRuleInformation']) {
        $si.PSObject.Properties.Remove('auditRuleInformation')
    }
    
    $odataType = $si.'@odata.type'
    
    switch -Wildcard ($odataType) {
        '*ChoiceSettingInstance' {
            $csv = $si.choiceSettingValue
            if ($csv -and $tmpl.choiceSettingValueTemplate) {
                $valTmplId = $tmpl.choiceSettingValueTemplate.settingValueTemplateId
                if ($valTmplId) {
                    $csv.settingValueTemplateReference = @{
                        settingValueTemplateId = $valTmplId
                        useTemplateDefault    = $false
                    }
                } elseif ($csv.PSObject.Properties['settingValueTemplateReference']) {
                    $csv.PSObject.Properties.Remove('settingValueTemplateReference')
                }
            }
            if ($csv.children) {
                foreach ($child in $csv.children) { Remap-SettingInstance $child }
            }
        }
        '*SimpleSettingInstance' {
            $ssv = $si.simpleSettingValue
            if ($ssv -and $tmpl.simpleSettingValueTemplate) {
                $valTmplId = $tmpl.simpleSettingValueTemplate.settingValueTemplateId
                if ($valTmplId) {
                    $ssv.settingValueTemplateReference = @{
                        settingValueTemplateId = $valTmplId
                        useTemplateDefault    = $false
                    }
                } elseif ($ssv.PSObject.Properties['settingValueTemplateReference']) {
                    $ssv.PSObject.Properties.Remove('settingValueTemplateReference')
                }
            }
        }
        '*ChoiceSettingCollectionInstance' {
            if ($si.choiceSettingCollectionValue) {
                $i = 0
                foreach ($item in $si.choiceSettingCollectionValue) {
                    if ($tmpl.choiceSettingCollectionValueTemplate -and $tmpl.choiceSettingCollectionValueTemplate.Count -gt $i) {
                        $valTmplId = $tmpl.choiceSettingCollectionValueTemplate[$i].settingValueTemplateId
                        if ($valTmplId) {
                            $item.settingValueTemplateReference = @{
                                settingValueTemplateId = $valTmplId
                                useTemplateDefault    = $false
                            }
                        }
                    }
                    if ($item.children) {
                        foreach ($child in $item.children) { Remap-SettingInstance $child }
                    }
                    $i++
                }
            }
        }
        '*SimpleSettingCollectionInstance' {
            if ($si.simpleSettingCollectionValue -and $tmpl.simpleSettingCollectionValueTemplate) {
                $i = 0
                foreach ($item in $si.simpleSettingCollectionValue) {
                    if ($tmpl.simpleSettingCollectionValueTemplate.Count -gt $i) {
                        $valTmplId = $tmpl.simpleSettingCollectionValueTemplate[$i].settingValueTemplateId
                        if ($valTmplId) {
                            $item.settingValueTemplateReference = @{
                                settingValueTemplateId = $valTmplId
                                useTemplateDefault    = $false
                            }
                        }
                    }
                    $i++
                }
            }
        }
        '*GroupSettingInstance' {
            if ($si.groupSettingValue -and $si.groupSettingValue.children) {
                # Remap the groupSettingValueTemplateReference if present
                if ($tmpl.groupSettingValueTemplate -and $tmpl.groupSettingValueTemplate.settingValueTemplateId) {
                    $si.groupSettingValue.settingValueTemplateReference = @{
                        settingValueTemplateId = $tmpl.groupSettingValueTemplate.settingValueTemplateId
                        useTemplateDefault    = $false
                    }
                }
                foreach ($child in $si.groupSettingValue.children) { Remap-SettingInstance $child }
            }
        }
        '*GroupSettingCollectionInstance' {
            if ($si.groupSettingCollectionValue) {
                $i = 0
                foreach ($gsv in $si.groupSettingCollectionValue) {
                    if ($tmpl.groupSettingCollectionValueTemplate -and $tmpl.groupSettingCollectionValueTemplate.Count -gt $i) {
                        $valTmplId = $tmpl.groupSettingCollectionValueTemplate[$i].settingValueTemplateId
                        if ($valTmplId) {
                            $gsv.settingValueTemplateReference = @{
                                settingValueTemplateId = $valTmplId
                                useTemplateDefault    = $false
                            }
                        }
                    }
                    if ($gsv.children) {
                        foreach ($child in $gsv.children) { Remap-SettingInstance $child }
                    }
                    $i++
                }
            }
        }
    }
}

# ─── Build clean body ─────────────────────────────────────────────
Write-Host "`n🔧 Building policy body with remapped template references..."
$body = [ordered]@{
    name              = $sourcePolicy.name
    description       = $sourcePolicy.description
    platforms         = $sourcePolicy.platforms
    technologies      = $sourcePolicy.technologies
    roleScopeTagIds   = $sourcePolicy.roleScopeTagIds
    settings          = $sourcePolicy.settings
    templateReference = [ordered]@{
        templateId = $templateId
    }
}

$remapCount = 0
foreach ($s in $body.settings) {
    $s.PSObject.Properties.Remove('id')
    Remap-SettingInstance $s.settingInstance
    $remapCount++
}
Write-Host "   Processed $remapCount top-level settings"

# ─── POST to Graph ────────────────────────────────────────────────
$jsonBody = $body | ConvertTo-Json -Depth 50 -Compress
Write-Host "`n📤 Creating policy ($($jsonBody.Length) chars)..."

try {
    $result = Invoke-MgGraphRequest -Method POST `
        -Uri 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies' `
        -Body $jsonBody -ContentType 'application/json'
    
    Write-Host "   ✅ Created → ID: $($result.id)" -ForegroundColor Green
    
    # ─── Assign ────────────────────────────────────────────────────
    Write-Host "`n📌 Assigning to All Devices + All Licensed Users..."
    $assignBody = @{
        assignments = @(
            @{
                target = @{
                    '@odata.type'                                = '#microsoft.graph.allDevicesAssignmentTarget'
                    deviceAndAppManagementAssignmentFilterId     = $null
                    deviceAndAppManagementAssignmentFilterType   = 'none'
                }
            },
            @{
                target = @{
                    '@odata.type'                                = '#microsoft.graph.allLicensedUsersAssignmentTarget'
                    deviceAndAppManagementAssignmentFilterId     = $null
                    deviceAndAppManagementAssignmentFilterType   = 'none'
                }
            }
        )
    } | ConvertTo-Json -Depth 10
    
    Invoke-MgGraphRequest -Method POST `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$($result.id)/assign" `
        -Body $assignBody -ContentType 'application/json' | Out-Null
    
    Write-Host "   ✅ Assigned" -ForegroundColor Green
    Write-Host "`n🎉 Windows 11 Security Baseline successfully imported!" -ForegroundColor Green
    
} catch {
    Write-Host "   ❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails) {
        $errMsg = $_.ErrorDetails.Message
        # Try to extract the inner error message
        if ($errMsg -match '"Message"\s*:\s*"([^"]+)"') {
            $innerMsg = $Matches[1] -replace '\\n', "`n" -replace '\\r', ''
            Write-Host "`n   Inner Error:" -ForegroundColor Yellow
            Write-Host "   $innerMsg"
        }
        
        # Extract invalid reference IDs for debugging
        if ($errMsg -match 'InvalidReferenceId\\n([a-f0-9-]+)') {
            $badId = $Matches[1]
            Write-Host "`n   Invalid Reference ID: $badId" -ForegroundColor Yellow
            # Find which setting uses this ID
            $jsonStr = $jsonBody
            if ($jsonStr -match "($badId)") {
                Write-Host "   This ID is present in the payload — remapping may have missed it"
            }
        }
    }
}
