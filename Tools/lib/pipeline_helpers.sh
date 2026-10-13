#!/bin/bash

#===============================================================================
# pipeline_helpers.sh
# Reusable functions for shell script pipelines
# 
# Extracted from process_audio_pipeline.sh (gold standard template)
# Version: 1.0.0
# Last Updated: 2026-02-08
#===============================================================================

# USAGE:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/pipeline_helpers.sh"
#   
#   # Then use any function:
#   check_dependencies "python3" "ffmpeg" "python:numpy"
#   display_message "${COLOR_SUCCESS}" "✅ Done!"
#   run_step 1 "Transcode Video" "ffmpeg -i input.mp4 output.avi" "output.avi"

#===============================================================================
# Default Color Constants
#===============================================================================

# Override these in your script before sourcing if needed:
# COLOR_PRIMARY="#FF5E3A"
# source lib/pipeline_helpers.sh

COLOR_PRIMARY="${COLOR_PRIMARY:-#FF5E3A}"
COLOR_SECONDARY="${COLOR_SECONDARY:-#FF9F00}"
COLOR_SUCCESS="${COLOR_SUCCESS:-#00FF00}"
COLOR_ERROR="${COLOR_ERROR:-#FF0000}"
COLOR_WARNING="${COLOR_WARNING:-#FFD700}"
COLOR_INFO="${COLOR_INFO:-#00BFFF}"

#===============================================================================
# Default Error Messages
#===============================================================================

INVALID_OPT_ERR="${INVALID_OPT_ERR:-Invalid option:}"
REQ_ARG_ERR="${REQ_ARG_ERR:-requires an argument}"
WRONG_ARGS_ERR="${WRONG_ARGS_ERR:-wrong number of arguments passed to script}"
MISSING_DEP_ERR="${MISSING_DEP_ERR:-missing required dependency}"

#===============================================================================
# Display Functions - Graceful UI with gum fallback
#===============================================================================

# Display styled message with color
# Falls back to plain echo if gum not available
#
# Usage: display_message "${COLOR_SUCCESS}" "Operation completed"
#
display_message() {
    local color="$1"
    shift

    if command -v gum >/dev/null 2>&1; then
        gum style --foreground "$color" "$@"
    else
        echo "$@"
    fi
}

# Display styled banner/header
# Falls back to plain bordered text if gum not available
#
# Usage: display_banner "${COLOR_PRIMARY}" "My Pipeline" "" "Stage 1 of 3"
#
display_banner() {
    local color="$1"
    shift

    if command -v gum >/dev/null 2>&1; then
        gum style --border double --border-foreground "$color" \
            --align center --width 60 --margin "1 2" --bold "$@"
    else
        echo "========================================"
        for line in "$@"; do
            echo "$line"
        done
        echo "========================================"
    fi
}

# Display informational message
# Shorthand for display_message with INFO color
#
# Usage: info "Processing file..."
#
info() {
    display_message "${COLOR_INFO}" "$@"
}

# Display success message
# Shorthand for display_message with SUCCESS color
#
# Usage: success "✅ File processed successfully"
#
success() {
    display_message "${COLOR_SUCCESS}" "$@"
}

# Display warning message
# Shorthand for display_message with WARNING color
#
# Usage: warn "⚠️  File already exists, skipping"
#
warn() {
    display_message "${COLOR_WARNING}" "$@"
}

# Display error message
# Shorthand for display_message with ERROR color
#
# Usage: error "❌ Failed to process file"
#
error() {
    display_message "${COLOR_ERROR}" "$@"
}

#===============================================================================
# Dependency Validation
#===============================================================================

# Check for required dependencies and report all missing at once
# Supports: binaries, Python packages, Python modules, environment variables
#
# Usage: 
#   check_dependencies \
#       "ffmpeg" \
#       "python3" \
#       "python:numpy" \
#       "python:scipy" \
#       "env:API_KEY"
#
# Formats:
#   "binary_name"           - Check for binary in PATH
#   "python:package_name"   - Check for Python package via import
#   "env:VAR_NAME"          - Check for environment variable
#
check_dependencies() {
    local missing=()
    local python_bin="${PYTHON_BIN:-python3}"

    for dep in "$@"; do
        if [[ "$dep" == python:* ]]; then
            # Python package check
            local pkg="${dep#python:}"
            if ! ${python_bin} -c "import ${pkg}" 2>/dev/null; then
                missing+=("python:${pkg}")
            fi
        elif [[ "$dep" == env:* ]]; then
            # Environment variable check
            local var="${dep#env:}"
            if [ -z "${!var}" ]; then
                missing+=("env:${var}")
            fi
        else
            # Binary check
            if ! command -v "$dep" >/dev/null 2>&1; then
                missing+=("$dep")
            fi
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        display_banner "${COLOR_ERROR}" "❌ Missing Dependencies"
        echo ""
        echo "The following dependencies are missing:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        echo ""
        
        # Provide installation hints
        if [[ " ${missing[@]} " =~ " python:" ]]; then
            echo "Python packages:"
            echo "  pip install $(printf '%s ' "${missing[@]}" | sed 's/python://g' | grep -v '^[[:space:]]*$')"
            echo ""
        fi
        
        if [[ " ${missing[@]} " =~ " env:" ]]; then
            echo "Environment variables:"
            for dep in "${missing[@]}"; do
                if [[ "$dep" == env:* ]]; then
                    local var="${dep#env:}"
                    echo "  export ${var}='your_value_here'"
                fi
            done
            echo ""
        fi
        
        return 1
    fi
    
    success "✅ All dependencies validated"
    return 0
}

