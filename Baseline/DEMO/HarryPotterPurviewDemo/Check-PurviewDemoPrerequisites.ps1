# ═══════════════════════════════════════════════════════════════════════
# Check Purview Demo Prerequisites
# ═══════════════════════════════════════════════════════════════════════
# Run this BEFORE the demo to verify everything is in place.
# Checks all 7 prerequisites from the Purview Demo Walkthrough.
#
# Requires: Microsoft.Graph.Authentication module
# ═══════════════════════════════════════════════════════════════════════

param(
    [string]$TenantId
)

$ErrorActionPreference = 'Continue'

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🛡️  PURVIEW DEMO — PREREQUISITES CHECK                ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Connect to Graph ────────────────────────────────────────────────────
$graphScopes = @(
    'Directory.Read.All',
    'SharePointTenantSettings.ReadWrite.All',
    'Group.Read.All',
    'User.Read.All',
    'GroupMember.Read.All',
    'Domain.Read.All',
    'Sites.Read.All',
    'Files.Read.All'
)

$connectParams = @{ Scopes = $graphScopes; NoWelcome = $true }
if ($TenantId) { $connectParams['TenantId'] = $TenantId }

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Gray
Connect-MgGraph @connectParams

$ctx = Get-MgContext
$tenantDomain = (Get-MgDomain -All | Where-Object { $_.Id -like '*.onmicrosoft.com' -and $_.Id -notlike '*.mail.onmicrosoft.com' }).Id

Write-Host "   Tenant:  $tenantDomain ($($ctx.TenantId))" -ForegroundColor DarkGray
Write-Host "   Account: $($ctx.Account)" -ForegroundColor DarkGray
Write-Host ""

$results = @()
$passCount = 0
$failCount = 0
$warnCount = 0

function Add-Result {
    param([string]$Check, [string]$Status, [string]$Detail)
    $script:results += [PSCustomObject]@{ Check = $Check; Status = $Status; Detail = $Detail }
    switch ($Status) {
        '✅ PASS' { $script:passCount++ }
        '❌ FAIL' { $script:failCount++ }
        '⚠️ WARN' { $script:warnCount++ }
    }
}

# ═══════════════════════════════════════════════════════════════════════
# CHECK 1: EnableMIPLabels in Group.Unified directory settings
# ═══════════════════════════════════════════════════════════════════════
Write-Host "[1/7] Checking EnableMIPLabels (Group.Unified)..." -ForegroundColor Yellow
try {
    $groupSettings = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/groupSettings'
    $mipEntry = $groupSettings.value | ForEach-Object { $_.values } | Where-Object { $_.name -eq 'EnableMIPLabels' }

    if ($mipEntry.value -eq 'True') {
        Write-Host "   ✅ EnableMIPLabels = True" -ForegroundColor Green
        Add-Result -Check 'EnableMIPLabels' -Status '✅ PASS' -Detail 'Group.Unified setting is True'
    } else {
        Write-Host "   ❌ EnableMIPLabels = $($mipEntry.value)" -ForegroundColor Red
        Add-Result -Check 'EnableMIPLabels' -Status '❌ FAIL' -Detail "Value is '$($mipEntry.value)' — run Enable-SensitivityLabelsPrerequisites.ps1"
    }
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Add-Result -Check 'EnableMIPLabels' -Status '❌ FAIL' -Detail "Error reading group settings: $($_.Exception.Message)"
}

# ═══════════════════════════════════════════════════════════════════════
# CHECK 2: isSensitivityLabelsEnabled in SharePoint tenant settings
# ═══════════════════════════════════════════════════════════════════════
Write-Host "[2/7] Checking isSensitivityLabelsEnabled (SharePoint)..." -ForegroundColor Yellow
try {
    $spSettings = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/admin/sharepoint/settings'

    if ($spSettings.isSensitivityLabelsEnabled -eq $true) {
        Write-Host "   ✅ isSensitivityLabelsEnabled = True" -ForegroundColor Green
        Add-Result -Check 'SharePoint Sensitivity Labels' -Status '✅ PASS' -Detail 'isSensitivityLabelsEnabled is True'
    } elseif ($null -eq $spSettings.isSensitivityLabelsEnabled -or $spSettings.isSensitivityLabelsEnabled -eq '') {
        Write-Host "   ⚠️  isSensitivityLabelsEnabled = (null/empty)" -ForegroundColor Yellow
        Write-Host "      This usually means the setting was recently enabled and is still propagating." -ForegroundColor DarkGray
        Write-Host "      Try again in a few hours, or verify via SPO PowerShell:" -ForegroundColor DarkGray
        Write-Host "        Connect-SPOService -Url 'https://<tenant>-admin.sharepoint.com'" -ForegroundColor DarkGray
        Write-Host "        Get-SPOTenant | Select-Object EnableAIPIntegration" -ForegroundColor DarkGray
        Add-Result -Check 'SharePoint Sensitivity Labels' -Status '⚠️ WARN' -Detail 'Value is null — likely propagating after recent enable. Re-check in a few hours.'
    } else {
        Write-Host "   ❌ isSensitivityLabelsEnabled = False" -ForegroundColor Red
        Add-Result -Check 'SharePoint Sensitivity Labels' -Status '❌ FAIL' -Detail 'Run Enable-SharePointSensitivityLabels.ps1 or Enable-SensitivityLabelsPrerequisites.ps1'
    }
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Add-Result -Check 'SharePoint Sensitivity Labels' -Status '❌ FAIL' -Detail "Error reading SP settings: $($_.Exception.Message)"
}

