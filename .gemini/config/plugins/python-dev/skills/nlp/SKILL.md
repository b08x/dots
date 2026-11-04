---
name: nlp
description: "Use for classical NLP in Python: tokenization, segmentation, POS tagging, and dependency parsing with spaCy; WordNet lookups with the wn package (Open English WordNet); lexical ranking with scikit-learn TF-IDF and bm25s. Loaded by the implementer when the brief names nlp, spaCy, WordNet, BM25, TF-IDF, or POS tagging. Not for LLM work."
---

# NLP: Classical Language Processing

Classical NLP is deterministic and inspectable. Use it for tokens, tags, parses, lexical lookups, and lexical ranking. Use `genai` for anything that generates or judges text with a model.

## Tools

| Task | Tool | Note |
|---|---|---|
| Tokenize, tag, parse | `spacy` | Run one pipeline pass over a `Doc`. Load the model once per process. |
| Lexical database | `wn` with Open English WordNet | Query local data; do not depend on a global corpus loader. |
| TF-IDF vectors | `scikit-learn` `TfidfVectorizer` | Fit on the training corpus only; transform new text. |
| BM25 ranking | `bm25s` | Precomputes sparse scores at index time. Fast top-k over large corpora. |

## Rules

- Load a spaCy pipeline once and reuse it. Creating a pipeline per call is the common performance bug.
- Keep tokenization and tagging in one pipeline pass. Do not tokenize and then re-tag the strings.
- Fit TF-IDF and BM25 indexes once. Persist them with the corpus version, so a query never silently uses a stale index.
- Treat WordNet results as a lookup. Record the lexicon version in the output.
- Benchmark claims in library READMEs are the library's own. Measure on your corpus before you rely on a figure.

## Typed output

```python
from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class Token(BaseModel):
    """One token with its linguistic annotations."""

    model_config = ConfigDict(frozen=True, strict=True, extra="forbid")

    text: str
    lemma: str
    pos: str
    dep: str
```

## Testing

- Use short fixed sentences with known tags. Assert the tags, not the whole parse tree.
- For ranking, assert the order of two documents where the relevant one must rank first. Do not assert exact scores.
- Keep the spaCy model name in settings so tests can use a smaller model.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Slow tagging | Pipeline loaded per call | Cache the pipeline at module scope behind a function |
| Query returns unrelated documents | Index built on a different corpus version | Rebuild the index; store the corpus hash with it |
| Different tags across machines | Different model versions | Pin the model package version in `pyproject.toml` |

## Related

- `genai` for LLM calls.
- `db-engineer` for storing indexes and corpora.
