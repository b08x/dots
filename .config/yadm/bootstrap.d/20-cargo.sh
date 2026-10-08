#!/usr/bin/env bash
# 20-cargo.sh: install rustup, configure cargo, and install the crates listed
# in cargo-packages.txt that are not installed yet.
#
# Exits 0 when something was done, 2 when everything was already in place,
# 1 on any failure. Crate failures do not stop the remaining crates.

set -uo pipefail

YADM_CONFIG_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..
# shellcheck source=../scripts/syncopated-theme.sh
source "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh"

: "${SYNCOPATED_STEP:=cargo}"

CARGO_HOME=${CARGO_HOME:-$HOME/.cargo}
CARGO_TMPDIR=${CARGO_TMPDIR:-$CARGO_HOME/tmp}
RUSTUP_URL=https://sh.rustup.rs
PACKAGES_FILE=$YADM_CONFIG_DIR/files/cargo-packages.txt
CARGO_CONFIG=$CARGO_HOME/config.toml

PATH=$CARGO_HOME/bin:$PATH
DID_WORK=0
FAILED=0
CARGO_TMPDIR_CREATED=""

cleanup_tmpdir() {
  if [[ -n $CARGO_TMPDIR_CREATED && -d $CARGO_TMPDIR_CREATED ]]; then
    rmdir "$CARGO_TMPDIR_CREATED" 2>/dev/null || true
  fi
}
trap cleanup_tmpdir EXIT

# can_execute_in DIR : verify that binaries or scripts can be executed in DIR.
# Returns 0 if execution succeeds, 1 if blocked (e.g. noexec mount).
can_execute_in() {
  local dir=$1 testfile rc=1
  [[ -d $dir && -w $dir ]] || return 1
  testfile=$(mktemp -p "$dir" .can_exec.XXXXXX 2>/dev/null) || return 1
  chmod 700 "$testfile" 2>/dev/null || { rm -f "$testfile"; return 1; }
  printf '#!/bin/sh\nexit 0\n' >"$testfile" 2>/dev/null
  if [[ -x $testfile ]] && "$testfile" 2>/dev/null; then
    rc=0
  fi
  rm -f "$testfile"
  return "$rc"
}

# setup_tmpdir : detect whether /tmp (or current TMPDIR) is mounted with noexec.
# When execution is blocked, configure and export TMPDIR to point to an executable
# directory under CARGO_HOME so rustup-init, cargo, and build.rs scripts succeed.
setup_tmpdir() {
  local current_tmp="${TMPDIR:-/tmp}"
  if ! can_execute_in "$current_tmp"; then
    local fallback_tmp="${CARGO_TMPDIR:-$CARGO_HOME/tmp}"
    if [[ ! -d $fallback_tmp ]]; then
      mkdir -p "$fallback_tmp" || {
        err "Could not create temporary directory: $fallback_tmp"
        return 1
      }
      chmod 700 "$fallback_tmp" 2>/dev/null || true
      CARGO_TMPDIR_CREATED="$fallback_tmp"
    fi

    if ! can_execute_in "$fallback_tmp"; then
      err "Temporary directory $fallback_tmp does not permit execution"
      return 1
    fi

    export TMPDIR="$fallback_tmp"
    info "Configured TMPDIR=$TMPDIR ($current_tmp does not permit execution)"
  fi

  if [[ -n ${CARGO_TARGET_DIR:-} ]] && ! can_execute_in "$CARGO_TARGET_DIR"; then
    warn "CARGO_TARGET_DIR ($CARGO_TARGET_DIR) is not executable; unsetting"
    unset CARGO_TARGET_DIR
  fi

  return 0
}

# rustup_install URL : download the rustup installer and run it. Runs inside
# run_item, so it must not depend on this script's variables.
rustup_install() {
  local script rc
  script=$(mktemp) || return 1
  if ! curl -fsSL --connect-timeout 15 -o "$script" "$1"; then
    rm -f "$script"
    echo "Could not download the rustup installer" >&2
    return 1
  fi
  # --no-modify-path: ~/.zshenv already sources ~/.cargo/env.
  sh "$script" -y --no-modify-path </dev/null
  rc=$?
  rm -f "$script"
  return "$rc"
}

install_rustup() {
  if [[ -x $CARGO_HOME/bin/rustup ]]; then
    info "rustup is already installed"
    return 0
  fi
  run_item "Rust toolchain" rustup_install "$RUSTUP_URL" || return 1
  DID_WORK=1
}

configure_cargo() {
  if [[ ! -f $CARGO_CONFIG ]]; then
    mkdir -p "$(dirname "$CARGO_CONFIG")"
    printf '[build]\njobs = 4\n' >"$CARGO_CONFIG"
    DID_WORK=1
    ok "Created $CARGO_CONFIG with jobs = 4"
  elif grep -q '^jobs *= *4' "$CARGO_CONFIG"; then
    info "cargo already builds with jobs = 4"
  elif grep -q '^\[build\]' "$CARGO_CONFIG"; then
    warn "$CARGO_CONFIG has a [build] section without jobs = 4; leaving it unchanged"
  else
    printf '\n[build]\njobs = 4\n' >>"$CARGO_CONFIG"
    DID_WORK=1
    ok "Added jobs = 4 to $CARGO_CONFIG"
  fi
}

install_crates() {
  if ! command -v cargo >/dev/null 2>&1; then
    err "cargo is not available"
    return 1
  fi
  if [[ ! -r $PACKAGES_FILE ]]; then
    err "Package list not found: $PACKAGES_FILE"
    return 1
  fi

  local wanted=() installed crate attempted=0
  mapfile -t wanted < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$PACKAGES_FILE" | grep -v '^$')
  installed=$(cargo install --list 2>/dev/null | awk '/^[^ ]/{print $1}')

  for crate in "${wanted[@]}"; do
    if grep -qx -- "$crate" <<<"$installed"; then
      continue
    fi
    attempted=$((attempted + 1))
    if run_item "$(item_label "$crate")" cargo install --locked "$crate"; then
      DID_WORK=1
    else
      FAILED=1
    fi
  done
  ((attempted == 0)) && info "All ${#wanted[@]} crates are already installed"
  return 0
}

main() {
  setup_tmpdir || return "$RC_FAILED"
  install_rustup || return "$RC_FAILED"
  configure_cargo
  install_crates || return "$RC_FAILED"
  ((FAILED)) && return "$RC_FAILED"
  ((DID_WORK)) && return "$RC_OK"
  return "$RC_SKIPPED"
}

main "$@"
