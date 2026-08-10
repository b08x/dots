# sfl-engine Case Study — Dual-Database Storage & Retrieval

`sfl-engine` (`/home/b08x/WorkspaceV3/sfl-engine`) is a stance-filtered RAG engine and the concrete, load-bearing instantiation of the [orm-idiom-patterns](orm-idiom-patterns.md) picking guidance. It uses **only Sequel + Postgres + pgvector** for persistence (no Ohm/Redis in the production path — the `dot-` Redis service in `docker-compose.yml` is provisioned for dev only; no `SFL::Store::*` adapter speaks to it). The "pick Redis vs. Postgres" decision from the idiom patterns resolves here to **three Postgres tables** (structural row, ideational payload, interpersonal payload) sharing a foreign key — the dual-store pattern applied within a single database instead of across two.

This reference is written for direct use inside `sfl-engine` — class names, file paths, and invariant labels (F1, F6-F9, F11, D9) are real and load-bearing, not illustrative.

## The load-bearing invariant: payload separation

An `SFL::Core::Types::AnnotatedClause` carries three independently-stored payloads — `syntactic` (Pass 1) + `ideational` (Pass 1 post-processing) on one side, `interpersonal` + `textual` (Pass 2 LLM) on the other — and the schema FKs them together but stores them in three tables (`clauses` + `ideational_payloads` + `interpersonal_payloads`) so retrieval can filter one without reading the other.

## Storage shape

- **Three tables, three FK-cascading writes per `SFL::Store::PgClauseStore#replace_document`:**
  - `clauses` (`external_id` ← `AnnotatedClause#id`; `tokens` and `groups` are `pg_jsonb`)
  - `ideational_payloads` (`clause_id` ← `AnnotatedClause#id`; `ON DELETE CASCADE` from `clauses`)
  - `interpersonal_payloads` (`clause_id` ← `AnnotatedClause#id`; `ON DELETE CASCADE` from `clauses`)
- `replace_document` is the **only** write path for clauses. It owns its own `db.transaction { delete; multi_insert }` so re-running a compile never leaves stale rows behind (F7 idempotency). Do not delete from these tables manually — the FK cascade does it.
- `SFL::Store::PgEmbeddingStore#replace_document` writes to the `embeddings` pgvector table and flips `clauses.embedding_status` to `"embedded"` on success or `"failed"` (with an `embedding_error` note) on a nil/empty vector (F11 contract). One failed clause doesn't abort the rest of the document.
- `SFL::Store::PgClauseStore#update_interpersonal` is the single-clause re-annotation write path. HITL review decisions that flip a clause's interpersonal values call this — it never touches `clauses` or `ideational_payloads`, so syntactic structure and Pass-1 payloads survive untouched. Anything that wants to rewrite a full clause must go through `replace_document`.
- `AnnotatedClause#id` is the only uuid that round-trips. `SyntacticClause#id`, `IdeationalPayload#clause_id`, and `InterpersonalPayload#clause_id` are distinct upstream but collapsed to the outer `id` on storage — a pre-existing, documented lossy round trip (see `PgClauseStore#find_by_document`).

## Scalar filters and hybrid retrieval

- Filters live in `SFL::Store::ClauseFilters::FIND_ALL_FILTERS` as **table-qualified lambdas** (e.g. `Sequel[:interpersonal_payloads][:mood] => v`) so they compose safely on a multi-joined scope.
- `SFL::Store::PgHybridRetriever` calls `ClauseFilters.apply` on **both** the semantic (pgvector) arm and the keyword (Postgres FTS) arm **before** `.order`/`.limit`. Applying the filter only after merging the two arms starves the result to fewer than `limit` rows when the filter is selective (F8 fix). Don't reorder this — never inline a `.where` in the retriever outside `ClauseFilters.apply`.
- `SFL::Store::PgHybridRetriever::RRF_K = 60` (standard) and `CANDIDATE_MULTIPLIER = 3` control the in-memory RRF merge. RRF stays in Ruby over at most `2 * (limit * 3)` rows; don't push it into SQL.
- The `SFL::Core::Types::RetrievalFilters` struct (`:mood`, `:min_modality`, `:max_modality`, `:min_tenor`, `:max_tenor`, `:process_type`, `:source_type`) is the public type passed in from `SFL::CLI` `--mood` / `--min-tenor` / etc. flags through `SFL::Retrieval::ContextSynthesizer#synthesize`.

