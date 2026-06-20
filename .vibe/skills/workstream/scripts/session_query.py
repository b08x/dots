#!/usr/bin/env python3
"""
workstream session_query.py
---------------------------
Query, chunk, and DSPy-rank session data from code-insights and Hermes SQLite DBs.
Applies SFL metafunction analysis to classify sessions by task character.

Context management: all gathered data is written to workstream_db.py (WAL SQLite)
instead of being streamed to stdout. The skill reads back only compact summaries.

Usage:
    python3 session_query.py --slug hermes --days 14
    python3 session_query.py --slug all --days 7 --sfl
    python3 session_query.py --query "optimization ranking" --days 30
    python3 session_query.py --slug gitagent --metafunction ideational
    python3 session_query.py --slug hermes --read-only  # query DB, no new gather
"""

import argparse
import json
import sqlite3
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

# Import the WAL context store
_SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(_SCRIPT_DIR))
from workstream_db import (
    open_db as open_context_db,
    init_schema,
    upsert_workstream,
    write_sessions,
    write_chunks,
    top_chunks,
    recent_sessions,
    fts_search,
    export_markdown,
)

# ---------------------------------------------------------------------------
# DB paths
# ---------------------------------------------------------------------------
HERMES_DB    = Path.home() / ".hermes" / "state.db"
INSIGHTS_DB  = Path.home() / ".local" / "share" / "code-insights" / "sessions.db"
# code-insights may also live here depending on version:
INSIGHTS_DB2 = Path.home() / ".code-insights" / "sessions.db"

# ---------------------------------------------------------------------------
# SFL metafunction definitions (used as DSPy signature docstrings + prompts)
# ---------------------------------------------------------------------------
SFL_METAFUNCTIONS = {
    "ideational": (
        "Ideational metafunction: what was constructed, explored, or transformed. "
        "Captures experiential content — tools built, bugs fixed, systems designed, "
        "knowledge extracted. Ask: what happened in the world of the task?"
    ),
    "interpersonal": (
        "Interpersonal metafunction: the stance, agency, and interaction pattern of the session. "
        "Who initiated? Was the agent autonomous or directed? Exploratory or convergent? "
        "Adversarial, collaborative, delegated? Ask: what was the social/agentive texture?"
    ),
    "textual": (
        "Textual metafunction: the coherence and flow of the session as discourse. "
        "How did the session arc — did it start broad and narrow, or spiral? "
        "Were there context shifts, rabbit holes, compactions? Ask: how was the session structured as text?"
    ),
}

TASK_TYPES = [
    "scaffold",        # Creating new structure
    "debug",           # Finding/fixing failures
    "explore",         # Investigating/researching
    "refactor",        # Restructuring existing work
    "extract",         # KG/data extraction pipeline
    "optimize",        # Performance/prompt tuning
    "integrate",       # Wiring systems together
    "document",        # Writing docs/specs
    "automate",        # Building repeatable workflows
    "evaluate",        # Benchmarking/comparing
]

# ---------------------------------------------------------------------------
# SQLite helpers
# ---------------------------------------------------------------------------

def open_db(path: Path) -> Optional[sqlite3.Connection]:
    if not path.exists():
        return None
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error:
        return None


def query_hermes(slug: str, days: int) -> list[dict]:
    conn = open_db(HERMES_DB)
    if not conn:
        return []
    since = (datetime.now() - timedelta(days=days)).isoformat()
    rows = []
    for where in [
        f"project_path LIKE '%{slug}%'",
        f"title LIKE '%{slug}%'",
    ]:
        try:
            cur = conn.execute(f"""
                SELECT id, title, message_count, tool_call_count,
                       started_at, ended_at, project_path,
                       summary
                FROM sessions
                WHERE {where}
                  AND started_at >= ?
                ORDER BY started_at DESC
                LIMIT 30
            """, (since,))
            rows = [dict(r) for r in cur.fetchall()]
            if rows:
                break
        except sqlite3.OperationalError:
            pass
    conn.close()
    return rows


def query_insights(slug: str, days: int) -> list[dict]:
    for db_path in [INSIGHTS_DB, INSIGHTS_DB2]:
        conn = open_db(db_path)
        if not conn:
            continue
        since = (datetime.now() - timedelta(days=days)).isoformat()
        # Probe schema
        try:
            tables = {r[0] for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            ).fetchall()}
            # code-insights v1 schema
            if "sessions" in tables:
                cur = conn.execute(f"""
                    SELECT id, project, title, message_count,
                           started_at, ended_at, summary, tool_calls
                    FROM sessions
                    WHERE project LIKE '%{slug}%'
                      AND started_at >= ?
                    ORDER BY started_at DESC
                    LIMIT 30
                """, (since,))
                rows = [dict(r) for r in cur.fetchall()]
                conn.close()
                if rows:
                    return rows
        except sqlite3.OperationalError:
            pass
        conn.close()
    return []


