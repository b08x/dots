# Chapter 2: Role Design & Usability

## Core Idea
Roles should be self-contained, portable units of automation that do one thing well and follow convention over configuration.

## Frameworks Introduced
- **Self-Contained Roles**: Keep purpose and function focused to do one thing well.
  - When to use: When creating a new role.
  - How: Limit hard dependencies, keep roles loosely-coupled, and think about the full life-cycle of a single service.
- **Convention over Configuration**: Roles should run with as few parameter variables as possible.
  - When to use: When designing role variables.
  - How: Provide sane defaults in `defaults/` and use variables only to modify default behavior.

## Key Concepts
- **Roles** — Portable units of Ansible content decoupled from plays.
- **`defaults/`** — Variables meant to be easily overridden by users.
- **`vars/`** — Internal variables used by the role, not likely to be changed (e.g., package names by OS).
- **Loosely-Coupled** — Minimizing dependencies on other roles or external variables.
- **Molecule** — Testing framework designed for Ansible Role development.
- **ansible-lint** — Static analysis tool to check roles and playbooks.

## Mental Models
- **Role as a Service Manager** — A role should manage the full life-cycle of a service (or microservice), not an entire environment.
- **Convention over Configuration** — Provide everything needed for a standard install by default.

## Anti-patterns
- **Role as a Class/Object** — Treating roles as programming constructs.
- **Black-box Stack Roles** — Creating "umbrella" roles that try to manage an entire stack.
- **Tight Coupling** — Creating roles that cannot function without multiple other external roles or variables.

## Code Examples
```yaml
# requirements.yml
---
- src: nginxinc.nginx
  version: 0.8.0
- src: geerlingguy.firewall
  version: 2.4.0
```
- **What it demonstrates**: Version pinning for shared roles to ensure portability and repeatability.

## Key Takeaways
1. Keep roles focused: one role = one service.
2. Use `defaults/` for sane, overridable settings.
3. Use `vars/` for role-internal data (e.g., package lists).
4. Automate testing using Molecule and ansible-lint.
5. Avoid "command" modules; seek out native modules first.

## Connects To
- **Ch 01**: Applies "The Ansible Way" to structural components.
- **Ch 03**: When logic gets too complex for a role, move it to a module.
