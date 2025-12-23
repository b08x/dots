#!/bin/bash

# Script to re-encode video files, with optional GPU acceleration and audio removal.
# Supports batch processing of multiple files.

# Usage: ./vlm_preprocessing.sh [options] file1.mp4 file2.mov ...

# --- Configuration ---
# Set to 1 to enable GPU by default
DEFAULT_GPU=0
# Set to 1 to remove audio by default
DEFAULT_NO_AUDIO=0
# Set to 1 to extract high-quality audio by default
DEFAULT_EXTRACT_AUDIO=0

# --- Argument Parsing ---
if [ "$#" -eq 0 ]; then
  echo "Error: No input files specified."
  echo "Usage: $0 [options] file1.mp4 file2.mov ..."
  echo "Options:"
  echo "  -g, --gpu           Enable GPU acceleration."
  echo "  -e, --extract-audio  Extract high-quality MP3 for transcription."
  echo "  --no-audio          Remove the audio track."
  exit 1
fi

GPU_ENABLED=$DEFAULT_GPU
NO_AUDIO=$DEFAULT_NO_AUDIO
EXTRACT_AUDIO=$DEFAULT_EXTRACT_AUDIO
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
    -e|--extract-audio)
    EXTRACT_AUDIO=1
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

if ! command -v ffprobe &> /dev/null; then
  echo "Warning: ffprobe is not installed. Audio format detection will be unavailable; defaulting to AAC for audio."
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

  # Audio Handling and container decision
  CONTAINER="mp4"

  if [ $NO_AUDIO -eq 1 ]; then
    echo "Removing audio track."
    FFMPEG_CMD+=" -an"
  else
    # Detect audio codec using ffprobe if available
    AUDIO_CODEC=""
    if command -v ffprobe &> /dev/null; then
      AUDIO_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$INPUT_FILE" 2>/dev/null || true)
    else
      echo "Warning: ffprobe not found; defaulting to AAC for audio encoding."
    fi

    if [ -z "${AUDIO_CODEC}" ]; then
      echo "No audio stream detected or detection failed; encoding audio to AAC for safety."
      FFMPEG_CMD+=" -c:a aac -b:a 128k"
    elif [ "${AUDIO_CODEC}" = "flac" ]; then
      echo "Input audio is FLAC: copying audio stream and switching output container to .mkv"
      FFMPEG_CMD+=" -c:a copy"
      CONTAINER="mkv"
    elif [[ "${AUDIO_CODEC}" == pcm_* ]]; then
      echo "Input audio is WAV/PCM: converting to 16-bit FLAC and switching container to .mkv"
      FFMPEG_CMD+=" -c:a flac -sample_fmt s16 -compression_level 5"
      CONTAINER="mkv"
    else
      echo "Encoding audio to AAC (default). Detected codec: ${AUDIO_CODEC}"
      FFMPEG_CMD+=" -c:a aac -b:a 128k"
    fi
  fi

  # Stream Mapping
  if [ $NO_AUDIO -eq 1 ]; then
    FFMPEG_CMD+=" -map 0:v:0"
  else
    FFMPEG_CMD+=" -map 0:v:0 -map 0:a:0"
  fi

  # Adjust output filename extension if container changed
  if [ "${CONTAINER}" = "mkv" ]; then
    OUTPUT_FILE="${INPUT_FILE%.*}_processed.mkv"
    if [ $NO_AUDIO -eq 1 ]; then
      OUTPUT_FILE="${INPUT_FILE%.*}_processed_no_audio.mkv"
    fi
  fi

  FFMPEG_CMD+=" -threads 4"

  FFMPEG_CMD+=" \"$OUTPUT_FILE\""

  # --- Execution ---
  echo "Executing command: $FFMPEG_CMD"
  eval $FFMPEG_CMD

  # --- MP3 Extraction ---
  if [ $EXTRACT_AUDIO -eq 1 ]; then
    MP3_FILE="${INPUT_FILE%.*}.mp3"
    echo "Extracting high-quality MP3: $MP3_FILE"
    FFMPEG_AUDIO_CMD="ffmpeg -i \"$INPUT_FILE\" -vn -c:a libmp3lame -b:a 320k \"$MP3_FILE\""
    echo "Executing command: $FFMPEG_AUDIO_CMD"
    eval $FFMPEG_AUDIO_CMD
    if [ $? -eq 0 ]; then
      echo "Successfully extracted MP3: $MP3_FILE"
    else
      echo "Error: Failed to extract MP3: $MP3_FILE"
    fi
  fi

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