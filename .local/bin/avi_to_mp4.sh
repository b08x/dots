#!/bin/bash

# --- Simple AVI to MP4 Converter ---
# Usage:
# 1. Make this script executable: chmod +x convert.sh
# 2. Run it with your file:    ./convert.sh /path/to/yourfile.avi
# -----------------------------------

# Check if an input file was provided
if [ -z "$1" ]; then
  echo "Error: No input file specified."
  echo "Usage: $0 /path/to/yourfile.avi"
  exit 1
fi

INPUT_FILE="$1"
# Create the output filename by replacing the old extension with .mp4
OUTPUT_FILE="${INPUT_FILE%.*}.mp4"

echo "Converting '$INPUT_FILE'..."
echo "Output:     '$OUTPUT_FILE'"

# Run the ffmpeg command
ffmpeg -i "$INPUT_FILE" \
       -c:v h264_nvenc \
       -c:a aac \
       -b:a 289k \
       -ar 48000 \
       -ac 2 \
       "$OUTPUT_FILE"

echo "Conversion complete."