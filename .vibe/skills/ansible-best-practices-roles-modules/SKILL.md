---
name: ansible-best-practices-roles-modules
description: "Knowledge base from \"Ansible Best Practices: Roles & Modules\" by Tim Appnel. Use when applying best practices for Ansible Roles and Modules, including design, usability, testing, and implementation."
allowed-tools:
  - Read
  - Grep
argument-hint: [topic, framework name, or chapter number]
---

# Ansible Best Practices: Roles & Modules
**Author**: Tim Appnel | **Pages**: 36 | **Chapters**: 3 | **Generated**: 2026-06-03

## How to Use This Skill

- **Without arguments** — load core frameworks for reference
- **With a topic** — ask about `idempotency`, `molecule`, or `role design`; I find and read the relevant chapter
- **With chapter** — ask for `ch01`, `ch02`, or `ch03`; I load that specific chapter
- **Browse** — ask "what chapters do you have?" to see the full index

When you ask about a topic not covered in Core Frameworks below, I will read
the relevant chapter file before answering.

---

## Core Frameworks & Mental Models

### The Ansible Way
- **Complexity Kills Productivity** — Strive for simplification in what you automate. Complexity is the primary enemy of efficient automation.
- **Optimize for Readability** — Write automation so it serves as the documentation of your workflow.
- **Think Declaratively** — Ansible is a desired state engine. Avoid procedural "coding" in YAML playbooks; instead, describe what the system should look like.

### Role Design Principles
- **Self-Contained & Focused** — Keep the purpose of a role limited to one service or function (e.g., manage the full life-cycle of a microservice).
- **Convention over Configuration** — Provide sane defaults in `defaults/` so roles run with minimal, if any, parameter overrides for standard usage.
- **Loosely-Coupled** — Limit hard dependencies on other roles or external variables to maximize portability and reuse.

### Module Design Principles
- **User-Centric Abstraction** — Modules should abstract complexity away from users, making powerful automation simple. They should not be a one-to-one mapping of an API or CLI tool.
- **Idempotency** — Modules must ensure no side-effects occur with multiple runs; if the system is already in the desired state, no changes should be made.
- **Fail Fast** — Immediately detect and report failure conditions through input validation and defensive programming.

---

## Chapter Index

| # | Title | Key Frameworks |
|---|-------|----------------|
| [ch01](references/chapters/ch01-ansible-philosophy.md) | The Ansible Way | Complexity Kills Productivity, Declarative Thinking |
| [ch02](references/chapters/ch02-roles-best-practices.md) | Role Design & Usability | Convention over Configuration, Loosely-Coupled Roles |
| [ch03](references/chapters/ch03-modules-best-practices.md) | Module Design & Implementation | Idempotency, User-Centric Abstraction, Fail Fast |

## Topic Index

- **Action Plugins** → ch03
- **ansible-lint** → ch02
- **Check Mode** → ch03
- **Convention over Configuration** → ch02
- **Defaults vs Vars** → ch02
- **Idempotency** → ch03
- **Molecule** → ch02
- **Normalized Parameters** → ch03
- **Portability** → ch02
- **Readability** → ch01

## Supporting Files

- [glossary.md](glossary.md) — all key terms with definitions
- [patterns.md](patterns.md) — concrete design patterns and techniques
- [cheatsheet.md](cheatsheet.md) — quick reference tables and rules

---

## Scope & Limits

This skill covers the best practices shared by Tim Appnel in the "Roles & Modules" presentation. For hands-on implementation details or syntax help for specific core modules, combine with project documentation.
