#!/usr/bin/env bash
set -x

# Function to detect scenes using SIFT-Video
detect_scenes() {
  local video_file="$1"
  local output_dir="$2"
  local base_name="$3"
  
  # Use SIFT-Video for intelligent scene detection
  python3 "${HOME}/Workspace/SIFT-Video/cli.py" \
    --input "${video_file}" \
    --output-dir "${output_dir}" \
    --scene-only \
    --threshold 30.0
  
  # Return the scene list file if created
  echo "${output_dir}/${base_name}_scenes.json"
}

# Function to split audio based on scene boundaries
split_audio_by_scenes() {
  local audio_file="$1"
  local scene_file="$2" 
  local output_dir="$3"
  local base_name="$4"
  
  # Extract scene timestamps and split audio accordingly
  if [[ -f "$scene_file" ]] && command -v jq >/dev/null 2>&1; then
    echo "Splitting audio based on scene boundaries..."
    
    # Parse scene boundaries from JSON
    local scene_count=0
    while read -r start_time end_time; do
      if [[ -n "$start_time" && -n "$end_time" ]]; then
        local output_file="${output_dir}/${base_name}_scene_$(printf "%03d" $scene_count).wav"
        
        # Extract audio segment using ffmpeg
        ffmpeg -i "${audio_file}" \
          -ss "$start_time" \
          -to "$end_time" \
          -c copy \
          "$output_file" 2>/dev/null
        
        ((scene_count++))
      fi
    done < <(jq -r '.scenes[] | "\(.start_time) \(.end_time)"' "$scene_file" 2>/dev/null)
    
    return 0
  else
    return 1
  fi
}

# Function to split large audio files intelligently
split_audio() {
  local input_file="$1"
  local output_dir="$2"
  local base_name="$3"
  local video_file="$4"  # Optional: original video file for scene detection
  
  # Try scene-based splitting if video file is available
  if [[ -n "$video_file" && -f "$video_file" ]]; then
    echo "Attempting scene-based splitting..."
    local scene_file=$(detect_scenes "$video_file" "$output_dir" "$base_name")
    
    if split_audio_by_scenes "$input_file" "$scene_file" "$output_dir" "$base_name"; then
      echo "Scene-based splitting successful"
      return 0
    else
      echo "Scene-based splitting failed, falling back to silence detection"
    fi
  fi
  
  # Fallback to silence-based splitting using sox
  if command -v sox >/dev/null 2>&1; then
    echo "Using silence-based splitting with sox..."
    sox "${input_file}" "${output_dir}/${base_name}_chunk_.wav" \
      silence 1 0.1 1% 1 2.0 1% : \
      newfile : \
      restart
    
    if [[ $? -eq 0 ]]; then
      return 0
    fi
  fi
  
  # Final fallback to time-based splitting
  echo "Using time-based splitting with ffmpeg..."
  ffmpeg -i "${input_file}" \
    -f segment \
    -segment_time 600 \
    -reset_timestamps 1 \
    -c copy \
    "${output_dir}/${base_name}_chunk_%03d.wav"
}

# Function to run whisper-stream
run_whisper() {
  local wav_file="$1"
  local whisper_stream="whisper-stream"
  
  # Check if file size is under 25MB limit
  local filesize=$(stat -c%s "$wav_file")
  if [ $filesize -gt 26214400 ]; then
    echo "Audio file exceeds 25MB limit, splitting into chunks..."
    
    # Split the audio file (pass original video file for scene detection)
    split_audio "${wav_file}" "${dest_dir}" "${filename}" "${infile}"
    
    # Process each chunk (handle both scene and chunk naming)
    local chunk_files=("${dest_dir}/${filename}_scene_"*.wav "${dest_dir}/${filename}_chunk_"*.wav)
    local all_text=""
    local chunk_num=0
    
    for chunk_file in "${chunk_files[@]}"; do
      if [[ -f "$chunk_file" ]]; then
        echo "Processing chunk: $(basename "$chunk_file")"
        
        # Transcribe chunk
        $whisper_stream \
          -f "${chunk_file}" \
          -l "en" \
          -q \
          -df "${chunk_file%.wav}.txt"
        
        # Append to combined text
        if [[ -f "${chunk_file%.wav}.txt" ]]; then
          echo "=== Chunk $((++chunk_num)) ===" >> "${dest_dir}/${filename}.txt"
          cat "${chunk_file%.wav}.txt" >> "${dest_dir}/${filename}.txt"
          echo "" >> "${dest_dir}/${filename}.txt"
        fi
        
        # Clean up chunk file
        rm -f "${chunk_file}" "${chunk_file%.wav}.txt"
      fi
    done
    
    echo "Combined transcription saved to: ${dest_dir}/${filename}.txt"
    return 0
  fi
  
  # Basic transcription to text file
  $whisper_stream \
    -f "${wav_file}" \
    -l "en" \
    -q \
    -df "${dest_dir}/${filename}.txt"
  
  # Generate timestamped JSON for compatibility
  $whisper_stream \
    -f "${wav_file}" \
    -l "en" \
    -q \
    -g "segment" \
    -df "${dest_dir}/${filename}.json"
}

