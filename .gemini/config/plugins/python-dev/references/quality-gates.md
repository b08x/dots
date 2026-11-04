# Quality Gates

Single source of truth for gate commands, thresholds, modes, rollback routes, and escalation triggers. Role skills cite the check names below and never restate commands. `scripts/gate.py <phase>` runs one phase. The orchestrator (`pythonista` or `the python-development skill`) executes rollback. Phase agents never choose the route.

## Block format

Every executable check is a fenced block whose info string carries the check name and its keys:

````
```gate:<phase>:<check> mode=<blocking|report-only|escalate> rollback=<phase|none> scope=<project|changed> tool=<executable|builtin:name|none>
<command>
```
````

- `mode`: `blocking` fails the gate. `report-only` is recorded in `FINDINGS` and never fails it. `escalate` stops the run and asks the user (see Escalation).
- `rollback`: the phase the orchestrator re-dispatches on failure. `none` for report-only and escalate.
- `scope`: `project` runs against the whole project. `changed` runs against the target list described in Greenfield and Brownfield scope.
- `tool`: the executable that must be present in the project environment, `builtin:<name>` for checks that need Python logic, or `none`. A missing tool yields `not run` (see Missing tools).
- The body runs with `bash -eu -o pipefail` from the project root. Exit 0 is a pass. A body may hold several commands.
- Placeholders: `<pkg>` is the import name from `[project].name` (hyphens become underscores). `<pkg_dir>` is `src/<pkg>` when it exists, otherwise `<pkg>`. `<TARGET>` is the file or module list for the check's scope. `<CRAP>` is the CRAP threshold (6 by default, 8 only when the brief states it). `<TOUCHED>` is the set of files touched in Lite Mode.

## Gates

| Phase | Checks | Threshold | Mode | Rollback target |
|---|---|---|---|---|
| specifier | `gherkin`, `stride` | Every `features/*.feature` parses; every feature file that marks a trust boundary has at least one `@stride` scenario | blocking | specifier |
| implementer | `suite`, `gitleaks`, `cc` | Test suite green; gitleaks zero findings; per-function CC ≤ 4 | `suite`, `gitleaks` blocking; `cc` report-only | implementer |
| cleaner | `crap`, `crap-escalate`, `cc`, `types` | CRAP ≤ `<CRAP>` per function; any function with CRAP > 30 escalates; ruff C901 max-complexity 6; `mypy --strict` clean | `crap`, `cc`, `types` blocking; `crap-escalate` escalate | implementer |
| hardener | `mutation`, `audit`, `bandit` | Zero unexplained surviving mutants; pip-audit zero findings; bandit zero findings at medium severity and medium confidence | blocking | implementer |
| verifier | `tach`, `imports`, `eager-import`, `pyright`, `pytest`, `ruff`, `sift`, `debt-ratchet`, `interrogate`, `pydoclint` | All blocking checks pass; SIFT verdict with no Critical or High finding and not NO-GO | blocking except `interrogate` and `pydoclint` (report-only) | implementer |
| lite | `ruff-lite`, `compile-lite` | Touched files lint clean and compile | blocking | none |

The `hardener` gate never edits production code. Its only writes are tests under `tests/` or `features/`, plus the single file `.python-dev/mutants-justified.txt`. Trigger 5 enforces this. The scope check tracks that one file and allows it for the hardener only. Other `.python-dev/` files are excluded from the snapshot, so trigger 5 does not check them.

## Specifier

```gate:specifier:gherkin mode=blocking rollback=specifier scope=project tool=none
uv run python -c "import pathlib; from gherkin.parser import Parser; p = Parser(); [p.parse(f.read_text(encoding='utf-8')) for f in sorted(pathlib.Path('features').glob('*.feature'))]"
```

```gate:specifier:stride mode=blocking rollback=specifier scope=project tool=none
for f in $(grep -l '^#[[:space:]]*trust-boundary:' features/*.feature 2>/dev/null || true); do
  grep -q '@stride' "$f" || { echo "missing @stride: $f"; exit 1; }
done
```

