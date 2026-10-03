#!/usr/bin/env python3
"""
Convert conditionalaccess.tech CATech-branded article HTML into:
  1. A Markdown archive copy (article-archive/markdown/<series>/<slug>.md)
  2. A simplified, Medium-friendly HTML copy (article-archive/medium/<series>/<slug>.html)

The CATech article templates are visually rich but each article invents its own
bespoke CSS component names (compare-card, persona-card, rung, spoke, mistake, ...).
Rather than hand-coding every one-off class name, this converter extracts content
generically:
  - strips known site chrome (topbar/site-header, sidebar TOC, series-nav, mobile-toc,
    cta-block, scripts/styles, decorative svg/buttons)
  - walks real semantic tags (h2-h6, p, ul/ol, table, pre, blockquote, hr, img/figure)
  - treats any bespoke "card" div (one with child elements whose classes suggest an
    icon/label/title/description/list/footer pattern) as a generic card and flattens
    it into a title line + description paragraph(s) + nested list, preserving
    reading order without needing to know the component's specific class names.

Run: python3 article-archive/scripts/convert.py
"""
import base64
import os
import re
import sys
from urllib.parse import urljoin

from bs4 import BeautifulSoup, Comment, NavigableString, Tag

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SITE_BASE = "https://conditionalaccess.tech/"

SOURCES = [
    ("articles/azure/azure-policy-msp-governance.html", "azure"),
    ("articles/conditional-access/baseline-scopes-publish/baseline-scopes.html", "conditional-access"),
    ("articles/conditional-access/ca-mistakes-top-10.html", "conditional-access"),
    ("articles/conditional-access/ca-policy-analyzer-july-2026.html", "conditional-access"),
    ("articles/conditional-access/ca-policy-analyzer/ca-policy-analyzer-update.html", "conditional-access"),
    ("articles/conditional-access/ca-safety-net.html", "conditional-access"),
    ("articles/conditional-access/demo-ca-rpmsg-aip-exclusion.html", "conditional-access"),
    ("articles/conditional-access/mfa-for-all-but-not-the-same.html", "conditional-access"),
    ("articles/entra/au-vs-rmau.html", "entra"),
    ("articles/entra/mastering-groups-deep-dive.html", "entra"),
    ("articles/entra/service-principal-shadow-admins.html", "entra"),
    ("articles/entra/sms-voice-retirement-part1.html", "entra"),
    ("articles/entra/sms-voice-retirement-part2.html", "entra"),
    ("articles/governance/ai-readiness-governance-audit.html", "governance"),
    ("articles/governance/configuration-is-not-control.html", "governance"),
    ("articles/governance/groups-connective-tissue.html", "governance"),
    ("articles/governance/lifecycle-sprawl-countermeasure.html", "governance"),
    ("articles/governance/ownership-operating-model.html", "governance"),
    ("articles/identity/authentication-methods.html", "identity"),
    ("articles/identity/groups-connective-tissue.html", "identity"),
    ("articles/identity/identity-is-everything.html", "identity"),
    ("articles/identity/passkeys.html", "identity"),
    ("articles/identity/who-did-you-let-in.html", "identity"),
]

SKIP_TAGS = {"script", "style", "nav", "header", "aside", "svg", "button",
             "input", "select", "option", "noscript", "form"}

SKIP_CLASS_SUBSTR = [
    "site-header", "topbar", "site-nav", "sidebar", "series-nav", "mobile-toc",
    "cta-block", "back-btn", "scroll-hint", "article-nav", "mobile-test",
    "hero",  # hero is parsed separately
]

INLINE_UNWRAP = {"span", "label", "i", "b", "strong", "em", "code", "a", "sup", "cite"}


def classes_of(tag):
    return tag.get("class") or []


def cls_str(tag):
    return " ".join(classes_of(tag))


def has_any_class_substr(tag, substrs):
    c = cls_str(tag)
    return any(s in c for s in substrs)


def class_contains(tag, needle):
    return any(needle in c for c in classes_of(tag))


def norm_ws(text):
    return re.sub(r"\s+", " ", text).strip()


