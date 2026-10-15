#!/usr/bin/env python3
"""
Agent Creator Workflow - non-interactive generator.

The orchestrating agent (see skills/agent-creator/SKILL.md) collects answers
interactively via ask_user_question, then hands them to this script as a JSON
file. This script NEVER reads stdin and NEVER calls input(): Vibe's bash tool
is non-interactive, so any input() would hit end-of-input immediately.

Usage:
    agent_creator_workflow.py ANSWERS.json [--dry-run] [--force]
    agent_creator_workflow.py ANSWERS.json --sfl-prompt-file PROMPT.md
    agent_creator_workflow.py --schema
    agent_creator_workflow.py ANSWERS.json --agents-dir DIR --prompts-dir DIR

Exit codes:
    0  success (or --dry-run preview complete)
    1  validation error (nothing written)
    2  usage error
    3  SFL delegation requested: [AGENT_TASK_REQUEST] printed, nothing
       written. Delegate with the task tool, save the subagent output to a
       file, and re-run with --sfl-prompt-file <path>.

Schema reference (verified against mistral-vibe vibe/core/agents/models.py):
- The agent name comes from the FILENAME stem of the TOML - there is no `id`
  key, and there is no `name` key. Display text belongs in `display_name`.
- Profile fields: display_name, description, safety, agent_type, instructions.
  Everything else is a config override (enabled_tools, disabled_tools,
  enabled_skills, bypass_tool_permissions, system_prompt_id, [tools.*],
  [session_logging]).
- There is no `auto_approve` key - use `bypass_tool_permissions` (bool).
- There is no `user_invocable` key.
- agent_type: "agent" (default) = selectable via `vibe --agent`;
  "subagent" = spawn-only via agentType (tools.subagent.spawn) - `--agent`
  rejects it. Subagents MUST have a non-empty description or they are not
  advertised to the spawning agent.
- enabled_tools is a glob allowlist. An EMPTY list means "no restriction",
  NOT "no tools". To disable every tool use disabled_tools = ["*"].
- system_prompt_id resolves to ~/.vibe/prompts/<id>.md; an inline
  `instructions` value takes precedence over it. This script always writes
  the prompt file that system_prompt_id points at.

Answers JSON schema (run with --schema to print this):
{
  "agent_id": "my-agent",                 // required, ^[a-z0-9_-]+$
  "agent_name": "My Agent",              // required -> display_name
  "description": "...",                  // required, non-empty
  "agent_type": "agent",                 // "agent" | "subagent"; default "agent"
  "safety": "neutral",                   // safe|neutral|destructive|smart|yolo
  "bypass_tool_permissions": false,      // bool; there is no auto_approve key
  "enabled_tools": [],                   // [] = no restriction (NOT "no tools")
  "disabled_tools": [],                  // may be ["*"]; must not overlap
                                         //   enabled_tools
  "enabled_skills": [],                  // skills written to the TOML
  "bash_allowlist": [],                  // optional -> [tools.bash] allowlist
  "delegate_sfl": false,                 // if true and no prompt text is
                                         //   supplied: print [AGENT_TASK_REQUEST]
                                         //   and exit 3
  "sfl_prompt_text": null,              // inline prompt text from the subagent
  "pattern_name": null,                  // used by the fallback prompt
  "subagents": [                         // optional; one TOML + prompt each
    {
      "subagent_id": "my-agent-reader",  // required
      "display_name": "Reader",          // optional, defaults from id
      "description": "...",              // REQUIRED non-empty (or the
                                         //   subagent is not advertised)
      "enabled_tools": ["read_file", "grep"],
      "disabled_tools": []
    }
  ]
}
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import tomli_w

# --- Configuration ---
VIBE_ROOT = Path.home() / ".vibe"
SKILL_DIR = VIBE_ROOT / "skills" / "agent-creator"
DEFAULT_AGENTS_DIR = VIBE_ROOT / "agents"
DEFAULT_PROMPTS_DIR = VIBE_ROOT / "prompts"

AGENT_ID_RE = re.compile(r"^[a-z0-9_-]+$")
VALID_AGENT_TYPES = {"agent", "subagent"}
VALID_SAFETY = {"safe", "neutral", "destructive", "smart", "yolo"}

# Tools that are safe to run without prompting. Everything else the user
# enables gets "ask". `task` is ALWAYS "always" when enabled - the
# subagent-delegation pattern (patterns/subagent-delegation.md) makes that
# non-negotiable: delegation cannot work if each spawn needs approval.
ALWAYS_TOOLS = {"read_file", "grep", "task", "ask_user_question", "todo", "skill"}


class AgentCreationError(Exception):
    """Validation error - nothing has been written when this is raised."""


def log(message: str, level: str = "INFO") -> None:
    print(f"[{level}] {message}")


def validate_agent_id(agent_id: str, field: str = "agent_id") -> str:
    if not agent_id or not AGENT_ID_RE.match(agent_id):
        raise AgentCreationError(
            f"Invalid {field}: {agent_id!r} (must match ^[a-z0-9_-]+$)"
        )
    return agent_id


def validate_tools(enabled: List[str], disabled: List[str]) -> None:
    if "*" in disabled:
        return  # ["*"] disables everything; overlap check does not apply
    overlap = sorted(set(enabled) & set(disabled))
    if overlap:
        raise AgentCreationError(
            "enabled_tools and disabled_tools must not overlap: "
            f"{overlap}. To disable every tool use disabled_tools = [\"*\"]."
        )


def default_prompt(config: Dict[str, Any], agent_name: str, description: str) -> str:
    """Full structured fallback prompt (used when SFL delegation is skipped)."""
    pattern = config.get("pattern_name")
    skills = config.get("enabled_skills") or []
    lines = [
        f"# {agent_name} System Prompt",
        "",
        "## Role",
        description,
        "",
        "## Responsibilities",
        config.get("responsibilities")
        or f"Perform {agent_name}'s primary purpose as requested by the user.",
        "",
    ]
    if pattern:
        lines += [
            "## Pattern",
            f"This agent implements the **{pattern}** pattern.",
            f"See: {SKILL_DIR}/references/Agent Skill Design Patterns.md",
            "",
        ]
    if skills:
        lines += [
            "## Skills",
            "Load these skills on demand when a task requires them:",
            ", ".join(f"`{s}`" for s in skills),
            "",
        ]
    lines += [
        "## Workflow",
        "1. Analyze the user's request.",
        "2. Execute the appropriate action.",
        "3. Return results to the user.",
        "",
        "---",
        "**Generated by agent-creator.**",
    ]
    if pattern:
        lines.append(f"**Pattern:** {pattern}")
    return "\n".join(lines) + "\n"


def tool_permission(tool: str) -> str:
    if tool == "task":
        return "always"  # non-negotiable for delegation
    return "always" if tool in ALWAYS_TOOLS else "ask"


def build_agent_toml(config: Dict[str, Any], agent_type: str) -> Dict[str, Any]:
    """Build a schema-valid agent profile dict (no id/name/auto_approve/
    user_invocable keys - none of them exist)."""
    agent_id = validate_agent_id(config["agent_id"])
    description = (config.get("description") or "").strip()
    if not description:
        raise AgentCreationError("description must be non-empty")
    if agent_type not in VALID_AGENT_TYPES:
        raise AgentCreationError(
            f"agent_type must be one of {sorted(VALID_AGENT_TYPES)}, "
            f"got {agent_type!r}"
        )

    enabled_tools = list(config.get("enabled_tools") or [])
    disabled_tools = list(config.get("disabled_tools") or [])
    validate_tools(enabled_tools, disabled_tools)

    profile: Dict[str, Any] = {
        "display_name": config["agent_name"],
        "description": description,
        "agent_type": agent_type,
        "safety": config.get("safety", "neutral"),
        "bypass_tool_permissions": bool(config.get("bypass_tool_permissions", False)),
        "system_prompt_id": config.get("system_prompt_id", agent_id),
        "enabled_tools": enabled_tools,
        "disabled_tools": disabled_tools,
    }

    enabled_skills = config.get("enabled_skills") or []
    if enabled_skills:
        profile["enabled_skills"] = enabled_skills

    tools_cfg: Dict[str, Any] = {}
    for tool in enabled_tools:
        if tool == "*":
            continue  # "*"-style globs do not get a [tools.*] table
        tools_cfg[tool] = {"permission": tool_permission(tool)}
    bash_allowlist = config.get("bash_allowlist") or []
    if "bash" in enabled_tools and bash_allowlist:
        tools_cfg["bash"] = {"permission": "ask", "allowlist": bash_allowlist}
    if tools_cfg:
        profile["tools"] = tools_cfg

    profile["session_logging"] = {"enabled": True, "session_prefix": agent_id}
    return profile


def build_subagent_toml(sub: Dict[str, Any]) -> Dict[str, Any]:
    subagent_id = validate_agent_id(sub["subagent_id"], "subagent_id")
    description = (sub.get("description") or "").strip()
    if not description:
        raise AgentCreationError(
            f"Subagent {subagent_id!r} has an empty description. Subagents "
            "with an empty description are not advertised to the spawning "
            "agent and can never be spawned."
        )
    cfg = {
        "agent_id": subagent_id,
        "agent_name": sub.get("display_name")
        or subagent_id.replace("-", " ").replace("_", " ").title(),
        "description": description,
        "safety": sub.get("safety", "safe"),
        "bypass_tool_permissions": False,
        "enabled_tools": sub.get("enabled_tools") or ["read_file", "grep"],
        "disabled_tools": sub.get("disabled_tools")
        or ["write_file", "search_replace", "bash", "task"],
    }
    # A subagent that spawns children needs task enabled and "always".
    if "task" in cfg["enabled_tools"]:
        cfg["disabled_tools"] = [
            t for t in cfg["disabled_tools"] if t != "task"
        ]
    return build_agent_toml(cfg, agent_type="subagent")


def write_profile(
    path: Path, profile: Dict[str, Any], dry_run: bool, force: bool
) -> None:
    if path.exists() and not force and not dry_run:
        raise AgentCreationError(
            f"{path} already exists. Pass --force to overwrite."
        )
    content = tomli_w.dumps(profile)
    if dry_run:
        print(f"----- BEGIN {path} -----")
        print(content, end="")
        print(f"----- END {path} -----")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        tomli_w.dump(profile, f)
    log(f"wrote {path}")


def write_prompt(
    path: Path, prompt_text: str, dry_run: bool, force: bool
) -> None:
    if path.exists() and not force and not dry_run:
        raise AgentCreationError(
            f"{path} already exists. Pass --force to overwrite."
        )
    if dry_run:
        print(f"----- BEGIN {path} -----")
        print(prompt_text, end="")
        print(f"----- END {path} -----")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        f.write(prompt_text)
    log(f"wrote {path}")


def generate_agent_files(
    config: Dict[str, Any],
    agents_dir: Path,
    prompts_dir: Path,
    sfl_prompt_text: Optional[str],
    dry_run: bool,
    force: bool,
) -> int:
    """Returns the process exit code. All validation happens before any
    write, so a failure never leaves partial output behind."""
    agent_id = validate_agent_id(config["agent_id"])
    agent_name = config["agent_name"]
    description = (config.get("description") or "").strip()
    agent_type = config.get("agent_type", "agent")

    # SFL delegation handshake: if requested but not supplied, emit the task
    # request and exit 3 WITHOUT writing anything. The orchestrator delegates
    # with the task tool, saves the output, and re-runs with
    # --sfl-prompt-file. This keeps the script re-entrant: no stdin, no
    # blocking waits, no half-finished runs.
    if config.get("delegate_sfl") and not sfl_prompt_text:
        task_desc = (
            f"Generate a high-performance system prompt for '{agent_name}'. "
            f"Purpose: {description}. "
            f"Skills: {', '.join(config.get('enabled_skills') or []) or 'none'}."
        )
        print("[AGENT_TASK_REQUEST]")
        print(
            json.dumps(
                {"agent": "sfl-prompt-engineer", "task": task_desc},
                indent=2,
            )
        )
        print("[END_TASK_REQUEST]")
        log(
            "SFL prompt requested but not supplied. Nothing written. "
            "Delegate with the task tool, save the subagent output to a "
            "file, and re-run with --sfl-prompt-file <path>.",
            "ACTION",
        )
        return 3

    # --- Build and validate EVERYTHING first (main + all subagents) ---
    profile = build_agent_toml(config, agent_type=agent_type)
    sub_profiles = [build_subagent_toml(sub) for sub in config.get("subagents") or []]

    if sfl_prompt_text:
        # The subagent may wrap its output in a marker; keep what follows it.
        if "[SUBAGENT_OUTPUT]" in sfl_prompt_text:
            sfl_prompt_text = sfl_prompt_text.split("[SUBAGENT_OUTPUT]", 1)[1]
        prompt_text = sfl_prompt_text.strip() + "\n"
    else:
        prompt_text = default_prompt(config, agent_name, description)

    # --- Compute all target paths and check for collisions up front ---
    targets: List[Path] = [
        agents_dir / f"{agent_id}.toml",
        prompts_dir / f"{profile['system_prompt_id']}.md",
    ]
    for sub_profile in sub_profiles:
        sub_id = sub_profile["session_logging"]["session_prefix"]
        targets.append(agents_dir / f"{sub_id}.toml")
        targets.append(prompts_dir / f"{sub_profile['system_prompt_id']}.md")
    if not dry_run and not force:
        existing = [str(t) for t in targets if t.exists()]
        if existing:
            raise AgentCreationError(
                "refusing to overwrite existing file(s): "
                + ", ".join(existing)
                + " (pass --force to overwrite)"
            )

    # --- Only now write: main profile, prompt, then each subagent ---
    write_profile(agents_dir / f"{agent_id}.toml", profile, dry_run, force)
    write_prompt(
        prompts_dir / f"{profile['system_prompt_id']}.md",
        prompt_text,
        dry_run,
        force,
    )
    for sub, sub_profile in zip(config.get("subagents") or [], sub_profiles):
        sub_id = sub_profile["session_logging"]["session_prefix"]
        write_profile(agents_dir / f"{sub_id}.toml", sub_profile, dry_run, force)
        write_prompt(
            prompts_dir / f"{sub_profile['system_prompt_id']}.md",
            default_prompt(
                sub, sub_profile["display_name"], sub_profile["description"]
            ),
            dry_run,
            force,
        )

    if dry_run:
        log("dry-run complete - nothing written", "OK")
    else:
        log(f"done: agent {agent_id} (agent_type={agent_type})", "OK")
        if agent_type == "agent":
            print(f"Test with: vibe --agent {agent_id}")
        else:
            print(
                f"Spawn-only profile: use agentType '{agent_id}' "
                '(vibe --agent rejects agent_type = "subagent").'
            )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Non-interactive agent generator (see --schema)."
    )
    parser.add_argument("answers", nargs="?", help="path to the answers JSON file")
    parser.add_argument("--dry-run", action="store_true", help="preview; write nothing")
    parser.add_argument("--force", action="store_true", help="overwrite existing files")
    parser.add_argument(
        "--sfl-prompt-file",
        help="markdown file with the sfl-prompt-engineer subagent output",
    )
    parser.add_argument(
        "--agents-dir", default=str(DEFAULT_AGENTS_DIR), help=argparse.SUPPRESS
    )
    parser.add_argument(
        "--prompts-dir", default=str(DEFAULT_PROMPTS_DIR), help=argparse.SUPPRESS
    )
    parser.add_argument(
        "--schema", action="store_true", help="print the answers JSON schema and exit"
    )
    args = parser.parse_args()

    if args.schema:
        marker = "Answers JSON schema (run with --schema to print this):"
        print(__doc__.split(marker)[-1].strip())
        return 0

    if not args.answers:
        parser.error(
            "an answers JSON file is required (this script never reads stdin)"
        )
        return 2

    answers_path = Path(args.answers)
    try:
        with open(answers_path) as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        log(f"cannot read answers file {answers_path}: {e}", "ERROR")
        return 2

    sfl_prompt_text = None
    if args.sfl_prompt_file:
        try:
            sfl_prompt_text = Path(args.sfl_prompt_file).read_text()
        except OSError as e:
            log(f"cannot read --sfl-prompt-file: {e}", "ERROR")
            return 2
    elif config.get("sfl_prompt_text"):
        sfl_prompt_text = config["sfl_prompt_text"]

    try:
        return generate_agent_files(
            config,
            Path(args.agents_dir),
            Path(args.prompts_dir),
            sfl_prompt_text,
            args.dry_run,
            args.force,
        )
    except AgentCreationError as e:
        log(str(e), "ERROR")
        return 1


if __name__ == "__main__":
    sys.exit(main())