Feature files that carry no `# trust-boundary:` marker are not required to contain `@stride`. The `features/` directory is checked by the not-applicable rule, not by the check body.

## Implementer

```gate:implementer:suite mode=blocking rollback=implementer scope=project tool=pytest
uv run pytest --strict-markers --strict-config
```

```gate:implementer:gitleaks mode=blocking rollback=implementer scope=project tool=gitleaks
gitleaks detect --no-git --redact --source .
```

```gate:implementer:cc mode=report-only rollback=none scope=changed tool=ruff
uv run ruff check --select C901 --config "lint.mccabe.max-complexity=4" <TARGET>
```

## Cleaner

```gate:cleaner:crap mode=blocking rollback=implementer scope=changed tool=crap4py
rm -f coverage.lcov
uv run pytest --cov=<pkg> --cov-branch --cov-report=lcov:coverage.lcov -q
uv run crap4py <TARGET> --lcov coverage.lcov --max-crap <CRAP>
```

```gate:cleaner:crap-escalate mode=escalate rollback=none scope=changed tool=crap4py
test -f coverage.lcov || { echo "coverage.lcov missing: the crap measurement did not run" >&2; exit 2; }
uv run crap4py <TARGET> --lcov coverage.lcov --max-crap 30
```

`crap-escalate` escalates only when crap4py exits 1, which means a function is above 30. Any other non-zero exit is a measurement error and is reported as a failure. The `rm -f` in `cleaner:crap` makes sure a stale `coverage.lcov` from an earlier run cannot be measured.

```gate:cleaner:cc mode=blocking rollback=implementer scope=changed tool=ruff
uv run ruff check --select C901 --config "lint.mccabe.max-complexity=6" <TARGET>
```

```gate:cleaner:types mode=blocking rollback=implementer scope=changed tool=mypy
uv run mypy --strict <TARGET>
```

CRAP formula, with `comp(f)` as cyclomatic complexity and `cov(f)` as branch coverage: `CRAP(f) = comp(f)² × (1 − cov(f))³ + comp(f)`. The cleaner reads the score from crap4py output. A function with CRAP > 30 cannot pass by adding tests alone. It must be decomposed, so the `crap-escalate` check escalates to the user rather than rolling back.

## Hardener

```gate:hardener:mutation mode=blocking rollback=implementer scope=changed tool=builtin:mutmut-survivors
uv run mutmut run '<TARGET>'
```

`builtin:mutmut-survivors` counts surviving mutants in `mutmut results` for the scoped modules. Each equivalent mutant must be listed in `.python-dev/mutants-justified.txt` (one name per line), with its reason in the hardener's `FINDINGS`. The gate reads that file. Greenfield `<TARGET>` is `<pkg>.*`. Brownfield `<TARGET>` is `<pkg>.<module>.*` for each changed module.

```gate:hardener:audit mode=blocking rollback=implementer scope=project tool=pip-audit
req="$(mktemp)"
trap 'rm -f "$req"' EXIT
uv export --frozen --no-hashes --no-emit-project --format requirements-txt > "$req"
uvx --from pip-audit==2.10.1 pip-audit --requirement "$req" --strict --desc
```

`pip-audit` exits non-zero on any known vulnerability. `--strict` also fails when dependency collection fails. The export goes to a temporary file because pip-audit does not read a requirements list from stdin. pip-audit runs in its own pinned tool environment, not in the project's venv: a vulnerable project dependency can break the tool that audits it.

```gate:hardener:bandit mode=blocking rollback=implementer scope=changed tool=bandit
uv run bandit -c pyproject.toml -r <TARGET> --severity-level medium --confidence-level medium
```

## Verifier

```gate:verifier:tach mode=blocking rollback=implementer scope=project tool=tach
uv run tach check && uv run tach check-external
```

```gate:verifier:imports mode=blocking rollback=implementer scope=project tool=lint-imports
uv run lint-imports
```

```gate:verifier:eager-import mode=blocking rollback=implementer scope=project tool=none
uv run python -W error -c "import importlib, pkgutil, <pkg>; [importlib.import_module(m.name) for m in pkgutil.walk_packages(<pkg>.__path__, <pkg>.__name__ + '.')]"
```

