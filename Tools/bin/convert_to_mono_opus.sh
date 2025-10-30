#!/bin/bash

# Converts an audio file to a high-quality, mono Opus file,
# optimized for voice transcription.

# --- CONFIGURATION ---
DEFAULT_SAMPLE_RATE=16000
DEFAULT_BITRATE="64k"

# --- FUNCTIONS ---

# Logs a message to stderr.
log_error() {
  echo "ERROR: $1" >&2
}

# Displays usage information and exits.
usage() {
  if [[ -n "$1" ]]; then
    log_error "$1"
  fi
  echo "Usage: $(basename "$0") <input_file> [output_file]"
  echo "  Converts an audio file to a mono Opus file optimized for transcription."
  echo
  echo "Arguments:"
  echo "  input_file     Path to the source audio file."
  echo "  output_file    Optional: Path to save the converted Opus file."
  echo "                 If omitted, the output will be saved in the same"
  echo "                 directory as the input file with an '.opus' extension."
  exit 1
}

# Checks for required command-line dependencies.
check_dependencies() {
  if ! command -v ffmpeg &>/dev/null; then
    log_error "ffmpeg is not installed. Please install it to continue."
    exit 1
  fi
}

# Converts the audio file using ffmpeg.
convert_audio() {
  local input_file="$1"
  local output_file="$2"
  local sample_rate="$3"
  local bitrate="$4"
  local ffmpeg_opts=()

  echo "Processing '$input_file'..."

  # Check for NVIDIA GPU and add hwaccel option if available
  if command -v nvidia-smi &>/dev/null; then
    echo "NVIDIA GPU detected, enabling CUDA hardware acceleration for decoding."
    ffmpeg_opts+=(-hwaccel cuda)
  fi

  # -af "highpass=f=200, acompressor=threshold=-20dB:ratio=2:attack=5:release=50":
  #   - highpass=f=200: Removes low-frequency noise below 200Hz.
  #   - acompressor: Compresses the dynamic range to even out volume levels.
  # -c:a libopus: Specifies the Opus audio codec.
  # -b:a $bitrate: Sets the audio bitrate.
  # -vbr on: Enables variable bitrate for better quality and efficiency.
  if ! ffmpeg "${ffmpeg_opts[@]}" -i "$input_file" \
    -af "highpass=f=200, acompressor=threshold=-20dB:ratio=2:attack=5:release=50" \
    -ar "$sample_rate" \
    -ac 1 \
    -c:a libopus \
    -b:a "$bitrate" \
    -vbr on \
    -y "$output_file" &>/dev/null; then
    log_error "ffmpeg failed to convert '$input_file'."
    rm -f "$output_file"
    return 1
  fi
}

# --- MAIN EXECUTION ---

main() {
  check_dependencies

  local input_file="$1"
  local output_file="$2"

  # --- Argument Validation ---
  if [[ -z "$input_file" ]]; then
    usage "Missing input file."
  fi

  if [[ ! -f "$input_file" ]]; then
    log_error "Input file not found: '$input_file'"
    exit 1
  fi

  if [[ -z "$output_file" ]]; then
    output_file="${input_file%.*}.opus"
  fi

  # --- Processing ---
  if convert_audio "$input_file" "$output_file" "$DEFAULT_SAMPLE_RATE" "$DEFAULT_BITRATE"; then
    echo "Success: Audio converted and saved to '$output_file'"
  else
    exit 1
  fi
}

# Execute the main function with all script arguments
main "$@"