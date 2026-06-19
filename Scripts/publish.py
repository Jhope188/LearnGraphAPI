#!/usr/bin/env python3
"""
publish.py — Article publish orchestrator for conditionalaccess.tech

Interactive mode:     python3 scripts/publish.py
Config-driven mode:   python3 scripts/publish.py --config .publish-config.json

Config JSON schema (used by Copilot agent):
{
  "title":        "My Article Title",
  "series":       "identity",           // identity | governance | conditional-access | msp
  "series_label": "Identity Series · PT06",
  "filename":     "my-article.html",
  "date":         "2026-06-23",         // ISO format, defaults to today
  "description":  "One sentence summary.",
  "is_coming_soon": true,               // false = brand-new card, not yet in index
  "push":         true,                 // false = local only, no git push
  "entra_news": null                    // null = not featured, or:
  // "entra_news": {
  //   "issue":     "155",
  //   "date":      "Jun 21, 2026",
  //   "url":       "https://entra.news/p/entra-news-155-this-week-in-microsoft",
  //   "badge":     "auth",             // ca | pop | sec | auth | tenant | dev
  //   "new_issue": true                // false if this issue was already counted
  // }
}

Files updated:
  articles/index.html    — latest-banner, tab count, card activation/insertion
  index.html             — featured resource-card on homepage
  feed.xml               — new RSS <item> prepended
  entra-news.html        — feature-row + stat counts  (Entra News only)
  index.html             — entra-news-badge counts    (Entra News only)
  entra.news/readme.md   — At a Glance table + article catalogue (Entra News only)
"""

import json
import re
import subprocess
import sys
from datetime import date, datetime
from pathlib import Path

ROOT       = Path(__file__).resolve().parent.parent
ARTICLES   = ROOT / "articles" / "index.html"
INDEX      = ROOT / "index.html"
FEED       = ROOT / "feed.xml"
ENTRA_HTML = ROOT / "entra-news.html"
ENTRA_MD   = ROOT / "entra.news" / "readme.md"
BASE_URL   = "https://conditionalaccess.tech"

TAB_LABELS = {
    "identity":           "Identity Security",
    "governance":         "Governance",
    "conditional-access": "Conditional Access",
    "msp":                "MSP",
}
BADGE_LABELS = {
    "ca":     "Conditional Access",
    "pop":    "Most Popular",
    "sec":    "Security",
    "auth":   "Authentication",
    "tenant": "Tenant",
    "dev":    "Dev",
}
BADGE_CLASSES = {
    "ca":     "section-ca",
    "pop":    "section-pop",
    "sec":    "section-sec",
    "auth":   "section-auth",
    "tenant": "section-tenant",
    "dev":    "section-dev",
}


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def ask(prompt, default=None):
    suffix = f" [{default}]" if default is not None else ""
    value  = input(f"  {prompt}{suffix}: ").strip()
    return value if value else default

def ask_bool(prompt, default=False):
    suffix = " [Y/n]" if default else " [y/N]"
    value  = input(f"  {prompt}{suffix}: ").strip().lower()
    if not value:
        return default
    return value in ("y", "yes")

def fmt_rfc822(d: date) -> str:
    return datetime(d.year, d.month, d.day).strftime("%a, %d %b %Y 00:00:00 +0000")

def fmt_display(d: date) -> str:
    """Returns e.g. 'Jun 23, 2026'"""
    return d.strftime("%b %-d, %Y")

def strip_tags(text: str) -> str:
    return re.sub(r"<[^>]+>", "", text).strip()


# ─────────────────────────────────────────────────────────────────────────────
# 1. Gather article metadata
# ─────────────────────────────────────────────────────────────────────────────

