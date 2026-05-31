"""
update_entra_news.py
---------------------
Triggered by the entra-news-update.yml workflow_dispatch.
Reads inputs from environment variables and updates:

  1. entra-news.html  — adds new row to the feature grid, updates stats
  2. entra.news/readme.md — adds Feature #N block, updates all counters
  3. index.html        — updates the Entra News badge (N features • N issues)

Environment variables expected (all set by the workflow):
  ISSUE_NUMBER   e.g. "151"
  ARTICLE_TITLE  e.g. "Authentication Methods: The Spectrum"
  ARTICLE_URL    e.g. "https://conditionalaccess.tech/articles/identity/authentication-methods.html"
  SECTION        e.g. "Authentication"  (or "Conditional Access", "Security", "Most Popular Posts")
  ISSUE_DATE     e.g. "Jun 1, 2026"
  CONTEXT        optional free-text note
"""

import os
import re
from datetime import date
from pathlib import Path

# ── Inputs ─────────────────────────────────────────────────────────────────────

ISSUE_NUMBER  = int(os.environ["ISSUE_NUMBER"])
ARTICLE_TITLE = os.environ["ARTICLE_TITLE"].strip()
ARTICLE_URL   = os.environ["ARTICLE_URL"].strip()
SECTION       = os.environ["SECTION"].strip()
ISSUE_DATE    = os.environ["ISSUE_DATE"].strip()   # e.g. "Jun 1, 2026"
CONTEXT       = os.environ.get("CONTEXT", "").strip()
TODAY         = date.today().strftime("%B %-d, %Y")  # e.g. "June 1, 2026"

# ── Section → badge class mapping ─────────────────────────────────────────────

SECTION_BADGE = {
    "Authentication":     "section-auth",
    "Conditional Access": "section-ca",
    "Security":           "section-security",
    "Most Popular Posts": "section-popular",
    "Tenant Configuration": "section-tenant",
    "DevOps & PowerShell":  "section-devops",
}
badge_class = SECTION_BADGE.get(SECTION, "section-auth")

# Emoji for section in readme
SECTION_EMOJI = {
    "Authentication":       "🫆",
    "Conditional Access":   "🚦",
    "Security":             "🥷",
    "Most Popular Posts":   "🚀",
    "Tenant Configuration": "📒",
    "DevOps & PowerShell":  "🤖",
}
section_display = f"{SECTION_EMOJI.get(SECTION, '')} {SECTION}".strip()

# ── Helper: extract current stats from entra-news.html ────────────────────────

ENTRA_NEWS_HTML = Path("entra-news.html")
INDEX_HTML      = Path("index.html")
ENTRA_README    = Path("entra.news/readme.md")

html = ENTRA_NEWS_HTML.read_text(encoding="utf-8")

# Pull current feature/issue counts from the stats row
feat_match   = re.search(r'<span class="stat-val"><span class="teal">(\d+)</span></span>\s*<span class="stat-label">Features', html)
issues_match = re.search(r'<span class="stat-val"><span class="teal">(\d+)</span></span>\s*<span class="stat-label">Issues', html)

current_features = int(feat_match.group(1))  if feat_match  else 0
current_issues   = int(issues_match.group(1)) if issues_match else 0

new_features = current_features + 1
new_issues   = current_issues + 1

print(f"Current: {current_features} features / {current_issues} issues")
print(f"New:     {new_features} features / {new_issues} issues")

# ── 1. Update entra-news.html ─────────────────────────────────────────────────

# Update meta description counts
html = re.sub(
    r'(\d+) features across (\d+) issues',
    f'{new_features} features across {new_issues} issues',
    html
)

# Update stats row numbers
html = re.sub(
    r'(<span class="stat-val"><span class="teal">)\d+(</span></span>\s*<span class="stat-label">Features)',
    rf'\g<1>{new_features}\2',
    html
)
html = re.sub(
    r'(<span class="stat-val"><span class="teal">)\d+(</span></span>\s*<span class="stat-label">Issues)',
    rf'\g<1>{new_issues}\2',
    html
)

# Update "All N Features" heading
html = re.sub(
    r'All \d+ Features',
    f'All {new_features} Features',
    html
)

