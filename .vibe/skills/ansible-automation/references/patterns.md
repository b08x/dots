# Ansible Patterns and Best Practices

This guide follows the style conventions from the RHEL Workstation Builder project.

## Table of Contents
- [Playbook Patterns](#playbook-patterns)
- [Role Patterns](#role-patterns)
- [Variable Patterns](#variable-patterns)
- [Docker Patterns](#docker-patterns)
- [Python Environment Patterns](#python-environment-patterns)
- [Idempotency Patterns](#idempotency-patterns)
- [Handler Patterns](#handler-patterns)

## Playbook Patterns

### Basic Structure

```yaml
---
- name: Descriptive playbook name
  hosts: all
  gather_facts: true

  tasks:
    - name: Install packages
      ansible.builtin.dnf:
        name:
          - package1
          - package2
        state: present
      become: true
      tags: ["packages", "install"]
```

### Multi-Host Playbooks

```yaml
---
- name: Setup web servers
  hosts: webservers
  gather_facts: true

  tasks:
    - name: Install nginx
      ansible.builtin.dnf:
        name: nginx
        state: present
      become: true
      tags: ["web", "packages"]

- name: Setup database servers
  hosts: dbservers
  gather_facts: true

  tasks:
    - name: Install PostgreSQL
      ansible.builtin.dnf:
        name: postgresql-server
        state: present
      become: true
      tags: ["db", "packages"]
```

### Tagging Tasks

```yaml
---
- name: Full deployment
  hosts: all
  gather_facts: true

  tasks:
    - name: Install base packages
      ansible.builtin.dnf:
        name: "{{ base_packages }}"
        state: present
      become: true
      tags: ["base", "packages"]

    - name: Setup application
      ansible.builtin.template:
        src: app.conf.j2
        dest: /etc/app.conf
      become: true
      tags: ["app", "config"]

    - name: Start services
      ansible.builtin.systemd:
        name: app-service
        state: started
        enabled: true
      become: true
      tags: ["services"]
```

Run with tags:
```bash
ansible-playbook playbook.yml --tags "base,app"
```

### Handler Pattern

```yaml
---
- name: Configure and start service
  hosts: all
  gather_facts: true

  tasks:
    - name: Install nginx
      ansible.builtin.dnf:
        name: nginx
        state: present
      become: true
      notify: Restart nginx
      tags: ["nginx", "packages"]

    - name: Configure nginx
      ansible.builtin.template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      become: true
      notify: Restart nginx
      tags: ["nginx", "config"]

  handlers:
    - name: Restart nginx
      ansible.builtin.systemd:
        name: nginx
        state: restarted
      become: true
```

### Conditional Execution

```yaml
- name: Install package on Fedora
  ansible.builtin.dnf:
    name: package
    state: present
  become: true
  when: ansible_distribution == "Fedora"
  tags: ["packages"]

- name: Install package if file does not exist
  ansible.builtin.dnf:
    name: package
    state: present
  become: true
  when: not ansible.builtin.stat(path=/path/to/file).stat.exists
  tags: ["packages"]
```

### Loop Patterns

```yaml
- name: Install multiple packages
  ansible.builtin.dnf:
    name: "{{ item }}"
    state: present
  become: true
  loop:
    - package1
    - package2
    - package3
  tags: ["packages"]

- name: Create multiple users
  ansible.builtin.user:
    name: "{{ item.name }}"
    state: present
    groups: "{{ item.groups }}"
  become: true
  loop:
    - { name: alice, groups: wheel }
    - { name: bob, groups: users }
  loop_control:
    label: "{{ item.name }}"
  tags: ["user"]
```

### Block Structure

Use blocks for logical grouping and privilege escalation:

```yaml
- name: Install and configure application
  block:
    - name: Create application directory
      ansible.builtin.file:
        path: /opt/myapp
        state: directory
        mode: "0755"
        owner: myapp
        group: myapp

    - name: Deploy configuration
      ansible.builtin.template:
        src: myapp.conf.j2
        dest: /opt/myapp/myapp.conf
        owner: myapp
        mode: "0644"

  become: true
  tags: ["myapp", "setup"]
```

## Role Patterns

### Role Directory Structure

```
roles/my_role/
├── tasks/
│   └── main.yml          # Main tasks for the role
├── handlers/
│   └── main.yml          # Handlers triggered by this role
├── vars/
│   └── main.yml          # Role variables (higher precedence)
├── defaults/
│   └── main.yml          # Default variables (lower precedence)
├── templates/            # Jinja2 templates
│   └── config.j2
├── files/                # Static files to copy
│   └── config.txt
├── meta/
│   └── main.yml          # Role metadata and dependencies
└── README.md             # Role documentation
```

### Role Dependencies (meta/main.yml)

```yaml
---
galaxy_info:
  author: Your Name
  description: Role description
  company: Your Company
  license: MIT
  min_ansible_version: 2.9
  platforms:
    - name: Fedora
      versions:
        - all

dependencies: []
```

### Variable Precedence in Roles

Order of precedence (highest to lowest):
1. `--extra-vars` (command line)
2. `host_vars/` and `group_vars/`
3. Role `vars/main.yml`
4. Role `defaults/main.yml`
5. Playbook `vars:`
6. Inventory vars

### Import vs Include

```yaml
# tasks/main.yml - Static import at parse time
---
- name: Import common tasks
  ansible.builtin.import_tasks: common.yml
  tags: ["common"]

- name: Import role
  ansible.builtin.import_role:
    name: common
  tags: ["common"]

# Dynamic include at runtime
- name: Include OS-specific tasks
  ansible.builtin.include_tasks: "{{ ansible_os_family }}.yml"
  when: os_specific_tasks
  tags: ["os-specific"]
```

## Variable Patterns

### Variable Files Organization

```
inventory/
├── production.yml
└── staging.yml

group_vars/
├── all.yml            # All hosts
├── webservers.yml     # Web server group
└── dbservers.yml      # Database server group

host_vars/
├── web1.example.com.yml
└── web2.example.com.yml

roles/my_role/
├── defaults/
│   └── main.yml       # Default values
└── vars/
    └── main.yml       # Role-specific values
```

### Variable Naming Conventions

Use **role prefix** and **snake_case** for all variable names:

```yaml
# Good - descriptive names with role prefix
devtools_user:
  name: "{{ ansible_user_id }}"
  group: "{{ ansible_user_id }}"
  groups: ["mock", "wheel"]

devtools_rpm_packages:
  - git
  - vim
  - rpmdevtools

devtools_asdf_install_path: /opt/asdf
devtools_asdf_version: v0.14.0

# Good - nested for related values
app_config:
  port: 8080
  host: localhost
  timeout: 30

# Avoid - too vague
value1: "something"
value2: "something_else"
```

### Variable Scoping

```yaml
# Playbook-level variables
- name: Play with variables
  hosts: all
  gather_facts: true

  vars:
    app_name: myapp
    app_version: "1.0"

  vars_files:
    - vars/production.yml

  tasks:
    - name: Print variables
      ansible.builtin.debug:
        msg: "{{ app_name }} v{{ app_version }}"
      tags: ["debug"]
```

### Jinja2 Filters

```yaml
- name: Example of filters
  ansible.builtin.debug:
    msg: |
      Uppercase: {{ "hello" | upper }}
      Lowercase: {{ "HELLO" | lower }}
      Trim: {{ "  hello  " | trim }}
      Split: {{ "a,b,c" | split(",") }}
      Join: {{ ["a","b","c"] | join(",") }}
      Default: {{ undefined_var | default("fallback") }}
      Boolean: {{ variable | bool }}
      Basename: {{ "/path/to/file.txt" | basename }}
      Dirname: {{ "/path/to/file.txt" | dirname }}
  tags: ["debug"]
```

### Vault for Secrets

```yaml
# Encrypt with: ansible-vault encrypt vars/secrets.yml
- name: Include encrypted vars
  ansible.builtin.include_vars: secrets.yml
  tags: ["secrets"]

# Or inline
- name: Use vault variable
  ansible.builtin.debug:
    msg: "DB password is {{ vault_db_password }}"
  tags: ["debug"]
```

Run with vault:
```bash
ansible-playbook playbook.yml --ask-vault-pass
ansible-playbook playbook.yml --vault-password-file ~/.vault_pass.txt
```

## Docker Patterns

### Pull and Run Container

```yaml
- name: Pull Docker image
  community.docker.docker_image:
    name: ghcr.io/openai/whisper.cpp
    tag: latest
    source: pull
  tags: ["docker", "images"]

- name: Run container
  community.docker.docker_container:
    name: whisper
    image: ghcr.io/openai/whisper.cpp:latest
    state: started
    restart_policy: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - "/host/models:/models"
      - "/host/output:/output"
    env:
      MODEL_PATH: "/models/ggml-base.en.bin"
    command: ["--server", "--port", "9000"]
  become: true
  tags: ["docker", "containers"]
```

### Docker Compose

```yaml
- name: Deploy with docker-compose
  community.docker.docker_compose:
    project_src: /path/to/compose/dir
    state: present
    pull: true
    recreate: always
  become: true
  tags: ["docker", "compose"]
```

### Docker Network Management

```yaml
- name: Create Docker network
  community.docker.docker_network:
    name: app-network
    driver: bridge
    state: present
  become: true
  tags: ["docker", "network"]

- name: Connect container to network
  community.docker.docker_container:
    name: my-app
    image: my-app:latest
    networks:
      - name: app-network
  tags: ["docker", "network"]
```

## Python Environment Patterns

### System Python

```yaml
- name: Install Python and pip
  ansible.builtin.dnf:
    name:
      - python3
      - python3-pip
      - python3-devel
      - python3-venv
    state: present
  become: true
  tags: ["python", "packages"]

- name: Install pip packages globally
  ansible.builtin.pip:
    name:
      - setuptools
      - wheel
      - pip
    state: latest
    executable: pip3
  become: true
  tags: ["python", "packages"]
```

### Virtual Environment

```yaml
- name: Create virtual environment
  ansible.builtin.command: python3 -m venv {{ venv_path }}
  args:
    creates: "{{ venv_path }}/bin/python"
  tags: ["python", "setup"]

- name: Install requirements in virtualenv
  ansible.builtin.pip:
    requirements: "{{ project_dir }}/requirements.txt"
    virtualenv: "{{ venv_path }}"
    state: latest
  tags: ["python", "packages"]

- name: Install specific packages
  ansible.builtin.pip:
    name:
      - flask
      - gunicorn
      - requests
    virtualenv: "{{ venv_path }}"
  tags: ["python", "packages"]
```

### Python Version Management (pyenv)

```yaml
- name: Install pyenv dependencies
  ansible.builtin.dnf:
    name:
      - git
      - gcc
      - zlib-devel
      - bzip2-devel
      - readline-devel
      - sqlite-devel
      - openssl-devel
      - libffi-devel
    state: present
  become: true
  tags: ["pyenv", "deps"]

- name: Clone pyenv
  ansible.builtin.git:
    repo: https://github.com/pyenv/pyenv.git
    dest: ~/.pyenv
  tags: ["pyenv"]

- name: Install Python version
  ansible.builtin.command: ~/.pyenv/bin/pyenv install 3.11.6
  args:
    creates: ~/.pyenv/versions/3.11.6/bin/python
  tags: ["pyenv", "python"]
```

## Idempotency Patterns

### Package Installation

```yaml
# GOOD - always idempotent
- name: Install package
  ansible.builtin.dnf:
    name: nginx
    state: present
  become: true
  tags: ["packages"]

# BAD - not idempotent (runs every time)
- name: Install package
  ansible.builtin.command: dnf install -y nginx
  tags: ["packages"]
```

### File Creation

```yaml
# GOOD - idempotent
- name: Create directory
  ansible.builtin.file:
    path: /path/to/dir
    state: directory
    mode: "0755"
  become: true
  tags: ["directories"]

# GOOD - idempotent with creates
- name: Download file
  ansible.builtin.get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
    mode: "0644"
  tags: ["download"]

# GOOD - idempotent with creates
- name: Extract archive
  ansible.builtin.unarchive:
    src: /tmp/file.tar.gz
    dest: /opt/
    remote_src: true
    creates: /opt/file/
  tags: ["archive"]
```

### Service Management

```yaml
# GOOD - idempotent
- name: Ensure service is running
  ansible.builtin.systemd:
    name: nginx
    state: started
    enabled: true
  become: true
  tags: ["services"]

# BAD - not idempotent
- name: Start service
  ansible.builtin.command: systemctl start nginx
  tags: ["services"]
```

### User Management

```yaml
# GOOD - idempotent
- name: Ensure user exists
  ansible.builtin.user:
    name: deploy
    state: present
    shell: /bin/bash
  become: true
  tags: ["user"]

# GOOD - idempotent
- name: Ensure user in group
  ansible.builtin.user:
    name: deploy
    groups: docker
    append: true
  become: true
  tags: ["user", "groups"]
```

### Shell Commands

```yaml
# GOOD - idempotent with creates
- name: Initialize database
  ansible.builtin.command: /usr/bin/init-db
  args:
    creates: /var/lib/db/initialized
  tags: ["db"]

# GOOD - conditional execution
- name: Run only if needed
  ansible.builtin.command: /usr/bin/setup
  when: not ansible.builtin.stat(path=/opt/setup/done).stat.exists
  tags: ["setup"]
```

## Handler Patterns

### Handler Naming

Use descriptive, action-oriented names:

```yaml
- name: Restart Docker
  ansible.builtin.systemd:
    name: docker
    state: restarted
  become: true

- name: Reload NFS
  ansible.builtin.systemd:
    name: nfs-server
    state: reloaded
  become: true

- name: Restart Samba
  ansible.builtin.systemd:
    name: smb
    state: restarted
  become: true
```

### Notification Pattern

```yaml
- name: Configure service
  ansible.builtin.template:
    src: service.conf.j2
    dest: /etc/service/service.conf
  become: true
  notify: Restart service
  tags: ["config"]
```