## Trust contract

`SFL::Core::Types::TRUSTED_ANNOTATION_SOURCES = %w[llm human].freeze` is the single source of truth for "this annotation can ground an answer." `fallback`, `stub`, and `chunk_artifact` are excluded by design. The closed `AnnotationSource` enum (`String.default("llm").enum("llm", "fallback", "stub", "chunk_artifact", "human")`) must be updated in lockstep with this list — don't add a new `annotation_source` value without updating both.

## Two-pass pipeline (Layer 3)

### Composition

`SFL::Core::Pipeline#compile` is a `Dry::Monads[:result]` bind ladder: `parse → pair_with_ideational → annotate → persist → embed`. A Pass-1 `SidecarError` short-circuits to `Failure([:pass_one_failed, message])` — ideational extraction, Pass 2, storage, and embedding never run for that document. Don't insert guard clauses inside individual stages; the bind chain is the guard.

### Pass 1 = spaCy subprocess sidecar

`SFL::Core::PassOne::SpacySidecarParser` shells out to `sidecar/spacy_sidecar.py` over NDJSON on stdin/stdout. Key invariants: `pgroup: true` so SIGINT to the Ruby process group doesn't kill the sidecar mid-turn; restart-and-retry is exactly once on `Errno::EPIPE` / `IOError` / `SidecarError` — a second transport failure surfaces as `SidecarError`, never loops or hangs; the head-index lookup is positional (`token.head.i - sent.start`, sentence-local), not text-keyed, so repeated-word sentences cannot mis-resolve dependents (F1/D1 — structurally impossible here, not just tested-around).

### Pass 2 contract rejection

`SFL::Core::Types::ModalityWeight` and `TenorValue` are `Coercible::Float.constrained(gteq: 0.0, lteq: 1.0)`. Out-of-range scalars raise `Dry::Struct::Error` in `SFL::LLM::Engine#interpersonal_from` and degrade the whole clause to defaults (`annotation_source: "fallback"`) — the F6/D9 fix is "contract-reject, never silently rescale" (a `0.7` clamped from a real `1.7` is a lie downstream quality scoring would trust). `Coercible` (not strict `Float`) so LLM boundary values `0`/`1` arriving as JSON integers still pass.

`SFL::LLM::Engine#safe_reasoning_trace_from` rescues `Dry::Struct::Error` around the trace-only step and leaves `reasoning_trace: nil` while keeping the real mood/tenor/modality from the LLM — a malformed reasoning trace never blanks the clause; only its provenance record is at risk.

`SFL::LLM::Engine#annotate` rescues everything else into `default_result(clause, …)`, `annotation_source: "fallback"`. `SFL::LLM::Degradation.default_interpersonal` / `default_textual` are the single source of truth for "what does a default look like" — a default must never claim `annotation_source: "llm"`.

### Classification registry fuzzy match

`SFL::Core::ClassificationRegistry::FUZZY_THRESHOLD = 0.92` and `FUZZY_MIN_LENGTH = 4` are calibrated against live Pass-2 output: every observed real near-miss scores ≥ 0.9378 against its intended target, the best garbage term tops out at 0.809. Lowering the threshold silently rewrites a value; a miss falls through to the (warned) default. `.normalize` returns `[value, status]` where status is `:exact` (silent), `:aliased` (silent), `:fuzzy` (WARN — surface so a permanent alias can be added), or `:unknown` (WARN + "consider adding it to ClassificationRegistry"). Don't suppress the WARNs; the alias table grows from observed real output.

### `--pass1-only` is the single Pass-2 stub gate

Lives in `SFL::Core::Pipeline#annotate` (`return Success(stub_annotate_all(pairs)) if pass_one_only`), wired once for every caller. Every stubbed clause has `annotation_source: "stub"`. The alternate path is injecting `SFL::Core::Ports::Null::Annotator` directly; both routes go through `Ports::Null::Annotator#annotate_batch`, so there is one source of truth for "what a stub looks like."

