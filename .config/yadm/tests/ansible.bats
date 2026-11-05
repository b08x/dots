#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/scripts/ansible-runner.sh" "$T/yadm/scripts/"
  cp "$YADM_SRC/bootstrap.d/02-ansible-pull.sh" "$T/yadm/bootstrap.d/"

  stub gum 'echo "gum $*" >>"$T/calls"
if [[ "$1" == "choose" ]]; then
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--selected" ]]; then
      shift
      tr "," "\n" <<<"$1"
      break
    fi
    shift
  done
fi
exit 0'
  stub ansible-pull 'echo "${ANSIBLE_STDOUT_CALLBACK:-unset}" >>"$T/cb"; echo "${ANSIBLE_INVENTORY_ENABLED:-unset}" >>"$T/inv_enabled"; echo "${ANSIBLE_LOG_PATH:-unset}" >>"$T/log_path"; echo "ansible-pull $*" >>"$T/calls"; echo "ansible-pull finished"; exit "${ANSIBLE_PULL_RC:-0}"'
  stub sudo 'echo "sudo $*" >>"$T/calls"; if [[ "$*" == *"-n true"* ]]; then exit "${SUDO_N_RC:-0}"; fi; exit 0'

  unset SYNCOPATED_ANSIBLE_TAGS
  unset SYNCOPATED_ANSIBLE_PULL_URL SYNCOPATED_ANSIBLE_PULL_PLAYBOOK SYNCOPATED_ANSIBLE_PULL_CHECKOUT SYNCOPATED_ANSIBLE_PULL_BRANCH SYNCOPATED_ANSIBLE_PULL_INVENTORY
  unset SYNCOPATED_ANSIBLE_ASK_BECOME_PASS SYNCOPATED_GPU_DETECTED SYNCOPATED_KVM_DETECTED SYNCOPATED_DESKTOP
  unset SYNCOPATED_DESKTOP_UI_ENVIRONMENT SYNCOPATED_ANSIBLE_EXTRA_VARS SYNCOPATED_ANSIBLE_DESKTOP_EXTRA_VARS
}

teardown() { cleanup_env; }

run_pull() { run bash "$T/yadm/bootstrap.d/02-ansible-pull.sh" </dev/null; }

# --- Shared ansible-runner tests ---

@test "ansible-runner executes ansible-pull with default arguments" {
  run bash -c 'source "$1"; run_ansible_tags "test" "common,tools" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  local expected_host
  expected_host=${HOSTNAME:-$(hostname 2>/dev/null || uname -n)}
  grep -q "ansible-pull --url https://gitlab.com/syncopatedX/workstation.git --directory .* --inventory ${expected_host}, --checkout development --tags common,tools local.yml" "$T/calls"
}

@test "ansible-runner exports callback, inventory enabled, and step-specific log path" {
  run bash -c 'source "$1"; run_ansible_tags "mystep" "common" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$T/cb")" = "default" ]
  grep -q "host_list" "$T/inv_enabled"
  grep -q "ansible-mystep.log" "$T/log_path"
}

@test "ansible-runner supports URL, branch, playbook, and inventory overrides" {
  export SYNCOPATED_ANSIBLE_PULL_URL="https://example.com/custom.git"
  export SYNCOPATED_ANSIBLE_PULL_BRANCH="feature-x"
  export SYNCOPATED_ANSIBLE_PULL_PLAYBOOK="site.yml"
  export SYNCOPATED_ANSIBLE_PULL_INVENTORY="customhost"
  run bash -c 'source "$1"; run_ansible_tags "custom" "all" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  grep -q "ansible-pull --url https://example.com/custom.git --directory .* --inventory customhost, --checkout feature-x --tags all site.yml" "$T/calls"
}

@test "ansible-runner skips execution when tags_csv is empty" {
  run bash -c 'source "$1"; run_ansible_tags "empty" "" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  [[ $output == *"no tags selected; skipping execution"* ]]
  ! grep -q "ansible-pull" "$T/calls"
}

@test "ansible-runner skips when playbook URL is empty" {
  export SYNCOPATED_ANSIBLE_PULL_URL=""
  run bash -c 'source "$1"; run_ansible_tags "test" "common" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 2 ]
  [[ $output == *"no playbook URL configured"* ]]
  ! grep -q "ansible-pull" "$T/calls"
}

@test "ansible-runner skips when ansible-pull is missing" {
  rm "$T/bin/ansible-pull"
  run bash -c 'source "$1"; run_ansible_tags "test" "common" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 2 ]
  [[ $output == *"ansible-pull is not installed"* ]]
}

@test "ansible-runner fails when ansible-pull exits non-zero" {
  export ANSIBLE_PULL_RC=1
  run bash -c 'source "$1"; run_ansible_tags "test" "common" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"ansible-pull failed for test"* ]]
}

