---
name: knowledge-synthesizer
description: Auto-trigger after /code-insights extract to orchestrate comprehensive knowledge synthesis. Creates workstream dashboards from code-insights session data, delegates subagents for parallel data gathering and parsing, generates Obsidian dashboards/canvases, and optionally imports to NotebookLM. Use whenever code-insights extraction finishes, when user wants to visualize coding sessions, create research dashboards, or synthesize multi-platform AI session data into actionable outputs. Trigger on phrases like "synthesize sessions", "create dashboard from code-insights", "visualize my coding work", or automatically after any /code-insights extract completes.
---

# Knowledge Synthesizer

Orchestrates comprehensive knowledge synthesis from code-insights session data into Obsidian workstream dashboards, canvases, and optional NotebookLM notebooks. This skill acts as a higher-level workflow coordinator that ties together code-insights, workstream, and notebooklm capabilities.

## Prerequisites

Before starting, verify these tools are available:

```bash
# Check code-insights database exists
test -f ~/.code-insights/data.db && echo "✓ code-insights DB found" || echo "✗ code-insights DB missing"

# Check code-insights skill
ls ~/.vibe/skills/code-insights/SKILL.md

# Check workstream skill and DB
ls ~/.vibe/skills/workstream/SKILL.md
python3 ~/.claude/skills/workstream/scripts/workstream_db.py status

# Check NotebookLM (optional)
which notebooklm
notebooklm status 2>/dev/null || echo "NotebookLM not available (optional)"

# Check for required Ruby/Python packages
ruby -v && python3 -c "import sqlite3; print('Dependencies OK')"
```

**If prerequisites fail**: Stop immediately and tell user what's missing. Do not proceed with best-effort.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    KNOWLEDGE SYNTHESIZER                      │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  STEP 1: Validate Code-Insights Data                         │
│  - Check if code-insights DB exists and has recent sessions  │
│  - Query session count and date range                        │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  STEP 2: Extract & Parse Projects (Parallel Subagents)       │
│  ┌────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Query      │  │ Extract      │  │ Analyze      │         │
│  │ Sessions   │  │ Patterns     │  │ Friction     │         │
│  └────────────┘  └──────────────┘  └──────────────┘         │
│  Query code-insights DB for sessions, group by project_id    │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  STEP 3: User Choice (Ask)                                   │
│  - Show detected projects from sessions                      │
│  - Ask which outputs to create                               │
│  - Confirm scope before proceeding                           │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  STEP 4: Sequential Synthesis (Per Project)                  │
│  FOR EACH PROJECT:                                           │
│    1. Gather project-specific sessions from code-insights DB │
│    2. Extract friction patterns and insights                 │
│    3. Create/update Obsidian dashboard                       │
│    4. Create canvas visualization if requested               │
│    5. Update TaskNotes from identified actions               │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  STEP 5: Optional NotebookLM Import                          │
│  - Export sessions via /code-insights export                 │
│  - Import session transcripts as NotebookLM sources          │
│  - Create Q&A note with citations                            │
│  - Link to dashboards                                        │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  OUTPUTS CREATED                                             │
│  ✓ Obsidian dashboards (one per project)                     │
│  ✓ Canvas visualizations (optional)                          │
│  ✓ NotebookLM notebook (optional)                            │
│  ✓ TaskNotes synced from identified actions                  │
└──────────────────────────────────────────────────────────────┘
```

## Workflow

### Step 1: Validate Code-Insights Data

**When this skill triggers**, code-insights should have recent session data. Validate using the code-insights skill:

```bash
# Check database exists (validation only)
test -f ~/.code-insights/data.db || { echo "ERROR: code-insights DB not found"; exit 1; }

# Use code-insights skill to check for recent sessions
ruby ~/.vibe/skills/code-insights/code-insights stats
```

**If no sessions found**: Ask user if they want to run `/code-insights extract recent --hours 168` first. Do not proceed without session data.

**If sessions exist**: Use the code-insights skill (NOT direct queries) to gather data:

```bash
# Get sessions by project (use code-insights skill)
ruby ~/.vibe/skills/code-insights/code-insights sessions --project X --since "7 days ago"

# Get friction patterns (use code-insights skill)
ruby ~/.vibe/skills/code-insights/code-insights patterns --project X --recurring

