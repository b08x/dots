# Gem Registry — Context7 IDs × Architectural Roles

Cross-reference of the project gem stack with Context7 library IDs, architectural  
planes, and common usage patterns. Used by rubysmithing-context to resolve library  
IDs without a resolve step, and by rubysmithing-genai/tui for stack-aware scaffolding.

Last updated: 2026-03-18

## Contents
- [Runtime Spine (Boot + Wiring)](#runtime-spine-boot--wiring)
- [CLI & Terminal UI Layer](#cli--terminal-ui-layer)
- [Storage & Persistence](#storage--persistence)
- [Async, Networking & Orchestration](#async-networking--orchestration)
- [AI / NLP Layer](#ai--nlp-layer)
- [Data Processing](#data-processing)
- [Retrieval, Similarity & Fuzzy Matching](#retrieval-similarity--fuzzy-matching)
- [Algorithms / Knowledge Structures](#algorithms--knowledge-structures)
- [Validation & Types](#validation--types)
- [Parsing / Encoding Boundaries](#parsing--encoding-boundaries)
- [Debugging & Introspection](#debugging--introspection)
- [MCP Tooling](#mcp-tooling)


> **Registry staleness**: each entry carries a `last_verified` date (YYYY-MM).
> Entries older than 3 months should be re-verified via Context7 before use.
> Run `cache.evict("<gem>")` after a successful re-verification to force a fresh lookup.

---

## Runtime Spine (Boot + Wiring)

| Gem | Context7 ID | Role | Notes | last_verified |
|---|---|---|---|---|
| dotenv | `/bkeepers/dotenv` | Env var loader | No Context7 entry; API is stable (`Dotenv.load`) | 2026-03 |
| tty-config | `/piotrmurach/tty-config` | Config loader | No Context7 entry; check rubydoc.info | 2026-03 |
| zeitwerk | `/fxn/zeitwerk` | Code autoloader | No Context7 entry; API is stable | 2026-03 |
| rake | `/ruby/rake` | Task automation | No Context7 entry | 2026-03 |
| journald-logger | `/theforeman/journald-logger` | Structured logging | No Context7 entry | 2026-03 |
| hashie | `/hashie/hashie` | Flexible data structures | Mash, indifferent access; abstraction leak vector | 2026-03 |

---

## CLI & Terminal UI Layer

| Gem | Context7 ID | Role | Key Patterns | last_verified |
|---|---|---|---|---|
| bubbletea | `/marcoroth/bubbletea-ruby` | TUI framework (Elm arch) | Model / Update / View lifecycle; 48 snippets | 2026-03 |
| lipgloss | `/marcoroth/lipgloss-ruby` | Terminal styling | Style composition, join_horizontal/vertical; 72 snippets | 2026-03 |
| bubblezone | `/marcoroth/bubblezone-ruby` | Mouse events | Zone registration, click detection; 53 snippets | 2026-03 |
| gum | `/marcoroth/gum-ruby` | Shell UI utilities | choose, input, confirm wrappers; 72 snippets | 2026-03 |
| bubbles | `/marcoroth/bubbles-ruby` | TUI components | List, TextArea, Spinner, Progress | 2026-03 |
| glamour | `/marcoroth/glamour-ruby` | Markdown rendering | Render markdown strings in terminal | 2026-03 |
| harmonica | `/marcoroth/harmonica-ruby` | Animation/transitions | Spring physics for UI transitions | 2026-03 |
| huh | `/marcoroth/huh-ruby` | Form builder | Form groups, Select, Input, Confirm | 2026-03 |
| ntcharts | `/marcoroth/ntcharts-ruby` | Terminal charts | Line, Bar, Scatter charts | 2026-03 |
| highline | `/JEG2/highline` | CLI fallback | No Context7 entry; legacy/fallback only | 2026-03 |
| drydock | `/delano/drydock` | CLI framework | No Context7 entry | 2026-03 |

---

## Storage & Persistence

| Gem | Context7 ID | Role | Key Patterns | last_verified |
|---|---|---|---|---|
| sequel | `/jeremyevans/sequel` | Database toolkit / ORM | Dataset API, migrations, plugins | 2026-03 |
| sequel_pg | `/jeremyevans/sequel_pg` | Postgres performance extension | Faster encoding/decoding, driver bypass paths | 2026-03 |
| pgvector | `/pgvector/pgvector` | Vector similarity search | `vector` column type, `<=>` operator, `nearest_neighbors` | 2026-03 |
| pg | — | PostgreSQL driver | No Context7 entry; used via sequel | 2026-03 |
| redis | — | Redis client | No Context7 entry; API is stable | 2026-03 |
| redic | — | Lightweight Redis client | No Context7 entry | 2026-03 |
| ohm | `/soveran/ohm` | Redis object modeling | No Context7 entry | 2026-03 |
| ohm-contrib | `/cyx/ohm-contrib` | Ohm extensions | No Context7 entry | 2026-03 |

---

## Async, Networking & Orchestration

| Gem | Context7 ID | Role | Key Patterns | last_verified |
|---|---|---|---|---|
| async | `/socketry/async` | Fiber concurrency | `Async { }` blocks, `Async::Task`, barriers | 2026-03 |
| falcon | `/socketry/falcon` | Async HTTP server | Rack-compatible, fiber scheduler | 2026-03 |
| gush | `/chaps-io/gush` | DAG workflow engine | Job definition, workflow creation, Redis backend | 2026-03 |
| faraday | — | HTTP client | No Context7 entry; API is stable | 2026-03 |
| circuit_breaker | `/wsargent/circuit_breaker` | Circuit breaker | State machine-based, thread-safe | 2026-03 |
| parallel | `/grosser/parallel` | Multi-process parallelism | `Parallel.map`, CPU-bound distribution | 2026-03 |
| concurrent-ruby | `/ruby-concurrency/concurrent-ruby` | Concurrency primitives | Futures, promises, thread pools | 2026-03 |
| open4 | `/ahoward/open4` | Process control | Spawn + capture stdout/stderr; shell boundary | 2026-03 |

---

## AI / NLP Layer

| Gem | Context7 ID | Role | Key Patterns | last_verified |
|---|---|---|---|---|
| ruby_llm | `/crmne/ruby_llm` | Unified LLM interface | `.chat`, `.embed`, tool definitions, streaming | 2026-03 |
| ruby_llm-mcp | `/patvice/ruby_llm-mcp` | MCP integration | No Context7 entry | 2026-03 |
| ruby_llm-schema | `/danielfriis/ruby_llm-schema` | Structured outputs | Schema validation on LLM responses | 2026-03 |
| dspy.rb | `/vicentereig/dspy.rb` | LLM programming framework | Signatures, Predict, ChainOfThought, ReAct | 2026-03 |
| dspy-ruby_llm | — | DSPy ↔ RubyLLM adapter | use the dspy.rb context7 ID | 2026-03 |
| informers | `/ankane/informers` | Local transformer inference | Embedding and classification models | 2026-03 |
| ruby-spacy | `/yohasebe/ruby-spacy` | spaCy NLP via Ruby | Pipeline loading, entity extraction, parsing | 2026-03 |
| deepsearch-rb | `/alexshagov/deepsearch-rb` | Web research | No Context7 entry | 2026-03 |
| tomoto | `/ankane/tomoto` | Topic modeling | No Context7 entry | 2026-03 |
| hugging-face | `/fwdai/hugging-face` | HF API client | Remote inference, model routing | 2026-03 |
| lingua | `/dbalatero/lingua` | Language detection | N-gram based classification | 2026-03 |
| ruby-wordnet | `/ged/ruby-wordnet` | Lexical semantics | Synsets, hypernyms, semantic graph | 2026-03 |
| wordnet-defaultdb | `/wordnet/wordnet-defaultdb` | WordNet dataset | Required backing DB | 2026-03 |

**Additional Context7 docs for AI layer:**

* `/websites/rubyllm`
* `/websites/spacy_io`
* `/explosion/spacy-llm`
* `/huggingface/sentence-transformers`

---

## Document Ingestion

| Gem | Context7 ID | Role | Key Patterns | last_verified |
|---|---|---|---|---|
| kreuzberg | `/websites/kreuzberg_dev_reference` | Document extraction (PDF, DOCX, XLSX, images) | `extract_file_sync`, `extract_bytes_sync`, `batch_extract_bytes_sync`, `Config::Extraction`, `Config::Chunking`, `HierarchyConfig` | 2026-03 |

**kreuzberg key signatures:**
- `Kreuzberg.extract_file_sync(path, config: config)` → `result` with `.content`, `.mime_type`, `.metadata`, `.tables`, `.detected_languages`, `.pages`
- `Kreuzberg.extract_bytes_sync(data, mime_type, config)` → same result shape
- `Kreuzberg.batch_extract_bytes_sync(data_list, mime_types, config)` → `Array<Hash>`
- `Kreuzberg::Config::Extraction.new(chunking:, ocr:, pdf_options:, language_detection:, extract_tables:, extract_images:, use_cache:, output_format:)`
- `Kreuzberg::Config::Chunking.new(max_characters: N, overlap: N, respect_sentences: true, respect_paragraphs: false, chunker_type: 'text', prepend_heading_context: false)`
- `Kreuzberg::Config::Ocr.new(backend: 'tesseract'|'easyocr', language: 'eng')`
- `Kreuzberg::PdfConfig.new(hierarchy: Kreuzberg::HierarchyConfig.new(enabled: true), extract_images: false, passwords: [])` — `result.pages[n].hierarchy.blocks` → `block.level`, `block.text`
- Ruby-native PDF/DOCX/XLSX/image extraction — replaces Docling PyCall bridge

---

## Data Processing

| Gem | Context7 ID | Role | Key Patterns | last_verified |
|---|---|---|---|---|
| pragmatic_segmenter | `/diasks2/pragmatic_segmenter` | Sentence segmentation | Rule-based boundary detection | 2026-03 |
| front_matter_parser | `/waiting-for-dev/front_matter_parser` | YAML frontmatter extraction | No Context7 entry | 2026-03 |
| jsonl | — | JSON Lines parser | No Context7 entry | 2026-03 |
| yajl-ruby | `/brianmario/yajl-ruby` | Streaming JSON parser | Incremental parsing | 2026-03 |
| commonmarker | `/gjtorikian/commonmarker` | Markdown → AST | C-backed parser, deterministic output | 2026-03 |
| kramdown | `/gettalong/kramdown` | Markdown parser | Pure Ruby, extensible | 2026-03 |
| loofah | `/flavorjones/loofah` | HTML sanitization | XSS boundary enforcement | 2026-03 |
| mimemagic | `/mimemagicrb/mimemagic` | MIME detection | Content-type inference | 2026-03 |

---

## Retrieval, Similarity & Fuzzy Matching

| Gem | Context7 ID | Role | Key Patterns | last_verified |
|---|---|---|---|---|
| tf-idf-similarity | `/jpmckinney/tf-idf-similarity` | Vector space model | TF-IDF matrix + cosine similarity | 2026-03 |
| bm25f-ruby | `/catflip/bm25f-ruby` | Ranking function | BM25F scoring across fields | 2026-03 |
| fuzzy_tools | `/brianhempel/fuzzy_tools` | Approximate matching | Edit distance, token similarity | 2026-03 |

---

## Algorithms / Knowledge Structures

| Gem | Context7 ID | Role | Notes | last_verified |
|---|---|---|---|---|
| algorithms | `/kanwei/algorithms` | Data structures | No Context7 entry | 2026-03 |
| rubyfca | `/yohasebe/rubyfca` | Formal Concept Analysis | Lattice construction | 2026-03 |
| gemoji | `/github/gemoji` | Emoji lookup | No Context7 entry; CLI rendering only | 2026-03 |

---

## Validation & Types

| Gem | Context7 ID | Role | Key Patterns | last_verified |
|---|---|---|---|---|
| dry-schema | `/dry-rb/dry-schema` | Schema validation | `Dry::Schema.Params`, `.call`, `.errors` | 2026-03 |
| dry-types | `/dry-rb/dry-types` | Type system | `Types::Strict::*`, coercion | 2026-03 |

---

## Parsing / Encoding Boundaries

| Gem | Context7 ID | Role | Notes | last_verified |
|---|---|---|---|---|
| decode | `/socketry/decode` | Structured decoding | Binary/text decoding primitives | 2026-03 |

---

## Debugging & Introspection

| Gem | Context7 ID | Role | Notes | last_verified |
|---|---|---|---|---|
| pry | `/websites/rdoc_info_github_pry_pry_master` | REPL / introspection | Runtime object spelunking | 2026-03 |

---

## MCP Tooling

| Gem | Context7 ID | Role | Notes | last_verified |
|---|---|---|---|---|
| fast-mcp | `/yjacquin/fast-mcp` | Fast MCP server | Tool registration, server boot | 2026-03 |

---

## Project Archetypes → Required Gem Sets

Use these to determine which gems to resolve via Context7 for a given project type.

### Minimal CLI Tool

```shell

Runtime spine + drydock/highline + journald-logger

```

### Terminal AI App (basic chatbot)

```shell

Runtime spine + bubbletea + lipgloss + ruby_llm + circuit_breaker + async

```

### RAG Application

```shell

Runtime spine + bubbletea + ruby_llm + pgvector + sequel + pg

+ kreuzberg + pragmatic_segmenter + async + circuit_breaker

```

### SFL / Neuro-Symbolic NLP Pipeline

```shell

Runtime spine + kreuzberg + pragmatic_segmenter + ruby-spacy

+ ruby-wordnet + wordnet-defaultdb + informers

+ ruby_llm + ruby_llm-schema + sequel + sequel_pg + pgvector + pg

+ ohm + ohm-contrib + async + circuit_breaker

```

### Agent with Tool-Calling

```shell

Runtime spine + bubbletea + ruby_llm + ruby_llm-mcp + dspy.rb + dspy-ruby_llm

+ async + gush + circuit_breaker + redis + ohm

```

### File Processing / Export Tool (e.g. GDrive browser)

```shell

Runtime spine + bubbletea + lipgloss + huh + glamour + gum + async + faraday

```

### Full AI Orchestration Stack

```shell

All gems — use the full emergent architecture diagram from the dependency mapping doc

```
