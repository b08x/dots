#!/usr/bin/env bash
# 40-gnome-extensions.sh: Install system GNOME extensions and enable them.
#
# Exits 0 when something was installed or enabled, 2 when everything was
# already in place, 1 on any failure.

set -uo pipefail

YADM_CONFIG_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..
# shellcheck source=../scripts/syncopated-theme.sh
source "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh"

EXTENSIONS_FILE=$YADM_CONFIG_DIR/files/gnome-extensions.txt
DID_WORK=0
FAILED=0

if ! command -v gnome-extensions >/dev/null 2>&1; then
  warn "gnome-extensions command not found; skipping extension management"
  exit "$RC_SKIPPED"
fi

load_extensions() {
  if [[ ! -r $EXTENSIONS_FILE ]]; then
    err "Extension list not found: $EXTENSIONS_FILE"
    return 1
  fi

  info "Loading GNOME extensions from $EXTENSIONS_FILE"
  declare -g -a DNF_PACKAGES=()
  declare -g -a ALL_UUIDS=()
  declare -g -a USER_UUIDS=()

  local line pkg uuid
  while IFS= read -r line; do
    # Remove comments and whitespace
    line=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z $line ]] && continue

    if [[ $line == *:* ]]; then
      pkg="${line%%:*}"
      uuid="${line#*:}"
      DNF_PACKAGES+=("$pkg")
      ALL_UUIDS+=("$uuid")
    else
      USER_UUIDS+=("$line")
      ALL_UUIDS+=("$line")
    fi
  done < "$EXTENSIONS_FILE"
}

install_system_extensions() {
  if ((${#DNF_PACKAGES[@]} == 0)); then
    return 0
  fi

  local to_install=()
  for pkg in "${DNF_PACKAGES[@]}"; do
    if ! rpm -q "$pkg" >/dev/null 2>&1; then
      to_install+=("$pkg")
    fi
  done

  if ((${#to_install[@]} > 0)); then
    info "Installing missing GNOME extension packages via sudo dnf: ${to_install[*]}"
    if sudo dnf install -y "${to_install[@]}"; then
      DID_WORK=1
      ok "System GNOME extensions installed"
    else
      err "Failed to install system GNOME extensions"
      FAILED=1
    fi
  else
    info "All system GNOME extension packages are already installed"
  fi
}

enable_extensions() {
  local installed_exts enabled_exts
  installed_exts=$(gnome-extensions list 2>/dev/null)
  enabled_exts=$(gnome-extensions list --enabled 2>/dev/null)

  local uuid attempted=0
  for uuid in "${ALL_UUIDS[@]}"; do
    if grep -qx "$uuid" <<< "$installed_exts"; then
      if ! grep -qx "$uuid" <<< "$enabled_exts"; then
        attempted=$((attempted + 1))
        info "Enabling extension: $uuid"
        if gnome-extensions enable "$uuid"; then
          DID_WORK=1
          ok "Extension $uuid enabled"
        else
          err "Failed to enable extension: $uuid"
          FAILED=1
        fi
      fi
    else
      if [[ " ${USER_UUIDS[*]} " == *" $uuid "* ]]; then
        warn "User extension $uuid is not installed. Please install it manually or via browser."
      else
        warn "System extension $uuid is not installed even after DNF step."
      fi
    fi
  done

  ((attempted == 0)) && info "All available configured extensions are already enabled"
  return 0
}

main() {
  load_extensions || return "$RC_FAILED"
  install_system_extensions
  enable_extensions

  ((FAILED)) && return "$RC_FAILED"
  ((DID_WORK)) && return "$RC_OK"
  return "$RC_SKIPPED"
}

main "$@"
