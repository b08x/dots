# Stateful Agent Pattern

## Overview
Agent **maintains state across interactions**, enabling multi-turn workflows.
Uses **todo lists**, **session variables**, or **external storage** for persistence.

## When to Use
- Chat assistants
- Multi-step workflows
- Interactive tools
- Any task requiring **memory of past interactions**

## Structure
```
[Agent: Stateful]
       │
       ├───▶ State: Todo List (task progress)
       ├───▶ State: Session Variables (user preferences)
       └────▶ State: External Storage (database)
```

## Configuration Template
```toml

display_name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "{safety_level}"
bypass_tool_permissions = false
system_prompt_id = "{agent_id}"

enabled_tools = ["todo", "ask_user_question", "read_file", "write_file"]
disabled_tools = ["bash", "task"]

[tools.todo]
permission = "always"

[tools.ask_user_question]
permission = "always"

[tools.read_file]
permission = "always"

[tools.write_file]
permission = "ask"

[session_logging]
session_prefix = "{agent_id}"
enabled = true
```

## Required Tools
- `todo` (permission = `"always"`) - **Core tool** for state management
- `ask_user_question` (permission = `"always"`) - For interaction

## State Management Strategies
| **Strategy** | **Use Case** | **Implementation** |
|--------------|--------------|---------------------|
| Todo List | Task progress tracking | Built-in `todo` tool |
| Session Variables | Temporary user preferences | Mistral Vibe session context |
| External Storage | Persistent data | Database/API integration |
| File-based | Simple persistence | `write_file`/`read_file` |

## Example
```toml

display_name = "Interactive Assistant"
description = "Assists users with multi-turn conversations"
agent_type = "agent"
safety = "neutral"
system_prompt_id = "interactive-assistant"

enabled_tools = ["todo", "ask_user_question", "read_file"]
disabled_tools = ["bash", "task", "write_file"]

[tools.todo]
permission = "always"

[tools.ask_user_question]
permission = "always"
```
