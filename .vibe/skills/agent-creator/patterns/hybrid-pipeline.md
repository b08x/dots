# Hybrid Pipeline Pattern

## Overview
**Custom combination** of multiple patterns to solve complex workflows.
Example: **Multi-Agent Debate + Chain-of-Verification** for ultra-high-confidence reviews.

## When to Use
- Complex workflows with mixed requirements
- High-stakes decisions requiring multiple validation layers
- Custom agent architectures

## Structure
```
[Hybrid Agent]
       │
       ├───▶ [Pattern 1: Multi-Agent Debate]
       │     │
       │     ├───▶ Judge A
       │     ├───▶ Judge B
       │     └────▶ Judge C
       │
       └────▶ [Pattern 2: Chain-of-Verification]
             │
             ├───▶ CoVe Step 1
             ├───▶ CoVe Step 2
             └────▶ CoVe Step 3
```

## Configuration Template
```toml

# Pattern 1: Multi-Agent Debate
# Pattern 2: Chain-of-Verification
display_name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "{safety_level}"
bypass_tool_permissions = false
system_prompt_id = "{agent_id}"

enabled_tools = ["read_file", "grep", "task", "ask_user_question"]
disabled_tools = ["write_file", "search_replace"]

[tools.task]
permission = "always"

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
- Depends on **selected patterns**
- Typically includes: `task`, `read_file`, `grep`, `ask_user_question`

## Example: Multi-Agent Debate + CoVe
```toml

display_name = "Ultra Reviewer"
description = "Combines Multi-Agent Debate with CoVe for maximum confidence"
agent_type = "agent"
safety = "neutral"
system_prompt_id = "ultra-reviewer"

enabled_tools = ["read_file", "grep", "task", "ask_user_question"]
disabled_tools = ["write_file", "search_replace", "bash"]

[tools.task]
permission = "always"

[tools.ask_user_question]
permission = "always"
```

## Customization
1. Select **base patterns** to combine
2. Define **interaction rules** between patterns
3. Configure **handoff conditions**
