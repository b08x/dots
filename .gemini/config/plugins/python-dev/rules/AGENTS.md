# Python Development Rules for Antigravity

These workspace rules apply to all Python development workflows driven by Antigravity CLI (`agy`) and the `python-dev` plugin.

---

## 1. Python Coding Standards

When writing, refactoring, or generating Python code in this workspace:

- **Future Annotations**: Always include `from __future__ import annotations` as the first import in every `.py` file.
- **Package and Module Layout**: Follow standard Python packaging layout strictly. File paths must mirror module and package namespaces exactly (`src/<pkg>/<module>.py`).
- **Explicit Exports**: Always define `__all__` in every public module to declare the published public interface.
- **Type Safety and Error Handling**:
  - For complex logic, domain models, and external boundaries, use `pydantic` models at I/O boundaries and frozen dataclasses for internal representations rather than unstructured dictionaries.
  - Use `returns` (`Result`, `Failure`) or explicit custom exceptions; never use bare `except:` clauses.
  - Lite scripts (under ~50 lines, standalone) may remain standard library only.
- **Method and Function Visibility**:
  - Default all new functions and class members to private (`_name`).
  - Promote members to public only when they are deliberate, stable parts of the published interface.
- **Parameter Forwarding**: Forward undeclared arguments using `*args: P.args, **kwargs: P.kwargs` under `ParamSpec` rather than manually re-declaring parameters.
- **Inline Library Verification**:
  - Verify non-stdlib package APIs at the point of use using Context7 MCP (`query-docs` / `resolve-library-id`) or DeepWiki MCP.
  - If MCP tools are unavailable, gracefully fall back to web search (`search_web`) or local codebase discovery (`search_graph`, inspecting existing tests and implementation).
  - Never assume non-stdlib package API signatures from memory.
- **Codebase Structure Discovery**:
  - In Python projects, query codebase-memory-mcp tools first (`search_graph`, `trace_path`, `get_code_snippet`).
  - Confirm dynamic dispatch (e.g. `getattr`, `importlib`, framework registries) with `grep`.
- **Documentation Comments**:
  - Write Google-style docstrings, validated with `pydoclint --style google` and `ruff`.

---

## 2. Orchestrator Invariants (`pythonista`)

The `pythonista` orchestrator coordinates multi-phase development:

1. **Pre-flight Capability Verification**: Verifies execution environment capabilities before planning. If command execution (`run_command`) is undeclared, halts immediately and alerts the user rather than stalling in survey loops.
2. **Never writes Python**: The orchestrator must NEVER author, edit, or refactor `.py` files directly. All code modifications are routed to phase subagents via `invoke_subagent` (with `define_subagent` fallback with `EnableWriteTools=true`).
3. **Fixed Phase Sequence**: Routes through the 5 phase subagents in order: `specifier` → `implementer` → `cleaner` → `hardener` → `verifier`, skipping non-applicable phases with an explicit rationale.
4. **Plan Before Spawning**: Emit the structured dispatch plan (`ROUTE`, `MODE`, `SCOPE`, `CROSS-CUTTING`, `CONTRACTS`, `STAGES`, `GATE`, `VERIFY`) before spawning any subagent.
5. **Pinned Parallel Contracts**: Parallel stages must share a pinned type contract written field-by-field in `CONTRACTS` before dispatch.
6. **Verify, Don't Relay**: Before summarizing or accepting claims (e.g., "all tests pass"), run the verification command (`VERIFY`, e.g. `uv run pytest`) in the orchestrator context.
7. **Capped Rollbacks**: Capped at at most 2 rollbacks per quality gate before stopping and asking the user.

---

## 3. Quality Gate Thresholds & Deterministic Checks

| Phase | Gate Name | Deterministic Command / Check | Blocking Threshold | Rollback Target |
|---|---|---|---|---|
| `specifier` | STRIDE | `uv run pytest --collect-only` | 1 misuse scenario per trust boundary crossing; pytest-bdd parses cleanly | `specifier` |
| `implementer` | suite + gitleaks | `uv run pytest` && `gitleaks detect` | Test runner passes (0 failures); gitleaks clean; CC <= 6 (report-only) | `implementer` |
| `cleaner` | CRAP + CC | `uv run pytest` + `ruff check --select C90` | CRAP <= 6 (or <= 8 if specified); CC <= 6 per function | `cleaner` |
| `hardener` | mutation + audit | `uv run mutmut run` && `uv run pip-audit` && `uv run bandit` | Mutant score >= 80% or 0 unexplained surviving mutants; 0 high/crit vulnerabilities; 0 high/crit bandit issues | `implementer` (for mutant test gaps) |
| `verifier` | boundaries + eager import + SIFT | tach / import-linter && eager import && `uv run pytest` && `ruff check` && SIFT | 0 boundary errors; eager import clean; pytest passes; ruff clean; SIFT verdict GO (0 Critical/High findings) | Target named by failing check row |

### Escalation Triggers (Working Tree Scope Checks)

After every phase, compare the working tree against the pre-dispatch baseline:

1. **Trigger 1 (Out-of-Scope Files)**: Files modified outside the explicit `PATHS` declared in the brief.
2. **Trigger 2 (File Deletions)**: Unexpected deletion of existing source or test files.
3. **Trigger 3 (Dependency Mutation)**: Modification of `pyproject.toml` or `uv.lock` not declared in `PATHS`.
4. **Trigger 4 (Untracked Mod)**: Pre-existing tracked files touched when only new files were expected.

When an escalation trigger fires, halt execution and present the diff stat to the user.

---

## 4. Subagent Operational Constraints & Tool Permissions

Each subagent runs in an isolated context and must return a compact report:

```text
CHANGED: <file paths modified/created, or "none">
FINDINGS: <2-5 bullet points of concrete facts, gate name, and measured values>
UNRESOLVED: <blockers, missing tools, or "none">
NEXT: <clear instructions for the subsequent phase, or "none">
```

All phase subagents are granted explicit write and edit file access (`write_file`, `edit_file`, `read_file`, `run_command`, `search_web`):

- `specifier`: Writes NO production code and NO unit tests. Creates `features/*.feature`, `features/qa-procedure.md`, and component plan.
- `implementer`: Writes tests and production code until tests pass. Has full file write/edit permissions for project source and tests under `PATHS`.
- `cleaner`: Reduces complexity in already-passing code. Follows fixed order: diagnose → change → re-measure. Has full file write/edit permissions for refactoring and adding reproducing tests.
- `hardener`: Adds tests to kill mutants and identifies security vulnerabilities. Writes only under `tests/` and `features/`, plus `.python-dev/mutants-justified.txt`. Changes NO production code.
- `verifier`: Writes NO code (except survey output under `.python-dev/` when running in survey mode). Runs independent verification checks in a fresh context and produces SIFT audit verdict.
