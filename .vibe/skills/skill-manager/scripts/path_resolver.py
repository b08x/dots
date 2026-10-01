#!/usr/bin/env python3
"""
path_resolver.py
Enforces absolute paths for all file references in a skill folder.
"""

import os
import re
from pathlib import Path

def resolve_paths(skill_dir: Path) -> None:
    """
    Recursively replace relative paths with absolute paths in all files.
    Absolute paths are formatted as: ~/.vibe/skills/{skill_name}/{relative_path}
    """
    skill_name = skill_dir.name
    base_path = f"~/.vibe/skills/{skill_name}"

    # Patterns to match file references
    patterns = [
        (r'(\[.*?\]\((.*?)\))', 2),  # Markdown links: [text](path) -> group 2
        (r'(include\s+[\'\"](.*?)[\'\"])', 2),  # Include statements
        (r'(require\s+[\'\"](.*?)[\'\"])', 2),  # Require statements
        (r'(read_file\s*\(\s*[\'\"](.*?)[\'\"]\s*\))', 2),  # read_file tool calls
        (r'(\.\/|\.\.\/|/)([a-zA-Z0-9_\-\./]+)', 0),  # Relative paths (entire match)
    ]

    def update_file(file_path: Path) -> None:
        """Update all relative paths in a file to absolute paths."""
        try:
            content = file_path.read_text()
            updated_content = content
            lines = content.splitlines()

            for line_num, line in enumerate(lines):
                for pattern, group_idx in patterns:
                    for match in re.finditer(pattern, line):
                        path_ref = match.group(group_idx)
                        if not path_ref:
                            continue

                        # Skip absolute paths, URLs, and anchor links
                        if (path_ref.startswith(('~', '/', 'http://', 'https://')) or
                            path_ref.startswith('#')):
                            continue

                        # Skip if it's a Windows path (e.g., C:\...)
                        if re.match(r'^[a-zA-Z]:\\', path_ref):
                            continue

                        # Construct absolute path
                        # Handle relative paths (./, ../, or just filename)
                        if path_ref.startswith('./'):
                            relative_path = path_ref[2:]
                        elif path_ref.startswith('../'):
                            relative_path = path_ref
                        else:
                            relative_path = path_ref

                        absolute_path = f"{base_path}/{relative_path}"

                        # Replace the path in the line
                        new_line = line.replace(path_ref, absolute_path)
                        if new_line != line:
                            lines[line_num] = new_line
                            # Add a resolution note as a comment
                            if not any(f"Path Resolution Note: {absolute_path}" in l for l in lines):
                                lines.insert(line_num + 1, f"<!-- Path Resolution Note: Use absolute path `{absolute_path}`. Fallback: Try relative path `{path_ref}`. -->")

            updated_content = "\n".join(lines)
            if updated_content != content:
                file_path.write_text(updated_content)
                print(f"Updated paths in: {file_path.relative_to(skill_dir)}")

        except Exception as e:
            print(f"FATAL: Error processing {file_path}: {e}")

    # Walk through all files in the skill directory
    for root, _, files in os.walk(skill_dir):
        for file in files:
            file_path = Path(root) / file
            update_file(file_path)

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("Usage: python path_resolver.py <skill_directory>")
        sys.exit(1)
    skill_dir = Path(sys.argv[1]).expanduser().resolve()
    resolve_paths(skill_dir)
    print(f"\n✅ All paths in {skill_dir} resolved to absolute paths.")