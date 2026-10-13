# Win - Network - D - GSA Client Install
# Source: Microsoft Learn "Install the Global Secure Access client for Windows" (sample script, logic unchanged)
# Package with GlobalSecureAccessClient.exe (exact filename) in the same folder, then wrap with IntuneWinAppUtil.exe.
# Install cmd : powershell.exe -ExecutionPolicy Bypass -File Win-GSA-Client-Install.ps1
# Uninstall   : "GlobalSecureAccessClient.exe" /uninstall /quiet /norestart
# Return codes: 0 success | 3010 soft reboot | 1618 retry
$logFile = "$env:ProgramData\GSAInstall\install.log"
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null
function Write-Log { param([string]$message)
    Add-Content -Path $logFile -Value ("{0} - {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $message) }
try {
    $ErrorActionPreference = 'Stop'
    Write-Log "Starting Global Secure Access client installation."
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
    $regName = "DisabledComponents"
    $expected = 0x20   # prefer IPv4 over IPv6
    $rebootRequired = $false
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null; Write-Log "Created $regPath" }
    $existing = $null
    try { $existing = Get-ItemPropertyValue -Path $regPath -Name $regName -ErrorAction Stop } catch {}
    if ($null -eq $existing) {
        New-ItemProperty -Path $regPath -Name $regName -PropertyType DWord -Value $expected -Force | Out-Null
        Write-Log "Created $regName = 0x20"; $rebootRequired = $true
    } elseif ([int]$existing -ne $expected) {
        Set-ItemProperty -Path $regPath -Name $regName -Value $expected
        Write-Log "Updated $regName from $existing to 0x20"; $rebootRequired = $true
    } else { Write-Log "$regName already 0x20. No change." }

    $root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $installerPath = Join-Path $root "GlobalSecureAccessClient.exe"
    Write-Log "Running installer from $installerPath"
    if (-not (Test-Path $installerPath)) { Write-Log "Installer not found"; exit 1 }
    $p = Start-Process -FilePath $installerPath -ArgumentList "/quiet" -Wait -PassThru
    if ($p.ExitCode -eq 1618) { Write-Log "Install in progress elsewhere (1618)"; exit 1618 }
    elseif ($p.ExitCode -ne 0) { Write-Log "Installer exit code $($p.ExitCode)"; exit $p.ExitCode }
    Write-Log "Installer completed successfully."
    if ($rebootRequired) { Write-Log "Reboot required (registry change)."; exit 3010 }
    exit 0
} catch { Write-Log "Fatal error: $_"; exit 1603 }
