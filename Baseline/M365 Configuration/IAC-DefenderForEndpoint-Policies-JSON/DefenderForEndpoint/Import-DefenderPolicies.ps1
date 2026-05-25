<#
.SYNOPSIS
    Imports Defender for Endpoint baseline policies into a target Microsoft 365 tenant.

.DESCRIPTION
    Reads all policy JSON files from the DefenderForEndpoint folder, creates each policy
    via the Microsoft Graph Beta API, and assigns them to All Devices + All Licensed Users.

    Source-tenant IDs, OData context, and metadata are stripped automatically — new IDs
    are generated in the target tenant.

.PARAMETER TenantId
    The target tenant ID to import policies into.

.PARAMETER PolicyFolder
    Path to the folder containing the policy JSON files. Defaults to the script's own directory.

.PARAMETER WhatIf
    Preview what would be imported without making any changes.

.EXAMPLE
    .\Import-DefenderPolicies.ps1 -TenantId 'e37d43b7-ff48-444b-9d44-fbd4477c18f3'

.EXAMPLE
    .\Import-DefenderPolicies.ps1 -TenantId 'e37d43b7-ff48-444b-9d44-fbd4477c18f3' -WhatIf

.NOTES
    Requires: Microsoft.Graph.Authentication module
    Scopes:   DeviceManagementConfiguration.ReadWrite.All
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [string]$PolicyFolder = $PSScriptRoot
)

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
$graphBaseUri = 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies'
$requiredScopes = @('DeviceManagementConfiguration.ReadWrite.All')

# Import order: Audit policies first, then enforcement
$importOrder = @(
    'ASR-Audit.json'
    'ASR-ExploitProtection.json'
    'ASR-DeviceControl.json'
    'ASR-AppBrowserIsolation.json'
    'Firewall.json'
    'Antivirus-SecurityExperience.json'
    'Antivirus-DefenderUpdateControls.json'
    'Antivirus-Exclusions.json'
    'Antivirus-DefenderAntivirus.json'
    'SecurityBaseline.json'
    'ASR-Rules.json'  # Enforcement last — deploy after audit monitoring
)

# ─────────────────────────────────────────────
# Functions
# ─────────────────────────────────────────────
function Write-Banner {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║   Defender for Endpoint — Baseline Policy Importer      ║' -ForegroundColor Cyan
    Write-Host '║   Microsoft Graph Beta API                              ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''
}