# Get insights (use code-insights skill)
ruby ~/.vibe/skills/code-insights/code-insights insights --project X --confidence 0.8
```

**Why use code-insights skill?**
- Single source of truth for queries
- Better error handling
- Consistent JSON output
- Reuses existing query logic

### Step 2: Extract & Parse Projects

Launch **parallel subagents** to query code-insights database and extract project information:

#### Subagent 1: Session Aggregator
```
Task: Use code-insights skill to get sessions grouped by project
- Call: ruby code-insights sessions --since "7 days ago"
- Parse JSON output to extract unique project_ids
- Group by project_id with session counts
- Get session metadata (titles, sources, durations)
- Output: JSON with {project_id, session_count, sources[], date_range}
```

#### Subagent 2: Friction Pattern Analyzer
```
Task: Use code-insights skill to extract friction patterns
- For each project_id:
  - Call: ruby code-insights patterns --project {id} --recurring --min-occurrences 2
- Parse JSON output for friction categories
- Identify recurring issues per project (knowledge-gap, tool-limitation, etc.)
- Output: JSON with {project_id, friction_patterns[], top_categories[]}
```

#### Subagent 3: Insights Extractor
```
Task: Use code-insights skill to extract actionable insights
- For each project_id:
  - Call: ruby code-insights insights --project {id} --confidence 0.8
- Parse JSON output for high-confidence learnings
- Group insights by type
- Output: JSON with {project_id, insights[], actionable_items[]}
```

**Wait for all subagents to complete.** Aggregate their outputs into a unified project analysis.

### Step 3: User Choice

Present detected projects and ask what to create:

```markdown
I found activity in these projects from your recall:

1. **project-alpha** (12 commits, 8 sessions, last active 2 hours ago)
2. **ml-pipeline** (3 commits, 15 sessions, last active yesterday)
3. **documentation** (0 commits, 4 sessions, notes only)

What would you like me to create?
```

Use AskUserQuestion tool with:
- **Question 1**: "Which projects should I create workstream dashboards for?" (multi-select)
- **Question 2**: "Additional outputs?" (Canvas visualization, NotebookLM import, Obsidian Base)

**If user selects nothing**: Abort gracefully with "No outputs selected. Run `/synthesize` again when ready."

### Step 4: Sequential Synthesis (Per Project)

For each selected project, create Obsidian dashboards using code-insights session data:

**Workflow per project**:

1. **Gather project-specific data using code-insights skill**:
   ```bash
   # Use code-insights skill (NOT direct SQL queries)
   ruby ~/.vibe/skills/code-insights/code-insights sessions \
     --project {project_id} --since "7 days ago"
   
   # Export sessions for the project
   ruby ~/.vibe/skills/code-insights/code-insights export \
     --session {session_id} --format markdown
   
   # Get friction patterns
   ruby ~/.vibe/skills/code-insights/code-insights patterns \
     --project {project_id} --recurring
   ```
   
   **Important**: Use the code-insights skill interface, not direct SQLite queries. This ensures:
   - Consistent output format (JSON)
   - Better error handling
   - Single source of truth for query logic
   - Easier maintenance

2. **Create Obsidian dashboard**:
   - Use workstream skill pattern but adapt for code-insights data
   - Include: session timeline, friction patterns, insights, next actions
   - **Add cross-reference section** linking to recall dashboards:
     ```markdown
     ## Related Dashboards
     - [[Recall Dashboard {date}]] - Temporal timeline across all platforms
     - See: `Dashboards/Recall Dashboard *.md` for cross-platform views
     ```
   - Save to `~/Notebook/Dashboards/{project_name}-Sessions.md`

3. **If canvas requested**, create visualization:
   - Central node: Project name
   - Session nodes: Timeline or grouped by character/source
   - Friction nodes: Recurring patterns
   - Action nodes: Extracted from insights
   - Save to `~/Notebook/Dashboards/{project_name}-Canvas-{date}.canvas`

4. **Extract and sync action items**:
   - Parse insights for actionable items
   - Create TaskNotes entries if TaskNotes is available
   - Link tasks back to dashboard

### Step 5: Optional NotebookLM Import

**Only if user selected NotebookLM import AND `notebooklm` CLI is available**:

1. **Check notebook status**:
   ```bash
   notebooklm status
   ```
   If no active notebook, ask user to select one or skip.

2. **Export sessions via code-insights**:
   ```bash
   # Export sessions for the project(s)
   /code-insights export --project {project_id} --format markdown
   
   # This creates files in ~/.code-insights/exports/sessions/
   ```

3. **Import session transcripts to NotebookLM**:
   - Use the exported markdown files as sources
   - Invoke `/notebooklm` skill to handle the import
   - Each exported session becomes a NotebookLM source
   - Add citations linking back to code-insights sessions

4. **Update dashboards** with NotebookLM links:
   ```markdown
   ## Related Resources
   - [[NotebookLM/{notebook-slug}/Sources/{session-title}]]
   - Original session: `~/.code-insights/exports/sessions/{session-dir}/`
   ```

### Step 6: Confirmation & Summary

Report what was created:

```markdown
✓ Created/updated workstream dashboards:
  - project-alpha-Workstream.md (8 commits, 12 sessions, 3 next actions)
  - ml-pipeline-Workstream.md (3 commits, 15 sessions, 5 next actions)

