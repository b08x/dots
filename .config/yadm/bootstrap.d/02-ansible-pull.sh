#!/usr/bin/env bash
# bootstrap: needs-sudo
# =============================================================================
# 02-ansible-pull.sh: converge the entire workstation via one ansible-pull run
# Consolidates the former 01-ansible-system / 02-ansible-desktop /
# 03-ansible-tools / 04-ansible-user steps into a single privileged pull
# (--ask-become-pass, i.e. -K) against local.yml.
#
# Default tags (hardware- and desktop-aware):
#   repos,common,tuning,networking[,gpu],containerd[,libvirt],
#   [desktop_ui,desktop,]tools,user
#
# Tag selection precedence:
#   SYNCOPATED_ANSIBLE_TAGS  >  interactive menu  >  detected defaults
# Desktop environment override: SYNCOPATED_DESKTOP_UI_ENVIRONMENT
# (leading SYNCOPATED_DESKTOP / detect_desktop).
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

: "${SYNCOPATED_STEP:=ansible-pull}"
: "${SYNCOPATED_TERMINAL:=kitty}"
export SYNCOPATED_TERMINAL

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
  # --- firstboot marker (parity hinge) ---------------------------------------
  # The workstation ansible pull writes ~/.initial-firstboot (the primary
  # workstation user's home; root:root 0644, world-readable) after a full
  # convergence run (roles/user in the workstation repo is its single
  # writer). When the marker exists, this machine has already been converged
  # through the same pull — ISO-installed machines skip this step, vanilla
  # installs run the pull exactly once. The check is a PLAIN test -f: the
  # marker lives in the user's home precisely so no sudo is needed to see it
  # (root's $HOME and /root are 0550 root:root on stock installs, unstat-able
  # by the non-root console user). SYNCOPATED_ANSIBLE_PULL_FORCE re-converges
  # by name regardless of the marker. This step never writes the marker
  # itself; the pull below is what needs sudo (needs-sudo header).
  local firstboot_marker="${SYNCOPATED_ANSIBLE_PULL_FIRSTBOOT_MARKER:-${HOME:-/home/$(id -un)}/.initial-firstboot}"
  local force="${SYNCOPATED_ANSIBLE_PULL_FORCE:-}"
  if [[ -z $force ]] || [[ $force != 1 && $force != yes && $force != true ]]; then
    if test -f "$firstboot_marker"; then
      info "firstboot ansible-pull already completed; skipping ($firstboot_marker exists; set SYNCOPATED_ANSIBLE_PULL_FORCE=1 to re-converge)"
      return "${RC_SKIPPED:-2}"
    fi
  fi

  local all_tags=(repos common tuning networking gpu containerd libvirt desktop_ui desktop tools user)

  # --- desktop environment --------------------------------------------------
  local default_de="none"
  local detected_env=${SYNCOPATED_DESKTOP:-$(detect_desktop)}
  case $detected_env in
    cosmic|gnome|sway) default_de="$detected_env" ;;
    *) default_de="none" ;;
  esac

  local desktop_env=""
  if [[ -n ${SYNCOPATED_DESKTOP_UI_ENVIRONMENT:-} ]]; then
    desktop_env="$SYNCOPATED_DESKTOP_UI_ENVIRONMENT"
  elif [[ $detected_env == "shell" || $detected_env == "none" ]]; then
    desktop_env="$detected_env"
  elif interactive; then
    desktop_env=$(choose_selected "Select desktop environment to configure" "$default_de" "cosmic" "gnome" "sway" "none") || desktop_env="$default_de"
  else
    desktop_env="$default_de"
  fi
  [[ -z $desktop_env ]] && desktop_env="$default_de"

  local graphical=1
  if [[ $desktop_env == "none" || $desktop_env == "shell" ]]; then
    graphical=0
  fi

  # --- default tags ----------------------------------------------------------
  local default_tags=(repos common tuning networking)
  has_gpu && default_tags+=(gpu)
  default_tags+=(containerd)
  has_kvm && default_tags+=(libvirt)
  ((graphical)) && default_tags+=(desktop_ui desktop)
  default_tags+=(tools user)

  local defaults_csv=""
  local IFS=,
  defaults_csv="${default_tags[*]}"
  unset IFS

  local tags_csv=""
  if [[ -n ${SYNCOPATED_ANSIBLE_TAGS:-} ]]; then
    tags_csv="$SYNCOPATED_ANSIBLE_TAGS"
  elif interactive; then
    local picked=()
    mapfile -t picked < <(choose_many_selected "Select Ansible tags to apply" "$defaults_csv" "${all_tags[@]}")
    local joined=""
    local IFS=,
    joined="${picked[*]}"
    unset IFS
    tags_csv="$joined"
  else
    tags_csv="$defaults_csv"
  fi

  # --- extra vars ------------------------------------------------------------
  local extra_vars=""
  if [[ $graphical -eq 1 ]]; then
    extra_vars="desktop_ui_environment=$desktop_env"
  fi

  if [[ -z $tags_csv ]]; then
    info "No Ansible tags selected; skipping ansible-pull"
    return "${RC_OK:-0}"
  fi

  if ((graphical)); then
    info "Converging workstation (desktop: $desktop_env)"
  else
    info "Converging workstation (headless: $desktop_env)"
  fi

  # -K: single privileged pull (--ask-become-pass) for the whole convergence
  run_ansible_tags "ansible-pull" "$tags_csv" 1 "$extra_vars"
}

main "$@"
