<#
.SYNOPSIS
    Creates Harry Potter themed Agent ID Blueprints & Agent Identities in Microsoft Entra ID.

.DESCRIPTION
    Demonstrates the Microsoft Entra Agent ID (Preview) feature by creating 5 magical
    agent identity blueprints and their corresponding agent identities.

    Architecture (each level builds on the previous):
        Blueprint (template)  →  Blueprint Principal (tenant SP)  →  Agent Identity (instance)

    Blueprints Created:
        🎩 Hogwarts Sorting Hat          →  The Sorting Hat
        🛡️ Auror Department Sentinel      →  Mad-Eye Moody
        📚 Hogwarts Library Keeper        →  Madam Pince
        🦉 Ministry Owl Post             →  Hedwig
        ⚗️ Potions Lab Cauldron           →  Professor Snape's Cauldron

    Prerequisites:
        - Microsoft 365 Copilot license
        - Frontier program enabled (M365 Admin → Copilot → Settings → User access → Copilot Frontier)
        - Agent ID Developer or Agent ID Administrator role
        - PowerShell 7+
        - Microsoft.Graph.Beta.Applications module (auto-installed)

    References:
        - Create blueprint:  https://learn.microsoft.com/entra/agent-id/identity-platform/create-blueprint
        - Agent identities:  https://learn.microsoft.com/entra/agent-id/identity-platform/create-delete-agent-identities
        - Known issues:      https://learn.microsoft.com/entra/agent-id/identity-platform/preview-known-issues

.PARAMETER TenantId
    The Entra ID tenant ID. Defaults to Inforcer2M365 tenant.

.PARAMETER SponsorEmail
    Email of the user to set as owner/sponsor for all blueprints.
    Defaults to the currently signed-in user.

.PARAMETER SkipAgentIdentities
    Only create blueprints and principals; skip agent identity creation.
    Useful if you only want the blueprints visible in the Agent registry.

.PARAMETER PropagationDelay
    Seconds to wait for Azure AD propagation before creating agent identities.
    Default: 20. Increase if you see 400/404 errors during Phase 5.

.PARAMETER DryRun
    Preview what would be created without making any changes.

.EXAMPLE
    .\Create-HarryPotterAgents.ps1 -DryRun

.EXAMPLE
    .\Create-HarryPotterAgents.ps1 -TenantId "e37d43b7-ff48-444b-9d44-fbd4477c18f3"

.EXAMPLE
    .\Create-HarryPotterAgents.ps1 -SkipAgentIdentities

.NOTES
    Author  : Magical IT Department
    Date    : 2025-07-17
    Version : 1.0.0
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$TenantId = "e37d43b7-ff48-444b-9d44-fbd4477c18f3",

    [Parameter()]
    [string]$SponsorEmail,

    [Parameter()]
    [int]$PropagationDelay = 20,

    [switch]$SkipAgentIdentities,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ═══════════════════════════════════════════════════════════════
#  Banner
# ═══════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "  ╔═══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║   🏰  Hogwarts Agent Identity Provisioner  🏰       ║" -ForegroundColor Magenta
Write-Host "  ║   Microsoft Entra Agent ID (Preview)                 ║" -ForegroundColor Magenta
Write-Host "  ╚═══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
if ($DryRun) {
    Write-Host "  ⚠️  DRY RUN MODE — no changes will be made" -ForegroundColor Yellow
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════
#  Module Check
# ═══════════════════════════════════════════════════════════════
$requiredModules = @(
    "Microsoft.Graph.Beta.Applications",
    "Microsoft.Graph.Users"
)
foreach ($mod in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "📦 Installing $mod..." -ForegroundColor Yellow
        Install-Module $mod -Scope CurrentUser -Force -AllowClobber
    }
}

