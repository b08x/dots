# SFL Writing Guide for Codebase Documentation

Systemic Functional Linguistics (SFL) applied to technical documentation
produces prose that is precise, honest about uncertainty, and useful to
readers at different levels of familiarity. This guide distills the
principles most relevant to codebase documentation.

---

## The Three Process Types

Every sentence in technical documentation expresses one of three process types.
Knowing which type you're writing helps you pick the right structure and verb.

| Process Type | What It Describes | Key Verbs | Example |
|---|---|---|---|
| **Material** | What the system *does* — transformations, data flows, outputs | transforms, produces, generates, processes, validates, emits | "The router **transforms** raw HTTP requests into typed handler calls" |
| **Mental** | What users *experience* — understanding, decisions, cognitive load | discovers, learns, typically finds, may expect, often requires | "Users **typically discover** the graph query API after exploring the wiki output" |
| **Relational** | How components *connect* — dependencies, classifications | depends on, enables, requires, is part of, coordinates with | "The embedding layer **requires** the vector index **for** semantic retrieval" |

**Practical rule**: Each major documentation section should lead with its
dominant process type. Architecture sections → relational. Data flow sections
→ material. Getting started / onboarding → mental.

---

## Modality Calibration

Modality is how certain you sound. Match it to your evidence quality.
This is especially important in codebase docs because sources vary in reliability —
code comments, architecture diagrams, and runtime behavior don't always agree.

| Evidence Quality | Language to Use | Examples |
|---|---|---|
| **Verified** — tested, in code, measurable | "**does / is / transforms / returns**" (no hedging) | "The parser **returns** an AST node for each declaration" |
| **Observable pattern** — consistent but not guaranteed | "**typically / generally / usually / often**" | "Users **typically reach** module proficiency after 2–3 integration sessions" |
| **Inferred** — reasoned from context | "**likely / appears to / suggests / may**" | "The batching logic **likely reduces** DB round-trips under high write load" |
| **Ambiguous / user-dependent** | "**varies based on / depends on / may differ**" | "Response latency **varies based on** graph size and cluster density" |

### Mapping graphify Confidence Tags to Modality

graphify tags every extracted relationship. Use these to set modality automatically:

| graphify Tag | Meaning | Modality Language | Mermaid Style |
|---|---|---|---|
| `EXTRACTED` | Directly found in source | Verified — no hedging | Solid arrow `-->` |
| `INFERRED` | Deduced from indirect evidence | "likely", "appears to" | Solid with note |
| `AMBIGUOUS` | Uncertain or conflicting signals | "may", "varies", "possibly" | Dashed arrow `-.->` |

When graphify marks a relationship AMBIGUOUS, write: "X **may coordinate with** Y
(relationship inferred from naming conventions; verify in [module])" — not "X
**coordinates with** Y."

---

## The Transformation Contract Pattern

For module and component documentation, the **Transformation Contract** is the
most honest and precise format. It answers: what goes in, what comes out, and
under what conditions?

```
[Component Name] **transforms** [specific inputs]
**into** [specific outputs]
**through** [verified processing steps]
**when** [operating conditions].
```

**Example (well-formed):**
> The embedding pipeline **transforms** raw source file chunks (≤900 tokens each)
> **into** cosine-comparable float vectors **through** the EmbeddingGemma-300M
> model **when** the qmd embed command is run against an indexed collection.

**Anti-patterns to avoid:**

| ❌ Overclaiming | ✅ Transformation Contract |
|---|---|
| "Provides comprehensive code insights" | "Extracts function-level relationships as graph edges tagged EXTRACTED or INFERRED" |
| "Automates documentation" | "Generates per-concept markdown files from graph node metadata and source docstrings" |
| "Understands your codebase" | "Parses 29 languages via tree-sitter AST; semantic meaning depends on user-supplied context" |
| "Always accurate" | "Achieves [X]% edge-extraction accuracy on benchmarks; AMBIGUOUS tags flag uncertain relationships" |

---

## Data Flow Pipeline Format

For sequences of transformations (indexing, build pipelines, request flows), use
the numbered pipeline format with `→` chains:

