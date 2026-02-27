#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Recreates IAC Defender for Office 365 policies from JSON exports in a new tenant.

.DESCRIPTION
    This script imports Defender for Office 365 policies that were exported to JSON files
    and recreates them in the target tenant. Includes anti-phishing, anti-spam (inbound &
    outbound), anti-malware, Safe Links, Safe Attachments, Connection Filter policies, and
    Mail Flow (Transport) Rules.
    
    The script is tenant-agnostic: it automatically detects the target tenant's domains
    and updates RecipientDomainIs rules accordingly.

.PARAMETER ImportPath
    Path to the exported policies JSON folder.

.PARAMETER DryRun
    If specified, shows what would be created without actually creating policies.

.PARAMETER SkipDomainUpdate
    If specified, does not update RecipientDomainIs in rules to match the target tenant.

.EXAMPLE
    .\recreate-iac-defender-policies.ps1
    .\recreate-iac-defender-policies.ps1 -DryRun

.NOTES
    Author: IAC
    Date: 2026-02-27
    Aligned to: CIS Microsoft 365 Foundations Benchmark v6.0.0
    Requires: ExchangeOnlineManagement module, Exchange Administrator or Security Administrator role
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ImportPath = (Split-Path -Parent $PSScriptRoot),

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$SkipDomainUpdate
)

if ($ImportPath -like "*Scripts") {
    $ImportPath = Split-Path -Parent $ImportPath
}

#############################################################################
# HELPER: Get target tenant domains for rule updates
#############################################################################
function Get-TargetTenantDomains {
    $acceptedDomains = Get-AcceptedDomain | Select-Object -ExpandProperty DomainName
    return $acceptedDomains
}

#############################################################################
# HELPER: Update RecipientDomainIs to target tenant domains
#############################################################################
function Update-RuleDomains {
    param($RuleConfig, $TargetDomains)
    if ($null -eq $RuleConfig -or $SkipDomainUpdate) { return $RuleConfig }
    if ($RuleConfig.RecipientDomainIs) {
        Write-Host "      Updating RecipientDomainIs: $($RuleConfig.RecipientDomainIs -join ', ') -> $($TargetDomains -join ', ')" -ForegroundColor Gray
        $RuleConfig.RecipientDomainIs = $TargetDomains
    }
    return $RuleConfig
}

#############################################################################
# HELPER: Build rule params
#############################################################################
function Build-RuleParams {
    param($RuleConfig, [string]$PolicyParamName, [string]$PolicyName)
    $ruleParams = @{
        Name = $RuleConfig.Name
        $PolicyParamName = $PolicyName
        Priority = $RuleConfig.Priority
    }
    @('RecipientDomainIs','SentTo','SentToMemberOf',
      'ExceptIfRecipientDomainIs','ExceptIfSentTo','ExceptIfSentToMemberOf') | ForEach-Object {
        if ($RuleConfig.$_) { $ruleParams[$_] = $RuleConfig.$_ }
    }
    if ($RuleConfig.State -eq 'Enabled' -or $RuleConfig.Enabled -eq $true) {
        $ruleParams['Enabled'] = $true
    } elseif ($null -ne $RuleConfig.State -or $null -ne $RuleConfig.Enabled) {
        $ruleParams['Enabled'] = $false
    }
    return $ruleParams
}

