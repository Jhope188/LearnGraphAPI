"""
release_articles.py
--------------------
Reads articles/identity/readme.md and articles/governance/readme.md,
parses the publish schedule, and for any article whose date has been
reached converts its coming-soon card in articles/index.html into a
live clickable link.  Also prepends the new article to feed.xml.

The readme table format expected:
| PT01 | Title | `filename.html` | Mon DD, YYYY | status |

To reschedule: change the date in the readme and push.
To add a new series: follow the same readme format and add a SERIES
entry to the SERIES dict below.
"""

import re
from datetime import date, datetime
from pathlib import Path

TODAY = date.today()
INDEX_FILE = Path("articles/index.html")
FEED_FILE  = Path("feed.xml")
BASE_URL   = "https://conditionalaccess.tech"

# Maps series name -> (readme path, url folder prefix)
SERIES = {
    "identity":   (Path("articles/identity/readme.md"),   "identity/"),
    "governance": (Path("articles/governance/readme.md"),  "governance/"),
}

# Regex to parse a readme table data row
ROW_RE = re.compile(
    r"\|\s*PT\d+\s*\|"           # | PT01 |
    r"[^|]+\|"                   # title |
    r"\s*`([^`]+)`\s*\|"         # `filename.html` |
    r"\s*([A-Za-z]+ \d+,\s*\d{4})\s*\|"  # Mon DD, YYYY |
    r"[^|]*\|"                   # status |
)

def parse_schedule(readme_path):
    """Returns list of (filename, publish_date) from a readme."""
    schedule = []
    for line in readme_path.read_text(encoding="utf-8").splitlines():
        m = ROW_RE.search(line)
        if m:
            filename = m.group(1)
            try:
                pub_date = date.fromisoformat(
                    # normalise "Jun 23, 2026" -> "2026-06-23"
                    str(__import__("datetime").datetime.strptime(
                        m.group(2).strip(), "%b %d, %Y").date())
                )
                schedule.append((filename, pub_date))
            except ValueError:
                pass
    return schedule

def _strip_tags(html_text):
    """Remove HTML tags from a string."""
    return re.sub(r'<[^>]+>', '', html_text).strip()

def update_feed(series_name, url_prefix, filename, pub_date, inner_html):
    """Prepend a new RSS <item> to feed.xml for the released article."""
    if not FEED_FILE.exists():
        return

    title_m = re.search(r'<h3>(.*?)</h3>', inner_html, re.DOTALL)
    desc_m  = re.search(r'<p>(.*?)</p>',  inner_html, re.DOTALL)
    if not title_m or not desc_m:
        return

    title   = _strip_tags(title_m.group(1))
    desc    = _strip_tags(desc_m.group(1))
    item_url = f"{BASE_URL}/articles/{url_prefix}{filename}"
    pub_rfc  = datetime(pub_date.year, pub_date.month, pub_date.day) \
                       .strftime("%a, %d %b %Y 00:00:00 +0000")

    rss_item = (
        f"\n    <item>\n"
        f"      <title>{title}</title>\n"
        f"      <link>{item_url}</link>\n"
        f"      <description>{desc}</description>\n"
        f"      <pubDate>{pub_rfc}</pubDate>\n"
        f"      <guid isPermaLink=\"true\">{item_url}</guid>\n"
        f"    </item>\n"
    )

    feed = FEED_FILE.read_text(encoding="utf-8")
    # Bump lastBuildDate
    feed = re.sub(
        r'<lastBuildDate>.*?</lastBuildDate>',
        f'<lastBuildDate>{pub_rfc}</lastBuildDate>',
        feed,
        count=1
    )
    # Insert item right after </lastBuildDate>
    feed = feed.replace('</lastBuildDate>', f'</lastBuildDate>{rss_item}', 1)
    FEED_FILE.write_text(feed, encoding="utf-8")


html = INDEX_FILE.read_text(encoding="utf-8")
original = html
changes = []

for series_name, (readme_path, url_prefix) in SERIES.items():
    if not readme_path.exists():
        continue
    for filename, pub_date in parse_schedule(readme_path):
        if TODAY < pub_date:
            continue
        # Find the coming-soon div for this file
        pattern = re.compile(
            r'<div class="article-card coming-soon"'
            r'\s+data-series="' + re.escape(series_name) + r'"'
            r'\s+data-file="' + re.escape(filename) + r'"'
            r'>(.*?<div class="article-card-footer"[^>]*>.*?</div>\s*)</div>',
            re.DOTALL
        )
        captured_inner = []
        def activate(m, _fn=filename, _sn=series_name, _pd=pub_date, _up=url_prefix):
            inner = m.group(1)
            captured_inner.append(inner)
            changes.append(f"  ✅ {_sn}/{_fn} (scheduled {_pd})")
            return (
                f'<a href="{_up}{_fn}" class="article-card">'
                + inner
                + '</a>'
            )
        new_html = pattern.sub(activate, html, count=1)
        if new_html != html and captured_inner:
            html = new_html
            update_feed(series_name, url_prefix, filename, pub_date, captured_inner[0])

if html != original:
    INDEX_FILE.write_text(html, encoding="utf-8")
    print(f"Released on {TODAY}:")
    for c in changes:
        print(c)

    # Update readme status: 🔜 Scheduled -> ✅ Published + set exact date
    for series_name, (readme_path, _) in SERIES.items():
        if not readme_path.exists():
            continue
        readme = readme_path.read_text(encoding="utf-8")
        for filename, pub_date in parse_schedule(readme_path):
            if TODAY >= pub_date:
                readme = re.sub(
                    r'(\|\s*`' + re.escape(filename) + r'`\s*\|[^|]*\|)\s*🔜 Scheduled\s*(\|)',
                    r'\1 ✅ Published \2',
                    readme
                )
        readme_path.write_text(readme, encoding="utf-8")

    print("✅ articles/index.html and feed.xml updated. GitHub Pages will redeploy shortly.")
else:
    print(f"⏳ Nothing to release today ({TODAY}).")