# ---------------------------------------------------------------------------
# Chunking — split sessions into semantic chunks for ranking
# ---------------------------------------------------------------------------

def chunk_sessions(sessions: list[dict], chunk_size: int = 5) -> list[dict]:
    """
    Group sessions into overlapping windows of `chunk_size` by time.
    Each chunk gets a combined text representation for DSPy ranking.
    """
    chunks = []
    for i in range(0, len(sessions), max(1, chunk_size - 1)):
        window = sessions[i : i + chunk_size]
        combined_text = "\n\n".join(
            f"[{s.get('started_at', '?')}] {s.get('title', 'untitled')} "
            f"({s.get('message_count', 0)} msgs, {s.get('tool_call_count', 0)} tools)\n"
            f"{s.get('summary', '')}"
            for s in window
        )
        chunks.append({
            "chunk_index": i // max(1, chunk_size - 1),
            "sessions": window,
            "combined_text": combined_text,
            "session_count": len(window),
            "date_range": (
                window[-1].get("started_at", "?")[:10],
                window[0].get("started_at", "?")[:10],
            ),
        })
    return chunks


# ---------------------------------------------------------------------------
# DSPy pipeline
# ---------------------------------------------------------------------------

def build_dspy_pipeline(lm_model: str = "openai/gpt-4o-mini"):
    """
    Build a DSPy pipeline with three signatures:
      1. SessionRanker     — score session relevance to a query
      2. SFLAnalyser       — apply all three SFL metafunctions
      3. TaskClassifier    — assign task_type + dominant metafunction
    """
    try:
        import dspy
        from typing import Literal
    except ImportError:
        return None

    dspy.configure(lm=dspy.LM(lm_model))

    # --- Signature 1: Relevance ranking ---
    class SessionRelevance(dspy.Signature):
        """
        Score how relevant a block of AI session activity is to a given query or topic.
        Consider technical content, intent, and outcomes described in the sessions.
        """
        session_block: str = dspy.InputField(
            desc="Combined text of one or more AI coding sessions"
        )
        query: str = dspy.InputField(
            desc="Topic, concept, or question to match against"
        )
        relevance_score: float = dspy.OutputField(
            desc="Relevance score 0.0–1.0 (1.0 = highly relevant)"
        )
        relevance_reason: str = dspy.OutputField(
            desc="One sentence explaining the score"
        )

    # --- Signature 2: SFL metafunction analysis ---
    class SFLAnalysis(dspy.Signature):
        """
        Apply Systemic Functional Linguistics metafunction analysis to a block of AI session activity.

        Ideational metafunction: what was constructed, explored, or transformed.
        Captures experiential content — tools built, bugs fixed, systems designed, knowledge extracted.

        Interpersonal metafunction: the stance, agency, and interaction pattern of the session.
        Who initiated? Was the agent autonomous or directed? Exploratory or convergent?

        Textual metafunction: the coherence and flow of the session as discourse.
        How did the session arc — start broad and narrow, or spiral? Context shifts, rabbit holes?
        """
        session_block: str = dspy.InputField(
            desc="Combined text of one or more AI coding sessions including titles, summaries, tool use"
        )
        ideational: str = dspy.OutputField(
            desc="What was built, fixed, extracted, or designed. Key constructs and transformations."
        )
        interpersonal: str = dspy.OutputField(
            desc="Agent stance and interaction texture. Autonomous vs directed, exploratory vs convergent."
        )
        textual: str = dspy.OutputField(
            desc="Session arc and discourse structure. How the session cohered or diverged as a sequence."
        )
        dominant_metafunction: Literal["ideational", "interpersonal", "textual"] = dspy.OutputField(
            desc="Which metafunction most characterizes this session block"
        )

    # --- Signature 3: Task type classification ---
    class TaskClassification(dspy.Signature):
        """
        Classify the primary task type of an AI coding session based on its content and SFL analysis.
        Also identify which SFL metafunctions are most strongly expressed and how they interact.
        """
        session_block: str = dspy.InputField(
            desc="Combined text of one or more AI coding sessions"
        )
        ideational_summary: str = dspy.InputField(
            desc="Ideational metafunction analysis from SFL pass"
        )
        interpersonal_summary: str = dspy.InputField(
            desc="Interpersonal metafunction analysis from SFL pass"
        )
        task_type: Literal[
            "scaffold", "debug", "explore", "refactor", "extract",
            "optimize", "integrate", "document", "automate", "evaluate"
        ] = dspy.OutputField(
            desc="Primary task type of the session block"
        )
        metafunction_interaction: str = dspy.OutputField(
            desc=(
                "How the ideational and interpersonal metafunctions interact in this session. "
                "e.g. 'autonomous agent scaffolding (ideational-led, interpersonal=delegated)' or "
                "'human-directed debugging (interpersonal-led, ideational=repair)'"
            )
        )
        sfl_tags: list[str] = dspy.OutputField(
            desc="Short SFL-grounded tags for this session block, e.g. ['process:material', 'mood:imperative', 'theme:topical']"
        )

    ranker     = dspy.ChainOfThought(SessionRelevance)
    sfl        = dspy.ChainOfThought(SFLAnalysis)
    classifier = dspy.ChainOfThought(TaskClassification)

    return ranker, sfl, classifier


