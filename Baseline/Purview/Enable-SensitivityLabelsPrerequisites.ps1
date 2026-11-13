# ═══════════════════════════════════════════════════════════════════════
# Enable Sensitivity Labels Prerequisites - Master Script
# ═══════════════════════════════════════════════════════════════════════
# This script enables all prerequisites needed before sensitivity labels
# can be applied to Teams, SharePoint sites, and Microsoft 365 Groups.
#
# Prerequisites it configures:
#   1. EnableMIPLabels = True  (Group.Unified directory settings via Graph)
#   2. EnableAIPIntegration = True  (SharePoint tenant setting: sensitivity
#      labels for Office files in SharePoint and OneDrive)
#   3. EnableSensitivityLabelForPDF / ForOneNote / ForVideoFiles
#      (SharePoint tenant settings for PDF, OneNote and MP4 video)
#   4. Execute-AzureADLabelSync  (Syncs Purview labels to Entra ID via IPPS)
#
# After running: allow up to 24 hours for full propagation.
# Then the "Groups & sites" checkbox in the label editor will be available.
#
# Steps 2 and 3 are SharePoint tenant settings. Microsoft Graph does not expose
# them, so the script connects to the SharePoint admin center:
#   - Windows: Microsoft.Online.SharePoint.PowerShell (Connect-SPOService).
#   - macOS / Linux: that module does not run, so pass -PnPClientId (an Entra
#     app registered for PnP.PowerShell interactive sign-in). Set-PnPTenant has
#     no parameter for the OneNote and video settings, so the script reads and
#     sets those over the same admin CSOM endpoint that Set-SPOTenant uses.
#
# Author: Inforcer Baseline
# ═══════════════════════════════════════════════════════════════════════

#Requires -Modules Microsoft.Graph.Authentication, ExchangeOnlineManagement

param(
    [Parameter(HelpMessage = "Tenant ID to connect to. If omitted, uses interactive tenant selection.")]
    [string]$TenantId,

    [Parameter(HelpMessage = "SharePoint admin center URL, e.g. https://contoso-admin.sharepoint.com. Derived from the tenant's onmicrosoft.com domain if omitted.")]
    [string]$SharePointAdminUrl,

    [Parameter(HelpMessage = "Client ID of an Entra app registered for PnP.PowerShell interactive sign-in. Used on macOS and Linux only; Windows uses the SharePoint Online Management Shell and ignores it. Prompted for if omitted.")]
    [string]$PnPClientId,

    [Parameter(HelpMessage = "Skip the PDF, OneNote and MP4 video sensitivity label settings (step 3).")]
    [switch]$SkipFileTypeLabels
)

$ErrorActionPreference = 'Stop'

# SharePoint tenant settings that control labeling for file types beyond Office files
$fileTypeSettings = @(
    @{ Name = 'EnableSensitivityLabelForPDF';        Display = 'PDF files' }
    @{ Name = 'EnableSensitivityLabelForOneNote';    Display = 'OneNote sections' }
    @{ Name = 'EnableSensitivityLabelForVideoFiles'; Display = 'MP4 video files and Clipchamp projects' }
)
$fileTypeResults = [ordered]@{}
$aipResult = 'Not checked'
$spoMethod = $null
$spoConnectAttempted = $false
$tenantObjectTypeId = '{268004ae-ef6b-4e9b-8425-127220d84719}'

function Invoke-SpoCsom {
    param([string]$Actions)

    $xml = '<Request AddExpandoFieldTypeSuffix="true" SchemaVersion="15.0.0.0" LibraryVersion="16.0.0.0" ApplicationName=".NET Runtime" xmlns="http://schemas.microsoft.com/sharepoint/clientquery/2009"><Actions>' + $Actions + '</Actions><ObjectPaths><Constructor Id="1" TypeId="' + $tenantObjectTypeId + '" /></ObjectPaths></Request>'
    $raw = Invoke-PnPSPRestMethod -Method Post -Url '/_vti_bin/client.svc/ProcessQuery' -Content $xml -ContentType 'text/xml' -Raw
    $response = $raw | ConvertFrom-Json
    $header = $response | Where-Object { $_ -is [pscustomobject] -and $_.PSObject.Properties.Name -contains 'ErrorInfo' } | Select-Object -First 1
    if ($header.ErrorInfo) { throw $header.ErrorInfo.ErrorMessage }
    return $response
}

