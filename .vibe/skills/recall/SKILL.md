---
name: recall
description: Multi-platform AI harness session recall across Claude Code, Gemini CLI, OpenCode, and Hermes. Auto-discovers and correlates GitHub activity from all repos with recent commits. Handles temporal queries and cross-platform session aggregation with intelligent contextual chunking.
license: MIT
allowed-tools:
  - read_file
  - write_file
  - grep
  - ask_user_question
  - bash
  - qmd_*
  - trackboi_switch_project
  - trackboi_add_track_decision
  - trackboi_move_card
  - trackboi_get_track
metadata:
  author: b08x
  version: "1.2.0"
  category: productivity
---

# Multi-Platform Recall

Comprehensive AI harness session recall across Claude Code, Gemini CLI, OpenCode, and Hermes, plus **Obsidian notes**, **Local Git activity**, and **GitHub commits from all repos with recent activity**. 

**New in v1.2.0**: Automatically discovers and correlates commits from all GitHub repositories where you've been active in the specified timeframe - no need to manually specify repos anymore!

Every recall ends with the **One Thing** - a concrete, highest-leverage next action synthesized from cross-platform results.

## Architecture Overview

The system is built as a modular Python package (`recall/`) that enforces strict separation of concerns between data models, provider-specific extraction, AI analysis, and core orchestration.

### Package Structure

- **`recall/models.py`**: Unified dataclasses (`ParsedSession`, `ParsedMessage`, `SessionUsage`, etc.) ensuring schema consistency across all platforms.
- **`recall/providers/`**: Platform-specific extractors (Gemini, Hermes, Claude Code, OpenCode, Obsidian, Local Git) inheriting from a common `BaseProvider`.
- **`recall/ai/`**: 
    - `signatures.py`: DSPy signatures for semantic analysis.
    - `modules.py`: DSPy modules for topic extraction and timeline synthesis.
    - `chunking.py`: **Contextual Chunking Strategy** for handling long sessions.
- **`recall/core.py`**: Orchestrates providers and AI processing into a unified timeline.
- **`scripts/recall_cli.py`**: Unified entry point for all operations.

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Claude Code    │     │   Gemini CLI     │     │    Hermes       │
│  Mistral-Vibe   │     │   OpenCode       │     │   + others      │
└────────┬────────┘     └────────┬─────────┘     └────────┬────────┘
         │                       │                         │
         │          All synced to unified database         │
         │                       ▼                         │
         └───────────►  ┌─────────────────────┐  ◄────────┘
                        │  CODE-INSIGHTS DB   │
                        │  ~/.code-insights/  │
                        │   data.db           │
                        └──────────┬──────────┘
                                   │
                                   ▼
    ┌───────────────────────────────────────────────────────────┐
    │          UNIFIED CODE-INSIGHTS PROVIDER                   │
    │     (Single source for all AI harness sessions)           │
    └────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
    ┌───────────────────────────────────────────────────────────┐
    │               CONTEXTUAL CHUNKING LAYER                   │
    │      (Intelligent message grouping for LLM context)       │
    └────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
    ┌───────────────────────────────────────────────────────────┐
    │               DSPy CORRELATION & ANALYSIS                 │
    │      (Timeline Synthesis + One Thing Generation)          │
    └────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
    ┌───────────────────────────────────────────────────────────┐
    │               OUTPUTS (CLI, JSON, Obsidian)               │
    └───────────────────────────────────────────────────────────┐
