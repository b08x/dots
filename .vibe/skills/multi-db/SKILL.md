---
name: multi-db
description: "Use for Ruby projects storing data across more than one database - Ohm (Redis) and Sequel (PostgreSQL/pgvector) model design, picking between them, porting a model between ORMs, and dual-database storage/retrieval patterns (multi-table payload separation, hybrid RRF retrieval, scalar filters). Trigger on 'Ohm model', 'Sequel model', 'Redis model', 'pgvector store', 'multi-database', 'dual-database', 'ORM pattern', 'clause store', 'hybrid retrieval filters'."
user-invocable: true
---

# RubyDev Multi-DB — Ohm + Sequel Dual-Database Patterns

## Overview

This skill covers Ruby projects that store data in **more than one database** — typically Redis (via `Ohm`, schemaless, fast, state-machine-shaped) and PostgreSQL/pgvector (via `Sequel`, durable, queryable, with embeddings). It embodies "The Data Modeler" persona: pick the right store for each concern, keep the two in sync by shared key (not ORM relation), and never blur schemaless state from durable, query-able storage.

Two reference layers back this skill:

- **[~/.vibe/skills/multi-db/references/orm-idiom-patterns.md](~/.vibe/skills/multi-db/~/.vibe/skills/multi-db/references/orm-idiom-patterns.md))** — generic Ohm ↔ Sequel idiom table, picking guidance, and porting-between-ORMs mapping. Read this when designing or porting *any* Ohm/Sequel model, in any project.
- **[~/.vibe/skills/multi-db/references/sfl-engine-case-study.md](~/.vibe/skills/multi-db/~/.vibe/skills/multi-db/references/sfl-engine-case-study.md))** — a concrete, actionable worked instantiation of these patterns from `sfl-engine` (a stance-filtered RAG engine at `/home/b08x/WorkspaceV3/sfl-engine`): three-table payload-separated storage, hybrid RRF retrieval with scalar filters, and the two-pass annotation pipeline. Read this when working inside `sfl-engine/lib/sfl/store/`, `lib/sfl/llm/`, `lib/sfl/core/`, or `lib/sfl/retrieval/` — the class names, file paths, and invariants (F1, F6-F8, F11, D9) are real and load-bearing, not illustrative.

## When to Use

- Designing a new Ohm model (Redis) or Sequel model (PostgreSQL/pgvector)
- Deciding whether a concern belongs in Redis (state machine, ephemeral, fast writes) or Postgres (durable, queryable, embeddings)
- Porting a model between Ohm and Sequel
- Adding a pgvector-backed store, embedding column, or `nearest_neighbors` similarity query
- Building a hybrid (semantic + keyword) retrieval layer with Reciprocal Rank Fusion
- Working inside `sfl-engine`'s storage (`SFL::Store::*`), pipeline (`SFL::Core::Pipeline`), or classification registry — see the case study reference directly

**Don't use for:**
- Single-database CRUD with no ORM design question — just write the code
- General ETL / CSV / batch file processing (use [data-engineer/SKILL.md](~/.vibe/skills/data-engineer/SKILL.md))
- LLM agent / MCP server scaffolding that doesn't touch storage design (use [genai/SKILL.md](~/.vibe/skills/genai/SKILL.md)) — genai's RRF example is a generic pattern; this skill's case study is the concrete instantiation with real invariants

## Picking Between Ohm and Sequel

- **Redis is the source of truth** (state machine, ephemeral, fast writes): use Ohm. Example: a `Document` model with status machine, retry count, processing events.
- **Postgres + pgvector is the source of truth** (durable, queryable, embeddings): use Sequel. Example: a `DocumentRecord` model with pgvector `:embedding`, or a model joined `many_to_one` to a parent.
- **Both**: keep state in Ohm and embeddings in Sequel, joined by a shared `document_id` / `external_id` — **not** an ORM relation. This is the load-bearing seam: the two stores never reference each other through a foreign key or association, only through an application-level shared identifier.

Full idiom-by-idiom mapping (schema declaration, validation, relations, embeddings, upsert/dedup, STI, etc.) is in [~/.vibe/skills/multi-db/references/orm-idiom-patterns.md](~/.vibe/skills/multi-db/~/.vibe/skills/multi-db/references/orm-idiom-patterns.md)).

## Procedure

### Add a new Ohm model

