# IAC Entra ID Policy Documentation

**Generated:** January 16, 2026 21:10:25
**Source:** /Users/jon/Desktop/BaslineSetup/IAC-Entra-Policies-JSON

---

## Table of Contents

- [Overview](#overview)
- [Conditional Access Policies](#conditional-access-policies)
- [Named Locations](#named-locations)

---

## Overview

This document provides comprehensive documentation for all IAC (Infrastructure as Code) Conditional Access policies and Named Locations in the tenant. Each policy includes:

- **Purpose**: What the policy does and why it exists
- **State**: Whether the policy is enabled, disabled, or in report-only mode
- **Assignments**: Which users, groups, and roles the policy applies to
- **Conditions**: The circumstances under which the policy is evaluated
- **Controls**: The security requirements enforced by the policy

---

## Conditional Access Policies

### IAC - APP - BLOCK - SharePoint-OneDrive-NonTrustedLocations

**Purpose:** Blocks access from specific geographic locations or countries. Prevents unauthorized access from regions where the organization doesn't operate.

**State:** `disabled`

**Policy ID:** `8ee4b0d5-8daf-4e7e-9302-f718f9eb2208`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- AVD-ExternalUsers
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- **Office 365 SharePoint Online** `(00000003-0000-0ff1-ce00-000000000000)`


##### Platforms


##### Locations
**Include Locations:** All locations
**Exclude Locations:** AllTrusted


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('8ee4b0d5-8daf-4e7e-9302-f718f9eb2208')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "21344a9f-6ef0-4181-970a-15202237ac4b",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "00000003-0000-0ff1-ce00-000000000000"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "locations": {
      "excludeLocations": [
        "AllTrusted"
      ],
      "includeLocations": [
        "All"
      ]
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - APP - BLOCK - SharePoint-OneDrive-NonTrustedLocations",
  "templateId": null
}
```

---

### IAC - APP - SESSION - O365 - Timeoutsettings

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `3836e733-e555-4a7e-ad7d-8ad2d5d6a1f1`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- Office 365


##### Platforms
**Include Platforms:** all
**Exclude Platforms:** android, iOS, macOS, linux


##### Locations


##### Client App Types
- browser

##### Device States
Not configured

#### Grant Controls

None

#### Session Controls

**Application Enforced Restrictions:** Enabled


#### Configuration JSON

```json
{
  "sessionControls": {
    "applicationEnforcedRestrictions": {
      "isEnabled": true
    },
    "secureSignInSession": null,
    "disableResilienceDefaults": null,
    "cloudAppSecurity": null,
    "signInFrequency": null,
    "persistentBrowser": null
  },
  "state": "disabled",
  "grantControls": null,
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "browser"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "locations": null,
    "platforms": {
      "includePlatforms": [
        "all"
      ],
      "excludePlatforms": [
        "android",
        "iOS",
        "macOS",
        "linux"
      ]
    },
    "devices": {
      "deviceFilter": {
        "rule": "device.isCompliant -eq True -and device.trustType -eq \"ServerAD\"",
        "mode": "exclude"
      }
    },
    "insiderRiskLevels": null,
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "Office365"
      ]
    },
    "signInRiskLevels": []
  },
  "displayName": "IAC - APP - SESSION - O365 - Timeoutsettings",
  "templateId": null
}
```

---

### IAC - APP – BLOCK – AVD - Exclude - AllowedAVDUsers

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `c9daf693-95d8-4be9-bba7-02ec159acfd5`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- AVD-ExternalUsers
- AVDUsers


#### Conditions

##### Applications
**Include Applications:**
- `0af06dc6-e4b5-4f28-818e-e78e62d137a5`
- **Azure Virtual Desktop Client** `(9cdead84-a844-4324-93f2-b2e6bb768d07)`


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('c9daf693-95d8-4be9-bba7-02ec159acfd5')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "21344a9f-6ef0-4181-970a-15202237ac4b",
        "0007f38d-c059-4dac-91bf-ed108dda8d02"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "0af06dc6-e4b5-4f28-818e-e78e62d137a5",
        "9cdead84-a844-4324-93f2-b2e6bb768d07"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - APP – BLOCK – AVD - Exclude - AllowedAVDUsers",
  "templateId": null
}
```

---

### IAC - APP – BLOCK – AVD - NonTrustedLocations

**Purpose:** Blocks access from specific geographic locations or countries. Prevents unauthorized access from regions where the organization doesn't operate.

