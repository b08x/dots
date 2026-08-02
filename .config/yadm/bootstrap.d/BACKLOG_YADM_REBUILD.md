# Layer 2 Refactor Backlog: Rebuilding & Purging `~/.config/yadm`

**Generated:** August 2026  
**Context:** Workstation OS migration from Fedora/RHEL to **Pop!_OS** & adoption of the strict **3-Layer State Governance Architecture**.

This document serves as the master backlog and engineering specification for stripping out legacy Layer 1 system automation from `~/.config/yadm` and rebuilding `bootstrap.d` into a purely declarative, user-scoped identity manager.

---

## 0. Architectural Principles (Why We Are Rebuilding)

Under our 3-Layer Governance Architecture:
- **Layer 1 (Root/System - Standalone Ansible Repos)** manages APT packages, daemons, kernel EFIVARs (`kernelstub`), and Docker/Podman runtimes.
- **Layer 2 (`yadm` - User Home)** governs ONLY what lives under `$HOME`: dotfiles, user shell environment, encryption keys, and user-scoped CLI tool manifests.

**The Current Problem in `~/.config/yadm`:**  
Our forensic review uncovered severe Layer 1 entanglement and storage bloat inside our current dotfile structure:
1. An entire embedded Ansible setup (`.ansible/`, `ansible.cfg`, `inventory/`, `roles/`) currently lives inside `~/.config/yadm`, creating competing authorities against our external workstation builders.
2. Legacy Fedora-specific Python verifiers (`fedora_mcp_verifier.py`) and obsolete runtime bootstrap scripts (`02-ansible-playbook`, `04-ansible-asdf`) are hardcoded into the pipeline.
3. Over 11 GB of global `pip --user` dependencies have polluted `~/.local/lib/python3.x/site-packages`, duplicating host CUDA and PyTorch stacks.
4. Unencrypted agent state, API credentials (`~/.claude.json`, `~/.hermes/profiles/`), and world-readable `.env` files require structured cryptographic handling via `yadm encrypt`.

---

## 1. Backlog Phase 1: Purging Legacy & Layer 1 Bloat

Before writing new user scripts, eliminate system automation that violates Layer 2 boundaries:

- [x] **TASK-101: Excise Embedded Ansible Ecosystem**  
  - Delete `~/.config/yadm/.ansible/`, `~/.config/yadm/ansible.cfg`, `~/.config/yadm/inventory/`, and `~/.config/yadm/roles/`.
  - **Rationale:** All system configuration is handled by `pop_os-workstation-builder` (or equivalent external repositories). `yadm` should never run root playbooks.

- [x] **TASK-102: Remove Distro-Specific & Legacy Bootstrap Scripts**  
  - Delete `fedora_mcp_verifier.py` and `fedora_mcp_verifierB.py` (tied to RHEL/Fedora specific DNF paths).
  - Remove legacy bootstrap scripts in `bootstrap.d/`:  
    - `02-ansible-playbook` (violates Layer 2 boundary).
    - `04-ansible-asdf` (superseded by lightweight modern version managers like `uv` or `mise`).

- [x] **TASK-103: Eliminate Dead Dotfile Frameworks**  
  - Consolidate any remaining hooks out of legacy `~/.dotfiles/` and delete stale April logs like `~/dotly.log`. (Note: `python_env_manager` safely archived to `WorkspaceV3/Syncopated/_legacy_archive/`).

---

## 2. Backlog Phase 2: Python Virtualenv Enforcement & Tool Restoration

To recover ~16 GB of filesystem space and prevent Python package erosion on Pop!_OS:

- [x] **TASK-201: Deploy Global Virtualenv Guardrail**  
  - Create and track `~/.config/pip/pip.conf` with the following rigid policy:
    ```ini
    [global]
    require-virtualenv = true
    ```
  - **Impact:** Prevents bare `pip install` commands from touching `~/.local/lib/` or corrupting Debian system Python packages.

- [x] **TASK-202: Establish Declarative CLI Manifest (`~/.config/tooling/uv-tools.txt`)**  
  - Create a plain-text manifest listing user developer utilities that must live in isolated virtual environments via `uv tool`:
    ```
    ansible-builder
    ansible-navigator
    devstart
    docs2db
    linux-mcp-server
    mistral-vibe
    omega13
    rubygemdb
    seishun
    ```

