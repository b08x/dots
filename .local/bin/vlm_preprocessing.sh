#!/bin/bash

# Script to re-encode a video file, with optional GPU acceleration and audio removal.

# Usage: ./video_only.sh input.mp4 [-g|--gpu] [--no-audio]

# --- Configuration ---
# Set to 1 to enable GPU by default
DEFAULT_GPU=0
# Set to 1 to remove audio by default
DEFAULT_NO_AUDIO=0

# --- Argument Parsing ---
if [ -z "$1" ]; then
  echo "Error: No input file specified."
  echo "Usage: $0 input.mp4 [-g|--gpu] [--no-audio]"
  exit 1
fi

INPUT_FILE="$1"
GPU_ENABLED=$DEFAULT_GPU
NO_AUDIO=$DEFAULT_NO_AUDIO

# Parse remaining arguments
for arg in "${@:2}"; do
  case $arg in
    -g|--gpu)
    GPU_ENABLED=1
    shift # Remove --gpu from processing
    ;;
    --no-audio)
    NO_AUDIO=1
    shift # Remove --no-audio from processing
    ;;
  esac
done


# --- Prerequisite Checks ---
if ! command -v ffmpeg &> /dev/null; then
  echo "Error: ffmpeg is not installed. Please install it."
  exit 1
fi

# --- File Naming ---
OUTPUT_FILE="${INPUT_FILE%.*}_processed.mp4"
if [ $NO_AUDIO -eq 1 ]; then
  OUTPUT_FILE="${INPUT_FILE%.*}_processed_no_audio.mp4"
fi


# --- FFMPEG Command Construction ---
FFMPEG_CMD="ffmpeg -i \"$INPUT_FILE\""

# Video Codec
if [ $GPU_ENABLED -eq 1 ]; then
  if ! command -v nvidia-smi &> /dev/null; then
    echo "Error: NVIDIA GPU not found. 'nvidia-smi' command failed."
    echo "Cannot use GPU acceleration. Falling back to CPU."
    FFMPEG_CMD+=" -c:v libx264 -crf 23 -preset medium"
  else
    echo "GPU acceleration enabled."
    FFMPEG_CMD+=" -c:v h264_nvenc -preset medium"
  fi
else
  echo "Using CPU for encoding."
  FFMPEG_CMD+=" -c:v libx264 -crf 23 -preset medium"
fi

# Audio Handling
if [ $NO_AUDIO -eq 1 ]; then
  echo "Removing audio track."
  FFMPEG_CMD+=" -an"
else
  FFMPEG_CMD+=" -c:a aac -b:a 128k"
fi

# Stream Mapping
if [ $NO_AUDIO -eq 1 ]; then
  FFMPEG_CMD+=" -map 0:v:0"
else
  FFMPEG_CMD+=" -map 0:v:0 -map 0:a:0"
fi

FFMPEG_CMD+=" \"$OUTPUT_FILE\""

# --- Execution ---
echo "Processing video..."
echo "Executing command: $FFMPEG_CMD"
eval $FFMPEG_CMD

# --- Completion Check ---
if [ $? -eq 0 ]; then
  echo "Video processing complete."
  echo "Output file: $OUTPUT_FILE"
else
  echo "Error: An error occurred during video processing."
  exit 1
fi

exit 0
