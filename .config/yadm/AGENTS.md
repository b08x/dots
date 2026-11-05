# AGENTS.md — Syncopated yadm bootstrap

This repository is a **yadm dotfiles tree** whose payload is a Bash bootstrap orchestrator for a Fedora/GNOME workstation. The tracked files *are* the config: `bootstrap` lives at `~/.config/yadm/bootstrap` on the host, so paths in code are relative to `~/.config/yadm/`, not a project root.

## Structure

- `bootstrap` — master orchestrator. Runs preflight/shell/decrypt/alternates built-in steps, then every executable script in `bootstrap.d/` in name order. Exposes `--all` and `--only STEP[,STEP...]`.
- `bootstrap.d/NN-name.sh` — one step per script; the numeric prefix defines execution order (01 ruby, 02 the consolidated ansible-pull step, 03 zsh, then desktop 80–90). Scripts must be **executable** or they are silently skipped.
- `scripts/` — shared libraries sourced by bootstrap and step scripts:
  - `syncopated-theme.sh` — output helpers (`info/ok/warn/err`), `interactive`, `detect_distro/detect_distro_family/detect_desktop`, gum prompts (`choose`, `choose_many`, `choose_many_selected`), `RC_OK=0 RC_FAILED=1 RC_SKIPPED=2`.
  - `ansible-runner.sh` — `run_ansible_tags STEP TAGS_CSV [NEEDS_SUDO]`; runs `ansible-pull` against the workstation playbook repo (branch `development`), caching it in `~/.cache/syncopated/ansible-pull`.
  - `gum-helpers.sh` — gum styling/palette helpers for interactive scripts.
- `files/*.txt` — package lists consumed by steps and orchestrator (`bootstrap-system-packages.txt`, `ruby-system-packages.txt`, `default-gems.txt`, `user-flatpaks.txt`). Steps read these; add entries there rather than hardcoding packages in scripts.
- `01-ruby.sh` (renamed from `30-ruby.sh`) — Ruby environment. Cargo/rust, GNOME extensions, and VS Code extensions are no longer bootstrap steps: they are converged by the `user` Ansible role through `02-ansible-pull.sh`.
- `02-ansible-pull.sh` (formerly the four `NN-ansible-{system,desktop,tools,user}.sh` steps) — one consolidated privileged `ansible-pull` run (`--ask-become-pass`, i.e. `-K`) against `local.yml`. Tag defaults are hardware- and desktop-aware (`gpu` only with a GPU, `libvirt` only with KVM, `desktop_ui,desktop` only on a graphical desktop); override with `SYNCOPATED_ANSIBLE_TAGS`, force the desktop environment with `SYNCOPATED_DESKTOP_UI_ENVIRONMENT`.
- `tests/` — bats test suite; `tests/helpers.bash` sets up a throwaway `$HOME`, copies the tree, and provides `make_env`, `stub NAME BODY`, `cleanup_env`.
- `goals/` — prior planning artifacts (facts/plan docs from earlier refactors); reference material, not code.

## Conventions & gotchas

- **Step exit contract**: return 0 = ok, 1 = failed, 2 = skipped. Return `RC_FAILED`/`RC_SKIPPED` from the theme, not literal numbers. A failed step continues to later scripts (bootstrap exits 1 at the end), unless interactive (then retry/skip/abort menu).
- **Sudo declaration**: a step script that needs sudo must contain the line `# bootstrap: needs-sudo` in its header — the orchestrator greps for it to pre-authenticate before gum spinners hide stdin.
- **Use `set -uo pipefail`** (not `set -e`; steps manage their own failure paths and return codes).
- **Sourcing shared libs**: step scripts resolve theme/runner files relative to `${BASH_SOURCE[0]}` first, then fall back to `~/.config/yadm/scripts/...`. Copy that pattern in new steps.
- **Feature detection is overridable**: steps check env vars like `SYNCOPATED_GPU_DETECTED`, `SYNCOPATED_KVM_DETECTED` before probing `/dev`; honors `SYNCOPATED_DESKTOP`, `SYNCOPATED_DISTRO(_FAMILY)`. Tests rely on these hooks.
- **Interactivity**: `interactive()` is true on a TTY or when `SYNCOPATED_FORCE_INTERACTIVE=1`. Non-interactive runs must pick sensible defaults and never block on prompts. All gum-based prompts fall back to plain output when gum is absent.
- **Test overrides**: `SYNCOPATED_OS_RELEASE` (path to an os-release file), `SYNCOPATED_NO_ANIM=1`, `SYNCOPATED_FORCE_INTERACTIVE=1`, plus `SYNCOPATED_ANSIBLE_TAGS` (pull tag override), `SYNCOPATED_ANSIBLE_PULL_*` (url/branch/playbook/checkout/inventory) and `SYNCOPATED_GPU_DETECTED`/`SYNCOPATED_KVM_DETECTED`/`SYNCOPATED_DESKTOP`.
- **Logging**: orchestrator writes to `~/.bootstrap.log` and journald via `systemd-cat`; some helpers also log to `./logs/`. Log a step's lifecycle with `log_line`.
- Template engine for yadm alternates is **jinjanator** (`j2`), installed via `uv tool install` — the decrypt/alternates steps expect it.

## Commands

```sh
# Run the full bootstrap (interactive menu on a TTY)
./bootstrap
./bootstrap --all                 # every step, no menu
./bootstrap --only ruby,zsh       # named steps (names = filename minus NN- prefix)

# Tests (bats)
bats tests/
bats tests/bootstrap.bats          # single file
bats tests/zsh.bats tests/ruby.bats

# Lint (shellcheck config in .shellcheckrc sources SCRIPTDIR and SCRIPTDIR/..)
shellcheck bootstrap scripts/*.sh bootstrap.d/*.sh
```

There is no Makefile/CI config; bats and shellcheck are run directly.

## Testing approach

Tests stub all external tools (`yadm`, `sudo`, `dnf`, `gum` is deliberately absent) on a minimal PATH of symlinked coreutils, run the real script under `bash`, and assert on a `$T/calls` call-log plus output text (`✓ step (ok)`, `- step (skipped)`, `✗ step (failed)`). When adding/changing a step script, extend or add a matching `tests/<step>.bats` using `make_env`/`stub`/`add_script`-style helpers; never run against the real `$HOME`.
