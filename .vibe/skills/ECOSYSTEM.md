# AI Session Analysis Ecosystem

Three complementary skills work together to provide comprehensive session analysis and visualization.

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                 CODE-INSIGHTS DATABASE                        │
│                ~/.code-insights/data.db                       │
│                                                               │
│  Tables: sessions, messages, insights, session_facets        │
│  Sources: claude-code, gemini-cli, hermes-agent, opencode,   │
│           mistral-vibe, crush, antigravity, codex-cli         │
└────────────────┬─────────────────────────────────────────────┘
                 │
        ┌────────┴─────────┐
        │                  │
        ▼                  ▼
┌──────────────┐    ┌──────────────┐
│code-insights │    │    recall    │
│   (Ruby)     │    │   (Python)   │
│  L1: Query   │    │ L1: Synthesis│
└──────┬───────┘    └──────┬───────┘
       │                   │
       │  ┌────────────────┘
       │  │
       ▼  ▼
┌──────────────────┐
│knowledge-synth.  │
│ (Orchestrator)   │
│ L2: Dashboards   │
└──────────────────┘
```

## The Three Skills

### 1. code-insights (Ruby) - Query & Analyze
**Path:** `~/.vibe/skills/code-insights/`

**Purpose:** Low-level database queries and pattern detection

**When to use:**
- Query sessions by time/source/project
- Detect friction patterns
- Find high-confidence insights
- Analyze session facets
- Export sessions (JSON/MD/JSONL)
- Integration with graphify/QMD

**Example commands:**
```bash
# Extract recent sessions
/code-insights extract recent --hours 6 --source claude-code

# Find friction patterns
/code-insights patterns --category knowledge-gap --project X

# Export and index with graphify
/code-insights export --session X --graphify

# Get statistics
/code-insights stats
```

**Outputs:**
- JSON data (stdout)
- Exported session files: `~/.code-insights/exports/sessions/`
- Graphify knowledge graphs (when integrated)

---

### 2. recall (Python) - Synthesize & Recommend
**Path:** `~/.vibe/skills/recall/`

**Purpose:** Temporal synthesis across platforms with narrative generation

**When to use:**
- "What did I work on last week?"
- Generate unified timeline across AI tools
- Get recommended next action ("One Thing")
- Visualize work in Obsidian
- Correlate with GitHub commits
- Cross-platform analysis

**Example commands:**
```bash
# Full recall workflow (last 7 days)
python3 recall_workflow.py --days 7

# With graphify export
python3 recall_workflow.py --days 7 --export-graphify

# With QMD export
python3 recall_workflow.py --days 7 --export-qmd

