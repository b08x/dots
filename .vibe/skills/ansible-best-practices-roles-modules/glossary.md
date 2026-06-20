# Glossary: Ansible Best Practices

**Action Plugin** — A plugin that executes on the Ansible controller before dispatching a module to the target host. (Ch 03)

**ansible-lint** — A static analysis tool used to identify common issues and non-best practices in playbooks and roles. (Ch 02)

**Check Mode** — A mode (`--check`) where Ansible predicts changes without applying them. (Ch 03)

**Complexity** — The primary enemy of productivity in automation; the "Ansible Way" prioritizes simplicity. (Ch 01)

**Convention over Configuration** — A design pattern where tools come with sane defaults so users only need to specify what is different. (Ch 02)

**Declarative** — A programming paradigm where you describe *what* you want the state to be, rather than *how* to achieve it. (Ch 01)

**`defaults/`** — A directory in a role for low-precedence variables intended for user overrides. (Ch 02)

**Idempotency** — The property of a module where multiple runs result in the same desired state without unintended side effects. (Ch 03)

**Loosely-Coupled** — A design goal for roles to minimize hard dependencies on external components. (Ch 02)

**Module** — A specialized program (usually Python) that performs the actual work of an Ansible task. (Ch 03)

**module_utils** — Shared Python libraries used by Ansible modules to avoid code duplication. (Ch 03)

**Molecule** — A framework for testing Ansible roles across different scenarios and platforms. (Ch 02)

**Role** — A self-contained, portable unit of Ansible automation for a specific service or function. (Ch 02)

**`vars/`** — A directory in a role for high-precedence variables internal to the role's logic. (Ch 02)

**YAML** — The human-readable serialization language used for Ansible playbooks and role configuration. (Ch 01)
