# QMD Codebase Query Patterns

This file covers codebase-mapper-specific qmd usage. For general qmd usage —
query syntax, MCP tools, collection management, query types — refer to the **qmd skill**.

## Collection Setup (Codebase-Specific)

`scripts/map_codebase.sh` handles this automatically, but if running manually:

```bash
qmd collection add [TARGET_DIR] --name codebase
qmd context add qmd://codebase "Source code for [project name] — used for documentation enrichment"
qmd update
qmd embed --chunk-strategy auto   # AST-aware chunking for code files (TS, JS, Python, Go, Rust)
```

`--chunk-strategy auto` is important for codebases: it uses tree-sitter to chunk at
function/class boundaries instead of arbitrary token positions, producing better
search results for code-oriented queries.

---

## Query Patterns by Documentation Task

### Module Documentation — "What does X do?"

Best combination: `vec` for narrative + `lex` for implementation detail.

**MCP:**
```json
{
  "searches": [
    { "type": "vec", "query": "how does [ModuleName] work and what does it produce" },
    { "type": "lex", "query": "[ClassName] [primaryMethod]" }
  ],
  "collections": ["codebase"],
  "limit": 8
}
```

**CLI:**
```bash
qmd query $'vec: how does AuthManager work and what does it produce\nlex: AuthManager authenticate' \
  -c codebase --md
```

Use output to fill the transformation contract and Key Components table in
`docs/modules/<name>.md`.

---

### Design Rationale — "Why was X built this way?"

`lex` for explicit comment markers + `vec` for implicit reasoning.

**MCP:**
```json
{
  "searches": [
    { "type": "lex", "query": "\"# WHY\" OR \"# NOTE\" OR \"# HACK\" [concept]" },
    { "type": "vec", "query": "design decision rationale [concept] tradeoff" }
  ],
  "collections": ["codebase"],
  "intent": "architectural reasoning and implementation decisions"
}
```

**CLI:**
```bash
# Find all explicit rationale comments
qmd search "# WHY" -c codebase --full --all --min-score 0.3

# Semantic search for reasoning around a concept
qmd query "why was [concept] designed this way" -c codebase --md
```

Use output to populate `docs/decisions.md` entries. Cross-reference with
graphify's extracted WHY/NOTE/HACK nodes — qmd may surface comments graphify
didn't extract as graph nodes.

---

### Limitations & Edge Cases — "Where does X break down?"

`hyde` is best here: write what a limitation comment looks like, find similar ones.

**MCP:**
```json
{
  "searches": [
    { "type": "hyde", "query": "This function does not handle the case where [concept] exceeds [limit]. Known limitation: performance degrades when [condition]. Edge case: [scenario] is not supported." },
    { "type": "vec", "query": "limitation edge case not supported [module]" },
    { "type": "lex", "query": "TODO FIXME \"not supported\" \"known issue\"" }
  ],
  "collections": ["codebase"]
}
```

**CLI:**
```bash
qmd query "known limitations edge cases [module]" -c codebase --md
```

Use output for the "Known Limitations" section in module docs, with INFERRED
modality unless the comment is explicit (then EXTRACTED).

---

### Data Flow Tracing — "How does data move through X?"

`vec` + `lex` targeting entry points and transformation steps.

**MCP:**
```json
{
  "searches": [
    { "type": "vec", "query": "how data flows through [pipeline/feature] from input to output" },
    { "type": "lex", "query": "[entryFunction] transform process pipeline" }
  ],
  "collections": ["codebase"],
  "intent": "data transformation sequence and processing steps"
}
```

Use output to verify / supplement the sequence diagram in `docs/data-flow.md`.

---

### Dependency Discovery — "What does X depend on?"

`lex` for import statements + `vec` for conceptual dependencies.

**MCP:**
```json
{
  "searches": [
    { "type": "lex", "query": "import require [ModuleName]" },
    { "type": "vec", "query": "dependencies required by [ModuleName] to operate" }
  ],
  "collections": ["codebase"]
}
```

Compare results against graphify's dependency edges. EXTRACTED in graphify
(AST-derived) takes precedence; qmd results supplement with runtime/dynamic
dependencies that static analysis may miss.

---

### Batch Module Retrieval — Read Multiple Files

For bulk context when generating several module docs at once, use `multi_get`
rather than running individual queries:

**MCP:**
```json
// mcp__qmd__multi_get
{
  "path": "src/auth/**/*.ts",
  "maxLines": 80
}
```

**CLI:**
```bash
# By glob — all files in a module directory
qmd multi-get "src/auth/**/*.ts" -l 80

# By comma-separated list (preserves order)
qmd multi-get "src/auth/manager.ts,src/auth/session.ts,src/auth/permissions.ts"

# By docids from search results
qmd multi-get "#abc123,#def456,#ghi789"
```

Use `multi_get` when you need to read the actual source of several modules
before writing their transformation contracts — faster than individual `get` calls.

---

## Query Type Selection Guide (Codebase Context)

| Documentation Task | Best Query Type | Why |
|---|---|---|
| Find a specific class/function | `lex` | Exact identifier match |
| "How does X work" | `vec` | Semantic — vocabulary unknown |
| Find limitation-style comments | `hyde` | Match comment vocabulary |
| Find `# WHY` / `# NOTE` comments | `lex` | Exact prefix match |
| Architectural reasoning | `vec` + `intent` | Disambiguate from unrelated "design" uses |
| Verify graphify relationships | `lex` (function names) | Ground-truth check |
| Find usage examples | `lex` (function name) + `vec` | Both exact and contextual |

---

## Enrichment Workflow for Each Doc Section

```
docs/README.md          ← graphify GRAPH_REPORT.md (primary)
                           qmd: vec "project overview purpose" (supplement)

docs/architecture.md    ← graphify callflow HTML (primary)
                           qmd: vec "architecture design decisions" (rationale)

docs/modules/<n>.md     ← graphify wiki/<n>.md (primary)
                           qmd multi_get: source files (transformation contract)
                           qmd lex: "# WHY" "# NOTE" in module (rationale)

docs/data-flow.md       ← graphify sequence diagrams (primary)
                           qmd vec: "data flow [feature]" (verify/supplement)

docs/decisions.md       ← graphify WHY/NOTE/HACK nodes (primary)
                           qmd lex: "# WHY" --full (catch any graphify missed)
                           qmd hyde: limitation comment pattern (edge cases)
```

**Confidence when combining sources:**
- graphify EXTRACTED + qmd confirms → strong modality
- graphify INFERRED + qmd finds explicit comment → upgrade to EXTRACTED
- graphify AMBIGUOUS + qmd finds nothing → keep dashed arrow + "possibly"
- qmd only (graphify missed it) → INFERRED modality, note the source
