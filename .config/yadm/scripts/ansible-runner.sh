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

# detect_terminal_emulator : identify installed graphical terminal emulator in priority order.
detect_terminal_emulator() {
  if [[ -n ${SYNCOPATED_TERMINAL:-} ]] && command -v "$SYNCOPATED_TERMINAL" >/dev/null 2>&1; then
    printf '%s\n' "$SYNCOPATED_TERMINAL"
    return 0
  fi

  local term
  for term in ptyxis kitty foot gnome-terminal xterm; do
    if command -v "$term" >/dev/null 2>&1; then
      printf '%s\n' "$term"
      return 0
    fi
  done
  return 1
}

# launch_terminal TERM TITLE SCRIPT_PATH : execute script inside specified emulator.
launch_terminal() {
  local term=$1
  local title=$2
  local script_path=$3

  case "$term" in
    ptyxis)
      ptyxis -s --title "$title" -- bash "$script_path"
      ;;
    kitty)
      kitty --title "$title" bash "$script_path"
      ;;
    foot)
      foot -T "$title" bash "$script_path"
      ;;
    gnome-terminal)
      gnome-terminal --wait --title="$title" -- bash "$script_path"
      ;;
    xterm)
      xterm -title "$title" -e bash "$script_path"
      ;;
    *)
      "$term" bash "$script_path"
      ;;
  esac
}

# run_in_terminal TERM STEP_NAME CMD_ARGS... : wrapper running ansible-pull in new window.
run_in_terminal() {
  local term=$1
  local step_name=$2
  shift 2
  local -a cmd_args=("$@")

  local wrapper_script status_file
  wrapper_script=$(mktemp -t "ansible-${step_name}-run-XXXXXX.sh")
  status_file=$(mktemp -t "ansible-${step_name}-status-XXXXXX.txt")

  local log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/syncopated"
  local session_log="${SYNCOPATED_ANSIBLE_SESSION_LOG:-${log_dir}/ansible-${step_name}-session.log}"
  local log_identifier="${SYNCOPATED_LOG_IDENTIFIER:-${BOOTSTRAP_LOG_IDENTIFIER:-yadm-ansible-pull}}"

  # shellcheck disable=SC2016
  {
    echo "#!/usr/bin/env bash"
    echo "export ANSIBLE_STDOUT_CALLBACK=${ANSIBLE_STDOUT_CALLBACK@Q}"
    echo "export ANSIBLE_INVENTORY_ENABLED=${ANSIBLE_INVENTORY_ENABLED@Q}"
    echo "export ANSIBLE_LOG_PATH=${ANSIBLE_LOG_PATH@Q}"
    echo "export ANSIBLE_FORCE_COLOR=true"
    echo "export PYTHONUNBUFFERED=1"
    echo "export SESSION_LOG=${session_log@Q}"
    echo "export LOG_IDENTIFIER=${log_identifier@Q}"
    echo "cd ${PWD@Q} || true"
    echo 'if command -v systemd-cat >/dev/null 2>&1; then'
    printf '  ansible-pull %s 2>&1 | tee -a "$SESSION_LOG" >(systemd-cat -t "$LOG_IDENTIFIER" -p info 2>/dev/null || true)\n' "$(printf '%q ' "${cmd_args[@]}")"
    echo '  rc=${PIPESTATUS[0]}'
    echo 'else'
    printf '  ansible-pull %s 2>&1 | tee -a "$SESSION_LOG"\n' "$(printf '%q ' "${cmd_args[@]}")"
    echo '  rc=${PIPESTATUS[0]}'
    echo 'fi'
    echo "echo \"\$rc\" > ${status_file@Q}"
    echo 'if ((rc != 0)); then'
    echo '  echo ""'
    echo '  echo "✗ ansible-pull failed with exit code $rc"'
    echo '  echo "Log file: $ANSIBLE_LOG_PATH"'
    echo '  echo "Session log: $SESSION_LOG"'
    echo '  echo ""'
    echo '  read -r -p "Press [Enter] to close this window..." _ || true'
    echo 'fi'
    echo 'exit "$rc"'
  } > "$wrapper_script"
  chmod +x "$wrapper_script"

  launch_terminal "$term" "Ansible Pull - $step_name" "$wrapper_script"
  local term_rc=$?

  local pull_rc=1
  if [[ -s "$status_file" ]]; then
    pull_rc=$(<"$status_file")
  elif ((term_rc != 0)); then
    pull_rc=$term_rc
  fi

  rm -f "$wrapper_script" "$status_file"
  return "$pull_rc"
}

