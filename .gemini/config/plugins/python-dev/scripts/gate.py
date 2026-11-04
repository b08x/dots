#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Run one phase's quality gate. Checks come from fenced `gate:<phase>:<check>` blocks in references/quality-gates.md.

Exit codes: 0 pass, 1 fail, 2 usage or configuration error, 3 fail (not run), 4 escalate.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tomllib
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from scope_check import changed_files, current_state

PHASES = ("specifier", "implementer", "cleaner", "hardener", "verifier", "lite")
MODES = ("blocking", "report-only", "escalate")
ROLLBACKS = ("specifier", "implementer", "none")
SCOPES = ("project", "changed")
REQUIRED_KEYS = ("mode", "rollback", "scope", "tool")
FENCE_OPEN = re.compile(r"^```gate:(?P<phase>[a-z]+):(?P<name>[a-z][a-z0-9-]*)(?P<keys>(?:\s+[a-z]+=\S+)*)\s*$")
FENCE_CLOSE = "```"
DEFAULT_GATES = Path(__file__).resolve().parents[1] / "references" / "quality-gates.md"
DEBT_BASELINE = Path(".python-dev/debt-baseline.json")
DEBT_CURRENT = Path(".python-dev/debt-current.json")
JUSTIFIED_MUTANTS = Path(".python-dev/mutants-justified.txt")
MUTANT_LINE = re.compile(r"^\s*(?P<name>[\w.]+__mutmut_\d+):\s*(?P<state>[a-z][a-z ]*?)\s*$")
MUTANT_OK = frozenset({"killed"})
MUTANT_HARNESS_FAILURE = "timeout"
ESCALATE_EXIT = 1
SUMMARY = re.compile(r"(\d+)/(\d+)\s+🎉 (\d+) 🫥 (\d+)\s+⏰ (\d+)\s+🤔 (\d+)\s+🙁 (\d+)")
VERDICT = re.compile(r"VERDICT: (GO|NO-GO)")
SEVERITY = re.compile(r"^\s*[-*]\s*\[(Critical|High|Medium|Low)\]", re.MULTILINE)
LOWER_IS_BETTER = ("cc_over_limit", "circular_deps", "vulnerable_deps", "outdated_deps",
                   "unused_deps", "undocumented_api", "duplication_pct")
HIGHER_IS_BETTER = ("coverage_pct",)
EXIT = {"pass": 0, "fail": 1, "usage": 2, "not-run": 3, "escalate": 4}


class GateConfigError(ValueError):
    """The gates file is malformed or a check is misconfigured."""


class NotRun(Exception):
    """A builtin check cannot run because an input or tool is missing."""


@dataclass(frozen=True)
class Check:
    """One fenced gate block."""

    phase: str
    name: str
    mode: str
    rollback: str
    scope: str
    tool: str
    body: str

    @property
    def ident(self) -> str:
        """Return the `phase:name` identifier used in output."""
        return f"{self.phase}:{self.name}"


@dataclass(frozen=True)
class Context:
    """Project facts that placeholders and n/a rules depend on."""

    root: Path
    pkg: str
    pkg_dir: str
    scope: str
    crap: int
    changed_py: tuple[str, ...]
    changed_modules: tuple[str, ...]
    touched: tuple[str, ...]


@dataclass(frozen=True)
class Result:
    """Outcome of one check."""

    check: Check
    status: Literal["pass", "fail", "report", "escalate", "not-run", "n/a"]
    detail: str


Runner = Callable[[str, Path], tuple[int, str]]
Probe = Callable[[str, Path], bool]


