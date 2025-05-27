#!/usr/bin/env bash
#
# Script to optionally install a specific Python version from source, then uv,
# and finally create a virtual environment with spaCy (and a transformer model)
# installed via uv and spaCy CLI, with a Gum-enhanced UI.
#
# Usage:
#   ./setup_spacy_env.sh --project-dir /path/to/project [--install-python X.Y.Z] [--spacy-model model_name]
#
# Required Arguments:
#   --project-dir path        Specifies the directory where the .venv will be created. This is mandatory.
#
# Options:
#   --install-python X.Y.Z  If provided, the script will attempt to install the
#                           specified Python version (e.g., 3.11.7) from source.
#                           If not provided, the script will search for an existing
#                           Python (>= 3.11 by default) and use it. If no suitable
#                           Python is found and this flag is not used, the script
#                           will exit with an error.
#   --spacy-model model_name  Specifies the spaCy model to download (e.g., en_core_web_trf).
#                             Defaults to en_core_web_trf.
#

# --- Strict Mode ---
# Error traps will handle detailed error reporting
set -o pipefail # Exit on pipe failure. -e and -u are handled by traps/gum.

# --- Script Information & Logging ---
SCRIPT_NAME=$(basename "$0")
SCRIPT_LOG_DIR="$HOME/.local/share/script_logs"
mkdir -p "$SCRIPT_LOG_DIR" # Ensure log directory exists
SCRIPT_LOG="${SCRIPT_LOG_DIR}/${SCRIPT_NAME%.*}.log"
SCRIPT_TMP_DIR="" # Will be created by gum_setup_temp_dir

# --- GUM Configuration & Functions ---
# GUM
GUM_VERSION="0.13.0"
: "${GUM:=$HOME/.local/bin/gum}" # GUM=/usr/bin/gum ./your_script.sh

# COLORS
COLOR_WHITE=251
COLOR_GREEN=36
COLOR_PURPLE=212
COLOR_YELLOW=221
COLOR_RED=9

ERROR_MSG_FILE="" # Will be set in gum_setup_temp_dir
TRAP_CLEANUP_REQUIRED=false

# Main script log function - appends to SCRIPT_LOG
_log_to_file() {
    # $1: Log level (INFO, WARN, ERROR, DEBUG)
    # $2: Message (all remaining arguments)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] - $2" >>"$SCRIPT_LOG"
}

# Initial log function definitions (before GUM is fully initialized and confirmed)
# These will be redefined in gum_init to use styled GUM output.
log_info() {
    _log_to_file "INFO" "$@"
    echo "[INFO] $@" # Plain echo before gum is ready
}
log_warn() {
    _log_to_file "WARN" "$@"
    echo "[WARN] $@" >&2 # Plain echo to stderr
}
log_error() {
    _log_to_file "ERROR" "$@"
    echo "[ERROR] $@" >&2 # Plain echo to stderr
}
log_debug() { 
    _log_to_file "DEBUG" "$@"
}

# Convenience wrappers, also to be redefined
log() { log_info "$@"; } 
warn() { log_warn "$@"; }
error_exit() {
    log_error "$@" 
    exit 1       
}

gum_setup_temp_dir() {
    if [ -z "$SCRIPT_TMP_DIR" ]; then
        SCRIPT_TMP_DIR="$(mktemp -d "/tmp/.${SCRIPT_NAME%.*}_gum_XXXXX")"
        _log_to_file "INFO" "Created temporary directory: ${SCRIPT_TMP_DIR}"
        TRAP_CLEANUP_REQUIRED=true 
    else
        TRAP_CLEANUP_REQUIRED=false
    fi
    ERROR_MSG_FILE="${SCRIPT_TMP_DIR}/script.err"
}

# TRAP FUNCTIONS
# shellcheck disable=SC2317
trap_error() {
    local func_name="${1:-unknown_function}"
    local line_num="${2:-unknown_line}"
    local bash_command_info=""
    # Check if BASH_COMMAND is set and not empty, to avoid issues in some shells or contexts
    if [ -n "${BASH_COMMAND:-}" ]; then
        bash_command_info="Command '${BASH_COMMAND}' "
    fi
    local error_msg_text="${bash_command_info}failed with exit code $? in function '${func_name}' (line ${line_num})"
    echo "$error_msg_text" >"$ERROR_MSG_FILE" 
}

