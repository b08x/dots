#!/bin/bash

# --- Advanced FFmpeg Converter ---
#
# This script applies a specific, high-quality conversion:
# - Changes frame rate to 30 FPS using motion interpolation.
# - Re-encodes audio to high-bitrate AC3.
# - Re-encodes video to very high-quality H.264 (CRF 15).
# - Preserves limited "TV" color range.
#
# Usage:
#   ./advanced_convert.sh /path/to/yourfile.mp4
#
# ---------------------------------------------------

# 1. Check if an input file was provided
if [ -z "$1" ]; then
  echo "Error: No input file specified."
  echo "Usage: $0 /path/to/yourfile.mp4"
  exit 1
fi

INPUT_FILE="$1"
# Create an output filename like "MyVideo - Converted.mp4"
OUTPUT_FILE="${INPUT_FILE%.*} - Converted.mp4"

echo "Input:   '$INPUT_FILE'"
echo "Output:  '$OUTPUT_FILE'"
echo "Starting advanced conversion..."

# 2. Check for NVIDIA hardware acceleration (NVENC)
# We default to CPU encoding (libx264)
VIDEO_CODEC="libx264"
VIDEO_PRESET="-preset medium"

# 'command -v' checks if a command exists. 'ffmpeg -encoders' lists all encoders.
# We grep for 'h264_nvenc'. If it's found, we use it.
if command -v ffmpeg &> /dev/null && ffmpeg -encoders 2>/dev/null | grep -q 'h264_nvenc'; then
  echo "NVIDIA (h264_nvenc) encoder found. Using hardware acceleration."
  VIDEO_CODEC="h264_nvenc"
  # NVENC uses different quality/preset flags
  VIDEO_PRESET="-preset p6 -rc vbr -cq 18" # p6=medium, cq=18 is ~CRF 15
else
  echo "No NVIDIA encoder found. Using high-quality CPU encoding (libx264)... this may be slow."
fi

# 3. Set the advanced filtergraph
# This is the complex -vf chain from your command
VIDEO_FILTER=(
  "scale=flags=accurate_rnd+full_chroma_inp+full_chroma_int:in_range=mpeg:out_range=mpeg,"
  "minterpolate='mi_mode=dup:mc_mode=aobmc:me_mode=bidir:vsbmc=1:fps=30.000000'"
)
# Join the filter parts into a single string
VIDEO_FILTER_STRING=$(IFS=; echo "${VIDEO_FILTER[*]}")

# --- KEYFRAME SETTING ---
# The original command used '-g 1' (all keyframes). This creates
# huge files and is usually for editing. It's commented out by default.
# Uncomment the line below if you need all keyframes.
# KEYFRAME_SETTING="-g 1"
KEYFRAME_SETTING="" # Default (unset)

# 4. Run the full FFmpeg Command
ffmpeg -loglevel verbose \
       -i "$INPUT_FILE" \
       -max_muxing_queue_size 9999 \
       -map 0:a? \
       -map 0:V? \
       -map_metadata 0 \
       -ignore_unknown \
       -vf "$VIDEO_FILTER_STRING" \
       -color_range 1 \
       -f mp4 \
       -codec:a ac3 \
       -b:a 512k \
       -codec:v "$VIDEO_CODEC" \
       $VIDEO_PRESET \
       -crf 15 \
       $KEYFRAME_SETTING \
       -y "$OUTPUT_FILE"

# 5. Check if the command succeeded
if [ $? -eq 0 ]; then
  echo "Conversion complete: '$OUTPUT_FILE'"
else
  echo "Error during conversion. Check logs above."
  # Clean up the partial/failed output file
  rm -f "$OUTPUT_FILE"
fi