def load_checks(path: Path) -> list[Check]:
    """Parse every `gate:` block in the gates file. Raises GateConfigError on malformed blocks."""
    checks: list[Check] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    index = 0
    while index < len(lines):
        match = FENCE_OPEN.match(lines[index])
        index += 1
        if not match:
            continue
        body: list[str] = []
        while index < len(lines) and lines[index] != FENCE_CLOSE:
            body.append(lines[index])
            index += 1
        index += 1
        keys = dict(token.split("=", 1) for token in match["keys"].split())
        ident = f"{match['phase']}:{match['name']}"
        missing = [k for k in REQUIRED_KEYS if k not in keys]
        if missing:
            raise GateConfigError(f"{ident}: missing key(s) {', '.join(missing)}")
        check = Check(
            phase=match["phase"], name=match["name"], mode=keys["mode"], rollback=keys["rollback"],
            scope=keys["scope"], tool=keys["tool"], body="\n".join(body).strip(),
        )
        _validate(check)
        checks.append(check)
    return checks


def _validate(check: Check) -> None:
    """Reject values outside the documented vocabulary."""
    if check.phase not in PHASES:
        raise GateConfigError(f"{check.ident}: unknown phase '{check.phase}'")
    if check.mode not in MODES:
        raise GateConfigError(f"{check.ident}: unknown mode '{check.mode}'")
    if check.rollback not in ROLLBACKS:
        raise GateConfigError(f"{check.ident}: unknown rollback '{check.rollback}'")
    if check.scope not in SCOPES:
        raise GateConfigError(f"{check.ident}: unknown scope '{check.scope}'")
    if check.tool.startswith("builtin:") and check.tool not in BUILTINS:
        raise GateConfigError(f"{check.ident}: unknown builtin '{check.tool}'")
    if not check.tool.startswith("builtin:") and check.tool != "none" and not check.body:
        raise GateConfigError(f"{check.ident}: empty body")


def read_pkg(root: Path) -> str:
    """Return the import name from `[project].name` (hyphens become underscores)."""
    pyproject = root / "pyproject.toml"
    if not pyproject.is_file():
        raise GateConfigError("pyproject.toml not found")
    name = tomllib.loads(pyproject.read_text(encoding="utf-8")).get("project", {}).get("name")
    if not name:
        raise GateConfigError("[project].name missing from pyproject.toml")
    return str(name).replace("-", "_").lower()


def mutation_targets(ctx: Context) -> list[str]:
    """Return the mutmut target patterns. changed_modules are already dotted names that include the package."""
    if ctx.scope == "greenfield":
        return [f"{ctx.pkg}.*"]
    return [f"{module}.*" for module in ctx.changed_modules]


def module_of(path: str, pkg: str) -> str | None:
    """Map a changed `.py` path under src/<pkg> or <pkg> to its dotted module name."""
    rel = path[4:] if path.startswith("src/") else path
    if not rel.endswith(".py") or not rel.startswith(f"{pkg}/"):
        return None
    dotted = rel[:-3].replace("/", ".")
    return dotted.removesuffix(".__init__")


def build_context(
    root: Path, *, phase: str, scope: str, baseline: Path | None, crap: int, touched: Sequence[str]
) -> Context:
    """Resolve placeholders and, in brownfield scope, the changed-file list.

    Lite Mode has no project, so a missing pyproject.toml is allowed there only.
    """
    if phase == "lite" and not (root / "pyproject.toml").is_file():
        pkg, pkg_dir = "", ""
    else:
        pkg = read_pkg(root)
        pkg_dir = f"src/{pkg}" if (root / "src" / pkg).is_dir() else pkg
    changed: list[str] = []
    if scope == "brownfield":
        if baseline is None:
            raise GateConfigError("--scope brownfield requires --baseline")
        base = json.loads(baseline.read_text(encoding="utf-8"))["files"]
        changed = changed_files(base, current_state(root))
    changed_py = tuple(p for p in changed if p.endswith(".py") and (root / p).is_file())
    modules = tuple(m for m in (module_of(p, pkg) for p in changed_py) if m)
    return Context(root, pkg, pkg_dir, scope, crap, changed_py, modules, tuple(touched))


