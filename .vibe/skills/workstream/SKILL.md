---
name: workstream
description: Generate, update, audit, and visualize Obsidian workstream dashboards in /home/b08x/Notebook/Dashboards/. Use when user says /workstream, asks to create/update a project workstream, asks about workstream status, or asks to canvas/visualize a topic across workstreams.
---

# Workstream Dashboard Manager

You are an expert knowledge manager for an Obsidian vault at `/home/b08x/Notebook`. Your job is to create, update, and audit workstream dashboard files that track active software projects.

Vault path:       `/home/b08x/Notebook`
Dashboard dir:    `/home/b08x/Notebook/Dashboards/`
File convention:  `{slug}-Workstream.md`

---

## Context Management — DB First

**All gathered data is stored in a SQLite WAL database. Never stream raw session dumps or large commit logs into the conversation context.**

```
DB path:   ~/.claude/skills/workstream/workstream.db
WAL mode:  always on (journal_mode=WAL, synchronous=NORMAL)
Vec ext:   sqlite-vec (pip install sqlite-vec) for KNN search over SFL chunk embeddings
Scripts:   ~/.claude/skills/workstream/scripts/
```

### Prerequisites (run once per session)

```bash
# Ensure DB is initialised
python3 ~/.claude/skills/workstream/scripts/workstream_db.py init
```

### Core read-back commands (use these instead of raw script stdout)

```bash
# Compact markdown summary safe for context window
python3 ~/.claude/skills/workstream/scripts/workstream_db.py export --slug {slug}

# Recent commits only
python3 ~/.claude/skills/workstream/scripts/workstream_db.py query \
  --slug {slug} --table commits --limit 15

# Recent sessions only
python3 ~/.claude/skills/workstream/scripts/workstream_db.py query \
  --slug {slug} --table sessions --limit 20

# Top SFL chunks (relevance ≥ 0.5)
python3 ~/.claude/skills/workstream/scripts/workstream_db.py query \
  --slug {slug} --table chunks --min-relevance 0.5 --limit 5

# Keyword search across all stored context
python3 ~/.claude/skills/workstream/scripts/workstream_db.py search \
  --query "{topic}" --limit 10

# DB health / per-slug row counts
python3 ~/.claude/skills/workstream/scripts/workstream_db.py status
```

### Data write commands (gather → DB, never to stdout)

```bash
# Gather sessions → write to DB → print compact summary
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug {slug} --days 14 --source both --format db-export

# With SFL analysis
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug {slug} --days 14 --sfl --query "{topic}" \
  --source both --format db-export

# Read from DB only (no new gather)
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug {slug} --read-only --format db-export
```

**Rule:** If `session_query.py` output exceeds ~30 lines, use `--format db-export` and read back via `workstream_db.py export`. Never paste full JSON blobs into the conversation.

---

## Operation Modes

- `/workstream generate {slug}` → MODE: GENERATE
- `/workstream update {slug}` or `/workstream update all` → MODE: UPDATE
- `/workstream audit` → MODE: AUDIT
- `/workstream canvas {intent}` → MODE: CANVAS
- `/workstream tasks {slug}` → show tracked TaskNotes for a slug
- `/workstream tasks sync {slug}` → force re-sync Next Actions → TaskNotes

---

## MODE: GENERATE

### Step 1 — Gather Inputs

Required (ask if missing):
- `slug` — GitHub repo name identifier
- `name` — human-readable project name
- `description` — one-sentence blockquote summary
- `tech_tags` — comma-separated list

### Step 2 — Resolve GitHub Repo

```bash
gh repo list -L 141 --json name,updatedAt,description \
  | python3 -c "import json,sys; repos=[r for r in json.load(sys.stdin) \
    if '{slug}' in r['name'].lower()]; print(json.dumps(repos, indent=2))"
```

### Step 3 — Gather Commits

```bash
# Find repo path
find ~/Workspace ~/WorkspaceV3 -maxdepth 3 -type d -iname "*{slug}*" 2>/dev/null

# Fetch commits (72h first, widen to 30d if empty)
git -C {repo-path} log --oneline --since="72 hours ago" \
  --format="%h|%as|%s" 2>/dev/null | head -15
# if empty:
git -C {repo-path} log --oneline --since="30 days ago" \
  --format="%h|%as|%s" 2>/dev/null | head -15
```

Write commits to DB:
```bash
python3 - <<'EOF'
import sys; sys.path.insert(0, str(__import__('pathlib').Path.home() /
  ".claude/skills/workstream/scripts"))
from workstream_db import open_db, init_schema, upsert_workstream, write_commits
conn = open_db(); init_schema(conn)
upsert_workstream(conn, "{slug}", name="{name}", repo_path="{repo-path}")
write_commits(conn, "{slug}", [
  {"hash": "{h}", "date": "{d}", "message": "{m}"},
  # ... one dict per commit line
])
EOF
```

### Step 4 — Gather Sessions → DB

```bash
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug {slug} --days 14 --sfl --query "{description}" \
  --source both --format db-export
```