def gather_interactive() -> dict:
    print()
    print("╔══════════════════════════════════════════════╗")
    print("║   conditionalaccess.tech — Publish Article   ║")
    print("╚══════════════════════════════════════════════╝")
    print()

    today = date.today()
    cfg = {}
    cfg["title"]        = ask("Article title")
    cfg["series"]       = ask("Tab section (identity / governance / conditional-access / msp)", "identity")
    cfg["series_label"] = ask("Series label  (e.g. Identity Series · PT06)", "")
    cfg["filename"]     = ask("HTML filename  (e.g. my-article.html)")
    cfg["date"]         = ask("Publish date  (YYYY-MM-DD)", str(today))
    cfg["description"]  = ask("Short description (one sentence)")
    cfg["is_coming_soon"] = ask_bool("Is this converting a coming-soon card?", default=True)
    cfg["push"]         = ask_bool("Push to GitHub after update?", default=True)

    print()
    featured = ask_bool("Featured in Entra News?", default=False)
    if featured:
        print()
        issue_num  = ask("Issue number (e.g. 155)")
        issue_date = ask("Issue date   (e.g. Jun 21, 2026)")
        issue_url  = ask(
            "Issue URL",
            f"https://entra.news/p/entra-news-{issue_num}-this-week-in-microsoft"
        )
        print("  Badge type: ca | pop | sec | auth | tenant | dev")
        badge_key  = ask("Badge type", "auth")
        new_issue  = ask_bool("Is this a brand-new issue (not already counted)?", default=True)
        cfg["entra_news"] = {
            "issue":     issue_num,
            "date":      issue_date,
            "url":       issue_url,
            "badge":     badge_key,
            "new_issue": new_issue,
        }
    else:
        cfg["entra_news"] = None

    return cfg


