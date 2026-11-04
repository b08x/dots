#!/usr/bin/env bash
# shellcheck disable=SC2034  # Environment variables and return codes used across sub-steps
# =============================================================================
# ansible-runner.sh: Shared Ansible execution library for Syncopated bootstrap.
# Source this script; it provides run_ansible_tags for modular bootstrap steps.
# =============================================================================

[[ -n ${SYNCOPATED_ANSIBLE_RUNNER_LOADED:-} ]] && return 0
SYNCOPATED_ANSIBLE_RUNNER_LOADED=1

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if [[ -z ${SYNCOPATED_THEME_LOADED:-} ]]; then
  if [[ -f "$SCRIPT_DIR/syncopated-theme.sh" ]]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/syncopated-theme.sh"
  elif [[ -f "${HOME}/.config/yadm/scripts/syncopated-theme.sh" ]]; then
    # shellcheck source=/dev/null
    source "${HOME}/.config/yadm/scripts/syncopated-theme.sh"
  else
    info() { echo "➜ $*"; }
    ok() { echo "✓ $*"; }
    warn() { echo "! $*" >&2; }
    err() { echo "✗ $*" >&2; }
    have_gum() { command -v gum >/dev/null 2>&1; }
    have_systemd_cat() { command -v systemd-cat >/dev/null 2>&1; }
    interactive() { [[ -n ${SYNCOPATED_FORCE_INTERACTIVE:-} ]] || [[ -t 0 && -t 1 ]]; }
    RC_OK=0
    RC_FAILED=1
    RC_SKIPPED=2
  fi
fi

# Default configuration parameters (can be overridden via environment variables)
PLAYBOOK_URL=${SYNCOPATED_ANSIBLE_PULL_URL-https://gitlab.com/syncopatedX/workstation.git}
PLAYBOOK=${SYNCOPATED_ANSIBLE_PULL_PLAYBOOK:-local.yml}
CHECKOUT=${SYNCOPATED_ANSIBLE_PULL_CHECKOUT:-${XDG_CACHE_HOME:-$HOME/.cache}/syncopated/ansible-pull}
BRANCH=${SYNCOPATED_ANSIBLE_PULL_BRANCH:-development}
LOCAL_HOSTNAME=${HOSTNAME:-$(hostname 2>/dev/null || uname -n)}
INVENTORY=${SYNCOPATED_ANSIBLE_PULL_INVENTORY:-"${LOCAL_HOSTNAME},"}

# run_ansible_tags STEP_NAME TAGS_CSV [NEEDS_SUDO]
# Runs ansible-pull with the specified tags against local.yml.
run_ansible_tags() {
  local step_name=$1
  local tags_csv=$2
  local needs_sudo=${3:-0}

  if ! command -v ansible-pull >/dev/null 2>&1; then
    warn "ansible-pull is not installed; $step_name playbook skipped"
    return "${RC_SKIPPED:-2}"
  fi

  local repo_url=${SYNCOPATED_ANSIBLE_PULL_URL-${PLAYBOOK_URL}}
  if [[ -z $repo_url ]]; then
    info "$step_name: no playbook URL configured; skipping"
    return "${RC_SKIPPED:-2}"
  fi

  if [[ -z $tags_csv ]]; then
    info "$step_name: no tags selected; skipping execution"
    return "${RC_OK:-0}"
  fi

  local playbook=${SYNCOPATED_ANSIBLE_PULL_PLAYBOOK:-${PLAYBOOK}}
  local checkout=${SYNCOPATED_ANSIBLE_PULL_CHECKOUT:-${CHECKOUT}}
  local branch=${SYNCOPATED_ANSIBLE_PULL_BRANCH:-${BRANCH}}
  local local_host=${HOSTNAME:-$(hostname 2>/dev/null || uname -n)}
  local inventory=${SYNCOPATED_ANSIBLE_PULL_INVENTORY:-"${local_host},"}
  if [[ -n $inventory && ! -e $inventory && $inventory != *,* ]]; then
    inventory="${inventory},"
  fi

  local -a become_args=()
  if [[ $needs_sudo == "1" || $needs_sudo == "true" || $needs_sudo == "yes" ]]; then
    if [[ ${SYNCOPATED_ANSIBLE_ASK_BECOME_PASS:-} == "yes" || ${SYNCOPATED_ANSIBLE_ASK_BECOME_PASS:-} == "1" ]]; then
      become_args+=(--ask-become-pass)
    elif ! sudo -n true 2>/dev/null; then
      if interactive; then
        become_args+=(--ask-become-pass)
      fi
    fi
  fi

  local log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/syncopated"
  mkdir -p "$log_dir"
  export ANSIBLE_STDOUT_CALLBACK=default
  export ANSIBLE_INVENTORY_ENABLED="host_list,script,auto,yaml,toml,ini"
  export ANSIBLE_LOG_PATH="${log_dir}/ansible-${step_name}.log"

  local -a pull_args=()
  ((${#become_args[@]} > 0)) && pull_args+=("${become_args[@]}")
  pull_args+=(
    --url "$repo_url"
    --directory "$checkout"
  )
  if [[ -n $inventory ]]; then
    pull_args+=(--inventory "$inventory")
  fi
  if [[ -n $branch ]]; then
    pull_args+=(--checkout "$branch")
  fi
  pull_args+=(--tags "$tags_csv" "$playbook")

  info "Applying $playbook (tags: $tags_csv) from $repo_url"

  local pull_rc=0
  if have_systemd_cat; then
    ansible-pull "${pull_args[@]}" 2>&1 | tee >(systemd_cat_log info)
    pull_rc=${PIPESTATUS[0]}
  else
    ansible-pull "${pull_args[@]}"
    pull_rc=$?
  fi

  if ((pull_rc != 0)); then
    err "ansible-pull failed for $step_name"
    return "${RC_FAILED:-1}"
  fi

  ok "Playbook applied successfully for $step_name"
  return "${RC_OK:-0}"
}