# run_ansible_tags STEP_NAME TAGS_CSV [NEEDS_SUDO] [EXTRA_VARS]
# Runs ansible-pull with the specified tags against local.yml.
run_ansible_tags() {
  local step_name=$1
  local tags_csv=$2
  local needs_sudo=${3:-0}
  local extra_vars=${4:-}

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
    if [[ ${SYNCOPATED_ANSIBLE_ASK_BECOME_PASS:-} != "no" && ${SYNCOPATED_ANSIBLE_ASK_BECOME_PASS:-} != "0" ]]; then
      become_args+=(--ask-become-pass)
    fi
  elif [[ ${SYNCOPATED_ANSIBLE_ASK_BECOME_PASS:-} == "yes" || ${SYNCOPATED_ANSIBLE_ASK_BECOME_PASS:-} == "1" ]]; then
    become_args+=(--ask-become-pass)
  fi

  local log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/syncopated"
  mkdir -p "$log_dir"
  export ANSIBLE_STDOUT_CALLBACK=default
  export ANSIBLE_INVENTORY_ENABLED="host_list,script,auto,yaml,toml,ini"
  export ANSIBLE_LOG_PATH="${log_dir}/ansible-${step_name}.log"
  export SYNCOPATED_ANSIBLE_SESSION_LOG="${log_dir}/ansible-${step_name}-session.log"

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
  if [[ -n ${SYNCOPATED_ANSIBLE_EXTRA_VARS:-} ]]; then
    if [[ -n $extra_vars ]]; then
      extra_vars="$extra_vars ${SYNCOPATED_ANSIBLE_EXTRA_VARS}"
    else
      extra_vars="${SYNCOPATED_ANSIBLE_EXTRA_VARS}"
    fi
  fi
  if [[ -n $extra_vars ]]; then
    pull_args+=(--extra-vars "$extra_vars")
  fi
  pull_args+=(--tags "$tags_csv" "$playbook")

  local term=""
  if [[ -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} ]] && [[ ${SYNCOPATED_ANSIBLE_TERMINAL:-1} != "0" && ${SYNCOPATED_ANSIBLE_TERMINAL:-} != "inline" ]]; then
    term=$(detect_terminal_emulator) || term=""
  fi

  local pull_rc=0
  if [[ -n $term ]]; then
    info "Applying $playbook (tags: $tags_csv) in terminal ($term)"
    run_in_terminal "$term" "$step_name" "${pull_args[@]}"
    pull_rc=$?
  else
    info "Applying $playbook (tags: $tags_csv) from $repo_url"
    local session_log="${SYNCOPATED_ANSIBLE_SESSION_LOG:-${log_dir}/ansible-${step_name}-session.log}"
    if have_systemd_cat; then
      ansible-pull "${pull_args[@]}" 2>&1 | tee -a "$session_log" >(systemd_cat_log info)
      pull_rc=${PIPESTATUS[0]}
    else
      ansible-pull "${pull_args[@]}" 2>&1 | tee -a "$session_log"
      pull_rc=${PIPESTATUS[0]}
    fi
  fi

  if ((pull_rc != 0)); then
    err "ansible-pull failed for $step_name"
    return "${RC_FAILED:-1}"
  fi

  ok "Playbook applied successfully for $step_name"
  return "${RC_OK:-0}"
}
