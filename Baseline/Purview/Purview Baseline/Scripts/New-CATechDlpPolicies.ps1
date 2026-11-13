<#
.SYNOPSIS
  Creates the remaining CAT DLP policies (Teams, Devices, Copilot, Confidential external-block) in SIMULATION (no notifications). Dry run unless -Create is passed.
.DESCRIPTION
  Run in Security & Compliance PowerShell (Connect-IPPSSession is called below).
  Parameters checked against Microsoft Learn on 2026-11-13. Label-condition rules and the Teams
  AccessScope condition are UNTESTED in this tenant: after -Create, open each rule in the portal and
  confirm the conditions and actions before promoting past simulation.
  Policies built by hand (M365 Sensitive Content, M365 Restricted) are included but switched OFF.
  They are only run with -IncludeManualPolicies, for documentation / rebuilding in another tenant.
  Existing policies are skipped, never changed. Nothing is disabled or deleted by this script.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$UserPrincipalName,
  [Parameter(Mandatory)][string]$AlertEmail,
  [switch]$Create,
  [switch]$IncludeManualPolicies,  # OFF by default: the M365 policies below were built by hand and are only listed here for documentation / rebuilding in another tenant
  [switch]$SkipTeams,              # Teams DLP needs E5-level licensing
  [switch]$SkipEndpoint,           # Endpoint DLP needs E5 + onboarded devices + Compliance (Data) Administrator role
  [switch]$SkipCopilotLabelBlock,  # Copilot label rule needs E5 + Microsoft 365 Copilot license
  [switch]$SkipConfidential        # Confidential external-block, replaces the old hand-built/SPO policies for Confidential
)

# ---------------- CONFIG: edit these ----------------
$SensitiveSITs = @(
  @{Name = "Credit Card Number"},
  @{Name = "U.S. Bank Account Number"},
  @{Name = "ABA Routing Number"},
  @{Name = "SWIFT Code"},
  @{Name = "International Banking Account Number (IBAN)"},
  @{Name = "U.S. Social Security Number (SSN)"}
  # add your user-defined SITs here, for example: @{Name = "My Custom SIT"}
)
$RestrictedBlockLabels = @("Restricted - Internal")                                            # label display names as shown by Get-Label
# Confidential - Third Parties is deliberately excluded: it's the user-defined-recipient label
# meant for controlled external sharing, so blocking all external sharing of it would defeat
# its purpose (mirrors how $RestrictedBlockLabels excludes Restricted - Third Parties above).
$ConfidentialLabels    = @("Confidential - Internal", "Confidential - Reporting")
$CopilotBlockLabels    = @("Restricted - Internal", "Restricted - Third Parties")              # labels Copilot must not process
# ------------------------------------------------------

Connect-IPPSSession -UserPrincipalName $UserPrincipalName
$results = New-Object System.Collections.Generic.List[object]

# Pre-flight: every SIT name must resolve, every label must exist
$known = Get-DlpSensitiveInformationType | Select-Object -ExpandProperty Name
foreach ($s in $SensitiveSITs) {
  if ($known -notcontains $s.Name) { throw "SIT '$($s.Name)' not found. Check names with Get-DlpSensitiveInformationType." }
}
function Get-LabelGuids([string[]]$Names) {
  foreach ($n in $Names) {
    $l = Get-Label | Where-Object { $_.DisplayName -eq $n -or $_.Name -eq $n }
    if (-not $l) { throw "Label '$n' not found. Run: Get-Label | ft DisplayName,Guid  and fix the CONFIG block." }
    ($l | Select-Object -First 1).Guid.ToString()
  }
}
function New-LabelCondition([string[]]$Guids) {
  # basic-syntax label condition (format from the New-DlpComplianceRule parameter docs)
  , @(@{ operator = "And"; groups = @(@{ operator = "Or"; name = "Default"; labels = @($Guids | ForEach-Object { @{ name = $_; type = "Sensitivity" } }) }) })
}

