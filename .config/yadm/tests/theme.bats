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

@test "step_label turns step names into readable labels" {
  run bash -c 'source "$1"; step_label 20-cargo.sh; step_label preflight; step_label bootstrap.d/80-install-user-flatpaks.sh; step_label cargo' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Cargo" ]
  [ "${lines[1]}" = "Preflight" ]
  [ "${lines[2]}" = "Install user flatpaks" ]
  [ "${lines[3]}" = "Cargo" ]
}

@test "item_label turns package ids into readable labels" {
  run bash -c 'source "$1"; item_label org.mozilla.firefox; item_label rubocop; item_label ms-python.python' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "${lines[0]}" = "Firefox" ]
  [ "${lines[1]}" = "Rubocop" ]
  [ "${lines[2]}" = "Python" ]
}

# gum_stub: a gum whose spin records its title and runs the command after --.
gum_stub() {
  stub gum 'if [ "$1" = spin ]; then
  shift; while [ "$1" != -- ]; do [ "$1" = --title ] && echo "title $2" >>"$T/calls"; shift; done
  shift; "$@"
else exit 0; fi'
}

@test "run_item without gum prints info and ok lines and logs the output" {
  run bash -c 'source "$1"; LOG_FILE=$2/log; run_item "Thing" bash -c "echo noisy; exit 0"' _ "$YADM_SRC/scripts/syncopated-theme.sh" "$T"
  [ "$status" -eq 0 ]
  [[ $output == *"➜ Installing Thing"* ]]
  [[ $output == *"✓ Thing"* ]]
  [[ $output != *noisy* ]]
  grep -q noisy "$T/log"
}

@test "run_item on failure prints the output, an err line and returns the status" {
  run bash -c 'source "$1"; LOG_FILE=$2/log; run_item "Thing" bash -c "echo boom; exit 7" 2>&1' _ "$YADM_SRC/scripts/syncopated-theme.sh" "$T"
  [ "$status" -eq 7 ]
  [[ $output == *"✗ Thing"* ]]
  [[ $output == *"boom"* ]]
  grep -q boom "$T/log"
}

@test "run_item under gum titles the spinner with the label" {
  gum_stub
  run bash -c 'source "$1"; LOG_FILE=$2/log; SYNCOPATED_FORCE_INTERACTIVE=1 run_item "Rust toolchain" bash -c "echo hi"' _ "$YADM_SRC/scripts/syncopated-theme.sh" "$T"
  [ "$status" -eq 0 ]
  grep -qx 'title Installing Rust toolchain' "$T/calls"
  [[ $output == *"✓ Rust toolchain"* ]]
  [[ $output != *hi* ]]
  grep -q hi "$T/log"
}

@test "run_item under gum preserves a failing status and shows the output" {
  gum_stub
  run bash -c 'source "$1"; LOG_FILE=$2/log; SYNCOPATED_FORCE_INTERACTIVE=1 run_item "X" bash -c "echo bad; exit 4" 2>&1' _ "$YADM_SRC/scripts/syncopated-theme.sh" "$T"
  [ "$status" -eq 4 ]
  [[ $output == *"✗ X"* && $output == *bad* ]]
}

@test "run_item runs an exported shell function under gum" {
  gum_stub
  run bash -c 'source "$1"; LOG_FILE=$2/log; myfn() { echo "arg $1"; }; SYNCOPATED_FORCE_INTERACTIVE=1 run_item "Fn" myfn 42' _ "$YADM_SRC/scripts/syncopated-theme.sh" "$T"
  [ "$status" -eq 0 ]
  grep -q 'arg 42' "$T/log"
}

@test "choose_many keeps everything on an empty answer and honors numbers" {
  run bash -c 'source "$1"; echo | choose_many H A B C 2>/dev/null' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$output" = $'A\nB\nC' ]
  run bash -c 'source "$1"; echo "3,1" | choose_many H A B C 2>/dev/null' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$output" = $'C\nA' ]
}

# systemd_cat_stub : stub systemd-cat to record calls and standard input
systemd_cat_stub() {
  stub systemd-cat 'echo "systemd-cat $*" >>"$T/calls"; cat >>"$T/systemd_cat_in"; exit 0'
}

@test "systemd_cat_log calls systemd-cat with identifier and priority" {
  systemd_cat_stub
  run bash -c 'source "$1"; systemd_cat_log info "hello world"' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  grep -q 'systemd-cat -t yadm-bootstrap -p info' "$T/calls"
  grep -q 'hello world' "$T/systemd_cat_in"
}

@test "systemd_cat_log supports piped stdin input and step prefix" {
  systemd_cat_stub
  run bash -c 'source "$1"; SYNCOPATED_STEP=cargo; printf "line 1\nline 2\n" | systemd_cat_log info' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  grep -q 'systemd-cat -t yadm-bootstrap -p info' "$T/calls"
  grep -q '\[cargo\] line 1' "$T/systemd_cat_in"
  grep -q '\[cargo\] line 2' "$T/systemd_cat_in"
}

