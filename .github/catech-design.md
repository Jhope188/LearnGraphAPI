2 files
---
name: design-system
description: >
  Jon Hope's personal design system for conditionalaccess.tech, Microsoft MVP brand content,
  and Inforcer blog posts. Use this skill whenever Jon asks to build, update, or redesign
  any of the following: HTML articles or blog posts, LinkedIn banners or carousel images,
  website pages or landing pages, wallpapers or branded backgrounds, infographics, or any
  other visual or written deliverable that carries the conditionalaccess.tech or MVP brand.
  Also trigger when Jon says "use my design system", "keep it on brand", "match my site style",
  "build a post", "new article", or asks for any design or content output without specifying
  a style — assume this system applies. Do NOT trigger for pure technical tasks (KQL queries,
  Intune policy review, CA troubleshooting) unless a designed output is also requested.
---
 
# conditionalaccess.tech Design System
 
Reference this file before writing any HTML, CSS, or design-adjacent output for Jon.
All token values, type decisions, and component patterns are defined here.
Full detail is in `references/tokens.md`. Read it for any non-trivial design task.
 
---
 
## Quick Reference
 
### Color Tokens
```css
--color-base:          #0a1628;   /* Page background */
--color-surface:       #0d2137;   /* Card / panel */
--color-surface-alt:   #112840;   /* Elevated / hover */
--color-border:        rgba(0,184,176,0.12);
--color-teal:          #00b8b0;   /* Primary accent, ".tech" wordmark */
--color-teal-dim:      #1a7f7a;   /* Ambient glow, secondary */
--color-teal-glow:     rgba(26,127,122,0.20);
--color-ms-blue:       #0078d4;   /* MVP logo contexts ONLY */
--color-text-primary:  #e8f0f8;
--color-text-secondary:#7a9bb5;
--color-text-dim:      #4a6a80;
--color-ok:            #00b8b0;
--color-warn:          #f5c842;
--color-danger:        #e05533;
```
 
### Typography
```css
/* Body / UI */
font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
 
/* Mono (policy names, Graph values, code) */
font-family: 'Cascadia Code', 'Consolas', monospace;
```
 
Type scale and full spacing system: see `references/tokens.md`.
 
### Signature Background
```css
/* Hero sections — the teal bloom */
background:
  radial-gradient(ellipse 55% 45% at 70% 25%, rgba(26,127,122,0.22) 0%, transparent 65%),
  radial-gradient(ellipse 35% 55% at 15% 75%, rgba(0,184,176,0.08) 0%, transparent 60%),
  #0a1628;
```
 
---
 
## Design Rules (Non-Negotiable)
 
1. **Dark-first.** No light mode. The brand lives in deep navy and teal.
2. **Segoe UI only.** No decorative display faces. Semibold at large sizes does the work.
3. **Teal is the accent.** `--color-ms-blue` is reserved for MVP logo and Microsoft product references only.
4. **One visual anchor per section.** Heading, pull quote, table, or card grid — never two.
5. **No bullets in prose.** Bullets are for checklists and reference tables only.
6. **No em dashes or arrow dashes (`→`) in prose.** Use commas and colons instead.
7. **Animation is minimal.** Hero fadeUp only. No parallax, no looping decorative effects.
8. **Icons are flat, single-color, 24px grid.** No gradients or shadows on icons.
---
 
## Component Patterns
 
### Card
```css
background: var(--color-surface);
border: 1px solid var(--color-border);
border-radius: 6px;
padding: 24px 28px;
```
Add `::before` with `height: 2px; background: linear-gradient(90deg, var(--color-teal), transparent)` on featured cards only.
 
### Status Badges
```css
.badge-ok     { background: rgba(0,184,176,0.12); color: #00b8b0; }
.badge-warn   { background: rgba(245,200,66,0.10); color: #f5c842; }
.badge-danger { background: rgba(224,85,51,0.12);  color: #e05533; }
```
 
