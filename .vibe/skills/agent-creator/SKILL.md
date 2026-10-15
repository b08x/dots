---
name: agent-creator
description: >
  Interactive agent creation workflow that guides developers through defining new Mistral Vibe agents.
  Asks targeted questions, applies design patterns, and generates standardized TOML + prompt files.
  Branches to skill-architect when new skills are needed.
license: MIT
compatibility: Mistral Vibe CLI 1.0+
user-invocable: true
allowed-tools:
  - ask_user_question
  - write_file
  - read_file
  - grep
  - task
  - bash
---

# Agent Creator

**You are the Agent Creator.** When invoked via `/create-agent` or `/agent-creator`, follow this workflow **exactly**.

---

## CONSTANTS

```
BASE = "/home/b08x/.vibe/skills/agent-creator"
AGENTS_DIR = "/home/b08x/.vibe/agents"
PROMPTS_DIR = "/home/b08x/.vibe/prompts"
```

---

## STEP 1: Load Registry (JSON for easier parsing)

```bash
bash(command="python3 -c \"import yaml, sys, json; r=yaml.safe_load(open('"$BASE"/patterns/registry.yaml')); print(json.dumps(r))\"")
```
Store the JSON output as `REGISTRY`.

---

## STEP 2: Classify Purpose

Ask user for agent purpose:

```
response = ask_user_question({
  "questions": [{
    "question": "What is your agent's PRIMARY purpose?",
    "header": "Purpose",
    "options": [
      {"label": "Analyze/Review", "description": "Evaluate existing work (code review, requirements validation)"},
      {"label": "Generate/Create", "description": "Produce new artifacts (docs, configs, templates)"},
      {"label": "Orchestrate/Coordinate", "description": "Manage workflows, agents, or multi-step processes"},
      {"label": "Interact/Respond", "description": "Chat, Q&A, or conversational agents"},
      {"label": "Transform/Process", "description": "Modify or process data (pipelines, conversions)"},
      {"label": "Custom/Other", "description": "Doesn't fit the above categories"}
    ]
  }]
})
```

Extract `purpose = response["questions"][0]["answer"]`

Map to pattern:
```python
purpose_map = {
    "Analyze/Review": "multi-agent-debate",
    "Generate/Create": "single-agent",
    "Orchestrate/Coordinate": "subagent-delegation",
    "Interact/Respond": "stateful-agent",
    "Transform/Process": "cove",
    "Custom/Other": "hybrid-pipeline"
}
pattern_id = purpose_map.get(purpose, "single-agent")
```

---

## STEP 3: Get Pattern Info from Registry

```bash
bash(command="python3 -c \"import json, sys; r=json.loads(sys.stdin); print(json.dumps(r['patterns']['" + pattern_id + "']))\" <<< '\${REGISTRY}'")
```
Store as `pattern_info`.

Extract `pattern_name = pattern_info["name"]`
Extract `pattern_desc = pattern_info["description"]`

---

## STEP 4: Confirm Pattern Selection

```
confirm_response = ask_user_question({
  "questions": [{
    "question": "Based on your purpose, I recommend the **" + pattern_name + "** pattern (" + pattern_desc + "). Use this pattern?",
    "header": "Pattern Selection",
    "options": [
      {"label": "Yes", "value": pattern_id},
      {"label": "No, show other patterns", "value": "show_all"},
      {"label": "No, specify manually", "value": "manual"}
    ]
  }]
})
```

Extract `selection = confirm_response["questions"][0]["answer"]`

### If selection == "show_all":

Build options from all patterns:
```bash
bash(command="python3 -c \"import json, sys; r=json.loads(sys.stdin); patterns=r['patterns']; print(json.dumps([{'label': p['name'], 'value': k, 'description': p['description']} for k,p in patterns.items()]))\" <<< '\${REGISTRY}'")
```
Store as `pattern_options`.

```
list_response = ask_user_question({
  "questions": [{
    "question": "Select a pattern:",
    "header": "All Patterns",
    "options": pattern_options
  }]
})
```
Extract `pattern_id = list_response["questions"][0]["answer"]`

Update pattern_info:
```bash
bash(command="python3 -c \"import json, sys; r=json.loads(sys.stdin); print(json.dumps(r['patterns']['" + pattern_id + "']))\" <<< '\${REGISTRY}'")
```
Store as `pattern_info`.

