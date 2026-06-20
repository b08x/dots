# Single Agent Pattern

## Overview
**Simple, self-contained agent** for focused, single-purpose tasks.
No subagents, no delegation — just direct execution.

## When to Use
- Documentation generation
- File analysis
- Simple transformations
- Any task that **doesn’t require multiple perspectives or subagents**

## Structure
```
[Single Agent]
   │
   ├───▶ Tool: read_file
   ├───▶ Tool: grep
   └────▶ Tool: write_file (optional)
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
user_invocable = {user_invocable}

[config]
enabled_tools = {enabled_tools}
disabled_tools = {disabled_tools}

{tool_permissions}

[project_context]
timeout_seconds = 5.0

[session_logging]
session_prefix = "{agent_id}"
enabled = true
```

## Required Tools
- At least **one** tool (e.g., `read_file`)

## Recommended Tools
- `read_file` (permission = `"always"`)
- `grep` (permission = `"always"`)
- `ask_user_question` (permission = `"always"`)

## Example
```toml

id = "readme-generator"
name = "README Generator"
description = "Generates production-quality README files"
agent_type = "agent"
safety = "neutral"

[config]
enabled_tools = ["read_file", "write_file", "grep"]

[tools.read_file]
permission = "always"

[tools.write_file]
permission = "ask"
denylist = ["~/.vibe/", "~/.ssh/"]
```
