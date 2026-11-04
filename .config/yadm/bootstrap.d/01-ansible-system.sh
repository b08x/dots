#!/usr/bin/env bash
# bootstrap: needs-sudo
# =============================================================================
# 01-ansible-system.sh: apply system configuration playbook via ansible-pull
# Tags: repos, common, tuning, networking, gpu, containerd, libvirt
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

: "${SYNCOPATED_STEP:=ansible-system}"

has_gpu() {
  if [[ -n ${SYNCOPATED_GPU_DETECTED:-} ]]; then
    [[ $SYNCOPATED_GPU_DETECTED == 1 || $SYNCOPATED_GPU_DETECTED == true || $SYNCOPATED_GPU_DETECTED == yes ]]
    return
  fi
  local dri_dir="${SYNCOPATED_DEV_DRI:-/dev/dri}"
  if [[ -d $dri_dir ]] && { compgen -G "$dri_dir/renderD*" >/dev/null || compgen -G "$dri_dir/card*" >/dev/null; }; then
    return 0
  fi
  if compgen -G "/dev/nvidia*" >/dev/null || [[ -d /sys/class/drm/card0 ]]; then
    return 0
  fi
  return 1
}

has_kvm() {
  if [[ -n ${SYNCOPATED_KVM_DETECTED:-} ]]; then
    [[ $SYNCOPATED_KVM_DETECTED == 1 || $SYNCOPATED_KVM_DETECTED == true || $SYNCOPATED_KVM_DETECTED == yes ]]
    return
  fi
  local kvm_dev="${SYNCOPATED_DEV_KVM:-/dev/kvm}"
  [[ -e $kvm_dev ]]
}

main() {
  local all_tags=(repos common tuning networking gpu containerd libvirt)
  local default_tags=(repos common tuning networking)

  if has_gpu; then
    default_tags+=(gpu)
  fi

  default_tags+=(containerd)

  if has_kvm; then
    default_tags+=(libvirt)
  fi

  local defaults_csv
  local IFS=,
  defaults_csv="${default_tags[*]}"

  local tags_csv=""
  if [[ -n ${SYNCOPATED_ANSIBLE_SYSTEM_TAGS:-} ]]; then
    tags_csv="$SYNCOPATED_ANSIBLE_SYSTEM_TAGS"
  elif [[ -n ${SYNCOPATED_ANSIBLE_TAGS:-} ]]; then
    tags_csv="$SYNCOPATED_ANSIBLE_TAGS"
  elif interactive; then
    local picked=()
    mapfile -t picked < <(choose_many_selected "Select Ansible system tags to apply" "$defaults_csv" "${all_tags[@]}")
    tags_csv="${picked[*]}"
  else
    tags_csv="$defaults_csv"
  fi

  run_ansible_tags "ansible-system" "$tags_csv" 1
}

main "$@"
