import re

with open('/Users/jon/Desktop/LearnGraphAPI/articles/conditional-access/ca-policy-analyzer-july-2026.html', 'r') as f:
    content = f.read()

print(f"File length: {len(content)}")
print(f"Base64 images: {content.count('data:image/png;base64')}")

# Step 1: Replace old CSS nav with new site-header CSS
css_start = content.find('  /* Fixed nav badges */')
css_end = content.find('  /* Hero */')
print(f"\nCSS section: {css_start} to {css_end}")

new_nav_css = '''  /* Site nav */
  .site-header {
    position: fixed; top: 0; left: 0; right: 0; z-index: 50;
    display: flex; align-items: center; justify-content: space-between;
    padding: 0.85rem 6vw;
    background: rgba(10,22,40,0.88);
    border-bottom: 1px solid rgba(255,255,255,0.07);
    backdrop-filter: blur(10px);
  }
  .wordmark {
    font-weight: 500; font-size: 0.95rem; letter-spacing: 0.01em;
    color: var(--color-text-primary); text-decoration: none; white-space: nowrap;
  }
  .wordmark span { color: var(--color-teal); }
  .site-nav { display: flex; gap: 1.75rem; align-items: center; }
  .site-nav a {
    font-size: 0.8rem; letter-spacing: 0.08em; text-transform: uppercase;
    color: var(--color-text-secondary); text-decoration: none; transition: color 0.2s;
    padding: 0.5rem 0;
  }
  .site-nav a:hover { color: var(--color-text-primary); }
  .site-nav a.active { color: var(--color-teal); }

'''

content = content[:css_start] + new_nav_css + content[css_end:]

# Step 2: Replace the nav HTML block
body_idx = content.find('<body>\n')
hero_idx = content.find('\n<section class="hero">')
print(f"\nNav HTML block: {body_idx} to {hero_idx}")

new_nav_html = '''<body>

<header class="site-header">
  <a href="https://conditionalaccess.tech" class="wordmark">conditionalaccess<span>.tech</span></a>
  <nav class="site-nav">
    <a href="https://conditionalaccess.tech/articles.html" class="active">Writing</a>
    <a href="https://conditionalaccess.tech/appearances.html" class="hide-mobile">Appearances</a>
    <a href="https://conditionalaccess.tech/about.html">About</a>
  </nav>
</header>

<!-- legacy logo anchor kept for asset reference only: -->
<a href="https://conditionalaccess.tech" style="display:none" class="logo-btn">
  <img src="../../logo/CATechLogo.png" alt="conditionalaccess.tech" />
</a>'''

content = content[:body_idx] + new_nav_html + content[hero_idx:]

# Step 3: Replace base64 images
# Find all base64 img tags
pattern = re.compile(r'<img src="data:image/png;base64,[^"]*"([^>]*)>', re.DOTALL)
matches = list(pattern.finditer(content))
print(f"\nFound {len(matches)} base64 images after nav replacement")

for i, m in enumerate(matches):
    attrs = m.group(1)
    alt_match = re.search(r'alt="([^"]*)"', attrs)
    alt = alt_match.group(1) if alt_match else "NO ALT"
    print(f"  Image {i+1}: alt='{alt[:80]}'")

# Replace each base64 image
# Image 1 (logo - now hidden, already replaced in nav HTML step)
# Image 2 (hero content image - "CA Policy Analyzer July Updates")
# Image 3 (figure image - "CA Policy Analyzer opening screen...")

# Re-find since content changed
matches = list(pattern.finditer(content))
print(f"\nReplacing {len(matches)} base64 images...")

# Process in reverse order to preserve indices
for m in reversed(matches):
    attrs = m.group(1)
    alt_match = re.search(r'alt="([^"]*)"', attrs)
    alt = alt_match.group(1) if alt_match else ""
    style_match = re.search(r'style="([^"]*)"', attrs)
    style = f' style="{style_match.group(1)}"' if style_match else ''
    
    new_img = f'<img src="images/CAPolicyAnalyzer/CAPolicyAnalyzerJuly.png" alt="{alt}"{style}>'
    content = content[:m.start()] + new_img + content[m.end():]
    print(f"  Replaced: alt='{alt[:60]}'")

print(f"\nRemaining base64 images: {content.count('data:image/png;base64')}")

# Step 4: Update @media query to add site-nav hide-mobile
old_media = '  @media (max-width: 600px) {'
new_media = '''  @media (max-width: 768px) {
    .site-nav a.hide-mobile { display: none; }
  }
  @media (max-width: 600px) {'''
content = content.replace(old_media, new_media, 1)
print(f"\nMedia query updated: {'768px' in content}")

# Step 5: Write the result
with open('/Users/jon/Desktop/LearnGraphAPI/articles/conditional-access/ca-policy-analyzer-july-2026.html', 'w') as f:
    f.write(content)

print(f"\nDone! Final file length: {len(content)}")
print(f"Final base64 count: {content.count('data:image/png;base64')}")