**State:** `disabled`

**Policy ID:** `620fe00f-2446-453f-b1b8-9e739bbaa282`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- AVD-ExternalUsers


#### Conditions

##### Applications
**Include Applications:**
- `0af06dc6-e4b5-4f28-818e-e78e62d137a5`
- **Azure Virtual Desktop Client** `(9cdead84-a844-4324-93f2-b2e6bb768d07)`


##### Platforms


##### Locations
**Include Locations:** All locations
**Exclude Locations:** AllTrusted


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('620fe00f-2446-453f-b1b8-9e739bbaa282')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "21344a9f-6ef0-4181-970a-15202237ac4b"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "0af06dc6-e4b5-4f28-818e-e78e62d137a5",
        "9cdead84-a844-4324-93f2-b2e6bb768d07"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "locations": {
      "excludeLocations": [
        "AllTrusted"
      ],
      "includeLocations": [
        "All"
      ]
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - APP – BLOCK – AVD - NonTrustedLocations",
  "templateId": null
}
```

---

### IAC - GLOBAL - BLOCK - Authentication Transfer

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `e8c3969f-9e28-48b5-b930-fef43c783ded`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('e8c3969f-9e28-48b5-b930-fef43c783ded')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": {
      "transferMethods": "authenticationTransfer"
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL - BLOCK - Authentication Transfer",
  "templateId": null
}
```

---

### IAC - GLOBAL - BLOCK - Device Code Auth Flow

**Purpose:** Blocks the device code authentication flow to prevent unauthorized access. Device code flow can be abused for phishing attacks where attackers trick users into authenticating on their behalf.

**State:** `disabled`

**Policy ID:** `4635c7c6-9fda-4a88-8791-c4353729a220`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('4635c7c6-9fda-4a88-8791-c4353729a220')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": {
      "transferMethods": "deviceCodeFlow"
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL - BLOCK - Device Code Auth Flow",
  "templateId": null
}
```

---

### IAC - GLOBAL - BLOCK - Unsupported Device Platforms

**Purpose:** Blocks sign-ins from unsupported or unmanaged device platforms to reduce security risks. Ensures users only access resources from approved operating systems.

**State:** `disabled`

**Policy ID:** `49fb70f3-7de2-45a3-9263-f2b1f36db351`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms
**Include Platforms:** all
**Exclude Platforms:** android, iOS, windows, macOS


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('49fb70f3-7de2-45a3-9263-f2b1f36db351')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "locations": null,
    "platforms": {
      "includePlatforms": [
        "all"
      ],
      "excludePlatforms": [
        "android",
        "iOS",
        "windows",
        "macOS"
      ]
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL - BLOCK - Unsupported Device Platforms",
  "templateId": null
}
```

---

### IAC - GLOBAL - GRANT - MFA - AllAdmins

**Purpose:** Requires Multi-Factor Authentication for all administrator roles. Provides additional security for privileged accounts that have elevated access.

**State:** `disabled`

**Policy ID:** `0a906da3-3cbe-4227-a036-7fb9afc121e9`

#### Assignments


**Exclude Users:**
- Alex Wilber (AlexW@M365x37845673.OnMicrosoft.com)

**Exclude Groups:**
- Azure-Breakglass

**Include Roles:**
# Azure AD Admin Roles

