#!/usr/bin/env python3
"""
init_skill.py
Entry point for skill-manager. Handles both 'create' and 'import' commands.
"""

import os
import sys
import argparse
import shutil
from pathlib import Path
from typing import Optional, Dict, List

# Constants
SKILLS_DIR = Path("~/.vibe/skills").expanduser()
SCHEMA_PATH = SKILLS_DIR / "schemas" / "skill_schema.json"

def ask_user_question(prompt: str, question_type: str = "input", options: Optional[List[str]] = None) -> str:
    """
    Wrapper for Mistral Vibe's ask_user_question tool.
    Simulates the tool call for local testing.
    """
    if options:
        print(f"\n{prompt}\nOptions: {', '.join(options)}")
        choice = input("Your choice: ").strip()
        if choice not in options:
            raise ValueError(f"Invalid option. Choose from: {', '.join(options)}")
        return choice
    else:
        return input(f"\n{prompt}\nYour input: ").strip()

def delegate_to_architect(context: Dict[str, str]) -> Dict[str, str]:
    """
    Delegate guided workflow steps to skill-architect.
    Returns refined context (e.g., project description, tasks).
    """
    print("\n[Delegating to skill-architect for guided workflow...]")
    # Simulate subagent call
    refined_description = ask_user_question(
        "Refine your project description (or press Enter to keep current):",
        question_type="input",
        options=None
    ) or context.get("description", "")
    refined_tasks = ask_user_question(
        "Refine your desired tasks (or press Enter to keep current):",
        question_type="input",
        options=None
    ) or context.get("tasks", "")
    return {
        "description": refined_description,
        "tasks": refined_tasks
    }

def generate_skill_name(description: str) -> str:
    """Generate a slug from the description."""
    name = description.lower().replace(" ", "-")
    # Remove special characters
    import re
    name = re.sub(r'[^a-z0-9-]', '', name)
    return name

def create_scaffold(skill_name: str, description: str, tasks: str, output_dir: Path) -> None:
    """Create a new skill scaffold."""
    skill_dir = output_dir / skill_name
    if skill_dir.exists():
        raise FileExistsError(f"FATAL: Skill '{skill_name}' already exists at {skill_dir}")

    # Create directories
    (skill_dir / "scripts").mkdir(parents=True, exist_ok=True)
    (skill_dir / "references").mkdir(parents=True, exist_ok=True)
    (skill_dir / "assets").mkdir(parents=True, exist_ok=True)

    # Draft SKILL.md
    skill_md = f"""---
name: {skill_name}
description: >
  {description}
user-invocable: true
allowed-tools:
  - read_file
  - write_file
---

# {skill_name.replace('-', ' ').title()}

## Overview
{description}

## Instructions
{tasks}

---
## File References
All file paths in this skill must use absolute paths starting with `~/.vibe/skills/{skill_name}/`.
Example: `~/.vibe/skills/{skill_name}/scripts/example.py`
"""
    (skill_dir / "SKILL.md").write_text(skill_md)
    print(f"\nScaffold created at: {skill_dir}")

def import_skill(input_path: Path, output_dir: Path) -> None:
    """Import and validate an existing skill folder."""
    from validate_skill import validate_skill_folder
    from path_resolver import resolve_paths

    input_path = input_path.expanduser().resolve()
    if not input_path.exists():
        raise FileNotFoundError(f"FATAL: Input path does not exist: {input_path}")

    skill_md_path = input_path / "SKILL.md"
    if not skill_md_path.exists():
        raise FileNotFoundError(f"FATAL: Missing SKILL.md in: {input_path}")

    # Extract skill name from SKILL.md
    import yaml
    with open(skill_md_path, 'r') as f:
        content = f.read()
        # Find first and second --- delimiters
        first_delim = content.find("---")
        second_delim = content.find("---", first_delim + 3)
        if first_delim == -1 or second_delim == -1:
            raise ValueError("FATAL: Missing YAML frontmatter delimiters '---' in SKILL.md")
        frontmatter = yaml.safe_load(content[first_delim+3:second_delim])
    skill_name = frontmatter.get("name")
    if not skill_name:
        skill_name = input_path.name
    skill_dir = output_dir / skill_name

    if skill_dir.exists():
        raise FileExistsError(f"FATAL: Skill '{skill_name}' already exists at {skill_dir}")

    # Copy the entire folder to the output directory
    shutil.copytree(input_path, skill_dir)

    # Resolve paths in the copied skill
    resolve_paths(skill_dir)

    # Validate the imported skill
    validate_skill_folder(skill_dir)

    print(f"\nSkill imported to: {skill_dir}")

def main():
    parser = argparse.ArgumentParser(description="Skill Manager: Create or import Mistral Vibe skills.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Create command
    create_parser = subparsers.add_parser("create", help="Create a new skill.")
    create_parser.add_argument("--description", required=True, help="Project description.")
    create_parser.add_argument("--tasks", required=True, help="Desired tasks for the skill.")

    # Import command
    import_parser = subparsers.add_parser("import", help="Import an existing skill folder.")
    import_parser.add_argument("input_path", type=Path, help="Path to the skill folder to import.")

    args = parser.parse_args()

    try:
        if args.command == "create":
            # Guided workflow
            context = {"description": args.description, "tasks": args.tasks}
            refined_context = delegate_to_architect(context)

            skill_name = generate_skill_name(refined_context["description"])
            # Confirm skill name
            confirmed_name = ask_user_question(
                f"Proposed skill name: {skill_name}. Press Enter to confirm or provide a new name:",
                question_type="input"
            ) or skill_name

            create_scaffold(
                skill_name=confirmed_name,
                description=refined_context["description"],
                tasks=refined_context["tasks"],
                output_dir=SKILLS_DIR
            )
        elif args.command == "import":
            import_skill(args.input_path, SKILLS_DIR)

    except Exception as e:
        print(f"FATAL: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()