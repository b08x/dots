#!/usr/bin/env bash
# 91-install-vscode-extensions.sh: install Visual Studio Code extensions
# for native (code) or Flatpak (com.visualstudio.code) installations.
#
# Exits 0 when something was installed, 2 when everything was already in place
# or VS Code is not installed, 1 on any failure. Extension failures do not stop
# the remaining extensions.

set -uo pipefail

YADM_CONFIG_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..
# shellcheck source=../scripts/syncopated-theme.sh
source "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh"

: "${SYNCOPATED_STEP:=install-vscode-extensions}"

EXTENSIONS_FILE=${VSCODE_EXTENSIONS_FILE:-$YADM_CONFIG_DIR/files/vscode-extensions.txt}
DID_WORK=0
FAILED=0
declare -a CODE_CMD=()
declare -a EXTENSIONS=()

detect_vscode_cmd() {
  if [[ -n ${VSCODE_CMD:-} ]]; then
    read -r -a CODE_CMD <<< "$VSCODE_CMD"
    return 0
  fi

  if command -v code >/dev/null 2>&1; then
    CODE_CMD=(code)
    return 0
  fi

  if command -v flatpak >/dev/null 2>&1 && flatpak list --app --columns=application 2>/dev/null | grep -qx "com.visualstudio.code"; then
    CODE_CMD=(flatpak run com.visualstudio.code)
    return 0
  fi

  return 1
}

load_extensions() {
  if [[ -r $EXTENSIONS_FILE ]]; then
    info "Loading VS Code extensions from $EXTENSIONS_FILE"
    mapfile -t EXTENSIONS < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$EXTENSIONS_FILE" | grep -v '^$')
  else
    err "Extension list not found: $EXTENSIONS_FILE"
    return 1
  fi
}

install_extensions() {
  local installed_output
  info "Checking installed VS Code extensions via '${CODE_CMD[*]}'"
  if ! installed_output=$("${CODE_CMD[@]}" --list-extensions 2>/dev/null); then
    err "Failed to query installed extensions using '${CODE_CMD[*]}'"
    return "$RC_FAILED"
  fi

  declare -A installed_map=()
  local line
  while IFS= read -r line; do
    [[ -n $line ]] && installed_map["${line,,}"]=1
  done <<< "$installed_output"

  local ext attempted=0
  for ext in "${EXTENSIONS[@]}"; do
    local ext_clean="${ext%%#*}"
    ext_clean="$(echo "$ext_clean" | tr -d '[:space:]')"
    [[ -z $ext_clean ]] && continue

    local ext_lower="${ext_clean,,}"
    if [[ -n "${installed_map[$ext_lower]:-}" ]]; then
      continue
    fi

    attempted=$((attempted + 1))
    if run_item "$(item_label "$ext_clean")" "${CODE_CMD[@]}" --install-extension "$ext_clean"; then
      DID_WORK=1
      installed_map["$ext_lower"]=1
    else
      FAILED=1
    fi
  done

  if ((attempted == 0)); then
    info "All ${#EXTENSIONS[@]} VS Code extensions are already installed"
  fi

  return 0
}

main() {
  if ! detect_vscode_cmd; then
    warn "VS Code not found; skipping extension installation"
    return "$RC_SKIPPED"
  fi

  if ! load_extensions; then
    return "$RC_FAILED"
  fi
  if ((${#EXTENSIONS[@]} == 0)); then
    info "No VS Code extensions configured"
    return "$RC_SKIPPED"
  fi

  install_extensions || return "$RC_FAILED"

  ((FAILED)) && return "$RC_FAILED"
  ((DID_WORK)) && return "$RC_OK"
  return "$RC_SKIPPED"
}

main "$@"