| Role ID | Display Name | Description |
|---------|-------------|-------------|
| `c4e39bd9-1100-46d3-8c65-fb160da0071f` | Authentication Administrator | Allowed to view, set and reset authentication method information for any non-admin user. |
| `b0f54661-2d74-4c50-afa3-1ec803f12efe` | Billing Administrator | Can perform common billing related tasks like updating payment information. |
| `b1be1c3e-b65d-4f19-8427-f6fa0d97feb9` | Conditional Access Administrator | Can manage Conditional Access capabilities. |
| `29232cdf-9323-42fd-ade2-1d097af3e4de` | Exchange Administrator | Can manage all aspects of the Exchange product. |
| `62e90394-69f5-4237-9190-012177145e10` | Global Administrator | Can manage all aspects of Microsoft Entra ID and Microsoft services that use Microsoft Entra identities. |
| `729827e3-9c14-49f7-bb1b-9608f156bbb8` | Helpdesk Administrator | Can reset passwords for non-administrators and Helpdesk Administrators. |
| `194ae4cb-b126-40b2-bd5b-6091b380977d` | Security Administrator | Security Administrator allows ability to read and manage security configuration and reports. |
| `f28a1f50-f6e7-4571-818b-6a12f2af6b6c` | SharePoint Administrator | Can manage all aspects of the SharePoint service. |
| `fe930be7-5e62-47db-91af-98c3a49a38b1` | User Administrator | Can manage all aspects of users and groups, including resetting passwords for limited admins. |
| `9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3` | Application Administrator | Can create and manage all aspects of app registrations and enterprise apps. |
| `158c047a-c907-4556-b7ef-446551a6b5f7` | Cloud Application Administrator | Can create and manage all aspects of app registrations and enterprise apps except App Proxy. |
| `966707d0-3269-4727-9be2-8c3a10f19b9d` | Password Administrator | Can reset passwords for non-administrators and Password Administrators. |
| `e8611ab8-c189-46e8-94e1-60213ab1f814` | Privileged Role Administrator | Can manage role assignments in Microsoft Entra ID, and all aspects of Privileged Identity Management. |
| `7be44c8a-adaf-4e2a-84d6-ab2649e08a13` | Privileged Authentication Administrator | Allowed to view, set and reset authentication method information for any user (admin or non-admin). |


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms
**Include Platforms:** all


##### Locations
**Include Locations:** All locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- Multi-Factor Authentication


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "mfa"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('0a906da3-3cbe-4227-a036-7fb9afc121e9')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [
        "c4e39bd9-1100-46d3-8c65-fb160da0071f",
        "b0f54661-2d74-4c50-afa3-1ec803f12efe",
        "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9",
        "29232cdf-9323-42fd-ade2-1d097af3e4de",
        "62e90394-69f5-4237-9190-012177145e10",
        "729827e3-9c14-49f7-bb1b-9608f156bbb8",
        "194ae4cb-b126-40b2-bd5b-6091b380977d",
        "f28a1f50-f6e7-4571-818b-6a12f2af6b6c",
        "fe930be7-5e62-47db-91af-98c3a49a38b1",
        "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3",
        "158c047a-c907-4556-b7ef-446551a6b5f7",
        "966707d0-3269-4727-9be2-8c3a10f19b9d",
        "e8611ab8-c189-46e8-94e1-60213ab1f814",
        "7be44c8a-adaf-4e2a-84d6-ab2649e08a13"
      ],
      "includeUsers": [],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [
        "b5c09c55-0ac4-49f0-b709-8b2497eb5034"
      ],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": {
        "guestOrExternalUserTypes": "serviceProvider",
        "externalTenants": {
          "@odata.type": "#microsoft.graph.conditionalAccessEnumeratedExternalTenants",
          "members": [
            "1b2f14e2-91f9-4876-9f59-3cb09b4ec310"
          ],
          "membershipKind": "enumerated"
        }
      },
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": {
      "includePlatforms": [
        "all"
      ],
      "excludePlatforms": []
    },
    "locations": {
      "excludeLocations": [],
      "includeLocations": [
        "All"
      ]
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL - GRANT - MFA - AllAdmins",
  "templateId": null
}
```

---

### IAC - GLOBAL - GRANT - MFA - External-Guest-Users

**Purpose:** Requires Multi-Factor Authentication for user access. Adds an extra layer of security beyond just username and password.

**State:** `disabled`

**Policy ID:** `0ac710dc-f044-402b-8c55-96a379f9733e`

#### Assignments


**Exclude Groups:**
- CA - GuestExclusions
- Azure-Breakglass


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- Multi-Factor Authentication


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "mfa"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('0ac710dc-f044-402b-8c55-96a379f9733e')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [],
      "excludeGroups": [
        "c07caedd-cc1f-483e-8ff9-332f6aad189b",
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": {
        "guestOrExternalUserTypes": "serviceProvider",
        "externalTenants": {
          "@odata.type": "#microsoft.graph.conditionalAccessEnumeratedExternalTenants",
          "members": [
            "1b2f14e2-91f9-4876-9f59-3cb09b4ec310"
          ],
          "membershipKind": "enumerated"
        }
      },
      "includeGuestsOrExternalUsers": {
        "guestOrExternalUserTypes": "internalGuest,b2bCollaborationGuest,b2bCollaborationMember,b2bDirectConnectUser,otherExternalUser,serviceProvider",
        "externalTenants": {
          "membershipKind": "all",
          "@odata.type": "#microsoft.graph.conditionalAccessAllExternalTenants"
        }
      }
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL - GRANT - MFA - External-Guest-Users",
  "templateId": null
}
```