# shellcheck disable=SC2317
trap_exit() {
    local result_code="$?"
    local error_from_file && [ -f "$ERROR_MSG_FILE" ] && error_from_file="$(<"$ERROR_MSG_FILE")" && rm -f "$ERROR_MSG_FILE"

    if [ "$TRAP_CLEANUP_REQUIRED" = "true" ] && [ -d "$SCRIPT_TMP_DIR" ]; then
        _log_to_file "INFO" "Cleaning up temporary directory: ${SCRIPT_TMP_DIR}"
        rm -rf "$SCRIPT_TMP_DIR"
    fi

    local use_gum_for_exit=false
    if [ -n "$GUM" ] && [ -x "$GUM" ]; then # Check if GUM is valid for exit messages
        use_gum_for_exit=true
    fi

    if [ "$result_code" = "130" ]; then # Ctrl+C
        _log_to_file "WARN" "Script interrupted by user (SIGINT)"
        if $use_gum_for_exit; then custom_gum_warn "Script interrupted. Exiting..."; else echo "[WARN] Script interrupted. Exiting..."; fi
        exit 130
    fi

    if [ "$result_code" -ne "0" ]; then
        if [ -n "$error_from_file" ]; then
            # Error message was already logged by error_exit (which calls log_error -> custom_gum_fail)
            : 
        else
            _log_to_file "ERROR" "Script exited with an unknown error (code $result_code)."
            if $use_gum_for_exit; then custom_gum_fail "An unexpected error occurred (exit code $result_code)."; else echo "[ERROR] An unexpected error occurred (exit code $result_code)."; fi
        fi
        
        if $use_gum_for_exit; then 
            custom_gum_warn "See ${SCRIPT_LOG} for more details."
            if "$GUM" confirm --default="No" "Show logs now?"; then # GUM confirm is fine here
                "$GUM" pager --show-line-numbers <"$SCRIPT_LOG"
            fi
        else
            echo "[WARN] See ${SCRIPT_LOG} for more details."
        fi
    else
        _log_to_file "INFO" "Script completed successfully."
        if $use_gum_for_exit; then custom_gum_info "Setup completed successfully!"; else echo "[INFO] Setup completed successfully!"; fi
    fi
    exit "$result_code"
}

# GUM CORE AND STYLE FUNCTIONS
_gum_cmd_exists() {
    [ -n "$GUM" ] && [ -x "$GUM" ]
}

gum() { # This is the raw gum command executor
    if ! _gum_cmd_exists; then
        echo "GUM NOT FOUND (tried: $GUM): $*" >&2
        return 1 # Indicates gum command itself failed
    fi
    "$GUM" "$@"
}

gum_style() { gum style "$@"; } 
gum_white() { gum_style --foreground "$COLOR_WHITE" "$@"; }
gum_purple() { gum_style --foreground "$COLOR_PURPLE" "$@"; }
gum_yellow() { gum_style --foreground "$COLOR_YELLOW" "$@"; }
gum_red() { gum_style --foreground "$COLOR_RED" "$@"; }
gum_green() { gum_style --foreground "$COLOR_GREEN" "$@"; }

# GUM CUSTOM PRINT FUNCTIONS (using join and style)
custom_gum_info() { gum join "$(gum_green --bold "• ")" "$(gum_white "$@")"; }
custom_gum_warn() { gum join "$(gum_yellow --bold "• ")" "$(gum_white "$@")"; }
custom_gum_fail() { gum join "$(gum_red --bold "• ")" "$(gum_white "$@")"; }
gum_title() { gum join "$(gum_purple --bold "+ ")" "$(gum_purple --bold "$@")"; }


