# Schema Validation Guide

This document explains how **schema validation** works for Mistral Vibe skills and how to ensure your skills comply with the required schema.

---

## **1. Overview**

The **Mistral Vibe Skill Schema** (`~/.vibe/skills/skill-manager/references/skill_schema.json`) defines the **structure and requirements** for all `SKILL.md` files. Validating your skill against this schema ensures it is **compatible** with Mistral Vibe and can be **discovered, invoked, and executed** correctly.

---

## **2. Schema Location**

The schema file is located at:

```
~/.vibe/skills/skill-manager/references/skill_schema.json
```

If this file does not exist, you can create it using the template provided in the **Skill Manager** skill or copy it from the [Mistral Vibe repository](https://github.com/mistralai/mistral-vibe).

---

## **3. Required Fields**

Every `SKILL.md` **must** include the following fields in its YAML frontmatter:


| Field            | Type    | Description                                                                                    | Example                           |
| ---------------- | ------- | ---------------------------------------------------------------------------------------------- | --------------------------------- |
| `name`           | string  | Unique identifier for the skill (slug format: lowercase, hyphens, no spaces or special chars). | `data-cleaner`                    |
| `description`    | string  | Clear and concise description of the skill's purpose and use cases.                            | `A skill for cleaning CSV files.` |
| `user-invocable` | boolean | Whether the skill can be invoked directly by the user.                                         | `true`                            |
| `allowed-tools`  | array   | List of tools the skill is permitted to use.                                                   | `["read_file", "write_file"]`     |


---

## **4. Optional Fields**


| Field           | Type   | Description                                    | Default Value       |
| --------------- | ------ | ---------------------------------------------- | ------------------- |
| `license`       | string | License for the skill (e.g., MIT, Apache 2.0). | `MIT`               |
| `compatibility` | string | Mistral Vibe version compatibility.            | `Mistral Vibe 2.0+` |


---

## **5. Schema Structure**

Here is the **JSON Schema** for `SKILL.md` frontmatter:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://mistral.ai/schemas/skill_schema.json",
  "title": "Mistral Vibe Skill Schema",
  "description": "Schema for validating Mistral Vibe SKILL.md files",
  "type": "object",
  "required": [
    "name",
    "description",
    "user-invocable"
  ],
  "additionalProperties": false,
  "properties": {
    "name": {
      "type": "string",
      "description": "Unique identifier for the skill (slug format, e.g., 'data-cleaner').",
      "pattern": "^[a-z0-9-]+$",
      "minLength": 1,
      "maxLength": 64
    },
    "description": {
      "type": "string",
      "description": "Clear and concise description of the skill's purpose and use cases.",
      "minLength": 10,
      "maxLength": 500
    },
    "user-invocable": {
      "type": "boolean",
      "description": "Whether the skill can be invoked directly by the user.",
      "default": true
    },
    "allowed-tools": {
      "type": "array",
      "description": "List of tools the skill is permitted to use.",
      "items": {
        "type": "string",
        "enum": [
          "read_file",
          "write_file",
          "bash",
          "grep",
          "ask_user_question",
          "todo",
          "task",
          "open_url",
          "web_search",
          "search_replace",
          "code_interpreter"
        ]
      },
      "uniqueItems": true
    },
    "license": {
      "type": "string",
      "description": "License for the skill (optional).",
      "default": "MIT"
    },
    "compatibility": {
      "type": "string",
      "description": "Mistral Vibe version compatibility (optional).",
      "default": "Mistral Vibe 2.0+"
    }
  }
}
```

---

## **6. Validation Process**

The **Skill Manager** uses the `validate_skill.py` script to validate skills against the schema. Here’s how it works:

### **Step 1: Load the Schema**

- The script loads the schema from `~/.vibe/skills/skill-manager/references/skill_schema.json`.
- If the schema file is missing, the validation **fails immediately**.

### **Step 2: Validate Frontmatter**

- The script checks that the `SKILL.md` file contains **valid YAML frontmatter**.
- It verifies that all **required fields** (`name`, `description`, `user-invocable`) are present.
- It ensures the `name` field matches the **slug pattern** (`^[a-z0-9-]+$`).

### **Step 3: Validate Allowed Tools**

- The script checks that all tools listed in `allowed-tools` are **valid** (i.e., included in the schema’s `enum` list).
- It ensures there are **no duplicate tools** in the list.

### **Step 4: Validate Optional Fields**

- If optional fields (`license`, `compatibility`) are present, the script checks that their values are **valid strings**.

---

## **7. Common Validation Errors**


| Error                                    | Cause                                                                            | Fix                                                                   |
| ---------------------------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| `FATAL: Missing SKILL.md`                | The `SKILL.md` file is missing in the skill directory.                           | Ensure `SKILL.md` exists in the skill directory.                      |
| `FATAL: Missing YAML frontmatter`        | The `SKILL.md` file does not start with `---`.                                   | Add YAML frontmatter to the beginning of `SKILL.md`.                  |
| `FATAL: Invalid YAML frontmatter`        | The YAML frontmatter is malformed (e.g., missing colons, incorrect indentation). | Fix the YAML syntax in the frontmatter.                               |
| `FATAL: Missing required field: {field}` | A required field (`name`, `description`, or `user-invocable`) is missing.        | Add the missing field to the YAML frontmatter.                        |
| `FATAL: Invalid skill name`              | The `name` field does not match the slug pattern (`^[a-z0-9-]+$`).               | Use only lowercase letters, numbers, and hyphens in the `name` field. |
| `FATAL: Invalid tool in allowed-tools`   | A tool in `allowed-tools` is not in the schema’s `enum` list.                    | Use only valid tools (see the schema for the full list).              |
| `FATAL: Duplicate tools`                 | The `allowed-tools` list contains duplicate entries.                             | Remove duplicate tools from the list.                                 |


---

## **8. How to Validate Your Skill**

### **Manual Validation**

1. Open your `SKILL.md` file.
2. Check that it includes **all required fields** in the YAML frontmatter.
3. Ensure the `name` field matches the **slug pattern**.
4. Verify that all tools in `allowed-tools` are **valid**.

### **Automated Validation**

Use the `validate_skill.py` script to automatically validate your skill:

```bash
python ~/.vibe/skills/skill-manager/scripts/validate_skill.py ~/.vibe/skills/{skill_name}
```

#### **Example Output (Success)**

```
✅ Skill at ~/.vibe/skills/data-cleaner passed all Chain of Verification checks.
```

#### **Example Output (Failure)**

```
Validation Errors:
FATAL: Missing required frontmatter field: description
FATAL: Invalid skill name: Data Cleaner
```

---

## **9. Fixing Validation Errors**

### **Missing Required Fields**

If you see:

```
FATAL: Missing required field: description
```

**Fix**: Add the missing field to your `SKILL.md` frontmatter:

```yaml
---
name: data-cleaner
description: A skill for cleaning CSV files.
user-invocable: true
allowed-tools:
  - read_file
  - write_file
