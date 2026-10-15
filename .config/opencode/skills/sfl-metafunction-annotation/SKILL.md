---
name: sfl-metafunction-annotation
description: Use when classifying utterances with SFL (Systemic Functional Linguistics) Interpersonal and Textual metafunctions — mood, modality, tenor, theme, rheme, and cohesive markers — especially alongside a deterministic Pass 1 analysis (participants, processes, circumstances). Front-loads the sfl-annotator pipeline output contract.
metadata:
  display-name: SFL Metafunction Annotation
  short-description: SFL Interpersonal and Textual metafunction classification
---

# SFL Metafunction Annotation

Annotate input utterances with Hallidayan Interpersonal and Textual metafunction
labels, using the deterministic Pass 1 analysis (participants, processes,
circumstances) as grounding. Classification MUST follow the strict taxonomies
below — never invent labels outside the allowed value sets.

## Inputs

- `utterance`: Spoken transcript segment string.
- `pass1_analysis`: JSON string containing deterministic spaCy extractions
  (`participants`, `processes`, `circumstances`).

## Output

A single JSON object with the keys defined below, and nothing else.

## Interpersonal metafunction

1. `mood` — Classify the primary clause grammatical mood.
   Allowed values: `declarative`, `interrogative_polar`,
   `interrogative_wh`, `imperative`, `exclamative`, `fragment`.
2. `modality` — Classify epistemic probability or deontic obligation.
   Allowed values: `low`, `median`, `high`, `neutral`.
3. `tenor` — Classify social distance, affect, and register.
   Allowed values MUST be restricted to: `formal`, `academic`, `neutral`,
   `casual`, `slang`.

## Textual metafunction

1. `theme` — Extract the exact substring functioning as the point of departure
   (up to and including the first experiential element / participant /
   circumstance).
2. `rheme` — Extract the exact remaining substring of the utterance developing
   the theme.
3. `cohesive_markers` — Extract a list of discourse markers, conjunctions, or
   reference chains linking the segment to prior discourse
   (e.g. `["however", "therefore", "that"]`). Return `[]` if none exist.

## Rules

- `theme` + `rheme` must exactly reconstruct the `utterance` (concatenation,
  allowing only the whitespace between them).
- Every classification must be one of the allowed values above; if a category
  genuinely does not apply, use the fallback permitted for that category
  (`fragment` for mood only when the segment lacks a finite clause).
- Cross-check `theme` against `pass1_analysis`: the first experiential element
  (participant or circumstance) normally anchors the theme.
