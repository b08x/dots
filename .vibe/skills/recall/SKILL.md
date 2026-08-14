---
name: recall
description: Use when user asks to recall work across multiple AI platforms (Claude Code, Antigravity, OpenCode, Hermes), correlate with GitHub activity, or analyze file changes from backups. Handles temporal queries, topic searches, and cross-platform session aggregation. Triggers on "recall", "what did we work on", "session history across platforms", "multi-platform recall", "GitHub commits", "backup diffs", "restic changes".
argument-hint: [yesterday|today|last week|TOPIC|platform:PLATFORM_NAME|github:REPO|backup:PATH]
allowed-tools: Bash(python3:*), Bash(hermes:*), Bash(antigravity:*), Bash(opencode:*), Bash(gh:*), Bash(restic:*)
---

# Multi-Platform Recall Skill

Comprehensive session recall across Claude Code, Antigravity, OpenCode, and Hermes with GitHub activity correlation and backup diff analysis. Every recall ends with the **One Thing** - a concrete, highest-leverage next action synthesized from cross-platform results.

## What It Does

- **Multi-platform session aggregation**: Extracts and correlates sessions from all major AI platforms
- **GitHub integration**: Pulls commit history, PR activity, and file changes for contextual insights
- **Backup correlation**: Analyzes restic incremental diffs to show file evolution over time
- **Temporal correlation**: Aligns session timestamps with commits and file changes
- **Cross-platform synthesis**: Identifies work patterns and connections across different tools
- **One Thing generation**: Synthesizes the single most impactful next action from all sources

## Platform Session Locations

| Platform | Session Storage | Export Command | Format |
|----------|----------------|----------------|--------|
| Claude Code | `~/.claude/projects/*/` | Native JSONL parsing | JSONL |
| Hermes | SQLite store | `hermes sessions export` | JSONL |
| Antigravity | `~/.gemini/antigravity-cli/brain/*/` | JSONL file parsing | JSONL |
| OpenCode | `~/.local/share/opencode/opencode.db` | SQLite query | SQLite |
| Code-Insights | `~/.code-insights/data.db` | Hybrid RAG SQLite query | SQLite (FTS5 + Vec) |

## Common Baseline Failure Patterns

Based on testing, agents without this skill exhibit these failures:

| Failure Pattern | Agent Rationalization | Reality |
|-----------------|----------------------|---------|
| "I can only search current directory" | "Assumes user is in wrong repo" | Need to access platform-specific storage locations |
| "Cannot access other AI tools" | "No capability to read session files" | Each platform has documented storage and export methods |
| "GitHub requires authentication" | "Assumes complex API integration needed" | `gh cli` handles auth and provides simple commands |
| "Backup analysis too complex" | "Restic integration unclear" | Restic has straightforward diff commands |
| "Generic next steps instead of actual data" | "Better to give advice than admit limitations" | Users need actual session content, not suggestions |

## Anti-Rationalization Guards

**Red Flags - STOP and Use This Skill:**
- "I can only search the current directory"
- "I don't have access to your other AI tools"
- "GitHub integration would require complex setup"
- "Let me suggest some next steps instead"
- "You should manually check your sessions"
- "Multi-platform capabilities don't exist in the current skill"
- "The expanded features aren't implemented yet"

**Reality Check:** Every major AI platform provides session export/access. This skill documents exactly how AND provides the implementation script.

**If you catch yourself saying these things:**
1. Check the query classification in `workflows/recall.md`
2. Look for multi-platform indicators (mentions of "platforms", "across tools", etc.)
3. Use `multi-platform-extract.py` script instead of falling back to Claude-only recall
4. The script exists at `scripts/multi-platform-extract.py` - use it

**Critical:** Don't fall back to old behavior when user asks for multi-platform recall. Use the expanded implementation.

## Usage Patterns

### Temporal Recall
```
/recall yesterday                    # All platforms, yesterday
/recall last week across platforms   # Multi-platform aggregation
/recall 2025-03-25 with github      # Include GitHub activity
/recall this week with backups      # Include restic diffs
```

