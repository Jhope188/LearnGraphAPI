# Remediation (detection) - Win - Network - D - GSA Client Settings
# Run as SYSTEM, 64-bit PowerShell = Yes. Keep $gsaSettings identical in the remediation script.
# Values below are the Learn sample values. For the pilot, leave Disable button visible (HideDisableButton=0) and unrestricted.
$gsaPath = "HKLM:\SOFTWARE\Microsoft\Global Secure Access Client"
$gsaSettings = @{ HideSignOutButton = 1; HideDisablePrivateAccessButton = 1; HideDisableButton = 0; RestrictNonPrivilegedUsers = 0 }
$bad = $false
foreach ($s in $gsaSettings.GetEnumerator()) {
    $cur = (Get-ItemProperty -Path $gsaPath -Name $s.Key -ErrorAction SilentlyContinue).$($s.Key)
    if ($cur -ne $s.Value) { Write-Output "Non-compliant: $($s.Key) is $cur, expected $($s.Value)"; $bad = $true }
}
if ($bad) { Write-Output "Non-compliant"; exit 1 } else { Write-Output "Compliant"; exit 0 }
