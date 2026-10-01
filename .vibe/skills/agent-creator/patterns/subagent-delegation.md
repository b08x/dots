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

id = "{agent_id}"
name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "{safety_level}"
auto_approve = {auto_approve}
system_prompt_id = "{agent_id}"
user_invocable = true




[config]
enabled_tools = ["read_file", "grep", "task", "ask_user_question"]
disabled_tools = {disabled_tools}

[tools.task]
permission = "always"  # CRITICAL: Required for delegation

[tools.read_file]
permission = "always"

[tools.grep]
permission = "always"

{tool_permissions}

[project_context]
timeout_seconds = 5.0
```

## Required Tools
- `task` (permission = `"always"`) - **Non-negotiable** for delegation

## Required Settings

## Example
```toml

id = "gir"
name = "GIR"
description = "Graph Intelligence Runner - creates knowledge graphs"



[tools.task]
permission = "always"
```