# ═══════════════════════════════════════════════════════════════════════
# CHECK 3: Harry Potter users exist (spot-check key characters)
# ═══════════════════════════════════════════════════════════════════════
Write-Host "[3/7] Checking key Harry Potter users..." -ForegroundColor Yellow
$usersOK = $true
$userChecks = @(
    @{ Name = 'Harry Potter';      UPN = "harry.potter@$tenantDomain" },
    @{ Name = 'Hermione Granger';  UPN = "hermione.granger@$tenantDomain" },
    @{ Name = 'Dolores Umbridge';  UPN = "dolores.umbridge@$tenantDomain" }
)
foreach ($uc in $userChecks) {
    try {
        $u = Get-MgUser -Filter "userPrincipalName eq '$($uc.UPN)'" -Property DisplayName,UserPrincipalName,OfficeLocation,JobTitle,AccountEnabled
        if ($u) {
            $enabledTag = if ($u.AccountEnabled) { "enabled" } else { "DISABLED" }
            Write-Host "   ✅ $($u.DisplayName) | $($u.OfficeLocation) | $($u.JobTitle) | $enabledTag" -ForegroundColor Green
        } else {
            Write-Host "   ❌ NOT FOUND: $($uc.UPN)" -ForegroundColor Red
            $usersOK = $false
        }
    } catch {
        Write-Host "   ❌ Error checking $($uc.Name): $($_.Exception.Message)" -ForegroundColor Red
        $usersOK = $false
    }
}
if ($usersOK) {
    Add-Result -Check 'Key Users Exist' -Status '✅ PASS' -Detail 'Harry, Hermione, and Dolores all present'
} else {
    Add-Result -Check 'Key Users Exist' -Status '❌ FAIL' -Detail 'One or more key users missing — run Create-HarryPotterUsers.ps1'
}

# ═══════════════════════════════════════════════════════════════════════
# CHECK 4: Gryffindor dynamic group exists and has members
# ═══════════════════════════════════════════════════════════════════════
Write-Host "[4/7] Checking Gryffindor dynamic group..." -ForegroundColor Yellow
try {
    $gryGroups = Get-MgGroup -Search '"displayName:Gryffindor"' -ConsistencyLevel eventual -All
    $gryf = $gryGroups | Where-Object { $_.DisplayName -like '*Gryffindor*' } | Select-Object -First 1

    if ($gryf) {
        $members = Get-MgGroupMember -GroupId $gryf.Id -All
        Write-Host "   ✅ $($gryf.DisplayName) — $($members.Count) members" -ForegroundColor Green
        foreach ($m in $members) {
            $mu = Get-MgUser -UserId $m.Id -Property DisplayName,UserPrincipalName -ErrorAction SilentlyContinue
            if ($mu) { Write-Host "      • $($mu.DisplayName) ($($mu.UserPrincipalName))" -ForegroundColor DarkGray }
        }
        if ($members.Count -ge 6) {
            Add-Result -Check 'Gryffindor Dynamic Group' -Status '✅ PASS' -Detail "$($members.Count) members in $($gryf.DisplayName)"
        } else {
            Add-Result -Check 'Gryffindor Dynamic Group' -Status '⚠️ WARN' -Detail "Only $($members.Count) members — expected 6. Dynamic membership may still be processing."
        }
    } else {
        Write-Host "   ❌ Gryffindor dynamic group NOT FOUND" -ForegroundColor Red
        Add-Result -Check 'Gryffindor Dynamic Group' -Status '❌ FAIL' -Detail 'Group not found — run Create-HarryPotterUsers.ps1 (creates house groups)'
    }
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Add-Result -Check 'Gryffindor Dynamic Group' -Status '❌ FAIL' -Detail "Error: $($_.Exception.Message)"
}

