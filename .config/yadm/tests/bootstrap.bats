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
  add_script 10-one.sh 0
}
teardown() { cleanup_env; }

# add_script NAME RC: a bootstrap.d script that records its run and returns RC.
add_script() {
  printf '#!/bin/bash\necho "script %s" >>"%s/calls"\nexit %s\n' "$1" "$T" "$2" >"$T/yadm/bootstrap.d/$1"
  chmod +x "$T/yadm/bootstrap.d/$1"
}

run_bootstrap() { run bash "$T/yadm/bootstrap" </dev/null; }

# line_of PATTERN: line number of the first output line matching PATTERN.
line_of() { grep -n -- "$1" <<<"$output" | head -1 | cut -d: -f1; }

@test "shows the logo caption, the OS banner and the step list" {
  run_bootstrap
  [ "$status" -eq 0 ]
  [[ $output == *"user configuration · yadm bootstrap"* ]]
  [[ $output == *"Fedora Linux 43"* ]]
  for step in preflight shell decrypt alternates one; do
    [[ $output == *"$step ("* ]]
  done
}

@test "runs preflight, decrypt and alt in order" {
  run_bootstrap
  [ "$status" -eq 0 ]
  d=$(grep -n '^yadm decrypt' "$T/calls" | cut -d: -f1)
  a=$(grep -n '^yadm alt' "$T/calls" | cut -d: -f1)
  s=$(grep -n '^yadm status' "$T/calls" | cut -d: -f1)
  [ "$s" -lt "$d" ]
  [ "$d" -lt "$a" ]
}

@test "bootstrap.d scripts run after the built-in steps, in name order" {
  add_script 20-two.sh 0
  run_bootstrap
  a=$(grep -n '^yadm alt' "$T/calls" | cut -d: -f1)
  one=$(grep -n '^script 10-one' "$T/calls" | cut -d: -f1)
  two=$(grep -n '^script 20-two' "$T/calls" | cut -d: -f1)
  [ "$a" -lt "$one" ]
  [ "$one" -lt "$two" ]
}

@test "skips the shell step when the login shell is zsh" {
  run_bootstrap
  ! grep -q '^sudo usermod' "$T/calls"
  [[ $output == *"- shell (skipped)"* ]]
}

@test "runs usermod -s when the login shell is not zsh" {
  printf '/bin/bash' >"$T/shell"
  run_bootstrap
  grep -q '^sudo usermod -s .*zsh tester' "$T/calls"
  [[ $output == *"✓ shell (ok)"* ]]
}

@test "a failing script is marked failed, exits 1 and later scripts still run" {
  add_script 20-bad.sh 1
  add_script 30-after.sh 0
  run_bootstrap
  [ "$status" -eq 1 ]
  grep -q '^script 30-after' "$T/calls"
  [[ $output == *"✗ bad (failed)"* ]]
  [[ $output == *"✓ after (ok)"* ]]
}

@test "a script returning 2 is skipped and does not fail bootstrap" {
  add_script 20-skip.sh 2
  run_bootstrap
  [ "$status" -eq 0 ]
  [[ $output == *"- skip (skipped)"* ]]
}

@test "the final report lists every step and a summary" {
  add_script 20-bad.sh 1
  run_bootstrap
  for step in preflight shell decrypt alternates one bad; do
    [[ $output == *"$step ("* ]]
  done
  [[ $output == *"Bootstrap finished with failures: "* ]]
  [[ $output == *"1 failed"* ]]
}

@test "the mid-run completion line and removed features are gone" {
  run_bootstrap
  [[ $output != *"Bootstrap complete"* ]]
  [[ $output != *"fastfetch"* ]]
  [[ $output != *"End."* ]]
  ! grep -qE 'get_environment_variables|fastfetch' "$YADM_SRC/bootstrap"
}

