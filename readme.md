# conditionalaccess.tech — Site Structure

**Jon Hope · Microsoft MVP · Security: Identity & Access**
Site: [conditionalaccess.tech](https://conditionalaccess.tech) · Hosted on GitHub Pages from `main`

---

## 🗺️ Page Map

| Page | URL | File |
|---|---|---|
| Homepage | `conditionalaccess.tech` | `index.html` |
| Writing Hub | `conditionalaccess.tech/articles.html` | `articles.html` |
| Entra.News Features | `conditionalaccess.tech/entra-news.html` | `entra-news.html` |
| Appearances | `conditionalaccess.tech/appearances.html` | `appearances.html` |
| About | `conditionalaccess.tech/about.html` | `about.html` |
| RSS Feed | `conditionalaccess.tech/feed.xml` | `feed.xml` |

---

## 🏠 Homepage — `index.html`

The main landing page for the site. Sections in order:

- **Hero** — Name, MVP badge, role (M365 Solutions Architect · inforcer), bio, LinkedIn + Medium CTAs
- **Focus** — Three pillars: Microsoft Entra ID, Conditional Access, M365 Governance
- **Resources** — Tool cards: CA Policy Analyzer, Graph API Reference, CA Policy Templates, Entra Baselines
- **Writing** — Featured latest article card (auto-updated by publish script), link to articles hub
- **Appearances** — YouTube playlist card + Podcasts & Events card (links to `appearances.html`)
- **CTA Band** — LinkedIn connect + Medium read buttons
- **Footer** — Copyright

---

## 📚 Writing Hub — `articles.html`

Root-level article index (replaces `articles/index.html`). Three series sections:

### 🔵 Identity Series — 5 articles live

| PT | Title | Published |
|---|---|---|
| PT01 | [Identity Is Everything](identity/identity-is-everything.html) | May 2026 |
| PT02 | [Authentication Methods: The Spectrum](identity/authentication-methods.html) | May 2026 |
| PT03 | [Passkeys: Security Only Works If People Use It](identity/passkeys.html) | Jun 1, 2026 |
| PT04 | [Who Did You Let Into Your House?](identity/who-did-you-let-in.html) | Jun 9, 2026 |
| PT05 | [Groups: The Connective Tissue](identity/groups-connective-tissue.html) | Jun 16, 2026 |

Series focus: Microsoft Entra ID, authentication, identity architecture, and threat detection.

---

### 🟡 Governance Series — 5 articles scheduled

| PT | Title | Scheduled |
|---|---|---|
| PT01 | Groups Are the Connective Tissue — and Nobody Owns the Scissors | Jun 30, 2026 |
| PT02 | The Governance Gap | Jul 14, 2026 |
| PT03 | The Cleanup Campaign That Never Ends | Jul 28, 2026 |
| PT04 | Clean the House Before the Guests Arrive | Aug 11, 2026 |
| PT05 | The Ownership Operating Model | Aug 25, 2026 |

Series focus: M365 governance, group lifecycle, ownership models, tenant cleanup, and Copilot readiness.

Files live in `articles/governance/` when published.

---

### 🟢 Conditional Access Series — 2 articles live

| Title | Published |
|---|---|
| [CA Policy Analyzer Update](conditional-access/ca-policy-analyzer/ca-policy-analyzer-update.html) | May 2026 |
| [MFA for All… But Not the Same](conditional-access/mfa-for-all-but-not-the-same.html) | Feb 2026 |

Series focus: Policy design, exclusions, service principal gaps, named locations, and device compliance.

---

## 📰 Entra.News Features — `entra-news.html`

Tracks every time conditionalaccess.tech content has been featured in the [Entra.News](https://entra.news) weekly newsletter, curated by Merill Fernando (Microsoft Identity PM).

**Current stats:**

| Metric | Count |
|---|---|
| Features | 22 |
| Issues | 20 |
| Podium Finishes | 🥇 🥈 🥉 |
| Articles Featured | 47% |

Sections on the page:
- **Stats row** — live counters (updated by publish script)
- **JS feature list** — all 22 features rendered from a JS array (newest first); updated by publish script
- **Podium appearances** — #1, #2, #3 Most Popular Post finishes
- **Merill card** — context on the newsletter and its curation

Badge types: `ca` · `auth` · `sec` · `pop` · `tenant` · `dev`

Stats and grid rows are automatically updated by `.github/scripts/publish.py` when a new article is published with `entra_news` data set in `.publish-config.json`.

---

## 🎙️ Appearances — `appearances.html`

Dedicated page for podcast and live event appearances.

### Podcasts

| Show | Episode | Date | Length |
|---|---|---|---|
| [M365.FM](https://podcasts.apple.com/gb/podcast/m365-fm-modern-work-security-and-productivity/id1810175174?i=1000773419918) | Securing Identities at Scale: Conditional Access, Azure Security & Infrastructure as Code | Jun 19, 2026 | 58 min |

Host: Mirko Peters. Topics: Conditional Access, Zero Trust, Bicep/IaC, passkeys, AI in security.

Also available on [Spreaker](https://www.spreaker.com/episode/securing-identities-at-scale-conditional-access-azure-security-infrastructure-as-code-with-jonathan-hope-mvp--72538680).

### Events

Placeholder — no in-person or virtual event sessions listed yet.

---

## 📡 RSS Feed — `feed.xml`

Standard RSS 2.0 feed. URL: `https://conditionalaccess.tech/feed.xml`

Autodiscovery `<link>` tags are present in `index.html` and `articles.html`. An RSS icon in the articles nav links directly to the feed.

**Current items (newest first):**

| # | Title | Published |
|---|---|---|
| 1 | Groups: The Connective Tissue of Microsoft 365 | Jun 16, 2026 |
| 2 | Who Did You Let Into Your House? | Jun 9, 2026 |
| 3 | Passkeys: Security Only Works If People Use It | Jun 1, 2026 |
| 4 | Authentication Methods: The Spectrum | May 15, 2026 |
| 5 | Identity Is Everything | May 1, 2026 |
| 6 | CA Policy Analyzer Update | May 7, 2026 |
| 7 | MFA for All… But Not the Same | Feb 1, 2026 |

New items are prepended automatically by the publish script. The `<lastBuildDate>` is also updated on each run.

---

## 🗂️ Folder Structure

```
index.html                    ← Homepage
articles.html                 ← Writing hub (root-level)
entra-news.html               ← Entra.News features tracker
appearances.html              ← Appearances page
about.html                    ← About page
styles.css                    ← Shared stylesheet
assets/                       ← Images: avatar, MVP badge, cert badges
feed.xml                      ← RSS 2.0 feed
articles/
  index.html                  ← Legacy hub (kept for backwards links)
  identity/                   ← Identity Series HTML files
    identity-is-everything.html
    authentication-methods.html
    passkeys.html
    who-did-you-let-in.html
    groups-connective-tissue.html
    images/
  governance/                 ← Governance Series HTML files (coming soon)
    readme.md                 ← Governance publish schedule
  conditional-access/         ← CA Series HTML files
    mfa-for-all-but-not-the-same.html
    ca-policy-analyzer/
      ca-policy-analyzer-update.html
    images/
  msp/                        ← MSP Series (planned)
    readme.md
```

---

## ⚙️ Publish Workflow

New articles are published using the orchestrator script:

```bash
python3 .github/scripts/publish.py --config .publish-config.json
```

The script updates all six site files in one run:

| File | What changes |
|---|---|
| `articles.html` | Featured article updated, series count +1, coming-soon card → live |
| `index.html` | Featured writing card title, description, URL |
| `feed.xml` | New `<item>` prepended, `lastBuildDate` updated |
| `entra-news.html` | New JS array entry added, Features + Issues counts incremented |
| `index.html` | Entra.News stats updated |
| `entra.news/readme.md` | At a Glance table + article catalogue row added |

Scheduled releases (coming-soon → live without Copilot) are handled separately by `.github/scripts/release_articles.py` via a GitHub Actions workflow.

