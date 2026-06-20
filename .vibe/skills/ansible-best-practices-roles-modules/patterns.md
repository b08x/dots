# Patterns & Techniques: Ansible Best Practices

## Self-Contained Role Pattern
**When to use**: When designing any new role.
**How**: 
- One role should manage one service (e.g., `nginx`, `postgresql`).
- Keep provisioning separate from configuration.
- Avoid "umbrella" roles that manage entire stacks.
**Trade-offs**: May result in more roles to manage, but increases reuse and portability.

## Convention Over Configuration Pattern
**When to use**: To increase usability of roles.
**How**:
- Put all common settings in `defaults/main.yml`.
- Use variables as parameters ONLY to modify those defaults.
- A role should run successfully with zero user-provided variables for a standard install.
**Trade-offs**: Requires thinking through "sane defaults" upfront.

## Fail Fast Pattern (Modules)
**When to use**: When implementing custom Ansible modules.
**How**:
- Validate all inputs immediately using `argument_spec`.
- Check for required external dependencies (libraries, binaries) at the start.
- Exit and report errors before performing any state changes.
**Trade-offs**: More boilerplate code, but much higher reliability.

## User-Centric Abstraction Pattern
**When to use**: When deciding how to implement a module.
**How**:
- Focus on the *task* the user wants to accomplish, not the *API* you are calling.
- Abstract away complex data structures and multiple API calls into a single declarative interface.
- Normalize parameter names (e.g., use `state`, `name`, `path`).
**Trade-offs**: More complex module logic (Python), but simpler playbook logic (YAML).

## Atomic Move Technique
**When to use**: When a module writes to a file.
**How**:
- Write the output to a temporary file first.
- Use `atomic_move` to replace the destination file.
- This prevents partial writes if the process is interrupted.
**Trade-offs**: Slightly more resource intensive than direct writes.
