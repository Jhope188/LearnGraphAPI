<#
.SYNOPSIS
    Read-only diagnostic: dumps the current encryption rights configuration for the
    Restricted parent label and its sub-labels (Internal, Third Parties).

.DESCRIPTION
    Connects to Security & Compliance PowerShell (if not already connected) and prints
    each label's LabelActions (the "encrypt" action's Settings, including
    encryptionrightsdefinitions), ContentType, and related metadata. Makes NO
    changes to any label.

    Use this to confirm exactly which principals/groups hold which usage rights
    (e.g. PRINT vs. EXTRACT) on "Restricted - Internal" before editing
    SensitivityLabel.ps1 or IAC-Sensitivity-Labels-Documentation.md to match.

.EXAMPLE
    .\Get-RestrictedInternalLabelRights.ps1

.NOTES
    Author: IAC
    Requires: ExchangeOnlineManagement module v3+
    Role: Compliance Administrator or Information Protection Administrator (read-only)
#>

[CmdletBinding()]
param()

# ============================================================================
# CONNECT
# ============================================================================
try {
    Get-Label -ErrorAction Stop | Out-Null
    Write-Host "[OK] Already connected to Security & Compliance" -ForegroundColor Green
} catch {
    Write-Host "[..] Connecting to Security & Compliance PowerShell (browser sign-in)..." -ForegroundColor Yellow
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "[OK] Connected" -ForegroundColor Green
}

# ============================================================================
# FETCH + DISPLAY
# ============================================================================
# Restricted - Internal / Third Parties are children of the "Restricted" label
# group (ParentId / IsLabelGroup), not standalone top-level labels. Get-Label
# -Identity <DisplayName> can fail to resolve a label nested under a group, so
# pull every label once and match client-side - this works regardless of
# parent/group nesting.
Write-Host "[..] Fetching all labels..." -ForegroundColor Yellow
$allLabels = @(Get-Label -ErrorAction Stop)
Write-Host "[OK] Found $($allLabels.Count) label(s) in the tenant" -ForegroundColor Green

$targetNames = @("Restricted", "Restricted - Internal", "Restricted - Third Parties")

foreach ($name in $targetNames) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  $name" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan

    $labelMatches = @($allLabels | Where-Object { $_.DisplayName.Trim() -eq $name })
    if ($labelMatches.Count -eq 0) {
        Write-Host "  [NOT FOUND] No label with DisplayName '$name'. Here are all DisplayNames seen:" -ForegroundColor Red
        $allLabels | Select-Object -ExpandProperty DisplayName | Sort-Object | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkGray }
        continue
    }
    if ($labelMatches.Count -gt 1) {
        Write-Host "  [WARN] $($labelMatches.Count) labels share DisplayName '$name' - showing all of them" -ForegroundColor Yellow
    }

    foreach ($label in $labelMatches) {
        Write-Host "  Name                      : $($label.Name)" -ForegroundColor White
        Write-Host "  DisplayName               : $($label.DisplayName)" -ForegroundColor White
        Write-Host "  ImmutableId               : $($label.ImmutableId)" -ForegroundColor Gray
        Write-Host "  ParentId                  : $($label.ParentId)" -ForegroundColor Gray
        Write-Host "  IsLabelGroup / ParentLabel: $($label.IsLabelGroup)" -ForegroundColor Gray
        Write-Host "  ContentType               : $($label.ContentType -join ', ')" -ForegroundColor White

        # Encryption config (and everything else - watermark, header/footer,
        # group/site protection) lives inside LabelActions, not as flat
        # top-level properties, for labels on this tenant/module version.
        # Each entry is a JSON string like:
        #   {"Type":"encrypt","Disabled":"false","Settings":[{"Key":"encryptionrightsdefinitions","Value":"..."}, ...]}
        $actions = @($label.LabelActions)
        Write-Host "  LabelActions count        : $($actions.Count)" -ForegroundColor Gray

        $rightsRaw = $null
        foreach ($actionRaw in $actions) {
            try {
                $action = $actionRaw | ConvertFrom-Json -ErrorAction Stop
            } catch {
                Write-Host "    [WARN] Could not parse LabelAction as JSON: $actionRaw" -ForegroundColor Red
                continue
            }
            Write-Host ""
            Write-Host "  --- LabelAction: $($action.Type) (Disabled=$($action.Disabled)) ---" -ForegroundColor Yellow
            foreach ($setting in $action.Settings) {
                Write-Host "      $($setting.Key) = $($setting.Value)" -ForegroundColor White
                if ($setting.Key -match '^encryptionrightsdefinitions$') {
                    $rightsRaw = $setting.Value
                }
            }
        }

        if (-not $rightsRaw) {
            Write-Host ""
            Write-Host "  [INFO] No 'encryptionrightsdefinitions' setting found in any LabelAction." -ForegroundColor Yellow
        }

        if ($rightsRaw) {
            Write-Host ""
            Write-Host "  Parsed per-principal rights:" -ForegroundColor Yellow
            # Format is typically "principal1:RIGHT1,RIGHT2;principal2:RIGHT1,RIGHT2;..."
            $entries = $rightsRaw -split ';' | Where-Object { $_.Trim() -ne '' }
            foreach ($entry in $entries) {
                $parts = $entry -split ':', 2
                if ($parts.Count -eq 2) {
                    $principal = $parts[0].Trim()
                    $rights = $parts[1].Trim()
                    $hasExtract = $rights -match '\bEXTRACT\b|\bOWNER\b|\bFULLCONTROL\b'
                    $hasPrint = $rights -match '\bPRINT\b|\bOWNER\b|\bFULLCONTROL\b'
                    Write-Host "    - $principal" -ForegroundColor White
                    Write-Host "        Rights       : $rights" -ForegroundColor Gray
                    Write-Host "        Has PRINT    : $hasPrint" -ForegroundColor $(if ($hasPrint) { 'Green' } else { 'DarkGray' })
                    Write-Host "        Has EXTRACT  : $hasExtract  <-- if True, Copilot CAN read this content for this principal" -ForegroundColor $(if ($hasExtract) { 'Red' } else { 'Green' })
                } else {
                    Write-Host "    (unparsed entry) $entry" -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "  (no EncryptionRightsDefinitions set - parent/container label or UserDefined encryption)" -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Done. Paste this full output back to continue the review." -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