def _clean_env() -> dict[str, str]:
    """Return the environment without VIRTUAL_ENV, so uv targets each project's own .venv."""
    return {k: v for k, v in os.environ.items() if k != "VIRTUAL_ENV"}


def _shell(body: str, cwd: Path) -> tuple[int, str]:
    """Run a gate body under bash with pipefail. Returns (exit code, combined output)."""
    proc = subprocess.run(
        ["bash", "-eu", "-o", "pipefail", "-c", body],
        cwd=cwd, capture_output=True, text=True, check=False, env=_clean_env(),
    )
    return proc.returncode, proc.stdout + proc.stderr


def _project_has_tool(tool: str, cwd: Path) -> bool:
    """True when the executable exists inside the project's uv environment."""
    proc = subprocess.run(
        ["uv", "run", "--no-sync", "sh", "-c", 'command -v "$1"', "sh", tool],
        cwd=cwd, capture_output=True, text=True, check=False, env=_clean_env(),
    )
    return proc.returncode == 0


def tool_available(check: Check, cwd: Path, probe: Probe) -> bool:
    """Return False when the check's tool cannot be found."""
    if check.tool == "none" or check.tool.startswith("builtin:"):
        return True
    first = check.body.split()[0] if check.body.split() else ""
    if "uvx " in check.body or first == "uvx":
        return shutil.which("uvx") is not None
    if "uv run" in check.body or first == "uv":
        return probe(check.tool, cwd)
    return shutil.which(check.tool) is not None


def _target(check: Check, ctx: Context) -> str | None:
    """Return the TARGET placeholder value for a changed-scope check, or None when empty."""
    if check.scope != "changed":
        return ctx.pkg_dir
    if ctx.scope == "greenfield":
        return ctx.pkg_dir
    return " ".join(shlex.quote(p) for p in ctx.changed_py) or None


def _substitute(body: str, check: Check, ctx: Context) -> str | None:
    """Fill placeholders. Returns None when the check has no target."""
    target = _target(check, ctx)
    if "<TARGET>" in body and target is None:
        return None
    filled = body.replace("<TARGET>", target or "")
    filled = filled.replace("<TOUCHED>", " ".join(shlex.quote(p) for p in ctx.touched))
    filled = filled.replace("<CRAP>", str(ctx.crap)).replace("<pkg_dir>", ctx.pkg_dir).replace("<pkg>", ctx.pkg)
    return filled


def not_applicable(check: Check, ctx: Context) -> str | None:
    """Return the reason a check does not apply, or None when it applies."""
    root = ctx.root
    if check.ident == "verifier:tach" and not (root / "tach.toml").is_file():
        return "no tach.toml"
    if check.ident == "verifier:imports" and not _has_importlinter(root):
        return "no import-linter configuration"
    if check.phase == "specifier" and not (root / "features").is_dir():
        return "no features/ directory"
    if check.ident == "verifier:debt-ratchet":
        if ctx.scope != "brownfield":
            return "greenfield project"
        if not (root / DEBT_BASELINE).is_file():
            return "no debt-baseline.json"
    if check.scope == "changed" and ctx.scope == "brownfield" and not ctx.changed_py:
        return "no changed Python files"
    if check.ident == "hardener:mutation" and ctx.scope == "brownfield" and not ctx.changed_modules:
        return "no changed module"
    return None


def _has_importlinter(root: Path) -> bool:
    """True when pyproject declares import-linter contracts or a .importlinter file exists."""
    if (root / ".importlinter").is_file():
        return True
    pyproject = root / "pyproject.toml"
    if not pyproject.is_file():
        return False
    return "importlinter" in tomllib.loads(pyproject.read_text(encoding="utf-8")).get("tool", {})


