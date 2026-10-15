# Agent Creator
**Interactive agent creation workflow for Mistral Vibe with design pattern integration and skill branching**

---

## 📌 **Overview**

**Agent Creator** is a **modular, progressive-closure system** for creating Mistral Vibe agents that:
- Guides users through agent creation with **targeted questions**
- Applies **proven design patterns** from `Agent Skill Design Patterns.md`
- **Branches to `skill-architect`** when new skills are needed
- Generates **standardized TOML configurations** and prompt files
- Minimizes context usage with **on-demand loading** of patterns and questions

---

## 🎯 **Features**

| Feature | Description |
|---------|-------------|
| **Pattern-Based Creation** | Uses 7 proven design patterns (Single Agent, Multi-Agent Debate, Subagent Delegation, etc.) |
| **Skill Branching** | Automatically invokes `skill-architect` when new skills are needed |
| **Modular Architecture** | Patterns, questions, and templates are loaded on-demand |
| **Progressive Closure** | Only ~80 lines in context at any time (vs. 700+ with embedded patterns) |
| **Error Handling** | Comprehensive validation and fallback mechanisms |
| **Standardized Output** | Generates valid flat TOML files with `[tools.*]` blocks |
| **Full Documentation** | Auto-generates prompt files with pattern references |

---

## 🏗 **Architecture**

```
agent-creator/
├── README.md                          # This file
├── agent_creator_workflow.py    # Main workflow script
│
├── patterns/                         # Design pattern definitions
│   ├── registry.yaml                 # Pattern metadata
│   ├── single-agent.md               # Single Agent pattern
│   ├── multi-agent-debate.md         # Multi-Agent Debate pattern
│   ├── subagent-delegation.md        # Subagent Delegation pattern
│   ├── cove.md                       # Chain-of-Verification pattern
│   ├── tool-orchestrator.md          # Tool Orchestrator pattern
│   ├── stateful-agent.md             # Stateful Agent pattern
│   └── hybrid-pipeline.md            # Hybrid Pipeline pattern
│
├── questions/                        # Modular question groups
│   ├── purpose.yaml                  # Purpose classification
│   ├── metadata.yaml                 # Agent identity
│   ├── tools.yaml                    # Tool selection
│   ├── security.yaml                 # Security settings
│   ├── subagents.yaml                # Subagent configuration
│   └── skills.yaml                   # Skill assignment + branching
│
├── templates/                        # TOML templates
│   ├── agent.toml                    # Base agent template
│   ├── subagent.toml                 # Base subagent template
│   ├── single-agent.toml             # Single Agent template
│   ├── multi-agent-debate.toml       # Multi-Agent Debate template
│   ├── subagent-delegation.toml      # Subagent Delegation template
│   ├── cove.toml                     # Chain-of-Verification template
│   ├── tool-orchestrator.toml        # Tool Orchestrator template
│   └── hybrid-pipeline.toml          # Hybrid Pipeline template
│
└── references/                       # External references
    └── Agent Skill Design Patterns.md  # Full patterns document
```

**Agent Definition:**
- `~/.vibe/agents/agent-creator.toml` - Mistral Vibe agent configuration

**Dependencies:**
- `skill-architect` agent (for skill creation)
- `skill-researcher` subagent (assists skill-architect)

---

## 📥 **Setup**

### **1. Prerequisites**
- Mistral Vibe CLI installed
- Python 3.10+ (for script execution)
- `tomli` and `tomli_w` Python packages:
  ```bash
  pip install tomli tomli_w pyyaml
  ```

### **2. Install the System**
```bash
# Create the directory structure
mkdir -p ~/.vibe/skills/agent-creator/{patterns,questions,templates,references}

# Copy all files from this README's sibling canvases into the appropriate directories
# For example:
# - Copy pattern .md files to ~/.vibe/skills/agent-creator/patterns/
# - Copy question .yaml files to ~/.vibe/skills/agent-creator/questions/
# - Copy template .toml files to ~/.vibe/skills/agent-creator/templates/
# - Copy agent-creator.toml to ~/.vibe/agents/
# - Copy agent_creator_workflow.py to ~/.vibe/skills/agent-creator/
```

### **3. Enable Required Agents**
Add to `~/.vibe/config.toml`:
```toml
enabled_agents = [
    # ... your existing agents ...
    "agent-creator",
    "skill-architect",
    "skill-researcher"
]
```

### **4. Verify Setup**
```bash
# Check all files are in place
ls -l ~/.vibe/skills/agent-creator/{patterns,questions,templates}/

# Check agent is enabled
grep "agent-creator" ~/.vibe/config.toml

# Check skill-architect is enabled
grep "skill-architect" ~/.vibe/config.toml
```

---

## 🚀 **Usage**

