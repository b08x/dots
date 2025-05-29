#!/usr/bin/env bash

# ~/.setup.sh
# Initial script: Checks prereqs, installs gum/yadm, handles SSH (with HTTPS fallback), clones repo, runs bootstrap.

set -o pipefail # Exit on pipe failure.

# set a trap to exit with CTRL+C
ctrl_c() {
        echo "** End."
        sleep 1
}

trap ctrl_c INT SIGINT SIGTERM ERR EXIT

# --- Wipe Screen Function ---
wipe() {
  tput -S <<!
clear
cup 1
!
}

wipe
# --- Configuration ---
YADM_URL_SSH="git@github.com:b08x/dots.git"
YADM_URL_HTTPS="https://github.com/b08x/dots.git"
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
# _gum_cmd_exists is unused
gum() {
    # GUM must be set by gum_init to a valid executable path.
    # gum_init ensures this or exits if it cannot make GUM executable.
    "$GUM" "$@"
}
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
    # Attempt to find gum in PATH first
    if command -v gum &>/dev/null; then
        local system_gum_path
        system_gum_path=$(command -v gum)
        if [ -x "$system_gum_path" ]; then
            GUM="$system_gum_path" # Use system-wide gum
            log_plain_info "✅ Gum found in PATH at $GUM."
            return 0
        else
            log_plain_warn "Gum found in PATH at '$system_gum_path' but it is not executable. Attempting local installation/check."
            # GUM remains its default value ($HOME/.local/bin/gum) for the next checks/installation
        fi
    fi

    # If not found in PATH or system one not executable, check if $GUM (default $HOME/.local/bin/gum) is already installed and executable
    # GUM is already defaulted to $HOME/.local/bin/gum by: : "${GUM:=$HOME/.local/bin/gum}"
    if [ -x "$GUM" ]; then
        log_plain_info "✅ Gum found at $GUM."
        return 0
    fi

    # If neither system-wide nor local $GUM exists and is executable, proceed to download to $GUM
    log_plain_info "Gum not found or not executable. Attempting to download v${GUM_VERSION} to $GUM..."

    local gum_url gum_download_path os_name arch_name
    os_name=$(uname -s)
    arch_name=$(uname -m)
    case "$arch_name" in
        x86_64) arch_name="x86_64" ;;
        aarch64) arch_name="arm64" ;;
        *) arch_name="$arch_name" ;; # Keep original if not x86_64 or aarch64
    esac
    gum_url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${os_name}_${arch_name}.tar.gz"
    gum_download_path="${SCRIPT_TMP_DIR}/gum.tar.gz"

    mkdir -p "$(dirname "$GUM")" || { log_plain_error "Failed to create directory $(dirname "$GUM")."; exit 1; }

    if ! curl -Lsf "$gum_url" -o "$gum_download_path"; then log_plain_error "Failed to download gum from $gum_url." && exit 1; fi
    if ! tar -xzf "$gum_download_path" --directory "$SCRIPT_TMP_DIR"; then log_plain_error "Failed to extract gum." && exit 1; fi

    local extracted_gum_binary
    extracted_gum_binary=$(find "$SCRIPT_TMP_DIR" -name "gum" -type f -executable -print -quit)
    [ -z "$extracted_gum_binary" ] && log_plain_error "Gum binary not found in the downloaded archive. Contents of $SCRIPT_TMP_DIR: $(ls -A "$SCRIPT_TMP_DIR")" && exit 1

    mv "$extracted_gum_binary" "$GUM" || { log_plain_error "Failed to move gum to $GUM."; exit 1; }
    chmod +x "$GUM" || { log_plain_error "Failed to make $GUM executable."; exit 1; }
    log_plain_info "✅ Gum installed to $GUM."

    # Final verification that $GUM is now executable
    if ! [ -x "$GUM" ]; then
        log_plain_error "Gum installation appears to have failed. $GUM is not executable."
        exit 1
    fi
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

# --- SSH Key Setup (Idempotent) ---
setup_ssh_keys() {
  if [ -f "${HOME}/.ssh/id_ed25519" ] && [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
    say "SSH keys already exist." $GREEN
    return 0
  fi

  gum_info "SSH keys not found. Attempting to transfer from another host."

  REMOTE_HOST=$(gum input --placeholder "hostname.domain.net" --prompt "Enter the hostname where SSH keys are stored: ")
  ssh_folder=$(gum input --value "${HOME}/.ssh" --prompt "Enter the folder name for SSH keys: ")

  # Copy SSH keys
  if rsync -avP --delete "${REMOTE_HOST}:~/.ssh/" "${HOME}/.ssh/"; then
    # Set proper permissions for SSH keys
    chmod 700 "${HOME}/.ssh"
    chmod 600 "${HOME}/.ssh"/*
    gum_info "SSH keys successfully transferred and set up." $GREEN
    YADM_URL="$YADM_URL_SSH"
    return 0
  else
    gum_info "Failed to transfer SSH keys." $RED
    return 1
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

    local conflicting_files=$("$YADM_CMD" status --porcelain | grep -E '^ M|^\\?\\?' | awk '{print $NF}')
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

sleep 1
wipe
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