---
```

### **Invalid Skill Name**

If you see:

```
FATAL: Invalid skill name: Data Cleaner
```

**Fix**: Use a slug format for the `name` field:

```yaml
name: data-cleaner  # Correct
# name: Data Cleaner  # Incorrect
```

### **Invalid Tool**

If you see:

```
FATAL: Invalid tool in allowed-tools: invalid_tool
```

**Fix**: Use only tools from the **allowed list** (see the schema for valid tools):

```yaml
allowed-tools:
  - read_file       # Correct
  - write_file      # Correct
  # - invalid_tool  # Incorrect
```

---

## **10. Best Practices**

1. **Always Validate**:
  - Run `validate_skill.py` **before** finalizing your skill.
  - Fix all errors **before** testing the skill.
2. **Use Defaults for Optional Fields**:
  - If you don’t specify `license` or `compatibility`, the schema’s default values will be used.
3. **Keep Frontmatter Clean**:
  - Avoid adding **custom fields** not defined in the schema.
  - Use **clear, concise** descriptions for the `description` field.
4. **Test in a Clean Environment**:
  - Validate your skill in a **fresh Mistral Vibe installation** to ensure compatibility.

---

## **11. Schema Updates**

The schema may be updated in future versions of Mistral Vibe. To stay up-to-date:

1. **Check for updates** in the [Mistral Vibe repository](https://github.com/mistralai/mistral-vibe).
2. **Update your local schema** file (`~/.vibe/skills/skill-manager/references/skill_schema.json`) if changes are released.
3. **Revalidate your skills** after updating the schema.
