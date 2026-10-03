# article-archive

Safe-keeping archive of every published conditionalaccess.tech article, generated from the
live CATech-branded HTML in [`articles/`](../articles).

## Structure

```
article-archive/
  catech-branded/<series>/<slug>.html   # exact copy of the live, as-published HTML
  markdown/<series>/<slug>.md           # plain-Markdown copy (YAML frontmatter + body)
  medium/<series>/<slug>.html           # stripped-down HTML safe to paste into Medium's editor
  images/<series>/<slug>/img-NN.ext     # screenshots that were embedded as base64 in the
                                         # source HTML, extracted to real files and shared
                                         # by reference between the markdown/ and medium/ copies
  scripts/convert.py                    # regenerates markdown/ + medium/ + images/ from
                                         # catech-branded/'s source articles list
```

`series` is one of `identity`, `governance`, `conditional-access`, `entra`, `azure`.

## Regenerating

```bash
python3 article-archive/scripts/convert.py
```

This re-reads the 23 published articles listed at the top of `scripts/convert.py` (in
`articles/`, not `catech-branded/`), rebuilds every `.md` / Medium `.html` file, and
re-extracts embedded screenshots into `images/`. Re-run it any time an article is updated.

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

## Medium copies

The `medium/` HTML files only use tags Medium's editor understands when pasted
(`h1`/`h2`/`h3`, `p`, `strong`, `em`, `a`, `blockquote`, `ul`/`ol`/`li`, `pre`/`code`, `img`,
`hr`) with no CSS classes or inline styles. Open a file in a browser, select all, and paste
into Medium's story editor. Image `src` paths are relative to this folder (`../../images/...`),
so keep the whole `article-archive/` folder together, or re-upload the images manually if you
move a single file out on its own.
