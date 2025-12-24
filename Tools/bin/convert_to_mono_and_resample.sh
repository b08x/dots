#!/bin/bash

# Usage: convert_to_mono_and_resample.sh <input_file> <output_file> <sample_rate>
# Example: convert_to_mono_and_resample.sh input.mp3 output.wav 16000

input_file="$1"
output_file="$2"
sample_rate="${3:-16000}"  # Default sample rate is 16000 if not provided


if [ -z "$input_file" ] || [ -z "$output_file" ]; then
    echo "Usage: $0 <input_file> <output_file> <sample_rate>"
    exit 1
fi

ffmpeg -i "$input_file" \
    -af "highpass=f=200, acompressor=threshold=-20dB:ratio=2:attack=5:release=50" \
    -ar "$sample_rate" \
    -ac 1 \
    -c:a pcm_s16le \
    "$output_file"


if [ $? -eq 0 ]; then
  echo "Audio converted to mono, resampled to ${sample_rate}Hz, gain-adjusted, high-pass filtered, and saved to $output_file"
else
    echo "Error during audio conversion." >&2
    exit 1
fi