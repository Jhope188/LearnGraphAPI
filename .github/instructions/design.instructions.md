---
applyTo: "**/*.html,**/*.css"
---

# conditionalaccess.tech — Design System

Apply this when creating or editing any HTML/CSS for conditionalaccess.tech. Every design decision should feel like a well-configured Entra tenant — no noise, every choice intentional.

## Color Tokens

```css
:root {
  --color-base:           #0a1628;  /* Deep navy — page background */
  --color-surface:        #0d2137;  /* Card / panel layer */
  --color-surface-alt:    #112840;  /* Elevated card / hover state */
  --color-border:         rgba(0, 184, 176, 0.12);

  --color-teal:           #00b8b0;  /* Primary highlight, interactive, wordmark ".tech" */
  --color-teal-dim:       #1a7f7a;  /* Ambient glow, bloom, secondary accent */
  --color-teal-glow:      rgba(26, 127, 122, 0.20);

  --color-ms-blue:        #0078d4;  /* MVP logo contexts only */
  --color-ms-blue-dark:   #1b3a5c;

  --color-text-primary:   #e8f0f8;
  --color-text-secondary: #7a9bb5;
  --color-text-dim:       #4a6a80;

  --color-ok:     #00b8b0;
  --color-warn:   #f5c842;
  --color-danger: #e05533;
}
```

## Typography

```css
/* Primary */
font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;

/* Monospace — code, CLI, Graph API values, policy names */
font-family: 'Cascadia Code', 'Cascadia Mono', 'Consolas', monospace;
```

### Type Scale
- Display hero: `clamp(2.5rem, 6vw, 5rem)`, weight 600, tracking -0.02em, lh 1.05
- H1: `clamp(1.75rem, 3.5vw, 2.5rem)`, weight 600, tracking -0.01em
- H2: `1.25rem`, weight 600
- Body: `1rem`, weight 400, lh 1.75, color `--color-text-secondary`
- Eyebrow/label: `0.7rem`, weight 600, tracking 0.18em, uppercase, color `--color-teal`
- Mono inline: `0.82rem`, background `rgba(0,184,176,0.08)`, padding `2px 6px`, border-radius `3px`

## Spacing System (base 4px)
4 → tight inline gap | 8 → within component | 16 → default padding | 24 → section gap | 32 → card padding | 48 → between sections | 64 → major breaks | 96 → hero rhythm

## Component Patterns

### Card
```css
background: var(--color-surface);
border: 1px solid var(--color-border);
border-radius: 6px;
padding: 24px 28px;
```
Teal top accent bar (featured cards only):
```css
::before { top:0; left:0; right:0; height:2px; background: linear-gradient(90deg, var(--color-teal), transparent); }
```

### Status Badge
```css
.badge-ok     { background: rgba(0,184,176,0.12); color: var(--color-teal); }
.badge-warn   { background: rgba(245,200,66,0.10); color: #f5c842; }
.badge-danger { background: rgba(224,85,51,0.12);  color: var(--color-danger); }
```

### Callout / Alert
```css
border-left: 3px solid var(--color-teal); /* warn: #f5c842, danger: var(--color-danger) */
border-radius: 0 6px 6px 0;
padding: 16px 20px;
```

## The Teal Bloom (hero sections only — do not overuse)
```css
background:
  radial-gradient(ellipse 55% 45% at 70% 25%, rgba(26,127,122,0.22) 0%, transparent 65%),
  radial-gradient(ellipse 35% 55% at 15% 75%, rgba(0,184,176,0.08) 0%, transparent 60%),
  #0a1628;
```

## Layout
- Max-width prose: `760px`
- Max-width full-bleed: `960px`
- No container above `1100px`
- Every section needs exactly one visual anchor — never two
- No bullets in prose; tables for reference content only

## Motion
Allowed: `fadeUp` on hero only, `transition: 0.15s ease` on hover states.
Not allowed: parallax, entrance animations on body content, bouncing/spinning/looping animations.

## Icon Rules
- Flat, single-color, 24px grid. No gradients or drop shadows on icons.
- Phosphor Icons for general UI; Fluent UI for M365 product references
- Icons inherit `currentColor`; never a different color unless signaling status

## Wordmark
```
Icon:  Entra-style shield
Text:  "conditionalaccess" — Segoe UI Semibold, #e8f0f8
       ".tech" — Segoe UI Semibold, #00b8b0
Sub:   "Microsoft MVP • Security: Identity & Access" — weight 400, #7a9bb5
```

## MVP Logo Rules
- Dark backgrounds: full-color reversed (white diamond + white text)
- Minimum clear space: height of "MVP" letterforms on all sides
- Never recolored, cropped, or inside a shaped container (circle, hexagon)

## Design Anti-Patterns — Never Do These
- Gradient mesh overload (purple-to-teal-to-pink)
- Glowing orbs / floating spheres
- Glass morphism stacked on glass morphism
- Stock photography
- Icon soup (every element gets a Font Awesome icon)
- Teal highlights used reflexively — the bloom is the signature, use it intentionally
- Every section titled — let elements breathe

## File Naming
```
conditionalaccess-[purpose]-[variant].[ext]
e.g. conditionalaccess-wallpaper-4k.png, conditionalaccess-logo-dark.svg
```

## Content Voice
- Direct. Short sentences after a long one. No hedging.
- Practitioner-level assumed — don't explain what MFA is.
- Analogy-first for complex concepts, then the technical detail.
- No em dashes in prose. Use commas and colons.
- "recurrence" not "reoccurrence"