def run_pipeline(
    chunks: list[dict],
    query: str,
    run_sfl: bool = True,
    lm_model: str = "openai/gpt-4o-mini",
) -> list[dict]:
    """
    Run chunks through the DSPy pipeline:
      1. Score relevance to query
      2. (optional) SFL analysis
      3. Task classification
    Return chunks sorted by relevance, each annotated with analysis results.
    """
    pipeline = build_dspy_pipeline(lm_model)
    if pipeline is None:
        print("[session_query] DSPy not available — returning raw chunks", file=sys.stderr)
        return chunks

    ranker, sfl, classifier = pipeline
    results = []

    for chunk in chunks:
        text = chunk["combined_text"]
        result = dict(chunk)

        # --- Step 1: Relevance ---
        try:
            rel = ranker(session_block=text, query=query)
            result["relevance_score"]  = rel.relevance_score
            result["relevance_reason"] = rel.relevance_reason
        except Exception as e:
            result["relevance_score"]  = 0.0
            result["relevance_reason"] = f"error: {e}"

        # --- Step 2: SFL ---
        if run_sfl:
            try:
                sfl_out = sfl(session_block=text)
                result["sfl"] = {
                    "ideational":           sfl_out.ideational,
                    "interpersonal":        sfl_out.interpersonal,
                    "textual":              sfl_out.textual,
                    "dominant_metafunction": sfl_out.dominant_metafunction,
                }
            except Exception as e:
                result["sfl"] = {"error": str(e)}

        # --- Step 3: Task classification ---
        try:
            ideational_in    = result.get("sfl", {}).get("ideational", "")
            interpersonal_in = result.get("sfl", {}).get("interpersonal", "")
            cls = classifier(
                session_block=text,
                ideational_summary=ideational_in,
                interpersonal_summary=interpersonal_in,
            )
            result["task_type"]              = cls.task_type
            result["metafunction_interaction"] = cls.metafunction_interaction
            result["sfl_tags"]               = cls.sfl_tags
        except Exception as e:
            result["task_type"]              = "unknown"
            result["metafunction_interaction"] = f"error: {e}"
            result["sfl_tags"]               = []

        results.append(result)

    # Sort by relevance descending
    results.sort(key=lambda r: r.get("relevance_score", 0.0), reverse=True)
    return results


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

def format_markdown_table(results: list[dict]) -> str:
    lines = [
        "| Date Range | Sessions | Task Type | Dominant Metafunction | Relevance | Interaction |",
        "|---|---|---|---|---|---|",
    ]
    for r in results:
        dr = r.get("date_range", ("?", "?"))
        sc = r.get("session_count", 0)
        tt = r.get("task_type", "?")
        dm = r.get("sfl", {}).get("dominant_metafunction", "?")
        rs = f"{r.get('relevance_score', 0.0):.2f}"
        mi = r.get("metafunction_interaction", "")[:60]
        lines.append(f"| {dr[0]}–{dr[1]} | {sc} | {tt} | {dm} | {rs} | {mi} |")
    return "\n".join(lines)