### If selection == "manual":

```
manual_response = ask_user_question({
  "questions": [{
    "question": "Enter pattern ID:",
    "header": "Manual Pattern",
    "options": []
  }]
})
```
Extract `pattern_id = manual_response["questions"][0]["answer"]`

Update pattern_info (same bash command as above).

---

## STEP 5: Load and Parse Questions

### Helper: Load YAML Questions

```bash
# Generic YAML loader - use for any question file
# Input: filename (e.g., "metadata.yaml")
# Output: JSON array of questions
bash(command="python3 -c \"import yaml, sys; q=yaml.safe_load(open('"$BASE"/questions/" + sys.argv[1])); print(json.dumps(q.get('questions', [])))\" " + filename)
```

### 5.1 Load Metadata Questions

```bash
bash(command="python3 -c \"import yaml, sys; q=yaml.safe_load(open('"$BASE"/questions/metadata.yaml')); print(json.dumps(q.get('questions', [])))\"")
```
Store as `metadata_questions_json`.

Initialize `config = {"pattern_id": pattern_id, "pattern_name": pattern_name}`

For each question in metadata_questions_json:
  - Determine multi_select: `q.get("type") == "multi_choice"`
  - Build options: `q.get("options", [])`
  - Ask user
  - Extract answer
  - Store in config[question["id"]]
  - For boolean: convert to Python boolean
  - For multi_choice: store as list
  - For agent_id: validate format `[a-z0-9_-]+`

### 5.2 Load Pattern-Specific Questions

Check if pattern file exists:
```bash
bash(command="test -f \"$BASE/questions/\" + pattern_id + ".yaml\" && echo EXISTS || echo MISSING")
```

If EXISTS:
  ```bash
  bash(command="python3 -c \"import yaml, sys; q=yaml.safe_load(open('"$BASE"/questions/" + pattern_id + ".yaml')); print(json.dumps(q.get('questions', [])))\"")
  ```
  Store as `pattern_questions_json`.
  
  For each question in pattern_questions_json:
    - Ask user and store in config

---

## STEP 6: Handle Skills

```
skill_response = ask_user_question({
  "questions": [{
    "question": "How should this agent handle skills?",
    "header": "Skills",
    "options": [
      {"label": "Use existing skills only", "value": "existing"},
      {"label": "Create new skill(s) for this agent", "value": "new"},
      {"label": "Both existing and new skills", "value": "mixed"}
    ]
  }]
})
```

Extract `skill_choice = skill_response["questions"][0]["answer"]`

### If skill_choice == "existing":

```
existing_response = ask_user_question({
  "questions": [{
    "question": "Which existing skills? (comma-separated, leave empty for none)",
    "header": "Existing Skills",
    "options": []
  }]
})
```
Extract skills: `config["enabled_skills"] = [s.strip() for s in existing_response["questions"][0]["answer"].split(",") if s.strip()]`

### If skill_choice == "new":

```
purpose_response = ask_user_question({
  "questions": [{
    "question": "What is the PRIMARY purpose of the new skill?",
    "header": "New Skill Purpose",
    "options": []
  }]
})
```
Extract `purpose = purpose_response["questions"][0]["answer"]`

Branch to skill-architect (the target must be a registered
`agent_type = "subagent"` profile with a non-empty description; if none is
available, create the skill inline using the skill-creator skill instead):
```
skill_name = task(
  agent="skill-architect",
  task="Create a skill for: " + purpose + ". Return ONLY the skill name."
)
```
Store: `config["enabled_skills"] = [skill_name.strip()]`

### If skill_choice == "mixed":

Get existing skills (same as above), then:

```
purpose_response = ask_user_question({
  "questions": [{
    "question": "What is the PRIMARY purpose of the NEW skill?",
    "header": "New Skill Purpose",
    "options": []
  }]
})
```

Branch to skill-architect:
```
skill_name = task(
  agent="skill-architect",
  task="Create a skill for: " + purpose + ". Return ONLY the skill name."
)
```
Store: `config["enabled_skills"] = existing_skills + [skill_name.strip()]`

---

## STEP 7: Load Tool Questions

```bash
bash(command="python3 -c \"import yaml, sys; q=yaml.safe_load(open('"$BASE"/questions/tools.yaml')); print(json.dumps(q.get('questions', [])))\"")
```
Store as `tool_questions_json`.

