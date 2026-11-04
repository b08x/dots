# Debt Survey (Brownfield)

A read-only survey of a whole existing project. It writes the baseline the debt ratchet compares against. The verifier runs it when its `TASK` is `survey`.

## Output files

- `.python-dev/debt-baseline.json`: written on the first run only.
- `.python-dev/debt-current.json`: written on every run after a baseline exists, so `gate.py`'s `verifier:debt-ratchet` can compare the two.
- `.python-dev/debt-report.md`: readable report, one row per debt item with its risk and group.

Both JSON files have the same shape:

```json
{
  "metrics": {
    "cc_over_limit": 0,
    "circular_deps": 0,
    "vulnerable_deps": 0,
    "outdated_deps": 0,
    "unused_deps": 0,
    "coverage_pct": 0.0,
    "undocumented_api": 0,
    "duplication_pct": 0.0
  },
  "measured_with": {"pkg": "<import name>", "pkg_dir": "<src/pkg or pkg>"}
}
```

The keys must match `LOWER_IS_BETTER` and `HIGHER_IS_BETTER` in `scripts/gate.py`. Lower is better for every key except `coverage_pct`.

## Measurements

Run each measurement from the project root. Record the tool's version with the result. If a tool is missing, record the key as `null` and list it in the report as `not run: <tool> unavailable`. Do not invent a number.

| Metric | Measurement | Unit |
|---|---|---|
| `cc_over_limit` | Count of ruff `C901` violations at max complexity 6 over the package directory | functions |
| `circular_deps` | Count of cyclic-dependency errors reported by `tach check`, when `tach.toml` exists | cycles |
| `vulnerable_deps` | Count of advisories from pip-audit on the locked requirements | advisories |
| `outdated_deps` | Count of packages with a newer version in the lock, from `uv pip list --outdated` | packages |
| `unused_deps` | Count of `unused` findings from deptry | dependencies |
| `coverage_pct` | Line coverage percent from a pytest-cov JSON report | percent |
| `undocumented_api` | Count of public names without a docstring, from interrogate | names |
| `duplication_pct` | Share of lines in duplicate-code reports from pylint `R0801` | percent |

Use Context7 to confirm each tool's current flags before running it. Do not guess flags.

## Report

`.python-dev/debt-report.md` has one row per debt item:

| Item | Category | Risk | Group | Measured |
|---|---|---|---|---|
| `<path or name>` | code / architecture / technology / testing / docs | Critical / High / Medium / Low | Quick Win / Medium-Term / Long-Term | `<number and unit>` |

Risk follows the rules in the `analyse` skill: define it by effect. Group follows the change size. Measured values use units only. Do not add dollar figures, hours, or ROI.

## Rules

- Read-only for the project. The only writes are under `.python-dev/`.
- Do not run any fixing command, for example an autofix, an installer, or `uv lock`.
- The survey does not gate anything by itself. The ratchet gate compares the numbers later.
