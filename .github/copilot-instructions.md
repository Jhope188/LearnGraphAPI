# conditionalaccess.tech — Copilot Workspace Instructions

This is Jon Hope's personal security blog at **conditionalaccess.tech**, hosted on GitHub Pages.
These instructions tell Copilot how to assist with the full article publish workflow.

---

## 🗂 Repo Structure

```
articles/
  index.html              ← Articles hub (legacy, kept for backwards links)
  identity/               ← Identity Series HTML files
  governance/             ← Governance Series HTML files
  conditional-access/     ← CA Series HTML files
  msp/                    ← MSP Series HTML files
about.html                ← About page
articles.html             ← Writing hub (root-level, replaces articles/index.html)
index.html                ← Homepage (featured writing card, Entra News stats)
appearances.html          ← Appearances page (podcasts, events, Entra.News link)
entra-news.html           ← Entra.News features tracker (JS-rendered feature list)
styles.css                ← Shared stylesheet for all root-level pages
assets/                   ← Images: avatar, MVP badge, cert badges
feed.xml                  ← RSS 2.0 feed (newest item first)
entra.news/readme.md      ← Entra.News stats + article catalogue
.github/scripts/publish.py        ← Master publish orchestrator
.publish-config.json      ← Ephemeral config written by Copilot before running publish.py
```

---

## 📋 Article Publish Workflow

When the user says any variation of:
- "publish article X"
- "I'm ready to post [article name]"
- "release the [series] article"
- "post the new article"

Follow these steps **in exact order**:

---

### Step 1 — Collect article metadata

Ask the user (or infer from context) for:
- **Title**: Full article title
- **Series tab**: `identity` | `governance` | `conditional-access` | `msp`
- **Series label**: e.g. `Identity Series · PT06`
- **Filename**: HTML filename only (e.g. `my-new-article.html`)
- **Publish date**: ISO format (default: today)
- **Description**: One clear sentence for cards, RSS, and meta
- **Is coming-soon?**: `true` if it's already in `articles/index.html` as a coming-soon card, `false` if it's brand new
- **Push to GitHub**: default `true`

---

### Step 2 — Check Entra News MCP

Use the `mcp_entra-news-mc_find_tool_mentions` tool to search for the article title:

```
query: "[article title]"
limit: 5
```

Also check `mcp_entra-news-mc_list_issues` to see the last 2–3 issues.

If the article **is featured** in a recent issue, collect:
- Issue number (e.g. `155`)
- Issue publication date (display format: `Jun 21, 2026`)
- Issue URL slug (e.g. `https://entra.news/p/entra-news-155-this-week-in-microsoft`)
- Section badge type: `ca` | `pop` | `sec` | `auth` | `tenant` | `dev`
- Whether the issue is new (not previously counted in the stats)

If **not featured**: set `entra_news` to `null`.

---

### Step 3 — Write `.publish-config.json`

Write this file at the repo root using all gathered data:

```json
{
  "title":         "Article Title Here",
  "series":        "identity",
  "series_label":  "Identity Series · PT06",
  "filename":      "my-article.html",
  "date":          "2026-06-23",
  "description":   "One sentence description.",
  "is_coming_soon": true,
  "push":          true,
  "entra_news": {
    "issue":     "155",
    "date":      "Jun 21, 2026",
    "url":       "https://entra.news/p/entra-news-155-this-week-in-microsoft",
    "badge":     "auth",
    "new_issue": true
  }
}
```

Set `entra_news` to `null` if not featured.

---

### Step 4 — Run the publish script

Run the VS Code task **"Publish Article (from config)"** or execute:

```bash
python3 .github/scripts/publish.py --config .publish-config.json
```

The script updates these files automatically:
| File | What changes |
|---|---|
| `articles.html` | featured article updated, series count +1, card activated/inserted |
| `index.html` | Featured writing card title, description, and URL |
| `feed.xml` | New `<item>` prepended, `lastBuildDate` updated |
| `entra-news.html` | JS features array entry added, Features + Issues stat counts incremented |
| `index.html` | Entra News stats updated (22 features / 20 issues → new counts) |
| `entra.news/readme.md` | At a Glance table, article catalogue row added, archive snapshot |

---

### Step 5 — Verify

After the script completes, confirm:
1. `articles/index.html` — latest-banner shows the new article title and date
2. `feed.xml` — new `<item>` is first in the channel
3. If Entra News: `entra-news.html` feature-grid has a new row at the top
4. Commit message is: `publish: [title] (Entra.News #NNN)` or `publish: [title]`

If anything looks wrong, read the relevant file and re-apply the specific fix.

---

### Step 6 — Clean up

Delete `.publish-config.json` (it's ephemeral) or leave it — it's in `.gitignore`.

---

## 🔧 Badge Type Reference

| Badge key | Display label | CSS class | When to use |
|---|---|---|---|
| `ca` | Conditional Access | `section-ca` | CA policy articles |
| `pop` | Most Popular | `section-pop` | Article reached Most Popular Posts |
| `sec` | Security | `section-sec` | Security-focused content |
| `auth` | Authentication | `section-auth` | Identity/authentication articles |
| `tenant` | Tenant | `section-tenant` | Tenant configuration content |
| `dev` | Dev | `section-dev` | Developer/Graph API content |

---

## 📰 Entra News count rules

- **Features**: increment by 1 for every new feature-row added, regardless of issue
- **Issues**: increment by 1 ONLY if the issue number has NOT been counted before
  - Same article appearing in a new issue = +1 feature, +1 issue
  - Second article in the same issue = +1 feature, +0 issues
- **Podium finishes**: updated manually when an article reaches #1, #2, or #3 Most Popular

---

## ✏️ Series label format

| Series | Format example |
|---|---|
| Identity | `Identity Series · PT06` |
| Governance | `Governance Series · PT01` |
| Conditional Access | `Conditional Access Series` |
| MSP | `MSP Series · PT01` |

---

## 🗒 Article card date format

- `May 2026` — when the exact day isn't significant or it's a month-only entry
- `Jun 1, 2026` — when publishing on a specific day

Use `fmt_display()` logic: `%b %-d, %Y`

---

## 🚫 Do not

- Manually edit `feed.xml` structure (use the script)
- Change `id="featured-article"` in `articles.html` — the script targets this selector
- Touch `release_articles.py` — that script handles scheduled GitHub Action releases only; `.github/scripts/publish.py` is for on-demand publishing
- Add `.publish-config.json` to git commits

---

## 🔁 Quick reference — files to update per publish

| Always | Only if Entra News featured |
|---|---|
| `articles.html` | `entra-news.html` |
| `index.html` (featured writing card) | `index.html` (Entra News stats) |
| `feed.xml` | `entra.news/readme.md` |
