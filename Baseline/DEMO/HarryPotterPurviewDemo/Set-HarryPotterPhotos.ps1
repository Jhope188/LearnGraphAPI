#Requires -Modules Microsoft.Graph.Users

<#
.SYNOPSIS
    Sets profile photos for all Harry Potter demo users.

.DESCRIPTION
    Uploads profile photos for Harry Potter Entra ID demo users.
    - First checks the local characters-resized folder for a matching photo
    - Falls back to house-coloured avatars from ui-avatars.com if no local file exists
    - Passes -ContentType correctly for both png and jpg uploads
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
# Photo folder — resized character images live next to this script
# ---------------------------------------------------------------------------
$scriptDir  = $PSScriptRoot
$photoDir   = Join-Path $scriptDir "characters-resized"
Write-Host "📂 Photo folder: $photoDir" -ForegroundColor Cyan

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
# Set photos — local file first, then fallback to house-colour avatar
# ---------------------------------------------------------------------------
$success   = 0
$failed    = 0
$fromFile  = 0
$fromAvatar = 0

foreach ($user in $hpUsers) {
    $house = $user.OfficeLocation
    $bgHex = $houseColors[$house]
    $fgHex = if ($house -eq "Hufflepuff") { $hufflepuffTextColor } else { "ffffff" }

    # Build potential local filenames: "Harry_Potter.png", "Harry_Potter.jpg", "Dolores.png" etc.
    $safeName   = $user.DisplayName -replace '\s+', '_'
    $firstName  = ($user.DisplayName -split '\s+')[0]
    $localPhoto = $null
    $contentType = "image/png"

    # Check for local photo: full name first, then first name only
    foreach ($nameVariant in @($safeName, $firstName)) {
        foreach ($ext in @("png", "jpg", "jpeg")) {
            $candidate = Join-Path $photoDir "$nameVariant.$ext"
            if (Test-Path $candidate) {
                $localPhoto  = $candidate
                $contentType = if ($ext -eq "png") { "image/png" } else { "image/jpeg" }
                break
            }
        }
        if ($localPhoto) { break }
    }

    $photoSource = $null
    $tempFile    = $null

    try {
        if ($localPhoto) {
            # Use the local character photo
            $photoSource = $localPhoto
            Write-Host "  📷 $($user.DisplayName) — using local photo: $(Split-Path $localPhoto -Leaf)" -ForegroundColor DarkCyan
        }
        else {
            # Fallback: download house-coloured avatar
            $encodedName = [Uri]::EscapeDataString($user.DisplayName)
            $avatarUrl   = "https://ui-avatars.com/api/?name=$encodedName&size=512" +
                           "&background=$bgHex&color=$fgHex&bold=true&format=png"

            $tempFile = [System.IO.Path]::Combine(
                [System.IO.Path]::GetTempPath(),
                "$($user.Id).png"
            )

            Invoke-WebRequest -Uri $avatarUrl -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
            $photoSource = $tempFile
            $contentType = "image/png"
            Write-Host "  🎨 $($user.DisplayName) — using house avatar ($house)" -ForegroundColor DarkYellow
        }

        if ($PSCmdlet.ShouldProcess($user.DisplayName, "Set profile photo")) {
            Set-MgUserPhotoContent -UserId $user.Id `
                                   -InFile $photoSource `
                                   -ContentType $contentType `
                                   -ErrorAction Stop

            Write-Host "  ✅ $($user.DisplayName)  ($house)" -ForegroundColor Green
            $success++
            if ($localPhoto) { $fromFile++ } else { $fromAvatar++ }
        }
    }
    catch {
        Write-Warning "  ❌ $($user.DisplayName) ($house) — $($_.Exception.Message)"
        $failed++
    }
    finally {
        if ($tempFile -and (Test-Path $tempFile)) { Remove-Item $tempFile -Force }
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  Photos set:    $success  (📷 local: $fromFile | 🎨 avatar: $fromAvatar)" -ForegroundColor $(if ($success -gt 0) { "Green" } else { "Gray" })
Write-Host "  Failed:        $failed"  -ForegroundColor $(if ($failed  -gt 0) { "Red"   } else { "Gray" })
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Host "Tip: If you see '403 Forbidden', re-run Connect-MgGraph with" -ForegroundColor Yellow
    Write-Host "     -Scopes 'User.ReadWrite.All' to force a fresh token.`n"   -ForegroundColor Yellow
}
