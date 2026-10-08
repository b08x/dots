#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/20-cargo.sh" "$T/yadm/bootstrap.d/"
  mkdir -p "$T/yadm/files"; cp "$YADM_SRC/files/cargo-packages.txt" "$T/yadm/files/"
  mkdir -p "$HOME/.cargo/bin"
  stub curl 'out=; while [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; url=$1; shift; done
echo "curl $url" >>"$T/calls"; echo "#installer" >"$out"'
  stub sh 'echo "sh $*" >>"$T/calls"'
  # cargo stub: `install --list` prints $T/installed as "name vX:" lines.
  stub cargo 'if [ "$1 $2" = "install --list" ]; then
  while read -r n; do [ -n "$n" ] && printf "%s v1.0.0:\n    %s\n" "$n" "$n"; done <"$T/installed"
else echo "cargo $*" >>"$T/calls"; [ "$3" = "${CARGO_FAIL:-none}" ] && exit 101; fi; exit 0'
  printf '#!/bin/sh\n' >"$HOME/.cargo/bin/rustup"
  chmod +x "$HOME/.cargo/bin/rustup"
  printf '[build]\njobs = 4\n' >"$HOME/.cargo/config.toml"
  grep -v '^#' "$T/yadm/files/cargo-packages.txt" >"$T/installed"
}
teardown() { cleanup_env; }

run_cargo() { run bash "$T/yadm/bootstrap.d/20-cargo.sh" </dev/null; }

@test "package list holds the 9 crates and no exa" {
  [ "$(grep -vc '^#' "$YADM_SRC/files/cargo-packages.txt")" -eq 9 ]
  for c in bottom choose du-dust git-cliff gping ripgrep_all sd gitui eza; do
    grep -qx "$c" "$YADM_SRC/files/cargo-packages.txt"
  done
  ! grep -qx exa "$YADM_SRC/files/cargo-packages.txt"
}

@test "runs rustup-init -y when rustup is missing" {
  rm "$HOME/.cargo/bin/rustup"
  run_cargo
  grep -q 'curl https://sh.rustup.rs' "$T/calls"
  grep -q 'sh .* -y --no-modify-path' "$T/calls"
  [ "$status" -eq 0 ]
}

@test "does not run the rustup installer when rustup exists" {
  run_cargo
  ! grep -q rustup "$T/calls"
}

@test "creates config.toml when absent" {
  rm "$HOME/.cargo/config.toml"
  run_cargo
  [ "$(cat "$HOME/.cargo/config.toml")" = $'[build]\njobs = 4' ]
  [ "$status" -eq 0 ]
}

@test "leaves a config that already has jobs = 4 byte-identical" {
  printf '[net]\nretry = 3\n[build]\njobs = 4\n' >"$HOME/.cargo/config.toml"
  before=$(md5sum <"$HOME/.cargo/config.toml")
  run_cargo
  [ "$(md5sum <"$HOME/.cargo/config.toml")" = "$before" ]
}

@test "warns and leaves a [build] section without jobs unchanged" {
  printf '[build]\ntarget-dir = "x"\n' >"$HOME/.cargo/config.toml"
  before=$(md5sum <"$HOME/.cargo/config.toml")
  run_cargo
  [ "$(md5sum <"$HOME/.cargo/config.toml")" = "$before" ]
  [[ $output == *"unchanged"* ]]
}

@test "appends [build] to a config without one" {
  printf '[net]\nretry = 3\n' >"$HOME/.cargo/config.toml"
  run_cargo
  grep -q '^jobs = 4' "$HOME/.cargo/config.toml"
  grep -q '^retry = 3' "$HOME/.cargo/config.toml"
}

@test "installs exactly the one missing crate" {
  grep -vx sd "$T/installed" >"$T/installed.new"
  mv "$T/installed.new" "$T/installed"
  run_cargo
  [ "$status" -eq 0 ]
  [ "$(grep -c '^cargo install' "$T/calls")" -eq 1 ]
  grep -qx 'cargo install --locked sd' "$T/calls"
}

@test "attempted installs equal missing crates" {
  : >"$T/installed"
  run_cargo
  [ "$(grep -c '^cargo install --locked' "$T/calls")" -eq 9 ]
}

@test "exits 2 when everything is installed" {
  run_cargo
  [ "$status" -eq 2 ]
  ! grep -q '^cargo' "$T/calls"
}

@test "a failing crate exits 1 and the remaining crates are still attempted" {
  : >"$T/installed"
  CARGO_FAIL=bottom run_cargo
  [ "$status" -eq 1 ]
  [ "$(grep -c '^cargo install --locked' "$T/calls")" -eq 9 ]
}

@test "falls back to CARGO_TMPDIR when TMPDIR does not permit execution" {
  local noexec_tmp="$T/noexec_tmp"
  mkdir -p "$noexec_tmp"
  chmod 500 "$noexec_tmp"
  TMPDIR="$noexec_tmp" run_cargo
  [ "$status" -eq 2 ]
  [[ $output == *"Configured TMPDIR="* ]]
}

@test "unsets CARGO_TARGET_DIR when pointing to non-executable directory" {
  local noexec_target="$T/noexec_target"
  mkdir -p "$noexec_target"
  chmod 500 "$noexec_target"
  CARGO_TARGET_DIR="$noexec_target" run_cargo
  [ "$status" -eq 2 ]
  [[ $output == *"is not executable; unsetting"* ]]
}
