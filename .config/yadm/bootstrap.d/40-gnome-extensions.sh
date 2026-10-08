#!/usr/bin/env bash
# 40-gnome-extensions.sh: Install GNOME extensions and enable them.
#
# Exits 0 when something was installed or enabled, 2 when everything was
# already in place, 1 on any failure.
#
# bootstrap: needs-sudo

set -uo pipefail

YADM_CONFIG_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..
# shellcheck source=../scripts/syncopated-theme.sh
source "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh"

EXTENSIONS_FILE=${GNOME_EXTENSIONS_FILE:-$YADM_CONFIG_DIR/files/gnome-extensions.txt}
DID_WORK=0
FAILED=0
EXTENSIONS_INSTALLED=0
declare -g -A JUST_INSTALLED=()
declare -g -A PKG_TO_UUID=()

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
      PKG_TO_UUID["$pkg"]="$uuid"
    else
      USER_UUIDS+=("$line")
      ALL_UUIDS+=("$line")
    fi
  done < "$EXTENSIONS_FILE"
}

is_extension_installed() {
  local uuid=$1
  local installed_list=${2:-}
  if [[ -n ${JUST_INSTALLED[$uuid]:-} ]]; then
    return 0
  fi
  if [[ -n $installed_list ]] && grep -qx "$uuid" <<< "$installed_list"; then
    return 0
  fi
  local user_ext_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$uuid"
  if [[ -d $user_ext_dir || -d "/usr/share/gnome-shell/extensions/$uuid" ]]; then
    return 0
  fi
  return 1
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
    # bootstrap runs `sudo -v` first, so the spinner never hides a password prompt.
    if run_item "GNOME extension packages" sudo dnf install -y "${to_install[@]}"; then
      DID_WORK=1
      EXTENSIONS_INSTALLED=$((EXTENSIONS_INSTALLED + ${#to_install[@]}))
      for pkg in "${to_install[@]}"; do
        if [[ -n ${PKG_TO_UUID[$pkg]:-} ]]; then
          JUST_INSTALLED["${PKG_TO_UUID[$pkg]}"]=1
        fi
      done
    else
      FAILED=1
    fi
  else
    info "All system GNOME extension packages are already installed"
  fi
}

get_shell_version() {
  if command -v gnome-shell >/dev/null 2>&1; then
    gnome-shell --version 2>/dev/null | sed -n 's/^GNOME Shell \([0-9.]*\).*/\1/p'
  fi
}

download_user_extension() {
  local uuid=$1
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl command not found; cannot download extension $uuid" >&2
    return 1
  fi

  local shell_ver
  shell_ver=${GNOME_SHELL_VERSION:-$(get_shell_version)}
  local info_url="https://extensions.gnome.org/extension-info/?uuid=${uuid}"
  [[ -n $shell_ver ]] && info_url+="&shell_version=${shell_ver}"

  local info_file
  info_file=$(mktemp -t "info.${uuid}.XXXXXX" 2>/dev/null || mktemp) || return 1

  if ! curl -fsSL --connect-timeout 15 -o "$info_file" "$info_url" 2>/dev/null; then
    # If query with shell_version failed, retry without shell_version
    if ! curl -fsSL --connect-timeout 15 -o "$info_file" "https://extensions.gnome.org/extension-info/?uuid=${uuid}" 2>/dev/null; then
      rm -f "$info_file"
      return 1
    fi
  fi

  local json
  json=$(cat "$info_file")
  rm -f "$info_file"

  [[ -z $json ]] && return 1

  local download_path=""
  if command -v jq >/dev/null 2>&1; then
    download_path=$(jq -r '.download_url // empty' <<< "$json" 2>/dev/null)
  fi

  if [[ -z $download_path ]] && command -v python3 >/dev/null 2>&1; then
    download_path=$(python3 -c '
import sys, json
try:
    data = json.loads(sys.argv[1])
    url = data.get("download_url")
    if not url and "shell_version_map" in data:
        m = data["shell_version_map"]
        if m:
            latest = max(m.values(), key=lambda v: (v.get("version", 0), v.get("pk", 0)))
            pk = latest.get("pk")
            uuid = data.get("uuid")
            if pk and uuid:
                url = f"/download-extension/{uuid}.shell-extension.zip?version_tag={pk}"
    print(url or "")
except Exception:
    pass
' "$json" 2>/dev/null)
  fi

  if [[ -z $download_path ]]; then
    download_path=$(sed -n 's/.*"download_url":[[:space:]]*"\([^"]*\)".*/\1/p' <<< "$json")
  fi

  if [[ -z $download_path ]]; then
    return 1
  fi

  local download_url="$download_path"
  if [[ $download_url != http* ]]; then
    download_url="https://extensions.gnome.org${download_path}"
  fi

  local tmp_zip
  tmp_zip=$(mktemp -t "${uuid}.XXXXXX.shell-extension.zip" 2>/dev/null || mktemp --suffix=".${uuid}.shell-extension.zip" 2>/dev/null || mktemp)
  if ! curl -fsSL --connect-timeout 30 -o "$tmp_zip" "$download_url"; then
    rm -f "$tmp_zip"
    return 1
  fi

  printf '%s\n' "$tmp_zip"
  return 0
}

install_user_extension() {
  local uuid=$1
  local bundle=""
  local tmp_zip=""

  if [[ -f $uuid ]]; then
    bundle="$uuid"
  else
    tmp_zip=$(download_user_extension "$uuid") || {
      echo "Failed to download extension $uuid" >&2
      return 1
    }
    bundle="$tmp_zip"
  fi

  local rc=0
  if ! gnome-extensions install --force "$bundle"; then
    echo "gnome-extensions install failed for $uuid" >&2
    rc=1
  fi

  [[ -n $tmp_zip && -f $tmp_zip ]] && rm -f "$tmp_zip"
  return "$rc"
}

export -f get_shell_version download_user_extension install_user_extension

install_user_extensions() {
  if ((${#USER_UUIDS[@]} == 0)); then
    return 0
  fi

  local installed_exts
  installed_exts=$(gnome-extensions list 2>/dev/null || true)

  local uuid attempted=0
  for uuid in "${USER_UUIDS[@]}"; do
    if is_extension_installed "$uuid" "$installed_exts"; then
      continue
    fi

    attempted=$((attempted + 1))
    if run_item "$uuid" install_user_extension "$uuid"; then
      DID_WORK=1
      EXTENSIONS_INSTALLED=$((EXTENSIONS_INSTALLED + 1))
      JUST_INSTALLED["$uuid"]=1
    else
      FAILED=1
    fi
  done

  if ((attempted == 0)); then
    info "All user GNOME extensions are already installed"
  fi
}

enable_via_gsettings() {
  local uuid=$1
  command -v gsettings >/dev/null 2>&1 || return 1
  local current
  current=$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null) || return 1
  if [[ $current == *\'$uuid\'* || $current == *\"$uuid\"* ]]; then
    return 0
  fi
  local updated=""
  if command -v python3 >/dev/null 2>&1; then
    updated=$(python3 -c "
import sys, ast
try:
    s = sys.argv[1]
    l = ast.literal_eval(s)
    if sys.argv[2] not in l:
        l.append(sys.argv[2])
    print(repr(l))
except Exception:
    pass
" "$current" "$uuid" 2>/dev/null)
  fi
  if [[ -z $updated ]]; then
    if [[ $current == "[]" || $current == "@as []" ]]; then
      updated="['$uuid']"
    elif [[ $current == *"]" ]]; then
      updated="${current%]}, '$uuid']"
    fi
  fi
  if [[ -n $updated ]]; then
    gsettings set org.gnome.shell enabled-extensions "$updated" 2>/dev/null && return 0
  fi
  return 1
}

enable_extensions() {
  local installed_exts enabled_exts
  installed_exts=$(gnome-extensions list 2>/dev/null || true)
  enabled_exts=$(gnome-extensions list --enabled 2>/dev/null || true)

  local uuid attempted=0
  for uuid in "${ALL_UUIDS[@]}"; do
    if is_extension_installed "$uuid" "$installed_exts"; then
      if ! grep -qx "$uuid" <<< "$enabled_exts"; then
        attempted=$((attempted + 1))
        info "Enabling extension: $uuid"
        if gnome-extensions enable "$uuid"; then
          DID_WORK=1
          ok "Extension $uuid enabled"
        elif enable_via_gsettings "$uuid"; then
          DID_WORK=1
          ok "Extension $uuid enabled in settings"
        else
          err "Failed to enable extension: $uuid"
          FAILED=1
        fi
      fi
    else
      if [[ " ${USER_UUIDS[*]} " == *" $uuid "* ]]; then
        warn "User extension $uuid is not installed even after install step."
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
  install_user_extensions
  enable_extensions

  if ((EXTENSIONS_INSTALLED > 0)); then
    warn "GNOME extensions were installed. A reboot is recommended to load them."
  fi

  ((FAILED)) && return "$RC_FAILED"
  ((DID_WORK)) && return "$RC_OK"
  return "$RC_SKIPPED"
}

main "$@"
