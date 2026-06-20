<div align="center">

# workstream

*Keep your projects visible. Keep your context window intact.*

</div>

---

A Claude Code skill for generating, updating, auditing, and visualizing Obsidian workstream dashboards — backed by a SQLite WAL context store so gathered data stops living in the conversation.

The problem it solves is unremarkable: project dashboards go stale, session data accumulates across four different platforms, and feeding all of it to an LLM at once produces the kind of output that technically answers the question. This does something about that.

---

## Features

- **Dashboard generation** — creates `{slug}-Workstream.md` files in `Dashboards/` from live GitHub, commit, and session data; no manual transcription required
- **Surgical updates** — refreshes commits and session history in-place; preserves the narrative sections a human actually wrote
- **WAL context store** — all gathered data lands in a SQLite WAL database at `~/.claude/skills/workstream/workstream.db`; the conversation receives a compact export, not a payload
- **DSPy session pipeline** — chunks session history from Hermes and code-insights, ranks chunks by relevance, then applies SFL metafunction analysis (ideational / interpersonal / textual) and task classification
- **KNN semantic search** — sqlite-vec vec0 table for 768-dim embedding search over processed chunks when `sqlite-vec` is installed
- **Canvas generation** — produces `.canvas` files in four archetypes (DEEP DIVE, CROSS-WORKSTREAM, TIMELINE, CONCEPT MAP) selected automatically from the intent string
- **Staleness audit** — flags workstreams not updated in 7+ days, reports per-slug DB row counts

---

## Installation

<details>
<summary>Python dependencies</summary>

```bash
# Required
pip install dspy-ai

# Optional — enables KNN semantic search over SFL chunk embeddings
pip install sqlite-vec
```

</details>

<details>
<summary>Initialise the DB (run once)</summary>

```bash
python3 ~/.claude/skills/workstream/scripts/workstream_db.py init
```

Expected output:

```
[workstream_db] schema initialised at ~/.claude/skills/workstream/workstream.db
[workstream_db] WAL mode: wal
[workstream_db] sqlite-vec: available   # or: not installed
```

WAL mode is always enabled on open. No further configuration is required for the store to function; `sqlite-vec` absence degrades gracefully to keyword search.

</details>

---

## Usage

### Commands

```
/workstream generate {slug}
/workstream update {slug}
/workstream update all
/workstream audit
/workstream canvas {intent}
```

### Options

**generate**
- `{slug}` — GitHub repo name used as the workstream identifier; the skill resolves the repo path via `find ~/Workspace ~/WorkspaceV3 -maxdepth 3 -type d -iname "*{slug}*"`

**update**
- `{slug}` — target workstream slug, or `all` to refresh every `*-Workstream.md` in `Dashboards/`
- Preserved sections: `What's Being Built`, `Blockers / Current State`, `Next Actions`
- Refreshed sections: `Recent Commits`, `Session History`, `last updated` timestamp

**canvas**
- `{intent}` — free-form string; archetype selection is automatic

| Intent type | Archetype selected |
|---|---|
| Single project name | DEEP DIVE |
| Cross-cutting theme | CROSS-WORKSTREAM *(default)* |
| Time period or "what changed" | TIMELINE |
| Technical concept or decision | CONCEPT MAP |

### Examples

```bash
# Generate a new dashboard from scratch
/workstream generate syncopated-context

# Refresh commits and sessions on one workstream
/workstream update hermes

# Refresh all dashboards in one pass
/workstream update all

# Check which workstreams have gone quiet
/workstream audit

# Visualize how the graphify schema work intersects projects
/workstream canvas graphify schema providers

# Concept map for a technical decision
/workstream canvas AdalFlow vs DSPy optimization tradeoffs

# Temporal view of the last sprint
/workstream canvas what changed week 19
```

---

## Context DB

The WAL store is the main reason gather-heavy update cycles don't collapse the context window. Full session blobs and commit logs are written to the DB; the conversation receives a ~20-line markdown export.

