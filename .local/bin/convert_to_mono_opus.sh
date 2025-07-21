#!/bin/bash

# This script converts an audio or video file to a 16kHz mono Opus file.
# It requires ffmpeg and sox to be installed.

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if an input file is provided
if [ -z "$1" ]; then
  echo "Usage: $(basename "$0") <input_file>"
  exit 1
fi

INPUT_FILE="$1"
# Construct the output filename by replacing the original extension with .opus
OUTPUT_FILE="${INPUT_FILE%.*}.opus"

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file not found: $INPUT_FILE"
  exit 1
fi

echo "Converting '$INPUT_FILE' to 16kHz mono Opus..."

# Use ffmpeg to decode the input file to a WAV stream on stdout,
# then pipe it to sox to perform the resampling, channel selection,
# and encoding to the Opus format.
ffmpeg -i "$INPUT_FILE" -f wav - | sox -t wav - -r 16000 -c 1 -t opus "$OUTPUT_FILE"

echo "Conversion complete. Output saved to: '$OUTPUT_FILE'"
