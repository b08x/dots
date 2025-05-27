#!/usr/bin/env bash

# .config/yadm/bootstrap.d/01-setup.sh
# Runs via 'yadm bootstrap'. Sets up Ansible and runs ansible-pull.

set -o pipefail # Exit on pipe failure.

# --- Configuration & Gum Setup ---
GUM_VERSION="0.13.0"
: "${GUM:=$HOME/.local/bin/gum}"
SCRIPT_TMP_DIR=""
ERROR_MSG_FILE=""
HAS_SUDO="false"
export PATH="$HOME/.local/bin:$PATH"

# --- Basic Logging (Before Gum) ---
log_plain_error() { printf "\033[0;31m[ERROR]\033[0m %s\n" "$@" >&2; }
log_plain_info() { printf "\033[0;32m[INFO]\033[0m %s\n" "$@"; }

# --- Temp Dir & Cleanup ---
setup_temp_dir() { SCRIPT_TMP_DIR="$(mktemp -d "/tmp/.bootstrap_01_XXXXX")"; ERROR_MSG_FILE="${SCRIPT_TMP_DIR}/script.err"; trap cleanup EXIT; }
cleanup() { [ -n "$SCRIPT_TMP_DIR" ] && [ -d "$SCRIPT_TMP_DIR" ] && rm -rf "$SCRIPT_TMP_DIR"; }
setup_temp_dir

# --- Gum Setup (Copied/Refined) ---
COLOR_WHITE=251; COLOR_GREEN=36; COLOR_PURPLE=212; COLOR_YELLOW=221; COLOR_RED=9
_gum_cmd_exists() { [ -n "$GUM" ] && [ -x "$GUM" ]; }
gum() { if ! _gum_cmd_exists; then log_plain_error "GUM NOT FOUND: $*"; return 1; fi; "$GUM" "$@"; }
gum_style() { gum style "$@"; }
gum_white() { gum_style --foreground "$COLOR_WHITE" "$@"; }
gum_purple() { gum_style --foreground "$COLOR_PURPLE" "$@"; }
gum_yellow() { gum_style --foreground "$COLOR_YELLOW" "$@"; }
gum_red() { gum_style --foreground "$COLOR_RED" "$@"; }
gum_green() { gum_style --foreground "$COLOR_GREEN" "$@"; }
custom_gum_info() { gum join "$(gum_green --bold "• ")" "$(gum_white "$@")"; }
custom_gum_warn() { gum join "$(gum_yellow --bold "• ")" "$(gum_white "$@")"; }
custom_gum_fail() { gum join "$(gum_red --bold "• ")" "$(gum_white "$@")"; exit 1; }
gum_title() { gum join "$(gum_purple --bold "+ ")" "$(gum_purple --bold "$@")"; }
gum_info() { custom_gum_info "$@"; }
gum_warn() { custom_gum_warn "$@"; }
gum_fail() { custom_gum_fail "$@"; }
gum_confirm() { gum confirm --prompt.foreground "$COLOR_PURPLE" "$@"; }
gum_choose() { gum choose --cursor "> " --header.foreground "$COLOR_PURPLE" --cursor.foreground "$COLOR_PURPLE" "$@"; }
gum_filter() { gum filter --prompt "> " --indicator ">" --placeholder "Type to filter..." --height 8 --header.foreground "$COLOR_PURPLE" "$@"; }
gum_spin() { gum spin --spinner dot --title.foreground "$COLOR_PURPLE" --spinner.foreground "$COLOR_PURPLE" --show-output "$@"; }
gum_init() { if ! _gum_cmd_exists; then log_plain_error "Gum ($GUM) expected but not found."; exit 1; fi; }
check_command() { if ! command -v "$1" &> /dev/null; then gum_fail "Required command '$1' is missing."; fi; }

# --- Sudo Check (Copied from Task 4) ---
check_sudo_access() {
    gum_title "Checking for Sudo Access"
    HAS_SUDO="false"
    if [ "$(id -u)" -eq 0 ]; then gum_info "✅ Running as root."; HAS_SUDO="true"; return 0; fi
    if ! command -v sudo &> /dev/null; then gum_warn "⚠️ 'sudo' not found."; return 0; fi
    if sudo -n true 2>/dev/null; then gum_info "✅ Passwordless sudo detected."; HAS_SUDO="true"; return 0; fi
    if gum_confirm "Provide sudo password for system changes?"; then
        if sudo -v; then gum_info "✅ Sudo access confirmed."; HAS_SUDO="true"; return 0;
        else gum_warn "⚠️ Failed to get sudo."; fi
    fi
    [ "$HAS_SUDO" = "false" ] && gum_warn "⚠️ Proceeding without sudo.";
}

