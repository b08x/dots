#!/usr/bin/env python3
"""
validate_skill.py
Runs Chain of Verification checks on a skill folder.
"""

import os
import re
import yaml
import json
from pathlib import Path
from typing import List

# Constants
SKILLS_DIR = Path("~/.vibe/skills").expanduser()
SCHEMA_PATH = SKILLS_DIR / "schemas" / "skill_schema.json"

def load_schema() -> dict:
    """Load Mistral Vibe skill schema."""
    if not SCHEMA_PATH.exists():
        raise FileNotFoundError(f"FATAL: Schema file not found: {SCHEMA_PATH}")
    with open(SCHEMA_PATH, 'r') as f:
        return json.load(f)

def validate_frontmatter(skill_md_path: Path) -> List[str]:
    """Validate YAML frontmatter in SKILL.md."""
    errors = []
    required_fields = ["name", "description", "user-invocable"]

    with open(skill_md_path, 'r') as f:
        content = f.read()
        # Extract frontmatter
        if not content.startswith("---"):
            errors.append("FATAL: Missing YAML frontmatter delimiter '---'.")
            return errors
        try:
            # Find first and second --- delimiters
            first_delim = content.find("---")
            second_delim = content.find("---", first_delim + 3)
            if first_delim == -1 or second_delim == -1:
                errors.append("FATAL: Missing YAML frontmatter delimiters '---'.")
                return errors
            frontmatter = yaml.safe_load(content[first_delim+3:second_delim])
        except yaml.YAMLError as e:
            errors.append(f"FATAL: Invalid YAML frontmatter: {e}")
            return errors

        if frontmatter is None:
            errors.append("FATAL: Empty YAML frontmatter.")
            return errors

        for field in required_fields:
            if field not in frontmatter:
                errors.append(f"FATAL: Missing required frontmatter field: {field}")

    return errors

def validate_paths(skill_dir: Path) -> List[str]:
    """Recursively validate all file references in the skill folder."""
    errors = []
    skill_name = skill_dir.name
    base_path = f"~/.vibe/skills/{skill_name}"

    # Patterns to match file references in Markdown and scripts
    patterns = [
        r'(\[.*?\]\((.*?)\))',  # Markdown links: [text](path)
        r'(```[^\n]*\n(.*?)\n```)',  # Code blocks
        r'(include\s+[\'\"](.*?)[\'\"])',  # Include statements
        r'(require\s+[\'\"](.*?)[\'\"])',  # Require statements (Ruby/Python)
        r'(read_file\s*\(\s*[\'\"](.*?)[\'\"]\s*\))',  # read_file tool calls
        r'(\.\/|\.\.\/|/)([a-zA-Z0-9_\-\./]+)',  # Relative paths
    ]

    def check_file(file_path: Path) -> None:
        try:
            content = file_path.read_text()
            for line_num, line in enumerate(content.splitlines(), 1):
                for pattern in patterns:
                    for match in re.finditer(pattern, line):
                        path_ref = None
                        # Extract the path from the match
                        if pattern.startswith(r'(\[.*?\]\((.*?)\))'):
                            path_ref = match.group(2)
                        elif pattern.startswith(r'(\.\/|\.\.\/|/)([a-zA-Z0-9_\-\./]+)'):
                            path_ref = match.group(0)
                        else:
                            for group in match.groups():
                                if group and not group.startswith(('http://', 'https://')):
                                    path_ref = group
                                    break

                        if path_ref and not path_ref.startswith(('~', '/', 'http://', 'https://')):
                            # Check if the path is relative
                            if not os.path.isabs(path_ref) and not path_ref.startswith('~'):
                                absolute_path = f"{base_path}/{path_ref}"
                                errors.append(
                                    f"{file_path.relative_to(skill_dir)}:{line_num}: "
                                    f"Relative path '{path_ref}'. Use absolute path: {absolute_path}"
                                )
        except Exception as e:
            errors.append(f"FATAL: Error reading {file_path}: {e}")

    # Walk through all files in the skill directory
    for root, _, files in os.walk(skill_dir):
        for file in files:
            file_path = Path(root) / file
            check_file(file_path)

    return errors

def lint_markdown(skill_md_path: Path) -> List[str]:
    """Lint SKILL.md for common Markdown issues."""
    errors = []
    with open(skill_md_path, 'r') as f:
        content = f.read()

    # Check for unclosed code blocks
    code_block_count = content.count("```")
    if code_block_count % 2 != 0:
        errors.append("FATAL: Unclosed code block in SKILL.md.")

    # Check for unclosed YAML frontmatter
    if content.count("---") < 2:
        errors.append("FATAL: Unclosed YAML frontmatter in SKILL.md.")

    return errors

def validate_skill_folder(skill_dir: Path) -> None:
    """Run all Chain of Verification checks on a skill folder."""
    errors = []

    # Check SKILL.md exists
    skill_md_path = skill_dir / "SKILL.md"
    if not skill_md_path.exists():
        errors.append(f"FATAL: Missing SKILL.md in {skill_dir}")
        print("\n".join(errors))
        raise FileNotFoundError(f"FATAL: Missing SKILL.md in {skill_dir}")

    # Validate frontmatter
    errors.extend(validate_frontmatter(skill_md_path))

    # Validate paths
    errors.extend(validate_paths(skill_dir))

    # Lint Markdown
    errors.extend(lint_markdown(skill_md_path))

    if errors:
        print("\nValidation Errors:")
        print("\n".join(errors))
        raise ValueError(f"FATAL: Validation failed for {skill_dir}")

    print(f"\n✅ Skill at {skill_dir} passed all Chain of Verification checks.")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python validate_skill.py <skill_directory>")
        sys.exit(1)
    skill_dir = Path(sys.argv[1]).expanduser().resolve()
    validate_skill_folder(skill_dir)