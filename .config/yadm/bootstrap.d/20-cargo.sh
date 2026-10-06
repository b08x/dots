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

RUSTUP_URL=https://sh.rustup.rs
PACKAGES_FILE=$YADM_CONFIG_DIR/files/cargo-packages.txt
CARGO_CONFIG=$HOME/.cargo/config.toml

PATH=$HOME/.cargo/bin:$PATH
DID_WORK=0
FAILED=0

install_rustup() {
  if [[ -x $HOME/.cargo/bin/rustup ]]; then
    info "rustup is already installed"
    return 0
  fi
  local script rc
  info "Installing rustup"
  script=$(mktemp) || return 1
  if ! curl -fsSL --connect-timeout 15 -o "$script" "$RUSTUP_URL"; then
    rm -f "$script"
    err "Could not download the rustup installer"
    return 1
  fi
  # --no-modify-path: ~/.zshenv already sources ~/.cargo/env.
  sh "$script" -y --no-modify-path </dev/null
  rc=$?
  rm -f "$script"
  if ((rc != 0)); then
    err "The rustup installer failed"
    return 1
  fi
  DID_WORK=1
  ok "rustup installed"
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
    info "Installing $crate"
    if cargo install --locked "$crate" </dev/null; then
      DID_WORK=1
      ok "$crate installed"
    else
      err "$crate failed to install"
      FAILED=1
    fi
  done
  ((attempted == 0)) && info "All ${#wanted[@]} crates are already installed"
  return 0
}

main() {
  install_rustup || return "$RC_FAILED"
  configure_cargo
  install_crates || return "$RC_FAILED"
  ((FAILED)) && return "$RC_FAILED"
  ((DID_WORK)) && return "$RC_OK"
  return "$RC_SKIPPED"
}

main "$@"
