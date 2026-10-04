#!/usr/bin/env bats

load helpers

setup() {
  make_env
  cp "$YADM_SRC/bootstrap.d/01-ansible-pull.sh" "$T/yadm/bootstrap.d/"
  stub ansible-pull 'echo "ansible-pull $*" >>"$T/calls"; exit "${ANSIBLE_PULL_RC:-0}"'
  unset SYNCOPATED_ANSIBLE_PULL_URL SYNCOPATED_ANSIBLE_PULL_PLAYBOOK SYNCOPATED_ANSIBLE_PULL_CHECKOUT SYNCOPATED_ANSIBLE_PULL_BRANCH
}
teardown() { cleanup_env; }

run_pull() { run bash "$T/yadm/bootstrap.d/01-ansible-pull.sh" </dev/null; }

@test "runs ansible-pull against the default gitlab repository when no url is specified" {
  run_pull
  [ "$status" -eq 0 ]
  grep -q '^ansible-pull --url https://gitlab.com/syncopatedX/workstation.git --directory .* --ask-become-pass local.yml$' "$T/calls"
}

@test "skips without running ansible-pull when url is empty" {
  export SYNCOPATED_ANSIBLE_PULL_URL=""
  run_pull
  [ "$status" -eq 2 ]
  [[ $output == *"no system playbook configured"* ]]
  [ ! -s "$T/calls" ]
}

@test "runs ansible-pull against the configured repository override" {
  export SYNCOPATED_ANSIBLE_PULL_URL=https://example.com/playbook.git
  run_pull
  [ "$status" -eq 0 ]
  grep -q '^ansible-pull --url https://example.com/playbook.git --directory .* --ask-become-pass local.yml$' "$T/calls"
}

@test "supports branch checkout override" {
  export SYNCOPATED_ANSIBLE_PULL_BRANCH=development
  run_pull
  [ "$status" -eq 0 ]
  grep -q '^ansible-pull --url https://gitlab.com/syncopatedX/workstation.git --directory .* --checkout development --ask-become-pass local.yml$' "$T/calls"
}

@test "a failing ansible-pull fails the step" {
  export SYNCOPATED_ANSIBLE_PULL_URL=https://example.com/playbook.git ANSIBLE_PULL_RC=1
  run_pull
  [ "$status" -eq 1 ]
}

@test "skips when ansible-pull is not installed" {
  export SYNCOPATED_ANSIBLE_PULL_URL=https://example.com/playbook.git
  rm "$T/bin/ansible-pull"
  run_pull
  [ "$status" -eq 2 ]
}
