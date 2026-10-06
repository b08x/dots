#!/usr/bin/env bash
# 80-install-user-flatpaks.sh: Install user-space Flatpaks using flathub remote.
#
# Exits 0 when something was done, 2 when everything was already in place,
# 1 on any failure. App failures do not stop the remaining apps.

set -uo pipefail

YADM_CONFIG_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..
# shellcheck source=../scripts/syncopated-theme.sh
source "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh"

PACKAGES_FILE=$YADM_CONFIG_DIR/files/user-flatpaks.txt
declare -a USER_FLATPAKS=()
if [[ -r $PACKAGES_FILE ]]; then
  mapfile -t USER_FLATPAKS < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$PACKAGES_FILE" | grep -v '^$')
else
  err "Package list not found: $PACKAGES_FILE"
  exit 1
fi

DID_WORK=0
FAILED=0

if ! command -v flatpak &>/dev/null; then
  warn "flatpak command not found; skipping user Flatpak installations"
  exit 2
fi

ensure_flathub_remote() {
  if ! flatpak remotes --user | grep -q "^flathub"; then
    info "Adding Flathub user remote"
    if flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
      DID_WORK=1
      ok "Flathub user remote added"
    else
      err "Failed to add Flathub user remote"
      return 1
    fi
  else
    info "Flathub user remote is already configured"
  fi
  return 0
}

install_flatpak_app() {
  local app="$1"
  if flatpak list --app --columns=application | grep -qx "$app"; then
    info "Flatpak $app is already installed"
    return 0
  fi

  info "Installing user Flatpak: $app"
  if flatpak install -y --user flathub "$app"; then
    DID_WORK=1
    ok "Flatpak $app installed"
  else
    err "Failed to install user Flatpak: $app"
    return 1
  fi
}

main() {
  if ! ensure_flathub_remote; then
    exit 1
  fi

  for app in "${USER_FLATPAKS[@]}"; do
    if ! install_flatpak_app "$app"; then
      FAILED=1
    fi
  done

  if ((FAILED > 0)); then
    exit 1
  elif ((DID_WORK > 0)); then
    exit 0
  else
    exit 2
  fi
}

main "$@"