gum_init() {
    _log_to_file "INFO" "Initializing gum..."
    if ! _gum_cmd_exists; then
        local system_gum
        system_gum=$(command -v gum 2>/dev/null)

        if [ -n "$system_gum" ] && [ -x "$system_gum" ]; then
            _log_to_file "INFO" "Found system gum binary at: $system_gum"
            GUM="$system_gum"
        elif [ -x "/usr/bin/gum" ]; then GUM="/usr/bin/gum"; _log_to_file "INFO" "Found gum at $GUM";
        elif [ -x "/usr/local/bin/gum" ]; then GUM="/usr/local/bin/gum"; _log_to_file "INFO" "Found gum at $GUM";
        elif [ -x "$HOME/.local/bin/gum" ]; then GUM="$HOME/.local/bin/gum"; _log_to_file "INFO" "Found gum at $GUM";
        else
            _log_to_file "INFO" "Gum not found, attempting to download version ${GUM_VERSION}..."
            echo "[INFO] Gum not found. Attempting to download v${GUM_VERSION}..." # Plain echo for bootstrap
            local gum_url gum_download_path os_name arch_name
            os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
            arch_name=$(uname -m)
            case "$arch_name" in
                x86_64) arch_name="amd64" ;; aarch64) arch_name="arm64" ;;
                armv7l) arch_name="armv7" ;; armhf) arch_name="armv7" ;; # Common for RPi
                i386|i686) arch_name="386" ;;
            esac
            _log_to_file "INFO" "Detected OS: ${os_name}, Architecture for Gum: ${arch_name}"
            gum_url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_${os_name}_${arch_name}.tar.gz"
            _log_to_file "INFO" "Downloading from: ${gum_url}"
            gum_download_path="${SCRIPT_TMP_DIR}/gum.tar.gz"
            
            local download_cmd_str="curl -Lsf \"$gum_url\" -o \"$gum_download_path\""
            echo "Downloading gum from ${gum_url}..."
            if ! eval "$download_cmd_str"; then
                _log_to_file "ERROR" "Failed to download gum from ${gum_url}"
                echo "[ERROR] Failed to download gum. Please install it manually from https://github.com/charmbracelet/gum" >&2
                return 1 # Critical failure for gum_init
            fi

            _log_to_file "INFO" "Extracting gum archive to ${SCRIPT_TMP_DIR}"
            echo "Extracting gum..."
            if ! tar -xzf "$gum_download_path" --directory "$SCRIPT_TMP_DIR"; then
                _log_to_file "ERROR" "Failed to extract ${gum_download_path}"
                echo "[ERROR] Error extracting ${gum_download_path}" >&2; return 1
            fi
            
            local extracted_gum_binary
            extracted_gum_binary=$(find "$SCRIPT_TMP_DIR" -name "gum" -type f -executable -print -quit)
            if [ -z "$extracted_gum_binary" ]; then
                 _log_to_file "ERROR" "Gum binary not found in extracted archive at ${SCRIPT_TMP_DIR}"
                 echo "[ERROR] 'gum' binary not found in the extracted archive." >&2; return 1
            fi
            _log_to_file "INFO" "Found extracted gum binary at $extracted_gum_binary"

            mkdir -p "$HOME/.local/bin" || { _log_to_file "ERROR" "Failed to create $HOME/.local/bin"; echo "[ERROR] Error creating $HOME/.local/bin" >&2; return 1; }
            mv "$extracted_gum_binary" "$HOME/.local/bin/gum" || { _log_to_file "ERROR" "Failed to move gum to $HOME/.local/bin/gum"; echo "[ERROR] Error moving gum" >&2; return 1; }
            chmod +x "$HOME/.local/bin/gum" || { _log_to_file "ERROR" "Failed to chmod +x $HOME/.local/bin/gum"; echo "[ERROR] Error setting executable" >&2; return 1; }
            GUM="$HOME/.local/bin/gum"
            _log_to_file "INFO" "Gum v${GUM_VERSION} installed to $GUM"
            echo "Gum v${GUM_VERSION} installed to $GUM"
        fi
    else
        _log_to_file "INFO" "Gum binary already available at: $GUM"
    fi

    if ! _gum_cmd_exists; then
        echo "[CRITICAL ERROR] Gum is not available or not executable after initialization attempt at '$GUM'. This script requires 'gum' to function. Aborting." >&2
        _log_to_file "CRITICAL" "Gum not available at '$GUM' after init."
        exit 1 # Hard exit if GUM is essential and not found/installed
    fi
    _log_to_file "INFO" "Gum initialization completed. Using: $($GUM --version)"

    # Redefine log functions to use the custom GUM styled outputs
    log_info() { _log_to_file "INFO" "$@"; custom_gum_info "$@"; }
    log_warn() { _log_to_file "WARN" "$@"; custom_gum_warn "$@"; }
    log_error() { _log_to_file "ERROR" "$@"; custom_gum_fail "$@"; }
    # Redefine convenience wrappers
    log() { log_info "$@"; }
    warn() { log_warn "$@"; }
    error_exit() { log_error "$@"; exit 1; } 

    return 0
}

