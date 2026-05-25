"""
release_articles.py
--------------------
Reads articles/identity/readme.md and articles/governance/readme.md,
parses the publish schedule, and for any article whose date has been
reached converts its coming-soon card in articles/index.html into a
live clickable link.

The readme table format expected:
| PT01 | Title | `filename.html` | Mon DD, YYYY | status |

To reschedule: change the date in the readme and push.
To add a new series: follow the same readme format and add a SERIES
entry to the SERIES dict below.
"""

import re
from datetime import date
from pathlib import Path

TODAY = date.today()
INDEX_FILE = Path("articles/index.html")

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
        def activate(m):
            inner = m.group(1)
            changes.append(f"  ✅ {series_name}/{filename} (scheduled {pub_date})")
            return (
                f'<a href="{url_prefix}{filename}" class="article-card">'
                + inner
                + '</a>'
            )
        html = pattern.sub(activate, html, count=1)

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

    print("✅ articles/index.html updated. GitHub Pages will redeploy shortly.")
else:
    print(f"⏳ Nothing to release today ({TODAY}).")
