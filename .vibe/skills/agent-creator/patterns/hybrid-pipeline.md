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

id = "{agent_id}"
name = "{agent_name}"
description = """{description}"""
agent_type = "agent"
safety = "{safety_level}"
auto_approve = false
system_prompt_id = "{agent_id}"
user_invocable = true

# Pattern 1: Multi-Agent Debate



# Pattern 2: Chain-of-Verification
[config]
enabled_tools = ["read_file", "grep", "task", "ask_user_question"]

[tools.task]
permission = "always"

[tools.read_file]
permission = "always"

[tools.grep]
permission = "always"

[tools.ask_user_question]
permission = "always"

[project_context]
timeout_seconds = 5.0
```

## Required Tools
- Depends on **selected patterns**
- Typically includes: `task`, `read_file`, `grep`, `ask_user_question`

## Example: Multi-Agent Debate + CoVe
```toml

id = "ultra-reviewer"
name = "Ultra Reviewer"
description = "Combines Multi-Agent Debate with CoVe for maximum confidence"



[tools.task]
permission = "always"

[tools.ask_user_question]
permission = "always"
```

## Customization
1. Select **base patterns** to combine
2. Define **interaction rules** between patterns
3. Configure **handoff conditions**