```
1. **[Input Stage]**: [sources] **provide** [data format] **at** [frequency/trigger] **through** [mechanism]
2. **[Transform Stage]**: [component] **converts** [input form] **into** [output form] **using** [algorithm/logic]
3. **[Validation Stage]**: [validator] **verifies** [quality criteria] **producing** [clean data / error report]
4. **[Output Stage]**: [formatter] **produces** [deliverable format] **for** [consumer]
```

Pair with a `flowchart` or `sequenceDiagram` so readers see the same flow visually
and in prose.

---

## Dependency Documentation Pattern

For every significant dependency, document three things: what it provides,
what breaks if it fails, and how the system mitigates that.

```
**[Dependency Name]**: **provides** [service/data] **via** [protocol/interface]
  - **Failure impact**: [what degrades or breaks]
  - **Mitigation**: [fallback, circuit breaker, degraded mode]
```

**Example:**
> **graphify (tree-sitter AST extraction)**: **provides** structural relationship
> edges for 29 languages **via** local process (no API calls for code files).
> - **Failure impact**: extraction falls back to heuristic/import-based relationships only
> - **Mitigation**: confidence tags downgrade to INFERRED; GRAPH_REPORT.md flags gaps

---

## Ruby Pragmatist Framing

Each major documentation section benefits from a one- or two-sentence analogy
that reveals both capability and limitation. The analogy should be *precise*, not
just comforting. Avoid: "like having a senior developer on call." Prefer analogies
that surface trade-offs.

**Formula:**
> [Component] works like [analogy that reveals mechanism] — **[what it does well]
> while [what requires human input / has limits]**, much like [familiar comparison
> that sets honest expectations].

**Example for a codebase mapper:**
> The knowledge graph works like an X-ray rather than an MRI — it **maps structural
> relationships quickly and completely** while **surface anatomy (naming, imports,
> calls) is clear but soft-tissue meaning (intent, domain logic) requires human
> interpretation**, much like how a wiring diagram shows connections but not the
> reason each circuit exists.

---

## Section-Level Writing Guide

### README / Overview

Lead with **relational process** (what this system is part of / what it enables),
then **material process** (what it transforms), then **mental process** (what the
reader will understand).

Structure:
1. One-sentence purpose (relational)
2. Transformation contract (material)
3. Key concepts table (god nodes → relational)
4. Architecture diagram (relational + material)
5. What varies by context (mental / conditional modality)

### Module Documentation

Lead with **material process** (transformation contract), then **relational**
(dependencies and what it enables), then **mental** (what's confusing / what users
typically misunderstand).

Use EXTRACTED/INFERRED/AMBIGUOUS modality throughout.

### Architecture Documentation

Lead with **relational process** (component relationship map), then **material**
(data flow pipeline), then **mental** (design reasoning — WHY decisions were made).

Include a Ruby Pragmatist insight that acknowledges the dominant architectural
trade-off (e.g., latency vs. consistency, simplicity vs. extensibility).

### Decisions / Rationale

This section is pure **mental process** — document what the team understood,
what they considered, and what they chose. Use `# WHY:` / `# NOTE:` / `# HACK:`
patterns extracted by graphify. Modality: often medium (patterns) rather than
high (verified), since reasoning is inferred from comments.

---

## Quality Checklist

Before publishing any generated documentation section, verify:

**Ideational (Field) — Process Type Coverage**
- [ ] Material processes specify inputs, transformations, outputs, and circumstances
- [ ] Relational processes map dependencies and what each component enables
- [ ] Mental processes address the user cognitive journey and likely confusion points

**Interpersonal (Tenor) — Modality Calibration**
- [ ] Verified claims use strong modality ("does / is / transforms")
- [ ] Pattern-based claims use medium modality ("typically / generally / often")
- [ ] graphify AMBIGUOUS edges use weak modality ("may / varies / possibly")
- [ ] No absolute modality ("always / never") without benchmark evidence

**Textual (Mode) — Information Organization**
- [ ] Each section leads with its dominant process type
- [ ] Diagrams appear before their prose explanation
- [ ] Transformation contracts present before dependency lists
- [ ] Ruby Pragmatist framing present for each major section
- [ ] Cross-links between module docs reflect the graph structure

**Anti-patterns removed**
- [ ] No vague capability claims ("provides insights", "understands code")
- [ ] No confidence overclaiming relative to graphify tags
- [ ] Limitations documented with the same specificity as capabilities
