# Step 2: Gate Tools, Baseline, Dispatch, and Reconcile

Run this after the plan is accepted. Lite mode skips the gate tools and the baseline.

## 1. Gate tools (Standard, brownfield or after scaffold)

Run `tasks/gate-tools.md`. It installs the pinned tools into the project with `uv add --dev`, using `references/gate-tools.toml`.

## 2. Baseline

```bash
uv run "../scripts/scope_check.py" snapshot --out .python-dev/baseline.json
```

Record `git rev-parse HEAD` from the snapshot's `head` field in the run notes. The gate tool install in step 1 happens before this snapshot, so its edits to `pyproject.toml` and `uv.lock` are part of the baseline.

## 3. Debt survey (brownfield, first run only)

If `.python-dev/debt-baseline.json` does not exist, dispatch `verifier` once with `TASK: survey`. Follow `tasks/debt-survey.md`. Then take a new snapshot, so the survey's output files are not counted as a stage change.

## 4. Dispatch each stage

For each stage in plan order:

1. Write the brief in the template from `agents/pythonista.md`, Step 4. Copy the pinned `CONTRACT` into every parallel peer's brief.
2. Spawn the stage using Antigravity's `invoke_subagent` tool (`TypeName="<stage>"`, `Role="<stage>"`, `Prompt=brief`). If the subagent is unmounted or unavailable in the current session, register it on the fly using `define_subagent(Name="<stage>", Description=..., EnableWriteTools=true, SystemPrompt=...)` using the definitions in `agents/<stage>.md` and then call `invoke_subagent`. All subagents have write and edit file access (`write_file`, `edit_file`, `run_command`, `read_file`, `search_web`).
3. When it returns, parse `CHANGED`, `FINDINGS`, `UNRESOLVED`, and `NEXT`. If the report is prose, reduce it to that shape yourself before it goes into another brief.
4. For parallel peers, open the artifacts and check them against the `CONTRACT` field by field before any downstream brief is written.

## 5. Pause after the specifier

When the route has `specifier` and `implementer`, show the user the feature files and the QA procedure, and wait for approval. Skip the pause when `--no-checkpoint` was given.

## 6. Save the verifier report

When the verifier returns, write its full report text to `.python-dev/verifier-report.md` before the gate runs. The gate reads the verdict and the severity bullets from that file.
