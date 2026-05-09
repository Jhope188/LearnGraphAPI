# Simulate REAL M365 User Activity for Copilot Assessment (v3)
# ─────────────────────────────────────────────────────────────
# This script generates ACTUAL content across licensed users so
# activity appears in M365 Usage Reports & Copilot readiness.
#
# HOW IT WORKS (Delegated Auth):
#   The signed-in admin sends emails TO and creates meetings WITH
#   all other licensed users. This generates:
#     • SENDER activity for the admin (Exchange, OneDrive, Calendar)
#     • RECIPIENT activity for each user (receiving mail = Exchange active)
#     • ATTENDEE activity for each user (meeting invite = Calendar active)
#     • Teams activity via channel messages
#
# CONNECT FIRST, then run this script in the same PowerShell session:
#   Connect-MgGraph -TenantId '<your-tenant-id>' -Scopes @(
#       'User.Read.All','Mail.Send','Mail.ReadWrite','Files.ReadWrite.All',
#       'Calendars.ReadWrite','Group.ReadWrite.All','TeamMember.Read.All',
#       'Channel.ReadBasic.All','ChannelMessage.Send'
#   ) -NoWelcome
#
# Author: Magical IT Department
# Date: March 5, 2026

param(
    [Parameter(Mandatory)]
    [string]$TenantId,
    [int]$MaxRecipients = 20,
    [int]$EmailsPerRecipient = 2,
    [switch]$WhatIf,
    [switch]$KeepConnection
)

Write-Host ""
Write-Host "🎯 Microsoft 365 Activity Simulator v3 — Real Content Generation" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# CHECK CONNECTION
# ═══════════════════════════════════════════════════════════════
Write-Host "🔗 Checking Microsoft Graph connection..." -ForegroundColor Yellow
$context = Get-MgContext

