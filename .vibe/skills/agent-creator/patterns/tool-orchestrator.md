# Tool Orchestrator Pattern

## Overview
Agent **coordinates external tools/APIs** to perform complex operations.
Acts as a **wrapper** around CLI tools, APIs, or services.

## When to Use
- API clients
- CLI tool wrappers
- Service integrations
- Any task requiring **external system coordination**

## Structure
```
[Agent: Orchestrator]
       │
       ├───▶ Tool: bash (curl, git, etc.)
       ├───▶ Tool: write_file (for configs)
       └────▶ Tool: read_file (for inputs)
```

## Configuration Template
```toml

display_name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "{safety_level}"
bypass_tool_permissions = false
system_prompt_id = "{agent_id}"

enabled_tools = ["bash", "read_file", "write_file", "ask_user_question"]
disabled_tools = ["grep", "task"]

[tools.bash]
permission = "ask"
allowlist = {bash_allowlist}
denylist = [
    "rm", "rm -rf", "sudo", "su", "passwd", "dd", "mkfs",
    "chmod -R", "chown", "chgrp", "> /dev/sd*", "mv /", "cp -r /"
]

[tools.read_file]
permission = "always"

[tools.write_file]
permission = "ask"

[tools.ask_user_question]
permission = "always"

[session_logging]
session_prefix = "{agent_id}"
enabled = true
```

## Required Tools
- `bash` (permission = `"ask"` or `"always"`) - **Core tool** for orchestration

## Security Considerations
- **Always** include a `bash` denylist
- **Restrict** allowlist to only required commands
- **Avoid** `permission = "always"` for `bash` unless in a trusted environment

## Example
```toml

display_name = "GitHub Automation"
description = "Automates GitHub repository operations"
agent_type = "agent"
safety = "neutral"
system_prompt_id = "github-automation"

enabled_tools = ["bash", "read_file", "write_file"]
disabled_tools = ["grep", "task"]

[tools.bash]
permission = "ask"
allowlist = ["git", "gh", "curl", "jq"]
denylist = ["rm -rf", "sudo", "dd", "mkfs"]
```
