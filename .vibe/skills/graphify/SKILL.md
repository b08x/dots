---
name: graphify
description: "any input (code, docs, papers, images, videos) to knowledge graph. Use when user asks any question about a codebase, documents, or project content - especially if graphify-out/ exists, treat the question as a /graphify query. DELEGATES to hybrid subagents for actual execution."
trigger: /graphify
---

# /graphify - Hybrid Delegation Orchestrator

**CRITICAL: This skill is an orchestrator only.** It MUST delegate all graph operations to specialized hybrid subagents using the `task()` tool. Do NOT execute graphify commands directly.

## Architecture

```
hybrid-gir (orchestrator)
├── hybrid-graphify-query     (stateless) - BFS/DFS queries, path finding, node lookups
├── hybrid-graphify-export    (stateless) - HTML, SVG, Neo4j, GraphML, Obsidian exports
├── hybrid-graphify-maintain  (stateless) - update, extract --force, cluster-only, merge-graphs
└── hybrid-graphify-research  (stateful)  - multi-turn analysis, deep research
```

## Delegation Rules

| Command Pattern | Subagent | Reason |
|----------------|----------|---------|
| `/graphify query "..."` | `hybrid-graphify-query` | Stateless query execution |
| `/graphify path "A" "B"` | `hybrid-graphify-query` | Shortest path finding |
| `/graphify explain "..."` | `hybrid-graphify-query` | Single node explanation |
| `/graphify export *` | `hybrid-graphify-export` | Format conversion only |
| `/graphify update *` | `hybrid-graphify-maintain` | Incremental updates |
| `/graphify extract * --force` | `hybrid-graphify-maintain` | Full rebuilds |
| `/graphify cluster-only *` | `hybrid-graphify-maintain` | Re-clustering only |
| `/graphify merge-graphs *` | `hybrid-graphify-maintain` | Graph merging |
| `/graphify add *` | `hybrid-graphify-maintain` | URL ingestion |
| Multi-turn analysis | `hybrid-graphify-research` | Stateful context |
| Deep research questions | `hybrid-graphify-research` | Cross-community analysis |

## Usage

### Standard Command Patterns

```
/graphify                                             # full pipeline → delegate to maintain
/graphify <path>                                      # full pipeline → delegate to maintain
/graphify https://github.com/<owner>/<repo>           # clone + full pipeline → maintain
/graphify <url1> <url2> ...                           # multi-repo merge → maintain
/graphify <path> --mode deep                          # deep extraction → maintain
/graphify <path> --update                             # incremental → maintain
/graphify <path> --cluster-only                       # re-cluster → maintain
/graphify <path> --directed                           # directed graph → maintain
/graphify <path> --whisper-model <model>             # transcription → maintain
/graphify <path> --html                               # export → export
/graphify <path> --svg                                # export → export
/graphify <path> --graphml                            # export → export
/graphify <path> --neo4j                              # export → export
/graphify <path> --neo4j-push <uri>                   # export → export
/graphify <path> --mcp                                # serve → export
/graphify <path> --wiki                               # wiki export → export
/graphify <path> --obsidian                           # obsidian export → export
/graphify query "<question>"                          # query → query
/graphify query "<question>" --dfs                    # DFS query → query
/graphify query "<question>" --budget <N>             # query → query
/graphify path "A" "B"                               # path → query
/graphify explain "<node>"                            # explain → query
/graphify add <url>                                   # add URL → maintain
```

## Orchestration Workflow

### Step 1: Parse Command
Identify the operation type from the user's input. Match against the Delegation Rules table above.

### Step 2: Validate Prerequisites
- Check if `graphify-out/` directory exists
- If not, and the command requires an existing graph (query, path, explain, export), delegate to `hybrid-graphify-maintain` first to build the graph
- If the command is a build command (update, extract, cluster-only), proceed directly

### Step 3: Delegate via task() Tool

Use the `task()` tool to delegate to the appropriate subagent. **NEVER execute graphify commands directly.**

**Template:**
```python
task(
    agent="SUBAGENT_NAME",
    task="EXACT_COMMAND_OR_DESCRIPTION"
)
```

**Examples:**

```python
# Query delegation
task(
    agent="hybrid-graphify-query",
    task="Query 'How does authentication work?' on graph at ./graphify-out/graph.json using BFS traversal, max depth 3"
)

# Path delegation
task(
    agent="hybrid-graphify-query", 
    task="Find shortest path between 'AuthModule' and 'Database' in ./graphify-out/graph.json"
)

# Export delegation
task(
    agent="hybrid-graphify-export",
    task="Export graph at ./graphify-out/graph.json to HTML and SVG formats"
)

# Maintenance delegation
task(
    agent="hybrid-graphify-maintain",
    task="Run graphify update . for incremental update"
)

# Research delegation (stateful)
task(
    agent="hybrid-graphify-research",
    task="Analyze the authentication architecture across the codebase. Graph path: ./graphify-out/graph.json"
)
```

