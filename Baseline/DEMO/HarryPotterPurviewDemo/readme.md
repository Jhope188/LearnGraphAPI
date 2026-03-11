# 🛡️ Microsoft Purview Demo Walkthrough

## The Battle for Hogwarts — Sensitivity Labels, Copilot Oversharing & Restricted SharePoint Search

> **Tenant:** acme2m365.onmicrosoft.com  
> **Presenter:** Jon Hope (Global Admin)  
> **Estimated Demo Time:** 30–45 minutes

---

## 🎭 The Story

> *Dolores Umbridge has been appointed Senior Undersecretary to the Minister and is using her position to spy on Dumbledore's Army. She's discovered that Microsoft 365 Copilot can search across SharePoint — and she intends to use it to expose every secret the Order of the Phoenix is hiding.*
>
> *Your job: use Microsoft Purview Sensitivity Labels and Restricted SharePoint Search to ensure that only trusted Gryffindor members can access the Order's most sensitive documents — even when Copilot is involved.*

---

## 📋 Prerequisites Checklist

> ⏱️ **Allow at least 24 hours** before the demo for all scripts to propagate fully.  
> Run scripts in the order listed below. Each script accepts `-TenantDomain` so it can be reused in any tenant.

---

### 🖥️ Script Run Order

#### STEP 1 — Create Users & Groups
```powershell
pwsh Characters/Create-HarryPotterUsers.ps1 -TenantDomain "contoso.onmicrosoft.com"
```
> Creates all 21 Harry Potter demo users with correct Department, JobTitle, and OfficeLocation (house) attributes. Also creates the four Hogwarts house **dynamic security groups** (Gryffindor, Slytherin, Ravenclaw, Hufflepuff) with membership rules based on `physicalDeliveryOfficeName`.  
> ⏱️ Dynamic group membership populates within 15 min – 2 hours.

---