# ═══════════════════════════════════════════════════════════════
#  Helper — Retry with exponential backoff
#  (Known issue: rapid sequential creation often fails with 400)
# ═══════════════════════════════════════════════════════════════
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 4,
        [int]$InitialDelay = 5,
        [string]$Operation = "operation"
    )
    $attempt = 0
    $delay = $InitialDelay
    while ($true) {
        try {
            return (& $ScriptBlock)
        }
        catch {
            $attempt++
            if ($attempt -ge $MaxRetries) { throw }
            Write-Host "   ⏳ $Operation — attempt $attempt/$MaxRetries failed, retrying in ${delay}s..." -ForegroundColor DarkYellow
            Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
            Start-Sleep -Seconds $delay
            $delay = [math]::Min($delay * 2, 60)
        }
    }
}

# ═══════════════════════════════════════════════════════════════
#  Connect to Microsoft Graph
# ═══════════════════════════════════════════════════════════════
$scopes = @(
    "AgentIdentityBlueprint.Create",
    "AgentIdentityBlueprint.AddRemoveCreds.All",
    "AgentIdentityBlueprint.ReadWrite.All",
    "AgentIdentityBlueprintPrincipal.Create",
    "User.Read"
)

Write-Host "🔮 Connecting to Microsoft Graph with Agent ID scopes..." -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "   [DRY RUN] Would connect with scopes:" -ForegroundColor DarkGray
    $scopes | ForEach-Object { Write-Host "     • $_" -ForegroundColor DarkGray }
} else {
    Connect-MgGraph -Scopes $scopes -TenantId $TenantId -NoWelcome
    $ctx = Get-MgContext
    Write-Host "   ✅ Connected to tenant: $($ctx.TenantId)" -ForegroundColor Green
    Write-Host "   Account: $($ctx.Account)" -ForegroundColor Gray
}

