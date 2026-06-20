# Ansible Automation Subagents

Specialized subagents for use with the ansible-automation skill. These subagents work together to provide comprehensive Ansible automation support through context gathering, intent clarification, and documentation research.

## Available Subagents

### 1. ansible-context-gatherer

**Purpose**: Collects and analyzes existing Ansible context including playbooks, roles, inventory files, variables, and environment state. Uses `ansible-playbook-grapher` to visualize playbook structure when needed.

**Responsibilities**:
- Scan directory structure for Ansible files (.yml, .yaml)
- Identify existing playbooks, roles, group_vars, host_vars
- Extract current variable definitions and defaults
- Identify installed Ansible version and collections
- Detect existing inventory structure
- Map dependencies between playbooks and roles
- Generate visual graphs of playbook structure using `ansible-playbook-grapher` for complex automation analysis

**Tools Used**:
- `bash` - For file system exploration and Ansible version checks
- `grep` - For pattern matching in Ansible files
- `read_file` - For reading and analyzing file contents
- `ansible-playbook-grapher` - For visualizing playbook structure (see `references/ansible-playbook-grapher.md`)

**When to Use**:
- Before creating new Ansible automation
- When modifying existing automation
- To understand current state before making changes
- When debugging complex playbook flows (use `--renderer mermaid-flowchart --include-role-tasks --view`)

**Output**: Structured context summary including:
- File inventory with paths and types
- Variable mapping and precedence
- Role structure analysis
- Existing patterns and conventions
- Optional: Playbook visualization graphs (SVG, Mermaid, or JSON format)

---

### 2. ansible-intent-clarifier

**Purpose**: Asks highly detailed, targeted questions to precisely understand user requirements and constraints for Ansible automation tasks.

**Responsibilities**:
- Probe for specific technical requirements
- Clarify scope and boundaries
- Identify constraints (OS versions, environments, security)
- Determine success criteria
- Uncover implicit assumptions
- Validate understanding before execution

**Question Categories**:

**Target Environment**:
- "What operating system(s) and versions are you targeting?"
- "Is this for local development, production, or both?"
- "What is the current Ansible version in use?"

**Scope Definition**:
- "Which specific systems or services need to be configured?"
- "Should this be a playbook, role, or collection?"
- "What existing automation should this integrate with?"

**Requirements Gathering**:
- "What packages need to be installed?"
- "What configuration files need to be managed?"
- "What services need to be running/stopped?"
- "What users or groups need to be created?"

**Constraints & Security**:
- "Are there any security policies to follow?"
- "What privilege escalation requirements exist?"
- "Are there network restrictions or proxy settings?"
- "What secrets management approach should be used?"

**Style & Standards**:
- "Should this follow the RHEL Workstation Builder style guide?"
- "Are there existing naming conventions to match?"
- "What tagging strategy should be used?"

**Tools Used**:
- `ask_user_question` - Primary tool for structured questioning

**When to Use**:
- At the start of any non-trivial Ansible task
- When requirements are ambiguous
- Before creating new automation
- When user intent is unclear

**Output**: Comprehensive requirements document with validated understanding

---

### 3. ansible-docs-researcher

**Purpose**: Uses Context7 MCP tool to query official Ansible and Mistral Vibe documentation for syntax verification, best practices, and module information.

**Responsibilities**:
- Query Ansible documentation for module syntax and parameters
- Look up best practices and patterns
- Verify correct usage of Ansible features
- Research external topics using web_search (e.g., Podman quadlets Fedora 42)
- Cross-reference with style guide requirements

**Tools Used**:
- `context7_query-docs` - Primary tool with library_id `/ansible/ansible-documentation` for Ansible documentation
- `web_search` - For external topics outside Ansible docs scope (e.g., Podman quadlets, Fedora-specific configurations)

**Library IDs**:
- `/ansible/ansible-documentation` - Official Ansible docs

**Query Patterns**:

**Module Research**:
- `"ansible.builtin.{module_name} module parameters and examples"`
- `"{module_name} module return values and examples"`
- `"best practices for using {module_name} module"`

**Syntax Verification**:
- `"correct YAML syntax for {feature} in Ansible"`
- `"Jinja2 templating syntax for {use_case}"`
- `"conditional syntax with when statement examples"`

**Pattern Research**:
- `"Ansible role directory structure best practices"`
- `"variable precedence and inheritance in Ansible roles"`
- `"tagging strategy for Ansible playbooks"`

**Style Guide**:
- `"RHEL Workstation Builder Ansible style guide conventions"`
- `"ansible.builtin module naming conventions"`
- `"YAML formatting standards for Ansible files"`

