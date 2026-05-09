# IAC - O365 - BLOCK - NonWorkingHours Policy Documentation

**Generated:** January 27, 2026
**Source:** /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccess/IAC - O365 - BLOCK - NonWorkingHours.json

---

## Overview

This document provides detailed documentation for the **IAC - O365 - BLOCK - NonWorkingHours** Conditional Access policy. This policy uses **preview features** from the Microsoft Graph beta API to implement time-based access control.

---

## Policy Details

### IAC - O365 - BLOCK - NonWorkingHours

**Purpose:** Blocks access to Office 365 applications outside of working hours (Monday-Friday, 9 AM - 5 PM UTC). This time-based Conditional Access policy uses preview features to restrict access during non-business hours for enhanced security.

**State:** `enabled`

**Policy ID:** `8b6e642a-8d67-4111-9100-88dcf19a66c3`

**Created:** January 27, 2026 01:09:53 UTC  
**Modified:** January 28, 2026 01:11:23 UTC

---

## ⚠️ Important Notes

### Preview Features
- This policy uses the **`times`** condition, which is a **preview feature**
- Requires the **Microsoft Graph beta API** endpoint for backup and restore operations
- API Endpoint: `https://graph.microsoft.com/beta/identity/conditionalAccess/policies`
- Standard v1.0 endpoint will **not** support this policy

### Restore Requirements
When restoring this policy, ensure your script uses the beta endpoint:
```powershell
Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies" -Method POST -Body $policyBody
```

---

## Policy Configuration

#### Assignments

**Include Users:**
- User ID: `274c4644-56e5-4ce1-8f30-13457b94c6e5`

**Exclude Groups:**
- Group ID: `96437e0d-3d7c-4e28-b9bf-0fa68eabbff7` (Likely on-call/after-hours exception group)

**Include Roles:** None

**Exclude Roles:** None

#### Conditions

##### Applications
**Include Applications:**
- **Office 365** (All O365 apps)

**Exclude Applications:** None

**Application Filter:** Not configured

##### Time Restrictions (Preview Feature)

**Include Days:**
- **Days of Week:** Monday, Tuesday, Wednesday, Thursday, Friday
- **Time Zone:** UTC
- **All Day:** No
- **Start Time:** 09:00:00
- **End Time:** 17:00:00

**Behavior:** Policy blocks access **outside** of these times (i.e., blocks during non-working hours)

**Include All Times:** No

**Exclude Range:** Not configured

**Include Range:** Not configured

**Exclude Days:** Not configured

##### Client App Types
- all

##### Platforms
Not configured

##### Locations
Not configured

##### User Risk Levels
Not configured

##### Sign-in Risk Levels
Not configured

##### Devices
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- **block**

**Built-in Controls:**
- Block access

**Custom Authentication Factors:** None

**Terms of Use:** None

**Authentication Strength:** Not configured

#### Session Controls

None

---

## Business Logic

### How It Works

1. **Working Hours Definition**
   - Monday through Friday
   - 9:00 AM to 5:00 PM (17:00)
   - Time Zone: UTC

2. **Blocking Behavior**
   - Access to Office 365 is **blocked** when current time is **outside** working hours
   - Weekends (Saturday & Sunday): Blocked all day
   - Weeknights (after 5 PM): Blocked
   - Early mornings (before 9 AM): Blocked

3. **Exception Handling**
   - Users in the excluded group can access O365 anytime
   - Recommended for IT support, on-call staff, executives, or global teams

### Use Cases

- **Reduce After-Hours Security Risks:** Prevent compromised accounts from being used outside business hours
- **Compliance Requirements:** Meet regulatory requirements for access restrictions
- **Cost Management:** Limit usage to business hours for certain user groups
- **Geographic Time Zone Management:** Combine with other policies for multi-region organizations

### Recommendations

1. **Time Zone Adjustment**
   - Current setting: UTC
   - Consider adjusting to your organization's primary time zone
   - For multi-region orgs, create separate policies per region

2. **Exception Groups**
   - Create dedicated security groups for:
     - IT Support (24/7 access needed)
     - On-call staff
     - Executive team
     - Global teams in different time zones
   - Add these groups to the policy exclusion list

3. **Testing Strategy**
   - Start with policy in **Report-Only** mode
   - Monitor sign-in logs for 2-4 weeks
   - Identify legitimate after-hours access patterns
   - Add necessary exclusions before enabling