```gate:verifier:pyright mode=blocking rollback=implementer scope=changed tool=pyright
uv run pyright <TARGET>
```

```gate:verifier:pytest mode=blocking rollback=implementer scope=project tool=pytest
uv run pytest --strict-markers --strict-config
```

```gate:verifier:ruff mode=blocking rollback=implementer scope=changed tool=ruff
uv run ruff check <TARGET> && uv run ruff format --check <TARGET>
```

```gate:verifier:sift mode=blocking rollback=implementer scope=project tool=builtin:sift-verdict
```

`builtin:sift-verdict` reads the verifier's report (`--verifier-report`). It passes when the report has no Critical or High finding and the verdict is not NO-GO. The body is empty because the check reads the report, not a command.

```gate:verifier:debt-ratchet mode=blocking rollback=implementer scope=project tool=builtin:debt-ratchet
```

`builtin:debt-ratchet` runs only in brownfield mode and only when `.python-dev/debt-baseline.json` exists. The ratchet rules are in Debt ratchet.

```gate:verifier:interrogate mode=report-only rollback=none scope=changed tool=interrogate
uv run interrogate -v --fail-under 100 <TARGET>
```

```gate:verifier:pydoclint mode=report-only rollback=none scope=changed tool=pydoclint
uv run pydoclint --style google <TARGET>
```

## Lite

```gate:lite:ruff-lite mode=blocking rollback=none scope=changed tool=ruff
uvx ruff check <TOUCHED>
```

```gate:lite:compile-lite mode=blocking rollback=none scope=changed tool=none
python3 -m py_compile <TOUCHED>
```

## Report-only checks

These results are written to `FINDINGS` and never trigger a rollback: `implementer:cc`, `verifier:interrogate`, `verifier:pydoclint`, and any `survey` output from the verifier. Their results do not change the gate's pass or fail state.

## Rollback

1. On a blocking failure, the orchestrator re-dispatches the phase named in `rollback=` with the failure (check name, command, measured value) as the new `TASK`.
2. After the re-dispatch, the orchestrator runs the scope check, then re-runs the gate.
3. Cap: at most 2 rollbacks per gate. After the second, the orchestrator stops dispatching, shows the failing check and measured values, and asks the user.
4. A rollback to the implementer re-runs every later phase in the route, because the route is linear.
5. If the rollback target is not in the route (for example, Fix: cleaner → verifier, with no implementer), the orchestrator does not add a phase. It stops and asks the user.
6. A report-only result is recorded in `FINDINGS` and never triggers a rollback.
7. A trigger stop and an `escalate` result do not count against the cap.

## Escalation triggers

The orchestrator compares the working tree to the pre-dispatch baseline after every stage, before the stage's gate runs. Any one trigger stops the run and shows the user the diff stat and the trigger that fired. These triggers are evaluated by `scripts/scope_check.py compare`.

1. A changed file lies outside `PATHS`.
2. A test or feature file was deleted, or an added line introduces a skip or suppression token. The tokens are `pytest.mark.skip`, `pytest.skip(`, `xfail`, `unittest.skip`, `@skip`, `@wip`, `# type: ignore`, `# noqa`, `# pragma: no cover`, and `# pyright: ignore`. This trigger applies in every phase, including the cleaner.
3. A protected path changed and is not listed in `PATHS`. Protected paths are `pyproject.toml`, `uv.lock`, `tach.toml`, `.importlinter`, `setup.cfg`, `alembic/versions/`, `migrations/`, and any auth or session path.
4. The count of changed files exceeds max(5, 2 × files in `PATHS`).
5. The hardener stage changes any path outside `tests/`, `features/`, or `.python-dev/mutants-justified.txt`.

Trigger 2 counts only the added lines of the diff, so a skip token that already existed before dispatch does not fire. A match in a file that was already dirty before dispatch is shown to the user as a probable pre-existing edit and does not stop the run. A match in a file that the stage newly created fires the trigger.

The cleaner gate's `crap-escalate` result is handled the same way. It does not count against the rollback cap.

## Baseline

