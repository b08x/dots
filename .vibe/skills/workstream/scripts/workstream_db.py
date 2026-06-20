#!/usr/bin/env python3
"""
workstream_db.py
----------------
SQLite WAL + sqlite-vec context store for workstream skill.

All gathered context (commits, sessions, SFL analysis, embeddings) is written
here instead of being streamed through the LLM context window. The skill
reads back only the rows it needs via targeted queries.

DB path:  ~/.claude/skills/workstream/workstream.db
WAL mode: always enabled on open
Vec ext:  sqlite-vec loaded if available (pip install sqlite-vec)
          graceful fallback to keyword-only search if unavailable

Usage:
    python3 workstream_db.py init
    python3 workstream_db.py status
    python3 workstream_db.py query --slug hermes --table sessions --limit 10
    python3 workstream_db.py query --slug all --table chunks --sfl ideational
    python3 workstream_db.py search --query "gem verification" --limit 5
    python3 workstream_db.py prune --days 30
    python3 workstream_db.py export --slug hermes --format markdown
"""

import argparse
import json
import sqlite3
import struct
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
DB_DIR  = Path.home() / ".claude" / "skills" / "workstream"
DB_PATH = DB_DIR / "workstream.db"

# ---------------------------------------------------------------------------
# sqlite-vec loader (graceful fallback)
# ---------------------------------------------------------------------------
VEC_AVAILABLE = False

def _load_vec_extension(conn: sqlite3.Connection) -> bool:
    """Attempt to load sqlite-vec. Return True if loaded."""
    global VEC_AVAILABLE
    try:
        import sqlite_vec
        conn.enable_load_extension(True)
        sqlite_vec.load(conn)
        conn.enable_load_extension(False)
        VEC_AVAILABLE = True
        return True
    except (ImportError, sqlite3.OperationalError):
        return False


def _serialize_f32(vec: list[float]) -> bytes:
    """Pack a Python list of floats into a 32-bit float BLOB."""
    return struct.pack(f"{len(vec)}f", *vec)


# ---------------------------------------------------------------------------
# Connection factory
# ---------------------------------------------------------------------------
def open_db(path: Path = DB_PATH) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row

    # WAL mode — better concurrency, no blocking reads during writes
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")   # safe with WAL
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA temp_store=MEMORY")

    _load_vec_extension(conn)
    return conn


# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------
SCHEMA = """
-- Workstream registry
CREATE TABLE IF NOT EXISTS workstreams (
    slug        TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    repo_path   TEXT,
    description TEXT,
    tags        TEXT,                  -- JSON array
    last_gather TEXT                   -- ISO timestamp of last data pull
);

-- Raw commit rows per workstream
CREATE TABLE IF NOT EXISTS commits (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    slug        TEXT NOT NULL REFERENCES workstreams(slug),
    hash        TEXT NOT NULL,
    commit_date TEXT NOT NULL,         -- YYYY-MM-DD
    message     TEXT NOT NULL,
    gathered_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(slug, hash)
);

-- Raw session rows from Hermes / code-insights
CREATE TABLE IF NOT EXISTS sessions (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    slug           TEXT NOT NULL REFERENCES workstreams(slug),
    session_id     TEXT,
    title          TEXT,
    platform       TEXT,              -- 'hermes' | 'code-insights'
    started_at     TEXT,
    ended_at       TEXT,
    message_count  INTEGER DEFAULT 0,
    tool_count     INTEGER DEFAULT 0,
    summary        TEXT,
    gathered_at    TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(slug, session_id)
);

-- DSPy-processed chunks (relevance + SFL + task classification)
CREATE TABLE IF NOT EXISTS chunks (
    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
    slug                    TEXT NOT NULL REFERENCES workstreams(slug),
    chunk_index             INTEGER NOT NULL,
    session_count           INTEGER NOT NULL,
    date_from               TEXT,
    date_to                 TEXT,
    combined_text           TEXT NOT NULL,
    relevance_score         REAL DEFAULT 0.0,
    relevance_reason        TEXT,
    task_type               TEXT,
    ideational              TEXT,
    interpersonal           TEXT,
    textual                 TEXT,
    dominant_metafunction   TEXT,
    metafunction_interaction TEXT,
    sfl_tags                TEXT,     -- JSON array
    query_used              TEXT,
    gathered_at             TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Canvas generation log
CREATE TABLE IF NOT EXISTS canvases (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    filename    TEXT NOT NULL UNIQUE,
    intent      TEXT NOT NULL,
    archetype   TEXT NOT NULL,        -- DEEP_DIVE | CROSS_WORKSTREAM | TIMELINE | CONCEPT_MAP
    node_count  INTEGER,
    edge_count  INTEGER,
    slugs_used  TEXT,                 -- JSON array of workstream slugs
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Key-value context store (repo metadata, audit cache, etc.)
CREATE TABLE IF NOT EXISTS kv_store (
    key         TEXT PRIMARY KEY,
    value       TEXT NOT NULL,        -- JSON or plain string
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
"""

