#!/usr/bin/env python3

import assemblyai as aai
import json
import argparse
import os
import sys

# --- CONFIGURATION ---
API_KEY = os.getenv("ASSEMBLYAI_API_KEY")

if not API_KEY:
    print("❌ Error: ASSEMBLYAI_API_KEY environment variable is not set.")
    print("   Please set it using: export ASSEMBLYAI_API_KEY='your_key'")
    sys.exit(1)

# --- HELPER FUNCTIONS FOR ASS CREATION ---


def ms_to_ass_time(ms):
    """Converts milliseconds to ASS timestamp format (H:MM:SS.cs)."""
    if ms is None:
        ms = 0
    seconds = ms / 1000.0
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    cs = int((seconds * 100) % 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def generate_ass_from_data(word_data, output_file):
    """Generates an ASS file from the list of word objects."""

    # 1. Define Styles (Host A = Cyan, Host B = Yellow)
    ass_content = [
        "[Script Info]",
        "Title: Podcast Subtitles",
        "ScriptType: v4.00+",
        "Collisions: Normal",
        "PlayResX: 1920",
        "PlayResY: 1080",
        "",
        "[V4+ Styles]",
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
        "Style: Host A,Arial,60,&H008AB3FF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,1.5,1.0,2,10,10,50,1",
        "Style: Host B,Arial,60,&H00FAE6E6,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,1.5,1.0,2,10,10,50,1",
        "Style: Default,Arial,60,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,1.5,1.0,2,10,10,50,1",
        "",
        "[Events]",
        "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text",
    ]

    # 2. Group words into phrases
    grouped_lines = []
    if word_data:
        # Initialize first line
        current_line = {
            "speaker": word_data[0]["speaker"],
            "start": word_data[0]["start"],
            "end": word_data[0]["end"],
            "text": [word_data[0]["text"]],
        }

        for item in word_data[1:]:
            speaker = item.get("speaker", "Unknown")
            start = item.get("start", 0)
            end = item.get("end", 0)
            text = item.get("text", "")

            # Logic: Merge if same speaker AND short gap (< 600ms) AND line not too long
            time_gap = start - current_line["end"]
            line_length = sum(len(w) for w in current_line["text"])

            if (
                speaker == current_line["speaker"]
                and time_gap < 600
                and line_length < 80
            ):

                current_line["text"].append(text)
                current_line["end"] = end
            else:
                # Ensure no overlap with the NEXT line
                if current_line["end"] > start:
                    current_line["end"] = start

                grouped_lines.append(current_line)
                current_line = {
                    "speaker": speaker,
                    "start": start,
                    "end": end,
                    "text": [text],
                }
        # Final overlap check for the very last line added after the loop
        if grouped_lines and grouped_lines[-1]["end"] > current_line["start"]:
            grouped_lines[-1]["end"] = current_line["start"]
        grouped_lines.append(current_line)

    # 3. Write Events
    for line in grouped_lines:
        start_time = ms_to_ass_time(line["start"])
        end_time = ms_to_ass_time(line["end"])
        full_text = " ".join(line["text"])
        speaker = line["speaker"] if line["speaker"] else "Unknown"

        # Match Style to Speaker
        # Note: If API returns "Speaker A" instead of "Host A", mapped here
        style = "Default"
        if "Host A" in speaker or "Speaker A" in speaker:
            style = "Host A"
        elif "Host B" in speaker or "Speaker B" in speaker:
            style = "Host B"

        event_str = (
            f"Dialogue: 0,{start_time},{end_time},{style},{speaker},0,0,0,,{full_text}"
        )
        ass_content.append(event_str)

    with open(output_file, "w", encoding="utf-8") as f:
        f.write("\n".join(ass_content))
    print(f"✅ Generated Subtitles: {output_file}")


# --- MAIN TRANSCRIPTION LOGIC ---


def main():
    # Set up Argument Parser
    parser = argparse.ArgumentParser(
        description="Transcribe audio file and generate ASS subtitles."
    )
    parser.add_argument(
        "audio_file",
        help="Path (local) or URL (remote) to the audio file to transcribe",
    )
    args = parser.parse_args()

    file_path = args.audio_file

    # Determine output filenames based on input filename
    if "://" in file_path:
        # It's a URL, get the last segment
        filename = file_path.split("/")[-1].split("?")[0]
        if not filename:
            filename = "downloaded_audio"
    else:
        filename = os.path.basename(file_path)

    base_name = os.path.splitext(filename)[0]
    output_json = f"{base_name}_timestamps.json"
    output_ass = f"{base_name}.ass"

    print(f"🚀 Starting Transcription for: {file_path}")
    print(f"📄 Output files will be: {output_json}, {output_ass}")

    aai.settings.api_key = API_KEY

    # Configure the request
    config = aai.TranscriptionConfig(
        summarization=True,
        iab_categories=True,
        speaker_labels=True,  # Essential for diarization
        format_text=True,
        punctuate=True,
        speech_model=aai.SpeechModel.universal,
        language_detection=True,
    )

    # Note: 'speech_understanding' is not a standard attribute for the base
    # TranscriptionConfig in all SDK versions, but we will attach it as requested.
    config.speech_understanding = {
        "request": {
            "speaker_identification": {
                "speaker_type": "role",
                "known_values": ["Host A", "Host B"],
            }
        }
    }

    transcriber = aai.Transcriber(config=config)

    # Run Transcription
    try:
        transcript = transcriber.transcribe(file_path)
    except Exception as e:
        print(f"❌ Error during transcription request: {e}")
        sys.exit(1)

    if transcript.status == aai.TranscriptStatus.error:
        print(f"❌ Transcription failed: {transcript.error}")
        return

    print("✅ Transcription completed successfully.")

    # Convert AssemblyAI Word objects to a clean dictionary list
    words_data = []
    for w in transcript.words:
        words_data.append(
            {
                "text": w.text,
                "start": w.start,
                "end": w.end,
                "confidence": w.confidence,
                "speaker": w.speaker,
            }
        )

    # Save the raw JSON (useful for debugging)
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(words_data, f, indent=2)
    print(f"✅ Saved Timestamp Data: {output_json}")

    # Generate the ASS file
    generate_ass_from_data(words_data, output_ass)


if __name__ == "__main__":
    main()