### Callout / Alert
```css
border-left: 3px solid var(--color-teal); /* or warn/danger color */
background: var(--color-surface);
border-radius: 0 6px 6px 0;
padding: 16px 20px;
```
 
### Inline Mono Tag
```css
font-family: 'Cascadia Code', monospace;
font-size: 0.82rem;
color: var(--color-teal);
background: rgba(0,184,176,0.08);
padding: 2px 6px;
border-radius: 3px;
```
 
### Eyebrow / Section Label
```css
font-size: 0.7rem; font-weight: 600;
letter-spacing: 0.18em; text-transform: uppercase;
color: var(--color-teal);
```
 
---
 
## Brand Elements
 
### conditionalaccess.tech Wordmark
- Icon: Entra-style shield (blue, Microsoft Entra product icon family)
- "conditionalaccess" — Segoe UI Semibold, `#e8f0f8`
- ".tech" — Segoe UI Semibold, `#00b8b0`
- Subtitle: "Microsoft MVP • Security: Identity & Access" — Segoe UI Regular, `#7a9bb5`
### MVP Logo Rules
- Dark backgrounds (navy, blue-black): white reversed version
- Light backgrounds: standard blue master logo
- Never recolor, crop, or place inside a shaped container
- For tight spaces: diamond symbol only, 32px minimum
---
 
## Content Voice
 
- Direct. Short sentences after long ones. No hedging.
- Practitioner-level assumed — don't explain what MFA is.
- Analogy-first for complex concepts, then the technical detail.
- No em dashes or `→` in prose.
- Banned words: "systematically," "entropy," "theater" (governance context), "rubber stamp," "instantiating."
- Correct spelling: "recurrence" not "reoccurrence."
---
 
## When to Read the Full Reference
 
Read `references/tokens.md` when:
- Building a full HTML article or page from scratch
- Matching spacing precisely across a multi-section layout
- Checking color accessibility pairings
- Comparing conditionalaccess.tech teal against MVP blue or weather-app teal
- Setting up file/asset naming conventions
 

# conditionalaccess.tech — Design System
**Jon Hope | Microsoft MVP, Security: Identity & Access**
*Version 1.0 — June 2026*
 
---
 
## Philosophy
 
This system is built for one audience: M365 security practitioners and MSP admins who are skeptical of fluff and respond to clarity. The design should feel like a well-configured Entra tenant — no noise, no default settings left in place, every choice intentional.
 
Three sources shaped this system:
 
1. **Your brand** — the conditionalaccess.tech wallpaper and logo establish the ambient teal-on-deep-navy palette and the Entra-style shield icon.
2. **Microsoft MVP brand kit** — Segoe UI, the Microsoft blue family, and structured whitespace set the typographic register.
3. **The weather app** — minimal icon language, teal gradient cards, generous padding, and a layout that prioritizes scannable hierarchy over decoration.
**The design risk worth taking:** No decorative illustrations. No glows for atmosphere's sake alone. The teal bloom on dark navy is *the* signature. Everything else serves information delivery.
 
---
 
## Color Tokens
 
```css
:root {
  /* Backgrounds */
  --color-base:         #0a1628;  /* Deep navy — page background */
  --color-surface:      #0d2137;  /* Card / panel layer */
  --color-surface-alt:  #112840;  /* Elevated card / hover state */
  --color-border:       rgba(0, 184, 176, 0.12);  /* Teal border, dimmed */
 
  /* Brand Accent */
  --color-teal:         #00b8b0;  /* Primary highlight, interactive, wordmark ".tech" */
  --color-teal-dim:     #1a7f7a;  /* Ambient glow, bloom, secondary accent */
  --color-teal-glow:    rgba(26, 127, 122, 0.20); /* Radial bloom for backgrounds */
 
  /* Microsoft System Blue — use for MVP logo contexts only */
  --color-ms-blue:      #0078d4;  /* MVP diamond, system-level trust indicators */
  --color-ms-blue-dark: #1b3a5c;  /* Dark Blue / Blue 13 from MVP brand kit */
 
  /* Text */
  --color-text-primary:   #e8f0f8;  /* Near-white with blue cast — headings, body */
  --color-text-secondary: #7a9bb5;  /* Muted slate blue — labels, metadata */
  --color-text-dim:       #4a6a80;  /* Disabled, decorative numbers */
 
  /* Status */
  --color-ok:      #00b8b0;  /* Teal — pass / safe / compliant */
  --color-warn:    #f5c842;  /* Amber — conditional / review needed */
  --color-danger:  #e05533;  /* Muted red-orange — fail / critical / blocked */
}
```
 
