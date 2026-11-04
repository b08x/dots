#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/scripts/ansible-runner.sh" "$T/yadm/scripts/"
  cp "$YADM_SRC/bootstrap.d/01-ansible-system.sh" "$T/yadm/bootstrap.d/"
  cp "$YADM_SRC/bootstrap.d/02-ansible-desktop.sh" "$T/yadm/bootstrap.d/"
  cp "$YADM_SRC/bootstrap.d/03-ansible-tools.sh" "$T/yadm/bootstrap.d/"
  cp "$YADM_SRC/bootstrap.d/04-ansible-user.sh" "$T/yadm/bootstrap.d/"

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
  stub ansible-pull 'echo "${ANSIBLE_STDOUT_CALLBACK:-unset}" >>"$T/cb"; echo "${ANSIBLE_INVENTORY_ENABLED:-unset}" >>"$T/inv_enabled"; echo "${ANSIBLE_LOG_PATH:-unset}" >>"$T/log_path"; echo "ansible-pull $*" >>"$T/calls"; exit "${ANSIBLE_PULL_RC:-0}"'
  stub sudo 'echo "sudo $*" >>"$T/calls"; if [[ "$*" == *"-n true"* ]]; then exit "${SUDO_N_RC:-0}"; fi; exit 0'

  unset SYNCOPATED_ANSIBLE_TAGS SYNCOPATED_ANSIBLE_SYSTEM_TAGS SYNCOPATED_ANSIBLE_DESKTOP_TAGS SYNCOPATED_ANSIBLE_TOOLS_TAGS SYNCOPATED_ANSIBLE_USER_TAGS
  unset SYNCOPATED_ANSIBLE_PULL_URL SYNCOPATED_ANSIBLE_PULL_PLAYBOOK SYNCOPATED_ANSIBLE_PULL_CHECKOUT SYNCOPATED_ANSIBLE_PULL_BRANCH SYNCOPATED_ANSIBLE_PULL_INVENTORY
  unset SYNCOPATED_ANSIBLE_ASK_BECOME_PASS SYNCOPATED_GPU_DETECTED SYNCOPATED_KVM_DETECTED SYNCOPATED_DESKTOP
}

teardown() { cleanup_env; }

run_system() { run bash "$T/yadm/bootstrap.d/01-ansible-system.sh" </dev/null; }
run_desktop() { run bash "$T/yadm/bootstrap.d/02-ansible-desktop.sh" </dev/null; }
run_tools() { run bash "$T/yadm/bootstrap.d/03-ansible-tools.sh" </dev/null; }
run_user() { run bash "$T/yadm/bootstrap.d/04-ansible-user.sh" </dev/null; }

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

@test "ansible-runner passes --ask-become-pass when needs_sudo=1, interactive, and password required" {
  export SUDO_N_RC=1 SYNCOPATED_FORCE_INTERACTIVE=1
  run bash -c 'source "$1"; run_ansible_tags "priv" "system" 1' _ "$T/yadm/scripts/ansible-runner.sh"
  [ "$status" -eq 0 ]
  grep -q "ansible-pull --ask-become-pass --url" "$T/calls"
}

@test "ansible-runner does NOT pass --ask-become-pass when sudo -n true succeeds" {
  export SUDO_N_RC=0 SYNCOPATED_FORCE_INTERACTIVE=1
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

# --- 01-ansible-system tests ---

@test "ansible-system runs with full hardware defaults when GPU and KVM detected" {
  export SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=1
  run_system
  [ "$status" -eq 0 ]
  grep -q -- "--tags repos,common,tuning,networking,gpu,containerd,libvirt local.yml" "$T/calls"
}

@test "ansible-system deselects gpu when no GPU detected" {
  export SYNCOPATED_GPU_DETECTED=0 SYNCOPATED_KVM_DETECTED=1
  run_system
  [ "$status" -eq 0 ]
  grep -q -- "--tags repos,common,tuning,networking,containerd,libvirt local.yml" "$T/calls"
  ! grep -q -- "gpu" "$T/calls"
}

@test "ansible-system deselects libvirt when KVM is absent" {
  export SYNCOPATED_GPU_DETECTED=1 SYNCOPATED_KVM_DETECTED=0
  run_system
  [ "$status" -eq 0 ]
  grep -q -- "--tags repos,common,tuning,networking,gpu,containerd local.yml" "$T/calls"
  ! grep -q -- "libvirt" "$T/calls"
}

@test "ansible-system respects SYNCOPATED_ANSIBLE_SYSTEM_TAGS override" {
  export SYNCOPATED_ANSIBLE_SYSTEM_TAGS="common,networking"
  run_system
  [ "$status" -eq 0 ]
  grep -q -- "--tags common,networking local.yml" "$T/calls"
}

@test "ansible-system respects general SYNCOPATED_ANSIBLE_TAGS override" {
  export SYNCOPATED_ANSIBLE_TAGS="tuning"
  run_system
  [ "$status" -eq 0 ]
  grep -q -- "--tags tuning local.yml" "$T/calls"
}

# --- 02-ansible-desktop tests ---

@test "ansible-desktop selects desktop_ui and desktop for graphical desktop" {
  export SYNCOPATED_DESKTOP=gnome
  run_desktop
  [ "$status" -eq 0 ]
  grep -q -- "--tags desktop_ui,desktop local.yml" "$T/calls"
}

@test "ansible-desktop deselects desktop_ui when desktop environment is shell" {
  export SYNCOPATED_DESKTOP=shell
  run_desktop
  [ "$status" -eq 0 ]
  grep -q -- "--tags desktop local.yml" "$T/calls"
}

@test "ansible-desktop respects SYNCOPATED_ANSIBLE_DESKTOP_TAGS override" {
  export SYNCOPATED_ANSIBLE_DESKTOP_TAGS="desktop_ui"
  run_desktop
  [ "$status" -eq 0 ]
  grep -q -- "--tags desktop_ui local.yml" "$T/calls"
}

# --- 03-ansible-tools tests ---

@test "ansible-tools runs with tools tag by default" {
  run_tools
  [ "$status" -eq 0 ]
  grep -q -- "--tags tools local.yml" "$T/calls"
}

@test "ansible-tools respects SYNCOPATED_ANSIBLE_TOOLS_TAGS override" {
  export SYNCOPATED_ANSIBLE_TOOLS_TAGS="custom_tools"
  run_tools
  [ "$status" -eq 0 ]
  grep -q -- "--tags custom_tools local.yml" "$T/calls"
}

# --- 04-ansible-user tests ---

@test "ansible-user runs unprivileged with user tag by default" {
  export SUDO_N_RC=1 SYNCOPATED_FORCE_INTERACTIVE=1
  run_user
  [ "$status" -eq 0 ]
  grep -q -- "--tags user local.yml" "$T/calls"
  ! grep -q -- "--ask-become-pass" "$T/calls"
}

@test "ansible-user respects SYNCOPATED_ANSIBLE_USER_TAGS override" {
  export SYNCOPATED_ANSIBLE_USER_TAGS="dotfiles"
  run_user
  [ "$status" -eq 0 ]
  grep -q -- "--tags dotfiles local.yml" "$T/calls"
}
