---
name: ruby-nlp
description: "Use for classical NLP and text-linguistics tasks in Ruby - sentence/word tokenization, POS tagging, dependency parsing, WordNet lexical lookup, fuzzy/string similarity, TF-IDF/BM25 ranking, topic modeling, and local or hosted transformer inference. Trigger on 'tokenize', 'sentence segmentation', 'POS tagging', 'dependency parsing', 'WordNet', 'fuzzy match', 'TF-IDF', 'BM25', 'topic modeling', 'spaCy', 'transformer inference'."
user-invocable: true
---

# RubyDev Ruby-NLP — Text Linguistics & Classical NLP Toolkit

## Overview

This skill covers Ruby's **text-linguistics and classical NLP toolkit**: tokenization, sentence segmentation, part-of-speech tagging, dependency parsing, lexical resources (WordNet), string/text similarity scoring, topic modeling, and transformer inference (hosted or local). It embodies "The Linguist" persona: pick the narrowest gem that does the linguistic task at hand, don't reach for an LLM call where a tokenizer or a similarity score suffices.

**Core Mandate**: Prefer a deterministic, purpose-built NLP gem over an LLM call whenever the task is tokenization, segmentation, tagging, lexical lookup, or scoring — these are solved problems with fast, free, reproducible tools; save the LLM call for generation and reasoning.

Full gem catalog with Context7 IDs and per-gem notes: [~/.vibe/skills/ruby-nlp/references/nlp-gem-catalog.md](~/.vibe/skills/ruby-nlp/~/.vibe/skills/ruby-nlp/references/nlp-gem-catalog.md)).

## When to Use

- Splitting text into sentences or tokens before embedding or clause-level processing
- Part-of-speech tagging, named-entity recognition, or dependency parsing
- Looking up synonyms, hypernyms, or word relationships (WordNet)
- Fuzzy/approximate string matching (typo-tolerant search, deduplication)
- Scoring text similarity or relevance without a vector database (TF-IDF, BM25)
- Topic modeling over a document collection
- Running transformer models locally (no API call) or via the Hugging Face Hub API

**Don't use for:**
- **The actual LLM chat/completion/embedding client** — use [ruby-llm/SKILL.md](~/.vibe/skills/ruby-llm/SKILL.md)
- **RAG architecture, clause-level chunking pipeline design, pgvector schema, RRF orchestration** — use [genai/SKILL.md](~/.vibe/skills/genai/SKILL.md); this skill supplies the tokenizer/tagger/scorer *inside* that pipeline, it doesn't design the pipeline
- **General Ruby code** — use the [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md)
- **Document extraction from PDF/DOCX/images** (OCR, format conversion) — that's document intelligence, not language processing; use [data-engineer/SKILL.md](~/.vibe/skills/data-engineer/SKILL.md) or a dedicated extraction tool, then hand the extracted text to this skill

## Gem Categories

All gems MUST have their API verified via Context7 MCP (or DeepWiki) **at the point of use** — no central registry or verification step. Full table with Context7 IDs in [~/.vibe/skills/ruby-nlp/references/nlp-gem-catalog.md](~/.vibe/skills/ruby-nlp/~/.vibe/skills/ruby-nlp/references/nlp-gem-catalog.md)).

| Category | Gems | Task |
|:---|:---|:---|
| Tokenization & Segmentation | `pragmatic_segmenter`, `pragmatic_tokenizer`, `tokenizers`, `scalpel` | Split text into sentences, words, or subword units |
| Linguistic Structure | `ruby-spacy`, `linkparser`, `rsyntaxtree`, `lingua` | POS tagging, NER, dependency parsing, syntax trees, text quality |
| Lexical Resources | `wordnet`, `rwordnet`, `wordnet-defaultdb` | Synsets, hypernyms, word relationships |
| Similarity & Ranking | `amatch`, `tf-idf-similarity`, `bm25f` | Fuzzy string matching, TF-IDF/BM25 relevance scoring |
| Topic Modeling | `tomoto` | LDA and related topic-model inference |
| Model Inference & Hub | `hugging-face`, `informers` | Hosted (API) vs. local (ONNX) transformer inference |

**Gemfile fragment** (add only the gems the task actually needs — this whole list is rarely required at once):

```ruby
gem "pragmatic_segmenter"  # or "scalpel" — pick one, not both
gem "pragmatic_tokenizer"
gem "tokenizers"
gem "ruby-spacy"           # requires a Python + spaCy runtime on the host
gem "linkparser"           # requires the Link Grammar C library
gem "rsyntaxtree"
gem "lingua"
gem "rwordnet"             # or "wordnet" — pick one
gem "wordnet-defaultdb"    # required data dependency for either WordNet interface
gem "amatch"
gem "tf-idf-similarity"
gem "bm25f"
gem "tomoto"
gem "hugging-face"         # hosted inference
gem "informers"            # local ONNX inference
```

## Procedure

### Segment text into sentences

Use `pragmatic_segmenter` as the default — it's the more actively-referenced gem in this ecosystem and handles abbreviations, decimals, and quoted speech better than a naive regex split. `scalpel` is an alternative sentence segmenter; **don't run both** in the same pipeline — pick one and be consistent, since they can disagree on edge cases (abbreviations, list markers) and produce different clause boundaries for the same input.

```ruby
require "pragmatic_segmenter"

segmenter = PragmaticSegmenter::Segmenter.new(text: document_text)
sentences = segmenter.segment # => Array of String
```

### Tokenize

Two different granularities, two different gems — don't conflate them:
- **`pragmatic_tokenizer`**: word/token-level splitting for classical NLP (POS tagging input, bag-of-words, etc.)
- **`tokenizers`**: subword/BPE-style tokenization matching how transformer models actually consume text — use this when you need to count tokens against an LLM's context limit, not a rough `text.length / 4` estimate.

