#!/usr/bin/env python3
"""
transcribe_and_optimize.py

Modular, headless audio transcription and NLP post-processing pipeline.
Features:
- transcribe.cpp engine integration (default) with native two-speaker MOSS diarization and Whisper fallback.
- Optional AssemblyAI transcription engine fallback (--engine assemblyai).
- Custom speaker labeling (--speaker-1, --speaker-2).
- Domain keyword spotting and sentence boundary protection via spaCy.
- Optional Mistral Vibe LLM dialogue refinement (--vibe).
- NLP-ready JSON serialization by default.
- Backward-compatible ASS subtitle generation (--export-ass).
- ASS dialogue-event JSONL export (--export-jsonl), one JSON object per Dialogue event.
- Direct ASS/SSA -> JSONL conversion when .ass/.ssa files are passed as inputs
  (merged from ass_to_jsonl.py; no transcription or spaCy load).
- Optional interactive styling menu (--tui).

JSONL record schema:
    index, start_ms, end_ms, duration_ms, start, end (H:MM:SS.cc),
    style, speaker (ASS Name field), layer, effect, text, [raw], [comment]
"""

import argparse
import glob
import json
import os
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import termios
import time
import tty
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import pysubs2
from rich.console import Console
from rich.live import Live
from rich.panel import Panel
from rich.table import Table
import spacy
from spacy.language import Language
from spacy.matcher import PhraseMatcher

# --- DEFAULT PATHS & CONSTANTS ---
DEFAULT_TRANSCRIBE_CLI = "/home/b08x/LLMOS/transcribe.cpp/build/bin/transcribe-cli"
DEFAULT_MOSS_SNAPSHOT_DIR = (
    "/home/b08x/.cache/huggingface/hub/models--handy-computer--moss-transcribe-diarize-gguf/snapshots"
)
DEFAULT_WHISPER_SNAPSHOT_DIR = (
    "/home/b08x/.cache/huggingface/hub/models--handy-computer--whisper-large-v3-turbo-gguf/snapshots"
)

# Terminal setup for Rich
_term_width = shutil.get_terminal_size(fallback=(120, 24)).columns
console = Console(force_terminal=True, width=_term_width)


# --- SPACY DOMAIN PHRASE PROTECTOR FACTORY ---
if not Language.has_factory("domain_phrase_protector"):
    @Language.factory("domain_phrase_protector")
    class DomainPhraseProtector:
        def __init__(self, nlp: Language, name: str):
            self.nlp = nlp
            self.matcher = PhraseMatcher(nlp.vocab, attr="LOWER")

        def set_keywords(self, keywords: List[str]) -> None:
            self.matcher = PhraseMatcher(self.nlp.vocab, attr="LOWER")
            if keywords:
                patterns = [self.nlp.make_doc(kw) for kw in keywords if kw.strip()]
                if patterns:
                    self.matcher.add("DOMAIN_KEYWORD", patterns)

        def __call__(self, doc):
            if len(self.matcher) > 0:
                for match_id, start, end in self.matcher(doc):
                    for i in range(start + 1, end):
                        doc[i].is_sent_start = False
            return doc


# --- AUDIO & MODEL HELPERS ---

def find_default_moss_model() -> Optional[str]:
    pattern = os.path.join(DEFAULT_MOSS_SNAPSHOT_DIR, "*", "MOSS-Transcribe-Diarize-Q8_0.gguf")
    matches = glob.glob(pattern)
    return matches[0] if matches else None


def find_default_whisper_model() -> Optional[str]:
    pattern = os.path.join(DEFAULT_WHISPER_SNAPSHOT_DIR, "*", "whisper-large-v3-turbo-Q8_0.gguf")
    matches = glob.glob(pattern)
    return matches[0] if matches else None


def get_gpu_vram_mb() -> int:
    try:
        res = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.total", "--format=csv,noheader,nounits"],
            capture_output=True,
            text=True,
            check=True,
        )
        val = res.stdout.strip().splitlines()[0]
        return int(val)
    except Exception:
        return 0


def resolve_model_path(
    model_arg: Optional[str],
    duration_ms: int = 0,
    backend: str = "auto",
    rich_console: Optional[Console] = None,
) -> str:
    if model_arg:
        if os.path.exists(model_arg):
            return os.path.abspath(model_arg)
        raise FileNotFoundError(f"Specified model file does not exist: {model_arg}")

    # Check for memory and context constraints on long audio (> 150s)
    # Monolithic MOSS caps out on context/generation window and scales poorly on long audio;
    # Whisper Turbo uses fixed 30s sliding windows, supports unbounded duration, and is much faster.
    if duration_ms > 150_000:
        whisper = find_default_whisper_model()
        if whisper and os.path.exists(whisper):
            if rich_console and not rich_console.quiet:
                rich_console.print(
                    f"[yellow]ℹ️ Audio duration ({duration_ms // 1000}s > 150s) exceeds safe single-context limit. "
                    f"Auto-routing to Whisper Turbo.[/yellow]"
                )
            return os.path.abspath(whisper)

    moss = find_default_moss_model()
    if moss and os.path.exists(moss):
        return os.path.abspath(moss)

    whisper = find_default_whisper_model()
    if whisper and os.path.exists(whisper):
        return os.path.abspath(whisper)

    raise FileNotFoundError("Could not locate default MOSS or Whisper GGUF model in cache.")


def resolve_transcribe_cli() -> str:
    env_cli = os.getenv("TRANSCRIBE_CLI_PATH")
    if env_cli and os.path.isfile(env_cli) and os.access(env_cli, os.X_OK):
        return env_cli
    if os.path.isfile(DEFAULT_TRANSCRIBE_CLI) and os.access(DEFAULT_TRANSCRIBE_CLI, os.X_OK):
        return DEFAULT_TRANSCRIBE_CLI
    which_cli = shutil.which("transcribe-cli")
    if which_cli:
        return which_cli
    raise FileNotFoundError("transcribe-cli executable not found.")


