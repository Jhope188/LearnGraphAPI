# Create Temporary Access Pass (TAP) for All Harry Potter Users
# ──────────────────────────────────────────────────────────────
# A TAP counts as a strong authentication method in Entra ID,
# so each user will appear as "MFA capable" in:
#   • Authentication Methods Registration Report
#   • Conditional Access MFA compliance
#   • Security defaults MFA status
#
# CONNECT FIRST, then run this script in the same PowerShell session:
#   Connect-MgGraph -TenantId 'e37d43b7-ff48-444b-9d44-fbd4477c18f3' -Scopes @(
#       'User.Read.All','UserAuthenticationMethod.ReadWrite.All'
#   ) -NoWelcome
#
# PREREQUISITE: TAP policy must be enabled in the tenant:
#   Entra ID → Protection → Authentication methods → Temporary Access Pass → Enable
#
# Author: Magical IT Department
# Date: March 5, 2026

param(
    [string]$TenantId = "e37d43b7-ff48-444b-9d44-fbd4477c18f3",
    [int]$TapLifetimeMinutes = 480,       # 8 hours (max depends on policy, up to 43200 = 30 days)
    [switch]$IsUsableOnce = $false,        # $false = reusable within lifetime
    [switch]$WhatIf
)

Write-Host ""
Write-Host "🔑 Temporary Access Pass (TAP) Creator — Harry Potter Users" -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# CHECK CONNECTION
# ═══════════════════════════════════════════════════════════════
Write-Host "🔗 Checking Microsoft Graph connection..." -ForegroundColor Yellow
$context = Get-MgContext

if (-not $context) {
    Write-Host ""
    Write-Host "❌ No active Graph session. Please connect first:" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Connect-MgGraph -TenantId '$TenantId' -Scopes @(" -ForegroundColor White
    Write-Host "       'User.Read.All','UserAuthenticationMethod.ReadWrite.All'" -ForegroundColor White
    Write-Host "   ) -NoWelcome" -ForegroundColor White
    Write-Host ""
    Write-Host "   Then re-run this script." -ForegroundColor White
    Write-Host ""
    return
}

Write-Host "✅ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
Write-Host "   Account: $($context.Account)" -ForegroundColor Gray
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# DEFINE HARRY POTTER USERS
# ═══════════════════════════════════════════════════════════════
$domain = "Inforcer2m365.onmicrosoft.com"

$harryPotterUPNs = @(
    "harry.potter@$domain",
    "hermione.granger@$domain",
    "ron.weasley@$domain",
    "albus.dumbledore@$domain",
    "minerva.mcgonagall@$domain",
    "draco.malfoy@$domain",
    "severus.snape@$domain",
    "bellatrix.lestrange@$domain",
    "lucius.malfoy@$domain",
    "horace.slughorn@$domain",
    "dolores.umbridge@$domain",
    "luna.lovegood@$domain",
    "cho.chang@$domain",
    "filius.flitwick@$domain",
    "gilderoy.lockhart@$domain",
    "sybill.trelawney@$domain",
    "neville.longbottom@$domain",
    "cedric.diggory@$domain",
    "newt.scamander@$domain",
    "pomona.sprout@$domain",
    "nymphadora.tonks@$domain"
)

Write-Host "👥 Looking up Harry Potter users..." -ForegroundColor Yellow
Write-Host ""

$users = @()
$notFound = @()

foreach ($upn in $harryPotterUPNs) {
    try {
        $user = Get-MgUser -UserId $upn -Property Id, DisplayName, UserPrincipalName -ErrorAction Stop
        $users += $user
    }
    catch {
        $notFound += $upn
    }
}

Write-Host "✅ Found $($users.Count) Harry Potter users" -ForegroundColor Green
if ($notFound.Count -gt 0) {
    Write-Host "⚠️  Not found ($($notFound.Count)):" -ForegroundColor Yellow
    foreach ($nf in $notFound) {
        Write-Host "   • $nf" -ForegroundColor DarkYellow
    }
}
Write-Host ""

if ($users.Count -eq 0) {
    Write-Host "❌ No users found. Exiting." -ForegroundColor Red
    return
}

# ═══════════════════════════════════════════════════════════════
# CREATE TAP FOR EACH USER
# ═══════════════════════════════════════════════════════════════
Write-Host "🔑 Creating Temporary Access Passes..." -ForegroundColor Yellow
Write-Host "   Lifetime: $TapLifetimeMinutes minutes ($([math]::Round($TapLifetimeMinutes / 60, 1)) hours)" -ForegroundColor Gray
Write-Host "   Is usable once: $IsUsableOnce" -ForegroundColor Gray
if ($WhatIf) { Write-Host "   ⚠️  WhatIf mode — no TAPs will be created" -ForegroundColor Yellow }
Write-Host ""

$stats = @{
    Created  = 0
    Skipped  = 0
    Errors   = 0
}

$tapResults = @()

foreach ($user in $users) {
    Write-Host "   🧙 $($user.DisplayName)" -ForegroundColor White

    if ($WhatIf) {
        Write-Host "      🔸 [WhatIf] Would create TAP" -ForegroundColor DarkYellow
        continue
    }

    # Check if user already has an active TAP
    try {
        $existingTaps = Invoke-MgGraphRequest -Method GET `
            -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/authentication/temporaryAccessPassMethods" `
            -ErrorAction Stop

        $activeTaps = $existingTaps.value | Where-Object {
            $_.methodUsabilityReason -ne "Expired"
        }

        if ($activeTaps -and $activeTaps.Count -gt 0) {
            Write-Host "      ⏭️  Already has active TAP — skipping" -ForegroundColor DarkGray
            $stats.Skipped++
            continue
        }
    }
    catch {
        # If we can't check, proceed to create
    }

    # Create the TAP
    $tapBody = @{
        lifetimeInMinutes = $TapLifetimeMinutes
        isUsableOnce      = [bool]$IsUsableOnce
    }

    try {
        $result = Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/users/$($user.Id)/authentication/temporaryAccessPassMethods" `
            -Body ($tapBody | ConvertTo-Json) `
            -ContentType "application/json" `
            -ErrorAction Stop

        $tapCode = $result.temporaryAccessPass
        $tapExpiry = $result.startDateTime

        Write-Host "      ✅ TAP created: $tapCode" -ForegroundColor Green
        Write-Host "         Expires: $($result.startDateTime) + $TapLifetimeMinutes min" -ForegroundColor DarkGray

        $tapResults += [PSCustomObject]@{
            DisplayName  = $user.DisplayName
            UPN          = $user.UserPrincipalName
            TAP          = $tapCode
            LifetimeMin  = $TapLifetimeMinutes
            IsUsableOnce = [bool]$IsUsableOnce
            CreatedAt    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }

        $stats.Created++
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -like "*TemporaryAccessPass*not enabled*" -or $errorMsg -like "*not found*policy*") {
            Write-Host "      ❌ TAP policy not enabled in tenant!" -ForegroundColor Red
            Write-Host "         → Entra ID → Protection → Authentication methods → Temporary Access Pass → Enable" -ForegroundColor Yellow
            $stats.Errors++
            break
        }
        elseif ($errorMsg -like "*already exists*" -or $errorMsg -like "*active pass*") {
            Write-Host "      ⏭️  Active TAP already exists" -ForegroundColor DarkGray
            $stats.Skipped++
        }
        else {
            Write-Host "      ❌ Error: $errorMsg" -ForegroundColor Red
            $stats.Errors++
        }
    }

    Start-Sleep -Milliseconds 300
}