---

### IAC - GLOBAL – BLOCK - Legacy Authentication

**Purpose:** Blocks legacy authentication protocols that don't support modern security features like MFA. Prevents sign-ins using basic authentication, which is commonly exploited in password spray attacks.

**State:** `disabled`

**Policy ID:** `88e31244-d731-4bad-97e8-a623506ed559`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- exchangeActiveSync
- other

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('88e31244-d731-4bad-97e8-a623506ed559')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "exchangeActiveSync",
      "other"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL – BLOCK - Legacy Authentication",
  "templateId": null
}
```

---

### IAC - GLOBAL – BLOCK – Countries not Allowed - NoExclusions

**Purpose:** Blocks access from specific geographic locations or countries. Prevents unauthorized access from regions where the organization doesn't operate.

**State:** `disabled`

**Policy ID:** `6170d175-6a8f-4c81-8eac-9b4ec286bc97`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations
**Include Locations:** 19895061-779a-4200-9524-36bccf61f684


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('6170d175-6a8f-4c81-8eac-9b4ec286bc97')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "locations": {
      "excludeLocations": [],
      "includeLocations": [
        "19895061-779a-4200-9524-36bccf61f684"
      ]
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL – BLOCK – Countries not Allowed - NoExclusions",
  "templateId": null
}
```

---

### IAC - GLOBAL – BLOCK – Countries not Allowed

**Purpose:** Blocks access from specific geographic locations or countries. Prevents unauthorized access from regions where the organization doesn't operate.

**State:** `disabled`

**Policy ID:** `b0052c50-3891-4e84-abde-772c5b58bc15`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - TravelingUsers


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations
**Include Locations:** All locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('b0052c50-3891-4e84-abde-772c5b58bc15')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "063f926c-a676-4880-9edd-78a0ee7d5ff4"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "locations": {
      "excludeLocations": [],
      "includeLocations": [
        "All"
      ]
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL – BLOCK – Countries not Allowed",
  "templateId": null
}
```

---

### IAC - GLOBAL – BLOCK – Service Accounts

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `2a72176a-39ba-4223-8a10-3ca9595d06e4`

#### Assignments


**Include Groups:**
- CA - ServiceAccounts

**Exclude Groups:**
- Azure-Breakglass
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations
**Include Locations:** All locations
**Exclude Locations:** 0852b0c4-160e-441f-922b-a91615d22742


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('2a72176a-39ba-4223-8a10-3ca9595d06e4')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [
        "8782b8eb-5554-4d69-a496-1106cf10aac4"
      ],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "locations": {
      "excludeLocations": [
        "0852b0c4-160e-441f-922b-a91615d22742"
      ],
      "includeLocations": [
        "All"
      ]
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL – BLOCK – Service Accounts",
  "templateId": null
}
```

---

### IAC - GLOBAL – SESSION – Admin Persistence (1 Hours)

**Purpose:** Limits administrator session duration to reduce the risk of compromised admin accounts. Forces admins to re-authenticate after the specified time period.

**State:** `disabled`

**Policy ID:** `6d984e86-d898-48e5-b80a-a862bc4b7040`

#### Assignments


**Exclude Groups:**
- Azure-Breakglass

**Include Roles:**
- Unknown
- Unknown
- Unknown
- Unknown
- Unknown
- Unknown
- Unknown
- Unknown
- Unknown
- Unknown
- Unknown


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- browser

##### Device States
Not configured

#### Grant Controls

None

#### Session Controls

**Sign-in Frequency:** 1 hours (Enabled)
**Persistent Browser:** never (Enabled)


#### Configuration JSON

```json
{
  "sessionControls": {
    "secureSignInSession": null,
    "disableResilienceDefaults": null,
    "persistentBrowser": {
      "isEnabled": true,
      "mode": "never"
    },
    "cloudAppSecurity": null,
    "signInFrequency": {
      "frequencyInterval": "timeBased",
      "isEnabled": true,
      "value": 1,
      "authenticationType": "primaryAndSecondaryAuthentication",
      "type": "hours"
    },
    "applicationEnforcedRestrictions": null
  },
  "state": "disabled",
  "grantControls": null,
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [
        "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3",
        "0526716b-113d-4c15-b2c8-68e3c22b9f80",
        "158c047a-c907-4556-b7ef-446551a6b5f7",
        "17315797-102d-40b4-93e0-432062caca18",
        "e6d1a23a-da11-4be4-9570-befc86d067a7",
        "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9",
        "62e90394-69f5-4237-9190-012177145e10",
        "8ac3fc64-6eca-42ea-9e69-59f4c7b60eb2",
        "7be44c8a-adaf-4e2a-84d6-ab2649e08a13",
        "e8611ab8-c189-46e8-94e1-60213ab1f814",
        "194ae4cb-b126-40b2-bd5b-6091b380977d"
      ],
      "includeUsers": [],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "browser"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL – SESSION – Admin Persistence (1 Hours)",
  "templateId": null
}
```

