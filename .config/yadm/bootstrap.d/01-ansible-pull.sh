#!/usr/bin/env bash
# 01-ansible-pull.sh: apply the Syncopated system playbook with ansible-pull
# (system tuning and other system-level settings).
#
# Optional bootstrap step: asks before doing anything and exits 2 (skipped)
# when declined or when no terminal is attached.
# Override: SYNCOPATED_ANSIBLE_PULL=yes|no answers the opt-in prompt.
#
# Additional overrides: SYNCOPATED_ANSIBLE_PULL_URL,
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

# want_ansible_pull : succeed when the user opts in to applying the system playbook.
# Defaults to no; without a terminal or gum there is no one to ask.
want_ansible_pull() {
  case ${SYNCOPATED_ANSIBLE_PULL:-} in
    yes|true|1) return 0 ;;
    no|false|0) return 1 ;;
  esac
  [[ -t 0 && -t 1 ]] && have_gum || return 1
  gum confirm --default=false --prompt.foreground "${VIOLET[0]}" \
    "Apply system configuration playbook via ansible-pull (requires sudo)?"
}

main() {
  if ! want_ansible_pull; then
    info "ansible-pull: system playbook skipped"
    return "$RC_SKIPPED"
  fi
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
