# Remediation (fix) - Win - Network - D - GSA Client Settings
$gsaPath = "HKLM:\SOFTWARE\Microsoft\Global Secure Access Client"
$gsaSettings = @{ HideSignOutButton = 1; HideDisablePrivateAccessButton = 1; HideDisableButton = 0; RestrictNonPrivilegedUsers = 0 }
if (-not (Test-Path $gsaPath)) { New-Item -Path $gsaPath -Force | Out-Null }
foreach ($s in $gsaSettings.GetEnumerator()) {
    Set-ItemProperty -Path $gsaPath -Name $s.Key -Value $s.Value -Type DWord -Force | Out-Null
    Write-Output "Set $($s.Key) to $($s.Value)"
}
