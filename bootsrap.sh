#!/usr/bin/env bash
# This script is used to bootstrap the environment for a project.

# Setup logging
SCRIPT_LOG_DIR="${HOME}"
mkdir -p "${SCRIPT_LOG_DIR}"
SCRIPT_LOG="${SCRIPT_LOG_DIR}/setup_$(date +%Y%m%d_%H%M%S).log"
touch "${SCRIPT_LOG}"

# Log function
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${message}" | tee -a "${SCRIPT_LOG}"
}

log "INFO" "Starting setup script"

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
YADM_CMD="$HOME/.local/bin/yadm"
export PATH="$HOME/.local/bin:$PATH"

# ANSIBLE
ANSIBLE_REPO="${ANSIBLE_REPO:-git@github.com:syncopatedX/ansible.git}"

# GUM
GUM_VERSION="0.16.0"
GUM="${GUM:-/usr/bin/gum}" # GUM=/usr/bin/gum ./your_script.sh

# COLORS
COLOR_WHITE=251
COLOR_GREEN=36
COLOR_PURPLE=212
COLOR_YELLOW=221
COLOR_RED=9

# TEMP - Define SCRIPT_TMP_DIR if not already defined in the main script
if [ -z "${SCRIPT_TMP_DIR:-}" ]; then
    SCRIPT_TMP_DIR="$(mktemp -d "/tmp/.tmp.gum_XXXXX")"
    ERROR_MSG="${SCRIPT_TMP_DIR}/gum_helpers.err"
    TRAP_CLEANUP_REQUIRED=true # Flag to indicate cleanup is needed at exit
    log "INFO" "Created temporary directory: ${SCRIPT_TMP_DIR}"
else
    TRAP_CLEANUP_REQUIRED=false
    ERROR_MSG="${SCRIPT_TMP_DIR}/gum_helpers.err"
fi

# TRAP FUNCTIONS
# shellcheck disable=SC2317
trap_error() {
    # If process calls this trap, write error to file to use in exit trap
    local error_msg="Command '${BASH_COMMAND}' failed with exit code $? in function '${1:-unknown}' (line ${2:-unknown})"
    echo "$error_msg" >"$ERROR_MSG"
    log "ERROR" "$error_msg"
}

# shellcheck disable=SC2317
trap_exit() {
    local result_code="$?"

    # Read error msg from file (written in error trap)
    local error=""
    if [ -f "$ERROR_MSG" ]; then
        error="$(<"$ERROR_MSG")"
        rm -f "$ERROR_MSG"
    fi

    # Cleanup temporary directory only if it was created in this script
    if [ "$TRAP_CLEANUP_REQUIRED" = "true" ]; then
        log "INFO" "Cleaning up temporary directory: ${SCRIPT_TMP_DIR}"
        rm -rf "$SCRIPT_TMP_DIR"
    fi

    # When ctrl + c pressed exit without other stuff below
    if [ "$result_code" = "130" ]; then
        log "WARN" "Script interrupted by user"
        gum_warn "Exit..."
        exit 1
    fi

    # Check if this is a clean whisper-stream exit
    if [ "${WHISPER_STREAM_CLEAN_EXIT:-false}" = "true" ]; then
        log "INFO" "whisper-stream exited cleanly"
        # Don't show success message for whisper-stream clean exits
        exit 0
    fi

    # Check if failed and print error
    if [ "$result_code" -gt "0" ]; then
        if [ -n "$error" ]; then
            log "ERROR" "$error"
            gum_fail "$error" # Print error message (if exists)
        else
            log "ERROR" "An unknown error occurred with exit code $result_code"
            gum_fail "An Error occurred" # Otherwise print default error message
        fi

        gum_warn "See ${SCRIPT_LOG} for more information..."
        gum_confirm "Show Logs?" && gum pager --show-line-numbers <"$SCRIPT_LOG" # Ask for show logs?
    else
        log "INFO" "Script completed successfully"
        gum_info "Setup completed successfully!"
    fi

    exit "$result_code" # Exit script
}

# ////////////////////////////////////////////////////////////////////////////////////////////////////
# GUM FUNCTIONS
# ////////////////////////////////////////////////////////////////////////////////////////////////////