function Connect-SharePointAdmin {
    # Connects once and returns 'SPO', 'PnP' or $null
    if ($script:spoConnectAttempted) { return $script:spoMethod }
    $script:spoConnectAttempted = $true

    $initialDomain = $tenantDomain | Select-Object -First 1
    $adminUrl = if ($SharePointAdminUrl) { $SharePointAdminUrl } else { "https://$($initialDomain -replace '\.onmicrosoft\.com$', '')-admin.sharepoint.com" }
    $onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows

    if ($onWindows) {
        # Windows: SharePoint Online Management Shell only
        if (-not (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)) {
            Write-Host "  ⚠️  Could not connect to the SharePoint admin center ($adminUrl). These settings are not checked." -ForegroundColor Yellow
            Write-Host "     The SharePoint Online Management Shell is not installed. Run: Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser" -ForegroundColor Yellow
            return $null
        }
        try {
            Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking -ErrorAction Stop
            Connect-SPOService -Url $adminUrl -ErrorAction Stop
            $script:spoMethod = 'SPO'
        }
        catch {
            Write-Host "  ⚠️  Could not connect to the SharePoint admin center ($adminUrl). These settings are not checked." -ForegroundColor Yellow
            Write-Host "     SharePoint Online Management Shell sign-in failed: $($_.Exception.Message)" -ForegroundColor Yellow
            return $null
        }
    }
    else {
        # macOS and Linux: PnP.PowerShell only, because the SharePoint Online Management Shell does not run here
        if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
            Write-Host "  ⚠️  Could not connect to the SharePoint admin center ($adminUrl). These settings are not checked." -ForegroundColor Yellow
            Write-Host "     PnP.PowerShell is not installed for this PowerShell. Run: Install-Module PnP.PowerShell -Scope CurrentUser" -ForegroundColor Yellow
            return $null
        }
        $clientId = $PnPClientId
        if (-not $clientId -and [Environment]::UserInteractive) {
            $clientId = Read-Host "  PnP app (client) ID for the SharePoint sign-in (press Enter to skip)"
        }
        if (-not $clientId) {
            Write-Host "  ⚠️  Could not connect to the SharePoint admin center ($adminUrl). These settings are not checked." -ForegroundColor Yellow
            Write-Host "     -PnPClientId was not provided. On macOS and Linux the script needs it to sign in with PnP.PowerShell." -ForegroundColor Yellow
            return $null
        }
        try {
            Import-Module PnP.PowerShell -ErrorAction Stop
            Connect-PnPOnline -Url $adminUrl -Interactive -ClientId $clientId -Tenant $initialDomain -ErrorAction Stop
            $script:spoMethod = 'PnP'
        }
        catch {
            Write-Host "  ⚠️  Could not connect to the SharePoint admin center ($adminUrl). These settings are not checked." -ForegroundColor Yellow
            Write-Host "     PnP.PowerShell sign-in failed: $($_.Exception.Message)" -ForegroundColor Yellow
            return $null
        }
    }

    Write-Host "  Connected to $adminUrl using $($script:spoMethod)" -ForegroundColor Gray
    return $script:spoMethod
}

