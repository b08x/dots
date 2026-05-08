---
name: ansible-automation
description: This skill should be used when working with Ansible playbooks, roles, tasks, variables, or inventory files. It provides templates, patterns, and references for creating and managing Ansible automation for configuration management, application deployment, and environment setup following the RHEL Workstation Builder style guide conventions.
---

# Ansible Automation

## Overview

To create or modify Ansible automation including playbooks, roles, tasks files, variable files, and inventory configurations. This skill provides reusable templates, module references, and best practice patterns aligned with the RHEL Workstation Builder Ansible Style Guide.

**Style Guide Compliance**: All templates and examples follow the conventions documented in the RHEL Workstation Builder project style guide, including:
- 2-space YAML indentation
- `ansible.builtin.*` fully-qualified module names
- `become: true` at task level (not playbook level)
- `tags: ["tag1", "tag2"]` array format
- snake_case variable naming with role prefixes
- `ansible_user_id` for current user references

## When to Use This Skill

Use this skill when users request:
- Creation or editing of Ansible playbooks (.yml files)
- Creation or editing of Ansible roles (directory structure with tasks/, handlers/, vars/, etc.)
- Creation or editing of Ansible tasks files
- Creation or editing of Ansible variable files (group_vars, host_vars, vars/)
- Creation or editing of Ansible inventory files
- Setup of Docker containers via Ansible
- Package installation and environment configuration via Ansible

## Quick Start

### Create a Playbook

To create a new playbook following style guide conventions:

1. Copy a template from `assets/playbooks/`
2. Customize variables using snake_case with appropriate prefixes
3. Use `ansible.builtin.*` module names
4. Add `become: true` to tasks requiring privilege escalation
5. Tag all tasks with `tags: ["category", "action"]`

Available templates:
- `assets/playbooks/python-env.yml` - Python environment setup
- `assets/playbooks/docker-container.yml` - Docker container deployment
- `assets/playbooks/package-install.yml` - Package installation

### Create a Role

To create a new Ansible role following the standard structure:

1. Copy `assets/roles-template/` directory
2. Rename to your role name (lowercase, hyphen-separated)
3. Customize files with role-prefixed variables (e.g., `role_service_name`)

Standard role structure:
```
roles/role-name/
├── tasks/
│   └── main.yml          # Main tasks
├── handlers/
│   └── main.yml          # Handlers
├── vars/
│   └── main.yml          # High-precedence variables
├── defaults/
│   └── main.yml          # Default variables
├── templates/            # Jinja2 templates
├── files/                # Static files
└── meta/
    └── main.yml          # Metadata
```

### Reference Style Guide Patterns

For complete style guide compliance, reference:
- `references/patterns.md` - Best practice patterns with style guide examples
- `references/modules.md` - Module usage with style guide formatting
- `references/fedora-packages.md` - Package names and examples

## Style Guide Compliance

All templates in this skill follow these conventions from the RHEL Workstation Builder Style Guide:

### File Organization
- Roles use standard directory structure
- Templates use descriptive names with `.j2` extension
- Playbooks use clear, descriptive names

### YAML Formatting
- 2-space indentation (never tabs)
- Consistent spacing around colons: `key: value`
- Blank lines between logical task groups
- Square bracket array format for tags: `tags: ["role", "action"]`

### Variable Naming
- Use **role prefix** and **snake_case**: `role_service_name`, `python_environment_venv_path`
- Group related variables under common prefixes
- Use `ansible_user_id` for current user references
- Use `ansible_env.HOME` for home directory

### Task Structure
- Descriptive, action-oriented names starting with verbs
- Attribute order: `name` → module → `become` → `loop`/`with_items` → `when` → `tags` → `notify`
- `become: true` at task level, not playbook level
- Use blocks for logical grouping with privilege escalation

### Module Usage
- Fully qualify all modules: `ansible.builtin.dnf`, `community.docker.docker_container`
- Always specify `state:` parameter explicitly
- Use `mode: "0644"` (quoted string) for permissions
- Specify `owner` and `group` when needed

### Tagging
- Use hierarchical tag structure: `tags: ["role_name", "category"]`
- Consistent categories: `packages`, `config`, `services`, `desktop`, `user`

### Idempotency
- All tasks must be idempotent and safe to run multiple times
- Use module parameters instead of shell commands
- Use `creates:` or `removes:` with command/shell tasks
- Use `changed_when: false` for read-only operations

## Workflows

### Create a Tasks File for Python Environment

To create a tasks file for installing and configuring a Python environment:

1. Reference `assets/playbooks/python-env.yml` for complete example
2. Use `python_environment_*` variable prefix
3. Reference `references/modules.md` for `pip` module usage
4. Follow pattern from `references/patterns.md` for Python environments

