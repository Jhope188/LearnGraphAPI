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
  articles.html          — featured article, series count, card activation/insertion
  index.html             — featured writing card on homepage
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
ARTICLES   = ROOT / "articles.html"
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
# 2. Update articles.html
# ─────────────────────────────────────────────────────────────────────────────

def update_articles_index(cfg: dict):
    series       = cfg["series"]
    filename     = cfg["filename"]
    title        = cfg["title"]
    description  = cfg["description"]
    series_lbl   = cfg["series_label"]
    display_date = cfg["display_date"]
    tab_label    = TAB_LABELS.get(series, series.title())
    article_path = f"articles/{series}/{filename}"

    html = ARTICLES.read_text(encoding="utf-8")

    # ── 2a. Update featured article (id="featured-article") ──────────────────
    featured_inner = (
        f'\n        <div style="position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,#00b8b0,transparent);"></div>\n'
        f'        <div style="display:flex;gap:8px;margin-bottom:18px;flex-wrap:wrap;">\n'
        f'          <span style="font-size:0.6rem;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;background:rgba(0,184,176,0.12);color:#00b8b0;padding:4px 9px;border-radius:3px;">{series_lbl}</span>\n'
        f'          <span style="font-size:0.6rem;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;background:rgba(245,200,66,0.10);color:#f5c842;padding:4px 9px;border-radius:3px;">Latest</span>\n'
        f'        </div>\n'
        f'        <h2 style="font-size:clamp(1.6rem,3.2vw,2.3rem);font-weight:600;letter-spacing:-0.015em;line-height:1.15;margin:0 0 14px;color:#e8f0f8;max-width:18em;">{title}</h2>\n'
        f'        <p style="font-size:1.02rem;line-height:1.7;color:#7a9bb5;margin:0 0 22px;max-width:42em;">{description}</p>\n'
        f'        <div style="display:flex;align-items:center;gap:8px;font-size:0.84rem;color:#4a6a80;"><i class="ph ph-calendar-blank" style="font-size:15px;"></i> {display_date} · {tab_label}</div>\n'
        f'      '
    )

    def replace_featured(m):
        open_tag = re.sub(r'href="[^"]*"', f'href="{article_path}"', m.group(1))
        return open_tag + featured_inner + m.group(3)

    html = re.sub(
        r'(<a[^>]+id="featured-article"[^>]*>)'
        r'(.*?)'
        r'(</a>)',
        replace_featured,
        html, count=1, flags=re.DOTALL
    )

    # ── 2b. Increment series count badge ─────────────────────────────────────
    def inc_count(m):
        return m.group(1) + str(int(m.group(2)) + 1) + m.group(3)

    html = re.sub(
        r'(<span id="count-' + re.escape(series) + r'"[^>]*>)(\d+)([^<]*</span>)',
        inc_count,
        html, count=1
    )

    # ── 2c. Activate coming-soon OR insert new card ───────────────────────────
    if cfg["is_coming_soon"]:
        cs_pat = re.compile(
            r'<div data-series="' + re.escape(series) + r'" data-file="' + re.escape(filename) + r'"[^>]*>\n'
            r'((?:[ \t]+.*\n)*?)'
            r'[ \t]+</div>',
            re.DOTALL
        )
        new_card = (
            f'<a class="lift" href="{article_path}" '
            f'style="display:block;background:#0d2137;border:1px solid rgba(0,184,176,0.12);border-radius:10px;padding:26px 28px;">\n'
            f'          <div style="font-size:0.62rem;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;color:#00b8b0;margin-bottom:10px;">{series_lbl}</div>\n'
            f'          <h3 style="font-size:1.18rem;font-weight:600;margin:0 0 8px;color:#e8f0f8;line-height:1.3;">{title}</h3>\n'
            f'          <p style="font-size:0.92rem;line-height:1.6;color:#7a9bb5;margin:0 0 14px;">{description}</p>\n'
            f'          <div style="font-size:0.78rem;color:#4a6a80;">{display_date}</div>\n'
            f'        </a>'
        )
        html = cs_pat.sub(new_card, html, count=1)
    else:
        new_card = (
            f'\n        <a class="lift" href="{article_path}" '
            f'style="display:block;background:#0d2137;border:1px solid rgba(0,184,176,0.12);border-radius:10px;padding:26px 28px;">\n'
            f'          <div style="font-size:0.62rem;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;color:#00b8b0;margin-bottom:10px;">{series_lbl}</div>\n'
            f'          <h3 style="font-size:1.18rem;font-weight:600;margin:0 0 8px;color:#e8f0f8;line-height:1.3;">{title}</h3>\n'
            f'          <p style="font-size:0.92rem;line-height:1.6;color:#7a9bb5;margin:0 0 14px;">{description}</p>\n'
            f'          <div style="font-size:0.78rem;color:#4a6a80;">{display_date}</div>\n'
            f'        </a>'
        )
        html = re.sub(
            r'(<div id="grid-' + re.escape(series) + r'"[^>]*>)',
            lambda m: m.group(0) + new_card,
            html, count=1
        )

    ARTICLES.write_text(html, encoding="utf-8")
    print("  ✅ articles.html — featured article, series count, article card")


