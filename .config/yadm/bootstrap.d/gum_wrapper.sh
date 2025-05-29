#!/usr/bin/env bash

# GUM
GUM_VERSION="0.16.0"
: "${GUM:=$HOME/.local/bin/gum}" # GUM=/usr/bin/gum ./your_script.sh

# COLORS
COLOR_WHITE=251
COLOR_GREEN=36
COLOR_PURPLE=212
COLOR_YELLOW=221
COLOR_RED=9

SCRIPT_TMP_DIR="$(mktemp -d "/tmp/.tmp.gum_XXXXX")"
log "INFO" "Created temporary directory: ${SCRIPT_TMP_DIR}"

# TEMP - Define SCRIPT_TMP_DIR if not already defined in the main script
if [ -z "$SCRIPT_TMP_DIR" ]; then
    SCRIPT_TMP_DIR="$(mktemp -d "/tmp/.tmp.gum_XXXXX")"
    ERROR_MSG="${SCRIPT_TMP_DIR}/gum_helpers.err"
    TRAP_CLEANUP_REQUIRED=true # Flag to indicate cleanup is needed at exit
else
    TRAP_CLEANUP_REQUIRED=false
    ERROR_MSG="${SCRIPT_TMP_DIR}/gum_helpers.err"
fi

# TRAP FUNCTIONS
# shellcheck disable=SC2317
trap_error() {
    # If process calls this trap, write error to file to use in exit trap
    local error_msg="Command '${BASH_COMMAND}' failed with exit code $? in function '${1}' (line ${2})"
    echo "$error_msg" >"$ERROR_MSG"
    log "ERROR" "$error_msg"
}

# shellcheck disable=SC2317
trap_exit() {
    local result_code="$?"

    # Read error msg from file (written in error trap)
    local error && [ -f "$ERROR_MSG" ] && error="$(<"$ERROR_MSG")" && rm -f "$ERROR_MSG"

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

# Gum wrapper
gum_style() { gum style "${@}"; }
gum_confirm() { gum confirm --prompt.foreground "$COLOR_PURPLE" "${@}"; }
gum_input() { gum input --placeholder "..." --prompt "> " --prompt.foreground "$COLOR_PURPLE" --header.foreground "$COLOR_PURPLE" "${@}"; }
gum_write() { gum write --prompt "> " --header.foreground "$COLOR_PURPLE" --show-cursor-line --char-limit 0 "${@}"; }
gum_choose() { gum choose --cursor "> " --header.foreground "$COLOR_PURPLE" --cursor.foreground "$COLOR_PURPLE" "${@}"; }
gum_filter() { gum filter --prompt "> " --indicator ">" --placeholder "Type to filter..." --height 8 --header.foreground "$COLOR_PURPLE" "${@}"; }
gum_spin() { gum spin --spinner line --title.foreground "$COLOR_PURPLE" --spinner.foreground "$COLOR_PURPLE" "${@}"; }

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
