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

@test "detect_desktop falls back to session desktop files" {
  mkdir -p "$T/wayland-sessions"
  touch "$T/wayland-sessions/cosmic.desktop"
  SYNCOPATED_SESSION_DIRS="$T/wayland-sessions" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "cosmic" ]

  rm "$T/wayland-sessions/cosmic.desktop"
  touch "$T/wayland-sessions/gnome.desktop"
  SYNCOPATED_SESSION_DIRS="$T/wayland-sessions" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "gnome" ]

  rm "$T/wayland-sessions/gnome.desktop"
  touch "$T/wayland-sessions/sway.desktop"
  SYNCOPATED_SESSION_DIRS="$T/wayland-sessions" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "sway" ]
}

@test "detect_desktop falls back to binaries" {
  mkdir -p "$T/empty"
  stub cosmic-session 'true'
  SYNCOPATED_SESSION_DIRS="$T/empty" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "cosmic" ]
  rm "$T/bin/cosmic-session"

  stub gnome-shell 'true'
  SYNCOPATED_SESSION_DIRS="$T/empty" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "gnome" ]
  rm "$T/bin/gnome-shell"

  stub sway 'true'
  SYNCOPATED_SESSION_DIRS="$T/empty" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "sway" ]
}

@test "detect_desktop defaults to shell when headless and unrecognised" {
  mkdir -p "$T/empty"
  SYNCOPATED_SESSION_DIRS="$T/empty" run bash -c 'source "$1"; detect_desktop' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "shell" ]
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
