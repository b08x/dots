# Strangler Facade for Oversized Modules

Use this when a module is too large or too coupled to rewrite in one change. The facade keeps every existing import working while the internals move, one piece at a time.

## Steps

1. **Freeze the public surface.** List every name the module exports (`__all__`, plus names other modules import). Record it in the brief.
2. **Write characterization tests.** Add tests that pin the current behavior of each exported name. They must pass before you change anything.
3. **Create the new home.** Put the new implementation in a new module, for example `<pkg>/billing/_pricing.py`. Keep it private (underscore prefix) until the migration is done.
4. **Move one function.** Copy the function into the new module, have the old name delegate to it, and run the characterization tests. Then move the next one.
5. **Route the callers.** Once every caller uses the new path, remove the delegating name from the facade's `__all__`.
6. **Retire the facade.** When no caller imports the old module, delete it. Confirm with a code-graph search and a `grep` for the module path.

## Example

```python
# billing.py (facade, kept for existing imports)
from __future__ import annotations

from pkg.billing._pricing import price_order as _price_order

__all__ = ["price_order"]


def price_order(order_id: str) -> int:
    """Return the price in cents for an order. Delegates to the new implementation."""
    return _price_order(order_id)
```

## Checks

- The characterization tests pass before and after every move.
- `tach` boundaries hold: the facade is the only public interface of the package.
- Each step is one commit, so a regression can be reverted without losing the rest.

## Stop conditions

- A caller needs an internal name the facade does not export. Add a test for it, then decide whether it belongs in the public surface. Do not export it silently.
- The move would change a public signature. Stop and route to the user. A signature change is not a refactor.
