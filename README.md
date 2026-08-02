# dots: Declarative Layer 2 User Identity & Workstation Tooling

**An unprivileged, zero-sudo workstation user environment governed by `yadm` under strict 3-Layer state architecture.**  
*Documentation & Knowledge Base: [DeepWiki: b08x/dots](https://deepwiki.com/b08x/dots)*

Most developer dotfile repositories degrade into fragile, monolithic bash scripts over time. As you work across multiple operating systems or machine refreshes, traditional dotfiles attempt to solve too many orthogonal problems simultaneously—running root package managers (`sudo dnf install` or `sudo apt-get`), compiling host drivers, and interweaving global system configuration with personal editor customizations. When migrating hardware or testing fresh distributions, these entangled scripts inevitably abort on broken package names or authentication dialogs.

This repository takes a strictly bounded approach: it governs **user identity and declarative user-space tooling exclusively**. Powered by `yadm` (Yet Another Dotfiles Manager), this environment executes without ever invoking `sudo`, mutating system filesystems, or leaking plaintext API credentials.

---

## Architecture: The 3-Layer Governance Model

To guarantee machine reproducibility and eliminate configuration creep, every component on this Linux workstation resides within an immutable layer boundary:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ LAYER 1 — Ansible (System / Root Scope)                                     │
│ Managed externally by: github.com/b08x/pop_os-workstation-builder           │
│ APT system packages · System76 daemons · kernelstub EFIVARs · Docker/Podman │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 2 — yadm (User Home Scope)                 ◀══ [ THIS REPOSITORY ]    │
│ Zsh prompt · Git/SSH/GPG identity · Unprivileged Flatpaks · uv CLI tools    │
├─────────────────────────────────────────────────────────────────────────────┤
│ LAYER 3 — Ephemeral Workspace (Project Scope)                               │
│ Local repository .venv · Containerized AI runtimes · node_modules           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Relationship to Layer 1 (System Builder)
Before initiating this user identity handoff, your machine's base operating system, real-time PipeWire threading (`rtkit`), System76 power daemons, and container virtualization runtimes must be provisioned by our primary root orchestration engine:
👉 **[pop_os-workstation-builder](https://github.com/b08x/pop_os-workstation-builder)**

> **The Architectural Rule**: Nothing in this dotfiles repository requires superuser (`sudo`) access. If a dependency demandsroot privileges, package installation via APT/DNF, or system-wide visibility, it belongs in `pop_os-workstation-builder`. Everything in `dots` executes cleanly inside `$HOME`.

---

## Zero-Touch Bootstrap Workflow

On a freshly initialized OS, bringing your custom shell, terminal color schemes, engineering utilities, and developer identities to life takes a single unprivileged command:

```bash
# 1. Clone dotfiles directly to $HOME and trigger automated user bootstrapping
yadm clone --bootstrap https://github.com/b08x/dots.git

# 2. Once cryptographic keys are decrypted, transition remote origin from HTTPS to SSH
yadm remote set-url origin git@github.com:b08x/dots.git
```

### Anatomy of the Modular Bootstrap Pipeline
When you execute `yadm bootstrap`, execution is delegated to an idempotent script array stored in `~/.config/yadm/bootstrap.d/`:

* **[01-setup-tools.sh](file:///home/b08x/.config/yadm/bootstrap.d/01-setup-tools.sh) (Declarative CLI Provisioning)**: Installs the blazing-fast `uv` Python package resolver directly into user space (`~/.local/bin`). It then reads our declarative manifest at [~/.config/tooling/uv-tools.txt](file:///home/b08x/.config/tooling/uv-tools.txt) and automatically provisions isolated CLI tools (`ansible-builder`, `docs2db`, `mistral-vibe`, `omega13`, `rubygemdb`, etc.) without touching system Python libraries. Finally, it verifies native Rust utility crates (`btm`, `rga`, `sd`, `choose`).
* **[02-flatpaks.sh](file:///home/b08x/.config/yadm/bootstrap.d/02-flatpaks.sh) (User-Space GUI Applications)**: Enables Flathub remotely under `--user` scope and deploys 18 curated desktop productivity and media tools (Obsidian, Typora, Audacity, Helvum, PodmanDesktop, DBeaver, Discord) completely within `$HOME/.local/share/flatpak/`, bypassing root Polkit requirements.
* **[03-permissions-hardening.sh](file:///home/b08x/.config/yadm/bootstrap.d/03-permissions-hardening.sh) (Security & Credential Sanitizer)**: Runs an automated post-bootstrap audit that enforces strict filesystem access permissions: directory vaults (`~/.ssh`, `~/.gnupg`) are locked to mode `700`, while sensitive private keys and AI agent token configurations are strictly clamped to mode `600`.

---

## Zero-Knowledge Encryption Vault (`yadm encrypt`)

Committing API tokens, AI assistant OAuth configs, or SSH keys to GitHub invites critical security leaks. Rather than managing third-party external vaults, this repository embeds symmetric and GPG/age cryptographic tracking via `yadm encrypt`.

### What We Protect
Our encryption specification at [~/.config/yadm/encrypt](file:///home/b08x/.config/yadm/encrypt) explicitly secures high-value credentials across your home directory:
* **Infrastructure Identities**: SSH private keys (`.ssh/id_ed25519*`, `.ssh/id_rsa*`) and GPG ASCII armored keyrings (`.gpg/private/*.asc`, `.gpg/recipes.kdbx`).
* **AI Agent Authentication**: OAuth token repositories and custom instruction profiles for modern agent frameworks:
  * `.claude.json` *(MCP server definitions and bearer tokens)*
  * `.codex/auth.json`
  * `.hermes/profiles/*/auth.json` and `.hermes/profiles/*/.env`
* **Local Developer Environment**: Global secret declarations in `.env` and `.config/tooling/secrets.env`.

### Routine Cryptographic Commands
When deploying to a new machine or rotating access tokens, interact with your encrypted archive directly through `yadm`:

```bash
# Unseal and restore your SSH keys and AI credentials on a new machine
yadm decrypt

# Add a new credential path to the vault protection list
echo ".config/new_app/secrets.json" >> ~/.config/yadm/encrypt

# Re-encrypt your local credentials into the version-controlled archive after rotating tokens
yadm encrypt
yadm add ~/.config/yadm/encrypt ~/.config/yadm/archive
yadm commit -m "chore(security): rotate encrypted AI credentials and SSH vaults"
```

---

## Guardrails Against Home Directory Entropy

A long-running workstation typically accumulates tens of gigabytes of hidden cache residue and overlapping dependencies. This repository deploys proactive guardrails to ensure `$HOME` remains pristine:

1. **Global Python Virtualenv Lockdown**: We deploy [~/.config/pip/pip.conf](file:///home/b08x/.config/pip/pip.conf) containing `require-virtualenv = true`. If you accidentally execute a bare `pip install` command in your terminal, the installation aborts immediately. This permanently prevents `pip --user` builds from duplicating system CUDA stacks or breaking OS DNF/APT Python libraries.
2. **AI & Toolchain Ignore Blacklist**: Our master ignore file at [~/.yadmignore](file:///home/b08x/.yadmignore) explicitly filters out multi-gigabyte build caches, throwaway evaluation repositories, and dynamic AI memory snapshots from polluting your Git repository:
   * **Agent Runtime Memory**: `.hermes/state-snapshots/`, `.hermes/state.db`, `.gemini/antigravity-cli/brain/`, `.claude/plugins/marketplaces/`.
   * **Toolchain Artifacts**: `.local/share/uv/`, `.local/share/virtualenvs/`, `.dspy_cache/`, and Node modules (`**/node_modules/*`).

---

## Maintenance & Extending

Because this dotfile suite is modular and strictly idempotent, you can re-execute bootstrapping at any time without side effects or duplicate installations:

```bash
# Safely re-run the complete Layer 2 tool and application alignment loop
yadm bootstrap
```

### Adding New Utilities
* **To add a Python developer utility**: Append the package name directly to [~/.config/tooling/uv-tools.txt](file:///home/b08x/.config/tooling/uv-tools.txt) and re-run `yadm bootstrap`.
* **To add a desktop GUI application**: Insert the Flathub application ID into the `FLATPAK_APPS` array in [~/.config/yadm/bootstrap.d/02-flatpaks.sh](file:///home/b08x/.config/yadm/bootstrap.d/02-flatpaks.sh).
* **To add system packages or daemons**: Switch over to your Layer 1 repository at **[pop_os-workstation-builder](https://github.com/b08x/pop_os-workstation-builder)** and modify `vars/pop_os_packages.yml`.
