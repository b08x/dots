#!/usr/bin/env python3
"""
tasknotes_sync.py — Sync workstream Next Actions to Obsidian TaskNotes plugin.

Usage:
    python3 tasknotes_sync.py sync   --file Dashboards/foo-Workstream.md --slug foo
    python3 tasknotes_sync.py status --slug foo
    python3 tasknotes_sync.py list   --slug foo

Reads unchecked `- [ ] text` items from the "## Next Actions" section of a
workstream dashboard, creates TaskNotes tasks via the HTTP API, and replaces
the checkbox lines with Obsidian wikilinks to the created task files.

Previously created tasks are tracked in the workstream DB (table: tasknotes)
to prevent duplicates. On re-run, only genuinely new items (not yet tracked)
are sent to the API.
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
VAULT_ROOT    = Path("/home/b08x/Notebook")
API_BASE      = os.environ.get("TASKNOTES_API", "http://localhost:8080/api")
API_KEY       = os.environ.get("TASKNOTES_API_KEY", "")
DB_PATH       = Path.home() / ".claude/skills/workstream/workstream.db"
DASHBOARDS    = VAULT_ROOT / "Dashboards"

# ---------------------------------------------------------------------------
# DB helpers
# ---------------------------------------------------------------------------

def open_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    return conn


def ensure_tasknotes_table(conn: sqlite3.Connection) -> None:
    conn.execute("""
        CREATE TABLE IF NOT EXISTS tasknotes (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            slug        TEXT NOT NULL,
            task_text   TEXT NOT NULL,
            task_id     TEXT,          -- TaskNotes internal ID (from API)
            task_path   TEXT,          -- vault-relative path e.g. Tasks/foo.md
            created_at  TEXT DEFAULT (datetime('now')),
            UNIQUE(slug, task_text)
        )
    """)
    conn.commit()


def get_tracked(conn: sqlite3.Connection, slug: str) -> dict[str, dict]:
    rows = conn.execute(
        "SELECT task_text, task_id, task_path FROM tasknotes WHERE slug = ?",
        (slug,)
    ).fetchall()
    return {r["task_text"]: {"id": r["task_id"], "path": r["task_path"]} for r in rows}


def track_task(conn: sqlite3.Connection, slug: str, text: str,
               task_id: str, task_path: str) -> None:
    conn.execute("""
        INSERT OR REPLACE INTO tasknotes (slug, task_text, task_id, task_path)
        VALUES (?, ?, ?, ?)
    """, (slug, text, task_id, task_path))
    conn.commit()

# ---------------------------------------------------------------------------
# TaskNotes API
# ---------------------------------------------------------------------------

def _headers() -> dict:
    h = {"Content-Type": "application/json", "Accept": "application/json"}
    if API_KEY:
        h["Authorization"] = f"Bearer {API_KEY}"
    return h


def api_request(method: str, path: str, body: dict | None = None) -> dict | None:
    url = f"{API_BASE}{path}"
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, headers=_headers(), method=method)
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"  [API {e.code}] {path}: {e.read().decode()}", file=sys.stderr)
        return None
    except urllib.error.URLError as e:
        print(f"  [API ERROR] {path}: {e.reason}", file=sys.stderr)
        return None


def get_filter_options() -> dict:
    return api_request("GET", "/filter-options") or {}


def create_task(title: str, project: str, priority: str = "normal") -> dict | None:
    body = {
        "title": title,
        "status": "open",
        "priority": priority,
        "projects": [f"[[{project}]]"],
    }
    return api_request("POST", "/tasks", body)


def list_tasks_for_project(project: str) -> list:
    result = api_request("GET", f"/tasks?project={urllib.parse.quote(project)}&limit=100")
    if result is None:
        return []
    return result if isinstance(result, list) else result.get("tasks", [])

# ---------------------------------------------------------------------------
# Workstream file parsing
# ---------------------------------------------------------------------------

def parse_next_actions(md_text: str) -> list[str]:
    """Return list of unchecked action texts from ## Next Actions section."""
    in_section = False
    actions = []
    for line in md_text.splitlines():
        if re.match(r"^##\s+Next Actions", line):
            in_section = True
            continue
        if in_section and re.match(r"^##\s+", line):
            break
        if in_section:
            m = re.match(r"^\s*-\s+\[\s+\]\s+(.+)", line)
            if m:
                actions.append(m.group(1).strip())
    return actions


def replace_action_with_link(md_text: str, action_text: str, task_path: str) -> str:
    """Replace a `- [ ] action_text` line with an Obsidian task wikilink."""
    # task_path like "Tasks/my-task.md" → strip .md for wikilink
    wikilink_target = task_path.removesuffix(".md")
    replacement = f"- [[{wikilink_target}|☑ {action_text}]]"
    # Match the checkbox line (possibly with leading spaces)
    pattern = re.compile(
        r"^(\s*-\s+\[\s+\]\s+)" + re.escape(action_text) + r"\s*$",
        re.MULTILINE
    )
    return pattern.sub(replacement, md_text, count=1)

