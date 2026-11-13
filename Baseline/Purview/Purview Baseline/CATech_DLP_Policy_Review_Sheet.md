# CAT DLP policies: final list

Every description starts with "Conditionalaccess.tech DLP". The shared SIT list is: Credit Card Number, U.S. Bank Account Number, ABA Routing Number, SWIFT Code, International Banking Account Number (IBAN), U.S. Social Security Number (SSN), plus any user-defined SITs.

## Summary

| # | Policy | Designed for | Locations | Based on | License | How it gets created |
|---|---|---|---|---|---|---|
| 1 | CAT - DLP - M365 - Block Sensitive Content | Stops financial, SSN and user-defined data from leaving by email or file sharing | Exchange, SharePoint, OneDrive | SIT | E3 / Business Premium | Already built by hand |
| 2 | CAT - DLP - M365 - Block External - Restricted | Stops Restricted - Internal labeled content from going to external recipients, by email or file sharing | Exchange, SharePoint, OneDrive | Label | E3 / Business Premium | Already built by hand |
| 3 | CAT - DLP - TEAMS - Block Sensitive Content | Stops sensitive data typed into Teams chat or channel messages shared externally | Teams | SIT | E5 | Script |
| 4 | CAT - DLP - D - Block Sensitive Content | Stops sensitive files being copied to USB or network shares from onboarded devices; audits printing | Devices | SIT | E5 + onboarding | Script |
| 5 | CAT - DLP - M365 - Block External - Confidential | Stops Confidential - Internal / Confidential - Reporting labeled content from going to external recipients, by email or file sharing | Exchange, SharePoint, OneDrive | Label | E3 / Business Premium | Script (optional) |
| 6 | CAT - DLP - COPILOT - Block Restricted Content | Stops Copilot from processing Restricted labeled files and emails | Copilot (preview) | Label | E5 + Copilot license | Script (optional) |

