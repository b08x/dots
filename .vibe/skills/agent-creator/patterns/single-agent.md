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

display_name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "{safety_level}"
bypass_tool_permissions = {bypass_tool_permissions}
system_prompt_id = "{agent_id}"

enabled_tools = {enabled_tools}
disabled_tools = {disabled_tools}

[tools.read_file]
permission = "always"

[tools.grep]
permission = "always"

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

display_name = "README Generator"
description = "Generates production-quality README files"
agent_type = "agent"
safety = "neutral"
bypass_tool_permissions = false
system_prompt_id = "readme-generator"

enabled_tools = ["read_file", "write_file", "grep"]
disabled_tools = ["bash", "task"]

[tools.read_file]
permission = "always"

[tools.grep]
permission = "always"

[tools.write_file]
permission = "ask"

[session_logging]
session_prefix = "readme-generator"
enabled = true
```
