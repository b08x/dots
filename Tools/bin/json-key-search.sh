#!/usr/bin/env bash
# ==============================================================================
# json-key-search.sh
# Parse a JSON file, return its available keys as selectable components,
# and interactively search on those keys using jq, gum, rga, and fzf.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Locate dependencies & tools
# ------------------------------------------------------------------------------
# Locate Charmbracelet Gum safely (avoiding ruby gem shims if any)
if [ -x "/usr/bin/gum" ]; then
    GUM="/usr/bin/gum"
elif [ -x "$HOME/.local/bin/gum" ]; then
    GUM="$HOME/.local/bin/gum"
elif [ -x "/usr/local/bin/gum" ]; then
    GUM="/usr/local/bin/gum"
elif command -v gum >/dev/null 2>&1; then
    GUM="$(command -v gum)"
else
    echo "Error: 'gum' is required. Please install from https://github.com/charmbracelet/gum" >&2
    exit 1
fi

gum() {
    "$GUM" "$@"
}

# Verify other required tools
for tool in jq rga fzf; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Required dependency '$tool' is not installed or not in PATH." >&2
        exit 1
    fi
done

# Preview tool preference: bat > sed
HAS_BAT=false
if command -v bat >/dev/null 2>&1; then
    HAS_BAT=true
fi

# ------------------------------------------------------------------------------
# UI Styling & Helpers
# ------------------------------------------------------------------------------
COLOR_PURPLE=212
COLOR_CYAN=75
COLOR_GREEN=36
COLOR_YELLOW=221
COLOR_RED=196

gum_title() { gum style --foreground "$COLOR_PURPLE" --bold "◈ $*"; }
gum_subtitle() { gum style --foreground "$COLOR_CYAN" "$*"; }
gum_info() { gum style --foreground "$COLOR_GREEN" "• $*"; }
gum_warn() { gum style --foreground "$COLOR_YELLOW" "• $*"; }
gum_fail() { gum style --foreground "$COLOR_RED" --bold "✗ $*"; }

# ------------------------------------------------------------------------------
# Temporary Directory & Cleanup Trap
# ------------------------------------------------------------------------------
TMP_DIR="$(mktemp -d "/tmp/.tmp.jsonsearch_XXXXXX")"

