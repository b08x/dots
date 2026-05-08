# Ansible Modules Reference

This guide follows the style conventions from the RHEL Workstation Builder project.

## Package Management

### dnf (Fedora/RHEL/CentOS)

Installs, upgrades, and removes packages using dnf.

```yaml
- name: Install packages
  ansible.builtin.dnf:
    name:
      - package1
      - package2
    state: present
    update_cache: true
  become: true
  tags: ["packages", "install"]

- name: Remove package
  ansible.builtin.dnf:
    name: package-to-remove
    state: absent
  become: true
  tags: ["packages"]

- name: Install from URL
  ansible.builtin.dnf:
    name: https://example.com/package.rpm
    state: present
  become: true
  tags: ["packages"]
```

**State options:** `present`, `absent`, `latest`

### pip

Manages Python packages using pip.

```yaml
- name: Install Python packages
  ansible.builtin.pip:
    name:
      - requests
      - numpy
    state: latest
    executable: pip3
  become: true
  tags: ["python", "packages"]

- name: Install from requirements file
  ansible.builtin.pip:
    requirements: /path/to/requirements.txt
    virtualenv: /path/to/venv
  tags: ["python", "packages"]

- name: Install in virtualenv
  ansible.builtin.pip:
    name: package-name
    virtualenv: /path/to/venv
    virtualenv_python: python3.11
  tags: ["python", "packages"]
```

**State options:** `present`, `absent`, `latest`, `forcelink`

### apt (Debian/Ubuntu)

Manages packages using apt.

```yaml
- name: Install packages
  ansible.builtin.apt:
    name:
      - package1
      - package2
    state: present
    update_cache: true
    cache_valid_time: 3600
  become: true
  tags: ["packages", "install"]

- name: Install specific version
  ansible.builtin.apt:
    name: package=1.2.3
    state: present
  become: true
  tags: ["packages"]
```

## File Management

### copy

Copies files to remote locations.

```yaml
- name: Copy file
  ansible.builtin.copy:
    src: /local/path/file.conf
    dest: /remote/path/file.conf
    owner: root
    group: root
    mode: "0644"
    backup: true
  become: true
  tags: ["config", "files"]

- name: Copy with content
  ansible.builtin.copy:
    content: "line1\nline2\n"
    dest: /remote/path/file.txt
  tags: ["config"]
```

### template

Templates a file using Jinja2.

```yaml
- name: Deploy configuration template
  ansible.builtin.template:
    src: templates/config.j2
    dest: /etc/app/config.conf
    owner: "{{ app_user }}"
    group: "{{ app_group }}"
    mode: "0644"
    backup: true
  become: true
  notify: Restart application
  tags: ["config", "templates"]
```

### file

Manages files and directories.

```yaml
- name: Create directory
  ansible.builtin.file:
    path: /path/to/dir
    state: directory
    mode: "0755"
    owner: root
    group: root
  become: true
  tags: ["directories"]

- name: Create symlink
  ansible.builtin.file:
    src: /path/to/target
    dest: /path/to/link
    state: link
  become: true
  tags: ["files"]

- name: Remove file or directory
  ansible.builtin.file:
    path: /path/to/remove
    state: absent
  become: true
  tags: ["cleanup"]
```

**State options:** `file`, `directory`, `link`, `absent`, `touch`, `hard`

## Docker

### docker_container

Manages Docker containers.

```yaml
- name: Run container
  community.docker.docker_container:
    name: my-container
    image: ghcr.io/openai/whisper.cpp:latest
    state: started
    restart_policy: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - "/host/path:/container/path"
    env:
      ENV_VAR: "value"
    command: ["--option", "value"]
  become: true
  tags: ["docker", "containers"]

- name: Stop and remove container
  community.docker.docker_container:
    name: my-container
    state: absent
  become: true
  tags: ["docker", "cleanup"]
```

**Restart policy options:** `no`, `always`, `unless-stopped`, `on-failure`

### docker_image

Manages Docker images.

```yaml
- name: Pull image
  community.docker.docker_image:
    name: ghcr.io/openai/whisper.cpp
    tag: latest
    source: pull
  tags: ["docker", "images"]

- name: Build image from Dockerfile
  community.docker.docker_image:
    name: my-image
    tag: v1
    build:
      path: /path/to/dockerfile/dir
    source: build
  become: true
  tags: ["docker", "build"]
```

## System Management

### systemd

Manages systemd services.

```yaml
- name: Ensure service is running
  ansible.builtin.systemd:
    name: nginx
    state: started
    enabled: true
  become: true
  tags: ["services"]

- name: Restart service
  ansible.builtin.systemd:
    name: nginx
    state: restarted
  become: true
  tags: ["services"]

- name: Stop service
  ansible.builtin.systemd:
    name: nginx
    state: stopped
  become: true
  tags: ["services"]

- name: Reload service
  ansible.builtin.systemd:
    name: nginx
    state: reloaded
  become: true
  tags: ["services"]
```

**State options:** `started`, `stopped`, `restarted`, `reloaded`

### user

Manages user accounts.

```yaml
- name: Create user
  ansible.builtin.user:
    name: deploy
    state: present
    shell: /bin/bash
    home: /home/deploy
    create_home: true
    system: false
  become: true
  tags: ["user"]

- name: Add user to group
  ansible.builtin.user:
    name: deploy
    groups: docker
    append: true
  become: true
  tags: ["user", "groups"]
```

### group

Manages groups.

```yaml
- name: Create group
  ansible.builtin.group:
    name: appgroup
    state: present
    gid: 1001
  become: true
  tags: ["user", "groups"]
```

## Network

### get_url

Downloads files.

```yaml
- name: Download file
  ansible.builtin.get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
    mode: "0644"
  tags: ["download"]

- name: Download with checksum
  ansible.builtin.get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
    checksum: "sha256:abc123..."
  tags: ["download"]
```

## Utilities

### command

Runs commands (does not process through shell).

```yaml
- name: Run command
  ansible.builtin.command: /usr/bin/command arg1 arg2
  register: command_result
  changed_when: false
  tags: ["commands"]

- name: Run only if file does not exist
  ansible.builtin.command: /usr/bin/create_file
  args:
    creates: /path/to/file
  tags: ["commands"]
```

**Note:** Use `command` instead of `shell` when possible for security and idempotency.

### shell

Runs shell commands.

```yaml
- name: Run shell command
  ansible.builtin.shell: echo "hello" > /tmp/test.txt
  args:
    creates: /tmp/test.txt
  tags: ["commands"]
```

**Warning:** Use `shell` only when necessary (pipes, redirects, etc.).

### debug

Prints debug messages.

```yaml
- name: Display variable
  ansible.builtin.debug:
    var: my_variable
  tags: ["debug"]

- name: Display message
  ansible.builtin.debug:
    msg: "Value is {{ my_variable }}"
  tags: ["debug"]
```

### set_fact

Sets facts/variables at runtime.

```yaml
- name: Set fact
  ansible.builtin.set_fact:
    new_variable: "value"
    combined: "{{ var1 }}_{{ var2 }}"
  tags: ["facts"]
```

### wait_for

Waits for a condition.

```yaml
- name: Wait for port
  ansible.builtin.wait_for:
    host: localhost
    port: 8080
    timeout: 60
  tags: ["wait"]

- name: Wait for file
  ansible.builtin.wait_for:
    path: /tmp/file.txt
    timeout: 30
  tags: ["wait"]
```