### Platform-Specific
```
/recall platform:hermes last 3 days # Hermes only
/recall platform:antigravity auth work   # Antigravity sessions on "auth"
/recall platform:claude code review # Claude Code sessions on "code review"
```

### Integrated Analysis
```
/recall github:myrepo auth commits   # GitHub commits + related sessions
/recall backup:~/Workspace changes  # File changes + session correlation
/recall cross-platform debugging    # All sources for "debugging" topic
```

## Implementation

### 1. Platform Session Extraction

**Claude Code (Current Implementation)**
```python
# Use existing extract-sessions.py
python3 scripts/extract-sessions.py --days 7 --source ~/.claude/projects/PROJECT
```

**Hermes Sessions**
```bash
# Export to JSONL
hermes sessions export -
```

**Antigravity Sessions**
```bash
# Parse JSONL session files
find ~/.gemini/antigravity-cli/brain/ -name "transcript.jsonl" -mtime -7 -exec cat {} \;
```

**OpenCode Sessions**
```python
# SQLite query over local opencode DB
# Extracts sessions and associated message/part tables
sqlite3 ~/.local/share/opencode/opencode.db "SELECT id, created_at, title, messages FROM sessions ORDER BY created_at DESC LIMIT 100;"

# Get sessions from specific date range
sqlite3 ~/.local/share/opencode/opencode.db "SELECT id, created_at, title, messages FROM sessions WHERE created_at >= '2025-03-25' AND created_at <= '2025-03-26' ORDER BY created_at DESC;"

# Export as JSON for correlation
sqlite3 -json ~/.local/share/opencode/opencode.db "SELECT id, created_at, title, messages FROM sessions WHERE created_at >= '2025-03-25' ORDER BY created_at DESC;"
```

**Code-Insights Sessions**
```python
# SQLite query over local data.db
# Uses FTS5 keyword and sqlite-vec vector search (Hybrid RAG) for topic filtering
# Handled via _extract_codeinsights_sessions in scripts/multi-platform-extract.py
```

### 2. GitHub Integration

```bash
# Get commits for date range
gh api repos/:owner/:repo/commits --method GET \
  --field since="2025-03-25T00:00:00Z" \
  --field until="2025-03-26T23:59:59Z" \
  --jq '.[] | {sha: .sha, message: .commit.message, date: .commit.author.date}'

# Get PR activity
gh pr list --state all --limit 20 --json number,title,createdAt,updatedAt
```

### 3. Restic Backup Correlation

```bash
# List snapshots for date range
restic snapshots --insecure-no-password -r $RESTIC_REPO --json | jq '.[] | select(.time >= "2025-03-25" and .time <= "2025-03-26")'

# Diff between snapshots
restic diff SNAPSHOT1 SNAPSHOT2 --json
```

### 4. Temporal Correlation Engine

```python
# Correlate sessions with commits and file changes
def correlate_timeline(sessions, commits, backup_diffs):
    timeline = []
    for session in sessions:
        session_time = parse_timestamp(session['timestamp'])

        # Find nearby commits (±30 minutes)
        nearby_commits = [c for c in commits
                         if abs(parse_timestamp(c['date']) - session_time).seconds < 1800]

        # Find file changes from backups
        relevant_changes = [d for d in backup_diffs
                           if session_overlaps_files(session, d['changed_files'])]

        timeline.append({
            'session': session,
            'commits': nearby_commits,
            'file_changes': relevant_changes
        })

    return timeline
```

### 5. Cross-Platform Synthesis

The **One Thing** synthesis process:
1. **Pattern Detection**: Identify common themes across platforms
2. **Momentum Analysis**: What has forward progress vs. what's stalled
3. **Blocker Identification**: What's preventing completion
4. **Leverage Calculation**: Highest-impact next action

## Workflow

See `workflows/multi-platform-recall.md` for complete routing logic and step-by-step correlation process.

## Integration with Persistent Memory

When configured with the memory system:
- Cross-platform patterns stored as user memories
- Failed correlation attempts stored as feedback memories
- Project-specific session insights stored as project memories
- Platform usage patterns tracked for optimization

## Intelligent Extraction Decision Tree

The recall script automatically decides between **direct extraction** and **qmd indexing** based on query characteristics, avoiding context overflow while keeping fast queries fast.

