# Chain-of-Verification (CoVe) Pattern

## Overview
Agent **validates its own work** through a structured verification process.
Each step generates **questions to verify correctness**, then answers them.

## When to Use
- Quality assurance
- Testing
- Self-validating workflows
- Any task where **accuracy verification is critical**

## Structure
```
[Agent]
   │
   ├───▶ Step 1: Initial Analysis
   ├───▶ Step 2: Generate Verification Questions
   ├───▶ Step 3: Answer Questions
   └────▶ Step 4: Final Validation
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

[config]
enabled_tools = ["read_file", "grep", "ask_user_question"]
disabled_tools = ["write_file", "search_replace", "bash"]

[tools.read_file]
permission = "always"

[tools.grep]
permission = "always"

[tools.ask_user_question]
permission = "always"

[project_context]
timeout_seconds = 5.0

[session_logging]
session_prefix = "{agent_id}"
enabled = true
```

## Required Tools
- `read_file` (permission = `"always"`) - For analysis
- `grep` (permission = `"always"`) - For searching
- `ask_user_question` (permission = `"always"`) - For verification questions

## CoVe Process
1. **Initial Analysis**: Perform the primary task
2. **Generate Questions**: Create 3-5 questions to verify the work
   - Example: "Does this code handle edge case X?"
   - Example: "Is this implementation aligned with requirement Y?"
3. **Answer Questions**: Provide detailed answers with reasoning
4. **Final Validation**: Synthesize answers into a confidence score

## Example
```toml

id = "quality-validator"
name = "Quality Validator"
description = "Validates code against quality standards using CoVe"

[config]
enabled_tools = ["read_file", "grep", "ask_user_question"]
```