For each question in tool_questions_json:
  - Ask user and store in config

---

## STEP 8: Load Security Questions

```bash
bash(command="python3 -c \"import yaml, sys; q=yaml.safe_load(open('"$BASE"/questions/security.yaml')); print(json.dumps(q.get('questions', [])))\"")
```
Store as `security_questions_json`.

For each question in security_questions_json:
  - Check condition: replace `{enabled_tools}` with str(config.get("enabled_tools", []))
  - Evaluate condition using Python
  - If true, ask user and store in config

---

## STEP 9: Load Subagent Questions (if applicable)

Check if pattern supports subagents:
```python
supports_subagents = pattern_id in ["multi-agent-debate", "subagent-delegation", "hybrid-pipeline"]
```

If supports_subagents:
  ```bash
  bash(command="python3 -c \"import yaml, sys; q=yaml.safe_load(open('"$BASE"/questions/subagents.yaml')); print(json.dumps(q.get('questions', [])))\"")
  ```
  Store as `subagent_questions_json`.
  
  For each question in subagent_questions_json:
    - Check condition: replace `{spawns_subagents}` with str(config.get("spawns_subagents", False))
    - Evaluate using Python
    - If true, ask user and store in config

---

## STEP 10: Generate Files via the Workflow Script

Collect everything into a single answers JSON and hand file generation to
`agent_creator_workflow.py`. **Never assemble the TOML by hand.** The script
is a pure non-interactive generator: it never reads stdin (Vibe's bash tool
is non-interactive, so `input()` would hit end-of-input immediately) and it
enforces every schema fact below.

Write the answers to `~/.vibe/temp/agent-creator/<agent_id>.answers.json`:

```json
{
  "agent_id": "my-agent",
  "agent_name": "My Agent",
  "description": "...",
  "agent_type": "agent",
  "safety": "neutral",
  "bypass_tool_permissions": false,
  "enabled_tools": [],
  "disabled_tools": [],
  "enabled_skills": [],
  "bash_allowlist": [],
  "delegate_sfl": false,
  "pattern_name": "Single Agent",
  "subagents": [
    {"subagent_id": "my-agent-reader", "description": "Non-empty or it is never advertised."}
  ]
}
```

The `subagents` array is built from the answers collected in STEP 9: each
`subagent_ids` entry needs at least a `subagent_id` and a NON-EMPTY
`description` (the script rejects empty descriptions — such subagents are
never advertised). Tools default to `["read_file", "grep"]`.

Run `python3 skills/agent-creator/agent_creator_workflow.py --schema` once to
print the exact answers schema. Then preview with a dry run:

```bash
bash(command="python3 ~/.vibe/skills/agent-creator/agent_creator_workflow.py ~/.vibe/temp/agent-creator/<agent_id>.answers.json --dry-run")
```

The script writes, all schema-valid:
- `AGENTS_DIR/<agent_id>.toml` — the agent profile
- `PROMPTS_DIR/<system_prompt_id>.md` — the prompt `system_prompt_id` points at
- one TOML + prompt per `subagents` entry, with `agent_type = "subagent"`

Exit codes: `0` = OK (or dry-run complete), `1` = validation error (nothing
written), `2` = usage error, `3` = SFL delegation requested (see STEP 11).
All validation happens before any write, so a failed run never leaves partial
files behind, and existing files are never overwritten without `--force`.

Schema notes (verified against mistral-vibe `vibe/core/agents/models.py`) —
the script enforces all of these, and you must review against them:
- The agent name comes from the FILENAME stem — there is no `id` key, and no
  `name` key. Display text belongs in `display_name`.
- Profile fields: `display_name`, `description`, `safety`, `agent_type`,
  `instructions`. Everything else is a config override
  (`enabled_tools`, `disabled_tools`, `enabled_skills`,
  `bypass_tool_permissions`, `system_prompt_id`, `[tools.*]`,
  `[session_logging]`) — all top-level, no `[config]` wrapper.
- `agent_type = "agent"` (default) = selectable via `vibe --agent`;
  `agent_type = "subagent"` = spawn-only via agentType (tools.subagent.spawn),
  and `--agent` rejects it. Subagents MUST have a non-empty `description`,
  or they are not advertised to the spawning agent.