#############################################################################
# MAIN EXECUTION
#############################################################################
try {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  IAC Defender for Office 365 Policy Recreation" -ForegroundColor Cyan
    Write-Host "  CIS Microsoft 365 Foundations Benchmark v6.0.0" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    }
    Write-Host "Import Path: $ImportPath" -ForegroundColor Gray
    Write-Host ""

    # Verify Exchange Online connection
    try {
        $orgConfig = Get-OrganizationConfig -ErrorAction Stop
        Write-Host "[OK] Connected to: $($orgConfig.Name)" -ForegroundColor Green
    } catch {
        Write-Host "[!] Not connected. Connecting to Exchange Online..." -ForegroundColor Yellow
        Connect-ExchangeOnline -ShowBanner:$false
        $orgConfig = Get-OrganizationConfig
        Write-Host "[OK] Connected to: $($orgConfig.Name)" -ForegroundColor Green
    }

    $targetDomains = Get-TargetTenantDomains
    Write-Host "Target domains: $($targetDomains -join ', ')" -ForegroundColor Gray
    Write-Host ""

    $results = @{ Created = @(); Failed = @(); Skipped = @() }

    ###########################################################################
    # 1. ANTI-PHISHING
    ###########################################################################
    Write-Host "--- [1/8] Anti-Phishing Policies ---" -ForegroundColor Magenta
    $path = Join-Path $ImportPath "AntiPhishing"
    if (Test-Path $path) {
        foreach ($jsonFile in (Get-ChildItem $path -Filter "*.json")) {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $config = $json.PolicyConfig
            Write-Host "  $($config.Name)" -ForegroundColor White
            $existing = Get-AntiPhishPolicy -Identity $config.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "     SKIP: Already exists" -ForegroundColor Yellow
                $results.Skipped += "AntiPhish: $($config.Name)"
                continue
            }
            $props = @(
                'AdminDisplayName','AuthenticationFailAction','DmarcQuarantineAction','DmarcRejectAction',
                'EnableFirstContactSafetyTips','EnableMailboxIntelligence','EnableMailboxIntelligenceProtection',
                'EnableOrganizationDomainsProtection','EnableSimilarDomainsSafetyTips','EnableSimilarUsersSafetyTips',
                'EnableSpoofIntelligence','EnableTargetedDomainsProtection','EnableTargetedUserProtection',
                'EnableUnauthenticatedSender','EnableUnusualCharactersSafetyTips','EnableViaTag',
                'ExcludedDomains','ExcludedSenders','HonorDmarcPolicy','ImpersonationProtectionState',
                'MailboxIntelligenceProtectionAction','MailboxIntelligenceQuarantineTag',
                'PhishThresholdLevel','SpoofQuarantineTag',
                'TargetedDomainProtectionAction','TargetedDomainQuarantineTag','TargetedDomainsToProtect',
                'TargetedUserProtectionAction','TargetedUserQuarantineTag','TargetedUsersToProtect'
            )
            $params = @{ Name = $config.Name }
            foreach ($p in $props) {
                $val = $config.$p
                if ($null -ne $val -and $val -ne '') { $params[$p] = $val }
            }
            if (-not $DryRun) {
                try {
                    New-AntiPhishPolicy @params | Out-Null
                    Write-Host "     [OK] Policy created" -ForegroundColor Green
                    if ($json.RuleConfig) {
                        $json.RuleConfig = Update-RuleDomains -RuleConfig $json.RuleConfig -TargetDomains $targetDomains
                        $ruleParams = Build-RuleParams -RuleConfig $json.RuleConfig -PolicyParamName 'AntiPhishPolicy' -PolicyName $config.Name
                        New-AntiPhishRule @ruleParams | Out-Null
                        Write-Host "     [OK] Rule created" -ForegroundColor Green
                    }
                    $results.Created += "AntiPhish: $($config.Name)"
                } catch {
                    Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
                    $results.Failed += "AntiPhish: $($config.Name) - $($_.Exception.Message)"
                }
            } else { Write-Host "     [DRY RUN] Would create policy + rule" -ForegroundColor Yellow }
        }
    } else { Write-Host "  No AntiPhishing folder found" -ForegroundColor Gray }

    ###########################################################################
    # 2. ANTI-SPAM (INBOUND)
    ###########################################################################
    Write-Host ""
    Write-Host "--- [2/8] Anti-Spam Inbound Policies ---" -ForegroundColor Magenta
    $path = Join-Path $ImportPath "AntiSpam"
    if (Test-Path $path) {
        foreach ($jsonFile in (Get-ChildItem $path -Filter "*.json")) {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $config = $json.PolicyConfig
            Write-Host "  $($config.Name)" -ForegroundColor White
            $existing = Get-HostedContentFilterPolicy -Identity $config.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "     SKIP: Already exists" -ForegroundColor Yellow
                $results.Skipped += "AntiSpam: $($config.Name)"
                continue
            }
            $props = @(
                'AdminDisplayName','AddXHeaderValue','AllowedSenderDomains','AllowedSenders',
                'BlockedSenderDomains','BlockedSenders','BulkSpamAction','BulkThreshold',
                'DownloadLink','EnableEndUserSpamNotifications','EnableLanguageBlockList',
                'EnableRegionBlockList','HighConfidencePhishAction','HighConfidenceSpamAction',
                'IncreaseScoreWithBizOrInfoUrls','IncreaseScoreWithImageLinks',
                'IncreaseScoreWithNumericIps','IncreaseScoreWithRedirectToOtherPort',
                'InlineSafetyTipsEnabled','LanguageBlockList',
                'MarkAsSpamBulkMail','MarkAsSpamEmbedTagsInHtml','MarkAsSpamEmptyMessages',
                'MarkAsSpamFormTagsInHtml','MarkAsSpamFramesInHtml','MarkAsSpamFromAddressAuthFail',
                'MarkAsSpamJavaScriptInHtml','MarkAsSpamNdrBackscatter','MarkAsSpamObjectTagsInHtml',
                'MarkAsSpamSensitiveWordList','MarkAsSpamSpfRecordHardFail','MarkAsSpamWebBugsInHtml',
                'ModifySubjectValue','PhishSpamAction','PhishZapEnabled',
                'QuarantineRetentionPeriod','RedirectToRecipients','RegionBlockList',
                'SpamAction','SpamZapEnabled','TestModeAction','TestModeBccToRecipients',
                'SpamQuarantineTag','HighConfidenceSpamQuarantineTag','PhishQuarantineTag',
                'HighConfidencePhishQuarantineTag','BulkQuarantineTag'
            )
            $params = @{ Name = $config.Name }
            foreach ($p in $props) {
                $val = $config.$p
                if ($null -ne $val -and $val -ne '') { $params[$p] = $val }
            }
            if (-not $DryRun) {
                try {
                    New-HostedContentFilterPolicy @params | Out-Null
                    Write-Host "     [OK] Policy created" -ForegroundColor Green
                    if ($json.RuleConfig) {
                        $json.RuleConfig = Update-RuleDomains -RuleConfig $json.RuleConfig -TargetDomains $targetDomains
                        $ruleParams = Build-RuleParams -RuleConfig $json.RuleConfig -PolicyParamName 'HostedContentFilterPolicy' -PolicyName $config.Name
                        New-HostedContentFilterRule @ruleParams | Out-Null
                        Write-Host "     [OK] Rule created" -ForegroundColor Green
                    }
                    $results.Created += "AntiSpam: $($config.Name)"
                } catch {
                    Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
                    $results.Failed += "AntiSpam: $($config.Name) - $($_.Exception.Message)"
                }
            } else { Write-Host "     [DRY RUN] Would create policy + rule" -ForegroundColor Yellow }
        }
    }

    ###########################################################################
    # 3. OUTBOUND SPAM
    ###########################################################################
    Write-Host ""
    Write-Host "--- [3/8] Outbound Spam Policies ---" -ForegroundColor Magenta
    $path = Join-Path $ImportPath "OutboundSpam"
    if (Test-Path $path) {
        foreach ($jsonFile in (Get-ChildItem $path -Filter "*.json")) {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $config = $json.PolicyConfig
            Write-Host "  $($config.Name)" -ForegroundColor White
            $existing = Get-HostedOutboundSpamFilterPolicy -Identity $config.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "     SKIP: Already exists" -ForegroundColor Yellow
                $results.Skipped += "OutboundSpam: $($config.Name)"
                continue
            }
            $props = @(
                'AdminDisplayName','RecipientLimitExternalPerHour','RecipientLimitInternalPerHour',
                'RecipientLimitPerDay','ActionWhenThresholdReached','AutoForwardingMode',
                'BccSuspiciousOutboundMail','BccSuspiciousOutboundAdditionalRecipients',
                'NotifyOutboundSpam','NotifyOutboundSpamRecipients'
            )
            $params = @{ Name = $config.Name }
            foreach ($p in $props) {
                $val = $config.$p
                if ($null -ne $val -and $val -ne '') { $params[$p] = $val }
            }
            if (-not $DryRun) {
                try {
                    New-HostedOutboundSpamFilterPolicy @params | Out-Null
                    Write-Host "     [OK] Policy created" -ForegroundColor Green
                    if ($json.RuleConfig) {
                        $json.RuleConfig = Update-RuleDomains -RuleConfig $json.RuleConfig -TargetDomains $targetDomains
                        $ruleParams = Build-RuleParams -RuleConfig $json.RuleConfig -PolicyParamName 'HostedOutboundSpamFilterPolicy' -PolicyName $config.Name
                        New-HostedOutboundSpamFilterRule @ruleParams | Out-Null
                        Write-Host "     [OK] Rule created" -ForegroundColor Green
                    }
                    $results.Created += "OutboundSpam: $($config.Name)"
                } catch {
                    Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
                    $results.Failed += "OutboundSpam: $($config.Name) - $($_.Exception.Message)"
                }
            } else { Write-Host "     [DRY RUN] Would create policy + rule" -ForegroundColor Yellow }
        }
    } else { Write-Host "  No OutboundSpam folder found" -ForegroundColor Gray }

    ###########################################################################
    # 4. ANTI-MALWARE
    ###########################################################################
    Write-Host ""
    Write-Host "--- [4/8] Anti-Malware Policies ---" -ForegroundColor Magenta
    $path = Join-Path $ImportPath "AntiMalware"
    if (Test-Path $path) {
        foreach ($jsonFile in (Get-ChildItem $path -Filter "*.json")) {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $config = $json.PolicyConfig
            Write-Host "  $($config.Name)" -ForegroundColor White
            $existing = Get-MalwareFilterPolicy -Identity $config.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "     SKIP: Already exists" -ForegroundColor Yellow
                $results.Skipped += "AntiMalware: $($config.Name)"
                continue
            }
            $props = @(
                'AdminDisplayName','CustomNotifications','EnableExternalSenderAdminNotifications',
                'EnableFileFilter','EnableInternalSenderAdminNotifications',
                'ExternalSenderAdminAddress','FileTypes','FileTypeAction',
                'InternalSenderAdminAddress','QuarantineTag','ZapEnabled'
            )
            $params = @{ Name = $config.Name }
            foreach ($p in $props) {
                $val = $config.$p
                if ($null -ne $val -and $val -ne '') { $params[$p] = $val }
            }
            if (-not $DryRun) {
                try {
                    New-MalwareFilterPolicy @params | Out-Null
                    Write-Host "     [OK] Policy created" -ForegroundColor Green
                    if ($json.RuleConfig) {
                        $json.RuleConfig = Update-RuleDomains -RuleConfig $json.RuleConfig -TargetDomains $targetDomains
                        $ruleParams = Build-RuleParams -RuleConfig $json.RuleConfig -PolicyParamName 'MalwareFilterPolicy' -PolicyName $config.Name
                        New-MalwareFilterRule @ruleParams | Out-Null
                        Write-Host "     [OK] Rule created" -ForegroundColor Green
                    }
                    $results.Created += "AntiMalware: $($config.Name)"
                } catch {
                    Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
                    $results.Failed += "AntiMalware: $($config.Name) - $($_.Exception.Message)"
                }
            } else { Write-Host "     [DRY RUN] Would create policy + rule" -ForegroundColor Yellow }
        }
    }

    ###########################################################################
    # 5. SAFE LINKS
    ###########################################################################
    Write-Host ""
    Write-Host "--- [5/8] Safe Links Policies ---" -ForegroundColor Magenta
    $path = Join-Path $ImportPath "SafeLinks"
    if (Test-Path $path) {
        foreach ($jsonFile in (Get-ChildItem $path -Filter "*.json")) {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $config = $json.PolicyConfig
            Write-Host "  $($config.Name)" -ForegroundColor White
            $existing = Get-SafeLinksPolicy -Identity $config.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "     SKIP: Already exists" -ForegroundColor Yellow
                $results.Skipped += "SafeLinks: $($config.Name)"
                continue
            }
            $props = @(
                'AdminDisplayName','AllowClickThrough','CustomNotificationText',
                'DeliverMessageAfterScan','DisableUrlRewrite','DoNotRewriteUrls',
                'EnableForInternalSenders','EnableOrganizationBranding',
                'EnableSafeLinksForEmail','EnableSafeLinksForOffice','EnableSafeLinksForTeams',
                'ScanUrls','TrackClicks'
            )
            $params = @{ Name = $config.Name }
            foreach ($p in $props) {
                $val = $config.$p
                if ($null -ne $val -and $val -ne '') { $params[$p] = $val }
            }
            if (-not $DryRun) {
                try {
                    New-SafeLinksPolicy @params | Out-Null
                    Write-Host "     [OK] Policy created" -ForegroundColor Green
                    if ($json.RuleConfig) {
                        $json.RuleConfig = Update-RuleDomains -RuleConfig $json.RuleConfig -TargetDomains $targetDomains
                        $ruleParams = Build-RuleParams -RuleConfig $json.RuleConfig -PolicyParamName 'SafeLinksPolicy' -PolicyName $config.Name
                        New-SafeLinksRule @ruleParams | Out-Null
                        Write-Host "     [OK] Rule created" -ForegroundColor Green
                    }
                    $results.Created += "SafeLinks: $($config.Name)"
                } catch {
                    Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
                    $results.Failed += "SafeLinks: $($config.Name) - $($_.Exception.Message)"
                }
            } else { Write-Host "     [DRY RUN] Would create policy + rule" -ForegroundColor Yellow }
        }
    }

    ###########################################################################
    # 6. SAFE ATTACHMENTS
    ###########################################################################
    Write-Host ""
    Write-Host "--- [6/8] Safe Attachments Policies ---" -ForegroundColor Magenta
    $path = Join-Path $ImportPath "SafeAttachments"
    if (Test-Path $path) {
        foreach ($jsonFile in (Get-ChildItem $path -Filter "*.json")) {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $config = $json.PolicyConfig
            Write-Host "  $($config.Name)" -ForegroundColor White
            $existing = Get-SafeAttachmentPolicy -Identity $config.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "     SKIP: Already exists" -ForegroundColor Yellow
                $results.Skipped += "SafeAttachments: $($config.Name)"
                continue
            }
            $props = @(
                'Action','AdminDisplayName','Enable','QuarantineTag','Redirect','RedirectAddress'
            )
            $params = @{ Name = $config.Name }
            foreach ($p in $props) {
                $val = $config.$p
                if ($null -ne $val -and $val -ne '') { $params[$p] = $val }
            }
            if (-not $DryRun) {
                try {
                    New-SafeAttachmentPolicy @params | Out-Null
                    Write-Host "     [OK] Policy created" -ForegroundColor Green
                    if ($json.RuleConfig) {
                        $json.RuleConfig = Update-RuleDomains -RuleConfig $json.RuleConfig -TargetDomains $targetDomains
                        $ruleParams = Build-RuleParams -RuleConfig $json.RuleConfig -PolicyParamName 'SafeAttachmentPolicy' -PolicyName $config.Name
                        New-SafeAttachmentRule @ruleParams | Out-Null
                        Write-Host "     [OK] Rule created" -ForegroundColor Green
                    }
                    $results.Created += "SafeAttachments: $($config.Name)"
                } catch {
                    Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
                    $results.Failed += "SafeAttachments: $($config.Name) - $($_.Exception.Message)"
                }
            } else { Write-Host "     [DRY RUN] Would create policy + rule" -ForegroundColor Yellow }
        }
    }

    ###########################################################################
    # 7. CONNECTION FILTER
    ###########################################################################
    Write-Host ""
    Write-Host "--- [7/8] Connection Filter Policy ---" -ForegroundColor Magenta
    $path = Join-Path $ImportPath "ConnectionFilter"
    if (Test-Path $path) {
        foreach ($jsonFile in (Get-ChildItem $path -Filter "*.json")) {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $config = $json.PolicyConfig
            Write-Host "  Connection Filter (Default)" -ForegroundColor White
            $updateParams = @{ Identity = 'Default' }
            $changed = $false
            if ($config.IPAllowList -and $config.IPAllowList.Count -gt 0) {
                $updateParams['IPAllowList'] = $config.IPAllowList
                $changed = $true
            }
            if ($config.IPBlockList -and $config.IPBlockList.Count -gt 0) {
                $updateParams['IPBlockList'] = $config.IPBlockList
                $changed = $true
            }
            if ($null -ne $config.EnableSafeList) {
                $updateParams['EnableSafeList'] = $config.EnableSafeList
                $changed = $true
            }
            if ($changed -and -not $DryRun) {
                try {
                    Set-HostedConnectionFilterPolicy @updateParams
                    Write-Host "     [OK] Connection filter updated" -ForegroundColor Green
                    $results.Created += "ConnectionFilter: Default"
                } catch {
                    Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
                    $results.Failed += "ConnectionFilter: $($_.Exception.Message)"
                }
            } elseif (-not $changed) {
                Write-Host "     INFO: No custom IP lists to apply" -ForegroundColor Gray
                $results.Skipped += "ConnectionFilter: No changes needed"
            } else {
                Write-Host "     [DRY RUN] Would update connection filter" -ForegroundColor Yellow
            }
        }
    }

    ###########################################################################
    # 8. MAIL FLOW RULES (TRANSPORT RULES)
    ###########################################################################
    Write-Host ""
    Write-Host "--- [8/8] Mail Flow Rules (Transport Rules) ---" -ForegroundColor Magenta
    $path = Join-Path $ImportPath "MailFlowRules"
    if (Test-Path $path) {
        foreach ($jsonFile in (Get-ChildItem $path -Filter "*.json" | Sort-Object Name)) {
            $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $config = $json.RuleConfig
            Write-Host "  $($config.Name)" -ForegroundColor White

            $existing = Get-TransportRule -Identity $config.Name -ErrorAction SilentlyContinue
            if ($existing) {
                Write-Host "     SKIP: Already exists" -ForegroundColor Yellow
                $results.Skipped += "MailFlow: $($config.Name)"
                continue
            }

            if (-not $DryRun) {
                try {
                    $ruleParams = @{ Name = $config.Name }

                    # Conditions
                    if ($config.FromScope)   { $ruleParams['FromScope']   = $config.FromScope }
                    if ($config.SentToScope)  { $ruleParams['SentToScope']  = $config.SentToScope }
                    if ($config.HeaderMatchesMessageHeader) {
                        $ruleParams['HeaderMatchesMessageHeader'] = $config.HeaderMatchesMessageHeader
                        $ruleParams['HeaderMatchesPatterns']      = @($config.HeaderMatchesPatterns)
                    }
                    if ($config.AttachmentExtensionMatchesWords -and $config.AttachmentExtensionMatchesWords.Count -gt 0) {
                        $ruleParams['AttachmentExtensionMatchesWords'] = $config.AttachmentExtensionMatchesWords
                    }

                    # Actions
                    if ($config.ApplyHtmlDisclaimerText) {
                        $ruleParams['ApplyHtmlDisclaimerText']           = $config.ApplyHtmlDisclaimerText
                        $ruleParams['ApplyHtmlDisclaimerLocation']       = $config.ApplyHtmlDisclaimerLocation
                        $ruleParams['ApplyHtmlDisclaimerFallbackAction'] = $config.ApplyHtmlDisclaimerFallbackAction
                    }
                    if ($config.RejectMessageReasonText) {
                        $ruleParams['RejectMessageReasonText']        = $config.RejectMessageReasonText
                        $ruleParams['RejectMessageEnhancedStatusCode'] = $config.RejectMessageEnhancedStatusCode
                    }
                    if ($config.SetAuditSeverity) {
                        $ruleParams['SetAuditSeverity'] = $config.SetAuditSeverity
                    }
                    if ($null -ne $config.Priority -and $config.Priority -gt 0) {
                        $ruleParams['Priority'] = $config.Priority
                    }

                    New-TransportRule @ruleParams | Out-Null
                    Write-Host "     [OK] Rule created" -ForegroundColor Green
                    $results.Created += "MailFlow: $($config.Name)"
                } catch {
                    Write-Host "     [FAIL] $($_.Exception.Message)" -ForegroundColor Red
                    $results.Failed += "MailFlow: $($config.Name) - $($_.Exception.Message)"
                }
            } else {
                Write-Host "     [DRY RUN] Would create transport rule" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  No MailFlowRules folder found" -ForegroundColor Gray
    }

    ###########################################################################
    # SUMMARY
    ###########################################################################
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                    Recreation Summary" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Created:  $($results.Created.Count)" -ForegroundColor Green
    Write-Host "  Skipped:  $($results.Skipped.Count)" -ForegroundColor Yellow
    Write-Host "  Failed:   $($results.Failed.Count)" -ForegroundColor Red
    Write-Host ""

    if ($results.Created.Count -gt 0) {
        Write-Host "  Created:" -ForegroundColor Green
        $results.Created | ForEach-Object { Write-Host "    - $_" -ForegroundColor Green }
    }
    if ($results.Skipped.Count -gt 0) {
        Write-Host "  Skipped (already exist):" -ForegroundColor Yellow
        $results.Skipped | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    }
    if ($results.Failed.Count -gt 0) {
        Write-Host "  Failed:" -ForegroundColor Red
        $results.Failed | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }

    # Export summary JSON
    $summary = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Tenant    = $orgConfig.Name
        DryRun    = $DryRun.IsPresent
        Created   = $results.Created
        Skipped   = $results.Skipped
        Failed    = $results.Failed
    }
    $summaryPath = Join-Path $ImportPath "recreation-summary.json"
    $summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $summaryPath -Encoding utf8
    Write-Host ""
    Write-Host "  Summary saved: $summaryPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "         Defender Policy Recreation Complete" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
