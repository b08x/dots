# Python Patterns (3.12+)

Working conventions for Python code written under this plugin. Each row names the pattern, the library or language feature that implements it, and the constraint the gates enforce. Gate commands live in `quality-gates.md`. This file does not restate them.

## Pattern map

| Pattern | Implementation | Constraint |
|---|---|---|
| Immutability directive | `from __future__ import annotations` (deferred evaluation) and `typing.Final` | Mandated by ruff `I002` with `lint.isort.required-imports = ["from __future__ import annotations"]`. Note: `FA102` fires only when PEP 585/604 generics appear under an older target version, so it cannot enforce this on its own. |
| Immutable typed values, internal | `@dataclass(frozen=True, slots=True, kw_only=True)` | Internal domain value objects. Hashable, small, no runtime validation. |
| Typed values at I/O boundaries | `pydantic.BaseModel` with `model_config = ConfigDict(frozen=True, strict=True, extra="forbid")` | JSON, HTTP, DB, and LLM payloads. Validation runs in pydantic-core (Rust). |
| Cross-field invariants | `@field_validator`, `@model_validator(mode="after")`, `Annotated[T, AfterValidator(fn)]` | Separate structural parsing (strict field types) from domain rules. Raise `ValueError` or `PydanticCustomError` so `ValidationError` reports locations. |
| Railway-oriented errors | `returns.result.Result[Ok, Err]`, `Success`, `Failure`, `@safe`, `flow` and `bind`; `match` on `Success` and `Failure` | Enable `plugins = ["returns.contrib.mypy.returns_plugin"]` under `[tool.mypy]`. Use `match` to consume results exhaustively. |
| Dependency injection | `typing.Protocol` for service boundaries; `dishka` (`Provider`, `Scope.APP`, `Scope.REQUEST`, `make_async_container`) for wiring | Protocols, not base classes. Register providers with explicit scopes so tests can swap adapters (for example Redis-OM versus an in-memory fake). |
| Generics | PEP 695 syntax: `def first[T](xs: Sequence[T]) -> T:`, `type Pair[T] = tuple[T, T]` | Ruff `UP006`, `UP007`, `UP040`, and `UP046` ban `typing.List`, `Dict`, `Optional`, and legacy `TypeVar` declarations. `mypy --strict` and `pyright` enforce complete signatures. |
| Enumerations | `enum.StrEnum` | Closed sets of string values. |
| Public surface | `__all__: list[str]` in every public module and package facade | `mypy --no-implicit-reexport` and tach enforce it. |
| Eager import safety | Standard `src/<pkg>/` layout, snake_case modules, PEP 562 package `__getattr__` only when a lazy surface is required | The verifier's eager-import check (`gate:verifier:eager-import`) walks every submodule and fails on import-time side effects or cycles. |
| Module boundaries | `tach.toml` `[[modules]]` and `[[interfaces]]`, plus import-linter contracts in `pyproject.toml` | A package exposes only its facade. Cross-package imports pass frozen dataclasses, frozen pydantic models, or core-owned `Protocol`s. |
| Private by default | Single-underscore prefix (`_helper`); ruff `SLF001` | Fails the build on external access to private members. |
| Argument forwarding | `ParamSpec`: `def wrap[**P, R](fn: Callable[P, R]) -> Callable[P, R]` | Preserves static types across decorators and wrappers. |
| Banned dynamic imports | ruff `TID251` (`banned-api`) for `importlib.import_module` in project code | Static import graphs must stay complete. The eager-import check uses `importlib` in the gate command only, not in project code. |

## ORM boundary rule

ORM models (SQLAlchemy `Mapped` classes, Django models) stay private inside each module's repository layer. They never cross a tach interface boundary. Reason: an ORM model can be reached at runtime through a registry (`apps.get_model`), a relation manager, or a migration without an import statement. Static import checks cannot see that path. Facades return frozen dataclasses or frozen pydantic models instead.

## Async and I/O

- Replace threads that do I/O with `asyncio` tasks. Use `asyncio.TaskGroup` for structured concurrency.
- Do not call blocking I/O inside `async def`. Wrap it with `asyncio.to_thread`.
- Under `AsyncSession`, materialize query results (`.scalars().all()`) inside the session. Implicit lazy loading raises `MissingGreenlet`.

## Errors

- No bare `except:`. Catch the narrowest exception type. Ruff `BLE001` and `E722` enforce this.
- Re-raise with `raise ... from exc` when translating an exception.
- Use `returns` only where the caller is expected to branch on failure. Otherwise raise.

## Tests

- Tests live in `tests/`. Acceptance scenarios live in `features/` and run through pytest-bdd.
- Test names describe behavior. A test that only asserts that a call happened is a weak test. The hardener's mutation check exists to catch it.
- Never add `pytest.mark.skip`, `xfail`, `# type: ignore`, `# noqa`, or `# pragma: no cover` to silence a gate. Trigger 2 stops the run on each of them.
