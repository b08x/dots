#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = ["tomlkit>=0.13"]
# ///
"""Apply the python-dev gate overlay to a freshly scaffolded project.

Idempotent: running it twice leaves the project as it was after the first run.
Edits pyproject.toml with tomlkit so existing tables are merged, not duplicated.
Pinned gate tools come from references/gate-tools.toml; nothing is installed
outside the project. Use --skip-uv to edit files without running uv.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tomllib
from pathlib import Path
from typing import Any

import tomlkit

PLUGIN_ROOT = Path(__file__).resolve().parents[3]
GATE_TOOLS = PLUGIN_ROOT / "references" / "gate-tools.toml"
RUFF_SELECT = ["E", "F", "W", "I", "N", "UP", "B", "A", "SIM", "TC", "C90", "SLF", "TID", "D"]
BANNED_DYNAMIC_IMPORT = "importlib.import_module"
FUTURE_IMPORT = "from __future__ import annotations"
GITIGNORE_LINES = [".python-dev/", "mutants/", ".coverage", "coverage.lcov", "htmlcov/"]


def _import_name(project: Path) -> str:
    """Return the import name from [project].name in pyproject.toml."""
    data = tomllib.loads((project / "pyproject.toml").read_text(encoding="utf-8"))
    return str(data["project"]["name"]).replace("-", "_").lower()


def _table(doc: Any, *path: str) -> Any:
    """Return the nested table at `path`, creating it when missing."""
    node = doc
    for key in path:
        if key not in node:
            node.add(key, tomlkit.table())
        node = node[key]
    return node


def _ensure_list(container: Any, key: str, values: list[str]) -> None:
    """Make sure every value in `values` is present in the array at `key`."""
    current = list(container.get(key, []))
    for value in values:
        if value not in current:
            current.append(value)
    container[key] = current


def configure_ruff(doc: tomlkit.TOMLDocument) -> None:
    """Enable the complexity, import, private-access, and docstring rules and their limits."""
    lint = _table(doc, "tool", "ruff", "lint")
    _ensure_list(lint, "select", RUFF_SELECT)
    _table(doc, "tool", "ruff", "lint", "mccabe")["max-complexity"] = 6
    _table(doc, "tool", "ruff", "lint", "isort")["required-imports"] = [FUTURE_IMPORT]
    banned = _table(doc, "tool", "ruff", "lint", "flake8-tidy-imports", "banned-api")
    banned[BANNED_DYNAMIC_IMPORT] = {"msg": "Use a static import. Dynamic imports hide edges from tach and import-linter."}
    _table(doc, "tool", "ruff", "lint", "pydocstyle")["convention"] = "google"
    per_file = _table(doc, "tool", "ruff", "lint", "per-file-ignores")
    per_file["tests/**"] = ["D"]


def configure_tools(doc: tomlkit.TOMLDocument, pkg: str) -> None:
    """Configure pydoclint, mutmut, and import-linter."""
    _table(doc, "tool", "pydoclint")["style"] = "google"
    mutmut = _table(doc, "tool", "mutmut")
    mutmut["source_paths"] = [f"src/{pkg}"]
    mutmut["pytest_add_cli_args_test_selection"] = ["tests/"]
    lint = _table(doc, "tool", "importlinter")
    lint["root_package"] = pkg
    contract = tomlkit.aot()
    entry = tomlkit.table()
    entry["name"] = "Library code does not import the entry point"
    entry["type"] = "forbidden"
    entry["source_modules"] = [pkg]
    entry["forbidden_modules"] = [f"{pkg}.__main__"]
    contract.append(entry)
    lint["contracts"] = contract


def write_tach(project: Path, pkg: str) -> None:
    """Write a minimal tach.toml that declares the package as the only module."""
    target = project / "tach.toml"
    if target.exists():
        return
    target.write_text(
        'source_roots = ["src"]\nexclude = ["tests", "features", "docs"]\n\n'
        f'[[modules]]\npath = "{pkg}"\ndepends_on = []\n',
        encoding="utf-8",
    )


def scaffold_dirs(project: Path, pkg: str) -> None:
    """Create features/ and tests/step_defs/, the pytest-bdd binding module, and an import test.

    The import test guarantees pytest collects at least one test, so the suite gate is never a no-tests exit.
    """
    tests = project / "tests"
    tests.mkdir(exist_ok=True)
    import_test = tests / "test_package_imports.py"
    if not any(tests.glob("test_*.py")):
        import_test.write_text(
            '"""The package imports cleanly. A placeholder until the first behavior test exists."""\n\n'
            "from __future__ import annotations\n\n"
            f"import {pkg}\n\n"
            "\n"
            "def test_package_imports() -> None:\n"
            f'    assert {pkg}.__name__ == "{pkg}"\n',
            encoding="utf-8",
        )
    (project / "features").mkdir(exist_ok=True)
    (project / "features" / ".gitkeep").touch()
    step_defs = project / "tests" / "step_defs"
    step_defs.mkdir(parents=True, exist_ok=True)
    (step_defs / "__init__.py").touch()
    features_test = project / "tests" / "test_features.py"
    if not features_test.exists():
        # pytest-bdd raises NoScenariosFound when the directory holds no feature file, so bind
        # scenarios only once a feature exists. The specifier adds the first one.
        features_test.write_text(
            '"""Run the pytest-bdd acceptance scenarios in features/."""\n\n'
            "from __future__ import annotations\n\n"
            "from pathlib import Path\n\n"
            "from pytest_bdd import scenarios\n\n"
            'FEATURES = Path(__file__).resolve().parent.parent / "features"\n\n'
            'if any(FEATURES.glob("*.feature")):\n'
            '    scenarios("../features")\n',
            encoding="utf-8",
        )


def update_gitignore(project: Path) -> None:
    """Append the cache and report paths that scope_check excludes."""
    target = project / ".gitignore"
    existing = target.read_text(encoding="utf-8").splitlines() if target.exists() else []
    missing = [line for line in GITIGNORE_LINES if line not in existing]
    if missing:
        target.write_text("\n".join([*existing, *missing]) + "\n", encoding="utf-8")


def add_gate_tools(project: Path) -> None:
    """Install the pinned dev tools with uv add --dev, from references/gate-tools.toml."""
    pins = tomllib.loads(GATE_TOOLS.read_text(encoding="utf-8"))["dev"]
    specs = [f"{name}=={version}" for name, version in pins.items()]
    subprocess.run(["uv", "add", "--dev", *specs], cwd=project, check=True)


def fix_future_imports(project: Path) -> None:
    """Insert the required __future__ import into existing sources (ruff I002 autofix).

    The scaffold's own files predate the overlay, so the gate would fail on them otherwise.
    """
    subprocess.run(
        ["uv", "run", "ruff", "check", "--select", "I002", "--fix", "--quiet", "src", "tests"],
        cwd=project, check=False,
    )
    # The inserted import needs the blank line that ruff format expects after it.
    subprocess.run(["uv", "run", "ruff", "format", "--quiet", "src", "tests"], cwd=project, check=False)


def lock_and_commit(project: Path) -> None:
    """Refresh the lockfile and create the first commit when the project is not yet a repository."""
    subprocess.run(["uv", "lock"], cwd=project, check=True)
    if not (project / ".git").exists():
        subprocess.run(["git", "init", "-q"], cwd=project, check=True)
    subprocess.run(["git", "add", "-A"], cwd=project, check=True)
    identity = subprocess.run(["git", "config", "user.name"], cwd=project, capture_output=True, text=True, check=False)
    fallback = [] if identity.stdout.strip() else ["-c", "user.name=python-dev", "-c", "user.email=python-dev@localhost"]
    staged = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=project, check=False)
    if staged.returncode != 0:
        subprocess.run(["git", *fallback, "commit", "-q", "-m", "chore: apply python-dev gate overlay"], cwd=project, check=True)


def apply(project: Path, *, skip_uv: bool) -> None:
    """Apply every overlay step to `project`."""
    pkg = _import_name(project)
    pyproject = project / "pyproject.toml"
    doc = tomlkit.parse(pyproject.read_text(encoding="utf-8"))
    configure_ruff(doc)
    configure_tools(doc, pkg)
    pyproject.write_text(tomlkit.dumps(doc), encoding="utf-8")
    write_tach(project, pkg)
    scaffold_dirs(project, pkg)
    update_gitignore(project)
    if not skip_uv:
        add_gate_tools(project)
        fix_future_imports(project)
        lock_and_commit(project)


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", required=True, help="scaffolded project directory")
    parser.add_argument("--skip-uv", action="store_true", help="edit files only; skip uv add, uv lock, git")
    args = parser.parse_args(argv)
    project = Path(args.project).resolve()
    if not (project / "pyproject.toml").is_file():
        print(f"apply_overlay: no pyproject.toml in {project}", file=sys.stderr)
        return 2
    apply(project, skip_uv=args.skip_uv)
    print(f"overlay applied to {project}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
