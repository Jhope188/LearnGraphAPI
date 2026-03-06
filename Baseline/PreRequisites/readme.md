# Inforcer Prerequisites for Microsoft 365 Business Premium

## Manual Prerequisites Before Deploying Policies via Inforcer

These settings **must be completed manually** in the tenant **before** deploying policies.  
Follow the steps **in order**. The checklist is grouped by portal for clarity.

---

## Prerequisite Checklist (Execution Order)

| Step | Prerequisite | Portal |
|-----:|--------------|--------|
| 1 | Create Intune Enrollment + Azure Credential Configuration Endpoint Service enterprise apps | Entra |
| 2 | Configure MDM user scope for automatic enrollment | Entra |
| 3 | Enable Exchange organization configuration | Exchange Online |
| 4 | Provision Microsoft Defender for Endpoint (open Defender portal) | Defender |
| 5 | Verify Tamper Protection is On (enabled by default) | Defender |
| 6 | Enable Microsoft Defender for Endpoint connector (Defender + Intune) | Defender / Intune |
| 7 | Review Intune platform restrictions baseline | Intune |
| 8 | Set Windows Hello for Business to **Not configured** | Intune |
| 9 | Enable Windows diagnostic data for Intune | Intune |
| 10 | Exclude break-glass accounts from all Conditional Access policies | Entra |
| 11 | *(Optional)* Configure named locations (Blocked / Allowed countries) | Entra |

---

## Step 1. Create Required Enterprise Applications (Entra)

Create both service principals **before** configuring Conditional Access so they appear as targetable cloud apps.

### Why this matters

- **Microsoft Intune Enrollment**
  - Not always auto-created in new tenants
  - Without it, *Intune Enrollment* does not appear in Conditional Access
- **Azure Credential Configuration Endpoint Service**
  - Required for passkey registration in Microsoft Authenticator
  - Must be excluded from certain CA policies (device compliance / APP) to avoid blocking passkey registration

### How

```powershell
Connect-MgGraph -Scopes "Application.ReadWrite.All"

New-MgServicePrincipal -AppId "d4ebce55-015a-49b5-a083-c84d1797ae8c"
New-MgServicePrincipal -AppId "ea890292-c8c8-4433-b5ea-b09d0668e1a6"
```

### Verify

Entra admin center → **Enterprise applications**  
Confirm both apps appear.

---

## Step 2. Configure MDM User Scope (Entra)

MDM user scope controls who can enroll devices in Intune.

**Path:** Entra → Devices → Enrollment → Microsoft Intune  
Set **MDM user scope** to **All** or **Some**.

---

## Step 3. Enable Exchange Organization Configuration (Exchange Online)

Exchange tenants are often dehydrated by default.

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
Connect-ExchangeOnline
Enable-OrganizationCustomization
Get-OrganizationConfig | Select IsDehydrated
```

```powershell
$OrgConfigParams = @{
    AuditDisabled              = $false
    OAuth2ClientProfileEnabled = $true
    MailTipsAllTipsEnabled     = $true
    RejectDirectSend           = $true
}

Set-OrganizationConfig @OrgConfigParams
Disconnect-ExchangeOnline -Confirm:$false
```

---

## Step 4. Provision Microsoft Defender for Endpoint

Sign in to https://security.microsoft.com as a Global or Security Admin.  
Navigate to **Assets → Devices** to trigger provisioning if the portal hasn't been activated yet.  
Complete the initial setup wizard or dismiss it to proceed with manual configuration.

---

## Step 5. Verify Tamper Protection

Tamper Protection is **enabled by default** for all enterprise customers via [Built-in Protection](https://learn.microsoft.com/en-us/defender-endpoint/built-in-protection).  
Verify it is On: Defender portal → **Settings → Endpoints → Advanced features**  
Confirm **Tamper Protection** is set to **On**.

---

## Step 6. Enable Defender for Endpoint Connector (Intune + Defender)

This is a **two-sided** connection:

1. **Defender portal** → Settings → Endpoints → Advanced features → Toggle **Microsoft Intune connection** to **On** → Save preferences  
2. **Intune admin center** → Endpoint security → Microsoft Defender for Endpoint → Confirm **Connection status** shows **Enabled**

> **Note:** It can take up to 15 minutes for the connection status to update after enabling the Defender-side toggle.

---

## Step 7. Review Intune Platform Restrictions

Intune → **Devices → Device onboarding → Enrollment → Device platform restriction**  
Ensure required platforms are allowed.  
Recommended: Block personal devices unless explicitly required.

---

## Step 8. Windows Hello for Business

Intune → Devices → Enrollment → Windows Hello for Business  
Set to **Not configured**.

---

## Step 9. Enable Windows Diagnostic Data

Intune → Tenant administration → Connectors and tokens → Windows data  
Enable features requiring Windows diagnostic data.

---

## Step 10. Break-Glass Account Exclusions

Exclude emergency access accounts from **all** Conditional Access policies.

---

## Step 11. Optional – Named Locations

Create:
- **IAC – Blocked Countries**
- **IAC – Allowed Countries**

Populate before enabling CA policies to avoid lockout.
