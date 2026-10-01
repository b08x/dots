---
name: skill-manager  
description: >  
  Unified tool for creating and importing Mistral Vibe skills.  
  For creation: Generates a scaffold (SKILL.md, scripts/, references/, assets/) from a project description and tasks.  
  For import: Converts existing skill folders into Mistral Vibe-compatible format with absolute paths and schema validation.  
user-invocable: true  
allowed-tools:
- read_file
- write_file
- bash
- grep
- ask_user_question
- todo
- task
- open_url
- web_search

---

# Skill Manager

## Overview

This skill provides a unified workflow for:

1. **Creating** new skills with a guided workflow.
2. **Importing** existing skill folders with automatic path resolution and schema validation.

**Key Features**:

- **Chain of Verification**: Every step is validated before proceeding.
- **Absolute Path Enforcement**: All file references use `~/.vibe/skills/{skill_name}/...`.
- **Schema Compliance**: Input and output are validated against `~/.vibe/skills/skill-manager/references/skill_schema.json`.
- **Multi-File Support**: Handles `SKILL.md`, `assets/`, `references/`, and `scripts/` with preserved directory structure.

## Dependencies

- **Mistral Vibe 2.0+**: For skill discovery, invocation, and tool access.
- **Bash/Grep/Sed**: For file manipulation and path resolution.

---

## Instructions

### Create a New Skill

**Command**:

```bash
/skill-manager create --description "<project_description>" --tasks "<desired_tasks>"
```

**Steps**:

1. **Guided Workflow**:
  - Prompt for project description and desired tasks.
  - Use `ask_user_question` to refine inputs.
2. **Generate Scaffold**:
  - Draft `SKILL.md` with YAML frontmatter (`name`, `description`, `user-invocable`, `allowed-tools`).
  - Create directory structure (`scripts/`, `references/`, `assets/`).
3. **Validate**: Run Chain of Verification checks (schema, paths, linting).

**Note**: All paths must resolve to `~/.vibe/skills/{skill_name}/`.

---

### Import an Existing Skill

**Command**:

```bash
/skill-manager import /path/to/skill/folder
```

**Steps**:

1. **Read Input Folder**: Extract `SKILL.md` and bundled resources.
2. **Validate Compatibility**:
  - Compare `SKILL.md` against `~/.vibe/skills/skill-manager/references/skill_schema.json`.
  - Fail immediately if required fields (`name`, `description`, `user-invocable`) are missing.
3. **Resolve Paths**:
  - Recursively replace relative paths in `SKILL.md`, `assets/`, `references/`, and `scripts/` with absolute paths.
  - Preserve directory structure.
4. **Add Notes**: Insert path resolution notes for every referenced file.
5. **Handle Collisions**: Fail if `~/.vibe/skills/{skill_name}` exists.

---

## Directory Structure

```
~/.vibe/skills/skill-manager/
├── SKILL.md
└── scripts/
    ├── init_skill.py       # Entry point for create/import
    ├── validate_skill.py   # Chain of Verification checks
    └── path_resolver.py    # Enforces absolute paths
```

---

## Error Handling


| Error Type             | Action                                                              |
| ---------------------- | ------------------------------------------------------------------- |
| Missing frontmatter    | Fail: `FATAL: Missing required field: {field}`.                     |
| Relative path detected | Auto-replace with absolute path and add resolution note.            |
| Name collision         | Fail: `FATAL: Skill '{skill_name}' already exists.`.                |
| Invalid input          | Fail: `FATAL: Unsupported format or missing SKILL.md`.              |
| Unresolved path        | Fail: `FATAL: Path '{path}' cannot be resolved to ~/.vibe/skills/`. |


---

## Usage Examples

### Example 1: Create a New Skill

```bash
/skill-manager create --description "A skill for managing project documentation" --tasks "generate markdown templates, validate file structures"
```

**Output**:

```
~/.vibe/skills/doc-manager/
├── SKILL.md
├── scripts/
│   └── validate_structure.py
└── references/
    └── template_guidelines.md
```

### Example 2: Import a Legacy Skill

```bash
/skill-manager import /path/to/legacy-skill
```

**Output**:

```
~/.vibe/skills/legacy-skill/
├── SKILL.md               # Updated with absolute paths
├── scripts/
│   └── legacy_script.py   # Paths updated
└── references/
    └── legacy_docs.md     # Paths updated
```
