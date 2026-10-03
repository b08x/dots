#!/usr/bin/env bash
# 10-zsh.sh: install oh-my-zsh and zoxide for the current user.
#
# Skips each part that is already installed. Exits 0 when something was
# installed, 2 when everything was already present, 1 on any failure.
# Never modifies ~/.zshrc (KEEP_ZSHRC=yes).
#
# Override (used by the bats tests): SYNCOPATED_SYSTEM_OMZ.

set -uo pipefail

# shellcheck source=../scripts/syncopated-theme.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../scripts/syncopated-theme.sh"

OMZ_URL=https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
ZOXIDE_URL=https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh
SYSTEM_OMZ=${SYNCOPATED_SYSTEM_OMZ:-/usr/share/oh-my-zsh}

# download URL : download an installer to a temp file and print its path.
download() {
  local tmp
  tmp=$(mktemp) || return 1
  if ! curl -fsSL --connect-timeout 15 -o "$tmp" "$1"; then
    rm -f "$tmp"
    return 1
  fi
  printf '%s\n' "$tmp"
}

# install_omz : 0 installed, 2 already present, 1 failed.
install_omz() {
  if [[ -d $HOME/.oh-my-zsh || -d $SYSTEM_OMZ ]]; then
    info "oh-my-zsh is already installed"
    return "$RC_SKIPPED"
  fi
  local script rc
  info "Installing oh-my-zsh to $HOME/.oh-my-zsh"
  script=$(download "$OMZ_URL") || {
    err "Could not download the oh-my-zsh installer"
    return "$RC_FAILED"
  }
  ZSH=$HOME/.oh-my-zsh KEEP_ZSHRC=yes CHSH=no RUNZSH=no sh "$script" --unattended </dev/null
  rc=$?
  rm -f "$script"
  if ((rc != 0)); then
    err "The oh-my-zsh installer failed"
    return "$RC_FAILED"
  fi
  ok "oh-my-zsh installed"
}

# install_zoxide : 0 installed, 2 already present, 1 failed.
install_zoxide() {
  if command -v zoxide >/dev/null 2>&1 || [[ -x $HOME/.local/bin/zoxide ]]; then
    info "zoxide is already installed"
    return "$RC_SKIPPED"
  fi
  local script rc
  info "Installing zoxide to $HOME/.local/bin"
  script=$(download "$ZOXIDE_URL") || {
    warn "Could not download the zoxide installer"
    return "$RC_FAILED"
  }
  sh "$script" </dev/null
  rc=$?
  rm -f "$script"
  if ((rc != 0)); then
    warn "The zoxide installer failed"
    return "$RC_FAILED"
  fi
  ok "zoxide installed"
}

main() {
  local omz_rc zoxide_rc
  install_omz
  omz_rc=$?
  install_zoxide
  zoxide_rc=$?

  ((omz_rc == RC_FAILED || zoxide_rc == RC_FAILED)) && return "$RC_FAILED"
  ((omz_rc == RC_SKIPPED && zoxide_rc == RC_SKIPPED)) && return "$RC_SKIPPED"
  return "$RC_OK"
}

main "$@"