### Palette Reference
 
| Role | Hex | Notes |
|------|-----|-------|
| Page background | `#0a1628` | Matches conditionalaccess.tech wallpaper base |
| Card surface | `#0d2137` | 1 stop lighter than base |
| Teal (primary) | `#00b8b0` | Wordmark ".tech", interactive elements, strong callouts |
| Teal bloom | `#1a7f7a` | Ambient radial gradient, section dividers |
| MS Blue | `#0078d4` | Reserved for MVP logo contexts and Microsoft product references |
| Text primary | `#e8f0f8` | Has a blue-cool cast (not warm off-white) |
| Text secondary | `#7a9bb5` | Labels, timestamps, metadata |
 
**Color pairings that work (accessibility-verified minimum 4.5:1):**
- `#00b8b0` on `#0a1628` → passes AA for large text / decorative use
- `#e8f0f8` on `#0a1628` → passes AA+ for body text
- `#e8f0f8` on `#0d2137` → passes AA for body text
---
 
## Typography
 
### Font Stack
 
```css
/* Primary — UI, body, all prose */
font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
 
/* Monospace — code blocks, CLI examples, Graph API values, policy names */
font-family: 'Cascadia Code', 'Cascadia Mono', 'Consolas', monospace;
```
 
> **Why Segoe UI:** It matches the Microsoft MVP brand kit and the Microsoft product family (Entra admin center, M365 portal) that the audience lives in every day. It signals that this content belongs in that ecosystem without imitating it. It is clean enough to carry technical content and familiar enough not to distract.
 
> **No separate display face.** The combination of Segoe UI Semibold at large sizes with generous tracking reads as sophisticated and modern. Adding a second decorative face introduces personality that would compete with the content's technical authority.
 
### Type Scale
 
```css
/* Display — hero headlines, section titles */
font-size: clamp(2.5rem, 6vw, 5rem);
font-weight: 600;
letter-spacing: -0.02em;
line-height: 1.05;
color: var(--color-text-primary);
 
/* Heading 1 — article titles, page H1 */
font-size: clamp(1.75rem, 3.5vw, 2.5rem);
font-weight: 600;
letter-spacing: -0.01em;
line-height: 1.15;
 
/* Heading 2 — section headers */
font-size: 1.25rem;
font-weight: 600;
letter-spacing: 0.01em;
line-height: 1.3;
 
/* Body — prose, descriptions */
font-size: 1rem;
font-weight: 400;
line-height: 1.75;
color: var(--color-text-secondary);
 
/* Label / Eyebrow — uppercase metadata, category tags */
font-size: 0.7rem;
font-weight: 600;
letter-spacing: 0.18em;
text-transform: uppercase;
color: var(--color-teal);
 
/* Mono — inline code, policy names, Graph values */
font-size: 0.82rem;
font-family: 'Cascadia Code', monospace;
color: var(--color-teal);
background: rgba(0, 184, 176, 0.08);
padding: 2px 6px;
border-radius: 3px;
```
 
---
 
## Spacing System
 
Base unit: `4px`. All spacing uses multiples.
 
