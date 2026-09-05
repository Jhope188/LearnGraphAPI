# Article template

`article-template.html` is the reusable base layout for conditionalaccess.tech long-form articles, extracted from [`articles/entra/service-principal-shadow-admins.html`](../entra/service-principal-shadow-admins.html) ("NHI? Never Heard of Him").

## Layout behavior

- **Desktop (>900px):** sticky left sidebar table-of-contents + centered article column, matching the site's dark/teal visual system.
- **Tablet & mobile (≤900px):** the sidebar TOC collapses into a horizontal, scrollable pill bar docked directly under the topbar — it no longer disappears. Active-section highlighting (via `IntersectionObserver`) still works against the same links.
- **Phone/tablet landscape (≤900px width, landscape orientation):** hero padding compresses to reduce vertical scroll, and wide elements (tables, code blocks, screenshots) bleed to the viewport edges to make better use of the extra horizontal space instead of staying capped at portrait width.

## How to use

1. Copy `article-template.html` into the correct series folder: `articles/<series>/<slug>.html`.
2. Fill in the `<meta og:*>` tags, `<title>`, and hero eyebrow/H1/subtitle/sub copy.
3. Replace the sidebar `<ol>` entries with one `<li>` per `<h2 id="...">` in your article, numbered in order.
4. Write the article body using the built-in component patterns already present in the template — copy/paste and edit:
   - `.callout` / `.callout-warn` / `.callout-danger` — notes, cautions, warnings
   - `.badge-ok` / `.badge-warn` / `.badge-danger` — inline severity tags
   - `pre` / `code` — code blocks and inline code
   - `.step-block` + `.step-num` — numbered walkthroughs
   - `.screenshot-block` + `.screenshot-caption` — captioned images
   - `.perm-table` — data tables
   - `.card-featured` — highlighted summary/pull-out boxes
   - `blockquote` — pull-quotes
5. Update the footer credit line if authorship changes.
6. Follow the publish workflow in [.github/copilot-instructions.md](../../.github/copilot-instructions.md) to wire the new article into `articles.html`, `index.html`, `feed.xml`, and (if applicable) `entra-news.html`.

Do not edit the CSS/responsive rules per-article unless a genuinely new pattern is needed — fix it in the template first so every future article inherits the improvement.
