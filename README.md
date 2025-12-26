# Learn Microsoft Graph API → Microsoft Graph API Cheat Sheet

> **Purpose**: A practical, engineer-focused reference for discovering and using Microsoft Graph endpoints that return Entra ID data.
>
> Use this as a printable reference, a living document, or a baseline for building your own internal Graph catalog.

## 📚 Table of Contents

- [Entra ID → Microsoft Graph API Cheat Sheet](#entra-id--microsoft-graph-api-cheat-sheet)
  - [What is Microsoft Graph](#what-is-microsoft-graph)
  - [How is Graph Structured](#How-Microsoft-Graph-Is-Structured)
  - [Ways to learn Graph](#Ways-to-Interact-and-Keep-up-to-date-with-Graph)
  - [Ways to call Graph](#Ways-to-Call-Microsoft-Graph)
 
    

- [Microsoft Graph `/me` and `/$value` – Quick Reference](#microsoft-graph-me-and-value--quick-reference)
  - [Base `/me` endpoint](#base-me-endpoint)
  - [What does `/$value` mean?](#what-does-value-mean)
  - [Where `/$value` works with `/me`](#where-value-works-with-me)
    - [User profile photo](#user-profile-photo)
    - [Profile photo size variants](#profile-photo-size-variants)
    - [Primitive property example](#primitive-property-example)
  - [Where `/$value` does NOT work](#where-value-does-not-work)
  - [Mental model](#mental-model)
  - [Common `/me` + `/$value` patterns](#common-me--value-patterns)
  - [Permissions](#permissions)
  - [TL;DR](#tldr)

- [Microsoft Graph Identity – Quick Reference](#microsoft-graph-identity--quick-reference)
  - [Identity Core](#identity-core)
  - [Common User Queries](#common-user-queries)
  - [Groups](#groups)
  - [What does `/any(c:c eq 'DynamicMembership')` do?](#understanding-the-any-function-in-microsoft-graph-queries)
  - [Applications & Enterprise Apps](#applications-and-enterprise-apps)
  - [🛡️Conditional Access & Protection](#conditional-access-and-protection)

- [Authentication & Passwordless](#authentication--passwordless)
  - [Tenant-wide Authentication Policies](#tenant-wide-authentication-policies)
  - [FIDO2 & Passkeys](#fido2--passkeys)
  - [Per-user Authentication Methods](#per-user-authentication-methods)

- [Audit Logs & Reports](#audit-logs)

- [Identity Governance](#access-reviews)

- [Tenant & Directory Settings](#tenant--directory-settings)

- [Entra Portal → Graph Mapping Rules](#entra-portal--graph-mapping-rules)

- [Graph Discovery Workflow (Reusable)](#graph-discovery-workflow-reusable)

- [Reverse-Engineering Entra Portal Calls](#reverse-engineering-entra-portal-calls)

- [Common Read Permissions](#common-read-permissions)

- [Microsoft Graph OData Metadata – Reference & Usage Guide](#microsoft-graph-odata-metadata--reference--usage-guide)

- [Microsoft Graph Intune Device Management – Metadata & OData Usage Guide](#microsoft-graph-intune-device-management--metadata--odata-usage-guide)

- [Microsoft Graph `$select` Query Option](#microsoft-graph-select-query-option)

- [HTTP Methods Overview for Microsoft Graph API](#http-methods-overview-for-microsoft-graph-api)


## What Is Microsoft Graph?

**Microsoft Graph** is Microsoft’s unified REST API that provides a single endpoint to access data and actions across Microsoft cloud services.

Instead of calling many different service-specific APIs (Azure AD, Exchange, SharePoint, Intune, Teams), Microsoft Graph exposes them through **one consistent API surface**.

At a high level, Microsoft Graph allows you to:
- Read and manage **Entra ID (Azure AD)** objects (users, groups, devices)
- Configure **authentication and security policies**
- Access **Microsoft 365** data (mail, calendar, files)
- Manage **Intune / device management**
- Query **audit logs, sign-ins, and reports**

---

## The Microsoft Graph Endpoint

![Graph API Breakdown](https://github.com/Jhope188/LearnGraphAPI/blob/main/Images/APIBreakdown.png)

All Microsoft Graph calls use a **single base URL**:

```http
https://graph.microsoft.com
```

You then choose an **API version**:
- `v1.0` → production, stable
- `beta` → preview, newest features (may change)

Example:
```http
https://graph.microsoft.com/v1.0/me
```

---

## How Microsoft Graph Is Structured

Microsoft Graph is built on **REST + OData** principles.

Key concepts:
- **Resources** → users, groups, devices, policies
- **Relationships** → members, owners, assignments
- **Actions** → reset password, assign license

Example resource path:
```text
/users/{id}/memberOf
```

---

## Authentication: How You Are Allowed to Call Graph

Microsoft Graph uses **OAuth 2.0 access tokens** issued by Entra ID.

You must authenticate using one of these identities:
- A **signed-in user** (delegated permissions)
- An **application / service principal** (application permissions)

### Delegated vs Application Permissions

| Permission type | Runs as | Typical use |
|-----------------|--------|-------------|
| Delegated | Signed-in user | Graph Explorer, user tools |
| Application | App identity | Automation, background jobs |

---



## Ways to Interact and Keep up to date with Graph
`Digging Into the Graph Documentation`
><https://learn.microsoft.com/en-us/graph/api/overview?view=graph-rest-1.0&viewFallbackFrom=graph-rest-1.0%2F%3Fwt.mc_id%3Dmsgraph_inproduct_graphexhelp>


`Getting familiar with upcoming Microsoft Changes`
><https://developer.microsoft.com/en-us/graph/changelog/?filterBy=beta,Identity%20and%20access>


`Daniel Bradley MS Docs Tracker`
> <https://msdocstracker.com/#graph>

`Lokka`
> <https://lokka.dev/docs/install>


---

## Ways to Call Microsoft Graph

### 1. Graph Explorer (Easiest)

Graph Explorer is a browser-based tool for testing Graph requests.

- Runs as **you**
- Handles tokens automatically
- Best for learning and discovery

Example:
```http
GET https://graph.microsoft.com/v1.0/me
```

`Graph Explorer`
><https://aka.ms/ge>

---

### 2. REST API (Raw HTTP)

Microsoft Graph is fundamentally an **HTTP REST API**.

Example:
```http
GET /v1.0/users
Authorization: Bearer {access_token}
```

Used when:
- Building custom apps
- Calling Graph from scripts or services

---

### 3. PowerShell (Microsoft Graph SDK)

Microsoft provides PowerShell modules that wrap Graph calls.

Example:
```powershell
Connect-MgGraph -Scopes User.Read.All
Get-MgUser
```

PowerShell is ideal for:
- Admin automation
- Reporting
- Bulk operations

---

### 4. SDKs (C#, Python, JavaScript)

Microsoft provides SDKs that abstract raw HTTP calls.

Supported languages include:
- C# / .NET
- JavaScript / TypeScript
- Python
- Java

SDKs handle:
- Authentication
- Paging
- Serialization

---

## Common HTTP Methods Used in Graph

| Method | Purpose |
|------|--------|
| GET | Read data |
| POST | Create objects or trigger actions |
| PATCH | Update existing objects |
| DELETE | Remove objects |

Example:
```http
PATCH /v1.0/users/{id}
```

---



# Microsoft Graph `/me` and `/$value` – Quick Reference

## Base `/me` endpoint

```http
GET https://graph.microsoft.com/v1.0/me
```

Returns the **signed-in user’s directory object** as **JSON**.

---

## What does `/$value` mean?

In Microsoft Graph, `/$value` tells the service:

> **Return the raw value of the resource, not the JSON wrapper.**

It is used when the resource represents:

* A **binary stream** (photo, file)
* A **primitive value** (string, number)
* A **collection of primitive values**

![GraphExplorerMe](https://github.com/Jhope188/LearnGraphAPI/blob/main/Images/MyPhoto.png)

---

## Where `/$value` works with `/me`

### User profile photo

```http
GET /v1.0/me/photo/$value
```

* Returns raw binary image (JPEG/PNG)
* No JSON response
* Browser downloads or renders the image

---

### Profile photo size variants

```http
GET /v1.0/me/photos/48x48/$value
```

---

### Primitive property example

```http
GET /v1.0/me/mailboxSettings/timeZone/$value
```

Returns a **plain string**, not JSON metadata.

---

## Where `/$value` does **NOT** work

```http
GET /v1.0/me/$value
```

❌ Invalid because `/me` is a **complex object**, not a primitive or stream.

Typical error:

```json
{
  "error": {
    "code": "BadRequest",
    "message": "Cannot use $value on a complex type."
  }
}
```

---

## Mental model

| Resource type                         | `/$value` supported |
| ------------------------------------- | ------------------- |
| Binary (photo, file)                  | ✅                   |
| Primitive (string, int)               | ✅                   |
| Primitive collection                  | ✅                   |
| Complex object (user)                 | ❌                   |
| Navigation object (manager, memberOf) | ❌                   |

---

## Common `/me` + `/$value` patterns

| Endpoint                              | Result            |
| ------------------------------------- | ----------------- |
| `/me/photo/$value`                    | Raw profile image |
| `/me/photos/{size}/$value`            | Sized photo       |
| `/me/mailboxSettings/timeZone/$value` | Plain string      |
| `/me/manager/$value`                  | ❌ Not supported   |

---

## Permissions

* `User.Read` (basic signed-in user)
* `User.Read.All` (reading other users)

---

## TL;DR

```text
/$value = raw output
No JSON wrapper
Use for photos, files, and primitive values
Never use it on /me itself
```


# Microsoft Graph `Identity` – Quick Reference



## 🔐 Identity Core
```http
GET /v1.0/users
GET /v1.0/groups
GET /v1.0/devices
GET /v1.0/directoryObjects
```

### Common User Queries
```http
GET /v1.0/users/{id}
GET /v1.0/users/{id}/memberOf
GET /v1.0/users/{id}/transitiveMemberOf
GET /v1.0/users/{id}/manager
GET /v1.0/users/{id}/directReports
GET /v1.0/users/{id}/registeredDevices
GET /v1.0/users/{id}/ownedDevices
GET /v1.0/users/{id}/authentication/methods
```

### Groups
```http
GET /v1.0/groups/{id}
GET /v1.0/groups/{id}/members
GET /v1.0/groups/{id}/transitiveMembers
GET /v1.0/groups/{id}/owners
GET v/1.0/groups/$count (Count requires a consistency level header)

```
```
GET https://graph.microsoft.com/v1.0/groups/$count?$filter=securityEnabled eq true

HEADER:
ConsistencyLevel: eventual
```
>**NOTE** This is a more real world scenario to pull back the count for total security groups

```
Get https://graph.microsoft.com/v1.0/groups/$count?$filter=startswith(displayName,'ACME')

HEADER:
ConsistencyLevel: eventual
```
>**NOTE** This is a more real world scenario to pull back the count for total groups that meet a naming convention

### Return all Groups by DisplayName
```

https://graph.microsoft.com/v1.0/groups?$select=displayName
```

### Expand Groups and Select Owner property
```

https://graph.microsoft.com/v1.0/groups?$select=displayName&$expand=owners($select=displayName,userPrincipalName)
```

### Get All Groups by DisplayName and type then filter on Dynamic

```
https://graph.microsoft.com/beta/groups?$select=displayname,grouptypes&$filter=groupTypes/any(c:c eq 'DynamicMembership')
```


### Filter Groups by names that start with ACME-AUTH
```

https://graph.microsoft.com/v1.0/groups?$filter=startswith(displayName,'ACME-AUTH')&$select=id,displayName
```
```
What this does

/groups → queries all groups

$filter=startswith(displayName,'ACME-AUTH') → returns only groups whose names start with ACME-AUTH

$select=id,displayName → returns only: id (object ID)/displayName
```

Have to switch to Beta to report on Group Owner value
```
https://graph.microsoft.com/beta/groups/0e4b5629-83d8-4aae-a5cb-5f0c31836116?$expand=owners
```

```
##Grab the user account object ID: Cant patch a group owner with UserPrincipalName

https://graph.microsoft.com/beta/users/jhope@acmebaseline.onmicrosoft.com?$select=id

```

```
##Now its multiple steps to patch the odata with the updated owner

POST /v1.0/groups/{GROUP_OBJECT_ID}/owners/$ref
> Replace Group Object with the ID Above

Request body update with odata and user object id:

{
  "@odata.id": "https://graph.microsoft.com/v1.0/users/USER_OBJECT_ID"
}

{
  "@odata.id": "https://graph.microsoft.com/v1.0/users/eaf72a07-8d1f-4324-b8dd-35d906b86d6d"
}

Check for the updated group owner information

GET https://graph.microsoft.com/beta/groups/0e4b5629-83d8-4aae-a5cb-5f0c31836116?$expand=owners

How to filter better for just the Owner Display name and id
https://graph.microsoft.com/beta/groups/0e4b5629-83d8-4aae-a5cb-5f0c31836116?$select=id,displayName&$expand=owners($select=id,displayName)


NOTE: Groups self service sign up features:
https://learn.microsoft.com/en-us/entra/identity/users/groups-self-service-management?WT.mc_id=Portal-Microsoft_AAD_IAM#group-settings
```

```
Locate the Group to convert:
https://graph.microsoft.com/v1.0/groups?$filter=startswith(displayName,'AD')&$select=id,displayName

Document Group ID: (AD-AVDUsers)
GET https://graph.microsoft.com/v1.0/groups/abc11e5a-7aa8-4412-932d-f6d7c946cf7e/onPremisesSyncBehavior?$select=isCloudManaged

fce75b28-01cd-4270-b529-4989b1daf0db

Change the SOA from OnPrem to Cloud
PATCH https://graph.microsoft.com/v1.0/groups/abc11e5a-7aa8-4412-932d-f6d7c946cf7e/onPremisesSyncBehavior

REQUEST BODY:
{
     "isCloudManaged": true
}  
```
> **Group SOA** <https://learn.microsoft.com/en-us/entra/identity/hybrid/how-to-group-source-of-authority-configure>

---

## Understanding the `any()` Function in Microsoft Graph Queries

### What does `/any(c:c eq 'DynamicMembership')` do?

### Example Query

```http
https://graph.microsoft.com/beta/groups?$select=displayName,groupTypes&$filter=groupTypes/any(c:c eq 'DynamicMembership')
```

### Plain English Explanation
This filter means:

- Return only groups where the `groupTypes` collection contains the value `DynamicMembership`.
- This query retrieves only **dynamic groups** from Microsoft Entra ID.

### Why is `any()` Required?
- The `groupTypes` property is **not a single value**, it is a **collection (array)**.
- Examples of values returned by Microsoft Graph:

```json
"groupTypes": []
```
```json
"groupTypes": ["Unified"]
```
```json
"groupTypes": ["DynamicMembership"]
```
```json
"groupTypes": ["Unified", "DynamicMembership"]
```
- Because `groupTypes` is a collection, you **cannot filter it like this**:

```http
groupTypes eq 'DynamicMembership'
```
- OData requires evaluating **each element in the collection**, which is why the `any()` function is required.

### Breaking Down the Syntax

```text
groupTypes/any(c:c eq 'DynamicMembership')
```

| Component | Description |
|-----------|-------------|
| groupTypes | The collection property on the group object |
| any(...)  | OData function that evaluates elements in a collection |
| c         | Temporary variable representing each element |
| c eq 'DynamicMembership' | Condition applied to each element |

**How to read this expression:**
- For each value `c` in `groupTypes`, return the group **if any value equals `DynamicMembership`**.
- If at least one element matches, the group is included in the response.

### What Groups Does This Query Return?
This query returns:

- Dynamic Security Groups
- Dynamic Microsoft 365 Groups

Both group types include the following value:

```json
"groupTypes": ["DynamicMembership"]
```

Microsoft 365 dynamic groups may also include:

```json
"groupTypes": ["Unified", "DynamicMembership"]
```

### Common Filter Variations

**All Dynamic Groups**
```http
groupTypes/any(c:c eq 'DynamicMembership')
```

**Microsoft 365 (Unified) Groups Only**
```http
groupTypes/any(c:c eq 'Unified')
```

**Dynamic Microsoft 365 Groups Only**
```http
groupTypes/any(c:c eq 'Unified') and groupTypes/any(c:c eq 'DynamicMembership')
```

**Non-Dynamic Groups**
```http
not(groupTypes/any(c:c eq 'DynamicMembership'))
```

### Why This Matters in Real-World Graph Usage
The `any()` function is used throughout Microsoft Graph when filtering **collection properties**, including:

- `assignedLicenses/any(...)`
- `proxyAddresses/any(...)`
- `members/any(...)`
- `authenticationMethods/any(...)`

Understanding `any()` allows you to:

- Reverse engineer Entra ID, Intune, and Microsoft 365 portal behavior
- Write precise and safe Microsoft Graph queries
- Avoid targeting unintended objects
- Confidently filter large datasets at scale

### Key Takeaways

- `groupTypes` is a **collection**, not a single value
- `any()` checks whether **at least one element matches a condition**
- This query returns **only dynamic groups**
- Mastering `any()` is essential for effective Microsoft Graph filtering



---

## 🧩 Applications and Enterprise Apps

### App Registrations
```http
GET /v1.0/applications
GET /v1.0/applications/{id}
```

### Enterprise Applications (Service Principals)
```http
GET /v1.0/servicePrincipals
GET /v1.0/servicePrincipals/{id}
GET /v1.0/servicePrincipals/{id}/appRoleAssignments
GET /v1.0/servicePrincipals/{id}/oauth2PermissionGrants
```

---

## Conditional Access and Protection

```http
GET /v1.0/identity/conditionalAccess/policies
GET /v1.0/identity/conditionalAccess/namedLocations
GET /v1.0/identity/conditionalAccess/authenticationStrengths
```

```
https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies

Response: Returns all Conditional Access policies with full details including:

Policy ID, display name, state (enabled/disabled/report-only)
Conditions (users, groups, applications, locations, platforms, etc.)
Grant controls (MFA, compliant device, approved app, etc.)
Session controls (sign-in frequency, persistent browser, etc.)
Authentication strength requirements

?$select=id,displayName,state
?$filter=state eq 'enabled'
```
```
(https://graph.microsoft.com/beta/identity/conditionalAccess/policies?$select=id,displayName,state&$filter=startswith(displayName,'ACME')&$orderby=displayName)
```
> You’re running into a Microsoft Graph beta limitation / bug, not a syntax issue on your side.
```
For Conditional Access policies, the /beta/identity/conditionalAccess/policies endpoint does not reliably enforce startswith() server-side. When this happens, Graph returns all policies and applies only partial or no filtering internally — which is why you’re seeing policies that do not start with ACME.

Key point (important)

There is currently no 100% reliable server-side way to return only CA policies whose displayName starts with a string.

> **Rule**: If the Entra blade is under **Protection**, the Graph path usually starts with `/identity`.
```



---

## 🔑 Authentication & Passwordless

### Tenant-wide Authentication Policies
```http
GET /v1.0/authenticationMethodsPolicy
GET /beta/authenticationMethodsPolicy
GET /beta/policies/authenticationMethodsPolicy
```
`Policies/AuthenticationMethodsPolicy`
```
**This endpoint returns a single singleton policy, not a collection.**

So:

❌ $filter

❌ $select for sub-objects

❌ “enabled only”

…are not supported, because there is only one policy object per tenant.
```

`Getting Familiar with different Authentication types`
> <https://learn.microsoft.com/en-us/graph/api/resources/authenticationmethod?view=graph-rest-beta>

### FIDO2 & Passkeys
```http

GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations

GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/FIDO2
GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/microsoftAuthenticator
GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/temporaryAccessPass
GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/sms
GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/voice
GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/email
GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/softwareOath
GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/hardwareOath
GET /beta/authenticationMethodsPolicy/authenticationMethodConfigurations/x509Certificate

```
```
authenticationMethodsPolicy
└── authenticationMethodConfigurations
    ├── fido2
    ├── microsoftAuthenticator
    ├── temporaryAccessPass
    ├── softwareOath
    ├── hardwareOath
    ├── sms
    ├── voice
    ├── email
    └── x509Certificate

```

![Beta vs V1 Endpoint with FIDO2](https://github.com/Jhope188/LearnGraphAPI/blob/main/Images/V1vsBetaEndpoint.png)


>🔑 Permissions required
```
Read: Policy.Read.AuthenticationMethod

Write: Policy.ReadWrite.AuthenticationMethod

(Global Admin or Authentication Policy Admin role required)
```


### Per-user Authentication Methods
```http
GET /v1.0/users/{id}/authentication/methods
```

---

## 📜 Audit Logs & Reports

### Audit Logs
```http
GET /v1.0/auditLogs/signIns
GET /v1.0/auditLogs/directoryAudits
```

### Reports
```http
GET /v1.0/reports/authenticationMethodsUserRegistrationDetails
GET /v1.0/reports/credentialUserRegistrationDetails
GET /v1.0/reports/signInActivity
```

---

## 🧭 Identity Governance

### Access Reviews
```http
GET /v1.0/identityGovernance/accessReviews/definitions
GET /v1.0/identityGovernance/accessReviews/instances
```

### Entitlement Management
```http
GET /v1.0/identityGovernance/entitlementManagement/catalogs
GET /v1.0/identityGovernance/entitlementManagement/accessPackages
```

---

## ⚙️ Tenant & Directory Settings

```http
GET /v1.0/organization
GET /v1.0/domains
GET /v1.0/directoryRoles
GET /v1.0/subscribedSkus
```

---

## 🔎 Entra Portal → Graph Mapping Rules

| Entra Portal Area | Likely Graph Root |
|------------------|------------------|
| Users / Groups | `/users`, `/groups` |
| Enterprise Apps | `/servicePrincipals` |
| App Registrations | `/applications` |
| Protection | `/identity` |
| Policies | `/policies`, `/authenticationMethodsPolicy` |
| Reports | `/reports` |
| Logs | `/auditLogs` |

---

## 🧠 Graph Discovery Workflow (Reusable)

1. Identify the Entra blade (Users, Protection, Identity, Policies)
2. Open **Graph Explorer** and start with `/beta`
3. Inspect the response for `@odata.type`
4. Validate properties in `$metadata`
5. Confirm permissions in Graph Explorer
6. Prefer `/v1.0` for automation when available
7. Track beta → v1.0 promotion

---

## 🧪 Reverse-Engineering Entra Portal Calls

1. Open **https://entra.microsoft.com**
2. Open Browser DevTools → Network
3. Filter for `graph.microsoft.com`
4. Navigate to the blade
5. Copy the `GET` request backing the UI
6. Paste into Graph Explorer or PowerShell

---

## 🔑 Common Read Permissions

| Data Type | Permission |
|---------|------------|
| Users | `User.Read.All` |
| Groups | `Group.Read.All` |
| Directory | `Directory.Read.All` |
| Policies | `Policy.Read.All` |
| Auth Methods | `AuthenticationMethod.Read.All` |
| Logs | `AuditLog.Read.All` |
| Reports | `Reports.Read.All` |

---

## 📌 Notes
- Most Entra innovation appears in **/beta** first
- `$metadata` is always authoritative
- Portal network calls reveal undocumented APIs


---

**Audience**: Entra ID engineers, identity architects, security engineers

**Maintenance Tip**: Review this document quarterly and diff `/beta/$metadata` for new resource types






# Microsoft Graph OData Metadata – Reference & Usage Guide

This document explains **what the Microsoft Graph `$metadata` endpoint is**, **how to read it**, and **how to translate metadata into practical OData query usage** when working with Microsoft Entra (Azure AD) resources.

---

## 1. What is `$metadata` in Microsoft Graph

The `$metadata` endpoint exposes the **entire service schema** for Microsoft Graph using the **OData v4 EDMX (Entity Data Model XML)** format.

```
GET https://graph.microsoft.com/v1.0/$metadata
GET https://graph.microsoft.com/beta/$metadata
```

It describes:

- Entity types (users, groups, devices, etc.)
- Properties and their data types
- Navigation properties (relationships)
- Inheritance
- Collections vs singletons
- Actions and functions

Think of `$metadata` as the **authoritative contract** for Graph.

---

## 2. Why `$metadata` matters (especially for Entra)

You use metadata to:

- Discover **all properties** (even undocumented ones)
- Understand **relationships** between resources
- Determine **what can be selected, expanded, or filtered**
- Build **SDKs, schemas, or automation safely**
- Explain **why a query fails** (unsupported filters/orderby)

The Entra Admin Center is built **directly on this schema**.

---

## 3. High-level structure of the metadata file

The metadata document is XML and follows this hierarchy:

```
Edmx
 └── DataServices
      └── Schema (Namespace="microsoft.graph")
           ├── EntityType
           ├── ComplexType
           ├── EnumType
           ├── EntityContainer
```

---

## 4. EntityType → Graph Resource Mapping

Each **EntityType** maps to a Graph resource.

### Example: User

```xml
<EntityType Name="user" BaseType="graph.directoryObject">
  <Property Name="displayName" Type="Edm.String" />
  <Property Name="accountEnabled" Type="Edm.Boolean" />
  <Property Name="userPrincipalName" Type="Edm.String" />
  <NavigationProperty Name="memberOf" Type="Collection(graph.directoryObject)" />
</EntityType>
```

### Graph endpoint

```
/users
/users/{id}
```

---

## 5. Property → OData `$select`

Every `<Property>` element is selectable.

### Metadata

```xml
<Property Name="displayName" Type="Edm.String" />
```

### OData usage

```http
GET /users?$select=id,displayName
```

If it appears in metadata, it **can be selected**.

---

## 6. Property types and OData behavior

| EDM Type             | Meaning    | OData impact           |
| -------------------- | ---------- | ---------------------- |
| `Edm.String`         | Text       | Filterable sometimes   |
| `Edm.Boolean`        | true/false | Often filterable       |
| `Edm.DateTimeOffset` | Timestamp  | Filterable & sortable  |
| `Edm.Guid`           | Object ID  | Filterable             |
| `Collection(...)`    | Array      | Limited filter support |

---

## 7. NavigationProperty → `$expand`

Navigation properties define **relationships**.

### Metadata

```xml
<NavigationProperty Name="memberOf" Type="Collection(graph.directoryObject)" />
```

### OData usage

```http
GET /users/{id}/memberOf
```

or

```http
GET /users/{id}?$expand=memberOf
```

> ⚠️ `$expand` is **heavily restricted** in Graph and often capped or blocked.

---

## 8. Inheritance (BaseType)

Many Entra objects inherit from `directoryObject`.

```xml
<EntityType Name="user" BaseType="graph.directoryObject" />
```

This means users inherit:

- `id`
- `deletedDateTime`

Available to all directory objects.

---

## 9. EntityContainer → Root endpoints

The **EntityContainer** defines top-level Graph paths.

```xml
<EntityContainer Name="GraphService">
  <EntitySet Name="users" EntityType="graph.user" />
</EntityContainer>
```

Maps directly to:

```
/users
```

---

## 10. Actions & Functions

Metadata also defines callable operations.

### Example

```xml
<Action Name="assignLicense" IsBound="true">
```

### Graph call

```http
POST /users/{id}/assignLicense
```

If it exists in metadata → it exists in Graph.

---

## 11. Metadata vs OData query options

| Metadata element   | OData feature              |
| ------------------ | -------------------------- |
| Property           | `$select`, `$filter`       |
| NavigationProperty | `$expand`, child endpoints |
| EntitySet          | Root endpoint              |
| EntityType         | Resource schema            |
| Action             | POST operation             |
| Function           | GET operation              |

---

## 12. Why metadata does NOT guarantee query support

Important limitation:

> **Metadata shows what exists — not what is indexed.**

So even if a property exists:

- `$filter` may fail
- `$orderby` may fail
- `$expand` may be blocked

Example:

```xml
<Property Name="accountEnabled" Type="Edm.Boolean" />
```

But:

```http
$filter=accountEnabled eq true   ✅
$orderby=accountEnabled          ❌
```

Indexing is a **service-level decision**, not metadata.

---

## 13. v1.0 vs beta metadata

| Version | Purpose                           |
| ------- | --------------------------------- |
| v1.0    | Production-supported schema       |
| beta    | Preview, experimental, incomplete |

Always compare:

```
/v1.0/$metadata
/beta/$metadata
```

Beta often exposes:

- New authentication methods
- Passkey / FIDO2 extensions
- Governance features

---

## 14. Practical workflow (recommended)

1. Inspect `$metadata`
2. Identify EntityType
3. Identify Properties & NavigationProperties
4. Build `$select` first
5. Add `$filter`
6. Assume client-side `$orderby`
7. Follow `@odata.nextLink`

---

## 15. Mental model summary

- `$metadata` = **schema truth**
- OData = **query language**
- Graph = **restricted OData implementation**
- Portal = **Graph + client-side logic**

---

## 16. Key takeaway

If you understand `$metadata`, you can:

- Predict Graph behavior
- Reverse engineer portal calls
- Avoid unsupported queries
- Build resilient Entra automation

---


# Microsoft Graph Intune Device Management – Metadata & OData Usage Guide

This document explains **how Microsoft Intune (device management) endpoints are modeled in Microsoft Graph**, how to **read the metadata**, and how to **safely use OData query options** against Intune resources.

It is intentionally parallel to the Entra OData guide, but focused on:

- `deviceManagement/*`
- Intune-backed resources
- Intune-specific OData constraints

---

## 1. Intune in Microsoft Graph (big picture)

All Intune APIs live under the **`deviceManagement` namespace** in Microsoft Graph.

```
https://graph.microsoft.com/v1.0/deviceManagement
https://graph.microsoft.com/beta/deviceManagement
```

Unlike Entra directory objects, **Intune data is service-backed**, not directory-backed.

This distinction explains why:

- `$orderby` often works in Intune
- `$filter` is more permissive
- `$expand` is still limited

---

## 2. Intune `$metadata` endpoints

```
GET https://graph.microsoft.com/v1.0/$metadata
GET https://graph.microsoft.com/beta/$metadata
```

Search within metadata for:

```
Namespace="microsoft.graph"
EntityType Name="managedDevice"
EntityType Name="deviceConfiguration"
```

All Intune entities are defined here.

---

## 3. Core Intune entity types (most used)

| EntityType               | Graph endpoint                               | Portal blade                     |
| ------------------------ | -------------------------------------------- | -------------------------------- |
| `managedDevice`          | `/deviceManagement/managedDevices`           | Devices → All devices            |
| `deviceConfiguration`    | `/deviceManagement/deviceConfigurations`     | Devices → Configuration profiles |
| `deviceCompliancePolicy` | `/deviceManagement/deviceCompliancePolicies` | Devices → Compliance policies    |
| `mobileApp`              | `/deviceManagement/mobileApps`               | Apps → All apps                  |
| `deviceManagementScript` | `/deviceManagement/deviceManagementScripts`  | Devices → Scripts                |
| `deviceHealthScript`     | `/deviceManagement/deviceHealthScripts`      | Devices → Proactive remediations |

---

## 4. Example: `managedDevice` metadata

```xml
<EntityType Name="managedDevice">
  <Property Name="id" Type="Edm.String" />
  <Property Name="deviceName" Type="Edm.String" />
  <Property Name="operatingSystem" Type="Edm.String" />
  <Property Name="osVersion" Type="Edm.String" />
  <Property Name="complianceState" Type="graph.complianceState" />
  <Property Name="managementAgent" Type="graph.managementAgentType" />
  <NavigationProperty Name="users" Type="Collection(graph.user)" />
</EntityType>
```

---

## 5. Property → `$select` (Intune)

Every `<Property>` is selectable.

```http
GET /deviceManagement/managedDevices?
$select=id,deviceName,operatingSystem,complianceState
```

Best practice:

- Always `$select`
- Intune objects are **large**

---

## 6. `$filter` support (much better than Entra)

Intune supports filtering on many properties.

### Common examples

```http
GET /deviceManagement/managedDevices?
$filter=operatingSystem eq 'Windows'
```

```http
$filter=complianceState eq 'compliant'
```

```http
$filter=startswith(deviceName,'AVD')
```

Enums (like `complianceState`) are defined in metadata as `EnumType`.

---

## 7. `$orderby` (generally supported)

Unlike Entra directory objects, **Intune supports server-side sorting**.

```http
GET /deviceManagement/managedDevices?
$orderby=deviceName asc
```

⚠️ Sorting still requires:

- Property to be scalar
- No complex navigation expansion

---

## 8. Pagination and `@odata.nextLink`

Default page size is **100** (varies by endpoint).

```json
"@odata.nextLink": "https://graph.microsoft.com/..."
```

Rules:

- Always follow `nextLink`
- Never assume `$top` returns everything

---

## 9. NavigationProperty → child endpoints

Navigation properties define **supported child routes**.

### Metadata

```xml
<NavigationProperty Name="deviceCompliancePolicyStates"
  Type="Collection(graph.deviceCompliancePolicyState)" />
```

### Graph usage

```http
GET /deviceManagement/managedDevices/{id}/deviceCompliancePolicyStates
```

Intune strongly prefers **child endpoints** over `$expand`.

---

## 10. `$expand` (use sparingly)

Some Intune resources support `$expand`, but many do not.

```http
GET /deviceManagement/managedDevices?$expand=users
```

Common outcomes:

- Partial expansion
- Throttling
- UnsupportedQuery errors

➡️ Prefer separate calls.

---

## 11. Actions in Intune metadata

Actions are **POST operations** defined in metadata.

### Metadata

```xml
<Action Name="syncDevice" IsBound="true" />
```

### Graph

```http
POST /deviceManagement/managedDevices/{id}/syncDevice
```

Portal buttons almost always map to actions.

---

## 12. Assignments (critical Intune pattern)

Assignments are modeled as **child collections**, not properties.

### Example: App assignments

```http
GET /deviceManagement/mobileApps/{id}/assignments
```

Same pattern for:

- Configuration profiles
- Compliance policies
- Scripts

---

## 13. v1.0 vs beta (Intune reality)

| Version | Reality                               |
| ------- | ------------------------------------- |
| v1.0    | Stable, lagging features              |
| beta    | Required for most new Intune features |

Examples only in beta:

- Endpoint Privilege Management
- Advanced reporting
- Some remediation APIs

---

## 14. Common Intune OData pitfalls

| Issue             | Cause                       |
| ----------------- | --------------------------- |
| UnsupportedQuery  | `$expand` or invalid filter |
| Throttling        | Large tenant + no `$select` |
| Missing data      | Not following `nextLink`    |
| Enum filter fails | Wrong enum string           |

---

## 15. Safe query pattern (recommended)

```http
GET /deviceManagement/managedDevices?
$select=id,deviceName,operatingSystem,complianceState
&$filter=operatingSystem eq 'Windows'
&$orderby=deviceName
```

Then:

- Page with `nextLink`
- Join related data client-side

---

## 16. Mental model (Intune vs Entra)

| Aspect     | Entra      | Intune       |
| ---------- | ---------- | ------------ |
| Backend    | Directory  | Service DB   |
| `$orderby` | Rare       | Common       |
| `$filter`  | Restricted | Flexible     |
| `$expand`  | Limited    | Very limited |
| Pagination | Required   | Required     |

---

## 17. Key takeaways

- Intune Graph is **OData-friendly but opinionated**
- Metadata tells you **what exists**, not limits
- Prefer **child endpoints over `$expand`**
- Always `$select` and page

---

## 18. Recommended next steps

- Annotated metadata walkthrough for `managedDevice`
- Assignment model deep dive
- Portal blade → Graph → metadata mapping
- PowerShell SDK vs raw REST comparison

---

Understanding Intune metadata + OData gives you **portal-level automation without guessing**.


**Example Usage** 

- Scopes required: 

Pulling all powershell scripts from Intune using the API

```
https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts
```

![Get Avaialable Intune Platform Scripts](https://github.com/Jhope188/LearnGraphAPI/blob/main/Images/GetScriptfromIntunePlatformScripts.png)


```
https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/{deviceManagementScript-id}$select=scriptContent

```

![Get Script Platform Script Content](https://github.com/Jhope188/LearnGraphAPI/blob/main/Images/SortScriptContent.png)

Here you would copy the script content from its base64 encoding into an editor

```
https://www.base64decode.org/
```

This would give you the content of the script for review

![Decode content in Base64 decoder](https://github.com/Jhope188/LearnGraphAPI/blob/main/Images/ConvertfromBase64.png)

**Working Example**
```
https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/c7cd4ba5-ccbf-4c9a-9be5-e22cda7379b0?$select=scriptContent
```

# Microsoft Graph `$select` Query Option

## ❓ What does the `?` before `$select` mean?

In Microsoft Graph, the `?` indicates the **start of query options** for an HTTP request. Everything after `?` modifies *how* data is returned, not *what* endpoint you are calling.

---

## 📌 Basic Structure

```http
GET https://graph.microsoft.com/v1.0/users?$select=id,displayName
```

- `/users` → **resource path** (what you are querying)
- `?` → **start of query string**
- `$select` → **OData query option**

---

## 🔍 Why `$select` needs `?`

HTTP URLs follow a standard structure:

```text
/path?queryKey=value&queryKey=value
```

In Microsoft Graph:

- `?` starts the query section
- `&` chains multiple query options

### Example with multiple query options

```http
GET /v1.0/users?$select=id,displayName,userPrincipalName&$top=10
```

---

## 🧪 Common OData Query Options

| Query Option | Purpose                    | Example                           |
| ------------ | -------------------------- | --------------------------------- |
| `$select`    | Return specific properties | `?$select=id,displayName`         |
| `$filter`    | Filter results             | `?$filter=accountEnabled eq true` |
| `$expand`    | Include related objects    | `?$expand=memberOf`               |
| `$top`       | Limit results              | `?$top=25`                        |
| `$orderby`   | Sort results               | `?$orderby=displayName`           |
| `$count`     | Include count              | `?$count=true`                    |

---

## 📦 Example: Without vs With `$select`

### ❌ Without `$select`

```http
GET /v1.0/users
```

Returns **many default properties** per user, resulting in a larger payload.

---

### ✅ With `$select`

```http
GET /v1.0/users?$select=id,displayName,userPrincipalName
```

Returns **only the properties you explicitly request**.

**Benefits**:

- Smaller response payloads
- Faster queries
- Clear, intentional documentation

---

## ⚠️ Important Rules and Limitations

- `$select` **does not grant or change permissions**
- Some properties:

  - Require **additional permissions**
  - Are **not selectable** on certain endpoints
- `$select=*` is **not supported** in Microsoft Graph

---

## 🧠 Mental Model

```text
/users           → what data you are requesting
?                → how the data should be returned
$select=prop     → which fields are included
&$filter=...     → which records are returned
```

---

## ✍️ Documentation-Friendly Example

````md
### Example: Select Specific User Properties

```http
GET /v1.0/users?$select=id,displayName,userPrincipalName
````

**Description**: Returns a list of users with only ID, display name, and user principal name.

**Permissions Required**:

- `User.Read.All`

**Notes**:

- Use `$select` to reduce payload size
- Combine with `$filter` for targeted queries

```

---

## 📌 Summary

- `?` starts the query string in a Graph request
- `$select` controls which properties are returned
- Using `$select` improves performance and clarity
- Always pair `$select` with the minimum required permissions

---

**Audience**: Entra ID engineers, security engineers, Graph API consumers

**Recommended Use**: Internal documentation, team wikis, API reference guides

```


# HTTP Methods Overview for Microsoft Graph API

This document provides a concise reference for the main HTTP methods used in Microsoft Graph, their purposes, and behavior.

---

## 1️⃣ GET

- **Purpose**: Retrieve data from a resource.
- **Idempotent**: ✅ (safe to call multiple times without changing server state)
- **Request Body**: Not typically used
- **Response**: Returns the resource(s) in JSON format

**Example**:

```http
GET /v1.0/users?$select=displayName,userPrincipalName
```

---

## 2️⃣ POST

- **Purpose**: Create a new resource or invoke an action.
- **Idempotent**: ❌ (calling multiple times may create multiple resources)
- **Request Body**: Required, contains data for creation or action parameters
- **Response**: Returns the created resource or action result

**Example**:

```http
POST /v1.0/groups
Content-Type: application/json

{
  "displayName": "New Team",
  "mailEnabled": false,
  "mailNickname": "newteam",
  "securityEnabled": true
}
```

---

## 3️⃣ PUT

- **Purpose**: Replace an existing resource entirely.
- **Idempotent**: ✅ (replacing the resource with the same data multiple times has no additional effect)
- **Request Body**: Required, must contain full resource representation
- **Response**: Usually returns `204 No Content`

**Example**:

```http
PUT /v1.0/groups/{id}
Content-Type: application/json

{
  "displayName": "Updated Team Name",
  "mailEnabled": false,
  "mailNickname": "updatedteam",
  "securityEnabled": true
}
```

---

## 4️⃣ PATCH

- **Purpose**: Update parts of an existing resource.
- **Idempotent**: ✅ (updating the same properties with same values multiple times has no effect)
- **Request Body**: Contains only the fields to update
- **Response**: Usually returns `204 No Content`

**Example**:

```http
PATCH /v1.0/groups/{id}
Content-Type: application/json

{
  "displayName": "Partially Updated Name"
}
```

---

## 5️⃣ DELETE

- **Purpose**: Remove a resource.
- **Idempotent**: ✅ (deleting the same resource multiple times has no effect)
- **Request Body**: Not used
- **Response**: Usually returns `204 No Content`

**Example**:

```http
DELETE /v1.0/groups/{id}
```

---

### Quick Comparison Table

| Method | Purpose                         | Idempotent | Body Required | Response                         |
| ------ | ------------------------------- | ---------- | ------------- | -------------------------------- |
| GET    | Retrieve resource(s)            | ✅          | No            | JSON data                        |
| POST   | Create resource / invoke action | ❌          | Yes           | Created resource / action result |
| PUT    | Replace resource entirely       | ✅          | Yes           | 204 No Content                   |
| PATCH  | Update part of resource         | ✅          | Yes           | 204 No Content                   |
| DELETE | Remove resource                 | ✅          | No            | 204 No Content                   |

---

**Notes**:

- Idempotent methods are safe for retries.
- POST is used for creation and actions that may have side effects.
- PATCH is preferred for partial updates to reduce payload and avoid overwriting unchanged properties.
- Always check required permissions for each operation in Microso
