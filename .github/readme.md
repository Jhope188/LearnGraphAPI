# conditionalaccess.tech — Site Repository

Personal technical writing site for **Jon Hope**, Microsoft MVP for Security: Identity and Access. M365 Solutions Architect at inforcer.

**Live site:** [conditionalaccess.tech](https://conditionalaccess.tech)

---

## Site Structure

```
/
├── index.html                        # Homepage (bio, featured work, links)
├── entra-news.html                   # Entra News coverage page
├── identity-security-blog.html       # Blog landing page
├── repo-structure.html               # Site map / repo structure page
├── MerillCartoon.png                 # Profile/avatar image
├── jon_extracted.png                 # Profile photo asset
│
├── articles/
│   ├── index.html                    # Article hub (tabbed: Identity / Governance / CA)
│   │
│   ├── identity/
│   │   ├── identity-is-everything.html        # PT01 — Identity Is Everything ✅ LIVE
│   │   ├── authentication-methods.html        # PT02 — Authentication Methods ✅ LIVE
│   │   ├── passkeys.html                      # PT03 — Passkeys (scheduled)
│   │   ├── who-did-you-let-in.html            # PT04 — Guest Identities (scheduled)
│   │   ├── groups-connective-tissue.html      # PT05 — Groups as Connective Tissue (scheduled)
│   │   ├── images/                            # Article images
│   │   │   ├── IdentityisEverything.png
│   │   │   ├── Identityseries.png
│   │   │   ├── Identityinreality.png
│   │   │   ├── ITDR.png
│   │   │   ├── MFAChart.png
│   │   │   └── guestchart.png
│   │   └── Markdown/                          # Source markdown for articles
│   │       ├── identity-is-everything.md
│   │       └── who-did-you-let-in.md
│   │
│   ├── governance/
│   │   ├── groups-connective-tissue.html      # PT01 — Groups & Connective Tissue (scheduled)
│   │   ├── configuration-is-not-control.html  # PT02 — The Governance Gap (scheduled)
│   │   ├── lifecycle-sprawl-countermeasure.html # PT03 — The Cleanup Campaign (scheduled)
│   │   ├── ai-readiness-governance-audit.html # PT04 — Clean the House (scheduled)
│   │   └── ownership-operating-model.html     # PT05 — The Ownership Operating Model (scheduled)
│   │
│   ├── conditional-access/
│   │   ├── mfa-for-all-but-not-the-same.html  # MFA for All… But Not the Same ✅ LIVE
│   │   └── images/
│   │       └── CALayers.png
│   │
│   ├── entra/
│   │   └── readme.md
│   │
│   └── azure/
│       └── readme.md
│
└── .github/
    ├── workflows/
    │   └── scheduled-release.yml     # GitHub Actions: daily article release automation
    └── scripts/
        └── release_articles.py       # Python script: converts coming-soon → live links
```

---

## Article Hub (`articles/index.html`)

The hub uses a **tabbed layout** with three series:

| Tab | Articles | Status |
|-----|----------|--------|
| **Identity** | 5 articles (PT01–PT05) | PT01–PT02 live, PT03–PT05 scheduled |
| **Governance** | 5 articles (PT01–PT05) | All scheduled |
| **Conditional Access** | 1 article + placeholder | 1 live |

### Article Cards
- **Live articles** → `<a>` tag with `href` pointing to the HTML file
- **Scheduled articles** → `<div class="article-card coming-soon">` with `data-series` and `data-file` attributes used by the automation script
- **Featured/latest card** → `class="article-card featured"` badge and a hero banner at the top of the page

### Tab Navigation
Tabs are driven by plain JavaScript — clicking a tab toggles `.active` on `.tab-btn` and `#panel-{series}`. Deep-linking via URL hash is supported (e.g. `articles/index.html#governance`).

---

## Article Release Automation

Scheduled releases are handled entirely by GitHub Actions — no manual publishing step needed.

### How it works

1. **`.github/workflows/scheduled-release.yml`** runs on a cron schedule (daily at 07:00 EST / 12:00 UTC)
2. It calls **`.github/scripts/release_articles.py`**, which:
   - Reads `articles/index.html`
   - Checks `data-file` attributes on `coming-soon` cards against scheduled dates (read from article `<footer>` or card metadata)
   - When the release date has passed, converts the `<div class="article-card coming-soon">` into a live `<a>` tag
   - Commits the updated `articles/index.html` back to the repo

### Release Schedule

| Date | Series | Article |
|------|--------|---------|
| ~~May 26, 2026~~ | ~~Identity PT02~~ | ~~Authentication Methods: The Spectrum~~ ✅ Released |
| Jun 2, 2026 | Identity PT03 | Passkeys: Security Only Works If People Use It |
| Jun 9, 2026 | Identity PT04 | Who Did You Let Into Your House? |
| Jun 16, 2026 | Identity PT05 | Groups as Connective Tissue |
| Jun 23, 2026 | Governance PT01 | Groups Are the Connective Tissue |
| Jun 30, 2026 | Governance PT02 | The Governance Gap |
| Jul 7, 2026 | Governance PT03 | The Cleanup Campaign That Never Ends |
| Jul 14, 2026 | Governance PT04 | Clean the House Before the Guests Arrive |
| Jul 21, 2026 | Governance PT05 | The Ownership Operating Model |

---

## Design System

All pages share a consistent dark theme defined with CSS custom properties:

| Variable | Value | Use |
|----------|-------|-----|
| `--navy` | `#08132a` | Page background |
| `--navy-card` | `#0d1f3c` | Card background |
| `--blue` | `#1e56c8` | Primary blue |
| `--blue-hi` | `#3b7ff5` | Highlighted blue / series label |
| `--teal` | `#00c2b3` | Accent / nav brand / active tab indicator |
| `--white` | `#ffffff` | Headings |
| `--text` | `#c8d8f0` | Body text |
| `--muted` | `#5f7aaa` | Secondary / metadata text |

**Fonts:** [Syne](https://fonts.google.com/specimen/Syne) (700/800) for headings · [DM Sans](https://fonts.google.com/specimen/DM+Sans) (300/400/500) for body text

---

## GitHub Repository

**Repo:** [github.com/Jhope188/LearnGraphAPI](https://github.com/Jhope188/LearnGraphAPI)

The automation workflow requires the repo to have **write permissions** enabled for GitHub Actions (`Settings → Actions → General → Workflow permissions → Read and write`).
