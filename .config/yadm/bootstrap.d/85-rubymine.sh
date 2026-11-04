#!/usr/bin/env bash
# 85-rubymine.sh: install JetBrains RubyMine IDE via official Linux tarball.
#
# Detects pre-existing RubyMine or JetBrains Toolbox installations, exiting 2
# (skipped) if already present. Otherwise fetches the latest release tarball
# from JetBrains, extracts to ~/.local/share/JetBrains/RubyMine, creates symlink
# ~/.local/bin/rubymine, and provisions a desktop launcher.
#
# Exits 0 on success, 2 if skipped/already installed, 1 on failure.

# shellcheck disable=SC2329  # install functions are invoked indirectly by run_item
set -uo pipefail

YADM_CONFIG_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/..
# shellcheck source=../scripts/syncopated-theme.sh
source "$YADM_CONFIG_DIR/scripts/syncopated-theme.sh"

: "${SYNCOPATED_STEP:=rubymine}"

JETBRAINS_API_URL="https://data.services.jetbrains.com/products/releases?code=RM&latest=true&type=release"
INSTALL_DIR="${RUBYMINE_INSTALL_DIR:-$HOME/.local/share/JetBrains/RubyMine}"
BIN_DIR="${RUBYMINE_BIN_DIR:-$HOME/.local/bin}"
APPS_DIR="${RUBYMINE_APPS_DIR:-$HOME/.local/share/applications}"
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
  if [[ -x "/opt/rubymine/bin/rubymine.sh" ]]; then
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
  return 1
}

get_release_url() {
  if [[ -n ${SYNCOPATED_RUBYMINE_URL:-} ]]; then
    printf '%s\n' "$SYNCOPATED_RUBYMINE_URL"
    return 0
  fi

  local arch key api_out
  arch=$(uname -m 2>/dev/null || echo "x86_64")
  key="linux"
  if [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    key="linuxARM64"
  fi

  api_out=$(curl -fsSL --connect-timeout 15 "$JETBRAINS_API_URL") || {
    echo "Failed to query JetBrains release API" >&2
    return 1
  }

  local url=""
  if command -v jq >/dev/null 2>&1; then
    url=$(printf '%s' "$api_out" | jq -r ".RM[0].downloads.${key}.link // empty" 2>/dev/null || true)
  fi
  if [[ -z $url ]]; then
    url=$(printf '%s' "$api_out" | grep -o "\"${key}\":{[^}]*\"link\":\"[^\"]*\"" | sed -n 's/.*"link":"\([^"]*\)".*/\1/p' | head -n 1)
  fi

  if [[ -z $url ]]; then
    echo "Could not find RubyMine download link for $key" >&2
    return 1
  fi

  printf '%s\n' "$url"
}

rubymine_install_task() {
  local url
  url=$(get_release_url) || return 1

  local tmp_tar
  tmp_tar=$(mktemp) || return 1

  if ! curl -fsSL --connect-timeout 15 -o "$tmp_tar" "$url"; then
    echo "Failed to download RubyMine tarball from $url" >&2
    rm -f "$tmp_tar"
    return 1
  fi

  mkdir -p "$INSTALL_DIR"
  if ! tar -xzf "$tmp_tar" -C "$INSTALL_DIR" --strip-components=1; then
    echo "Failed to extract RubyMine tarball to $INSTALL_DIR" >&2
    rm -f "$tmp_tar"
    return 1
  fi
  rm -f "$tmp_tar"

  mkdir -p "$BIN_DIR"
  ln -sf "$INSTALL_DIR/bin/rubymine.sh" "$BIN_DIR/rubymine"

  local icon="$INSTALL_DIR/bin/rubymine.svg"
  if [[ ! -f $icon && -f "$INSTALL_DIR/bin/rubymine.png" ]]; then
    icon="$INSTALL_DIR/bin/rubymine.png"
  fi

  mkdir -p "$APPS_DIR"
  cat > "$APPS_DIR/jetbrains-rubymine.desktop" <<DESKTOP_EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RubyMine
Icon=$icon
Exec="$INSTALL_DIR/bin/rubymine.sh" %f
Comment=The Most Intelligent Ruby and Rails IDE
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-rubymine
DESKTOP_EOF
  chmod 644 "$APPS_DIR/jetbrains-rubymine.desktop" 2>/dev/null || true

  return 0
}

export -f get_release_url rubymine_install_task

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

  if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    err "curl and tar are required to install RubyMine"
    exit "$RC_FAILED"
  fi

  export JETBRAINS_API_URL INSTALL_DIR BIN_DIR APPS_DIR SYNCOPATED_RUBYMINE_URL
  if run_item "RubyMine IDE" rubymine_install_task; then
    exit "$RC_OK"
  else
    exit "$RC_FAILED"
  fi
}

main "$@"