def builtin_sift(ctx: Context, report: Path | None) -> tuple[bool, str]:
    """Pass when the verifier report has a verdict other than NO-GO and no Critical or High finding."""
    if report is None or not report.is_file():
        raise NotRun("verifier report missing (pass --verifier-report)")
    text = report.read_text(encoding="utf-8")
    # Exactly one VERDICT line, and it must be GO or NO-GO. Anything else is no verdict.
    verdict_lines = [line.strip() for line in text.splitlines() if line.lstrip().startswith("VERDICT:")]
    if len(verdict_lines) != 1:
        return False, f"expected exactly one VERDICT line, found {len(verdict_lines)}"
    verdict = VERDICT.fullmatch(verdict_lines[0])
    if verdict is None:
        return False, f"unrecognized verdict line: {verdict_lines[0]!r}"
    severe = [m for m in SEVERITY.findall(text) if m in ("Critical", "High")]
    if verdict.group(1) == "NO-GO":
        return False, "verdict NO-GO"
    if severe:
        return False, f"{len(severe)} Critical/High finding(s)"
    return True, f"verdict {verdict.group(1)}, no Critical or High finding"


def parse_mutant_states(results: str) -> dict[str, str]:
    """Map each mutant name in `mutmut results` output to its state (killed, survived, timeout, ...)."""
    states: dict[str, str] = {}
    for line in results.splitlines():
        match = MUTANT_LINE.match(line)
        if match:
            states[match["name"]] = match["state"]
    return states


def parse_mutmut_summary(output: str) -> dict[str, int] | None:
    """Return the counts from mutmut's last progress summary, or None when it printed none.

    `mutmut results` prints nothing once every mutant is killed, so the run summary is the source of
    truth for totals, and the results listing only supplies names for the non-killed mutants.
    """
    matches = SUMMARY.findall(output)
    if not matches:
        return None
    checked, total, killed, no_tests, timeout, suspicious, survived = (int(v) for v in matches[-1])
    return {
        "checked": checked, "total": total, "killed": killed, "no_tests": no_tests,
        "timeout": timeout, "suspicious": suspicious, "survived": survived,
    }


def builtin_mutmut(ctx: Context, runner: Runner) -> tuple[bool, str]:
    """Run mutmut on the scoped modules and classify every mutant.

    A baseline suite that fails under mutmut is a failure. A run in which every mutant times out is a
    harness failure and raises NotRun, because it proves nothing either way. Killed mutants and
    justified equivalents pass. Survived, not-checked, no-tests, and suspicious mutants are unexplained.
    """
    targets = mutation_targets(ctx)
    if not targets:
        raise NotRun("no module to mutate")
    totals = {"checked": 0, "total": 0, "killed": 0, "no_tests": 0, "timeout": 0, "suspicious": 0, "survived": 0}
    for target in targets:
        # PYTEST_DISABLE_PLUGIN_AUTOLOAD: the tach pytest plugin (a Rust extension) hangs mutmut's forked
        # workers when tach.toml exists, so every mutant times out. Mutation runs do not need plugins.
        run_rc, run_out = runner(
            f"PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 uv run mutmut run {shlex.quote(target)}", ctx.root
        )
        if run_rc != 0 and "failed to collect stats" in run_out:
            return False, "baseline test suite fails under mutmut; fix the suite first"
        summary = parse_mutmut_summary(run_out)
        if summary is None:
            raise NotRun(f"mutmut printed no summary for {target}")
        for key in totals:
            totals[key] += summary[key]
    if totals["total"] == 0:
        raise NotRun("mutmut generated no mutants")
    if totals["timeout"] == totals["total"]:
        raise NotRun(f"mutmut harness: all {totals['total']} mutant(s) timed out; verdicts unreliable")
    _, results = runner("uv run mutmut results", ctx.root)
    states = parse_mutant_states(results)
    justified_file = ctx.root / JUSTIFIED_MUTANTS
    justified = set(justified_file.read_text(encoding="utf-8").split()) if justified_file.is_file() else set()
    unexplained = [
        name for name, state in states.items()
        if state not in MUTANT_OK and state != MUTANT_HARNESS_FAILURE and name not in justified
    ]
    if unexplained:
        return False, f"{len(unexplained)} unexplained mutant(s): {', '.join(unexplained[:5])}"
    open_count = totals["survived"] + totals["no_tests"] + totals["suspicious"] + (totals["total"] - totals["checked"])
    listed = [name for name, state in states.items() if state not in MUTANT_OK and state != MUTANT_HARNESS_FAILURE]
    if open_count > len(listed):
        return False, f"{open_count - len(listed)} unlisted unexplained mutant(s)"
    return True, f"{totals['killed']} killed, {totals['timeout']} timed out, {len(listed)} justified, of {totals['total']}"


