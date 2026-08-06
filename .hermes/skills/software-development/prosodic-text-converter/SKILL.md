---
name: prosodic-text-converter
description: "Run the prosodic-text-converter CLI: SSML, pitch, TTS."
version: 0.1.0
author: Hermes
metadata:
  hermes:
    tags: [Ruby, SSML, Pitch, Aubio, SonicAnnotator, ElevenLabs]
---

# prosodic-text-converter

Drive the `prosodic-text-converter` Ruby CLI at `~/Workspace/rubyfiles/RubyStuff/prosodic-text-converter/`. The tool reads text (stdin or file), optionally analyzes an audio reference with a pitch backend (aubio YIN or sonic-annotator pYIN), calls an LLM (via `ruby_llm`) to draft SSML tagged with prosody/break cues, and can hand the SSML to ElevenLabs for synthesis. Does NOT cover real-time streaming, custom SSML element authoring, or non-TTS voice cloning.

Repo layout the skill targets (from the actual project tree):
- `lib/prosodic-text-converter.rb` — entrypoint that loads env via `dotenv`, then `core/logging`, `audio/{spectrogram,pitch_analyzer}`, `analysis/{spectrogram_analyzer,prosodic_pattern}`, `text/text_analyzer`, `conversion/{llm_converter,ssml_formatter}`, and `core/{config,converter,cli}`.
- `lib/prosodic-text-converter/core/cli.rb` — `ProsodicTextConverter::CLI.run(args)`.
- `lib/prosodic-text-converter/core/converter.rb` — `Converter.new(pattern:, provider:, model:, pitch_backend:, output_dir:, config:)` plus `Converter.available_pitch_backends`.
- `lib/prosodic-text-converter/conversion/ssml_formatter.rb` — Nokogiri-based validator / cleaner / timing extractor.
- `lib/prosodic-text-converter/conversion/llm_converter.rb` — LLM-driven SSML generation pipeline.
- `lib/prosodic-text-converter/audio/{spectrogram,pitch_analyzer,aubio_pitch_analyzer,sonic_annotator_pitch_analyzer,spectrogram_analyzer,speech_synthesizer}.rb` — SoX + ImageMagick spectrogram pipeline and dual pitch backends.
- `lib/prosodic-text-converter/conversion/elevenlabs_formatter.rb` + `audio/speech_synthesizer.rb` — ElevenLabs TTS path.

## When to Use

- "Convert this paragraph to SSML with deliberate pacing."
- "Extract a prosodic pattern from `voice.wav` and apply it to my text."
- "Pick between aubio and sonic-annotator pitch backends."
- "Synthesize the SSML through ElevenLabs voice X."
- "Validate / clean SSML and report segment + break timing."
- "Run a health check or list backends before processing."
- "Rephrase text with SFL-based prosodic optimization before SSML tagging."

## Prerequisites

- Ruby 3.x (project uses frozen string literals; `tty-config` and `ruby_llm` are the modern dependencies).
- Bundler-managed gems: `ruby_llm`, `nokogiri`, `mini_magick`, `dotenv`, `tty-config`, plus test-only deps if running the test scripts at the repo root.
- System binaries on `PATH`:
  - `sox` — audio decoding / spectrogram source.
  - `convert` (ImageMagick) — spectrogram image generation.
  - `aubio` — required for the `aubio` pitch backend (YIN).
  - `sonic-annotator` — optional, enables the `sonic_annotator` backend (pYIN, plus Vamp plugins like `pyin` and `vamp-example-plugins`).
- LLM provider key (whichever you pass via `--provider`): `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY`, or a local Ollama daemon.
- For TTS: `ELEVENLABS_API_KEY` and a voice ID (`--elevenlabs-voice`).
- A `.env` file in the project root is auto-loaded via `dotenv` (with `overwrite: true`).

## How to Run

The CLI entrypoint is `ProsodicTextConverter::CLI.run(ARGV)`. Invoke through the `terminal` tool from the repo root:

```
ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --help
```

Or via a `bin/` shim if you create one. Pipe text on stdin or pass an input file path as the last positional argument. After conversion, SSML prints to stdout; with `--elevenlabs-voice=...` the MP3 is written to `--output-dir` (default `./output`).