#===============================================================================
# File Validation
#===============================================================================

# Validate that a file exists, is readable, and optionally matches format
#
# Usage: 
#   validate_file "/path/to/file.mp4"
#   validate_file "/path/to/file.mp4" "ffprobe"  # Use ffprobe to validate format
#
validate_file() {
    local filepath="$1"
    local validator="${2:-}"  # Optional: ffprobe, file, etc.

    if [ ! -f "$filepath" ]; then
        error "❌ File not found: $filepath"
        return 1
    fi

    if [ ! -r "$filepath" ]; then
        error "❌ File not readable: $filepath"
        return 1
    fi

    # Optional format validation
    if [ "$validator" = "ffprobe" ]; then
        if ! command -v ffprobe >/dev/null 2>&1; then
            warn "⚠️  ffprobe not available, skipping format validation"
        elif ! ffprobe -v error -show_format "$filepath" >/dev/null 2>&1; then
            error "❌ Invalid or unsupported media format: $filepath"
            return 1
        fi
    fi

    return 0
}

#===============================================================================
# Pipeline Stage Execution
#===============================================================================

# Execute a pipeline stage with progress feedback and error handling
# Validates exit code AND expected output file creation
#
# Usage:
#   run_step 1 "Transcribe Audio" \
#       "python transcribe.py input.mp3" \
#       "output.srt"
#
# Arguments:
#   $1 - Stage number (for display)
#   $2 - Stage name (for display)
#   $3 - Command to execute
#   $4 - Expected output file (optional, for validation)
#
run_step() {
    local step_num="$1"
    local step_name="$2"
    local cmd="$3"
    local expected_output="${4:-}"

    echo ""

    # Display stage header
    if command -v gum >/dev/null 2>&1; then
        gum style \
            --border rounded --border-foreground "${COLOR_PRIMARY}" \
            --align center --width 60 --bold \
            "Stage ${step_num}: ${step_name}"
    else
        echo "========================================"
        echo "Stage ${step_num}: ${step_name}"
        echo "========================================"
    fi

    echo ""

    # Execute with spinner or plain output
    local exit_code
    if command -v gum >/dev/null 2>&1; then
        gum spin --spinner dot --title "Processing..." -- bash -c "$cmd"
        exit_code=$?
    else
        echo "Processing..."
        bash -c "$cmd"
        exit_code=$?
    fi

    # Check exit code
    if [ $exit_code -eq 0 ]; then
        # Verify expected output was created
        if [ -n "$expected_output" ] && [ ! -f "$expected_output" ]; then
            display_banner "${COLOR_ERROR}" \
                "❌ Pipeline Failed" \
                "" \
                "Stage: $step_name" \
                "Expected output not created: $expected_output"
            echo ""
            echo "Intermediate files preserved for debugging"
            return 1
        fi

        success "✅ $step_name completed successfully"
        if [ -n "$expected_output" ]; then
            info "   Output: $expected_output"
        fi

        return 0
    else
        display_banner "${COLOR_ERROR}" \
            "❌ Pipeline Failed" \
            "" \
            "Stage: $step_name" \
            "Exit code: $exit_code" \
            "" \
            "Command: $cmd"

        echo ""
        echo "Intermediate files preserved for debugging"
        return $exit_code
    fi
}

#===============================================================================
# Interactive File Selection
#===============================================================================