✓ Created canvas visualizations:
  - project-alpha-Deep-Dive-2026-05-17.canvas (14 nodes, 18 edges)

✓ Synced to TaskNotes:
  - 8 tasks created across both projects

⏭ Next: Open ~/Notebook/Dashboards/ to view your workstreams
```

## Error Handling (Fail Fast)

**If any of these fail, STOP and report clearly**:

- **No code-insights DB found**: "Code-insights database not found at ~/.code-insights/data.db. Run `/code-insights extract` first."
- **No sessions in DB**: "No sessions found in code-insights database. Run `/code-insights extract recent --hours 168` to gather session data."
- **Database locked**: "Code-insights DB is locked (another process accessing it). Wait and try again."
- **Invalid project_id**: "Project ID '{project_id}' not found in sessions table. Check available projects with `/code-insights stats`."
- **NotebookLM CLI error**: "NotebookLM CLI not authenticated. Run `notebooklm login` or skip NotebookLM import."
- **TaskNotes API offline**: "TaskNotes plugin not running. Action items will be saved to dashboard only."
- **Export directory missing**: "Could not find code-insights export directory. Run `/code-insights export --session {id}` first."

**Do not attempt best-effort workarounds.** Clear errors help users fix the underlying issue.

## Delegation Patterns

### When to Use Parallel Subagents

**Use parallel subagents for**:
- Parsing different data sources (sessions, commits, notes) simultaneously
- Gathering data from multiple repos at once
- Running independent analysis tasks

**Example**:
```
Spawn in parallel:
- Subagent A: Parse sessions from Claude Code
- Subagent B: Parse sessions from Gemini CLI
- Subagent C: Extract commits from recall JSON
```

### When to Use Sequential Processing

**Use sequential processing for**:
- Creating dashboards (one per project, in order)
- Invoking skills that depend on previous outputs
- User confirmation steps

**Example**:
```
Sequential:
1. Create workstream dashboard for project-alpha
2. Wait for completion
3. Create canvas based on that dashboard
4. Update NotebookLM with dashboard link
```

## Integration Points

### With Code-Insights Skill
- **Input**: Session data from `~/.code-insights/data.db`
- **Data used**: Sessions, friction patterns, insights, session facets
- **When to re-run**: If recent sessions missing, suggest running `/code-insights extract recent --hours 168`
- **Export format**: Uses `/code-insights export` for markdown/JSON outputs

### With Workstream Skill (Optional)
- **Pattern reuse**: Borrows dashboard structure and TaskNotes sync patterns
- **Could invoke**: `/workstream canvas {slug}` for additional visualizations
- **Not required**: Can create dashboards directly without workstream dependency

### With NotebookLM Skill
- **Invokes**: `/notebooklm import` workflow for session transcripts
- **Depends on**: `notebooklm` CLI authenticated
- **Outputs**: Source files in NotebookLM/{notebook-slug}/Sources/
- **Session linking**: Each code-insights export becomes a NotebookLM source

### With Obsidian Skills
- **Could use**: obsidian-bases for creating filtered views of sessions
- **Could use**: obsidian-cli for programmatic vault operations
- **Could use**: obsidian-markdown for canvas file generation
- **Not required**: Dashboards are plain markdown, canvases are JSON

## Advanced: Cross-Workstream Analysis

**If user asks to synthesize across ALL workstreams** (not just recent recall):

1. **Query workstream DB for all active projects**:
   ```bash
   python3 ~/.claude/skills/workstream/scripts/workstream_db.py status
   ```

2. **Create CROSS-WORKSTREAM canvas** showing relationships:
   - Central topic node
   - Spoke connections to each project
   - Implications and patterns across projects

3. **Use semantic search** to find connections:
   ```bash
   ck --sem "{theme}" --threshold 0.4 --topk 8 -l ~/Notebook/Dashboards
   ```

## Usage Examples

### Example 1: After Code-Insights Extraction
```
user: /code-insights extract recent --hours 72
[extraction completes]
assistant: [auto-triggers knowledge-synthesizer]

