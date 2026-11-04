---
name: analyse
description: Use when diagnosing a Python codebase's problems with Kaizen methods (Gemba Walk, Value Stream, Muda, Root-Cause, Five Whys) or surveying technical debt (code, architecture, technology, testing, docs) with measured units. Maps each method to a Python failure mode and to a handoff key that the cleaner or verifier can act on.
---

# Analyse: Kaizen Diagnostics and Debt Survey

Find the cause before the change. Each method produces a handoff key in the form `<method>:<category>`, so the cleaner or verifier can act on it without re-deriving the analysis.

## Methods

| Method | Use when | Output key |
|---|---|---|
| Gemba Walk | You need to see how the code is actually used | `gemba:<area>` |
| Value Stream | A request crosses several modules and the delay is unclear | `stream:<step>` |
| Muda (waste) | The code has dead, duplicated, or unused parts | `muda:<category>` |
| Root-Cause | A symptom has an unknown cause | `root-cause:<cause>` |
| Five Whys | The cause is one layer below the symptom | `whys:<depth>` |
| Tech debt | A survey of the whole project or a module | `tech-debt:<code\|architecture\|technology\|testing\|docs>` |

## Python failure modes

| Key | Symptom | Diagnostic | Handoff |
|---|---|---|---|
| `muda:inventory` | Declared dependencies that nothing imports | `deptry` (unused and missing dependencies) | cleaner removes the entry; protected path, so the brief must name `pyproject.toml` |
| `muda:dead-code` | Functions and modules nothing calls | Code graph search for callers (`codebase-memory-mcp`), then `grep` to confirm no dynamic dispatch | cleaner deletes after the suite passes |
| `root-cause:circular-import` | `ImportError` at startup, or an eager-import failure | `tach show` for the module graph | cleaner breaks the cycle with a protocol or a moved function |
| `root-cause:boundary-leak` | A module reaches into another module's internals | `tach check` output, and the boundary rule in `python-patterns.md` | cleaner routes through the facade |
| `root-cause:mutable-default` | Shared state between calls | Read the signature | cleaner applies the `refactor` skill entry |
| `root-cause:blocking-io` | An async service stalls | Read the call sites inside `async def` | cleaner wraps the call with `asyncio.to_thread` |

## Tech debt method

Use `tech-debt:<category>` for a survey. The survey's full procedure is `../../tasks/debt-survey.md`.

Categories:

- `code`: complexity, duplication, long functions.
- `architecture`: cycles, boundary violations, layering breaks.
- `technology`: outdated, vulnerable, or unused dependencies.
- `testing`: coverage, weak tests, missing acceptance scenarios.
- `docs`: undocumented public API, stale docstrings.

Rules for every debt item:

1. Carry a risk: Critical, High, Medium, or Low. Define the risk by effect: data loss or a security hole is Critical; a defect is High; a maintenance cost is Medium; a style issue is Low.
2. Carry a group: **Quick Win** (under one change, low risk), **Medium-Term** (a few modules, a planned change), or **Long-Term** (an architectural change).
3. Use a measured unit. Count functions above complexity 6, count cycles, count advisories, measure coverage in percent, count undocumented public names. Report the unit with the number.
4. Do not add dollar figures, hourly estimates, or ROI. The survey reports measured units only.

## Procedure

1. State the symptom or the survey scope in one sentence.
2. Choose the method that matches the question. Do not run a method that does not answer it.
3. Gather the measurement with the tool named in the table. Quote its output in the finding.
4. Name the cause. If the cause is one layer below the symptom, use Five Whys to go one layer at a time, and stop at the first cause you can change.
5. Emit the handoff key and the brief for the owning phase.

## Related

- `refactor` for the named change once the cause is known.
- `sift` for the verifier's quality report.
- Context7 for tool flags at point of use. Do not guess them.