### Step 4: Handle Results

- For stateless subagents (query, export, maintain): Wait for results, then present to user
- For stateful subagent (research): Maintain conversation context, allow follow-up questions
- If delegation fails: Retry once, then fall back to direct execution with clear warning

## Special Cases

### Help Command
If user invokes `/graphify --help` or `/graphify -h` (with no other arguments), print this help message:

```
Usage: /graphify [command] [options] [path]

Commands:
  (no command)            Full pipeline: detect → extract → cluster → report
  --update                Incremental update of changed files
  --extract --force       Full rebuild (ignores cache)
  --cluster-only          Re-run community detection only
  --merge-graphs A B     Merge multiple graph.json files
  
  query "<question>"       BFS traversal for broad context
  query "<question>" --dfs DFS traversal to trace paths
  query "<question>" --budget N  Cap answer at N tokens
  
  path "A" "B"           Find shortest path between nodes
  explain "<node>"        Explain a single node
  
  --html                 Export interactive HTML visualization
  --svg                  Export SVG (embeds in Notion, GitHub)
  --graphml              Export GraphML (Gephi, yEd)
  --neo4j                Generate Cypher for Neo4j
  --neo4j-push <uri>     Push directly to Neo4j instance
  --obsidian             Build Obsidian vault
  --wiki                 Build agent-crawlable wiki
  --mcp                  Start MCP stdio server
  
  add <url>              Fetch URL and add to corpus
  
  --mode deep           Thorough extraction, richer INFERRED edges
  --directed            Build directed graph (preserves edge direction)
  --whisper-model <m>   Use specific Whisper model for transcription
  --obsidian-dir <p>    Custom Obsidian vault path
  --watch               Watch folder, auto-rebuild on changes
```

### GitHub URL Detection
If the path argument starts with `https://github.com/` or `http://github.com/`, you MUST first clone the repo before delegating:

```python
# Single repo - delegate cloning to maintain
task(
    agent="hybrid-graphify-maintain",
    task="Clone https://github.com/owner/repo and run full pipeline"
)

# Multiple repos - delegate merge to maintain
task(
    agent="hybrid-graphify-maintain",
    task="Clone https://github.com/owner1/repo1 and https://github.com/owner2/repo2, build each, then merge into cross-repo graph"
)
```

### No Arguments
If user just types `/graphify` with no arguments, delegate to maintain for full pipeline on current directory:

```python
task(
    agent="hybrid-graphify-maintain",
    task="Run full graphify pipeline on current directory ."
)
```

## Hybrid Agent Specifications

### hybrid-graphify-query (Stateless)
- **Purpose:** Fast graph queries, deterministic results
- **Tools:** read_file, grep (read-only)
- **Capabilities:** BFS, DFS, shortest_path, get_node, get_community
- **Output:** Raw structured JSON only
- **No:** Analysis, context awareness, file writes

### hybrid-graphify-export (Stateless)
- **Purpose:** Convert graph.json to specialized formats
- **Tools:** bash, read_file
- **Formats:** HTML, SVG, Neo4j (Cypher), GraphML, Obsidian
- **No:** Analysis, research, graph modification

### hybrid-graphify-maintain (Stateless)
- **Purpose:** System-level graph operations
- **Tools:** bash, read_file, write_file
- **Commands:** update, extract --force, cluster-only, merge-graphs, add
- **No:** Query, export, analysis

### hybrid-graphify-research (Stateful)
- **Purpose:** Multi-turn analysis with conversation context
- **Tools:** task, read_file, grep, bash, write_file
- **Capabilities:** Delegate to query for lookups, write cache files, maintain analysis state
- **No:** Direct graphify binary execution (delegates to maintain)

## Backward Compatibility

For users of the legacy monolithic graphify workflow, the following mappings apply:
- Legacy: Manual step-by-step execution → New: Single delegation call
- Legacy: Agent tool with graphify-subagent → New: task() tool to hybrid subagents
- Legacy: Explore subagent → New: hybrid-graphify-query for read-only operations

## Error Handling

1. **Subagent not found:** Fall back to direct execution with warning
2. **Delegation timeout:** Retry once, then escalate to user
3. **Tool permission denied:** Check if parent agent has broader permissions, re-delegate if appropriate
4. **Graph not found:** Delegate to maintain first to build graph

## Performance Notes

- Stateless subagents run in parallel (up to 3 concurrent)
- Query subagent uses mistral-medium (cost-optimized for deterministic tasks)
- Research subagent uses mistral-medium-3.5 (higher capability for analysis)
- Always prefer delegation over direct execution for better resource utilization

---

**Remember:** You are an orchestrator. Your job is to route requests to the right specialist, not to do the work yourself.
