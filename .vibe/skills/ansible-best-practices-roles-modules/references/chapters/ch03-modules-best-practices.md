# Chapter 3: Module Design & Implementation

## Core Idea
Modules should be user-centric, declarative, and idempotent, abstracting complexity to make powerful automation simple.

## Frameworks Introduced
- **User-Centric Module Design**: Modules balance simplicity and power by abstracting details.
  - When to use: When developing a custom module.
  - How: Do not auto-generate modules from APIs; instead, implement common automation tasks for the user.
- **Fail Fast**: Modules should immediately detect and report failure conditions.
  - When to use: During module implementation.
  - How: Validate arguments upfront using `argument_spec` and apply defensive programming.

## Key Concepts
- **Modules** — Small programs (Python/PowerShell) called by tasks to perform actions.
- **Idempotency** — No side-effects with multiple runs.
- **Check Mode** — Ability for a module to report what it *would* do without making changes.
- **Predictable Interface** — Using lowercase, underscore-separated parameters (e.g., `update_cache`).
- **Normalized Parameters** — Using standard names like `name`, `state`, `dest`, `src`.
- **Action Plugin** — Logic that executes on the controller before dispatching a module.

## Mental Models
- **Abstract Complexity** — A module's job is to hide the "how" (API details, CLI flags) and expose the "what" (desired state).
- **Module as an Interface** — Think of the module as a declarative interface to a tool or service.

## Anti-patterns
- **API Wrapper Modules** — Creating a one-to-one mapping of an API, which forces users to be experts in that API.
- **Monolithic Modules** — Modules that try to do everything and become hard to use.
- **Reinventing the Wheel** — Not using `module_utils` (e.g., `basic.py`, `urls.py`).

## Code Examples
```python
# Normalized Parameter names
update_cache: yes  # YES
UpdateCache: yes   # NO
```
- **What it demonstrates**: The "Ansible Way" for parameter naming conventions.

## Key Takeaways
1. Design modules for the user, not the API.
2. Ensure idempotency (no side effects on repeat runs).
3. Support check mode and diff mode.
4. Normalize parameter names with common Ansible standards.
5. Fail fast and provide informative error messages.
6. Use `module_utils` to avoid reinventing core logic.

## Connects To
- **Ch 01**: Modules are the primary way to "Think Declaratively".
- **Ch 02**: Roles often benefit from custom modules to replace complex shell logic.