def builtin_debt(ctx: Context) -> tuple[bool, str]:
    """Pass when no whole-project debt metric worsened against the baseline."""
    baseline_path = ctx.root / DEBT_BASELINE
    current_path = ctx.root / DEBT_CURRENT
    if not current_path.is_file():
        raise NotRun(f"{DEBT_CURRENT} missing; the verifier survey must write it")
    base = json.loads(baseline_path.read_text(encoding="utf-8"))["metrics"]
    cur = json.loads(current_path.read_text(encoding="utf-8"))["metrics"]
    # A metric the survey could not measure is stored as null. It cannot prove "not worse", so it is not run.
    keys = (*LOWER_IS_BETTER, *HIGHER_IS_BETTER)
    unmeasured = [k for k in keys if cur.get(k) is None or base.get(k) is None]
    worse = [k for k in LOWER_IS_BETTER if k not in unmeasured and cur[k] > base[k]]
    worse += [k for k in HIGHER_IS_BETTER if k not in unmeasured and cur[k] < base[k]]
    if worse:
        return False, f"worsened: {', '.join(worse)}"
    if unmeasured:
        raise NotRun(f"unmeasured metric(s): {', '.join(unmeasured)}")
    return True, "no whole-project debt metric worsened"


BUILTINS = ("builtin:sift-verdict", "builtin:mutmut-survivors", "builtin:debt-ratchet")


def run_check(check: Check, ctx: Context, *, runner: Runner, probe: Probe, report: Path | None) -> Result:
    """Evaluate one check: n/a, not run, builtin, or shell body."""
    reason = not_applicable(check, ctx)
    if reason:
        return Result(check, "n/a", reason)
    if not tool_available(check, ctx.root, probe):
        return Result(check, "not-run", f"{check.tool} unavailable")
    try:
        if check.tool == "builtin:sift-verdict":
            ok, detail = builtin_sift(ctx, report)
        elif check.tool == "builtin:mutmut-survivors":
            ok, detail = builtin_mutmut(ctx, runner)
        elif check.tool == "builtin:debt-ratchet":
            ok, detail = builtin_debt(ctx)
        else:
            body = _substitute(check.body, check, ctx)
            if body is None:
                return Result(check, "n/a", "no changed Python files")
            rc, output = runner(body, ctx.root)
            ok, detail = rc == 0, _tail(output) if rc else "exit 0"
            if check.mode == "escalate" and rc not in (0, ESCALATE_EXIT):
                # Only exit 1 means the threshold was exceeded. Anything else is a broken measurement.
                return Result(check, "fail", f"measurement error (exit {rc}): {detail}")
    except NotRun as exc:
        return Result(check, "not-run", str(exc))
    if ok:
        return Result(check, "pass", detail)
    if check.mode == "report-only":
        return Result(check, "report", detail)
    if check.mode == "escalate":
        return Result(check, "escalate", detail)
    return Result(check, "fail", detail)


def _tail(output: str, lines: int = 12) -> str:
    """Return the last lines of command output for the report."""
    kept = [line for line in output.splitlines() if line.strip()]
    return "\n      ".join(kept[-lines:]) if kept else "exit non-zero, no output"