function Connect-ToGraph {
    param([string]$Tenant, [string[]]$Scopes)

    # Check if Microsoft.Graph.Authentication module is available
    if (-not (Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication')) {
        Write-Host '❌ Microsoft.Graph.Authentication module not found.' -ForegroundColor Red
        Write-Host '   Install it with: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser' -ForegroundColor Yellow
        throw 'Missing required module: Microsoft.Graph.Authentication'
    }

    # Check if already connected to the correct tenant
    $context = Get-MgContext -ErrorAction SilentlyContinue
    if ($context -and $context.TenantId -eq $Tenant) {
        Write-Host "✅ Already connected to tenant: $Tenant" -ForegroundColor Green
        return
    }

    Write-Host "🔐 Connecting to tenant: $Tenant" -ForegroundColor Yellow
    Connect-MgGraph -TenantId $Tenant -Scopes $Scopes -NoWelcome
    $context = Get-MgContext
    Write-Host "✅ Connected as: $($context.Account) → $($context.TenantId)" -ForegroundColor Green
}

function Build-PolicyBody {
    param([PSCustomObject]$PolicyJson)

    # Build clean body — strip source-tenant IDs, OData context, and read-only fields
    $body = [ordered]@{
        name            = $PolicyJson.name
        description     = $PolicyJson.description
        platforms       = $PolicyJson.platforms
        technologies    = $PolicyJson.technologies
        roleScopeTagIds = $PolicyJson.roleScopeTagIds
        settings        = $PolicyJson.settings
        templateReference = [ordered]@{
            templateId = $PolicyJson.templateReference.templateId
        }
    }

    # Clean each setting — remove the 'id' field (Graph auto-generates these)
    foreach ($setting in $body.settings) {
        $setting.PSObject.Properties.Remove('id')
    }

    return $body
}

function Build-AssignmentBody {
    # Standard assignment: All Devices + All Licensed Users
    $assignments = @(
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

    return @{ assignments = $assignments }
}

function Import-SinglePolicy {
    param(
        [string]$FilePath,
        [int]$Index,
        [int]$Total
    )

    $fileName = Split-Path $FilePath -Leaf
    $json = Get-Content $FilePath -Raw | ConvertFrom-Json

    Write-Host ''
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "[$Index/$Total] $($json.name)" -ForegroundColor White
    Write-Host "  File:     $fileName" -ForegroundColor DarkGray
    Write-Host "  Template: $($json.templateReference.templateDisplayName)" -ForegroundColor DarkGray
    Write-Host "  Settings: $($json.settingCount)" -ForegroundColor DarkGray

    if ($PSCmdlet.ShouldProcess($json.name, 'Create policy')) {
        try {
            # Create the policy
            $body = Build-PolicyBody -PolicyJson $json
            $bodyJson = $body | ConvertTo-Json -Depth 50 -Compress

            $policy = Invoke-MgGraphRequest -Method POST -Uri $graphBaseUri `
                -Body $bodyJson -ContentType 'application/json'

            Write-Host "  ✅ Created → ID: $($policy.id)" -ForegroundColor Green

            # Assign the policy
            $assignBody = Build-AssignmentBody
            $assignJson = $assignBody | ConvertTo-Json -Depth 10 -Compress

            Invoke-MgGraphRequest -Method POST `
                -Uri "$graphBaseUri('$($policy.id)')/assign" `
                -Body $assignJson -ContentType 'application/json' | Out-Null

            Write-Host "  📌 Assigned → All Devices + All Licensed Users" -ForegroundColor Cyan

            return [PSCustomObject]@{
                File     = $fileName
                Name     = $json.name
                PolicyId = $policy.id
                Status   = 'Success'
                Error    = $null
            }
        }
        catch {
            Write-Host "  ❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red

            return [PSCustomObject]@{
                File     = $fileName
                Name     = $json.name
                PolicyId = $null
                Status   = 'Failed'
                Error    = $_.Exception.Message
            }
        }
    }
    else {
        Write-Host "  ⏭️  Skipped (WhatIf)" -ForegroundColor Yellow
        return [PSCustomObject]@{
            File     = $fileName
            Name     = $json.name
            PolicyId = $null
            Status   = 'Skipped'
            Error    = $null
        }
    }
}

# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
Write-Banner

# Validate policy folder
if (-not (Test-Path $PolicyFolder)) {
    Write-Host "❌ Policy folder not found: $PolicyFolder" -ForegroundColor Red
    exit 1
}

# Build ordered file list — use defined order, then pick up any extras
$allJsonFiles = Get-ChildItem -Path $PolicyFolder -Filter '*.json' | Select-Object -ExpandProperty Name
$orderedFiles = @()

foreach ($name in $importOrder) {
    if ($name -in $allJsonFiles) {
        $orderedFiles += $name
    }
}

# Add any files not in the predefined order
foreach ($name in $allJsonFiles) {
    if ($name -notin $orderedFiles) {
        $orderedFiles += $name
    }
}

$totalPolicies = $orderedFiles.Count

Write-Host "📁 Policy folder: $PolicyFolder" -ForegroundColor White
Write-Host "📋 Policies found: $totalPolicies" -ForegroundColor White
Write-Host "🏢 Target tenant:  $TenantId" -ForegroundColor White
Write-Host ''

if ($totalPolicies -eq 0) {
    Write-Host '❌ No JSON policy files found in the folder.' -ForegroundColor Red
    exit 1
}

# Show import plan
Write-Host '📋 Import Order:' -ForegroundColor Yellow
for ($i = 0; $i -lt $orderedFiles.Count; $i++) {
    $filePath = Join-Path $PolicyFolder $orderedFiles[$i]
    $policyJson = Get-Content $filePath -Raw | ConvertFrom-Json
    Write-Host "   $($i + 1). $($policyJson.name)" -ForegroundColor DarkGray
}
Write-Host ''

# Confirm
if (-not $WhatIfPreference) {
    $confirm = Read-Host "Proceed with importing $totalPolicies policies into tenant $TenantId? (Y/N)"
    if ($confirm -notin @('Y', 'y', 'Yes', 'yes')) {
        Write-Host '🚫 Import cancelled.' -ForegroundColor Yellow
        exit 0
    }
}

# Connect to Graph
Connect-ToGraph -Tenant $TenantId -Scopes $requiredScopes

# Import each policy
$results = @()
for ($i = 0; $i -lt $orderedFiles.Count; $i++) {
    $filePath = Join-Path $PolicyFolder $orderedFiles[$i]
    $result = Import-SinglePolicy -FilePath $filePath -Index ($i + 1) -Total $totalPolicies
    $results += $result
}

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║                    Import Summary                        ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

$succeeded = ($results | Where-Object Status -eq 'Success').Count
$failed    = ($results | Where-Object Status -eq 'Failed').Count
$skipped   = ($results | Where-Object Status -eq 'Skipped').Count

$results | Format-Table -Property @(
    @{ Label = 'Status'; Expression = {
        switch ($_.Status) {
            'Success' { "✅ $($_.Status)" }
            'Failed'  { "❌ $($_.Status)" }
            'Skipped' { "⏭️  $($_.Status)" }
        }
    }},
    'Name',
    'PolicyId',
    'File'
) -AutoSize -Wrap

Write-Host "  ✅ Succeeded: $succeeded" -ForegroundColor Green
if ($failed -gt 0) { Write-Host "  ❌ Failed:    $failed" -ForegroundColor Red }
if ($skipped -gt 0) { Write-Host "  ⏭️  Skipped:   $skipped" -ForegroundColor Yellow }
Write-Host "  📋 Total:     $totalPolicies" -ForegroundColor White
Write-Host ''

# Export results to CSV
$csvPath = Join-Path $PolicyFolder "ImportResults_$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation
Write-Host "📄 Results exported to: $csvPath" -ForegroundColor DarkGray
Write-Host ''

if ($failed -gt 0) {
    Write-Host '⚠️  Some policies failed to import. Check the errors above and retry.' -ForegroundColor Yellow
    Write-Host '   Common fixes:' -ForegroundColor DarkGray
    Write-Host '   • Ensure DeviceManagementConfiguration.ReadWrite.All scope is granted' -ForegroundColor DarkGray
    Write-Host '   • Check the tenant has the required Defender for Endpoint licences' -ForegroundColor DarkGray
    Write-Host '   • Verify the template IDs are supported in the target tenant' -ForegroundColor DarkGray
}