# ─── Get current user for owner/sponsor ───
if (-not $DryRun) {
    if ($SponsorEmail) {
        $sponsor = Get-MgUser -UserId $SponsorEmail
    } else {
        $currentAccount = (Get-MgContext).Account
        $sponsor = Get-MgUser -UserId $currentAccount
    }
    $sponsorId   = $sponsor.Id
    $sponsorName = $sponsor.DisplayName
    Write-Host "   👤 Sponsor/Owner: $sponsorName ($sponsorId)" -ForegroundColor Green
} else {
    $sponsorId   = "00000000-0000-0000-0000-000000000000"
    $sponsorName = "[Current User]"
    Write-Host "   👤 Sponsor/Owner: $sponsorName" -ForegroundColor DarkGray
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════
#  Define Harry Potter Agent Blueprints & Agent Identities
# ═══════════════════════════════════════════════════════════════
$blueprintDefs = @(
    @{
        DisplayName = "Hogwarts Sorting Hat"
        Description = "AI-powered student classification and house assignment based on personality traits, abilities, and potential."
        Emoji       = "🎩"
        Agents      = @(
            @{ DisplayName = "The Sorting Hat"; Description = "Autonomous classification agent that evaluates traits and assigns houses" }
        )
    },
    @{
        DisplayName = "Auror Department Sentinel"
        Description = "Dark arts threat detection, security monitoring, and incident response for magical law enforcement."
        Emoji       = "🛡️"
        Agents      = @(
            @{ DisplayName = "Mad-Eye Moody"; Description = "CONSTANT VIGILANCE! Real-time threat detection and security monitoring agent" }
        )
    },
    @{
        DisplayName = "Hogwarts Library Keeper"
        Description = "Secure knowledge retrieval and research assistance from the Restricted Section and beyond."
        Emoji       = "📚"
        Agents      = @(
            @{ DisplayName = "Madam Pince"; Description = "Knowledge retrieval agent with strict access controls and citation tracking" }
        )
    },
    @{
        DisplayName = "Ministry Owl Post"
        Description = "Encrypted magical communications routing, delivery tracking, and secure message handling."
        Emoji       = "🦉"
        Agents      = @(
            @{ DisplayName = "Hedwig"; Description = "Reliable communications routing agent with end-to-end encryption" }
        )
    },
    @{
        DisplayName = "Potions Lab Cauldron"
        Description = "Magical formula analysis, ingredient optimisation, and potion brewing quality control."
        Emoji       = "⚗️"
        Agents      = @(
            @{ DisplayName = "Professor Snapes Cauldron"; Description = "Formula analysis and quality control agent — no dunderheads allowed" }
        )
    }
)

# ═══════════════════════════════════════════════════════════════
#  PHASE 1 — Create Agent Identity Blueprints
# ═══════════════════════════════════════════════════════════════
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Phase 1 · Creating Agent Identity Blueprints" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# Track created blueprints with their IDs
$blueprints = [System.Collections.ArrayList]::new()
$bpCreated = 0; $bpSkipped = 0; $bpFailed = 0

foreach ($def in $blueprintDefs) {
    $displayName = "$($def.Emoji) $($def.DisplayName)"

    if ($DryRun) {
        Write-Host "   🔮 [DRY RUN] Would create blueprint: $displayName" -ForegroundColor DarkCyan
        Write-Host "      $($def.Description)" -ForegroundColor DarkGray
        [void]$blueprints.Add(@{
            DisplayName = $displayName
            AppId       = "<generated>"
            ObjectId    = "<generated>"
            Secret      = "<generated>"
            Agents      = $def.Agents
            IsNew       = $true
        })
        $bpCreated++
        continue
    }

    try {
        # ── Check if blueprint already exists by display name ──
        $filterName = $def.DisplayName.Replace("'", "''")
        $searchUri  = "https://graph.microsoft.com/beta/applications?`$filter=startswith(displayName,'$filterName')&`$top=5"
        $existing   = $null
        try {
            $searchResult = Invoke-MgGraphRequest -Method GET -Uri $searchUri -OutputType PSObject
            $existing = $searchResult.value | Where-Object { $_.displayName -eq $displayName }
        } catch {
            # Filter may fail with special chars — proceed to create
        }

        if ($existing) {
            Write-Host "   ⏭️  Already exists: $displayName" -ForegroundColor Gray
            Write-Host "      AppId: $($existing.appId)" -ForegroundColor DarkGray
            [void]$blueprints.Add(@{
                DisplayName = $displayName
                AppId       = $existing.appId
                ObjectId    = $existing.id
                Secret      = $null
                Agents      = $def.Agents
                IsNew       = $false
            })
            $bpSkipped++
            Write-Host ""
            continue
        }

        # ── Create the blueprint ──
        $body = @{
            "@odata.type"         = "Microsoft.Graph.AgentIdentityBlueprint"
            "displayName"         = $displayName
            "sponsors@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$sponsorId")
            "owners@odata.bind"   = @("https://graph.microsoft.com/v1.0/users/$sponsorId")
        } | ConvertTo-Json -Depth 5

        $response = Invoke-WithRetry -Operation "Create blueprint '$displayName'" -MaxRetries 5 -InitialDelay 10 -ScriptBlock {
            Invoke-MgGraphRequest `
                -Method POST `
                -Uri "https://graph.microsoft.com/beta/applications/graph.agentIdentityBlueprint" `
                -Body $body `
                -ContentType "application/json" `
                -OutputType PSObject
        }

        Write-Host "   ✅ Created: $displayName" -ForegroundColor Green
        Write-Host "      AppId:    $($response.appId)" -ForegroundColor Gray
        Write-Host "      ObjectId: $($response.id)" -ForegroundColor Gray
        [void]$blueprints.Add(@{
            DisplayName = $displayName
            AppId       = $response.appId
            ObjectId    = $response.id
            Secret      = $null
            Agents      = $def.Agents
            IsNew       = $true
        })
        $bpCreated++

        # Generous delay to avoid known Azure AD propagation issue
        Write-Host "   ⏳ Waiting 15s for Azure AD propagation..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 15
    }
    catch {
        Write-Host "   ❌ Failed: $displayName" -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
        $bpFailed++
    }
    Write-Host ""
}

Write-Host "  📊 Blueprints: ✅ $bpCreated created  ⏭️ $bpSkipped skipped  ❌ $bpFailed failed" -ForegroundColor Cyan
Write-Host ""

# Bail early if no blueprints were created or found
if ($blueprints.Count -eq 0) {
    Write-Host "❌ No blueprints available. Check licensing (Copilot + Frontier) and permissions." -ForegroundColor Red
    if (-not $DryRun) { Disconnect-MgGraph | Out-Null }
    return
}

# ═══════════════════════════════════════════════════════════════
#  PHASE 2 — Add Client Secrets (for demo/testing only)
#  Production: use managed identities + federated identity creds
# ═══════════════════════════════════════════════════════════════
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Phase 2 · Adding Client Secrets (demo only)" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

foreach ($bp in $blueprints) {
    if (-not $bp.IsNew) {
        Write-Host "   ⏭️  Skipping (pre-existing): $($bp.DisplayName)" -ForegroundColor Gray
        Write-Host "      Add a secret manually if needed for agent identity creation" -ForegroundColor DarkGray
        Write-Host ""
        continue
    }

    if ($DryRun) {
        Write-Host "   🔮 [DRY RUN] Would add client secret to: $($bp.DisplayName)" -ForegroundColor DarkCyan
        Write-Host ""
        continue
    }

    try {
        $secretBody = @{
            passwordCredential = @{
                displayName = "HP Demo Secret"
                endDateTime = (Get-Date).AddMonths(6).ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        } | ConvertTo-Json -Depth 5

        $secretResp = Invoke-WithRetry -Operation "Add secret to '$($bp.DisplayName)'" -ScriptBlock {
            Invoke-MgGraphRequest `
                -Method POST `
                -Uri "https://graph.microsoft.com/beta/applications/$($bp.ObjectId)/addPassword" `
                -Body $secretBody `
                -ContentType "application/json" `
                -OutputType PSObject
        }

        $bp.Secret = $secretResp.secretText
        Write-Host "   🔑 Secret added: $($bp.DisplayName)" -ForegroundColor Green
        Write-Host "      Expires: $($secretResp.endDateTime)" -ForegroundColor Gray

        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "   ❌ Failed to add secret: $($bp.DisplayName)" -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#  PHASE 3 — Configure Identifier URI & OAuth Scope
# ═══════════════════════════════════════════════════════════════
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Phase 3 · Configuring Identifier URIs & Scopes" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

foreach ($bp in $blueprints) {
    if (-not $bp.IsNew) {
        Write-Host "   ⏭️  Skipping (pre-existing): $($bp.DisplayName)" -ForegroundColor Gray
        Write-Host ""
        continue
    }

    if ($DryRun) {
        Write-Host "   🔮 [DRY RUN] Would configure: api://$($bp.AppId)" -ForegroundColor DarkCyan
        Write-Host ""
        continue
    }

    try {
        $scopeGuid = [guid]::NewGuid().ToString()
        $patchBody = @{
            identifierUris = @("api://$($bp.AppId)")
            api = @{
                oauth2PermissionScopes = @(
                    @{
                        adminConsentDescription = "Allow the application to access the agent on behalf of the signed-in user."
                        adminConsentDisplayName = "Access agent"
                        id                      = $scopeGuid
                        isEnabled               = $true
                        type                    = "User"
                        value                   = "access_agent"
                    }
                )
            }
        } | ConvertTo-Json -Depth 10

        Invoke-WithRetry -Operation "Configure URI for '$($bp.DisplayName)'" -ScriptBlock {
            Invoke-MgGraphRequest `
                -Method PATCH `
                -Uri "https://graph.microsoft.com/beta/applications/$($bp.ObjectId)" `
                -Body $patchBody `
                -ContentType "application/json" `
                -Headers @{ "OData-Version" = "4.0" }
        }

        Write-Host "   🌐 Configured: $($bp.DisplayName)" -ForegroundColor Green
        Write-Host "      URI:   api://$($bp.AppId)" -ForegroundColor Gray
        Write-Host "      Scope: access_agent" -ForegroundColor Gray

        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "   ⚠️  URI config failed (non-critical): $($bp.DisplayName)" -ForegroundColor Yellow
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#  PHASE 4 — Create Blueprint Principals (tenant-level SP)
# ═══════════════════════════════════════════════════════════════
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Phase 4 · Creating Blueprint Principals" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

foreach ($bp in $blueprints) {
    if (-not $bp.IsNew) {
        Write-Host "   ⏭️  Skipping (pre-existing): $($bp.DisplayName)" -ForegroundColor Gray
        Write-Host ""
        continue
    }

    if ($DryRun) {
        Write-Host "   🔮 [DRY RUN] Would create principal for: $($bp.DisplayName)" -ForegroundColor DarkCyan
        Write-Host ""
        continue
    }

    try {
        $principalBody = @{ appId = $bp.AppId } | ConvertTo-Json

        $principalResp = Invoke-WithRetry -Operation "Create principal for '$($bp.DisplayName)'" -ScriptBlock {
            Invoke-MgGraphRequest `
                -Method POST `
                -Uri "https://graph.microsoft.com/beta/serviceprincipals/graph.agentIdentityBlueprintPrincipal" `
                -Headers @{ "OData-Version" = "4.0" } `
                -Body $principalBody `
                -ContentType "application/json" `
                -OutputType PSObject
        }

        Write-Host "   ✅ Principal created: $($bp.DisplayName)" -ForegroundColor Green
        Write-Host "      SP Id: $($principalResp.id)" -ForegroundColor Gray

        Start-Sleep -Seconds 3
    }
    catch {
        Write-Host "   ❌ Failed: $($bp.DisplayName)" -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#  PHASE 5 — Create Agent Identities
#  Agent identities are created BY the blueprint (client_credentials)
#  Known limitation: no delegated permission available
# ═══════════════════════════════════════════════════════════════
if ($SkipAgentIdentities) {
    Write-Host ""
    Write-Host "⏭️  Phase 5 skipped (-SkipAgentIdentities)" -ForegroundColor Yellow
    Write-Host "   Blueprints are visible in Entra → Agent ID → Agent registry" -ForegroundColor DarkGray
    Write-Host ""
} else {
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  Phase 5 · Creating Agent Identities" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""

    # Blueprints with secrets can create agent identities
    $blueprintsWithSecrets = $blueprints | Where-Object { $_.Secret }

    if ($DryRun) {
        foreach ($bp in $blueprints) {
            foreach ($agent in $bp.Agents) {
                Write-Host "   🔮 [DRY RUN] Would create agent identity: $($agent.DisplayName)" -ForegroundColor DarkCyan
                Write-Host "      From blueprint: $($bp.DisplayName)" -ForegroundColor DarkGray
            }
        }
        Write-Host ""
    }
    elseif ($blueprintsWithSecrets.Count -eq 0) {
        Write-Host "   ⚠️  No blueprints have secrets — cannot create agent identities." -ForegroundColor Yellow
        Write-Host "      Pre-existing blueprints need secrets added manually." -ForegroundColor DarkGray
        Write-Host "      Or re-run the script after removing existing blueprints." -ForegroundColor DarkGray
        Write-Host ""
    }
    else {
        # Wait for Azure AD propagation (known issue with rapid sequential creation)
        Write-Host "   ⏳ Waiting ${PropagationDelay}s for Azure AD propagation..." -ForegroundColor Yellow
        Start-Sleep -Seconds $PropagationDelay

        $agCreated = 0; $agFailed = 0

        foreach ($bp in $blueprintsWithSecrets) {
            # ── Acquire token using blueprint's client credentials ──
            try {
                Write-Host "   🔐 Authenticating as: $($bp.DisplayName)..." -ForegroundColor DarkCyan

                $tokenBody = @{
                    client_id     = $bp.AppId
                    scope         = "https://graph.microsoft.com/.default"
                    client_secret = $bp.Secret
                    grant_type    = "client_credentials"
                }

                $tokenResp = Invoke-WithRetry -Operation "Get token for '$($bp.DisplayName)'" -InitialDelay 10 -ScriptBlock {
                    Invoke-RestMethod -Method POST `
                        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
                        -ContentType "application/x-www-form-urlencoded" `
                        -Body $tokenBody
                }

                $bpToken = $tokenResp.access_token
                Write-Host "   ✅ Authenticated" -ForegroundColor Green

                # ── Create each agent identity from this blueprint ──
                foreach ($agent in $bp.Agents) {
                    try {
                        $agentBody = @{
                            "displayName"              = $agent.DisplayName
                            "agentIdentityBlueprintId" = $bp.AppId
                            "sponsors@odata.bind"      = @("https://graph.microsoft.com/v1.0/users/$sponsorId")
                        } | ConvertTo-Json -Depth 5

                        $agentResp = Invoke-WithRetry -Operation "Create agent '$($agent.DisplayName)'" -InitialDelay 10 -ScriptBlock {
                            Invoke-RestMethod -Method POST `
                                -Uri "https://graph.microsoft.com/beta/serviceprincipals/Microsoft.Graph.AgentIdentity" `
                                -Headers @{
                                    "Authorization" = "Bearer $bpToken"
                                    "Content-Type"  = "application/json"
                                    "OData-Version" = "4.0"
                                } `
                                -Body $agentBody
                        }

                        Write-Host "   ✅ Agent created: $($agent.DisplayName)" -ForegroundColor Green
                        Write-Host "      Blueprint: $($bp.DisplayName)" -ForegroundColor Gray
                        Write-Host "      Agent ID:  $($agentResp.id)" -ForegroundColor Gray
                        Write-Host ""
                        $agCreated++

                        Start-Sleep -Seconds 3
                    }
                    catch {
                        Write-Host "   ❌ Failed to create agent: $($agent.DisplayName)" -ForegroundColor Red
                        Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
                        Write-Host ""
                        $agFailed++
                    }
                }
            }
            catch {
                Write-Host "   ❌ Authentication failed for: $($bp.DisplayName)" -ForegroundColor Red
                Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "      Agent identities for this blueprint will be skipped." -ForegroundColor DarkGray
                Write-Host ""
                $agFailed += $bp.Agents.Count
            }
        }

        Write-Host "  📊 Agent Identities: ✅ $agCreated created  ❌ $agFailed failed" -ForegroundColor Cyan
        Write-Host ""
    }
}