def load_config(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


# ─────────────────────────────────────────────────────────────────────────────
# 2. Update articles/index.html
# ─────────────────────────────────────────────────────────────────────────────

def update_articles_index(cfg: dict):
    series      = cfg["series"]
    filename    = cfg["filename"]
    title       = cfg["title"]
    description = cfg["description"]
    series_lbl  = cfg["series_label"]
    display_date = cfg["display_date"]
    tab_label   = TAB_LABELS.get(series, series.title())

    html = ARTICLES.read_text(encoding="utf-8")

    # ── 2a. Update latest-banner ──────────────────────────────────────────────
    new_inner = (
        f'\n    <span class="latest-card-arrow">↗</span>\n'
        f'    <div class="latest-card-series">{series_lbl}</div>\n'
        f'    <h2>{title}</h2>\n'
        f'    <p>{description}</p>\n'
        f'    <div class="latest-card-meta">\n'
        f'      <span>{tab_label}</span>\n'
        f'      <span>{display_date}</span>\n'
        f'    </div>\n'
        f'  '
    )

    def replace_latest_href(m):
        open_a  = re.sub(r'href="[^"]*"', f'href="{series}/{filename}"', m.group(1))
        return open_a + new_inner + m.group(3)

    html = re.sub(
        r'(<a [^>]*?id="latest-article-card"[^>]*>)'
        r'(.*?)'
        r'(</a>)',
        replace_latest_href,
        html, count=1, flags=re.DOTALL
    )

    # ── 2b. Increment tab count ───────────────────────────────────────────────
    def inc_count(m):
        return m.group(1) + str(int(m.group(2)) + 1) + m.group(3)

    html = re.sub(
        r'(data-tab="' + re.escape(series) + r'"[^>]*>.*?'
        r'<span class="tab-count">)(\d+)(</span>)',
        inc_count,
        html, count=1, flags=re.DOTALL
    )

    # ── 2c. Activate coming-soon OR insert new card ───────────────────────────
    if cfg["is_coming_soon"]:
        cs_pat = re.compile(
            r'<div class="article-card coming-soon"'
            r'\s+data-series="' + re.escape(series) + r'"'
            r'\s+data-file="'   + re.escape(filename) + r'"'
            r'>(.*?)</div>',
            re.DOTALL
        )
        html = cs_pat.sub(
            lambda m: f'<a href="{series}/{filename}" class="article-card">{m.group(1)}</a>',
            html, count=1
        )
    else:
        new_card = (
            f'\n      <a href="{series}/{filename}" class="article-card">\n'
            f'        <div class="article-type">{series_lbl}</div>\n'
            f'        <h3>{title}</h3>\n'
            f'        <p>{description}</p>\n'
            f'        <div class="article-card-footer"><span>{display_date}</span></div>\n'
            f'      </a>'
        )
        html = re.sub(
            r'(id="panel-' + re.escape(series) + r'"[^>]*>.*?<div class="article-grid">)',
            lambda m: m.group(0) + new_card,
            html, count=1, flags=re.DOTALL
        )

    ARTICLES.write_text(html, encoding="utf-8")
    print("  ✅ articles/index.html — latest-banner, tab count, article card")


# ─────────────────────────────────────────────────────────────────────────────
# 3. Update index.html featured resource-card
# ─────────────────────────────────────────────────────────────────────────────

def update_homepage(cfg: dict):
    series      = cfg["series"]
    filename    = cfg["filename"]
    title       = cfg["title"]
    description = cfg["description"]
    tab_label   = TAB_LABELS.get(series, series.title())
    article_url = f"{BASE_URL}/articles/{series}/{filename}"

    idx = INDEX.read_text(encoding="utf-8")

    # Replace the first article resource-card in the writing section
    idx = re.sub(
        r'<a href="https://conditionalaccess\.tech/articles/[^"]*" class="resource-card">'
        r'\s*<span class="resource-type">[^<]*</span>'
        r'\s*<h3>[^<]*</h3>'
        r'\s*<p>[^<]*</p>'
        r'\s*<span class="resource-arrow">[^<]*</span>'
        r'\s*</a>',
        (
            f'<a href="{article_url}" class="resource-card">\n'
            f'          <span class="resource-type">{tab_label}</span>\n'
            f'          <h3>{title}</h3>\n'
            f'          <p>{description}</p>\n'
            f'          <span class="resource-arrow">&#x2197;</span>\n'
            f'        </a>'
        ),
        idx, count=1, flags=re.DOTALL
    )

    INDEX.write_text(idx, encoding="utf-8")
    print("  ✅ index.html — featured resource-card")


# ─────────────────────────────────────────────────────────────────────────────
# 4. Update feed.xml
# ─────────────────────────────────────────────────────────────────────────────

def update_feed(cfg: dict):
    series      = cfg["series"]
    filename    = cfg["filename"]
    title       = cfg["title"]
    description = cfg["description"]
    pub_date    = cfg["pub_date"]
    tab_label   = TAB_LABELS.get(series, series.title())
    article_url = f"{BASE_URL}/articles/{series}/{filename}"
    pub_rfc     = fmt_rfc822(pub_date)

    feed = FEED.read_text(encoding="utf-8")
    new_item = (
        f"\n    <item>\n"
        f"      <title>{title}</title>\n"
        f"      <link>{article_url}</link>\n"
        f"      <description>{description}</description>\n"
        f"      <pubDate>{pub_rfc}</pubDate>\n"
        f"      <guid isPermaLink=\"true\">{article_url}</guid>\n"
        f"      <category>{tab_label}</category>\n"
        f"    </item>\n"
    )
    feed = re.sub(
        r"<lastBuildDate>.*?</lastBuildDate>",
        f"<lastBuildDate>{pub_rfc}</lastBuildDate>",
        feed, count=1
    )
    feed = feed.replace("</lastBuildDate>", f"</lastBuildDate>{new_item}", 1)

    FEED.write_text(feed, encoding="utf-8")
    print("  ✅ feed.xml — new RSS item prepended")


# ─────────────────────────────────────────────────────────────────────────────
# 5. Entra News updates
# ─────────────────────────────────────────────────────────────────────────────

def update_entra_news(cfg: dict):
    en_cfg = cfg["entra_news"]
    title  = cfg["title"]

    issue_num   = en_cfg["issue"]
    issue_date  = en_cfg["date"]
    issue_url   = en_cfg["url"]
    badge_key   = en_cfg["badge"]
    new_issue   = en_cfg["new_issue"]
    badge_class = BADGE_CLASSES.get(badge_key, "section-auth")
    badge_label = BADGE_LABELS.get(badge_key, "Authentication")

    # ── 5a. entra-news.html ───────────────────────────────────────────────────
    en = ENTRA_HTML.read_text(encoding="utf-8")

    # Parse current counts
    feat_m  = re.search(
        r'<span class="stat-val"><span class="teal">(\d+)</span></span>'
        r'\s*<span class="stat-label">Features</span>', en)
    issue_m = re.search(
        r'<span class="stat-val"><span class="teal">(\d+)</span></span>'
        r'\s*<span class="stat-label">Issues</span>', en)
    old_feat  = int(feat_m.group(1))  if feat_m  else 21
    old_issue = int(issue_m.group(1)) if issue_m else 19
    new_feat  = old_feat  + 1
    new_issue_count = old_issue + (1 if new_issue else 0)

    # Prepend new feature-row to grid
    new_row = (
        f'\n          <a href="{issue_url}" target="_blank" class="feature-row">\n'
        f'            <div>\n'
        f'              <div class="feature-issue">#{issue_num}</div>\n'
        f'              <div class="feature-issue-date">{issue_date}</div>\n'
        f'            </div>\n'
        f'            <div class="feature-title">{title}</div>\n'
        f'            <span class="feature-section-badge {badge_class}">{badge_label}</span>\n'
        f'          </a>\n'
    )
    en = en.replace('<div class="feature-grid">', f'<div class="feature-grid">{new_row}', 1)

    # Update stat-val: Features
    en = re.sub(
        r'(<span class="stat-val"><span class="teal">)\d+(</span></span>\s*'
        r'<span class="stat-label">Features</span>)',
        lambda m: m.group(1) + str(new_feat) + m.group(2),
        en, count=1
    )
    # Update stat-val: Issues
    en = re.sub(
        r'(<span class="stat-val"><span class="teal">)\d+(</span></span>\s*'
        r'<span class="stat-label">Issues</span>)',
        lambda m: m.group(1) + str(new_issue_count) + m.group(2),
        en, count=1
    )
    # Update meta description
    en = re.sub(
        r'(\d+) features across (\d+) issues',
        f'{new_feat} features across {new_issue_count} issues',
        en, count=1
    )
    en = re.sub(
        r'Archive snapshot refreshed through Entra\.News #\d+ \([^)]+\)\.',
        f'Archive snapshot refreshed through Entra.News #{issue_num} ({issue_date}).',
        en, count=1
    )
    ENTRA_HTML.write_text(en, encoding="utf-8")
    print(f"  ✅ entra-news.html — #{issue_num} row added, features {old_feat}→{new_feat}, issues {old_issue}→{new_issue_count}")

    # ── 5b. index.html entra-news-badge ──────────────────────────────────────
    idx = INDEX.read_text(encoding="utf-8")
    idx = re.sub(
        r'\d+ features &bull; \d+ issues',
        f'{new_feat} features &bull; {new_issue_count} issues',
        idx, count=1
    )
    INDEX.write_text(idx, encoding="utf-8")
    print(f"  ✅ index.html — Entra News badge → {new_feat} features · {new_issue_count} issues")

    # ── 5c. entra.news/readme.md ──────────────────────────────────────────────
    md = ENTRA_MD.read_text(encoding="utf-8")

    # At a Glance
    md = re.sub(
        r'\| Entra News Features \| \d+ \(across \d+ issues\) \|',
        f'| Entra News Features | {new_feat} (across {new_issue_count} issues) |',
        md, count=1
    )
    md = re.sub(
        r'Last Updated: .+',
        f'Last Updated: {fmt_display(cfg["pub_date"])}',
        md, count=1
    )
    # Next article number
    nums     = re.findall(r'^\| (\d+) \|', md, re.MULTILINE)
    next_num = max(int(n) for n in nums) + 1 if nums else 39
    new_row_md = (
        f'| {next_num} | {title} | '
        f'{fmt_display(cfg["pub_date"])[:6].rstrip(",")} | — | — | ✅ #{issue_num} |\n'
    )
    # Insert after header separator
    md = re.sub(
        r'(\| # \| Title \| Published \| Responses \| Saves \| Entra News \|\n'
        r'\|[-|]+\|\n)',
        lambda m: m.group(0) + new_row_md,
        md, count=1
    )
    # Archive snapshot note
    md = re.sub(
        r'Current public archive snapshot: Entra News #\d+ \([^)]+\)\.',
        f'Current public archive snapshot: Entra News #{issue_num} ({issue_date}).',
        md, count=1
    )
    md = re.sub(
        r'Current Entra News archive snapshot:.*?\n',
        f'Current Entra News archive snapshot: the latest weekly issue visible in the public archive is Entra News #{issue_num} (published {issue_date}). This page reflects that latest weekly release in the site metadata and archive notes.\n',
        md, count=1
    )
    ENTRA_MD.write_text(md, encoding="utf-8")
    print("  ✅ entra.news/readme.md — At a Glance + article catalogue updated")


# ─────────────────────────────────────────────────────────────────────────────
# 6. Git commit + push
# ─────────────────────────────────────────────────────────────────────────────

def git_push(cfg: dict):
    series   = cfg["series"]
    filename = cfg["filename"]
    title    = cfg["title"]
    en_cfg   = cfg.get("entra_news")

    files = [
        "articles/index.html",
        "index.html",
        "feed.xml",
    ]
    if en_cfg:
        files += ["entra-news.html", "entra.news/readme.md"]
    # Include the article HTML if present in repo
    article_path = ROOT / "articles" / series / filename
    if article_path.exists():
        files.append(f"articles/{series}/{filename}")

    subprocess.run(["git", "add"] + files, cwd=ROOT, check=True)

    msg = f"publish: {title}"
    if en_cfg:
        msg += f" (Entra.News #{en_cfg['issue']})"
    subprocess.run(["git", "commit", "-m", msg], cwd=ROOT, check=True)
    subprocess.run(["git", "push", "origin", "main"], cwd=ROOT, check=True)
    print(f"\n  🚀 Pushed to GitHub — live at: {BASE_URL}/articles/{series}/{filename}")


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    # Load config from file or gather interactively
    if "--config" in sys.argv:
        idx = sys.argv.index("--config")
        config_path = sys.argv[idx + 1]
        cfg = load_config(config_path)
        print(f"\n📋 Config loaded from {config_path}")
    else:
        cfg = gather_interactive()

    # Normalise and derive helpers
    cfg.setdefault("date", str(date.today()))
    cfg.setdefault("is_coming_soon", True)
    cfg.setdefault("push", True)
    cfg.setdefault("entra_news", None)
    cfg["pub_date"]     = date.fromisoformat(cfg["date"])
    cfg["display_date"] = fmt_display(cfg["pub_date"])

    # Confirm
    print()
    print("  ─────────────────────────────────────────")
    print(f"  Title    : {cfg['title']}")
    print(f"  File     : articles/{cfg['series']}/{cfg['filename']}")
    print(f"  Date     : {cfg['display_date']}")
    print(f"  Series   : {cfg['series_label']}")
    if cfg["entra_news"]:
        en = cfg["entra_news"]
        print(f"  Entra.News: #{en['issue']} — {en['badge'].upper()}")
    print("  ─────────────────────────────────────────")

    if "--config" not in sys.argv:
        if not ask_bool("\n  Proceed with publish?", default=True):
            print("  Aborted.")
            sys.exit(0)

    print("\n📝 Updating files...")
    update_articles_index(cfg)
    update_homepage(cfg)
    update_feed(cfg)

    if cfg["entra_news"]:
        print("\n📰 Updating Entra News pages...")
        update_entra_news(cfg)

    if cfg["push"]:
        print("\n🔀 Committing and pushing...")
        git_push(cfg)
    else:
        print("\n  Files updated locally. Run `git push origin main` when ready.")

    print("\n✅ All done.\n")


if __name__ == "__main__":
    main()
