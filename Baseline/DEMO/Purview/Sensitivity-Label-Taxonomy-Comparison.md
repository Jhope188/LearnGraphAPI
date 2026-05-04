# Sensitivity Label Taxonomy: IAC vs Microsoft Default

> **Author:** IAC / Inforcer M365 Solutions Architecture  
> **Date:** May 2026  
> **Reference:** [Microsoft Default Sensitivity Labels & Policies](https://learn.microsoft.com/en-us/purview/default-sensitivity-labels-policies) · [Get Started with Sensitivity Labels](https://learn.microsoft.com/en-us/purview/get-started-with-sensitivity-labels)

---

## Structural Overview

| Dimension | IAC | Microsoft Default |
|---|---|---|
| Total labels | 9 | 12 |
| Classification tiers | 2 (Confidential, Restricted) | 3 (General sublabels, Confidential, Highly Confidential) |
| Flat top-level labels | 2 (Public, General) | 6 (Personal, Public, General + 3 parents) |
| Groups & Sites protection | ✅ Yes — on parent labels | ❌ No — not configured |
| Auto-labeling configured | ❌ No | ✅ Yes — credit card SITs |
| Meetings scope | ❌ No | ✅ Yes (Oct 2024+ tenants) |
| Content markings on General | ✅ Header + Footer | ❌ None |
| Mandatory labeling | ✅ Yes | ✅ Yes (downgrade justification only) |
| Policy architecture | Tiered (3 policies) | Single unified policy |

---

## Label-by-Label Mapping

| IAC Label | Closest Microsoft Default | Notes |
|---|---|---|
| Public | Public | Near-identical |
| General (default) | General \ Anyone (unrestricted) | IAC is broader in scope; adds content markings |
| — | General \ Anyone (unrestricted) | **IAC gap** — no label for general external sharing |
| — | Personal | **IAC gap** — no personal/non-business label |
| Confidential - Internal | Confidential \ All Employees | Functionally equivalent encryption model |
| Confidential - Third Parties | Confidential \ Trusted People | Different permission model (see below) |
| Confidential - Reporting | *(no equivalent)* | IAC-specific — debatable value (see below) |
| Restricted - Internal | Highly Confidential \ All Employees | Encryption model differs significantly (see below) |
| Restricted - Third Parties | Highly Confidential \ Specific People | DNF vs. user-prompt model |

---

## Where IAC Is Clearly Better

**1. Groups & Sites protection on parent labels.** This is the most significant structural advantage IAC has over Microsoft's default taxonomy. Microsoft's 12 default labels have *no* Groups & Sites scope configured — none of them protect Teams, SharePoint sites, or M365 Groups at the container level. IAC's Confidential and Restricted parent labels enforce privacy settings and guest access controls on containers directly. This is architecturally correct and something Microsoft's defaults simply omit. Organizations relying solely on Microsoft's defaults get zero container-level protection out of the box.

**2. Tiered policy architecture.** Microsoft defaults publish everything to all users in a single policy. IAC's three-policy structure enables label visibility segmentation by group, which matters as soon as contractors or department-specific needs enter the picture. The design rationale is solid and scales well.

**3. Visual markings on the highest-sensitivity labels.** Restricted labels carry a "RESTRICTED" watermark. Microsoft's "Highly Confidential" parent has a watermark, but "Highly Confidential \ All Employees" and "Highly Confidential \ Specific People" only have footer markings — no watermark. The IAC decision to watermark all Restricted sublabels is more aggressive and arguably more appropriate for the highest tier.

**4. Mandatory labeling across all content.** The IAC Base Policy enforces mandatory labeling with downgrade justification on all users from day one, including Power BI. Microsoft's defaults only require downgrade justification — mandatory labeling itself is not enforced on first label assignment in Office apps the same way. IAC's approach is more rigorous.

---

## Where Microsoft Default Is Better (and IAC Has Real Gaps)

**1. No "Personal" label — this is a genuine gap.** Microsoft includes Personal specifically for non-business data on work devices (BYOD scenarios, personal notes, etc.). Without it, users have no compliant place to put personal content, which leads to either mislabeling personal items as "Public" or skipping labels altogether on personal-use files. For any organization allowing personal use on managed devices, this gap creates compliance ambiguity. IAC should add this.

**2. General has no audience distinction — this matters more than it looks.** Microsoft splits General into "All Employees (unrestricted)" and "Anyone (unrestricted)." IAC's single General label doesn't distinguish between content that's internal-only versus content that's been approved for external sharing. Both are unencrypted, so the label can't enforce the distinction — but it signals intent to users and creates a DLP policy hook. Without "General - Anyone" or equivalent, IAC users share externally under the same General label as purely internal content, which erases a meaningful data handling signal.

**3. Auto-labeling is absent from IAC's documentation.** Microsoft's defaults ship with auto-labeling configured for credit card numbers (recommending Confidential \ Anyone unrestricted for 1–9 instances, Confidential \ All Employees for 10+). IAC has no auto-labeling configured. Auto-labeling is table stakes for any mature information protection posture — manual labeling alone leaves significant coverage gaps, particularly for content at rest in SharePoint/OneDrive that was created before label policies existed.

**4. "Trusted People" is more flexible than "Third Parties" with DNF.** Microsoft's Confidential \ Trusted People uses Encrypt-Only for Outlook (not Do Not Forward) and prompts users for permissions in Word, Excel, and PowerPoint. IAC's Third Parties labels enforce DNF universally, which means recipients cannot forward the email — but they *can* still print it or screenshot it. More importantly, DNF is email-only semantics applied to what are also file labels, which creates inconsistency. Encrypt-Only for Outlook with user-prompted permissions for documents gives users more control and is a better fit for legitimate third-party collaboration scenarios.

**5. Meetings scope is missing entirely from IAC.** Since October 2024, Microsoft supports sensitivity labels on Teams meetings (scheduling invites, meeting options). IAC's taxonomy has no label scoped for Meetings, meaning Teams meeting sensitivity labeling is unavailable. For organizations with Microsoft Teams Copilot or who want to control meeting recording/transcription sensitivity, this is a real gap.

---

## Specific Technical Concerns in IAC

### Concern 1: Restricted - Internal uses admin-only Owner rights — operational risk

```
"Rights" | "<AdminEmail>": OWNER (full control)
```

If the admin account's email changes, the account is disabled, or the account doesn't exist when someone tries to access an encrypted file, those files become inaccessible. This is a classic "super-user trap" in RMS deployments. Microsoft's "Highly Confidential \ All Employees" uses org-wide Co-Author rights, which is resilient. The IAC approach should either use a security group (so membership can be managed) or a super-user/RMS administrator account, not a single named admin mailbox. At minimum, the `-EncryptionRightsDefinitions` should reference a mail-enabled security group, not a personal admin UPN.

### Concern 2: Confidential - Reporting is architecturally redundant

Confidential - Reporting has *identical* encryption settings to Confidential - Internal (same org-wide Co-Author rights). The only difference is the content marking text. This means the label adds no additional protection or access differentiation — it's purely a classification signal. Microsoft's best practice guidance warns against sublabels that don't provide distinct protection differences, as they add cognitive load without enforcement value. If the goal is to identify reporting data for DLP or audit purposes, a sensitivity type or metadata approach is cleaner. If kept, the intended DLP trigger should be explicitly documented.

### Concern 3: Parent label model — migration risk for new tenants

Microsoft announced that new tenants created after October 1, 2025 automatically use the modern label scheme, where "parent labels" are replaced by "label groups." Label groups only support name, description, color, and priority — they cannot carry protection settings. The IAC taxonomy relies on parent labels carrying `protectgroup` and `protectsite` LabelActions for container protection. If this tenant was created after October 2025, the migration to label groups could break the container protection on the Confidential and Restricted parent labels. This needs to be verified:

```powershell
# Verify backend label scheme
(Get-Label -Identity "Confidential").LabelActions
# Should show: {"Type":"protectgroup"... "disabled":"false"} and {"Type":"protectsite"... "disabled":"false"}
```

### Concern 4: General label content markings may cause alert fatigue

Red header and footer on "General" content — which is the *default* for all content — means every single document and email will carry red markings. Red conventionally signals urgency or high sensitivity. Applying red to the lowest-sensitivity labeled content trains users to ignore red markings, which undermines the visual impact of the same red markings on Confidential and Restricted labels. Microsoft's defaults use no markings on General content. Consider changing General's content markings to a neutral color (black or grey) and reserving red for Confidential and above.

---

## Label Naming: Restricted vs. Highly Confidential

Microsoft recommends "Highly Confidential" rather than "Restricted" as the highest commercial sensitivity tier. This is the correct call for M365 deployments for three reasons:

**1. Cognitive clarity.** "Confidential" and "Highly Confidential" form an obvious severity scale. "Confidential vs. Restricted" is ambiguous — users frequently interpret "Restricted" as *access-restricted* (a SharePoint permission concept) rather than *content sensitivity*, leading to systematic mislabeling.

**2. Legal/regulatory connotations.** In regulated industries, "Restricted" often has specific legal meaning — ITAR export restrictions, HIPAA restricted data, financial restricted lists. Applying it as a general sensitivity label creates friction with legal and compliance teams who use the term in a narrower, legally defined context.

**3. Microsoft tooling alignment.** Default SIT-to-label mappings, auto-labeling policy templates, and Microsoft 365 Copilot's label-awareness features are designed against the Personal / Public / General / Confidential / Highly Confidential taxonomy. Deviation requires constant mental translation and custom documentation.

### The ISO 27001 Counterpoint

The standard that formally uses "Restricted" as the highest commercial label tier is **ISO/IEC 27001:2022 Annex A, control A.5.12** — not NIST. The ISO example taxonomy is: Public → Internal → Confidential → Restricted. NIST's frameworks (SP 800-60, SP 800-171, CSF) use impact levels (Low/Moderate/High) and CUI categories, not prescriptive label names.

| Framework | Highest Tier | Second-Highest |
|---|---|---|
| Microsoft Default | Highly Confidential | Confidential |
| ISO/IEC 27001:2022 | Restricted | Confidential |
| US Federal / NIST | Top Secret | Secret |
| UK Government (HMG) | Top Secret | Secret |
| Australian PSPF | Protected | Official Sensitive |

**Recommendation:** Use Microsoft's "Highly Confidential" naming for M365 deployments unless the organization is pursuing ISO 27001 certification, in which case document the explicit mapping (Highly Confidential = Restricted in ISO 27001 terms) in the label policy documentation.

---

## Summary Verdict

| Category | Winner | Reasoning |
|---|---|---|
| Container (Groups/Sites) protection | **IAC** | Microsoft defaults have none |
| Classification depth | **Microsoft** | 3-tier model aligns with NIST/ISO; IAC misses General audience distinction |
| Auto-labeling | **Microsoft** | IAC has nothing configured |
| External sharing flexibility | **Microsoft** | Encrypt-Only vs. DNF; General - Anyone label |
| Highest-tier encryption resilience | **Microsoft** | Org-wide vs. admin-only single account |
| Policy granularity | **IAC** | Tiered policies beat a single unified policy |
| Meetings coverage | **Microsoft** | IAC has none |
| Personal/non-business data | **Microsoft** | IAC has no Personal label |
| Visual marking strategy | **Mixed** | IAC watermarks all Restricted (good); red on General (problematic) |

IAC's taxonomy is architecturally more sophisticated than Microsoft's defaults in container protection and policy design — those are genuine strengths. However, IAC has three real gaps that should be addressed: the missing Personal label, the absence of auto-labeling, and the admin-only encryption on Restricted - Internal. The Confidential - Reporting sublabel and General red markings are worth reconsidering. The parent label migration risk needs to be confirmed before any changes are made.

---

## Recommended Corrected Taxonomy

```
Personal         (flat — File, Email — no protection, non-business data)
Public           (flat — File, Email, Site, UnifiedGroup — no protection)
General          (default — File, Email, Site, UnifiedGroup — neutral markings, no encryption)
General - Anyone (flat — File, Email — no encryption, approved external sharing signal)
│
Confidential     (parent/group — container: Private, guests ALLOWED)
├── Confidential - Internal        (org-wide Co-Author encryption)
└── Confidential - Third Parties   (user-defined + Encrypt-Only, not DNF)
│
Highly Confidential  (parent/group — container: Private, guests BLOCKED)
├── Highly Confidential - Internal     (security group Co-Author, watermark)
└── Highly Confidential - Third Parties  (user-defined + DNF, watermark)
```

---

## Recommended Immediate Actions

1. Verify whether the tenant uses the modern label scheme (label groups) or traditional parent labels — this determines whether container protection is functioning as documented
2. Replace `<AdminEmail>: OWNER` encryption on Restricted - Internal with a mail-enabled security group
3. Add a Personal label scoped to File and Email with no protection
4. Add a General - Anyone sublabel for approved external sharing scenarios
5. Configure at least one auto-labeling policy — start with the Microsoft default credit card SIT configuration as a baseline
6. Change General content marking color from red to black/grey
7. Evaluate renaming Restricted → Highly Confidential unless the organization is ISO 27001 certified/pursuing certification
8. Evaluate removing or repurposing Confidential - Reporting as a DLP metadata signal rather than a standalone label

---

## Sources

- [Default sensitivity labels and policies — Microsoft Learn](https://learn.microsoft.com/en-us/purview/default-sensitivity-labels-policies)
- [Migrate parent sensitivity labels to label groups](https://learn.microsoft.com/purview/migrate-sensitivity-label-scheme)
- [Get started with sensitivity labels](https://learn.microsoft.com/en-us/purview/get-started-with-sensitivity-labels)
- [Power BI sensitivity label structure best practices](https://learn.microsoft.com/power-bi/guidance/powerbi-implementation-planning-info-protection#sensitivity-label-structure)
- [Data governance and security baselines with Microsoft Purview](https://learn.microsoft.com/azure/cloud-adoption-framework/data/governance-security-baselines-purview-data-estate-unify-data-platform)
- ISO/IEC 27001:2022 Annex A, Control A.5.12 — Classification of Information
