---
name: ruby-multi-db
description: Ruby multi-database model and pipeline patterns.
version: 0.1.0
author: Hermes
metadata:
  hermes:
    tags: [Ruby, Ohm, Sequel, Redis, PostgreSQL, pgvector, SFL, Annotation, ORM, Models, Two-Pass-Pipeline]
---

# Ruby Multi-DB

Layered reference for Ruby projects that store data in **more than one database** — typically Redis (Ohm, schemaless, fast) and PostgreSQL/pgvector (Sequel, durable, queryable, with embeddings). Two source corpora feed this skill:

- **`/home/b08x/Workspace/rubyfiles/RubyStuff/Misc/models/`** — a working sketch directory of generic Ohm and Sequel modeling idioms (Document, DocumentSegment, Section, Collection, Item, Audio, Image, Word, Sentence, Entity, Phrase, Page, PageElement).
- **`/home/b08x/WorkspaceV3/sfl-engine/`** — a production stance-filtered RAG engine that **instantiates** those idioms in its own storage and retrieval layer (`SFL::Store::PgClauseStore`, `SFL::Store::PgEmbeddingStore`, `SFL::Store::PgHybridRetriever`, `SFL::Store::ClauseFilters`) and adds the annotation-specific machinery (two-pass pipeline, classification registry, hybrid RRF) on top.

