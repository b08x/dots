---
name: refactor
description: Use when applying a named refactoring to Python code. Matches a code issue to a known transformation (nested conditionals to guard clauses or match, bare except to narrow exceptions, threads to asyncio, legacy TypeVar to PEP 695, mutable default arguments, dict soup to frozen dataclasses or pydantic models) and applies it as a surgical change. Includes the strangler facade for oversized modules.
---

# Refactor: Named Python Transformations

Each entry names a smell, the transformation, and the check that proves the change is safe. Apply one entry at a time. Re-measure after each one.

## Rules

- Behavior stays the same. The test suite is the proof. Run it after every entry.
- One entry per change. Do not combine two transformations in one edit.
- Stay inside the brief's `PATHS`.
- Do not add a suppression comment to pass a check.

## Entries

### Nested conditionals → guard clauses

**Smell:** more than two levels of nesting, or an `else` after a `return`.
**Transform:** return early on the failing or trivial case; keep the main path flat.
**Check:** the function's cyclomatic complexity drops; the suite passes.

```python
# before
def fee(order: Order) -> Decimal:
    if order.is_valid:
        if order.total > 0:
            return order.total * RATE
        else:
            return Decimal(0)
    else:
        raise InvalidOrderError(order.id)

# after
def fee(order: Order) -> Decimal:
    if not order.is_valid:
        raise InvalidOrderError(order.id)
    if order.total <= 0:
        return Decimal(0)
    return order.total * RATE
```

### Closed set of shapes → `match`

**Smell:** an `isinstance` chain that branches on the shape of one value.
**Transform:** `match` with class patterns on frozen dataclasses or pydantic models; end with an exhaustive case.
**Check:** a type checker reports no missing case.

### Bare `except:` → narrow exceptions

**Smell:** `except:` or `except Exception:` that swallows errors.
**Transform:** catch the specific exception; re-raise with `raise ... from exc` when you translate it.
**Check:** ruff `E722` and `BLE001` pass; a test covers the translated error.

### Threads for I/O → asyncio

**Smell:** `threading.Thread` or a thread pool around network or file I/O in a service.
**Transform:** `async def` with `asyncio.TaskGroup`; wrap any remaining blocking call with `asyncio.to_thread`.
**Check:** no blocking call remains inside `async def`; the suite passes under `pytest-asyncio` or the project's async test runner.

### Legacy `TypeVar` → PEP 695

**Smell:** `T = TypeVar("T")` followed by a generic function, or `typing.List`, `Dict`, `Optional`.
**Transform:** `def first[T](xs: Sequence[T]) -> T:`; `type Pair[T] = tuple[T, T]`; `list[int]`, `dict[str, int]`, `int | None`.
**Check:** ruff `UP006`, `UP007`, `UP040`, `UP046` pass; `mypy --strict` passes.

### Mutable default argument → `None` sentinel

**Smell:** `def f(items: list[str] = [])`.
**Transform:** `def f(items: list[str] | None = None)`, then `items = [] if items is None else items`.
**Check:** a test calls the function twice and shows the default is not shared.

### Dict soup → frozen dataclass or pydantic model

**Smell:** a `dict[str, Any]` passed across two or more functions, with keys read by string.
**Transform:** a frozen `@dataclass(slots=True, kw_only=True)` for internal values; a frozen pydantic `BaseModel` at an I/O boundary.
**Check:** attribute access replaces string keys; `mypy --strict` and `pyright` pass; the suite passes.

### Repeated `if` on a type code → polymorphism or a dispatch table

**Smell:** an `if kind == "a"` chain that repeats across functions.
**Transform:** a `Protocol` with one method, implemented per kind; or a `dict` from kind to callable when the set is open and small.
**Check:** the chain is gone from every call site; each implementation has its own test.

## Strangler facade for oversized modules

Use `references/strangler-facade.md` when a module is too large to rewrite in one step. The facade keeps the old public surface and routes calls to new code one piece at a time.

## Procedure

1. Name the smell from the finding in the brief.
2. Pick the entry above. If none fits, report it as `UNRESOLVED` and stop.
3. Make the change. Run the suite. Re-run the cleaner gate.
4. Repeat for the next smell.