@test "a failed decrypt is marked failed and the later steps still run" {
  stub yadm 'echo "yadm $*" >>"$T/calls"; [ "$1" = decrypt ] && exit 1; exit 0'
  run_bootstrap
  [ "$status" -eq 1 ]
  grep -q '^yadm alt' "$T/calls"
  [[ $output == *"✗ decrypt (failed)"* ]]
}

@test "step states are logged to ~/.bootstrap.log" {
  add_script 20-bad.sh 1
  run_bootstrap
  grep -q ' bad failed$' "$HOME/.bootstrap.log"
  grep -q ' one ok$' "$HOME/.bootstrap.log"
}

@test "drift without a terminal backs up and proceeds without prompting" {
  printf 'x\n' >"$HOME/.zshrc"
  stub yadm 'echo "yadm $*" >>"$T/calls"; [ "$1" = status ] && echo " M .zshrc"; exit 0'
  run_bootstrap
  [ "$status" -eq 0 ]
  [[ $output == *"Backup completed"* ]]
}

# --- interactive failure prompt, driven through a pty ------------------------

# run_pty ANSWERS: run bootstrap on a pty, feeding ANSWERS to the prompt.
run_pty() {
  local script_bin
  script_bin=$(PATH=$ORIG_PATH type -P script) || skip "script(1) not available"
  ln -sf "$script_bin" "$T/bin/script"
  run bash -c 'printf "%b" "$1" | script -qec "bash $2 --all" /dev/null' _ "$1" "$T/yadm/bootstrap"
}

@test "retry reruns a failed step" {
  printf '#!/bin/bash\necho "script flaky" >>"%s/calls"\n[ "$(grep -c "script flaky" "%s/calls")" -ge 2 ]\n' "$T" "$T" >"$T/yadm/bootstrap.d/20-flaky.sh"
  chmod +x "$T/yadm/bootstrap.d/20-flaky.sh"
  run_pty '1\n'
  [ "$(grep -c 'script flaky' "$T/calls")" -eq 2 ]
  [ "$status" -eq 0 ]
  [[ $output == *"flaky (ok)"* ]]
}

@test "skip marks the step failed and continues" {
  add_script 20-bad.sh 1
  add_script 30-after.sh 0
  run_pty '2\n'
  [ "$status" -eq 1 ]
  grep -q '^script 30-after' "$T/calls"
  [[ $output == *"bad (failed)"* ]]
}

@test "abort stops with the report and skips the remaining steps" {
  add_script 20-bad.sh 1
  add_script 30-after.sh 0
  run_pty '3\n'
  [ "$status" -eq 1 ]
  ! grep -q '^script 30-after' "$T/calls"
  [[ $output == *"Bootstrap finished with failures"* ]]
  [[ $output == *"after (pending)"* ]]
}

@test "the final step list is drawn once, not repeated by the report" {
  run_bootstrap
  [ "$status" -eq 0 ]
  [ "$(grep -c 'one (ok)' <<<"$output")" -eq 1 ]
}

@test "01-ansible-pull runs first and 91-install-vscode-extensions runs last" {
  names=$(find "$YADM_SRC/bootstrap.d" -maxdepth 1 -type f -printf '%f\n' | sort)
  [ "$(head -n 1 <<<"$names")" = 01-ansible-pull.sh ]
  [ "$(sed -n '$p' <<<"$names")" = 91-install-vscode-extensions.sh ]
}

# --- step selection ----------------------------------------------------------

# run_menu ANSWER: run bootstrap as on a terminal, answering the plain menu.
run_menu() { run bash -c 'printf "%b" "$1" | SYNCOPATED_FORCE_INTERACTIVE=1 bash "$2"' _ "$1" "$T/yadm/bootstrap"; }

@test "--only runs just the named step and reports the rest as not run" {
  run bash "$T/yadm/bootstrap" --only one </dev/null
  [ "$status" -eq 0 ]
  grep -q '^script 10-one' "$T/calls"
  ! grep -q '^yadm decrypt' "$T/calls"
  [[ $output == *"shell (pending)"* ]]
  [[ $output == *"not run"* ]]
}