def get_audio_duration_ms(audio_path: str) -> int:
    try:
        cmd = [
            "ffprobe",
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            audio_path,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return int(float(res.stdout.strip()) * 1000)
    except Exception:
        return 0


def prepare_wav_for_transcribe(audio_path: str, rich_console: Optional[Console] = None) -> Tuple[str, bool]:
    """Ensures audio is 16kHz mono 16-bit PCM WAV. Returns (wav_path, is_temporary)."""
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    needs_convert = True
    if audio_path.lower().endswith(".wav"):
        try:
            cmd = [
                "ffprobe",
                "-v", "error",
                "-select_streams", "a:0",
                "-show_entries", "stream=sample_rate,channels",
                "-of", "csv=p=0",
                audio_path,
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            output = res.stdout.strip()
            if output == "16000,1":
                needs_convert = False
        except Exception:
            needs_convert = True

    if not needs_convert:
        return audio_path, False

    temp_wav = tempfile.NamedTemporaryFile(suffix="_16k.wav", delete=False)
    temp_wav.close()
    if rich_console and not rich_console.quiet:
        rich_console.print(f"[dim]Converting audio to 16kHz mono WAV: {temp_wav.name}[/dim]")

    conv_cmd = [
        "ffmpeg",
        "-y",
        "-i", audio_path,
        "-ar", "16000",
        "-ac", "1",
        "-c:a", "pcm_s16le",
        temp_wav.name,
    ]
    subprocess.run(conv_cmd, capture_output=True, check=True)
    return temp_wav.name, True


def load_keywords(keywords_arg: Optional[str], keywords_file: Optional[str]) -> List[str]:
    keywords = []
    if keywords_arg:
        for item in keywords_arg.split(","):
            cleaned = item.strip()
            if cleaned:
                keywords.append(cleaned)

    if keywords_file:
        if not os.path.exists(keywords_file):
            raise FileNotFoundError(f"Keywords file not found: {keywords_file}")
        if keywords_file.endswith(".json"):
            with open(keywords_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    for item in data:
                        if isinstance(item, str) and item.strip():
                            keywords.append(item.strip())
        else:
            with open(keywords_file, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        keywords.append(line)

    return list(dict.fromkeys(keywords))


def apply_two_speaker_fallback(
    utterances: List[Dict[str, Any]],
    speaker_1: str = "Speaker 1 (M)",
    speaker_2: str = "Speaker 2 (F)",
) -> List[Dict[str, Any]]:
    """Heuristic fallback to alternate speaker turns for 2-speaker dialogues when diarization fails."""
    if len(utterances) <= 1:
        return utterances

    current_spk = speaker_1
    last_end = 0

    for i, u in enumerate(utterances):
        t0 = u["start_ms"]
        t1 = u["end_ms"]
        gap = t0 - last_end

        prev_q = utterances[i - 1]["text"].strip().endswith("?") if i > 0 else False
        if i > 0 and (gap >= 350 or prev_q):
            current_spk = speaker_2 if current_spk == speaker_1 else speaker_1

        u["speaker"] = current_spk
        last_end = t1

    # If it still produced only 1 speaker (e.g. all gaps < 350ms),
    # force a split across the top pauses
    if len(set(u["speaker"] for u in utterances)) == 1 and len(utterances) > 1:
        gaps = [
            (i, utterances[i]["start_ms"] - utterances[i - 1]["end_ms"])
            for i in range(1, len(utterances))
        ]
        sorted_gaps = sorted([g for _, g in gaps], reverse=True)
        split_idx = min(len(sorted_gaps) // 4, 10)
        threshold = sorted_gaps[split_idx] if sorted_gaps else 100
        current_spk = speaker_1
        last_end = 0
        for i, u in enumerate(utterances):
            t0 = u["start_ms"]
            t1 = u["end_ms"]
            gap = t0 - last_end
            if i > 0 and gap >= max(threshold, 100):
                current_spk = speaker_2 if current_spk == speaker_1 else speaker_1
            u["speaker"] = current_spk
            last_end = t1

    return utterances


# --- TRANSCRIPTION ENGINE LAYER ---

class AudioTranscriber:
    """Base class for transcription engines."""

    def transcribe(self, audio_path: str) -> List[Dict[str, Any]]:
        raise NotImplementedError


class TranscribeCppBackend(AudioTranscriber):
    """Local transcribe.cpp engine with MOSS diarization, Whisper fallback, and OOM recovery."""

    def __init__(
        self,
        cli_path: str,
        model_path: str,
        backend: str = "auto",
        speaker_1: str = "Speaker 1 (M)",
        speaker_2: str = "Speaker 2 (F)",
        rich_console: Optional[Console] = None,
    ):
        self.cli_path = cli_path
        self.model_path = model_path
        self.backend = backend
        self.speaker_1 = speaker_1
        self.speaker_2 = speaker_2
        self.rich_console = rich_console

    def _execute_transcribe_cli(
        self,
        wav_path: str,
        model_path: str,
        backend: str,
        diarize: bool,
    ) -> Dict[str, Any]:
        batch_file = tempfile.NamedTemporaryFile(mode="w", suffix=".list", delete=False)
        try:
            batch_file.write(f"{wav_path}\n")
            batch_file.flush()
            batch_file.close()

            cmd = [
                self.cli_path,
                "-m", model_path,
                "--batch", batch_file.name,
                "--batch-jsonl",
                "-q",
            ]
            if backend != "auto":
                cmd.extend(["--backend", backend])
            if diarize:
                cmd.append("--diarize")

            if self.rich_console and not self.rich_console.quiet:
                self.rich_console.print(
                    f"[dim]Running transcribe-cli with model: {os.path.basename(model_path)} "
                    f"(backend={backend}, diarize={diarize})[/dim]"
                )

            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode != 0:
                err_text = res.stderr.strip() or res.stdout.strip()
                raise RuntimeError(
                    f"transcribe-cli failed (exit code {res.returncode}):\n{err_text}"
                )

            result_json = None
            for line in res.stdout.splitlines():
                line = line.strip()
                if not line or not line.startswith("{"):
                    continue
                try:
                    data = json.loads(line)
                    if "segments" in data:
                        result_json = data
                        break
                    elif "error" in data:
                        raise RuntimeError(f"transcribe-cli reported error: {data['error']}")
                except Exception as e:
                    if "reported error" in str(e):
                        raise
                    continue

            if not result_json:
                raise RuntimeError(
                    f"Failed to parse transcribe-cli JSONL output. Stderr: {res.stderr.strip()}"
                )
            return result_json
        finally:
            if os.path.exists(batch_file.name):
                os.remove(batch_file.name)

    def transcribe(self, audio_path: str) -> List[Dict[str, Any]]:
        wav_path, is_temp = prepare_wav_for_transcribe(audio_path, self.rich_console)
        try:
            is_diarize_model = any(
                k in os.path.basename(self.model_path).lower() for k in ["moss", "granite"]
            )
            try:
                result_json = self._execute_transcribe_cli(
                    wav_path=wav_path,
                    model_path=self.model_path,
                    backend=self.backend,
                    diarize=is_diarize_model,
                )
            except RuntimeError as exc:
                err_lower = str(exc).lower()
                is_oom = any(
                    k in err_lower
                    for k in ["out of memory", "cudamalloc failed", "kv cache allocation failed"]
                )
                if is_oom and is_diarize_model and self.backend in ("auto", "cuda"):
                    whisper_model = find_default_whisper_model()
                    if whisper_model and os.path.exists(whisper_model):
                        if self.rich_console and not self.rich_console.quiet:
                            self.rich_console.print(
                                "[yellow]⚠️ transcribe-cli encountered GPU Out-Of-Memory with MOSS. "
                                "Automatically falling back to Whisper Turbo on CUDA...[/yellow]"
                            )
                        self.model_path = os.path.abspath(whisper_model)
                        result_json = self._execute_transcribe_cli(
                            wav_path=wav_path,
                            model_path=self.model_path,
                            backend=self.backend,
                            diarize=False,
                        )
                    else:
                        if self.rich_console and not self.rich_console.quiet:
                            self.rich_console.print(
                                "[yellow]⚠️ transcribe-cli hit GPU OOM. Retrying MOSS with CPU backend...[/yellow]"
                            )
                        result_json = self._execute_transcribe_cli(
                            wav_path=wav_path,
                            model_path=self.model_path,
                            backend="cpu",
                            diarize=True,
                        )
                else:
                    raise

            utterances = []
            segments = result_json.get("segments", [])
            last_end = 0
            current_speaker = self.speaker_1

            for seg in segments:
                text = seg.get("text", "").strip()
                if not text:
                    continue
                t0_ms = int(seg.get("t0_ms", 0))
                t1_ms = int(seg.get("t1_ms", 0))
                spk_id = seg.get("speaker_id")
                if spk_id == 1:
                    speaker = self.speaker_1
                elif spk_id == 2:
                    speaker = self.speaker_2
                elif spk_id is not None and spk_id > 0:
                    speaker = f"Speaker {spk_id}"
                else:
                    # Alternating speaker turn heuristic for models without native diarization
                    prev_q = utterances[-1]["text"].endswith("?") if utterances else False
                    if (t0_ms - last_end >= 350 or prev_q) and last_end > 0:
                        current_speaker = (
                            self.speaker_2 if current_speaker == self.speaker_1 else self.speaker_1
                        )
                    speaker = current_speaker

                last_end = t1_ms
                utterances.append({
                    "speaker": speaker,
                    "start_ms": t0_ms,
                    "end_ms": t1_ms,
                    "text": text,
                })

            if len(utterances) > 1 and len(set(u["speaker"] for u in utterances)) == 1:
                if self.rich_console and not self.rich_console.quiet:
                    self.rich_console.print(
                        "[yellow]⚠️ Local engine output only 1 speaker. Applying 2-speaker turn-taking fallback...[/yellow]"
                    )
                utterances = apply_two_speaker_fallback(utterances, self.speaker_1, self.speaker_2)

            return utterances
        finally:
            if is_temp and os.path.exists(wav_path):
                os.remove(wav_path)


class AssemblyAIBackend(AudioTranscriber):
    """AssemblyAI cloud transcription engine fallback."""

    def __init__(
        self,
        speaker_1: str = "Speaker 1 (M)",
        speaker_2: str = "Speaker 2 (F)",
        speakers_expected: Optional[int] = 2,
        rich_console: Optional[Console] = None,
    ):
        self.api_key = os.getenv("ASSEMBLYAI_API_KEY")
        if not self.api_key:
            raise ValueError(
                "ASSEMBLYAI_API_KEY environment variable is not set. Please set it using: export ASSEMBLYAI_API_KEY='your_key'"
            )
        self.speaker_1 = speaker_1
        self.speaker_2 = speaker_2
        self.speakers_expected = speakers_expected
        self.rich_console = rich_console

    def transcribe(self, audio_path: str) -> List[Dict[str, Any]]:
        import assemblyai as aai

        aai.settings.api_key = self.api_key
        config_kwargs = {
            "speaker_labels": True,
            "format_text": True,
            "punctuate": True,
            "speech_model": aai.SpeechModel.universal,
            "language_detection": True,
        }
        if self.speakers_expected:
            config_kwargs["speakers_expected"] = self.speakers_expected

        config = aai.TranscriptionConfig(**config_kwargs)

        if self.rich_console and not self.rich_console.quiet:
            spk_info = f" (speakers_expected={self.speakers_expected})" if self.speakers_expected else ""
            self.rich_console.print(f"[dim]Submitting audio to AssemblyAI API{spk_info}...[/dim]")

        transcriber = aai.Transcriber(config=config)
        transcript = transcriber.transcribe(audio_path)
        if transcript.status == aai.TranscriptStatus.error:
            raise RuntimeError(f"AssemblyAI transcription failed: {transcript.error}")

        utterances = []
        if getattr(transcript, "utterances", None):
            for u in transcript.utterances:
                raw_spk = str(u.speaker).strip() if u.speaker is not None else "A"
                if raw_spk in ("A", "1"):
                    speaker = self.speaker_1
                elif raw_spk in ("B", "2"):
                    speaker = self.speaker_2
                else:
                    speaker = f"Speaker {raw_spk}"

                utterances.append({
                    "speaker": speaker,
                    "start_ms": int(u.start),
                    "end_ms": int(u.end),
                    "text": u.text.strip(),
                })
        elif getattr(transcript, "words", None):
            words = transcript.words
            if not words:
                return []

            gap_threshold = 1000
            blocks = []
            first_spk = words[0].speaker or "A"
            current_block = {
                "speaker": first_spk,
                "start": words[0].start,
                "end": words[0].end,
                "words": [words[0].text],
            }

            for w in words[1:]:
                spk = w.speaker or "A"
                start = w.start
                end = w.end
                text = w.text
                time_gap = start - current_block["end"]

                if spk == current_block["speaker"] and time_gap < gap_threshold:
                    current_block["words"].append(text)
                    current_block["end"] = end
                else:
                    blocks.append(current_block)
                    current_block = {
                        "speaker": spk,
                        "start": start,
                        "end": end,
                        "words": [text],
                    }
            blocks.append(current_block)

            for b in blocks:
                raw_spk = str(b["speaker"]).strip()
                if raw_spk in ("A", "1"):
                    speaker = self.speaker_1
                elif raw_spk in ("B", "2"):
                    speaker = self.speaker_2
                else:
                    speaker = f"Speaker {raw_spk}"

                utterances.append({
                    "speaker": speaker,
                    "start_ms": int(b["start"]),
                    "end_ms": int(b["end"]),
                    "text": " ".join(b["words"]).strip(),
                })

        # Safeguard: if diarization returned only 1 speaker but 2 were expected
        if len(utterances) > 1 and len(set(u["speaker"] for u in utterances)) == 1 and self.speakers_expected == 2:
            if self.rich_console and not self.rich_console.quiet:
                self.rich_console.print(
                    "[yellow]⚠️ Diarization detected only 1 speaker. Applying 2-speaker turn-taking fallback...[/yellow]"
                )
            utterances = apply_two_speaker_fallback(utterances, self.speaker_1, self.speaker_2)

        return utterances


# --- SPACY NLP POST-PROCESSING LAYER ---

class SpacyPostProcessor:
    """Handles domain keyword detection and sentence boundary protection."""

    def __init__(self, keywords: Optional[List[str]] = None, rich_console: Optional[Console] = None):
        self.rich_console = rich_console
        self.keywords = list(dict.fromkeys([k.strip() for k in (keywords or []) if k.strip()]))
        self.nlp = self._load_spacy()
        self._setup_pipeline()

    def _load_spacy(self) -> Language:
        try:
            return spacy.load("en_core_web_md")
        except OSError:
            if self.rich_console and not self.rich_console.quiet:
                self.rich_console.print(
                    "[yellow]⚠️ Spacy model 'en_core_web_md' not found. Downloading...[/yellow]"
                )
            subprocess.run([sys.executable, "-m", "spacy", "download", "en_core_web_md"], check=True)
            return spacy.load("en_core_web_md")

    def _setup_pipeline(self) -> None:
        if "domain_phrase_protector" not in self.nlp.pipe_names:
            self.protector = self.nlp.add_pipe("domain_phrase_protector", before="parser")
        else:
            self.protector = self.nlp.get_pipe("domain_phrase_protector")
        self.protector.set_keywords(self.keywords)

    def segment_sentences(
        self, text: str, start_ms: int, end_ms: int
    ) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        if not text.strip():
            return [], []

        doc = self.nlp(text)

        matched_records = []
        if len(self.protector.matcher) > 0:
            seen_spans = set()
            for match_id, start, end in self.protector.matcher(doc):
                span = doc[start:end]
                span_key = (span.start_char, span.end_char)
                if span_key not in seen_spans:
                    seen_spans.add(span_key)
                    matched_records.append({
                        "keyword": span.text,
                        "start_char": span.start_char,
                        "end_char": span.end_char,
                    })
            matched_records.sort(key=lambda x: x["start_char"])

        sents = [s.text.strip() for s in doc.sents if s.text.strip()]
        total_duration = end_ms - start_ms
        total_chars = len(text)
        sentences = []
        current_start = start_ms

        for sent_text in sents:
            sent_len = len(sent_text)
            if total_chars > 0 and total_duration > 0:
                ratio = sent_len / total_chars
                duration = int(total_duration * ratio)
                if duration < 500 and total_duration > (500 * len(sents)):
                    duration = 500
                current_end = current_start + duration
            else:
                current_end = current_start

            sentences.append({
                "text": sent_text,
                "start_ms": current_start,
                "end_ms": current_end,
            })
            current_start = current_end

        if sentences:
            sentences[-1]["end_ms"] = end_ms
            for j in range(len(sentences) - 1):
                if sentences[j]["end_ms"] > sentences[j + 1]["start_ms"]:
                    sentences[j]["end_ms"] = sentences[j + 1]["start_ms"]

        return sentences, matched_records

    def process_utterances(self, raw_utterances: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        processed = []
        for idx, u in enumerate(raw_utterances):
            text = u.get("text", "").strip()
            start_ms = u.get("start_ms", 0)
            end_ms = u.get("end_ms", 0)
            speaker = u.get("speaker", "Unknown")

            sentences, keywords_matched = self.segment_sentences(text, start_ms, end_ms)

            processed.append({
                "id": idx,
                "speaker": speaker,
                "start_ms": start_ms,
                "end_ms": end_ms,
                "text": text,
                "refined_text": text,
                "sentences": sentences,
                "keywords_matched": keywords_matched,
            })
        return processed


# --- VIBE LLM REFINEMENT LAYER ---

class VibeRefiner:
    """Mistral Vibe LLM dialogue and domain vocabulary refiner."""

    def __init__(
        self,
        enabled: bool = False,
        custom_prompt: Optional[str] = None,
        rich_console: Optional[Console] = None,
    ):
        self.enabled = enabled
        self.custom_prompt = custom_prompt
        self.rich_console = rich_console
        self.vibe_bin = shutil.which("vibe") or "/home/b08x/.local/bin/vibe"

    def refine(
        self,
        utterances: List[Dict[str, Any]],
        keywords: List[str],
        post_processor: SpacyPostProcessor,
    ) -> List[Dict[str, Any]]:
        if not self.enabled or not utterances:
            return utterances

        if not os.path.exists(self.vibe_bin) and not shutil.which("vibe"):
            if self.rich_console and not self.rich_console.quiet:
                self.rich_console.print(
                    "[yellow]⚠️ Warning: 'vibe' executable not found. Skipping Vibe refinement.[/yellow]"
                )
            return utterances

        payload = [
            {"id": u["id"], "speaker": u["speaker"], "text": u["text"]}
            for u in utterances
        ]

        instructions = (
            f"Custom instructions: {self.custom_prompt}\n" if self.custom_prompt else ""
        )
        prompt = f"""You are a transcription refinement assistant.
{instructions}Task: Correct domain keyword misspellings, phonetic errors, or speech-to-text glitches in the dialogue utterances below.
Preserve the exact speaker intent, tone, order, and meaning. Do not invent new facts.
Target domain keywords: {', '.join(keywords) if keywords else 'N/A'}

Input utterances:
{json.dumps(payload, ensure_ascii=False, indent=2)}

Return ONLY a valid JSON array of objects with the exact schema:
[
  {{"id": 0, "refined_text": "..."}},
  ...
]
Do not wrap in any extra explanation outside the JSON array."""

        if self.rich_console and not self.rich_console.quiet:
            self.rich_console.print("[cyan]🔮 Running Mistral Vibe domain refinement...[/cyan]")

        try:
            cmd = [
                self.vibe_bin,
                "-p", prompt,
                "--output", "json",
                "--trust",
                "--disabled-tools", "*",
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=120, check=True)
            vibe_json = json.loads(res.stdout)

            assistant_text = ""
            for msg in vibe_json:
                if msg.get("role") == "assistant":
                    for c in msg.get("content", []):
                        if c.get("type") == "text":
                            assistant_text += c.get("text", "")

            assistant_text = assistant_text.strip()
            if assistant_text.startswith("```"):
                lines = assistant_text.splitlines()
                if lines[0].startswith("```"):
                    lines = lines[1:]
                if lines and lines[-1].startswith("```"):
                    lines = lines[:-1]
                assistant_text = "\n".join(lines).strip()

            refined_items = json.loads(assistant_text)
            refined_map = {
                item["id"]: item["refined_text"]
                for item in refined_items
                if "id" in item and "refined_text" in item
            }

            for u in utterances:
                ref_text = refined_map.get(u["id"])
                if ref_text and ref_text != u["text"]:
                    u["refined_text"] = ref_text
                    new_sents, new_kws = post_processor.segment_sentences(
                        ref_text, u["start_ms"], u["end_ms"]
                    )
                    u["sentences"] = new_sents
                    if new_kws:
                        u["keywords_matched"] = new_kws

            if self.rich_console and not self.rich_console.quiet:
                self.rich_console.print("[green]✅ Vibe domain refinement complete.[/green]")

        except Exception as e:
            if self.rich_console and not self.rich_console.quiet:
                self.rich_console.print(
                    f"[yellow]⚠️ Warning: Vibe refinement failed ({e}). Falling back to raw text.[/yellow]"
                )

        return utterances


# --- SUBTITLE STYLING & EXPORT LAYER ---

FONTS = [
    "Suez One", "Potta One", "Dosis", "Gothic A1",
    "Waiting for the Sunrise", "Chilanka",
    "Arial", "Roboto", "Open Sans", "Verdana", "Noto Sans",
]

COLORS = [
    {"label": "White (Default)", "value": pysubs2.Color(255, 255, 255)},
    {"label": "Seishun Indigo", "value": pysubs2.Color(240, 101, 87)},
    {"label": "Seishun Cyan", "value": pysubs2.Color(245, 230, 197)},
    {"label": "Melon Green", "value": pysubs2.Color(159, 246, 178)},
    {"label": "Forest Green", "value": pysubs2.Color(6, 114, 36)},
    {"label": "Sunset Orange", "value": pysubs2.Color(54, 89, 223)},
    {"label": "Warm Peach", "value": pysubs2.Color(189, 224, 255)},
    {"label": "Dark Navy", "value": pysubs2.Color(83, 64, 53)},
    {"label": "Silver Mask", "value": pysubs2.Color(231, 231, 228)},
    {"label": "Yellow", "value": pysubs2.Color(255, 255, 0)},
    {"label": "Magenta", "value": pysubs2.Color(255, 0, 255)},
]

ALIGNMENTS = [
    {"label": "Bottom-Center (2) - Standard", "value": 2},
    {"label": "Bottom-Left (1)", "value": 1},
    {"label": "Bottom-Right (3)", "value": 3},
    {"label": "Top-Center (8)", "value": 8},
    {"label": "Center (5) - Creative", "value": 5},
]

ANIMATIONS = [
    {"label": "None", "value": None},
    {"label": "Seishun Float (Gentle Upward drift)", "value": "seishun_float"},
    {"label": "Fade In/Out (300ms)", "value": "fade"},
    {"label": "Pop-in (Scale)", "value": "pop"},
    {"label": "Dynamic Move (Bottom to Up)", "value": "move_up"},
]


class RichMenu:
    def __init__(self, title, options, multi_select=False, default_indices=None):
        self.title = title
        self.options = options
        self.multi_select = multi_select
        self.selected_index = 0
        self.selected_indices = set(default_indices) if default_indices else set()
        if not multi_select and not self.selected_indices:
            self.selected_indices.add(0)

    def _get_key(self):
        if select.select([sys.stdin], [], [], 0.05)[0]:
            try:
                data = os.read(sys.stdin.fileno(), 10)
                return data.decode("utf-8", errors="ignore") if data else None
            except Exception:
                return None
        return None

    def _render(self):
        table = Table(show_header=False, box=None, padding=(0, 1))
        table.add_column("option", no_wrap=True)
        for i, option in enumerate(self.options):
            label = option["label"] if isinstance(option, dict) else str(option)
            is_highlighted = i == self.selected_index
            is_selected = i in self.selected_indices

            prefix = "[bold green]▶[/] " if is_highlighted else "  "
            if self.multi_select:
                checkbox = "[[bold green]X[/]]" if is_selected else "[ ]"
                display_text = f"{prefix}{checkbox} {label}"
            else:
                display_text = f"{prefix}{label}"

            style = "bold yellow" if is_highlighted else "white"
            if is_selected and not self.multi_select:
                style = "bold green"

            table.add_row(display_text, style=style)

        return Panel(
            table,
            title=f"[bold cyan]{self.title}[/bold cyan]",
            expand=False,
            border_style="blue",
            subtitle="[dim]Arrows: move • Space: toggle • Enter: confirm[/dim]",
        )

    def ask(self):
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            with Live(
                self._render(),
                console=console,
                refresh_per_second=10,
                auto_refresh=False,
                transient=True,
            ) as live:
                live.refresh()
                while True:
                    key = self._get_key()
                    if key is None:
                        time.sleep(0.01)
                        continue

                    if key == "\x1b[A":  # Up
                        self.selected_index = (self.selected_index - 1) % len(self.options)
                    elif key == "\x1b[B":  # Down
                        self.selected_index = (self.selected_index + 1) % len(self.options)
                    elif key == " ":  # Space
                        if self.multi_select:
                            if self.selected_index in self.selected_indices:
                                self.selected_indices.remove(self.selected_index)
                            else:
                                self.selected_indices.add(self.selected_index)
                        else:
                            self.selected_indices = {self.selected_index}
                    elif key in ("\r", "\n"):  # Enter
                        if not self.selected_indices:
                            if not self.multi_select:
                                self.selected_indices.add(self.selected_index)
                            else:
                                continue
                        break
                    elif key == "\x03":  # Ctrl+C
                        raise KeyboardInterrupt()

                    live.update(self._render())
                    live.refresh()
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

        if self.multi_select:
            return [self.options[i] for i in sorted(self.selected_indices)]
        return self.options[list(self.selected_indices)[0]]


def get_user_interactive_options() -> Dict[str, Any]:
    options = {}
    console.print(
        Panel("[bold magenta]🎙️ ASS Subtitle Styling Menu[/bold magenta]", border_style="cyan")
    )
    options["preset"] = RichMenu("Subtitle Format Preset", [
        {"label": "Podcast (Two-Speaker Styling)", "value": "podcast"},
        {"label": "General / Movie Style", "value": "general"},
    ]).ask()["value"]

    options["font"] = RichMenu("Font Family", FONTS).ask()
    options["size"] = int(RichMenu("Font Size", ["40", "50", "60", "70", "80", "90"]).ask())

    text_styles = RichMenu("Text Styles", [
        {"label": "Bold", "value": "bold"},
        {"label": "Italic", "value": "italic"},
        {"label": "Underline", "value": "underline"},
    ], multi_select=True).ask()

    options["bold"] = any(s["value"] == "bold" for s in text_styles)
    options["italic"] = any(s["value"] == "italic" for s in text_styles)
    options["underline"] = any(s["value"] == "underline" for s in text_styles)

    options["speaker_colors"] = [
        RichMenu("Color for Speaker 1", COLORS).ask()["value"],
        RichMenu("Color for Speaker 2", COLORS).ask()["value"],
    ]
    options["alignment"] = RichMenu("Alignment", ALIGNMENTS).ask()["value"]
    options["margin_v"] = int(RichMenu("Vertical Margin", ["20", "30", "50", "70", "100"]).ask())
    options["animation"] = RichMenu("Animations", ANIMATIONS).ask()["value"]
    return options


def get_default_styling_options() -> Dict[str, Any]:
    return {
        "preset": "podcast",
        "font": "Arial",
        "size": 50,
        "bold": False,
        "italic": False,
        "underline": False,
        "speaker_colors": [
            pysubs2.Color(240, 101, 87),   # Seishun Indigo
            pysubs2.Color(245, 230, 197),  # Seishun Cyan
        ],
        "alignment": 2,
        "margin_v": 50,
        "animation": None,
    }


def apply_animation(text: str, animation_type: Optional[str]) -> str:
    if not animation_type:
        return text
    if animation_type == "seishun_float":
        return r"{\t(0,500,\fscy110\fscx110)\blur0.6}" + text
    if animation_type == "fade":
        return r"{\fad(300,300)}" + text
    if animation_type == "pop":
        return r"{\fscx0\fscy0\t(0,200,\fscx100\fscy100)}" + text
    if animation_type == "move_up":
        return r"{\an2\move(960,1080,960,1000)}" + text
    return text


def setup_subs_styles(
    subs: pysubs2.SSAFile,
    options: Dict[str, Any],
    speaker_1: str = "Speaker 1 (M)",
    speaker_2: str = "Speaker 2 (F)",
) -> None:
    colors = options.get("speaker_colors", [
        pysubs2.Color(240, 101, 87),
        pysubs2.Color(245, 230, 197),
    ])

    # Style for Speaker 1
    s1 = pysubs2.SSAStyle()
    s1.fontname = options.get("font", "Arial")
    s1.fontsize = options.get("size", 50)
    s1.primarycolor = colors[0]
    s1.outlinecolor = pysubs2.Color(0, 0, 0)
    s1.backcolor = pysubs2.Color(0, 0, 0, 128)
    s1.outline = 2.0
    s1.shadow = 1.5
    s1.alignment = options.get("alignment", 2)
    s1.marginv = options.get("margin_v", 50)
    s1.bold = options.get("bold", False)
    s1.italic = options.get("italic", False)
    s1.underline = options.get("underline", False)
    subs.styles["Speaker 1"] = s1

    # Style for Speaker 2
    s2 = pysubs2.SSAStyle()
    s2.fontname = options.get("font", "Arial")
    s2.fontsize = options.get("size", 50)
    s2.primarycolor = colors[1] if len(colors) > 1 else colors[0]
    s2.outlinecolor = pysubs2.Color(0, 0, 0)
    s2.backcolor = pysubs2.Color(0, 0, 0, 128)
    s2.outline = 2.0
    s2.shadow = 1.5
    s2.alignment = options.get("alignment", 2)
    s2.marginv = options.get("margin_v", 50)
    s2.bold = options.get("bold", False)
    s2.italic = options.get("italic", False)
    s2.underline = options.get("underline", False)
    subs.styles["Speaker 2"] = s2

    # Default fallback
    d = pysubs2.SSAStyle()
    d.fontname = options.get("font", "Arial")
    d.fontsize = options.get("size", 50)
    d.primarycolor = pysubs2.Color(255, 255, 255)
    subs.styles["Default"] = d


def build_ass_subs(
    utterances: List[Dict[str, Any]],
    options: Dict[str, Any],
    speaker_1: str = "Speaker 1 (M)",
    speaker_2: str = "Speaker 2 (F)",
) -> pysubs2.SSAFile:
    subs = pysubs2.SSAFile()
    setup_subs_styles(subs, options, speaker_1, speaker_2)
    anim = options.get("animation")

    events = []
    for u in utterances:
        spk = u.get("speaker") or speaker_1
        if spk == speaker_1:
            style = "Speaker 1"
        elif spk == speaker_2:
            style = "Speaker 2"
        else:
            style = "Default"

        sentences = u.get("sentences", [])
        if not sentences:
            sentences = [{
                "text": u.get("refined_text") or u.get("text", ""),
                "start_ms": u.get("start_ms", 0),
                "end_ms": u.get("end_ms", 0),
            }]

        for s in sentences:
            stext = apply_animation(s.get("text", ""), anim)
            event = pysubs2.SSAEvent(
                start=s.get("start_ms", 0),
                end=s.get("end_ms", 0),
                text=stext,
                style=style,
                name=spk,
            )
            events.append(event)

    subs.events = events
    return subs


def export_ass_subtitles(
    utterances: List[Dict[str, Any]],
    output_path: str,
    options: Dict[str, Any],
    speaker_1: str = "Speaker 1 (M)",
    speaker_2: str = "Speaker 2 (F)",
) -> None:
    subs = build_ass_subs(utterances, options, speaker_1, speaker_2)
    subs.save(output_path, encoding="utf-8")


def export_srt_subtitles(
    utterances: List[Dict[str, Any]],
    output_path: str,
    speaker_1: str = "Speaker 1 (M)",
    speaker_2: str = "Speaker 2 (F)",
    include_speaker_label: bool = True,
) -> None:
    """Exports utterances to SubRip (.srt) subtitle format with speaker attribution tags."""
    subs = pysubs2.SSAFile()
    events = []
    for u in utterances:
        spk = u.get("speaker") or speaker_1
        sentences = u.get("sentences", [])
        if not sentences:
            sentences = [{
                "text": u.get("refined_text") or u.get("text", ""),
                "start_ms": u.get("start_ms", 0),
                "end_ms": u.get("end_ms", 0),
            }]

        for s in sentences:
            stext = s.get("text", "").strip()
            if not stext:
                continue
            if include_speaker_label and spk:
                stext = f"[{spk}] {stext}"
            event = pysubs2.SSAEvent(
                start=s.get("start_ms", 0),
                end=s.get("end_ms", 0),
                text=stext,
            )
            events.append(event)

    subs.events = events
    subs.save(output_path, encoding="utf-8")


# --- ASS -> JSONL LAYER (merged from ass_to_jsonl.py) ---

ASS_INPUT_EXTS = (".ass", ".ssa")


def format_ass_time(ms: int) -> str:
    """Milliseconds -> ASS timestamp H:MM:SS.cc (centiseconds)."""
    cs = round(ms / 10)
    h, cs = divmod(cs, 360000)
    m, cs = divmod(cs, 6000)
    s, cs = divmod(cs, 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def load_ass_file(path: Path) -> pysubs2.SSAFile:
    # explicit format: autodetection fails on minimal files lacking a Styles section
    fmt = {".ass": "ass", ".ssa": "ssa"}.get(path.suffix.lower())
    try:
        return pysubs2.load(str(path), encoding="utf-8", format_=fmt)
    except UnicodeDecodeError:
        return pysubs2.load(str(path), encoding="latin-1", format_=fmt)


def ass_event_to_record(index: int, event: pysubs2.SSAEvent, keep_raw: bool) -> Dict[str, Any]:
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


def ass_to_jsonl_records(
    subs: pysubs2.SSAFile,
    include_comments: bool = False,
    keep_raw: bool = False,
    skip_empty: bool = True,
) -> List[Dict[str, Any]]:
    records = []
    for event in subs.events:
        if event.is_comment and not include_comments:
            continue
        record = ass_event_to_record(len(records), event, keep_raw)
        if skip_empty and not record["text"]:
            continue
        if include_comments:
            record["comment"] = event.is_comment
        records.append(record)
    return records


def write_jsonl(records: List[Dict[str, Any]], out) -> None:
    for record in records:
        out.write(json.dumps(record, ensure_ascii=False) + "\n")


def export_jsonl_events(
    utterances: List[Dict[str, Any]],
    output_path: str,
    options: Dict[str, Any],
    speaker_1: str = "Speaker 1 (M)",
    speaker_2: str = "Speaker 2 (F)",
    keep_raw: bool = False,
    skip_empty: bool = True,
) -> int:
    """Exports the ASS dialogue events built from utterances as JSONL. Returns record count."""
    subs = build_ass_subs(utterances, options, speaker_1, speaker_2)
    records = ass_to_jsonl_records(subs, keep_raw=keep_raw, skip_empty=skip_empty)
    with open(output_path, "w", encoding="utf-8") as out:
        write_jsonl(records, out)
    return len(records)


def convert_ass_inputs(ass_files: List[str], args: argparse.Namespace) -> None:
    """Direct ASS/SSA -> JSONL conversion for subtitle inputs (no transcription)."""
    out_is_dir = bool(args.output) and os.path.isdir(args.output)
    if args.output and not out_is_dir and len(ass_files) > 1:
        sys.exit("error: --output must be a directory when converting multiple .ass inputs")
    if args.output == "-":
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # quiet exit when piped to head

    for name in ass_files:
        path = Path(name)
        if not path.is_file():
            print(f"skip: {path} not found", file=sys.stderr)
            continue
        subs = load_ass_file(path)
        records = ass_to_jsonl_records(
            subs, args.include_comments, args.keep_raw, not args.keep_empty
        )

        if args.output == "-":
            write_jsonl(records, sys.stdout)
            continue

        if args.output and not out_is_dir:
            out_path = Path(args.output)
        elif out_is_dir:
            out_path = Path(args.output) / path.with_suffix(".jsonl").name
        else:
            out_path = path.with_suffix(".jsonl")  # next to input
        out_path = out_path.with_name(out_path.name.replace(" ", "_"))
        with out_path.open("w", encoding="utf-8") as out:
            write_jsonl(records, out)
        if not console.quiet:
            console.print(
                f"✅ {path.name} -> [bold green]{out_path}[/bold green] ({len(records)} records)"
            )


# --- PIPELINE RUNNER ---

class PipelineRunner:
    def __init__(
        self,
        transcriber: AudioTranscriber,
        post_processor: SpacyPostProcessor,
        vibe_refiner: VibeRefiner,
        rich_console: Optional[Console] = None,
    ):
        self.transcriber = transcriber
        self.post_processor = post_processor
        self.vibe_refiner = vibe_refiner
        self.rich_console = rich_console

    def run(
        self,
        audio_path: str,
        engine_name: str,
        model_name: str,
        speaker_1: str,
        speaker_2: str,
    ) -> Dict[str, Any]:
        if self.rich_console and not self.rich_console.quiet:
            self.rich_console.print(f"🚀 [bold cyan]Transcribing:[/] {audio_path}")

        duration_ms = get_audio_duration_ms(audio_path)
        raw_utterances = self.transcriber.transcribe(audio_path)

        if self.rich_console and not self.rich_console.quiet:
            self.rich_console.print(
                "🧠 [bold cyan]Processing with spaCy NLP (keywords & sentences)...[/]"
            )
        processed_utterances = self.post_processor.process_utterances(raw_utterances)

        if self.vibe_refiner.enabled:
            processed_utterances = self.vibe_refiner.refine(
                processed_utterances, self.post_processor.keywords, self.post_processor
            )

        if duration_ms == 0 and processed_utterances:
            duration_ms = max(u["end_ms"] for u in processed_utterances)

        return {
            "metadata": {
                "file": os.path.abspath(audio_path),
                "duration_ms": duration_ms,
                "engine": engine_name,
                "model": model_name,
                "speakers": [speaker_1, speaker_2],
                "keywords_loaded": self.post_processor.keywords,
            },
            "utterances": processed_utterances,
        }


# --- CLI PARSER & ENTRYPOINT ---

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="🎙️ Transcribe & Optimize Pipeline: Modular audio transcription with diarization, spaCy NLP, Mistral Vibe refinement, and ASS subtitle export."
    )
    parser.add_argument(
        "audio_files", nargs="+",
        help="Path(s) to audio file(s) to transcribe, .json to re-export, or .ass/.ssa to convert to JSONL",
    )
    parser.add_argument(
        "-o", "--output",
        help="Output file path (.json, .ass, .srt, .jsonl) or directory; '-' = stdout for .ass inputs",
    )
    parser.add_argument(
        "--engine",
        choices=["transcribe_cpp", "assemblyai"],
        default="transcribe_cpp",
        help="Transcription engine to use (default: transcribe_cpp)",
    )
    parser.add_argument(
        "--model",
        help="Path to GGUF model file for transcribe.cpp (default: MOSS-Transcribe-Diarize-Q8_0.gguf)",
    )
    parser.add_argument(
        "--backend",
        choices=["auto", "cuda", "cpu", "vulkan"],
        default="auto",
        help="Compute backend for transcribe.cpp (default: auto)",
    )
    parser.add_argument(
        "--speaker-1",
        default="Speaker 1 (M)",
        help="Custom label for Speaker 1 (default: 'Speaker 1 (M)')",
    )
    parser.add_argument(
        "--speaker-2",
        default="Speaker 2 (F)",
        help="Custom label for Speaker 2 (default: 'Speaker 2 (F)')",
    )
    parser.add_argument(
        "--keywords",
        help="Comma-separated domain keywords to detect (e.g. 'term1,term2')",
    )
    parser.add_argument(
        "--keywords-file",
        help="Path to file containing domain keywords (.txt or .json)",
    )
    parser.add_argument(
        "--vibe",
        action="store_true",
        help="Use Mistral Vibe CLI to refine domain vocabulary and dialogue",
    )
    parser.add_argument(
        "--vibe-prompt",
        help="Custom prompt instructions for Mistral Vibe refinement",
    )
    parser.add_argument(
        "--export-ass",
        action="store_true",
        help="Export processed dialogue as styled ASS subtitles",
    )
    parser.add_argument(
        "--export-srt",
        action="store_true",
        help="Export processed dialogue as SubRip (.srt) subtitles with speaker labels",
    )
    parser.add_argument(
        "--export-jsonl",
        action="store_true",
        help="Export ASS dialogue events as JSONL (one object per event)",
    )
    parser.add_argument(
        "--keep-raw",
        action="store_true",
        help="JSONL: include original event text with override tags",
    )
    parser.add_argument(
        "--include-comments",
        action="store_true",
        help="JSONL (.ass inputs): include Comment: events",
    )
    parser.add_argument(
        "--keep-empty",
        action="store_true",
        help="JSONL: keep events whose text is empty after stripping tags",
    )
    parser.add_argument(
        "--speakers-expected",
        type=int,
        default=2,
        help="Expected number of speakers for diarization (default: 2)",
    )
    parser.add_argument(
        "--retranscribe-single-speaker",
        action="store_true",
        help="When using --skip-existing, re-transcribe if existing output has <= 1 speaker",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Save output files in the same directory as the input audio file",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip processing if the target output JSON file already exists",
    )
    parser.add_argument(
        "--continue-on-error",
        action="store_true",
        help="Continue processing remaining files if an error occurs on a file",
    )
    parser.add_argument(
        "--save-json",
        action="store_true",
        help="Save raw transcription timestamps JSON (<base>_timestamps.json)",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress non-error console output",
    )
    parser.add_argument(
        "--tui",
        action="store_true",
        help="Launch interactive styling menu for ASS subtitles (requires TTY)",
    )
    parser.add_argument(
        "--no-tui",
        action="store_true",
        help="Explicitly run headless without interactive styling menu (default)",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.quiet:
        console.quiet = True

    # ASS/SSA inputs bypass transcription and spaCy entirely
    ass_files = [f for f in args.audio_files if f.lower().endswith(ASS_INPUT_EXTS)]
    if ass_files:
        convert_ass_inputs(ass_files, args)
        args.audio_files = [f for f in args.audio_files if f not in ass_files]
        if not args.audio_files:
            return
    if args.output == "-":
        sys.exit("error: --output - is only valid for .ass/.ssa inputs")

    try:
        keywords = load_keywords(args.keywords, args.keywords_file)
    except Exception as e:
        console.print(f"[red]❌ Error loading keywords: {e}[/red]")
        sys.exit(1)

    # Initialize transcription engine backend
    transcriber = None
    cli_path = None
    if args.engine == "assemblyai":
        try:
            transcriber = AssemblyAIBackend(
                speaker_1=args.speaker_1,
                speaker_2=args.speaker_2,
                speakers_expected=args.speakers_expected,
                rich_console=console,
            )
            model_name = "universal"
        except ValueError as e:
            console.print(f"[red]❌ {e}[/red]")
            sys.exit(1)
        except Exception as e:
            console.print(f"[red]❌ Error initializing AssemblyAI: {e}[/red]")
            sys.exit(1)
    else:
        try:
            cli_path = resolve_transcribe_cli()
            model_name = args.model or "auto"
        except Exception as e:
            console.print(f"[red]❌ Error initializing transcribe.cpp engine: {e}[/red]")
            sys.exit(1)

    # Initialize spaCy and Vibe refiner
    try:
        post_processor = SpacyPostProcessor(keywords=keywords, rich_console=console)
    except Exception as e:
        console.print(f"[red]❌ Error initializing spaCy post-processor: {e}[/red]")
        sys.exit(1)

    vibe_refiner = VibeRefiner(
        enabled=args.vibe,
        custom_prompt=args.vibe_prompt,
        rich_console=console,
    )

    runner = PipelineRunner(
        transcriber=transcriber,
        post_processor=post_processor,
        vibe_refiner=vibe_refiner,
        rich_console=console,
    )

    # Determine subtitle options if exporting ASS
    user_options = None
    if (
        args.export_ass
        or args.export_jsonl
        or (args.output and args.output.lower().endswith((".ass", ".jsonl")))
    ):
        if args.tui and sys.stdin.isatty():
            try:
                user_options = get_user_interactive_options()
            except KeyboardInterrupt:
                console.print("\n[yellow]Interrupted by user. Exiting...[/yellow]")
                sys.exit(0)
        else:
            user_options = get_default_styling_options()

    for idx, audio_file in enumerate(args.audio_files, 1):
        if not console.quiet:
            console.print(f"\n{'=' * 60}")
            console.print(f"📁 Processing File {idx}/{len(args.audio_files)}: {audio_file}")
            console.print(f"{'=' * 60}")

        is_json_input = audio_file.lower().endswith(".json")
        if is_json_input:
            base_name = os.path.splitext(os.path.basename(audio_file))[0]
            if base_name.endswith("_nlp"):
                base_name = base_name[:-4]
            audio_dir = os.path.dirname(os.path.abspath(audio_file))
            model_name = "from_json"
        else:
            if args.engine == "transcribe_cpp":
                duration_ms = get_audio_duration_ms(audio_file)
                cur_model = resolve_model_path(
                    args.model,
                    duration_ms=duration_ms,
                    backend=args.backend,
                    rich_console=console,
                )
                transcriber = TranscribeCppBackend(
                    cli_path=cli_path,
                    model_path=cur_model,
                    backend=args.backend,
                    speaker_1=args.speaker_1,
                    speaker_2=args.speaker_2,
                    rich_console=console,
                )
                model_name = cur_model
                runner.transcriber = transcriber

            base_name = os.path.splitext(os.path.basename(audio_file))[0]
            audio_dir = os.path.dirname(os.path.abspath(audio_file))

        # Determine output file paths
        need_ass = args.export_ass
        need_srt = args.export_srt
        need_jsonl = args.export_jsonl
        jsonl_path = None

        if args.in_place:
            json_path = os.path.join(audio_dir, f"{base_name}_nlp.json")
            ass_path = os.path.join(audio_dir, f"{base_name}_nlp.ass")
            srt_path = os.path.join(audio_dir, f"{base_name}_nlp.srt")
            raw_json_path = os.path.join(audio_dir, f"{base_name}_timestamps.json")
        elif args.output:
            if len(args.audio_files) == 1:
                if args.output.lower().endswith(".ass"):
                    ass_path = args.output
                    srt_path = os.path.splitext(args.output)[0] + ".srt"
                    json_path = os.path.splitext(args.output)[0] + ".json"
                    raw_json_path = os.path.splitext(args.output)[0] + "_timestamps.json"
                    need_ass = True
                elif args.output.lower().endswith(".srt"):
                    srt_path = args.output
                    ass_path = os.path.splitext(args.output)[0] + ".ass"
                    json_path = os.path.splitext(args.output)[0] + ".json"
                    raw_json_path = os.path.splitext(args.output)[0] + "_timestamps.json"
                    need_srt = True
                elif args.output.lower().endswith(".jsonl"):
                    jsonl_path = args.output
                    json_path = os.path.splitext(args.output)[0] + ".json"
                    ass_path = os.path.splitext(args.output)[0] + ".ass"
                    srt_path = os.path.splitext(args.output)[0] + ".srt"
                    raw_json_path = os.path.splitext(args.output)[0] + "_timestamps.json"
                    need_jsonl = True
                elif args.output.lower().endswith(".json"):
                    json_path = args.output
                    ass_path = os.path.splitext(args.output)[0] + ".ass"
                    srt_path = os.path.splitext(args.output)[0] + ".srt"
                    raw_json_path = os.path.splitext(args.output)[0] + "_timestamps.json"
                else:
                    if os.path.isdir(args.output):
                        json_path = os.path.join(args.output, f"{base_name}_nlp.json")
                        ass_path = os.path.join(args.output, f"{base_name}_nlp.ass")
                        srt_path = os.path.join(args.output, f"{base_name}_nlp.srt")
                        raw_json_path = os.path.join(args.output, f"{base_name}_timestamps.json")
                    else:
                        json_path = args.output
                        ass_path = f"{args.output}.ass"
                        srt_path = f"{args.output}.srt"
                        raw_json_path = f"{args.output}_timestamps.json"
            else:
                if os.path.isdir(args.output):
                    json_path = os.path.join(args.output, f"{base_name}_nlp.json")
                    ass_path = os.path.join(args.output, f"{base_name}_nlp.ass")
                    srt_path = os.path.join(args.output, f"{base_name}_nlp.srt")
                    raw_json_path = os.path.join(args.output, f"{base_name}_timestamps.json")
                else:
                    json_path = f"{base_name}_nlp.json"
                    ass_path = f"{base_name}_optimized.ass"
                    srt_path = f"{base_name}_optimized.srt"
                    raw_json_path = f"{base_name}_timestamps.json"
        else:
            json_path = f"{base_name}_nlp.json"
            ass_path = f"{base_name}_optimized.ass"
            srt_path = f"{base_name}_optimized.srt"
            raw_json_path = f"{base_name}_timestamps.json"

        if jsonl_path is None:
            jsonl_path = os.path.splitext(ass_path)[0] + ".jsonl"

        if args.skip_existing and os.path.exists(json_path):
            skip = True
            if args.retranscribe_single_speaker:
                try:
                    with open(json_path, "r", encoding="utf-8") as f:
                        old_data = json.load(f)
                    old_speakers = set(u.get("speaker") for u in old_data.get("utterances", []))
                    if len(old_speakers) <= 1:
                        skip = False
                        if not console.quiet:
                            console.print(
                                f"[yellow]🔄 Re-transcribing {audio_file}: existing output only has 1 speaker ({old_speakers})[/yellow]"
                            )
                except Exception:
                    pass
            if skip:
                if not console.quiet:
                    console.print(
                        f"[yellow]⏩ Skipping {audio_file}: output already exists ({json_path})[/yellow]"
                    )
                continue

        if is_json_input:
            with open(audio_file, "r", encoding="utf-8") as f:
                result = json.load(f)
            if isinstance(result, list):
                result = {"utterances": result}
            speakers = set(u.get("speaker") for u in result.get("utterances", []))
            if len(speakers) <= 1 and args.speakers_expected == 2:
                if not console.quiet:
                    console.print(
                        f"[yellow]⚠️ Existing JSON has only 1 speaker ({speakers}). Applying 2-speaker turn-taking fallback...[/yellow]"
                    )
                result["utterances"] = apply_two_speaker_fallback(
                    result.get("utterances", []), args.speaker_1, args.speaker_2
                )
        else:
            try:
                result = runner.run(
                    audio_path=audio_file,
                    engine_name=args.engine,
                    model_name=model_name,
                    speaker_1=args.speaker_1,
                    speaker_2=args.speaker_2,
                )
            except Exception as e:
                console.print(f"[red]❌ Error processing {audio_file}: {e}[/red]")
                if args.continue_on_error or len(args.audio_files) > 1:
                    continue
                else:
                    sys.exit(1)

        # Save JSON output
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2, ensure_ascii=False)
        if not console.quiet:
            console.print(f"✅ Saved Structured NLP JSON: [bold green]{json_path}[/bold green]")

        # Save raw timestamps JSON if requested
        if args.save_json:
            with open(raw_json_path, "w", encoding="utf-8") as f:
                json.dump(result["utterances"], f, indent=2, ensure_ascii=False)
            if not console.quiet:
                console.print(f"✅ Saved Raw JSON: [bold green]{raw_json_path}[/bold green]")

        # Export ASS subtitles if requested
        if need_ass:
            export_ass_subtitles(
                utterances=result["utterances"],
                output_path=ass_path,
                options=user_options or get_default_styling_options(),
                speaker_1=args.speaker_1,
                speaker_2=args.speaker_2,
            )
            if not console.quiet:
                console.print(f"✅ Generated ASS Subtitles: [bold green]{ass_path}[/bold green]")

        # Export SRT subtitles if requested
        if need_srt:
            export_srt_subtitles(
                utterances=result["utterances"],
                output_path=srt_path,
                speaker_1=args.speaker_1,
                speaker_2=args.speaker_2,
            )
            if not console.quiet:
                console.print(f"✅ Generated SRT Subtitles: [bold green]{srt_path}[/bold green]")

        # Export ASS dialogue events as JSONL if requested
        if need_jsonl:
            n_records = export_jsonl_events(
                utterances=result["utterances"],
                output_path=jsonl_path,
                options=user_options or get_default_styling_options(),
                speaker_1=args.speaker_1,
                speaker_2=args.speaker_2,
                keep_raw=args.keep_raw,
                skip_empty=not args.keep_empty,
            )
            if not console.quiet:
                console.print(
                    f"✅ Generated JSONL Events: [bold green]{jsonl_path}[/bold green] ({n_records} records)"
                )

        # Print summary table if not quiet
        if not console.quiet:
            table = Table(title=f"Utterance Summary for {base_name}", show_header=True)
            table.add_column("ID", justify="right", style="cyan", no_wrap=True)
            table.add_column("Speaker", style="magenta")
            table.add_column("Time (ms)", style="green")
            table.add_column("Text", style="white")
            table.add_column("Keywords", style="yellow")
            for u in result["utterances"]:
                kws = ", ".join(k["keyword"] for k in u["keywords_matched"]) or "-"
                disp_text = u["refined_text"] if u["refined_text"] != u["text"] else u["text"]
                table.add_row(
                    str(u["id"]),
                    u["speaker"],
                    f"{u['start_ms']}-{u['end_ms']}",
                    disp_text[:60] + ("..." if len(disp_text) > 60 else ""),
                    kws,
                )
            console.print(table)


if __name__ == "__main__":
    main()
