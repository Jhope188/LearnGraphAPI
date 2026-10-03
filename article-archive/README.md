# article-archive

Safe-keeping archive of every published conditionalaccess.tech article, generated from the
live CATech-branded HTML in [`articles/`](../articles).

## Structure

```
article-archive/
  catech-branded/<series>/<slug>.html   # exact copy of the live, as-published HTML
  markdown/<series>/<slug>.md           # plain-Markdown copy (YAML frontmatter + body)
  medium/<series>/<slug>.html           # stripped-down HTML safe to paste into Medium's editor
  images/<series>/<slug>/
    <slug>-NN.ext                       # screenshots that were embedded as base64 in the
                                         # source HTML, extracted to real files and shared
                                         # by reference between the markdown/ and medium/ copies
    <slug>-component-NN.png             # real <table>s / multi-card grids, rendered with the
                                         # article's own CSS in a headless browser and
                                         # screenshotted - used only in medium/ (see below)
  scripts/convert.py                    # regenerates markdown/ + medium/ + images/ from
                                         # catech-branded/'s source articles list
```

`series` is one of `identity`, `governance`, `conditional-access`, `entra`, `azure`.

## Regenerating

```bash
pip3 install playwright && python3 -m playwright install chromium   # one-time, for visual export

# Full regen of every article published/linked from articles.html (fast - no
# visual-component screenshots unless you ask for them):
python3 article-archive/scripts/convert.py
python3 article-archive/scripts/convert.py --visual-export-all   # + screenshot every table/grid

# Just one article, always with visual-component export (this is what
# .github/scripts/publish.py calls automatically on every publish - see below):
python3 article-archive/scripts/convert.py --article articles/entra/service-principal-shadow-admins.html --series entra
```

Full-regen mode discovers the published article list from `articles.html`'s links (not a
hand-maintained list), so newly published articles are picked up automatically.

## Runs automatically on every publish

`.github/scripts/publish.py` calls `convert.py --article ... --series ...` for the article
being published, right before it commits and pushes, via `export_archive_copy()`. That means
every `publish: ...` commit also includes an updated `catech-branded/` + `markdown/` +
`medium/` (+ `images/`) copy of that article, with visual-component screenshots always on for
the article actually being published. If the archive step fails for any reason (Playwright
not installed, etc.) it prints a warning and the real site publish still completes - it never
blocks a publish.

## How the conversion works

Each CATech article invents its own bespoke CSS component names (`compare-card`,
`persona-card`, `rung`, `spoke`, `mistake`, ...). Rather than hand-coding every one-off class,
`convert.py` extracts content structurally:

- strips known site chrome (topbar/site-header, sidebar TOC, series-nav, mobile-toc,
  cta-block, scripts/styles)
- walks real semantic tags (`h2`-`h6`, `p`, `ul`/`ol`, `table`, `pre`, `blockquote`, `hr`,
  `img`/`figure`)
- recognizes the cross-article "numbered section header" pattern (`section-num` +
  `section-title`, `mistake-num` + `mistake-title`, etc.) and turns it into a real `## N. Title`
  heading
- treats any div whose children look like an icon/label/title/description/list/footer as a
  generic "card" and flattens it into a bold title line + paragraph(s) + nested list, in
  reading order, regardless of what the component's CSS class is actually called

This is a readability-first, content-complete conversion, not a pixel-perfect one. Visual
layouts (side-by-side comparison grids, flowcharts, multi-column tables built from `div`s
instead of `<table>`) are flattened into sequential prose/lists. Spot-check before publishing.

## Visual component export (tables / comparison grids -> screenshots)

Real `<table>` elements and multi-card "grid" components (comparison grids, defense stacks,
persona rows, ...) render poorly once flattened to plain text, and Medium's own table support
is weak. For these, `convert.py` uses Playwright to open the *original* article in a headless
browser (so the real CSS applies), hides the fixed topbar/nav/sidebar chrome, and screenshots
just that component - no manual cropping. The Medium HTML gets an `<img>` in that component's
exact place instead of the flattened text; the Markdown copy is untouched, since a real GFM
table or a flattened card list already reads fine as Markdown.

Detection is generic, not based on specific class names:
- every real `<table>` is always exported
- any div/section whose *every* direct child independently qualifies as a "card" (see above),
  with 2 or more such children, is treated as a visual grid and exported as one image

Visual export always runs for a single `--article` invocation (used by `publish.py` and the
test above). For full-regen mode, it's opt-in via `--visual-export-all` since it adds real
browser rendering time per article. Requires
`pip3 install playwright && python3 -m playwright install chromium`; if Playwright isn't
installed, this step is silently skipped and the rest of the conversion still runs exactly
as before.

## Medium copies

The `medium/` HTML files only use tags Medium's editor understands when pasted
(`h1`/`h2`/`h3`, `p`, `strong`, `em`, `a`, `blockquote`, `ul`/`ol`/`li`, `pre`/`code`, `img`,
`hr`) with no CSS classes or inline styles. Open a file in a browser, select all, and paste
into Medium's story editor. Image `src` paths are relative to this folder (`../../images/...`),
so keep the whole `article-archive/` folder together, or re-upload the images manually if you
move a single file out on its own. For the `component-NN.png` screenshots specifically, Medium
needs its own uploaded copy of each image (it won't fetch a local file path when you paste) -
upload each one at the point it appears in the pasted draft.