SCHEMA_VEC = """
-- Vector embeddings for chunks (sqlite-vec virtual table)
-- Dimension matches Ollama nomic-embed-text (768) or OpenAI ada-002 (1536)
-- Created only if sqlite-vec is available
CREATE VIRTUAL TABLE IF NOT EXISTS chunk_embeddings USING vec0(
    chunk_id   INTEGER PRIMARY KEY,
    embedding  float[768]
);
"""


def init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(SCHEMA)
    if VEC_AVAILABLE:
        try:
            conn.executescript(SCHEMA_VEC)
        except sqlite3.OperationalError as e:
            # May fail if dimension mismatch on existing table — non-fatal
            print(f"[workstream_db] vec0 table skipped: {e}", file=sys.stderr)
    conn.commit()


# ---------------------------------------------------------------------------
# Write helpers
# ---------------------------------------------------------------------------

def upsert_workstream(conn, slug: str, name: str = "", repo_path: str = "",
                      description: str = "", tags: list = None) -> None:
    conn.execute("""
        INSERT INTO workstreams (slug, name, repo_path, description, tags, last_gather)
        VALUES (?, ?, ?, ?, ?, datetime('now'))
        ON CONFLICT(slug) DO UPDATE SET
            name        = excluded.name,
            repo_path   = excluded.repo_path,
            description = excluded.description,
            tags        = excluded.tags,
            last_gather = datetime('now')
    """, (slug, name or slug, repo_path, description, json.dumps(tags or [])))
    conn.commit()


def write_commits(conn, slug: str, commits: list[dict]) -> int:
    """Insert commits, skip duplicates. Return count inserted."""
    inserted = 0
    for c in commits:
        try:
            conn.execute("""
                INSERT OR IGNORE INTO commits (slug, hash, commit_date, message)
                VALUES (?, ?, ?, ?)
            """, (slug, c.get("hash",""), c.get("date",""), c.get("message","")))
            if conn.execute("SELECT changes()").fetchone()[0]:
                inserted += 1
        except sqlite3.IntegrityError:
            pass
    conn.commit()
    return inserted


