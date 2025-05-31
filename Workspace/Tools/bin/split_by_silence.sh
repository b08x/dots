#!/bin/bash

# Ensure the script exits on any error
set -e

# Function to display usage information
usage() {
    echo "Usage: $0 input_video output_directory"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    usage
fi

# Assign input arguments to variables
input_video="$1"
output_dir="$2"

# Verify that the input video file exists
if [ ! -f "$input_video" ]; then
    echo "Error: Input video file '$input_video' not found."
    exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$output_dir"

# Generate a temporary file to store silence detection log
silence_log=$(mktemp)

# Detect silence in the audio stream and log the output
ffmpeg -i "$input_video" -af silencedetect=noise=-30dB:d=5 -f null - 2> "$silence_log"

# Initialize variables
start_time=0
index=1

# Function to extract a segment from the input video
extract_segment() {
    local start=$1
    local end=$2
    local idx=$3
    local duration

    # Calculate the duration of the segment
    duration=$(echo "$end - $start" | bc)

    # Define the output file name
    output_file=$(printf "%s/segment_%03d.mp4" "$output_dir" "$idx")

    # Extract the segment using ffmpeg
    ffmpeg -init_hw_device qsv=qsv:hw -filter_hw_device qsv -i "$input_video" -ss "$start" -t "$duration" -vf 'format=nv12,hwupload=extra_hw_frames=64' -c:v h264_qsv "$output_file"
}

# Read the silence log and process each line
while IFS= read -r line; do
    if [[ $line =~ silence_start ]]; then
        # Extract the silence start time
        silence_start=$(echo "$line" | awk '{print $5}')

        # Extract the segment from the previous start time to the current silence start
        extract_segment "$start_time" "$silence_start" "$index"

        # Update the start time for the next segment
        start_time="$silence_start"
        index=$((index + 1))
    elif [[ $line =~ silence_end ]]; then
        # Update the start time to the end of the silence
        start_time=$(echo "$line" | awk '{print $5}')
    fi
done < "$silence_log"

# Extract the final segment from the last silence end to the end of the video
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_video")
extract_segment "$start_time" "$duration" "$index"

# Clean up the temporary silence log file
rm "$silence_log"
