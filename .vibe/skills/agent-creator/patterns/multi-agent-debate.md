# Multi-Agent Debate Pattern

## Overview
Uses **multiple specialized judge subagents** to evaluate work from different perspectives.
Each judge operates **independently**, then **debates findings** to reach consensus.

## When to Use
- Code reviews
- Architecture validation
- Requirements verification
- Any task requiring **multiple expert perspectives**

## Structure
```
[Main Agent: Critique Coordinator]
       │
       ├───▶ [Judge 1: Requirements Validator]
       ├───▶ [Judge 2: Solution Architect]
       └────▶ [Judge 3: Code Quality Reviewer]
```

## Configuration Template
```toml

id = "{agent_id}"
name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "neutral"
auto_approve = false
system_prompt_id = "{agent_id}"




[config]
enabled_tools = ["read_file", "grep", "task", "ask_user_question"]
disabled_tools = ["write_file", "search_replace"]

[tools.read_file]
permission = "always"

[tools.grep]
permission = "always"

[tools.task]
permission = "always"  # CRITICAL: Required to spawn judges

[tools.ask_user_question]
permission = "always"
```

## Required Tools
- `task` (permission = `"always"`) - **Non-negotiable** for spawning judges
- `read_file` (permission = `"always"`) - For analyzing files
- `grep` (permission = `"always"`) - For searching code

## Example
See: `~/.vibe/agents/critique-agent.toml` (existing implementation)
