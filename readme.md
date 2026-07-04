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

- **Hero** — Name, MVP badge, role (M365 Solutions Architect · Inforcer), bio, LinkedIn + Medium CTAs
- **Focus** — Three pillars: Microsoft Entra ID, Conditional Access, M365 Governance
- **Resources** — Tool cards: CA Policy Analyzer, Graph API Reference, CA Policy Templates, Entra Baselines
- **Writing** — Featured latest article card (`id="latest-article"`, auto-updated by publish script) + three recent row links
- **Appearances** — YouTube playlist card + Podcasts & Events card (links to `appearances.html`)
- **CTA Band** — LinkedIn connect + Medium read buttons
- **Footer** — Copyright

---

## �� Writing Hub — `articles.html`

Root-level article index (replaces `articles/index.html`). Three series sections with article count badges.

### 🔵 Identity Series — 5 articles live

| PT | Title | Published |
|---|---|---|
| PT01 | [Identity Is Everything](articles/identity/identity-is-everything.html) | May 18, 2026 |
| PT02 | [Authentication Methods: The Spectrum](articles/identity/authentication-methods.html) | May 25, 2026 |
| PT03 | [Passkeys: Security Only Works If People Use It](articles/identity/passkeys.html) | Jun 1, 2026 |
| PT04 | [Who Did You Let Into Your House?](articles/identity/who-did-you-let-in.html) | Jun 9, 2026 |
| PT05 | [Groups: The Connective Tissue of Microsoft 365](articles/identity/groups-connective-tissue.html) | Jun 16, 2026 |

All five articles have: fixed site nav bar, full Open Graph + Twitter card meta, series nav (all links live and clickable), prev/next navigation, and "Browse All Articles" CTA.

OG images live in `articles/identity/images/`:

| Slug | File |
|---|---|
| identity-is-everything | `Identityinreality.png` |
| authentication-methods | `identityauthmethods.png` |
| passkeys | `identitypasskeys.png` |
| who-did-you-let-in | `whodidyouletin.png` |
| groups-connective-tissue | `Groupstheconnectivetissue.png` |

Series focus: Microsoft Entra ID, authentication, identity architecture, and threat detection.

---

### 🟡 Governance Series — 1 live · 4 scheduled

| PT | Title | Status | Date |
|---|---|---|---|
| PT01 | [Groups Are the Connective Tissue](articles/governance/groups-connective-tissue.html) | ✅ Live | Jul 6, 2026 |
| PT02 | The Governance Gap | 🔒 Scheduled | Jul 20, 2026 |
| PT03 | The Cleanup Campaign That Never Ends | 🔒 Scheduled | Aug 3, 2026 |
| PT04 | Clean the House Before the Guests Arrive | 🔒 Scheduled | Aug 17, 2026 |
| PT05 | The Ownership Operating Model | 🔒 Scheduled | Aug 31, 2026 |

Series publishes biweekly from Jul 6. Files live in `articles/governance/` when published.

OG image for PT01: `articles/governance/images/pt01-groupstheconnectivetissue.png`

Series focus: M365 governance, group lifecycle, ownership models, tenant cleanup, and Copilot readiness.

---

### 🟢 Conditional Access Series — 3 articles live

| Title | Published |
|---|---|
| [Baseline Scopes: Microsoft Closed the Side Door](articles/conditional-access/baseline-scopes-publish/baseline-scopes.html) | Jul 2026 |
| [CA Policy Analyzer Update](articles/conditional-access/ca-policy-analyzer/ca-policy-analyzer-update.html) | May 2026 |
| [MFA for All… But Not the Same](articles/conditional-access/mfa-for-all-but-not-the-same.html) | Feb 2026 |

MFA for All ↔ CA Policy Analyzer cross-linked via prev/next navigation.