def write_sessions(conn, slug: str, sessions: list[dict]) -> int:
    """Insert sessions, skip duplicates. Return count inserted."""
    inserted = 0
    for s in sessions:
        sid = s.get("id") or s.get("session_id") or str(s.get("started_at",""))
        try:
            conn.execute("""
                INSERT OR IGNORE INTO sessions
                  (slug, session_id, title, platform, started_at, ended_at,
                   message_count, tool_count, summary)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                slug, sid,
                s.get("title",""),
                s.get("_source") or s.get("platform",""),
                s.get("started_at",""),
                s.get("ended_at",""),
                int(s.get("message_count") or 0),
                int(s.get("tool_call_count") or s.get("tool_count") or 0),
                s.get("summary",""),
            ))
            if conn.execute("SELECT changes()").fetchone()[0]:
                inserted += 1
        except sqlite3.IntegrityError:
            pass
    conn.commit()
    return inserted


def write_chunks(conn, slug: str, chunks: list[dict],
                 embedder=None) -> int:
    """
    Write DSPy-processed chunks. If embedder callable provided,
    generate and store embeddings in chunk_embeddings vec0 table.
    """
    inserted = 0
    for c in chunks:
        sfl  = c.get("sfl", {})
        tags = c.get("sfl_tags", [])
        dr   = c.get("date_range", ("", ""))
        cur = conn.execute("""
            INSERT INTO chunks
              (slug, chunk_index, session_count, date_from, date_to,
               combined_text, relevance_score, relevance_reason,
               task_type, ideational, interpersonal, textual,
               dominant_metafunction, metafunction_interaction,
               sfl_tags, query_used)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (
            slug,
            int(c.get("chunk_index", 0)),
            int(c.get("session_count", 0)),
            dr[0] if isinstance(dr, (list,tuple)) else "",
            dr[1] if isinstance(dr, (list,tuple)) else "",
            c.get("combined_text",""),
            float(c.get("relevance_score", 0.0)),
            c.get("relevance_reason",""),
            c.get("task_type",""),
            sfl.get("ideational",""),
            sfl.get("interpersonal",""),
            sfl.get("textual",""),
            sfl.get("dominant_metafunction",""),
            c.get("metafunction_interaction",""),
            json.dumps(tags),
            c.get("query_used",""),
        ))
        chunk_id = cur.lastrowid
        inserted += 1

        # Optionally embed and store in vec0 table
        if embedder and VEC_AVAILABLE and chunk_id:
            try:
                vec = embedder(c.get("combined_text",""))
                if vec and len(vec) == 768:
                    conn.execute(
                        "INSERT OR REPLACE INTO chunk_embeddings(chunk_id, embedding) VALUES (?, ?)",
                        (chunk_id, _serialize_f32(vec))
                    )
            except Exception as e:
                print(f"[workstream_db] embedding failed for chunk {chunk_id}: {e}",
                      file=sys.stderr)

    conn.commit()
    return inserted


def log_canvas(conn, filename: str, intent: str, archetype: str,
               node_count: int, edge_count: int, slugs: list[str]) -> None:
    conn.execute("""
        INSERT OR REPLACE INTO canvases
          (filename, intent, archetype, node_count, edge_count, slugs_used)
        VALUES (?,?,?,?,?,?)
    """, (filename, intent, archetype, node_count, edge_count, json.dumps(slugs)))
    conn.commit()


def set_kv(conn, key: str, value) -> None:
    conn.execute("""
        INSERT INTO kv_store (key, value, updated_at)
        VALUES (?, ?, datetime('now'))
        ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=datetime('now')
    """, (key, json.dumps(value) if not isinstance(value, str) else value))
    conn.commit()


def get_kv(conn, key: str, default=None):
    row = conn.execute("SELECT value FROM kv_store WHERE key=?", (key,)).fetchone()
    if not row:
        return default
    try:
        return json.loads(row["value"])
    except (json.JSONDecodeError, TypeError):
        return row["value"]


# ---------------------------------------------------------------------------
# Read helpers — return small result sets safe for context window
# ---------------------------------------------------------------------------

def recent_commits(conn, slug: str, limit: int = 15) -> list[dict]:
    q = "SELECT hash, commit_date, message FROM commits"
    args = []
    if slug != "all":
        q += " WHERE slug=?"
        args.append(slug)
    q += " ORDER BY commit_date DESC LIMIT ?"
    args.append(limit)
    return [dict(r) for r in conn.execute(q, args).fetchall()]


def recent_sessions(conn, slug: str, limit: int = 20,
                    platform: str = None) -> list[dict]:
    q = "SELECT slug, title, platform, started_at, message_count, tool_count FROM sessions"
    args = []
    conds = []
    if slug != "all":
        conds.append("slug=?"); args.append(slug)
    if platform:
        conds.append("platform=?"); args.append(platform)
    if conds:
        q += " WHERE " + " AND ".join(conds)
    q += " ORDER BY started_at DESC LIMIT ?"
    args.append(limit)
    return [dict(r) for r in conn.execute(q, args).fetchall()]


def top_chunks(conn, slug: str, limit: int = 5,
               min_relevance: float = 0.0,
               metafunction: str = None,
               task_type: str = None) -> list[dict]:
    conds = ["relevance_score >= ?"]
    args  = [min_relevance]
    if slug != "all":
        conds.append("slug=?"); args.append(slug)
    if metafunction:
        conds.append("dominant_metafunction=?"); args.append(metafunction)
    if task_type:
        conds.append("task_type=?"); args.append(task_type)
    q = f"""
        SELECT slug, chunk_index, date_from, date_to, session_count,
               relevance_score, task_type, dominant_metafunction,
               metafunction_interaction, sfl_tags, ideational, interpersonal
        FROM chunks
        WHERE {' AND '.join(conds)}
        ORDER BY relevance_score DESC, gathered_at DESC
        LIMIT ?
    """
    args.append(limit)
    rows = conn.execute(q, args).fetchall()
    result = []
    for r in rows:
        d = dict(r)
        try:
            d["sfl_tags"] = json.loads(d["sfl_tags"] or "[]")
        except Exception:
            pass
        result.append(d)
    return result