function Build {
  param([string]$Name, [string]$Comment, [hashtable]$PolicyParams, [string]$RuleName, [hashtable]$RuleParams)
  if (-not $Create) { Write-Host "[dry-run] would create: $Name"; $results.Add([pscustomobject]@{Policy = $Name; Result = "dry-run"}); return }
  try {
    if (Get-DlpCompliancePolicy -Identity $Name -ErrorAction SilentlyContinue) {
      Write-Host "[skip]    already exists: $Name" -ForegroundColor Yellow
      $results.Add([pscustomobject]@{Policy = $Name; Result = "exists, not changed"}); return
    }
    New-DlpCompliancePolicy -Name $Name -Comment $Comment -Mode TestWithoutNotifications @PolicyParams | Out-Null
  } catch {
    Write-Host "[FAIL]    policy $Name : $($_.Exception.Message)" -ForegroundColor Red
    $results.Add([pscustomobject]@{Policy = $Name; Result = "FAIL (policy): $($_.Exception.Message)"}); return
  }
  try {
    New-DlpComplianceRule -Name $RuleName -Policy $Name @RuleParams | Out-Null
    Write-Host "[ok]      $Name (simulation)" -ForegroundColor Green
    $results.Add([pscustomobject]@{Policy = $Name; Result = "created, simulation"})
  } catch {
    Write-Host "[PARTIAL] $Name created but rule failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "          Fix the rule in the portal, or remove the empty policy and re-run." -ForegroundColor Red
    $results.Add([pscustomobject]@{Policy = $Name; Result = "PARTIAL: policy exists, rule failed: $($_.Exception.Message)"})
  }
}

$sitText = "financial, Social Security number and user-defined sensitive information types (SITs)"


# ======================================================================================
# MANUAL POLICIES - ALREADY BUILT BY HAND IN THE CONDITIONALACCESS.TECH TENANT.
# These are skipped unless -IncludeManualPolicies is passed, so a normal run never touches them.
# They are listed so the full set is documented and can be rebuilt in another tenant.
# Even with the switch on, Build skips any policy whose name already exists.
# Combined EXO+SPO+OneDrive rules use only conditions common to all three locations.
# UNTESTED via script: BlockAccessScope PerUser on a policy that includes Exchange.
# ======================================================================================
function Skip-Manual([string]$Name) {
  Write-Host "[manual]  built by hand, not run: $Name" -ForegroundColor DarkGray
  $results.Add([pscustomobject]@{Policy = $Name; Result = "manual (built by hand), not run"})
}

# M1. M365 - Block Sensitive Content (MANUAL)
if ($IncludeManualPolicies) {
  Build -Name "CAT - DLP - M365 - Block Sensitive Content" `
    -Comment "Conditionalaccess.tech DLP Detects $sitText in Exchange Online email, SharePoint and OneDrive, and blocks delivery or access for people outside the organization. Internal users are not affected. Starts in simulation; promote to enforce after baseline review." `
    -PolicyParams @{ ExchangeLocation = "All"; SharePointLocation = "All"; OneDriveLocation = "All" } `
    -RuleName "Sensitive Content External Block" `
    -RuleParams @{ ContentContainsSensitiveInformation = $SensitiveSITs; AccessScope = "NotInOrganization"; BlockAccess = $true; BlockAccessScope = "PerUser"
                   NotifyUser = @("Owner", "LastModifier"); GenerateAlert = @($AlertEmail) }
} else { Skip-Manual "CAT - DLP - M365 - Block Sensitive Content" }

# M2. M365 - Block External - Restricted (MANUAL)
if ($IncludeManualPolicies) {
  $rIds = Get-LabelGuids $RestrictedBlockLabels
  Build -Name "CAT - DLP - M365 - Block External - Restricted" `
    -Comment "Conditionalaccess.tech DLP Blocks content labeled Restricted - Internal from being sent to or shared with external recipients, by email or through SharePoint and OneDrive. Internal users are not affected." `
    -PolicyParams @{ ExchangeLocation = "All"; SharePointLocation = "All"; OneDriveLocation = "All" } `
    -RuleName "Restricted Internal External Block" `
    -RuleParams @{ ContentContainsSensitiveInformation = (New-LabelCondition $rIds); AccessScope = "NotInOrganization"; BlockAccess = $true; BlockAccessScope = "PerUser"
                   NotifyUser = @("Owner", "LastModifier"); GenerateAlert = @($AlertEmail) }
} else { Skip-Manual "CAT - DLP - M365 - Block External - Restricted" }

# ======================================================================================
# CREATED BY THIS SCRIPT (simulation mode)
# ======================================================================================

