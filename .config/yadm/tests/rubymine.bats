#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/85-rubymine.sh" "$T/yadm/bootstrap.d/"
  export RUBYMINE_INSTALL_DIR="$HOME/.local/share/JetBrains/RubyMine"
  export RUBYMINE_BIN_DIR="$HOME/.local/bin"
  export RUBYMINE_APPS_DIR="$HOME/.local/share/applications"

  # Default stub for curl: handles JetBrains release API and tarball download
  stub curl '
    echo "curl $*" >>"$T/calls"
    out=""
    url=""
    while [ $# -gt 0 ]; do
      if [ "$1" = "-o" ]; then
        out=$2
        shift 2
        continue
      fi
      url=$1
      shift
    done
    if [ -n "${CURL_FAIL:-}" ]; then
      exit 1
    fi
    if [[ "$url" == *"releases?code=RM"* ]]; then
      echo '\''{"RM":[{"version":"2026.2.4","downloads":{"linux":{"link":"https://download.jetbrains.com/ruby/RubyMine-2026.2.4.tar.gz"}}}]}'\''
      exit 0
    elif [ -n "$out" ]; then
      echo "dummy-tarball-content" >"$out"
      exit 0
    fi
    exit 0
  '

  # Default stub for tar: creates bin/rubymine.sh and bin/rubymine.svg in target directory
  stub tar '
    echo "tar $*" >>"$T/calls"
    if [ -n "${TAR_FAIL:-}" ]; then
      exit 1
    fi
    target_dir=""
    while [ $# -gt 0 ]; do
      if [ "$1" = "-C" ]; then
        target_dir=$2
        shift 2
        continue
      fi
      shift
    done
    if [ -n "$target_dir" ]; then
      mkdir -p "$target_dir/bin"
      touch "$target_dir/bin/rubymine.sh"
      chmod +x "$target_dir/bin/rubymine.sh"
      touch "$target_dir/bin/rubymine.svg"
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
  ! grep -q '^curl ' "$T/calls"
}

@test "skips with exit 2 when --skip-rubymine is passed" {
  run_rubymine --skip-rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine installation skipped"* ]]
  ! grep -q '^curl ' "$T/calls"
}

@test "skips with exit 2 when rubymine is in PATH" {
  stub rubymine 'true'
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^curl ' "$T/calls"
}

@test "skips with exit 2 when ~/.local/bin/rubymine exists" {
  mkdir -p "$RUBYMINE_BIN_DIR"
  touch "$RUBYMINE_BIN_DIR/rubymine"
  chmod +x "$RUBYMINE_BIN_DIR/rubymine"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^curl ' "$T/calls"
}

@test "skips with exit 2 when JetBrains RubyMine installation exists in ~/.local/share" {
  mkdir -p "$RUBYMINE_INSTALL_DIR/bin"
  touch "$RUBYMINE_INSTALL_DIR/bin/rubymine.sh"
  chmod +x "$RUBYMINE_INSTALL_DIR/bin/rubymine.sh"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^curl ' "$T/calls"
}

@test "skips with exit 2 when JetBrains Toolbox is installed" {
  stub jetbrains-toolbox 'true'
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^curl ' "$T/calls"
}

@test "skips with exit 2 when JetBrains Toolbox rubymine app directory exists" {
  mkdir -p "$HOME/.local/share/JetBrains/Toolbox/apps/rubymine"
  run_rubymine
  [ "$status" -eq 2 ]
  [[ $output == *"RubyMine is already installed"* ]]
  ! grep -q '^curl ' "$T/calls"
}

@test "fails with exit 1 when curl is missing" {
  rm "$T/bin/curl"
  run_rubymine
  [ "$status" -eq 1 ]
  [[ $output == *"curl and tar are required"* ]]
}

@test "fails with exit 1 when tar is missing" {
  rm "$T/bin/tar"
  run_rubymine
  [ "$status" -eq 1 ]
  [[ $output == *"curl and tar are required"* ]]
}

@test "downloads and installs RubyMine successfully" {
  run_rubymine
  [ "$status" -eq 0 ]
  grep -q 'https://download.jetbrains.com/ruby/RubyMine-2026.2.4.tar.gz' "$T/calls"
  grep -q "^tar .* -C $RUBYMINE_INSTALL_DIR --strip-components=1" "$T/calls"
  [ -L "$RUBYMINE_BIN_DIR/rubymine" ]
  [ "$(readlink "$RUBYMINE_BIN_DIR/rubymine")" = "$RUBYMINE_INSTALL_DIR/bin/rubymine.sh" ]
  [ -f "$RUBYMINE_APPS_DIR/jetbrains-rubymine.desktop" ]
  grep -q "Exec=\"$RUBYMINE_INSTALL_DIR/bin/rubymine.sh\" %f" "$RUBYMINE_APPS_DIR/jetbrains-rubymine.desktop"
  grep -q "Icon=$RUBYMINE_INSTALL_DIR/bin/rubymine.svg" "$RUBYMINE_APPS_DIR/jetbrains-rubymine.desktop"
  [[ $output == *"✓ RubyMine IDE"* ]]
}

@test "fails with exit 1 when tarball download fails" {
  export CURL_FAIL=1
  run_rubymine
  [ "$status" -eq 1 ]
  [[ $output == *"✗ RubyMine IDE"* ]]
}

@test "fails with exit 1 when tar extraction fails" {
  export TAR_FAIL=1
  run_rubymine
  [ "$status" -eq 1 ]
  [[ $output == *"✗ RubyMine IDE"* ]]
}

@test "master bootstrap registers rubymine step" {
  cp "$YADM_SRC/bootstrap" "$T/yadm/"
  printf 'NAME="Fedora Linux"\nVERSION_ID=43\n' >"$T/os-release"
  export SYNCOPATED_OS_RELEASE=$T/os-release
  printf '/usr/bin/zsh' >"$T/shell"
  stub yadm 'echo "yadm $*" >>"$T/calls"; exit 0'
  stub sudo 'echo "sudo $*" >>"$T/calls"; exit 0'
  stub getent 'echo "tester:x:1000:1000::/home/tester:$(cat "$T/shell")"'
  stub zsh 'true'
  stub j2 'true'
  stub uv 'echo "uv $*" >>"$T/calls"'

  run bash "$T/yadm/bootstrap" --only=rubymine </dev/null
  [ "$status" -eq 0 ]
  [[ $output == *"rubymine (ok)"* ]]
}