### **Method 1: Slash Command (Recommended)**
```bash
vibe
> /create-agent
```
or
```bash
vibe
> /agent-creator
```

### **Method 2: Direct Agent Invocation**
```bash
vibe --agent agent-creator
```

### **Method 3: Standalone Script (non-interactive generator)**
The script is a pure generator: it reads an answers JSON file and never reads
stdin. Collect the answers yourself, then:
```bash
python3 ~/.vibe/skills/agent-creator/agent_creator_workflow.py --schema   # answers schema
python3 ~/.vibe/skills/agent-creator/agent_creator_workflow.py answers.json --dry-run
python3 ~/.vibe/skills/agent-creator/agent_creator_workflow.py answers.json            # writes
```

---

## 🎭 **Example Session**

The wizard asks its questions through the `ask_user_question` UI; the script
is only invoked at generation time and never prompts.

```
> /create-agent

(Purpose)       What is your agent's PRIMARY purpose?
                → Analyze/Review
(Pattern)       Recommended: Multi-Agent Debate. Use this pattern? → Yes
(Metadata)      Display name → "Ansible Review Coordinator"
                Agent ID → ansible-review-coordinator
                Description → "Coordinates multi-perspective Ansible playbook
                reviews using judge subagents."
                Agent type → Primary agent (vibe --agent)
                Safety → neutral
(Tools)         Enabled: read_file, grep, task, ask_user_question
                Disabled: (none — an empty enabled list would mean "no
                restriction", not "no tools")
(Security)      bypass_tool_permissions → false
                bash not enabled, so no bash permission questions
(Skills)        Create a new skill → task-delegate to a skill subagent
                → enabled_skills: ["ansible-playbook-security-analyzer"]
(Subagents)     spawns_subagents → yes
                requirements-validator, playbook-validator, security-scanner
                (each gets agent_type = "subagent" and a non-empty description)

[STEP 10] Write ~/.vibe/temp/agent-creator/ansible-review-coordinator.answers.json
[STEP 10] python3 .../agent_creator_workflow.py answers.json --dry-run   → exit 0
[STEP 12] User confirms the preview
[STEP 12] python3 .../agent_creator_workflow.py answers.json            → exit 0

✅ Agent creation complete!
   Agent: ansible-review-coordinator (agent_type = "agent")
   Pattern: Multi-Agent Debate
   Skills: ansible-playbook-security-analyzer

   Files created:
   - ~/.vibe/agents/ansible-review-coordinator.toml
   - ~/.vibe/prompts/ansible-review-coordinator.md
   - ~/.vibe/agents/requirements-validator.toml   (agent_type = "subagent")
   - ~/.vibe/prompts/requirements-validator.md
   - ~/.vibe/agents/playbook-validator.toml       (agent_type = "subagent")
   - ~/.vibe/prompts/playbook-validator.md
   - ~/.vibe/agents/security-scanner.toml         (agent_type = "subagent")
   - ~/.vibe/prompts/security-scanner.md

   Test with: vibe --agent ansible-review-coordinator
```

If SFL prompt engineering was requested, the dry run instead prints an
`[AGENT_TASK_REQUEST]` block and exits with code 3 (nothing written); the
orchestrator delegates with the `task` tool, saves the subagent output, and
re-runs with `--sfl-prompt-file`.

---

## 📚 **Design Patterns Reference**

| Pattern | Use Case | Example |
|---------|----------|---------|
| **Single Agent** | Simple, self-contained tasks | `readme-generator` |
| **Multi-Agent Debate** | Complex reviews with multiple perspectives | `critique-agent` |
| **Subagent Delegation** | Parent agent with specialized subagents | `gir` |
| **Chain-of-Verification** | Structured validation with self-checking | Quality assurance agents |
| **Tool Orchestrator** | Coordinates external tools/APIs | `github-automation` |
| **Stateful Agent** | Maintains context across interactions | Chat assistants |
| **Hybrid Pipeline** | Custom combination of patterns | Complex workflows |

**Full Documentation:**
See `~/.vibe/skills/agent-creator/references/Agent Skill Design Patterns.md`

---

## 🔧 **Customization**

### **1. Adding New Patterns**
1. Create a new file in `patterns/` (e.g., `my-pattern.md`)
2. Add the pattern to `patterns/registry.yaml`:
   ```yaml
   patterns:
     my-pattern:
       name: "My Pattern"
       description: "Description of my pattern"
       file: "patterns/my-pattern.md"
       template: "templates/my-pattern.toml"
       complexity: "medium"
   ```
3. Create a template file in `templates/my-pattern.toml`
4. Create a question file in `questions/my-pattern.yaml` (optional)

### **2. Modifying Existing Patterns**
Edit the corresponding files in:
- `patterns/{pattern-id}.md` - Pattern documentation
- `templates/{pattern-id}.toml` - TOML template
- `questions/{pattern-id}.yaml` - Pattern-specific questions