```
4px   → tight inline gap (icon + label)
8px   → element gap within a component
12px  → compact padding (tags, badges, small cards)
16px  → default component padding
24px  → section gap within content
32px  → section padding for cards
48px  → between content sections
64px  → major section breaks
96px  → hero / page-level vertical rhythm
```
 
---
 
## Component Patterns
 
### Card
 
```css
.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  padding: 24px 28px;
  position: relative;
  overflow: hidden;
}
 
/* Teal top accent bar — use on featured/important cards only */
.card::before {
  content: '';
  position: absolute;
  top: 0; left: 0; right: 0; height: 2px;
  background: linear-gradient(90deg, var(--color-teal), transparent);
}
```
 
### Status Badge
 
```css
.badge { font-size: 0.65rem; letter-spacing: 0.08em; text-transform: uppercase;
         padding: 3px 8px; border-radius: 3px; font-weight: 600; }
 
.badge-ok     { background: rgba(0,184,176,0.12); color: var(--color-teal); }
.badge-warn   { background: rgba(245,200,66,0.10); color: #f5c842; }
.badge-danger { background: rgba(224,85,51,0.12);  color: var(--color-danger); }
```
 
### Callout / Alert Block
 
```css
.callout {
  background: var(--color-surface);
  border: 1px solid rgba(0,184,176,0.15);
  border-left: 3px solid var(--color-teal);
  border-radius: 0 6px 6px 0;
  padding: 16px 20px;
  margin: 24px 0;
}
.callout.warn   { border-left-color: #f5c842; }
.callout.danger { border-left-color: var(--color-danger); }
```
 
### Section Label (Eyebrow)
 
```css
.eyebrow {
  font-size: 0.7rem;
  font-weight: 600;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--color-teal);
  margin-bottom: 8px;
}
```
 
### Inline Mono Tag (Graph API values, policy names)
 
```html
<span class="mono">b2bCollaborationGuest</span>
```
 
---
 
## Background Texture — The Teal Bloom
 
The signature visual. Used on hero sections and the conditionalaccess.tech wallpaper. Do not use it everywhere.
 
```css
.hero-bg {
  background:
    radial-gradient(ellipse 55% 45% at 70% 25%, rgba(26,127,122,0.22) 0%, transparent 65%),
    radial-gradient(ellipse 35% 55% at 15% 75%, rgba(0,184,176,0.08) 0%, transparent 60%),
    #0a1628;
}
```
 
For the wallpaper variant (centered bloom):
 
```css
background:
  radial-gradient(ellipse 60% 50% at 60% 35%, rgba(26,127,122,0.28) 0%, transparent 70%),
  radial-gradient(ellipse 40% 60% at 25% 80%, rgba(0,120,212,0.08) 0%, transparent 60%),
  #0a1628;
```
 
---
 
## Icon Language
 
### Principle
Flat, single-color, 24px grid. No gradients on icons. No drop shadows. Match the weather app reference — icons exist to categorize information at a glance, not to decorate.
 
### Sources
- **Microsoft Fluent UI icons** — for M365 product references (Entra, Intune, Defender, Purview)
- **Phosphor Icons** — for general UI (lighter weight than Heroicons, cleaner at small sizes)
- **Your conditionalaccess.tech Entra-style shield** — reserved for brand use only, not as a repeating UI element
### Color Rule
Icons inherit `currentColor`. They should match the label or heading they accompany. Never use a different color than the surrounding text unless signaling a specific status.
 
---
 
## Logo & Brand Elements
 
### conditionalaccess.tech wordmark
 
```
Icon:  Entra-style shield (blue, matches Microsoft Entra product icon family)
Text:  "conditionalaccess" in Segoe UI Semibold, color: #e8f0f8
       ".tech" in Segoe UI Semibold, color: #00b8b0 (teal accent)
Sub:   "Microsoft MVP • Security: Identity & Access" in Segoe UI Regular 400,
        color: #7a9bb5, letter-spacing: 0.05em
```
 
### Microsoft MVP Logo — Use Rules
Based on the official MVP brand kit:
 