### pgvector dimension lockstep

`SFL::Store::PgEmbeddingStore::VECTOR_DIMENSIONS = 768` is hardcoded against `db/migrations/004_create_embeddings.rb`. A `mistral-embed` (1024-dim) config against an embeddinggemma-provisioned DB raises `SFL::Store::Error` naming the actual cause. If you change the embedding model's column width, change `VECTOR_DIMENSIONS` in lockstep.

### Pass 2 batch annotator is a distinct method, not a loop

`SFL::Core::Ports::Annotator#annotate_batch(pairs, context:)` has its own method (not `#annotate` called N times) because `SFL::LLM::Annotators::BatchClauseAnnotator`'s schema is a genuinely different call shape and cost profile. `SFL::LLM::Engine#annotate_batch` indexes responses by `:index` to match them back to pairs — order is preserved.

### Pass 2 cache key

`SFL::Core::Ports::FileCache` keys on `SHA256("#{document_id}#{clause.sentence_index}#{clause.text}")`. `sentence_index` disambiguates clauses with identical text recurring at different positions in the same document (e.g. repeated boilerplate headers).

## Operational notes

- **Zeitwerk inflections matter.** `TRUSTED_ANNOTATION_SOURCES` is a frozen `Array` constant, not a class — `lib/sfl.rb:18` maps `trusted_annotation_sources → TRUSTED_ANNOTATION_SOURCES`. `kb_*` formatters use `KB*`. `glimmer-dsl-libui` (`lib/sfl/gui`) is `loader.ignore`-ed (opt-in require). New files with non-default camelization need an inflection entry.
- **No bare `bundle exec sfl-analyze` / `sfl-api` / `sfl-review`.** sfl-engine is a non-gem app (no gemspec, no `executables` list → no Bundler binstub). Use `bundle exec exe/<name>`.
- **`SFL::Boot` is the sole ENV reader.** Everything else takes config via constructor injection — don't sprinkle `ENV[...]` reads in domain classes.
- **Host ports `5433` (Postgres) and `6380` (Redis)**, not the canonical `5432`/`6379`. The dev environment remaps to avoid fighting system services. Update `DATABASE_URL` and host-side tooling accordingly.
- **No auto-migration.** `SFL::Boot.call` deliberately never runs migrations. `rake db:migrate` is mandatory on a fresh DB; otherwise the API/CLI fails loudly post-Boot.
- **`experiments/` is quarantined.** `lib/sfl/experiments/` is never autoloaded, never shipped — don't `require` from it.

## Procedure: add a new retrieval filter

1. Add the filter to `SFL::Core::Types::RetrievalFilters`.
2. Add a lambda to `SFL::Store::ClauseFilters::FIND_ALL_FILTERS`, **table-qualified** (e.g. `Sequel[:interpersonal_payloads][:mood] => v`) so it composes safely on a multi-joined scope. Both arms of `SFL::Store::PgHybridRetriever` call `ClauseFilters.apply` against their own joined scope — never inline a `.where` in the retriever.
3. Wire the CLI flag in `SFL::CLI.parse_context_options` (`lib/sfl/cli.rb`); the flag value flows into `options[:filters]` and through to `SFL::Retrieval::ContextSynthesizer#synthesize`.

## Procedure: change the storage shape

- `replace_document` is the only write path. It owns its own `db.transaction { delete; multi_insert }` so re-running a compile never leaves stale rows behind (F7). Do not delete from these tables manually — the FK cascade does it.
- `embedding_status` on `clauses` is the truth for "did this clause get a usable vector?" — `PgEmbeddingStore` flips it to `"embedded"` on success or `"failed"` on a nil/empty vector (F11 contract). One failed clause doesn't abort the rest of the document.
- `AnnotatedClause#id` is the only uuid that round-trips; the upstream per-payload ids collapse to it on storage.

## Procedure: run a one-off sfl-engine analysis

