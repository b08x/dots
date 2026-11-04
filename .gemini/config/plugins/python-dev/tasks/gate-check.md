# Gate Check: Run One Phase

Runs the gate for one phase with `scripts/gate.py`. The checks, thresholds, and rollback targets are defined in `references/quality-gates.md`. This task only describes how to call the runner and read its output.

## Call

```bash
uv run "../scripts/gate.py" <phase> \
  --root <project-root> \
  [--baseline .python-dev/baseline.json --scope brownfield] \
  [--brief-threshold 6|8] \
  [--verifier-report .python-dev/verifier-report.md] \
  [--touched <files>]
```

- `--root` defaults to the current directory. Pass it when the project is elsewhere.
- `--baseline` and `--scope brownfield` go together. Brownfield runs check only changed files for `scope=changed` checks.
- `--brief-threshold 8` only when the brief states CRAP 8.
- `--verifier-report` only for the verifier phase, after the report is saved.
- `--touched` only for `lite`.

## Output

```
GATE: pass | fail | fail (not run) | escalate (<phase>)
  [pass] <phase>:<check> (<mode>) - <detail>
  [FAIL] ...
  [not run] ...
  [n/a] ...
  [report] ...
  [ESCALATE] ...
ROLLBACK: <phase>          (when a blocking check failed)
ESCALATE TO USER: <check>  (when a check escalated)
```

## Exit codes

| Code | Gate | Meaning |
|---|---|---|
| 0 | pass | Every blocking check passed or is not applicable. |
| 1 | fail | A blocking check failed. Roll back to `ROLLBACK:`. |
| 2 | usage | Bad arguments or configuration. |
| 3 | fail (not run) | A tool is missing or a builtin input is absent. |
| 4 | escalate | A check needs the user, for example CRAP above 30. |

Precedence when several results apply: escalate, then fail, then not run.

## Rules

- Never report `not run` as a pass.
- Never call `gate.py` with `--verifier-report` before the verifier's report is saved.
- A `report` line never affects the gate result.
- Show the `GATE:` line and the check lines verbatim. Explain each in one sentence.