---

### IAC - GLOBAL – SESSION – All Users Persistence (9-12 Hours)

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `655c18b6-d254-4a32-a087-3ff9380abb68`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- browser

##### Device States
Not configured

#### Grant Controls

None

#### Session Controls

**Sign-in Frequency:** 12 hours (Enabled)
**Persistent Browser:** never (Enabled)


#### Configuration JSON

```json
{
  "sessionControls": {
    "secureSignInSession": null,
    "disableResilienceDefaults": null,
    "persistentBrowser": {
      "isEnabled": true,
      "mode": "never"
    },
    "cloudAppSecurity": null,
    "signInFrequency": {
      "frequencyInterval": "timeBased",
      "isEnabled": true,
      "value": 12,
      "authenticationType": "primaryAndSecondaryAuthentication",
      "type": "hours"
    },
    "applicationEnforcedRestrictions": null
  },
  "state": "disabled",
  "grantControls": null,
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "browser"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - GLOBAL – SESSION – All Users Persistence (9-12 Hours)",
  "templateId": null
}
```

---

### IAC - INTUNE - BLOCK - RequireCompliantDevice - NonTrustedLocations

**Purpose:** Blocks access from specific geographic locations or countries. Prevents unauthorized access from regions where the organization doesn't operate.

**State:** `disabled`

**Policy ID:** `d3edea14-047d-43ae-930b-0ea4e376cc05`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - DeviceExclusions


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('d3edea14-047d-43ae-930b-0ea4e376cc05')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "33a0d7cd-c3b2-4252-b441-3697e7453046"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "devices": {
      "deviceFilter": {
        "rule": "device.isCompliant -eq True -and device.trustType -eq \"ServerAD\" -or device.trustType -eq \"AzureAD\"",
        "mode": "exclude"
      }
    },
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "signInRiskLevels": []
  },
  "displayName": "IAC - INTUNE - BLOCK - RequireCompliantDevice - NonTrustedLocations",
  "templateId": null
}
```

---

### IAC - INTUNE - GRANT - RequireCompliantDevice

**Purpose:** Requires devices to be compliant with organizational security policies. Ensures devices meet minimum security standards before accessing corporate resources.

**State:** `disabled`

**Policy ID:** `87435d25-9ea5-47b4-9c16-5d6575396fc9`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - DeviceExclusions


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations
**Include Locations:** All trusted locations
**Exclude Locations:** AllTrusted


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- Require device to be marked as compliant
- Require Hybrid Azure AD joined device


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "compliantDevice",
      "domainJoinedDevice"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('87435d25-9ea5-47b4-9c16-5d6575396fc9')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "33a0d7cd-c3b2-4252-b441-3697e7453046"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "locations": {
      "excludeLocations": [
        "AllTrusted"
      ],
      "includeLocations": [
        "AllTrusted"
      ]
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - INTUNE - GRANT - RequireCompliantDevice",
  "templateId": null
}
```

---

### IAC - INTUNE – GRANT – Device Registration from trusted location

**Purpose:** Allows device registration only from trusted network locations. Ensures devices are enrolled from secure, known locations like corporate offices.

**State:** `disabled`

**Policy ID:** `33b49c12-465b-4dba-9785-fa7ccc326703`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - DeviceExclusions


#### Conditions

##### Applications


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR



