# Cheatsheet: Ansible Best Practices

## The Ansible Way
- **Complexity Kills Productivity** → Simplify everything.
- **Optimize for Readability** → Automation is documentation.
- **Think Declaratively** → "What" not "How".

## Roles vs. Modules
| Feature | Role | Module |
|---|---|---|
| **Language** | YAML | Python / PowerShell |
| **Purpose** | Workflow & Configuration Reuse | Atomic Action on Target |
| **Logic** | Orchestration | Sophisticated Logic / API |
| **Packaging** | `ansible-galaxy` | Distributed with Role/Library |

## Role Variables Priority
1. **`defaults/`** — Lowest priority. Use for overridable user settings.
2. **`vars/`** — Higher priority. Use for internal role constants.

## Recommended Testing Tools
- **Molecule** — Full lifecycle testing for roles.
- **ansible-lint** — Static analysis/best practice enforcement.
- **ansible-test** — (Specifically `ansible-test sanity`) For module code quality.

## Module Implementation Rules
- **Idempotency** — No side effects on repeat runs.
- **Check Mode** — Support `--check` for "dry runs".
- **Predictable Interface** — Lowercase + underscores for params.
- **Normalized Params** — Use `name`, `state`, `src`, `dest`, `path`.
- **Fail Fast** — Validate inputs and dependencies upfront.

## Action Plugins
- Execute on the **controller**.
- Use when you need to perform logic *before* sending a module to the host.
- Use when a module needs the services of another core module (e.g., `copy`).
