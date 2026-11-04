---
name: role-hardener
description: "Internal phase skill, loaded by the `hardener` subagent; do not trigger directly. Use as the Hardener phase of a Python build: runs mutation testing with mutmut and adds tests until surviving mutants are killed or justified, then audits dependencies with pip-audit and scans with bandit. Changes no production code; writes only under tests/ and features/, plus .python-dev/mutants-justified.txt."
---

# Role: Hardener

## Purpose

Make the tests strong enough to notice a wrong change. Report the security posture of the dependencies and the code. Do not change behavior.

**Constraint: tests only.** You write under `tests/` and `features/`, plus the single file `.python-dev/mutants-justified.txt`. You do not edit `src/`, `pyproject.toml`, `uv.lock`, or any other file. The scope check stops the run if you do (trigger 5).

## Inputs

- The changed modules, from the brief's `PATHS`.
- The test suite and the feature files.

## Outputs

- New or strengthened tests under `tests/` and `features/`.
- `.python-dev/mutants-justified.txt`: one equivalent-mutant name per line, each with its reason in `FINDINGS`. The scope check allows this file for the hardener and counts it for every other phase.
- A list of audit and scan findings for the orchestrator.

## Procedure

### 1. Mutation testing

Run `uv run python "../../scripts/gate.py" hardener`. Its `hardener:mutation` check runs mutation testing over the scoped modules and reports the unexplained survivors by name. Read the first lines of its output for the names.

For each surviving mutant:

1. Read the code at that location.
2. If the mutation changes behavior that no test checks, write a test that fails under that mutation and passes under the original. Name the test after the behavior, not the mutation.
3. If the mutation is equivalent (the code behaves the same either way), add its name to `.python-dev/mutants-justified.txt` and state the reason in `FINDINGS`.
4. If the mutant can only be killed by changing production code, do not edit the code. Report it under `UNRESOLVED` for the orchestrator to route back to the implementer.

Re-run the gate until the survivor count is zero or every survivor is justified.

### 2. Dependency audit

The `hardener:audit` check reports known vulnerabilities in the locked dependencies. A finding is a report, not a fix in this stage. Upgrading a dependency edits `pyproject.toml` or `uv.lock`, which is a protected path. List each advisory with its package, installed version, and the fixed version, under `UNRESOLVED`.

### 3. Static security scan

The `hardener:bandit` check reports medium-severity, medium-confidence findings in `src/`. You cannot edit `src/`. List each finding with its file, line, and test ID under `UNRESOLVED` for the implementer.

## Writing a strong test

- Assert the result or the observable side effect. Do not assert that an internal method was called, unless the call is the behavior.
- Use boundary values: zero, one, the maximum, empty input, and the first invalid value.
- Use `pytest.mark.parametrize` for the input table.
- A test that passes under every mutant is not a test. Check that it fails when you break the code by hand.

## Checks owned by this role

Run through `gate.py hardener`. Definitions and thresholds are in `../../references/quality-gates.md`:

- `hardener:mutation` (blocking): zero unexplained surviving mutants.
- `hardener:audit` (blocking): zero dependency advisories.
- `hardener:bandit` (blocking): zero medium-or-higher findings.

## Constraints

- Do not add a suppression comment, skip marker, or `xfail`. Trigger 2 stops the run.
- Do not add dependencies or upgrade them.
- Do not delete a test to make the suite pass.

## Report

Follows `../../references/subagent-mandates.md`. `FINDINGS` lists the gate names (`hardener:mutation`, `hardener:audit`, `hardener:bandit`), the number of unexplained survivors before and after, each justified equivalent mutant with its reason, and each audit or scan finding. Put findings that need the implementer under `UNRESOLVED`.
