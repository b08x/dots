#!/usr/bin/env python3
"""
Convert ASS subtitles to JSONL (one JSON object per Dialogue event).

Record schema:
    index, start_ms, end_ms, duration_ms, start, end (H:MM:SS.cc),
    style, speaker (ASS Name field), layer, effect, text, [raw]

Usage:
    ass_to_jsonl.py input.ass                 # writes input.jsonl next to input
                                              # (spaces in output filename -> underscores)
    ass_to_jsonl.py input.ass -o out.jsonl
    ass_to_jsonl.py input.ass -o -            # stdout
    ass_to_jsonl.py *.ass                     # batch, one .jsonl per input
    ass_to_jsonl.py input.ass --keep-raw --include-comments
"""

import argparse
import json
import signal
import sys
from pathlib import Path

import pysubs2


def format_ass_time(ms: int) -> str:
    """Milliseconds -> ASS timestamp H:MM:SS.cc (centiseconds)."""
    cs = round(ms / 10)
    h, cs = divmod(cs, 360000)
    m, cs = divmod(cs, 6000)
    s, cs = divmod(cs, 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def load_subs(path: Path) -> pysubs2.SSAFile:
    # explicit format: autodetection fails on minimal files lacking a Styles section
    fmt = {".ass": "ass", ".ssa": "ssa"}.get(path.suffix.lower())
    try:
        return pysubs2.load(str(path), encoding="utf-8", format_=fmt)
    except UnicodeDecodeError:
        return pysubs2.load(str(path), encoding="latin-1", format_=fmt)


def event_to_record(index: int, event: pysubs2.SSAEvent, keep_raw: bool) -> dict:
    # plaintext strips {\override} tags and maps \N, \n to newlines
    text = " ".join(event.plaintext.split())
    record = {
        "index": index,
        "start_ms": event.start,
        "end_ms": event.end,
        "duration_ms": event.end - event.start,
        "start": format_ass_time(event.start),
        "end": format_ass_time(event.end),
        "style": event.style,
        "speaker": event.name,
        "layer": event.layer,
        "effect": event.effect,
        "text": text,
    }
    if keep_raw:
        record["raw"] = event.text
    return record


def convert(path: Path, include_comments: bool, keep_raw: bool, skip_empty: bool) -> list[dict]:
    subs = load_subs(path)
    records = []
    for event in subs.events:
        if event.is_comment and not include_comments:
            continue
        record = event_to_record(len(records), event, keep_raw)
        if skip_empty and not record["text"]:
            continue
        if include_comments:
            record["comment"] = event.is_comment
        records.append(record)
    return records


def write_jsonl(records: list[dict], out) -> None:
    for record in records:
        out.write(json.dumps(record, ensure_ascii=False) + "\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert ASS subtitles to JSONL (one object per Dialogue event).",
    )
    parser.add_argument("inputs", nargs="+", type=Path, help="Input .ass file(s)")
    parser.add_argument(
        "-o", "--output",
        help="Output path, or '-' for stdout (single input only). Default: <input>.jsonl",
    )
    parser.add_argument("--keep-raw", action="store_true", help="Include original text with override tags")
    parser.add_argument("--include-comments", action="store_true", help="Include Comment: events")
    parser.add_argument("--keep-empty", action="store_true", help="Keep events whose text is empty after stripping")
    return parser.parse_args()


def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # quiet exit when piped to head
    args = parse_args()
    if args.output and len(args.inputs) > 1:
        sys.exit("error: --output only valid with a single input")

    for path in args.inputs:
        if not path.is_file():
            print(f"skip: {path} not found", file=sys.stderr)
            continue
        records = convert(path, args.include_comments, args.keep_raw, not args.keep_empty)

        if args.output == "-":
            write_jsonl(records, sys.stdout)
            continue

        out_path = Path(args.output) if args.output else path.with_suffix(".jsonl")
        out_path = out_path.with_name(out_path.name.replace(" ", "_"))
        with out_path.open("w", encoding="utf-8") as out:
            write_jsonl(records, out)
        print(f"{path.name} -> {out_path} ({len(records)} records)", file=sys.stderr)


if __name__ == "__main__":
    main()