Read back compact summary for context:
```bash
python3 ~/.claude/skills/workstream/scripts/workstream_db.py export --slug {slug}
```

### Step 5 — Compose Dashboard

Use only what the DB export returned. Schema:

```markdown
---
title: {name} — Workstream
workstream: {slug}
type: dashboard
tags:
  - dashboard
  - {slug}
  - {tech_tags...}
last updated: {YYYY-MM-DD HH:MM:SS}
---

# {name}

> {description}

## What's Being Built

{1–3 paragraphs from DB export + repo description. Present tense.}

## Recent Commits (72h)

| Hash | Date | Commit |
|------|------|--------|

## Session History (Apr 25 – present)

| Date | Platform | Activity | Msgs |
|------|----------|----------|------|

## Blockers / Current State

-

## Next Actions

- [ ]
```

### Step 6 — Write File

```
/home/b08x/Notebook/Dashboards/{slug}-Workstream.md
```

### Step 7 — Sync Next Actions → TaskNotes

After writing, push unchecked `- [ ]` items to Obsidian TaskNotes:

```bash
python3 ~/.claude/skills/workstream/scripts/tasknotes_sync.py sync \
  --slug {slug} \
  --project "{name}" \
  --priority normal
```

**What it does:**
- Parses `## Next Actions` for `- [ ] text` lines
- Creates a TaskNotes task per item (skips already-tracked ones)
- Rewrites matched lines in the dashboard as `[[Tasks/path|☑ text]]`
- Logs task IDs to workstream DB (table: `tasknotes`) — no duplicates on re-run

**If API is offline** (TaskNotes plugin not running), log the error and continue — the `- [ ]` lines remain unchanged for the next sync attempt.

---

## MODE: UPDATE

### Rules

- **PRESERVE:** `What's Being Built`, `Blockers`, `Next Actions` — never overwrite unless explicitly asked.
- **REFRESH:** `Recent Commits`, `Session History`, `last updated` timestamp.
- **NEVER** fabricate commit hashes, dates, or session data.

### Step 1 — Read Existing File

Use the Read tool. Note exact section boundaries.

### Step 2 — Gather Fresh Data → DB

```bash
# Commits
find ~/Workspace ~/WorkspaceV3 -maxdepth 3 -type d -iname "*{slug}*" 2>/dev/null
git -C {repo-path} log --oneline --since="72 hours ago" --format="%h|%as|%s" \
  2>/dev/null | head -15

# Sessions → DB
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug {slug} --days 7 --source both --format db-export
```

### Step 3 — Read Back Compact Summary

```bash
python3 ~/.claude/skills/workstream/scripts/workstream_db.py export --slug {slug}
```

Use only the rows in this output to update the file. If the export shows no new data, update only `last updated` and note "no new activity".

### Step 4 — Apply Targeted Edits

Use Edit tool for surgical replacements only:
1. `last updated:` → current datetime
2. `## Recent Commits` table rows → replace with DB export rows
3. `## Session History` table → prepend new rows at top

### Step 5 — Sync New Next Actions → TaskNotes

After edits, sync only items that are new since last run:

```bash
python3 ~/.claude/skills/workstream/scripts/tasknotes_sync.py sync \
  --slug {slug} \
  --priority normal
```

Previously created tasks are tracked in the DB — only genuinely new `- [ ]` lines are sent to the API. Already-linked items (wikilinks) are ignored automatically.

### Step 6 — Confirm

Report: sections updated, new commit count, new session count, TaskNotes created, `last updated`.

---

## MODE: AUDIT

### Step 1 — DB Status

```bash
python3 ~/.claude/skills/workstream/scripts/workstream_db.py status
```

### Step 2 — File Metadata

```bash
for f in /home/b08x/Notebook/Dashboards/*-Workstream.md; do
  echo "=== $f ==="
  grep -E "^(workstream:|last updated:)" "$f" | head -2
done
```

### Step 3 — Flag Stale

Calculate days since `last updated`. Flag > 7 days as STALE.

### Step 4 — TaskNotes Status

```bash
# For each slug in audit, show tracked task count
python3 ~/.claude/skills/workstream/scripts/tasknotes_sync.py status --slug {slug}
```

### Step 5 — Output Table

```
| Slug | Last Updated | Days Stale | DB Commits | DB Sessions | Tasks | Status |
|------|-------------|------------|------------|-------------|-------|--------|
```

Suggest `/workstream update {slug}` for each STALE entry.

---

## MODE: CANVAS

### Step 1 — Choose Archetype

| Intent is about… | Archetype |
|---|---|
| Single project | **DEEP DIVE** |
| Theme across projects | **CROSS-WORKSTREAM** (default) |
| Time period | **TIMELINE** |
| Technical concept | **CONCEPT MAP** |

### Step 2 — Gather Data → DB, Read Back Compact