- **On dark backgrounds** (navy, blue-black, blue-13): Use the full-color reversed (white diamond + white text) version
- **On light backgrounds**: Use the standard blue master logo
- Minimum clear space: equal to the height of the "MVP" letterforms on all sides
- Do not recolor, crop, or place on a background with insufficient contrast
- The MVP logo must never appear inside a shaped container (circle, hexagon, etc.) on branded content
- For article headers / LinkedIn banners: use the "Symbol" (diamond only) at 32px or smaller when space is tight
---
 
## Layout Principles
 
### Grid
Max-width prose: `760px`. Max-width full-bleed content (tables, comparison grids): `960px`. No container above `1100px`.
 
### Hierarchy rule
Every section needs exactly one visual anchor: a heading, a pull quote, a table, or a card grid. Never two. The eye needs one place to land.
 
### No bullets in prose
Bullet points are for checklists and structured reference content. Prose is prose. If a sentence needs a bullet to be understood, restructure the sentence.
 
### Tables
Used for reference content only (policy comparisons, guest type breakdowns, license mappings). Not for layout. Header row always uses the eyebrow type style.
 
---
 
## Motion / Animation
 
Less is more. The audience is technical — gratuitous animation reads as a distraction from content credibility.
 
Allowed:
```css
/* Fade up on page load — hero content only */
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(16px); }
  to   { opacity: 1; transform: translateY(0); }
}
 
/* Hover state on cards and buttons */
transition: background 0.15s ease, border-color 0.15s ease;
```
 
Not allowed:
- Parallax scroll effects
- Entrance animations on body content (only hero)
- Bouncing, spinning, or looping decorative animations
- Skeleton loaders (show content or nothing)
---
 
## Dark/Light Mode
 
This system is **dark-first**. A light variant is not defined here — the brand identity lives in the deep navy/teal pairing and a light-mode inversion would lose it. If a light mode is ever required (e.g., print stylesheet for a report), treat it as a separate document, not an inverted version of this system.
 
---
 
## Reference Comparisons
 
### conditionalaccess.tech teal vs. MVP blue family
| Token | Hex | Closest MVP color |
|-------|-----|-------------------|
| `--color-teal` | `#00b8b0` | No direct match — this is the brand differentiator |
| `--color-teal-dim` | `#1a7f7a` | No direct match |
| `--color-ms-blue` | `#0078d4` | MVP "Blue" (`#0078d4`) — exact match |
| `--color-ms-blue-dark` | `#1b3a5c` | MVP "Blue 13" (`#1b3355` approximate) |
| `--color-text-primary` | `#e8f0f8` | MVP "Off White" (`#f4f3f5`) — cooler variant |
 
### conditionalaccess.tech teal vs. weather app teal
The weather app hero card sits around `#2a8a8a`. This system's `--color-teal` (`#00b8b0`) is brighter and closer to cyan, which reads as more technical and less lifestyle. Keep the distinction — the weather app is consumer, this is practitioner.
 
---
 
## File & Asset Naming Convention
 
```
conditionalaccess-[purpose]-[variant].[ext]
 
Examples:
  conditionalaccess-wallpaper-4k.png
  conditionalaccess-wallpaper-aurora.png
  conditionalaccess-logo-dark.svg
  conditionalaccess-logo-light.svg
  conditionalaccess-avatar-clean.png
  conditionalaccess-banner-cloud.png
```
 
---
 
## Content Voice (for consistency with design)
 
- Direct. Short sentences after a long one. No hedging.
- Practitioner-level assumed. Don't explain what MFA is.
- Analogy-first for complex concepts, then the technical detail.
- No em dashes. No arrow dashes in prose. Use commas and colons.
- No words: "systematically," "entropy," "theater" (in governance context), "rubber stamp."
- Correct: "recurrence" not "reoccurrence."
---
 
*This document is a living reference. Update version and date when tokens or decisions change.*