cleanup() {
    local exit_code="$?"
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# Helper to extract clean "key": value without line numbers or ANSI codes
extract_key_value() {
    local raw="$1"
    local line
    # Strip ANSI escape codes
    line=$(printf "%s" "$raw" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')
    # Strip leading line number followed by colon: e.g. "3:" or "19:"
    line=$(printf "%s" "$line" | sed -E 's/^[[:space:]]*[0-9]+:[[:space:]]*//')
    # Strip trailing commas
    line=$(printf "%s" "$line" | sed -E 's/,[[:space:]]*$//')
    # Strip remaining leading and trailing whitespace
    line=$(printf "%s" "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    echo "$line"
}

# Helper to extract only the value part (without "key":)
extract_value_only() {
    local kv="$1"
    kv=$(extract_key_value "$kv")
    # Strip leading "key": or key:
    printf "%s" "$kv" | sed -E 's/^[[:space:]]*"[^"]+":[[:space:]]*//'
}

# Clipboard copy utility
copy_to_clipboard() {
    local text="$1"
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
        printf "%s\n" "$text" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf "%s\n" "$text" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        printf "%s\n" "$text" | xsel --clipboard --input
    else
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Help message
# ------------------------------------------------------------------------------
show_help() {
    cat << EOF
JSON Key Search & Explorer
Parse a JSON file, select keys as components, and search with jq, gum, rga, and fzf.

Usage:
  $(basename "$0") [OPTIONS] [FILE.json]
  cat data.json | $(basename "$0") [OPTIONS]

Options:
  -k, --keys KEY[,KEY...]   Pre-select specific key(s) to search on (bypasses selection)
  -q, --query QUERY         Initial search query for fzf / rga
  -f, --filter QUERY        Non-interactive filter query (outputs matches directly)
  -l, --list-keys           List available keys and their counts, then exit
  -m, --mode MODE           Key selector mode: 'filter' (default) or 'choose'
  -r, --raw                 Output selected result directly to stdout and exit
  -h, --help                Show this help message

Interactive Keybindings in Search (fzf):
  Enter       Select match and open Action Menu (or output)
  Tab         Multi-select matches (toggle mark)
  Ctrl-O      Inspect enclosing JSON object in pager (jq + gum pager)
  Ctrl-Y      Copy matched line/value to clipboard
  Ctrl-R      Switch to live full-text rga search
  Ctrl-F      Switch back to key-filtered search
  Ctrl-S      Select different keys without quitting

Examples:
  $(basename "$0") package.json
  $(basename "$0") -k name,version package.json
  $(basename "$0") --list-keys data.json
  curl -s https://api.github.com/repos/charmbracelet/gum | $(basename "$0")

EOF
}

# ------------------------------------------------------------------------------
# Parse CLI Options
# ------------------------------------------------------------------------------
PRESET_KEYS=""
INITIAL_QUERY=""
FILTER_QUERY=""
LIST_KEYS_ONLY=false
KEY_SELECT_MODE="filter"
RAW_OUTPUT=false
INPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -k|--keys)
            PRESET_KEYS="$2"
            shift 2
            ;;
        -q|--query)
            INITIAL_QUERY="$2"
            shift 2
            ;;
        -f|--filter)
            FILTER_QUERY="$2"
            shift 2
            ;;
        -l|--list-keys)
            LIST_KEYS_ONLY=true
            shift
            ;;
        -m|--mode)
            KEY_SELECT_MODE="$2"
            shift 2
            ;;
        -r|--raw)
            RAW_OUTPUT=true
            shift
            ;;
        -*)
            gum_fail "Unknown option: $1"
            echo "Run '$(basename "$0") --help' for usage." >&2
            exit 1
            ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            else
                gum_fail "Unexpected extra argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Input Resolution (File, Stdin, or File Picker)
# ------------------------------------------------------------------------------
TARGET_FILE=""
ORIGINAL_NAME=""

if [ -n "$INPUT_FILE" ]; then
    if [ ! -f "$INPUT_FILE" ]; then
        gum_fail "File not found: $INPUT_FILE"
        exit 1
    fi
    ORIGINAL_NAME="$(basename "$INPUT_FILE")"
    TARGET_FILE="$INPUT_FILE"
elif [ ! -t 0 ]; then
    # Input piped via stdin
    STDIN_TMP="$TMP_DIR/stdin_input.json"
    cat - > "$STDIN_TMP"
    if [ ! -s "$STDIN_TMP" ]; then
        gum_fail "Received empty input via stdin."
        exit 1
    fi
    TARGET_FILE="$STDIN_TMP"
    ORIGINAL_NAME="stdin.json"
    # Reconnect terminal stdin for interactive gum and fzf
    if [ -t 1 ] && [ -e /dev/tty ]; then
        exec < /dev/tty
    fi
else
    # Interactive file selection
    gum_title "JSON Key Search"
    gum_info "Select a JSON file to inspect:"
    CHOSEN_FILE=$(gum file --height 12 --header "Select JSON file" . || true)
    if [ -z "$CHOSEN_FILE" ] || [ ! -f "$CHOSEN_FILE" ]; then
        gum_warn "No file selected. Exiting."
        exit 0
    fi
    TARGET_FILE="$CHOSEN_FILE"
    ORIGINAL_NAME="$(basename "$TARGET_FILE")"
fi

# ------------------------------------------------------------------------------
# Validate JSON & Normalize Streams / Minified Formats
# ------------------------------------------------------------------------------
if ! jq empty "$TARGET_FILE" 2>/dev/null; then
    if jq -s empty "$TARGET_FILE" 2>/dev/null; then
        IS_JSONL=true
    else
        gum_fail "File '$ORIGINAL_NAME' does not contain valid JSON or JSONL."
        exit 1
    fi
