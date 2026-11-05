<div align="left">

# dotfiles

**Personal configurations for Linux-based workstations — managed with yadm, Jinja2 multi-host templating, and a Charm Gum TUI.**

[![yadm](https://img.shields.io/badge/managed%20by-yadm-2f2f2f?logo=git&logoColor=white)][yadm-overview]
[![shell](https://img.shields.io/badge/shell-Bash%20%2F%20Zsh-4EAA25?logo=gnu-bash&logoColor=white)](https://www.zsh.org)
[![tests](https://img.shields.io/badge/tests-bats-9B59B6)][bats]
[![license](https://img.shields.io/badge/license-MIT-blue)](#-license)

</div>

## 🏠 What this is

yadm manages `$HOME` as a bare Git repository whose origin is `git@github.com:b08x/dots.git`; the work tree is `$HOME` itself, and this file sits at `~/README.md`, tracked by that repository.

The same tree runs on the RHEL family of distributions — Fedora, AlmaLinux, Rocky — and every host difference lives in two Jinja2 templates rendered by `yadm alt`. No tracked file is a symlink; `yadm list -a` prints the full set. The bootstrap creates runtime state outside the tracked tree: `rubymine-fetch` installs under `/opt/rubymine` and symlinks `/usr/bin/rubymine` (`scripts/rubymine-fetch:50`), flatpak data lands under `~/.local/share/flatpak`, and the Obsidian step writes vault configuration into `~/Notebook`. Every clone carries the full history.

That tree divides by what happens to a file. The `.config/yadm/**` area is the control plane — the 504-line bootstrap orchestrator, the `bootstrap.d/` steps, the manifests, the `scripts/` helpers, the bats suite — the part of the tree that executes on the machine; everything else is payload: files the control plane puts in place and never runs. The split is the design. dots is a configuration that configures itself: an inert `.zshrc` becomes a working shell only after a `bootstrap.d/` step installs oh-my-zsh for it to load into — the bootstrap installs the shell it next runs in, and the manifests install the tools that read the manifests. This is Layer 2 of the three-layer *Syncopated* stack — see [The three layers](#-the-three-layers).

## 🥞 The three layers

Each layer draws a different boundary around "the machine." Layer 0 composes correctness into the machine *before* it exists; Layer 1 converges machines into correctness *after* they exist; Layer 2 — this repo — is the layer a re-image does not erase.

| Layer | Repo | Job |
| --- | --- | --- |
| 0 — osbuild | [syncopatedX/osbuild][osbuild], GitHub mirror [b08x/osbuild](https://github.com/b08x/osbuild); checkout `~/WorkspaceV3/Syncopated/osbuild` | Ansible build repo composing workstation images on Red Hat image-builder/osbuild: unattended installer ISOs via intents (`profiles/`), bootc containers, qcow2, Vagrant boxes; Fedora 43\|44, AlmaLinux 10, Rocky 9\|10; ansible-core >= 2.15 |
| 1 — workstation | [syncopatedX/workstation][sync], GitHub mirror [b08x/ansible-workstation](https://github.com/b08x/ansible-workstation); checkout `~/WorkspaceV3/Syncopated/workstation` | Ansible control repo provisioning Fedora 44 / AlmaLinux 10 / Rocky 10 workstations; eleven roles — common, containerd, desktop_ui, gpu, libvirt, nas, networking, tools, tts, tuning, user; `local.yml` is the pull playbook, `playbooks/workstation.yml` targets the workstations group (tinybot, gir, soundbot) |
| 2 — dots | this repository; the work tree is `$HOME` | dotfiles, templates, and the bootstrap that installs them |

The loop closes through the bootstrap. workstation's `common` role installs yadm (`roles/common/tasks/yadm.yml`) and its firstboot script chains into this repo's bootstrap; step `02-ansible-pull.sh` then pulls the workstation GitLab remote — branch `development` — and applies `local.yml` with `--ask-become-pass` and hardware-aware default tags, spanning everything from `repos` to `user`. Layer 2 triggers Layer 1 convergence before it applies user configuration: the edge the layering diagram cannot draw, pointing upward.

## 📋 Requirements

The bootstrap that closes that loop runs on a handful of host tools; each row names what happens when one is missing.

| Tool | Required for | If missing |
| --- | --- | --- |
| uv | installing jinjanator when the `j2` CLI is missing — the alternates step runs `uv tool install jinjanator` | if `j2` is also absent, the bootstrap fails: `uv is not installed; install it to set up templates` |
| [gum][gum] | every prompt, menu, and spinner | bootstrap runs `sudo dnf install -y gum`; failing that, plain numbered prompts and output |
| zsh | login shell, set via `sudo usermod -s` in the built-in `shell` step | the shell step fails: `zsh is not installed` |
| ansible-pull | step `02-ansible-pull.sh` — the bootstrap's one Layer-1 pull — though ansible-core itself arrives via the bootstrap's own package prelude (`files/bootstrap-system-packages.txt`) | absent anyway ⇒ the step returns 2 (skipped) — a skip, *not* a failure: the pull never ran, the final report prints it under `N skipped`, and only a failure forces exit 1, so the run can end clean with Layer-1 convergence never having happened |
| flatpak | step 80: the six manifest apps; the opt-in Obsidian setup launches the app | step 80 exits 2 (skipped) |

## 🚀 Bootstrap a machine

```console
yadm clone git@github.com:b08x/dots.git
# yadm asks: run the bootstrap now? → y
# (yadm clone --bootstrap forces it; --no-bootstrap skips it)

# later, explicitly:
~/.config/yadm/bootstrap --all
~/.config/yadm/bootstrap --only ruby    # a single step
```

Usage is `bootstrap [--all | --skip-packages | --only STEP[,STEP...]]`; an unknown option exits 2, and an unknown step name exits 2 after printing the valid names — today: `preflight`, `shell`, `decrypt`, `alternates`, `ruby`, `ansible-pull`, `zsh`, `install-user-flatpaks`, `rubymine`, `obsidian`. Because the work tree is `$HOME`, the bootstrap modifies the very repository it runs from — preflight inspects it before anything else does. Before any step runs, a package prelude (`ensure_system_packages`) dnf-installs `files/bootstrap-system-packages.txt` — ansible-core, three Ansible collections, python3-rich, python3-pyyaml; `--skip-packages` (or `SYNCOPATED_SKIP_PACKAGES`) skips it. Four built-in steps run in exact order, then every executable in `bootstrap.d/` runs in name order — and a non-executable script is warned about, not silently skipped (`Skipping <name> (not executable)`):

1. **preflight** (`check_drift_and_collisions`) — runs `yadm status --porcelain`, scans `##`-suffixed alternate targets, and offers a gum choice of *Backup, Diff & Proceed* / *Overwrite & Proceed* / *Abort*; a cancelled or EOF menu counts as Abort. Backup writes to `mktemp -d "/tmp/yadm_backup_$(date +%s)_XXX"`, then puts the diff through `gum pager` under a second confirm (*Proceed and overwrite these files?*); non-interactive runs default to *Backup & Proceed*. An abort returns 3, `RC_ABORT` — the one result that is neither ok, failed, nor skipped — and ends the run.
2. **shell** — `sudo usermod -s "$(command -v zsh)"`; exits 2 if the login shell is already zsh.
3. **decrypt** — `yadm decrypt`.
4. **alternates** — renders templates; when the `j2` CLI is missing it installs jinjanator with `uv tool install jinjanator` (not `dnf`, not `pip`), failing with `uv is not installed; install it to set up templates` if uv is absent.

Steps report a four-valued result — **0 ok, 1 failed, 2 skipped** (`RC_OK`/`RC_FAILED`/`RC_SKIPPED` in `scripts/syncopated-theme.sh`), plus the orchestrator's own 3 (abort) above. Scripts declare `# bootstrap: needs-sudo`, those declarations are grepped pre-run, and interactive runs authenticate up front via `sudo -v` because *gum spin hides stdin*. Everything logs to `~/.bootstrap.log` and systemd-cat. On failure, interactive runs offer retry/skip/abort; non-interactive runs record the failure and continue, and the final report — `N ok · N skipped · N failed` — exits 1 if any step failed.

Step selection goes through gum — `gum choose --no-limit --ordered`, a multi-select *Select the steps to run* with every step preselected — or, without gum, a numbered prompt where an empty line selects every step (`Choose [numbers, empty for all]`). Cancelling the menu selects nothing and exits 0.

`bootstrap.d/` holds 6 executable scripts on disk, and the runs read as one story in name order — manifest to consumer to guard conditions.

### 💎 01-ruby.sh

Reads two manifests — `default-gems.txt` for the 7 gems, `ruby-system-packages.txt` for the 12 dnf dev packages that build them — and installs under the system Ruby when it is ≥ 4.0.0, otherwise under rbenv pinned to Ruby 4.0.4 (`--global system\|rbenv`, `SYNCOPATED_RUBY_GLOBAL`, and `USE_RBENV=1` each force one side); gems go in via `gem install --user-install --bindir $HOME/.local/bin --no-document` (system) or `rbenv exec gem install` (rbenv), and `--skip-deps` / `SYNCOPATED_RUBY_SKIP_DEPS` skips the dnf packages.

### 🔄 02-ansible-pull.sh

Consumes no manifest: it makes one privileged ansible-pull run (`--ask-become-pass`) against `local.yml`, with default tags hardware- and desktop-aware — `repos common tuning networking` always, `gpu` only with a GPU, `containerd`, `libvirt` only with KVM, `desktop_ui desktop` only on a graphical desktop, then `tools user` — overridable through `SYNCOPATED_ANSIBLE_TAGS`, with `SYNCOPATED_DESKTOP_UI_ENVIRONMENT` forcing the desktop environment, and an empty tag selection a clean exit 0.

### 🐚 03-zsh.sh

Installs oh-my-zsh and zoxide from their upstream installers (`KEEP_ZSHRC=yes CHSH=no RUNZSH=no --unattended`) — both idempotent, neither touching `~/.zshrc` — and `SYNCOPATED_SYSTEM_OMZ` prefers a distro-installed oh-my-zsh at `/usr/share/oh-my-zsh`.

### 📦 80-install-user-flatpaks.sh

The one manifest consumer left in the high numbers: it ensures the per-user flathub remote (`flatpak remote-add --user --if-not-exists`) out of `user-flatpaks.txt`, then `flatpak install -y --user flathub` per entry, exiting 2 when `flatpak` is missing.

### 🛠️ 85-rubymine.sh

Takes no manifest: it installs RubyMine as a system RPM (`sudo dnf install -y rubymine`), falling back to `scripts/rubymine-fetch` (install under `/opt/rubymine`, symlink `/usr/bin/rubymine`), and skips — exit 2 — when any prior install exists: an RPM, the `com.jetbrains.RubyMine` flatpak, a Toolbox install, or a command on PATH.

### 🗒️ 90-obsidian-flatpak-setup.sh

Closes the set — still manifest-less, and opt-in (`SYNCOPATED_OBSIDIAN=yes\|no`, default no, and it requires a TTY with gum): it provisions the vault at `~/Notebook` with a `Daily/` directory and enables 69 plugins (disabling `sync`), and does *not* install the Obsidian flatpak, because step 80 owns that (`md.obsidian.Obsidian` is line 1 of `user-flatpaks.txt`).

`02-ansible-pull.sh` in full: one consolidated privileged run, assembled by `run_ansible_tags` in `scripts/ansible-runner.sh` — it does *not* read the local checkout at `~/WorkspaceV3/Syncopated/workstation`, it pulls the GitLab remote, branch `development`:

```console
ansible-pull --ask-become-pass \
  --url https://gitlab.com/syncopatedX/workstation.git \
  --directory ~/.cache/syncopated/ansible-pull \
  --inventory "<hostname>," \
  --checkout development \
  --tags "$tags" local.yml
```

The tag vocabulary runs eleven deep: `repos common tuning networking gpu containerd libvirt desktop_ui desktop tools user`. When a graphical terminal is present — detection order ptyxis, kitty, foot, gnome-terminal, xterm — the pull runs in a new terminal window; otherwise inline, teed to a session log under `~/.cache/syncopated/`. Forcing the desktop environment also passes `desktop_ui_environment` as an extra var. The consolidation is the point: the three steps this script replaced — cargo binaries, GNOME extensions, VS Code extensions — no longer have bootstrap scripts or manifests at all; the workstation `user` role converges them through the same pull ([Adding tools](#-adding-tools) has the re-run command).

## 🎛️ Host-specific behavior

The `alternates` built-in step renders the tree's two templates — `.zshrc##template.j2` and `.aliases##template.j2`, the only `##`-suffixed paths in the tree; every other payload file ships verbatim. Each template renders one concrete file per host from a single source. Take the theme selector as the example of the mechanism: `.zshrc##template.j2` branches it on the `HOSTNAME` variable — not `yadm.hostname`, not `YADM_HOSTNAME`:

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

Any hostname not in the block falls through to the `jaischeema` default — on gir, the rendered `~/.zshrc` reads `ZSH_THEME="gnzh"`.

`.aliases##template.j2` rides the same mechanism but branches on `YADM_HOSTNAME` — soundbot and gir each get audio/sampler aliases (`baudline_jack`, `pulse_list_sources`, `vnc_serv`, `soundsampler`, `samplerv2`) — and on `YADM_DISTRO` / `YADM_DISTRO_FAMILY` (`Fedora`, `Arch`); the standard aliases (`reboot`, `shutdown`, `btm`, `lsin`, `ls="eza -h --group-directories-first -g --icons auto"`) are the common base.

Adding a host needs one thing: a branch in the `ZSH_THEME` selector — or accept the `jaischeema` default.

One consequence of templating: because `yadm log`, `yadm status`, and `yadm diff` can change state, yadm re-renders both templates on every invocation, so those commands print the jinjanator banner twice, once per template — `j2 25.3.1, Jinja2 3.1.6`. That is the renderer announcing its version, not an error; jinjanator is installed per host, so the banner is host-dependent.

## 📦 What's in the repo

Host differences resolve at render time; the payload itself is one shared set. The tracked tree turns a bare host into a working workstation: a shell, a terminal, a file manager, a media player, a dictation pipeline, a knowledge base — and the control plane that puts every one of them in place. What each area gives a machine:

| Area | What it's for |
| --- | --- |
| shell/zsh | oh-my-zsh with a working plugin set (fzf, docker-compose, podman, ruby, systemd, …), 39 custom functions across 27 files under `.local/share/zsh/functions/` (`mkcd`, `dd_to_usb`, `rga-fzf`, and a yazi launcher), custom completions (`_gh` and `_rspec` among ten files in `completion/`; `_fd`, `_ripgrep`, `_crush` in `site-functions/`), and a homegrown theme file, `minimal-terminal-prompt` — shipped alongside the four upstream themes the template selector actually chooses |
| kitty | a themed terminal — `kitty.conf`, `current-theme.conf`, and a `kitty-themes/` directory |
| ranger | a heavily customized file manager: devicons for file icons, a zoxide plugin for jump navigation, and ranger-sox audio previews |
| mpv | a customized media player: nine lua scripts (autoload, playlist management, excerpting, web-download) with eight matching `script-opts` conf files |
| dev tooling | configs for crush, glow, micro, noisetorch, opencode, pip, qmd, weathr, and terrascope — the standout is omega13: a global `<ctrl>+<alt>+<space>` hotkey records audio and transcribes it via Whisper large-v3-turbo (a local GGUF model), routing the result to the clipboard or injecting it into the focused window (`.config/omega13/config.json`) |
| desktop | per-device key remaps for the actual keyboards in the house (Dell KB216, PowerMicII, SayoDevice 2x4F), Thunar custom actions, gowall `schema.yml`, GTK `settings.ini`, and `environment.d/00-arch.conf` |
| Obsidian vault | a personal knowledge base — 43 top-level areas, with a `Daily/` directory the omega13 recorder also writes to — whose configuration rides the clone (53 tracked files: `.obsidian/`, `_templates/`, `_textgenerator/`), while the notes themselves stay untracked |
| scripts | tracked automation for real workflows: NotebookLM batch transcription (`bin/batch_transcribe_notebooklm.sh`), ASS-to-JSONL conversion and JSON search (`Tools/bin/`), podman-volume backup/restore (`Tools/bin/podman-volume-backup-restore.sh`) |
| yadm control plane | the machinery that places everything above — the 504-line bootstrap orchestrator, the 6 `bootstrap.d/` steps, the 4 manifests, the `scripts/` helpers (`syncopated-theme.sh`, `gum-helpers.sh`, `ansible-runner.sh`, `rubymine-fetch`), and the 8-file bats suite |

The control plane is the one row that executes; every other row is payload it places. To see the raw tracked set for yourself, one command regenerates it: `yadm list -a`.

## 🧰 Adding tools

The manifests are the declarative half of the control plane: 4 plain-text files under `.config/yadm/files/`, 34 lines total. Three are consumed by exactly one `bootstrap.d/` script; the fourth is consumed by the orchestrator itself, as the package prelude every run starts with.

| Manifest | Lines | Consumed by |
| --- | ---: | --- |
| `bootstrap-system-packages.txt` | 7 | the orchestrator's `ensure_system_packages` prelude |
| `default-gems.txt` | 8 | `01-ruby.sh` |
| `ruby-system-packages.txt` | 13 | `01-ruby.sh` |
| `user-flatpaks.txt` | 6 | `80-install-user-flatpaks.sh` |
| Total | 34 | |

```console
# add a gem: edit one manifest line, re-run its step
$EDITOR ~/.config/yadm/files/default-gems.txt
~/.config/yadm/bootstrap --only ruby
```

What the manifests no longer cover — cargo binaries, GNOME extensions, VS Code extensions — moved to the Layer-1 `user` role: to add one now, edit the workstation repo and re-run the pull step (`SYNCOPATED_ANSIBLE_TAGS=user ~/.config/yadm/bootstrap --only ansible-pull`). Nothing is hidden behind a lockfile — to see the current set, read the file.

## 🧪 Testing

The control plane ships its own test suite: 8 `.bats` files under `.config/yadm/tests/` alongside the shared `helpers.bash`, named for the components they exercise — `ansible`, `bootstrap`, `desktop`, `distro`, `ruby`, `rubymine`, `theme`, `zsh`. All nine files are tracked; the formerly untracked pair `desktop.bats` and `rubymine.bats` joined the tree with the consolidation, and `cargo.bats`, `gnome-extensions.bats`, and `vscode.bats` were deleted with their steps. The repo sets `status.showuntrackedfiles=no`, so plain `yadm status` hides untracked files — `yadm status --porcelain -uall` shows the `??` entries. The runner is [bats][bats]: `bats tests/` from `~/.config/yadm` executes the suite.

## 📚 Further reading

The upstream projects and in-tree paths behind each layer, upstream docs first and the in-tree paths last:

- [yadm overview][yadm-overview] — how yadm manages `$HOME` as a bare repository
- [yadm alternates][yadm-alt] — the `##` suffix mechanism
- [yadm templates][yadm-tpl] — `##template.j2` and Jinja rendering
- [Charm Gum][gum] — the TUI menu library the bootstrap depends on
- [bats][bats] — the test runner
- [Syncopated workstation][sync] — Layer 1, the Ansible control repository the bootstrap pulls
- [Syncopated osbuild][osbuild] — Layer 0, the image-compose repository
- [bootstrap][bstrap] and [files][files] — the orchestrator and its manifests, in-tree

## 🤝 Contributing

This is a personal configuration repository, but issues and pull requests are welcome for generic bug fixes or portability improvements. The bootstrap orchestrator and the `tests/` suite are host-agnostic — no hostname, path, or machine-specific assumption; host-specific branching lives in the two templates (the theme selector, plus `HOSTNAME`/`YADM_HOSTNAME`/`YADM_DISTRO` conditionals) — so they port to any yadm machine unchanged. Host-specific configuration isn't a good fit.

## ⚖️ License

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