### **3. Adding New Questions**
1. Create a new YAML file in `questions/` (e.g., `my-questions.yaml`)
2. Reference it in the workflow script

### **4. Modifying Templates**
Edit the template files in `templates/` to change the default agent configurations.

---

## ⚠️ **Troubleshooting**

| Issue | Solution |
|-------|----------|
| **"Agent not found"** | Ensure `agent-creator` is in `enabled_agents` in `~/.vibe/config.toml` |
| **"Skill architect not available"** | Enable `skill-architect` and `skill-researcher` in `enabled_agents` |
| **"Pattern file not found"** | Verify the pattern exists in `patterns/` directory |
| **"Template file not found"** | Verify the template exists in `templates/` directory |
| **"Invalid agent ID"** | Use only lowercase letters, numbers, hyphens, and underscores |
| **"Skill creation failed"** | Check logs in `~/.vibe/temp/agent-creator/agent-creator.log` |
| **"File permission denied"** | Ensure `~/.vibe/agents/` and `~/.vibe/prompts/` are writable |

### **Debug Mode**
Run with output capture (the script never prompts — all output is logs,
task-request blocks, and file previews):
```bash
python3 ~/.vibe/skills/agent-creator/agent_creator_workflow.py answers.json --dry-run 2>&1 | tee debug.log
```

### **Check Logs**
```bash
tail -f ~/.vibe/temp/agent-creator/agent-creator.log
```

---

## 🧪 **Testing**

### **1. Test Individual Components**
```bash
# Schema and usage
python3 ~/.vibe/skills/agent-creator/agent_creator_workflow.py --schema

# Validation errors are exit code 1, nothing is written
python3 ~/.vibe/skills/agent-creator/agent_creator_workflow.py answers.json --dry-run
```

### **2. Full Workflow Test**
```bash
# Preview without writing, then write for real
python3 agent_creator_workflow.py answers.json --dry-run
python3 agent_creator_workflow.py answers.json --agents-dir /tmp/test-agents --prompts-dir /tmp/test-prompts

# Check generated files
ls -la /tmp/test-agents/
ls -la /tmp/test-prompts/
```

### **3. Cleanup Test Files**
```bash
# Remove test files
rm -f ~/.vibe/agents/*-test.toml
rm -f ~/.vibe/prompts/*-test.md
```

---

## 📁 **File Structure Reference**

```
~/.vibe/
├── agents/
│   ├── agent-creator.toml          # Agent definition
│   ├── {agent-id}.toml                 # Generated agents
│   └── {subagent-id}.toml              # Generated subagents
│
├── prompts/
│   └── {prompt-id}.md                   # Generated prompts
│
└── skills/
    └── agent-creator/
        ├── README.md                   # This file
        ├── agent_creator_workflow.py  # Main workflow
        │
        ├── patterns/
        │   ├── registry.yaml
        │   ├── single-agent.md
        │   ├── multi-agent-debate.md
        │   ├── subagent-delegation.md
        │   ├── cove.md
        │   ├── tool-orchestrator.md
        │   ├── stateful-agent.md
        │   └── hybrid-pipeline.md
        │
        ├── questions/
        │   ├── purpose.yaml
        │   ├── metadata.yaml
        │   ├── tools.yaml
        │   ├── security.yaml
        │   ├── subagents.yaml
        │   └── skills.yaml
        │
        ├── templates/
        │   ├── agent.toml
        │   ├── subagent.toml
        │   ├── single-agent.toml
        │   ├── multi-agent-debate.toml
        │   ├── subagent-delegation.toml
        │   ├── cove.toml
        │   ├── tool-orchestrator.toml
        │   └── hybrid-pipeline.toml
        │
        └── references/
            └── Agent Skill Design Patterns.md
```

---

## 🤝 **Contributing**

1. **Fork the structure** and modify files in your own `agent-creator` directory
2. **Test changes** with the testing procedures above
3. **Submit improvements** by sharing updated files

### **Contribution Guidelines**
- Follow the existing file structure
- Use consistent naming conventions (hyphen-case for files, snake_case for variables)
- Include validation in all user inputs
- Add error handling for all file operations
- Document new patterns in `Agent Skill Design Patterns.md`

---
## 📜 **License**

This project is licensed under the **MIT License** - see the `LICENSE` file in the `agent-creator` directory for details.

---
## 🆘 **Support**

For issues or questions:
1. Check the **Troubleshooting** section above
2. Review the logs in `~/.vibe/temp/agent-creator/`
3. Ensure all dependencies are installed (`tomli`, `tomli_w`, `pyyaml`)
4. Verify your Mistral Vibe installation is up to date

---
**Maintained with ❤️ for the Mistral Vibe community**
**Co-Authored-By: Mistral Vibe <vibe@mistral.ai>**