# ═══════════════════════════════════════════════════════════════════════
# CHECK 5: Order of the Phoenix SharePoint site exists
# ═══════════════════════════════════════════════════════════════════════
Write-Host "[5/7] Checking Order of the Phoenix site..." -ForegroundColor Yellow
try {
    $ootpGroups = Get-MgGroup -Search '"displayName:Order of the Phoenix"' -ConsistencyLevel eventual -All
    $ootp = $ootpGroups | Where-Object { $_.DisplayName -eq 'Order of the Phoenix' } | Select-Object -First 1

    if ($ootp) {
        Write-Host "   ✅ Group: $($ootp.DisplayName) ($($ootp.Id))" -ForegroundColor Green

        # Check for assigned labels
        $ootpFull = Get-MgGroup -GroupId $ootp.Id -Property AssignedLabels,Visibility
        if ($ootpFull.AssignedLabels -and $ootpFull.AssignedLabels.Count -gt 0) {
            $labelNames = ($ootpFull.AssignedLabels | ForEach-Object { $_.DisplayName }) -join ', '
            Write-Host "   ⚠️  Site has label(s): $labelNames" -ForegroundColor Yellow
            Write-Host "      Remove before demo if you want Act 1 (oversharing) to work" -ForegroundColor Yellow
        } else {
            Write-Host "   ✅ No sensitivity label on site (ready for demo)" -ForegroundColor Green
        }

        # Check files
        try {
            $driveItems = Invoke-MgGraphRequest -Method GET "https://graph.microsoft.com/v1.0/groups/$($ootp.Id)/drive/root/children"
            $fileCount = $driveItems.value.Count
            Write-Host "   📄 Documents: $fileCount" -ForegroundColor DarkGray
            foreach ($f in $driveItems.value) { Write-Host "      • $($f.name)" -ForegroundColor DarkGray }
        } catch {
            Write-Host "   ⚠️  Could not read drive (site may still be provisioning)" -ForegroundColor Yellow
        }

        Add-Result -Check 'Order of the Phoenix Site' -Status '✅ PASS' -Detail "Group exists: $($ootp.Id)"
    } else {
        Write-Host "   ❌ Order of the Phoenix NOT FOUND" -ForegroundColor Red
        Add-Result -Check 'Order of the Phoenix Site' -Status '❌ FAIL' -Detail 'Run Create-HarryPotterSharePointDemo.ps1 to create this site'
    }
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Add-Result -Check 'Order of the Phoenix Site' -Status '❌ FAIL' -Detail "Error: $($_.Exception.Message)"
}

# ═══════════════════════════════════════════════════════════════════════
# CHECK 6: Dumbledores Army HQ SharePoint site exists
# ═══════════════════════════════════════════════════════════════════════
Write-Host "[6/7] Checking Dumbledores Army HQ site..." -ForegroundColor Yellow
try {
    $daGroup = Get-MgGroup -Filter "mailNickname eq 'DumbledoresArmy'" -ErrorAction SilentlyContinue

    if ($daGroup) {
        Write-Host "   ✅ Group: $($daGroup.DisplayName) ($($daGroup.Id))" -ForegroundColor Green

        # Check for assigned labels
        $daFull = Get-MgGroup -GroupId $daGroup.Id -Property AssignedLabels,Visibility
        if ($daFull.AssignedLabels -and $daFull.AssignedLabels.Count -gt 0) {
            $labelNames = ($daFull.AssignedLabels | ForEach-Object { $_.DisplayName }) -join ', '
            Write-Host "   ⚠️  Site has label(s): $labelNames" -ForegroundColor Yellow
        } else {
            Write-Host "   ✅ No sensitivity label on site" -ForegroundColor Green
        }

        # Check files
        try {
            $driveItems = Invoke-MgGraphRequest -Method GET "https://graph.microsoft.com/v1.0/groups/$($daGroup.Id)/drive/root/children"
            $fileCount = $driveItems.value.Count
            Write-Host "   📄 Documents: $fileCount" -ForegroundColor DarkGray
            foreach ($f in $driveItems.value) { Write-Host "      • $($f.name)" -ForegroundColor DarkGray }
        } catch {
            Write-Host "   ⚠️  Could not read drive" -ForegroundColor Yellow
        }

        Add-Result -Check 'Dumbledores Army HQ Site' -Status '✅ PASS' -Detail "Group exists: $($daGroup.Id) with $fileCount documents"
    } else {
        Write-Host "   ❌ Dumbledores Army HQ NOT FOUND" -ForegroundColor Red
        Add-Result -Check 'Dumbledores Army HQ Site' -Status '❌ FAIL' -Detail 'Run Create-HarryPotterDemoEnvironment.ps1 to create this site'
    }
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Add-Result -Check 'Dumbledores Army HQ Site' -Status '❌ FAIL' -Detail "Error: $($_.Exception.Message)"
}

