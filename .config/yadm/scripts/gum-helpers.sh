#!/usr/bin/env bash

# Setup logging
SCRIPT_LOG_DIR="${PWD}/logs"
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

# Check for overcommit and install if available
if which overcommit >/dev/null 2>&1; then
	log "INFO" "Installing overcommit hooks"
	overcommit --install || log "WARN" "Failed to install overcommit hooks"
else
	log "WARN" "overcommit not found, skipping hook installation"
fi

# GUM
GUM_VERSION="0.17.0"
: "${GUM:=/usr/bin/gum}" # GUM=/usr/bin/gum ./your_script.sh

# COLORS
COLOR_WHITE=251
COLOR_GREEN=36
COLOR_PURPLE=212
COLOR_YELLOW=221
COLOR_RED=9

# FIELD NOTE COLOR PALETTE (from b08x.github.io theme-tokens.html)
FN_BG="#EDE6D6"
FN_BG2="#E3DBC8"
FN_BORDER="#D2C7B4"
FN_BORDER2="#C9B8A0"
FN_AMBER="#B5654A"
FN_AMBER_HI="#C97A5E"
FN_TEXT="#2A2420"
FN_TEXT2="#5C5248"
FN_MUTED="#8A7F72"
FN_DIM="#B0A492"
FN_RED="#A8453A"
FN_BADGE_BLUE="#5C7C99"
FN_BADGE_GREEN="#6B7F52"
FN_BADGE_RED="#A8453A"
FN_BADGE_TEXT="#F4EFE3"
FN_BADGE_NEUTRAL="#8A7F72"

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
# FIELD NOTE BANNER FUNCTIONS
# ////////////////////////////////////////////////////////////////////////////////////////////////////

fn_rule() {
	local width="${1:-50}"
	gum style --foreground "$FN_BORDER" "$(printf -- '─%.0s' $(seq 1 "$width"))"
}

# Show Field Note-themed splash screen
fn_splash() {
	local title="${1:-YADM Bootstrap}"
	local subtitle="${2:-Building your workstation...}"

	clear
	echo ""
	fn_rule 50
	gum style --foreground "$FN_AMBER" --bold --align center --width 50 "$title"
	gum style --foreground "$FN_MUTED" --align center --width 50 "$subtitle"
	fn_rule 50
	echo ""
}

# Show simple Field Note header (for sub-scripts)
fn_header() {
	local title="${1:-Setup}"

	fn_rule 50
	gum join \
		"$(gum style --foreground "$FN_MUTED" "BOOTSTRAP  ")" \
		"$(gum style --foreground "$FN_AMBER" --bold "$title")"
	fn_rule 50
	echo ""
}

# ////////////////////////////////////////////////////////////////////////////////////////////////////
# FIELD NOTE TASK BOARD (one row per bootstrap.d script)
# ////////////////////////////////////////////////////////////////////////////////////////////////////

FN_BOARD_WIDTH=44
FN_BOARD_PASS=0
FN_BOARD_FAIL=0

fn_board_init() {
	FN_BOARD_PASS=0
	FN_BOARD_FAIL=0
}

# fn_board_place <success|fail> <label>
fn_board_place() {
	local result="$1" label="$2"
	local badge label_text

	label_text="$(print_filled_space "$((FN_BOARD_WIDTH - 10))" "$label")"

	if [ "$result" = "success" ]; then
		badge="$(gum style --foreground "$FN_BADGE_TEXT" --background "$FN_BADGE_GREEN" --bold --padding "0 1" " OK ")"
		FN_BOARD_PASS=$((FN_BOARD_PASS + 1))
	else
		badge="$(gum style --foreground "$FN_BADGE_TEXT" --background "$FN_BADGE_RED" --bold --padding "0 1" " FAIL ")"
		FN_BOARD_FAIL=$((FN_BOARD_FAIL + 1))
	fi

	gum join "$(gum style --foreground "$FN_TEXT" "$label_text")" "  " "$badge"
}

