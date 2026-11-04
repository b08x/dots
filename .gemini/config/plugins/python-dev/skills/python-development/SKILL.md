---
name: python-development
description: Deterministic Python development workflow for Antigravity. Survey and plan, dispatch to the five phase subagents via invoke_subagent, reconcile, then gate and synthesize. Use for any Python task that spans more than one concern.
---

# Python Development Workflow

This workflow runs the `pythonista` orchestrator's procedure. It dispatches to five phase subagents (`specifier`, `implementer`, `cleaner`, `hardener`, `verifier`) using Antigravity's native `invoke_subagent` (with `define_subagent(EnableWriteTools=true)` fallback). Subagents receive explicit write and edit file access (`write_file`, `edit_file`, `run_command`, `read_file`, `search_web`). Behave exactly as `../../agents/pythonista.md` describes. Its CRITICAL_CONSTRAINTS apply here.

## User input

Parse any arguments or flags passed by the user. `--path` sets the repository root (default: the current directory). `--no-checkpoint` skips the pause after the specifier. `--brief-threshold 8` raises the CRAP threshold when explicitly requested.

## Steps

1. **Verify dispatch capabilities.** Verify `invoke_subagent` is available. If a subagent is unmounted, register it using `define_subagent` with `EnableWriteTools=true`.
2. **Survey and plan.** Follow `../../tasks/step-1-survey-plan.md`. It classifies the work as Lite or Standard, decides greenfield or brownfield, and emits the dispatch plan.
3. **Dispatch and reconcile.** Follow `../../tasks/step-2-dispatch-reconcile.md`. It installs the gate tools, takes the baseline, runs the debt survey when needed, and dispatches each stage with a compact brief and full write file access.
4. **Gate and synthesize.** Follow `../../tasks/step-3-gate-synthesize.md`. It runs the scope check and the gate after each stage, handles rollback with the two-attempt cap, and writes the final report.

## Rules that stay in force

- Never write or edit a `.py` file in this orchestrator thread.
- Never read a role or domain SKILL.md in this orchestrator thread.
- Run `uv run "../../scripts/scope_check.py"` and `uv run "../../scripts/gate.py"` for every check. Do not reimplement them.
- Exit 4 from a gate means escalate. Stop and ask the user.
- Report the verifier verdict verbatim, including when it fails.