**Style Guide Checklist:**
- [ ] Variables use snake_case with role prefix
- [ ] Modules are fully qualified (`ansible.builtin.*`)
- [ ] Tasks have `become: true` where needed
- [ ] Tags use array format: `tags: ["python", "packages"]`
- [ ] `ansible_user_id` used for user references
- [ ] All tasks are idempotent

### Create a Playbook for Docker Container

To create a playbook to setup whisper.cpp in a Docker container:

1. Copy `assets/playbooks/docker-container.yml` as starting point
2. Customize `docker_container_*` variables
3. Reference `references/modules.md` for `community.docker.*` modules
4. Follow Docker patterns from `references/patterns.md`

**Style Guide Compliance:**
- Use `community.docker.docker_container` (fully qualified)
- Variables: `docker_container_name`, `docker_container_image`
- Tags: `tags: ["docker", "containers"]`
- Privilege: `become: true` on relevant tasks

### Edit Vars File for Fedora Packages

To edit a vars file to include packages for Fedora:

1. Reference `assets/templates/vars-fedora.yml` for structure
2. Use `fedora_*` variable prefix for Fedora-specific settings
3. Reference `references/fedora-packages.md` for package names
4. Use `packages_base:`, `packages_dev:` grouping

**Example with Style Guide:**
```yaml
---
fedora_packages_base:
  - kitty
  - ranger
  - ffmpeg

fedora_packages_dev:
  - python3
  - python3-devel
  - gcc
  - make
```

## Best Practices

### Playbook Structure

1. Use `---` at the start of YAML files
2. Group related tasks with descriptive `name:`
3. Use `gather_facts: true` when needed, `false` for faster execution
4. Apply `become: true` at task level, not playbook level
5. Use blocks for logical grouping with privilege escalation

### Variable Management

1. Use `vars/main.yml` for role-specific variables (higher precedence)
2. Use `defaults/main.yml` for role defaults (lower precedence)
3. Define all role behavior through variables
4. Provide sensible defaults

**Variable Precedence (highest to lowest):**
1. `--extra-vars` (command line)
2. `host_vars/` and `group_vars/`
3. Role `vars/main.yml`
4. Role `defaults/main.yml`
5. Playbook `vars:`
6. Inventory vars

### Conditional Logic

Use consistent patterns for conditional execution:

```yaml
# Boolean variables
when: enable_feature | bool

# String comparisons
when: desktop_environment == "sway"

# List conditions
when: package_list | length > 0

# File existence
when: not ansible.builtin.stat(path=/path/to/file).stat.exists
```

### Error Handling

- Use `error_on_undefined_vars = True` in ansible.cfg
- Use `ignore_errors: true` sparingly with explanation
- Use `register` and `failed_when` for complex error handling

## Documentation and Syntax Verification

### Verify Ansible Syntax with Context7 MCP

Use the Context7 MCP tool (`context7_query-docs`) with library ID `/ansible/ansible-documentation` to verify Ansible syntax, look up module parameters, and access official documentation examples.

**Tool call format:**
- **libraryId**: `/ansible/ansible-documentation`
- **query**: Your specific syntax or documentation question

**Example queries:**
- `"ansible.builtin.copy module syntax and parameters"`
- `"correct YAML structure for Ansible playbooks"`
- `"ansible.builtin.dnf module usage examples"`
- `"Jinja2 templating syntax in Ansible tasks"`
- `"when condition syntax with multiple conditions"`
- `"loop and with_items correct usage patterns"`
- `"Ansible role standard directory structure"`
- `"become privilege escalation best practices"`

### Quick Syntax Check Workflow

1. **For module syntax verification**: Use Context7 with module name + "syntax" or "parameters"
2. **For local playbook validation**: Run `ansible-playbook --syntax-check playbook.yml`
3. **For style guide compliance**: Reference `references/patterns.md`
4. **For module examples**: Check `references/modules.md` or query Context7

## Bundled Resources

### References

- **modules.md**: Common Ansible modules with style guide-compliant examples
- **patterns.md**: Best practice patterns following RHEL Workstation Builder conventions
- **fedora-packages.md**: Fedora-specific package information with task examples

### Assets

- **playbooks/**: Style guide-compliant template playbooks
  - `python-env.yml`: Python environment setup
  - `docker-container.yml`: Docker container deployment
  - `package-install.yml`: Package installation
- **roles-template/**: Complete role directory structure
- **templates/**: Variable and configuration file templates
  - `vars-fedora.yml`: Fedora variable file template

### Scripts

Scripts directory available for future automation utilities.
