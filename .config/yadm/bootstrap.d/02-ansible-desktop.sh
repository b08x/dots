#!/usr/bin/env bash
# bootstrap: needs-sudo
# =============================================================================
# 02-ansible-desktop.sh: apply desktop configuration playbook via ansible-pull
# Tags: desktop_ui, desktop
# =============================================================================

set -uo pipefail

THEME_FILE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../scripts/syncopated-theme.sh"
if [[ -f "$THEME_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$THEME_FILE"
elif [[ -f "${HOME}/.config/yadm/scripts/syncopated-theme.sh" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.config/yadm/scripts/syncopated-theme.sh"
fi

RUNNER_FILE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../scripts/ansible-runner.sh"
if [[ -f "$RUNNER_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$RUNNER_FILE"
elif [[ -f "${HOME}/.config/yadm/scripts/ansible-runner.sh" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.config/yadm/scripts/ansible-runner.sh"
fi

: "${SYNCOPATED_STEP:=ansible-desktop}"

main() {
  local all_tags=(desktop_ui desktop)
  local desktop_env=${SYNCOPATED_DESKTOP:-$(detect_desktop)}
  local default_tags=()

  if [[ $desktop_env != "shell" ]]; then
    default_tags=(desktop_ui desktop)
  else
    default_tags=(desktop)
  fi

  local defaults_csv
  local IFS=,
  defaults_csv="${default_tags[*]}"

  local tags_csv=""
  if [[ -n ${SYNCOPATED_ANSIBLE_DESKTOP_TAGS:-} ]]; then
    tags_csv="$SYNCOPATED_ANSIBLE_DESKTOP_TAGS"
  elif [[ -n ${SYNCOPATED_ANSIBLE_TAGS:-} ]]; then
    tags_csv="$SYNCOPATED_ANSIBLE_TAGS"
  elif interactive; then
    local picked=()
    mapfile -t picked < <(choose_many_selected "Select Ansible desktop tags to apply" "$defaults_csv" "${all_tags[@]}")
    tags_csv="${picked[*]}"
  else
    tags_csv="$defaults_csv"
  fi

  run_ansible_tags "ansible-desktop" "$tags_csv" 1
}

main "$@"
