#!/bin/bash

# --- Simple MP4 Audio Converter ---
#
# This script takes an MP4 file, re-encodes the video with NVIDIA (h264_nvenc),
# and re-encodes the audio to specific AAC settings.
#
# It also includes an option to normalize audio to -23 LUFS.
# It now safely handles files with no audio.
#
# Usage:
# 1. Make this script executable: chmod +x convert_mp4_audio.sh
# 2. Run it with your file:    ./convert_mp4_audio.sh /path/to/yourfile.mp4
# 3. Run with normalization:  ./convert_mp4_audio.sh --normalize /path/to/yourfile.mp4
# ---------------------------------------------------

# 1. Initialize variables
NORMALIZE=0
INPUT_FILE=""

# 2. Parse arguments (robust loop)
while [ "$#" -gt 0 ]; do
  case "$1" in
    --normalize)
      NORMALIZE=1
      shift # Consume --normalize
      ;;
    -*)
      echo "Error: Unknown option: $1"
      echo "Usage: $0 [--normalize] /path/to/yourfile.mp4"
      exit 1
      ;;
    *)
      # This must be the input file
      if [ -n "$INPUT_FILE" ]; then
         echo "Error: Only one input file can be specified."
         echo "Usage: $0 [--normalize] /path/to/yourfile.mp4"
         exit 1
      fi
      INPUT_FILE="$1"
      shift # Consume the file path
      ;;
  esac
done

# 3. Check if input file was found
if [ -z "$INPUT_FILE" ]; then
  echo "Error: No input file specified."
  echo "Usage: $0 [--normalize] /path/to/yourfile.mp4"
  exit 1
fi

# 4. Check for required tools
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: 'ffmpeg' command not found. Please install it."
    exit 1
fi
if ! command -v ffprobe &> /dev/null; then
    echo "Error: 'ffprobe' command not found. Please install it."
    exit 1
fi
if [ $NORMALIZE -eq 1 ] && ! command -v ffmpeg-normalize &> /dev/null; then
    echo "Error: 'ffmpeg-normalize' command not found."
    echo "Please install it to use the --normalize option (e.g., pip install ffmpeg-normalize)"
    exit 1
fi

# 5. Set up output file
OUTPUT_FILE="${INPUT_FILE%.*} - Converted.mp4"

echo "Input:   '$INPUT_FILE'"
echo "Output:  '$OUTPUT_FILE'"

# 6. Check for audio stream
echo "Checking for audio streams..."
HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=index -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE")

# 7. Run the correct command based on audio presence
if [ -z "$HAS_AUDIO" ]; then
  # --- NO AUDIO ---
  echo "No audio stream found. Converting video only."
  ffmpeg -i "$INPUT_FILE" \
         -c:v h264_nvenc \
         -an \
         -y "$OUTPUT_FILE"

else
  # --- AUDIO EXISTS ---
  echo "Audio stream found. Processing video and audio."
  if [ $NORMALIZE -eq 1 ]; then
    # Use ffmpeg-normalize
    echo "Starting conversion with EBU R128 normalization (-23 LUFS)..."

    ffmpeg-normalize "$INPUT_FILE" \
         -o "$OUTPUT_FILE" \
         -nt ebu \
         -t -23 \
         -c:v h264_nvenc \
         -c:a aac \
         -b:a 289k \
         -ar 48000 \
         -ac 2 \
         -f # Force overwrite (like -y in ffmpeg)

  else
    # Use original ffmpeg command
    echo "Starting conversion..."
    ffmpeg -i "$INPUT_FILE" \
           -c:v h264_nvenc \
           -c:a aac \
           -b:a 289k \
           -ar 48000 \
           -ac 2 \
           -y "$OUTPUT_FILE"
  fi
fi

# 8. Final message
if [ $? -eq 0 ]; then
  echo "Conversion complete."
else
  echo "Error during conversion."
fi

