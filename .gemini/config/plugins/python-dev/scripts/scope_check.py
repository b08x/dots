#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Baseline snapshot and escalation-trigger comparison for python-dev phases.

`snapshot` records HEAD and a content hash of every modified, deleted, untracked,
or staged path. `compare` diffs the working tree against that snapshot and evaluates
the five escalation triggers in references/quality-gates.md.

Exit codes: 0 no trigger fired, 1 at least one trigger fired, 2 usage or git error.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any

EXCLUDED_PARTS = frozenset(
    {".venv", ".pytest_cache", ".mypy_cache", ".ruff_cache", "mutants", "htmlcov", ".python-dev"}
)
EXCLUDED_NAMES = frozenset({".coverage", "coverage.lcov"})
# The hardener's one permitted write under .python-dev/. It is tracked even though .python-dev/ is excluded.
JUSTIFIED_PATH = ".python-dev/mutants-justified.txt"
MISSING = "<missing>"
DELETED = "deleted"
PROTECTED_EXACT = frozenset({"pyproject.toml", "uv.lock", "tach.toml", ".importlinter", "setup.cfg"})
PROTECTED_PREFIXES = ("alembic/versions/", "migrations/")
AUTH_OR_SESSION = re.compile(r"(^|/)(auth|session)[^/]*(/|\.py$)")
TEST_OR_FEATURE = re.compile(r"(^|/)(tests?|features)/|(^|/)test_[^/]*\.py$|_test\.py$|\.feature$")
SKIP_TOKEN = re.compile(
    r"pytest\.mark\.skip|pytest\.skip\(|\bxfail\b|unittest\.skip|@skip\b|@wip\b"
    r"|#\s*type:\s*ignore|#\s*noqa|#\s*pragma:\s*no cover|#\s*pyright:\s*ignore"
)
TRIGGER_NAMES = {
    1: "file outside PATHS",
    2: "test deleted or skip/suppression added",
    3: "protected path changed outside PATHS",
    4: "changed-file count exceeds max(5, 2 x files in PATHS)",
    5: "hardener changed a path outside tests/, features/, or .python-dev/mutants-justified.txt",
}


class ScopeError(RuntimeError):
    """Raised for git failures and invalid arguments."""


def _git(root: Path, *args: str) -> str:
    """Run git in `root` and return stdout. Raises ScopeError on a non-zero exit."""
    result = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        raise ScopeError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def _excluded(path: str) -> bool:
    """Return True for tool-cache and generated paths that never enter the snapshot."""
    if path == JUSTIFIED_PATH:
        return False
    pure = PurePosixPath(path)
    return pure.name in EXCLUDED_NAMES or any(part in EXCLUDED_PARTS for part in pure.parts)


def _split_z(text: str) -> list[str]:
    """Split NUL-separated git output, dropping the empty trailing item."""
    return [item for item in text.split("\0") if item]


def _hash_path(root: Path, path: str) -> str:
    """Return the SHA-256 of a file, or DELETED when it no longer exists."""
    full = root / path
    if not full.is_file():
        return DELETED
    digest = hashlib.sha256()
    with full.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def current_state(root: Path) -> dict[str, str]:
    """Return {path: hash} for every modified, deleted, untracked, or staged path."""
    paths = set(_split_z(_git(root, "ls-files", "-m", "-o", "-d", "--exclude-standard", "-z")))
    paths |= set(_split_z(_git(root, "diff", "--cached", "--name-only", "-z")))
    # Scaffolded projects ignore .python-dev/, so git does not list the justified file. Add it explicitly.
    if (root / JUSTIFIED_PATH).is_file():
        paths.add(JUSTIFIED_PATH)
    return {p: _hash_path(root, p) for p in sorted(paths) if not _excluded(p)}


def changed_files(base_files: dict[str, str], cur_files: dict[str, str]) -> list[str]:
    """Return every path whose hash differs from, or is absent in, the baseline map."""
    return sorted(
        p for p in set(base_files) | set(cur_files)
        if base_files.get(p, MISSING) != cur_files.get(p, MISSING)
    )


def cmd_snapshot(args: argparse.Namespace) -> int:
    """Write the baseline JSON: HEAD plus the current content-hash map."""
    root = Path(args.root).resolve()
    payload = {"head": _git(root, "rev-parse", "HEAD").strip(), "files": current_state(root)}
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"snapshot: HEAD {payload['head'][:12]}, {len(payload['files'])} dirty path(s) -> {out}")
    return 0


def _normalize(entry: str) -> str:
    """Normalize a PATHS entry: strip ./ and trailing slashes. '' means the whole tree."""
    cleaned = entry.strip()
    while cleaned.startswith("./"):
        cleaned = cleaned[2:]
    cleaned = cleaned.rstrip("/")
    return "" if cleaned in ("", ".") else cleaned


def _covered(path: str, entries: list[str]) -> bool:
    """Return True when `path` lies under one of the normalized PATHS entries."""
    return any(entry == "" or path == entry or path.startswith(entry + "/") for entry in entries)


def _files_in_paths(root: Path, entries: list[str]) -> int:
    """Count files on disk under each PATHS entry (directories count their files)."""
    total = 0
    for entry in entries:
        target = root / entry if entry else root
        if target.is_file():
            total += 1
        elif target.is_dir():
            total += sum(
                1 for p in target.rglob("*") if p.is_file() and not _excluded(p.relative_to(root).as_posix())
            )
    return total