if (-not $context) {
    Write-Host ""
    Write-Host "❌ No active Graph session. Please connect first:" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Connect-MgGraph -TenantId '$TenantId' -Scopes @(" -ForegroundColor White
    Write-Host "       'User.Read.All','Mail.Send','Mail.ReadWrite'," -ForegroundColor White
    Write-Host "       'Files.ReadWrite.All','Calendars.ReadWrite'," -ForegroundColor White
    Write-Host "       'Group.ReadWrite.All','TeamMember.Read.All'," -ForegroundColor White
    Write-Host "       'Channel.ReadBasic.All','ChannelMessage.Send'" -ForegroundColor White
    Write-Host "   ) -NoWelcome" -ForegroundColor White
    Write-Host ""
    Write-Host "   Then re-run this script." -ForegroundColor White
    Write-Host ""
    return
}

Write-Host "✅ Connected to tenant: $($context.TenantId)" -ForegroundColor Green
Write-Host "   Signed in as: $($context.Account)" -ForegroundColor Gray

# Identify the signed-in user (this is who will perform all actions)
$me = Get-MgUser -Filter "userPrincipalName eq '$($context.Account)'" -Property Id, DisplayName, Mail, UserPrincipalName
if (-not $me) {
    $me = Get-MgUser -UserId $context.Account -Property Id, DisplayName, Mail, UserPrincipalName -ErrorAction SilentlyContinue
}
if (-not $me) {
    Write-Host "❌ Could not identify signed-in user. Exiting." -ForegroundColor Red
    return
}
Write-Host "   Actor: $($me.DisplayName) ($($me.Mail))" -ForegroundColor Gray
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# GET LICENSED USERS (all recipients)
# ═══════════════════════════════════════════════════════════════
Write-Host "👥 Finding licensed, active users..." -ForegroundColor Yellow

$allUsers = Get-MgUser -Filter "accountEnabled eq true" -All `
    -Property Id, DisplayName, UserPrincipalName, Mail, AssignedLicenses, UserType |
    Where-Object {
        $_.UserType -eq "Member" -and
        $_.AssignedLicenses.Count -gt 0 -and
        $_.UserPrincipalName -notlike "*#EXT#*" -and
        $_.Mail -ne $null
    }

if ($allUsers.Count -eq 0) {
    Write-Host "❌ No licensed users found. Exiting." -ForegroundColor Red
    return
}

# Separate: other users (recipients) vs the admin
$recipients = $allUsers | Where-Object { $_.Id -ne $me.Id }
if ($recipients.Count -gt $MaxRecipients) {
    $recipients = $recipients | Get-Random -Count $MaxRecipients
}

Write-Host "✅ Found $($allUsers.Count) licensed users total" -ForegroundColor Green
Write-Host "   🧙 Sender (you): $($me.DisplayName)" -ForegroundColor White
Write-Host "   📬 Recipients: $($recipients.Count) users" -ForegroundColor White
$recipients | ForEach-Object {
    Write-Host "      • $($_.DisplayName) ($($_.Mail))" -ForegroundColor Gray
}

if ($recipients.Count -eq 0) {
    Write-Host ""
    Write-Host "⚠️  No other licensed users to send to! Only you are licensed." -ForegroundColor Yellow
    Write-Host "   Assign M365 licenses to more users in the admin center, then re-run." -ForegroundColor Yellow
    Write-Host ""
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# TEMPLATE DATA (Harry Potter themed!)
# ═══════════════════════════════════════════════════════════════
$emailTemplates = @(
    @{
        Subject = "Reminder: Quidditch Practice Schedule"
        Body    = "<h3>🏟️ Quidditch Practice</h3><p>Just a reminder that Quidditch practice has been moved to Thursday evening. Please make sure your brooms are serviced and ready. New Nimbus 3000s have arrived for the reserve team.</p><p>See you on the pitch!</p>"
    },
    @{
        Subject = "Updated Potion Ingredients Order"
        Body    = "<h3>🧪 Potions Supply Update</h3><p>The latest shipment of lacewing flies and boomslang skin has arrived. Professor Slughorn has confirmed the inventory is now fully stocked for the semester. Please collect your class supplies.</p>"
    },
    @{
        Subject = "Ministry Memo: New Security Protocols"
        Body    = "<h3>🏛️ Ministry of Magic — Internal Memo</h3><p>Following recent events, all Ministry employees must update their Floo Network passwords by end of week. Two-factor authentication via Patronus verification is now mandatory for Level 5 clearance and above.</p>"
    },
    @{
        Subject = "Hogwarts Staff Meeting — Agenda"
        Body    = "<h3>📋 Weekly Staff Meeting</h3><p>Agenda items: 1) O.W.L. exam scheduling, 2) Forbidden Forest boundary updates, 3) New Defence Against the Dark Arts curriculum review, 4) Filch's request for additional chains (denied, again).</p>"
    },
    @{
        Subject = "Library Book Return Notice"
        Body    = "<h3>📚 Hogwarts Library</h3><p>This is an automated reminder that the following books are overdue: <em>Advanced Transfiguration</em>, <em>Moste Potente Potions</em>. Please return them to Madam Pince before penalties are applied.</p>"
    },
    @{
        Subject = "Inter-House Unity Event Planning"
        Body    = "<h3>🏰 Inter-House Collaboration</h3><p>We're organising an inter-house event for next month. Each house will present a magical innovation project. Please coordinate with your Head of House and submit your proposal by Friday.</p>"
    },
    @{
        Subject = "Herbology Greenhouse Schedule Change"
        Body    = "<h3>🌱 Greenhouse Update</h3><p>Due to an unexpected outbreak of Venomous Tentacula in Greenhouse 3, all Herbology classes will be held in Greenhouse 1 until further notice. Ear protection recommended.</p>"
    },
    @{
        Subject = "Owl Post Delivery Delays"
        Body    = "<h3>🦉 Owl Post Notice</h3><p>Please be advised that owl post deliveries may be delayed this week due to strong northerly winds. Priority parcels will still be dispatched via eagle owl.</p>"
    },
    @{
        Subject = "Marauder's Map Update — Restricted Areas"
        Body    = "<h3>🗺️ Marauder's Map Notice</h3><p>Sections B7 through D12 of the map have been updated to reflect the new corridor changes. The Room of Requirement entrance has shifted again — please verify before use.</p>"
    },
    @{
        Subject = "Patronus Training — Advanced Workshop"
        Body    = "<h3>🦌 Patronus Workshop</h3><p>An advanced Patronus training workshop will be held this Saturday in the Great Hall. Please bring your happiest memory. Chocolate will be provided for recovery. Professor Lupin has kindly agreed to supervise.</p>"
    }
)

$meetingTemplates = @(
    "O.W.L. Exam Preparation Review",
    "Quidditch League Planning Session",
    "Inter-House Prefect Meeting",
    "Defence Against the Dark Arts — Curriculum Update",
    "Ministry Liaison — Quarterly Sync",
    "Hogwarts Budget Review — Q2",
    "Magical Creature Care Coordination",
    "Staff Wellbeing Check-in",
    "Potion Safety Committee",
    "Triwizard Tournament Logistics"
)

$fileTemplates = @(
    @{
        Name    = "Quidditch-Match-Report-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        Content = "Quidditch Match Report`nDate: $(Get-Date -Format 'dd MMMM yyyy')`nGryffindor vs Slytherin`nFinal Score: 210 - 180`nSnitch caught by: Seeker at minute 47`nNotable plays: Outstanding Bludger defence by Beaters"
    },
    @{
        Name    = "Potion-Recipe-Notes-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        Content = "Polyjuice Potion Notes`nBrewing Time: 1 month`nKey Ingredients: Lacewing flies (stewed 21 days), Leeches, Powdered Bicorn Horn`nCritical Step: Must add the target's hair LAST`nNote: Tastes different for everyone."
    },
    @{
        Name    = "Staff-Meeting-Notes-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        Content = "Staff Meeting Notes — $(Get-Date -Format 'dd/MM/yyyy')`nAttendees: Dumbledore, McGonagall, Snape, Flitwick, Sprout`nActions: Review N.E.W.T. pass rates, Update ward boundaries`nNext: $(Get-Date (Get-Date).AddDays(7) -Format 'dd/MM/yyyy')"
    },
    @{
        Name    = "Security-Patrol-Log-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        Content = "Hogwarts Security Log`nDate: $(Get-Date -Format 'dd MMMM yyyy')`nPatrol: 3rd floor corridor — all clear`nFilch reported: Peeves near Moaning Myrtle's bathroom`nPrefect note: Students out past curfew near the Astronomy Tower"
    },
    @{
        Name    = "Hogwarts-Budget-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        Content = "Hogwarts Annual Budget Summary`nOwl Feed: 2,400 Galleons`nBroomstick Maintenance: 850 Galleons`nPotion Supplies: 3,200 Galleons`nLibrary Acquisitions: 1,100 Galleons`nCabin Repairs (Hagrid): 200 Galleons"
    }
)

$teamsMessages = @(
    "📋 Quick update: The project timeline has been updated. Please review the latest version in the shared folder.",
    "🎯 Reminder: Please submit your weekly reports by end of day Friday. Late submissions will be chased by owl.",
    "✅ Great progress on the quarterly review! Thanks everyone for your contributions.",
    "📅 Next team meeting moved to Thursday 2pm. Agenda shared via owl post. Bring your wands — practical session.",
    "🏆 Congratulations to the team on exceeding our targets this month! Butterbeer on me at the Three Broomsticks.",
    "📝 I've uploaded the draft proposal to the shared drive. Please review and leave comments by Wednesday.",
    "⚡ Heads up: System maintenance this weekend. Floo Network offline Saturday 2am-6am.",
    "🤝 Welcome to our new team members who joined this week! Looking forward to working with you all."
)

# ═══════════════════════════════════════════════════════════════
# RUN SIMULATION
# ═══════════════════════════════════════════════════════════════

$stats = @{
    EmailsSent     = 0
    EmailsRead     = 0
    FilesCreated   = 0
    EventsCreated  = 0
    TeamsMessages  = 0
    Errors         = 0
}

Write-Host "🚀 Starting REAL activity generation..." -ForegroundColor Yellow
if ($WhatIf) { Write-Host "   ⚠️  WhatIf mode — no changes will be made" -ForegroundColor Yellow }
Write-Host ""

# ─────────────────────────────────────────────────────────────
# PHASE 1: SEND EMAILS (From signed-in user → each recipient)
#   Generates: Exchange SEND activity (you) + RECEIVE activity (them)
# ─────────────────────────────────────────────────────────────
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "📧 Phase 1: Sending emails FROM $($me.DisplayName) TO recipients..." -ForegroundColor Cyan
Write-Host "   (Each received email = Exchange activity for that user)" -ForegroundColor DarkGray
Write-Host ""

foreach ($recipient in $recipients) {
    Write-Host "   📬 → $($recipient.DisplayName)" -ForegroundColor White

    for ($i = 0; $i -lt $EmailsPerRecipient; $i++) {
        $template = $emailTemplates | Get-Random
        $mailBody = @{
            Message = @{
                Subject = "$($template.Subject) [$((Get-Date).ToString('HH:mm'))]"
                Body    = @{
                    ContentType = "HTML"
                    Content     = $template.Body
                }
                ToRecipients = @(
                    @{ EmailAddress = @{ Address = $recipient.Mail } }
                )
            }
            SaveToSentItems = $true
        }

        if (-not $WhatIf) {
            try {
                Send-MgUserMail -UserId $me.Id -BodyParameter $mailBody -ErrorAction Stop
                Write-Host "      ✅ '$($template.Subject)'" -ForegroundColor Green
                $stats.EmailsSent++
            }
            catch {
                Write-Host "      ⚠️  $($_.Exception.Message)" -ForegroundColor Yellow
                $stats.Errors++
            }
        } else {
            Write-Host "      🔸 [WhatIf] Would send: '$($template.Subject)'" -ForegroundColor DarkYellow
        }
    }
    Start-Sleep -Milliseconds 500
}
Write-Host ""

# ─────────────────────────────────────────────────────────────
# PHASE 2: READ & INTERACT WITH MAIL (signed-in user's mailbox)
#   Generates: Exchange READ activity for you
# ─────────────────────────────────────────────────────────────
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "📬 Phase 2: Reading & marking mail in $($me.DisplayName)'s mailbox..." -ForegroundColor Cyan
Write-Host ""

if (-not $WhatIf) {
    try {
        $messages = Get-MgUserMessage -UserId $me.Id -Top 10 -OrderBy "receivedDateTime desc" -ErrorAction Stop
        $unreadMsgs = $messages | Where-Object { $_.IsRead -eq $false }

        if ($unreadMsgs) {
            $toMark = $unreadMsgs | Select-Object -First 5
            foreach ($msg in $toMark) {
                try {
                    Update-MgUserMessage -UserId $me.Id -MessageId $msg.Id -BodyParameter @{ IsRead = $true } -ErrorAction Stop
                    Write-Host "   ✅ Marked as read: '$($msg.Subject)'" -ForegroundColor Green
                    $stats.EmailsRead++
                } catch {
                    Write-Host "   ⚠️  Could not mark message: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "   ℹ️  No unread messages to mark" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "   ⚠️  Mail read error: $($_.Exception.Message)" -ForegroundColor Yellow
        $stats.Errors++
    }
}
Write-Host ""

# ─────────────────────────────────────────────────────────────
# PHASE 3: CREATE FILES IN ONEDRIVE (signed-in user's drive)
#   Generates: OneDrive/SharePoint activity for you
# ─────────────────────────────────────────────────────────────
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "💾 Phase 3: Creating files in $($me.DisplayName)'s OneDrive..." -ForegroundColor Cyan
Write-Host ""

foreach ($fileTemplate in $fileTemplates) {
    if (-not $WhatIf) {
        try {
            $contentBytes = [System.Text.Encoding]::UTF8.GetBytes($fileTemplate.Content)
            $stream = [System.IO.MemoryStream]::new($contentBytes)
            $uploadUrl = "https://graph.microsoft.com/v1.0/me/drive/root:/$($fileTemplate.Name):/content"
            Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -Body $stream -ContentType "text/plain" -ErrorAction Stop | Out-Null
            $stream.Dispose()
            Write-Host "   ✅ Created: $($fileTemplate.Name)" -ForegroundColor Green
            $stats.FilesCreated++
        }
        catch {
            Write-Host "   ⚠️  OneDrive error: $($_.Exception.Message)" -ForegroundColor Yellow
            $stats.Errors++
        }
    } else {
        Write-Host "   🔸 [WhatIf] Would create: $($fileTemplate.Name)" -ForegroundColor DarkYellow
    }
    Start-Sleep -Milliseconds 300
}
Write-Host ""

# ─────────────────────────────────────────────────────────────
# PHASE 4: CREATE CALENDAR EVENTS (on your calendar, invite others)
#   Generates: Calendar activity for YOU + all attendees receive invites
#   (Meeting invites = Calendar/Exchange activity for recipients)
# ─────────────────────────────────────────────────────────────
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "📅 Phase 4: Creating calendar events with attendees..." -ForegroundColor Cyan
Write-Host "   (Each invite = Calendar activity for the attendee)" -ForegroundColor DarkGray
Write-Host ""

$meetingsToCreate = $meetingTemplates | Get-Random -Count ([math]::Min(4, $meetingTemplates.Count))

foreach ($meetingSubject in $meetingsToCreate) {
    $startTime = (Get-Date).AddHours((Get-Random -Minimum 2 -Maximum 168))
    $endTime = $startTime.AddMinutes(30)

    # Pick 2-3 random attendees per meeting
    $attendeeCount = [math]::Min((Get-Random -Minimum 2 -Maximum 4), $recipients.Count)
    $meetingAttendees = if ($recipients.Count -gt 0) { $recipients | Get-Random -Count $attendeeCount } else { @() }

    $attendeeList = @()
    foreach ($att in $meetingAttendees) {
        $attendeeList += @{
            EmailAddress = @{ Address = $att.Mail; Name = $att.DisplayName }
            Type         = "required"
        }
    }

    $eventBody = @{
        Subject   = $meetingSubject
        Start     = @{
            DateTime = $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
            TimeZone = "UTC"
        }
        End       = @{
            DateTime = $endTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss")
            TimeZone = "UTC"
        }
        Attendees = $attendeeList
        Body      = @{
            ContentType = "HTML"
            Content     = "<p>📋 $meetingSubject — Auto-generated for M365 activity simulation.</p>"
        }
        IsOnlineMeeting       = $true
        OnlineMeetingProvider = "teamsForBusiness"
    }

    if (-not $WhatIf) {
        try {
            New-MgUserEvent -UserId $me.Id -BodyParameter $eventBody -ErrorAction Stop | Out-Null
            $attendeeNames = ($meetingAttendees | ForEach-Object { $_.DisplayName }) -join ", "
            Write-Host "   ✅ '$meetingSubject' → Attendees: $attendeeNames" -ForegroundColor Green
            $stats.EventsCreated++
        }
        catch {
            Write-Host "   ⚠️  Calendar error: $($_.Exception.Message)" -ForegroundColor Yellow
            $stats.Errors++
        }
    } else {
        Write-Host "   🔸 [WhatIf] Would create: '$meetingSubject'" -ForegroundColor DarkYellow
    }
    Start-Sleep -Milliseconds 500
}
Write-Host ""

# ─────────────────────────────────────────────────────────────
# PHASE 5: TEAMS CHANNEL MESSAGES
#   Generates: Teams activity for the poster
# ─────────────────────────────────────────────────────────────
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "💬 Phase 5: Posting Teams channel messages..." -ForegroundColor Cyan
Write-Host ""

try {
    $teams = Get-MgGroup -Filter "resourceProvisioningOptions/Any(x:x eq 'Team')" -Top 5 -ErrorAction Stop
    if ($teams) {
        foreach ($team in ($teams | Get-Random -Count ([math]::Min(2, $teams.Count)))) {
            $channels = Get-MgTeamChannel -TeamId $team.Id -ErrorAction Stop
            $generalChannel = $channels | Where-Object { $_.DisplayName -eq "General" } | Select-Object -First 1

            if ($generalChannel) {
                $messagesToPost = $teamsMessages | Get-Random -Count ([math]::Min(2, $teamsMessages.Count))
                foreach ($msg in $messagesToPost) {
                    $messageBody = @{ Body = @{ Content = $msg } }
                    if (-not $WhatIf) {
                        try {
                            New-MgTeamChannelMessage -TeamId $team.Id -ChannelId $generalChannel.Id -BodyParameter $messageBody -ErrorAction Stop | Out-Null
                            $preview = $msg.Substring(0, [math]::Min(55, $msg.Length))
                            Write-Host "   ✅ '$($team.DisplayName) > General': $preview..." -ForegroundColor Green
                            $stats.TeamsMessages++
                        }
                        catch {
                            Write-Host "   ⚠️  Teams error: $($_.Exception.Message)" -ForegroundColor Yellow
                            $stats.Errors++
                        }
                    } else {
                        Write-Host "   🔸 [WhatIf] Would post to '$($team.DisplayName) > General'" -ForegroundColor DarkYellow
                    }
                    Start-Sleep -Seconds 1
                }
            }
        }
    } else {
        Write-Host "   ⚠️  No Teams found in tenant" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ⚠️  Teams access error: $($_.Exception.Message)" -ForegroundColor Yellow
    $stats.Errors++
}
Write-Host ""

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📈 Activity Simulation Complete!" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "   🧙 Sender:              $($me.DisplayName)" -ForegroundColor White
Write-Host "   👥 Recipients:          $($recipients.Count) users" -ForegroundColor White
Write-Host ""
Write-Host "   📧 Emails sent:         $($stats.EmailsSent)" -ForegroundColor Green
Write-Host "   📬 Emails read/marked:  $($stats.EmailsRead)" -ForegroundColor Green
Write-Host "   💾 Files created:       $($stats.FilesCreated)" -ForegroundColor Green
Write-Host "   📅 Events created:      $($stats.EventsCreated)" -ForegroundColor Green
Write-Host "   💬 Teams messages:      $($stats.TeamsMessages)" -ForegroundColor Green
Write-Host "   ❌ Errors:              $($stats.Errors)" -ForegroundColor $(if ($stats.Errors -gt 0) { "Red" } else { "Gray" })
Write-Host ""
$totalActions = $stats.EmailsSent + $stats.EmailsRead + $stats.FilesCreated + $stats.EventsCreated + $stats.TeamsMessages
Write-Host "   📊 Total actions:       $totalActions" -ForegroundColor Yellow
Write-Host ""
Write-Host "📝 Activity generated for each user:" -ForegroundColor White
Write-Host "   • $($me.DisplayName): Exchange (send+read), OneDrive, Calendar, Teams" -ForegroundColor Gray
foreach ($r in $recipients) {
    Write-Host "   • $($r.DisplayName): Exchange (received $EmailsPerRecipient emails + meeting invites)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "⏰ When it appears:" -ForegroundColor White
Write-Host "   • Mailboxes/OneDrive      → immediately" -ForegroundColor Gray
Write-Host "   • Unified Audit Log       → within minutes" -ForegroundColor Gray
Write-Host "   • M365 Admin Usage Reports → 24-48 hours" -ForegroundColor Gray
Write-Host "   • Copilot readiness data   → 48 hours" -ForegroundColor Gray
Write-Host ""

if ($allUsers.Count -lt 5) {
    Write-Host "⚠️  NOTE: Only $($allUsers.Count) licensed users found!" -ForegroundColor Yellow
    Write-Host "   For better Copilot readiness data, assign M365 licenses" -ForegroundColor Yellow
    Write-Host "   to more users in Admin Center → Users → Active Users." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "💡 Tips:" -ForegroundColor Cyan
Write-Host "   • Run daily for 5-7 days to build sustained activity patterns" -ForegroundColor Gray
Write-Host "   • Use -WhatIf to preview without making changes" -ForegroundColor Gray
Write-Host "   • Use -MaxRecipients 20 to increase target users" -ForegroundColor Gray
Write-Host "   • Use -EmailsPerRecipient 3 to send more emails per user" -ForegroundColor Gray
Write-Host "   • Assign licenses to more users for broader coverage" -ForegroundColor Gray
Write-Host ""

if (-not $KeepConnection) {
    Disconnect-MgGraph | Out-Null
    Write-Host "🔌 Disconnected from Microsoft Graph" -ForegroundColor Gray
} else {
    Write-Host "🔗 Connection kept alive (-KeepConnection)" -ForegroundColor Gray
}