4. **User Communication**
   - Notify users before enabling this policy
   - Explain working hours access restrictions
   - Provide process for requesting exceptions
   - Document emergency access procedures

---

## JSON Configuration

```json
{
  "id": "8b6e642a-8d67-4111-9100-88dcf19a66c3",
  "displayName": "IAC - O365 - BLOCK - NonWorkingHours",
  "state": "enabled",
  "createdDateTime": "2026-01-27T01:09:53.5646252Z",
  "modifiedDateTime": "2026-01-28T01:11:23.7158106Z",
  "templateId": null,
  "conditions": {
    "times": {
      "includeDays": {
        "timeZone": "UTC",
        "daysOfWeek": [
          "monday",
          "tuesday",
          "wednesday",
          "thursday",
          "friday"
        ],
        "allDay": false,
        "startTime": "09:00:00",
        "endTime": "17:00:00"
      },
      "includeAllTimes": false,
      "excludeRange": null,
      "includeRange": null,
      "excludeDays": null
    },
    "applications": {
      "includeApplications": [
        "Office365"
      ],
      "excludeApplications": [],
      "includeUserActions": [],
      "applicationFilter": null,
      "includeAuthenticationContextClassReferences": []
    },
    "users": {
      "includeUsers": [
        "274c4644-56e5-4ce1-8f30-13457b94c6e5"
      ],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGroups": [
        "96437e0d-3d7c-4e28-b9bf-0fa68eabbff7"
      ],
      "includeRoles": [],
      "excludeRoles": [],
      "includeGuestsOrExternalUsers": null,
      "excludeGuestsOrExternalUsers": null
    },
    "clientAppTypes": [
      "all"
    ],
    "platforms": null,
    "locations": null,
    "clientApplications": null,
    "devices": null,
    "deviceStates": null,
    "userRiskLevels": [],
    "signInRiskLevels": []
  },
  "grantControls": {
    "operator": "OR",
    "builtInControls": [
      "block"
    ],
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "authenticationStrength": null
  },
  "sessionControls": null,
  "partialEnablementStrategy": null,
  "deletedDateTime": null
}
```

---

## Troubleshooting

### Common Issues

**1. Policy Not Appearing in List**
- **Cause:** Using v1.0 Graph API endpoint
- **Solution:** Use beta endpoint: `/beta/identity/conditionalAccess/policies`

**2. Restore Fails with "Unknown Property 'times'"**
- **Cause:** Script using v1.0 endpoint
- **Solution:** Update script to use beta endpoint for all CA policy operations

**3. Users Blocked During Working Hours**
- **Cause:** Time zone mismatch
- **Solution:** Verify UTC offset and adjust time zone in policy configuration

**4. Legitimate After-Hours Users Blocked**
- **Cause:** Missing from exclusion group
- **Solution:** Add user/group to the excluded groups list

### Verification Steps

```powershell
# Verify policy exists (requires beta endpoint)
Connect-MgGraph -Scopes 'Policy.Read.All'
$policy = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/8b6e642a-8d67-4111-9100-88dcf19a66c3" -Method GET
$policy.displayName
$policy.state
$policy.conditions.times

# Check exclusion group members
$groupId = "96437e0d-3d7c-4e28-b9bf-0fa68eabbff7"
Get-MgGroupMember -GroupId $groupId | Select-Object Id, DisplayName, UserPrincipalName
```

---

## Related Documentation

- [Microsoft Graph API Beta - Conditional Access](https://learn.microsoft.com/graph/api/resources/conditionalaccesspolicy?view=graph-rest-beta)
- [Time-based Conditional Access (Preview)](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-conditions#times-preview)
- [IAC Entra Policies Documentation](../IAC-Entra-Policies-Documentation.md)

---

## Change Log

| Date | Change | Modified By |
|------|--------|-------------|
| 2026-01-27 | Policy created with time-based restrictions | System |
| 2026-01-28 | Policy modified (exclusion group adjusted) | Admin |
| 2026-01-27 | Documentation created | GitHub Copilot |

---

**Last Updated:** January 27, 2026  
**Backup Location:** `/Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON/ConditionalAccess/IAC - O365 - BLOCK - NonWorkingHours.json`  
**Restore Script:** `recreate-iac-entra-policies.ps1` (Ensure beta endpoint is configured)