def _is_protected(path: str) -> bool:
    """Return True for dependency, boundary, migration, and auth/session paths."""
    return (
        PurePosixPath(path).name in PROTECTED_EXACT
        or path.startswith(PROTECTED_PREFIXES)
        or bool(AUTH_OR_SESSION.search(path))
    )


def _added_lines(root: Path, path: str, tracked: set[str]) -> list[str]:
    """Return the lines a stage added to `path`, compared with HEAD."""
    full = root / path
    if path not in tracked:
        return full.read_text(encoding="utf-8", errors="replace").splitlines() if full.is_file() else []
    diff = _git(root, "diff", "HEAD", "-U0", "--", path)
    return [line[1:] for line in diff.splitlines() if line.startswith("+") and not line.startswith("+++")]


def _diff_stat(root: Path, changed: list[str], tracked: set[str]) -> str:
    """Return `git diff --stat` for tracked changed paths plus a list of untracked ones."""
    tracked_changed = [p for p in changed if p in tracked]
    untracked = [p for p in changed if p not in tracked and (root / p).is_file()]
    lines: list[str] = []
    if tracked_changed:
        lines.append(_git(root, "diff", "HEAD", "--stat", "--", *tracked_changed).rstrip())
    lines.extend(f"  new (untracked): {p}" for p in untracked)
    return "\n".join(lines) if lines else "  (no content changes to show)"


def cmd_compare(args: argparse.Namespace) -> int:
    """Compare the working tree to the baseline and evaluate triggers 1-5."""
    root = Path(args.root).resolve()
    baseline = json.loads(Path(args.baseline).read_text(encoding="utf-8"))
    base_files: dict[str, str] = baseline["files"]
    cur_files = current_state(root)
    entries = [_normalize(p) for p in args.paths]
    tracked = set(_split_z(_git(root, "ls-files", "-z")))

    changed = changed_files(base_files, cur_files)

    fired: dict[int, list[str]] = {}
    warnings: list[str] = []

    # The hardener's justified-mutants file is its own write, not a PATHS entry. Other phases must still list it.
    outside = [
        p
        for p in changed
        if not _covered(p, entries) and not (args.phase == "hardener" and p == JUSTIFIED_PATH)
    ]
    if outside:
        fired[1] = outside

    trigger2: list[str] = [
        p for p in changed if cur_files.get(p) == DELETED and TEST_OR_FEATURE.search(p)
    ]
    for path in changed:
        if cur_files.get(path) == DELETED:
            continue
        if not any(SKIP_TOKEN.search(line) for line in _added_lines(root, path, tracked)):
            continue
        if base_files.get(path, MISSING) != MISSING:
            warnings.append(f"{path}: suppression token in a file already dirty at baseline (not counted)")
        else:
            trigger2.append(path)
    if trigger2:
        fired[2] = sorted(set(trigger2))

    protected = [p for p in changed if _is_protected(p) and not _covered(p, entries)]
    if protected:
        fired[3] = protected

    allowance = max(5, 2 * _files_in_paths(root, entries))
    if len(changed) > allowance:
        fired[4] = changed

    if args.phase == "hardener":
        outside_tests = [
            p for p in changed if not p.startswith(("tests/", "features/")) and p != JUSTIFIED_PATH
        ]
        if outside_tests:
            fired[5] = outside_tests

    print(f"phase: {args.phase}; changed: {len(changed)}; PATHS: {', '.join(args.paths) or '(none)'}")
    for trigger_id in sorted(fired):
        print(f"TRIGGER {trigger_id}: {TRIGGER_NAMES[trigger_id]}")
        for path in fired[trigger_id]:
            print(f"  - {path}")
    for note in warnings:
        print(f"WARNING: {note}")
    print("diff stat:")
    print(_diff_stat(root, changed, tracked))

    if args.json:
        report: dict[str, Any] = {
            "changed": changed,
            "triggers": [{"id": t, "name": TRIGGER_NAMES[t], "paths": fired[t]} for t in sorted(fired)],
            "warnings": warnings,
        }
        print(json.dumps(report, indent=2))

    return 1 if fired else 0


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser for the snapshot and compare subcommands."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=".", help="git repository root (default: current directory)")
    sub = parser.add_subparsers(dest="command", required=True)

    snap = sub.add_parser("snapshot", help="record HEAD and content hashes")
    snap.add_argument("--out", default=".python-dev/baseline.json", help="baseline JSON path")
    snap.set_defaults(func=cmd_snapshot)

    comp = sub.add_parser("compare", help="evaluate escalation triggers 1-5")
    comp.add_argument("--baseline", required=True, help="baseline JSON written by snapshot")
    comp.add_argument("--paths", nargs="*", default=[], help="PATHS the stage was briefed on")
    comp.add_argument("--phase", required=True, help="phase name, e.g. implementer or hardener")
    comp.add_argument("--json", action="store_true", help="also print a JSON report")
    comp.set_defaults(func=cmd_compare)
    return parser


def main(argv: list[str] | None = None) -> int:
    """Entry point. Returns the process exit code."""
    args = build_parser().parse_args(argv)
    try:
        return int(args.func(args))
    except (ScopeError, OSError, json.JSONDecodeError) as exc:
        print(f"scope_check: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