def vec_search(conn, query_vec: list[float], limit: int = 5) -> list[dict]:
    """KNN search via sqlite-vec. Returns chunk rows sorted by distance."""
    if not VEC_AVAILABLE:
        return []
    blob = _serialize_f32(query_vec)
    rows = conn.execute("""
        SELECT ce.chunk_id, ce.distance,
               c.slug, c.task_type, c.dominant_metafunction,
               c.metafunction_interaction, c.date_from, c.date_to,
               c.relevance_score
        FROM chunk_embeddings ce
        JOIN chunks c ON c.id = ce.chunk_id
        WHERE ce.embedding MATCH ?
        ORDER BY ce.distance
        LIMIT ?
    """, (blob, limit)).fetchall()
    return [dict(r) for r in rows]


def fts_search(conn, query: str, limit: int = 10) -> list[dict]:
    """
    Fallback keyword search over chunks.combined_text + sessions.title.
    Uses LIKE — fast enough for a local personal DB.
    """
    pattern = f"%{query}%"
    chunk_rows = conn.execute("""
        SELECT slug, 'chunk' AS source, combined_text AS text,
               task_type, dominant_metafunction, date_from, date_to
        FROM chunks WHERE combined_text LIKE ?
        ORDER BY relevance_score DESC LIMIT ?
    """, (pattern, limit)).fetchall()

    session_rows = conn.execute("""
        SELECT slug, 'session' AS source, title AS text,
               platform AS task_type, NULL AS dominant_metafunction,
               started_at AS date_from, ended_at AS date_to
        FROM sessions WHERE title LIKE ?
        ORDER BY started_at DESC LIMIT ?
    """, (pattern, limit)).fetchall()

    return [dict(r) for r in chunk_rows] + [dict(r) for r in session_rows]


# ---------------------------------------------------------------------------
# Status / audit
# ---------------------------------------------------------------------------

def status(conn) -> dict:
    stats = {}
    for table in ("workstreams", "commits", "sessions", "chunks", "canvases"):
        try:
            stats[table] = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        except sqlite3.OperationalError:
            stats[table] = 0

    stats["vec_available"] = VEC_AVAILABLE
    stats["db_path"] = str(DB_PATH)

    try:
        stats["wal_mode"] = conn.execute(
            "PRAGMA journal_mode"
        ).fetchone()[0]
    except Exception:
        stats["wal_mode"] = "unknown"

    # Per-slug summary
    rows = conn.execute("""
        SELECT w.slug, w.last_gather,
               COUNT(DISTINCT c.id) AS commit_count,
               COUNT(DISTINCT s.id) AS session_count,
               COUNT(DISTINCT ch.id) AS chunk_count
        FROM workstreams w
        LEFT JOIN commits  c  ON c.slug  = w.slug
        LEFT JOIN sessions s  ON s.slug  = w.slug
        LEFT JOIN chunks   ch ON ch.slug = w.slug
        GROUP BY w.slug
        ORDER BY w.last_gather DESC
    """).fetchall()
    stats["workstreams_detail"] = [dict(r) for r in rows]
    return stats


def prune_old(conn, days: int = 30) -> dict:
    cutoff = (datetime.now() - timedelta(days=days)).isoformat()
    deleted = {}
    for table in ("commits", "sessions", "chunks"):
        cur = conn.execute(
            f"DELETE FROM {table} WHERE gathered_at < ?", (cutoff,)
        )
        deleted[table] = cur.rowcount
    conn.commit()
    conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    return deleted


# ---------------------------------------------------------------------------
# Markdown export (for SKILL.md → context window handoff)
# Returns a COMPACT summary — not the full raw data
# ---------------------------------------------------------------------------