@test "systemd_cat_log respects SYNCOPATED_LOG_IDENTIFIER override" {
  systemd_cat_stub
  run bash -c 'SYNCOPATED_LOG_IDENTIFIER=custom-id; source "$1"; systemd_cat_log warning "caution"' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  grep -q 'systemd-cat -t custom-id -p warning' "$T/calls"
  grep -q 'caution' "$T/systemd_cat_in"
}

@test "info, ok, warn, err forward messages to systemd-cat with appropriate priorities" {
  systemd_cat_stub
  run bash -c 'source "$1"; info "step info"; ok "step ok"; warn "step warn" 2>&1; err "step err" 2>&1' _ "$YADM_SRC/scripts/syncopated-theme.sh"
  [ "$status" -eq 0 ]
  grep -q 'systemd-cat -t yadm-bootstrap -p info' "$T/calls"
  grep -q 'systemd-cat -t yadm-bootstrap -p notice' "$T/calls"
  grep -q 'systemd-cat -t yadm-bootstrap -p warning' "$T/calls"
  grep -q 'systemd-cat -t yadm-bootstrap -p err' "$T/calls"
  grep -q 'step info' "$T/systemd_cat_in"
  grep -q 'step ok' "$T/systemd_cat_in"
  grep -q 'step warn' "$T/systemd_cat_in"
  grep -q 'step err' "$T/systemd_cat_in"
}

@test "run_item logs installation start, command output, and exit status to systemd-cat" {
  systemd_cat_stub
  run bash -c 'source "$1"; LOG_FILE=$2/log; SYNCOPATED_STEP=test-step; run_item "Rust toolchain" bash -c "echo building crate; exit 0"' _ "$YADM_SRC/scripts/syncopated-theme.sh" "$T"
  [ "$status" -eq 0 ]
  grep -q 'systemd-cat -t yadm-bootstrap -p info' "$T/calls"
  grep -q 'systemd-cat -t yadm-bootstrap -p notice' "$T/calls"
  grep -q 'Installing Rust toolchain' "$T/systemd_cat_in"
  grep -q 'building crate' "$T/systemd_cat_in"
  grep -q 'Rust toolchain (exit 0)' "$T/systemd_cat_in"
}

@test "gum-helpers log function logs to systemd-cat with level mapped to priority" {
  systemd_cat_stub
  run bash -c 'export GUM_HELPERS_NO_TRAP=1; cd "$2"; source "$1" >/dev/null; log "INFO" "starting up"; log "WARN" "warning alert"; log "ERROR" "something failed"' _ "$YADM_SRC/scripts/gum-helpers.sh" "$T"
  [ "$status" -eq 0 ]
  grep -q 'systemd-cat -t yadm-bootstrap -p info' "$T/calls"
  grep -q 'systemd-cat -t yadm-bootstrap -p warning' "$T/calls"
  grep -q 'systemd-cat -t yadm-bootstrap -p err' "$T/calls"
  grep -q 'starting up' "$T/systemd_cat_in"
  grep -q 'warning alert' "$T/systemd_cat_in"
  grep -q 'something failed' "$T/systemd_cat_in"
}

@test "gum-helpers gum log intercepts and logs to systemd-cat" {
  systemd_cat_stub
  stub gum 'echo "gum $*" >>"$T/calls"; exit 0'
  run bash -c 'export GUM_HELPERS_NO_TRAP=1; cd "$2"; source "$1" >/dev/null; gum log --level error "an error occurred"' _ "$YADM_SRC/scripts/gum-helpers.sh" "$T"
  [ "$status" -eq 0 ]
  grep -q 'systemd-cat -t yadm-bootstrap -p err' "$T/calls"
  grep -q 'an error occurred' "$T/systemd_cat_in"
}

@test "run_item under gum disables echo, passes show-output=false, and drains terminal replies" {
  stub gum 'if [ "$1" = spin ]; then
  shift; while [ "$1" != -- ]; do [ "$1" = --title ] && echo "title $2" >>"$T/calls"; shift; done
  shift; "$@"
else exit 0; fi'
  run bash -c 'source "$1"; LOG_FILE=$2/log; SYNCOPATED_FORCE_INTERACTIVE=1 run_item "Claude-code" bash -c "echo installed; exit 0"' _ "$YADM_SRC/scripts/syncopated-theme.sh" "$T"
  [ "$status" -eq 0 ]
  grep -qx 'title Installing Claude-code' "$T/calls"
  [[ $output == *"✓ Claude-code"* ]]
}

@test "gum-helpers gum spin intercepts spin and runs with show-output=false" {
  stub gum 'echo "gum $*" >>"$T/calls"; exit 0'
  run bash -c 'export GUM=gum GUM_HELPERS_NO_TRAP=1; cd "$2"; source "$1" >/dev/null; gum spin --title "Running" -- sleep 0' _ "$YADM_SRC/scripts/gum-helpers.sh" "$T"
  [ "$status" -eq 0 ]
  grep -q 'gum spin --show-output=false --title Running -- sleep 0' "$T/calls"
}