# Build new feature row and insert at top of .feature-grid
# Extract month abbreviation for date display (e.g. "Jun 1, 2026")
new_row = (
    f'\n      <a href="https://entra.news/p/entra-news-{ISSUE_NUMBER}" target="_blank" class="feature-row">\n'
    f'        <div>\n'
    f'          <div class="feature-issue">#{ISSUE_NUMBER}</div>\n'
    f'          <div class="feature-issue-date">{ISSUE_DATE}</div>\n'
    f'        </div>\n'
    f'        <div class="feature-title">{ARTICLE_TITLE}</div>\n'
    f'        <span class="feature-section-badge {badge_class}">{SECTION}</span>\n'
    f'      </a>'
)

html = re.sub(
    r'(<div class="feature-grid">)',
    r'\1' + new_row,
    html,
    count=1
)

ENTRA_NEWS_HTML.write_text(html, encoding="utf-8")
print("✅ entra-news.html updated")

# ── 2. Update index.html Entra News badge ─────────────────────────────────────

main_html = INDEX_HTML.read_text(encoding="utf-8")
main_html = re.sub(
    r'<span class="entra-news-badge">\d+ features &bull; \d+ issues</span>',
    f'<span class="entra-news-badge">{new_features} features &bull; {new_issues} issues</span>',
    main_html
)
INDEX_HTML.write_text(main_html, encoding="utf-8")
print("✅ index.html Entra News badge updated")

# ── 3. Update entra.news/readme.md ────────────────────────────────────────────

readme = ENTRA_README.read_text(encoding="utf-8")

# Pull current feature number from readme (count existing ### Feature # blocks)
existing = re.findall(r'### Feature #(\d+)', readme)
new_feature_num = max(int(x) for x in existing) + 1 if existing else 1

# Build new feature block
context_line = f"\n- **Context:** {CONTEXT}" if CONTEXT else ""
new_block = (
    f"\n### Feature #{new_feature_num} — Issue #{ISSUE_NUMBER} ({ISSUE_DATE})\n"
    f"- **Article:** {ARTICLE_TITLE}\n"
    f"- **Link:** [{ARTICLE_URL}]({ARTICLE_URL})\n"
    f"- **Section:** {section_display}\n"
    f"{context_line}\n"
    f"---\n"
)

# Insert after the intro paragraph (before the first ### Feature block)
readme = re.sub(
    r'(---\n\n)(### Feature #)',
    r'\1' + new_block + r'\n### Feature #',
    readme,
    count=1
)

# Update At a Glance counts
readme = re.sub(
    r'(\| Entra News Features \| )\d+ \(across \d+ issues\)',
    f'\\g<1>{new_features} (across {new_issues} issues)',
    readme
)

# Update Unique Articles Featured percentage
total_match = re.search(r'\| Total Articles \| (\d+)', readme)
total_articles = int(total_match.group(1)) if total_match else new_features
unique_pct = round((new_feature_num / total_articles) * 100)  # rough — same article can appear twice
readme = re.sub(
    r'(\| Unique Articles Featured \| )\d+ of \d+ published \(\d+%\)',
    f'\\g<1>{new_feature_num} of {total_articles} published ({unique_pct}%)',
    readme
)

# Update By Entra News Section table — increment matching section
readme = re.sub(
    r'(\| ' + re.escape(section_display) + r' \| )(\d+)( \|)',
    lambda m: m.group(1) + str(int(m.group(2)) + 1) + m.group(3),
    readme
)

# Update Publishing Cadence — extract month from ISSUE_DATE e.g. "Jun 1, 2026" → "Jun 2026"
import datetime as dt
try:
    issue_dt = dt.datetime.strptime(ISSUE_DATE, "%b %d, %Y")
    cadence_month = issue_dt.strftime("%B %Y")  # e.g. "June 2026"
    readme = re.sub(
        r'(\| ' + re.escape(cadence_month) + r' \| \d+ \| )(\d+)( \|)',
        lambda m: m.group(1) + str(int(m.group(2)) + 1) + m.group(3),
        readme
    )
except ValueError:
    pass

# Update document generated date
readme = re.sub(
    r'\*Document generated: .*?\*',
    f'*Document generated: {TODAY}*',
    readme
)

ENTRA_README.write_text(readme, encoding="utf-8")
print(f"✅ entra.news/readme.md updated — Feature #{new_feature_num} added")

print(f"\n🎉 All done! Issue #{ISSUE_NUMBER} — '{ARTICLE_TITLE}' recorded as Feature #{new_feature_num}.")
