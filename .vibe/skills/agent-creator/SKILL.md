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

Branch to skill-architect:
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

## STEP 10: Generate Agent TOML

Load template:
```
template_path = "$BASE/templates/" + pattern_id + ".toml"
read_file(path=template_path)
```

If file not found:
```
read_file(path="$BASE/templates/agent.toml")
```

Store template content as `template`.

Prepare config for substitution:
```python
final_config = config.copy()
for key, value in final_config.items():
    if isinstance(value, list):
        if all(isinstance(v, str) for v in value):
            final_config[key] = '["' + '", "'.join(value) + '"]'
        else:
            final_config[key] = str(value)
    elif isinstance(value, bool):
        final_config[key] = str(value).lower()
    elif value is None:
        final_config[key] = '""'
```

Apply substitutions:
```python
for key, value in final_config.items():
    template = template.replace("{" + key + "}", str(value))
```

Write agent file:
```
agent_id = config["agent_id"]
write_file(
  path=AGENTS_DIR + "/" + agent_id + ".toml",
  content=template
)
```

---

## STEP 11: Generate Prompt File

```python
prompt_content = "# " + config.get("agent_name", agent_id) + " System Prompt\n\n"
prompt_content += "## Role\n"
prompt_content += config.get("description", "A specialized agent for Mistral Vibe.") + "\n\n"
prompt_content += "## Responsibilities\n"
prompt_content += config.get("agent_description", "Perform tasks as requested by the user.") + "\n\n"
prompt_content += "## Pattern\n"
prompt_content += "This agent implements the **" + pattern_name + "** pattern.\n"
prompt_content += "See: " + BASE + "/references/Agent Skill Design Patterns.md\n\n"
prompt_content += "## Workflow\n"
prompt_content += "1. Analyze the user's request.\n"
prompt_content += "2. Execute the appropriate action.\n"
prompt_content += "3. Return results to the user.\n\n"
prompt_content += "---\n"
prompt_content += "**Generated by agent-creator**\n"
prompt_content += "**Pattern:** " + pattern_name + "\n"
```

Write prompt:
```
write_file(
  path=PROMPTS_DIR + "/" + agent_id + ".md",
  content=prompt_content
)
```

---

## STEP 12: Generate Subagent TOMLs (if applicable)

Check if pattern supports subagents AND config has subagent_ids:
```python
if pattern_id in ["multi-agent-debate", "subagent-delegation", "hybrid-pipeline"]:
    subagent_ids = config.get("subagent_ids", "")
    if isinstance(subagent_ids, str):
        subagent_ids = [s.strip() for s in subagent_ids.split(",") if s.strip()]
    
    for sa_id in subagent_ids:
        subagent_template = read_file(path="$BASE/templates/subagent.toml")
        subagent_content = subagent_template.replace("{subagent_id}", sa_id)
        write_file(path=AGENTS_DIR + "/" + sa_id + ".toml", content=subagent_content)
```

---

## STEP 13: Final Summary

```python
skills_str = ", ".join(config.get("enabled_skills", [])) or "None"
subagents_list = config.get("subagent_ids", "")
if isinstance(subagents_list, str):
    subagents_list = [s.strip() for s in subagents_list.split(",") if s.strip()]

subagents_files = ""
if subagents_list:
    for sa in subagents_list:
        subagents_files += "\n    - " + AGENTS_DIR + "/" + sa + ".toml"

summary = "✅ Agent creation complete!\n\n"
summary += "**Agent:** " + agent_id + "\n"
summary += "**Pattern:** " + pattern_name + "\n"
summary += "**Skills:** " + skills_str + "\n\n"
summary += "**Files created:**\n"
summary += "- " + AGENTS_DIR + "/" + agent_id + ".toml\n"
summary += "- " + PROMPTS_DIR + "/" + agent_id + ".md"
summary += subagents_files + "\n\n"
summary += "Test your new agent with: `vibe --agent " + agent_id + "`"
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