else
    # Check if input is a stream of multiple JSON documents (e.g., JSONL)
    DOC_COUNT=$(jq -n '[inputs] | length' "$TARGET_FILE" 2>/dev/null || echo 1)
    if [ "$DOC_COUNT" -gt 1 ]; then
        IS_JSONL=true
    else
        IS_JSONL=false
    fi
fi

# Format into a clean, normalized JSON file if minified or JSONL
LINE_COUNT=$(wc -l < "$TARGET_FILE")
WORKING_FILE="$TARGET_FILE"

if [ "$IS_JSONL" = true ]; then
    WORKING_FILE="$TMP_DIR/normalized.json"
    jq -s . "$TARGET_FILE" > "$WORKING_FILE"
elif [ "$LINE_COUNT" -le 2 ]; then
    WORKING_FILE="$TMP_DIR/normalized.json"
    jq . "$TARGET_FILE" > "$WORKING_FILE"
fi

# ------------------------------------------------------------------------------
# Inspect JSON Root Structure & Extract Available Keys
# ------------------------------------------------------------------------------
KEY_STATS_FILE="$TMP_DIR/keys.tsv"

# Run jq extraction to get all paths and their occurrence counts
jq -r '
  [
    paths as $p
    | ($p | map(select(type == "string")) | join("."))
    | select(length > 0)
  ]
  | reduce .[] as $k ({}; .[$k] += 1)
  | to_entries
  | sort_by(-.value)
  | .[]
  | "\(.key)\t\(.value)"
' "$WORKING_FILE" > "$KEY_STATS_FILE"

TOTAL_UNIQUE_KEYS=$(wc -l < "$KEY_STATS_FILE")

# Handle cases where JSON contains no object keys (e.g. array of numbers/strings)
if [ "$TOTAL_UNIQUE_KEYS" -eq 0 ]; then
    if [ "$LIST_KEYS_ONLY" = true ]; then
        echo "No object keys found in JSON (contains only primitives)."
        exit 0
    fi
    gum_warn "No object keys found in JSON (array or scalar primitives)."
fi

# If user just wants key listing
if [ "$LIST_KEYS_ONLY" = true ]; then
    printf "%-40s %s\n" "KEY" "OCCURRENCES"
    printf "%-40s %s\n" "----------------------------------------" "-----------"
    while IFS=$'\t' read -r key count; do
        printf "%-40s %s\n" "$key" "$count"
    done < "$KEY_STATS_FILE"
    exit 0
fi

# ------------------------------------------------------------------------------
# Prepare Helper Scripts for fzf Actions
# ------------------------------------------------------------------------------
PREVIEW_SCRIPT="$TMP_DIR/fzf_preview.sh"
cat << 'EOF' > "$PREVIEW_SCRIPT"
#!/usr/bin/env bash
line="$1"
target="$2"
orig="$3"
has_bat="$4"

if [[ "$line" =~ ^[0-9]+$ ]]; then
    start=$((line > 7 ? line - 7 : 1))
    end=$((line + 15))
    if [ "$has_bat" = "true" ]; then
        bat --style=numbers,changes --color=always --highlight-line "$line" -r "$start:$end" "$target" 2>/dev/null
    else
        sed -n "${start},${end}p" "$target"
    fi
    echo ""
    echo -e "\033[1;35m──────────────────────────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;34mLine:\033[0m $line  │  \033[1;34mFile:\033[0m $orig"
    echo -e "\033[2m[Enter: Action Menu] [Ctrl-O: View Object] [Ctrl-Y: Copy] [Ctrl-R: Regex]\033[0m"
else
    head -n 40 "$target"
fi
EOF
chmod +x "$PREVIEW_SCRIPT"

INSPECT_SCRIPT="$TMP_DIR/fzf_inspect.sh"
cat << 'EOF' > "$INSPECT_SCRIPT"
#!/usr/bin/env bash
line="$1"
target="$2"
gum_bin="$3"

