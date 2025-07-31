#!/bin/bash

# Converts an audio file to mono, resamples it, applies a high-pass filter,
# and compresses the dynamic range.

# --- CONFIGURATION ---
DEFAULT_SAMPLE_RATE=16000

# --- FUNCTIONS ---

# Logs a message to stderr.
#
# Args:
#   $1: The message to log.
log_error() {
  echo "ERROR: $1" >&2
}

# Displays usage information and exits.
#
# Args:
#   $1: An optional error message to display.
usage() {
  if [[ -n "$1" ]]; then
    log_error "$1"
  fi
  echo "Usage: $(basename "$0") <input_file> <output_file> [sample_rate]"
  echo "  Converts an audio file to a mono WAV file with specific processing."
  echo
  echo "Arguments:"
  echo "  input_file     Path to the source audio file."
  echo "  output_file    Path to save the converted WAV file."
  echo "  sample_rate    Target sample rate (default: ${DEFAULT_SAMPLE_RATE}Hz)."
  exit 1
}

# Checks for required command-line dependencies.
#
# Exits the script if a dependency is not found.
check_dependencies() {
  if ! command -v ffmpeg &>/dev/null; then
    log_error "ffmpeg is not installed. Please install it to continue."
    exit 1
  fi
}

# Converts the audio file using ffmpeg.
#
# Args:
#   $1: The input file path.
#   $2: The output file path.
#   $3: The target sample rate.
#
# Returns:
#   0 on success, 1 on failure.
convert_audio() {
  local input_file="$1"
  local output_file="$2"
  local sample_rate="$3"

  echo "Processing '$input_file'..."

  # ffmpeg command with error suppression for cleaner output
  if ! ffmpeg -i "$input_file" \
    -af "highpass=f=200, acompressor=threshold=-20dB:ratio=2:attack=5:release=50" \
    -ar "$sample_rate" \
    -ac 1 \
    -c:a pcm_s16le \
    -y "$output_file" &>/dev/null; then
    log_error "ffmpeg failed to convert '$input_file'."
    # Attempt to clean up the potentially incomplete output file
    rm -f "$output_file"
    return 1
  fi
}

# --- MAIN EXECUTION ---

main() {
  check_dependencies

  local input_file="$1"
  local output_file="$2"
  local sample_rate="${3:-$DEFAULT_SAMPLE_RATE}"

  # --- Argument Validation ---
  if [[ -z "$input_file" ]] || [[ -z "$output_file" ]]; then
    usage "Missing required arguments."
  fi

  if [[ ! -f "$input_file" ]]; then
    log_error "Input file not found: '$input_file'"
    exit 1
  fi

  # --- Processing ---
  if convert_audio "$input_file" "$output_file" "$sample_rate"; then
    echo "Success: Audio converted and saved to '$output_file'"
  else
    # The error is already logged by convert_audio
    exit 1
  fi
}

# Execute the main function with all script arguments
main "$@"