def norm_ws_inline(text):
    """Collapse internal whitespace but keep a single leading/trailing space
    if present, so adjacent inline tags don't get glued together."""
    return re.sub(r"\s+", " ", text)


# ---------------------------------------------------------------------------
# Inline rendering (markdown + clean html)
# ---------------------------------------------------------------------------

def inline_md(node, base_url):
    if isinstance(node, Comment):
        return ""
    if isinstance(node, NavigableString):
        return norm_ws_inline(str(node))
    if not isinstance(node, Tag):
        return ""
    name = node.name
    if name == "br":
        return "  \n"
    inner = "".join(inline_md(c, base_url) for c in node.children).strip()
    if name in ("strong", "b"):
        return f"**{inner}**" if inner else ""
    if name in ("em", "i", "cite"):
        return f"*{inner}*" if inner else ""
    if name == "code":
        text = node.get_text()
        return f"`{text}`" if text else ""
    if name == "sup":
        return f"^{inner}"
    if name == "a":
        href = node.get("href") or ""
        href = urljoin(base_url, href) if href and not href.startswith("#") else href
        return f"[{inner}]({href})" if inner else ""
    return inner


def inline_text(node):
    """Plain text version (no markup) for titles/labels."""
    if isinstance(node, Tag):
        return norm_ws(node.get_text(separator=" "))
    return norm_ws(str(node))


def block_text_md(tag, base_url):
    """Render inline markdown for all children of a block-level tag (e.g. <p>)."""
    return "".join(inline_md(c, base_url) for c in tag.children).strip()


def inline_html(node, base_url):
    if isinstance(node, Comment):
        return ""
    if isinstance(node, NavigableString):
        return norm_ws_inline(str(node))
    if not isinstance(node, Tag):
        return ""
    name = node.name
    if name == "br":
        return "<br>"
    inner = "".join(inline_html(c, base_url) for c in node.children).strip()
    if name in ("strong", "b"):
        return f"<strong>{inner}</strong>" if inner else ""
    if name in ("em", "i", "cite"):
        return f"<em>{inner}</em>" if inner else ""
    if name == "code":
        text = node.get_text()
        return f"<code>{escape_html(text)}</code>" if text else ""
    if name == "sup":
        return f"<sup>{inner}</sup>"
    if name == "a":
        href = node.get("href") or ""
        href = urljoin(base_url, href) if href and not href.startswith("#") else href
        return f'<a href="{href}">{inner}</a>' if inner else ""
    return inner