- `enabled_tools` is a glob allowlist. An EMPTY list means "no
  restriction" (all tools stay), NOT "no tools". To disable every tool,
  use `disabled_tools = ["*"]`. A tool must never appear in both lists.
- There is no `auto_approve` key — use `bypass_tool_permissions`.
- There is no `user_invocable` key.
- `task` always gets `permission = "always"` when enabled — non-negotiable
  for delegation (patterns/subagent-delegation.md).
- `system_prompt_id` resolves to a `.md` file in `~/.vibe/prompts/` or
  the project's `.vibe/prompts/`. An inline `instructions` value takes
  precedence over it.

---

## STEP 11: SFL Delegation Handshake (optional)

If the answers set `"delegate_sfl": true` and no prompt text is supplied, the
script prints an `[AGENT_TASK_REQUEST]` block (JSON with `agent` + `task`)
and exits with code 3 **without writing anything**. When you see it:

1. Parse the JSON inside the block.
2. Delegate with the `task` tool to the requested subagent (e.g.,
   `sfl-prompt-engineer`), passing the full context of the agent being
   created (name, purpose, skills). The target must be a registered
   `agent_type = "subagent"` profile with a non-empty description.
3. Save the subagent's output to
   `~/.vibe/temp/agent-creator/<agent_id>.sfl-prompt.md`.
4. Re-run the script with `--sfl-prompt-file <that path>`.

If the SFL step is skipped, the script generates a full structured prompt
itself (Role / Responsibilities / Pattern / Skills / Workflow) — there is no
stub.

---

## STEP 12: Validate and Write

1. Review the `--dry-run` output against the schema notes in STEP 10.
2. Show the user what will be created and get explicit confirmation
   (ask_user_question) — nothing hits disk without approval.
3. Re-run the script WITHOUT `--dry-run`. The script refuses to overwrite
   existing files unless you pass `--force`; confirm with the user before
   ever using `--force`.
4. `read_file` the written TOML(s) for a final schema review.

---

## STEP 13: Final Summary

```python
skills_str = ", ".join(config.get("enabled_skills", [])) or "None"
subagents = config.get("subagents") or []
subagent_names = [sa["subagent_id"] for sa in subagents]

subagents_files = ""
for sa_name in subagent_names:
    subagents_files += "\n    - " + AGENTS_DIR + "/" + sa_name + ".toml"
    subagents_files += "\n    - " + PROMPTS_DIR + "/" + sa_name + ".md"

summary = "✅ Agent creation complete!\n\n"
summary += "**Agent:** " + agent_id + "\n"
summary += "**Pattern:** " + pattern_name + "\n"
summary += "**Skills:** " + skills_str + "\n\n"
summary += "**Files created:**\n"
summary += "- " + AGENTS_DIR + "/" + agent_id + ".toml\n"
summary += "- " + PROMPTS_DIR + "/" + agent_id + ".md\n"
summary += subagents_files + "\n\n"

test_cmd = "vibe --agent " + agent_id
if config.get("agent_type", "agent") == "subagent":
    test_cmd = "spawn it from another agent via task (agentType: " + agent_id + ")"
summary += "Test your new agent with: `" + test_cmd + "`"
```

```
ask_user_question({
  "questions": [{
    "question": summary,
    "header": "Complete",
    "options": [{"label": "OK", "value": "ok"}]
  }]
})
```

---

## Helper Functions

### YAML to JSON Parser

For any YAML file at path `$BASE/[subdir]/[file].yaml`:
```bash
bash(command="python3 -c \"import yaml, sys, json; print(json.dumps(yaml.safe_load(open('" + sys.argv[1] + "'))))\" \"$BASE/[subdir]/[file].yaml\"")
```

### Python Boolean Conversion

```python
bool_value = answer.lower() in ["true", "yes", "y", "1"]
```

### TOML Array Formatter

```python
array_str = '["' + '", "'.join(list_of_strings) + '"]'
```

### Validate Agent ID

```python
import re
if not re.match(r'^[a-z0-9_-]+$', agent_id):
    # Auto-fix
    agent_id = re.sub(r'[^a-z0-9]+', '-', agent_id.lower()).strip('-')
```

---

## Error Handling

If any tool call fails:
1. Display error message to user
2. Ask: "Retry or abort?"
3. On retry: Go back to previous step
4. On abort: Exit workflow cleanly