def export_markdown(conn, slug: str) -> str:
    commits  = recent_commits(conn, slug, limit=15)
    sessions = recent_sessions(conn, slug, limit=20)
    chunks   = top_chunks(conn, slug, limit=3, min_relevance=0.5)

    lines = [f"## Workstream context: `{slug}`\n"]

    if commits:
        lines.append("### Recent Commits\n| Hash | Date | Message |\n|---|---|---|")
        for c in commits:
            lines.append(f"| `{c['hash'][:7]}` | {c['commit_date']} | {c['message'][:72]} |")
    else:
        lines.append("_No commits in DB_")

    lines.append("")
    if sessions:
        lines.append("### Sessions\n| Date | Platform | Title | Msgs |\n|---|---|---|---|")
        for s in sessions:
            lines.append(
                f"| {(s.get('started_at') or '')[:10]} | {s.get('platform','')} "
                f"| {(s.get('title') or '')[:60]} | {s.get('message_count',0)} |"
            )
    else:
        lines.append("_No sessions in DB_")

    lines.append("")
    if chunks:
        lines.append("### Top SFL Chunks (relevance ≥ 0.5)\n")
        for ch in chunks:
            tags = ", ".join(ch.get("sfl_tags") or [])
            lines.append(
                f"**{ch['date_from']}–{ch['date_to']} · {ch['task_type']} "
                f"· {ch['dominant_metafunction']}** (score {ch['relevance_score']:.2f})\n"
                f"{ch.get('metafunction_interaction','')}\n"
                f"_tags: {tags}_\n"
            )

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Workstream SQLite WAL context store")
    sub = parser.add_subparsers(dest="cmd")

    sub.add_parser("init", help="Initialise DB schema")

    sub.add_parser("status", help="Show DB stats")

    q = sub.add_parser("query", help="Query stored data")
    q.add_argument("--slug", default="all")
    q.add_argument("--table", choices=["commits","sessions","chunks"], default="sessions")
    q.add_argument("--limit", type=int, default=20)
    q.add_argument("--sfl", help="Filter chunks by dominant_metafunction")
    q.add_argument("--task", help="Filter chunks by task_type")
    q.add_argument("--min-relevance", type=float, default=0.0)

    s = sub.add_parser("search", help="Keyword search across chunks and sessions")
    s.add_argument("--query", required=True)
    s.add_argument("--limit", type=int, default=10)

    p = sub.add_parser("prune", help="Delete rows older than N days")
    p.add_argument("--days", type=int, default=30)

    e = sub.add_parser("export", help="Export compact markdown summary")
    e.add_argument("--slug", default="all")
    e.add_argument("--format", choices=["markdown","json"], default="markdown")

    args = parser.parse_args()

    conn = open_db()
    init_schema(conn)

    if args.cmd == "init":
        print(f"[workstream_db] schema initialised at {DB_PATH}")
        print(f"[workstream_db] WAL mode: {conn.execute('PRAGMA journal_mode').fetchone()[0]}")
        print(f"[workstream_db] sqlite-vec: {'available' if VEC_AVAILABLE else 'not installed (pip install sqlite-vec)'}")

    elif args.cmd == "status":
        st = status(conn)
        print(json.dumps(st, indent=2, default=str))

    elif args.cmd == "query":
        if args.table == "commits":
            rows = recent_commits(conn, args.slug, args.limit)
        elif args.table == "sessions":
            rows = recent_sessions(conn, args.slug, args.limit)
        else:
            rows = top_chunks(conn, args.slug, args.limit,
                              min_relevance=args.min_relevance,
                              metafunction=args.sfl,
                              task_type=args.task)
        print(json.dumps(rows, indent=2, default=str))

    elif args.cmd == "search":
        rows = fts_search(conn, args.query, args.limit)
        print(json.dumps(rows, indent=2, default=str))

    elif args.cmd == "prune":
        deleted = prune_old(conn, args.days)
        print(f"[workstream_db] pruned: {deleted}")

    elif args.cmd == "export":
        if args.format == "json":
            data = {
                "commits":  recent_commits(conn, args.slug),
                "sessions": recent_sessions(conn, args.slug),
                "chunks":   top_chunks(conn, args.slug, min_relevance=0.4),
            }
            print(json.dumps(data, indent=2, default=str))
        else:
            print(export_markdown(conn, args.slug))

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
