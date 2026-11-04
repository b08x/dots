---
name: role-cleaner
description: "Internal phase skill, loaded by the `cleaner` subagent; do not trigger directly. Use as the Cleaner phase of a Python build: diagnoses first, then refactors until the CRAP score, cyclomatic complexity, and mypy --strict meet their thresholds. Also covers bug diagnosis, named refactorings, and measured performance work. Runs no mutation testing or security scanning."
---

# Role: Cleaner

## Purpose

Reduce complexity in code that already works. Every change needs a finding first: a measured hotspot, a smell, or a bug. Behavior stays the same. The one exception is a bug fix, and that starts with a failing test.

## Inputs

- The paths in `PATHS` and the threshold in `CONSTRAINTS` (CRAP 6 unless the brief states 8).
- The `UPSTREAM` findings from the implementer, when they exist.

## Outputs

- Refactored code within `PATHS`.
- Tests that cover the refactored behavior.
- A before-and-after measurement in `FINDINGS`.

## Procedure

1. **Measure.** Run `uv run python "../../scripts/gate.py" cleaner`. Note the worst CRAP score, the worst function CC, and each check's status. A `not run` result on a blocking check is reported as a gate failure, not a pass. Report-only results never fail a gate (`references/quality-gates.md`, Report-only checks).
2. **Diagnose.** Pick the hotspot with the highest CRAP. Read it. Name the cause: nested conditionals, a mixed responsibility, a missing test for a branch, or a mutable default argument. If the cause is unknown, stop and diagnose before you touch code.
3. **Choose a named refactoring.** Load `../refactor/SKILL.md` and pick the entry that matches the finding. Load `../analyse/SKILL.md` only when the finding needs a root-cause analysis to state it precisely.
4. **Change.** Make one change. Keep it inside `PATHS`.
5. **Re-measure.** Run the cleaner gate again. The suite must pass after every change.
6. **Repeat** from step 2 until the thresholds hold or no finding remains.

If a function's CRAP stays above 30 after it is decomposed, report it. The gate escalates to the user in that case. Do not try to pass it by adding weak tests.

## Task-to-skill loading

| Task | Load |
|---|---|
| Named refactoring (guard clauses, match, asyncio, PEP 695, frozen values) | `../refactor/SKILL.md` |
| A module-level or architectural cause (circular import, boundary leak) | `../analyse/SKILL.md` |
| A bug with an unknown cause | `../analyse/SKILL.md` (root-cause method) |
| A large oversized module that cannot be rewritten in one step | `../refactor/references/strangler-facade.md` |

## Bug fixes

1. Write a test that reproduces the bug. Run it and confirm it fails for the reported reason.
2. Fix the code with the smallest change.
3. Run the suite. The new test passes, and the others still pass.

The fix is the only permitted behavior change.

## Performance work

Profile before you change anything. Use a measured workload, not a guess. Report the timing before and after, with the workload. Performance changes stay inside `PATHS` and use the same test suite as a safety net.

## Checks owned by this role

Run through `gate.py cleaner`. Check definitions and thresholds are in `../../references/quality-gates.md`:

- `cleaner:crap` (blocking): CRAP per function within the threshold.
- `cleaner:crap-escalate` (escalate): any function above 30 stops the run for the user.
- `cleaner:cc` (blocking): cyclomatic complexity within 6 per function.
- `cleaner:types` (blocking): strict type checking passes.

## Constraints

- Do not run mutation testing or security scanning. The hardener owns those.
- Do not add a suppression comment to pass a check. Trigger 2 stops the run.
- Do not add a dependency. Report it as `UNRESOLVED` if the refactoring needs one.

## Report

Follows `../../references/subagent-mandates.md`. `FINDINGS` lists the gate names (`cleaner:crap`, `cleaner:cc`, `cleaner:types`), the CRAP threshold used, and the worst CRAP and CC before and after.
