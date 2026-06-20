---
name: architecture-diagram
description: "High-density technical blueprint architecture diagrams using the Paper & Ink aesthetic."
version: 1.1.0
author: Cocoon AI, ported and redesigned by Antigravity Agent
license: MIT
dependencies: []
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [architecture, diagrams, SVG, HTML, paper-ink, brutalism, blueprint]
    related_skills: [concept-diagrams, excalidraw]
---

# ARCHITECTURE DIAGRAM SPECIFICATION SHEET

Generate high-density technical blueprints and system architecture diagrams as standalone HTML files with inline SVG graphics. Styled strictly with the **Paper & Ink** visual system, these diagrams mimic archival specifications, engineering journals, and blueprint schematics.

---

## I. FUNCTIONAL SCOPE

| BEST SUITED FOR | NOT SUITED FOR |
| :--- | :--- |
| Software architecture layers (Client/Server/DB) | Narrative journeys or textbook-style stories |
| VPC, cloud regions, networks, subnets | Physics, biology, or raw scientific illustrations |
| API mapping, microservices topology | Animated visuals (use animation skills) |
| High-density physical-matter schematics | Hand-drawn board sketches (use excalidraw) |

---

## II. SYSTEM GENERATION WORKFLOW

### STEP 1: INITIAL RECONNAISSANCE
Before generating, inspect the project's visual parameters:
1. Search the codebase for custom styles, palettes, or design documents (`docs/architecture/index.md`).
2. If custom design tokens are specified, adapt the diagram colors/style to match.
3. If no custom visual system is declared, enforce the default **Paper & Ink** visual standard.

### STEP 2: BUILD THE SPEC FILE
- Build a self-contained, high-density HTML file containing all styles and SVGs inline.
- Save to `./[project-name]-architecture.html` using the `write_to_file` tool.
- Suggested preview command:
  ```bash
  # macOS: open file | Linux: xdg-open file
  open ./[project-name]-architecture.html
  ```

---

## III. VISUAL TOKEN ARCHITECTURE (PAPER & INK)

The visual design rejects blurs, shadows, gradients, and rounded corners in favor of flat physical-matter limitations.

```
┌──────────────────────────────────────────────────────────────┐
│ CORE PALETTE & STYLING RULES                                 │
├──────────────────────────────────────────────────────────────┤
│ Surface Background: Warm unbleached paper (#fcf9f2)          │
│ Ink Outline & Text: Rich technical charcoal (#1c1c18)        │
│ Corner Shape:       Strictly sharp 90-degree corners (rx="0")│
│ Dividers & Borders: Thin 1px solid ink lines                 │
└──────────────────────────────────────────────────────────────┘
```

### 1. SEMANTIC COLOR MAP
Use specific hex fills and strokes to categorize diagram components:

| COMPONENT TYPE | OUTLINE STROKE (HEX) | SHAPE FILL (HEX / RGBA) |
| :--- | :--- | :--- |
| **Frontend / Client UI** | `#a03e3d` (Maroon) | `#fdf2f2` (Light Maroon) / transparent |
| **Backend Core API** | `#0f1900` (Olive) | `#f4f8eb` (Light Olive) / transparent |
| **Database Engine** | `#1c1c18` (Charcoal Ink) | `#ebe8e1` (Surface Container High) |
| **Cloud Infrastructure** | `#7b776e` (Outline Grey) | `#e5e2db` (Surface Container Highest) |
| **Security / Perimeter** | `#ba1a1a` (Error Red) | `#ffdad6` (Light Red) / transparent |
| **Generic / External** | `#1c1c18` (Charcoal Ink) | `#fcf9f2` (Surface) / transparent |

### 2. TYPOGRAPHY MATRIX
All fonts must load from Google Fonts using `'JetBrains Mono'`, `'Merriweather'`, and `'Inter'`:

| ROLE | FAMILY | UTILITY |
| :--- | :--- | :--- |
| **Headers & Codes** | `'JetBrains Mono'`, monospace | Diagram titles, component titles, ports, metrics |
| **Body Content** | `'Merriweather'`, serif | Explanations, cards lists, long technical prose |
| **Utilitarian UI** | `'Inter'`, sans-serif | Routing labels, annotations, legend keys, metadata |

---

## IV. TECHNICAL SVG DESIGN SPECIFICATIONS

### 1. COMPONENT DRAWING
- **Corner Radius:** All `<rect>` components must use `rx="0" ry="0"` (strictly sharp).
- **Z-Order Layering:** Connection lines must be rendered *early* in the SVG source (immediately after the grid pattern) to sit cleanly behind component cards.
- **Dashed Boundaries:**
  - *Subnets / Internal Groups:* Dashed ink boundaries (`stroke-dasharray="4,4"`).
  - *Cloud VPC Regions:* Amber/grey boundaries with wide dashes (`stroke-dasharray="8,4"`).

### 2. GRID & ARROWS
- **Blueprint Grid:** 40px grid pattern in muted grey lines:
  ```svg
  <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
    <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#ebe8e1" stroke-width="1"/>
  </pattern>
  ```
- **Connection Lines:** Solid 1.5px `#1c1c18` strokes ending in sharp polygon markers.
- **Security / Auth Paths:** Dashed lines in Error Red (`#ba1a1a`).

### 3. AUTOMATIC LEGEND ALIGNMENT
- Always place the Legend Key inside a dedicated box with a 1px border.
- The legend must not overlap components or boundaries. Calculate bounds carefully.

---

## V. SPECIFICATION ARCHITECTURE

Generated HTML documents conform to a 4-block layout:
1. **Title Block:** Utilizes an uppercase `'JetBrains Mono'` title, high-contrast specs badge, and `'Inter'` description.
2. **Main SVG Canvas:** The blueprint grid contained in a bordered diagram card.
3. **High-Density Info Cards:** A 3-column flat grid with `#a03e3d` maroon markers (`■`) for specification lists.
4. **Footer:** Printed spec metadata.

---

## VI. REFERENCE DIRECTORY

- **Base Layout Template:** [template.html](file:///templates/template.html) (Core CSS, layout, and visual components reference).
- **Paper & Ink Guidelines:** [warm-cream-palette.md](file:///references/warm-cream-palette.md) (Alternative specs and visual guidelines).