```bash
# Health check and per-slug row counts
python3 ~/.claude/skills/workstream/scripts/workstream_db.py status

# Compact markdown export safe for context window
python3 ~/.claude/skills/workstream/scripts/workstream_db.py export --slug {slug}

# Query a specific table
python3 ~/.claude/skills/workstream/scripts/workstream_db.py query \
  --slug {slug} --table [commits|sessions|chunks] --limit 20

# Filter SFL chunks by metafunction
python3 ~/.claude/skills/workstream/scripts/workstream_db.py query \
  --slug {slug} --table chunks --sfl ideational --min-relevance 0.5

# Keyword search across all stored context
python3 ~/.claude/skills/workstream/scripts/workstream_db.py search \
  --query "blueprint librarian" --limit 10

# Prune rows older than N days and checkpoint the WAL
python3 ~/.claude/skills/workstream/scripts/workstream_db.py prune --days 30
```

### Schema

| Table | Contents |
|---|---|
| `workstreams` | Slug registry; last gather timestamp |
| `commits` | Raw commit rows, deduped by hash |
| `sessions` | Raw session rows from Hermes and code-insights |
| `chunks` | DSPy-processed chunks: relevance score, task type, SFL analysis |
| `chunk_embeddings` | sqlite-vec vec0 table; 768-dim float vectors for KNN |
| `canvases` | Canvas generation log: filename, archetype, node/edge count |
| `kv_store` | Key-value cache for repo metadata and audit state |

---

## Session Pipeline

The session pipeline (`scripts/session_query.py`) gathers from both Hermes and code-insights SQLite databases directly, bypassing any CLI wrappers that might filter or truncate results.

```bash
# Gather sessions → DB → return compact export
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug {slug} --days 14 --source both --format db-export

# With DSPy SFL analysis (slower; requires a configured LM)
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug {slug} --days 14 --sfl --query "gem verification pipeline" \
  --source both --format db-export

# Skip gathering; read the existing DB
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug {slug} --read-only --format db-export

# Keyword search without triggering a gather
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --search "blueprint" --slug all
```

The DSPy pipeline runs three passes per chunk window: relevance scoring against the query, SFL metafunction analysis, and task classification. Results are written to the `chunks` table. The conversation sees the compact export; the pipeline output does not.

---

## SFL Metafunction Analysis

Sessions are classified across three axes derived from Systemic Functional Linguistics:

- **Ideational** — what was constructed, extracted, or transformed; the experiential content of the session
- **Interpersonal** — the stance and agency texture; autonomous vs. directed, exploratory vs. convergent
- **Textual** — the session arc as discourse; how it cohered, where it spiralled, whether it compacted mid-flight

Each chunk receives a `dominant_metafunction`, a `task_type` (scaffold / debug / explore / refactor / extract / optimize / integrate / document / automate / evaluate), and a `metafunction_interaction` description suitable for use as a canvas node label.

The classification is useful for identifying patterns across projects — for instance, whether a given sprint was predominantly interpersonally-driven autonomous execution or ideationally-driven exploratory scaffolding. Whether that distinction matters in practice is left as an exercise.

---

## Data Sources

| Source | Access method | Written to |
|---|---|---|
| GitHub repo metadata | `gh repo list` + `gh repo view` | `workstreams` table |
| Recent commits | `find` + `git log` | `commits` table |
| Hermes sessions | `sqlite3 ~/.hermes/state.db` direct read | `sessions` table |
| code-insights sessions | `sqlite3 ~/.local/share/code-insights/sessions.db` | `sessions` table |
| DSPy SFL chunks | `session_query.py --sfl` | `chunks` + `chunk_embeddings` |
| Semantic vault search | `ck --sem "{intent}"` | canvas mode only; not persisted |
| Obsidian keyword search | `obsidian search` | canvas mode only; not persisted |

---

## Files

```
~/.claude/skills/workstream/
├── SKILL.md                        # Skill instructions for the agent
├── README.md                       # This file
├── workstream.db                   # SQLite WAL context store (created on init)
└── scripts/
    ├── workstream_db.py            # DB schema, read/write helpers, CLI
    └── session_query.py            # Hermes + code-insights gather → DSPy → DB
```

---

## License

MIT
