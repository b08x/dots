# Subagent Delegation Pattern

## Overview
**Parent agent** delegates specific tasks to **specialized subagents**.
Subagents handle distinct responsibilities, then return results to the parent.

## When to Use
- Workflow orchestration
- Modular task processing
- Complex pipelines with clear handoffs
- Any task where **different subagents excel at different parts**

## Structure
```
[Parent Agent: Orchestrator]
       │
       ├───▶ [Subagent 1: File Reader]
       ├───▶ [Subagent 2: Code Analyzer]
       └────▶ [Subagent 3: Report Generator]
```

## Configuration Template
```toml

display_name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "{safety_level}"
bypass_tool_permissions = {bypass_tool_permissions}
system_prompt_id = "{agent_id}"

enabled_tools = ["read_file", "grep", "task", "ask_user_question"]
disabled_tools = ["write_file", "search_replace"]

[tools.task]
permission = "always"  # CRITICAL: Required for delegation

[tools.read_file]
permission = "always"

[tools.grep]
permission = "always"

[tools.ask_user_question]
permission = "always"

[session_logging]
session_prefix = "{agent_id}"
enabled = true
```

## Required Tools
- `task` (permission = `"always"`) - **Non-negotiable** for delegation

## Required Settings

## Example
```toml

display_name = "GIR"
description = "Graph Intelligence Runner - creates knowledge graphs"
agent_type = "agent"
safety = "neutral"
system_prompt_id = "gir"

enabled_tools = ["read_file", "grep", "task"]
disabled_tools = ["write_file", "bash"]

[tools.task]
permission = "always"
```
