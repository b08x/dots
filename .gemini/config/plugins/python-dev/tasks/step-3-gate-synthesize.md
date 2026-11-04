# Step 3: Gate, Rollback, and Synthesize

Run this after each stage returns.

## 1. Scope check

```bash
uv run "../scripts/scope_check.py" compare --baseline .python-dev/baseline.json --phase <phase> --paths <PATHS>
```

| Exit | Action |
|---|---|
| 0 | Continue to the gate. |
| 1 | A trigger fired. Show the trigger and the diff stat, then stop and ask the user. This does not count against the rollback cap. |
| 2 | Usage or git error. Fix the call and rerun. |

## 2. Gate

```bash
uv run "../scripts/gate.py" <phase> --baseline .python-dev/baseline.json --scope <greenfield|brownfield> [--brief-threshold <n>]
```

For the verifier, add `--verifier-report .python-dev/verifier-report.md` after saving the report (see `step-2-dispatch-reconcile.md`, section 6).

| Exit | Action |
|---|---|
| 0 | Pass. Continue. |
| 1 | Blocking failure. Re-dispatch the `ROLLBACK:` target with the failing check, its measured value, and its output as the new `TASK`. Scope-check and gate again. |
| 2 | Configuration error. Show the message and stop. |
| 3 | `fail (not run)`. A tool is missing. Record `not run: <tool> unavailable`. Do not roll back. Continue the route and list it in the final summary. |
| 4 | Escalate. Show the `ESCALATE TO USER:` check and stop. |

## 3. Rollback cap

At most 2 rollbacks per gate. After the second failure on the same gate, stop, show the failing check and its measured values, and ask the user.

A rollback to the implementer re-runs every later stage in the route, because the route is linear.

## 4. Verifier verdict

The verifier's verdict is a gate. A Critical or High finding, or a NO-GO, means the route is not done. Roll back to the verifier row's target with the finding as `TASK`. Medium and Low findings may go to the user as known-unresolved.

## 5. Final verification

Run the plan's `VERIFY` command yourself. If it fails, the route is not done.

## 6. Report

Include:

- What changed, by file path.
- Which stages ran, and which were skipped and why.
- The verifier verdict, verbatim.
- The `VERIFY` command and its result.
- Every gate check that ended `not run`, with the tool name.
- For brownfield runs, the debt-ratchet result.
- Any escalation or trigger that stopped the run.

Do not replay the subagents' full output.
