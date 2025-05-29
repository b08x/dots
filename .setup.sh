#!/usr/bin/env bash

# ~/.setup.sh
# Initial script: Checks prereqs, installs gum/yadm, handles SSH (with HTTPS fallback), clones repo, runs bootstrap.

set -o pipefail # Exit on pipe failure.

# --- Configuration ---
YADM_REPO_NAME="b08x/dots.git" # <<< YOUR REPO (user/repo.git part)
YADM_URL_SSH="git@github.com:${YADM_REPO_NAME}"
YADM_URL_HTTPS="https://github.com/${YADM_REPO_NAME}"
YADM_URL="" # Will be set by SSH setup

GUM_VERSION="0.16.0"
: "${GUM:=$HOME/.local/bin/gum}"
SCRIPT_TMP_DIR=""
ERROR_MSG_FILE=""
YADM_CMD="$HOME/.local/bin/yadm"
export PATH="$HOME/.local/bin:$PATH"

# --- Basic Logging (Before Gum) ---
log_plain_error() { printf "\033[0;31m[ERROR]\033[0m %s\n" "$@" >&2; }
log_plain_info() { printf "\033[0;32m[INFO]\033[0m %s\n" "$@"; }
log_plain_warn() { printf "\033[0;33m[WARN]\033[0m %s\n" "$@"; }

# --- Prerequisite Check ---
check_hard_prereq() {
    if ! command -v "$1" &> /dev/null; then
        log_plain_error "CRITICAL: Required command '$1' is not installed."
        log_plain_error "Please install it (e.g., 'sudo pacman -S --needed $1') and run this script again."
        exit 1
    fi
}
log_plain_info "Checking hard prerequisites..."
check_hard_prereq "git"
check_hard_prereq "curl"
log_plain_info "✅ git and curl found."

# --- Temp Dir & Cleanup ---
setup_temp_dir() {
    SCRIPT_TMP_DIR="$(mktemp -d "/tmp/.setup_sh_XXXXX")"
    ERROR_MSG_FILE="${SCRIPT_TMP_DIR}/script.err"
    trap cleanup EXIT
}
cleanup() { [ -n "$SCRIPT_TMP_DIR" ] && [ -d "$SCRIPT_TMP_DIR" ] && rm -rf "$SCRIPT_TMP_DIR"; }
setup_temp_dir

# --- Gum Setup (Full version - includes download) ---
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
gum_input() { gum input --placeholder "..." --prompt "> " --prompt.foreground "$COLOR_PURPLE" --header.foreground "$COLOR_PURPLE" "$@"; }
gum_choose() { gum choose --cursor "> " --header.foreground "$COLOR_PURPLE" --cursor.foreground "$COLOR_PURPLE" "$@"; }
gum_filter() { gum filter --prompt "> " --indicator ">" --placeholder "Type to filter..." --height 8 --header.foreground "$COLOR_PURPLE" "$@"; }
gum_spin() { gum spin --spinner dot --title.foreground "$COLOR_PURPLE" --spinner.foreground "$COLOR_PURPLE" --show-output "$@"; }
gum_init() {
    if ! _gum_cmd_exists; then
        log_plain_info "Gum not found, attempting to download v${GUM_VERSION}..."
        local gum_url gum_download_path os_name arch_name
        os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
        arch_name=$(uname -m); case "$arch_name" in x86_64) arch_name="amd64" ;; aarch64) arch_name="arm64" ;; *) arch_name="$arch_name" ;; esac
        gum_url="https://github.com/charmbracelet/gum/releases/download/v0.16.0/gum_0.16.0_Linux_x86_64.tar.gz"
        gum_download_path="${SCRIPT_TMP_DIR}/gum.tar.gz"
        if ! curl -Lsf "$gum_url" -o "$gum_download_path"; then log_plain_error "Failed to download gum." && exit 1; fi
        if ! tar -xzf "$gum_download_path" --directory "$SCRIPT_TMP_DIR"; then log_plain_error "Failed to extract gum." && exit 1; fi
        local extracted_gum_binary=$(find "$SCRIPT_TMP_DIR" -name "gum" -type f -executable -print -quit)
        [ -z "$extracted_gum_binary" ] && log_plain_error "Gum binary not found." && exit 1
        mkdir -p "$HOME/.local/bin" && mv "$extracted_gum_binary" "$GUM" && chmod +x "$GUM" || { log_plain_error "Failed to install gum."; exit 1; }
        log_plain_info "✅ Gum installed to $GUM."
    else log_plain_info "✅ Gum found at $GUM."; fi
}