**External Topics (web_search)**:
- `"Podman quadlets configuration Fedora 42"`
- `"systemd quadlet syntax and examples"`
- `"Fedora 42 package names for container runtime"`
- `"Ansible community.general.podman modules usage"`

**When to Use**:
- When unsure about module parameters or syntax
- Before implementing complex Ansible features
- To verify style guide compliance
- When researching best practices

**Output**: Documentation excerpts with relevant examples and recommendations

---

## Subagent Workflow

### Standard Operation Flow

```
User Query → ansible-intent-clarifier → ansible-context-gatherer → ansible-docs-researcher → Execution
                    ↓                    ↓                    ↓
               (Clarify)          (Analyze)            (Research)
                    ↓                    ↓                    ↓
               Requirements ←---- Context -----→ Documentation
```

### Step-by-Step Process

1. **Intent Clarification Phase**
   - `ansible-intent-clarifier` engages first
   - Asks targeted questions to understand requirements
   - Validates understanding with user
   - Produces: Requirements specification

2. **Context Gathering Phase**
   - `ansible-context-gatherer` scans existing environment
   - Identifies relevant files and current state
   - Maps dependencies and existing patterns
   - Produces: Context summary

3. **Documentation Research Phase**
   - `ansible-docs-researcher` queries Context7 for:
     - Module syntax and parameters
     - Best practices for identified use cases
     - Style guide compliance requirements
     - Mistral Vibe integration patterns
   - Produces: Documentation summary with recommendations

4. **Synthesis & Execution**
   - Main agent combines all outputs
   - Creates or modifies Ansible automation
   - Validates against all gathered information

---

## Agent Collaboration Patterns

### Pattern 1: New Playbook Creation

```
ansible-intent-clarifier:
  - What systems should this playbook target?
  - What is the primary purpose?
  - What modules will be needed?
  
ansible-context-gatherer:
  - Scan for existing playbooks with similar purpose
  - Identify existing role dependencies
  - Check current inventory structure
  
ansible-docs-researcher:
  - Query module documentation for required modules
  - Research playbook structure best practices
  - Verify style guide requirements
```

### Pattern 2: Debugging Existing Automation

```
ansible-intent-clarifier:
  - What error or unexpected behavior are you seeing?
  - What is the expected vs actual behavior?
  - What has changed recently?
  
ansible-context-gatherer:
  - Read the failing playbook/role
  - Check related variable files
  - Examine inventory for target systems
  
ansible-docs-researcher:
  - Query syntax for suspected problematic modules
  - Research common pitfalls for the use case
  - Look up error messages in documentation
```

### Pattern 3: Role Refactoring

```
ansible-intent-clarifier:
  - What functionality should be extracted to a role?
  - What variables should be configurable?
  - What are the integration points?
  
ansible-context-gatherer:
  - Analyze existing playbook structure
  - Identify reusable task patterns
  - Map current variable usage
  
ansible-docs-researcher:
  - Query role structure best practices
  - Research variable design patterns
  - Look up role dependency management
```

---

## Usage Examples

### Example 1: Creating a New Role

```bash
# Spawn intent clarifier to understand requirements
agent: ansible-intent-clarifier
task: "User wants to create a role for Docker container management"

# Spawn context gatherer to analyze existing setup
agent: ansible-context-gatherer
task: "Gather existing Docker-related automation and infrastructure"

# Spawn docs researcher to verify syntax and patterns
agent: ansible-docs-researcher
task: "Research community.docker modules and role patterns"
```

### Example 2: Verifying Syntax Before Execution

```bash
# Use docs researcher to verify module syntax
agent: ansible-docs-researcher
query: "ansible.builtin.template module syntax for Jinja2 files"
library_id: '/ansible/ansible-documentation'
```

### Example 3: Researching External Topics with Web Search

```bash
# Search web for external topics not in Ansible docs
agent: ansible-docs-researcher
query: "Podman quadlets Fedora 42 systemd configuration"
tool: web_search
```

---

## Subagent Configuration Reference

### Common Parameters

All subagents accept:
- `task`: The specific task or question for the subagent
- `context`: Optional pre-collected context to use
- `timeout`: Optional timeout override

### Subagent-Specific Parameters

**ansible-context-gatherer**:
- `path`: Specific directory path to scan (default: current directory)
- `patterns`: File patterns to look for (default: *.yml, *.yaml)
- `depth`: Maximum directory depth to scan (default: 5)

**ansible-intent-clarifier**:
- `category`: Question category to focus on (environment, scope, requirements, constraints, style)
- `requirements`: Pre-collected requirements to validate

**ansible-docs-researcher**:
- `query`: The documentation query
- `library_id`: Context7 library ID (default: /ansible/ansible-documentation)
- `max_results`: Maximum number of results to return (default: 5)