function Get-SpoLabelSettingValues {
    param([ValidateSet('SPO', 'PnP')][string]$Method)

    $names = @('EnableAIPIntegration') + $fileTypeSettings.Name
    $values = [ordered]@{}

    if ($Method -eq 'SPO') {
        $tenant = Get-SPOTenant
        foreach ($n in $names) { $values[$n] = $tenant.$n }
        return $values
    }

    # Get-PnPTenant does not expose the OneNote and video properties, so read the
    # admin tenant object over CSOM, which returns every property the service knows.
    $response = Invoke-SpoCsom -Actions '<ObjectPath Id="2" ObjectPathId="1" /><Query Id="3" ObjectPathId="1"><Query SelectAllProperties="true"><Properties /></Query></Query>'
    $tenant = $response | Where-Object { $_ -is [pscustomobject] -and $_.PSObject.Properties.Name -contains 'EnableAIPIntegration' } | Select-Object -First 1
    if (-not $tenant) { throw 'The SharePoint admin tenant object was not returned.' }
    foreach ($n in $names) { $values[$n] = $tenant.$n }
    return $values
}

function Set-SpoLabelSetting {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('EnableAIPIntegration', 'EnableSensitivityLabelForPDF', 'EnableSensitivityLabelForOneNote', 'EnableSensitivityLabelForVideoFiles')]
        [string]$Name,
        [ValidateSet('SPO', 'PnP')][string]$Method
    )

    $setting = @{ $Name = $true }
    if ($Method -eq 'SPO') { Set-SPOTenant @setting; return }
    if ((Get-Command Set-PnPTenant).Parameters.ContainsKey($Name)) { Set-PnPTenant @setting; return }

    # Set-PnPTenant has no parameter for this setting, so set the property over CSOM
    Invoke-SpoCsom -Actions ('<SetProperty Id="2" ObjectPathId="1" Name="' + $Name + '"><Parameter Type="Boolean">true</Parameter></SetProperty>') | Out-Null
}

