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
| `articles.html` | featured article updated, series count +1, card activated/inserted, show-more button `data-total` +1 |
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

---

## 🔢 articles.html — Count sync rule (CRITICAL)

Every section in `articles.html` has **two** numbers that must always match. When adding or activating any article card, update **both** in the same edit:

| Element | Selector pattern | Example |
|---|---|---|
| Section badge | `<span id="count-[series]">N articles</span>` | `7 articles` |
| Show-more button | `<button ... data-total="N">Show all N articles ↓</button>` | `data-total="7"` |

**Series IDs:** `count-identity` / `count-conditional-access` / `count-governance` / `count-entra` / `count-msp`

If the button is missing for a section, add one following the same pattern as the CA section. Never update one without the other.

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
| | `appearances.html` (Featured N times heading, issues count, meta description) |

---

## � Mobile Layout & Navigation Standard (all articles)

Every article must use this exact header/navigation pattern. This was validated across iPhone (402×874) and Android (Pixel 8, 412×915) form factors in portrait and landscape using `mobile-test.html`. Apply verbatim to new articles — do not invent variations.

### Fixed topbar (required, identical markup/CSS on every article)
```html
<header class="topbar">
  <a href="https://conditionalaccess.tech" class="topbar-left">
    <img src="https://conditionalaccess.tech/assets/NewConditionalaccess.tech.png" alt="" />
    <span class="topbar-site">conditionalaccess.tech</span>
    <span class="topbar-divider"></span>
    <span class="topbar-article">[Short Article Title]</span>
  </a>
  <a href="https://conditionalaccess.tech/articles.html" class="topbar-right">← All Articles</a>
</header>
```
- `.topbar` is `position: fixed; height: 52px;` — never variable-height, never a `.nav` custom to one article.
- `.topbar-left` must have `min-width: 0` and `.topbar-article` must have `overflow:hidden; text-overflow:ellipsis; white-space:nowrap` so long titles truncate instead of wrapping/breaking the bar on narrow phones.
- `.topbar-right` always points to `articles.html` with the exact label `← All Articles`.
- Never reintroduce a floating `.back-btn`, `.logo-badge`, or standalone `.wordmark` — the topbar replaces all of those.
- **NEVER embed a base64-encoded `data:image/...` string for the topbar logo (or any other UI chrome image).** Always use the hosted path `https://conditionalaccess.tech/assets/NewConditionalaccess.tech.png`. This has caused real, hard-to-spot production bugs twice: a corrupted/oversized base64 blob (one case was 2.2MB on a single line, containing stray C2PA/JUMBF metadata) silently broke the topbar's flex layout, causing it to not span edge-to-edge with text rendering incorrectly around it — while `read_file` line-range tools failed to surface the problem because the single line was too long to render normally. If a topbar/nav bug resists CSS-level fixes, check with `grep -n 'data:image' file.html` and `awk '/data:image/{print NR": len="length($0)}'` to rule out an oversized inline image before spending time on CSS theories. Legitimate embedded screenshots elsewhere in an article (100–700KB, with descriptive alt text) are fine and not the same issue — the tell is an image with generic/empty alt text embedded in header/nav chrome, or any single line exceeding ~1MB.

### Desktop TOC vs. mobile TOC (900px breakpoint)
- **Desktop (>900px):** vertical sticky `.sidebar` (`position: sticky; top: 2rem`), numbered links, active state = colored text + left border accent.
- **Mobile (≤900px):** `.sidebar` is hidden (`display:none`) and one of two things takes over:
  1. `.mobile-toc` — horizontal scrollable pill bar, OR
  2. `.series-nav` — horizontal tab bar reused as the mobile TOC (only when the article is part of a numbered series with its own series nav).
- Whichever mobile nav is used **must** be `position: sticky; top: 52px;` (exactly the topbar height) so it docks directly under the fixed topbar with no gap and never disappears while scrolling.
- Mobile nav active-state styling is unified as a **filled pill**: `background: var(--color-teal); color: var(--color-base);` (dark text on solid teal) — not an outline/underline style. Inactive pills use a subtle border/background (`rgba(255,255,255,0.03–0.05)`).
- Add `scroll-margin-top` to section headings so anchored jumps land below the fixed topbar + mobile nav (~120–128px on mobile, ~2–4rem on desktop). Don't cut this too close — the pill nav's real rendered height varies slightly by device font metrics, so err on the generous side rather than the minimum that looks correct on one screenshot.
- **Edge-to-edge mobile nav bleed — use `width: 100vw; margin-left: calc(-50vw + 50%); margin-right: calc(-50vw + 50%);` on the nav element itself, NOT a negative margin matched to the parent `.page-body`'s padding value.** The negative-margin-matching-parent-padding approach (e.g. `margin: 0 -1rem` when `.page-body` has `padding: 0 1rem`) is fragile: if `.page-body` padding differs between the base ≤900px rule and a landscape-specific override (a common pattern for hero/article spacing), the nav's bleed silently falls out of sync and reintroduces edge gaps in one orientation. The `100vw` viewport-relative technique is immune to parent padding entirely and is the same effective result the CA article gets by placing `.mobile-toc` as a sibling of `.page-body` outside its padded box. Prefer the `100vw` technique for any nav/element that needs to escape a padded container, regardless of how many breakpoints override that container's padding.

