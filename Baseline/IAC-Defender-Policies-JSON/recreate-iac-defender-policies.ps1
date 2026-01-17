#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Recreates IAC Defender for Office 365 policies from JSON exports in a new tenant.

.DESCRIPTION
    This script imports Defender for Office 365 policies that were exported to JSON files
    and recreates them in the target tenant. Includes anti-phishing, anti-spam, anti-malware,
    Safe Links, and Safe Attachments policies.

.PARAMETER ImportPath
    Path to the exported policies JSON folder. Defaults to /Users/jon/Desktop/BaslineSetup/IAC-Defender-Policies-JSON

.PARAMETER DryRun
    If specified, shows what would be created without actually creating policies

.EXAMPLE
    .\recreate-iac-defender-policies.ps1
    Recreates all IAC Defender policies from the default location

.EXAMPLE
    .\recreate-iac-defender-policies.ps1 -DryRun
    Shows what policies would be created without making changes

.NOTES
    Author: GitHub Copilot
    Date: 2026-01-16
    Requires: Exchange Online PowerShell Module, Exchange Administrator or Security Administrator role
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ImportPath = "/Users/jon/Desktop/BaslineSetup/IAC-Defender-Policies-JSON",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Initialize tracking
$summary = @{
    StartTime = Get-Date
    ImportPath = $ImportPath
    AntiPhishing = @{ Created = @(); Failed = @() }
    AntiSpam = @{ Created = @(); Failed = @() }
    AntiMalware = @{ Created = @(); Failed = @() }
    SafeLinks = @{ Created = @(); Failed = @() }
    SafeAttachments = @{ Created = @(); Failed = @() }
}

