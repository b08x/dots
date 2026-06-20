---
name: code-insights
description: Extract and analyze AI coding sessions from code-insights SQLite database. Query sessions by time/project/source, correlate friction patterns, export to graphify/QMD.
trigger: /code-insights
version: 1.0.0
author: b08x
---

# Code-Insights Skill

Query and analyze AI coding sessions from the code-insights database (`~/.code-insights/data.db`).

## Commands

### Extract & Query
```bash
# Extract recent sessions
/code-insights extract recent --hours 6 --source claude-code --limit 20

# List sessions by project
/code-insights sessions --project ceda22e2013e495c --since "last week"

# Filter by session character
/code-insights sessions --character deep_focus --limit 10

# Show statistics
/code-insights stats
```

### Pattern Analysis
```bash
# Find sessions with specific friction category
/code-insights patterns --category knowledge-gap --project ceda22e2013e495c

# Show recurring friction patterns
/code-insights patterns --recurring --project ceda22e2013e495c --min-occurrences 3

# High-confidence insights
/code-insights insights --project ceda22e2013e495c --confidence 0.9
```

### Export & Integration
```bash
# Export single session (all formats)
/code-insights export --session <id>

# Export with specific format
/code-insights export --session <id> --format markdown

# Export and index with graphify
/code-insights export --session <id> --graphify

# Export recent sessions and index with QMD
/code-insights export --recent 6 --qmd-index

# Correlate multiple sessions
/code-insights correlate --sessions <id1>,<id2>,<id3> --output json
/code-insights correlate --sessions <id1>,<id2> --output graphify
```

## Addressing User Goals

**Goal 1: Patterns of failure to update agents/skills**
```bash
/code-insights patterns --category knowledge-gap --project <id> --since "30 days ago"
```

**Goal 2: Manual patterns to automate**
```bash
/code-insights patterns --recurring --min-occurrences 3 --project <id>
```

**Goal 3: Prompting techniques to improve**
```bash
/code-insights insights --project <id> --confidence 0.8
# Then filter by type=prompt_quality
```

**Goal 4: Fine-grained friction & effective patterns**
```bash
# Export sessions for correlation
/code-insights export --recent 6 --qmd-index

# Search across sessions
ruby lib/integrations.rb --qmd --search "repeated merge conflicts"
```

## Database Schema

**Primary Tables:**
- `sessions` (2.3K rows): Multi-source session metadata
- `messages` (80K rows): Conversation history  
- `session_facets` (1.8K rows): Friction points, effective patterns
- `insights` (11K rows): Cross-session learnings

**Source Tools:** claude-code, opencode, gemini-cli, mistral-vibe, hermes-agent, crush, antigravity, codex-cli

## Implementation

See `lib/session_discovery.rb` for core query patterns.

## Export Directory Structure

Sessions are exported with human-readable directory names:

```
~/.code-insights/exports/sessions/
├── pdca-guided-recursive-refactor_2026-05-16_cf4bc34/
│   ├── session.json           # Full session data
│   ├── conversation.md        # Markdown conversation
│   ├── messages.jsonl         # Line-delimited messages
│   ├── metadata.json          # Session metadata
│   └── graphify-out/
│       └── graph.json        # Knowledge graph
├── skill-driven-git-commit_2026-05-16_9042cb0/
└── ...
```

**Naming Format:** `{sanitized-title}_{date}_{short-uuid}/`

- **Title**: Extracted from custom_title or generated_title, sanitized for filesystem
- **Date**: Session start date (YYYY-MM-DD)
- **Short UUID**: First 7 characters of session ID for uniqueness

## References

- Planning: `.vibe/.trackboi/cards/card-code-insights-skill-v1-implementation-plan-17zyeyp/`
- Database: `~/.code-insights/data.db`
- Exports: `~/.code-insights/exports/sessions/`
- Changelog: `~/.claude/skills/code-insights/CHANGELOG.md`
