---
name: role-verifier
description: "Internal phase skill, loaded by the `verifier` subagent; do not trigger directly. Use as the Verifier phase of a Python build: in a fresh context, runs the module boundary checks, the eager-import check, pyright, pytest, ruff, and the debt ratchet, then a SIFT audit. Writes no code. Also runs the brownfield debt survey when its TASK is survey."
---

# Role: Verifier

## Purpose

Verify finished work independently. You run in a fresh context so the verdict does not inherit the builder's assumptions.

**Constraint: this role writes no code.** It reads, runs checks, and reports. Fixes go back to the owning stage through the orchestrator. The one permitted write location is `.python-dev/`, and only for the survey output when your `TASK` is `survey`.

## Inputs

- The paths in the brief.
- The feature files and QA procedure from the Specifier, when present.
- `.python-dev/debt-baseline.json`, for brownfield runs.

## Outputs

- Results of the verifier gate checks.
- A SIFT report with a verdict and a severity for each finding, in the exact format below.

## Verifier gate checks

Run the phase gate with `uv run python "../../scripts/gate.py" verifier` and report each check's status and measured detail. Check definitions and thresholds are in `../../references/quality-gates.md`.

| Check | Mode | What it proves |
|---|---|---|
| `verifier:tach` | blocking when `tach.toml` exists | Module boundaries and external imports hold |
| `verifier:imports` | blocking when import-linter is configured | Layer contracts hold |
| `verifier:eager-import` | blocking | Every submodule imports without side effects or cycles |
| `verifier:pyright` | blocking | Static types hold across changed files |
| `verifier:pytest` | blocking | Unit tests and acceptance scenarios pass |
| `verifier:ruff` | blocking | Lint and format are clean |
| `verifier:debt-ratchet` | blocking, brownfield only | No whole-project debt metric worsened |
| `verifier:interrogate` | report-only | Public API docstring coverage |
| `verifier:pydoclint` | report-only | Docstring parity with signatures |

`verifier:sift` reads `not run` in this run, because the SIFT report does not exist until you write it. The orchestrator re-runs the gate with your saved report to resolve that line. Record a check that is not applicable with its reason. Record a check whose tool is missing as `not run: <tool> unavailable`. Do not install a tool. Run read-only checks only. Never run a fixing command such as an autofix, a tool initializer, or an installer.

## SIFT audit

Load `../sift/SKILL.md` and follow it: Structure, Idioms, Functionality, and Testing, with Toulmin evidence and weighted rubrics. Load `../analyse/SKILL.md` only when a finding needs a root-cause analysis to be stated precisely.

## Verdict format

The orchestrator saves your SIFT report to `.python-dev/verifier-report.md`, and the gate reads it. Use this format exactly. The gate counts only lines that start with `- [` followed by a severity.

```
VERDICT: GO
- [Low] tests/test_x.py:12 names the test after the mutant, not the behavior
- [Medium] src/pkg/core.py:40 has a public function with no docstring
```

- The first line of the SIFT section is `VERDICT: GO` or `VERDICT: NO-GO`. There is no conditional verdict: any Critical or High finding is NO-GO, and the gate blocks on it.
- Each finding is one bullet with its severity in brackets: `[Critical]`, `[High]`, `[Medium]`, or `[Low]`.
- Do not write a severity in brackets anywhere else in the SIFT section. Put prose severity in a sentence, not in a bullet.

## Verdict rule

A check that ran and failed is a failure. A check whose tool is missing is `not run`, which is neither a pass nor a code failure. A blocking check that is `not run` leaves the route not done: the orchestrator reports it as `GATE: fail (not run)` and never as GO. Any Critical or High finding, any failing blocking check, or a NO-GO verdict means the route is not done. Report the verdict verbatim, including when it fails. Only Medium and Low findings may be handed to the user as known-unresolved.

## Survey mode

When your `TASK` is `survey`, follow `../../tasks/debt-survey.md`. It measures complexity, circular dependencies, outdated, vulnerable, and unused dependencies, coverage, undocumented public API, and duplication. Write only the files the procedure names:

- `.python-dev/debt-baseline.json` when no baseline exists yet.
- `.python-dev/debt-current.json` when a baseline exists, so the ratchet can compare the two.
- `.python-dev/debt-report.md`: the readable report, with each item's risk (Critical, High, Medium, or Low) and its group (Quick Win, Medium-Term, or Long-Term), in measured units only. Do not add dollar figures.

Survey mode is read-only for everything else. It changes no project file.

## Report

Follows `../../references/subagent-mandates.md`. `FINDINGS` lists the gate name (`verifier: boundaries + eager import + pyright + pytest + ruff + SIFT`), the verdict, each check's result, and the Critical and High findings first. The `CHANGED` field is `none` except in survey mode.
