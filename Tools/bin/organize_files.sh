#!/bin/bash

# This script organizes video and subtitle files into session-based folders.
# It groups videos based on the time gap between them. A new session starts
# when the time between consecutive files exceeds a set threshold.

# --- Configuration ---
# Video file extension (e.g., "mp4", "mkv")
VIDEO_EXTENSION="mp4"
# Maximum time gap between files in the same session (in seconds).
# 600 seconds = 10 minutes
MAX_GAP_SECONDS=600

# --- Script Logic ---
# Get a sorted list of video files. Sorting by name works because the filenames are timestamps.
video_files=($(ls *."$VIDEO_EXTENSION" 2>/dev/null | sort))

# Check if any video files were found.
if [ ${#video_files[@]} -eq 0 ]; then
    echo "No .${VIDEO_EXTENSION} files found."
    exit 0
fi

echo "Found ${#video_files[@]} video file(s). Starting organization..."
echo "---------------------------------"

last_file_timestamp=0
session_dir=""

# Loop through all found video files.
for video_file in "${video_files[@]}"; do
    # Extract the base name (e.g., "2025-10-26_12-03-33")
    base_name="${video_file%.$VIDEO_EXTENSION}"

    # --- Timestamp Extraction ---
    # The filename format is assumed to be YYYY-MM-DD_HH-MM-SS.
    date_part="${base_name%_*}"
    time_part="${base_name#*_}"
    # Replace hyphens in time part with colons for the 'date' command.
    time_part_formatted="${time_part//-/:}"
    datetime_str="$date_part $time_part_formatted"

    # Convert the timestamp string to seconds since epoch.
    current_file_timestamp=$(date -d "$datetime_str" +%s)
    
    # --- Session Logic ---
    # Calculate the time difference from the last file.
    time_diff=$((current_file_timestamp - last_file_timestamp))

    # If it's the first file or the gap is too large, start a new session.
    if [ "$last_file_timestamp" -eq 0 ] || [ "$time_diff" -gt "$MAX_GAP_SECONDS" ]; then
        session_dir="$base_name"
        echo "Creating new session directory: $session_dir"
        mkdir -p "$session_dir"
    fi

    # --- File Movement ---
    # Move the video file.
    echo "Moving $video_file to $session_dir/"
    mv "$video_file" "$session_dir/"

    # Move the corresponding subtitle file if it exists.
    subtitle_file="${base_name}.srt"
    if [ -f "$subtitle_file" ]; then
        echo "Moving $subtitle_file to $session_dir/"
        mv "$subtitle_file" "$session_dir/"
    else
        # This is not an error, as not all videos have subtitles.
        echo "Info: No subtitle file found for $video_file"
    fi
    
    # Update the timestamp for the next iteration.
    last_file_timestamp=$current_file_timestamp
    echo "---------------------------------"
done

echo "File organization complete."