# ═══════════════════════════════════════════════════════════════
# EXPORT TAP CODES (so you have a record)
# ═══════════════════════════════════════════════════════════════
if ($tapResults.Count -gt 0) {
    $exportPath = "$HOME/Desktop/HarryPotter-TAP-Codes-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
    $tapResults | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8

    Write-Host ""
    Write-Host "📁 TAP codes exported to:" -ForegroundColor Cyan
    Write-Host "   $exportPath" -ForegroundColor White
}

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🔑 TAP Creation Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "   ✅ Created:  $($stats.Created)" -ForegroundColor Green
Write-Host "   ⏭️  Skipped:  $($stats.Skipped)" -ForegroundColor Gray
Write-Host "   ❌ Errors:   $($stats.Errors)" -ForegroundColor $(if ($stats.Errors -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($tapResults.Count -gt 0) {
    Write-Host "📋 TAP Codes:" -ForegroundColor White
    Write-Host ""
    Write-Host "   Name                          TAP Code" -ForegroundColor DarkGray
    Write-Host "   ────────────────────────────   ────────────" -ForegroundColor DarkGray
    foreach ($r in $tapResults) {
        $paddedName = $r.DisplayName.PadRight(30)
        Write-Host "   $paddedName $($r.TAP)" -ForegroundColor White
    }
    Write-Host ""
}

Write-Host "📝 What this achieves:" -ForegroundColor White
Write-Host "   • Each user now has a strong auth method registered" -ForegroundColor Gray
Write-Host "   • Users appear as 'MFA capable' in Entra reports" -ForegroundColor Gray
Write-Host "   • Authentication Methods → Registration report shows TAP" -ForegroundColor Gray
Write-Host "   • Conditional Access MFA requirements satisfied" -ForegroundColor Gray
Write-Host ""
Write-Host "⏰ Report updates:" -ForegroundColor White
Write-Host "   • Auth methods registration → within minutes" -ForegroundColor Gray
Write-Host "   • Per-user MFA status       → within 1-2 hours" -ForegroundColor Gray
Write-Host "   • Copilot readiness (MFA)   → within 24 hours" -ForegroundColor Gray
Write-Host ""

if ($stats.Errors -gt 0) {
    Write-Host "⚠️  If TAP creation failed, ensure the policy is enabled:" -ForegroundColor Yellow
    Write-Host "   1. Go to entra.microsoft.com" -ForegroundColor Gray
    Write-Host "   2. Protection → Authentication methods → Policies" -ForegroundColor Gray
    Write-Host "   3. Temporary Access Pass → Enable → All users" -ForegroundColor Gray
    Write-Host "   4. Configure: Lifetime 1-480 min, Length 8+, One-time or Reusable" -ForegroundColor Gray
    Write-Host "   5. Save, then re-run this script" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "💡 Tips:" -ForegroundColor Cyan
Write-Host "   • TAPs expire after $TapLifetimeMinutes minutes — MFA status persists after expiry" -ForegroundColor Gray
Write-Host "   • Use -TapLifetimeMinutes 43200 for 30-day TAPs" -ForegroundColor Gray
Write-Host "   • Use -IsUsableOnce for single-use passes" -ForegroundColor Gray
Write-Host "   • Use -WhatIf to preview without creating" -ForegroundColor Gray
Write-Host ""