function Write-SettingStatus {
    param([string]$Name, [string]$State)

    $mark = switch ($State) { 'True' { '✅' } 'False' { '❌' } default { '⚠️ ' } }
    $color = switch ($State) { 'True' { 'Green' } 'False' { 'Red' } default { 'Yellow' } }
    Write-Host ("  {0,-36} {1} {2}" -f "${Name}:", $State, $mark) -ForegroundColor $color
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Sensitivity Labels Prerequisites - Master Setup Script" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ── Step 0: Connect to Microsoft Graph ──────────────────────────────────
Write-Host "[0/4] Connecting to Microsoft Graph..." -ForegroundColor Yellow

$graphScopes = @(
    'Directory.ReadWrite.All',
    'Domain.Read.All'
)

$connectParams = @{
    Scopes    = $graphScopes
    NoWelcome = $true
}
if ($TenantId) { $connectParams['TenantId'] = $TenantId }

Connect-MgGraph @connectParams

$ctx = Get-MgContext
$domainResponse = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/domains'
$tenantDomain = ($domainResponse.value | Where-Object { $_.id -like '*.onmicrosoft.com' -and $_.id -notlike '*.mail.onmicrosoft.com' }).id

Write-Host "  Connected as: $($ctx.Account)" -ForegroundColor Green
Write-Host "  Tenant ID:    $($ctx.TenantId)" -ForegroundColor Green
Write-Host "  Domain:       $tenantDomain" -ForegroundColor Green
Write-Host ""

# ── Step 1: Enable MIP Labels in Group.Unified directory settings ───────
Write-Host "[1/4] Enabling MIP Labels in Group.Unified directory settings..." -ForegroundColor Yellow

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
# Graph's sharepointSettings resource has no sensitivity label property, so this
# uses the EnableAIPIntegration tenant setting through the SharePoint admin center.
Write-Host "[2/4] Enabling sensitivity labels in SharePoint Online (EnableAIPIntegration)..." -ForegroundColor Yellow

try {
    $spoMethod = Connect-SharePointAdmin
    if ($spoMethod) {
        $current = Get-SpoLabelSettingValues -Method $spoMethod
        if ($current['EnableAIPIntegration'] -eq $true) {
            Write-Host "  ✅ EnableAIPIntegration already True" -ForegroundColor Green
        }
        else {
            Set-SpoLabelSetting -Name EnableAIPIntegration -Method $spoMethod
        }
        $aipResult = if ((Get-SpoLabelSettingValues -Method $spoMethod)['EnableAIPIntegration'] -eq $true) { 'True' } else { 'False' }
        if ($aipResult -eq 'True') {
            if ($current['EnableAIPIntegration'] -ne $true) { Write-Host "  ✅ EnableAIPIntegration set to True" -ForegroundColor Green }
        }
        else {
            Write-Host "  ⚠️  EnableAIPIntegration was set but still reads False. Check again in a few minutes." -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "  ❌ Failed to read or update EnableAIPIntegration: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ── Step 3: Sensitivity labels for PDF, OneNote and MP4 video ─────────
Write-Host "[3/4] Sensitivity label support for PDF, OneNote and MP4 video..." -ForegroundColor Yellow

if ($SkipFileTypeLabels) {
    Write-Host "  Skipped (-SkipFileTypeLabels)." -ForegroundColor Gray
    foreach ($s in $fileTypeSettings) { $fileTypeResults[$s.Name] = 'Not checked' }
}
else {
    try {
        $spoMethod = Connect-SharePointAdmin
        if (-not $spoMethod) {
            Write-Host "  Skipped: no SharePoint admin connection (see step 2)." -ForegroundColor Yellow
            foreach ($s in $fileTypeSettings) { $fileTypeResults[$s.Name] = 'Not checked' }
        }
        else {
            $current = Get-SpoLabelSettingValues -Method $spoMethod

            foreach ($s in $fileTypeSettings) {
                if ($current[$s.Name] -eq $true) {
                    Write-Host "  ✅ $($s.Name) already True ($($s.Display))" -ForegroundColor Green
                    $fileTypeResults[$s.Name] = 'True'
                    continue
                }

                try {
                    Set-SpoLabelSetting -Name $s.Name -Method $spoMethod
                    $fileTypeResults[$s.Name] = if ((Get-SpoLabelSettingValues -Method $spoMethod)[$s.Name] -eq $true) { 'True' } else { 'False' }
                    if ($fileTypeResults[$s.Name] -eq 'True') {
                        Write-Host "  ✅ $($s.Name) set to True ($($s.Display))" -ForegroundColor Green
                    }
                    else {
                        Write-Host "  ⚠️  $($s.Name) was set but still reads False. Check again in a few minutes." -ForegroundColor Yellow
                    }
                }
                catch {
                    $fileTypeResults[$s.Name] = 'False'
                    Write-Host "  ❌ Could not set $($s.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "  ❌ Failed to read the file type settings: $($_.Exception.Message)" -ForegroundColor Red
        foreach ($s in $fileTypeSettings) { if (-not $fileTypeResults.Contains($s.Name)) { $fileTypeResults[$s.Name] = 'Not checked' } }
    }
}
Write-Host ""

# ── Step 4: Sync labels from Purview to Entra ID ──────────────────────
Write-Host "[4/4] Syncing sensitivity labels to Entra ID (Execute-AzureADLabelSync)..." -ForegroundColor Yellow
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

# Verify SharePoint settings (steps 2 and 3)
Write-SettingStatus -Name 'EnableAIPIntegration' -State $aipResult
foreach ($s in $fileTypeSettings) {
    Write-SettingStatus -Name $s.Name -State $fileTypeResults[$s.Name]
}

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
if ($spoMethod -eq 'SPO') { try { Disconnect-SPOService -ErrorAction SilentlyContinue } catch {} }
if ($spoMethod -eq 'PnP') { try { Disconnect-PnPOnline -ErrorAction SilentlyContinue } catch {} }
Write-Host "Disconnected." -ForegroundColor Gray