gum_init() {
    log "INFO" "Initializing gum"
    # First check if GUM is already executable at the specified path
    if [ ! -x "$GUM" ]; then
        # Check if gum is available in the system path
        local system_gum
        system_gum=$(command -v gum 2>/dev/null)

        # If found in system path, use that
        if [ -n "$system_gum" ] && [ -x "$system_gum" ]; then
            log "INFO" "Found gum binary at: $system_gum"
            GUM="$system_gum"
        # Check common locations
        elif [ -x "/usr/bin/gum" ]; then
            log "INFO" "Found gum binary at: /usr/bin/gum"
            GUM="/usr/bin/gum"
        elif [ -x "/usr/local/bin/gum" ]; then
            log "INFO" "Found gum binary at: /usr/local/bin/gum"
            GUM="/usr/local/bin/gum"
        elif [ -x "$HOME/.local/bin/gum" ]; then
            log "INFO" "Found gum binary at: $HOME/.local/bin/gum"
            GUM="$HOME/.local/bin/gum"
        else
            # If not found anywhere, download it
            log "INFO" "Gum not found, downloading version ${GUM_VERSION}..."
            local gum_url gum_path # Prepare URL with version os and arch
            local os_name arch_name

            os_name=$(uname -s)
            arch_name=$(uname -m)

            log "INFO" "Detected OS: ${os_name}, Architecture: ${arch_name}"

            # https://github.com/charmbracelet/gum/releases
            gum_url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${os_name}_${arch_name}.tar.gz"
            log "INFO" "Downloading from: ${gum_url}"

            if ! curl -Lsf "$gum_url" >"${SCRIPT_TMP_DIR}/gum.tar.gz"; then
                log "ERROR" "Failed to download gum from ${gum_url}"
                echo "Error downloading ${gum_url}" >&2
                return 1
            fi

            log "INFO" "Extracting gum archive"
            if ! tar -xf "${SCRIPT_TMP_DIR}/gum.tar.gz" --directory "$SCRIPT_TMP_DIR"; then
                log "ERROR" "Failed to extract ${SCRIPT_TMP_DIR}/gum.tar.gz"
                echo "Error extracting ${SCRIPT_TMP_DIR}/gum.tar.gz" >&2
                return 1
            fi

            gum_path=$(find "${SCRIPT_TMP_DIR}" -type f -executable -name "gum" -print -quit)
            if [ -z "$gum_path" ]; then
                log "ERROR" "Gum binary not found in extracted archive"
                echo "Error: 'gum' binary not found in '${SCRIPT_TMP_DIR}'" >&2
                return 1
            fi

            log "INFO" "Creating ~/.local/bin directory if it doesn't exist"
            # Ensure ~/.local/bin exists
            if ! mkdir -p "$HOME/.local/bin"; then
                log "ERROR" "Failed to create directory ~/.local/bin"
                echo "Error creating directory ~/.local/bin" >&2
                return 1
            fi

            log "INFO" "Moving gum binary to ~/.local/bin"
            if ! mv "$gum_path" "$HOME/.local/bin/gum"; then
                log "ERROR" "Failed to move ${gum_path} to ~/.local/bin/gum"
                echo "Error moving ${gum_path} to ~/.local/bin/gum" >&2
                return 1
            fi

            log "INFO" "Making gum binary executable"
            if ! chmod +x "$HOME/.local/bin/gum"; then
                log "ERROR" "Failed to make ~/.local/bin/gum executable"
                echo "Error chmod +x ~/.local/bin/gum" >&2
                return 1
            fi

            GUM="$HOME/.local/bin/gum" # Update GUM variable to point to the local binary
            log "INFO" "Gum binary downloaded and made executable at: $GUM"
        fi
    else
        log "INFO" "Gum binary already exists at: $GUM"
    fi

    # Verify gum is executable
    if [ ! -x "$GUM" ]; then
        log "ERROR" "Gum binary is not executable: $GUM"
        echo "Error: Gum binary is not executable: $GUM" >&2
        return 1
    fi

    log "INFO" "Gum initialization completed successfully"
    return 0
}