The skill is organized in three layers. **Layer 1** (generic patterns) is what to read when picking an ORM or writing a new model. **Layer 2** (sfl-engine's concrete usage) is what to read when working inside sfl-engine itself. **Layer 3** (pipeline-only) is sfl-engine-specific and has no equivalent in the Misc models.

Out of scope: the `Misc/file-search.rb` CLI, `Misc/dify_*.rb`, `Misc/rubygem_table.rb`, `Misc/tomotoler.rb`, `Misc/spacy_nlp.rb`, `Misc/fetch_datasets.rb`, and the sfl-engine HTTP API/Falcon server, docker-compose profile dance, Boot ENV composition, and GUI.

---

## Layer 1 — Generic Ohm and Sequel patterns (from `Misc/models/`)

### Side-by-side idiom table

| Concern | Ohm (`Misc/models/ohm/`) | Sequel (`Misc/models/sequel/`) |
|---|---|---|
| Schema declaration | `attribute :name` (no DDL) | `class X < Sequel::Model` (auto-infers from table) |
| Required field | MemexRAG-style: `assert_present :name` in `def validate; super; end` (`Misc/models/document.rb`). Canonical `ohm/` files omit `def validate` and rely on indexes. | `validates_presence :name` in `def validate; super; end` |
| Membership enum | MemexRAG-style: `assert_member :status, VALID_STATUSES` (`Misc/models/document.rb`) | `validates_includes :status, VALID_STATUSES` |
| Numeric field | MemexRAG-style: `assert_numeric :processing_order` (`Misc/models/document_segment.rb`) | (use `plugin :validation_helpers` + type column) |
| Single-column index | `index :status` | (DB-side; create via migration) |
| Unique constraint | `unique :content_hash` | `validates_unique :name` |
| Belongs-to | `reference :document, :Document` | `many_to_one :document` |
| Has-many | `collection :segments, :DocumentSegment` | `one_to_many :sections` |
| Sorted has-many | `list :words, :Word` | (default `one_to_many` is order-by-PK; add `:order` to override) |
| Unordered set | `set :documents, :Document` | (use `one_to_many` with `class: :Item do \|ds\| ... end`) |
| Typed attribute | `attribute :metadata, Type::Hash` | (column-level `jsonb` or string) |
| JSON-as-string field | `JSON.parse(attr) rescue {}` getter + `attr = hash.to_json` setter | (use `pg_jsonb` column type) |
| Timestamps | `include Ohm::Timestamps` | `plugin :timestamps` |
| Embedding column | (store as `attribute :embedding, Type::Array` of floats) | `plugin :pgvector, :embedding` then `nearest_neighbors(:embedding, vec, distance: "cosine")` |
| Upsert / dedup | `rescue Ohm::UniqueIndexViolation; find(content_hash: ...).first` | `plugin :insert_conflict` (then `insert_conflict(target: :content_hash)`) |
| Normalization callback | `def before_save; self.text = text.downcase.strip if text; end` | `def before_create; self.created_at ||= Time.now; super; end` |
| STI / polymorphism | One base `Ohm::Model` + subclasses with `content_type` discriminator set in `initialize` (`ohm/page.rb`) | (no native STI; use Sequel's `plugin :single_table_inheritance` if needed) |

### Picking between Ohm and Sequel

- **Redis is the source of truth** (state machine, ephemeral, fast writes): use Ohm. Examples: `Document` (status machine, retry count, processing events), `DocumentSegment` (hierarchy, content_type), `Collection` (unordered set of Items).
- **Postgres + pgvector is the source of truth** (durable, queryable, embeddings): use Sequel. Examples: `DocumentRecord` (pgvector `:embedding`), `Section` (pgvector + `many_to_one :document`), `Item` (durable file paths).
- **Both**: MemexRAG keeps state in Ohm (Document status machine) and embeddings in Sequel (DocumentRecord with pgvector). They are joined by `document_id` / `external_id`, not by an ORM relation.

### Porting between ORMs

- **Ohm → Sequel**: attributes become columns, `attribute :text, Type::String` → `text TEXT`. `unique :name` → migration-side `unique_index` + `validates_unique :name`. `reference :parent, :ParentClass` → `many_to_one :parent`. `collection :children, :ChildClass` → `one_to_many :children`. `Type::Hash` → `jsonb` column. JSON-as-string fields → `jsonb` (drop the `JSON.parse` getter). Embeddings: `Type::Array` of floats → pgvector column + `plugin :pgvector`.
- **Sequel → Ohm**: inverse of the above. `validates_presence :name` → `assert_present :name`. `validates_includes` → `assert_member`. Unique index → `unique :name`. Embeddings become `Type::Array` of floats (lossy vs. pgvector indexing — keep Sequel if you actually query them by similarity).

---

## Layer 2 — SFL Engine's concrete instantiation of these patterns

SFL Engine is a stance-filtered RAG system. It uses **only Sequel + Postgres + pgvector** for persistence (no Ohm / Redis in the production path — the `dot-` Redis service in `docker-compose.yml` is provisioned for the dev environment but no `SFL::Store::*` adapter speaks to it). The Layer 1 "pick both ORMs" guidance still applies, but in sfl-engine the dual-database pattern resolves to **three Postgres tables** (one for the structural row, one for ideational payload, one for interpersonal payload) sharing a foreign key.

The pipeline's load-bearing invariant is **payload separation**: an `SFL::Core::Types::AnnotatedClause` carries three independently-stored payloads — `syntactic` (Pass 1) + `ideational` (Pass 1 post-processing) on one side, `interpersonal` + `textual` (Pass 2 LLM) on the other — and the schema FKs them together but stores them in three tables (`clauses` + `ideational_payloads` + `interpersonal_payloads`) so retrieval can filter one without reading the other.

### Storage shape (sfl-engine-specific)

- **Three tables, three FK-cascading writes per `SFL::Store::PgClauseStore#replace_document`:**
  - `clauses` (`external_id` ← `AnnotatedClause#id`; `tokens` and `groups` are `pg_jsonb`)
  - `ideational_payloads` (`clause_id` ← `AnnotatedClause#id`; `ON DELETE CASCADE` from `clauses`)
  - `interpersonal_payloads` (`clause_id` ← `AnnotatedClause#id`; `ON DELETE CASCADE` from `clauses`)
- `replace_document` is the **only** write path for clauses. It owns its own `db.transaction { delete; multi_insert }` so re-running a compile never leaves stale rows behind (F7 idempotency). Do not delete from these tables manually — the FK cascade does it.
- `SFL::Store::PgEmbeddingStore#replace_document` writes to the `embeddings` pgvector table and flips `clauses.embedding_status` to `"embedded"` on success or `"failed"` (with an `embedding_error` note) on a nil/empty vector (F11 contract). One failed clause doesn't abort the rest of the document.
- `SFL::Store::PgClauseStore#update_interpersonal` is the single-clause re-annotation write path. HITL review decisions that flip a clause's interpersonal values call this — it never touches `clauses` or `ideational_payloads`, so syntactic structure and Pass-1 payloads survive untouched.
- `AnnotatedClause#id` is the only uuid that round-trips. `SyntacticClause#id`, `IdeationalPayload#clause_id`, and `InterpersonalPayload#clause_id` are distinct upstream but collapsed to the outer `id` on storage — pre-existing lossy round trip, documented in `PgClauseStore#find_by_document`.

### Scalar filters (sfl-engine-specific)

- Filters live in `SFL::Store::ClauseFilters::FIND_ALL_FILTERS` as **table-qualified lambdas** (e.g. `Sequel[:interpersonal_payloads][:mood] => v`) so they compose safely on a multi-joined scope. `SFL::Store::PgHybridRetriever` calls `ClauseFilters.apply` on both the semantic (pgvector) arm and the keyword (Postgres FTS) arm **before** `.order`/`.limit`. Legacy ran both arms unfiltered and filtered the merged set, so a selective filter could starve the result to fewer than `limit` rows (F8 fix). Don't reorder this.
- `SFL::Store::PgHybridRetriever::RRF_K = 60` (standard) and `CANDIDATE_MULTIPLIER = 3` control the in-memory RRF merge. RRF stays in Ruby over at most `2 * (limit * 3)` rows; don't push it into SQL.
- The `SFL::Core::Types::RetrievalFilters` struct (`:mood`, `:min_modality`, `:max_modality`, `:min_tenor`, `:max_tenor`, `:process_type`, `:source_type`) is the public type passed in from `SFL::CLI` `--mood` / `--min-tenor` / etc. flags through `SFL::Retrieval::ContextSynthesizer#synthesize`.

### Trust contract (sfl-engine-specific)

- `SFL::Core::Types::TRUSTED_ANNOTATION_SOURCES = %w[llm human].freeze` is the single source of truth for "this annotation can ground an answer." `fallback`, `stub`, and `chunk_artifact` are excluded by design. The closed `AnnotationSource` enum (`String.default("llm").enum("llm", "fallback", "stub", "chunk_artifact", "human")`) is updated in lockstep with this list. Don't add a new `annotation_source` value without updating both.

---

## Layer 3 — Pipeline-only patterns (sfl-engine, no Misc equivalent)

### Two-pass composition

`SFL::Core::Pipeline#compile` is a `Dry::Monads[:result]` bind ladder: `parse → pair_with_ideational → annotate → persist → embed`. A Pass-1 `SidecarError` short-circuits to `Failure([:pass_one_failed, message])` — ideational extraction, Pass 2, storage, and embedding never run for that document. Don't insert guard clauses inside individual stages; the bind chain is the guard.

### Pass 1 = spaCy subprocess sidecar

`SFL::Core::PassOne::SpacySidecarParser` shells out to `sidecar/spacy_sidecar.py` over NDJSON on stdin/stdout. Key invariants: `pgroup: true` so SIGINT to the Ruby process group doesn't kill the sidecar mid-turn; restart-and-retry is exactly once on `Errno::EPIPE` / `IOError` / `SidecarError`; the head-index lookup is positional (`token.head.i - sent.start`, sentence-local), not text-keyed, so repeated-word sentences cannot mis-resolve dependents (F1/D1 — the bug class is structurally impossible here). The legacy `GC.start` PyCall workaround is gone.

### Pass 2 contract rejection

`SFL::Core::Types::ModalityWeight` and `TenorValue` are `Coercible::Float.constrained(gteq: 0.0, lteq: 1.0)` — out-of-range scalars raise `Dry::Struct::Error` in `SFL::LLM::Engine#interpersonal_from` and degrade the whole clause to defaults (`annotation_source: "fallback"`). The F6/D9 fix is "contract-reject, never silently rescale" — a 0.7 from a real 1.7 is a lie downstream quality scoring would trust. `Coercible` (not strict `Float`) so LLM boundary values `0` / `1` arriving as JSON integers pass.

### Classification registry fuzzy match

`SFL::Core::ClassificationRegistry::FUZZY_THRESHOLD = 0.92` and `FUZZY_MIN_LENGTH = 4` are calibrated against live Pass-2 output: every observed real near-miss scores ≥ 0.9378 against its intended target, the best garbage term tops out at 0.809. Lowering the threshold silently rewrites a value; a miss just falls through to the (warned) default. `.normalize` returns `[value, status]` where status is `:exact` (silent), `:aliased` (silent), `:fuzzy` (WARN: surface so a permanent alias can be added), or `:unknown` (WARN + "consider adding it to ClassificationRegistry"). The alias table grows from observed real output; don't suppress these WARNs.

### `--pass1-only` is the single Pass-2 stub gate

Lives in `SFL::Core::Pipeline#annotate` (`return Success(stub_annotate_all(pairs)) if pass_one_only`), wired once for every caller. Every stubbed clause has `annotation_source: "stub"`. The alternate path is to inject `SFL::Core::Ports::Null::Annotator` directly; both routes go through `Ports::Null::Annotator#annotate_batch`, so there is one source of truth for "what does a stub look like."

### pgvector dimension lockstep

`SFL::Store::PgEmbeddingStore::VECTOR_DIMENSIONS = 768` is hardcoded against `db/migrations/004_create_embeddings.rb`. A `mistral-embed` (1024-dim) config against an embeddinggemma-provisioned DB raises `SFL::Store::Error` with a message that names the actual cause. If you change the embedding model column width, change `VECTOR_DIMENSIONS` in lockstep.

### Pass 2 batch annotator is a distinct method, not a loop

`SFL::Core::Ports::Annotator#annotate_batch(pairs, context:)` has its own method (not `#annotate` called N times) because `SFL::LLM::Annotators::BatchClauseAnnotator`'s schema is a genuinely different call shape and cost profile. `SFL::LLM::Engine#annotate_batch` indexes responses by `:index` to match them back to pairs — order is preserved.

### Pass 2 cache key

`SFL::Core::Ports::FileCache` keys on `SHA256("#{document_id}#{clause.sentence_index}#{clause.text}")`. `sentence_index` disambiguates clauses with identical text recurring at different positions in the same document (e.g. repeated boilerplate headers).

---

## Procedure

### Decide which Layer to apply

1. **Working in `Misc/models/` or porting an Ohm/Sequel model between them**: Layer 1 only.
2. **Working in `sfl-engine/lib/sfl/store/` or `lib/sfl/llm/`**: Layer 2 (storage shape + scalar filters + trust contract) and Layer 3 (pass 2 / pipeline).
3. **Working in `sfl-engine/lib/sfl/core/pass_one/`, `lib/sfl/core/classification_registry.rb`, or `lib/sfl/retrieval/`**: Layer 3 only.
4. **Working in `sfl-engine/lib/sfl/cli.rb`, `config.ru`, `docker/`, or `bin/setup-*`**: this skill is not the right reference — the **sfl-engine** skill (deleted; now absorbed here) had CLI/API/Docker details; reach for `sfl-engine` or the sfl-engine `AGENTS.md` directly.

### Add a new Ohm model (Layer 1)

1. Place `lib/models/ohm/<name>.rb`. Include `Ohm::DataTypes` and `Ohm::Callbacks` (`Ohm::Timestamps` if you want `created_at` / `updated_at`).
2. Declare attributes: `attribute :name`, `attribute :metadata, Type::Hash`, etc. Use `Type::Integer` / `Type::Array` / `Type::Hash` for typed slots — see `Misc/models/ohm/word.rb` and `ohm/page.rb`.
3. Declare indexes: `index :status`, `index :content_hash`. Use `unique :content_hash` when dedup is required.
4. Declare relations: `reference :parent, :ParentClass` (many-to-one), `collection :children, :ChildClass` (has-many), `list :words, :Word` (ordered), `set :tags, :Tag` (unordered unique).
5. Implement `def validate; super; <assert_*>; end` following `Misc/models/document.rb:70` and `document_segment.rb:63`. `assert_present` covers `nil` but **not** empty-string — pair with `name && !name.empty?` checks if needed.
6. Implement `def before_save` for normalization (`text.downcase.strip`, `label.upcase`) — see `Misc/models/ohm/word.rb:28` and `entity.rb:27`.
7. JSON-as-string metadata: getter `JSON.parse(attr) rescue {}`, setter `attr = hash.to_json`. Pattern is identical in `Misc/models/ohm/document.rb:156` and `document_segment.rb:115`.
8. `find_or_create` factories live as class methods on the model (see `Misc/models/ohm/collection.rb:28`). Apply the same normalization in `before_save` to keep the index consistent.
9. `require_relative` the new model from the central loader (`Misc/models/ohm.rb`).

### Add a new Sequel model (Layer 1) or sfl-engine `SFL::Store::*` adapter (Layer 2)

1. **Layer 1** (generic Sequel model): `lib/models/sequel/<name>.rb`. Inherit `Sequel::Model` (auto-infers `<name>s` table) or `Sequel::Model(SomeDB[:table_name])` for explicit-dataset binding (see `Misc/models/sequel/document_record.rb` and `audio.rb`).
2. **Layer 2** (sfl-engine `SFL::Store::*`): `lib/sfl/store/pg_<name>.rb`, include the matching `SFL::Core::Ports::*` mixin (`Ports::ClauseStore`, `Ports::EmbeddingStore`, `Ports::Retriever`). Inject `db:` and any required collaborators via `initialize`. Do not call `ENV[]` directly — `SFL::Boot` is the sole ENV reader.
3. `plugin :validation_helpers`, `plugin :insert_conflict` (generic). For sfl-engine, plugins already on `Sequel::Model` via `db/migrations` and the app's `SFL::Boot` composition.
4. If the model carries an embedding, add `plugin :pgvector, :embedding` — the `:embedding` symbol names the pgvector column. **sfl-engine's `SFL::Store::PgEmbeddingStore` does not use this plugin directly; it uses `Pgvector.encode(vector)` for writes and a raw `embedding <=> ?` SQL fragment for reads** (`pg_hybrid_retriever.rb:67`). Don't add `plugin :pgvector, :embedding` to sfl-engine's store — it would conflict with the existing raw-SQL approach.
5. Declare relations: `one_to_many :sections`, `many_to_one :document`. Filter with a block: `one_to_many :text_files, class: :Item do |ds| ds.filter(type: 'text'); end` (`Misc/models/sequel/collection.rb:12`).
6. Implement `def validate; super; validates_presence :name; validates_unique :name; end`. Add `validates_includes :status, VALID_STATUSES` for enum membership.
7. For embeddings: use the `pgvector` plugin's `nearest_neighbors(:embedding, vec, distance: "cosine")` (Layer 1 — `Misc/models/sequel/document_record.rb` and `section.rb` document the shape in commented examples) — or, in sfl-engine, the raw SQL fragment in `SFL::Store::PgHybridRetriever#semantic_search`.
8. `validates_unique` requires a unique index on the column (migration-side). Add `def before_create; self.created_at ||= Time.now; super; end` for app-side defaults — see `Misc/models/sequel/item.rb:9`.

### Add a new retrieval filter (Layer 2 only)

1. Add the filter to `SFL::Core::Types::RetrievalFilters`.
2. Add a lambda to `SFL::Store::ClauseFilters::FIND_ALL_FILTERS`, **table-qualified** (e.g. `Sequel[:interpersonal_payloads][:mood] => v`) so it composes safely on a multi-joined scope. Both the semantic and keyword arms of `SFL::Store::PgHybridRetriever` call `ClauseFilters.apply` against their own joined scope — never inline a `.where` in the retriever.
3. CLI flag it in `SFL::CLI.parse_context_options` (`lib/sfl/cli.rb`); the flag value flows into `options[:filters]` and through to `SFL::Retrieval::ContextSynthesizer#synthesize`.

### Change the storage shape (Layer 2 only)

- `replace_document` is the only write path. It owns its own `db.transaction { delete; multi_insert }` so re-running a compile never leaves stale rows behind (F7). Do not delete from these tables manually — the FK cascade does it.
- `embedding_status` on `clauses` is the truth for "did this clause get a usable vector?" — `PgEmbeddingStore` flips it to `"embedded"` on success or `"failed"` on a nil/empty vector (F11 contract). One failed clause doesn't abort the rest of the document.
- `AnnotatedClause#id` is the only uuid that round-trips. `SyntacticClause#id`, `IdeationalPayload#clause_id`, and `InterpersonalPayload#clause_id` are distinct upstream but collapsed to the outer `id` on storage.

### Run a one-off sfl-engine analysis (Layer 3)

1. Confirm services are up: `docker compose ps` shows `postgres` healthy on `127.0.0.1:5433` (sfl-engine uses non-default host port 5433 to avoid the system Postgres on 5432). Run `bin/setup-python` if `.sfl-python/interpreter_path` doesn't exist. Run `rake db:migrate` if migrations are pending (`SFL::Boot` never migrates).
2. Use `--pass1-only` first to validate Pass 1 alone (no LLM cost, no API key). Output goes to `./output/latest/` by default.
3. Re-run without `--pass1-only` to add Pass 2. If you see `fallback` clauses in the report, those are real Pass-2 degradations (`annotation_source: "fallback"`) — `TRUSTED_ANNOTATION_SOURCES` (`llm`, `human`) excludes them from quality scoring and citation by design.
4. Add `--store` to persist. `bundle exec exe/sfl-analyze context "..." --min-tenor 0.6` then exercises retrieval against what you just stored.
5. Use `--resume` for repeat runs against the same document — it SHA256-caches Pass 2 results per `(document_id, sentence_index, text)` via `SFL::Core::Ports::FileCache`. Cache hits and misses are logged at INFO.

```bash
bundle exec exe/sfl-analyze documentation spec/fixtures/golden_master/README.md        # Pass 1 + Pass 2, no store
bundle exec exe/sfl-analyze documentation ./README.md --pass1-only                       # no LLM cost
bundle exec exe/sfl-analyze documentation ./README.md --store                            # + store + embed
bundle exec exe/sfl-analyze context "what does SFL stand for" --limit 5                  # hybrid RRF
```

---

## Pitfalls

### Layer 1 (Misc models)

- **There are stale `_`-suffixed files in `Misc/models/ohm/`** (`page.rb_`, `word.rb_`, `sentence.rb_`, `paragraph.rb_`, `phrase.rb_`, `topic.rb`). They are pre-rename versions and do **not** match the canonical files. Read the unsuffixed version; the `_` ones are historical snapshots from a rename that never got cleaned up.
- **MemexRAG has two parallel model hierarchies** (per `Misc/AGENTS.md`): the canonical ones in `Misc/models/ohm/` and the legacy single-file roots in `Misc/models/ohm.rb` (Topic/Paragraph/Sentence/Phrase/Word/Entity). They are not interchangeable. `ohm.rb` re-`require`s a subset of models for the legacy entry points — prefer the `ohm/` directory for new code.
- **`assert_present` does not catch empty-string.** `Ohm::Model#assert_present(:name)` only checks `nil`. If you want to reject `""`, validate explicitly (`assert name && !name.empty?` or `assert_present :name, minimum: 1`).
- **`Ohm::UniqueIndexViolation` is the canonical "already exists" signal**, not a real error. Catch it and return the existing record (see `Misc/models/ohm/document.rb:102`). Always pair `unique :content_hash` with this rescue pattern or you double-create.
- **`unique :name` declares the unique index**, but you still need to `index :name` separately if you also want a non-unique index for plain lookups. `Misc/models/ohm/topic.rb` uses both: `unique :name` + `index :name`.
- **Sequel's `validates_unique` requires a unique index** (migration-side). Adding `validates_unique :name` to a model whose `:name` column has no DB-side unique constraint will pass validation but allow duplicates — a race-condition trap. Create the index in a migration first.
- **`plugin :pgvector, :embedding` requires a column literally named `:embedding`.** Renaming the column to `:vector` (or `:embedding_vector`) will make the plugin silently no-op or raise. Either keep the column named `:embedding` or pass the correct symbol to the plugin.
- **Filtered `one_to_many` blocks must be re-applied on every association access.** `Misc/models/sequel/collection.rb:12` defines `one_to_many :text_files, class: :Item do |ds| ds.filter(type: 'text'); end`. Sequel calls the block at access time, so `Collection#text_files` always returns the filtered set. Don't re-filter downstream.
- **`Audio < Sequel::Model(PGConnect.instance.db[:audio_files])` is the only model in the Misc directory using explicit-dataset binding.** The rest inherit `Sequel::Model` and rely on Sequel's auto-inference. If your table name doesn't pluralize correctly (or you have a legacy schema), use the explicit-dataset form, not a `set_dataset` override on the model class.
- **STI-lite in `Misc/models/ohm/page.rb` works because `PageElement` is a real `Ohm::Model` class**, not an abstract Ruby module. The subclasses (`Image` / `Table` / `Link`) call `super` in `initialize` and set `content_type`. Querying `Page.find(content_type: 'image')` does **not** return `Image` instances — it returns `PageElement` instances filtered by content_type. Use Sequel's `plugin :single_table_inheritance` for real STI.
- **`metadata` getter returns `{}` on `JSON::ParserError`**, not raising (see `Misc/models/ohm/document.rb:158` and `document_segment.rb:118`). Don't assume a malformed JSON-string metadata column raises; silently returning `{}` is the established contract.
- **`before_save` runs before `before_create`** and both run on every save in Ohm. If a callback should only fire on insert, check `self.new?` first. `Misc/models/ohm/word.rb` and `entity.rb` use `before_save` for normalization that should arguably run on every write — they're consistent, but they normalize on update too, which can re-strip a value the user just set.

### Layer 2 (sfl-engine storage)

- **The trusted-source list is `["llm", "human"]` only.** `SFL::Core::Types::TRUSTED_ANNOTATION_SOURCES` is the single source of truth for "this annotation can ground an answer." `fallback`, `stub`, and `chunk_artifact` are excluded by design. Don't add a new `annotation_source` value without updating both this list and `AnnotationSource` (which is the closed `enum`).
- **`PgEmbeddingStore::VECTOR_DIMENSIONS = 768` is hardcoded against `db/migrations/004_create_embeddings.rb`.** A `mistral-embed` (1024-dim) config against an embeddinggemma-provisioned DB raises `SFL::Store::Error` with a message that names the actual cause. If you change the embedding model column width, change `VECTOR_DIMENSIONS` in lockstep.
- **Retrieval filters push into both SQL arms BEFORE `.order`/`.limit` (F8).** `PgHybridRetriever` runs `ClauseFilters.apply(scope, filters)` on both the pgvector arm (`semantic_search`) and the Postgres FTS arm (`keyword_search`) before ranking. Don't reorder this.
- **RRF merge stays in Ruby.** `PgHybridRetriever#reciprocal_rank_fusion` does an in-memory merge over at most `2 * (limit * 3)` rows (`CANDIDATE_MULTIPLIER = 3`). Don't push RRF into SQL.
- **`PgClauseStore#update_interpersonal` is the single-clause re-annotation write path.** HITL review decisions that flip a clause's interpersonal values call this — it never touches `clauses` or `ideational_payloads`. Anything that wants to rewrite a full clause must go through `replace_document`.
- **Don't add `plugin :pgvector, :embedding` to sfl-engine's `PgEmbeddingStore`**. The store uses `Pgvector.encode(vector)` for writes and a raw `embedding <=> ?` SQL fragment for reads (`pg_hybrid_retriever.rb:67`). Adding the plugin would conflict with the existing raw-SQL approach.

### Layer 3 (sfl-engine pipeline)

- **Pass 2 contract-rejects out-of-range scalars, it does not rescale them.** An LLM returning `1.7` raises `Dry::Struct::Error` in `SFL::LLM::Engine#interpersonal_from`, which logs a WARN and degrades the whole clause to defaults (`annotation_source: "fallback"`). This is the F6/D9 fix — never silently clamp the value.
- **`Types::Coercible::Float` is intentional, not a typo.** LLM JSON output for boundary values (`0`, `1`) often arrives as bare integers; a strict `Float` rejects those (live-verified failure mode 2026-08-02, same class as `Premise#type`). Coercible means `0` and `1` pass; `"not a number"` and `1.7` don't.
- **A malformed reasoning trace never blanks the clause.** `SFL::LLM::Engine#safe_reasoning_trace_from` rescues `Dry::Struct::Error` around the trace-only step and leaves `reasoning_trace: nil` while keeping the real mood/tenor/modality from the LLM. The mood value was correct; only its provenance is at risk.
- **Fuzzy-match threshold is `0.92`, calibrated — don't lower it.** See `SFL::Core::ClassificationRegistry` header comment for the calibration reasoning.
- **Fuzzy vs unknown vs aliased vs exact — three different WARNs.** Don't suppress; the alias table grows from observed real output.
- **`--pass1-only` is the single switch that stubs Pass 2 — there is no other.** The gate lives in `SFL::Core::Pipeline#annotate`. Injecting `SFL::Core::Ports::Null::Annotator` directly is the alternate path; both routes go through `Ports::Null::Annotator#annotate_batch`.
- **Pass 1 is a subprocess sidecar, not in-process Python.** `pgroup: true` isolates it from SIGINT. If you swap to `docker run … sfl-spacy-sidecar`, the parser doesn't care — any subprocess with the same NDJSON protocol works (`command:` kwarg).
- **Sidecar restart-and-retry is exactly once.** A second transport failure surfaces as `SidecarError` — never loops, never hangs.
- **Pipeline `bind` ladder short-circuits on Pass-1 failure.** `Core::Pipeline#compile` is `parse → pair_with_ideational → annotate → persist → embed` via `Dry::Monads[:result]`. A Pass-1 `SidecarError` short-circuits to `Failure([:pass_one_failed, message])` — ideational extraction, Pass 2, storage, and embedding never run. Don't insert guard clauses inside individual stages; the bind chain is the guard.
- **Pass 2 batch annotator is a distinct method, not a loop.** `Ports::Annotator#annotate_batch(pairs, context:)` has its own method because `SFL::LLM::Annotators::BatchClauseAnnotator`'s schema is a genuinely different call shape and cost profile. `SFL::LLM::Engine#annotate_batch` indexes responses by `:index` to match them back to pairs — order is preserved.
- **`SFL::LLM::Engine#annotate` rescues everything into a default.** Every call ends in `default_result(clause, …)` with `annotation_source: "fallback"` on failure. `SFL::LLM::Degradation.default_interpersonal` / `default_textual` are the single source of truth for "what does a default look like" — `annotation_source` is always `"fallback"`, never `"llm"`. A default that claims to be real model output is a lie a downstream quality score or citation would trust.
- **Zeitwerk inflections matter in sfl-engine.** `TRUSTED_ANNOTATION_SOURCES` is a frozen `Array` constant, not a class — `lib/sfl.rb:18` maps `trusted_annotation_sources → TRUSTED_ANNOTATION_SOURCES`. `kb_*` formatters use `KB*`. `glimmer-dsl-libui` (`lib/sfl/gui`) is `loader.ignore`-ed (opt-in require). New files with non-default camelization need an inflection entry.
- **No bare `bundle exec sfl-analyze` / `sfl-api` / `sfl-review`** — sfl-engine is a non-gem app (no gemspec, no `executables` list → no Bundler binstub). Use `bundle exec exe/<name>`.
- **`SFL::Boot` is the sole ENV reader.** Everything else takes config via constructor injection. Don't sprinkle `ENV[...]` reads in domain classes.
- **Host port `5433` (Postgres) and `6380` (Redis) in sfl-engine**, not the canonical `5432`/`6379`. The dev environment remaps to avoid fighting system services. Update `DATABASE_URL` and host-side tooling accordingly.
- **No auto-migration.** `SFL::Boot.call` deliberately never runs migrations. `rake db:migrate` is mandatory on a fresh DB; otherwise the API/CLI fails loudly post-Boot.
- **`experiments/` is quarantined.** `lib/sfl/experiments/` is never autoloaded, never shipped. Don't `require` from it.

---

## Verification

```bash
# Layer 1 — Misc models: directory structure + idiom presence
ls /home/b08x/Workspace/rubyfiles/RubyStuff/Misc/models/ohm/*.rb | grep -v '_' | wc -l
ls /home/b08x/Workspace/rubyfiles/RubyStuff/Misc/models/sequel/*.rb | wc -l
grep -l "^  attribute :" /home/b08x/Workspace/rubyfiles/RubyStuff/Misc/models/ohm/*.rb | grep -v '_'
grep -lE "^  (reference|collection|list|set) :" /home/b08x/Workspace/rubyfiles/RubyStuff/Misc/models/ohm/*.rb | grep -v '_'
grep -lE "validates_(presence|unique|includes)" /home/b08x/Workspace/rubyfiles/RubyStuff/Misc/models/sequel/*.rb
grep -l "plugin :pgvector" /home/b08x/Workspace/rubyfiles/RubyStuff/Misc/models/sequel/*.rb
grep -l "assert_present\|assert_member\|assert_numeric" /home/b08x/Workspace/rubyfiles/RubyStuff/Misc/models/document*.rb

# Layer 2 + 3 — sfl-engine: pipeline + storage + retrieval
cd /home/b08x/WorkspaceV3/sfl-engine
docker compose up -d                                          # postgres on 127.0.0.1:5433
bin/setup-python                                              # if not vendored yet
rake db:migrate
bundle exec exe/sfl-analyze documentation spec/fixtures/golden_master/README.md
bundle exec exe/sfl-analyze documentation spec/fixtures/golden_master/README.md --pass1-only
bundle exec exe/sfl-analyze documentation spec/fixtures/golden_master/README.md --store
bundle exec exe/sfl-analyze context "what does SFL stand for" --limit 5
bundle exec rake                                              # full spec + rubocop
```

A clean `bundle exec rake` exit (`N+ examples, 0 failures`; RuboCop clean) proves Layer 2 + 3 end-to-end: loaders emit `SFL::Core::Types::Unit`s → `SFL::Analysis::Engine` drives `SFL::Core::Pipeline` → Pass 1 sidecar returns `SyntacticClause`s → `IdeationalExtractor` produces `IdeationalPayload`s → Pass 2 LLM annotator returns `Interpersonal + Textual` payloads → `ClassificationRegistry` normalizes mood/theme_type → `Core::Pipeline` binds the `AnnotatedClause` → `PgClauseStore` / `PgEmbeddingStore` persist three-table + pgvector → `PgHybridRetriever` returns scalar-filtered RRF results. The Layer 1 `ls`/`grep` greps confirm the Misc directory is structurally what Layer 1 describes (an empty `assert_*` result inside `Misc/models/ohm/` is expected — those models are declarative-only).