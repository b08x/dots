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

EXTENSIONS_FILE=${VSCODE_EXTENSIONS_FILE:-$YADM_CONFIG_DIR/vscode-extensions.txt}
DID_WORK=0
FAILED=0
declare -a CODE_CMD=()
declare -a EXTENSIONS=()

DEFAULT_EXTENSIONS=(
  "ahmadawais.shades-of-purple"
  "anseki.vscode-color"
  "anthropic.claude-code"
  "batisteo.vscode-django"
  "beardedbear.beardedicons"
  "bierner.markdown-mermaid"
  "bulletproof-sh.ctrl"
  "castwide.solargraph"
  "catppuccin.catppuccin-vsc-icons"
  "davidanson.vscode-markdownlint"
  "donjayamanne.python-environment-manager"
  "donjayamanne.python-extension-pack"
  "dracula-theme.theme-dracula"
  "dreamcatcher45.podmanager"
  "eliverlara.sweet-vscode-icons"
  "enkia.tokyo-night"
  "file-icons.file-icons"
  "github.github-vscode-theme"
  "github.vscode-github-actions"
  "google.google-antigravity"
  "hangxingliu.vscode-systemd-support"
  "johnpapa.winteriscoming"
  "kameshkotwani.google-search"
  "kevinrose.vsc-python-indent"
  "kuscamara.yamllint-fix"
  "magicstack.magicpython"
  "mechatroner.rainbow-csv"
  "miguelsolorio.fluent-icons"
  "misogi.ruby-rubocop"
  "mistralai.mistral-vibe-code"
  "ms-azuretools.vscode-containers"
  "ms-python.black-formatter"
  "ms-python.debugpy"
  "ms-python.flake8"
  "ms-python.pylint"
  "ms-python.python"
  "ms-python.vscode-pylance"
  "ms-python.vscode-python-envs"
  "ms-toolsai.jupyter"
  "ms-toolsai.jupyter-keymap"
  "ms-toolsai.jupyter-renderers"
  "ms-toolsai.vscode-jupyter-cell-tags"
  "ms-toolsai.vscode-jupyter-slideshow"
  "ms-vscode-remote.remote-containers"
  "ms-vscode.makefile-tools"
  "ms-vscode.vscode-chat-customizations-evaluations"
  "naumovs.color-highlight"
  "nefrob.vscode-just-syntax"
  "njpwerner.autodocstring"
  "onatm.open-in-new-window"
  "onlyati.quadlet-lsp"
  "openai.chatgpt"
  "redhat.ansible"
  "redhat.vscode-openshift-connector"
  "redhat.vscode-redhat-account"
  "redhat.vscode-yaml"
  "sdras.night-owl"
  "shakram02.bash-beautify"
  "shopify.ruby-lsp"
  "sst-dev.opencode"
  "takkao.open-window-tab-context"
  "tamasfe.even-better-toml"
  "teabyii.ayu"
  "tomoki1207.pdf"
  "vsls-contrib.gistfs"
  "wholroyd.jinja"
  "yzane.markdown-pdf"
  "zhuangtongfa.material-theme"
)

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
    EXTENSIONS=("${DEFAULT_EXTENSIONS[@]}")
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
    info "Installing VS Code extension: $ext_clean"
    if "${CODE_CMD[@]}" --install-extension "$ext_clean" </dev/null; then
      DID_WORK=1
      installed_map["$ext_lower"]=1
      ok "Extension $ext_clean installed"
    else
      err "Failed to install VS Code extension: $ext_clean"
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

  load_extensions
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