# ═══════════════════════════════════════════════════════════════════════
# CHECK 7: Copilot licences (check for M365 Copilot SKU assignment)
# ═══════════════════════════════════════════════════════════════════════
Write-Host "[7/7] Checking Copilot licence assignments..." -ForegroundColor Yellow
try {
    # Look for Microsoft 365 Copilot service plan on Dolores and Harry
    $copilotUsers = @(
        @{ Name = 'Dolores Umbridge'; UPN = "dolores.umbridge@$tenantDomain" },
        @{ Name = 'Harry Potter';     UPN = "harry.potter@$tenantDomain" }
    )
    $copilotOK = $true
    foreach ($cu in $copilotUsers) {
        try {
            $licences = Get-MgUserLicenseDetail -UserId $cu.UPN -ErrorAction Stop
            $hasCopilot = $licences | Where-Object {
                $_.ServicePlans | Where-Object {
                    $_.ServicePlanName -like '*COPILOT*' -or
                    $_.ServicePlanName -like '*M365_COPILOT*' -or
                    $_.ServicePlanName -like '*MICROSOFT_365_COPILOT*'
                }
            }
            if ($hasCopilot) {
                Write-Host "   ✅ $($cu.Name) — Copilot licence assigned" -ForegroundColor Green
            } else {
                $skuNames = ($licences | ForEach-Object { $_.SkuPartNumber }) -join ', '
                Write-Host "   ⚠️  $($cu.Name) — No Copilot licence found (has: $skuNames)" -ForegroundColor Yellow
                $copilotOK = $false
            }
        } catch {
            Write-Host "   ⚠️  $($cu.Name) — Could not check: $($_.Exception.Message)" -ForegroundColor Yellow
            $copilotOK = $false
        }
    }
    if ($copilotOK) {
        Add-Result -Check 'Copilot Licences' -Status '✅ PASS' -Detail 'Copilot assigned to both Harry and Dolores'
    } else {
        Add-Result -Check 'Copilot Licences' -Status '⚠️ WARN' -Detail 'Copilot licence missing on one or more demo users — assign in M365 Admin Centre'
    }
} catch {
    Write-Host "   ⚠️  Error checking licences: $($_.Exception.Message)" -ForegroundColor Yellow
    Add-Result -Check 'Copilot Licences' -Status '⚠️ WARN' -Detail "Error: $($_.Exception.Message)"
}

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║               📊 PREREQUISITES SUMMARY                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$results | Format-Table -Property @(
    @{ Label = 'Status'; Expression = { $_.Status }; Width = 10 },
    @{ Label = 'Check'; Expression = { $_.Check }; Width = 30 },
    @{ Label = 'Detail'; Expression = { $_.Detail } }
) -Wrap

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  ✅ Passed: $passCount   ❌ Failed: $failCount   ⚠️  Warnings: $warnCount" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

if ($failCount -eq 0 -and $warnCount -eq 0) {
    Write-Host ""
    Write-Host "  🎬 All clear — you're ready to run the demo!" -ForegroundColor Green
} elseif ($failCount -eq 0) {
    Write-Host ""
    Write-Host "  🎬 Demo can proceed but review warnings above." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "  🚫 Fix the failed checks before running the demo." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Quick fix scripts:" -ForegroundColor White
    Write-Host "    • Enable-SensitivityLabelsPrerequisites.ps1  (checks 1 & 2)" -ForegroundColor DarkGray
    Write-Host "    • Create-HarryPotterUsers.ps1                (checks 3 & 4)" -ForegroundColor DarkGray
    Write-Host "    • Create-HarryPotterSharePointDemo.ps1       (check 5)" -ForegroundColor DarkGray
    Write-Host "    • Create-HarryPotterDemoEnvironment.ps1      (check 6)" -ForegroundColor DarkGray
}

Write-Host ""

# Cleanup
try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