## Quick Reference

- Entry point: `ProsodicTextConverter::CLI.run(args)`.
- Configuration: `ProsodicTextConverter::Config.from_cli_args(args)` (tty-config with env prefix `PTC`, file `prosodic-text-converter.yml`).
- Converter factory: `Converter.new(pattern:, provider:, model:, pitch_backend:, output_dir:, config:)`.
- Backend discovery: `Converter.available_pitch_backends` → `[:aubio]` and/or `[:sonic_annotator]`.
- SSMLFormatter: `validate_ssml(ssml)`, `clean_ssml(ssml)`, `extract_timing_info(ssml)` (returns `{ segments, total_breaks, estimated_break_duration, break_times }`).
- LLMConverter: `LLMConverter` orchestrates `ruby_llm` against the configured `provider` / `model`.
- SpeechSynthesizer: `SpeechSynthesizer.new(provider: :elevenlabs).synthesize_ssml(ssml, voice:, model_id:, stability:, similarity_boost:, dictionary_ids:)`.
- Predefined patterns (segment / pause): `deliberate` (1.0s / 350ms), `rapid` (0.6s / 200ms), `contemplative` (1.4s / 500ms).
- CLI flags (selected):
  - `--pattern=NAME` — `deliberate | rapid | contemplative`.
  - `--audio=FILE` — extract prosodic pattern from this reference audio.
  - `--pitch-backend=NAME` — `aubio` or `sonic_annotator`.
  - `--analyze-only` — analyze audio but skip text conversion.
  - `--spectrogram-dir=DIR` — spectrogram output (default `./spectrograms`).
  - `--provider=NAME` / `--model=NAME` — LLM target (openai/anthropic/gemini/openrouter/ollama).
  - `--elevenlabs-voice=ID` / `--elevenlabs-voice-id=ID`, `--elevenlabs-model=ID`, `--elevenlabs-stability=FLOAT`, `--elevenlabs-similarity-boost=FLOAT`, `--elevenlabs-use-phonemes`, `--elevenlabs-dictionary-ids=ID1,ID2`.
  - `--output=FILE` / `--output-dir=DIR` — TTS output.
  - `--rephrase` / `--no-rephrase`, `--rephrasing-aggressiveness=conservative|medium|aggressive`, `--preserve-meaning-threshold=FLOAT`, `--rephrasing-timeout=SECONDS`.
  - `--verbose`, `--list-backends`, `--list-voices`, `--help`.
- Exit codes: `0` success, `1` generic failure, `124` timeout, `130` SIGINT.

## Procedure

1. From `~/Workspace/rubyfiles/RubyStuff/prosodic-text-converter/`, ensure `.env` carries whichever provider keys you need (e.g. `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`) — `dotenv` loads with `overwrite: true`.
2. Run a health check first to confirm SoX / ImageMagick / pitch backends are present:
   ```
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(["--health-check"])'
   ```
   Health check requires `ruby_llm`, `nokogiri`, `mini_magick`; `sox` and `convert` are required; `aubio` and `sonic-annotator` are optional.
3. List pitch backends to see what the local environment can offer:
   ```
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(["--list-backends"])'
   ```
4. Pipe text on stdin for a basic SSML conversion with the default `deliberate` pattern:
   ```
   echo "Hello, world." | ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --provider=openai
   ```
5. Switch provider/model and pattern:
   ```
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --pattern=rapid --provider=anthropic input.txt
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --pattern=deliberate --provider=openrouter --model=anthropic/claude-3.5-sonnet input.txt
   ```
6. Analyze a reference audio to drive the prosodic pattern:
   ```
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --audio=voice.wav --pitch-backend=aubio input.txt
   ```
   Or research-grade with sonic-annotator (pYIN, with Vamp plugins installed):
   ```
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --audio=speaker.wav --pitch-backend=sonic_annotator input.txt
   ```
7. Analyze-only mode dumps backend, spectrogram path, extracted pattern, and analysis method without producing SSML:
   ```
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --audio=test.wav --pitch-backend=aubio --analyze-only --verbose
   ```
8. Enable SFL-based rephrasing before SSML tagging:
   ```
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --rephrase --rephrasing-aggressiveness=medium --provider=gemini input.txt
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --rephrase --preserve-meaning-threshold=0.9 --audio=voice.wav input.txt
   ```