gum() {
    if [ -n "$GUM" ] && [ -x "$GUM" ]; then
        "$GUM" "$@"
    else
        log "ERROR" "GUM='${GUM}' is not found or executable"
        echo "Error: GUM='${GUM}' is not found or executable" >&2
        return 1
    fi
}

trap_gum_exit() { exit 130; }
trap_gum_exit_confirm() { gum_confirm "Exit?" && trap_gum_exit; }

# ////////////////////////////////////////////////////////////////////////////////////////////////////
# GUM WRAPPER
# ////////////////////////////////////////////////////////////////////////////////////////////////////

# Gum colors (https://github.com/muesli/termenv?tab=readme-ov-file#color-chart)
gum_white() { gum_style --foreground "$COLOR_WHITE" "${@}"; }
gum_purple() { gum_style --foreground "$COLOR_PURPLE" "${@}"; }
gum_yellow() { gum_style --foreground "$COLOR_YELLOW" "${@}"; }
gum_red() { gum_style --foreground "$COLOR_RED" "${@}"; }
gum_green() { gum_style --foreground "$COLOR_GREEN" "${@}"; }

# Gum prints
gum_title() { gum join "$(gum_purple --bold "+ ")" "$(gum_purple --bold "${*}")"; }
gum_info() { gum join "$(gum_green --bold "• ")" "$(gum_white "${*}")"; }
gum_warn() { gum join "$(gum_yellow --bold "• ")" "$(gum_white "${*}")"; }
gum_fail() { gum join "$(gum_red --bold "• ")" "$(gum_white "${*}")"; }
gum_success() { gum join "$(gum_green --bold "• ")" "$(gum_purple "${*}")"; }

# Gum wrapper
gum_style() { gum style "${@}"; }
gum_confirm() { gum confirm --prompt.foreground "$COLOR_PURPLE" "${@}"; }
gum_input() { gum input --placeholder "..." --prompt "> " --prompt.foreground "$COLOR_PURPLE" --header.foreground "$COLOR_PURPLE" "${@}"; }
gum_write() { gum write --prompt "> " --header.foreground "$COLOR_PURPLE" --show-cursor-line --char-limit 0 "${@}"; }
gum_choose() { gum choose --cursor "> " --header.foreground "$COLOR_PURPLE" --cursor.foreground "$COLOR_PURPLE" "${@}"; }
gum_filter() { gum filter --prompt "> " --indicator ">" --placeholder "Type to filter..." --height 8 --header.foreground "$COLOR_PURPLE" "${@}"; }
gum_spin() { gum spin --spinner line --title.foreground "$COLOR_PURPLE" --spinner.foreground "$COLOR_PURPLE" "${@}"; }
gum_file() { gum file --header.foreground "$COLOR_PURPLE" --cursor.foreground "$COLOR_PURPLE" --symlink.foreground "$COLOR_YELLOW" "${@}"; }

# Gum key & value
gum_proc() { gum join "$(gum_green --bold "• ")" "$(gum_white --bold "$(print_filled_space 24 "${1}")")" "$(gum_white "  >  ")" "$(gum_green "${2}")"; }
gum_property() { gum join "$(gum_green --bold "• ")" "$(gum_white "$(print_filled_space 24 "${1}")")" "$(gum_green --bold "  >  ")" "$(gum_white --bold "${2}")"; }

# HELPER FUNCTIONS
print_filled_space() {
    local total="$1" && local text="$2" && local length="${#text}"
    [ "$length" -ge "$total" ] && echo "$text" && return 0
    local padding=$((total - length)) && printf '%s%*s\n' "$text" "$padding" ""
}

# Ensure traps are set after sourcing gum_helpers
trap 'trap_exit' EXIT
trap 'trap_error ${FUNCNAME} ${LINENO}' ERR