# Specific GitHub repo
python3 recall_workflow.py --days 7 --github-repo owner/repo
```

**Outputs:**
- `~/Notebook/Dashboards/Recall Dashboard {date}.md` - Timeline dashboard
- `~/Notebook/Canvases/Recall Timeline {date}.canvas` - Visual timeline
- `/tmp/recall-output/*.json` - Raw correlation data
- Console: Narrative + "One Thing" recommendation

---

### 3. knowledge-synthesizer (Orchestrator) - Dashboard Creation
**Path:** `~/.vibe/skills/knowledge-synthesizer/`

**Purpose:** Project-specific dashboard generation with multi-skill coordination

**When to use:**
- Create detailed project dashboards from sessions
- Analyze friction patterns per project
- Generate NotebookLM sources
- Sync action items to TaskNotes
- Create project-centric canvases

**Trigger:**
- Auto-triggers after `/code-insights extract`
- Manually: "synthesize sessions" or "create dashboards"

**Outputs:**
- `~/Notebook/Dashboards/{project}-Sessions.md` (one per project)
- `~/Notebook/Dashboards/{project}-Canvas-{date}.canvas` (optional)
- NotebookLM sources (optional)
- TaskNotes entries

---

## Decision Tree

### "What skill should I use?"

```
User wants to...

┌─ Raw data query or pattern analysis?
│  → code-insights
│     /code-insights patterns --category X
│     /code-insights sessions --project Y
│
├─ Temporal timeline across platforms?
│  → recall
│     python3 recall_workflow.py --days 7
│
├─ Project-specific dashboards with friction analysis?
│  → knowledge-synthesizer
│     "synthesize sessions"
│
└─ Complete analysis (everything)?
   1. /code-insights extract recent --hours 168
   2. [knowledge-synthesizer auto-triggers] → project dashboards
   3. python3 recall_workflow.py --days 7 --export-graphify
   4. Review: ~/Notebook/Dashboards/
```

## Integration Patterns

### Pattern 1: knowledge-synthesizer → code-insights (PRIMARY)

knowledge-synthesizer should **always** use code-insights skill for queries:

```ruby
# CORRECT: Use skill delegation
sessions_json = `ruby ~/.vibe/skills/code-insights/code-insights sessions --project #{project_id}`
sessions = JSON.parse(sessions_json)

# WRONG: Direct database queries
conn = SQLite3::Database.new("#{ENV['HOME']}/.code-insights/data.db")
sessions = conn.execute("SELECT * FROM sessions WHERE project_id = ?", project_id)
```

**Why:**
- Single source of truth for queries
- Better error handling
- Consistent JSON output
- Reuses query logic
- Easier maintenance

### Pattern 2: recall → code-insights (OPTIONAL)

recall can optionally export via code-insights:

```bash
python3 recall_workflow.py --days 7 --export-graphify
```

**What happens:**
1. recall generates timeline (as usual)
2. Calls code-insights skill to export sessions
3. Sessions indexed by graphify for semantic search
4. User gets temporal view + knowledge graph

### Pattern 3: knowledge-synthesizer → recall (OPTIONAL)

For timeline generation within a project:

```python
subprocess.run([
    "python3", "recall_workflow.py",
    "--days", "7",
    "--github-repo", repo_name
])
```

**Use case:** User wants both project dashboard and timeline

## Complementary Views

### Temporal View (recall)
- **Focus:** When things happened
- **Sources:** All AI tools + GitHub + local git
- **Output:** Single unified timeline
- **Dashboard:** `Recall Dashboard {date}.md`
- **Canvas:** Timeline flow visualization

### Spatial View (knowledge-synthesizer)
- **Focus:** Project structure and patterns
- **Sources:** code-insights sessions only
- **Output:** Multiple project-specific dashboards
- **Dashboard:** `{project}-Sessions.md` per project
- **Canvas:** Project structure with friction nodes

### Data View (code-insights)
- **Focus:** Raw queries and pattern detection
- **Sources:** Database queries
- **Output:** JSON data, exports
- **Export:** Markdown, JSONL, graphify, QMD

## Dashboard Cross-References

### In recall Dashboard
```markdown
## Related Dashboards

### Project-Specific Analysis
- Use `/code-insights sessions --project <id>` to find projects
- Use `knowledge-synthesizer` to create project dashboards
- Project dashboards: `[[Dashboards/]]` (filter `-Sessions.md`)
```

### In knowledge-synthesizer Dashboard
```markdown
## Related Dashboards
- [[Recall Dashboard {date}]] - Temporal timeline across all platforms
- See: `Dashboards/Recall Dashboard *.md` for cross-platform views
```

## Common Workflows

### Workflow 1: Weekly Review
```bash
# 1. Extract sessions
/code-insights extract recent --hours 168

# 2. Project dashboards (auto-triggers)
[knowledge-synthesizer creates project dashboards]

# 3. Timeline + export
python3 recall_workflow.py --days 7 --export-graphify

# 4. Review outputs
open ~/Notebook/Dashboards/
```

### Workflow 2: Project Deep Dive
```bash
# 1. Find project ID
/code-insights stats

# 2. Analyze friction
/code-insights patterns --project X --recurring

# 3. Create dashboard
"synthesize sessions for project X"

# 4. Generate timeline for that project
python3 recall_workflow.py --days 14 --platforms all
```

### Workflow 3: Quick Daily Recall
```bash
# Simple timeline
python3 recall_workflow.py --days 1

# Output: Dashboard + Canvas + "One Thing"
```

### Workflow 4: Research Knowledge Graph
```bash
# Extract and export to graphify
/code-insights extract recent --hours 72
/code-insights export --recent 72 --graphify

# Or combine with recall
python3 recall_workflow.py --days 3 --export-graphify

# Now query the knowledge graph
# (graphify commands here)
```

## Data Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. AI Tools Create Sessions                             │
│    (claude-code, gemini-cli, hermes, etc.)              │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Sessions Synced to code-insights Database            │
│    (automatic via each tool's sync mechanism)           │
└────────────────┬────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
┌──────────────┐   ┌──────────────┐
│ 3a. Query    │   │ 3b. Synthesize│
│ (code-       │   │ (recall)      │
│  insights)   │   │               │
└──────┬───────┘   └──────┬────────┘
       │                  │
       │  ┌───────────────┘
       │  │
       ▼  ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Visualization Layer                                   │
│    - Obsidian Dashboards (recall + knowledge-synth)     │
│    - Obsidian Canvases (recall + knowledge-synth)       │
│    - NotebookLM Sources (knowledge-synth)               │
│    - Knowledge Graphs (graphify via code-insights)      │
└─────────────────────────────────────────────────────────┘
```

## File Locations

### Source Database
- `~/.code-insights/data.db` - Unified session database

### Exports
- `~/.code-insights/exports/sessions/` - Session exports (MD/JSON/JSONL)

### Obsidian Outputs
- `~/Notebook/Dashboards/Recall Dashboard {date}.md` - Recall timelines
- `~/Notebook/Dashboards/{project}-Sessions.md` - Project dashboards
- `~/Notebook/Canvases/Recall Timeline {date}.canvas` - Timeline canvases
- `~/Notebook/Canvases/{project}-Canvas-{date}.canvas` - Project canvases

### Temporary Data
- `/tmp/recall-output/` - Recall workflow outputs (JSON)

## Maintenance

### Updating Skills

**When code-insights database schema changes:**
1. Update code-insights skill query logic
2. Recall's CodeInsightsProvider may need updates
3. knowledge-synthesizer uses skill delegation (no changes needed)

**When adding new AI tools:**
1. Ensure tool syncs to code-insights database
2. All three skills automatically support it
3. No code changes required

**When adding new visualization types:**
- Extend obsidian_viz.py in recall skill
- Or add to knowledge-synthesizer dashboard templates

## Troubleshooting

### "No sessions found"
**Cause:** code-insights database empty or not updated
**Fix:** 
```bash
# Check database
sqlite3 ~/.code-insights/data.db "SELECT COUNT(*) FROM sessions;"

# Extract sessions
/code-insights extract recent --hours 168
```

### "Skills not communicating"
**Cause:** knowledge-synthesizer using direct DB queries
**Fix:** Update to use skill delegation pattern (see Integration Patterns)

### "Dashboards not cross-referenced"
**Cause:** Old skill versions
**Fix:** Update skills from this ecosystem documentation

### "Export integration not working"
**Cause:** code-insights skill not found
**Fix:**
```bash
# Check skill exists
ls ~/.vibe/skills/code-insights/code-insights

# Use full workflow
python3 recall_workflow.py --days 7 --export-graphify
```

## Version Compatibility

| Skill | Version | Features |
|-------|---------|----------|
| code-insights | 1.0.0 | Query, patterns, export, graphify/QMD |
| recall | 1.3.0+ | CodeInsightsProvider, export integration |
| knowledge-synthesizer | 1.0.0 | Should use skill delegation |

**Minimum versions for ecosystem:**
- recall: v1.3.0 (for export integration)
- code-insights: v1.0.0
- knowledge-synthesizer: v1.0.0

## Future Enhancements

**Planned:**
- Dashboard index generator
- Cross-project pattern detection
- Automated friction trend analysis
- Integration with additional knowledge bases
- Session similarity clustering
- Automated action item extraction

## See Also

- Individual skill documentation:
  - `/code-insights` → `~/.vibe/skills/code-insights/SKILL.md`
  - `/recall` → `~/.vibe/skills/recall/SKILL.md`
  - `knowledge-synthesizer` → `~/.vibe/skills/knowledge-synthesizer/SKILL.md`

- Related tools:
  - graphify: Knowledge graph generation
  - QMD: Semantic search and retrieval
  - NotebookLM: AI-powered Q&A over sources
  - TaskNotes: Action item tracking

---

**Last Updated:** 2026-05-17
**Ecosystem Version:** 1.0.0
