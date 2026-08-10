# Ohm ↔ Sequel Idiom Patterns

Generic, project-agnostic mapping between Ohm (Redis) and Sequel (PostgreSQL) model idioms. Use this when designing a new model in either ORM, or porting a model from one to the other.

## Side-by-side idiom table

| Concern | Ohm (Redis) | Sequel (PostgreSQL) |
|---|---|---|
| Schema declaration | `attribute :name` (no DDL) | `class X < Sequel::Model` (auto-infers from table) |
| Required field | `assert_present :name` in `def validate; super; end` | `validates_presence :name` in `def validate; super; end` |
| Membership enum | `assert_member :status, VALID_STATUSES` | `validates_includes :status, VALID_STATUSES` |
| Numeric field | `assert_numeric :processing_order` | (use `plugin :validation_helpers` + type column) |
| Single-column index | `index :status` | (DB-side; create via migration) |
| Unique constraint | `unique :content_hash` | `validates_unique :name` |
| Belongs-to | `reference :document, :Document` | `many_to_one :document` |
| Has-many | `collection :segments, :DocumentSegment` | `one_to_many :sections` |
| Sorted has-many | `list :words, :Word` | (default `one_to_many` is order-by-PK; add `:order` to override) |
| Unordered set | `set :documents, :Document` | (use `one_to_many` with `class: :Item do \|ds\| ... end`) |
| Typed attribute | `attribute :metadata, Type::Hash` | (column-level `jsonb` or string) |
| JSON-as-string field | `JSON.parse(attr) rescue {}` getter + `attr = hash.to_json` setter | (use `pg_jsonb` column type) |
| Timestamps | `include Ohm::Timestamps` | `plugin :timestamps` |
| Embedding column | store as `attribute :embedding, Type::Array` of floats | `plugin :pgvector, :embedding` then `nearest_neighbors(:embedding, vec, distance: "cosine")` |
| Upsert / dedup | `rescue Ohm::UniqueIndexViolation; find(content_hash: ...).first` | `plugin :insert_conflict` (then `insert_conflict(target: :content_hash)`) |
| Normalization callback | `def before_save; self.text = text.downcase.strip if text; end` | `def before_create; self.created_at ||= Time.now; super; end` |
| STI / polymorphism | one base `Ohm::Model` + subclasses with a discriminator field set in `initialize` | (no native STI; use `plugin :single_table_inheritance` if needed) |

## Picking between Ohm and Sequel

- **Redis is the source of truth** (state machine, ephemeral, fast writes): use Ohm. Typical fit: a status/retry state machine, a processing-event log, an unordered set of child references.
- **Postgres + pgvector is the source of truth** (durable, queryable, embeddings): use Sequel. Typical fit: durable records with embeddings, records that need joins or arbitrary SQL queries, anything queried by similarity.
- **Both**: keep state in Ohm and embeddings/durable records in Sequel, joined by a shared `document_id` / `external_id` at the application layer — never by an ORM relation across the two stores.

## Porting between ORMs

**Ohm → Sequel:**
- `attribute :text, Type::String` → `text TEXT` column
- `unique :name` → migration-side `unique_index` + `validates_unique :name`
- `reference :parent, :ParentClass` → `many_to_one :parent`
- `collection :children, :ChildClass` → `one_to_many :children`
- `Type::Hash` / JSON-as-string field → `jsonb` column (drop the manual `JSON.parse` getter — Sequel's `pg_jsonb` deserializes automatically)
- `Type::Array` of floats (embedding) → pgvector column + `plugin :pgvector`

**Sequel → Ohm:**
- `validates_presence :name` → `assert_present :name`
- `validates_includes :status, LIST` → `assert_member :status, LIST`
- DB-side unique index → `unique :name`
- pgvector embedding column → `Type::Array` of floats (lossy versus pgvector's indexed similarity search — keep the model in Sequel if you actually query by similarity; only port to Ohm if the embedding is carried but not queried there)

## Pitfalls

- **`assert_present` does not catch empty-string.** `Ohm::Model#assert_present(:name)` only checks for `nil`. If empty string should be rejected too, validate explicitly (`assert name && !name.empty?`).
- **`Ohm::UniqueIndexViolation` is the canonical "already exists" signal, not a real error.** Catch it and return the existing record. Always pair `unique :content_hash` with this rescue pattern, or concurrent writes will double-create.
- **`unique :name` declares a unique index but not a plain lookup index.** If you also want non-unique lookups on the same field, add `index :name` separately alongside `unique :name`.
- **`validates_unique` requires a DB-side unique index.** Adding `validates_unique :name` to a model whose `:name` column has no unique constraint in the DB passes validation but allows duplicates under concurrent writes — create the migration-side index first.
- **`plugin :pgvector, :embedding` requires a column literally named `:embedding`.** Renaming the column (e.g. to `:vector`) makes the plugin silently no-op or raise. Keep the column named `embedding`, or pass the correct symbol explicitly if the plugin API allows it.
- **Filtered `one_to_many` blocks are re-applied on every association access, not memoized.** `one_to_many :text_files, class: :Item do |ds| ds.filter(type: 'text'); end` means the association always returns the filtered set at access time — don't re-filter the result downstream, and don't cache it assuming it's a plain unfiltered set.
- **Explicit-dataset binding (`Sequel::Model(SomeDB[:table_name])`) is for tables that don't auto-pluralize correctly**, or legacy schemas — prefer plain `Sequel::Model` inheritance and auto-inference unless you hit that case; don't reach for a `set_dataset` override on the model class instead.
- **STI-lite (one base class + discriminator field set in `initialize`) works because the subclasses are real model classes calling `super`.** Querying the base class filtered by discriminator returns base-class instances, not subclass instances — it does not give you real polymorphic dispatch. Use Sequel's `plugin :single_table_inheritance` if you need actual STI.
- **A JSON-as-string metadata getter should return `{}` on `JSON::ParserError`, not raise.** This is the established contract for malformed JSON-string columns in Ohm-side models — don't assume a malformed value raises.
- **`before_save` runs on every save in Ohm, including updates**, not just inserts. A normalization callback intended for insert-only needs an explicit `self.new?` guard, or it will silently re-normalize a value the caller just set on update.