clone_ansible_repo() {
    local repo_url="${1:-${ANSIBLE_REPO}}"
    local target_dir="${2:-${HOME}/.config/syncopated}"
    
    log "INFO" "Starting ansible repository clone process"
    log "INFO" "Repository URL: ${repo_url}"
    log "INFO" "Target directory: ${target_dir}"
    
    # Check if git is available
    if ! command -v git &>/dev/null; then
        log "ERROR" "Git is not installed"
        gum_fail "Git is required but not installed. Please install git first."
        return 1
    fi
    
    # Check if target directory exists
    if [ -d "$target_dir" ]; then
        log "WARN" "Target directory already exists: ${target_dir}"
        if ! gum_confirm "Directory ${target_dir} already exists. Remove and re-clone?"; then
            log "INFO" "User chose not to overwrite existing directory"
            gum_info "Using existing directory: ${target_dir}"
            return 0
        fi
        
        log "INFO" "Removing existing directory: ${target_dir}"
        if ! rm -rf "$target_dir"; then
            log "ERROR" "Failed to remove existing directory: ${target_dir}"
            gum_fail "Failed to remove existing directory"
            return 1
        fi
    fi
    
    # Create parent directory if it doesn't exist
    local parent_dir
    parent_dir=$(dirname "$target_dir")
    if [ ! -d "$parent_dir" ]; then
        log "INFO" "Creating parent directory: ${parent_dir}"
        if ! mkdir -p "$parent_dir"; then
            log "ERROR" "Failed to create parent directory: ${parent_dir}"
            gum_fail "Failed to create parent directory"
            return 1
        fi
    fi
    
    # Clone the repository
    log "INFO" "Cloning repository..."
    gum_info "Cloning ansible repository..."
    
    if ! gum_spin --title "Cloning ${repo_url}..." -- git clone "$repo_url" "$target_dir"; then
        log "ERROR" "Failed to clone repository: ${repo_url}"
        gum_fail "Failed to clone ansible repository"
        return 1
    fi
    
    # Verify the clone was successful
    if [ ! -d "$target_dir/.git" ]; then
        log "ERROR" "Repository clone verification failed - no .git directory found"
        gum_fail "Repository clone verification failed"
        return 1
    fi
    
    log "INFO" "Repository cloned successfully to: ${target_dir}"
    gum_success "Ansible repository cloned successfully!"
    return 0
}

