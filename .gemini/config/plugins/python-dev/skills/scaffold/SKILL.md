---
name: scaffold
description: Use when creating a new Python project or package. Scaffolds with devstart (devstart new <name> -y --python 3.12), falls back to uv init --package when devstart is absent, then applies the python-dev gate overlay so the project passes every phase gate that can run on its first run. A `not run` result is reported, never counted as a pass. Use for "start project", "scaffold", "new package", or "create CLI".
---

# Scaffold: New Python Projects

A new project starts with a layout that already passes the gates. The scaffold creates the layout, and the overlay adds the gate configuration, the pinned tools, and the directories the acceptance runner needs.

## Procedure

1. **Check for an existing project.** If `pyproject.toml` exists in the target directory, stop. Scaffolding is for new projects only. Use the brownfield route.
2. **Create the project.**
   - If `devstart` is on the PATH: `devstart new <name> -y --python 3.12` in the parent directory.
   - Otherwise: `uv init --package <name> --python 3.12` in the parent directory.
   - Record which path you used in your report.
3. **Apply the overlay.** Run `uv run "scripts/apply_overlay.py" --project <project-dir>`. It is idempotent.
4. **Check the first gate run.** Run `uv run python "../../scripts/gate.py" implementer --root <project-dir>` and `... specifier`. A fresh project should pass both. Record any `not run` result with the tool name.
5. **Report.** Give the project path, the scaffold path used, and the gate results.

Details of each overlay step are in `references/devstart-overlay.md`.

## What the overlay adds

- Pinned gate tools from `../../references/gate-tools.toml`, installed with `uv add --dev`.
- Ruff rules for complexity (limit 6), required `from __future__ import annotations`, banned `importlib.import_module`, private access, and Google docstrings.
- `features/` for acceptance scenarios and `tests/step_defs/` for their step definitions.
- `tach.toml` and an import-linter contract that keeps the entry point out of library code.
- mutmut source paths, and pydoclint in Google style.
- A `uv lock` and a first commit.

## Choosing a project shape

| Need | Shape |
|---|---|
| A command-line tool | Package with a `__main__.py` entry point. Add the `tui` skill for rich output. |
| A library | Package without an entry point. The import-linter contract still holds. |
| A service | Package with `pydantic-settings` config and a `db-engineer` or `genai` layer. |
| A single script under about 50 lines, stdlib only | Do not scaffold. Use Lite Mode. |

## Rules

- Scaffold before any other domain skill, so the layout exists when the other skills write into it.
- Do not edit devstart's generated files by hand to satisfy a gate. Change the overlay, then rerun it.
- The project name is the distribution name. The import name is the same with hyphens replaced by underscores.