# 1. TEAMS - Sensitive Content
if (-not $SkipTeams) {
  Build -Name "CAT - DLP - TEAMS - Block Sensitive Content" `
    -Comment "Conditionalaccess.tech DLP Detects $sitText in Teams chat and channel message text and blocks messages shared outside the organization. Message text only; files shared in Teams are covered by the SPO policy. Requires E5-level licensing. Starts in simulation." `
    -PolicyParams @{ TeamsLocation = "All" } `
    -RuleName "Sensitive Content Teams Block" `
    -RuleParams @{ ContentContainsSensitiveInformation = $SensitiveSITs; AccessScope = "NotInOrganization"; BlockAccess = $true
                   NotifyUser = @("Owner"); GenerateAlert = @($AlertEmail) }
}

# 2. D - Sensitive Content (Endpoint)
if (-not $SkipEndpoint) {
  Build -Name "CAT - DLP - D - Block Sensitive Content" `
    -Comment "Conditionalaccess.tech DLP Detects $sitText on onboarded devices; blocks copy to removable media and network shares and audits printing. Paste and AI uploads are covered by the existing D policies. Requires E5-level licensing and device onboarding. Starts in simulation." `
    -PolicyParams @{ EndpointDlpLocation = "All" } `
    -RuleName "Sensitive Content Endpoint Restrict" `
    -RuleParams @{ ContentContainsSensitiveInformation = $SensitiveSITs
                   EndpointDlpRestrictions = @(@{Setting = "RemovableMedia"; Value = "Block"}, @{Setting = "NetworkShare"; Value = "Block"}, @{Setting = "Print"; Value = "Audit"})
                   NotifyUser = @("Owner"); GenerateAlert = @($AlertEmail) }
}

# 3. COPILOT - labeled content (E5). Copilot location cannot be combined with other locations.
if (-not $SkipCopilotLabelBlock) {
  $kIds = Get-LabelGuids $CopilotBlockLabels
  $loc = '[{"Workload":"Applications","Location":"470f2276-e011-4e9d-a6ec-20768be3a4b0","Inclusions":[{"Type":"Tenant","Identity":"All"}]}]'
  $adv = @{ Version = "1.0"; Condition = @{ Operator = "And"; SubConditions = @(@{ ConditionName = "ContentContainsSensitiveInformation"
           Value = @(@{ groups = @(@{ Operator = "Or"; name = "Default"; labels = @($kIds | ForEach-Object { @{ name = $_; type = "Sensitivity" } }) }) }) }) } } | ConvertTo-Json -Depth 100
  Build -Name "CAT - DLP - COPILOT - Block Restricted Content" `
    -Comment "Conditionalaccess.tech DLP Stops Microsoft 365 Copilot and Copilot Chat from processing files and emails labeled $($CopilotBlockLabels -join ', '). Label rule only; SIT prompt blocking is the Microsoft default Copilot policy. Requires E5-level licensing and a Microsoft 365 Copilot license. Starts in simulation." `
    -PolicyParams @{ Locations = $loc; EnforcementPlanes = @("CopilotExperiences") } `
    -RuleName "Copilot Restricted Content Block" `
    -RuleParams @{ AdvancedRule = $adv; RestrictAccess = @(@{ setting = "ExcludeContentProcessing"; value = "Block" }) }
}

# 4. M365 - Block External - Confidential. Replaces the old hand-built Confidential EXO
#    policy and the old script SPO Confidential policy, the same way #2 (manual) does for
#    Restricted. Confidential - Third Parties is deliberately excluded (see CONFIG block).
if (-not $SkipConfidential) {
  $cIds = Get-LabelGuids $ConfidentialLabels
  Build -Name "CAT - DLP - M365 - Block External - Confidential" `
    -Comment "Conditionalaccess.tech DLP Blocks content labeled $($ConfidentialLabels -join ', ') from being sent to or shared with external recipients, by email or through SharePoint and OneDrive. Internal users are not affected." `
    -PolicyParams @{ ExchangeLocation = "All"; SharePointLocation = "All"; OneDriveLocation = "All" } `
    -RuleName "Confidential External Block" `
    -RuleParams @{ ContentContainsSensitiveInformation = (New-LabelCondition $cIds); AccessScope = "NotInOrganization"; BlockAccess = $true; BlockAccessScope = "PerUser"
                   NotifyUser = @("Owner", "LastModifier"); GenerateAlert = @($AlertEmail) }
}

Write-Host "`n==== Summary ====" ; $results | Format-Table -AutoSize
if (-not $Create) { Write-Host "Dry run only. Re-run with -Create to make these changes." -ForegroundColor Cyan }
else { Write-Host "Next: open each new rule in the Purview portal and confirm conditions/actions before promoting past simulation." -ForegroundColor Cyan }
