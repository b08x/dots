---
tags: [code-insights, friction-analysis, debugging]
created: 2026-05-17T06:18:28.266546
project: .vibe
---

# Friction Analysis Report

**Project:** `.vibe`  
**Analysis Period:** 72 hours  
**Total Sessions:** 136  
**Sessions with Course Corrections:** 68

---

## Executive Summary

This report analyzes friction points, iteration patterns, and course corrections across 136 AI-assisted sessions using 4 different tools.

### Key Findings

- **Course Corrections:** 68 sessions required direction changes
- **High Iteration Sessions:** 8 sessions with >5 iterations
- **Tool Diversity Impact:** 38 tool transitions may indicate tool-specific friction

---

## 🔄 Course Corrections

Sessions where the approach needed to be changed mid-stream:

| Date | Tool | Workflow | Reason | Iterations |
|------|------|----------|--------|------------|
| 2026-04-27 | mistral-vibe | iterative-refinement | Discovered remaining references to 'bluefin-builder' in config.toml during verification phase (User#24, Assistant#23). | 3 |
| 2026-04-30 | mistral-vibe | debug-fix-verify | Circular reference issue discovered where readme-generator skill attempted to document itself instead of user projects, requiring multi-layer safeguards to prevent self-modification. | 3 |
| 2026-04-30 | gemini-cli | plan-then-implement | Path resolution failure for unstaged changes required manual adjustment (Assistant#6-7). | 2 |
| 2026-04-30 | crush | explore-then-build | Discovered the directory was a Crush/Vibe configuration workspace rather than a traditional codebase, rendering the initial AGENTS.md task irrelevant. | 3 |
| 2026-05-03 | mistral-vibe | iterative-refinement | Hardcoded path `/home/b08x` replaced with `$HOME` variable (User#5 feedback) | 3 |
| 2026-05-03 | mistral-vibe | debug-fix-verify | Module import mismatch between `graphify` and `graphifyy` caused repeated failures in semantic extraction workflow. | 12 |
| 2026-05-03 | mistral-vibe | debug-fix-verify | Discovered TOML syntax incompatibility with inline tables containing quoted keys, requiring removal of problematic section. | 12 |
| 2026-05-03 | opencode | explore-then-build | Missing chunk files required manual JSON extraction and disk write operations to recover semantic extraction results (Assistant#14-16). | 3 |
| 2026-05-03 | opencode | explore-then-build | User requested deeper analysis of weakly-connected nodes (User#1) and subsequent addition of inferred connections (User#3), requiring iterative refinement of the graph structure. | 3 |
| 2026-05-03 | opencode | iterative-refinement | GitHub skills were initially isolated in the graph due to merge failure, requiring manual bridge edge creation and full graph rebuild. | 3 |
| 2026-05-03 | mistral-vibe | debug-fix-verify | Repeated tool invocation failures due to incorrect path resolution, forcing fallback to directory listing. | 3 |
| 2026-05-08 | gemini-cli | iterative-refinement | The initial assumption about the presence of `chat.md` files was incorrect, requiring a pivot to using `messages.jsonl` for semantic extraction. | 3 |
| 2026-05-09 | mistral-vibe | iterative-refinement | Agent loading issue due to missing enabled_agents configuration | 3 |
| 2026-05-09 | mistral-vibe | debug-fix-verify | Initial agent naming conflict with Vibe's caching mechanism required renaming and explicit reload. | 3 |
| 2026-05-12 | gemini-cli | iterative-refinement | Misinterpretation of `yadm` path resolution and staging behavior led to repeated tool call failures, resolved by adjusting path context and staging strategy. | 3 |
| 2026-05-12 | mistral-vibe | explore-then-build | Git lock file conflicts required manual resolution of staging issues (User#28-User#30). | 3 |
| 2026-05-12 | mistral-vibe | plan-then-implement | User identified a critical dependency ordering issue in parallel execution (User#14: 'the repomix output needs to be created before graphify and qmd databases are created') | 2 |
| 2026-05-12 | crush | direct-execution | User explicitly requested bypassing the skill's default branch-check workflow to commit directly on the current branch ('dont create seperate branch, just commit'). | 2 |
| 2026-05-12 | mistral-vibe | plan-then-implement | Python module import path resolution required explicit directory context in `sys.path` (User#23-User#25). | 2 |
| 2026-05-12 | mistral-vibe | explore-then-build | Initial attempt to spawn `doc-generator` subagent failed due to security constraints, forcing pivot to direct file analysis and manual documentation generation. | 3 |
| 2026-05-15 | opencode | explore-then-build | Path correction for chunk 3 subagent task after detecting wrong file paths (/.claude/skills vs /skills) | 3 |
| 2026-05-15 | opencode | explore-then-build | Initial file path assumptions were incorrect; required directory exploration to locate actual skill files in /home/b08x/.claude/skills/ | 3 |
| 2026-05-15 | opencode | explore-then-build | Discovered file paths in the user's request did not exist, requiring re-scoping of the search space. | 3 |
| 2026-05-15 | opencode | explore-then-build | Discovered 10/25 requested files were missing, requiring pivot to analyze only existing files | 3 |
| 2026-05-15 | gemini-cli | explore-then-build | Subagent invocation failures led to direct extraction via Python script and manual graph construction using `grep_search` and `run_shell_command`. | 3 |
| 2026-05-15 | mistral-vibe | direct-execution | Subagent invocation failure due to security constraints required retooling the parallel processing approach. | 3 |
| 2026-05-15 | opencode | iterative-refinement | Subagent failures in chunks 4-6 required manual intervention and partial result merging. | 3 |
| 2026-05-15 | opencode | iterative-refinement | Initial assumption about script file locations was incorrect; corrected via glob verification and fallback to existing file reads. | 3 |
| 2026-05-15 | opencode | explore-then-build | Incorrect file paths provided by user required path resolution before proceeding with extraction. | 4 |
| 2026-05-15 | opencode | explore-then-build | Discovered missing files required recalibration of extraction scope to only existing files in `/notebooklm/scripts/` | 3 |
| 2026-05-15 | mistral-vibe | debug-fix-verify | Initial misdiagnosis of TOML section header requirement led to iterative testing and validation of the correct configuration pattern across multiple agent files. | 3 |
| 2026-05-15 | mistral-vibe | direct-execution | Initial tool delegation failed due to unknown agent, prompting manual fallback to direct knowledge graph construction. | 2 |
| 2026-05-15 | mistral-vibe | iterative-refinement | YAML validation failure and tool compatibility issues required incremental fixes to `allowed-tools` and metadata structure. | 5 |
| 2026-05-15 | mistral-vibe | iterative-refinement | Initial Python script execution failed due to permission restrictions, requiring a directory-local execution workaround (User#8 → User#9). | 3 |
| 2026-05-15 | mistral-vibe | iterative-refinement | Initial gem matching logic was too simplistic; refined to use authoritative inventory and registry from rubysmithing context after discovering stale assumptions about file paths (User#10-User#32). | 3 |
| 2026-05-15 | mistral-vibe | direct-execution | User clarified file output requirements after initial miscommunication (e.g., 'include sub-query results in separate JSON files'). | 3 |
| 2026-05-15 | mistral-vibe | iterative-refinement | Initial edits were applied to the wrong documentation file (`docs/other-steve.md` instead of `prompts/other-steve.md`), requiring a rollback and reapplication of changes to the correct file. | 2 |
| 2026-05-15 | mistral-vibe | explore-then-build | Discovered that MCP tools are auto-discovered and do not require explicit listing in `enabled_tools`, allowing removal of unrestricted `bash` access (User#8 → Assistant#8). | 3 |
| 2026-05-15 | mistral-vibe | iterative-refinement | Realized other-steve needed write_file access for report synthesis after initially removing all file tools (User#22). | 3 |
| 2026-05-15 | mistral-vibe | explore-then-build | User pivoted from generic agent listing to specific `mistral-vibe` agents (User#1) and later expanded scope to `vibe-agents`/`vibe-workstreams` (User#4) after initial file exploration. | 3 |
| 2026-05-15 | mistral-vibe | iterative-refinement | Discovered `graphify.detect.detect()` already handles `.graphifyignore` internally, eliminating need for manual filtering step. | 4 |
| 2026-05-15 | mistral-vibe | iterative-refinement | The initial semantic extraction process encountered repeated failures in chunk merging and AST/semantic integration, requiring multiple retries and manual intervention to resolve file path inconsistencies and JSON serialization issues. | 5 |
| 2026-05-15 | mistral-vibe | explore-then-build | Shifted from broad query to targeted graph analysis after initial tool failures (User#20-User#23). | 3 |
| 2026-05-16 | mistral-vibe | iterative-refinement | Stale Python interpreter path in `.graphify_python` caused repeated command failures (User#4, User#11 corrected). | 3 |
| 2026-05-16 | mistral-vibe | explore-then-build | Initial incorrect CLI command syntax (`graphify . --mode deep --update`) was corrected to `graphify update` after help documentation review. | 3 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | The initial plan to run `graphify update . --deep` failed with `error: unknown update option: --deep`, so the session pivoted to CLI help and local skill inspection. | 4 |
| 2026-05-16 | mistral-vibe | explore-then-build | File path resolution for merged-graph.json required manual intervention after initial output was written to a temporary scratchpad directory instead of the expected ./graphify-merged/ location. | 3 |
| 2026-05-16 | mistral-vibe | direct-execution | `graphify update .` refreshed the graph artifacts but did not emit added/removed/modified node deltas, so the session pivoted to `git diff HEAD~1..HEAD` and related file inspections as a proxy for what the refreshed graph now reflects. | 3 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | The workflow shifted from direct execution to path investigation after `graphify merge-graphs` failed because the relative input `graphify-out/graph.json` could not be resolved from the chosen working context. | 2 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | The exact merge command failed because `/tmp/vibe-scratchpad-139d8071-gqkbp5lv/graphify-out/graph.json` did not exist, so the session pivoted to locating a valid `graph.json`, copying it into the scratchpad, and then re-running the original command. | 4 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | Initial `graphify cluster-only` attempts targeted `graphify-merged/merged-graph.json` directly, then shifted to staging `graphify-merged/graphify-out/graph.json` and rerunning from the directory after `no graph found at .../graphify-out/graph.json` errors. | 5 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | Default `graphify export html --graph graphify-merged/merged-graph.json` skipped output because `graphify-merged/merged-graph.json` had 7,354 nodes above the 5,000 default limit, so the workflow pivoted to `--node-limit 10000`. | 5 |
| 2026-05-16 | mistral-vibe | explore-then-build | Early exploration of `./graphify-merged/merged-graph.json` was noisy and truncated, so the session narrowed to the `skills/agent-creator/agent_creator_workflow.py` node cluster and its `links` relations. | 7 |
| 2026-05-16 | mistral-vibe | iterative-refinement | Initial attempt to delete duplicate file was blocked by denylist pattern, requiring alternative approach (mv to /tmp/) | 3 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | Initial `graphify extract --deep --force .` usage failed because the CLI interpreted `--deep` as a path, and extraction from `/tmp/vibe-scratchpad-8b81c75e-xagc951z` also produced an empty graph, so the workflow pivoted to `graphify extract . --deep --force --out /tmp/vibe-scratchpad-8b81c75e-xagc951z` against `/home/b08x/.vibe`. | 5 |
| 2026-05-16 | mistral-vibe | iterative-refinement | The investigation pivoted after the unavailable tool error at User#4 and continued through targeted reads of `/home/b08x/.vibe/graphify-out/graph.json`, `README.md`, and `.gemini/settings.json` snippets. | 11 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | YAML frontmatter parsing failure due to malformed document delimiters in SKILL.md, requiring manual intervention and script updates. | 4 |
| 2026-05-16 | mistral-vibe | plan-then-implement | User manually corrected working directory ambiguity via `echo $PWD` (User#4-User#5) after initial tool failure due to unstated path assumptions. | 2 |
| 2026-05-16 | mistral-vibe | explore-then-build | Tooling limitations required iterative adjustments to question formatting and tool selection (e.g., User#35, User#20). | 3 |
| 2026-05-16 | mistral-vibe | direct-execution | Initial agent registration failed due to incorrect agent name ('vibe' vs registered 'agent_01KRRAZMGMDPN4PTQWGX4ZJRFH'), requiring explicit `set_active_agent` call with the correct ID (User#4 → User#5). | 2 |
| 2026-05-16 | mistral-vibe | explore-then-build | A blocked `python3` attempt led the workflow to use `/home/b08x/.local/apps/homebrew/bin/graphify` to regenerate `/home/b08x/.vibe/graphify-out/graph.html` from `/home/b08x/.vibe/graphify-out/graph.json`. | 4 |
| 2026-05-16 | gemini-cli | direct-execution | Security block on initial shell command required pivot to simplified syntax (Assistant#1 → Assistant#2). | 2 |
| 2026-05-16 | mistral-vibe | iterative-refinement | A standalone `python3` invocation was denied, so the session shifted toward generating a temporary script-based workaround. | 3 |
| 2026-05-16 | mistral-vibe | iterative-refinement | Discovered missing `task` tool configuration in `hybrid-graphify-research` subagent, preventing delegation to `graphify-query`. Corrected by updating TOML and validating against VibeConfig schema. | 3 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | Repeated agent invocation failures due to naming inconsistencies and SSL errors required iterative debugging and configuration tracing. | 5 |
| 2026-05-16 | mistral-vibe | iterative-refinement | Repeated path and tool failures forced a pivot from scratchpad-relative reads and unsupported shell calls to targeted searches inside `/home/b08x/.vibe/graphify-out/graph.json`. | 4 |
| 2026-05-16 | mistral-vibe | debug-fix-verify | Repeated agent invocation failures led to manual configuration checks and path validations (User#13-User#14). | 5 |
| 2026-05-16 | mistral-vibe | iterative-refinement | The session shifted from truncated full-file reads and unsupported bash invocations to targeted offset-based inspection of matching nodes in ./graphify-out/graph.json. | 5 |


### Course Correction Patterns

- **Discovered remaining references to 'bluefin-builder' in config.toml during verification phase (User#24, Assistant#23).**: 1 times
- **Circular reference issue discovered where readme-generator skill attempted to document itself instead of user projects, requiring multi-layer safeguards to prevent self-modification.**: 1 times
- **Path resolution failure for unstaged changes required manual adjustment (Assistant#6-7).**: 1 times
- **Discovered the directory was a Crush/Vibe configuration workspace rather than a traditional codebase, rendering the initial AGENTS.md task irrelevant.**: 1 times
- **Hardcoded path `/home/b08x` replaced with `$HOME` variable (User#5 feedback)**: 1 times
- **Module import mismatch between `graphify` and `graphifyy` caused repeated failures in semantic extraction workflow.**: 1 times
- **Discovered TOML syntax incompatibility with inline tables containing quoted keys, requiring removal of problematic section.**: 1 times
- **Missing chunk files required manual JSON extraction and disk write operations to recover semantic extraction results (Assistant#14-16).**: 1 times
- **User requested deeper analysis of weakly-connected nodes (User#1) and subsequent addition of inferred connections (User#3), requiring iterative refinement of the graph structure.**: 1 times
- **GitHub skills were initially isolated in the graph due to merge failure, requiring manual bridge edge creation and full graph rebuild.**: 1 times
- **Repeated tool invocation failures due to incorrect path resolution, forcing fallback to directory listing.**: 1 times
- **The initial assumption about the presence of `chat.md` files was incorrect, requiring a pivot to using `messages.jsonl` for semantic extraction.**: 1 times
- **Agent loading issue due to missing enabled_agents configuration**: 1 times
- **Initial agent naming conflict with Vibe's caching mechanism required renaming and explicit reload.**: 1 times
- **Misinterpretation of `yadm` path resolution and staging behavior led to repeated tool call failures, resolved by adjusting path context and staging strategy.**: 1 times
- **Git lock file conflicts required manual resolution of staging issues (User#28-User#30).**: 1 times
- **User identified a critical dependency ordering issue in parallel execution (User#14: 'the repomix output needs to be created before graphify and qmd databases are created')**: 1 times
- **User explicitly requested bypassing the skill's default branch-check workflow to commit directly on the current branch ('dont create seperate branch, just commit').**: 1 times
- **Python module import path resolution required explicit directory context in `sys.path` (User#23-User#25).**: 1 times
- **Initial attempt to spawn `doc-generator` subagent failed due to security constraints, forcing pivot to direct file analysis and manual documentation generation.**: 1 times
- **Path correction for chunk 3 subagent task after detecting wrong file paths (/.claude/skills vs /skills)**: 1 times
- **Initial file path assumptions were incorrect; required directory exploration to locate actual skill files in /home/b08x/.claude/skills/**: 1 times
- **Discovered file paths in the user's request did not exist, requiring re-scoping of the search space.**: 1 times
- **Discovered 10/25 requested files were missing, requiring pivot to analyze only existing files**: 1 times
- **Subagent invocation failures led to direct extraction via Python script and manual graph construction using `grep_search` and `run_shell_command`.**: 1 times
- **Subagent invocation failure due to security constraints required retooling the parallel processing approach.**: 1 times
- **Subagent failures in chunks 4-6 required manual intervention and partial result merging.**: 1 times
- **Initial assumption about script file locations was incorrect; corrected via glob verification and fallback to existing file reads.**: 1 times
- **Incorrect file paths provided by user required path resolution before proceeding with extraction.**: 1 times
- **Discovered missing files required recalibration of extraction scope to only existing files in `/notebooklm/scripts/`**: 1 times
- **Initial misdiagnosis of TOML section header requirement led to iterative testing and validation of the correct configuration pattern across multiple agent files.**: 1 times
- **Initial tool delegation failed due to unknown agent, prompting manual fallback to direct knowledge graph construction.**: 1 times
- **YAML validation failure and tool compatibility issues required incremental fixes to `allowed-tools` and metadata structure.**: 1 times
- **Initial Python script execution failed due to permission restrictions, requiring a directory-local execution workaround (User#8 → User#9).**: 1 times
- **Initial gem matching logic was too simplistic; refined to use authoritative inventory and registry from rubysmithing context after discovering stale assumptions about file paths (User#10-User#32).**: 1 times
- **User clarified file output requirements after initial miscommunication (e.g., 'include sub-query results in separate JSON files').**: 1 times
- **Initial edits were applied to the wrong documentation file (`docs/other-steve.md` instead of `prompts/other-steve.md`), requiring a rollback and reapplication of changes to the correct file.**: 1 times
- **Discovered that MCP tools are auto-discovered and do not require explicit listing in `enabled_tools`, allowing removal of unrestricted `bash` access (User#8 → Assistant#8).**: 1 times
- **Realized other-steve needed write_file access for report synthesis after initially removing all file tools (User#22).**: 1 times
- **User pivoted from generic agent listing to specific `mistral-vibe` agents (User#1) and later expanded scope to `vibe-agents`/`vibe-workstreams` (User#4) after initial file exploration.**: 1 times
- **Discovered `graphify.detect.detect()` already handles `.graphifyignore` internally, eliminating need for manual filtering step.**: 1 times
- **The initial semantic extraction process encountered repeated failures in chunk merging and AST/semantic integration, requiring multiple retries and manual intervention to resolve file path inconsistencies and JSON serialization issues.**: 1 times
- **Shifted from broad query to targeted graph analysis after initial tool failures (User#20-User#23).**: 1 times
- **Stale Python interpreter path in `.graphify_python` caused repeated command failures (User#4, User#11 corrected).**: 1 times
- **Initial incorrect CLI command syntax (`graphify . --mode deep --update`) was corrected to `graphify update` after help documentation review.**: 1 times
- **The initial plan to run `graphify update . --deep` failed with `error: unknown update option: --deep`, so the session pivoted to CLI help and local skill inspection.**: 1 times
- **File path resolution for merged-graph.json required manual intervention after initial output was written to a temporary scratchpad directory instead of the expected ./graphify-merged/ location.**: 1 times
- **`graphify update .` refreshed the graph artifacts but did not emit added/removed/modified node deltas, so the session pivoted to `git diff HEAD~1..HEAD` and related file inspections as a proxy for what the refreshed graph now reflects.**: 1 times
- **The workflow shifted from direct execution to path investigation after `graphify merge-graphs` failed because the relative input `graphify-out/graph.json` could not be resolved from the chosen working context.**: 1 times
- **The exact merge command failed because `/tmp/vibe-scratchpad-139d8071-gqkbp5lv/graphify-out/graph.json` did not exist, so the session pivoted to locating a valid `graph.json`, copying it into the scratchpad, and then re-running the original command.**: 1 times
- **Initial `graphify cluster-only` attempts targeted `graphify-merged/merged-graph.json` directly, then shifted to staging `graphify-merged/graphify-out/graph.json` and rerunning from the directory after `no graph found at .../graphify-out/graph.json` errors.**: 1 times
- **Default `graphify export html --graph graphify-merged/merged-graph.json` skipped output because `graphify-merged/merged-graph.json` had 7,354 nodes above the 5,000 default limit, so the workflow pivoted to `--node-limit 10000`.**: 1 times
- **Early exploration of `./graphify-merged/merged-graph.json` was noisy and truncated, so the session narrowed to the `skills/agent-creator/agent_creator_workflow.py` node cluster and its `links` relations.**: 1 times
- **Initial attempt to delete duplicate file was blocked by denylist pattern, requiring alternative approach (mv to /tmp/)**: 1 times
- **Initial `graphify extract --deep --force .` usage failed because the CLI interpreted `--deep` as a path, and extraction from `/tmp/vibe-scratchpad-8b81c75e-xagc951z` also produced an empty graph, so the workflow pivoted to `graphify extract . --deep --force --out /tmp/vibe-scratchpad-8b81c75e-xagc951z` against `/home/b08x/.vibe`.**: 1 times
- **The investigation pivoted after the unavailable tool error at User#4 and continued through targeted reads of `/home/b08x/.vibe/graphify-out/graph.json`, `README.md`, and `.gemini/settings.json` snippets.**: 1 times
- **YAML frontmatter parsing failure due to malformed document delimiters in SKILL.md, requiring manual intervention and script updates.**: 1 times
- **User manually corrected working directory ambiguity via `echo $PWD` (User#4-User#5) after initial tool failure due to unstated path assumptions.**: 1 times
- **Tooling limitations required iterative adjustments to question formatting and tool selection (e.g., User#35, User#20).**: 1 times
- **Initial agent registration failed due to incorrect agent name ('vibe' vs registered 'agent_01KRRAZMGMDPN4PTQWGX4ZJRFH'), requiring explicit `set_active_agent` call with the correct ID (User#4 → User#5).**: 1 times
- **A blocked `python3` attempt led the workflow to use `/home/b08x/.local/apps/homebrew/bin/graphify` to regenerate `/home/b08x/.vibe/graphify-out/graph.html` from `/home/b08x/.vibe/graphify-out/graph.json`.**: 1 times
- **Security block on initial shell command required pivot to simplified syntax (Assistant#1 → Assistant#2).**: 1 times
- **A standalone `python3` invocation was denied, so the session shifted toward generating a temporary script-based workaround.**: 1 times
- **Discovered missing `task` tool configuration in `hybrid-graphify-research` subagent, preventing delegation to `graphify-query`. Corrected by updating TOML and validating against VibeConfig schema.**: 1 times
- **Repeated agent invocation failures due to naming inconsistencies and SSL errors required iterative debugging and configuration tracing.**: 1 times
- **Repeated path and tool failures forced a pivot from scratchpad-relative reads and unsupported shell calls to targeted searches inside `/home/b08x/.vibe/graphify-out/graph.json`.**: 1 times
- **Repeated agent invocation failures led to manual configuration checks and path validations (User#13-User#14).**: 1 times
- **The session shifted from truncated full-file reads and unsupported bash invocations to targeted offset-based inspection of matching nodes in ./graphify-out/graph.json.**: 1 times


---

## 🔁 High Iteration Sessions

Sessions requiring significant back-and-forth (>5 iterations):

| Date | Tool | Iterations | Workflow | Messages | Friction Points |
|------|------|------------|----------|----------|----------------|
| 2026-05-16 | mistral-vibe | 14 | explore-then-build | 30 | Yes |
| 2026-05-03 | mistral-vibe | 12 | debug-fix-verify | 72 | Yes |
| 2026-05-03 | mistral-vibe | 12 | debug-fix-verify | 53 | Yes |
| 2026-05-16 | mistral-vibe | 11 | iterative-refinement | 78 | Yes |
| 2026-05-15 | crush | 8 | plan-then-implement | 9 | Yes |
| 2026-05-16 | mistral-vibe | 7 | explore-then-build | 54 | Yes |
| 2026-05-15 | mistral-vibe | 6 | direct-execution | 12 | Yes |
| 2026-05-03 | mistral-vibe | 6 | direct-execution | 13 | Yes |


### Iteration Analysis

**Average iterations in high-iteration sessions:** 9.5

**Tools with most high-iteration sessions:**
- **mistral-vibe**: 7 sessions
- **crush**: 1 sessions


---

## ✅ Effective Patterns

Patterns that led to successful outcomes:

*No effective patterns explicitly recorded.*


---

## 🔀 Tool-Specific Friction Analysis

### Tool Transition Patterns

**Total Transitions:** 38

**Most frequently switched FROM:**
- **mistral-vibe**: 17 times
- **crush**: 11 times
- **gemini-cli**: 6 times
- **opencode**: 4 times

**Most frequently switched TO:**
- **mistral-vibe**: 16 times
- **crush**: 12 times
- **gemini-cli**: 6 times
- **opencode**: 4 times


### Hypothesis: Why Switch Tools?

Based on the transition patterns:

1. **mistral-vibe → others** (17 transitions)
   - Suggests limitations encountered with primary tool
   - May indicate specific tasks better suited for other tools

2. **Return to mistral-vibe** (16 transitions)
   - Indicates tool preference for general work
   - Other tools used for specific capabilities

3. **Transition frequency** (38 in 136 sessions)
   - ~27.9% of sessions involve tool switch
   - Relatively high, suggests workflow optimization needed

---

## 🎯 Friction Mitigation Recommendations

### Immediate Actions

1. **Document Tool Use Cases**
   - Create a decision matrix for when to use each tool
   - Example: "Use opencode for X, mistral-vibe for Y"

2. **Reduce Tool Switching**
   - 38 transitions suggests uncertainty
   - Standardize on primary tool for 80% of tasks

3. **Track Course Correction Triggers**
   - 68 sessions needed direction changes
   - Identify common triggers to prevent future occurrences

### Long-term Improvements

1. **Workflow Pattern Standardization**
   - direct-execution worked 35 times
   - Formalize this pattern as default approach

2. **Iteration Reduction**
   - 8 sessions needed >5 iterations
   - Create templates/scaffolds for common tasks

3. **Friction Logging**
   - Enable detailed friction tracking in code-insights
   - Current data shows minimal friction metadata

---

## 📊 Statistical Summary

| Metric | Value |
|--------|-------|
| Total Sessions | 136 |
| Tools Used | 4 |
| Tool Transitions | 38 |
| Course Corrections | 68 |
| High-Iteration Sessions | 8 |
| Workflow Patterns | 7 |
| Transition Rate | 27.9% |
| Course Correction Rate | 50.0% |

---

## 🔍 Recommended Deep Dives

1. **Review specific high-iteration sessions** to understand what caused complexity
2. **Analyze messages** in course-correction sessions for trigger patterns
3. **Compare tool performance** on similar tasks
4. **Document successful patterns** from effective_patterns data

---

*Generated by Code Insights Friction Analysis*  
*Data source: `~/.code-insights/data.db`*  
*Project ID: 7988f69c3463b2d9*