- [x] **TASK-203: Track Core Developer Configurations**  
  - Ensure `yadm` explicitly tracks lightweight package configurations: `~/.gitconfig`, `~/.gemrc`, `~/.npmrc`, `~/.tool-versions` / `~/.default-gems`, and `~/.ssh/config` (NEVER track SSH private keys!).

---

## 3. Backlog Phase 3: Rebuilding `bootstrap.d/` Scripts

Re-architect the modular execution pipeline inside `~/.config/yadm/bootstrap.d/` to run completely as an unprivileged user:

- [x] **TASK-301: Rewrite `01-setup-tools.sh` (Declarative CLI Provisioning)**  
  - Update script to check for `uv` and iterate over `~/.config/tooling/uv-tools.txt`, executing `uv tool install --upgrade <package>` without sudo.
  - Implement zero-touch fallback checks for terminal prompt decorators (e.g. Starship / Oh-My-Zsh plugins).

- [x] **TASK-302: Reconstruct `02-flatpaks.sh` (Desktop Applications)**  
  - Renamed/migrated from legacy `05-flatpaks.sh`.
  - Ensure script targets user-space Flatpak installs (`flatpak install --user -y <remote> <app>`) for proprietary desktop tools, avoiding root APT bindings.

- [x] **TASK-303: Create `03-permissions-hardening.sh` (Secret & Token Sanitizer)**  
  - Create an automated post-bootstrap script that audits and rectifies filesystem permissions across `$HOME`:
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    # Secure SSH and GPG vaults
    chmod -R 700 ~/.ssh ~/.gnupg || true
    find ~/.ssh ~/.gnupg -type f -exec chmod 600 {} + || true

    # Lock down AI agent tokens and global environment definitions
    for secret_file in ~/.claude.json ~/.codex/auth.json; do
        [[ -f "$secret_file" ]] && chmod 600 "$secret_file" || true
    done
    find ~/.hermes/profiles/ -name "auth.json" -o -name ".env" -exec chmod 600 {} + 2>/dev/null || true
    ```

---

## 4. Backlog Phase 4: Zero-Knowledge Encryption & Cache Guardrails

- [x] **TASK-401: Lock Down Tokens with `yadm encrypt`**  
  - Update `~/.config/yadm/encrypt` (or `.yadm/encrypt`) to explicitly encrypt sensitive operational tokens using GPG / age:
    ```text
    .claude.json
    .codex/auth.json
    .hermes/profiles/*/auth.json
    .hermes/profiles/*/.env
    .config/tooling/secrets.env
    ```

- [x] **TASK-402: Expand `.yadmignore` Against Non-Deterministic AI State**  
  - Add explicit blacklist rules to `.yadmignore` to prevent throwaway evaluation models, caches, and scratch repos from inflating git commit histories:
    ```text
    # Media & ephemeral player state
    .config/mpv/watch_later/

    # Agent dynamic memory and evaluation state
    .hermes/state-snapshots/
    .hermes/state.db
    .gemini/antigravity-cli/brain/
    .claude/plugins/marketplaces/

    # Toolchain builds & cache directories
    .cache/
    .local/share/uv/
    .local/share/virtualenvs/
    .uv312/
    .uv313/
    .dspy_cache/
    ```

---

## 5. Verification Checklist (Definition of Done)

When Phase 1 through Phase 4 are completed, test the architecture using the following verification loop on a clean user account or distro box:

1. **Root Independence:** Running `yadm bootstrap` does not trigger `sudo` prompts or interact with package managers (`apt`, `dnf`, `pacman`).
2. **Idempotency:** Executing `~/.config/yadm/bootstrap.d/*` scripts a second time completes in < 5 seconds with zero state mutations.
3. **Safety Guarantee:** Running `stat -c "%a %n" ~/.claude.json ~/.ssh/*` returns `600` for all sensitive token stores.
4. **Clean Status:** `yadm status` reveals clean working directories with no `.venv`, `.cache`, or `.hermes` snapshot artifacts leaking into git staging.
