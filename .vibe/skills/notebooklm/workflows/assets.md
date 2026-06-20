# Asset Workflow

Generate and download rich media artifacts from NotebookLM notebooks: audio overviews (podcasts), video overviews, slide decks, infographics, flashcards, data tables, and quizzes. All downloaded assets live under `NotebookLM/{slug}/` alongside Sources and QA.

## Asset Types

| Type | Generate | Download | Format | Notes |
|------|---------|---------|--------|-------|
| Audio | `generate audio` | `download audio` | `.mp3` | Podcast-style deep dive; formats: deep-dive, brief, critique, debate |
| Video | `generate video` | `download video` | `.mp4` | Explainer animation; styles: classic, whiteboard, kawaii, anime, watercolor, etc. |
| Cinematic Video | `generate cinematic-video` | `download cinematic-video` | `.mp4` | AI-generated documentary (Veo 3, requires AI Ultra, ~30-40 min) |
| Slide Deck | `generate slide-deck` | `download slide-deck` | `.pdf` or `.pptx` | Formats: detailed, presenter |
| Infographic | `generate infographic` | `download infographic` | image | Visual summary |
| Flashcards | `generate flashcards` | `download flashcards` | JSON | Study cards |
| Data Table | `generate data-table` | `download data-table` | `.csv` | Structured data extraction |
| Quiz | `generate quiz` | `download quiz` | JSON | Q&A pairs |
| Mind Map | `generate mind-map` | `download mind-map` | JSON → Mermaid | See import workflow |

## Vault Structure

```
NotebookLM/{notebook-slug}/
├── Sources/          # .md per source (import workflow)
├── QA/               # Q&A notes (ask workflow)
├── Audio/            # .mp3 podcast files
├── Video/            # .mp4 overview files
└── Slides/           # .pdf or .pptx slide decks
```

Create asset dirs before downloading:
```bash
mkdir -p "NotebookLM/{slug}/Audio" "NotebookLM/{slug}/Video" "NotebookLM/{slug}/Slides"
```

## Step 1: Check Existing Artifacts

Before generating, check what already exists:

```bash
notebooklm artifact list --json
```

Parse output:
```bash
notebooklm artifact list --json | python3 -c "
import json,sys
d = json.load(sys.stdin)
arts = d if isinstance(d,list) else d.get('artifacts',[])
for a in arts:
    print(f\"{a.get('type','?'):15} | {a.get('title','?'):50} | {a.get('status','?')}\")
"
```

Use `-n <notebook-id>` to check a specific notebook without switching context.

## Step 2: Generate (if needed)

All generation is async except mind-map. Use `--wait` to block until done, or `artifact wait <id>` later.

```bash
# Audio - podcast deep dive
notebooklm generate audio "focus on the architectural decisions"
notebooklm generate audio "make it a debate between two perspectives" --format debate

# Audio from specific sources only
notebooklm generate audio "deep dive on the neuro-symbolic section" -s <source_id_1> -s <source_id_2>

# Video overview
notebooklm generate video "explainer for a technical audience" --style classic
notebooklm generate video "accessible overview" --style whiteboard

# Slide deck with speaker notes
notebooklm generate slide-deck "include speaker notes and examples" --format presenter
notebooklm generate slide-deck "executive summary" --format detailed --length short

# Wait for completion
notebooklm artifact wait <artifact-id>
# Or: notebooklm generate audio "..." --wait
```

## Step 3: Download Assets

```bash
# Download latest of each type
notebooklm download audio
notebooklm download video
notebooklm download slide-deck --format pdf

# Download all to a directory (use --no-clobber to skip existing)
notebooklm download audio --all NotebookLM/{slug}/Audio/ --no-clobber
notebooklm download video --all NotebookLM/{slug}/Video/ --no-clobber
notebooklm download slide-deck --all NotebookLM/{slug}/Slides/ --no-clobber --format pdf

# Download a specific artifact by fuzzy name
notebooklm download audio --name "deep dive on chapter 3"
notebooklm download slide-deck --name "executive summary" --format pptx

# Preview without downloading
notebooklm download audio --all --dry-run
```

## Step 4: Register Assets in Dashboard

After downloading, update the notebook's dashboard to reference assets:

```markdown
## Audio Overviews

| File | Topic |
|------|-------|
| [[NotebookLM/{slug}/Audio/Episode Title.mp3]] | Deep dive on X |

## Slide Decks

| File | Focus |
|------|-------|
| [[NotebookLM/{slug}/Slides/Deck Title.pdf]] | Executive summary |

## Videos

| File | Style |
|------|-------|
| [[NotebookLM/{slug}/Video/Overview.mp4]] | Whiteboard explainer |
```

## Step 5: Slide Deck Revision

Revise individual slides in an existing deck:

```bash
notebooklm generate revise-slide "make slide 3 focus more on the Ruby ecosystem" --artifact <artifact-id>
```

## Parallel Download Pattern (Multiple Notebooks)

For bulk asset downloads across notebooks, use background processes:

```bash
(notebooklm download audio --all NotebookLM/nb-a/Audio/ -n <id-a> --no-clobber 2>&1) &
(notebooklm download video --all NotebookLM/nb-b/Video/ -n <id-b> --no-clobber 2>&1) &
(notebooklm download slide-deck --all NotebookLM/nb-c/Slides/ -n <id-c> --no-clobber --format pdf 2>&1) &
wait
```

Note: `notebooklm use` changes the active context globally — use `-n <id>` flag on download commands to avoid context conflicts when running in parallel.

## Cinematic Video (AI Ultra Only)

Requires Google AI Ultra subscription. Generates documentary-style footage via Veo 3. Takes 30-40 minutes.

```bash
notebooklm generate cinematic-video "documentary overview of the architecture"
# ... wait 30-40 min ...
notebooklm artifact wait <artifact-id>
notebooklm download cinematic-video NotebookLM/{slug}/Video/
```
