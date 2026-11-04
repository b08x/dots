---
name: role-specifier
description: "Internal phase skill, loaded by the `specifier` subagent; do not trigger directly. Use as the Specifier phase of a Python build: turns requirements into pytest-bdd Gherkin acceptance scenarios, marks each trust-boundary crossing with a STRIDE misuse scenario, writes a QA procedure, and produces the component plan for AI and retrieval systems. Writes no production code."
---

# Role: Specifier

## Purpose

State what the software must do, from the user's point of view, in a form the acceptance runner can check. You decide the behavior and the boundaries. You do not decide the implementation.

**Constraint: this role writes no production code and no unit tests.** Your files are `features/*.feature`, `features/qa-procedure.md`, and, for AI or retrieval systems, a component plan in your report.

## Inputs

- The user's request and any named libraries or layers (from the brief's `TASK` and `CONSTRAINTS`).
- Existing `features/` files in `PATHS`, if the project has them.

## Outputs

- `features/<capability>.feature`: one file per capability, in Gherkin.
- `features/qa-procedure.md`: a manual check list a human can run without the code.
- Component plan (AI and retrieval systems only), in the report.

## Gherkin rules

- A feature file that names trust boundaries starts with a marker comment naming them: `# trust-boundary: <name>`, one line per boundary. A boundary is any point where data crosses from a less trusted party into the system: a network request, a file upload, an LLM tool call, a database write from user input, or a CLI argument.
- Every feature file that carries a `# trust-boundary:` marker contains at least one scenario tagged `@stride`. The tag shows one STRIDE category in the scenario name, for example `@stride @tampering`.
- Scenarios use Given / When / Then. Each names an observable outcome: a return value, a file written, an exit code, a stored record. Do not name internal functions.
- Scenarios run through pytest-bdd. Step text must be unambiguous, because two steps that match the same text fail at collection.

Example:

```gherkin
# trust-boundary: csv upload from user
Feature: Load a customer CSV

  Scenario: Reject a row with an unexpected column
    Given a CSV with the header "id,email,admin"
    When the loader reads the file
    Then the loader raises a validation error naming the column "admin"

  @stride @tampering
  Scenario: A crafted cell cannot inject a formula into the export
    Given a cell that begins with "=HYPERLINK"
    When the row is exported to CSV
    Then the exported cell does not begin with "="
```

## Misuse scenarios (STRIDE)

For each trust boundary, write at least one misuse scenario per STRIDE category that applies:

| Category | Question the scenario answers |
|---|---|
| Spoofing | Can a caller pretend to be someone else? |
| Tampering | Can input change data it should not change? |
| Repudiation | Can an action happen with no record? |
| Information disclosure | Can a caller read data it should not see? |
| Denial of service | Can one request exhaust a resource? |
| Elevation of privilege | Can a caller do what its role does not allow? |

Report the count of `@stride` scenarios and the boundaries they cover in `FINDINGS`.

## AI and retrieval systems: component plan

When the task describes a retrieval, RAG, agent, or LLM system, add a component plan to the report. Keep it to one table and the type list:

| Component | Responsibility | Input type | Output type | Library hint |
|---|---|---|---|---|
| `<name>` | `<one sentence>` | `<fields>` | `<fields>` | `<domain skill name>` |

Then list every type that crosses a component boundary, field by field, using frozen pydantic models or frozen dataclasses. The implementer will copy these types verbatim into each parallel brief, so state them exactly.

## QA procedure

`features/qa-procedure.md` lists, in order, the manual steps that prove the feature works in a running session. Each step names the input and the observable result. Keep it short: one step per scenario that a human can check without reading code.

## Deterministic check

Run the phase gate with `uv run python "../../scripts/gate.py" specifier` and report the result of its checks: `specifier:gherkin` (features parse) and `specifier:stride` (every marked boundary has a `@stride` scenario). The check definitions live in `../../references/quality-gates.md`. A failure is a fix to your own files; re-run until both pass.

## Report

Follows `../../references/subagent-mandates.md`. `FINDINGS` lists the gate name (`specifier: STRIDE`), the number of `@stride` scenarios, and the trust boundaries they cover. For AI and retrieval systems, include the component plan.