yadm_init() {
    log "INFO" "Initializing yadm"
    # First check if YADM is already executable at the specified path
    if [ ! -x "$YADM" ]; then
        # Check if yadm is available in the system path
        local system_yadm
        system_yadm=$(command -v yadm 2>/dev/null)

        # If found in system path, use that
        if [ -n "$system_yadm" ] && [ -x "$system_yadm" ]; then
            log "INFO" "Found yadm binary at: $system_yadm"
            YADM="$system_yadm"
        # Check common locations
        elif [ -x "/usr/bin/yadm" ]; then
            log "INFO" "Found yadm binary at: /usr/bin/yadm"
            YADM="/usr/bin/yadm"
        elif [ -x "/usr/local/bin/yadm" ]; then
            log "INFO" "Found yadm binary at: /usr/local/bin/yadm"
            YADM="/usr/local/bin/yadm"
        elif [ -x "$HOME/.local/bin/yadm" ]; then
            log "INFO" "Found yadm binary at: $HOME/.local/bin/yadm"
            YADM="$HOME/.local/bin/yadm"
        else
            # If not found anywhere, download the direct binary
            log "INFO" "Yadm not found, downloading direct binary..."
            local yadm_url yadm_path

            yadm_url="https://github.com/yadm-dev/yadm/raw/master/yadm"
            log "INFO" "Downloading from: ${yadm_url}"

            # Ensure ~/.local/bin exists
            if ! mkdir -p "$HOME/.local/bin"; then
                log "ERROR" "Failed to create directory ~/.local/bin"
                echo "Error creating directory ~/.local/bin" >&2
                return 1
            fi

            yadm_path="$HOME/.local/bin/yadm"
            if ! curl -Lsf "$yadm_url" -o "$yadm_path"; then
                log "ERROR" "Failed to download yadm from ${yadm_url}"
                echo "Error downloading ${yadm_url}" >&2
                return 1
            fi

            log "INFO" "Making yadm binary executable"
            if ! chmod +x "$yadm_path"; then
                log "ERROR" "Failed to make ~/.local/bin/yadm executable"
                echo "Error chmod +x ~/.local/bin/yadm" >&2
                return 1
            fi

            YADM="$yadm_path" # Update YADM variable to point to the local binary
            log "INFO" "Yadm binary downloaded and made executable at: $YADM"
        fi
    else
        log "INFO" "Yadm binary already exists at: $YADM"
    fi

    # Verify yadm is executable
    if [ ! -x "$YADM" ]; then
        log "ERROR" "Yadm binary is not executable: $YADM"
        echo "Error: Yadm binary is not executable: $YADM" >&2
        return 1
    fi

    log "INFO" "Yadm initialization completed successfully"
    return 0
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
    gum_info "SSH keys already exist."
    YADM_URL="$YADM_URL_SSH"
    return 0
  fi

  gum_info "SSH keys not found. Attempting to transfer from another host."

  sleep 1
  wipe
  gum_info "enter the host where the ssh keys can be transferred from"
  sleep 0.5
  REMOTE_HOST=$(gum input --placeholder "hostname.domain.net")

  ssh_folder=$(gum input --value "${HOME}/.ssh" --prompt "Enter the folder name for SSH keys: ")

  # Copy SSH keys
  if rsync -avP --delete "${REMOTE_HOST}:~/.ssh/" "${HOME}/.ssh/"; then
    # Set proper permissions for SSH keys
    chmod 700 "${HOME}/.ssh"
    chmod 600 "${HOME}/.ssh"/*
    gum_info "SSH keys successfully transferred and set up." $GREEN
    YADM_URL="$YADM_URL_SSH"
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

# --- Main Application ---

HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname)

export ANSIBLE_HOME="$HOME/.config/syncopated/ansible"
export ANSIBLE_PLUGINS="$ANSIBLE_HOME/plugins/modules"
export ANSIBLE_CONFIG="$ANSIBLE_HOME/ansible.cfg"
export ANSIBLE_INVENTORY="$ANSIBLE_HOME/inventory/dynamic_inventory.py"

# Check if essential commands are installed
if ! command -v ansible &>/dev/null; then
    gum_yellow "Error: ansible is not installed."
    sudo dnf -y install ansible git || {
        gum_fail "Failed to install ansible. Please install it manually."
        exit 1
    }
    gum_success "Ansible installed successfully."
else
    gum_info "Ansible is already installed."
fi

# if ! command -v jq &>/dev/null; then
#     echo "Error: jq is not installed. Please install it to use this script."
#     exit 1
# fi

gum_init # Initialize or install gum

sleep 1

wipe

gum_title "Workstatin Setup - Bootstrap Script"
gum_info "Fedora 42"; sleep 3

gum_info "Hostname: $HOSTNAME"; sleep 1
gum_info "User: $USER"; sleep 1
gum_info "Script Log: ${SCRIPT_LOG}"; sleep 1
gum_info "Ansible Home: $ANSIBLE_HOME"; sleep 1

setup_ssh_keys

gum_green "Cloning Ansible Collection"; sleep 1

if gum_confirm "Is this a controller host?"; then
    gum_info "Cloning Ansible Collection to Workspace"
    mkdir -pv $HOME/Workspace/OS
    cd $HOME/Workspace/OS && \
    git clone --recursive $ANSIBLE_REPO ansible || {
        gum_fail "Failed to clone Ansible repository. Please check the URL or your network connection."
        exit 1
    }
    cd ansible && git checkout development
else
    gum_info "Running local setup..."
    if [ ! -d $ANSIBLE_HOME ]; then
        gum_info "cloning Ansible collection"
        git clone --recursive $ANSIBLE_REPO $ANSIBLE_HOME
        cd $ANSIBLE_HOME && git checkout development
    else
        gum_yellow "ansible collection already exists, updating..."
        cd $ANSIBLE_HOME && git checkout development && git fetch && git pull
    fi
    
    cd $ANSIBLE_HOME && \
    ansible-playbook -K -i inventory/dynamic_inventory.py playbooks/full.yml --limit $HOSTNAME || {
        gum_fail "Failed to run local setup. Please check the logs."
        exit 1
    }
fi


wipe

# clone yadm repository
gum_green "Cloning YADM Repository"; sleep 1

wipe

#handle_yadm_conflicts

gum_info "🎉🎉🎉 Bootstrap process finished! 🎉🎉🎉"
exit 0