@test "--only with an unknown step exits 2 and lists the valid steps" {
  run bash "$T/yadm/bootstrap" --only nope </dev/null
  [ "$status" -eq 2 ]
  [[ $output == *"Unknown step(s): nope"* ]]
  [[ $output == *"preflight shell decrypt alternates one"* ]]
  ! grep -q '^script' "$T/calls"
}

@test "--all runs every step on a terminal without the menu" {
  run bash -c 'SYNCOPATED_FORCE_INTERACTIVE=1 bash "$1" --all </dev/null' _ "$T/yadm/bootstrap"
  [ "$status" -eq 0 ]
  [[ $output != *"Select the steps to run"* ]]
  grep -q '^yadm decrypt' "$T/calls"
  grep -q '^script 10-one' "$T/calls"
}

@test "without a terminal there is no menu and every step runs" {
  run_bootstrap
  [[ $output != *"Select the steps to run"* ]]
  grep -q '^yadm decrypt' "$T/calls"
}

@test "the menu lists every step by its readable name" {
  run_menu '\n'
  for label in Preflight Shell Decrypt Alternates One; do
    [[ $output == *") $label"* ]]
  done
}

@test "an empty menu answer keeps every step selected" {
  run_menu '\n'
  [ "$status" -eq 0 ]
  grep -q '^yadm decrypt' "$T/calls"
  grep -q '^script 10-one' "$T/calls"
}

@test "menu numbers pick steps, which run in their normal order" {
  run_menu '5 3\n'
  [ "$status" -eq 0 ]
  d=$(grep -n '^yadm decrypt' "$T/calls" | cut -d: -f1)
  one=$(grep -n '^script 10-one' "$T/calls" | cut -d: -f1)
  [ "$d" -lt "$one" ]
  ! grep -q '^yadm alt' "$T/calls"
  [[ $output == *"alternates (pending)"* ]]
}

@test "selecting nothing prints a message and exits 0" {
  run bash -c 'SYNCOPATED_FORCE_INTERACTIVE=1 bash "$1" </dev/null' _ "$T/yadm/bootstrap"
  [ "$status" -eq 0 ]
  [[ $output == *"nothing selected"* ]]
  ! grep -q '^script' "$T/calls"
}

@test "sudo -v runs once before the steps when a selected step needs sudo" {
  run_menu '2 5\n'
  [ "$(grep -c '^sudo -v' "$T/calls")" -eq 1 ]
}

@test "sudo -v is skipped when no selected step needs it" {
  run_menu '5\n'
  ! grep -q '^sudo -v' "$T/calls"
}

@test "a script marked needs-sudo triggers sudo -v" {
  printf '#!/bin/bash\n# bootstrap: needs-sudo\nexit 0\n' >"$T/yadm/bootstrap.d/20-priv.sh"
  chmod +x "$T/yadm/bootstrap.d/20-priv.sh"
  run_menu '6\n'
  [ "$(grep -c '^sudo -v' "$T/calls")" -eq 1 ]
}

@test "sudo -v is not run without a terminal" {
  run_bootstrap
  ! grep -q '^sudo -v' "$T/calls"
}

@test "bootstrap orchestrator logs lifecycle events and step states to systemd-cat" {
  stub systemd-cat 'echo "systemd-cat $*" >>"$T/calls"; cat >>"$T/systemd_cat_in"; exit 0'
  run_bootstrap
  [ "$status" -eq 0 ]
  grep -q 'systemd-cat -t yadm-bootstrap -p notice' "$T/calls"
  grep -q 'Bootstrap script started' "$T/systemd_cat_in"
  grep -q 'Bootstrap finished' "$T/systemd_cat_in"
  grep -q 'one ok' "$T/systemd_cat_in"
}