# Interactive file picker with gum
# Falls back to ls-based selection if gum unavailable
#
# Usage:
#   selected_file=$(select_file "." "*.mp4" "*.avi")
#   selected_file=$(select_file "/path/to/dir" "*.{mp3,wav,aac}")
#
select_file() {
    local search_dir="${1:-.}"
    shift
    local patterns=("$@")
    local files=()

    if [ ${#patterns[@]} -eq 0 ]; then
        patterns=("*")
    fi

    info "📁 Searching for files in: $search_dir"

    # Build find command
    local find_args=()
    for pattern in "${patterns[@]}"; do
        find_args+=(-o -iname "$pattern")
    done
    # Remove leading -o
    find_args=("${find_args[@]:1}")

    # Find files
    mapfile -t -d '' files < <(
        find "$search_dir" -maxdepth 2 \
            \( "${find_args[@]}" \) \
            -print0 2>/dev/null
    )

    if [ ${#files[@]} -eq 0 ]; then
        warn "⚠️  No files found in $search_dir"
        if command -v gum >/dev/null 2>&1; then
            if gum confirm "Enter file path manually?"; then
                gum input --placeholder "/path/to/file"
                return
            fi
        fi
        return 1
    fi

    # Use gum picker or simple selection
    if command -v gum >/dev/null 2>&1; then
        local max_items=30
        local display_list=()
        for i in "${!files[@]}"; do
            if [ $i -ge $max_items ]; then
                display_list+=("... ${#files[@]} total files (showing first $max_items)")
                break
            fi
            display_list+=("${files[$i]}")
        done
        gum choose --cursor.foreground="${COLOR_PRIMARY}" --height=15 "${display_list[@]}"
    else
        # Fallback: numbered list
        echo "Available files:"
        for i in "${!files[@]}"; do
            echo "  $((i+1)). ${files[$i]}"
        done
        read -p "Select file number: " selection
        echo "${files[$((selection-1))]}"
    fi
}

#===============================================================================
# Hardware/Feature Detection
#===============================================================================

# Detect available FFmpeg video encoder with fallback
# Returns: h264_nvenc (GPU) or libx264 (CPU)
#
# Usage: encoder=$(detect_video_encoder)
#
detect_video_encoder() {
    if command -v ffmpeg >/dev/null 2>&1; then
        if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_nvenc; then
            echo "h264_nvenc"
            return
        fi
    fi
    echo "libx264"
}

# Get appropriate preset for encoder type
#
# Usage: preset=$(get_encoder_preset "h264_nvenc")
#
get_encoder_preset() {
    local encoder="$1"
    case "$encoder" in
        h264_nvenc)
            echo "p4"
            ;;
        libx264)
            echo "medium"
            ;;
        *)
            echo "medium"
            ;;
    esac
}

#===============================================================================
# Path/String Escaping
#===============================================================================

# Shell-safe path escaping
# Uses printf '%q' for proper quoting
#
# Usage: escaped=$(shell_escape "/path/with spaces/file.mp4")
#
shell_escape() {
    printf '%q' "$1"
}

# FFmpeg filter-safe path escaping
# Different escaping rules than shell
#
# Usage: escaped=$(ffmpeg_filter_escape "/path/to/subtitle.ass")
#
ffmpeg_filter_escape() {
    local path="$1"
    # Escape single quotes for FFmpeg filter syntax
    echo "${path//\'/\'\\\'\'}"
}

#===============================================================================
# Utility Functions
#===============================================================================

# Confirm action with user (interactive mode only)
# Returns 0 if confirmed, 1 if denied or non-interactive
#
# Usage: 
#   if confirm "Delete all files?"; then
#       rm -rf *
#   fi
#
confirm() {
    local prompt="$1"
    
    if [ "${INTERACTIVE_MODE:-true}" != "true" ]; then
        return 0  # Auto-confirm in non-interactive mode
    fi
    
    if command -v gum >/dev/null 2>&1; then
        gum confirm "$prompt"
    else
        read -p "$prompt (y/N): " response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

# Get basename without extension
#
# Usage: base=$(get_basename "/path/to/file.mp4")
#        # Returns: file
#
get_basename() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    echo "${filename%.*}"
}

# Create timestamped output filename
#
# Usage: output=$(timestamped_output "backup.tar.gz")
#        # Returns: backup_2026-02-08_065309.tar.gz
#
timestamped_output() {
    local filepath="$1"
    local base="${filepath%.*}"
    local ext="${filepath##*.}"
    local timestamp=$(date +%Y-%m-%d_%H%M%S)
    
    if [ "$base" = "$ext" ]; then
        # No extension
        echo "${base}_${timestamp}"
    else
        echo "${base}_${timestamp}.${ext}"
    fi
}

#===============================================================================
# Initialization
#===============================================================================

# This function is called when the library is sourced
# Override by defining init_pipeline_helpers() before sourcing
#
_init_pipeline_helpers() {
    # Validate that we're being sourced, not executed
    if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
        echo "ERROR: This library should be sourced, not executed directly"
        echo "Usage: source pipeline_helpers.sh"
        exit 1
    fi
}

# Run initialization
_init_pipeline_helpers

# Export functions for subshells if needed
export -f display_message display_banner info success warn error
export -f check_dependencies validate_file run_step
export -f select_file detect_video_encoder get_encoder_preset
export -f shell_escape ffmpeg_filter_escape confirm
export -f get_basename timestamped_output