def summarize(results: Sequence[Result]) -> tuple[str, int]:
    """Return the GATE line and exit code. Precedence: escalate, then fail, then not run."""
    blocking_not_run = [r for r in results if r.status == "not-run" and r.check.mode != "report-only"]
    if any(r.status == "escalate" for r in results):
        return "escalate", EXIT["escalate"]
    if any(r.status == "fail" for r in results):
        return "fail", EXIT["fail"]
    if blocking_not_run:
        return "fail (not run)", EXIT["not-run"]
    return "pass", EXIT["pass"]


def _default_runner(body: str, cwd: Path) -> tuple[int, str]:
    """Shell runner used by the CLI."""
    return _shell(body, cwd)


def _default_probe(tool: str, cwd: Path) -> bool:
    """Project-tool probe used by the CLI."""
    return _project_has_tool(tool, cwd)


def run_phase(
    checks: Sequence[Check],
    phase: str,
    ctx: Context,
    *,
    runner: Runner = _default_runner,
    probe: Probe = _default_probe,
    report: Path | None = None,
) -> list[Result]:
    """Run every check for `phase` in file order and return the results."""
    selected = [c for c in checks if c.phase == phase]
    if not selected:
        raise GateConfigError(f"no gate checks defined for phase '{phase}'")
    return [run_check(c, ctx, runner=runner, probe=probe, report=report) for c in selected]


def format_report(phase: str, results: Sequence[Result]) -> str:
    """Render the GATE line, per-check lines, and the rollback or escalation hints."""
    gate, _ = summarize(results)
    lines = [f"GATE: {gate} ({phase})"]
    for r in results:
        label = {"pass": "pass", "fail": "FAIL", "report": "report", "escalate": "ESCALATE",
                 "not-run": "not run", "n/a": "n/a"}[r.status]
        lines.append(f"  [{label}] {r.check.ident} ({r.check.mode}) - {r.detail}")
    rollbacks = sorted({r.check.rollback for r in results if r.status == "fail" and r.check.rollback != "none"})
    if rollbacks:
        lines.append(f"ROLLBACK: {', '.join(rollbacks)}")
    escalations = [r.check.ident for r in results if r.status == "escalate"]
    if escalations:
        lines.append(f"ESCALATE TO USER: {', '.join(escalations)}")
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("phase", choices=PHASES)
    parser.add_argument("--root", default=".", help="project root to check (default: current directory)")
    parser.add_argument("--gates-file", default=str(DEFAULT_GATES), help="quality-gates.md location")
    parser.add_argument("--scope", choices=("greenfield", "brownfield"), default="greenfield")
    parser.add_argument("--baseline", help="scope_check snapshot JSON (required for brownfield)")
    parser.add_argument("--brief-threshold", type=int, default=6, help="CRAP threshold (default 6; 8 when the brief states it)")
    parser.add_argument("--verifier-report", help="verifier report file for builtin:sift-verdict")
    parser.add_argument("--touched", nargs="*", default=[], help="touched files for the lite phase")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """CLI entry point. Returns the exit code."""
    args = build_parser().parse_args(argv)
    root = Path(args.root).resolve()
    try:
        checks = load_checks(Path(args.gates_file))
        if args.phase == "lite" and not args.touched:
            raise GateConfigError("lite phase requires --touched FILE...")
        ctx = build_context(
            root,
            phase=args.phase,
            scope=args.scope,
            baseline=Path(args.baseline) if args.baseline else None,
            crap=args.brief_threshold,
            touched=args.touched,
        )
        results = run_phase(
            checks, args.phase, ctx,
            report=Path(args.verifier_report) if args.verifier_report else None,
        )
    except (GateConfigError, OSError, json.JSONDecodeError, tomllib.TOMLDecodeError) as exc:
        print(f"gate: {exc}", file=sys.stderr)
        return EXIT["usage"]
    print(format_report(args.phase, results))
    return summarize(results)[1]


if __name__ == "__main__":
    sys.exit(main())
