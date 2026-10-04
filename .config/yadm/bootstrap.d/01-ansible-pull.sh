#!/usr/bin/env bash
# 01-ansible-pull.sh: apply the Syncopated system playbook with ansible-pull
# (system tuning and other system-level settings).
#
# Runs ansible-pull against the repository and exits 0 on success, 1 on failure,
# 2 when ansible-pull is not installed or when skipped.
#
# Overrides (used by the bats tests): SYNCOPATED_ANSIBLE_PULL_URL,
# SYNCOPATED_ANSIBLE_PULL_PLAYBOOK, SYNCOPATED_ANSIBLE_PULL_CHECKOUT,
# SYNCOPATED_ANSIBLE_PULL_BRANCH.

set -uo pipefail

# shellcheck source=../scripts/syncopated-theme.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../scripts/syncopated-theme.sh"

# Repository holding the playbook (defaults to the GitLab workstation remote).
PLAYBOOK_URL=${SYNCOPATED_ANSIBLE_PULL_URL-https://gitlab.com/syncopatedX/workstation.git}
# Playbook file inside the repository.
PLAYBOOK=${SYNCOPATED_ANSIBLE_PULL_PLAYBOOK:-local.yml}
# Local checkout directory used by ansible-pull.
CHECKOUT=${SYNCOPATED_ANSIBLE_PULL_CHECKOUT:-${XDG_CACHE_HOME:-$HOME/.cache}/syncopated/ansible-pull}
# Optional branch/tag/commit override.
BRANCH=${SYNCOPATED_ANSIBLE_PULL_BRANCH:-}

main() {
  if [[ -z $PLAYBOOK_URL ]]; then
    info "ansible-pull: no system playbook configured yet"
    return "$RC_SKIPPED"
  fi
  if ! command -v ansible-pull >/dev/null 2>&1; then
    warn "ansible-pull is not installed; system playbook skipped"
    return "$RC_SKIPPED"
  fi
  info "Applying $PLAYBOOK from $PLAYBOOK_URL"
  local -a pull_args=(
    --url "$PLAYBOOK_URL"
    --directory "$CHECKOUT"
  )
  if [[ -n $BRANCH ]]; then
    pull_args+=(--checkout "$BRANCH")
  fi
  pull_args+=(--ask-become-pass "$PLAYBOOK")

  # --ask-become-pass: the playbook changes system settings with sudo.
  if ! ansible-pull "${pull_args[@]}"; then
    err "ansible-pull failed"
    return "$RC_FAILED"
  fi
  ok "System playbook applied"
}

main "$@"
