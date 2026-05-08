# Ansible Role Template

This is a template directory structure for creating Ansible roles. Copy this directory and rename it to create a new role.

## Directory Structure

```
my_role/
├── tasks/
│   └── main.yml          # Main tasks for the role
├── handlers/
│   └── main.yml          # Handlers triggered by this role
├── vars/
│   └── main.yml          # Role variables (higher precedence)
├── defaults/
│   └── main.yml          # Default variables (lower precedence)
├── templates/            # Jinja2 template files
│   └── *.j2
├── files/                # Static files to copy
│   └── *
├── meta/
│   └── main.yml          # Role metadata and dependencies
└── README.md             # Role documentation
```

## How to Use

1. Copy this directory:
   ```bash
   cp -r roles-template/ my_new_role/
   ```

2. Rename the directory to your role name

3. Customize the files:
   - Update `meta/main.yml` with role metadata
   - Add tasks to `tasks/main.yml`
   - Define variables in `defaults/main.yml` and `vars/main.yml`
   - Add handlers to `handlers/main.yml`

4. Reference the role in your playbook:
   ```yaml
   - name: Apply my new role
     hosts: all
     roles:
       - my_new_role
   ```

## Variable Precedence

From highest to lowest:
1. `--extra-vars` (command line)
2. `host_vars/` and `group_vars/`
3. Role `vars/main.yml`
4. Role `defaults/main.yml`
5. Playbook `vars:`
6. Inventory vars

## Best Practices

- Keep tasks small and focused
- Use handlers for service restarts
- Use `defaults/main.yml` for sensible defaults
- Use `vars/main.yml` for role-specific overrides
- Document variables in `meta/argument_specs.yml` or README
- Tag tasks for selective execution
