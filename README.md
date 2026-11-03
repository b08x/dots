<div align="center">

# dots

**Personal workstation configuration for four hosts — soundbot, ninjabot, gir, tinybot — managed with yadm, Jinja2 multi-host templating, and a Charm Gum TUI.**

[![yadm](https://img.shields.io/badge/managed%20by-yadm-2f2f2f?logo=git&logoColor=white)][yadm-overview]
[![shell](https://img.shields.io/badge/shell-Bash%20%2F%20Zsh-4EAA25?logo=gnu-bash&logoColor=white)](https://www.zsh.org)
[![tests](https://img.shields.io/badge/tests-bats-9B59B6)][bats]
[![license](https://img.shields.io/badge/license-Proprietary-red)](#license)

</div>

## What this is

This repository is a yadm-managed dotfiles tree whose work tree *is* `$HOME`: yadm treats `$HOME` as a bare git repository with origin `git@github.com:b08x/dots.git`, so this README lives at `~/README.md` and is tracked by the very repository it describes (`yadm remote -v` prints the origin). None of the 226 tracked files is a symlink — a `[ -L ]` scan over every tracked path returns zero matches — which sounds like a universal about `$HOME`, and isn't: the bootstrap itself creates runtime symlinks outside the tracked tree (`85-rubymine.sh:121` links `~/.local/bin/rubymine`). Tracked files sit at their real paths unless a `##template.j2` renders a host-specific name; every clone carries the full history — 199 commits at last count (`yadm log --oneline | wc -l`) — distinct from the 199 payload files counted below; and I run this same repository on all four machines — the same four hostnames that branch the theme selector at `~/.zshrc##template.j2:19-29`.

## Tracked dotfiles

The inventory of tracked files regenerates from one command: run `yadm list -a` and read its stdout. That command currently reports 226 tracked files, and it exits 0 with empty stderr. The `j2 25.3.1, Jinja2 3.1.6` line belongs to git passthrough commands — `yadm log`, `yadm status`, `yadm diff` — which flag themselves (`CHANGES_POSSIBLE=1`, `/usr/bin/yadm:1165`), trigger alt processing (:2087-2094), and render the 2 tracked `##template.j2` files through the `j2` binary (:496-508); jinjanator prints its banner on every invocation, so those commands print it exactly twice — which looks like an error, but is the renderer announcing its version, once per template. Those 226 files distribute as follows:

| Category | Count |
| --- | ---: |
| shell/zsh — completions, functions, themes, `.zshrc##template.j2`, `.aliases##template.j2`, `.zlogin`, `.zprofile`, `.zshenv`, `.profile` | 47 |
| Obsidian Notebook vault — `Notebook/**`: vault config, templates, textgenerator templates | 53 |
| mpv — `.config/mpv/**`: conf, `input.conf`, 10 lua scripts, 9 script-opts, fonts | 24 |
| GNOME / input-remapper / desktop — 9 `input-remapper-2` files incl. 7 presets, 4 `input-remapper` presets, kando 2, gtk-3.0/gtk-4.0 `settings.ini`, gowall `schema.yml`, `environment.d/00-arch.conf` | 19 |
| yadm infrastructure — `.config/yadm/**` | 27 |
| ranger — `.config/ranger/**` incl. `plugins/zoxide/` | 12 |
| dev tooling — `.config/{crush,micro,noisetorch,omega13,opencode,pip,qmd,tooling,voxtype,weathr}` | 11 |
| scripts — `Tools/bin` 5, `Tools/lib` 2, `bin` 2 | 9 |
| top-level / misc — `.gitconfig`, `.ssh/config`, `.cargo/config.toml`, `.gemrc`, `README.md`, `.yadmignore`, etc. | 14 |
| kitty — `kitty.conf`, `current-theme.conf`, `Treehouse.conf` | 3 |
| Thunar — `accels.scm`, `renamerrc`, `uca.xml` | 3 |
| other `.config` — `htoprc`, Obsidian `Custom Dictionary.txt`, `user-dirs.dirs`, `xdg-terminals.list` | 4 |

Of those 226 files, the 27 under `.config/yadm/**` are this repository's own control plane: the 440-line `bootstrap` orchestrator, `encrypt`, `.shellcheckrc`, the 8 tracked `bootstrap.d/` scripts, the 5 `files/` manifests, the 2 `scripts/` helpers, and the 9 `tests/` files — 27 in all. Those 27 files configure the other 199 — the payload.

Those two banner lines are host-dependent — jinjanator is installed per host. I cannot verify that the other three hosts print them. *Escape Hatch:* run `yadm log --oneline` on soundbot, ninjabot, and tinybot and count the `j2` banner lines — two per host with both templates tracked.

## Three layers

This dotfiles repository is Layer 2 of a three-layer *Syncopated* stack, and each layer draws a different boundary around "the machine." Layer 0 is the osbuild repository at the local checkout `~/WorkspaceV3/Syncopated/osbuild` (origin `git@gitlab.com:syncopatedX/osbuild.git`, GitHub mirror `git@github.com:b08x/osbuild.git`): *"An Ansible build repository for composing workstation images — unattended installer ISOs, bootc containers, application containers, and Vagrant boxes — for Fedora, AlmaLinux, and Rocky Linux, on Red Hat image-builder and osbuild"* (`~/WorkspaceV3/Syncopated/osbuild/README.md:5-12`). Its supported matrix is the widest by count — five release lines across three distributions (Fedora 43|44, AlmaLinux 10, Rocky 9|10) against workstation's three (`~/WorkspaceV3/Syncopated/workstation/README.md:5-7`) — under `ansible-core>=2.15.0` with `ansible.utils>=2.10.0` and `containers.podman>=1.10.0`, and its own README states the division of labor plainly: *"where workstation converges machines into correctness after they exist, this one composes correctness into the machine before it exists."*

Layer 1 is the workstation control repository at the local checkout `~/WorkspaceV3/Syncopated/workstation` (origin `git@gitlab.com:syncopatedX/workstation.git`, GitHub mirror `https://github.com/b08x/ansible-workstation.git`): *"An Ansible control repository provisioning Fedora 44 / AlmaLinux 10 / Rocky Linux 10 workstations. Ten roles. ansible-core >= 2.15, Python 3.12+ (3.14 aligned), x86_64, root required"* (workstation/README.md:5-7). workstation/README.md:25-31 defines the whole stack — *"Layer 0 is one of two base-system paths… composed in the companion osbuild repository… Layer 1 is this repository, Ansible orchestration for everything the host itself is; Layer 2 is yadm, your dotfiles, the one layer a re-image does not erase."*

Layer 2 is this repository. When the `01-ansible-pull.sh` bootstrap step runs, it does *not* read the local checkout at `~/WorkspaceV3/Syncopated/workstation`; it pulls the GitLab remote `https://gitlab.com/syncopatedX/workstation.git`, branch `development`, and applies `local.yml` (15,960 bytes) with `--tags user` — the user-space subset of the Layer-1 playbook.

## The bootstrap

The bootstrap is the 440-line orchestrator at `.config/yadm/bootstrap`, and a plain checkout does not run it unprompted: `yadm clone` asks — *"It appears that a bootstrap program exists. Would you like to execute it now? (y/n)"* (`/usr/bin/yadm:2111-2127`) — and runs it only on an affirmative answer; `yadm clone --bootstrap` forces it without asking, and `--no-bootstrap` prevents it (:773-785). Its usage is `bootstrap [--all | --only STEP[,STEP...]]` (bootstrap:65); flags parse at :72-82; and an unknown step name exits with status 2 via `validate_only` (:343-350).

At `.config/yadm/bootstrap:409-412`, four built-in steps register in exact order, and then every executable in `bootstrap.d/` runs in name order (:413, `discover_scripts` :255):

1. **preflight** (`check_drift_and_collisions`, :91-174) — runs `yadm status --porcelain` (:99), scans `yadm ls-files | grep '##'` for alternate/template targets (:100-104), and offers a gum choice of *"Backup, Diff & Proceed" / "Overwrite & Proceed" / "Abort"* (:121-122); backup writes to `mktemp -d "/tmp/yadm_backup_$(date +%s)_XXX"` (:130).
2. **shell** (`step_shell`, :176-190) — runs `sudo usermod -s zsh` (:189) and returns 2 if the shell is already zsh (:182).
3. **decrypt** (:192-205) — runs `yadm decrypt`.
4. **alternates** (:207-238) — renders templates; when the `j2` CLI is missing it installs jinjanator with `uv tool install jinjanator` (:219, :222) — not `dnf`, not `pip` — and requires uv, failing with the verbatim message `"uv is not installed; install it to set up templates"` (:214).

The step interface is a three-valued exit convention — 0 ok, 1 failed, 2 skipped (header :8-10; constants `RC_OK=0 RC_FAILED=1 RC_SKIPPED=2` in `scripts/syncopated-theme.sh:15-17`; mapped in `run_step` at bootstrap:317-320). A script declares `# bootstrap: needs-sudo` (e.g. `20-cargo.sh:7`), which bootstrap checks at :384; sudo is authenticated up front via `sudo -v` (:428-430) because *"gum spin hides stdin"* (:427). Everything logs to `$HOME/.bootstrap.log` (bootstrap:30). On failure in interactive mode, `run_step` offers retry/skip/abort (:311-337); in non-interactive mode failures are recorded and the run continues, and the final report exits 1 if any step failed (:272-305).

Step selection itself goes through gum — the Charm Gum prompt library the tagline names: bootstrap calls `choose_many "Select the steps to run"` (:368), defined in `scripts/syncopated-theme.sh:502-530` — with gum, `gum choose --no-limit --ordered`; without it, a numbered prompt on stderr reads selections from stdin, and an empty line selects every step (:517-519). A missing gum therefore narrows the menu to a stdin prompt; it does not disable it — `ensure_gum` (:97-107) installs gum with `sudo dnf install -y gum` (:100) and only warns with the gum GitHub URL when it cannot (:103).

`bootstrap.d/` holds 9 executable scripts on disk; of those 9, 8 are tracked, and the untracked one is marked below. Four of the nine — `01-ansible-pull.sh`, `10-zsh.sh`, `85-rubymine.sh`, `90-obsidian-flatpak-setup.sh` — consume no `files/` manifest at all.

| Script | Tracked | Manifest | What it does |
| --- | --- | --- | --- |
| `01-ansible-pull.sh` | yes | none | Opt-in Layer-1 apply: `ansible-pull --ask-become-pass --url https://gitlab.com/syncopatedX/workstation.git --directory $HOME/.cache/syncopated/ansible-pull --inventory "<hostname>," --checkout development --tags user local.yml` (args assembled :84-92). Pull URL defaults to `https://gitlab.com/syncopatedX/workstation.git` (:39, overridable via `SYNCOPATED_ANSIBLE_PULL_URL`); opt-in via `SYNCOPATED_ANSIBLE_PULL=yes|no` (:9) or gum confirm (:58-66). Declined, no URL, or missing `ansible-pull` → exit 2 (:71,:75,:79); pull failure → exit 1 (:103). It applies the *user-space* playbook with `--tags user`. |
| `10-zsh.sh` | yes | none | Installs oh-my-zsh and zoxide from their upstream install scripts (:17-18) with `KEEP_ZSHRC=yes CHSH=no RUNZSH=no --unattended` (:43); both installs are idempotent (already-installed checks :64-65, :73) and neither touches `~/.zshrc`. |
| `20-cargo.sh` | yes | `cargo-packages.txt` (:19) | Installs the 11 manifest tools in precedence order: a tool already on PATH is silently skipped (:177-178); the three crates mapped by `crate_to_dnf` (`dua-cli`, `gitui`, `eza`) install via `sudo dnf install -y` first (:89-98, :195); every other crate compiles via `cargo install --locked` (:214). |
| `30-ruby.sh` | yes | `default-gems.txt` (:20) | Installs the 8 default gems either under the system Ruby via `gem install --user-install --bindir $HOME/.local/bin` (:222) or, with `USE_RBENV=1` (:94-97), under rbenv pinned to Ruby 4.0.4 (`RUBY_VERSION_WANTED=4.0.4`, :19; `rbenv install`, :139) via `rbenv exec gem install` (:189). |
| `40-gnome-extensions.sh` | yes | `gnome-extensions.txt` (:21) | Installs/enables GNOME extensions; exits 2 when the desktop is not gnome (:21-23). |
| `80-install-user-flatpaks.sh` | yes | `user-flatpaks.txt` (:15) | Ensures the per-user flathub remote (`flatpak remote-add --user --if-not-exists`, :34), then runs `flatpak install -y --user flathub` per manifest entry (:52), skipping entries already installed (:47-48). |
| `85-rubymine.sh` | *untracked* | none | Installs JetBrains RubyMine from the official Linux tarball via the JetBrains releases API (`JETBRAINS_API_URL=...`), extracts to `~/.local/share/JetBrains/RubyMine`, symlinks `~/.local/bin/rubymine` (`ln -sf`, :121), and writes `~/.local/share/applications/jetbrains-rubymine.desktop` (:129). |
| `90-obsidian-flatpak-setup.sh` | yes | none | Opt-in vault setup (`SYNCOPATED_OBSIDIAN=yes|no` bypass or gum confirm, :167-174; declined → exit 2, :277-278): creates the vault at `~/Notebook` by default (:186) with a `Daily/` directory (:205-206) and enables 68 plugins enumerated at :29-98. It does not install the Obsidian Flatpak — `80-install-user-flatpaks.sh` owns that (`md.obsidian.Obsidian` is line 1 of `user-flatpaks.txt`; this script only warns if it is absent, :229-230, and can launch it, :237). |
| `91-install-vscode-extensions.sh` | yes | `vscode-extensions.txt` (:17) | Detects the target in order — `$VSCODE_CMD` override, native `code` on PATH, then the Flatpak `com.visualstudio.code` (:23-39) — and installs each of the 68 manifest extensions with one shared `--install-extension` call (:78), skipping those already present (:55). |

## Multi-host templates

Templating is how those 226 files stay in one branch across four hosts: of the 199 payload files outside `.config/yadm/**`, exactly 2 carry the `##template.j2` suffix — `.zshrc##template.j2` and `.aliases##template.j2`, the only `##`-suffixed paths `yadm list -a` reports — and those 2 render per host; the remaining 197 ship verbatim. At `~/.zshrc##template.j2:19-29`, the theme selector branches on the `HOSTNAME` variable — not `yadm.hostname`, not `YADM_HOSTNAME`:

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

That template renders one line per host — `strug` on soundbot, `jaischeema` on ninjabot, `gnzh` on gir, `xiong-chiamiov` on tinybot, and `jaischeema` as the default for any other host — and the render is verifiable: on gir, `/home/b08x/.zshrc` line 20 reads `ZSH_THEME="gnzh"`.

`~/.aliases##template.j2` rides the same mechanism but carries no `HOSTNAME` branch anywhere in its body (`grep -c HOSTNAME` returns 0), so every host renders it identically by construction — standard aliases (`reboot`, `shutdown`, `btm`, `lsin`, `ls="eza -h --group-directories-first -g --icons auto"`).

## Package manifests

The manifests are the declarative half of the control plane: 5 plain-text files under `.config/yadm/files/`, 99 lines total, each consumed by exactly one `bootstrap.d/` script. Those 99 lines break down as:

| Manifest | Lines | Consumed by |
| --- | ---: | --- |
| `cargo-packages.txt` | 11 | `20-cargo.sh` |
| `default-gems.txt` | 8 | `30-ruby.sh` |
| `gnome-extensions.txt` | 6 | `40-gnome-extensions.sh` |
| `user-flatpaks.txt` | 6 | `80-install-user-flatpaks.sh` |
| `vscode-extensions.txt` | 68 | `91-install-vscode-extensions.sh` |
| Total | 99 | |

To add a tool, edit one line of one manifest and re-run the corresponding step with `bootstrap --only <step>`; to see the current set, read the file — nothing is hidden behind a lockfile.

## Testing

The control plane ships its own test suite: 10 `.bats` files sit on disk under `.config/yadm/tests/` alongside the shared `helpers.bash`, named for the components they exercise — `ansible-pull.bats`, `bootstrap.bats`, `cargo.bats`, `desktop.bats`, `gnome-extensions.bats`, `ruby.bats`, `rubymine.bats`, `theme.bats`, `vscode.bats`, `zsh.bats`. Of those 10, 8 are tracked; `desktop.bats` and `rubymine.bats` show as `??` in `yadm status --porcelain -uall` (this repo sets `status.showuntrackedfiles=no`, which hides them from plain `yadm status`), matching the untracked `85-rubymine.sh`. The runner is [bats][bats]: `bats .config/yadm/tests/` executes the suite.

I cannot verify whether those three untracked yadm files — `bootstrap.d/85-rubymine.sh`, `tests/desktop.bats`, `tests/rubymine.bats` — will be committed. *Escape Hatch:* `yadm status --porcelain -uall` after the next commit shows whether the `??` entries clear.

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

This is a personal configuration repository, but issues and pull requests are welcome for generic bug fixes or portability improvements — specifically in the bootstrap orchestrator and the `tests/` suite, where the code is verifiably host-agnostic — a word-boundary grep for `soundbot|ninjabot|gir|tinybot` over `bootstrap` and all 10 `tests/*.bats` returns zero matches — so it ports to any yadm machine unchanged.

## License

Personal configuration. All rights reserved. Intended for private reference and reproduction.

[bstrap]: https://github.com/b08x/dots/blob/main/.config/yadm/bootstrap
[files]: https://github.com/b08x/dots/tree/main/.config/yadm/files
[sync]: https://gitlab.com/syncopatedX/workstation
[osbuild]: https://gitlab.com/syncopatedX/osbuild
[yadm-overview]: https://yadm.io/docs/overview
[yadm-alt]: https://yadm.io/docs/alternates
[yadm-tpl]: https://yadm.io/docs/templates
[gum]: https://github.com/charmbracelet/gum
[bats]: https://github.com/bats-core/bats-core
