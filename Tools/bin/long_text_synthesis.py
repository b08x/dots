#!/usr/bin/env python
import argparse
import os

import soundfile as sf

from helper import load_text_to_speech, timer, sanitize_filename, load_voice_style


def parse_args():
    parser = argparse.ArgumentParser(description="Long Text-to-Speech (TTS) Inference with ONNX")

    # Device settings
    parser.add_argument(
        "--use-gpu", action="store_true", help="Use GPU for inference (default: CPU)"
    )

    # Model settings
    parser.add_argument(
        "--onnx-dir",
        type=str,
        default="assets/onnx",
        help="Path to ONNX model directory",
    )

    # Synthesis parameters
    parser.add_argument(
        "--total-step", type=int, default=5, help="Number of denoising steps"
    )
    parser.add_argument(
        "--speed",
        type=float,
        default=1.05,
        help="Speech speed (default: 1.05, higher = faster)",
    )

    # Input/Output
    parser.add_argument(
        "--voice-style",
        type=str,
        default="assets/voice_styles/M2.json",
        help="Path to the voice style file",
    )
    parser.add_argument(
        "--text",
        type=str,
        default=None,
        help="Text to synthesize. If not provided, --text-file must be used.",
    )
    parser.add_argument(
        "--text-file",
        type=str,
        default=None,
        help="Path to a file containing the text to synthesize.",
    )
    parser.add_argument(
        "--save-dir", type=str, default="results", help="Output directory"
    )

    return parser.parse_args()


def main():
    print("=== Long Text TTS Inference with ONNX Runtime (Python) ===\n")

    # --- 1. Parse arguments --- #
    args = parse_args()

    if not args.text and not args.text_file:
        raise ValueError("Either --text or --text-file must be provided.")

    if args.text and args.text_file:
        raise ValueError("Cannot use both --text and --text-file. Please provide only one.")

    text = args.text
    if args.text_file:
        with open(args.text_file, 'r', encoding='utf-8') as f:
            text = f.read()

    total_step = args.total_step
    speed = args.speed
    save_dir = args.save_dir
    voice_style_path = args.voice_style

    # --- 2. Load Text to Speech --- #
    text_to_speech = load_text_to_speech(args.onnx_dir, args.use_gpu)

    # --- 3. Load Voice Style --- #
    style = load_voice_style([voice_style_path], verbose=True)

    # --- 4. Synthesize Speech --- #
    print("\nStarting synthesis...")
    with timer("Generating speech from text"):
        wav, duration = text_to_speech(text, style, total_step, speed)

    if not os.path.exists(save_dir):
        os.makedirs(save_dir)

    fname = f"{sanitize_filename(text, 20)}.wav"
    output_path = os.path.join(save_dir, fname)
    
    sf.write(output_path, wav.flatten(), text_to_speech.sample_rate)
    print(f"Saved: {output_path}")

    print("\n=== Synthesis completed successfully! ===")

if __name__ == "__main__":
    main()
