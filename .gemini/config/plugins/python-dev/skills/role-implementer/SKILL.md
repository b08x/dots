---
name: role-implementer
description: "Internal phase skill, loaded by the `implementer` subagent; do not trigger directly. Use as the Implementer phase of a Python build: writes pytest unit tests and pytest-bdd step definitions, then production code, until the acceptance scenarios and unit tests pass. Routes to the domain skill named in the brief."
---

# Role: Implementer

## Purpose

Make the acceptance scenarios and unit tests pass with the simplest code that does it. Tests come first. The suite decides when you are done.

## Inputs

- Feature files and the QA procedure from the Specifier, when the route includes it.
- The brief's `TASK`, `PATHS`, `SKILLS`, `CONTRACT`, and `CONSTRAINTS`.

## Outputs

- Unit tests under `tests/` and step definitions under `tests/step_defs/`.
- Production code under `src/<pkg>/` (or `<pkg>/` for a flat layout).
- A suite that passes.

## Order of work

1. If the brief's `SKILLS` names `scaffold`, load it first and create the project. Greenfield projects get `devstart` or `uv init --package`, then the overlay. Nothing else is written until the scaffold exists.
2. Load only the domain skills the brief names, under `../../skills/<name>/SKILL.md`. Do not load a skill the brief does not name.
3. Write the unit tests and step definitions for the behavior in `TASK`. Run them and confirm they fail for the right reason.
4. Write the production code until they pass.
5. Re-run the gate and report.

## Domain routing

| Brief `SKILLS` | Skill to load |
|---|---|
| `scaffold` | `../scaffold/SKILL.md` |
| `genai` | `../genai/SKILL.md` |
| `nlp` | `../nlp/SKILL.md` |
| `tui` | `../tui/SKILL.md` |
| `db-engineer` | `../db-engineer/SKILL.md` |

## Python conventions

The full pattern table is in `../../references/python-patterns.md`. The short form:

- `from __future__ import annotations` first, after the module docstring, in every `.py` file.
- `__all__` in every public module. Private helpers start with an underscore.
- Pydantic models (`frozen=True, strict=True, extra="forbid"`) at I/O boundaries. Frozen dataclasses for internal values. No raw `dict` as a domain object.
- `typing.Protocol` for injected dependencies, passed through keyword-only constructor arguments.
- Settings through `get_settings()` from `pydantic-settings`. Never `os.environ` in project code. See `../../references/environment-variables.md`.
- Logging through a module logger. See `../../references/logging-patterns.md`.
- No bare `except:`. No `typing.List`, `Dict`, `Optional`. Use `list`, `dict`, `X | None`, and PEP 695 generics.
- Never add a suppression comment to silence a checker. Trigger 2 stops the run on `# type: ignore`, `# noqa`, `# pragma: no cover`, and `# pyright: ignore`.

## Tests

- A unit test asserts an observable result. A test that only checks that a call happened is weak, and the hardener will find it.
- Use `pytest.mark.parametrize` for input variation, not copies of the same test.
- Acceptance scenarios bind to step definitions under `tests/step_defs/`. Each step has one definition.

## Deterministic checks

Run the phase gate with `uv run python "../../scripts/gate.py" implementer`. It reports:

- `implementer:suite` (blocking): the pytest suite is green.
- `implementer:gitleaks` (blocking): no secret findings.
- `implementer:cc` (report-only): per-function complexity. The target is 4 or less. Report the functions over it in `FINDINGS`. Do not fix them in this stage; the cleaner owns complexity.

Check definitions and thresholds: `../../references/quality-gates.md`.

## Genai choice: GEPA or MIPROv2

When the task optimizes a DSPy program, choose the optimizer here and say why in `FINDINGS`:

- **dspy.GEPA**: the metric returns `dspy.Prediction(score=float, feedback=str)` and the labeled set has roughly 20 to 100 examples. Set `reflection_lm` to a strong model and the task model to a cheap one.
- **dspy.MIPROv2**: the metric is a scalar only, or the training set is larger.

A plain-scalar metric passed to GEPA still runs, but the reflection loop loses its feedback channel. Do not do that silently.

## Report

Follows `../../references/subagent-mandates.md`. `FINDINGS` lists the gate names (`implementer:suite`, `implementer:gitleaks`), the test count, the CC report-only list, and any unverified library API under the Context7 rule.