@test "ansible-runner passes --ask-become-pass when needs_sudo=1" {
  export SUDO_N_RC=1
  run bash -c 'source "$1"; run_ansible_tags "priv" "system" 1' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  grep -q "ansible-pull --ask-become-pass --url" "$T/calls"
}

@test "ansible-runner passes --ask-become-pass when needs_sudo=1 even if sudo -n true succeeds" {
  export SUDO_N_RC=0
  run bash -c 'source "$1"; run_ansible_tags "priv" "system" 1' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  grep -q "ansible-pull --ask-become-pass --url" "$T/calls"
}

@test "ansible-runner respects SYNCOPATED_ANSIBLE_ASK_BECOME_PASS=no override" {
  export SYNCOPATED_ANSIBLE_ASK_BECOME_PASS=no
  run bash -c 'source "$1"; run_ansible_tags "priv" "system" 1' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  ! grep -q -- "--ask-become-pass" "$T/calls"
}

@test "ansible-runner does NOT pass --ask-become-pass when needs_sudo=0" {
  export SUDO_N_RC=1 SYNCOPATED_FORCE_INTERACTIVE=1
  run bash -c 'source "$1"; run_ansible_tags "user" "user" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  ! grep -q -- "--ask-become-pass" "$T/calls"
}

@test "detect_terminal_emulator prioritizes ptyxis over kitty and foot" {
  stub ptyxis 'true'
  stub kitty 'true'
  stub foot 'true'
  run bash -c 'source "$1"; detect_terminal_emulator' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "ptyxis" ]
}

@test "detect_terminal_emulator falls back down priority list" {
  stub foot 'true'
  run bash -c 'source "$1"; detect_terminal_emulator' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "foot" ]
}

@test "detect_terminal_emulator respects SYNCOPATED_TERMINAL override" {
  stub myterm 'true'
  SYNCOPATED_TERMINAL="myterm" run bash -c 'source "$1"; detect_terminal_emulator' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "myterm" ]
}

@test "ansible-runner runs in separate terminal window when display and emulator present" {
  stub ptyxis 'echo "ptyxis $*" >>"$T/calls"; shift 4; "$@"'
  WAYLAND_DISPLAY="wayland-0" run bash -c 'source "$1"; run_ansible_tags "termtest" "common" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  grep -q "ptyxis -s --title Ansible Pull - termtest -- bash " "$T/calls"
  grep -q "ansible-pull --url https://gitlab.com/syncopatedX/workstation.git" "$T/calls"
}

@test "ansible-runner creates session log and forwards to systemd-cat inside terminal" {
  stub ptyxis 'echo "ptyxis $*" >>"$T/calls"; shift 4; "$@"'
  stub systemd-cat 'echo "systemd-cat $*" >>"$T/calls"; cat >>"$T/systemd_cat_in"; exit 0'
  WAYLAND_DISPLAY="wayland-0" run bash -c 'source "$1"; run_ansible_tags "logtest" "common" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.cache/syncopated/ansible-logtest-session.log" ]
  grep -q "ansible-pull finished" "$HOME/.cache/syncopated/ansible-logtest-session.log"
  grep -q "systemd-cat -t yadm-bootstrap -p info" "$T/calls"
}

@test "ansible-runner falls back inline when headless" {
  stub ptyxis 'echo "ptyxis $*" >>"$T/calls"'
  unset WAYLAND_DISPLAY DISPLAY
  run bash -c 'source "$1"; run_ansible_tags "inlinetest" "common" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  ! grep -q "ptyxis" "$T/calls"
  grep -q "ansible-pull --url https://gitlab.com/syncopatedX/workstation.git" "$T/calls"
}

@test "ansible-runner passes --extra-vars when extra_vars is provided" {
  run bash -c 'source "$1"; run_ansible_tags "test" "common" 0 "desktop_ui_environment=gnome"' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  grep -q -- "--extra-vars desktop_ui_environment=gnome --tags common local.yml" "$T/calls"
}

@test "ansible-runner respects SYNCOPATED_ANSIBLE_EXTRA_VARS override" {
  export SYNCOPATED_ANSIBLE_EXTRA_VARS="custom_var=1"
  run bash -c 'source "$1"; run_ansible_tags "test" "common" 0' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  grep -q -- "--extra-vars custom_var=1 --tags common local.yml" "$T/calls"
}

# --- 02-ansible-pull consolidated step tests ---

@test "ansible-pull runs the full workstation convergence as a single -K pull" {
  export SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1 SYNCOPATED_DESKTOP=gnome
  run_pull
  [ "$status" -eq 0 ]
  grep -q -- "--ask-become-pass --url" "$T/calls"
  grep -q -- "--extra-vars desktop_ui_environment=gnome" "$T/calls"
  grep -q -- "--tags repos,common,tuning,networking,gpu,containerd,libvirt,desktop_ui,desktop,tools,user local.yml" "$T/calls"
  [[ $(grep -c '^ansible-pull ' "$T/calls") -eq 1 ]]
}