1. Confirm services are up: `docker compose ps` shows `postgres` healthy on `127.0.0.1:5433` (sfl-engine uses non-default host port 5433 to avoid the system Postgres on 5432). Run `bin/setup-python` if `.sfl-python/interpreter_path` doesn't exist. Run `rake db:migrate` if migrations are pending (`SFL::Boot` never migrates).
2. Use `--pass1-only` first to validate Pass 1 alone (no LLM cost, no API key). Output goes to `./output/latest/` by default.
3. Re-run without `--pass1-only` to add Pass 2. `fallback` clauses in the report are real Pass-2 degradations (`annotation_source: "fallback"`) — `TRUSTED_ANNOTATION_SOURCES` excludes them from quality scoring and citation by design.
4. Add `--store` to persist. `bundle exec exe/sfl-analyze context "..." --min-tenor 0.6` then exercises retrieval against what you just stored.
5. Use `--resume` for repeat runs against the same document — it SHA256-caches Pass 2 results per `(document_id, sentence_index, text)` via `SFL::Core::Ports::FileCache`. Cache hits and misses are logged at INFO.

```bash
bundle exec exe/sfl-analyze documentation spec/fixtures/golden_master/README.md        # Pass 1 + Pass 2, no store
bundle exec exe/sfl-analyze documentation ./README.md --pass1-only                       # no LLM cost
bundle exec exe/sfl-analyze documentation ./README.md --store                            # + store + embed
bundle exec exe/sfl-analyze context "what does SFL stand for" --limit 5                  # hybrid RRF
```

## Pitfalls (sfl-engine specific)

- **The trusted-source list is `["llm", "human"]` only.** Don't add a new `annotation_source` value without updating both `TRUSTED_ANNOTATION_SOURCES` and the closed `AnnotationSource` enum.
- **`PgEmbeddingStore::VECTOR_DIMENSIONS = 768` is hardcoded against `db/migrations/004_create_embeddings.rb`.** Change it in lockstep with any embedding-model column-width change.
- **Retrieval filters must push into both SQL arms before `.order`/`.limit` (F8).** Don't reorder — filtering after the RRF merge starves selective queries below `limit`.
- **RRF merge stays in Ruby**, never in SQL — `PgHybridRetriever#reciprocal_rank_fusion` bounds itself to `2 * (limit * 3)` rows.
- **`PgClauseStore#update_interpersonal` is the single-clause re-annotation write path** — it never touches `clauses` or `ideational_payloads`. A full clause rewrite must go through `replace_document`.
- **Don't add `plugin :pgvector, :embedding` to `PgEmbeddingStore`.** The store uses `Pgvector.encode(vector)` for writes and a raw `embedding <=> ?` SQL fragment for reads (`pg_hybrid_retriever.rb:67`) — the plugin would conflict with this raw-SQL approach.
- **Pass 2 contract-rejects out-of-range scalars; it never rescales them.** An LLM returning `1.7` raises `Dry::Struct::Error`, logs a WARN, and degrades the clause to `annotation_source: "fallback"` — never silently clamp.
- **`Coercible::Float` (not strict `Float`) is intentional** for `ModalityWeight`/`TenorValue` — LLM JSON boundary values (`0`, `1`) often arrive as bare integers.
- **Fuzzy-match threshold is `0.92`, calibrated — don't lower it** without re-running the calibration against live Pass-2 output.
- **`--pass1-only` is the single switch that stubs Pass 2** — the gate lives in `SFL::Core::Pipeline#annotate`; injecting `Ports::Null::Annotator` directly is the only alternate path, and both converge on the same `annotate_batch`.

## Verification

```bash
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

A clean `bundle exec rake` exit (`N+ examples, 0 failures`; RuboCop clean) proves the pipeline end-to-end: loaders emit `SFL::Core::Types::Unit`s → `SFL::Analysis::Engine` drives `SFL::Core::Pipeline` → Pass 1 sidecar returns `SyntacticClause`s → `IdeationalExtractor` produces `IdeationalPayload`s → Pass 2 LLM annotator returns `Interpersonal + Textual` payloads → `ClassificationRegistry` normalizes mood/theme_type → `Core::Pipeline` binds the `AnnotatedClause` → `PgClauseStore` / `PgEmbeddingStore` persist three-table + pgvector → `PgHybridRetriever` returns scalar-filtered RRF results.
