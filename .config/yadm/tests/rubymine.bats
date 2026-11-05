#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/85-rubymine.sh" "$T/yadm/bootstrap.d/"
  export RUBYMINE_INSTALL_DIR="$HOME/.local/share/JetBrains/RubyMine"
  export RUBYMINE_BIN_DIR="$HOME/.local/bin"
  export RUBYMINE_OPT_DIR="$T/opt/rubymine"

  # Default stub for sudo
  stub sudo '
    echo "sudo $*" >>"$T/calls"
    if [ -n "${SUDO_FAIL:-}" ]; then
      exit 1
    fi
    if [ "$1" = "dnf" ] && [ -n "${DNF_INSTALL_FAIL:-}" ]; then
      exit 1
    fi
    exit 0
  '

  # Default stub for dnf: by default rubymine package is not in repos
  stub dnf '
    echo "dnf $*" >>"$T/calls"
    if [ "$1" = "info" ] && [ "$2" = "rubymine" ]; then
      if [ -n "${DNF_HAS_RUBYMINE:-}" ]; then
        exit 0
      fi
      exit 1
    fi
    if [ "$1" = "install" ]; then
      if [ -n "${DNF_INSTALL_FAIL:-}" ]; then
        exit 1
      fi
      exit 0
    fi
    exit 0
  '
}

teardown() { cleanup_env; }

run_rubymine() { run bash "$T/yadm/bootstrap.d/85-rubymine.sh" "$@" </dev/null; }

