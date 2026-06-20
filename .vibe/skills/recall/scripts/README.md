# Session Recall Scripts

Multi-platform session extraction and correlation with normalized schema.

## Quick Start

```bash
# Standard recall - last 7 days, all platforms
python3 scripts/recall_workflow.py

# Extended timeframe with GitHub
python3 scripts/recall_workflow.py --days 14 --github-repo owner/repo

# Topic search
python3 scripts/recall_workflow.py --search "authentication" --days 30
```

## Architecture

```
recall_workflow.py          # Main orchestration (4-stage pipeline)
    │
    ├── Stage 1: Extraction
    │   └── normalized_sessions.py   # Multi-provider extraction
    │       ├── ClaudeProvider       # ~/.claude/projects/*/*.jsonl
    │       ├── HermesProvider       # ~/.hermes/state.db (SQLite)
    │       ├── GeminiProvider       # ~/.gemini/tmp/<hash>/chats/*.json
    │       └── OpenCodeProvider     # ~/.local/share/opencode/opencode.db
    │
    ├── Stage 2: Correlation
    │   └── normalized_sessions.py
    │       ├── GitHub integration (gh cli)
    │       ├── Restic backup analysis
    │       └── DSPy synthesis (with heuristic fallback)
    │
    ├── Stage 3: Search
    │   └── normalized_sessions.py
    │       └── Topic keyword matching
    │
    └── Stage 4: One Thing
        └── normalized_sessions.py
            └── DSPy OneThingGenerator signature
```

## Normalized Schema

All providers output unified `ParsedSession`:

```python
@dataclass
class ParsedSession:
    id: str
    project_path: str
    project_name: str
    summary: Optional[str]
    generated_title: Optional[str]
    started_at: datetime
    ended_at: datetime
    message_count: int
    user_message_count: int
    assistant_message_count: int
    tool_call_count: int
    source_tool: str              # 'claude' | 'hermes' | 'gemini' | 'opencode'
    usage: SessionUsage
    messages: List[ParsedMessage]
```

## Scripts

### recall_workflow.py

**Purpose:** Orchestrate complete 4-stage recall pipeline

**Usage:**
```bash
python3 scripts/recall_workflow.py [OPTIONS]

Options:
  --days N           Days to analyze (default: 7)
  --platforms LIST   Comma-separated providers (default: all)
  --github-repo REPO GitHub repo in owner/name format
  --search QUERY     Optional topic search query
  --output DIR       Output directory (default: /tmp/recall-output)
```

**Output:**
- `/tmp/recall-output/sessions_*.json` - Extracted sessions
- `/tmp/recall-output/correlation_*.json` - Timeline + synthesis
- `/tmp/recall-output/search_results.json` - Search matches (if --search)

### normalized_sessions.py

**Purpose:** Multi-provider extraction, normalization, and correlation

**Commands:**
```bash
# Extract from all providers
python3 scripts/normalized_sessions.py extract --days 7

# Extract from specific providers
python3 scripts/normalized_sessions.py extract --platforms claude,hermes --days 7

# Correlate with GitHub
python3 scripts/normalized_sessions.py correlate --days 7 --github-repo owner/repo

# Search by topic
python3 scripts/normalized_sessions.py search "authentication" --days 30

# Output to file
python3 scripts/normalized_sessions.py extract --days 7 --output sessions.json
```

**DSPy Signatures:**
- `SessionTopicExtractor` - Extract topics, files, actions from session
- `CommitSessionCorrelator` - Match commits to relevant sessions
- `TimelineSynthesizer` - Generate narrative from multi-source timeline
- `OneThingGenerator` - Single highest-leverage next action

### Legacy Scripts (Deprecated)

| Script | Status | Replacement |
|--------|--------|-------------|
| `extract-sessions.py` | Legacy | Use `normalized_sessions.py extract --platforms claude` |
| `multi-platform-extract.py` | Deprecated | Use `normalized_sessions.py extract` |
| `recall-day.py` | Deprecated | Use `recall_workflow.py --days 1` |
| `session-graph.py` | Legacy | Still available for graph visualization |

## Critical Fixes Applied

### Gemini Path Correction

**Before:** `~/.gemini/antigravity/conversations/*.json`

**After:** `~/.gemini/tmp/<project_hash>/chats/*.json`

The `GeminiProvider` now correctly resolves project hashes from `~/.gemini/projects.json`.

### Hermes SQLite Access

**Before:** `hermes sessions export` CLI dependency

**After:** Direct read-only SQLite queries to `~/.hermes/state.db`

Eliminates CLI dependency and improves reliability.

### Schema Normalization

All providers now output identical field names:

| Before (varied) | After (unified) |
|-----------------|-----------------|
| `timestamp` / `created_at` / `startedAt` | `started_at` |
| `numMessages` / `message_count` | `message_count` |
| `project` / `projectPath` / `project_path` | `project_path` |

## Output Examples

### Extraction Output

```json
{
  "claude": [
    {
      "id": "session_abc123",
      "project_name": "my-project",
      "generated_title": "Authentication refactor",
      "started_at": "2025-03-25T09:30:00",
      "message_count": 45,
      "source_tool": "claude"
    }
  ],
  "hermes": [...],
  "gemini": [...]
}
```

### Correlation Output

```json
{
  "timeline": [
    {
      "type": "session",
      "platform": "claude",
      "timestamp": "2025-03-25T09:30:00",
      "summary": "Authentication refactor discussion"
    },
    {
      "type": "commit",
      "platform": "github",
      "timestamp": "2025-03-25T09:45:00",
      "data": {"message": "WIP: auth middleware"}
    }
  ],
  "correlation": {
    "narrative": "Activity across 3 platforms focused on authentication...",
    "workstreams": ["auth refactor", "session management", "testing"],
    "next_actions": ["Complete auth middleware", "Add session tests"]
  }
}
```

### One Thing Output

```
ONE THING: Complete the session timeout fix from your Hermes debugging 
session by merging PR #23 and updating the auth middleware tests.

Reasoning: Highest momentum topic (auth) spanning 3 platforms with 
recent commits and unblocked path to completion.
```

## Dependencies

- **Required:** Python 3.10+
- **Optional:** DSPy (for LLM-powered synthesis)
- **Optional:** GitHub CLI (`gh`) for GitHub integration
- **Optional:** Restic for backup analysis

Without DSPy, the system falls back to deterministic heuristics for correlation and synthesis.