```

## Key Features

- **Multi-platform aggregation**: Correlates sessions from all major AI tools via unified code-insights database.
- **Auto-discovery GitHub Integration**: Automatically finds and correlates commits from all repos where you've been active - no manual repo specification needed!
- **Contextual Chunking**: Intelligently groups messages based on temporal gaps (>30 mins) and semantic boundaries (user directives + assistant execution) to prevent context loss in long sessions.
- **Unified Schema**: All data is normalized before analysis, ensuring consistent results regardless of the source.
- **Integrated Insights**: Combines session data with auto-discovered GitHub commits, local git logs, and Obsidian notes.
- **Automated Visualization**: Generates temporal dashboards and interactive canvases in Obsidian.
- **Export Integration** (v1.3.0): Optional export to graphify/QMD via code-insights skill for knowledge graph generation.

## Platform Session Locations

All AI harness sessions are now unified through the code-insights database:

| Platform | Session Storage | Access Method | Format |
|----------|----------------|---------------|--------|
| **All AI Harnesses** | `~/.code-insights/data.db` | Unified SQLite database | SQLite |
| ↳ Claude Code | Synced to code-insights | Via code-insights provider | Unified schema |
| ↳ Gemini CLI | Synced to code-insights | Via code-insights provider | Unified schema |
| ↳ Hermes Agent | Synced to code-insights | Via code-insights provider | Unified schema |
| ↳ OpenCode | Synced to code-insights | Via code-insights provider | Unified schema |
| ↳ Mistral-Vibe | Synced to code-insights | Via code-insights provider | Unified schema |
| Obsidian | `~/Notebook/*.md` | Recursive Markdown scan | Markdown |
| Local Git | `~/Workspace/**/.git` | Recursive git log scan | Git |

## Workflow Script

The primary interface is `scripts/recall_workflow.py` which orchestrates the following pipeline:

1.  **EXTRACTION**: Uses `recall_cli.py` to pull normalized sessions from specified platforms.
2.  **ANALYSIS (Optional)**: Applies contextual chunking and DSPy topic extraction to individual sessions.
3.  **CORRELATION**: Integrates GitHub/Git activity and restic backups into a unified timeline.
4.  **SYNTHESIS**: Generates a narrative summary and identifies the **One Thing** next action.
5.  **VISUALIZATION**: Updates Obsidian dashboards and canvases.

### CLI Usage

**Basic recall workflow:**
```bash
# Full workflow (last 7 days)
python3 scripts/recall_workflow.py --days 7

# With specific platform filtering
python3 scripts/recall_workflow.py --days 7 --platforms claude-code,gemini-cli

# With GitHub repo specification
python3 scripts/recall_workflow.py --days 7 --github-repo owner/repo

# Skip GitHub integration
python3 scripts/recall_workflow.py --days 7 --no-github
```

**With export integration (NEW in v1.3.0):**
```bash
# Export to graphify after recall
python3 scripts/recall_workflow.py --days 7 --export-graphify

# Export to QMD after recall
python3 scripts/recall_workflow.py --days 7 --export-qmd

# Both exports
python3 scripts/recall_workflow.py --days 7 --export-graphify --export-qmd
```

**Low-level session extraction:**
```bash
# Extract sessions from all platforms (last 7 days)
PYTHONPATH=. python3 scripts/normalized_sessions.py extract --days 7 --platforms all

# Extract from specific tools only
PYTHONPATH=. python3 scripts/normalized_sessions.py extract --days 7 --platforms claude-code,gemini-cli

# Full correlation with AUTO-DISCOVERY
PYTHONPATH=. python3 scripts/normalized_sessions.py correlate --days 7

# Search across aggregated sessions
PYTHONPATH=. python3 scripts/normalized_sessions.py search "authentication" --days 30

# Available source tools: claude-code, gemini-cli, hermes-agent, opencode, mistral-vibe
```

## Contextual Chunking Strategy

To handle long-running sessions that might exceed LLM context windows or contain multiple distinct topics, the system uses a `ContextualChunker`:

1.  **Temporal Splits**: Automatically starts a new chunk if there is a gap of >30 minutes between messages.
2.  **Semantic Integrity**: Ensures tool calls and their results are kept within the same chunk.
3.  **User-Led Boundaries**: Prefers splitting at user messages (which typically introduce new instructions) when character limits (default 8,000) are reached.

## GitHub Auto-Discovery

The recall skill now automatically discovers all repositories where you have commit activity within the specified timeframe, eliminating the need to manually specify repos.

### How It Works

1. **Authentication**: Uses your authenticated `gh` CLI session
2. **Commit Search**: Queries GitHub for all commits by you in the timeframe using `gh search commits --author=USERNAME --author-date=>=DATE`
3. **Repo Extraction**: Extracts unique repository names from the commit results
4. **Commit Aggregation**: Fetches detailed commit data from each discovered repo
5. **Timeline Integration**: Incorporates all commits into the unified correlation timeline

### Modes of Operation

| Mode | Command | Behavior |
|------|---------|----------|
| **Auto-discovery** (default) | `correlate --days 7` | Finds all repos with your commits |
| **Manual specification** | `correlate --days 7 --github-repo owner/repo` | Uses only the specified repo |
| **Skip GitHub** | `correlate --days 7 --no-github` | Local sessions only, no GitHub |

### Requirements

- Authenticated `gh` CLI (`gh auth login`)
- GitHub API access (automatic with `gh`)
- No rate limiting concerns (uses efficient GitHub Search API)

## DSPy Signatures

The correlation engine uses structured signatures for synthesis:

```python
class SessionTopicExtractor(dspy.Signature):
    """Extract topics/actions from a session chunk."""
    session_content: str = dspy.InputField()
    topics: List[str] = dspy.OutputField()
    files_touched: List[str] = dspy.OutputField()
    key_actions: List[str] = dspy.OutputField()