9. Synthesize the resulting SSML through ElevenLabs (writes MP3 into `--output-dir`, default `./output`):
   ```
   ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(ARGV)' -- --elevenlabs-voice=21m00Tcm4TlvDq8ikWAM --output=speech.mp3 input.txt
   ```
10. Validate / time any SSML string produced above using the formatter directly:
    ```ruby
    require 'prosodic-text-converter/conversion/ssml_formatter'
    f = ProsodicTextConverter::SSMLFormatter.new
    f.validate_ssml(ssml_string)              # => true/false
    f.clean_ssml(ssml_string)                 # pretty-printed, normalized
    f.extract_timing_info(ssml_string)        # => { segments:, total_breaks:, estimated_break_duration:, break_times: }
    ```
11. List ElevenLabs voices when picking one:
    ```
    ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(["--list-voices"])'
    ```
    Requires `ELEVENLABS_API_KEY`.

## Pitfalls

- The top-level `require 'prosodic-text-converter'` auto-loads `.env` with `overwrite: true`; an existing shell `OPENAI_API_KEY` is replaced if `.env` says otherwise. Set what you want in one place only.
- `--audio=...` without an input file errors out ("Text file required when using --audio option"). Provide text via stdin or as a positional arg.
- `--analyze-only` requires a real audio file on disk — `Converter.extract_pattern_from_audio(audio_file, output_dir:)` runs even when `--audio` is missing, but `--analyze-only` is the explicit gate.
- `available_pitch_backends` returns `[]` if neither `aubio` nor `sonic-annotator` is installed; the CLI then raises with install instructions (`apt-get install aubio-tools` on Linux, `brew install aubio` on macOS, plus `brew install sonic-visualiser` for sonic-annotator on macOS).
- Backends report differently: aubio is fast / speech-optimized (YIN), sonic-annotator is research-grade with confidence measures (pYIN, plus Vamp plugins). Same audio can produce different `prosodic_features.analysis_method` strings.
- The `Converter` constructor is wrapped in `Timeout.timeout(config.get(:llm_timeout, 30))`. Slow LLM responses or first-run gem warm-up can hit the timeout — bump `PTC_LLM_TIMEOUT` (or `--llm-timeout` if surfaced) before assuming the LLM is broken.
- Analysis timeout is `config.get(:analysis_timeout, 60)`; the audio+text pipeline doubles it (`analysis_timeout * 2`). Long audio on a slow box can still blow past — drop sample rate with `sox` first.
- `interrupt` (Ctrl-C) exits with code `130`; timeout exits with `124`. A failed validation prints the usage text before `exit 1`. These are deterministic and useful for shell pipelines.
- ElevenLabs options are passed through: `stability`, `similarity_boost`, `dictionary_ids` (comma-split), `model_id`. Empty `dictionary_ids` are dropped before the request. Output directory defaults to `./output`; `--output` is rebased under it unless absolute.
- `SSMLFormatter#clean_ssml` returns the raw string unchanged if Nokogiri parsing fails — it does NOT raise. Use `validate_ssml` for a hard yes/no.
- `extract_timing_info` measures `<prosody>` segments and `<break time="...">` durations in milliseconds (anything non-digit stripped from the time attribute). It does not understand `prosody duration=` overrides, only `<break>` pauses.
- `--rephrase` mode calls the LLM with an SFL-shaped prompt before SSML tagging; the semantic-similarity threshold (`--preserve-meaning-threshold`, default `0.8`) and aggressiveness level affect how much the text changes before it's tagged.

## Verification

Run the health check end-to-end through the `terminal` tool from the repo root:

```
ruby -Ilib -rprosodic-text-converter -e 'ProsodicTextConverter::CLI.run(["--health-check"])'
```

Expected: prints `✓ Ruby <version>`, the three required gems (`ruby_llm`, `nokogiri`, `mini_magick`), `✓ SoX audio processing`, `✓ ImageMagick`, plus at least one `✓ Pitch backend: aubio` (or `sonic_annotator`) line and a final `Health check completed successfully!`. Any `✗` line points at the missing dependency to install before exercising the conversion pipeline.