```ruby
require "pragmatic_tokenizer"
tokenizer = PragmaticTokenizer::Tokenizer.new
tokens = tokenizer.tokenize(sentence)
```

### Tag part-of-speech, parse dependencies, extract entities

`ruby-spacy` wraps spaCy (via a Python bridge) for POS tagging, named-entity recognition, and dependency parsing:

```ruby
require "ruby-spacy"

nlp = Spacy::Language.new("en_core_web_sm")
doc = nlp.read(sentence)

doc.each do |token|
  { text: token.text, pos: token.pos_, tag: token.tag_, dep: token.dep_, head: token.head.i }
end
```

`ruby-spacy` requires a working Python + spaCy installation on the host (it's a language bridge, not a pure-Ruby reimplementation) — heavier to deploy than the pure-Ruby gems in this table. For link-grammar-style dependency parsing without the Python dependency, `linkparser` is a pure-Ruby-binding alternative, but it requires the underlying Link Grammar C library installed. `rsyntaxtree` renders a parsed structure as a visual syntax tree — a presentation tool, not a parser itself; feed it output from `ruby-spacy` or `linkparser`.

### Look up lexical relationships (WordNet)

```ruby
require "rwordnet"

synsets = WordNet::Synset.find_all("run", :verb)
synsets.first.hypernyms # broader terms
```

`wordnet` and `rwordnet` are two different Ruby interfaces to the same underlying WordNet database — pick one, don't mix. Either requires the `wordnet-defaultdb` gem (or an equivalent SQLite database) as its actual data source; installing just the interface gem without the database gem raises a missing-database error at lookup time, not at require time.

### Score text similarity or relevance without embeddings

For fuzzy/typo-tolerant string matching:

```ruby
require "amatch"

Amatch::Levenshtein.new("kitten").match("sitting") # edit distance
```

For relevance ranking over a document/clause collection without a vector database:

```ruby
require "tf-idf-similarity"

corpus = TfIdfSimilarity::Document.new(text) # per document
matrix = TfIdfSimilarity::TfIdfModel.new(corpus_documents)
similarities = matrix.similarity_matrix
```

`bm25f` scores the same kind of relevance ranking with the BM25F algorithm (Postgres/Elasticsearch-style keyword ranking) — a good pure-Ruby stand-in for `ts_rank`/`plainto_tsquery` when the pipeline doesn't have Postgres full-text search available (see [genai/SKILL.md](~/.vibe/skills/genai/SKILL.md)'s hybrid RRF pattern for where this scoring plugs into a retrieval pipeline's keyword arm).

### Topic model a document collection

```ruby
require "tomoto"

model = Tomoto::LDA.new(k: 10) # 10 topics
documents.each { |doc| model.add_doc(tokenize(doc)) }
model.train(iterations: 100)
model.topic_words(0, top_n: 10) # top terms for topic 0
```

### Run a transformer model — hosted vs. local

- **`hugging-face`**: a Ruby API client to the Hugging Face Hub / Inference API — network call, needs an HF token, no local model download.
- **`informers`**: runs transformer inference **locally** via ONNX Runtime, in pure Ruby — no network call once the model is downloaded, but the model must be ONNX-exported and fits in local memory.

Pick `hugging-face` for prototyping against hosted models or when the model is too large to run locally; pick `informers` when the pipeline needs to run offline, needs low latency without network round-trips, or is processing volumes where per-call API costs would dominate.

## Common Pitfalls

1. **Running two sentence segmenters (`pragmatic_segmenter` + `scalpel`) in the same pipeline.** They disagree on edge cases; pick one and use it consistently so clause boundaries are reproducible.
2. **Conflating `tokenizers` (subword/BPE) with `pragmatic_tokenizer` (word-level).** Using word-level token counts to estimate LLM context usage undercounts — subword tokenizers split rare words into multiple tokens.
3. **Installing `wordnet`/`rwordnet` without `wordnet-defaultdb`.** The interface gem loads fine; the first lookup fails with a missing-database error, not a load-time error — install both together.
4. **Deploying `ruby-spacy` without verifying the Python/spaCy runtime is present on the target host.** Unlike the pure-Ruby gems in this table, it's a language bridge with an external system dependency.
5. **Reaching for an LLM call to do fuzzy matching or relevance scoring.** `amatch`, `tf-idf-similarity`, and `bm25f` are deterministic, free, and orders of magnitude faster than a model call for these specific tasks.
6. **Using `hugging-face` (hosted API) in a hot path with volume/latency requirements it can't meet**, or `informers` (local) for a model too large to fit in the deployment environment's memory — match the inference mode to the actual constraint before picking the gem.

## Verification Checklist

- [ ] All non-stdlib gem APIs verified inline via Context7/DeepWiki before use
- [ ] Exactly one sentence segmenter in use per pipeline (not both `pragmatic_segmenter` and `scalpel`)
- [ ] Token counting for LLM context limits uses `tokenizers` (subword), not a word-level tokenizer or a character-count estimate
- [ ] `wordnet`/`rwordnet` paired with `wordnet-defaultdb` (or equivalent DB) before first lookup
- [ ] `ruby-spacy`'s Python/spaCy runtime dependency verified present on the deployment target
- [ ] Similarity/ranking task solved with a deterministic gem (`amatch`/`tf-idf-similarity`/`bm25f`) rather than an LLM call, where applicable
- [ ] Transformer inference mode (`hugging-face` hosted vs. `informers` local) matched to the pipeline's actual latency/cost/offline constraints