def escape_html(text):
    return (text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


# ---------------------------------------------------------------------------
# Block model: list of dicts -> rendered to markdown and clean html
# ---------------------------------------------------------------------------

def should_skip(tag):
    if not isinstance(tag, Tag):
        return True
    if tag.name in SKIP_TAGS:
        return True
    if has_any_class_substr(tag, SKIP_CLASS_SUBSTR):
        return True
    return False


def is_leaf_card_component(tag):
    """A div whose direct children look like icon/label/num/title/desc/list/footer
    pieces of a bespoke 'card' component, regardless of the exact class prefix used."""
    if tag.name not in ("div", "section"):
        return False
    children = [c for c in tag.find_all(True, recursive=False)]
    if not children:
        return False
    has_title = any(class_contains(c, "title") for c in children)
    has_text = any(
        class_contains(c, "desc") or class_contains(c, "text") or class_contains(c, "body")
        or (c.name == "p")
        for c in children
    )
    return has_title and has_text


def numbered_heading_text(tag):
    """Recognize the cross-article 'numbered section header' pattern: a wrapper
    div whose only direct children are a short number/order marker (section-num,
    mistake-num, step-num, ...) and a title (section-title, mistake-title, ...).
    Returns the combined heading text, or None if the tag doesn't match."""
    if tag.name not in ("div", "section"):
        return None
    children = [c for c in tag.find_all(True, recursive=False) if inline_text(c)]
    if len(children) != 2:
        return None
    num_el = next((c for c in children if class_contains(c, "num")), None)
    title_el = next((c for c in children if class_contains(c, "title") or class_contains(c, "header")), None)
    if num_el is None or title_el is None or num_el is title_el:
        return None
    num_text = inline_text(num_el)
    title_text = inline_text(title_el)
    if len(num_text) > 6 or not title_text:
        return None
    sep = ". " if num_text[:1].isdigit() else " "
    return f"{num_text}{sep}{title_text}"


def render_card(tag, base_url, img_ctx=None):
    children = tag.find_all(True, recursive=False)
    consumed = set()
    emoji = label = num = title = footer = None
    descs = []
    descs_html = []
    sublist_tag = None

    for c in children:
        cid = id(c)
        if class_contains(c, "emoji") or class_contains(c, "icon"):
            if emoji is None:
                emoji = inline_text(c)
                consumed.add(cid)
        elif class_contains(c, "callout-label"):
            pass  # not a card marker
        elif class_contains(c, "label") and title is None:
            if label is None:
                label = inline_text(c)
                consumed.add(cid)
        elif class_contains(c, "num") and len(inline_text(c)) <= 6:
            if num is None:
                num = inline_text(c)
                consumed.add(cid)
        elif class_contains(c, "title") and title is None:
            title = inline_text(c)
            consumed.add(cid)
        elif class_contains(c, "footer") or class_contains(c, "meta"):
            if footer is None:
                footer = inline_text(c)
                consumed.add(cid)
        elif c.name in ("ul", "ol"):
            if sublist_tag is None:
                sublist_tag = c
                consumed.add(cid)
        elif class_contains(c, "desc") or class_contains(c, "text") or class_contains(c, "body") or c.name == "p":
            text = block_text_md(c, base_url)
            if text:
                descs.append(text)
                descs_html.append(inline_html_children(c, base_url))
            consumed.add(cid)

    lines = []
    heading_bits = [b for b in (num, emoji) if b]
    title_line = f"**{title}**" if title else ""
    if heading_bits and title_line:
        title_line = " ".join(heading_bits) + " " + title_line
    elif heading_bits and not title_line:
        title_line = " ".join(heading_bits)
    if label:
        lines.append(f"*{label}*")
    if title_line:
        lines.append(title_line)
    lines.extend(descs)

    blocks = []
    md_text = "\n\n".join(lines)
    html_bits = []
    if label:
        html_bits.append(f"<p><em>{escape_html(label)}</em></p>")
    if title_line:
        t_html = escape_html(title) if title else ""
        prefix = escape_html(" ".join(heading_bits) + " ") if heading_bits else ""
        html_bits.append(f"<p><strong>{prefix}{t_html}</strong></p>")
    for d in descs_html:
        html_bits.append(f"<p>{d}</p>")

    blocks.append({"type": "raw", "md": md_text, "html": "\n".join(html_bits)})

    if sublist_tag is not None:
        blocks.append(render_list(sublist_tag, base_url))

    if footer:
        blocks.append({"type": "raw", "md": f"*{footer}*", "html": f"<p><em>{escape_html(footer)}</em></p>"})

    # Anything left over (nested exotic structure) - flatten and append.
    leftover = [c for c in children if id(c) not in consumed]
    for c in leftover:
        walk_blocks(c, blocks, base_url, img_ctx)

    return blocks


def render_link_card(tag, base_url):
    """A whole-card <a class="link-card"> wrapping icon/label/title/desc divs -
    render as a bold linked title with the label/description beneath it."""
    href = urljoin(base_url, tag.get("href") or "")
    icon = label = title = desc = None
    leaves = [c for c in tag.find_all(True) if not c.find(True)]
    for c in leaves:
        if class_contains(c, "icon") or class_contains(c, "emoji"):
            icon = icon or inline_text(c)
        elif class_contains(c, "title"):
            title = title or inline_text(c)
        elif class_contains(c, "label"):
            label = label or inline_text(c)
        elif class_contains(c, "desc") or class_contains(c, "text"):
            t = inline_text(c)
            if t and t != title:
                desc = desc or t
    title = title or inline_text(tag)
    bits = [b for b in (icon, label) if b]
    prefix = (" ".join(bits) + " ") if bits else ""
    md = f"**{prefix}[{title}]({href})**"
    html = f'<p><strong>{escape_html(prefix)}<a href="{href}">{escape_html(title)}</a></strong></p>'
    if desc:
        md += f"\n{desc}"
        html += f"<p>{escape_html(desc)}</p>"
    return {"type": "raw", "md": md, "html": html}


def render_list(tag, base_url, ordered=None):
    if ordered is None:
        ordered = tag.name == "ol"
    items = []
    for li in tag.find_all("li", recursive=False):
        nested = li.find(["ul", "ol"], recursive=False)
        md_parts = []
        html_parts = []
        for c in li.children:
            if isinstance(c, Tag) and c.name in ("ul", "ol"):
                continue
            md_parts.append(inline_md(c, base_url))
            html_parts.append(inline_html(c, base_url))
        text_md = norm_ws("".join(md_parts))
        text_html = "".join(html_parts).strip()
        sub = render_list(nested, base_url) if nested is not None else None
        items.append((text_md, text_html, sub))
    return {"type": "list", "ordered": ordered, "items": items}


def render_table(tag, base_url):
    headers_md, headers_html = [], []
    thead = tag.find("thead")
    if thead:
        for th in thead.find_all(["th", "td"]):
            headers_md.append(block_text_md(th, base_url))
            headers_html.append(inline_html_children(th, base_url))
    rows_md, rows_html = [], []
    tbody = tag.find("tbody") or tag
    for tr in tbody.find_all("tr", recursive=(tbody is tag)):
        if thead and tr in thead.find_all("tr"):
            continue
        cells = tr.find_all(["td", "th"], recursive=False)
        md_cells = [block_text_md(td, base_url) for td in cells]
        html_cells = [inline_html_children(td, base_url) for td in cells]
        if md_cells:
            rows_md.append(md_cells)
            rows_html.append(html_cells)
    if not headers_md and rows_md:
        headers_md, rows_md = rows_md[0], rows_md[1:]
        headers_html, rows_html = rows_html[0], rows_html[1:]
    return {"type": "table", "headers": headers_md, "rows": rows_md,
            "headers_html": headers_html, "rows_html": rows_html}


def render_code(tag, base_url):
    code_tag = tag.find("code")
    text = (code_tag or tag).get_text()
    text = text.strip("\n")
    lang = ""
    src = code_tag or tag
    for c in classes_of(src):
        if c.startswith("language-"):
            lang = c[len("language-"):]
    return {"type": "code", "text": text, "lang": lang}


def render_callout(tag, base_url):
    label = None
    icon = None
    paras_md = []
    paras_html = []
    for c in tag.find_all(True, recursive=False):
        if class_contains(c, "callout-label"):
            label = inline_text(c)
        elif class_contains(c, "callout-icon"):
            icon = inline_text(c)
        elif c.name == "p" or class_contains(c, "text"):
            t = block_text_md(c, base_url)
            if t:
                paras_md.append(t)
                paras_html.append(inline_html_children(c, base_url))
    variant = "note"
    for v in ("warn", "danger", "ok", "info"):
        if class_contains(tag, v):
            variant = v
            break
    # The renderer already prefixes a variant icon, so only carry the text label here.
    prefix = f"{label}: " if label else ""
    body_md = " ".join(paras_md) if paras_md else inline_text(tag)
    body_html = " ".join(paras_html) if paras_html else escape_html(inline_text(tag))
    return {"type": "callout", "variant": variant, "prefix": prefix, "text": body_md, "html_text": body_html}


DATA_URI_RE = re.compile(r"^data:image/([a-zA-Z0-9.+-]+);base64,(.*)$", re.S)


def save_data_uri_image(data_uri, img_ctx):
    """Decode an embedded base64 screenshot and save it as a real file in the
    shared article-archive/images/<series>/<slug>/ folder, returning the
    relative path to use from the markdown/medium output files."""
    if img_ctx is None:
        return None
    m = DATA_URI_RE.match(data_uri)
    if not m:
        return None
    ext = m.group(1).split("+")[0].lower()
    ext = {"jpeg": "jpg"}.get(ext, ext)
    try:
        raw = base64.b64decode(m.group(2))
    except Exception:
        return None
    img_ctx["counter"] += 1
    fname = f'{img_ctx["slug"]}-{img_ctx["counter"]:02d}.{ext}'
    os.makedirs(img_ctx["save_dir"], exist_ok=True)
    with open(os.path.join(img_ctx["save_dir"], fname), "wb") as fh:
        fh.write(raw)
    return img_ctx["rel_prefix"] + fname


def render_figure_or_image(tag, base_url, img_ctx=None):
    img = tag if tag.name == "img" else tag.find("img")
    if img is None:
        return None
    src = img.get("src") or ""
    if src.startswith("data:"):
        src = save_data_uri_image(src, img_ctx) or ""
    else:
        src = urljoin(base_url, src)
    alt = img.get("alt") or ""
    caption = ""
    cap_tag = tag.find("figcaption") if tag.name == "figure" else None
    if cap_tag is None:
        sib = tag.find_next_sibling(True)
        if sib is not None and class_contains(sib, "caption"):
            cap_tag = sib
    if cap_tag is not None:
        caption = inline_text(cap_tag)
    return {"type": "image", "src": src, "alt": alt, "caption": caption}


def walk_blocks(node, blocks, base_url, img_ctx=None):
    buffer = []  # loose inline nodes (text + stray inline tags) awaiting a paragraph flush

    def flush_buffer():
        if not buffer:
            return
        md_text = norm_ws("".join(inline_md(n, base_url) for n in buffer))
        html_text = "".join(inline_html(n, base_url) for n in buffer).strip()
        buffer.clear()
        if md_text:
            blocks.append({"type": "para", "md": md_text, "html": f"<p>{html_text}</p>"})

    for child in node.children:
        if isinstance(child, Comment):
            continue
        if isinstance(child, NavigableString):
            buffer.append(child)
            continue
        if not isinstance(child, Tag):
            continue
        if should_skip(child):
            continue
        name = child.name

        if name == "br":
            flush_buffer()
            continue

        if name == "a" and class_contains(child, "link-card"):
            flush_buffer()
            blocks.append(render_link_card(child, base_url))
            continue

        if name in INLINE_UNWRAP:
            # Loose inline content (stray <strong>/<code>/<a>/... directly under a
            # block container) - buffer it so it merges into one paragraph with
            # its surrounding text instead of becoming its own isolated block.
            buffer.append(child)
            continue

        # Any other tag is block-level: flush whatever loose text came before it.
        flush_buffer()

        if name in ("h2", "h3", "h4", "h5", "h6"):
            level = int(name[1])
            text_md = block_text_md(child, base_url)
            if text_md:
                blocks.append({"type": "heading", "level": level, "md": text_md,
                                "html": inline_html_children(child, base_url)})
            continue

        if name == "p":
            text_md = block_text_md(child, base_url)
            if text_md:
                blocks.append({"type": "para", "md": text_md,
                                "html": f"<p>{inline_html_children(child, base_url)}</p>"})
            continue

        if name in ("ul", "ol"):
            blocks.append(render_list(child, base_url))
            continue

        if name == "table":
            blocks.append(render_table(child, base_url))
            continue

        if name == "pre":
            blocks.append(render_code(child, base_url))
            continue

        if name == "blockquote":
            text_md = block_text_md(child, base_url) or inline_text(child)
            blocks.append({"type": "quote", "md": text_md})
            continue

        if name == "hr":
            blocks.append({"type": "hr"})
            continue

        if name == "figure":
            img_block = render_figure_or_image(child, base_url, img_ctx)
            if img_block:
                blocks.append(img_block)
            continue

        if name == "img":
            img_block = render_figure_or_image(child, base_url, img_ctx)
            if img_block:
                blocks.append(img_block)
            continue

        if name in ("div", "section", "article"):
            heading_text = numbered_heading_text(child)
            if heading_text:
                blocks.append({"type": "heading", "level": 2, "md": heading_text,
                                "html": escape_html(heading_text)})
                continue
            if class_contains(child, "callout"):
                blocks.append(render_callout(child, base_url))
                continue
            if class_contains(child, "pull-quote") or class_contains(child, "pull_quote"):
                text_md = inline_text(child)
                blocks.append({"type": "quote", "md": text_md})
                continue
            if class_contains(child, "code-block") and child.find("pre"):
                blocks.append(render_code(child.find("pre"), base_url))
                continue
            if child.find("img") and (class_contains(child, "screenshot") or class_contains(child, "img-block") or class_contains(child, "figure")):
                img_block = render_figure_or_image(child, base_url, img_ctx)
                if img_block:
                    blocks.append(img_block)
                    continue
            if is_leaf_card_component(child):
                blocks.extend(render_card(child, base_url, img_ctx))
                continue
            # generic container: recurse, preserving order
            walk_blocks(child, blocks, base_url, img_ctx)
            continue

        # Unknown tag - recurse to avoid losing content.
        walk_blocks(child, blocks, base_url, img_ctx)

    flush_buffer()


def inline_html_children(tag, base_url):
    return "".join(inline_html(c, base_url) for c in tag.children).strip()


# ---------------------------------------------------------------------------
# Rendering blocks -> markdown / html strings
# ---------------------------------------------------------------------------

def render_blocks_markdown(blocks):
    out = []
    for b in blocks:
        t = b["type"]
        if t in ("para", "raw"):
            if b.get("md"):
                out.append(b["md"])
        elif t == "heading":
            out.append(f"{'#' * b['level']} {b['md']}")
        elif t == "quote":
            quoted = "\n".join(f"> {line}" for line in b["md"].splitlines()) or f"> {b['md']}"
            out.append(quoted)
        elif t == "callout":
            label = b["prefix"]
            icon = {"warn": "⚠️", "danger": "🛑", "ok": "✅", "info": "ℹ️", "note": "ℹ️"}.get(b["variant"], "ℹ️")
            text = f"> {icon} **{label.strip(': ') or b['variant'].upper()}:** {b['text']}" if label else f"> {icon} {b['text']}"
            out.append(text)
        elif t == "code":
            lang = b.get("lang", "")
            out.append(f"```{lang}\n{b['text']}\n```")
        elif t == "hr":
            out.append("---")
        elif t == "image":
            cap = f"\n*{b['caption']}*" if b["caption"] else ""
            if b["src"]:
                out.append(f"![{b['alt']}]({b['src']}){cap}")
            elif cap:
                out.append(cap.strip())
        elif t == "list":
            out.append(render_list_markdown(b))
        elif t == "table":
            out.append(render_table_markdown(b))
    return "\n\n".join([o for o in out if o and o.strip()])


def render_list_markdown(block, indent=0):
    lines = []
    pad = "  " * indent
    for i, (text_md, text_html, sub) in enumerate(block["items"]):
        marker = f"{i + 1}." if block["ordered"] else "-"
        lines.append(f"{pad}{marker} {text_md}")
        if sub:
            lines.append(render_list_markdown(sub, indent + 1))
    return "\n".join(lines)


def render_table_markdown(block):
    headers = block["headers"] or [""] * (len(block["rows"][0]) if block["rows"] else 1)
    lines = ["| " + " | ".join(headers) + " |",
              "| " + " | ".join(["---"] * len(headers)) + " |"]
    for row in block["rows"]:
        row = row + [""] * (len(headers) - len(row))
        lines.append("| " + " | ".join(row[:len(headers)]) + " |")
    return "\n".join(lines)


def render_blocks_html(blocks):
    out = []
    for b in blocks:
        t = b["type"]
        if t in ("para", "raw"):
            if b.get("html"):
                out.append(b["html"])
        elif t == "heading":
            level = min(max(b["level"], 2), 3)  # Medium only really supports H1/H2 (our H2/H3)
            out.append(f"<h{level}>{b['html']}</h{level}>")
        elif t == "quote":
            out.append(f"<blockquote><p>{escape_html(b['md'])}</p></blockquote>")
        elif t == "callout":
            label = b["prefix"]
            icon = {"warn": "⚠️", "danger": "🛑", "ok": "✅", "info": "ℹ️", "note": "ℹ️"}.get(b["variant"], "ℹ️")
            strong = escape_html(label.strip(': ') or b["variant"].upper())
            out.append(f"<blockquote><p>{icon} <strong>{strong}:</strong> {b.get('html_text') or escape_html(b['text'])}</p></blockquote>")
        elif t == "code":
            out.append(f"<pre><code>{escape_html(b['text'])}</code></pre>")
        elif t == "hr":
            out.append("<hr>")
        elif t == "image":
            if b["src"]:
                out.append(f'<img src="{b["src"]}" alt="{escape_html(b["alt"])}">')
            if b["caption"]:
                out.append(f"<p><em>{escape_html(b['caption'])}</em></p>")
        elif t == "list":
            out.append(render_list_html(b))
        elif t == "table":
            out.append(render_table_html(b))
    return "\n".join([o for o in out if o and o.strip()])


def render_list_html(block):
    tag = "ol" if block["ordered"] else "ul"
    items = []
    for text_md, text_html, sub in block["items"]:
        inner = text_html
        if sub:
            inner += render_list_html(sub)
        items.append(f"<li>{inner}</li>")
    return f"<{tag}>" + "".join(items) + f"</{tag}>"


def render_table_html(block):
    headers = block["headers_html"] or [""] * (len(block["rows_html"][0]) if block["rows_html"] else 1)
    head = "<tr>" + "".join(f"<th>{h}</th>" for h in headers) + "</tr>"
    rows = ""
    for row in block["rows_html"]:
        row = row + [""] * (len(headers) - len(row))
        rows += "<tr>" + "".join(f"<td>{c}</td>" for c in row[:len(headers)]) + "</tr>"
    return f"<table><thead>{head}</thead><tbody>{rows}</tbody></table>"


# ---------------------------------------------------------------------------
# Per-document extraction
# ---------------------------------------------------------------------------

def extract_meta(soup, rel_path):
    def meta(name=None, prop=None):
        if name:
            tag = soup.find("meta", attrs={"name": name})
        else:
            tag = soup.find("meta", attrs={"property": prop})
        return tag.get("content").strip() if tag and tag.get("content") else ""

    title = soup.title.get_text().strip() if soup.title else ""
    title = re.sub(r"\s*—\s*conditionalaccess\.tech\s*$", "", title)
    description = meta(name="description")
    published = meta(prop="article:published_time")
    canonical_tag = soup.find("link", rel="canonical")
    canonical = canonical_tag.get("href") if canonical_tag else urljoin(SITE_BASE, rel_path)
    og_image = meta(prop="og:image")
    return {
        "title": title,
        "description": description,
        "published": published,
        "canonical": canonical,
        "og_image": og_image,
    }


def extract_hero(soup):
    hero = soup.find(class_=lambda c: c and "hero" in c and (c == "hero" or c.split()[0] == "hero"))
    # fall back: first element literally with class "hero"
    if hero is None:
        hero = soup.find(attrs={"class": "hero"})
    if hero is None:
        for cand in soup.find_all(["section", "div"]):
            if "hero" in classes_of(cand):
                hero = cand
                break
    eyebrow = title = None
    subs = []
    meta_items = []
    if hero:
        for c in hero.find_all(True, recursive=False):
            if class_contains(c, "eyebrow") or class_contains(c, "hero-label"):
                eyebrow = inline_text(c)
            elif c.name == "h1":
                title = inline_text(c)
            elif class_contains(c, "hero-sub") or class_contains(c, "subtitle"):
                t = inline_text(c)
                if t:
                    subs.append(t)
            elif class_contains(c, "hero-meta"):
                meta_items = [inline_text(s) for s in c.find_all(True) if inline_text(s)]
                if not meta_items:
                    t = inline_text(c)
                    if t:
                        meta_items = [t]
    return {"eyebrow": eyebrow, "title": title, "subs": subs, "meta_items": meta_items}


def find_content_root(soup):
    for sel in [("main", {"class": "content"}), ("main", {"class": "content-wrap"})]:
        tag = soup.find(sel[0], **({"attrs": sel[1]} if False else {}))
    main = soup.find("main", class_="content") or soup.find("main", class_="content-wrap") or soup.find("main")
    if main:
        return main
    article = soup.find("article")
    if article:
        return article
    page_body = soup.find("div", class_="page-body")
    if page_body:
        return page_body
    return soup.body


def convert_one(src_path, series):
    rel_path = src_path
    base_url = urljoin(SITE_BASE, os.path.dirname(rel_path) + "/")
    full_path = os.path.join(REPO_ROOT, src_path)
    with open(full_path, encoding="utf-8") as f:
        soup = BeautifulSoup(f.read(), "lxml")

    meta = extract_meta(soup, rel_path)
    hero = extract_hero(soup)
    root = find_content_root(soup)

    slug = os.path.splitext(os.path.basename(src_path))[0]
    img_ctx = {
        "slug": slug,
        "counter": 0,
        "save_dir": os.path.join(REPO_ROOT, "article-archive", "images", series, slug),
        "rel_prefix": f"../../images/{series}/{slug}/",
    }

    blocks = []
    if root is not None:
        walk_blocks(root, blocks, base_url, img_ctx)

    return {
        "slug": slug,
        "series": series,
        "meta": meta,
        "hero": hero,
        "blocks": blocks,
    }


def render_markdown(doc):
    meta = doc["meta"]
    hero = doc["hero"]
    fm = [
        "---",
        f'title: "{(hero["title"] or meta["title"] or "").replace(chr(34), chr(39))}"',
        f'description: "{meta["description"].replace(chr(34), chr(39))}"',
        f'series: "{doc["series"]}"',
        f'published: "{meta["published"]}"',
        f'canonical_url: "{meta["canonical"]}"',
        f'source: "catech-branded/{doc["series"]}/{doc["slug"]}.html"',
        "---",
        "",
    ]
    body = [f'# {hero["title"] or meta["title"]}', ""]
    if hero["eyebrow"]:
        body.append(f'*{hero["eyebrow"]}*')
        body.append("")
    for s in hero["subs"]:
        body.append(s)
        body.append("")
    if hero["meta_items"]:
        body.append(" · ".join(hero["meta_items"]))
        body.append("")
    body.append(render_blocks_markdown(doc["blocks"]))
    return "\n".join(fm) + "\n".join(body).rstrip() + "\n"


def render_medium_html(doc):
    meta = doc["meta"]
    hero = doc["hero"]
    title = hero["title"] or meta["title"]
    parts = [
        "<!DOCTYPE html>",
        '<html lang="en">',
        "<head>",
        '<meta charset="UTF-8">',
        f"<title>{escape_html(title)}</title>",
        "</head>",
        "<body>",
        f"<h1>{escape_html(title)}</h1>",
    ]
    if hero["eyebrow"]:
        parts.append(f"<p><em>{escape_html(hero['eyebrow'])}</em></p>")
    for s in hero["subs"]:
        parts.append(f"<p>{escape_html(s)}</p>")
    if hero["meta_items"]:
        parts.append(f"<p><em>{escape_html(' · '.join(hero['meta_items']))}</em></p>")
    parts.append(f'<p><em>Originally published at <a href="{meta["canonical"]}">conditionalaccess.tech</a></em></p>')
    parts.append("<hr>")
    parts.append(render_blocks_html(doc["blocks"]))
    parts.append("</body></html>")
    return "\n".join(parts) + "\n"


def main():
    images_root = os.path.join(REPO_ROOT, "article-archive", "images")
    if os.path.isdir(images_root):
        import shutil
        shutil.rmtree(images_root)

    manifest_rows = []
    for src_path, series in SOURCES:
        doc = convert_one(src_path, series)
        md = render_markdown(doc)
        html = render_medium_html(doc)

        md_path = os.path.join(REPO_ROOT, "article-archive", "markdown", series, f'{doc["slug"]}.md')
        html_path = os.path.join(REPO_ROOT, "article-archive", "medium", series, f'{doc["slug"]}.html')
        with open(md_path, "w", encoding="utf-8") as f:
            f.write(md)
        with open(html_path, "w", encoding="utf-8") as f:
            f.write(html)

        word_count = len(re.findall(r"\w+", render_blocks_markdown(doc["blocks"])))
        manifest_rows.append((doc["series"], doc["slug"], doc["meta"]["title"] or doc["hero"]["title"], word_count))
        print(f'OK  {series:20s} {doc["slug"]:45s} words={word_count}')

    return manifest_rows


if __name__ == "__main__":
    main()