# Gum interaction wrappers
gum_confirm() { gum confirm --prompt.foreground "$COLOR_PURPLE" "$@"; }
gum_input() { gum input --placeholder "..." --prompt "> " --prompt.foreground "$COLOR_PURPLE" --header.foreground "$COLOR_PURPLE" "$@"; }
gum_write() { gum write --prompt "> " --header.foreground "$COLOR_PURPLE" --show-cursor-line --char-limit 0 "$@"; }
gum_choose() { gum choose --cursor "> " --header.foreground "$COLOR_PURPLE" --cursor.foreground "$COLOR_PURPLE" "$@"; }
gum_filter() { gum filter --prompt "> " --indicator ">" --placeholder "Type to filter..." --height 8 --header.foreground "$COLOR_PURPLE" "$@"; }
gum_spin() { gum spin --spinner dot --title.foreground "$COLOR_PURPLE" --spinner.foreground "$COLOR_PURPLE" --show-output "$@"; }

# --- Set Traps (after all GUM and logging functions are potentially redefined) ---
gum_setup_temp_dir # Call this before setting traps
trap 'trap_exit' EXIT
trap 'trap_error "${FUNCNAME[0]}" "${LINENO}"' ERR


# --- Main Script Configuration ---
DEFAULT_MIN_PYTHON_VERSION_FULL="3.11.7"
DEFAULT_MIN_PYTHON_VERSION_MAJOR_MINOR=$(echo "$DEFAULT_MIN_PYTHON_VERSION_FULL" | cut -d. -f1,2)
VENV_NAME_DEFAULT=".venv"
VENV_NAME="$VENV_NAME_DEFAULT"
SPACY_MODEL_PKG_DEFAULT="en_core_web_trf"
SPACY_MODEL_PKG="$SPACY_MODEL_PKG_DEFAULT"
BASE_INSTALL_DIR="$HOME/local_python_setup"

PROJECT_DIR_ARG="" # Will hold the path from --project-dir argument
PROJECT_DIR_EFFECTIVE="" # Will hold the final, validated project directory path

PYTHON_VERSION_BEING_HANDLED_FULL=""
PYTHON_VERSION_BEING_HANDLED_MAJOR_MINOR=""
PYTHON_RUNTIME_PREFIX_EFFECTIVE=""
PYTHON_SRC_DIR_EFFECTIVE=""
PYTHON_EXEC=""
UV_EXEC=""
DO_INSTALL_PYTHON=0
REQUESTED_PYTHON_VERSION_TO_INSTALL=""

# --- Main Script Functions ---

parse_args() {
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --install-python)
            if [[ -z "${2:-}" ]]; then error_exit "--install-python requires a version number argument (e.g., 3.11.7)."; fi
            DO_INSTALL_PYTHON=1
            REQUESTED_PYTHON_VERSION_TO_INSTALL="$2"
            if [[ ! "$REQUESTED_PYTHON_VERSION_TO_INSTALL" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                error_exit "Invalid Python version format for --install-python. Expected X.Y.Z. Got: $REQUESTED_PYTHON_VERSION_TO_INSTALL"
            fi
            log "Python installation requested for version: $REQUESTED_PYTHON_VERSION_TO_INSTALL"
            shift 2 ;;
            --spacy-model)
            if [[ -z "${2:-}" ]]; then error_exit "--spacy-model requires a model name argument."; fi
            SPACY_MODEL_PKG="$2"
            log "spaCy model set to: $SPACY_MODEL_PKG"
            shift 2 ;;
            --project-dir)
            if [[ -z "${2:-}" ]]; then error_exit "--project-dir requires a path argument."; fi
            PROJECT_DIR_ARG="$2"
            log "Project directory specified: $PROJECT_DIR_ARG"
            shift 2;;
            *) warn "Unknown option: $1"; shift ;;
        esac
    done
}