# ═══════════════════════════════════════════════════════════════
#  Summary
# ═══════════════════════════════════════════════════════════════
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🏰  Hogwarts Agent ID — Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "  ⚠️  DRY RUN — no changes were made" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "  Blueprints (Agent Registry):" -ForegroundColor White
foreach ($bp in $blueprints) {
    $status = if ($bp.IsNew) { "✅" } else { "⏭️" }
    Write-Host "    $status $($bp.DisplayName)"
    if (-not $DryRun -and $bp.AppId -ne "<generated>") {
        Write-Host "       AppId: $($bp.AppId)" -ForegroundColor DarkGray
    }
    foreach ($agent in $bp.Agents) {
        Write-Host "       → $($agent.DisplayName)" -ForegroundColor Gray
    }
}

# Display secrets (shown only once!)
$withSecrets = $blueprints | Where-Object { $_.Secret }
if ($withSecrets.Count -gt 0) {
    Write-Host ""
    Write-Host "  ⚠️  CLIENT SECRETS — save now, shown only once!" -ForegroundColor Red
    Write-Host "  ─────────────────────────────────────────────" -ForegroundColor DarkRed
    foreach ($bp in $withSecrets) {
        Write-Host "    $($bp.DisplayName)" -ForegroundColor Yellow
        Write-Host "      AppId:  $($bp.AppId)" -ForegroundColor Gray
        Write-Host "      Secret: $($bp.Secret)" -ForegroundColor Yellow
    }
    Write-Host "  ─────────────────────────────────────────────" -ForegroundColor DarkRed
}

Write-Host ""
Write-Host "  📍 View in Entra admin center:" -ForegroundColor Cyan
Write-Host "     Agent identities → https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AllAgents.MenuView" -ForegroundColor Blue
Write-Host "     Agent registry   → https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/AllAgents.MenuView/~/agentRegistry" -ForegroundColor Blue
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
#  Disconnect
# ═══════════════════════════════════════════════════════════════
if (-not $DryRun) {
    Disconnect-MgGraph | Out-Null
    Write-Host "  Disconnected from Microsoft Graph" -ForegroundColor Gray
}
Write-Host ""