fn_board_summary() {
	local total=$((FN_BOARD_PASS + FN_BOARD_FAIL))
	fn_rule "$FN_BOARD_WIDTH"
	if [ "$FN_BOARD_FAIL" -gt 0 ]; then
		gum style --foreground "$FN_MUTED" "${FN_BOARD_PASS}/${total} completed · ${FN_BOARD_FAIL} failed"
	else
		gum style --foreground "$FN_BADGE_GREEN" --bold "${FN_BOARD_PASS}/${total} completed"
	fi
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

# Field Note-themed gum prints
fn_info()    { gum join "$(gum style --foreground "$FN_BADGE_BLUE" --bold "• ")" "$(gum style --foreground "$FN_TEXT" "${*}")"; }
fn_success() { gum join "$(gum style --foreground "$FN_BADGE_GREEN" --bold "• ")" "$(gum style --foreground "$FN_TEXT" "${*}")"; }
fn_warn()    { gum join "$(gum style --foreground "$FN_AMBER" --bold "• ")" "$(gum style --foreground "$FN_TEXT" "${*}")"; }
fn_error()   { gum join "$(gum style --foreground "$FN_RED" --bold "• ")" "$(gum style --foreground "$FN_TEXT" "${*}")"; }
fn_step()    { gum join "$(gum style --foreground "$FN_AMBER" --bold "▸ ")" "$(gum style --foreground "$FN_TEXT" --bold "${*}")"; }

# Gum wrapper
gum_style() { gum style "${@}"; }
gum_confirm() { gum confirm --prompt.foreground "$COLOR_PURPLE" "${@}"; }
gum_input() { gum input --placeholder "..." --prompt "> " --prompt.foreground "$COLOR_PURPLE" --header.foreground "$COLOR_PURPLE" "${@}"; }
gum_write() { gum write --prompt "> " --header.foreground "$COLOR_PURPLE" --show-cursor-line --char-limit 0 "${@}"; }
gum_choose() { gum choose --cursor "> " --header.foreground "$COLOR_PURPLE" --cursor.foreground "$COLOR_PURPLE" "${@}"; }
gum_filter() { gum filter --prompt "> " --indicator ">" --placeholder "Type to filter..." --height 8 --header.foreground "$COLOR_PURPLE" "${@}"; }
gum_spin() { gum spin --spinner line --title.foreground "$COLOR_PURPLE" --spinner.foreground "$COLOR_PURPLE" "${@}"; }
gum_file() { gum file "${@}"; }

# Gum key & value
gum_proc() { gum join "$(gum_green --bold "• ")" "$(gum_white --bold "$(print_filled_space 24 "${1}")")" "$(gum_white "  >  ")" "$(gum_green "${2}")"; }
gum_property() { gum join "$(gum_green --bold "• ")" "$(gum_white "$(print_filled_space 24 "${1}")")" "$(gum_green --bold "  >  ")" "$(gum_white --bold "${2}")"; }

# HELPER FUNCTIONS
print_filled_space() {
	local total="$1" && local text="$2" && local length="${#text}"
	[ "$length" -ge "$total" ] && echo "$text" && return 0
	local padding=$((total - length)) && printf '%s%*s\n' "$text" "$padding" ""
}

# ////////////////////////////////////////////////////////////////////////////////////////////////////
# KITTY DASHBOARD (fullscreen status window, fed by an event log)
# ////////////////////////////////////////////////////////////////////////////////////////////////////

# Resolve the kitty remote-control socket: prefer the live env var (set
# automatically when already running inside a kitty pane), fall back to
# the static socket configured in ~/.config/kitty/kitty.conf.
fn_kitty_socket() {
	if [ -n "${KITTY_LISTEN_ON:-}" ]; then
		echo "$KITTY_LISTEN_ON"
	else
		echo "unix:/tmp/mykitty"
	fi
}

# Returns 0 if a kitty remote-control socket is reachable, 1 otherwise.
fn_kitty_available() {
	command -v kitty >/dev/null 2>&1 || return 1
	local socket
	socket="$(fn_kitty_socket)"
	kitty @ --to "$socket" ls >/dev/null 2>&1
}

# fn_open_dashboard <state_file>
# Spawns a fullscreen kitty OS window running fn_render_loop against
# state_file. Requires $SCRIPTS_DIR to point at this file's directory.
fn_open_dashboard() {
	local state_file="$1"
	local socket
	socket="$(fn_kitty_socket)"
	kitty @ --to "$socket" launch \
		--type=os-window \
		--os-window-state=fullscreen \
		--title "YADM Bootstrap" \
		bash -c "export GUM_HELPERS_NO_TRAP=1; source '$SCRIPTS_DIR/gum-helpers.sh' >/dev/null 2>&1; gum_init >/dev/null; fn_render_loop '$state_file'"
}

# fn_emit_event <state_file> <event> <label>
# event is one of: running, success, fail, done
fn_emit_event() {
	local state_file="$1" event="$2" label="$3"
	echo "${event}|${label}" >>"$state_file"
}

# fn_render_loop <state_file>
# Tails state_file, redrawing the Field Note board as events arrive.
# Blocks until it reads a "done|<code>" line, then waits for a keypress.
fn_render_loop() {
	local state_file="$1"
	fn_board_init
	fn_header "YADM Bootstrap"

	while IFS='|' read -r event payload; do
		case "$event" in
		running)
			fn_step "Running: $payload"
			;;
		success)
			fn_board_place success "$payload"
			;;
		fail)
			fn_board_place fail "$payload"
			;;
		done)
			fn_board_summary
			break
			;;
		esac
	done < <(tail -n +1 -f "$state_file")

	echo ""
	fn_info "Press any key to close this window..."
	read -n 1 -s -r
}

# Ensure traps are set after sourcing gum_helpers (skipped when this file is
# sourced by the kitty dashboard renderer — see fn_open_dashboard)
if [ -z "${GUM_HELPERS_NO_TRAP:-}" ]; then
	trap 'trap_exit' EXIT
	trap 'trap_error ${FUNCNAME} ${LINENO}' ERR
fi