# Function to run sonic-annotator
run_sonic_annotator() {
  local wav_file="$1"

  sonic-annotator -d vamp:vamp-aubio:aubiomelenergy:mfcc \
    -d vamp:vamp-aubio:aubioonset:onsets \
    -d vamp:vamp-aubio:aubionotes:notes \
    -d vamp:mtg-melodia:melodia:melody "${wav_file}" \
    -w csv --csv-force --csv-basedir "${dest_dir}"
}

# Function to process video using ffmpeg
transcode() {
  local infile="$1"
  local outfile="$2"

  # ffmpeg options
  local crf="15.0"
  local vcodec="libx264"
  local acodec="copy"
  local coder="1"
  local me_method="hex"
  local subq="6"
  local me_range="16"
  local g="250"
  local keyint_min="25"
  local sc_threshold="40"
  local i_qfactor="0.71"
  local b_strategy="1"
  local strict="-2"
  local threads="19"

  /usr/bin/ffmpeg -i "${infile}" \
    -crf "${crf}" \
    -vcodec "${vcodec}" \
    -acodec "${acodec}" \
    -coder "${coder}" \
    -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 \
    -me_method "${me_method}" \
    -subq "${subq}" \
    -me_range "${me_range}" \
    -g "${g}" \
    -keyint_min "${keyint_min}" \
    -sc_threshold "${sc_threshold}" \
    -i_qfactor "${i_qfactor}" \
    -b_strategy "${b_strategy}" \
    -strict "${strict}" \
    -threads "${threads}" \
    -y "${outfile}"
}

# Function to extract audio from a video file
extract_audio() {
  local infile="$1"
  local outfile="$2"
  local compress="$3"
  # Extract audio using ffmpeg
  ffmpeg -i "${infile}" -ar 16000 -acodec pcm_s16le -ac 1 "${outfile}"

  if [[ "$compress" == "mp3" ]]; then
    mp3file="${dest_dir}/${filename}.mp3"
    sox "${outfile}" -b 16 "${mp3file}"
  fi

}

# Function to run the unsilence command
unsilence_audio() {
  local infile="$1"
  local outfile="$2"
  local threshold=$(gum input --prompt "Enter threshold: " --placeholder="-30" --value="-30")

  unsilence -d -ss 1.5 -sl "${threshold}" "${infile}" "${outfile}"

}

normalize() {
  local infile="$1"
  local outfile="$2"

  ffmpeg-normalize -pr -nt rms "${infile}" \
    -prf "highpass=f=200" -prf "dynaudnorm=p=0.4:s=15" -pof "lowpass=f=7000" \
    -ar 48000 -c:a pcm_s16le --keep-loudness-range-target \
    -o "${outfile}"
}

pipeline() {
  local infile="$1"
  local ext="${infile##*.}"
  local normalized="${dest_dir}/${filename}_normalized.${ext}"
  local wavfile="${dest_dir}/${filename}.wav"

  local outfile="${dest_dir}/${filename}.${ext}"

  normalize "${infile}" "${normalized}"

  unsilence_audio "${normalized}" "${outfile}"

  extract_audio "${outfile}" "${wavfile}"

  run_whisper "${wavfile}" && run_sonic_annotator "${wavfile}" "${dest_dir}"

}


# Main script logic
declare infile="$1"
declare fbasename=$(basename "$infile")
declare filename="${fbasename%.*}"
declare ext="${infile##*.}"


if [[ -d "$2" ]]; then
  dest_dir="$2"
else
  dest_dir=$(gum file --directory)
fi

CHOICE=$(gum choose "Transcode" "Extract Audio" "Normalize Audio" "Unsilence Audio" "Pipeline")

case "$CHOICE" in
"Pipeline")
  pipeline "${infile}"
  ;;
"Transcode")
  outfile="${dest_dir}/${filename}.mp4"
  transcode "${infile}" "${outfile}"
  ;;
"Extract Audio")
  outfile="${dest_dir}/${filename}"
  extract_audio "${infile}" "${outfile}.wav"
  ;;
"Normalize Audio")
  outfile="${dest_dir}/${filename}"
  normalize "${infile}" "${outfile}_normalized.${ext}"
  ;;
"Unsilence Audio")
  outfile="${dest_dir}/${filename}"
  unsilence_audio "${infile}" "${outfile}"
  ;;
esac

# Create the destination folder if it doesn't exist
mkdir -p "${dest_dir}"

# # Ask the user if they want to move the files to a permanent folder
# MOVE_CHOICE=$(gum choose "Move to permanent folder" "Keep in temporary folder")

# if [[ "$MOVE_CHOICE" == "Move to permanent folder" ]]; then
#   # Ask for the destination folder
#   dest_dir=$(yad --file --directory)

#   # Check if the user canceled the folder selection
#   if [[ $? -ne 0 ]]; then
#     echo "Folder selection canceled. Files will remain in the temporary directory."
#   else
#     # Move the files to the destination folder
#     move_files "${temp_dir}" "${dest_dir}"

#     # Ask the user if they want to remove the temporary directory
#     rm_tmp=$(gum choose --timeout=6s --selected="yes" "yes" "no")
#     if [[ "$rm_tmp" == "yes" ]]; then
#       rm -rf "${temp_dir}"
#     else
#       echo "Files will remain in the temporary directory."
#     fi

#   fi
# fi
