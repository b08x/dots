# Step 1: Survey and Plan

Read only what routing needs: the user's request, the target path, and enough of the tree to name the affected paths. Do not read the codebase broadly. That work belongs to the subagents.

## 1. Classify

- **Lite**: one file, under about 50 lines, standard library only, no project structure. Route: `implementer` only. Gate: `gate.py lite --touched <file>`.
- **Standard**: anything else.

## 2. Decide the scope

- **Greenfield**: no `pyproject.toml` at the target. The first stage is `implementer` with `SKILLS: scaffold`. Gate tools and the baseline come after the scaffold.
- **Brownfield**: a `pyproject.toml` exists. Gate tools, baseline, and the debt survey come before the first stage.

## 3. Decide the cross-cutting concerns (Standard only)

Choose each, once, for the whole route:

- **Logging**: stdlib `logging`, or `structlog` if the project already uses it.
- **Error-handling posture**: `returns` `Result` for branching pipelines, or raise and catch at the boundary.
- **Config**: `pydantic-settings`, read at call time.

Name sibling projects in `PRIOR-ART` when the task sits inside a workspace.

## 4. Choose the route

| Request | Route |
|---|---|
| Build | specifier → implementer → cleaner → hardener → verifier |
| RAG or retrieval system | specifier → implementer per layer (contracts pinned) → reconcile → implementer → cleaner → hardener → verifier |
| Fix with a known cause | cleaner → verifier |
| Fix with an unknown cause | cleaner (diagnose first) → verifier |
| Speed up | cleaner (profile first) → verifier |
| Harden only | hardener → verifier |
| Review only | verifier |
| Document only | implementer |

## 5. Emit the dispatch plan

Print the plan in the format in `agents/pythonista.md`, Step 2. For Standard mode, `CROSS-CUTTING`, `CONTRACTS`, and `VERIFY` are required.

If the plan is materially larger than the request, stop and confirm with the user before any dispatch.