# ---------------------------------------------------------------------------
# Main commands
# ---------------------------------------------------------------------------

def cmd_sync(args) -> None:
    # Resolve file path
    if args.file:
        md_path = VAULT_ROOT / args.file
    else:
        md_path = DASHBOARDS / f"{args.slug}-Workstream.md"

    if not md_path.exists():
        print(f"[ERROR] File not found: {md_path}", file=sys.stderr)
        sys.exit(1)

    conn = open_db()
    ensure_tasknotes_table(conn)
    tracked = get_tracked(conn, args.slug)

    md_text = md_path.read_text()
    actions = parse_next_actions(md_text)

    if not actions:
        print(f"No unchecked Next Actions found in {md_path.name}")
        return

    # Determine project name: use --project arg or title from frontmatter
    project = args.project or args.slug
    if not args.project:
        m = re.search(r"^title:\s+(.+)", md_text, re.MULTILINE)
        if m:
            project = m.group(1).strip().removesuffix(" — Workstream")

    created = []
    skipped = []
    modified = md_text

    for action in actions:
        if action in tracked:
            skipped.append(action)
            continue

        print(f"  Creating: {action[:70]}")
        result = create_task(action, project=project, priority=args.priority)
        if result is None:
            print(f"    [SKIP] API returned no result", file=sys.stderr)
            continue

        # TaskNotes returns task with 'id' and 'path' (vault-relative)
        task_id   = result.get("id") or result.get("uuid") or ""
        task_path = result.get("path") or result.get("file") or f"TaskNotes/{action[:40]}.md"

        track_task(conn, args.slug, action, task_id, task_path)
        modified = replace_action_with_link(modified, action, task_path)
        created.append((action, task_path))

    # Write back if changed
    if modified != md_text:
        md_path.write_text(modified)
        print(f"\n  Updated {md_path.name} with {len(created)} task link(s)")

    print(f"\n  Summary:")
    print(f"    Created : {len(created)}")
    print(f"    Skipped (already tracked): {len(skipped)}")
    for text, path in created:
        print(f"    + [[{path}]] ← {text[:60]}")


def cmd_status(args) -> None:
    conn = open_db()
    ensure_tasknotes_table(conn)
    rows = conn.execute(
        "SELECT task_text, task_path, created_at FROM tasknotes WHERE slug = ? ORDER BY created_at DESC",
        (args.slug,)
    ).fetchall()
    if not rows:
        print(f"No tasks tracked for slug '{args.slug}'")
        return
    print(f"\nTracked TaskNotes for '{args.slug}' ({len(rows)} total):\n")
    for r in rows:
        print(f"  [{r['created_at'][:10]}] {r['task_text'][:60]}")
        print(f"             → [[{r['task_path']}]]")


def cmd_list(args) -> None:
    import urllib.parse
    project = args.project or args.slug
    tasks = list_tasks_for_project(project)
    if not tasks:
        print(f"No tasks found for project '{project}' (API may be offline)")
        return
    print(f"\nTaskNotes tasks for '{project}' ({len(tasks)}):\n")
    for t in tasks:
        status = t.get("status", "?")
        title  = t.get("title", "?")
        path   = t.get("path", "")
        print(f"  [{status:10s}] {title[:60]}")
        if path:
            print(f"               → [[{path}]]")

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    import urllib.parse  # ensure available

    p = argparse.ArgumentParser(description="Sync workstream Next Actions → TaskNotes")
    sub = p.add_subparsers(dest="cmd", required=True)

    # sync
    s = sub.add_parser("sync", help="Create TaskNotes for unchecked Next Actions")
    s.add_argument("--slug",     required=True, help="Workstream slug (e.g. rubydocops)")
    s.add_argument("--file",     default="",    help="Vault-relative path to .md file")
    s.add_argument("--project",  default="",    help="Override TaskNotes project name")
    s.add_argument("--priority", default="normal", choices=["low","normal","high","urgent"])

    # status
    st = sub.add_parser("status", help="Show tracked tasks for a slug")
    st.add_argument("--slug", required=True)
    st.add_argument("--project", default="")

    # list
    ls = sub.add_parser("list", help="List live TaskNotes tasks for a project")
    ls.add_argument("--slug", required=True)
    ls.add_argument("--project", default="")

    args = p.parse_args()

    if args.cmd == "sync":
        cmd_sync(args)
    elif args.cmd == "status":
        cmd_status(args)
    elif args.cmd == "list":
        cmd_list(args)


if __name__ == "__main__":
    main()
