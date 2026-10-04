#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/01-ansible-pull.sh" "$T/yadm/bootstrap.d/"
  stub gum 'echo "gum $*" >>"$T/calls"
case $1 in confirm) exit 1 ;; esac
exit 0'
  stub ansible-pull 'echo "${ANSIBLE_STDOUT_CALLBACK:-unset}" >>"$T/cb"; echo "${ANSIBLE_INVENTORY_ENABLED:-unset}" >>"$T/inv_enabled"; echo "ansible-pull $*" >>"$T/calls"; exit "${ANSIBLE_PULL_RC:-0}"'
  unset SYNCOPATED_ANSIBLE_PULL SYNCOPATED_ANSIBLE_PULL_URL SYNCOPATED_ANSIBLE_PULL_PLAYBOOK SYNCOPATED_ANSIBLE_PULL_CHECKOUT SYNCOPATED_ANSIBLE_PULL_BRANCH SYNCOPATED_ANSIBLE_PULL_INVENTORY
}
teardown() { cleanup_env; }

run_pull() { run bash "$T/yadm/bootstrap.d/01-ansible-pull.sh" </dev/null; }

@test "without a terminal the step is skipped without prompting" {
  run_pull
  [ "$status" -eq 2 ]
  [[ $output == *"system playbook skipped"* ]]
  ! grep -q '^gum confirm' "$T/calls"
  ! grep -q '^ansible-pull ' "$T/calls"
}

@test "SYNCOPATED_ANSIBLE_PULL=no skips the step" {
  export SYNCOPATED_ANSIBLE_PULL=no
  run_pull
  [ "$status" -eq 2 ]
  [[ $output == *"system playbook skipped"* ]]
  ! grep -q '^ansible-pull ' "$T/calls"
}

@test "opting in passes the opt-in check and runs ansible-pull against default repository" {
  export SYNCOPATED_ANSIBLE_PULL=yes
  run_pull
  [ "$status" -eq 0 ]
  grep -q '^ansible-pull --url https://gitlab.com/syncopatedX/workstation.git --directory .* --ask-become-pass local.yml$' "$T/calls"
}

@test "opting in with empty repository url skips the step" {
  export SYNCOPATED_ANSIBLE_PULL=yes SYNCOPATED_ANSIBLE_PULL_URL=""
  run_pull
  [ "$status" -eq 2 ]
  [[ $output == *"no system playbook configured"* ]]
  ! grep -q '^ansible-pull ' "$T/calls"
}

@test "runs ansible-pull against the configured repository override" {
  export SYNCOPATED_ANSIBLE_PULL=yes SYNCOPATED_ANSIBLE_PULL_URL=https://example.com/playbook.git
  run_pull
  [ "$status" -eq 0 ]
  grep -q '^ansible-pull --url https://example.com/playbook.git --directory .* --ask-become-pass local.yml$' "$T/calls"
}

@test "supports branch checkout override" {
  export SYNCOPATED_ANSIBLE_PULL=yes SYNCOPATED_ANSIBLE_PULL_BRANCH=development
  run_pull
  [ "$status" -eq 0 ]
  grep -q '^ansible-pull --url https://gitlab.com/syncopatedX/workstation.git --directory .* --checkout development --ask-become-pass local.yml$' "$T/calls"
}

@test "a failing ansible-pull fails the step" {
  export SYNCOPATED_ANSIBLE_PULL=yes ANSIBLE_PULL_RC=1
  run_pull
  [ "$status" -eq 1 ]
}

@test "skips when ansible-pull is not installed" {
  export SYNCOPATED_ANSIBLE_PULL=yes
  rm "$T/bin/ansible-pull"
  run_pull
  [ "$status" -eq 2 ]
  [[ $output == *"ansible-pull is not installed"* ]]
}

@test "sets ANSIBLE_STDOUT_CALLBACK=default when running ansible-pull" {
  export SYNCOPATED_ANSIBLE_PULL=yes
  run_pull
  [ "$status" -eq 0 ]
  [ "$(cat "$T/cb")" = "default" ]
}

@test "sets inventory flag to local hostname by default" {
  export SYNCOPATED_ANSIBLE_PULL=yes
  run_pull
  [ "$status" -eq 0 ]
  local expected_host
  expected_host=${HOSTNAME:-$(hostname 2>/dev/null || uname -n)}
  grep -q -- "--inventory ${expected_host}," "$T/calls"
}

@test "supports inventory override with trailing comma appended when needed" {
  export SYNCOPATED_ANSIBLE_PULL=yes SYNCOPATED_ANSIBLE_PULL_INVENTORY="custom-host"
  run_pull
  [ "$status" -eq 0 ]
  grep -q -- "--inventory custom-host," "$T/calls"
}

@test "exports ANSIBLE_INVENTORY_ENABLED with host_list" {
  export SYNCOPATED_ANSIBLE_PULL=yes
  run_pull
  [ "$status" -eq 0 ]
  grep -q "host_list" "$T/inv_enabled"
}