def format_sfl_detail(results: list[dict]) -> str:
    parts = []
    for i, r in enumerate(results, 1):
        sfl = r.get("sfl", {})
        tags = ", ".join(r.get("sfl_tags", []))
        parts.append(
            f"### Chunk {i} ({r.get('task_type', '?')} · relevance {r.get('relevance_score', 0):.2f})\n"
            f"**Dates:** {r.get('date_range', ('?','?'))[0]} – {r.get('date_range', ('?','?'))[1]}\n\n"
            f"**Ideational:** {sfl.get('ideational', '')}\n\n"
            f"**Interpersonal:** {sfl.get('interpersonal', '')}\n\n"
            f"**Textual:** {sfl.get('textual', '')}\n\n"
            f"**Metafunction interaction:** {r.get('metafunction_interaction', '')}\n\n"
            f"**SFL tags:** `{tags}`\n"
        )
    return "\n---\n".join(parts)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Workstream session DSPy query pipeline")
    parser.add_argument("--slug",       default="all",  help="Project slug or 'all'")
    parser.add_argument("--days",       type=int, default=7, help="Lookback window in days")
    parser.add_argument("--query",      default="",     help="Relevance query/topic")
    parser.add_argument("--sfl",        action="store_true", help="Run SFL metafunction analysis")
    parser.add_argument("--metafunction", choices=list(SFL_METAFUNCTIONS.keys()),
                        help="Filter output to a single metafunction")
    parser.add_argument("--chunk-size", type=int, default=5)
    parser.add_argument("--model",      default="openai/gpt-4o-mini")
    parser.add_argument("--format",     choices=["json", "markdown", "sfl-detail", "db-export"],
                        default="markdown")
    parser.add_argument("--source",     choices=["hermes", "insights", "both"], default="both")
    parser.add_argument("--read-only",  action="store_true",
                        help="Skip gathering; query the WAL DB directly")
    parser.add_argument("--search",     default="",
                        help="Keyword search over stored context (implies --read-only)")
    args = parser.parse_args()

    slug  = args.slug
    query = args.query or slug

    # Open WAL context store
    ctx_db = open_context_db()
    init_schema(ctx_db)

    # ── READ-ONLY / SEARCH paths ────────────────────────────────────────────
    if args.search:
        rows = fts_search(ctx_db, args.search, limit=15)
        if args.format == "json":
            print(json.dumps(rows, indent=2, default=str))
        else:
            for r in rows:
                print(f"[{r.get('source')}] {r.get('slug')} · {r.get('task_type','')} "
                      f"· {(r.get('text') or '')[:80]}")
        return

    if args.read_only:
        if args.format == "db-export":
            print(export_markdown(ctx_db, slug))
        else:
            chunks_out = top_chunks(ctx_db, slug, limit=10,
                                    metafunction=args.metafunction)
            if args.format == "json":
                print(json.dumps(chunks_out, indent=2, default=str))
            else:
                print(export_markdown(ctx_db, slug))
        return

    # ── GATHER path ──────────────────────────────────────────────────────────
    sessions = []
    if args.source in ("hermes", "both"):
        h = query_hermes(slug if slug != "all" else "", args.days)
        for s in h:
            s["_source"] = "hermes"
        sessions.extend(h)
    if args.source in ("insights", "both"):
        i = query_insights(slug if slug != "all" else "", args.days)
        for s in i:
            s["_source"] = "code-insights"
        sessions.extend(i)

    if not sessions:
        print(f"[session_query] No new sessions found for slug='{slug}' in last {args.days} days",
              file=sys.stderr)
        # Still try to return something useful from DB
        if args.format == "db-export":
            print(export_markdown(ctx_db, slug))
        sys.exit(0)

    # Sort and write raw sessions to WAL DB
    sessions.sort(key=lambda s: s.get("started_at", ""), reverse=True)
    upsert_workstream(ctx_db, slug)
    n_sessions = write_sessions(ctx_db, slug, sessions)
    print(f"[session_query] stored {n_sessions} new sessions for '{slug}'", file=sys.stderr)

    # Chunk
    chunks = chunk_sessions(sessions, chunk_size=args.chunk_size)
    for c in chunks:
        c["query_used"] = query

    # Run DSPy pipeline
    results = run_pipeline(
        chunks,
        query=query,
        run_sfl=args.sfl or bool(args.metafunction),
        lm_model=args.model,
    )

    # Write processed chunks to WAL DB (full data stays in DB)
    n_chunks = write_chunks(ctx_db, slug, results)
    print(f"[session_query] stored {n_chunks} chunks for '{slug}'", file=sys.stderr)

    # Filter by metafunction if requested
    if args.metafunction:
        results = [
            r for r in results
            if r.get("sfl", {}).get("dominant_metafunction") == args.metafunction
        ]

    # ── Output: compact summary only — full data lives in DB ─────────────────
    if args.format == "json":
        # Return lightweight summary rows, not full combined_text blobs
        summary = [
            {k: v for k, v in r.items() if k != "combined_text"}
            for r in results
        ]
        print(json.dumps(summary, indent=2, default=str))
    elif args.format == "sfl-detail":
        print(format_sfl_detail(results))
    elif args.format == "db-export":
        # Return the DB's compact markdown export — safe for context window
        print(export_markdown(ctx_db, slug))
    else:
        print(format_markdown_table(results))
        print(f"\n_Query: `{query}` · {len(sessions)} sessions written to DB · "
              f"{len(chunks)} chunks · source: {args.source} · last {args.days} days_\n"
              f"_Full context in: {ctx_db} — use `workstream_db.py export --slug {slug}` to read back_")


if __name__ == "__main__":
    main()