#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [],
    "authenticationStrength": {
      "combinationConfigurations@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('33b49c12-465b-4dba-9785-fa7ccc326703')/grantControls/authenticationStrength/combinationConfigurations",
      "allowedCombinations": [
        "windowsHelloForBusiness",
        "fido2",
        "x509CertificateMultiFactor",
        "deviceBasedPush",
        "temporaryAccessPassOneTime",
        "temporaryAccessPassMultiUse",
        "password,microsoftAuthenticatorPush",
        "password,softwareOath",
        "password,hardwareOath",
        "password,sms",
        "password,voice",
        "federatedMultiFactor",
        "microsoftAuthenticatorPush,federatedSingleFactor",
        "softwareOath,federatedSingleFactor",
        "hardwareOath,federatedSingleFactor",
        "sms,federatedSingleFactor",
        "voice,federatedSingleFactor"
      ],
      "requirementsSatisfied": "mfa",
      "modifiedDateTime": "2021-12-01T08:00:00Z",
      "id": "00000000-0000-0000-0000-000000000002",
      "createdDateTime": "2021-12-01T08:00:00Z",
      "description": "Combinations of methods that satisfy strong authentication, such as a password + SMS",
      "policyType": "builtIn",
      "displayName": "Multifactor authentication",
      "combinationConfigurations": []
    },
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('33b49c12-465b-4dba-9785-fa7ccc326703')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "33a0d7cd-c3b2-4252-b441-3697e7453046"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [
        "urn:user:registerdevice"
      ],
      "includeApplications": []
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - INTUNE – GRANT – Device Registration from trusted location",
  "templateId": null
}
```

---

### IAC - INTUNE – GRANT – Mobile Apps and Desktop Clients

**Purpose:** Enforces security requirements for mobile apps and desktop client access. Ensures modern authentication and security controls are applied to native applications.

**State:** `disabled`

**Policy ID:** `53c80126-ae17-4053-acc1-1d1afbfd8090`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - ServiceAccounts

**Exclude Roles:**
- Unknown


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- mobileAppsAndDesktopClients

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- Require device to be marked as compliant


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "compliantDevice"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('53c80126-ae17-4053-acc1-1d1afbfd8090')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "8782b8eb-5554-4d69-a496-1106cf10aac4"
      ],
      "excludeRoles": [
        "d29b2b05-8046-44ba-8758-1e26182fcf32"
      ],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "mobileAppsAndDesktopClients"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - INTUNE – GRANT – Mobile Apps and Desktop Clients",
  "templateId": null
}
```

---

### IAC - INTUNE – GRANT – Mobile Device Access Requirements

**Purpose:** Requires mobile devices to meet compliance requirements before accessing resources. Enforces device compliance policies for iOS and Android devices.

**State:** `disabled`

**Policy ID:** `70ab6ce0-a24c-44f6-b556-2c5a88ffeae1`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass


#### Conditions

##### Applications
**Include Applications:**
- Office 365

**Exclude Applications:**
- **Microsoft Intune** `(0000000a-0000-0000-c000-000000000000)`


##### Platforms
**Include Platforms:** android, iOS


##### Locations


