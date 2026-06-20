# Paper & Ink Specification Theme for Architecture Diagrams

The Paper & Ink theme is the official visual design standard for technical architecture diagrams, inspired by high-density architectural blueprints, academic journals, and technical documentation constraints. It prioritizes clarity, structure, and readability, avoiding digital noise like gradients, rounded corners, or shadows.

## Core Visual Token Architecture

### 1. Base Materials (CSS Theme Variables)
```css
:root {
  --color-surface: #fcf9f2;                  /* warm unbleached paper background */
  --color-surface-dim: #dcdad3;              /* dim/darker paper tone */
  --color-surface-container: #f1eee7;        /* container background */
  --color-surface-container-high: #ebe8e1;   /* high-priority container background */
  --color-surface-container-highest: #e5e2db;/* highest-priority container background */
  
  --color-primary: #171611;                  /* dark charcoal ink for primary text & lines */
  --color-secondary: #a03e3d;                /* accent Maroon for primary alerts/frontend boundaries */
  --color-tertiary: #0f1900;                 /* accent Olive for core APIs/backend boundaries */
  --color-error: #ba1a1a;                    /* deep red for security and warnings */
  
  --font-mono: 'JetBrains Mono', monospace;  /* structure and headers */
  --font-serif: 'Merriweather', serif;       /* descriptions and body */
  --font-sans: 'Inter', sans-serif;          /* utilitarian UI labels and micro-copy */
}
```

### 2. Element Shapes (Strictly Sharp)
- **Radius (rx/ry):** Strictly `0px` (or omitted). No rounded corners on buttons, cards, containers, or component boundaries.
- **Exceptions:** Standard circle elements when required for functional clarity (e.g. status dots or radio selectors).

### 3. Depth & Elevation
- **Flat Philosophy:** No Gaussians, backdrop blurs, glows, or shadows are allowed.
- **Layers:** Defined strictly by 1px solid ink borders and subtle flat tonal background shifts.

---

## Semantic Diagram Components

### Component Stroke & Fill Map
- **Frontend / Client UI:** Outlined in Accent Maroon (`#a03e3d`) with soft red fill (`#fdf2f2`) or transparent.
- **Backend Core / Gateway:** Outlined in Accent Olive (`#0f1900`) with soft green fill (`#f4f8eb`) or transparent.
- **Database Engine / Storage:** Outlined in Charcoal Ink (`#1c1c18`) with surface-container-high fill (`#ebe8e1`) or transparent.
- **Security Perimeter:** Outlined in Error Red (`#ba1a1a`) with soft red fill (`#ffdad6`) or transparent.
- **Generic / External:** Outlined in Charcoal Ink (`#1c1c18`) with transparent fill.
- **Connections / Arrows:** Solid `#1c1c18` ink strokes with standard sharp SVG polygon markers.

### Background Spec Grid
```svg
<pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
  <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#ebe8e1" stroke-width="1"/>
</pattern>
```

---

## Utilitarian HTML & CSS Reference Structure

```html
<style>
  body {
    background-color: var(--color-surface);
    color: var(--color-on-surface);
    font-family: var(--font-serif);
  }
  .diagram-container {
    background-color: var(--color-surface-container);
    border: 1px solid var(--color-primary);
    padding: 2rem;
  }
  h1 {
    font-family: var(--font-mono);
    text-transform: uppercase;
    font-weight: 700;
  }
  .card {
    background-color: var(--color-surface-container);
    border: 1px solid var(--color-primary);
  }
</style>
```
