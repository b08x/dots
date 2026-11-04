---
name: python-gate
description: Run one phase's quality gate and the scope check on the working tree, without dispatching a subagent. Use to check a phase by hand, for example after a scaffold or before a commit.
---

# Python Gate

Runs one phase gate from `../../references/quality-gates.md` against the working tree and reports the result. This skill dispatches no subagent and changes no project file.

## Usage

Provide the target phase: `specifier`, `implementer`, `cleaner`, `hardener`, `verifier`, or `lite`, and optional flags (`--baseline <file>`, `--brownfield`, `--brief-threshold 6`, `--verifier-report <file>`, `--touched <files...>`).

## Procedure

1. **Parse the phase.** The first argument must be one of `specifier`, `implementer`, `cleaner`, `hardener`, `verifier`, or `lite`. Stop with a usage line if it is missing or unknown.
2. **Scope check (when a baseline is given).** Run:

   ```bash
   uv run "../../scripts/scope_check.py" compare --baseline <file> --phase <phase> --paths <paths...>
   ```

   A non-zero exit means a trigger fired. Show the trigger and the diff stat, and stop.
3. **Gate.** Run:

   ```bash
   uv run "../../scripts/gate.py" <phase> [--baseline <file>] [--scope brownfield] [--brief-threshold <n>] [--verifier-report <file>] [--touched <files>]
   ```

   Pass `--scope brownfield` only when `--brownfield` was given. Pass the rest only when the user gave them.
4. **Report.** Show the `GATE:` line and each check's line, verbatim. Then explain each result in one sentence. Name the rollback target and the escalation when they are printed.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | pass |
| 1 | fail: a blocking check failed. Name the rollback target. |
| 2 | usage or configuration error. Show the message. |
| 3 | fail (not run): a tool is missing. Name the tool. Never call this a pass. |
| 4 | escalate: a check needs the user's decision. |

## Notes

- A `verifier:sift` result of `not run` is expected until the verifier report exists. The gate reports it as `GATE: fail (not run)` until `--verifier-report` names the saved verifier report. The verifier subagent writes the SIFT report, and the orchestrator saves it to `.python-dev/verifier-report.md` and passes that path (see `agents/pythonista.md`).
- For `scaffold` checks, run this after `apply_overlay.py`. A fresh project should pass every gate that can run. The hardener and verifier phases report `GATE: fail (not run)` until their inputs exist (see `devstart-overlay.md`). Report-only checks never fail a gate (`references/quality-gates.md`, Report-only checks).