##### Client App Types
- mobileAppsAndDesktopClients

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- Require device to be marked as compliant
- Require app protection policy


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "compliantDevice",
      "compliantApplication"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('70ab6ce0-a24c-44f6-b556-2c5a88ffeae1')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [
        "0000000a-0000-0000-c000-000000000000"
      ],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "Office365"
      ]
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "mobileAppsAndDesktopClients"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "locations": null,
    "platforms": {
      "includePlatforms": [
        "android",
        "iOS"
      ],
      "excludePlatforms": []
    },
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - INTUNE – GRANT – Mobile Device Access Requirements",
  "templateId": null
}
```

---

### IAC - INTUNE – SESSION – Block File Downloads On Unmanaged Devices

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `c9f17d79-f902-47eb-8209-d86cb926970f`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - DeviceExclusions


#### Conditions

##### Applications
**Include Applications:**
- Office 365


##### Platforms
**Include Platforms:** all
**Exclude Platforms:** android, iOS, windows, macOS


##### Locations
**Include Locations:** All locations
**Exclude Locations:** AllTrusted


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

None

#### Session Controls

**Cloud App Security:** blockDownloads


#### Configuration JSON

```json
{
  "sessionControls": {
    "secureSignInSession": null,
    "disableResilienceDefaults": null,
    "persistentBrowser": null,
    "cloudAppSecurity": {
      "cloudAppSecurityType": "blockDownloads",
      "isEnabled": true
    },
    "signInFrequency": null,
    "applicationEnforcedRestrictions": null
  },
  "state": "disabled",
  "grantControls": null,
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "33a0d7cd-c3b2-4252-b441-3697e7453046"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "authenticationFlows": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "devices": {
      "deviceFilter": {
        "rule": "device.isCompliant -eq True -or device.trustType -eq \"AzureAD\" -or device.trustType -eq \"ServerAD\"",
        "mode": "exclude"
      }
    },
    "platforms": {
      "includePlatforms": [
        "all"
      ],
      "excludePlatforms": [
        "android",
        "iOS",
        "windows",
        "macOS"
      ]
    },
    "locations": {
      "excludeLocations": [
        "AllTrusted"
      ],
      "includeLocations": [
        "All"
      ]
    },
    "insiderRiskLevels": null,
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "Office365"
      ]
    },
    "signInRiskLevels": []
  },
  "displayName": "IAC - INTUNE – SESSION – Block File Downloads On Unmanaged Devices",
  "templateId": null
}
```

---

### IAC - INTUNE – SESSION – BYOD Persistence

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `63b18c92-507d-425b-be41-48b5d75d8963`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

None

#### Session Controls

**Sign-in Frequency:** 9 hours (Enabled)
**Persistent Browser:** never (Enabled)


#### Configuration JSON

```json
{
  "sessionControls": {
    "secureSignInSession": null,
    "disableResilienceDefaults": null,
    "persistentBrowser": {
      "isEnabled": true,
      "mode": "never"
    },
    "cloudAppSecurity": null,
    "signInFrequency": {
      "frequencyInterval": "timeBased",
      "isEnabled": true,
      "value": 9,
      "authenticationType": "primaryAndSecondaryAuthentication",
      "type": "hours"
    },
    "applicationEnforcedRestrictions": null
  },
  "state": "disabled",
  "grantControls": null,
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "devices": {
      "deviceFilter": {
        "rule": "device.isCompliant -eq True",
        "mode": "exclude"
      }
    },
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "signInRiskLevels": []
  },
  "displayName": "IAC - INTUNE – SESSION – BYOD Persistence",
  "templateId": null
}
```

---

### IAC - P2 - GLOBAL - BLOCK - RiskyUsers - RegisterSecurityInfoRequirements

**Purpose:** Blocks sign-ins based on detected risk levels. Uses Microsoft Entra ID Protection to identify and block potentially compromised accounts or risky sign-in attempts.

**State:** `disabled`

**Policy ID:** `29c95a7f-cbe1-4e82-a016-7c33d7b9dab2`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass


#### Conditions

##### Applications


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- block


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "block"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('29c95a7f-cbe1-4e82-a016-7c33d7b9dab2')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [
        "urn:user:registersecurityinfo"
      ],
      "includeApplications": []
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [
      "high",
      "medium"
    ],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - P2 - GLOBAL - BLOCK - RiskyUsers - RegisterSecurityInfoRequirements",
  "templateId": null
}
```

---

### IAC - P2 - GLOBAL – GRANT – High-Risk Sign-Ins

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `294c064e-758e-4001-a5f1-5c0005b40f1a`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR



#### Session Controls

**Sign-in Frequency:**   (Enabled)


#### Configuration JSON

```json
{
  "sessionControls": {
    "signInFrequency": {
      "frequencyInterval": "everyTime",
      "isEnabled": true,
      "value": null,
      "authenticationType": "primaryAndSecondaryAuthentication",
      "type": null
    },
    "secureSignInSession": null,
    "disableResilienceDefaults": null,
    "cloudAppSecurity": null,
    "persistentBrowser": null,
    "applicationEnforcedRestrictions": null
  },
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [],
    "authenticationStrength": {
      "combinationConfigurations@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('294c064e-758e-4001-a5f1-5c0005b40f1a')/grantControls/authenticationStrength/combinationConfigurations",
      "allowedCombinations": [
        "windowsHelloForBusiness",
        "fido2",
        "x509CertificateMultiFactor",
        "temporaryAccessPassOneTime",
        "temporaryAccessPassMultiUse"
      ],
      "requirementsSatisfied": "mfa",
      "modifiedDateTime": "2026-01-16T14:37:21.7388692Z",
      "id": "abe3fdf2-dfd3-4606-b31d-dc95b4df53af",
      "createdDateTime": "2026-01-16T14:37:21.7388692Z",
      "description": "",
      "policyType": "custom",
      "displayName": "Modern MFA + TAP",
      "combinationConfigurations": []
    },
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('294c064e-758e-4001-a5f1-5c0005b40f1a')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": [
      "high"
    ]
  },
  "displayName": "IAC - P2 - GLOBAL – GRANT – High-Risk Sign-Ins",
  "templateId": null
}
```

