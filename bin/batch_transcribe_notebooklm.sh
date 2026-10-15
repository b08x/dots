#!/usr/bin/env bash
set -euo pipefail

PYTHON="/home/b08x/.venv/transcribe/bin/python"
SCRIPT="/home/b08x/bin/transcribe_and_optimize.py"
TARGET_DIR="${1:-/home/b08x/NotebookLM}"

echo "🔍 Scanning for WAV files in: $TARGET_DIR"
mapfile -t FILES < <(fd -e wav . "$TARGET_DIR")

TOTAL="${#FILES[@]}"
echo "Found $TOTAL WAV files."
if [[ "$TOTAL" -eq 0 ]]; then
    echo "No WAV files found."
    exit 0
fi

exec "$PYTHON" "$SCRIPT" --engine assemblyai --in-place --skip-existing --continue-on-error --export-ass --export-srt --speakers-expected 2 --retranscribe-single-speaker "${FILES[@]}"
