# Skill Development Guidelines

This document outlines the **best practices** and **requirements** for developing skills compatible with **Mistral Vibe 2.0+**. Adhering to these guidelines ensures your skills are **reliable, maintainable, and portable**.

---

## **1. General Principles**

### **Portability**
- Skills must work **regardless of the user's current working directory**.
- All file references must use **absolute paths** (e.g., `~/.vibe/skills/{skill_name}/scripts/example.py`).
- Avoid assumptions about the user's environment or directory structure.

### **Reliability**
- **No "File not found" errors**: Ensure all referenced files exist or provide fallback instructions.
- **Explicit dependencies**: List all required tools, libraries, or external services in the `SKILL.md` frontmatter or documentation.

### **User Experience**
- Skills should be **self-contained** and **self-documenting**.
- Use **imperative/infinitive form** for instructions (e.g., "Load the file" instead of "You should load the file").
- Provide **clear examples** and **use cases** in the `SKILL.md`.

### **Maintainability**
- Use **clear, explicit paths** for easier debugging.
- Include **comments** in scripts and references to explain non-obvious logic.
- Keep `SKILL.md` **concise but comprehensive**.

---

## **2. File Structure**

Every skill **must** follow this structure:
```
~/.vibe/skills/{skill_name}/
├── SKILL.md               # Required: Main skill definition
├── scripts/              # Optional: Executable code (Python, Bash, etc.)
├── references/            # Optional: Documentation or external resources
└── assets/                # Optional: Templates, icons, or other static files
```

### **SKILL.md**
- **Required**: Every skill must include a `SKILL.md` file.
- **Frontmatter**: Must include the following YAML fields:
  ```yaml
  ---
  name: {skill_name}          # Required: Unique identifier (slug format)
  description: >              # Required: Clear description of the skill
    A concise explanation of the skill's purpose and use cases.
  user-invocable: true        # Required: Whether the skill can be invoked directly
  allowed-tools:              # Required: List of permitted tools
    - read_file
    - write_file
  ---
  ```
- **Content**:
  - **Overview**: Briefly describe the skill's purpose and when to use it.
  - **Instructions**: Step-by-step guide on how to use the skill.
  - **Examples**: Practical examples of the skill in action.
  - **File References**: List of all files included in the skill, with absolute paths.

### **Scripts**
- Place executable code in the `scripts/` directory.
- Use **absolute paths** for all file references within scripts.
- Include a **README.md** in `scripts/` if additional documentation is needed.

### **References**
- Place external documentation, guidelines, or notes in the `references/` directory.
- Reference these files in `SKILL.md` using absolute paths.

### **Assets**
- Place templates, icons, or other static files in the `assets/` directory.
- Reference these files in `SKILL.md` or scripts using absolute paths.

---

## **3. Path Resolution**

### **Absolute Paths**
- **All file references** must use absolute paths starting with `~/.vibe/skills/{skill_name}/`.
- Example:
  - Correct: `~/.vibe/skills/data-cleaner/scripts/clean.py`
  - Incorrect: `scripts/clean.py` or `./scripts/clean.py`

### **Fallback Notes**
- For each file reference, include a **Path Resolution Note** in `SKILL.md`:
  ```markdown
  <!-- Path Resolution Note: Use absolute path `~/.vibe/skills/{skill_name}/scripts/example.py`. Fallback: Try relative path `scripts/example.py`. -->
  ```
- Fallback paths are **optional** but recommended for robustness.

### **Handling External Files**
- If a skill references files **outside** `~/.vibe/skills/{skill_name}/` (e.g., `/usr/local/templates/`):
  - **Copy the file** into the skill directory and update the reference.
  - **Do not** use symlinks or external paths.

---

## **4. Writing Style**

### **Imperative/Infinitive Form**
- Use **verb-first** instructions:
  - Correct: "Load the dataset from `~/.vibe/skills/data-loader/assets/data.csv`."
  - Incorrect: "You should load the dataset from `data.csv`."

### **Objective Language**
- Avoid subjective language (e.g., "this is easy").
- Focus on **facts and actions**.

### **Clarity**
- Use **short sentences** and **bullet points** for readability.
- Group related actions under clear headings (e.g., `## Setup`, `## Execution`).

---

## **5. Validation**

### **Schema Compliance**
- Validate your `SKILL.md` against the schema defined in `~/.vibe/skills/skill-manager/references/skill_schema.json`.
- Required fields: `name`, `description`, `user-invocable`, `allowed-tools`.

### **Path Validation**
- Ensure all paths in `SKILL.md`, `scripts/`, `references/`, and `assets/` are:
  - **Absolute** (start with `~/.vibe/skills/{skill_name}/`).
  - **Resolvable** (the referenced files exist).

### **Markdown Linting**
- Check for:
  - Unclosed code blocks (```).
  - Unclosed YAML frontmatter (`---`).
  - Invalid Markdown syntax.

---
## **6. Error Handling**

### **Missing Files**
- If a referenced file is missing, **fail immediately** with a clear error message:
  ```
  FATAL: File not found: ~/.vibe/skills/{skill_name}/scripts/example.py
  ```

### **Invalid Paths**
- If a path is invalid or unresolvable, **fail immediately** with:
  ```
  FATAL: Path '{path}' cannot be resolved to ~/.vibe/skills/{skill_name}/.
  ```

### **Name Collisions**
- If a skill with the same name already exists in `~/.vibe/skills/`, **fail immediately** with:
  ```
  FATAL: Skill '{skill_name}' already exists.
  ```

---
## **7. Examples**

### **Example 1: Valid Skill Structure**
```
~/.vibe/skills/data-cleaner/
├── SKILL.md
│   ├── YAML frontmatter: name, description, user-invocable, allowed-tools
│   └── Instructions: "Load data from `~/.vibe/skills/data-cleaner/assets/data.csv`..."
├── scripts/
│   └── clean.py          # Uses absolute paths for file I/O
└── assets/
    └── data.csv          # Referenced in SKILL.md
```

### **Example 2: Path Resolution Note**
```markdown
To clean the data, run the script:
```bash
python ~/.vibe/skills/data-cleaner/scripts/clean.py
```
<!-- Path Resolution Note: Use absolute path `~/.vibe/skills/data-cleaner/scripts/clean.py`. Fallback: Try relative path `scripts/clean.py`. -->
```

---
## **8. Testing**

### **Manual Testing**
1. Invoke the skill from **different directories** to ensure portability.
2. Verify all file references **resolve correctly**.
3. Check that the skill **fails gracefully** on errors (e.g., missing files).

### **Automated Validation**
- Use the `validate_skill.py` script to run **Chain of Verification** checks:
  ```bash
  python ~/.vibe/skills/skill-manager/scripts/validate_skill.py ~/.vibe/skills/{skill_name}
  ```

---
## **9. Best Practices**

### **Do:**
- Use **absolute paths** for all file references.
- Include **Path Resolution Notes** for critical files.
- Keep `SKILL.md` **up-to-date** with the latest file references.
- Test your skill in a **clean environment** (e.g., a fresh Mistral Vibe installation).

### **Don't:**
- Use **relative paths** (e.g., `./scripts/example.py`).
- Assume the user's **working directory**.
- Reference files **outside** `~/.vibe/skills/{skill_name}/` without copying them into the skill.
- Omit **required frontmatter fields** (`name`, `description`, `user-invocable`, `allowed-tools`).