---

### IAC - P2 - GLOBAL – GRANT – High-Risk Users

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `b05adb67-c3a7-4010-bcf1-f1af0c1a46d9`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** AND

**Required Controls:**
- Multi-Factor Authentication
- Require password change


#### Session Controls

**Sign-in Frequency:**   (Enabled)


#### Configuration JSON

```json
{
  "sessionControls": {
    "signInFrequency": {
      "frequencyInterval": "everyTime",
      "isEnabled": true,
      "value": null,
      "authenticationType": "primaryAndSecondaryAuthentication",
      "type": null
    },
    "secureSignInSession": null,
    "disableResilienceDefaults": null,
    "cloudAppSecurity": null,
    "persistentBrowser": null,
    "applicationEnforcedRestrictions": null
  },
  "state": "disabled",
  "grantControls": {
    "operator": "AND",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "mfa",
      "passwordChange"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('b05adb67-c3a7-4010-bcf1-f1af0c1a46d9')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [
      "high"
    ],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": []
  },
  "displayName": "IAC - P2 - GLOBAL – GRANT – High-Risk Users",
  "templateId": null
}
```

---

### IAC - P2 - GLOBAL – GRANT – Medium-Risk Sign-Ins

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `7cefe2df-20c0-406b-8a93-0dc4a1323183`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- All cloud apps


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- Multi-Factor Authentication


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "mfa"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('7cefe2df-20c0-406b-8a93-0dc4a1323183')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "All"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": [
      "medium"
    ]
  },
  "displayName": "IAC - P2 - GLOBAL – GRANT – Medium-Risk Sign-Ins",
  "templateId": null
}
```

---

### IAC - P2 - GLOBAL – GRANT – Medium-Risk Users

**Purpose:** Conditional Access policy that enforces security requirements based on specific conditions.

**State:** `disabled`

**Policy ID:** `757381f0-144b-4091-ad5e-5402372a25e3`

#### Assignments

**Include Users:**
- All users

**Exclude Groups:**
- Azure-Breakglass
- CA - GlobalExclusions


#### Conditions

##### Applications
**Include Applications:**
- **None** `(None)`


##### Platforms


##### Locations


##### Client App Types
- all

##### Device States
Not configured

#### Grant Controls

**Operator:** OR

**Required Controls:**
- Multi-Factor Authentication


#### Session Controls

None

#### Configuration JSON

```json
{
  "sessionControls": null,
  "state": "disabled",
  "grantControls": {
    "operator": "OR",
    "customAuthenticationFactors": [],
    "termsOfUse": [],
    "builtInControls": [
      "mfa"
    ],
    "authenticationStrength": null,
    "authenticationStrength@odata.context": "https://graph.microsoft.com/v1.0/$metadata#identity/conditionalAccess/policies('757381f0-144b-4091-ad5e-5402372a25e3')/grantControls/authenticationStrength/$entity"
  },
  "conditions": {
    "servicePrincipalRiskLevels": [],
    "users": {
      "includeRoles": [],
      "includeUsers": [
        "All"
      ],
      "excludeGroups": [
        "822cebe7-b527-405c-8bae-834782ec74cb",
        "6064391a-c4b7-4991-b87f-e7a98fcd23aa"
      ],
      "excludeRoles": [],
      "excludeUsers": [],
      "includeGroups": [],
      "excludeGuestsOrExternalUsers": null,
      "includeGuestsOrExternalUsers": null
    },
    "applications": {
      "excludeApplications": [],
      "includeAuthenticationContextClassReferences": [],
      "applicationFilter": null,
      "includeUserActions": [],
      "includeApplications": [
        "None"
      ]
    },
    "locations": null,
    "clientAppTypes": [
      "all"
    ],
    "clientApplications": null,
    "userRiskLevels": [],
    "platforms": null,
    "authenticationFlows": null,
    "insiderRiskLevels": null,
    "devices": null,
    "signInRiskLevels": [
      "medium"
    ]
  },
  "displayName": "IAC - P2 - GLOBAL – GRANT – Medium-Risk Users",
  "templateId": null
}
```

---

## Named Locations

Named Locations are used in Conditional Access policies to define trusted network locations, IP ranges, or geographic regions.

---

## Summary

This documentation was automatically generated from exported IAC policy JSON files.

**Total Conditional Access Policies:** 27
**Total Named Locations:** 0

For questions or updates to these policies, please refer to the change management process.