# --- Ansible Prereqs & Install (Copied - Verify-Only Version) ---
ensure_ansible_prereqs_and_install() {
    gum_title "Ensuring Ansible Prerequisites & Installation"
    gum_info "Verifying 'git' and 'curl'..."; check_command "git"; check_command "curl"; gum_info "✅ 'git' and 'curl' found."
    if ! command -v uv &> /dev/null; then
        gum_warn "'uv' not found."
        if gum_confirm "Install 'uv' via curl (user-local)?"; then
            gum_spin --title "Running uv install script..." -- bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh" || gum_fail "Failed to install 'uv'."
            export PATH="$HOME/.local/bin:$PATH"
            ! command -v uv &> /dev/null && gum_fail "'uv' installed but not found."
            gum_info "✅ 'uv' installed."; else gum_fail "Cannot proceed without 'uv'."; fi
    else gum_info "✅ 'uv' installed."; fi
    local ANSIBLE_VENV_PATH="$HOME/.local/venvs/ansible"; local ANSIBLE_EXEC="$ANSIBLE_VENV_PATH/bin/ansible-pull" # Changed to ansible-pull
    if [ -x "$ANSIBLE_EXEC" ]; then gum_info "✅ Ansible installed.";
    else
        gum_info "Installing 'ansible-core' via uv..."; mkdir -p "$(dirname "$ANSIBLE_VENV_PATH")"
        gum_spin --title "Creating venv..." -- uv venv "$ANSIBLE_VENV_PATH" --python python3 || gum_fail "Venv creation failed."
        gum_spin --title "Installing ansible..." -- "$ANSIBLE_VENV_PATH/bin/uv" pip install ansible-core || gum_fail "Ansible install failed."
        ! [ -x "$ANSIBLE_VENV_PATH/bin/ansible-playbook" ] && gum_fail "Ansible executable not found." # Check playbook first
        gum_info "✅ Ansible installed."; fi
    [[ ":$PATH:" != *":$ANSIBLE_VENV_PATH/bin:"* ]] && export PATH="$ANSIBLE_VENV_PATH/bin:$PATH"
    gum_info "Ansible ready."
}

# --- Ansible Tag Selection (Copied from Task 7) ---
select_ansible_tags() { # ... [omitted - include full function from Task 7] ... }
select_ansible_tags() {
    local readme_path="$HOME/README.md" ; local available_tags="" ; local selected_tags_str=""
    gum_title "Select Ansible Tags to Run"
    if [ ! -f "$readme_path" ]; then gum_warn "README.md not found. Using defaults."; available_tags="base\nshell\ndocker\naudio\ntools"
    else
        available_tags=$(awk -F'|' '/## 🏷️ Using Tags/{f=1} f&&/\|.*\|.*\|/&&!/---/&&!/Tag/{gsub(/ /,"",$2);print $2} /^## /&&f&&!/## 🏷️ Using Tags/{f=0}' "$readme_path")
        [ -z "$available_tags" ] && gum_warn "No tags parsed. Using defaults." && available_tags="base\nshell\ndocker\naudio\ntools"
    fi
    local selected_tags_arr; mapfile -t selected_tags_arr < <(echo -e "$available_tags" | gum filter --no-limit --height 15)
    if [ ${#selected_tags_arr[@]} -eq 0 ]; then
        if gum_confirm "No tags selected. Run ALL tasks?"; then echo ""; return 0;
        else gum_warn "Aborted."; return 1; fi
    else
        selected_tags_str=$(IFS=,; echo "${selected_tags_arr[*]}")
        gum_info "Selected tags: $selected_tags_str"; echo "$selected_tags_str"; return 0; fi
}


# --- Main Execution Flow ---
gum_init
gum_title "Yadm Bootstrap Stage 2: Ansible Setup & Execution"

check_sudo_access
ensure_ansible_prereqs_and_install || gum_fail "Failed to setup Ansible."

ANSIBLE_TAGS=$(select_ansible_tags)
TAGS_EXIT_CODE=$?

if [ $TAGS_EXIT_CODE -ne 0 ]; then
    gum_fail "Ansible run aborted during tag selection."
fi

# Get the yadm remote URL (handles both SSH and HTTPS)
YADM_PULL_URL=$("$HOME/.local/bin/yadm" remote get-url origin) || gum_fail "Could not get yadm remote URL."
gum_info "Using Ansible Pull URL: $YADM_PULL_URL"

# Define playbook path within the repo
ANSIBLE_PLAYBOOK="main.yml" # <<< ADJUST PLAYBOOK PATH IF NEEDED

# Construct ansible-pull command
ANSIBLE_CMD="ansible-pull -U \"$YADM_PULL_URL\" -d \"$HOME/.ansible-pull-checkout\" \"$ANSIBLE_PLAYBOOK\""
ANSIBLE_CMD="$ANSIBLE_CMD -e 'has_sudo=$HAS_SUDO'" # Pass sudo status

if [ -n "$ANSIBLE_TAGS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD --tags \"$ANSIBLE_TAGS\""
fi

# Add --ask-become-pass if sudo is available and needed
if [ "$HAS_SUDO" = "true" ]; then
    # We assume if sudo is available, we might need the password.
    # A more complex check could see if it's passwordless.
    ANSIBLE_CMD="$ANSIBLE_CMD --ask-become-pass"
fi

gum_info "Executing: $ANSIBLE_CMD"
gum_warn "You might be prompted for your sudo password now..."

# Run ansible-pull
eval "$ANSIBLE_CMD" || gum_fail "Ansible-pull run failed!"

gum_info "✅✅✅ Ansible Pull & Bootstrap Complete! ✅✅✅"
exit 0