class TimelineSynthesizer(dspy.Signature):
    """Synthesize coherent narrative from timeline events."""
    sessions: List[Dict] = dspy.InputField()
    commits: List[Dict] = dspy.InputField()
    narrative: str = dspy.OutputField()
    workstreams: List[str] = dspy.OutputField()

class OneThingGenerator(dspy.Signature):
    """Generate single highest-leverage next action."""
    recent_activity: str = dspy.InputField()
    one_thing: str = dspy.OutputField()
```

## Anti-Hallucination & Evidence-Based Synthesis

- **Evidence Requirement**: A "Workstream" MUST be backed by a Git commit, substantial assistant content (>5 messages), or documented file modifications.
- **Template Isolation**: Never carry over "Active Projects" from previous recalls unless validated by *current* data.
- **Zero Tolerance for Fluff**: Narratives must focus on kinetic energy (work done) rather than potential (untracked folders or empty files).

## Usage Patterns

### Temporal Recall (with auto-discovery)
- `/recall yesterday` (all platforms + auto-discovered GitHub repos)
- `/recall last 3 days` (auto-discovers repos with activity)
- `/recall last 7 days --no-github` (skip GitHub entirely)
- `/recall 2026-04-15 to 2026-04-17`

### Manual Repo Specification (backward compatible)
- `/recall last 3 days --github-repo owner/my-repo` (specific repo only)
- `/recall yesterday --github-repo owner/project` (manual specification)

### Platform/Topic Focused
- `/recall platform:gemini auth work`
- `/recall search "refactoring"`
- `/recall platform:claude code review`

## Performance & Integration

- **Extraction Speed**: ~30 seconds for a full weekly recall.
- **DSPy Synthesis**: 10-15 seconds per analysis.
- **Persistent Memory**: Correlated insights and platform usage patterns are stored in the memory system for cross-session optimization.

## Integration with Other Skills

### code-insights Skill

recall now integrates with the code-insights skill for optional export functionality:

```bash
# Timeline + knowledge graph export
python3 recall_workflow.py --days 7 --export-graphify

# Timeline + QMD semantic search index
python3 recall_workflow.py --days 7 --export-qmd
```

**What this does:**
1. recall extracts sessions and generates timeline (as usual)
2. After completion, calls code-insights skill to export sessions
3. Sessions are indexed by graphify or QMD for semantic search
4. You get both temporal view (recall) and spatial view (knowledge graph)

**Use cases:**
- "Show me my work timeline AND create a knowledge graph"
- "Generate recall dashboard and make it searchable with QMD"

### knowledge-synthesizer Skill

recall complements the knowledge-synthesizer skill:

- **recall**: Temporal "what did I do?" across all sources (AI + GitHub + git)
- **knowledge-synthesizer**: Project-specific dashboards with friction analysis

**Output locations:**
- recall: `~/Notebook/Dashboards/Recall Dashboard {date}.md`
- knowledge-synthesizer: `~/Notebook/Dashboards/{project}-Sessions.md`

**Recommended workflow:**
```bash
# 1. Extract recent sessions
/code-insights extract recent --hours 168

# 2. Generate project dashboards (knowledge-synthesizer auto-triggers)

# 3. Generate cross-platform timeline
python3 recall_workflow.py --days 7

# Now you have both spatial (per-project) and temporal (cross-platform) views
```

### Workflow Decision Tree

```
User wants to...

├─ "What did I work on last week?" (temporal view)
│  → Use recall skill
│     python3 recall_workflow.py --days 7
│
├─ "Show me patterns/friction in project X" (spatial view)
│  → Use code-insights skill
│     /code-insights patterns --project X
│
├─ "Create project dashboards from sessions"
│  → Use knowledge-synthesizer
│     "synthesize sessions"
│
└─ "Everything - timeline + project dashboards + knowledge graph"
   1. /code-insights extract recent --hours 168
   2. [knowledge-synthesizer auto-triggers]
   3. python3 recall_workflow.py --days 7 --export-graphify
   4. Review outputs in ~/Notebook/Dashboards/
```
