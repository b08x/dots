#!/usr/bin/env bats

load helpers

setup() { make_env; }
teardown() { cleanup_env; }

@test "palette matches the first-boot hex values" {
  run bash -c 'source "$1"; printf "%s %s %s %s %s" "${VIOLET[0]}" "${VIOLET_DIM[0]}" "${VIOLET_LIGHT[0]}" "${EMBER[0]}" "${EMBER_DIM[0]}"' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "#7B4FE0 #4B3A8C #A98BF0 #D2601A #7A3A1C" ]
}

@test "helpers print plain text without gum" {
  run bash -c 'source "$1"; info one; ok two; warn three 2>&1; err four 2>&1' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "➜ one" ]
  [ "${lines[1]}" = "✓ two" ]
  [ "${lines[2]}" = "! three" ]
  [ "${lines[3]}" = "✗ four" ]
  [[ $output != *$'\e'* ]]
}

@test "os_label reads NAME and VERSION_ID from os-release" {
  printf 'NAME="Fedora Linux"\nVERSION_ID=43\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; os_label' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$output" = "Fedora Linux 43" ]
}

@test "banner shows the OS label" {
  printf 'NAME="Fedora Linux"\nVERSION_ID=43\n' >"$T/os-release"
  SYNCOPATED_OS_RELEASE=$T/os-release run bash -c 'source "$1"; banner' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [[ $output == *"Fedora Linux 43"* ]]
  [[ $output == *"User configuration"* ]]
}

@test "logo without a terminal prints uncolored art and the caption" {
  run bash -c 'source "$1"; logo' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [[ $output != *$'\e'* ]]
  [[ $output == *"user configuration · yadm bootstrap"* ]]
}

@test "paint_art uses the swapped palette: ember mark, violet wordmark" {
  run bash -c 'COLORTERM=truecolor; source "$1"; paint_art 200; printf "%s\n" "${ART_PAINTED[1]}"; printf "%s\n" "${ART_PAINTED[9]}"' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  # Row 1 is mark only: ember (210;96;26) and ember dim (122;58;28), no violet.
  [[ ${lines[0]} == *"38;2;210;96;26"* ]]
  [[ ${lines[0]} != *"38;2;123;79;224"* ]]
  # Row 9 has the wordmark: violet (123;79;224).
  [[ ${lines[1]} == *"38;2;123;79;224"* ]]
}

@test "typewriter passes text through when not animating" {
  run bash -c 'source "$1"; printf "abc\n" | typewriter' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$output" = "abc" ]
}

@test "theme library can be sourced twice" {
  run bash -c 'source "$1"; source "$1"; info ok' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "➜ ok" ]
}

@test "draw_steps lists every state with its icon" {
  run bash -c 'source "$1"; STEPS=(a b c d); STEP_STATE[a]=ok; STEP_STATE[b]=failed; STEP_STATE[c]=skipped; draw_steps' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [[ $output == *"✓ a (ok)"* ]]
  [[ $output == *"✗ b (failed)"* ]]
  [[ $output == *"- c (skipped)"* ]]
  [[ $output == *"· d (pending)"* ]]
}

@test "draw_steps ends gum flags with -- so a skipped step is not parsed as a flag" {
  printf '#!/bin/bash\nprintf "%%s\\n" "$@"\n' >"$T/bin/gum"
  chmod +x "$T/bin/gum"
  run bash -c 'source "$1"; STEPS=(shell); STEP_STATE[shell]=skipped; draw_steps' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[-2]}" = "--" ]
  [ "${lines[-1]}" = "- shell (skipped)" ]
}

@test "gum-helpers colors resolve to the palette and function names survive" {
  run bash -c 'export GUM_HELPERS_NO_TRAP=1; cd "$2"; source "$1" >/dev/null; printf "%s %s\n" "$COLOR_PURPLE" "${COLORS[muted]}"; type section_header slide_transition gum_info fn_step >/dev/null && echo fns' _ "$YADM_SRC/scripts/gum-helpers.sh" "$T"
  [ "${lines[0]}" = "#7B4FE0 #4B3A8C" ]
  [ "${lines[1]}" = "fns" ]
}

@test "no script contains raw ANSI escapes or gum color 212" {
  run grep -nE '\\e\[|212' "$YADM_SRC/bootstrap" "$YADM_SRC"/bootstrap.d/* "$YADM_SRC/scripts/gum-helpers.sh"
  [ "$status" -eq 1 ]
}

@test "bootstrap and every bootstrap.d script source the theme" {
  for f in "$YADM_SRC/bootstrap" "$YADM_SRC"/bootstrap.d/*; do
    grep -q 'syncopated-theme.sh' "$f"
  done
}