# Helper function to create Anti-Phishing policy
function New-AntiPhishPolicyFromJson {
    param($JsonData)
    
    $params = @{}
    $config = $JsonData.PolicyConfig
    
    # Copy all relevant properties
    $propertiesToCopy = @(
        'AdminDisplayName', 'AuthenticationFailAction', 'DmarcQuarantineAction', 'DmarcRejectAction',
        'EnableAntiSpoofEnforcement', 'EnableAuthenticationSafetyTip', 'EnableAuthenticationSoftPassSafetyTip',
        'EnableFirstContactSafetyTips', 'EnableMailboxIntelligence', 'EnableMailboxIntelligenceProtection',
        'EnableOrganizationDomainsProtection', 'EnableSimilarDomainsSafetyTips', 'EnableSimilarUsersSafetyTips',
        'EnableSpoofIntelligence', 'EnableTargetedDomainsProtection', 'EnableTargetedUserProtection',
        'EnableUnauthenticatedSender', 'EnableUnusualCharactersSafetyTips', 'EnableViaTag',
        'ExcludedDomains', 'ExcludedSenders', 'HonorDmarcPolicy', 'ImpersonationProtectionState',
        'MailboxIntelligenceProtectionAction', 'MailboxIntelligenceProtectionActionRecipients',
        'MailboxIntelligenceQuarantineTag', 'PhishThresholdLevel', 'PolicyTag',
        'RecommendedPolicyType', 'SpoofQuarantineTag', 'TargetedDomainActionRecipients',
        'TargetedDomainProtectionAction', 'TargetedDomainQuarantineTag', 'TargetedDomainsToProtect',
        'TargetedUserActionRecipients', 'TargetedUserProtectionAction', 'TargetedUserQuarantineTag',
        'TargetedUsersToProtect', 'TreatSoftPassAsAuthenticated'
    )
    
    foreach ($prop in $propertiesToCopy) {
        if ($null -ne $config.$prop) {
            $params[$prop] = $config.$prop
        }
    }
    
    $params['Name'] = $config.Name
    
    try {
        if (-not $DryRun) {
            $newPolicy = New-AntiPhishPolicy @params
            Write-Host "   ✅ Created Anti-Phishing policy: $($config.Name)" -ForegroundColor Green
            
            # Create associated rule if one existed
            if ($JsonData.RuleConfig) {
                $ruleParams = @{
                    Name = $JsonData.RuleConfig.Name
                    AntiPhishPolicy = $config.Name
                    Priority = $JsonData.RuleConfig.Priority
                }
                
                if ($JsonData.RuleConfig.RecipientDomainIs) { $ruleParams['RecipientDomainIs'] = $JsonData.RuleConfig.RecipientDomainIs }
                if ($JsonData.RuleConfig.SentTo) { $ruleParams['SentTo'] = $JsonData.RuleConfig.SentTo }
                if ($JsonData.RuleConfig.SentToMemberOf) { $ruleParams['SentToMemberOf'] = $JsonData.RuleConfig.SentToMemberOf }
                if ($JsonData.RuleConfig.ExceptIfRecipientDomainIs) { $ruleParams['ExceptIfRecipientDomainIs'] = $JsonData.RuleConfig.ExceptIfRecipientDomainIs }
                if ($JsonData.RuleConfig.ExceptIfSentTo) { $ruleParams['ExceptIfSentTo'] = $JsonData.RuleConfig.ExceptIfSentTo }
                if ($JsonData.RuleConfig.ExceptIfSentToMemberOf) { $ruleParams['ExceptIfSentToMemberOf'] = $JsonData.RuleConfig.ExceptIfSentToMemberOf }
                if ($null -ne $JsonData.RuleConfig.Enabled -and $JsonData.RuleConfig.Enabled -ne "") {
                    $ruleParams['Enabled'] = [bool]$JsonData.RuleConfig.Enabled
                }
                
                $newRule = New-AntiPhishRule @ruleParams
                Write-Host "      ➕ Created rule: $($JsonData.RuleConfig.Name)" -ForegroundColor Gray
            }
            
            return $newPolicy
        } else {
            Write-Host "   [DRY RUN] Would create Anti-Phishing policy: $($config.Name)" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "   ❌ Failed to create: $($config.Name) - $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Helper function to create Anti-Spam policy
function New-AntiSpamPolicyFromJson {
    param($JsonData)
    
    $params = @{}
    $config = $JsonData.PolicyConfig
    
    # Copy all relevant properties (excluding ZapEnabled which is not valid for New-HostedContentFilterPolicy)
    $propertiesToCopy = @(
        'AdminDisplayName', 'AddXHeaderValue', 'AllowedSenderDomains', 'AllowedSenders',
        'BlockedSenderDomains', 'BlockedSenders', 'BulkSpamAction', 'BulkThreshold',
        'DownloadLink', 'EnableEndUserSpamNotifications', 'EnableLanguageBlockList',
        'EnableRegionBlockList', 'EndUserSpamNotificationCustomFromAddress',
        'EndUserSpamNotificationCustomFromName', 'EndUserSpamNotificationCustomSubject',
        'EndUserSpamNotificationFrequency', 'EndUserSpamNotificationLanguage',
        'EndUserSpamNotificationLimit', 'HighConfidencePhishAction', 'HighConfidenceSpamAction',
        'IncreaseScoreWithBizOrInfoUrls', 'IncreaseScoreWithImageLinks',
        'IncreaseScoreWithNumericIps', 'IncreaseScoreWithRedirectToOtherPort',
        'InlineSafetyTipsEnabled', 'LanguageBlockList', 'MarkAsSpamBulkMail',
        'MarkAsSpamEmbedTagsInHtml', 'MarkAsSpamEmptyMessages', 'MarkAsSpamFormTagsInHtml',
        'MarkAsSpamFramesInHtml', 'MarkAsSpamFromAddressAuthFail', 'MarkAsSpamJavaScriptInHtml',
        'MarkAsSpamNdrBackscatter', 'MarkAsSpamObjectTagsInHtml', 'MarkAsSpamSensitiveWordList',
        'MarkAsSpamSpfRecordHardFail', 'MarkAsSpamWebBugsInHtml', 'ModifySubjectValue',
        'PhishSpamAction', 'PhishZapEnabled', 'QuarantineRetentionPeriod',
        'RedirectToRecipients', 'RegionBlockList', 'SpamAction', 'SpamZapEnabled',
        'TestModeAction', 'TestModeBccToRecipients'
    )
    
    foreach ($prop in $propertiesToCopy) {
        if ($null -ne $config.$prop) {
            $params[$prop] = $config.$prop
        }
    }
    
    $params['Name'] = $config.Name
    
    try {
        if (-not $DryRun) {
            $newPolicy = New-HostedContentFilterPolicy @params
            Write-Host "   ✅ Created Anti-Spam policy: $($config.Name)" -ForegroundColor Green
            
            # Create associated rule if one existed
            if ($JsonData.RuleConfig) {
                $ruleParams = @{
                    Name = $JsonData.RuleConfig.Name
                    HostedContentFilterPolicy = $config.Name
                    Priority = $JsonData.RuleConfig.Priority
                }
                
                if ($JsonData.RuleConfig.RecipientDomainIs) { $ruleParams['RecipientDomainIs'] = $JsonData.RuleConfig.RecipientDomainIs }
                if ($JsonData.RuleConfig.SentTo) { $ruleParams['SentTo'] = $JsonData.RuleConfig.SentTo }
                if ($JsonData.RuleConfig.SentToMemberOf) { $ruleParams['SentToMemberOf'] = $JsonData.RuleConfig.SentToMemberOf }
                if ($JsonData.RuleConfig.ExceptIfRecipientDomainIs) { $ruleParams['ExceptIfRecipientDomainIs'] = $JsonData.RuleConfig.ExceptIfRecipientDomainIs }
                if ($JsonData.RuleConfig.ExceptIfSentTo) { $ruleParams['ExceptIfSentTo'] = $JsonData.RuleConfig.ExceptIfSentTo }
                if ($JsonData.RuleConfig.ExceptIfSentToMemberOf) { $ruleParams['ExceptIfSentToMemberOf'] = $JsonData.RuleConfig.ExceptIfSentToMemberOf }
                if ($null -ne $JsonData.RuleConfig.Enabled -and $JsonData.RuleConfig.Enabled -ne "") {
                    $ruleParams['Enabled'] = [bool]$JsonData.RuleConfig.Enabled
                }
                
                $newRule = New-HostedContentFilterRule @ruleParams
                Write-Host "      ➕ Created rule: $($JsonData.RuleConfig.Name)" -ForegroundColor Gray
            }
            
            return $newPolicy
        } else {
            Write-Host "   [DRY RUN] Would create Anti-Spam policy: $($config.Name)" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "   ❌ Failed to create: $($config.Name) - $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Helper function to create Anti-Malware policy
function New-AntiMalwarePolicyFromJson {
    param($JsonData)
    
    $params = @{}
    $config = $JsonData.PolicyConfig
    
    # Copy all relevant properties
    $propertiesToCopy = @(
        'AdminDisplayName', 'Action', 'CustomNotifications', 'EnableExternalSenderAdminNotifications',
        'EnableExternalSenderNotifications', 'EnableFileFilter', 'EnableInternalSenderAdminNotifications',
        'EnableInternalSenderNotifications', 'ExternalSenderAdminAddress', 'FileTypes',
        'InternalSenderAdminAddress', 'QuarantineTag', 'RecommendedPolicyType', 'ZapEnabled'
    )
    
    foreach ($prop in $propertiesToCopy) {
        if ($null -ne $config.$prop) {
            $params[$prop] = $config.$prop
        }
    }
    
    $params['Name'] = $config.Name
    
    try {
        if (-not $DryRun) {
            $newPolicy = New-MalwareFilterPolicy @params
            Write-Host "   ✅ Created Anti-Malware policy: $($config.Name)" -ForegroundColor Green
            
            # Create associated rule if one existed
            if ($JsonData.RuleConfig) {
                $ruleParams = @{
                    Name = $JsonData.RuleConfig.Name
                    MalwareFilterPolicy = $config.Name
                    Priority = $JsonData.RuleConfig.Priority
                }
                
                if ($JsonData.RuleConfig.RecipientDomainIs) { $ruleParams['RecipientDomainIs'] = $JsonData.RuleConfig.RecipientDomainIs }
                if ($JsonData.RuleConfig.SentTo) { $ruleParams['SentTo'] = $JsonData.RuleConfig.SentTo }
                if ($JsonData.RuleConfig.SentToMemberOf) { $ruleParams['SentToMemberOf'] = $JsonData.RuleConfig.SentToMemberOf }
                if ($JsonData.RuleConfig.ExceptIfRecipientDomainIs) { $ruleParams['ExceptIfRecipientDomainIs'] = $JsonData.RuleConfig.ExceptIfRecipientDomainIs }
                if ($JsonData.RuleConfig.ExceptIfSentTo) { $ruleParams['ExceptIfSentTo'] = $JsonData.RuleConfig.ExceptIfSentTo }
                if ($JsonData.RuleConfig.ExceptIfSentToMemberOf) { $ruleParams['ExceptIfSentToMemberOf'] = $JsonData.RuleConfig.ExceptIfSentToMemberOf }
                if ($null -ne $JsonData.RuleConfig.Enabled -and $JsonData.RuleConfig.Enabled -ne "") {
                    $ruleParams['Enabled'] = [bool]$JsonData.RuleConfig.Enabled
                }
                
                $newRule = New-MalwareFilterRule @ruleParams
                Write-Host "      ➕ Created rule: $($JsonData.RuleConfig.Name)" -ForegroundColor Gray
            }
            
            return $newPolicy
        } else {
            Write-Host "   [DRY RUN] Would create Anti-Malware policy: $($config.Name)" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "   ❌ Failed to create: $($config.Name) - $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Helper function to create Safe Links policy
function New-SafeLinksPolicyFromJson {
    param($JsonData)
    
    $params = @{}
    $config = $JsonData.PolicyConfig
    
    # Copy all relevant properties
    $propertiesToCopy = @(
        'AdminDisplayName', 'AllowClickThrough', 'CustomNotificationText', 'DeliverMessageAfterScan',
        'DisableUrlRewrite', 'DoNotAllowClickThrough', 'DoNotRewriteUrls', 'DoNotTrackUserClicks',
        'EnableForInternalSenders', 'EnableOrganizationBranding', 'EnableSafeLinksForEmail',
        'EnableSafeLinksForOffice', 'EnableSafeLinksForTeams', 'IsEnabled', 'ScanUrls',
        'TrackClicks', 'UseTranslatedNotificationText', 'WhiteListedUrls'
    )
    
    foreach ($prop in $propertiesToCopy) {
        if ($null -ne $config.$prop) {
            $params[$prop] = $config.$prop
        }
    }
    
    $params['Name'] = $config.Name
    
    try {
        if (-not $DryRun) {
            $newPolicy = New-SafeLinksPolicy @params
            Write-Host "   ✅ Created Safe Links policy: $($config.Name)" -ForegroundColor Green
            
            # Create associated rule if one existed
            if ($JsonData.RuleConfig) {
                $ruleParams = @{
                    Name = $JsonData.RuleConfig.Name
                    SafeLinksPolicy = $config.Name
                    Priority = $JsonData.RuleConfig.Priority
                }
                
                if ($JsonData.RuleConfig.RecipientDomainIs) { $ruleParams['RecipientDomainIs'] = $JsonData.RuleConfig.RecipientDomainIs }
                if ($JsonData.RuleConfig.SentTo) { $ruleParams['SentTo'] = $JsonData.RuleConfig.SentTo }
                if ($JsonData.RuleConfig.SentToMemberOf) { $ruleParams['SentToMemberOf'] = $JsonData.RuleConfig.SentToMemberOf }
                if ($JsonData.RuleConfig.ExceptIfRecipientDomainIs) { $ruleParams['ExceptIfRecipientDomainIs'] = $JsonData.RuleConfig.ExceptIfRecipientDomainIs }
                if ($JsonData.RuleConfig.ExceptIfSentTo) { $ruleParams['ExceptIfSentTo'] = $JsonData.RuleConfig.ExceptIfSentTo }
                if ($JsonData.RuleConfig.ExceptIfSentToMemberOf) { $ruleParams['ExceptIfSentToMemberOf'] = $JsonData.RuleConfig.ExceptIfSentToMemberOf }
                if ($null -ne $JsonData.RuleConfig.Enabled -and $JsonData.RuleConfig.Enabled -ne "") {
                    $ruleParams['Enabled'] = [bool]$JsonData.RuleConfig.Enabled
                }
                
                $newRule = New-SafeLinksRule @ruleParams
                Write-Host "      ➕ Created rule: $($JsonData.RuleConfig.Name)" -ForegroundColor Gray
            }
            
            return $newPolicy
        } else {
            Write-Host "   [DRY RUN] Would create Safe Links policy: $($config.Name)" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "   ❌ Failed to create: $($config.Name) - $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Helper function to create Safe Attachments policy
function New-SafeAttachmentsPolicyFromJson {
    param($JsonData)
    
    $params = @{}
    $config = $JsonData.PolicyConfig
    
    # Copy all relevant properties (ActionOnError not valid for New-SafeAttachmentPolicy)
    $propertiesToCopy = @(
        'Action', 'AdminDisplayName', 'Enable', 'EnableOrganizationBranding',
        'QuarantineTag', 'Redirect', 'RedirectAddress', 'RecommendedPolicyType'
    )
    
    foreach ($prop in $propertiesToCopy) {
        if ($null -ne $config.$prop) {
            $params[$prop] = $config.$prop
        }
    }
    
    $params['Name'] = $config.Name
    
    try {
        if (-not $DryRun) {
            $newPolicy = New-SafeAttachmentPolicy @params
            Write-Host "   ✅ Created Safe Attachments policy: $($config.Name)" -ForegroundColor Green
            
            # Create associated rule if one existed
            if ($JsonData.RuleConfig) {
                $ruleParams = @{
                    Name = $JsonData.RuleConfig.Name
                    SafeAttachmentPolicy = $config.Name
                    Priority = $JsonData.RuleConfig.Priority
                }
                
                if ($JsonData.RuleConfig.RecipientDomainIs) { $ruleParams['RecipientDomainIs'] = $JsonData.RuleConfig.RecipientDomainIs }
                if ($JsonData.RuleConfig.SentTo) { $ruleParams['SentTo'] = $JsonData.RuleConfig.SentTo }
                if ($JsonData.RuleConfig.SentToMemberOf) { $ruleParams['SentToMemberOf'] = $JsonData.RuleConfig.SentToMemberOf }
                if ($JsonData.RuleConfig.ExceptIfRecipientDomainIs) { $ruleParams['ExceptIfRecipientDomainIs'] = $JsonData.RuleConfig.ExceptIfRecipientDomainIs }
                if ($JsonData.RuleConfig.ExceptIfSentTo) { $ruleParams['ExceptIfSentTo'] = $JsonData.RuleConfig.ExceptIfSentTo }
                if ($JsonData.RuleConfig.ExceptIfSentToMemberOf) { $ruleParams['ExceptIfSentToMemberOf'] = $JsonData.RuleConfig.ExceptIfSentToMemberOf }
                if ($null -ne $JsonData.RuleConfig.Enabled -and $JsonData.RuleConfig.Enabled -ne "") {
                    $ruleParams['Enabled'] = [bool]$JsonData.RuleConfig.Enabled
                }
                
                $newRule = New-SafeAttachmentRule @ruleParams
                Write-Host "      ➕ Created rule: $($JsonData.RuleConfig.Name)" -ForegroundColor Gray
            }
            
            return $newPolicy
        } else {
            Write-Host "   [DRY RUN] Would create Safe Attachments policy: $($config.Name)" -ForegroundColor Yellow
            return $null
        }
    } catch {
        Write-Host "   ❌ Failed to create: $($config.Name) - $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Main execution
try {
    Write-Host "`n=== IAC Defender for Office 365 Policy Recreation ===" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "🔍 DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    }
    Write-Host "Import Path: $ImportPath`n" -ForegroundColor Gray
    
    # Verify connection
    try {
        $orgConfig = Get-OrganizationConfig -ErrorAction Stop
        Write-Host "✅ Connected to Exchange Online: $($orgConfig.Name)`n" -ForegroundColor Green
    } catch {
        Write-Host "❌ Not connected to Exchange Online. Please run Connect-ExchangeOnline first." -ForegroundColor Red
        exit 1
    }
    
    # Process Anti-Phishing Policies
    Write-Host "--- Processing Anti-Phishing Policies ---" -ForegroundColor Cyan
    $antiPhishPath = Join-Path $ImportPath "AntiPhishing"
    if (Test-Path $antiPhishPath) {
        $jsonFiles = Get-ChildItem -Path $antiPhishPath -Filter "*.json"
        Write-Host "Found $($jsonFiles.Count) Anti-Phishing policy files" -ForegroundColor Yellow
        
        foreach ($file in $jsonFiles) {
            try {
                $jsonData = Get-Content $file.FullName -Raw | ConvertFrom-Json
                Write-Host "`nProcessing: $($jsonData.SourcePolicyName)" -ForegroundColor White
                
                $result = New-AntiPhishPolicyFromJson -JsonData $jsonData
                $summary.AntiPhishing.Created += $jsonData.SourcePolicyName
            } catch {
                Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                $summary.AntiPhishing.Failed += $jsonData.SourcePolicyName
            }
        }
    }
    
    # Process Anti-Spam Policies
    Write-Host "`n--- Processing Anti-Spam Policies ---" -ForegroundColor Cyan
    $antiSpamPath = Join-Path $ImportPath "AntiSpam"
    if (Test-Path $antiSpamPath) {
        $jsonFiles = Get-ChildItem -Path $antiSpamPath -Filter "*.json"
        Write-Host "Found $($jsonFiles.Count) Anti-Spam policy files" -ForegroundColor Yellow
        
        foreach ($file in $jsonFiles) {
            try {
                $jsonData = Get-Content $file.FullName -Raw | ConvertFrom-Json
                Write-Host "`nProcessing: $($jsonData.SourcePolicyName)" -ForegroundColor White
                
                $result = New-AntiSpamPolicyFromJson -JsonData $jsonData
                $summary.AntiSpam.Created += $jsonData.SourcePolicyName
            } catch {
                Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                $summary.AntiSpam.Failed += $jsonData.SourcePolicyName
            }
        }
    }
    
    # Process Anti-Malware Policies
    Write-Host "`n--- Processing Anti-Malware Policies ---" -ForegroundColor Cyan
    $antiMalwarePath = Join-Path $ImportPath "AntiMalware"
    if (Test-Path $antiMalwarePath) {
        $jsonFiles = Get-ChildItem -Path $antiMalwarePath -Filter "*.json"
        Write-Host "Found $($jsonFiles.Count) Anti-Malware policy files" -ForegroundColor Yellow
        
        foreach ($file in $jsonFiles) {
            try {
                $jsonData = Get-Content $file.FullName -Raw | ConvertFrom-Json
                Write-Host "`nProcessing: $($jsonData.SourcePolicyName)" -ForegroundColor White
                
                $result = New-AntiMalwarePolicyFromJson -JsonData $jsonData
                $summary.AntiMalware.Created += $jsonData.SourcePolicyName
            } catch {
                Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                $summary.AntiMalware.Failed += $jsonData.SourcePolicyName
            }
        }
    }
    
    # Process Safe Links Policies
    Write-Host "`n--- Processing Safe Links Policies ---" -ForegroundColor Cyan
    $safeLinksPath = Join-Path $ImportPath "SafeLinks"
    if (Test-Path $safeLinksPath) {
        $jsonFiles = Get-ChildItem -Path $safeLinksPath -Filter "*.json"
        Write-Host "Found $($jsonFiles.Count) Safe Links policy files" -ForegroundColor Yellow
        
        foreach ($file in $jsonFiles) {
            try {
                $jsonData = Get-Content $file.FullName -Raw | ConvertFrom-Json
                Write-Host "`nProcessing: $($jsonData.SourcePolicyName)" -ForegroundColor White
                
                $result = New-SafeLinksPolicyFromJson -JsonData $jsonData
                $summary.SafeLinks.Created += $jsonData.SourcePolicyName
            } catch {
                Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                $summary.SafeLinks.Failed += $jsonData.SourcePolicyName
            }
        }
    }
    
    # Process Safe Attachments Policies
    Write-Host "`n--- Processing Safe Attachments Policies ---" -ForegroundColor Cyan
    $safeAttachmentsPath = Join-Path $ImportPath "SafeAttachments"
    if (Test-Path $safeAttachmentsPath) {
        $jsonFiles = Get-ChildItem -Path $safeAttachmentsPath -Filter "*.json"
        Write-Host "Found $($jsonFiles.Count) Safe Attachments policy files" -ForegroundColor Yellow
        
        foreach ($file in $jsonFiles) {
            try {
                $jsonData = Get-Content $file.FullName -Raw | ConvertFrom-Json
                Write-Host "`nProcessing: $($jsonData.SourcePolicyName)" -ForegroundColor White
                
                $result = New-SafeAttachmentsPolicyFromJson -JsonData $jsonData
                $summary.SafeAttachments.Created += $jsonData.SourcePolicyName
            } catch {
                Write-Host "   ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
                $summary.SafeAttachments.Failed += $jsonData.SourcePolicyName
            }
        }
    }
    
    # Summary
    $summary.EndTime = Get-Date
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Anti-Phishing Created: $($summary.AntiPhishing.Created.Count)" -ForegroundColor Green
    Write-Host "Anti-Spam Created: $($summary.AntiSpam.Created.Count)" -ForegroundColor Green
    Write-Host "Anti-Malware Created: $($summary.AntiMalware.Created.Count)" -ForegroundColor Green
    Write-Host "Safe Links Created: $($summary.SafeLinks.Created.Count)" -ForegroundColor Green
    Write-Host "Safe Attachments Created: $($summary.SafeAttachments.Created.Count)" -ForegroundColor Green
    
    $totalFailed = $summary.AntiPhishing.Failed.Count + $summary.AntiSpam.Failed.Count + 
                   $summary.AntiMalware.Failed.Count + $summary.SafeLinks.Failed.Count + 
                   $summary.SafeAttachments.Failed.Count
    
    if ($totalFailed -gt 0) {
        Write-Host "Total Failed: $totalFailed" -ForegroundColor Red
    }
    
    # Export summary
    $summaryPath = Join-Path $ImportPath "recreation-summary.json"
    $summary | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryPath -Encoding utf8
    Write-Host "`nSummary exported to: $summaryPath" -ForegroundColor Gray
    Write-Host "`n✅ Recreation complete!" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Fatal error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