if [[ "$line" =~ ^[0-9]+$ ]]; then
    is_array=$(jq 'if type == "array" then "true" else "false" end' "$target" 2>/dev/null || echo "false")
    if [ "$is_array" = "true" ]; then
        idx=$(awk -v target="$line" 'NR <= target && /^  \{/ { count++ } END { print count - 1 }' "$target")
        if [ -n "$idx" ] && [ "$idx" -ge 0 ]; then
            jq -C ".[$idx]" "$target" | "$gum_bin" pager --show-line-numbers
            exit 0
        fi
    fi
    jq -C . "$target" | "$gum_bin" pager --show-line-numbers
fi
EOF
chmod +x "$INSPECT_SCRIPT"

COPY_SCRIPT="$TMP_DIR/fzf_copy.sh"
cat << 'EOF' > "$COPY_SCRIPT"
#!/usr/bin/env bash
input_target="$1"

clean_line() {
    local l="$1"
    # Strip ANSI escape codes
    l=$(printf "%s" "$l" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')
    # Strip leading line number followed by colon
    l=$(printf "%s" "$l" | sed -E 's/^[[:space:]]*[0-9]+:[[:space:]]*//')
    # Strip trailing comma
    l=$(printf "%s" "$l" | sed -E 's/,[[:space:]]*$//')
    # Strip leading and trailing whitespace
    l=$(printf "%s" "$l" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    echo "$l"
}

copy_to_clip() {
    local text="$1"
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
        printf "%s\n" "$text" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf "%s\n" "$text" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        printf "%s\n" "$text" | xsel --clipboard --input
    else
        return 1
    fi
}

cleaned=""
if [ -f "$input_target" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        c=$(clean_line "$line")
        if [ -n "$c" ]; then
            if [ -z "$cleaned" ]; then
                cleaned="$c"
            else
                cleaned="${cleaned}
${c}"
            fi
        fi
    done < "$input_target"
else
    cleaned=$(clean_line "$*")
fi

if [ -n "$cleaned" ]; then
    copy_to_clip "$cleaned"
fi
EOF
chmod +x "$COPY_SCRIPT"

# ------------------------------------------------------------------------------
# Key Selection Function
# ------------------------------------------------------------------------------
select_keys() {
    if [ -n "$PRESET_KEYS" ]; then
        # Parse comma-separated keys
        IFS=',' read -r -a SELECTED_KEYS <<< "$PRESET_KEYS"
        return 0
    fi

    # Format choices for Gum
    local choices_file="$TMP_DIR/gum_choices.txt"
    {
        echo "* (All Keys / Entire File)"
        while IFS=$'\t' read -r key count; do
            printf "%-35s │ %s occurrences\n" "$key" "$count"
        done < "$KEY_STATS_FILE"
    } > "$choices_file"

    local raw_selected=""
    if [ "$KEY_SELECT_MODE" = "choose" ]; then
        raw_selected=$(gum choose --no-limit \
            --header="Select JSON Key(s) to search on (Space: toggle, Enter: confirm):" \
            --height=15 < "$choices_file" || true)
    else
        raw_selected=$(gum filter --no-limit \
            --header="Select JSON Key(s) to search on (Tab: multi-select, Enter: confirm):" \
            --placeholder="Type to filter keys..." \
            --height=15 < "$choices_file" || true)
    fi

    if [ -z "$raw_selected" ]; then
        gum_warn "No key selected. Defaulting to searching all keys."
        SELECTED_KEYS=("")
        return 0
    fi

    SELECTED_KEYS=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if [[ "$line" == *"All Keys"* ]] || [[ "$line" == "*"* ]]; then
            SELECTED_KEYS=("")
            return 0
        fi
        local k="${line%% │ *}"
        # shellcheck disable=SC2001
        k="$(echo "$k" | sed -e 's/[[:space:]]*$//')"
        [ -n "$k" ] && SELECTED_KEYS+=("$k")
    done <<< "$raw_selected"

    if [ ${#SELECTED_KEYS[@]} -eq 0 ]; then
        SELECTED_KEYS=("")
    fi
}

# ------------------------------------------------------------------------------
# Build Search Regex & Feed fzf
# ------------------------------------------------------------------------------
run_search() {
    local leaf_regex=""
    local keys_display=""

    if [ ${#SELECTED_KEYS[@]} -eq 0 ] || [ -z "${SELECTED_KEYS[0]:-}" ]; then
        # All keys
        leaf_regex='"[^"]+":\s*'
        keys_display="[All Keys]"
    else
        local escaped_leafs=()
        for k in "${SELECTED_KEYS[@]}"; do
            local leaf="${k##*.}"
            local esc
            # shellcheck disable=SC2016
            esc=$(printf "%s" "$leaf" | sed 's/[.[\*^$()+?{|]/\\&/g')
            escaped_leafs+=("\"$esc\"")
        done
        local leaf_pattern
        leaf_pattern=$(IFS='|'; echo "${escaped_leafs[*]}")
        leaf_regex="($leaf_pattern):\s*"
        keys_display="[${SELECTED_KEYS[*]}]"
    fi

    # If non-interactive filter query is provided
    if [ -n "$FILTER_QUERY" ]; then
        local raw_matches
        raw_matches=$(rga --color=never -n -i "$leaf_regex" "$WORKING_FILE" 2>/dev/null | fzf --filter="$FILTER_QUERY" || true)
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            extract_key_value "$line"
        done <<< "$raw_matches"
        exit 0
    fi

    # File info banner
    gum style --border rounded --margin "0 1" --padding "0 1" --border-foreground "$COLOR_PURPLE" \
        "File: $(gum style --bold --foreground "$COLOR_CYAN" "$ORIGINAL_NAME")  |  Keys: $(gum style --bold --foreground "$COLOR_GREEN" "$keys_display")"

    # Run fzf with rga
    local fzf_query_flag=()
    if [ -n "$INITIAL_QUERY" ]; then
        fzf_query_flag=(--query "$INITIAL_QUERY")
    fi

    local selected_lines
    selected_lines=$(
        rga --color=always -n -i "$leaf_regex" "$WORKING_FILE" 2>/dev/null | \
        fzf --ansi \
            --multi \
            --delimiter=":" \
            --header="Enter: Actions | Tab: Multi-Select | Ctrl-O: Object Pager | Ctrl-Y: Copy Key:Val | Ctrl-R: Live rga | Ctrl-S: Change Keys" \
            --preview="$PREVIEW_SCRIPT {1} '$WORKING_FILE' '$ORIGINAL_NAME' '$HAS_BAT'" \
            --preview-window="right:60%:wrap" \
            --bind="ctrl-o:execute($INSPECT_SCRIPT {1} '$WORKING_FILE' '$GUM')" \
            --bind="ctrl-y:execute-silent($COPY_SCRIPT {+f})+abort" \
            --bind="ctrl-r:reload(rga --color=always -n -i {q} '$WORKING_FILE' || true)" \
            --bind="ctrl-f:reload(rga --color=always -n -i '$leaf_regex' '$WORKING_FILE' || true)" \
            --bind="ctrl-s:abort" \
            "${fzf_query_flag[@]}" || true
    )

    if [ -z "$selected_lines" ]; then
        return 1
    fi

    SEARCH_RESULT="$selected_lines"
    return 0
}

# ------------------------------------------------------------------------------
# Action Menu on Selected Match
# ------------------------------------------------------------------------------
handle_action() {
    local raw_selection="$1"

    # If raw output requested, output clean "key": value and exit
    if [ "$RAW_OUTPUT" = true ]; then
        while IFS= read -r sel; do
            [ -z "$sel" ] && continue
            extract_key_value "$sel"
        done <<< "$raw_selection"
        exit 0
    fi

    # Multi-line handling
    local first_line
    first_line=$(echo "$raw_selection" | head -n 1)
    local line_num="${first_line%%:*}"
    local count
    count=$(echo "$raw_selection" | grep -c . || echo "1")

    echo ""
    gum style --border normal --padding "0 1" --border-foreground "$COLOR_GREEN" \
        "Selected $count item(s). Primary: Line $line_num"

    local action
    action=$(gum choose \
        "📋 View Full Record (jq + gum pager)" \
        "📎 Copy Key & Value to Clipboard" \
        "📎 Copy Value Only to Clipboard" \
        "🖨️  Print Key & Value to stdout" \
        "🖨️  Print Value Only to stdout" \
        "📦 Print Full JSON Record(s) to stdout" \
        "🔍 Search Again (Same Keys)" \
        "🔑 Select Different Keys" \
        "❌ Exit")

    case "$action" in
        *"View Full Record"*)
            "$INSPECT_SCRIPT" "$line_num"
            handle_action "$raw_selection"
            ;;
        *"Copy Key & Value"*)
            local all_vals=""
            while IFS= read -r sel; do
                [ -z "$sel" ] && continue
                local kv
                kv=$(extract_key_value "$sel")
                if [ -n "$kv" ]; then
                    if [ -z "$all_vals" ]; then
                        all_vals="$kv"
                    else
                        all_vals="${all_vals}
${kv}"
                    fi
                fi
            done <<< "$raw_selection"
            if copy_to_clipboard "$all_vals"; then
                gum_info "Copied key and value to clipboard!"
            else
                gum_warn "Clipboard utility not found (wl-copy, xclip, xsel)."
            fi
            handle_action "$raw_selection"
            ;;
        *"Copy Value Only"*)
            local all_vals=""
            while IFS= read -r sel; do
                [ -z "$sel" ] && continue
                local v
                v=$(extract_value_only "$sel")
                if [ -n "$v" ]; then
                    if [ -z "$all_vals" ]; then
                        all_vals="$v"
                    else
                        all_vals="${all_vals}
${v}"
                    fi
                fi
            done <<< "$raw_selection"
            if copy_to_clipboard "$all_vals"; then
                gum_info "Copied value to clipboard!"
            else
                gum_warn "Clipboard utility not found (wl-copy, xclip, xsel)."
            fi
            handle_action "$raw_selection"
            ;;
        *"Print Key & Value"*)
            while IFS= read -r sel; do
                [ -z "$sel" ] && continue
                extract_key_value "$sel"
            done <<< "$raw_selection"
            exit 0
            ;;
        *"Print Value Only"*)
            while IFS= read -r sel; do
                [ -z "$sel" ] && continue
                extract_value_only "$sel"
            done <<< "$raw_selection"
            exit 0
            ;;
        *"Print Full JSON Record"*)
            local is_array
            is_array=$(jq 'if type == "array" then "true" else "false" end' "$WORKING_FILE" 2>/dev/null || echo "false")
            if [ "$is_array" = "true" ]; then
                local idx
                idx=$(awk -v target="$line_num" 'NR <= target && /^  \{/ { count++ } END { print count - 1 }' "$WORKING_FILE")
                if [ -n "$idx" ] && [ "$idx" -ge 0 ]; then
                    jq ".[$idx]" "$WORKING_FILE"
                    exit 0
                fi
            fi
            jq . "$WORKING_FILE"
            exit 0
            ;;
        *"Search Again"*)
            return 2 # Signal repeat search
            ;;
        *"Select Different Keys"*)
            PRESET_KEYS=""
            return 3 # Signal re-select keys
            ;;
        *"Exit"|*)
            exit 0
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Main Application Loop
# ------------------------------------------------------------------------------
main() {
    while true; do
        select_keys

        while true; do
            SEARCH_RESULT=""
            if ! run_search; then
                # User hit Esc or Ctrl-S
                if gum confirm --default=true "Choose different keys to search?"; then
                    break
                else
                    exit 0
                fi
            fi

            handle_action "$SEARCH_RESULT"
            local action_status="$?"
            if [ "$action_status" -eq 2 ]; then
                # Search again with same keys
                continue
            elif [ "$action_status" -eq 3 ]; then
                # Choose different keys
                break
            else
                exit 0
            fi
        done
    done
}

main "$@"