@test "ansible-pull deselects gpu and libvirt when hardware is absent" {
  export SYNCOPATED_GPU_DETECTED=0 SYNCOPATED_KVM_DETECTED=0 SYNCOPATED_DESKTOP=gnome
  run_pull
  [ "$status" -eq 0 ]
  grep -q -- "--tags repos,common,tuning,networking,containerd,desktop_ui,desktop,tools,user local.yml" "$T/calls"
  ! grep -q ",gpu" "$T/calls"
  ! grep -q ",libvirt" "$T/calls"
}

@test "ansible-pull omits desktop tags and extra vars on a headless host" {
  export SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1 SYNCOPATED_DESKTOP=shell
  run_pull
  [ "$status" -eq 0 ]
  grep -q -- "--tags repos,common,tuning,networking,gpu,containerd,libvirt,tools,user local.yml" "$T/calls"
  ! grep -q -- "--extra-vars" "$T/calls"
  [[ $output == *"headless"* ]]
}

@test "ansible-pull respects SYNCOPATED_ANSIBLE_TAGS override" {
  export SYNCOPATED_ANSIBLE_TAGS="common,networking"
  run_pull
  [ "$status" -eq 0 ]
  grep -q -- "--tags common,networking local.yml" "$T/calls"
}

@test "ansible-pull passes desktop_ui_environment from SYNCOPATED_DESKTOP_UI_ENVIRONMENT" {
  export SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1 SYNCOPATED_DESKTOP=gnome
  export SYNCOPATED_DESKTOP_UI_ENVIRONMENT=cosmic
  run_pull
  [ "$status" -eq 0 ]
  grep -q -- "--extra-vars desktop_ui_environment=cosmic" "$T/calls"
  grep -q -- "--tags repos,common,tuning,networking,gpu,containerd,libvirt,desktop_ui,desktop,tools,user local.yml" "$T/calls"
}

@test "ansible-pull prompts for desktop environment and tags when interactive" {
  export SYNCOPATED_FORCE_INTERACTIVE=1 SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1 SYNCOPATED_DESKTOP=gnome
  run_pull
  [ "$status" -eq 0 ]
  grep -q "gum choose --header Select desktop environment to configure --selected gnome -- cosmic gnome sway none" "$T/calls"
  grep -q "gum choose --no-limit --ordered --header Select Ansible tags to apply --selected repos,common,tuning,networking,gpu,containerd,libvirt,desktop_ui,desktop,tools,user -- repos common tuning networking gpu containerd libvirt desktop_ui desktop tools user" "$T/calls"
  grep -q -- "--ask-become-pass --url" "$T/calls"
}

@test "ansible-pull respects SYNCOPATED_ANSIBLE_ASK_BECOME_PASS=no override" {
  export SYNCOPATED_ANSIBLE_ASK_BECOME_PASS=no
  export SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1 SYNCOPATED_DESKTOP=gnome
  run_pull
  [ "$status" -eq 0 ]
  ! grep -q -- "--ask-become-pass" "$T/calls"
  grep -q -- "--tags" "$T/calls"
}

@test "ansible-pull fails when the pull exits non-zero" {
  export ANSIBLE_PULL_RC=1 SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1 SYNCOPATED_DESKTOP=gnome
  run_pull
  [ "$status" -eq 1 ]
  [[ $output == *"ansible-pull failed for ansible-pull"* ]]
}

@test "ansible-pull defaults to kitty terminal with session logging when display is present" {
  stub kitty 'echo "kitty $*" >>"$T/calls"; shift 2; "$@"'
  WAYLAND_DISPLAY="wayland-0" SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1 SYNCOPATED_DESKTOP=gnome run_pull
  [ "$status" -eq 0 ]
  grep -q "kitty --title Ansible Pull - ansible-pull bash " "$T/calls"
  grep -q "ansible-pull --ask-become-pass --url https://gitlab.com/syncopatedX/workstation.git" "$T/calls"
  [ -f "$HOME/.cache/syncopated/ansible-ansible-pull-session.log" ]
  grep -q "ansible-pull finished" "$HOME/.cache/syncopated/ansible-ansible-pull-session.log"
}

@test "ansible-pull respects SYNCOPATED_TERMINAL override" {
  stub foot 'echo "foot $*" >>"$T/calls"; shift 2; "$@"'
  stub kitty 'echo "kitty $*" >>"$T/calls"; shift 2; "$@"'
  SYNCOPATED_TERMINAL=foot WAYLAND_DISPLAY="wayland-0" SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1 SYNCOPATED_DESKTOP=gnome run_pull
  [ "$status" -eq 0 ]
  grep -q "foot -T Ansible Pull - ansible-pull bash " "$T/calls"
  ! grep -q "^kitty" "$T/calls"
}
