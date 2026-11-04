<div align="left">

# dotfiles

**Personal workstation configuration for four hosts — soundbot, ninjabot, gir, tinybot — managed with yadm, Jinja2 multi-host templating, and a Charm Gum TUI.**

[![yadm](https://img.shields.io/badge/managed%20by-yadm-2f2f2f?logo=git&logoColor=white)][yadm-overview]
[![shell](https://img.shields.io/badge/shell-Bash%20%2F%20Zsh-4EAA25?logo=gnu-bash&logoColor=white)](https://www.zsh.org)
[![tests](https://img.shields.io/badge/tests-bats-9B59B6)][bats]
[![license](https://img.shields.io/badge/license-MIT-blue)](#license)

</div>

## What this is

You are reading one of the files this repository manages. The work tree is `$HOME` itself: yadm treats home as a bare repository with origin `git@github.com:b08x/dots.git`, so this README sits at `~/README.md`, tracked by the repository it describes.

The same tree runs on all four hosts, and every host difference lives in two Jinja2 templates rendered by `yadm alt`. The repo tracks 226 files; no tracked file is a symlink, though the bootstrap creates runtime symlinks outside the tracked tree (`85-rubymine.sh` links `~/.local/bin/rubymine`). Every clone carries the full history. This is Layer 2 of the three-layer *Syncopated* stack — see [The three layers](#the-three-layers).

## Requirements

| Tool | Required for | If missing |
| --- | --- | --- |
| uv | installing jinjanator when the `j2` CLI is missing — the alternates step runs `uv tool install jinjanator` | if `j2` is also absent, the bootstrap fails: `uv is not installed; install it to set up templates` |
| [gum][gum] | step-selection menu | bootstrap runs `sudo dnf install -y gum`; failing that, a numbered stdin prompt |
| zsh | login shell, set via `sudo usermod -s "$(command -v zsh)"` | — |
| ansible-pull | opt-in step `01-ansible-pull.sh` | step exits 2 (skipped) |
| flatpak | user flatpaks and VS Code extensions | steps 80 and 91 handle the details |

## Bootstrap a machine

```console
yadm clone git@github.com:b08x/dots.git
# yadm asks: run the bootstrap now? → y
# (yadm clone --bootstrap forces it; --no-bootstrap skips it)

# later, explicitly:
~/.config/yadm/bootstrap --all
~/.config/yadm/bootstrap --only cargo    # a single step
```

Usage is `bootstrap [--all | --only STEP[,STEP...]]`; an unknown step name exits 2. Because the work tree is `$HOME`, the bootstrap modifies the very repository it runs from — preflight inspects it before anything else does. Four built-in steps run in exact order, then every executable in `bootstrap.d/` runs in name order:

1. **preflight** (`check_drift_and_collisions`) — runs `yadm status --porcelain`, scans alternate/template targets, and offers a gum choice of *Backup, Diff & Proceed* / *Overwrite & Proceed* / *Abort*; backup writes to `mktemp -d "/tmp/yadm_backup_$(date +%s)_XXX"`.
2. **shell** — `sudo usermod -s "$(command -v zsh)"`; exits 2 if the shell is already zsh.
3. **decrypt** — `yadm decrypt`.
4. **alternates** — renders templates; when the `j2` CLI is missing it installs jinjanator with `uv tool install jinjanator` (not `dnf`, not `pip`), failing with `uv is not installed; install it to set up templates` if uv is absent.

Steps report a three-valued exit convention — **0 ok, 1 failed, 2 skipped**. Scripts declare `# bootstrap: needs-sudo`; sudo is authenticated up front via `sudo -v` because *gum spin hides stdin*. Everything logs to `~/.bootstrap.log` and systemd-cat. On failure, interactive runs offer retry/skip/abort; non-interactive runs record the failure and continue, and the final report exits 1 if any step failed.

Step selection goes through gum — `gum choose --no-limit --ordered`, a multi-select *Select the steps to run* — or, without gum, a numbered prompt on stdin where an empty line selects every step.

`bootstrap.d/` holds 9 executable scripts on disk; 8 are tracked.

| Script | Tracked | Manifest | Does |
| --- | --- | --- | --- |
| `01-ansible-pull.sh` | yes | none | Opt-in: pulls the workstation repo and applies `local.yml --tags user` (full command below) |
| `10-zsh.sh` | yes | none | Installs oh-my-zsh and zoxide from their upstream installers (`KEEP_ZSHRC=yes CHSH=no RUNZSH=no --unattended`); both idempotent, and neither touches `~/.zshrc` |
| `20-cargo.sh` | yes | `cargo-packages.txt` | Installs the 11 manifest crates; already-on-PATH tools are skipped, `dua-cli`/`gitui`/`eza` go via `sudo dnf install -y` first, the rest via `cargo install --locked` |
| `30-ruby.sh` | yes | `default-gems.txt` | Installs the 8 manifest gems under the system Ruby (requires Ruby >= 4.0.0) via `gem install --user-install --bindir $HOME/.local/bin`, or under rbenv pinned to Ruby 4.0.4 (`rbenv exec gem install`) with `USE_RBENV=1` |
| `40-gnome-extensions.sh` | yes | `gnome-extensions.txt` | Installs user extension UUIDs; exits 2 when the desktop is not GNOME |
| `80-install-user-flatpaks.sh` | yes | `user-flatpaks.txt` | Ensures the per-user flathub remote (`flatpak remote-add --user --if-not-exists`), then `flatpak install -y --user flathub` per entry |
| `85-rubymine.sh` | *untracked* | none | Installs RubyMine from the official JetBrains tarball (releases API) to `~/.local/share/JetBrains/RubyMine`, symlinks `~/.local/bin/rubymine`, writes a `.desktop` launcher |
| `90-obsidian-flatpak-setup.sh` | yes | none | Opt-in (`SYNCOPATED_OBSIDIAN=yes|no` or gum confirm): creates the vault at `~/Notebook` with a `Daily/` directory and enables 68 plugins; does **not** install the Obsidian flatpak — step 80 owns that (`md.obsidian.Obsidian` is line 1 of `user-flatpaks.txt`) |
| `91-install-vscode-extensions.sh` | yes | `vscode-extensions.txt` | Installs the 68 manifest extensions; target detected in order: `$VSCODE_CMD`, native `code`, then the Flatpak `com.visualstudio.code` |

`01-ansible-pull.sh` in full: opt-in via `SYNCOPATED_ANSIBLE_PULL=yes|no` (or a gum confirm), pull URL overridable via `SYNCOPATED_ANSIBLE_PULL_URL`; declined, no URL, or a missing `ansible-pull` exits 2, a pull failure exits 1. It does **not** read the local checkout at `~/WorkspaceV3/Syncopated/workstation` — it pulls the GitLab remote, branch `development`, and applies the user-space subset of the Layer-1 playbook:

```console
ansible-pull --ask-become-pass --url https://gitlab.com/syncopatedX/workstation.git \
  --directory $HOME/.cache/syncopated/ansible-pull --inventory "<hostname>," \
  --checkout development --tags user local.yml
```

## What's in the repo

The inventory regenerates from one command: `yadm list -a`. Its 226 files distribute as:

| Category | Count |
| --- | ---: |
| shell/zsh — completions, functions, themes, `.zshrc##template.j2`, `.aliases##template.j2`, `.zlogin`, `.zprofile`, `.zshenv`, `.profile` | 47 |
| Obsidian Notebook vault — `Notebook/**` | 53 |
| mpv — `.config/mpv/**`: conf, `input.conf`, lua scripts, script-opts, fonts | 24 |
| GNOME / input-remapper / desktop — presets, `settings.ini`, gowall `schema.yml`, `environment.d/00-arch.conf` | 19 |
| ranger — `.config/ranger/**` incl. `plugins/zoxide/` | 12 |
| dev tooling — `.config/{crush,micro,noisetorch,omega13,opencode,pip,qmd,tooling,voxtype,weathr}` | 11 |
| scripts — `Tools/bin`, `Tools/lib`, `bin` | 9 |
| top-level / misc — `.gitconfig`, `.ssh/config`, `.cargo/config.toml`, `.gemrc`, `README.md`, `.yadmignore`, etc. | 14 |
| kitty | 3 |
| Thunar | 3 |
| other `.config` — `htoprc`, Obsidian `Custom Dictionary.txt`, `user-dirs.dirs`, `xdg-terminals.list` | 4 |
| yadm control plane — `.config/yadm/**` | 27 |

Of those 226 files, the 27 under `.config/yadm/**` are the control plane: the 440-line `bootstrap` orchestrator, `encrypt`, `.shellcheckrc`, the 8 tracked `bootstrap.d/` scripts, the 5 `files/` manifests, the 2 `scripts/` helpers, and the 9 `tests/` files. The other 199 are payload — files the control plane puts in place and never executes. dots is a configuration that configures itself: the bootstrap installs the shell it next runs in, and the manifests install the tools that read the manifests.

## Host-specific behavior

Two payload files are templates — `.zshrc##template.j2` and `.aliases##template.j2`, the only `##`-suffixed paths in the tree; the other 197 ship verbatim. Each template renders one concrete file per host from a single source. `.zshrc##template.j2` branches its theme selector on the `HOSTNAME` variable — not `yadm.hostname`, not `YADM_HOSTNAME`:

```jinja
{% if HOSTNAME == 'ninjabot' %}
ZSH_THEME="jaischeema"
{% elif HOSTNAME == 'soundbot' %}
ZSH_THEME="strug"
{% elif HOSTNAME == 'gir' %}
ZSH_THEME="gnzh"
{% elif HOSTNAME == 'tinybot' %}
ZSH_THEME="xiong-chiamiov"
{% else %}
ZSH_THEME="jaischeema"
{% endif %}
```

The render: `strug` on soundbot, `jaischeema` on ninjabot, `gnzh` on gir, `xiong-chiamiov` on tinybot, and `jaischeema` as the default for any other host — on gir, the rendered `~/.zshrc` reads `ZSH_THEME="gnzh"`.

`.aliases##template.j2` rides the same mechanism but branches on `YADM_HOSTNAME` — soundbot and gir each get audio/sampler aliases (`baudline_jack`, `pulse_list_sources`, `vnc_serv`, `soundsampler`, `samplerv2`) — and on `YADM_DISTRO` / `YADM_DISTRO_FAMILY` (`Fedora`, `Arch`); the standard aliases (`reboot`, `shutdown`, `btm`, `lsin`, `ls="eza -h --group-directories-first -g --icons auto"`) are the common base.

Adding a host needs one thing: a branch in the `ZSH_THEME` selector — or accept the `jaischeema` default.

One consequence of templating: because `yadm log`, `yadm status`, and `yadm diff` can change state, yadm re-renders both templates on every invocation, so those commands print the jinjanator banner twice, once per template — `j2 25.3.1, Jinja2 3.1.6`. That is the renderer announcing its version, not an error; jinjanator is installed per host, so the banner is host-dependent.

## Adding tools

The manifests are the declarative half of the control plane: 5 plain-text files under `.config/yadm/files/`, 99 lines total, each consumed by exactly one `bootstrap.d/` script.

| Manifest | Lines | Consumed by |
| --- | ---: | --- |
| `cargo-packages.txt` | 11 | `20-cargo.sh` |
| `default-gems.txt` | 8 | `30-ruby.sh` |
| `gnome-extensions.txt` | 6 | `40-gnome-extensions.sh` |
| `user-flatpaks.txt` | 6 | `80-install-user-flatpaks.sh` |
| `vscode-extensions.txt` | 68 | `91-install-vscode-extensions.sh` |
| Total | 99 | |

```console
# add a tool: edit one manifest line, re-run its step
$EDITOR ~/.config/yadm/files/cargo-packages.txt
~/.config/yadm/bootstrap --only cargo
```

Nothing is hidden behind a lockfile — to see the current set, read the file.

## The three layers

Each layer draws a different boundary around "the machine." Layer 0 composes correctness into the machine *before* it exists; Layer 1 converges machines into correctness *after* they exist; Layer 2 — this repo — is the layer a re-image does not erase.

| Layer | Repo | Job |
| --- | --- | --- |
| 0 — osbuild | [syncopatedX/osbuild][osbuild], GitHub mirror [b08x/osbuild](https://github.com/b08x/osbuild); checkout `~/WorkspaceV3/Syncopated/osbuild` | Ansible build repo composing workstation images on Red Hat image-builder/osbuild: unattended installer ISOs via intents (`profiles/`), bootc containers, qcow2, Vagrant boxes; Fedora 43\|44, AlmaLinux 10, Rocky 9\|10; ansible-core >= 2.15 |
| 1 — workstation | [syncopatedX/workstation][sync], GitHub mirror [b08x/ansible-workstation](https://github.com/b08x/ansible-workstation); checkout `~/WorkspaceV3/Syncopated/workstation` | Ansible control repo provisioning Fedora 44 / AlmaLinux 10 / Rocky 10 workstations; ten roles — common, containerd, desktop_ui, libvirt, nas, networking, tools, tts, tuning, user; `local.yml` is the pull playbook, `playbooks/workstation.yml` targets the workstations group (gir, tinybot) |
| 2 — dots | this repository; the work tree is `$HOME` | dotfiles, templates, and the bootstrap that installs them |

The loop closes through the bootstrap. workstation's `common` role installs yadm (`roles/common/tasks/yadm.yml`) and its firstboot script chains into this repo's bootstrap; step `01-ansible-pull.sh` then pulls the workstation GitLab remote — branch `development` — and applies `local.yml --tags user`, the user-space subset of the Layer-1 playbook. Layer 2 triggers Layer 1 convergence before it applies user configuration: the edge the layering diagram cannot draw, pointing upward.

## Testing

The control plane ships its own test suite: 10 `.bats` files under `.config/yadm/tests/` alongside the shared `helpers.bash`, named for the components they exercise — `ansible-pull`, `bootstrap`, `cargo`, `desktop`, `gnome-extensions`, `ruby`, `rubymine`, `theme`, `vscode`, `zsh`. Of those 10, 8 are tracked; `desktop.bats` and `rubymine.bats` are untracked — `rubymine.bats` matching the untracked `85-rubymine.sh`. The repo sets `status.showuntrackedfiles=no`, so plain `yadm status` hides them — `yadm status --porcelain -uall` shows the `??` entries. The runner is [bats][bats]: `bats .config/yadm/tests/` executes the suite.

## Further reading

The upstream projects and in-tree paths behind each layer, in reading order:

- [yadm overview][yadm-overview] — how yadm manages `$HOME` as a bare repository
- [yadm alternates][yadm-alt] — the `##` suffix mechanism
- [yadm templates][yadm-tpl] — `##template.j2` and Jinja rendering
- [Charm Gum][gum] — the TUI menu library the bootstrap depends on
- [bats][bats] — the test runner
- [Syncopated workstation][sync] — Layer 1, the Ansible control repository the bootstrap pulls
- [Syncopated osbuild][osbuild] — Layer 0, the image-compose repository
- [bootstrap][bstrap] and [files][files] — the orchestrator and its manifests, in-tree

## Contributing

This is a personal configuration repository, but issues and pull requests are welcome for generic bug fixes or portability improvements. The bootstrap orchestrator and the `tests/` suite are host-agnostic — no hostname, path, or machine-specific assumption; host-specific branching lives in the two templates (the theme selector, plus `HOSTNAME`/`YADM_HOSTNAME`/`YADM_DISTRO` conditionals) — so they port to any yadm machine unchanged. Host-specific configuration isn't a good fit.

## License

[MIT](LICENSE) — see the [LICENSE](LICENSE) file at the repository root.

[bstrap]: https://github.com/b08x/dots/blob/main/.config/yadm/bootstrap
[files]: https://github.com/b08x/dots/tree/main/.config/yadm/files
[sync]: https://gitlab.com/syncopatedX/workstation
[osbuild]: https://gitlab.com/syncopatedX/osbuild
[yadm-overview]: https://yadm.io/docs/overview
[yadm-alt]: https://yadm.io/docs/alternates
[yadm-tpl]: https://yadm.io/docs/templates
[gum]: https://github.com/charmbracelet/gum
[bats]: https://github.com/bats-core/bats-core
