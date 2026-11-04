#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap" "$T/yadm/"
  printf 'NAME="Fedora Linux"\nVERSION_ID=43\n' >"$T/os-release"
  export SYNCOPATED_OS_RELEASE=$T/os-release
  printf '/usr/bin/zsh' >"$T/shell"
  stub yadm 'echo "yadm $*" >>"$T/calls"; exit 0'
  stub sudo 'echo "sudo $*" >>"$T/calls"; exit 0'
  stub getent 'echo "tester:x:1000:1000::/home/tester:$(cat "$T/shell")"'
  stub zsh 'true'
  stub j2 'true'
  stub uv 'echo "uv $*" >>"$T/calls"'
  unset SYNCOPATED_DESKTOP XDG_CURRENT_DESKTOP DESKTOP_SESSION SYNCOPATED_SESSION_DIRS
}

teardown() { cleanup_env; }

@test "detect_desktop respects SYNCOPATED_DESKTOP override" {
  for d in cosmic gnome sway shell; do
    SYNCOPATED_DESKTOP="$d" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
    [ "$status" -eq 0 ]
    [ "$output" = "$d" ]
  done
}

@test "detect_desktop identifies active COSMIC session from XDG_CURRENT_DESKTOP" {
  XDG_CURRENT_DESKTOP="COSMIC" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "cosmic" ]
}

@test "detect_desktop identifies active GNOME session from XDG_CURRENT_DESKTOP" {
  XDG_CURRENT_DESKTOP="ubuntu:GNOME" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "gnome" ]
}

@test "detect_desktop identifies active Sway session from XDG_CURRENT_DESKTOP" {
  XDG_CURRENT_DESKTOP="sway" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "sway" ]
}

@test "detect_desktop identifies desktop from DESKTOP_SESSION" {
  DESKTOP_SESSION="cosmic" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "cosmic" ]

  DESKTOP_SESSION="gnome-classic" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "gnome" ]

  DESKTOP_SESSION="sway" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "sway" ]
}

@test "detect_desktop defaults to shell when non-interactive and unrecognized" {
  run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh" </dev/null
  [ "$status" -eq 0 ]
  [ "$output" = "shell" ]
}

@test "detect_desktop does not probe session desktop files or binaries" {
  mkdir -p "$T/wayland-sessions"
  touch "$T/wayland-sessions/cosmic.desktop"
  stub gnome-shell 'true'
  run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh" </dev/null
  [ "$status" -eq 0 ]
  [ "$output" = "shell" ]
}

@test "detect_desktop prompts on interactive TTY when unrecognized" {
  stub gum 'echo "gum $*" >>"$T/calls"; echo "sway"'
  SYNCOPATED_FORCE_INTERACTIVE=1 run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "sway" ]
  grep -q "gum choose --header Select desktop environment --selected shell -- cosmic gnome sway shell" "$T/calls"
}

@test "detect_desktop prompts on interactive TTY and returns shell by default" {
  stub gum 'echo "gum $*" >>"$T/calls"; echo "shell"'
  SYNCOPATED_FORCE_INTERACTIVE=1 run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "shell" ]
  grep -q "gum choose --header Select desktop environment --selected shell -- cosmic gnome sway shell" "$T/calls"
}

@test "bootstrap logs and exports SYNCOPATED_DESKTOP to child scripts" {
  printf '#!/bin/bash\necho "CHILD_DESKTOP: $SYNCOPATED_DESKTOP" >>"%s/calls"\nexit 0\n' "$T" >"$T/yadm/bootstrap.d/10-child.sh"
  chmod +x "$T/yadm/bootstrap.d/10-child.sh"

  SYNCOPATED_DESKTOP=cosmic run bash "$T/yadm/bootstrap" --only=child </dev/null
  [ "$status" -eq 0 ]
  grep -q "Detected desktop environment: cosmic" "$HOME/.bootstrap.log"
  grep -q "CHILD_DESKTOP: cosmic" "$T/calls"
  [[ $output == *"Fedora Linux 43"* ]]
  [[ $output == *"Desktop: cosmic"* ]]
}
