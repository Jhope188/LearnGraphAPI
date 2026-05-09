#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns

<#
.SYNOPSIS
    Sets a random phone authentication method for all Harry Potter demo users.

.DESCRIPTION
    Adds a mobile phone authentication method with a random UK-format number
    to each Harry Potter user (identified by OfficeLocation = house name).
    Skips users that already have a phone method registered.

    Requires UserAuthenticationMethod.ReadWrite.All permission.
#>

[CmdletBinding(SupportsShouldProcess)]
param()

# ---------------------------------------------------------------------------
# Connect to Graph (re-use existing session or prompt for sign-in)
# ---------------------------------------------------------------------------
$requiredScopes = @("UserAuthenticationMethod.ReadWrite.All", "User.Read.All")
$ctx = Get-MgContext

if (-not $ctx) {
    Write-Host "🔐 No active session — launching interactive sign-in..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes $requiredScopes -NoWelcome
    $ctx = Get-MgContext
}
elseif ($requiredScopes | Where-Object { $ctx.Scopes -notcontains $_ }) {
    Write-Host "🔐 Reconnecting to request missing scopes..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes $requiredScopes -TenantId $ctx.TenantId -NoWelcome
    $ctx = Get-MgContext
}

if (-not $ctx) {
    Write-Error "❌ Failed to connect to Microsoft Graph. Exiting."
    return
}

$TenantId = $ctx.TenantId
Write-Host "🔗 Connected to tenant: $TenantId ($($ctx.Account))" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Random phone number generator (UK mobile format: +44 7XXX XXXXXX)
# ---------------------------------------------------------------------------
function New-RandomUKMobile {
    $prefixes = @("7911", "7700", "7457", "7521", "7835", "7946", "7012", "7624", "7555", "7890")
    $prefix   = $prefixes | Get-Random
    $suffix   = -join (1..6 | ForEach-Object { Get-Random -Minimum 0 -Maximum 10 })
    return "+44 $prefix $suffix"
}

# ---------------------------------------------------------------------------
# Houses
# ---------------------------------------------------------------------------
$houses = @("Gryffindor", "Slytherin", "Ravenclaw", "Hufflepuff")

# ---------------------------------------------------------------------------
# Get all Harry Potter users
# ---------------------------------------------------------------------------
Write-Host "`n📋 Fetching Harry Potter users..." -ForegroundColor Cyan
$hpUsers = Get-MgUser -All -Property "Id,DisplayName,OfficeLocation" `
    | Where-Object { $_.OfficeLocation -and $houses -contains $_.OfficeLocation }

if (-not $hpUsers) {
    Write-Warning "No users found with OfficeLocation set to a house name. Exiting."
    return
}

Write-Host "   Found $($hpUsers.Count) users.`n"

# ---------------------------------------------------------------------------
# Set phone auth method for each user
# ---------------------------------------------------------------------------
$success  = 0
$skipped  = 0
$failed   = 0

foreach ($user in ($hpUsers | Sort-Object DisplayName)) {
    $displayInfo = "$($user.DisplayName) ($($user.OfficeLocation))"

    try {
        # Check if user already has a phone method
        $existing = Get-MgUserAuthenticationPhoneMethod -UserId $user.Id -ErrorAction Stop

        if ($existing) {
            Write-Host "  ⏭️  $displayInfo — already has phone: $($existing[0].PhoneNumber)" -ForegroundColor DarkGray
            $skipped++
            continue
        }
    }
    catch {
        # 404 is fine — means no phone methods exist yet
        if ($_.Exception.Message -notmatch "404|NotFound") {
            Write-Warning "  ❌ $displayInfo — error checking existing methods: $($_.Exception.Message)"
            $failed++
            continue
        }
    }

    # Generate a random phone number
    $phoneNumber = New-RandomUKMobile

    try {
        if ($PSCmdlet.ShouldProcess($user.DisplayName, "Set phone auth: $phoneNumber")) {
            $body = @{
                phoneNumber = $phoneNumber
                phoneType   = "mobile"
            }

            New-MgUserAuthenticationPhoneMethod -UserId $user.Id -BodyParameter $body -ErrorAction Stop

            Write-Host "  ✅ $displayInfo → $phoneNumber" -ForegroundColor Green
            $success++
        }
    }
    catch {
        Write-Warning "  ❌ $displayInfo — $($_.Exception.Message)"
        $failed++
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Phone set:     $success" -ForegroundColor $(if ($success -gt 0) { "Green" } else { "Gray" })
Write-Host "  Skipped:       $skipped" -ForegroundColor $(if ($skipped -gt 0) { "Yellow" } else { "Gray" })
Write-Host "  Failed:        $failed"  -ForegroundColor $(if ($failed  -gt 0) { "Red"   } else { "Gray" })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host "Tip: Ensure you have the 'Authentication Administrator' or" -ForegroundColor Yellow
    Write-Host "     'Privileged Authentication Administrator' role assigned.`n" -ForegroundColor Yellow
}
