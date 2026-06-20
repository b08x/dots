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
# - Copy vibe_agent_creator_workflow.py to ~/.vibe/skills/agent-creator/
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

### **Method 3: Standalone Script**
```bash
cd ~/.vibe/skills/agent-creator
python3 agent_creator_workflow.py
```

---

## 🎭 **Example Session**

```
user@host:~$ vibe
> /create-agent

🚀 Agent Creator with Skill Branching
============================================================

📝 Purpose Classification
   What is your agent's PRIMARY purpose?
   1. Analyze/Review - Evaluate existing work (e.g., code review)
   2. Generate/Create - Produce new artifacts (e.g., docs, configs)
   3. Orchestrate/Coordinate - Manage workflows, agents, or multi-step processes
   4. Interact/Respond - Chat or conversational
   5. Transform/Process - Modify or process data
   6. Custom/Other - Doesn't fit the above categories
   [1-6, default: 1]: 1

💡 Based on your purpose, I recommend the **Multi-Agent Debate** pattern.
   Complex reviews with multiple judges

📝 Pattern Selection
   Use the Multi-Agent Debate pattern?
   1. Yes
   2. No, show other patterns
   3. No, specify manually
   [1-3, default: 1]: 1

📝 Multi-Agent Debate Configuration
   How many judge subagents should this agent spawn?
   1. 3 (Recommended: Requirements + Solution + Code Quality)
   2. 4 (Add a Security Judge)
   3. Custom number
   [1-3, default: 1]: 1

   What should the judge subagents be named? (comma-separated)
   [critique__requirements-validator,critique__solution-architect,critique__code-quality-reviewer]:
   > ansible__requirements-validator,ansible__playbook-validator,ansible__security-scanner

   Should judges run in parallel?
   1. Yes, parallel (faster)
   2. No, sequential (controlled)
   [1-2, default: 1]: 1

📝 Skill Assignment
   How should this agent handle skills?
   1. Use existing skills only
   2. Create new skill(s) for this agent
   3. Both existing and new skills
   [1-3]: 2

   What is the PRIMARY purpose of the new skill this agent needs?
   > Ansible playbook security analysis and compliance checking

🔄 Invoking skill-architect to create skill for: 'Ansible playbook security analysis and compliance checking'
   ✅ Created skill: ansible-playbook-security-analyzer

✅ Created and assigned new skill: ansible-playbook-security-analyzer

📝 Tool Configuration
   Which tools does this agent need? (Select all that apply)
   1. read_file - Read file contents
   2. write_file - Create/modify files
   3. grep - Search files with regex
   4. bash - Execute shell commands
   5. ask_user_question - Interactive user prompts
   6. todo - Task management
   7. task - Delegate to subagents
   8. search_replace - Modify file contents
   > 1,3,5,7

📝 Security
   What safety level should this agent have?
   1. safe - Read-only, no side effects
   2. neutral - Mostly safe, minimal side effects
   3. destructive - Can modify files or system state
   4. yolo - No restrictions - use with extreme caution
   [1-4, default: 2]: 2

   Should this agent auto-approve tool calls?
   [y/N]: n

📝 Subagent Delegation
   Should this agent spawn subagents?
   [y/N]: y

   Which subagents should this agent spawn? (Comma-separated)
   [file-reader-subagent, graphify-subagent]:
   > ansible__requirements-validator,ansible__playbook-validator,ansible__security-scanner

   What is the maximum recursion depth for subagents?
   1. 1 (No sub-subagents)
   2. 2 (One level of sub-subagents - RECOMMENDED)
   3. 3 (Two levels of sub-subagents)
   4. 4 (Deep nesting - use with caution)
   5. 5 (Maximum depth)
   [1-5, default: 2]: 2

============================================================
✅ Agent creation complete!
   Agent: ansible-review-coordinator
   Pattern: Multi-Agent Debate
   Skills: ansible-playbook-security-analyzer

   Files created:
   - /home/user/.vibe/agents/ansible-review-coordinator.toml
   - /home/user/.vibe/prompts/ansible-review-coordinator.md
   - /home/user/.vibe/agents/ansible__requirements-validator.toml
   - /home/user/.vibe/agents/ansible__playbook-validator.toml
   - /home/user/.vibe/agents/ansible__security-scanner.toml
```

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
Run with verbose logging:
```bash
cd ~/.vibe/skills/agent-creator
python3 vibe_agent_creator_workflow.py 2>&1 | tee debug.log
```

### **Check Logs**
```bash
tail -f ~/.vibe/temp/agent-creator/agent-creator.log
```

---

## 🧪 **Testing**

### **1. Test Individual Components**
```bash
# Test pattern loading
python3 -c "from vibe_agent_creator_workflow import load_pattern; print(load_pattern('multi-agent-debate'))"

# Test question loading
python3 -c "from vibe_agent_creator_workflow import load_questions; print(load_questions('purpose.yaml'))"

# Test template loading
python3 -c "from vibe_agent_creator_workflow import load_template; print(load_template('agent'))"
```

### **2. Full Workflow Test**
```bash
# Run in dry-run mode first
python3 vibe_agent_creator_workflow.py

# Check generated files
ls -la ~/.vibe/agents/*-test.toml
ls -la ~/.vibe/prompts/*-test.md
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
        ├── vibe_agent_creator_workflow.py  # Main workflow
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