### Responsive images (required on every article with screenshots)
Add this landscape safeguard so screenshots never overflow a short landscape viewport:
```css
@media (max-width: 900px) and (orientation: landscape) {
  .screenshot-block img, .screenshot-panel img, .screenshot-single img, .img-block img {
    max-width: 100%; width: auto; height: auto;
    max-height: calc(100vh - 52px - 56px);
    object-fit: contain;
    display: block; margin-left: auto; margin-right: auto;
  }
}
```

### Flex containers must not silently overflow (required on every article with `.step-block`/screenshots)
A flex child's default `min-width` is `auto`, not `0`. If a `.step-block`/`.step-content` wraps a wide screenshot or code block, the flex item can force the whole layout wider than the viewport on mobile — this drags the sticky sidebar/mobile-toc pill bar out of alignment with the fixed topbar the moment the page is scrolled sideways (looks like the nav "jumps" or briefly misaligns, and can leave a stuck state when rotating orientation). Always pair flex-based content wrappers with an explicit reset:
```css
.step-block { display: flex; gap: 1rem; align-items: flex-start; min-width: 0; }
.step-content { flex: 1; min-width: 0; }
.screenshot-block { max-width: 100%; }
.screenshot-block img { width: 100%; max-width: 100%; height: auto; display: block; }
```
This was the root cause found in the NHI article's Section 6 (Step A/B/C investigation screenshots) — apply this pattern to every new `.step-block` section, not just ones with images, since text-only step blocks are safe but any future embedded media inside one is not.

### Testing requirement before publish
- Use `mobile-test.html` (served locally, e.g. `python3 -m http.server 8000`) to check every new/edited article.
- **Always test both device presets** in the tester's Device dropdown — iPhone 17 Pro (402×874) and Pixel 8 / Android (412×915) — in **both** Portrait and Landscape, before publishing or considering an article/layout change done. Never assume iPhone-only testing covers Android; the punch-hole vs. Dynamic-Island frame and differing safe-area math means it doesn't.
- Confirm: topbar stays fixed, mobile nav is sticky directly under it (no gap, no disappearing), active pill is filled-teal, images don't overflow in landscape, and scrolling within any section (including sideways/inner-scroll on wide content) doesn't shift the sidebar/topbar out of alignment.
- Always cache-bust (`?t=timestamp`, already built into the tester's Reload/page-select) before trusting a screenshot.

---

## �📄 Article HTML template standards

Every article HTML file **must** include the following. Apply these when creating a new article or updating an existing one.

### Head block (required on every article)
- `<meta name="description" content="…">` — one sentence, matches the publish description
- `<link rel="canonical" href="https://conditionalaccess.tech/articles/[series]/[slug].html">`
- `<link rel="alternate" type="application/rss+xml" title="conditionalaccess.tech" href="/feed.xml">`
- Full Open Graph tags: `og:type` (article), `og:title`, `og:description`, `og:url`, `og:image`, `og:site_name`, `article:published_time`, `article:author`
- Twitter card: `twitter:card` (summary_large_image), `twitter:title`, `twitter:description`, `twitter:image`
- OG image path: `/assets/og/[slug].png` at 1200×630. File must exist before deploying — missing images won't break the page but LinkedIn/Twitter cards will render without artwork.
- Title tag format: `[Article Title] — conditionalaccess.tech`

### Site nav (replaces old floating Back/Home button)
- Slim fixed nav bar: wordmark left, **Writing / Appearances / About** links right
- Mark the active section (Writing for all articles)
- Appearances link hidden below 640 px via CSS

### Series nav (Identity series)
- All published posts are clickable links with hover state and "Read" affordance
- Current post is highlighted and non-clickable
- When a new Identity post publishes, add it to every other Identity article's series nav
- Governance series nav: leave non-clickable until Governance PT01 is live

### Prev / Next navigation
- Add below the series nav
- Part 1: next only. Final part: previous only. All others: both.
- CA articles cross-link: MFA for All ↔ CA Policy Analyzer Update

### CTA block
- Standard: **"Keep Reading / Browse All Articles"** → `articles.html`
- Secondary text links: RSS feed + Medium
- Exception: CA Policy Analyzer article keeps **"Launch the Analyzer"** as its primary CTA

---

## ✅ Pre-deploy checklist

Run through this before every article deploy or template update:

1. **OG images** — confirm `/assets/og/[slug].png` exists for every article being deployed. Create a 1200×630 image (or point all tags at one shared fallback) if missing.
2. **`article:published_time`** — verify the ISO date matches the actual publish date for each article. Check `articles.html` card dates if unsure.
3. **Series nav links** — if this is a new Identity or CA post, update the series nav in all sibling articles to include it.
4. **Prev/Next** — update the previous article's "next" link to point at the new article.
5. **After deploy** — run each new or updated URL through the [LinkedIn Post Inspector](https://www.linkedin.com/post-inspector/) to purge LinkedIn's share cache. Old previews persist until the cache is cleared.