check_build_tools() {
    log "Checking for essential Python build tools..."
    local missing_tool_detected=0
    command -v gcc >/dev/null 2>&1 || { warn "gcc not found. It is required to compile Python."; missing_tool_detected=1; }
    command -v make >/dev/null 2>&1 || { warn "make not found. It is required to compile Python."; missing_tool_detected=1; }
    command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1 || { warn "Neither wget nor curl found. One is needed to download files."; missing_tool_detected=1; }

    if [ "$missing_tool_detected" -eq 1 ]; then
        warn "One or more essential build tools are missing."
        warn "Please install them using your system's package manager."
        if ! gum_confirm "Attempt to proceed with Python compilation anyway (might fail)?"; then
            error_exit "User aborted due to missing build tools."
        fi
    else
        log "Basic build tools seem to be present."
    fi
}

check_python_version() {
    local exec_path="$1"
    local min_major_minor="$2"
    if ! command -v "$exec_path" >/dev/null 2>&1 || [ ! -x "$exec_path" ]; then return 1; fi
    local version_string
    version_string=$("$exec_path" --version 2>&1)
    if [[ ! "$version_string" =~ Python[[:space:]]+([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        log_debug "Could not parse version from '$exec_path': $version_string"; return 1;
    fi
    local major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}" actual_version_full="$major.$minor.${BASH_REMATCH[3]}"
    local req_major=$(echo "$min_major_minor" | cut -d. -f1) req_minor=$(echo "$min_major_minor" | cut -d. -f2)
    log_debug "Checking Python at '$exec_path': Version '$actual_version_full'. Required >= $min_major_minor."
    if [ "$major" -gt "$req_major" ] || ( [ "$major" -eq "$req_major" ] && [ "$minor" -ge "$req_minor" ] ); then
        log_debug "Version '$actual_version_full' meets requirement '$min_major_minor'."
        return 0
    else
        log_debug "Version '$actual_version_full' is lower than required '$min_major_minor'."
        return 1
    fi
}

install_python() {
    local python_executable_target_path="$PYTHON_RUNTIME_PREFIX_EFFECTIVE/bin/python$PYTHON_VERSION_BEING_HANDLED_MAJOR_MINOR"
    if [ -x "$python_executable_target_path" ]; then
        local current_version=$("$python_executable_target_path" --version 2>&1)
        if [[ "$current_version" == "Python $PYTHON_VERSION_BEING_HANDLED_FULL" ]]; then
            log "Python $PYTHON_VERSION_BEING_HANDLED_FULL already installed at $python_executable_target_path."
            PYTHON_EXEC="$python_executable_target_path"
            if [[ ":$PATH:" != *":$(dirname "$PYTHON_EXEC"):"* ]]; then export PATH="$(dirname "$PYTHON_EXEC"):$PATH"; fi
            return
        fi
        warn "Python at $python_executable_target_path is '$current_version', expected '$PYTHON_VERSION_BEING_HANDLED_FULL'. Re-installing."
    fi

    log "Installing Python $PYTHON_VERSION_BEING_HANDLED_FULL to $PYTHON_RUNTIME_PREFIX_EFFECTIVE..."
    cd "$PYTHON_SRC_DIR_EFFECTIVE"
    local python_tarball="Python-$PYTHON_VERSION_BEING_HANDLED_FULL.tgz"
    local python_source_url="https://www.python.org/ftp/python/$PYTHON_VERSION_BEING_HANDLED_FULL/$python_tarball"
    if [ ! -f "$python_tarball" ]; then
        log "Downloading Python $PYTHON_VERSION_BEING_HANDLED_FULL..."
        gum_spin --title "Downloading Python $PYTHON_VERSION_BEING_HANDLED_FULL..." -- \
            bash -c "curl -fSL \"$python_source_url\" -o \"$python_tarball\" || wget --quiet \"$python_source_url\" -O \"$python_tarball\"" \
            || error_exit "Failed to download Python $PYTHON_VERSION_BEING_HANDLED_FULL."
    fi
    local extracted_dir_name="Python-$PYTHON_VERSION_BEING_HANDLED_FULL"
    if [ -d "$extracted_dir_name" ]; then rm -rf "$extracted_dir_name"; fi
    log "Extracting Python source..."
    gum_spin --title "Extracting Python $PYTHON_VERSION_BEING_HANDLED_FULL..." -- tar -xzf "$python_tarball" || error_exit "Failed to extract Python source."
    cd "$extracted_dir_name" || error_exit "Failed to enter Python source directory."

    log "Configuring Python build (prefix: $PYTHON_RUNTIME_PREFIX_EFFECTIVE)..."
    gum_spin --title "Configuring Python $PYTHON_VERSION_BEING_HANDLED_FULL..." -- \
        ./configure --prefix="$PYTHON_RUNTIME_PREFIX_EFFECTIVE" --enable-optimizations --with-ensurepip=install \
        || error_exit "Python configure failed for $PYTHON_VERSION_BEING_HANDLED_FULL."

    log "Building Python $PYTHON_VERSION_BEING_HANDLED_FULL (using $(nproc) cores)... This may take a while."
    gum_spin --title "Building Python $PYTHON_VERSION_BEING_HANDLED_FULL (make -j$(nproc))..." -- \
        make -j$(nproc) || error_exit "Python make failed for $PYTHON_VERSION_BEING_HANDLED_FULL."

    log "Installing Python $PYTHON_VERSION_BEING_HANDLED_FULL..."
    gum_spin --title "Installing Python $PYTHON_VERSION_BEING_HANDLED_FULL (make install)..." -- \
        make install || error_exit "Python make install failed for $PYTHON_VERSION_BEING_HANDLED_FULL."

    if [ ! -x "$python_executable_target_path" ]; then 
        local alt_py3_path="$PYTHON_RUNTIME_PREFIX_EFFECTIVE/bin/python3"
        if [ -x "$alt_py3_path" ] && [[ "$($alt_py3_path --version 2>&1)" == "Python $PYTHON_VERSION_BEING_HANDLED_FULL" ]]; then
            ln -sf "$alt_py3_path" "$python_executable_target_path"
        else
            error_exit "Python executable not found at $python_executable_target_path or as python3 after install."
        fi
    fi
    if [[ ! "$($python_executable_target_path --version 2>&1)" == "Python $PYTHON_VERSION_BEING_HANDLED_FULL" ]]; then
        error_exit "Python installed to $python_executable_target_path, but version mismatch."
    fi
    log "Python $PYTHON_VERSION_BEING_HANDLED_FULL installed successfully."
    PYTHON_EXEC="$python_executable_target_path"
    if [[ ":$PATH:" != *":$(dirname "$PYTHON_EXEC"):"* ]]; then export PATH="$(dirname "$PYTHON_EXEC"):$PATH"; fi
}

manage_python() {
    if [ "$DO_INSTALL_PYTHON" -eq 1 ]; then
        PYTHON_VERSION_BEING_HANDLED_FULL="$REQUESTED_PYTHON_VERSION_TO_INSTALL"
        PYTHON_VERSION_BEING_HANDLED_MAJOR_MINOR=$(echo "$PYTHON_VERSION_BEING_HANDLED_FULL" | cut -d. -f1,2)
        PYTHON_RUNTIME_PREFIX_EFFECTIVE="$BASE_INSTALL_DIR/python_runtime/$PYTHON_VERSION_BEING_HANDLED_FULL"
        PYTHON_SRC_DIR_EFFECTIVE="$BASE_INSTALL_DIR/python_src/$PYTHON_VERSION_BEING_HANDLED_FULL"
        log "Preparing to install Python $PYTHON_VERSION_BEING_HANDLED_FULL into $PYTHON_RUNTIME_PREFIX_EFFECTIVE."
        mkdir -p "$PYTHON_SRC_DIR_EFFECTIVE" "$PYTHON_RUNTIME_PREFIX_EFFECTIVE"
        check_build_tools
        install_python
    else
        log "Searching for existing Python >= $DEFAULT_MIN_PYTHON_VERSION_MAJOR_MINOR..."
        local potential_pythons=( "python$DEFAULT_MIN_PYTHON_VERSION_MAJOR_MINOR" "python3" "python" )
        local default_local_py="$BASE_INSTALL_DIR/python_runtime/$DEFAULT_MIN_PYTHON_VERSION_FULL/bin/python$DEFAULT_MIN_PYTHON_VERSION_MAJOR_MINOR"
        if [ -x "$default_local_py" ]; then potential_pythons+=("$default_local_py"); fi
        local found_existing_python=0
        for py_cmd in "${potential_pythons[@]}"; do
            if local full_path_py=$(command -v "$py_cmd" 2>/dev/null); then
                if check_python_version "$full_path_py" "$DEFAULT_MIN_PYTHON_VERSION_MAJOR_MINOR"; then
                    PYTHON_EXEC="$full_path_py"
                    log "Found suitable existing Python: $PYTHON_EXEC ($($PYTHON_EXEC --version 2>&1 | cut -d' ' -f2))"
                    if [[ "$PYTHON_EXEC" == "$BASE_INSTALL_DIR/python_runtime/"* ]]; then
                         if [[ ":$PATH:" != *":$(dirname "$PYTHON_EXEC"):"* ]]; then export PATH="$(dirname "$PYTHON_EXEC"):$PATH"; fi
                    fi
                    found_existing_python=1; break
                fi
            fi
        done
        if [ "$found_existing_python" -eq 0 ]; then
            error_exit "No suitable Python (>= $DEFAULT_MIN_PYTHON_VERSION_MAJOR_MINOR) found. Use --install-python X.Y.Z or install manually."
        fi
    fi
}

install_uv() {
    log "Checking for uv..."
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
        UV_EXEC=$(command -v uv)
        log "uv is already installed: $UV_EXEC ($($UV_EXEC --version))"
        return
    fi
    log "Installing uv..."
    # uv installer itself might have its own progress, or be quick.
    bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh" \
        || error_exit "Failed to install uv."
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH" 
    if ! UV_EXEC=$(command -v uv 2>/dev/null); then
        if [ -x "$HOME/.local/bin/uv" ]; then UV_EXEC="$HOME/.local/bin/uv";
        elif [ -x "$HOME/.cargo/bin/uv" ]; then UV_EXEC="$HOME/.cargo/bin/uv";
        else error_exit "uv installation script ran, but 'uv' command not found."; fi
    fi
    log "uv installed successfully: $UV_EXEC ($($UV_EXEC --version))"
}

setup_spacy_venv() {
    local current_venv_name="${VENV_NAME:-$VENV_NAME_DEFAULT}"
    local current_spacy_model_pkg="${SPACY_MODEL_PKG:-$SPACY_MODEL_PKG_DEFAULT}"
    
    # PROJECT_DIR_EFFECTIVE should be set by main() before this function is called.
    if [ -z "$PROJECT_DIR_EFFECTIVE" ]; then
        error_exit "Project directory not set. This is an internal script error."
    fi
    log "Setting up virtual environment '$current_venv_name' in '$PROJECT_DIR_EFFECTIVE' for spaCy..."
    
    if [ -z "$PYTHON_EXEC" ] || [ ! -x "$PYTHON_EXEC" ]; then error_exit "Python executable not properly set or found."; fi
    if [ -z "$UV_EXEC" ] || [ ! -x "$UV_EXEC" ]; then error_exit "uv executable not properly set or found."; fi

    # Ensure the target project directory exists
    mkdir -p "$PROJECT_DIR_EFFECTIVE" || error_exit "Failed to create project directory: $PROJECT_DIR_EFFECTIVE"
    
    local venv_path="$PROJECT_DIR_EFFECTIVE/$current_venv_name"

    if [ -d "$venv_path" ]; then
        warn "Virtual environment '$venv_path' already exists."
        if ! gum_confirm "Use existing venv '$venv_path'? (Choosing 'no' will attempt to reinstall packages)"; then
            log "Re-creating venv '$venv_path' as requested by user."
             "$UV_EXEC" venv "$venv_path" --python "$PYTHON_EXEC" --clear || error_exit "Failed to re-create virtual environment."
        else
            log "Using existing venv '$venv_path'."
        fi
    else
        log "Creating virtual environment '$venv_path'..."
        # uv venv is usually quick and has its own output
        # Execute uv command from within the target project directory context for .venv creation
        (cd "$PROJECT_DIR_EFFECTIVE" && "$UV_EXEC" venv "$current_venv_name" --python "$PYTHON_EXEC") \
            || error_exit "Failed to create virtual environment in $PROJECT_DIR_EFFECTIVE."
    fi
    log "Virtual environment '$current_venv_name' is ready in '$PROJECT_DIR_EFFECTIVE'."

    log "Installing spaCy and torch (CPU) into '$venv_path'..."
    # uv pip install has its own progress bar. Run it with PROJECT_DIR_EFFECTIVE as CWD.
    (cd "$PROJECT_DIR_EFFECTIVE" && "$UV_EXEC" pip install pip spacy torch --find-links https://download.pytorch.org/whl/cpu/torch_stable.html) \
        || error_exit "Failed to install spaCy and torch using uv in $PROJECT_DIR_EFFECTIVE."
    log "spaCy and torch installed."

    log "Downloading spaCy model '$current_spacy_model_pkg'..."
    local venv_python_exec="$venv_path/bin/python"
    if [ ! -x "$venv_python_exec" ]; then error_exit "Python not found in venv: $venv_python_exec"; fi
    
    # Run spacy download with PROJECT_DIR_EFFECTIVE as CWD so it finds the venv if needed,
    # although using the direct venv_python_exec should be sufficient.
    (cd "$PROJECT_DIR_EFFECTIVE" && gum_spin --title "Downloading spaCy model '$current_spacy_model_pkg'..." -- \
        "$venv_python_exec" -m spacy download "$current_spacy_model_pkg") \
        || error_exit "Failed to download spaCy model '$current_spacy_model_pkg'."
    log "spaCy model '$current_spacy_model_pkg' downloaded."
}

# --- Main Execution ---
main() {
    gum_init || { 
        echo "[CRITICAL] Gum initialization failed. Cannot proceed with enhanced UI. Exiting." >&2
        exit 1
    }

    log "Starting Python, uv, and spaCy setup with Gum UI..." 
    gum_title "Python, uv, and spaCy Environment Setup"

    parse_args "$@"

    # Validate --project-dir
    if [ -z "$PROJECT_DIR_ARG" ]; then
        error_exit "The --project-dir argument is required. Please specify a directory for the virtual environment."
    fi
    # Attempt to resolve to an absolute path and create if it doesn't exist.
    # Or simply use it as is if it's relative and user intends that.
    # For robustness, let's try to make it absolute.
    if [[ "$PROJECT_DIR_ARG" != /* ]]; then # if not an absolute path
        PROJECT_DIR_EFFECTIVE="$(pwd)/$PROJECT_DIR_ARG"
    else
        PROJECT_DIR_EFFECTIVE="$PROJECT_DIR_ARG"
    fi
    # Normalize path (remove ../, // etc.)
    PROJECT_DIR_EFFECTIVE=$(realpath -m "$PROJECT_DIR_EFFECTIVE") || {
        error_exit "Failed to resolve project directory path: $PROJECT_DIR_ARG. Ensure 'realpath' is available or path is valid."
    }


    if [ "$DO_INSTALL_PYTHON" -eq 1 ]; then
        log "Python installation requested for version: $REQUESTED_PYTHON_VERSION_TO_INSTALL."
    else
        log "Will search for existing Python >= $DEFAULT_MIN_PYTHON_VERSION_MAJOR_MINOR."
    fi
    log "Virtual environment will be: '${VENV_NAME:-$VENV_NAME_DEFAULT}' in '$PROJECT_DIR_EFFECTIVE'"
    log "spaCy model to be installed: '${SPACY_MODEL_PKG:-$SPACY_MODEL_PKG_DEFAULT}'"
    
    mkdir -p "$BASE_INSTALL_DIR" # For local Python builds

    manage_python
    install_uv
    setup_spacy_venv # This will use PROJECT_DIR_EFFECTIVE

    _log_to_file "INFO" "All main setup tasks completed. Handing over to EXIT trap for final status."
}

# --- Script Entry Point ---
main "$@"
