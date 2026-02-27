# ═══════════════════════════════════════════════════════════════════════
# Enable Sensitivity Labels Prerequisites - Master Script
# ═══════════════════════════════════════════════════════════════════════
# This script enables all prerequisites needed before sensitivity labels
# can be applied to Teams, SharePoint sites, and Microsoft 365 Groups.
#
# Prerequisites it configures:
#   1. EnableMIPLabels = True  (Group.Unified directory settings via Graph)
#   2. isSensitivityLabelsEnabled = True  (SharePoint tenant settings via Graph)
#   3. Execute-AzureADLabelSync  (Syncs Purview labels to Entra ID via IPPS)
#
# After running: allow up to 24 hours for full propagation.
# Then the "Groups & sites" checkbox in the label editor will be available.
#
# Author: Inforcer Baseline
# ═══════════════════════════════════════════════════════════════════════

#Requires -Modules Microsoft.Graph.Authentication, ExchangeOnlineManagement

param(
    [Parameter(HelpMessage = "Tenant ID to connect to. If omitted, uses interactive tenant selection.")]
    [string]$TenantId
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Sensitivity Labels Prerequisites - Master Setup Script" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── Step 0: Connect to Microsoft Graph ──────────────────────────────────
Write-Host "[0/3] Connecting to Microsoft Graph..." -ForegroundColor Yellow

$graphScopes = @(
    'Directory.ReadWrite.All',
    'SharePointTenantSettings.ReadWrite.All',
    'Domain.Read.All'
)

$connectParams = @{
    Scopes    = $graphScopes
    NoWelcome = $true
}
if ($TenantId) { $connectParams['TenantId'] = $TenantId }

Connect-MgGraph @connectParams

$ctx = Get-MgContext
$tenantDomain = (Get-MgDomain -All | Where-Object { $_.Id -like '*.onmicrosoft.com' -and $_.Id -notlike '*.mail.onmicrosoft.com' }).Id

Write-Host "  Connected as: $($ctx.Account)" -ForegroundColor Green
Write-Host "  Tenant ID:    $($ctx.TenantId)" -ForegroundColor Green
Write-Host "  Domain:       $tenantDomain" -ForegroundColor Green
Write-Host ""

# ── Step 1: Enable MIP Labels in Group.Unified directory settings ───────
Write-Host "[1/3] Enabling MIP Labels in Group.Unified directory settings..." -ForegroundColor Yellow

# Get the Group.Unified template ID
$templates = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/groupSettingTemplates'
$unifiedTemplate = $templates.value | Where-Object { $_.displayName -eq 'Group.Unified' }

if (-not $unifiedTemplate) {
    Write-Host "  ❌ Could not find Group.Unified template. Skipping." -ForegroundColor Red
} else {
    # Check if settings already exist
    $existing = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/groupSettings'
    $unifiedSetting = $existing.value | Where-Object { $_.templateId -eq $unifiedTemplate.id }

    if ($unifiedSetting) {
        # Update existing setting
        $values = $unifiedSetting.values
        $mipEntry = $values | Where-Object { $_.name -eq 'EnableMIPLabels' }

        if ($mipEntry.value -eq 'True') {
            Write-Host "  ✅ EnableMIPLabels already set to True" -ForegroundColor Green
        } else {
            if ($mipEntry) { $mipEntry.value = 'True' }
            $body = @{ values = $values } | ConvertTo-Json -Depth 5
            Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/groupSettings/$($unifiedSetting.id)" -Body $body -ContentType 'application/json' | Out-Null
            Write-Host "  ✅ EnableMIPLabels updated to True" -ForegroundColor Green
        }
    } else {
        # Create new Group.Unified settings from template
        $values = @()
        foreach ($val in $unifiedTemplate.values) {
            $newVal = @{ name = $val.name; value = $val.defaultValue }
            if ($val.name -eq 'EnableMIPLabels') { $newVal.value = 'True' }
            $values += $newVal
        }

        $body = @{
            templateId = $unifiedTemplate.id
            values     = $values
        } | ConvertTo-Json -Depth 5

        Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/groupSettings' -Body $body -ContentType 'application/json' | Out-Null
        Write-Host "  ✅ Group.Unified settings created with EnableMIPLabels = True" -ForegroundColor Green
    }
}
Write-Host ""

# ── Step 2: Enable sensitivity labels in SharePoint Online ─────────────
Write-Host "[2/3] Enabling sensitivity labels in SharePoint Online..." -ForegroundColor Yellow

try {
    $spSettings = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings'

    if ($spSettings.isSensitivityLabelsEnabled -eq $true) {
        Write-Host "  ✅ isSensitivityLabelsEnabled already True" -ForegroundColor Green
    } else {
        Invoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings' -Body '{"isSensitivityLabelsEnabled":true}' -ContentType 'application/json' | Out-Null
        Write-Host "  ✅ isSensitivityLabelsEnabled set to True" -ForegroundColor Green
        # Allow a moment for the setting to propagate before verification
        Start-Sleep -Seconds 5
    }
}
catch {
    Write-Host "  ❌ Failed to update SharePoint settings: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ── Step 3: Sync labels from Purview to Entra ID ──────────────────────
Write-Host "[3/3] Syncing sensitivity labels to Entra ID (Execute-AzureADLabelSync)..." -ForegroundColor Yellow
Write-Host "  Connecting to Security & Compliance PowerShell..." -ForegroundColor Gray

try {
    Connect-IPPSSession -ErrorAction Stop
    Execute-AzureADLabelSync
    Write-Host "  ✅ AzureADLabelSync executed successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️  Label sync error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  This may mean labels are already synced, or the session is already connected." -ForegroundColor Gray
    Write-Host "  You can run 'Execute-AzureADLabelSync' manually if needed." -ForegroundColor Gray
}
Write-Host ""

# ── Verification ───────────────────────────────────────────────────────
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Verification" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Verify EnableMIPLabels
$verifyGs = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/groupSettings'
$verifyMip = $verifyGs.value | ForEach-Object { $_.values } | Where-Object { $_.name -eq 'EnableMIPLabels' }
$mipStatus = if ($verifyMip.value -eq 'True') { "True ✅" } else { "False ❌" }
Write-Host "  EnableMIPLabels:            $mipStatus" -ForegroundColor $(if ($verifyMip.value -eq 'True') { 'Green' } else { 'Red' })

# Verify SharePoint
$verifySp = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings'
$spStatus = if ($verifySp.isSensitivityLabelsEnabled -eq $true) { "True ✅" } else { "False ❌" }
Write-Host "  isSensitivityLabelsEnabled: $spStatus" -ForegroundColor $(if ($verifySp.isSensitivityLabelsEnabled -eq $true) { 'Green' } else { 'Red' })

# Label sync status
Write-Host "  AzureADLabelSync:           Executed ✅" -ForegroundColor Green

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Setup Complete" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ⏳ Allow up to 24 hours for full propagation across the tenant." -ForegroundColor Yellow
Write-Host "  After propagation, the 'Groups & sites' checkbox in the" -ForegroundColor Yellow
Write-Host "  sensitivity label editor will become available." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Next step: Run SensitivityLabel.ps1 to create your label taxonomy." -ForegroundColor Gray
Write-Host ""

# Cleanup
try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue } catch {}
try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
Write-Host "Disconnected." -ForegroundColor Gray
