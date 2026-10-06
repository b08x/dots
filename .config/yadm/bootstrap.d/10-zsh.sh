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

# Functions run by run_item in a child shell are exported and take their input
# as arguments.
export -f download

# omz_install URL : download the oh-my-zsh installer and run it unattended.
omz_install() {
  local script rc
  script=$(download "$1") || {
    echo "Could not download the oh-my-zsh installer" >&2
    return 1
  }
  ZSH=$HOME/.oh-my-zsh KEEP_ZSHRC=yes CHSH=no RUNZSH=no sh "$script" --unattended </dev/null
  rc=$?
  rm -f "$script"
  return "$rc"
}

# zoxide_install URL : download the zoxide installer and run it.
zoxide_install() {
  local script rc
  script=$(download "$1") || {
    echo "Could not download the zoxide installer" >&2
    return 1
  }
  sh "$script" </dev/null
  rc=$?
  rm -f "$script"
  return "$rc"
}

# install_omz : 0 installed, 2 already present, 1 failed.
install_omz() {
  if [[ -d $HOME/.oh-my-zsh || -d $SYSTEM_OMZ ]]; then
    info "oh-my-zsh is already installed"
    return "$RC_SKIPPED"
  fi
  run_item "oh-my-zsh" omz_install "$OMZ_URL" || return "$RC_FAILED"
}

# install_zoxide : 0 installed, 2 already present, 1 failed.
install_zoxide() {
  if command -v zoxide >/dev/null 2>&1 || [[ -x $HOME/.local/bin/zoxide ]]; then
    info "zoxide is already installed"
    return "$RC_SKIPPED"
  fi
  run_item "zoxide" zoxide_install "$ZOXIDE_URL" || return "$RC_FAILED"
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