```bash
# Find relevant workstream dashboards
grep -rl "{keyword}" /home/b08x/Notebook/Dashboards/ 2>/dev/null | head -10

# Semantic vault search
ck --sem "{intent}" --threshold 0.4 --topk 8 -l /home/b08x/Notebook

# Session search in DB (no new gather needed for canvas)
python3 ~/.claude/skills/workstream/scripts/workstream_db.py search \
  --query "{intent}" --limit 10

# If SFL analysis not yet run for relevant slugs, gather now:
python3 ~/.claude/skills/workstream/scripts/session_query.py \
  --slug all --days 14 --sfl --query "{intent}" \
  --source both --format db-export

# Read back top chunks with relevance ≥ 0.6
python3 ~/.claude/skills/workstream/scripts/workstream_db.py query \
  --slug all --table chunks --min-relevance 0.6 --limit 8
```

Use `dominant_metafunction` + `task_type` from the chunk query to decide which workstreams and patterns to surface as canvas nodes. Do NOT paste raw combined_text into the canvas — synthesise it.

### Step 3 — Layout (by archetype)

#### DEEP DIVE
```
[Title group]
  [Identity node] → [What's Being Built node]
                     ↓
[Data lane]
  [Commits node] [Sessions node] [Blockers node]
                     ↓
[Links row]
  [file: Workstream.md] [file: related notes] [Next Actions node]
```

#### CROSS-WORKSTREAM
```
[Central topic — color "5" cyan, large]
  → spoke → [Project A node]  → [Implication node]
  → spoke → [Project B node]  → [Implication node]
  → spoke → [Project C node]  → [Implication node]
[Bottom: file nodes for each Workstream.md]
```

#### TIMELINE
```
[Swim lane group: Project A] → [event] → [event] → [event]
[Swim lane group: Project B] → [event] → [event]
[Bottom: Key Events group]
```

#### CONCEPT MAP
```
[Central concept — color "6" purple]
  → [Mechanism] → [Example]
  → [Comparison] → [Tradeoffs]
  → [Application] → [Status / Next]
[Bottom: file nodes for vault research notes]
```

### Step 4 — Build Canvas JSON

**IDs:** 16-char lowercase hex. Generate fresh — never reuse.

**Node types:** `text` (use `\n` not `\\n`), `file` (vault-relative path + `.md`), `group` (set `label` + `color`), `link` (external URLs only)

**Color convention:**
| `"5"` cyan | Central topic |
| `"4"` green | Active project |
| `"3"` yellow | In-progress / blocked |
| `"1"` red | Blocker / risk |
| `"6"` purple | Research / concept |
| `"2"` orange | Session / activity |

**Layout:** groups at `x: -50, y: -50`; nodes spaced 60–80px; widths 280/380/500; groups fully contain children.

**Edges:** `fromSide`/`toSide` ∈ {top, right, bottom, left}; `toEnd: "arrow"`, `fromEnd: "none"`; add `label` when relationship needs naming.

**Validate before writing:**
1. All `fromNode`/`toNode` IDs exist in nodes array
2. No duplicate IDs
3. All text nodes have `text`, file nodes have `file`
4. Group bounds contain all children
5. Valid JSON (no literal newlines in strings)

### Step 5 — Filename

`Dashboards/{Intent-Slug}-{YYYY-MM-DD}.canvas` — max 5 words, hyphenated. Add `-v2` if exists.

### Step 6 — Write, Log to DB, Confirm

```bash
# After writing the .canvas file, log it
python3 - <<'EOF'
import sys; sys.path.insert(0, str(__import__('pathlib').Path.home() /
  ".claude/skills/workstream/scripts"))
from workstream_db import open_db, log_canvas
conn = open_db()
log_canvas(conn, "{filename}", "{intent}", "{archetype}",
           node_count={n}, edge_count={e}, slugs=["{slug1}", ...])
EOF
```

Report: file path, archetype, node/edge count, slugs linked, data sources with no results.

---

## Anti-Patterns

- **NEVER** stream raw session JSON or full commit logs into conversation context — write to DB, read back compact export
- **NEVER** invent commit hashes, session titles, or message counts
- **NEVER** overwrite `What's Being Built`, `Blockers`, or `Next Actions` without explicit user instruction
- **NEVER** use literal `\\n` in canvas JSON strings — use `\n`
- **NEVER** reference canvas `fromNode`/`toNode` IDs that don't exist in nodes array
- **NEVER** run `obsidian eval` in a loop
- **DO NOT** assume repo path — always `find ~/Workspace ~/WorkspaceV3 -maxdepth 3 -type d -iname "*{slug}*"`
- **DO NOT** skip Read before editing an existing file
- **DO NOT** call `tasknotes_sync.py` if the TaskNotes API is known offline — log and continue
- **NEVER** create duplicate tasks — the DB `tasknotes` table is the deduplication store; always run `status` before `sync` if unsure

---

## File Schema Reference

```
---
title: {name} — Workstream
workstream: {slug}
type: dashboard
tags: [dashboard, {slug}, {tech tags}]
last updated: YYYY-MM-DD HH:MM:SS
---
# {name}
> {blockquote}
## What's Being Built
## Recent Commits (72h)
## Session History (Apr 25 – present)
## Blockers / Current State
## Next Actions
```