@test "skips with exit 2 when SYNCOPATED_SKIP_RUBYMINE=1" {
  export SYNCOPATED_SKIP_RUBYMINE=1
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine installation skipped"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when --skip-rubymine is passed" {
  run_rubymine --skip-rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine installation skipped"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when rubymine is in PATH" {
  stub rubymine 'true'
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when ~/.local/bin/rubymine exists" {
  mkdir -p "$RUBYMINE_BIN_DIR"
  touch "$RUBYMINE_BIN_DIR/rubymine"
  chmod +x "$RUBYMINE_BIN_DIR/rubymine"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when /usr/bin/rubymine exists" {
  touch "$T/bin/rubymine"
  chmod +x "$T/bin/rubymine"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when /opt/rubymine/bin/rubymine exists" {
  mkdir -p "$RUBYMINE_OPT_DIR/bin"
  touch "$RUBYMINE_OPT_DIR/bin/rubymine"
  chmod +x "$RUBYMINE_OPT_DIR/bin/rubymine"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when /opt/rubymine/bin/rubymine.sh exists" {
  mkdir -p "$RUBYMINE_OPT_DIR/bin"
  touch "$RUBYMINE_OPT_DIR/bin/rubymine.sh"
  chmod +x "$RUBYMINE_OPT_DIR/bin/rubymine.sh"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when JetBrains RubyMine installation exists in ~/.local/share" {
  mkdir -p "$RUBYMINE_INSTALL_DIR/bin"
  touch "$RUBYMINE_INSTALL_DIR/bin/rubymine.sh"
  chmod +x "$RUBYMINE_INSTALL_DIR/bin/rubymine.sh"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when JetBrains Toolbox is installed" {
  stub jetbrains-toolbox 'true'
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when JetBrains Toolbox rubymine app directory exists" {
  mkdir -p "$HOME/.local/share/JetBrains/Toolbox/apps/rubymine"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^dnf ' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when rubymine is installed via rpm" {
  stub rpm '
    echo "rpm $*" >>"$T/calls"
    if [ "$1" = "-q" ] && [ "$2" = "rubymine" ]; then
      exit 0
    fi
    exit 1
  '
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  grep -q '^rpm -q rubymine' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "skips with exit 2 when rubymine is installed via flatpak" {
  stub flatpak '
    echo "flatpak $*" >>"$T/calls"
    if [ "$1" = "info" ] && [ "$2" = "com.jetbrains.RubyMine" ]; then
      exit 0
    fi
    exit 1
  '
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  grep -q '^flatpak info com.jetbrains.RubyMine' "$T/calls"
  ! grep -q '^sudo ' "$T/calls"
}

@test "installs RubyMine via dnf when available in package repository" {
  export DNF_HAS_RUBYMINE=1
  run_rubymine
  [ "$status" -eq 0 ]
  grep -q '^dnf info rubymine' "$T/calls"
  grep -q '^sudo dnf install -y rubymine' "$T/calls"
  [[ $output == *"✓ RubyMine IDE"* ]]
  ! grep -q 'rubymine-fetch' "$T/calls"
}

@test "falls back to rubymine-fetch when package is not in dnf repository" {
  run_rubymine
  [ "$status" -eq 0 ]
  grep -q '^dnf info rubymine' "$T/calls"
  grep -q "^sudo $T/yadm/scripts/rubymine-fetch" "$T/calls"
  [[ $output == *"✓ RubyMine IDE"* ]]
}

@test "falls back to rubymine-fetch when dnf install fails" {
  export DNF_HAS_RUBYMINE=1
  export DNF_INSTALL_FAIL=1
  run_rubymine
  [ "$status" -eq 0 ]
  grep -q '^dnf info rubymine' "$T/calls"
  grep -q '^sudo dnf install -y rubymine' "$T/calls"
  grep -q "^sudo $T/yadm/scripts/rubymine-fetch" "$T/calls"
  [[ $output == *"✓ RubyMine IDE"* ]]
}

@test "falls back to rubymine-fetch when dnf is not present" {
  rm -f "$T/bin/dnf"
  run_rubymine
  [ "$status" -eq 0 ]
  ! grep -q '^dnf ' "$T/calls"
  grep -q "^sudo $T/yadm/scripts/rubymine-fetch" "$T/calls"
  [[ $output == *"✓ RubyMine IDE"* ]]
}

@test "respects RUBYMINE_FETCH_PATH override" {
  custom_fetch="$T/custom-rubymine-fetch"
  printf '#!/bin/sh\nexit 0\n' >"$custom_fetch"
  chmod +x "$custom_fetch"
  export RUBYMINE_FETCH_PATH="$custom_fetch"

  run_rubymine
  [ "$status" -eq 0 ]
  grep -q "^sudo $custom_fetch" "$T/calls"
  [[ $output == *"✓ RubyMine IDE"* ]]
}

@test "falls back to WorkspaceV3 path when bundled rubymine-fetch is absent" {
  rm -f "$T/yadm/scripts/rubymine-fetch"
  ws_fetch="$T/ws-rubymine-fetch"
  printf '#!/bin/sh\nexit 0\n' >"$ws_fetch"
  chmod +x "$ws_fetch"
  export SYNCOPATED_RUBYMINE_WORKSPACE_FETCH="$ws_fetch"

  run_rubymine
  [ "$status" -eq 0 ]
  grep -q "^sudo $ws_fetch" "$T/calls"
  [[ $output == *"✓ RubyMine IDE"* ]]
}

@test "falls back to rubymine-fetch in PATH when other paths are absent" {
  rm -f "$T/yadm/scripts/rubymine-fetch"
  export SYNCOPATED_RUBYMINE_WORKSPACE_FETCH="$T/nonexistent"
  stub rubymine-fetch 'exit 0'

  run_rubymine
  [ "$status" -eq 0 ]
  grep -q "^sudo $T/bin/rubymine-fetch" "$T/calls"
  [[ $output == *"✓ RubyMine IDE"* ]]
}

@test "fails with exit 1 when rubymine is not in dnf and rubymine-fetch cannot be found" {
  rm -f "$T/yadm/scripts/rubymine-fetch"
  export SYNCOPATED_RUBYMINE_WORKSPACE_FETCH="$T/nonexistent"

  run_rubymine
  [ "$status" -eq 1 ]
  [[ $output == *"✗ RubyMine IDE"* ]]
  [[ $output == *"Could not find rubymine-fetch"* ]]
}

@test "fails with exit 1 when rubymine-fetch fails" {
  export SUDO_FAIL=1
  run_rubymine
  [ "$status" -eq 1 ]
  [[ $output == *"✗ RubyMine IDE"* ]]
}

@test "master bootstrap registers rubymine step and recognizes needs-sudo" {
  cp "$YADM_SRC/bootstrap" "$T/yadm/"
  printf 'NAME="Fedora Linux"\nVERSION_ID=43\n' >"$T/os-release"
  export SYNCOPATED_OS_RELEASE=$T/os-release
  printf '/usr/bin/zsh' >"$T/shell"
  stub yadm 'echo "yadm $*" >>"$T/calls"; exit 0'
  stub getent 'echo "tester:x:1000:1000::/home/tester:$(cat "$T/shell")"'
  stub zsh 'true'
  stub j2 'true'
  stub uv 'echo "uv $*" >>"$T/calls"'

  # Verify header declaration
  grep -q '^# bootstrap: needs-sudo' "$T/yadm/bootstrap.d/85-rubymine.sh"

  export SYNCOPATED_FORCE_INTERACTIVE=1
  run bash "$T/yadm/bootstrap" --only=rubymine </dev/null
  [ "$status" -eq 0 ]
  [[ $output == *"rubymine (ok)"* ]]
  grep -q '^sudo -v' "$T/calls"
}