I found sessions in 2 projects from the last 3 days:
1. ceda22e2013e495c (23 sessions, friction: knowledge-gap, tool-limitation)
2. ml-pipeline-v2 (15 sessions, friction: api-mismatch)

Would you like me to create Obsidian dashboards for these projects?

[user selects both, plus canvas for ceda22e2013e495c]

[Creates dashboards + canvas + extracts action items]
```

### Example 2: Explicit Synthesis Request
```
user: synthesize my code-insights sessions into dashboards
assistant: [triggers knowledge-synthesizer]

[Validates code-insights DB has data]
[Queries projects from sessions table]
[Creates outputs as requested]
```

### Example 3: With NotebookLM
```
user: /code-insights extract recent --hours 168
[extraction completes]
assistant: [auto-triggers knowledge-synthesizer]

[After creating dashboards]
I found 47 sessions across 3 projects. Would you like me to export these 
sessions and import them into NotebookLM for AI-powered Q&A?

[user: yes]
[Exports sessions, imports to NotebookLM, links to dashboards]
```

## Anti-Patterns

**DO NOT**:
- Proceed without validating code-insights database exists and has data
- Query the database directly with SQLite - USE CODE-INSIGHTS SKILL INSTEAD
- Create dashboards for projects with zero sessions
- Overwrite existing dashboards without user confirmation
- Parse raw SQL output directly (code-insights skill returns clean JSON)
- Bypass the code-insights skill interface (it's the single source of truth)
- Fail silently when database or tools are missing
- Create NotebookLM imports without asking user first
- Load entire session transcripts into context (use exports or summaries)

**DO**:
- Fail fast with clear error messages
- Use code-insights skill for ALL database queries (sessions, patterns, insights, export)
- Use parallel subagents for independent data analysis (each calling code-insights skill)
- Only use direct SQLite for validation (DB exists, session count check)
- Ask user which projects to process before starting
- Verify database has recent sessions via `code-insights stats`
- Report what was created with file paths, session counts, and stats

## Troubleshooting

### "No code-insights database found"
- Code-insights hasn't been set up yet
- Check if `~/.code-insights/data.db` exists
- Run sessions from AI tools to populate the database

### "No sessions in database"
- Database exists but is empty
- Run `/code-insights extract recent --hours 168` to populate
- Check that AI tools (claude-code, opencode, etc.) have recent activity

### "Could not query sessions table"
- Database may be corrupted
- Check with: `sqlite3 ~/.code-insights/data.db "SELECT COUNT(*) FROM sessions;"`
- If error, restore from backup or rebuild

### "NotebookLM not authenticated"
- Run: `notebooklm login`
- Or skip NotebookLM import

### "No project_id in sessions"
- Sessions exist but lack project_id metadata
- This is expected for some session types
- Filter to sessions with project_id: `WHERE project_id IS NOT NULL`

---

## Skill Ecosystem

This skill is part of a three-skill ecosystem:

```
┌────────────────────────────────────┐
│   CODE-INSIGHTS DATABASE           │
└──────────┬─────────────────────────┘
           │
    ┌──────┴───────┐
    │              │
    ▼              ▼
┌─────────┐   ┌──────────┐
│code-    │   │  recall  │
│insights │   │          │
└────┬────┘   └──────────┘
     │
     ▼
┌─────────────────┐
│knowledge-synth. │
│ (THIS SKILL)    │
└─────────────────┘
```

**Delegation Pattern:**
- **code-insights skill**: Query interface for database (L1)
- **recall skill**: Timeline synthesis (L1)
- **knowledge-synthesizer**: Orchestrates both (L2)

**This skill should:**
- Call code-insights skill for all data queries
- Call recall skill for timeline generation (optional)
- Never query code-insights database directly (except validation)
- Focus on orchestration and dashboard creation

**Related Skills:**
- `/code-insights` - Data extraction and pattern analysis
- `/recall` - Cross-platform timeline synthesis
- See `~/.vibe/skills/ECOSYSTEM.md` for complete relationship map

---

**Key Principle**: This skill is an orchestrator, not a reimplementation. It validates code-insights data, calls the code-insights skill for queries, asks user for preferences, delegates to specialized skills (code-insights export, notebooklm import, recall timeline), and creates Obsidian dashboards/canvases. The heavy lifting is done by code-insights for session extraction and notebooklm for knowledge graph import.