#### STEP 2 — Create SharePoint Sites
```powershell
pwsh Sharepoint/Create-HarryPotterDemoEnvironment.ps1
pwsh Sharepoint/Create-HarryPotterSharePointDemo.ps1
```
> **First script:** Creates 20 SharePoint sites as M365 Groups (Snape's Potions Lab, Gringotts, Daily Prophet, etc.) with demo documents uploaded to each.  
> **Second script:** Creates the **Order of the Phoenix** site separately with its sensitive documents (Dumbledore's Army.docx etc.).

---

#### STEP 3 — Create Hogwarts Staff Group & Grant Site Access
```powershell
pwsh Scripts/Create-HogwartsStaffGroup.ps1 -TenantDomain "contoso.onmicrosoft.com"
```
> Creates `🏰 Hogwarts Staff` as an **M365 Unified group** with 9 members (all Hogwarts Faculty + Administration + Dolores Umbridge explicitly). Then adds every member to all 21 SharePoint site M365 groups — giving Dolores broad access required for Act 1 (oversharing demonstration).  
> ⚠️ Dolores is `Department = "Ministry Leadership"` so she is added manually, not via a dynamic rule.

---

#### STEP 4 — Create Gryffindor M365 Dynamic Group (for label encryption)
```powershell
pwsh Scripts/Create-GryffindorM365Group.ps1 -TenantDomain "contoso.onmicrosoft.com"
```
> Creates `🦁 Gryffindor – M365 Dynamic User Group` as an **M365 Unified Dynamic group** (separate from the security group created in Step 1). This group has a mail address (`GryffindorM365@tenant`) which is required for sensitivity label encryption scoping — security groups have no email address and cannot be used directly in label rights definitions.  
> ⏱️ Dynamic membership populates within 15 min – 2 hours.

---

#### STEP 5 — Enable Sensitivity Label Prerequisites
```powershell
pwsh Purview/Enable-SensitivityLabelsPrerequisites.ps1 -TenantId "contoso.onmicrosoft.com"
```
> Enables three prerequisites needed before sensitivity labels work on Groups & Sites:
> 1. `EnableMIPLabels = True` in Group.Unified directory settings (via Graph)
> 2. `isSensitivityLabelsEnabled = True` in SharePoint tenant settings (via Graph)
> 3. Runs `Execute-AzureADLabelSync` to sync Purview labels to Entra ID  
> ⏱️ Requires **up to 24 hours** to fully propagate. Run this the day before the demo.

---

#### STEP 6 — Create Sensitivity Label & Publish Policy
```powershell
pwsh Scripts/Setup-PurviewDemo.ps1 -TenantDomain "contoso.onmicrosoft.com" -SkipSitePermissions
```
> Creates the `🛡️ Order of the Phoenix — Restricted` sensitivity label with:
> - Encryption scoped to Gryffindor group members (Co-Author rights)
> - Header: `ORDER OF THE PHOENIX — RESTRICTED`
> - Footer: `Access restricted to Gryffindor members only`
> - Watermark: `CONFIDENTIAL — OotP`
>
> Then publishes the **Order of the Phoenix Protection Policy** to all users.  
> ⏱️ Label appears in Office apps within ~1 hour. Full policy propagation up to 24 hours.  
> ℹ️ Use `-SkipSitePermissions` flag since Step 3 already handled site access.

---

### ✅ Pre-Demo Verification Checklist

| # | Check | How to Verify | Done |
|---|-------|---------------|------|
| 1 | 21 Harry Potter users exist | Entra ID → Users → filter by domain | ☐ |
| 2 | House dynamic groups populated | Entra ID → Groups → `🦁 Gryffindor – Dynamic User Group` → Members (expect 6) | ☐ |
| 3 | `🦁 Gryffindor – M365 Dynamic User Group` has members | Entra ID → Groups → Members tab (same 6 members) | ☐ |
| 4 | `🏰 Hogwarts Staff` group has 9 members | Entra ID → Groups → `🏰 Hogwarts Staff` → Members | ☐ |
| 5 | Dolores is a member of all 21 sites | SharePoint Admin → Active sites → any site → Membership → Members | ☐ |
| 6 | Sensitivity label visible in Purview | compliance.microsoft.com → Information Protection → Labels | ☐ |
| 7 | Label policy published | Information Protection → Label policies → `Order of the Phoenix Protection Policy` | ☐ |
| 8 | Copilot for M365 licences assigned | M365 Admin → Billing → Licences → assign to Dolores + Harry Potter | ☐ |
| 9 | 24-hour propagation window elapsed | Check timestamp from Step 5 | ☐ |
| 10 | Dolores signed out and back in fresh | Required to pick up new group membership tokens | ☐ |

### Key Characters

| Character | UPN | House | Role in Demo |
|-----------|-----|-------|-------------|
| **Dolores Umbridge** | `dolores.umbridge@Inforcer2m365.onmicrosoft.com` | 🐍 Slytherin | The adversary — tries to access restricted content via Copilot |
| **Harry Potter** | `harry.potter@Inforcer2m365.onmicrosoft.com` | 🦁 Gryffindor | The hero — has legitimate access to Order/DA sites |
| **Hermione Granger** | `hermione.granger@Inforcer2m365.onmicrosoft.com` | 🦁 Gryffindor | Alternative hero account for testing |

### 🦁 Gryffindor Dynamic Group Members

> **Group:** `🦁 Gryffindor – Dynamic User Group`  
> **Group ID:** `0d40e5d7-3dba-4c4f-bbe7-3e8456ae5e20`  
> **Membership Rule:** `user.physicalDeliveryOfficeName -eq "Gryffindor"`

| Member | UPN |
|--------|-----|
| Harry Potter | `harry.potter@Inforcer2m365.onmicrosoft.com` |
| Hermione Granger | `hermione.granger@Inforcer2m365.onmicrosoft.com` |
| Ron Weasley | `ron.weasley@Inforcer2m365.onmicrosoft.com` |
| Albus Dumbledore | `albus.dumbledore@Inforcer2m365.onmicrosoft.com` |
| Minerva McGonagall | `minerva.mcgonagall@Inforcer2m365.onmicrosoft.com` |
| Neville Longbottom | `neville.longbottom@Inforcer2m365.onmicrosoft.com` |

### 🏰 Key SharePoint Sites for This Demo

| Site | URL | Group ID | Documents |
|------|-----|----------|-----------|
| **Order of the Phoenix** | `https://Inforcer2m365.sharepoint.com/sites/OrderOfThePhoenix` | `3089b4c4-56f8-4047-a3cc-e3e846f71025` | Dumbledore's Army.docx |
| **Dumbledores Army HQ** | `https://Inforcer2m365.sharepoint.com/sites/DumbledoresArmy` | `7153419a-cc7a-432e-a5f9-d129942beae7` | DA Membership Roster.xlsx, DA Training Curriculum.pptx, The DA Charter - KEEP SECRET.docx |

---

## 🎬 ACT 1 — The Problem: Copilot Oversharing

> **Goal:** Show that without Sensitivity Labels, Copilot will happily surface sensitive content to *anyone* with a licence — including Dolores Umbridge.

### Step 1.1 — Log in as Dolores Umbridge

1. Open a **private/incognito browser window**
2. Navigate to **https://microsoft365.com**
3. Sign in as:
   - **Username:** `dolores.umbridge@Inforcer2m365.onmicrosoft.com`
   - **Password:** *(use TAP or password from user creation script)*

### Step 1.2 — Open Microsoft 365 Copilot

1. Click the **Copilot** icon in the left nav (or go to `https://microsoft365.com/chat`)
2. In the Copilot chat, type:

   > **"List all SharePoint sites I have access to"**

3. **🎤 Talking Point:** *"Notice how Copilot can discover and list all SharePoint sites in the tenant. Dolores — a Slytherin and Ministry bureaucrat — can see everything, including the Order of the Phoenix and Dumbledore's Army HQ sites."*

### Step 1.3 — Ask Copilot for Sensitive Content

1. In Copilot, type:

   > **"What is in the DA Charter document in Dumbledore's Army HQ?"**

2. Then try:

   > **"Show me the membership roster for Dumbledore's Army"**

3. And:

   > **"Find all documents about the Order of the Phoenix"**

4. **🎤 Talking Point:** *"Copilot is doing exactly what it's designed to do — making information easy to find. But that's the problem. Dolores Umbridge has no business seeing Dumbledore's Army charter or the Order's secret communications. This is the oversharing problem — Copilot respects permissions, but if permissions are too broad, sensitive content leaks."*

### Step 1.4 — Visit the SharePoint Sites Directly

1. Navigate to `https://Inforcer2m365.sharepoint.com/sites/OrderOfThePhoenix`
2. Navigate to `https://Inforcer2m365.sharepoint.com/sites/DumbledoresArmy`
3. **🎤 Talking Point:** *"Right now these are standard M365 Group sites. Any licensed user can browse right in. Let's fix that."*

> **📸 Screenshot opportunity:** Dolores viewing the DA Charter in SharePoint

---

## 🎬 ACT 2 — The Solution: Sensitivity Labels

> **Goal:** Create and apply a Sensitivity Label that encrypts content and restricts access to only the Gryffindor dynamic group.

### Step 2.1 — Create the Sensitivity Label

1. Open **Microsoft Purview Compliance Portal**: `https://compliance.microsoft.com`
2. Navigate to **Information Protection** → **Labels**
3. Click **+ Create a label**
4. Configure as follows:

| Setting | Value |
|---------|-------|
| **Name** | `Order of the Phoenix — Restricted` |
| **Display Name** | `🛡️ Order of the Phoenix — Restricted` |
| **Description for users** | `This content is restricted to members of the Order of the Phoenix (Gryffindor house members only). Do not share externally.` |
| **Description for admins** | `Encrypts content and restricts access to the Gryffindor dynamic security group. Used for Order of the Phoenix and DA sensitive documents.` |
| **Scope** | ✅ Items (Files, Emails) — ✅ Groups & sites |

5. Click **Next** → **Encryption** settings:

| Encryption Setting | Value |
|-------------------|-------|
| **Encryption** | ✅ Apply |
| **Assign permissions now or let users decide?** | Assign permissions now |
| **User access to content expires** | Never |
| **Allow offline access** | Always |

6. Click **Assign permissions** → **+ Add users or groups**
7. Search for and add: **`🦁 Gryffindor – Dynamic User Group`**
8. Set permissions to: **Co-Author** (View, Open, Read, Save, Edit, Copy, Macro rights)
9. Click **Save** → **Next**

10. **Content marking** (optional but recommended):

| Marking | Value |
|---------|-------|
| **Header** | ✅ `ORDER OF THE PHOENIX — RESTRICTED` |
| **Footer** | ✅ `Access restricted to Gryffindor members only` |
| **Watermark** | ✅ `CONFIDENTIAL — OotP` |

11. Click through remaining pages → **Create label**

> **🎤 Talking Point:** *"We've just created a sensitivity label that uses Azure Information Protection encryption. When applied, only the 6 members of the Gryffindor dynamic group can open the document. Even if someone shares the file directly with Dolores Umbridge, she physically cannot decrypt it."*

### Step 2.2 — Publish the Label

1. Still in **Information Protection** → **Label policies**
2. Click **+ Publish labels**
3. Select the `🛡️ Order of the Phoenix — Restricted` label
4. **Publish to:** All users (or specific users for demo scoping)
5. **Policy settings:**

| Setting | Value |
|---------|-------|
| **Policy name** | `Order of the Phoenix Protection Policy` |
| **Users must provide justification to remove a label** | ✅ Yes |
| **Require users to apply a label to emails and documents** | ☐ No (not for this demo) |
| **Default label for documents** | None |

6. Click **Submit**

> ⏱️ **Note:** Label policies can take **up to 24 hours** to propagate to all users. For the demo, you may want to pre-publish this the day before.

### Step 2.3 — Apply the Label to Documents

#### Option A: Manual Application (Good for Live Demo)

1. Open a **new browser window** as **Harry Potter** (`harry.potter@Inforcer2m365.onmicrosoft.com`)
2. Navigate to **Order of the Phoenix** SharePoint site
3. Open **Dumbledore's Army.docx** in Word Online
4. Click **Sensitivity** in the ribbon → Select **🛡️ Order of the Phoenix — Restricted**
5. Save the document
6. Repeat for **Dumbledores Army HQ** site:
   - Apply the label to `The DA Charter - KEEP SECRET.docx`
   - Apply the label to `DA Membership Roster.xlsx`
   - Apply the label to `DA Training Curriculum.pptx`

> **🎤 Talking Point:** *"Harry, as a Gryffindor member, can apply the label. Once applied, the document is now encrypted at rest and in transit. The encryption travels with the file — even if someone downloads it, emails it, or copies it to a USB stick."*

#### Option B: Auto-Labelling Policy (Better for Scale Demo)

1. In **Purview** → **Information Protection** → **Auto-labelling**
2. Click **+ Create auto-labelling policy**
3. Configure:

| Setting | Value |
|---------|-------|
| **Name** | `Auto-label Order of the Phoenix content` |
| **Sensitive info to detect** | Custom — keyword list: `Order of the Phoenix`, `Dumbledore's Army`, `DA Charter`, `KEEP SECRET` |
| **Label to apply** | `🛡️ Order of the Phoenix — Restricted` |
| **Locations** | SharePoint sites → Order of the Phoenix, Dumbledores Army HQ |

4. Run in **Simulation mode** first, then **Turn on policy**

---

## 🎬 ACT 3 — The Payoff: Dolores Gets Blocked

> **Goal:** Switch back to Dolores Umbridge and prove that the Sensitivity Label actually blocks access — including through Copilot.

### Step 3.1 — Dolores Tries Copilot Again

1. Switch to the **Dolores Umbridge** browser window
2. Open **Microsoft 365 Copilot** chat
3. Type:

   > **"What is in the DA Charter document?"**

4. **Expected Result:** Copilot will either:
   - **Not return the content** (because Dolores can't decrypt it)
   - Return a result saying the document exists but **cannot show the content**

5. Try:

   > **"Show me all members of Dumbledore's Army from the membership roster"**

6. **Expected Result:** Copilot cannot read the encrypted Excel file

> **🎤 Talking Point:** *"This is the power of Sensitivity Labels with encryption. Copilot respects the encryption boundary. Even though the document still exists in SharePoint, even though Copilot knows it's there, it cannot read the content because Dolores Umbridge is not in the Gryffindor group. The encryption is enforced at the file level, not just the site level."*

### Step 3.2 — Dolores Tries Direct Access

1. In Dolores's browser, navigate to:
   `https://Inforcer2m365.sharepoint.com/sites/DumbledoresArmy`
2. Try to open **The DA Charter - KEEP SECRET.docx**
3. **Expected Result:** Access denied or encrypted content warning

4. Try to open **DA Membership Roster.xlsx**
5. **Expected Result:** Cannot open — encryption blocks Dolores

> **📸 Screenshot opportunity:** Dolores getting "Access Denied" or encryption error on the DA Charter

### Step 3.3 — Harry Can Still Access Everything

1. Switch to the **Harry Potter** browser window
2. Open **Microsoft 365 Copilot**
3. Type:

   > **"What is in the DA Charter document?"**

4. **Expected Result:** Copilot returns the full content — Harry is in Gryffindor group

5. Open the document directly in SharePoint — works perfectly

> **🎤 Talking Point:** *"Harry is a member of the Gryffindor dynamic group, so the encryption lets him right through. Same document, same Copilot, completely different experience based on group membership. This is Zero Trust applied to content — verify explicitly, least-privilege access, assume breach."*

---

## 🎬 ACT 4 — Defence in Depth: Restricted SharePoint Search

> **Goal:** Show that even without Sensitivity Labels on every site, you can use Restricted SharePoint Search to hide sites from Copilot entirely — as an interim measure while you roll out labels.

### Step 4.1 — Explain the Problem at Scale

> **🎤 Talking Point:** *"Sensitivity Labels are the gold standard — they encrypt the content and protect it everywhere it goes. But what if you have 20+ SharePoint sites and can't label everything overnight? You need a safety net while you're rolling out labels. That's where Restricted SharePoint Search comes in."*

### Step 4.2 — Enable Restricted SharePoint Search

1. Open **SharePoint Admin Center**: `https://Inforcer2m365-admin.sharepoint.com`
2. Navigate to **Settings** → **Search** (or via direct URL)
3. Or use **PowerShell**:

```powershell
# Connect to SharePoint Online
Import-Module Microsoft.Online.SharePoint.PowerShell
Connect-SPOService -Url "https://Inforcer2m365-admin.sharepoint.com"

# Enable Restricted SharePoint Search
Set-SPOTenant -IsDataAccessInCardDesignerEnabled $false
```

4. Or via the **SharePoint Admin Center UI**:
   - Go to **Settings** → **Search settings**
   - Toggle **Restricted SharePoint Search** to **On**

> **🎤 Talking Point:** *"When you enable Restricted SharePoint Search, Copilot and Microsoft Search can ONLY index and return results from sites you explicitly allow. Every other site goes dark to Copilot — it can't see them, can't search them, can't summarise them."*

### Step 4.3 — Configure the Allowed List

1. In **SharePoint Admin Center** → **Search settings** → **Restricted SharePoint Search**
2. The allow list starts **empty** — meaning Copilot can search **nothing** until you add sites
3. Add only the sites you've already labelled or confirmed as safe:

| Site to Allow | Reason |
|--------------|--------|
| Hogwarts House Points | General/public info — no sensitivity |
| Quidditch World Cup 2026 | Public event planning — no sensitivity |
| Hogsmeade Village Council | Public business directory — no sensitivity |
| Dobbys Sock Foundation | Charitable org — no sensitivity |
| Hogwarts Express Operations | Operational — no sensitivity |

4. **Do NOT add** these to the allowed list:

| Site to Restrict | Reason |
|-----------------|--------|
| ❌ Order of the Phoenix | Contains encrypted OotP content — labels protect it, but defence in depth |
| ❌ Dumbledores Army HQ | Contains encrypted DA content |
| ❌ Malfoy Manor Enterprises | Political donations — needs review |
| ❌ Department of Mysteries | Classified content |
| ❌ Hogwarts Library Restricted Section | Restricted access materials |
| ❌ Snapes Potions Laboratory | Contains CONFIDENTIAL documents |

### Step 4.4 — Show Copilot with Restricted Search Active

1. Switch back to **Dolores Umbridge** browser
2. Open **Microsoft 365 Copilot**
3. Type:

   > **"List all SharePoint sites I have access to"**

4. **Expected Result:** Copilot only returns the 5 allowed sites — not all 20+

5. Try:

   > **"Find documents about potions"**

6. **Expected Result:** Nothing — Snapes Potions Laboratory isn't in the allowed list

7. Try:

   > **"What is in the Department of Mysteries?"**

8. **Expected Result:** Copilot has no knowledge of that site

> **🎤 Talking Point:** *"Restricted SharePoint Search is your emergency brake. Turn it on, start with zero sites allowed, then progressively add sites as you confirm they have the right labels and permissions. It's the 'deny by default' approach — nothing is searchable until you say it is."*

### Step 4.5 — Show That Direct Access Still Works

1. In Dolores's browser, **directly navigate** to:
   `https://Inforcer2m365.sharepoint.com/sites/HogwartsHousePoints`
2. **Expected Result:** She can still browse it — Restricted Search only affects Copilot/Search, not direct URL access

> **🎤 Talking Point:** *"Important caveat — Restricted SharePoint Search only controls what Copilot and Microsoft Search can discover. Users can still access sites directly if they have the URL and permissions. That's why you need BOTH: Sensitivity Labels for content-level encryption AND Restricted Search for discovery control. Defence in depth."*

---

## 🎬 ACT 5 — The Complete Picture

> **Goal:** Wrap up by showing the layered security model.

### The Defence-in-Depth Stack

```
┌─────────────────────────────────────────────────┐
│  Layer 4: Restricted SharePoint Search          │
│  Controls what Copilot & Search can discover    │
├─────────────────────────────────────────────────┤
│  Layer 3: Sensitivity Labels (Encryption)       │
│  Content-level encryption — travels with file   │
├─────────────────────────────────────────────────┤
│  Layer 2: SharePoint Site Permissions           │
│  M365 Group membership controls site access     │
├─────────────────────────────────────────────────┤
│  Layer 1: Entra ID Dynamic Groups               │
│  Automatic group membership based on attributes │
└─────────────────────────────────────────────────┘
```

### Summary Talking Points

| Layer | What It Does | Dolores Blocked? |
|-------|-------------|-----------------|
| **Entra ID Dynamic Groups** | Gryffindor group auto-populates from `OfficeLocation = Gryffindor` | Dolores is Slytherin → not in Gryffindor group |
| **SharePoint Permissions** | Site access controlled by M365 Group membership | ✅ If site is restricted to Gryffindor group |
| **Sensitivity Labels** | AIP encryption on individual files — only Gryffindor can decrypt | ✅ Even if Dolores gets the file, she can't open it |
| **Restricted SharePoint Search** | Copilot/Search can only see allowed sites | ✅ Sensitive sites invisible to Copilot |

> **🎤 Final Talking Point:** *"No single control is enough. Permissions can be misconfigured. Labels can be forgotten. Search controls can be too broad. But when you layer them together — dynamic groups, site permissions, file-level encryption, and search restrictions — you get true defence in depth. Dolores Umbridge isn't getting into Dumbledore's Army, no matter how hard she tries."*

---

## 🧹 Post-Demo Cleanup (Optional)

If you want to reset for the next demo run:

| Action | How |
|--------|-----|
| Remove Sensitivity Label from files | Open each file as Harry → Sensitivity → Remove label |
| Disable Restricted SharePoint Search | SharePoint Admin → Settings → Search → Toggle off |
| Delete the label policy | Purview → Information Protection → Label policies → Delete |
| Delete the label | Purview → Information Protection → Labels → Delete |

> **Note:** You do NOT need to delete SharePoint sites or users — the demo environment is reusable.

---

## 📚 Reference Links

| Resource | URL |
|----------|-----|
| Sensitivity Labels Overview | https://learn.microsoft.com/purview/sensitivity-labels |
| Create & Publish Labels | https://learn.microsoft.com/purview/create-sensitivity-labels |
| Auto-labelling Policies | https://learn.microsoft.com/purview/apply-sensitivity-label-automatically |
| Restricted SharePoint Search | https://learn.microsoft.com/sharepoint/restricted-sharepoint-search |
| Copilot & Oversharing | https://learn.microsoft.com/microsoft-365-copilot/microsoft-365-copilot-privacy#how-does-microsoft-365-copilot-use-your-organizational-data |
| Entra ID Dynamic Groups | https://learn.microsoft.com/entra/identity/users/groups-dynamic-membership |

---

## 🎯 Demo Flow Cheat Sheet (Quick Reference)

```
ACT 1 — THE PROBLEM (5 min)
  → Log in as Dolores Umbridge
  → Copilot: "List all SharePoint sites"          ← She sees everything
  → Copilot: "What is in the DA Charter?"          ← She reads the secret doc
  → Visit Order of the Phoenix site directly       ← Full access

ACT 2 — THE FIX (10 min)
  → Purview → Create Sensitivity Label
  → Encrypt → Assign to Gryffindor group only
  → Publish label policy
  → Apply label to OotP + DA documents (as Harry)

ACT 3 — THE PAYOFF (5 min)
  → Switch to Dolores
  → Copilot: "What is in the DA Charter?"          ← BLOCKED
  → Open DA Charter directly                       ← ACCESS DENIED
  → Switch to Harry → same queries work fine       ← ALLOWED

ACT 4 — DEFENCE IN DEPTH (10 min)
  → Enable Restricted SharePoint Search
  → Add only safe sites to allow list
  → Dolores Copilot: "List all sites"              ← Only sees 5 allowed sites
  → Sensitive sites completely invisible to Copilot

ACT 5 — WRAP UP (5 min)
  → Show the 4-layer defence model
  → Dynamic Groups → Permissions → Labels → Search
  → "No single control is enough — layer them"
```
