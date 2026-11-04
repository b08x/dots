---
name: sift
description: Use when assessing Python code quality, running an architectural review, or writing a tech advisory report. Applies the SIFT Protocol (Structure, Idioms, Functionality, Testing) with a Toulmin evidence model and weighted rubrics. Four report modes - Full, System Design, Tech Advisory, Backlog. Loaded by the verifier for the SIFT audit.
---

# SIFT: Quality Assessment Protocol

SIFT assesses a Python codebase on four dimensions and reports each finding with Toulmin evidence and a severity. The protocol is the same in every mode. Only the output shape changes.

## Dimensions and weights

| Dimension | Weight | Asks |
|---|---|---|
| Functionality | 0.35 | Does it do what the specification and the features say, including misuse cases? |
| Structure | 0.25 | Are module boundaries, dependencies, and responsibilities sound? |
| Idioms | 0.20 | Is the code idiomatic Python 3.12+ and consistent with the project's conventions? |
| Testing | 0.20 | Do the tests check behavior, and would they catch a regression? |

Overall score = (Functionality × 0.35) + (Structure × 0.25) + (Idioms × 0.20) + (Testing × 0.20), each dimension scored 0 to 100.

## Toulmin evidence

Every finding has six elements:

1. **Claim**: the statement the finding makes, in one sentence.
2. **Data**: the measured or observed facts. Cite `path:line`, a gate output, or a command result.
3. **Warrant**: the rule that connects the data to the claim. Cite a principle, for example a TRUE quality from `../../references/ood-principles.md` or a pattern from `../../references/python-patterns.md`.
4. **Backing**: why the warrant holds in this project. Name the evidence that supports the rule.
5. **Qualifier**: how sure the finding is: "always", "usually", or "in this context".
6. **Rebuttal**: when the finding does not apply. For example, "unless the module is a generated client".

A finding without data and a warrant is an opinion, and it is not reported.

## Severity

| Severity | Meaning | Effect on the verdict |
|---|---|---|
| Critical | Wrong behavior, data loss, a security hole, or a broken import | NO-GO until fixed |
| High | A defect likely to cause a bug, or a boundary violation | NO-GO until fixed |
| Medium | Maintainability cost with no current defect | Known-unresolved |
| Low | Style, naming, or a minor smell | Known-unresolved |

## Verdict

- **GO**: no Critical or High finding.
- **NO-GO**: any Critical or High finding. The verifier gate blocks on both.

The weighted dimension scores inform the report. The verdict follows the severities alone.

## Report modes

- **Full** (default): all four dimensions, every finding with Toulmin evidence, and a verdict.
- **System Design**: Structure and Functionality only, with the boundary map and the crossing types.
- **Tech Advisory**: the verdict, the Critical blockers, and the path to GO. Keep it to one page.
- **Backlog**: findings grouped as Quick Win, Medium-Term, and Long-Term, with the measured unit for each.

## Python idioms checklist

Check each item and cite one example per violation.

- `from __future__ import annotations` present in every module.
- Public modules declare `__all__`.
- Generics use PEP 695 syntax. No `typing.List`, `Dict`, `Optional`, or legacy `TypeVar`.
- No bare `except:`. Exceptions are narrowed and re-raised with `from`.
- No mutable default arguments.
- Domain values are frozen dataclasses or frozen pydantic models. No raw `dict` passed across a module boundary.
- Settings come from `pydantic-settings`. No `os.environ` reads outside the settings module.
- Context managers for files, locks, and connections.
- `match` used where a closed set of shapes is dispatched on.
- No `importlib.import_module` in project code (banned by ruff TID251).

## Testing checklist

- Tests assert observable results, not internal calls.
- Each acceptance scenario has a step definition with a single meaning.
- Boundary values are covered: zero, one, empty, the maximum, the first invalid value.
- No test is skipped, xfailed, or suppressed.
- A mutation run shows the tests catch behavior changes (see the hardener's `hardener:mutation` check).

## Procedure

1. Read the specification (features and QA procedure) and the brief's `PATHS`.
2. Run the verifier gate for measured data: `uv run python "../../scripts/gate.py" verifier`.
3. Score each dimension, recording every finding with its six Toulmin elements.
4. Assign each finding a severity. Compute the verdict with the rules above.
5. Write the report in the exact format the verifier role defines (`VERDICT:` line, then one bullet per finding).

## Related

- The `analyse` skill when a finding needs a root cause.
- The `role-verifier` skill for the exact report format and the gate checks.
