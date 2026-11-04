# devstart Overlay

The overlay is `skills/scaffold/scripts/apply_overlay.py`. This file records what each step does and why, so a reader can check the script without running it.

## Steps

| # | Step | Why |
|---|---|---|
| 1 | Ruff `lint.select` gains `C90`, `SLF`, `TID`, `D`. | `C90` enables the complexity rule; `SLF` bans private member access; `TID` bans dynamic imports; `D` enforces docstrings. |
| 2 | `lint.mccabe.max-complexity = 6` | The cleaner's complexity threshold, enforced at lint time. |
| 3 | `lint.isort.required-imports = ["from __future__ import annotations"]` | Ruff `I002` enforces the import in every module. `FA102` alone would not. |
| 4 | `lint.flake8-tidy-imports.banned-api` bans `importlib.import_module` | Dynamic imports hide edges from tach and import-linter. |
| 5 | `lint.pydocstyle.convention = "google"`; tests are exempt from `D`. | One docstring style for pydoclint and ruff. |
| 6 | `[tool.pydoclint] style = "google"` | Docstring parity with signatures (report-only gate). |
| 7 | `[tool.mutmut] source_paths` and `pytest_add_cli_args_test_selection` | Current mutmut 3 keys. The deprecated `paths_to_mutate` and `tests_dir` keys crash mutmut 3.8. |
| 8 | `[tool.importlinter]` with one forbidden contract | The library code must not import `<pkg>.__main__`. |
| 9 | `tach.toml` declaring `<pkg>` as the only module | Gives tach a boundary to check. |
| 10 | `features/` and `tests/step_defs/`; `tests/test_features.py` binds scenarios once a feature exists | pytest-bdd raises `NoScenariosFound` on an empty directory. |
| 11 | `.gitignore` gains `.python-dev/`, `mutants/`, and coverage paths | scope_check excludes them; they must not be committed. |
| 12 | `uv add --dev` with every pin in `gate-tools.toml` | Exact versions; no tool is installed outside the project. |
| 13 | `ruff check --select I002 --fix` then `ruff format` on `src` and `tests` | Existing devstart files predate the overlay. The fresh project must pass the ruff gate on its first run. |
| 14 | `uv lock`, then `git init` if needed and a first commit | The lockfile is part of the baseline. |

## Verified on

- devstart's default output (hatchling, `src/<pkg>`, mypy strict, pytest with `pythonpath = ["src"]`).
- All blocking checks in the implementer, cleaner, and specifier phases pass on the result. The hardener and verifier phases report `GATE: fail (not run)` until their inputs exist: `hardener:mutation` is **not run** on this host (see the note below), and `verifier:sift` needs a verifier report.

## Note on mutmut

On the host used for the first run, mutmut 3.8.0 reported every mutant as `timeout`, including on a one-test suite that passes in 0.4 seconds. The cause was not isolated. The gate reports this as `not run: mutmut harness`, never as a pass. Treat it as an open issue until a run on a clean host shows surviving and killed mutants.

## Rerunning

The overlay is idempotent for the file edits. Re-running `uv add --dev` and `uv lock` with the same pins changes nothing. Use `--skip-uv` to edit files only.
