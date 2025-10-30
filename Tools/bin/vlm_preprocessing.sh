#!/bin/bash

# Script to re-encode video files, with optional GPU acceleration and audio removal.
# Supports batch processing of multiple files.

# Usage: ./vlm_preprocessing.sh [options] file1.mp4 file2.mov ...

# --- Configuration ---
# Set to 1 to enable GPU by default
DEFAULT_GPU=0
# Set to 1 to remove audio by default
DEFAULT_NO_AUDIO=0

# --- Argument Parsing ---
if [ "$#" -eq 0 ]; then
  echo "Error: No input files specified."
  echo "Usage: $0 [options] file1.mp4 file2.mov ..."
  echo "Options:"
  echo "  -g, --gpu       Enable GPU acceleration."
  echo "  --no-audio      Remove the audio track."
  exit 1
fi

GPU_ENABLED=$DEFAULT_GPU
NO_AUDIO=$DEFAULT_NO_AUDIO
FILES=()

# Separate files from options
for arg in "$@"; do
  case $arg in
    -g|--gpu)
    GPU_ENABLED=1
    ;;
    --no-audio)
    NO_AUDIO=1
    ;;
    *)
    # Assuming anything else is a file
    if [ -f "$arg" ]; then
      FILES+=("$arg")
    else
      echo "Warning: Ignoring non-existent file or unknown option: $arg"
    fi
    ;;
  esac
done

if [ ${#FILES[@]} -eq 0 ]; then
  echo "Error: No valid input files found."
  exit 1
fi

# --- Prerequisite Checks ---
if ! command -v ffmpeg &> /dev/null; then
  echo "Error: ffmpeg is not installed. Please install it."
  exit 1
fi

# --- Processing Loop ---
for INPUT_FILE in "${FILES[@]}"; do
  echo "----------------------------------------"
  echo "Processing file: $INPUT_FILE"
  echo "----------------------------------------"

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
  echo "Executing command: $FFMPEG_CMD"
  eval $FFMPEG_CMD

  # --- Completion Check ---
  if [ $? -eq 0 ]; then
    echo "Successfully processed: $INPUT_FILE"
    echo "Output file: $OUTPUT_FILE"
  else
    echo "Error: An error occurred while processing: $INPUT_FILE"
  fi
done

echo "----------------------------------------"
echo "Batch processing complete."
echo "----------------------------------------"

exit 0