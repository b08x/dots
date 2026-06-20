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

id = "{agent_id}"
name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "{safety_level}"
auto_approve = {auto_approve}
system_prompt_id = "{agent_id}"
user_invocable = true

[config]
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
denylist = ["~/.vibe/", "~/.ssh/", "/etc/"]

[project_context]
timeout_seconds = 5.0
```

## Required Tools
- `bash` (permission = `"ask"` or `"always"`) - **Core tool** for orchestration

## Security Considerations
- **Always** include a `bash` denylist
- **Restrict** allowlist to only required commands
- **Avoid** `permission = "always"` for `bash` unless in a trusted environment

## Example
```toml

id = "github-automation"
name = "GitHub Automation"
description = "Automates GitHub repository operations"

[tools.bash]
permission = "ask"
allowlist = ["git", "gh", "curl", "jq"]
denylist = ["rm -rf", "sudo", "dd", "mkfs"]
```
