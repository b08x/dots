#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/91-install-vscode-extensions.sh" "$T/yadm/bootstrap.d/"
  : >"$T/installed"

  # code stub:
  # --list-extensions outputs the lines from $T/installed
  # --install-extension <name> records the call and fails if name matches VSCODE_FAIL
  stub code 'if [ "$1" = "--list-extensions" ]; then
    cat "$T/installed"
  elif [ "$1" = "--install-extension" ]; then
    echo "code install $2" >>"$T/calls"
    if [ "$2" = "${VSCODE_FAIL:-none}" ]; then
      exit 1
    fi
    exit 0
  else
    exit 1
  fi'
}

teardown() { cleanup_env; }

run_vscode_step() {
  run bash "$T/yadm/bootstrap.d/91-install-vscode-extensions.sh" </dev/null
}

@test "skips when code and flatpak are not installed" {
  rm "$T/bin/code"
  run_vscode_step
  [ "$status" -eq 2 ]
  [[ $output == *"VS Code not found"* ]]
}

@test "exits 2 when all default extensions are already installed" {
  # Populate $T/installed with all default extensions
  bash -c '
    YADM_CONFIG_DIR="$1/yadm"
    source "$1/yadm/bootstrap.d/91-install-vscode-extensions.sh"
    printf "%s\n" "${DEFAULT_EXTENSIONS[@]}" >"$2"
  ' _ "$T" "$T/installed"

  run_vscode_step
  [ "$status" -eq 2 ]
  ! grep -q 'code install' "$T/calls"
  [[ $output == *"already installed"* ]]
}

@test "installs missing extensions and exits 0" {
  # Only one extension missing from custom list
  printf 'redhat.ansible\nredhat.vscode-yaml\n' >"$T/installed"
  printf 'redhat.ansible\nredhat.vscode-yaml\nshopify.ruby-lsp\n' >"$T/ext.txt"
  export VSCODE_EXTENSIONS_FILE=$T/ext.txt

  run_vscode_step
  [ "$status" -eq 0 ]
  [ "$(grep -c 'code install' "$T/calls")" -eq 1 ]
  grep -qx 'code install shopify.ruby-lsp' "$T/calls"
  [[ $output == *"Extension shopify.ruby-lsp installed"* ]]
}

@test "handles case-insensitive extension names without reinstalling" {
  printf 'shopify.ruby-lsp\n' >"$T/installed"
  printf 'Shopify.Ruby-Lsp\n' >"$T/ext.txt"
  export VSCODE_EXTENSIONS_FILE=$T/ext.txt

  run_vscode_step
  [ "$status" -eq 2 ]
  ! grep -q 'code install' "$T/calls"
}

@test "extension failure exits 1 while attempting remaining extensions" {
  printf 'ext-a\next-fail\next-b\n' >"$T/ext.txt"
  export VSCODE_EXTENSIONS_FILE=$T/ext.txt
  export VSCODE_FAIL=ext-fail

  run_vscode_step
  [ "$status" -eq 1 ]
  [ "$(grep -c 'code install' "$T/calls")" -eq 3 ]
  grep -qx 'code install ext-a' "$T/calls"
  grep -qx 'code install ext-fail' "$T/calls"
  grep -qx 'code install ext-b' "$T/calls"
  [[ $output == *"Failed to install VS Code extension: ext-fail"* ]]
}

@test "supports VSCODE_CMD override" {
  stub my-custom-code 'if [ "$1" = "--list-extensions" ]; then
    echo "test.ext"
  elif [ "$1" = "--install-extension" ]; then
    echo "custom code install $2" >>"'"$T"'/calls"
  fi'
  export VSCODE_CMD="my-custom-code"
  printf 'test.ext\nother.ext\n' >"$T/ext.txt"
  export VSCODE_EXTENSIONS_FILE=$T/ext.txt

  run_vscode_step
  [ "$status" -eq 0 ]
  grep -qx 'custom code install other.ext' "$T/calls"
}
