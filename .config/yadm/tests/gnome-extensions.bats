#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/40-gnome-extensions.sh" "$T/yadm/bootstrap.d/"
  : >"$T/installed_exts"
  : >"$T/enabled_exts"
  : >"$T/rpm_installed"

  stub gnome-extensions '
    if [ "$1" = "list" ]; then
      if [ "${2:-}" = "--enabled" ]; then
        cat "$T/enabled_exts" 2>/dev/null || true
      else
        cat "$T/installed_exts" 2>/dev/null || true
      fi
    elif [ "$1" = "install" ]; then
      echo "gnome-extensions install $*" >>"$T/calls"
      if [ -n "${GNOME_EXT_FAIL_INSTALL:-}" ] && [[ "$*" == *"$GNOME_EXT_FAIL_INSTALL"* ]]; then
        exit 1
      fi
      exit 0
    elif [ "$1" = "enable" ]; then
      echo "gnome-extensions enable $2" >>"$T/calls"
      if [ -n "${GNOME_EXT_FAIL_ENABLE:-}" ] && [ "$2" = "$GNOME_EXT_FAIL_ENABLE" ]; then
        exit 1
      fi
      echo "$2" >>"$T/enabled_exts"
      exit 0
    else
      exit 1
    fi
  '

  stub rpm '
    if [ "$1" = "-q" ]; then
      if grep -qx "$2" "$T/rpm_installed" 2>/dev/null; then
        exit 0
      fi
      exit 1
    fi
  '

  stub sudo '
    echo "sudo $*" >>"$T/calls"
    if [ "$1" = "dnf" ] && [ "$2" = "install" ]; then
      shift 3
      for pkg in "$@"; do
        echo "$pkg" >>"$T/rpm_installed"
      done
      exit 0
    fi
    exit 0
  '

  stub curl '
    out=""
    url=""
    while [ $# -gt 0 ]; do
      if [ "$1" = "-o" ]; then
        out=$2
        shift 2
        continue
      fi
      url=$1
      shift
    done
    echo "curl $url" >>"$T/calls"
    if [[ "$url" == *"extension-info"* ]]; then
      uuid=$(echo "$url" | sed -n "s/.*uuid=\([^&]*\).*/\1/p")
      if [ -n "${GNOME_EXT_FAIL_DOWNLOAD:-}" ] && [ "$uuid" = "$GNOME_EXT_FAIL_DOWNLOAD" ]; then
        exit 1
      fi
      echo "{\"download_url\": \"/download-extension/${uuid}.shell-extension.zip?version_tag=1\"}" >"$out"
      exit 0
    elif [[ "$url" == *"download-extension"* ]]; then
      echo "fake-zip-content" >"$out"
      exit 0
    fi
    exit 0
  '
}

teardown() { cleanup_env; }

run_gnome_step() {
  run bash "$T/yadm/bootstrap.d/40-gnome-extensions.sh" </dev/null
}

@test "skips when gnome-extensions command is not found" {
  rm "$T/bin/gnome-extensions"
  run_gnome_step
  [ "$status" -eq 2 ]
  [[ $output == *"gnome-extensions command not found"* ]]
}

@test "exits 1 when extensions file is missing" {
  export GNOME_EXTENSIONS_FILE=$T/nonexistent.txt
  run_gnome_step
  [ "$status" -eq 1 ]
  [[ $output == *"Extension list not found"* ]]
}

@test "exits 2 when all system and user extensions are already installed and enabled" {
  mkdir -p "$T/yadm/files"
  cp "$YADM_SRC/files/gnome-extensions.txt" "$T/yadm/files/"
  while IFS= read -r line; do
    line=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    [[ -z $line ]] && continue
    if [[ $line == *:* ]]; then
      echo "${line%%:*}" >>"$T/rpm_installed"
      echo "${line#*:}" >>"$T/installed_exts"
      echo "${line#*:}" >>"$T/enabled_exts"
    else
      echo "$line" >>"$T/installed_exts"
      echo "$line" >>"$T/enabled_exts"
    fi
  done <"$YADM_SRC/files/gnome-extensions.txt"

  run_gnome_step
  [ "$status" -eq 2 ]
  ! grep -q 'sudo dnf install' "$T/calls"
  ! grep -q 'gnome-extensions install' "$T/calls"
  ! grep -q 'gnome-extensions enable' "$T/calls"
  [[ $output != *"reboot"* ]]
}

@test "installs missing user extensions with gnome-extensions install before enabling" {
  printf 'user-ext-1@example.com\nuser-ext-2@example.com\n' >"$T/ext.txt"
  export GNOME_EXTENSIONS_FILE=$T/ext.txt

  # user-ext-1 is already installed and enabled; user-ext-2 is missing
  echo "user-ext-1@example.com" >"$T/installed_exts"
  echo "user-ext-1@example.com" >"$T/enabled_exts"

  run_gnome_step
  [ "$status" -eq 0 ]
  grep -q 'gnome-extensions install.*user-ext-2@example.com' "$T/calls"
  grep -q 'gnome-extensions enable user-ext-2@example.com' "$T/calls"
  ! grep -q 'gnome-extensions install.*user-ext-1@example.com' "$T/calls"

  # Verify install happens before enable
  install_line=$(grep -n 'gnome-extensions install.*user-ext-2@example.com' "$T/calls" | cut -d: -f1)
  enable_line=$(grep -n 'gnome-extensions enable user-ext-2@example.com' "$T/calls" | cut -d: -f1)
  [ "$install_line" -lt "$enable_line" ]

  # Verify reboot message is displayed
  [[ $output == *"reboot"* ]]
}

@test "does not suggest reboot when only enabling already installed extensions" {
  printf 'user-ext-1@example.com\n' >"$T/ext.txt"
  export GNOME_EXTENSIONS_FILE=$T/ext.txt

  # user-ext-1 is installed but not enabled
  echo "user-ext-1@example.com" >"$T/installed_exts"

  run_gnome_step
  [ "$status" -eq 0 ]
  ! grep -q 'gnome-extensions install' "$T/calls"
  grep -q 'gnome-extensions enable user-ext-1@example.com' "$T/calls"
  [[ $output != *"reboot"* ]]
}

@test "user extension install failure exits 1 while attempting remaining extensions" {
  printf 'ext-a@example.com\next-fail@example.com\next-b@example.com\n' >"$T/ext.txt"
  export GNOME_EXTENSIONS_FILE=$T/ext.txt
  export GNOME_EXT_FAIL_INSTALL=ext-fail

  run_gnome_step
  [ "$status" -eq 1 ]
  [ "$(grep -c 'gnome-extensions install' "$T/calls")" -eq 3 ]
  grep -q 'gnome-extensions install.*ext-a@example.com' "$T/calls"
  grep -q 'gnome-extensions install.*ext-fail@example.com' "$T/calls"
  grep -q 'gnome-extensions install.*ext-b@example.com' "$T/calls"
}

@test "displays reboot message when system extensions are installed" {
  printf 'test-pkg:test-uuid@example.com\n' >"$T/ext.txt"
  export GNOME_EXTENSIONS_FILE=$T/ext.txt

  run_gnome_step
  [ "$status" -eq 0 ]
  grep -q 'sudo dnf install' "$T/calls"
  grep -q 'gnome-extensions enable test-uuid@example.com' "$T/calls"
  [[ $output == *"reboot"* ]]
}
