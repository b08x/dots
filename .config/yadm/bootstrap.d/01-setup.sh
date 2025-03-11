#!/usr/bin/env bash

# GUM
GUM_VERSION="0.13.0"
: "${GUM:=$HOME/.local/bin/gum}"   # GUM=/usr/bin/gum ./your_script.sh

# COLORS
COLOR_WHITE=251
COLOR_GREEN=36
COLOR_PURPLE=212
COLOR_YELLOW=221
COLOR_RED=9

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
    echo "Command '${BASH_COMMAND}' failed with exit code $? in function '${1}' (line ${2})" >"$ERROR_MSG"
}

# shellcheck disable=SC2317
trap_exit() {
    local result_code="$?"

    # Read error msg from file (written in error trap)
    local error && [ -f "$ERROR_MSG" ] && error="$(<"$ERROR_MSG")" && rm -f "$ERROR_MSG"

    # Cleanup temporary directory only if it was created in this script
    if [ "$TRAP_CLEANUP_REQUIRED" = "true" ]; then
        rm -rf "$SCRIPT_TMP_DIR"
    fi

    # When ctrl + c pressed exit without other stuff below
    [ "$result_code" = "130" ] && gum_warn "Exit..." && {
        exit 1
    }

    # Check if failed and print error
    if [ "$result_code" -gt "0" ]; then
        [ -n "$error" ] && gum_fail "$error"            # Print error message (if exists)
        [ -z "$error" ] && gum_fail "An Error occurred" # Otherwise pint default error message
        [ -n "$SCRIPT_LOG" ] && {
            gum_warn "See ${SCRIPT_LOG} for more information..."
            gum_confirm "Show Logs?" && gum pager --show-line-numbers <"$SCRIPT_LOG" # Ask for show logs?
        }
    fi

    exit "$result_code" # Exit script
}

gum_init() {
    # First check if GUM is already executable at the specified path
    if [ ! -x "$GUM" ]; then
        # Check if gum is available in the system path
        local system_gum
        system_gum=$(command -v gum 2>/dev/null)
        
        # If found in system path, use that
        if [ -n "$system_gum" ] && [ -x "$system_gum" ]; then
            echo "Found gum binary at: $system_gum"
            GUM="$system_gum"
        # Check common locations
        elif [ -x "/usr/bin/gum" ]; then
            echo "Found gum binary at: /usr/bin/gum"
            GUM="/usr/bin/gum"
        elif [ -x "/usr/local/bin/gum" ]; then
            echo "Found gum binary at: /usr/local/bin/gum"
            GUM="/usr/local/bin/gum"
        elif [ -x "$HOME/.local/bin/gum" ]; then
            echo "Found gum binary at: $HOME/.local/bin/gum"
            GUM="$HOME/.local/bin/gum"
        else
            # If not found anywhere, download it
            echo "Downloading gum binary..." # Loading
            local gum_url gum_path # Prepare URL with version os and arch
            # https://github.com/charmbracelet/gum/releases
            gum_url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_$(uname -s)_$(uname -m).tar.gz"
            if ! curl -Lsf "$gum_url" >"${SCRIPT_TMP_DIR}/gum.tar.gz"; then echo "Error downloading ${gum_url}" && exit 1; fi
            if ! tar -xf "${SCRIPT_TMP_DIR}/gum.tar.gz" --directory "$SCRIPT_TMP_DIR"; then echo "Error extracting ${SCRIPT_TMP_DIR}/gum.tar.gz" && exit 1; fi
            gum_path=$(find "${SCRIPT_TMP_DIR}" -type f -executable -name "gum" -print -quit)
            [ -z "$gum_path" ] && echo "Error: 'gum' binary not found in '${SCRIPT_TMP_DIR}'" && exit 1
            
            # Ensure ~/.local/bin exists
            mkdir -p "$HOME/.local/bin"
            
            if ! mv "$gum_path" "$HOME/.local/bin/gum"; then echo "Error moving ${gum_path} to ~/.local/bin/gum" && exit 1; fi
            if ! chmod +x "$HOME/.local/bin/gum"; then echo "Error chmod +x ~/.local/bin/gum" && exit 1; fi
            GUM="$HOME/.local/bin/gum" # Update GUM variable to point to the local binary
            echo "gum binary downloaded and made executable."
        fi
    fi
}

gum() {
    if [ -n "$GUM" ] && [ -x "$GUM" ]; then
        "$GUM" "$@"
    else
        echo "Error: GUM='${GUM}' is not found or executable" >&2
        exit 1
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

# Now you can use the gum functions
gum_init # Initialize gum (download if not present)

gum_title "yadm bootstrap"
gum_info "This is an info message using gum."

if gum_confirm "Do you want to continue?"; then
    gum_green "User confirmed!"
else
    gum_warn "User did not confirm."
fi

DISTRO=$( hostnamectl| awk '{ print $1,$2,$3 }'|grep "Operating System"|awk '{print $3}' )

# make sure pip3 git and git-lfs are installed
hash pipx pipenv git ruby mdadm&>/dev/null &&
echo "Looks like we have everything we need here." ||

if [ "$?" != 0 ];
then
  echo "something isn't installed...run case distro"
    case $DISTRO in
      Debian)
        sudo apt -y install git pipx python3-venv lsb-release mdadm
        ;;
      Fedora)
        sudo dnf -y install python3-pip git lsb-release
        ;;
      Arch)
        sudo pacman -S git python-pipx pyenv \
        			   rubygems ruby-bundler lsb-release mdadm \
        			   --noconfirm --overwrite '*'
        ;;
    esac
fi

# install cargo
if [ -x "$(command -v cargo)" ];
then
  echo "cargo is found!"
else
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o - | sh
fi

# install ansible if it isn't already available
if [ -x "$(command -v ansible)" ];
then
  gum_info "by the way, ansible is installed."
else
  #pipx install ansible-core || exit
  gum_warn "ansible is not installed."
fi