# --- Yadm Installation ---
install_yadm() {
    gum_title "Yadm Installation"
    if ! command -v yadm &> /dev/null && ! [ -x "$YADM_CMD" ]; then
        gum_info "Yadm not found. Installing to $HOME/.local/bin..."
        mkdir -p "$HOME/.local/bin"
        if gum_spin --title "Downloading yadm..." -- curl -fLo "$YADM_CMD" https://github.com/TheLocehiliosan/yadm/raw/master/yadm; then
            chmod a+x "$YADM_CMD" || gum_fail "Failed to make yadm executable."
            gum_info "✅ Yadm installed successfully."
        else gum_fail "Failed to download yadm."; fi
    else gum_info "✅ Yadm found."; YADM_CMD="yadm"; fi
}

# --- SSH Key Setup (Revised with HTTPS fallback) ---
# Function to check and start ssh-agent if needed
start_ssh_agent() {
    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
        gum_info "Starting ssh-agent..."
        eval "$(ssh-agent -s)" > /dev/null || gum_fail "Failed to start ssh-agent."
    else
        gum_info "ssh-agent is already running."
        # Ensure the current shell knows about the running agent
        # This part can be tricky and might need refinement based on the environment
        if [ -z "$SSH_AUTH_SOCK" ]; then
           export SSH_AUTH_SOCK=$(find /tmp/ssh-*/agent.* -user "$USER" -print 2>/dev/null | head -n 1)
           if [ -z "$SSH_AUTH_SOCK" ]; then
                gum_warn "Could not reliably find existing SSH_AUTH_SOCK. You might need to add keys manually."
           fi
        fi
    fi
}

# Function to attempt copying to clipboard
copy_to_clipboard() {
    local content="$1"
    if command -v xclip &> /dev/null; then
        echo -n "$content" | xclip -selection clipboard
        gum_info "Public key copied to clipboard using xclip."
        return 0
    elif command -v wl-copy &> /dev/null; then
        echo -n "$content" | wl-copy
        gum_info "Public key copied to clipboard using wl-copy."
        return 0
    else
        gum_warn "Could not find xclip or wl-copy. Please copy the key manually."
        return 1
    fi
}

setup_ssh_keys() {
    local ssh_key_path="$HOME/.ssh/id_ed25519"
    gum_title "SSH Key Setup for GitHub"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh" || gum_fail "Failed to create ~/.ssh"

    if gum_confirm "Do you want to set up/use SSH keys for Git (Recommended)?"; then
        if [ -f "$ssh_key_path.pub" ] && gum_confirm "Use existing SSH key ($ssh_key_path.pub)?"; then
            : # Use existing
        else # Generate new
            [ -f "$ssh_key_path.pub" ] && gum_warn "Backing up..." && mv "$ssh_key_path"{,.bak_$(date +%s)} && mv "$ssh_key_path.pub"{,.bak_$(date +%s)}
            local user_email; user_email=$(gum_input --header "Enter email for SSH key:" --value "$(git config user.email || echo 'you@example.com')")
            [ -z "$user_email" ] && gum_fail "Email cannot be empty."
            ssh-keygen -t ed25519 -C "$user_email" -f "$ssh_key_path" -N "" -q || gum_fail "SSH key generation failed."
        fi
        start_ssh_agent && ssh-add "$ssh_key_path" &>/dev/null || gum_warn "Failed to add key to agent."
        local public_key=$(<"$ssh_key_path.pub"); gum_info "Your Public SSH Key"; gum_info "$public_key"; gum_info "lines"
        copy_to_clipboard "$public_key"
        gum_warn "ACTION REQUIRED: Add the key to https://github.com/settings/keys"
        while ! gum_confirm "Have you added the key to GitHub?"; do gum_warn "Please add key."; done
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            gum_info "✅ SSH connection successful! Using SSH URL."
            YADM_URL="$YADM_URL_SSH"
            return 0
        else
            gum_warn "❌ SSH connection failed."
        fi
    fi

    if gum_confirm "SSH not set up or failed. Clone using HTTPS instead? (Read-only for yadm push)"; then
        gum_info "Using HTTPS URL."
        YADM_URL="$YADM_URL_HTTPS"
    else
        gum_fail "Cannot proceed without either SSH or HTTPS clone method."
    fi
}
start_ssh_agent() { if ! pgrep -u "$USER" ssh-agent > /dev/null; then eval "$(ssh-agent -s)" > /dev/null; fi; }
copy_to_clipboard() { local c="$1"; { command -v xclip &>/dev/null && echo -n "$c" | xclip -sel clip; } || { command -v wl-copy &>/dev/null && echo -n "$c" | wl-copy; } || return 1; }

