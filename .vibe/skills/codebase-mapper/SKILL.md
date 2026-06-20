---
name: codebase-mapper
user-invocable: true
description: |
  Map any codebase and generate beautiful, structured markdown documentation with
  Mermaid architecture diagrams. This skill should be used when a user wants to
  document an existing codebase, understand a new project's architecture, generate
  diagrams from code, or produce wiki-style documentation from source files. Uses
  graphify (knowledge graph extraction via tree-sitter AST for 29 languages) and
  optionally the qmd skill (semantic search index) to produce layered, cross-linked
  docs with architecture, call-flow, sequence, and dependency diagrams. Documentation
  prose follows SFL principles: modality matched to evidence quality, transformation
  contracts for modules, and Ruby Pragmatist framing that acknowledges both capability
  and limitation.
---

# Codebase Mapper

Generate beautiful markdown documentation and Mermaid diagrams from any codebase
using graphify (knowledge graph) and qmd (semantic search). The outputs include
architecture overviews, per-module docs, data-flow diagrams, and a design-decision
log — all automatically extracted from source code and comments.

## Companion Skills

**qmd skill** — handles all general qmd usage: query syntax, MCP tools, collection
management, query types (lex/vec/hyde), and CLI reference. Load it when using qmd
for any search operation. This skill only covers what's specific to codebase mapping:
collection setup for source code and per-task query patterns.

**SFL writing guide** (`references/sfl_writing_guide.md`) — governs documentation
prose: process types, modality calibration tied to graphify confidence tags, and
Ruby Pragmatist framing.

## When to Use

- "Document this codebase / repo"
- "Generate architecture diagrams for this project"
- "Explain how this codebase is structured"
- "Create a wiki for this code"
- "Map the dependencies / call flow of this project"
- "What are the key modules / god nodes in this repo?"

## Workflow

### Step 1 — Build the knowledge graph

Run `scripts/map_codebase.sh` against the target directory. Installs graphify
if needed, builds the knowledge graph, exports call-flow HTML, and sets up the
qmd collection with AST-aware chunking.

```bash
bash scripts/map_codebase.sh [TARGET_DIR]

# Options:
#   --skip-qmd         skip qmd setup (faster, no semantic enrichment later)
#   --skip-graphify    skip graph build (use existing graphify-out/)
```

Outputs in `graphify-out/`:
- `GRAPH_REPORT.md` — god nodes, surprising connections, suggested questions, design rationale
- `graph.json` — full knowledge graph (nodes + edges with EXTRACTED/INFERRED/AMBIGUOUS tags)
- `wiki/` — per-concept markdown files (one per module/class/concept)
- `*-callflow.html` — Mermaid architecture and call-flow diagrams

### Step 2 — Extract diagrams

```bash
python3 scripts/extract_mermaid.py [callflow.html] [--out-dir ./diagrams]
```

Pulls Mermaid blocks from the callflow HTML into `diagrams/diagrams.md`. If no
callflow HTML exists, synthesizes an architecture diagram from the top-connected
nodes in `graph.json`. See `references/mermaid_patterns.md` for diagram types.

### Step 3 — Read the writing guide

Before generating documentation, read `references/sfl_writing_guide.md`. It defines:
- Three process types and which leads each doc section
- Modality calibration: EXTRACTED → strong; INFERRED → medium; AMBIGUOUS → weak + dashed arrows
- Transformation contract pattern (required for every module doc)
- Ruby Pragmatist insight formula (required for README, architecture, each module)

### Step 4 — Generate documentation

Follow `references/doc_structure.md` for templates. Structure:

- `docs/README.md` — transformation contract + god nodes table + architecture diagram
- `docs/architecture.md` — component relationship map + data flow pipeline + design rationale
- `docs/modules/<name>.md` — per module, led by transformation contract
- `docs/data-flow.md` — sequence diagram of the primary operation
- `docs/decisions.md` — WHY/NOTE/HACK comments from the graph

**graphify output → doc section mapping:**

| graphify Output | → Doc Section | Modality |
|---|---|---|
| God nodes (GRAPH_REPORT.md) | README "Key Concepts" table | Match graphify tag |
| Surprising connections | README "Surprising Connections" | Note confidence |
| Suggested questions | README closing section | Direct copy |
| WHY/NOTE/HACK nodes | decisions.md | INFERRED unless explicit comment |
| wiki/ files | docs/modules/<name>.md | Supplement with transformation contracts |
| Callflow HTML diagrams | architecture.md + data-flow.md | EXTRACTED (AST-derived) |
| AMBIGUOUS edges | Dashed Mermaid arrows + "may"/"possibly" prose | Weak modality |