# ─────────────────────────────────────────────────────────────────────────────
# 3. Update index.html featured writing card
# ─────────────────────────────────────────────────────────────────────────────

def update_homepage(cfg: dict):
    series       = cfg["series"]
    filename     = cfg["filename"]
    title        = cfg["title"]
    description  = cfg["description"]
    display_date = cfg["display_date"]
    series_lbl   = cfg["series_label"]
    tab_label    = TAB_LABELS.get(series, series.title())
    article_url  = f"{BASE_URL}/articles/{series}/{filename}"

    idx = INDEX.read_text(encoding="utf-8")

    # Build new inner content for the featured writing card (id="latest-article")
    featured_inner = (
        f'\n          <div style="position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,#00b8b0,transparent);"></div>\n'
        f'          <div>\n'
        f'            <div style="display:flex;gap:8px;margin-bottom:18px;">\n'
        f'              <span style="font-size:0.6rem;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;background:rgba(0,184,176,0.12);color:#00b8b0;padding:4px 9px;border-radius:3px;">{series_lbl}</span>\n'
        f'              <span style="font-size:0.6rem;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;background:rgba(245,200,66,0.10);color:#f5c842;padding:4px 9px;border-radius:3px;">Latest</span>\n'
        f'            </div>\n'
        f'            <h3 style="font-size:1.75rem;font-weight:600;letter-spacing:-0.01em;line-height:1.2;margin:0 0 14px;color:#e8f0f8;">{title}</h3>\n'
        f'            <p style="font-size:0.98rem;line-height:1.7;color:#7a9bb5;margin:0;max-width:34em;">{description}</p>\n'
        f'          </div>\n'
        f'          <div style="display:flex;align-items:center;gap:8px;margin-top:24px;font-size:0.84rem;color:#4a6a80;"><i class="ph ph-calendar-blank" style="font-size:15px;"></i> {display_date}</div>\n'
        f'        '
    )

    def replace_latest(m):
        open_tag = re.sub(r'href="[^"]*"', f'href="{article_url}"', m.group(1))
        return open_tag + featured_inner + m.group(3)

    idx = re.sub(
        r'(<a[^>]+id="latest-article"[^>]*>)'
        r'(.*?)'
        r'(</a>)',
        replace_latest,
        idx, count=1, flags=re.DOTALL
    )

    INDEX.write_text(idx, encoding="utf-8")
    print("  ✅ index.html — featured writing card")


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

    # Parse current counts from id-tagged elements
    feat_m  = re.search(r'id="entra-features-count">(\d+)<', en)
    issue_m = re.search(r'id="entra-issues-count">(\d+)<', en)
    old_feat       = int(feat_m.group(1))  if feat_m  else 22
    old_issue_cnt  = int(issue_m.group(1)) if issue_m else 20
    new_feat        = old_feat + 1
    new_issue_count = old_issue_cnt + (1 if new_issue else 0)

    # Prepend new entry to JS features array
    js_entry = (
        f'      {{n:"{issue_num}", date:"{issue_date}", title:"{title}", '
        f'cat:"{badge_label}"}},\n      '
    )
    en = re.sub(r'(var features = \[\n)', lambda m: m.group(1) + js_entry, en, count=1)

    # Update features count stat
    en = re.sub(
        r'(id="entra-features-count">)\d+(<)',
        lambda m: m.group(1) + str(new_feat) + m.group(2),
        en, count=1
    )
    # Update issues count stat
    en = re.sub(
        r'(id="entra-issues-count">)\d+(<)',
        lambda m: m.group(1) + str(new_issue_count) + m.group(2),
        en, count=1
    )
    # Update "All N Features" heading
    en = re.sub(
        r'(id="all-features-heading">All )\d+( Features</h2>)',
        lambda m: m.group(1) + str(new_feat) + m.group(2),
        en, count=1
    )
    # Update meta description
    en = re.sub(
        r'(\d+) features across (\d+) issues',
        f'{new_feat} features across {new_issue_count} issues',
        en, count=1
    )
    # Update archive snapshot note
    en = re.sub(
        r'Archive snapshot refreshed through Entra\.News #\d+ \([^)]+\)\.',
        f'Archive snapshot refreshed through Entra.News #{issue_num} ({issue_date}).',
        en, count=1
    )
    ENTRA_HTML.write_text(en, encoding="utf-8")
    print(f"  ✅ entra-news.html — #{issue_num} row added, features {old_feat}→{new_feat}, issues {old_issue}→{new_issue_count}")

    # ── 5b. index.html entra-news stats ──────────────────────────────────────
    idx = INDEX.read_text(encoding="utf-8")
    idx = re.sub(
        r'(id="idx-entra-features">)\d+(<)',
        lambda m: m.group(1) + str(new_feat) + m.group(2),
        idx, count=1
    )
    idx = re.sub(
        r'(id="idx-entra-issues">)\d+(<)',
        lambda m: m.group(1) + str(new_issue_count) + m.group(2),
        idx, count=1
    )
    INDEX.write_text(idx, encoding="utf-8")
    print(f"  ✅ index.html — Entra News stats → {new_feat} features · {new_issue_count} issues")

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
        "articles.html",
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