# --- Yadm Conflict Handler (Revised to use $YADM_URL) ---
handle_yadm_conflicts() {
    gum_title "Yadm Dotfile Management"
    local yadm_repo_path="$HOME/.local/share/yadm/repo.git"

    if [ -z "$YADM_URL" ]; then gum_fail "YADM_URL not set!"; fi

    if [ ! -d "$yadm_repo_path" ]; then
        gum_info "Attempting to clone yadm repository: $YADM_URL"
        if ! "$YADM_CMD" clone "$YADM_URL"; then
            gum_warn "Yadm clone failed. Checking for conflicts..."
            if [ ! -d "$yadm_repo_path" ]; then
                 git clone --bare "$YADM_URL" "$yadm_repo_path" || gum_fail "Bare clone failed."
            fi
        else
            gum_info "✅ Yadm cloned. Checking out..."
            "$YADM_CMD" checkout "$HOME" || gum_warn "Checkout had issues, checking conflicts..."
        fi
    else gum_info "Yadm repo exists. Checking status..."; fi

    local conflicting_files=$("$YADM_CMD" status --porcelain | grep -E '^ M|^??' | awk '{print $NF}')
    if [ -z "$conflicting_files" ]; then gum_info "✅ No conflicts found."; return 0; fi

    gum_warn "Found potential conflicts/untracked files:"; echo "$conflicting_files" | "$GUM" style --border normal
    local selected_files; selected_files=$(echo "$conflicting_files" | gum filter --no-limit --height 10)

    if [ -n "$selected_files" ]; then
        local action; action=$(gum_choose "Backup selected" "Delete (Overwrite) selected" "Abort")
        local backup_dir="$HOME/.yadm-backup-$(date +%F_%T)"
        case "$action" in
            "Backup selected")
                mkdir -p "$backup_dir"
                echo "$selected_files" | while read -r file; do mkdir -p "$backup_dir/$(dirname "$file")"; mv "$HOME/$file" "$backup_dir/$(dirname "$file")/" || gum_warn "Failed: $file"; done; gum_info "Backed up.";;
            "Delete (Overwrite) selected")
                if gum_confirm "⚠️ Sure DELETE?"; then echo "$selected_files" | xargs -I {} rm -rf "$HOME/{}"; gum_info "Deleted."; else gum_fail "Aborted."; fi ;;
            "Abort") gum_fail "Aborted.";;
        esac
        "$YADM_CMD" checkout "$HOME" || gum_fail "Checkout failed after handling."
    else gum_warn "No files selected. Proceeding."; fi
     gum_info "✅ Yadm conflict handling finished."
}

if [ -x "$(command -v cargo)" ];
then
  echo "cargo is found!"
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o - | sh
fi

if [ -x "$(command -v choose)" ];
then
  echo "choose is found!"
else
  cargo install choose
fi

if [ -x "$(command -v sd)" ];
then
  echo "sd is found!"
else
  cargo install sd
fi

# --- Main Execution Flow for setup.sh ---
gum_init
gum_title "Starting Workstation Bootstrap (Stage 1)..."
install_yadm
setup_ssh_keys # This will set YADM_URL
handle_yadm_conflicts # This will use YADM_URL to clone

gum_info "Setup complete. Running yadm bootstrap (Stage 2)..."
"$YADM_CMD" bootstrap || gum_fail "Yadm bootstrap script (01-setup.sh) failed!"

gum_info "🎉🎉🎉 Bootstrap process finished! 🎉🎉🎉"
exit 0