**Teams (#3) and Devices (#4) stay separate.** Learn says that with multiple locations only the conditions common to all of them are available, and "Content is shared from Microsoft 365" (the external-recipient scope) is a Teams condition but not an Endpoint one. A combined policy would lose the external scope on Teams.

## Replaced or dropped (not created)

| Old script policy | What happened |
|---|---|
| CAT - DLP - EXO - Block Sensitive Content | Replaced by #1 (the SIT policy, Exchange part) |
| CAT - DLP - SPO - Block Sensitive Content | Replaced by #1 (the SIT policy, SharePoint and OneDrive part) |
| CAT - DLP - SPO - Block External Share - Restricted | Replaced by #2 (the label policy) |
| CAT - DLP - SPO - Block External Share - Confidential | Replaced by #5 (script) |
| CAT - DLP - EXO - Block Auto-Forward - Sensitive Content | Dropped. #1 already blocks external sends of that content; Inbox-rule forwarding is controlled by the outbound spam policy ("Automatic forwarding rules" = Off) |

Not in this list: the other policies already in your tenant (for example Confidential EXO at priority 3, the Endpoint policies at priority 1 and 2, the Copilot default prompt policy). The old `CAT - DLP - EXO - Block External Send - Restricted Internal` should be retired once #2 is verified, so they don't double-match.

---

## 1. CAT - DLP - M365 - Block Sensitive Content (already built)
- **Designed for:** blocking sensitive financial, SSN and user-defined data from going to people outside the organization, whether by email or by file sharing. Also covers files shared through Teams, which are stored in SharePoint and OneDrive.
- **Locations:** Exchange, SharePoint, OneDrive.
- **Condition:** Content contains any of the shared SITs AND shared with people outside my organization.
- **Action:** Block external delivery or access. Internal users are not affected.
- **Description:** Conditionalaccess.tech DLP Detects financial, Social Security number and user-defined sensitive information types (SITs) in Exchange Online email, SharePoint and OneDrive, and blocks delivery or access for people outside the organization. Internal users are not affected. Starts in simulation; promote to enforce after baseline review.
- **Confirm:** the SIT list includes all six SITs, including SSN.

## 2. CAT - DLP - M365 - Block External - Restricted (already built)
- **Designed for:** blocking content labeled Restricted - Internal from reaching external recipients.
- **Locations:** Exchange, SharePoint, OneDrive.
- **Condition:** Sensitivity label Restricted - Internal AND shared with people outside my organization.
- **Action:** Block users from receiving email or accessing shared SharePoint and OneDrive files. External recipients only.
- **Description:** Conditionalaccess.tech DLP Blocks content labeled Restricted - Internal from being sent to or shared with external recipients, by email or through SharePoint and OneDrive. Internal users are not affected.
- **Confirm:** the policy mode, and that the block option is "Block only people outside your organization".

## 3. CAT - DLP - TEAMS - Block Sensitive Content (script)
- **Designed for:** sensitive data typed into Teams chat and channel messages. Message text only; files shared in Teams are covered by #1.
- **Locations:** Teams chat and channel messages.
- **Condition:** Content contains any of the shared SITs AND shared with people outside my organization. Teams cannot use label conditions.
- **Action:** Block messages shared outside the organization. Notify owner. Alert.
- **Description:** Conditionalaccess.tech DLP Detects financial, Social Security number and user-defined sensitive information types (SITs) in Teams chat and channel message text and blocks messages shared outside the organization. Message text only; files shared in Teams are covered by the SPO policy. Requires E5-level licensing. Starts in simulation.
- **Skip with:** `-SkipTeams`. **Untested:** the AccessScope condition on a Teams-only policy.

## 4. CAT - DLP - D - Block Sensitive Content (script)
- **Designed for:** sensitive files leaving onboarded devices by USB or network share.
- **Locations:** Devices (Endpoint DLP), all onboarded devices.
- **Condition:** Content contains any of the shared SITs.
- **Action:** Block copy to removable media; block copy to network share; audit print. Notify owner. Alert.
- **Description:** Conditionalaccess.tech DLP Detects financial, Social Security number and user-defined sensitive information types (SITs) on onboarded devices; blocks copy to removable media and network shares and audits printing. Paste and AI uploads are covered by the existing D policies. Requires E5-level licensing and device onboarding. Starts in simulation.
- **Skip with:** `-SkipEndpoint`. **Untested:** notify-user value "Owner" on an Endpoint rule.

## 5. CAT - DLP - M365 - Block External - Confidential (script, optional)
- **Designed for:** Confidential - Internal / Confidential - Reporting labeled content going to external recipients. Replaces the existing Confidential EXO policy (priority 3) and the old script SPO Confidential policy, the same way #2 did for Restricted. Confidential - Third Parties is deliberately excluded: it's the user-defined-recipient label meant for controlled external sharing, so blocking all external sharing of it would defeat its purpose.
- **Locations:** Exchange, SharePoint, OneDrive.
- **Condition:** Sensitivity label Confidential - Internal or Confidential - Reporting AND shared with people outside my organization.
- **Action:** Block users from receiving email or accessing shared files; block only people outside the organization.
- **Description:** Conditionalaccess.tech DLP Blocks content labeled Confidential - Internal, Confidential - Reporting from being sent to or shared with external recipients, by email or through SharePoint and OneDrive. Internal users are not affected.
- **Skip with:** `-SkipConfidential`. **Untested:** the label condition and `BlockAccessScope PerUser` on a policy that includes Exchange. Keep the old Confidential EXO policy until this one is verified, then retire it so they don't double-match.

## 6. CAT - DLP - COPILOT - Block Restricted Content (script, optional)
- **Designed for:** keeping Restricted labeled files and emails out of Copilot responses. This is not a prompt block; SIT prompt blocking is the Microsoft default Copilot policy.
- **Locations:** Microsoft 365 Copilot and Copilot Chat (preview). Cannot be combined with other locations.
- **Condition:** Sensitivity label Restricted - Internal or Restricted - Third Parties.
- **Action:** Copilot does not process the labeled content.
- **Description:** Conditionalaccess.tech DLP Stops Microsoft 365 Copilot and Copilot Chat from processing files and emails labeled Restricted - Internal, Restricted - Third Parties. Label rule only; SIT prompt blocking is the Microsoft default Copilot policy. Requires E5-level licensing and a Microsoft 365 Copilot license. Starts in simulation.
- **Skip with:** `-SkipCopilotLabelBlock`. **Untested:** the AdvancedRule JSON for the label condition. Preview feature.

---

## How the manual policies are handled in the script
Policies #1 and #2 are written into `New-CATechDlpPolicies.ps1` but switched off. A normal run prints "built by hand, not run" for each and never touches them.
- `-IncludeManualPolicies` turns on #1 and #2 (only for rebuilding in another tenant; an existing name is still skipped).
- #5 (Confidential) is a normal script-created policy like #3, #4 and #6 - it runs by default and is skipped only with `-SkipConfidential`.
- Descriptions and rule names in the script match what is written above.

## Before running `-Create`
1. Run the script without `-Create` first (dry run).
2. After creating, open each rule in the portal and confirm the conditions and actions. The label rules, the Teams condition and the Endpoint notify value are untested.
3. Start each policy in simulation, then turn it On: `Set-DlpCompliancePolicy -Identity "<name>" -Mode Enable`.
