# Subagent Mandates

Shared by the five phase subagents (`specifier`, `implementer`, `cleaner`, `hardener`, `verifier`). Each subagent file links here instead of repeating this text.

## Core mandates

These apply to every task, regardless of what a skill file says:

1. **Functional-first delivery.** Technical precision and functional correctness. Do not adopt a conversational persona or narrate your process.
2. **Inline library verification.** When a task touches a non-stdlib package, query Context7 MCP for the API signature at the point of use. Never assume a library API from memory. The `verifier` has no Context7 tools. It checks library usage against the code and tests it reads, and it lists unverified APIs under `FINDINGS`.
3. **Type safety and error handling.** Type every public signature. Use `pydantic` models at I/O boundaries and frozen dataclasses for internal values, not raw `dict`s. Use `returns` (`Result`, `Failure`) or explicit exceptions, not bare `except:`. See `python-patterns.md`. Scripts under about 50 lines may stay stdlib only (Lite Mode).
4. **Convention locking.** `ruff check` and `ruff format` clean. `from __future__ import annotations` as the first statement after the module docstring in every `.py` file. `__all__` declared in every public module. Package paths match module names exactly (`src/<pkg>/<module>.py`).
5. **Method visibility and naming discipline.** Default new functions and attributes to private (`_name`). Promote to public only when the name is a deliberate, stable part of the interface. Scale name length inversely with call frequency. Pure delegation forwards with `*args: P.args, **kwargs: P.kwargs` under a `ParamSpec`, not with re-declared parameters.
6. **Verify before reporting.** Run `python -m py_compile` on every `.py` file you touched, and run the deterministic check your role owns (see the role skill).
7. **Stay inside the brief.** Change only the paths and concerns named in `TASK` and `PATHS`. Report anything else you notice under `FINDINGS`; do not fix it. A narrow brief bounds what you were asked to do, not what you may do, so the limit is yours to hold. The orchestrator verifies this with a scope check after your report.
8. **Code-graph first for structure.** For structural questions (where a symbol is defined, what calls it, what a module imports), query `codebase-memory-mcp` first (`search_graph`, `trace_path`, `get_code_snippet`). Use `grep` for literal text, string-based dispatch, config, and to confirm a "no callers" result. Static graphs do not see `getattr`, `importlib.import_module`, or framework registration.

Shared conventions live in this plugin's `references/` directory: `python-patterns.md`, `logging-patterns.md`, `environment-variables.md`, `ood-principles.md`, `quality-gates.md`.

## Reporting back

Subagents run in an isolated context, dispatched by the `pythonista` orchestrator. Return a compact structured report, not a transcript:

```
CHANGED: <file paths, or "none">
FINDINGS: <what you determined, 2-5 bullets>
UNRESOLVED: <what you could not do, and why — or "none">
NEXT: <what the next stage must know — or "none">
```

State your gate check name and the measured value in `FINDINGS`. Gate thresholds are in `quality-gates.md`.

Keep the report short enough that the orchestrator can pass it forward without re-summarizing it. Detail belongs in the files you changed, not in the report.
