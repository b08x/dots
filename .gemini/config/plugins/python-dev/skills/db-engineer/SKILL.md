---
name: db-engineer
description: "Use for data pipelines and databases in Python: polars lazy frames for CSV and NDJSON, ijson for streaming JSON, msgspec or orjson for fast serialization, SQLAlchemy 2.0 with async sessions and a unit of work, psycopg 3 COPY for bulk loads, redis-om for Redis models, and pgvector for embeddings. Loaded by the implementer when the brief names db-engineer, polars, SQLAlchemy, Postgres, Redis, ETL, or a repository layer."
---

# DB Engineer: Data Pipelines and Persistence

Keep ORM models private. Expose frozen dataclasses or frozen pydantic models through a repository, and let nothing outside the module touch a session or an ORM class.

## Choosing the tool

| Task | Tool | Why |
|---|---|---|
| Large CSV or NDJSON transforms | `polars` lazy (`scan_csv`, `scan_ndjson`) | Out-of-core streaming in a multi-threaded engine. Call `.collect(engine="streaming")` only at the end. |
| Streaming a huge JSON array | `ijson` | Parses incrementally; no full load. |
| Fast serialization at a boundary | `msgspec` or `orjson` | Typed or fast encoding; pick one per project. |
| Relational access | SQLAlchemy 2.0 (`Mapped`, `mapped_column`, `AsyncSession`) | Explicit session boundaries. |
| Bulk insert | psycopg 3 `COPY` | Binary protocol; far faster than multi-row `INSERT`. |
| Redis models | `redis-om` (`HashModel`, `JsonModel`) | Secondary indexes and search through RediSearch. |
| Vectors | `pgvector` (`pgvector.sqlalchemy.Vector`) | Cosine, L2, and inner-product operators with HNSW or IVFFlat. |

## The repository rule

```python
from __future__ import annotations

from collections.abc import Callable
from contextlib import AbstractAsyncContextManager
from dataclasses import dataclass
from typing import Protocol

__all__ = ["Customer", "CustomerRepository"]


@dataclass(frozen=True, slots=True, kw_only=True)
class Customer:
    """Domain value returned by the repository."""

    customer_id: int
    email: str


class Session(Protocol):
    """The subset of an async session the repository uses."""

    async def commit(self) -> None:
        """Persist pending changes."""


SessionFactory = Callable[[], AbstractAsyncContextManager[Session]]


class CustomerRepository:
    """Owns the session and the ORM model. Callers receive `Customer` values only."""

    def __init__(self, *, session_factory: SessionFactory) -> None:
        self._session_factory = session_factory
```

- The ORM model class stays inside the module (`_models.py`, underscore prefix).
- Public functions return frozen dataclasses or frozen pydantic models.
- `tach` declares the repository module as the interface. Other modules import only that.

Reason: an ORM model can be reached through a registry or a relation manager without an import statement, so static import checks cannot see the leak. The rule keeps the models unreachable.

## Async sessions

- Materialize inside the session: `.scalars().all()`, then return. Lazy loading after the session closes raises `MissingGreenlet`.
- One unit of work per request or job. Commit or roll back in one place.
- Do not share a session across tasks.

## Streaming ETL

1. Scan the source lazily (`scan_csv` or `scan_ndjson`).
2. Validate the schema once at the boundary, with a pydantic model or a polars schema.
3. Transform in the lazy plan. Do not iterate rows in Python.
4. Write with `COPY` for bulk loads, or collect to a frame for small outputs.

## Testing

- Use an ephemeral database for integration tests. Each test runs in a transaction that rolls back.
- Repository tests assert the returned domain value, not the ORM row.
- Migrations are tested by applying them to an empty database and checking the head revision.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `MissingGreenlet` | Lazy load after session close | Materialize in the repository |
| Slow ingest | Row-by-row `INSERT` | Use `COPY` |
| Memory spike on a CSV | `read_csv` on the whole file | `scan_csv` and a lazy plan |
| Vector query ignores the index | Wrong operator for the index | Match `vector_cosine_ops` to `cosine_distance` |

## Related

- `genai` for producing embeddings.
- `scaffold` for the project layout.
- Verify each library signature with Context7 at point of use.