### Decision Nodes (Priority Order)

| Node | Condition | Mode | Reasoning |
|------|-----------|------|-----------|
| **Topic Search** | Query has 3+ words (not a date) | `index-then-search` | Semantic lookup via qmd |
| **Long Range** | Date span > 7 days | `index-only` | Avoid massive extraction |
| **Large Count** | Estimated sessions > 50 | `index-only` | Context overflow protection |
| **Multi-Platform** | 3+ platforms queried | `index-then-search` | Aggregation complexity |
| **Default** | Simple temporal query | `direct` | Fast path |

### How It Works

```python
# The decision tree runs automatically in auto mode
# Override with --mode flag if needed

python3 multi-platform-extract.py "Ruby RAG"           # → index-then-search (topic)
python3 multi-platform-extract.py last 30 days        # → index-only (long range)
python3 multi-platform-extract.py --mode direct yesterday  # → direct (forced)
```

### Session Count Estimation

Based on platform-specific heuristics (~sessions/day):
- **Claude Code**: 8/day
- **Hermes**: 5/day
- **Antigravity**: 2/day
- **OpenCode**: 1/day

Multiplied by days in range, capped at 200.

### Index Freshness

The system checks for an existing index at `~/.recall-index/`:
- If index is < 24 hours old and matches date range → **reuse**
- Otherwise → **rebuild**

Force rebuild: delete `~/.recall-index/` or use `--mode index`

## Modular RAG with qmd

For large recall queries (e.g., "last month until today"), use qmd to index sessions and search incrementally without holding all context.

### Workflow

```
1. Extract & Index:  python3 scripts/multi-platform-extract.py --index /tmp/recall-index
2. Search:           python3 scripts/multi-platform-extract.py --search "authentication" --index /tmp/recall-index
3. Iterate:          Refine queries without re-extracting sessions
```

### Index & Search Commands

```bash
# Step 1: Extract sessions and build qmd index
python3 scripts/multi-platform-extract.py --index ~/recall-index last month

# Step 2: Search indexed sessions (multiple times, low context)
python3 scripts/multi-platform-extract.py --search "ruby code" --index ~/recall-index
python3 scripts/multi-platform-extract.py --search "debugging session" --index ~/recall-index --search-type hybrid

# Search types:
#   --search-type sem      # Semantic (conceptual similarity) - DEFAULT
#   --search-type lex      # Lexical (BM25 full-text)
#   --search-type hybrid   # Combined regex + semantic (RRF)
#   --search-type regex    # Traditional grep-style pattern matching

# Control result count:
#   --topk 10              # Return only top 5 results
```

### When to Use Modular RAG

| Scenario | Approach |
|----------|----------|
| "Recall what I worked on yesterday" | Direct extraction (fast) |
| "Last month across all platforms" | Extract + qmd-index, then search |
| "Find sessions about X" | Search existing index |
| Iterative exploration of past work | qmd queries |

### Index Structure

```
~/recall-index/
├── sessions/               # Individual session files
│   ├── hermes_20260315_143022_abc123.txt
│   ├── claude_20260314_091500_def456.txt
│   └── ...
└── summary.json            # Metadata about the index

Note: qmd sqlite index is stored globally in ~/.cache/qmd/<index-name>.sqlite
```

### Benefits

- **Constant context**: Search queries use minimal context regardless of date range
- **Incremental exploration**: Iteratively refine searches without re-extracting
- **Multiple views**: Same index supports semantic, lexical, and regex search
- **Portable**: Index directory can be copied to other machines
- **Graceful degradation**: If `qmd` is not installed or indexing fails, the system automatically falls back to direct extraction

## Performance Notes

- **Session extraction**: Parallel processing across platforms (~30 seconds for 7 days)
- **qmd indexing**: Automatic; incremental updates on subsequent searches
- **GitHub API**: Rate limited to 5000 requests/hour
- **Restic operations**: I/O bound, cache snapshot lists
- **Correlation engine**: Memory intensive for large datasets, use streaming for >1000 sessions
- **Modular RAG**: Bypasses correlation engine for search-only queries
