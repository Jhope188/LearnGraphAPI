#Requires -Modules Microsoft.Graph.Users

<#
.SYNOPSIS
    Sets house-coloured profile photos for all Harry Potter demo users.

.DESCRIPTION
    Standalone script to (re)apply ui-avatars.com profile photos to all
    existing Harry Potter Entra ID users.  Run this after Create-HarryPotterUsers.ps1
    if photos were skipped (users already existed) or failed silently.

    Key fix over the original script:
    - Always iterates existing users rather than skipping them
    - Passes -ContentType "image/png" to Set-MgUserPhotoContent (was missing)
    - Uses a clean temp path without the double-extension bug
    - Verbose success/failure output per user
#>

[CmdletBinding(SupportsShouldProcess)]
param()

# ---------------------------------------------------------------------------
# Connect to Graph (re-use existing session or prompt for sign-in)
# ---------------------------------------------------------------------------
$requiredScopes = @("User.ReadWrite.All")
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
# House → background hex  (text is always white)
# ---------------------------------------------------------------------------
$houseColors = @{
    "Gryffindor" = "740001"   # Scarlet
    "Slytherin"  = "1a472a"   # Dark green
    "Ravenclaw"  = "0e1a40"   # Dark blue
    "Hufflepuff" = "f0c75e"   # Yellow (text colour overridden to black below)
}

$hufflepuffTextColor = "000000"   # Black text on yellow background

# ---------------------------------------------------------------------------
# Get all users whose OfficeLocation is a house name
# ---------------------------------------------------------------------------
Write-Host "`n📋 Fetching Harry Potter users..." -ForegroundColor Cyan
$hpUsers = Get-MgUser -All -Property "Id,DisplayName,OfficeLocation" `
    | Where-Object { $_.OfficeLocation -and $houseColors.ContainsKey($_.OfficeLocation) }

if (-not $hpUsers) {
    Write-Warning "No users found with OfficeLocation set to a house name. Exiting."
    return
}

Write-Host "   Found $($hpUsers.Count) users.`n"

# ---------------------------------------------------------------------------
# Set photos
# ---------------------------------------------------------------------------
$success = 0
$failed  = 0

foreach ($user in $hpUsers) {
    $house = $user.OfficeLocation
    $bgHex = $houseColors[$house]
    $fgHex = if ($house -eq "Hufflepuff") { $hufflepuffTextColor } else { "ffffff" }

    # URL-encode display name for the API
    $encodedName = [Uri]::EscapeDataString($user.DisplayName)
    $avatarUrl   = "https://ui-avatars.com/api/?name=$encodedName&size=512" +
                   "&background=$bgHex&color=$fgHex&bold=true&format=png"

    # Unique temp file per user (avoids collision; no double-extension)
    $tempFile = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        "$($user.Id).png"
    )

    try {
        # Download avatar
        Invoke-WebRequest -Uri $avatarUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

        if ($PSCmdlet.ShouldProcess($user.DisplayName, "Set profile photo")) {
            # Upload – must pass -ContentType or Graph rejects the request silently
            Set-MgUserPhotoContent -UserId $user.Id `
                                   -InFile $tempFile `
                                   -ContentType "image/png" `
                                   -ErrorAction Stop

            Write-Host "  ✅ $($user.DisplayName)  ($house)" -ForegroundColor Green
            $success++
        }
    }
    catch {
        Write-Warning "  ❌ $($user.DisplayName) ($house) — $($_.Exception.Message)"
        $failed++
    }
    finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Photos set:    $success" -ForegroundColor $(if ($success -gt 0) { "Green" } else { "Gray" })
Write-Host "  Failed:        $failed"  -ForegroundColor $(if ($failed  -gt 0) { "Red"   } else { "Gray" })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host "Tip: If you see '403 Forbidden', re-run Connect-MgGraph with" -ForegroundColor Yellow
    Write-Host "     -Scopes 'User.ReadWrite.All' to force a fresh token.`n"   -ForegroundColor Yellow
}