OG images live in `articles/conditional-access/images/`:
- `CATechBaselineScopes.png` — Baseline Scopes hero
- `CAGapPyramidNew.png` — CA gap diagram
- `LinkedInBaselineScopePost.png`
- `PasskeyRPID.png`
- `BaselineScope/` — portal screenshot subfolder

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
- **JS feature list** — all features rendered from a JS array (newest first); updated by publish script
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
| 1 | Groups Are the Connective Tissue (Governance PT01) | Jul 6, 2026 |
| 2 | Groups: The Connective Tissue of Microsoft 365 (Identity PT05) | Jun 16, 2026 |
| 3 | Who Did You Let Into Your House? | Jun 9, 2026 |
| 4 | Passkeys: Security Only Works If People Use It | Jun 1, 2026 |
| 5 | Authentication Methods: The Spectrum | May 25, 2026 |
| 6 | Identity Is Everything | May 18, 2026 |
| 7 | CA Policy Analyzer Update | May 7, 2026 |
| 8 | MFA for All… But Not the Same | Feb 2026 |

New items are prepended automatically by the publish script. The `<lastBuildDate>` is also updated on each run.

---

## 🗂️ Folder Structure

```
index.html                          ← Homepage
articles.html                       ← Writing hub (root-level)
entra-news.html                     ← Entra.News features tracker
appearances.html                    ← Appearances page
about.html                          ← About page
styles.css                          ← Shared stylesheet
assets/                             ← Images: avatar, MVP badge, cert badges
feed.xml                            ← RSS 2.0 feed
articles/
  index.html                        ← Legacy hub (kept for backwards links)
  identity/
    identity-is-everything.html
    authentication-methods.html
    passkeys.html
    who-did-you-let-in.html
    groups-connective-tissue.html
    images/
      Identityinreality.png         ← OG: identity-is-everything
      identityauthmethods.png       ← OG: authentication-methods
      identitypasskeys.png          ← OG: passkeys
      whodidyouletin.png            ← OG: who-did-you-let-in
      Groupstheconnectivetissue.png ← OG: groups-connective-tissue
      groupsastheconnectivetissue.png
  governance/
    groups-connective-tissue.html   ← PT01 · live Jul 6, 2026
    readme.md                       ← Governance publish schedule
    images/
      pt01-groupstheconnectivetissue.png  ← OG: governance PT01
      Groups/                       ← Supporting HTML reference file
  conditional-access/
    mfa-for-all-but-not-the-same.html
    baseline-scopes-publish/
      baseline-scopes.html          ← Baseline Scopes article
      assets/
        baseline-scopes-hero.png
        baseline-scopes-portal.png
        excluded-resources.png
    ca-policy-analyzer/
      ca-policy-analyzer-update.html
      natp-ep11-thumb.png
    images/
      CATechBaselineScopes.png
      CAGapPyramidNew.png
      LinkedInBaselineScopePost.png
      PasskeyRPID.png
      BaselineScope/                ← Portal screenshot subfolder
  msp/
    readme.md                       ← MSP Series (planned)
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

Scheduled releases (coming-soon → live without Copilot) are handled by `.github/scripts/release_articles.py` via the weekly cron workflow.

---

## 🚀 GitHub Actions Workflows

| Workflow | File | Trigger |
|---|---|---|
| Deploy GitHub Pages | `.github/workflows/pages.yml` | Push to `main` / manual |
| Scheduled Article Release | `.github/workflows/scheduled-release.yml` | Sundays 12:00 UTC / manual |
| Entra News Feature Update | `.github/workflows/entra-news-update.yml` | Manual dispatch |

The Pages workflow uses `actions/configure-pages@v5`, `actions/upload-pages-artifact@v3`, and `actions/deploy-pages@v4` (all current versions, Node.js 24 compatible).

---

## 📝 Article Template Standards

All published articles include:

- **Fixed site nav bar** — wordmark left, Writing / Appearances / About right (Appearances hidden below 640 px)
- **Meta block** — `<meta name="description">`, canonical URL, RSS alternate link, full Open Graph tags (`og:type`, `og:title`, `og:description`, `og:url`, `og:image` 1200×630, `og:site_name`, `article:published_time`, `article:author`), Twitter `summary_large_image` card
- **Title format** — `Article Title — conditionalaccess.tech`
- **Series nav** — clickable for all live posts; current post highlighted and non-clickable
- **Prev/Next navigation** — linked within series (PT01 has next only, PT05 has prev only)
- **CTA** — "Browse All Articles" pointing at `articles.html`; RSS and Medium as secondary text links
- **OG images** — stored in the series `images/` folder, referenced as absolute `https://conditionalaccess.tech/articles/{series}/images/{slug}.png`