### Step 5 — Semantic enrichment with qmd

Use the **qmd skill** for query mechanics. For codebase-specific patterns —
which query type (lex/vec/hyde) to use for each documentation task, batch
module retrieval, and how to combine graphify + qmd confidence — read
`references/qmd_codebase_patterns.md`.

**Task → qmd pattern quick reference:**

| Documentation Task | Query Type | Reference |
|---|---|---|
| "What does X do?" | `vec` + `lex` (identifier) | qmd_codebase_patterns.md |
| Design rationale | `lex` ("# WHY") + `vec` | qmd_codebase_patterns.md |
| Limitations & edge cases | `hyde` (limitation comment) + `lex` (TODO/FIXME) | qmd_codebase_patterns.md |
| Data flow tracing | `vec` + `intent` | qmd_codebase_patterns.md |
| Batch module source read | `multi_get` (glob or docids) | qmd skill + qmd_codebase_patterns.md |

**Confidence when combining sources:**
- graphify EXTRACTED + qmd confirms → strong modality
- graphify INFERRED + qmd finds explicit comment → upgrade to EXTRACTED
- graphify AMBIGUOUS + qmd finds nothing → keep dashed arrow + "possibly"
- qmd only (graphify missed it) → INFERRED modality, note the source

## Key Outputs

| File | Contents | Primary Doc Section |
|------|----------|---------------------|
| `graphify-out/GRAPH_REPORT.md` | God nodes, connections, questions | README + architecture |
| `graphify-out/wiki/*.md` | Per-concept markdown | docs/modules/ |
| `graphify-out/graph.json` | Full graph (queryable: `graphify query "..."`) | Deep-dive |
| `diagrams/diagrams.md` | Mermaid diagrams embedded | architecture.md |

## Diagram Types

Read `references/mermaid_patterns.md` for complete patterns:

- **Architecture** (`flowchart TD`) — module layers; AMBIGUOUS edges use `-.->` 
- **Call flow** (`sequenceDiagram`) — request/response between components
- **Data model** (`classDiagram`) — entities and relationships
- **State machine** (`stateDiagram-v2`) — entity lifecycle
- **Dependency** (`flowchart LR`) — import graph

Limit 8–15 nodes per diagram. Use `subgraph` for visual layers. Label edges
with verb phrases. Style god nodes:
`classDef god fill:#f59e0b,stroke:#d97706,color:#000,font-weight:bold`

## Graphify Features

- **God nodes** — highest-degree nodes; anchor the relational map. Highlight in
  README "Key Concepts" table and in Mermaid with `:::god` style.
- **Confidence tags** drive modality throughout:
  - EXTRACTED → strong modality, solid arrows
  - INFERRED → "typically", "appears to", solid arrows with note
  - AMBIGUOUS → "may", "possibly", dashed arrows (`-.->`) + verification note
- **Design rationale nodes** — graphify extracts `# NOTE:`, `# WHY:`, `# HACK:`
  comments. Populate decisions.md. Modality: EXTRACTED for decision text,
  INFERRED for consequences.
- **`--mode deep`** — for larger/complex codebases; surfaces more cross-module edges.
- **`--update`** — re-extracts only changed files after code changes.

## SFL Writing (Summary)

Full guide in `references/sfl_writing_guide.md`. Core rules:

1. Each section leads with its dominant process type (architecture → relational; modules → material)
2. Transformation contract opens every module doc
3. graphify confidence tags determine modality — never hedge EXTRACTED facts, always hedge AMBIGUOUS ones
4. No "always"/"never" without benchmark evidence
5. Limitations documented with same specificity as capabilities
6. Ruby Pragmatist insight required for README, architecture.md, and each module doc

## Anti-Patterns

| ❌ | ✅ |
|---|---|
| "Understands your codebase" | "Parses 29 languages via tree-sitter; semantic meaning depends on user-supplied context" |
| "Automates documentation" | "Generates per-concept markdown from graph node metadata and source docstrings" |
| "Provides insights" | "Extracts function-level relationships as edges tagged EXTRACTED or INFERRED" |
| "Always accurate" | "EXTRACTED edges derive from AST; AMBIGUOUS edges are flagged for manual verification" |
