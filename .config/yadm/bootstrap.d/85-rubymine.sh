#!/usr/bin/env bash
# bootstrap: needs-sudo
# 85-rubymine.sh: install JetBrains RubyMine IDE via system package manager or rubymine-fetch.
#
# Detects pre-existing RubyMine, Flatpak, RPM, or JetBrains Toolbox installations,
# exiting 2 (skipped) if already present.
#
# If not installed:
# 1. Checks if 'rubymine' is available via system package manager (dnf) and installs it.
# 2. Otherwise falls back to rubymine-fetch (system-wide under /opt/rubymine).
#
# Exits 0 on success, 2 if skipped/already installed, 1 on failure.

# shellcheck disable=SC2329  # install functions are invoked indirectly by run_item
set -uo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
YADM_CONFIG_DIR=$(readlink -f "$SCRIPT_DIR/..")
if [[ -f "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh" ]]; then
  # shellcheck source=../scripts/syncopated-theme.sh
  source "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh"
elif [[ -f "${HOME}/.config/yadm/scripts/syncopated-theme.sh" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.config/yadm/scripts/syncopated-theme.sh"
fi

: "${SYNCOPATED_STEP:=rubymine}"

INSTALL_DIR="${RUBYMINE_INSTALL_DIR:-$HOME/.local/share/JetBrains/RubyMine}"
BIN_DIR="${RUBYMINE_BIN_DIR:-$HOME/.local/bin}"
OPT_DIR="${RUBYMINE_OPT_DIR:-/opt/rubymine}"
OPT_SKIP=0

parse_args() {
  while (($#)); do
    case "$1" in
      --skip-rubymine) OPT_SKIP=1 ;;
    esac
    shift
  done
}

is_installed() {
  if command -v rubymine >/dev/null 2>&1; then
    return 0
  fi
  if command -v jetbrains-toolbox >/dev/null 2>&1; then
    return 0
  fi
  if [[ -x "$BIN_DIR/rubymine" ]]; then
    return 0
  fi
  if [[ -x "/usr/bin/rubymine" ]]; then
    return 0
  fi
  if [[ -x "$OPT_DIR/bin/rubymine" || -x "$OPT_DIR/bin/rubymine.sh" ]]; then
    return 0
  fi
  if [[ -x "$INSTALL_DIR/bin/rubymine.sh" ]]; then
    return 0
  fi
  if [[ -x "$HOME/.local/share/JetBrains/Toolbox/bin/jetbrains-toolbox" ]]; then
    return 0
  fi
  local d
  for d in "$HOME/.local/share/JetBrains/Toolbox/apps/rubymine" \
           "$HOME/.local/share/JetBrains/Toolbox/apps/RubyMine" \
           "$HOME"/.local/share/JetBrains/Toolbox/apps/*rubymine*; do
    if [[ -d "$d" ]]; then
      return 0
    fi
  done
  if command -v rpm >/dev/null 2>&1 && rpm -q rubymine >/dev/null 2>&1; then
    return 0
  fi
  if command -v flatpak >/dev/null 2>&1 && flatpak info com.jetbrains.RubyMine >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

find_rubymine_fetch() {
  if [[ -n "${RUBYMINE_FETCH_PATH:-}" && -f "$RUBYMINE_FETCH_PATH" ]]; then
    printf '%s\n' "$RUBYMINE_FETCH_PATH"
    return 0
  fi

  local bundled="$YADM_CONFIG_DIR/scripts/rubymine-fetch"
  if [[ -f "$bundled" ]]; then
    printf '%s\n' "$bundled"
    return 0
  fi

  local fallback_bundled="${HOME}/.config/yadm/scripts/rubymine-fetch"
  if [[ -f "$fallback_bundled" ]]; then
    printf '%s\n' "$fallback_bundled"
    return 0
  fi

  local workspace_path="${SYNCOPATED_RUBYMINE_WORKSPACE_FETCH:-/home/b08x/WorkspaceV3/Syncopated/rpmbuild/roles/packages/files/rubymine/rubymine-fetch}"
  if [[ -f "$workspace_path" ]]; then
    printf '%s\n' "$workspace_path"
    return 0
  fi

  if command -v rubymine-fetch >/dev/null 2>&1; then
    command -v rubymine-fetch
    return 0
  fi

  return 1
}

rubymine_install_task() {
  # 1. Check system package manager (dnf/rpm)
  if command -v dnf >/dev/null 2>&1; then
    if dnf info rubymine >/dev/null 2>&1; then
      if sudo dnf install -y rubymine; then
        return 0
      fi
      echo "dnf install rubymine failed; falling back to rubymine-fetch" >&2
    fi
  fi

  # 2. Otherwise install via rubymine-fetch
  local fetch_script
  if ! fetch_script=$(find_rubymine_fetch); then
    echo "Could not find rubymine-fetch and rubymine package is not available via dnf" >&2
    return 1
  fi

  if [[ -x "$fetch_script" ]]; then
    sudo "$fetch_script"
  else
    sudo sh "$fetch_script"
  fi
}

export -f find_rubymine_fetch rubymine_install_task

main() {
  parse_args "$@"

  if ((OPT_SKIP)) || [[ ${SYNCOPATED_SKIP_RUBYMINE:-} == 1 || ${SYNCOPATED_SKIP_RUBYMINE:-} == "yes" || ${SYNCOPATED_SKIP_RUBYMINE:-} == "true" ]]; then
    info "RubyMine installation skipped by configuration"
    exit "$RC_SKIPPED"
  fi

  if is_installed; then
    info "RubyMine is already installed"
    exit "$RC_SKIPPED"
  fi

  export YADM_CONFIG_DIR RUBYMINE_FETCH_PATH
  if run_item "RubyMine IDE" rubymine_install_task; then
    exit "$RC_OK"
  else
    exit "$RC_FAILED"
  fi
}

main "$@"