Before the first dispatch, `scripts/scope_check.py snapshot` records `git rev-parse HEAD` and a content hash of every modified, deleted, untracked, or staged file. A status listing alone would miss a further edit to a file that was already modified. Excluded directories are `.venv/`, `.pytest_cache/`, `.mypy_cache/`, `.ruff_cache/`, `mutants/`, `htmlcov/`, `.python-dev/`, and the coverage files `.coverage` and `coverage.lcov`.

A path that was dirty at baseline and is clean now has been reverted by the stage. It counts as changed, because the stage altered a pre-existing edit.

## Missing tools

When a check's `tool=` executable is not installed, `gate.py` records `not run: <tool> unavailable`. A blocking check with a `not run` entry does not pass. Its result is `GATE: fail (not run)`. A report-only check with `not run` is listed in the findings and does not fail the gate. A builtin check whose inputs are unusable records `not run: <reason>` the same way, for example `not run: mutmut harness`. That result does not trigger a rollback, because re-dispatching a phase cannot install a tool. A route with a blocking `not run` check is not done, and the orchestrator never reports it as GO. The final summary lists every check that did not run.

`tasks/gate-tools.md` installs the project-level tools with `uv add --dev` before the baseline, using exact versions from `references/gate-tools.toml`. Binaries that are not on PyPI are checked, not installed. `gitleaks` is one such binary.

## Not-applicable rules

A check that does not apply to the project is recorded as `not applicable: <reason>`. It is neither a pass nor a failure and never blocks. A gate whose every check is not applicable reports `GATE: pass`.

| Check | Not applicable when |
|---|---|
| `verifier:tach` | No `tach.toml` at the project root |
| `verifier:imports` | No `[tool.importlinter]` table in `pyproject.toml` and no `.importlinter` file |
| `specifier:stride`, `specifier:gherkin` | No `features/` directory |
| `verifier:debt-ratchet` | Greenfield project, or no `.python-dev/debt-baseline.json` |
| `hardener:mutation` | No changed module with a test file, in brownfield scope |
| any `scope=changed` check | Brownfield scope with an empty changed-file list |

In Lite Mode, the `lite` gate replaces every other gate. Nothing is installed into the project.

## Greenfield and brownfield scope

- **Greenfield** (project scaffolded in this run): every check runs with `<TARGET>` set to `<pkg_dir>` or `<pkg>.*`.
- **Brownfield** (existing project): gates use the project's own configuration. `scope=changed` checks run only on files changed since the baseline. `scope=project` checks run project-wide: tests, boundary, eager-import, audit, gitleaks, and debt-ratchet.

`gate.py --scope brownfield --baseline <file>` derives the changed-file list from `scope_check.py`'s baseline.

## Debt ratchet

Brownfield only. On the first brownfield run without `.python-dev/debt-baseline.json`, the verifier runs a read-only `survey` that writes `.python-dev/debt-baseline.json` and `.python-dev/debt-report.md`. When a baseline already exists, the survey writes `.python-dev/debt-current.json` so the ratchet can compare the two. The survey covers complexity, circular dependencies, outdated, vulnerable, and unused dependencies, coverage, undocumented public API, and duplication. The survey procedure is `tasks/debt-survey.md`.

Whole-project debt metrics may not worsen against `debt-baseline.json`. Untouched existing debt never blocks. Each debt item carries a risk of Critical, High, Medium, or Low and a group of Quick Win, Medium-Term, or Long-Term. Metrics use measured units only. Do not add dollar figures.

## Lite Mode

Lite Mode applies to a single file, stdlib only, under about 50 lines. Only `lite:ruff-lite` and `lite:compile-lite` run, on the touched files. No project tool is installed and no `pyproject.toml` is required.

## Tooling and Threshold Specifications

The quality gates enforce the following standards:

- Acceptance scenarios run through pytest-bdd (`uv run pytest`).
- Docstring parity uses `pydoclint --style google`.
- The eager-import check imports the real package name `<pkg>`, not `src`.
- CRAP and CC thresholds are strict: CRAP ≤ 6, CC ≤ 6, with CRAP > 30 as the escalation point.