1. Include `Ohm::DataTypes` and `Ohm::Callbacks` (`Ohm::Timestamps` if you want `created_at`/`updated_at`).
2. Declare attributes with `attribute :name`; use `Type::Integer` / `Type::Array` / `Type::Hash` for typed slots.
3. Declare indexes: `index :status`; use `unique :content_hash` when dedup is required — and pair it with `index :content_hash` too if you also need non-unique lookups (the unique index alone doesn't give you a plain lookup index).
4. Declare relations: `reference :parent, :ParentClass` (many-to-one), `collection :children, :ChildClass` (has-many), `list :words, :Word` (ordered), `set :tags, :Tag` (unordered unique).
5. Implement `def validate; super; assert_present :name; end`. `assert_present` catches `nil` but **not** empty-string — pair with an explicit `name && !name.empty?` check if you need to reject `""`.
6. Implement `def before_save` for normalization (`text.downcase.strip`). Note `before_save` runs on **every** save, not just insert — check `self.new?` first if a callback should only fire on insert, or accept that it also re-normalizes on update.
7. For JSON-as-string fields: getter `JSON.parse(attr) rescue {}` (returns `{}` on malformed JSON, doesn't raise), setter `attr = hash.to_json`.
8. Rescue `Ohm::UniqueIndexViolation` as the canonical "already exists" signal — treat it as control flow, not a real error: `rescue Ohm::UniqueIndexViolation; find(content_hash: ...).first`. Always pair a `unique` index with this rescue or you'll double-create on race.

### Add a new Sequel model

1. Inherit `Sequel::Model` (auto-infers `<name>s` table) — or `Sequel::Model(SomeDB[:table_name])` for explicit-dataset binding when the table name doesn't pluralize correctly or you're binding to a legacy schema.
2. Add `plugin :validation_helpers`, `plugin :insert_conflict` if upsert/dedup is needed.
3. If the model carries an embedding: `plugin :pgvector, :embedding` — the `:embedding` symbol **must** name a column literally called `embedding`; renaming the column silently no-ops the plugin or raises.
4. Declare relations: `one_to_many :sections`, `many_to_one :document`. Filter with a block — `one_to_many :text_files, class: :Item do |ds| ds.filter(type: 'text'); end` — Sequel calls the block at access time, so the association always returns the filtered set; don't re-filter downstream.
5. Implement `def validate; super; validates_presence :name; validates_unique :name; end`. `validates_unique` requires a DB-side unique index — adding it without the migration-side index passes validation but allows duplicate rows under race conditions.
6. For similarity search: `nearest_neighbors(:embedding, vec, distance: "cosine")` from the pgvector plugin.
7. `def before_create; self.created_at ||= Time.now; super; end` for app-side defaults.

### Port a model between ORMs

- **Ohm → Sequel**: attributes become columns (`attribute :text, Type::String` → `text TEXT`); `unique :name` → migration-side `unique_index` + `validates_unique :name`; `reference :parent, :ParentClass` → `many_to_one :parent`; `collection :children, :ChildClass` → `one_to_many :children`; `Type::Hash` / JSON-as-string → `jsonb` column (drop the `JSON.parse` getter); `Type::Array` of floats → pgvector column + `plugin :pgvector`.
- **Sequel → Ohm**: inverse of the above. `validates_presence` → `assert_present`; `validates_includes` → `assert_member`; unique index → `unique`; pgvector embeddings become `Type::Array` of floats (lossy vs. pgvector indexing — keep Sequel if you actually query by similarity).

### Add a dual-database (payload-separated) store or retrieval filter

This is the sfl-engine-instantiated pattern: one structural table + N payload tables sharing a foreign key, one write path per aggregate (`replace_document`-style), table-qualified filter lambdas applied before `.order`/`.limit` on every retrieval arm, and RRF merge kept in application code rather than pushed into SQL. Full procedure, invariants, and file/class references are in [~/.vibe/skills/multi-db/references/sfl-engine-case-study.md](~/.vibe/skills/multi-db/~/.vibe/skills/multi-db/references/sfl-engine-case-study.md)) — follow it directly when touching `sfl-engine/lib/sfl/store/` or `lib/sfl/retrieval/`.

## Common Pitfalls

1. **`assert_present` doesn't catch empty-string.** Ohm-side; validate explicitly if `""` should be rejected.
2. **`validates_unique` without a DB-side unique index** passes validation but allows duplicate rows under concurrent writes — create the index in a migration first.
3. **Renaming a pgvector column away from `:embedding`** silently breaks `plugin :pgvector, :embedding` — keep the column named `embedding` or pass the correct symbol explicitly.
4. **Filtered `one_to_many` blocks are re-applied on every access**, not memoized — don't re-filter the result downstream, and don't assume the association is a plain unfiltered set.
5. **`before_save` fires on every save in Ohm**, not just insert. A normalization callback intended for insert-only needs an explicit `self.new?` guard.
6. **Two ORM stores joined by shared ID, never by ORM relation.** Don't reach for a foreign-key association across Redis and Postgres — join by `document_id`/`external_id` at the application layer.
7. **Retrieval filters must apply to every arm before `.order`/`.limit`.** In a hybrid semantic+keyword retriever, applying a filter only after merging starves the result to fewer than `limit` rows when the filter is selective. Apply it identically on each arm's own scope.

Full pitfall catalog (including sfl-engine-specific ones — trust contract, dimension lockstep, pipeline bind-chain, fuzzy-match calibration) is in [~/.vibe/skills/multi-db/references/sfl-engine-case-study.md](~/.vibe/skills/multi-db/~/.vibe/skills/multi-db/references/sfl-engine-case-study.md)).

## Verification Checklist

- [ ] Chose Redis (Ohm) vs Postgres (Sequel) per the state-machine/durable-queryable split, not by default habit
- [ ] Dual-database models joined by shared ID, not ORM relation
- [ ] Unique constraints have both a DB-side index and an app-side `rescue`/`validates_unique` pairing
- [ ] pgvector columns named `embedding` if using `plugin :pgvector, :embedding`
- [ ] Retrieval filters (if hybrid) apply before `.order`/`.limit` on every search arm
- [ ] `# frozen_string_literal: true` on every new `.rb` file; Zeitwerk-compliant naming
- [ ] For sfl-engine work specifically: case-study invariants checked (single write path per aggregate, trusted-source list, embedding dimension lockstep)
