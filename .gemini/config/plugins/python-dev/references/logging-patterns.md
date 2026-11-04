# Logging Patterns — stdlib logging, structlog optional

Standard for every python-dev skill that emits logs. Use the standard library `logging` module. Use `structlog` only when the project already depends on it or when structured output is a stated requirement.

## Rules

- One module-level logger per module: `log = logging.getLogger(__name__)`. Never configure the root logger in library code.
- Libraries add a `NullHandler` and nothing else. Applications configure handlers once, at the entry point.
- Log with lazy `%` arguments (`log.info("loaded %d rows", n)`), not f-strings. The f-string is built even when the level is disabled.
- Never log secrets. A `SecretStr` renders as `**********`; keep it that way. Do not log request bodies that carry credentials.
- Use `log.exception(...)` inside an `except` block to keep the traceback. Use `log.error` when no traceback exists.

## Library module

```python
from __future__ import annotations

import logging

log = logging.getLogger(__name__)
log.addHandler(logging.NullHandler())


def load(path: str) -> int:
    log.debug("loading %s", path)
    rows = _read(path)
    log.info("loaded %d rows from %s", len(rows), path)
    return len(rows)


def _read(path: str) -> list[str]:
    with open(path, encoding="utf-8") as fh:
        return fh.readlines()
```

## Application entry point

```python
from __future__ import annotations

import logging.config
from typing import Any


def build_config(level: str) -> dict[str, Any]:
    """Return a `logging.config.dictConfig` mapping for the given root level."""
    return {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {"plain": {"format": "%(asctime)s %(levelname)s %(name)s: %(message)s"}},
        "handlers": {"console": {"class": "logging.StreamHandler", "formatter": "plain"}},
        "root": {"level": level, "handlers": ["console"]},
    }


def configure(level: str) -> None:
    logging.config.dictConfig(build_config(level))
```

Trigger 2 stops any run that adds a suppression comment.

## Structured logging (structlog)

Use only when required. Configure once at startup:

```python
import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
)
log = structlog.get_logger(__name__)
log.info("row_loaded", path=path, rows=n)
```

Bind request or job identifiers with `structlog.contextvars.bind_contextvars(request_id=...)`, not by passing a logger around.

## What to log

| Level | Use for |
|---|---|
| DEBUG | Control flow, cache hits, parameter values that carry no secrets |
| INFO | A completed unit of work: "loaded 4 rows", "migration applied" |
| WARNING | Recovered or degraded behavior: a retry succeeded, a fallback was used |
| ERROR | A failed operation the caller will see |
| CRITICAL | The process cannot continue |

## Checklist

- [ ] `log = logging.getLogger(__name__)` at module level
- [ ] No `basicConfig` or root handler in library code
- [ ] `%`-style lazy arguments
- [ ] No secret values in any message
- [ ] No `print` used for diagnostics in library code
