# Ruby-NLP Gem Catalog

Curated from a broader gem inventory table — this catalog keeps only gems that do actual language processing (tokenization, parsing, lexical lookup, text similarity/ranking, topic modeling, transformer inference). Gems excluded from the source table as out-of-scope for NLP: `kamal` (deployment), `image_processing`/`ruby-vips` (image manipulation), `ruby-sox` (audio), `rdf`/`rdf-turtle` (semantic-web triples — knowledge-graph territory, see [genai/SKILL.md](~/.vibe/skills/genai/SKILL.md)'s neuro-symbolic pattern instead), `syntax_tree` (Ruby-*code* AST parsing, not natural language), `jsonlint`/`yajl-ruby` (generic JSON), `open4`/`shared_tools` (subprocess utilities), `front_matter_parser` (YAML front matter), `kreuzberg` (document intelligence/extraction — feeds an NLP pipeline but isn't itself language processing), `inkmark` (markdown conversion).

Every Context7 ID below MUST be verified inline before relying on it — several are marked unverified because the source inventory's own ID looked suspect (mismatched repo name) or was blank.

| Gem | Category | Repo | Context7 ID | Status | Description |
|---|---|---|---|---|---|
| `pragmatic_segmenter` | Tokenization & Segmentation | `diasks2/pragmatic_segmenter` | `/diasks2/pragmatic_segmenter` | ✅ Verified | Sentence segmentation tool that handles abbreviations, decimals, and quoted speech. |
| `scalpel` | Tokenization & Segmentation | — | `/ant-research/scalelsd` | 🔴 Suspect — ID looks mismatched (points to an unrelated repo name); verify before use | Alternative sentence segmentation tool for Ruby. |
| `pragmatic_tokenizer` | Tokenization & Segmentation | — | `/diasks2/pragmatic_segmenter` | 🔴 Suspect — same ID as `pragmatic_segmenter` in the source table, likely a copy-paste error; verify the tokenizer's actual ID | A multilingual tokenizer that splits a string into word-level tokens. |
| `tokenizers` | Tokenization & Segmentation | — | — | 🔴 To verify | Fast, state-of-the-art (subword/BPE-style) tokenizers for Ruby — the granularity transformer models actually consume. |
| `ruby-spacy` | Linguistic Structure | `yohasebe/ruby-spacy` | `/yohasebe/ruby-spacy` | ✅ Verified | Wrapper module for using spaCy (POS tagging, NER, dependency parsing) from Ruby via a Python bridge. |
| `linkparser` | Linguistic Structure | — | `/ged/linkparser` | ✅ Verified (per source table) | Ruby binding for the Abiword version of the Link Grammar Parser — dependency-style parsing without a Python bridge, but needs the Link Grammar C library installed. |
| `rsyntaxtree` | Linguistic Structure | — | `/websites/bobbylight_github_io_rsyntaxtextarea` | 🔴 Suspect — ID points to an unrelated "syntax text area" editor-component site, not a syntax-tree generator; verify before use | Syntax tree generator/visualizer for Ruby. |
| `lingua` | Linguistic Structure | — | `/dbalatero/lingua` | ✅ Verified (per source table) | Sentence splitting, syllable counting, and text-quality analysis. |
| `wordnet` | Lexical Resources | — | — | 🔴 To verify | Ruby interface to the WordNet® lexical database. |
| `rwordnet` | Lexical Resources | — | `/doches/rwordnet` | ✅ Verified (per source table) | Pure-Ruby interface to the WordNet database (alternative to the `wordnet` gem — pick one). |
| `wordnet-defaultdb` | Lexical Resources | — | — | 🔴 To verify | Container gem for the default WordNet SQL/SQLite database — required data dependency for `wordnet`/`rwordnet` lookups. |
| `amatch` | Similarity & Ranking | `flori/amatch` | `/flori/amatch` | ✅ Verified | Approximate/fuzzy string matching (Levenshtein and related edit-distance algorithms). |
| `tf-idf-similarity` | Similarity & Ranking | — | `/jpmckinney/tf-idf-similarity` | ✅ Verified (per source table) | Calculates similarity between texts using TF-IDF weighting. |
| `bm25f` | Similarity & Ranking | `catflip/bm25f-ruby` | `/catflip/bm25f-ruby` | ✅ Verified | Fast implementation of the BM25F ranking algorithm — multi-field relevance scoring, the same family as Postgres FTS's `ts_rank`. |
| `tomoto` | Topic Modeling | — | `/ankane/tomoto-ruby` | ✅ Verified (per source table) | High-performance topic modeling (LDA and related models) for Ruby. |
| `hugging-face` | Model Inference & Hub | `alchaplinsky/hugging-face` | `/alchaplinsky/hugging-face` | ✅ Verified | Ruby client for the Hugging Face Hub / Inference API — hosted, network-call-based inference. |
| `informers` | Model Inference & Hub | — | `/ankane/informers` | ✅ Verified (per source table) | Fast local transformer inference for Ruby via ONNX Runtime — no network call once the model is downloaded. |

## Notes on suspect Context7 IDs

Three IDs above are flagged suspect because they don't match the gem's own name/repo pattern the way the other rows do (`scalpel`, `rsyntaxtree`, `pragmatic_tokenizer`). This is exactly the failure mode the plugin's verification mandate exists to catch: an inventory table entry that looks plausible at a glance but resolves to the wrong library. Resolve these three via `mcp__plugin_context7_context7__resolve-library-id` (searching by gem name, not by trusting the table's ID) before writing any code against them.
