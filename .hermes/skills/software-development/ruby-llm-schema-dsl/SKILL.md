---
name: ruby-llm-schema-dsl
description: Define and emit JSON Schemas via the RubyLLM DSL.
version: 0.1.0
author: Hermes
metadata:
  hermes:
    tags: [Ruby, DSL, JSON-Schema, RubyLLM, LLM, Structured-Output, Tools]
---

# RubyLLM::Schema DSL

Use the `ruby_llm-schema` gem (`/home/b08x/WorkspaceV3/_clones/ruby_llm-schema`, v0.4.0) to define JSON Schema documents in a Rails-inspired Ruby DSL and emit them as `to_json_schema` / `to_json` payloads for LLM structured output and `RubyLLM::Tool` parameters. This skill is **a usage reference, not a RubyLLM chat / agent reference** — it does not cover `RubyLLM.chat`, `with_schema`'s call mechanics, embedding, or tool execution; it covers only the schema definition DSL that lives in `lib/ruby_llm/schema/`.

Three entry points (`class < RubyLLM::Schema`, `RubyLLM::Schema.create`, `RubyLLM::Helpers#schema`) emit the same shape. Pick by how you want to reuse the schema; pick by file/module scope; pick by whether you need the class or just an instance.

## When to Use

- Defining a structured-output schema for an LLM call (`chat.with_schema(MySchema)`).
- Defining parameters for a `RubyLLM::Tool` subclass (`params MySchema` or inline `params do … end`).
- Generating portable JSON Schema documents (config files, API contracts, validation payloads) without an LLM.
- Composing sub-schemas via `define` / `reference` / `of:`, recursive schemas via `:root`, or nested Schema classes.
- Validating a schema before emission (catches circular references).

## Prerequisites

- Ruby **>= 3.1.3** (per `ruby_llm-schema.gemspec`).
- Bundler. Install via Gemfile: `gem 'ruby_llm-schema'`. Or direct: `gem install ruby_llm-schema`.
- The library is stdlib + `json` only at runtime (no transitive gem deps for DSL use). `simplecov`, `rubocop`, `rspec` are dev-only per `Gemfile`.
- No API keys needed for schema definition or emission. API keys are needed only when a defined schema is consumed by `RubyLLM.chat.with_schema(...)` (out of scope here).

## How to Run

This skill is a reference. Use it through `read_file` on the gem source (`lib/ruby_llm/schema.rb`, `lib/ruby_llm/schema/dsl/*.rb`, `lib/ruby_llm/schema/validator.rb`, `lib/ruby_llm/schema/json_output.rb`) and `execute_code` to drive it interactively. For verifying your schema, run the gem's own spec suite through the `terminal` tool:

```bash
cd /home/b08x/WorkspaceV3/_clones/ruby_llm-schema
bundle install
bundle exec rspec                              # full suite (12 spec files, ~ all property types)
bundle exec rspec spec/ruby_llm/schema/properties/strings_spec.rb  # one type
bundle exec ruby -Ilib -rruby_llm/schema -e 'puts RubyLLM::Schema.create { string :name }.new.to_json'
```

## Quick Reference

| Construct | DSL | Where defined |
|---|---|---|
| String | `string :name, enum: [...], pattern: "...", format: "email", min_length:, max_length:` | `dsl/primitive_types.rb` |
| Number | `number :age, minimum:, maximum:, multiple_of:, enum:` | same |
| Integer | `integer :n, minimum:, maximum:, multiple_of:, enum:` | same |
| Boolean | `boolean :active` | same |
| Null | `null :placeholder` | same |
| Object (inline) | `object :address do … end` | `dsl/complex_types.rb` |
| Object (by class) | `object :ceo, of: PersonSchema` | `dsl/schema_builders.rb#determine_object_reference` |
| Object (deprecated alias) | `object :home_location, reference: :location` | `dsl/schema_builders.rb` (warns deprecation) |
| Array of primitive | `array :tags, of: :string` | `dsl/schema_builders.rb#determine_array_items` |
| Array of object (block) | `array :items do object do … end end` | same |
| Array of schema class | `array :employees, of: PersonSchema` | same |
| Array size | `array :items, min_items: 1, max_items: 10` | same |
| Union (anyOf) | `any_of :value do string; number; null end` | `dsl/complex_types.rb`, `dsl/schema_builders.rb` |
| Union (oneOf) | `one_of :value do … end` | same |
| Optional (sugar) | `optional :name do string end` ⇒ `any_of :name { string; null }` | `dsl/complex_types.rb` |
| Required flag | `string :name` (default required) / `string :name, required: false` | `dsl/primitive_types.rb` |
| Inline `requires:` dep | `string :cvv, required: false, requires: :credit_card` ⇒ `dependentRequired` | `dsl/utilities.rb#add_property` |
| `dependent` block (with validation) | `dependent :credit_card do requires :cvv; validates :cvv, type: :string, min_length: 1 end` ⇒ `dependentSchemas` | `dsl/conditionals.rb` |
| Conditional (if/then/else) | `given status: "shipped" do requires :tracking_number end` + `otherwise do … end` | `dsl/conditionals.rb` |
| Sub-schema definition | `define :location do string :lat; string :lng end` (lands in `$defs`) | `dsl/utilities.rb` |
| Reference to definition | `array :coords, of: :location` or `object :loc, of: :location` | `dsl/schema_builders.rb` |
| Recursive reference | `object :sub_schema, reference: :root` ⇒ `{"$ref": "#"}` | `dsl/utilities.rb#reference` |
| Factory class | `MySchema = RubyLLM::Schema.create do … end` | `schema.rb#create` |
| Inheritance class | `class MySchema < RubyLLM::Schema … end` | `schema.rb` |
| Helper instance | `include RubyLLM::Helpers; s = schema "Name" do … end` | `helpers.rb` |
| Emit Hash | `schema.to_json_schema` | `json_output.rb` |
| Emit pretty JSON | `puts schema.to_json` | same |
| Class-level validation | `MySchema.validate!` / `MySchema.valid?` | `validator.rb` (DFS, raises `ValidationError` on cycle) |
| Instance validation | `schema.validate!` / `schema.valid?` | `schema.rb` |

`validates` option keys (inside `dependent` / `given` blocks): `type:`, `not_value:`, `min_length:`, `max_length:`, `pattern:` (string or regexp), `enum:`, `const:`, `minimum:`, `maximum:`. Anything else raises `ArgumentError, "unknown validates option: …"` (`dsl/conditionals.rb#validates`).

## Procedure

1. **Pick an entry point** based on whether you want a reusable class or a one-shot instance:
   - Class inheritance (reusable, named, can be subclassed): `class PersonSchema < RubyLLM::Schema … end`
   - Factory (reusable, anonymous, returned from a method): `PersonSchema = RubyLLM::Schema.create do … end`
   - Helper (one-shot instance, useful inside tools): `include RubyLLM::Helpers; s = schema("Person") do … end`

2. **Declare top-level properties** with `string` / `number` / `integer` / `boolean` / `null`. All are required by default; pass `required: false` for optional. Every property takes `description:` as the first-class arg.

3. **Compose nested objects** with `object :name do … end` blocks, or by class with `object :name, of: OtherSchemaClass` (the `of:` form is the current canonical — see Pitfalls for the deprecated `reference:` form).

4. **Compose arrays** with `array :name, of: :primitive_symbol` (primitive), `array :name, of: SomeSchemaClass` (schema class), or `array :name do object do … end end` (inline object). Add `min_items:` / `max_items:` for size constraints.

5. **Express optionality** one of two ways:
   - `string :name, required: false` ⇒ drops `:name` from `required` array. **OpenAI rejects this** (requires all properties present at the top level).
   - `optional :name do string end` ⇒ expands to `any_of :name { string; null }`, which OpenAI accepts. Use `optional` whenever the LLM provider requires every property to be present.

6. **Express dependencies** two ways:
   - Inline: `string :cvv, required: false, requires: %i[billing_address]` ⇒ `dependentRequired` (Draft 2019-09).
   - Block (when you also need field validation): `dependent :credit_card do requires :billing_address; validates :billing_address, type: :string, min_length: 1 end` ⇒ `dependentSchemas`. The block-without-validations case still upgrades to `dependentSchemas` only if at least one `validates` is present (see `dsl/conditionals.rb#merge_conditions`).

7. **Express conditional requirements** with `given property: value do … end` + optional `otherwise do … end`. Condition values auto-coerce: `String` → `const`, `Array` → `enum`, `Regexp` → `pattern`, `Hash` → raw schema (`dsl/conditionals.rb#coerce_condition`). Empty condition raises `ArgumentError, "given requires at least one property condition"`.

8. **Reuse sub-schemas** with `define :name do … end` (lands in `$defs[name]`) and reference them via `of: :name` on `object` / `array`. For self-recursion, use `reference: :root` (resolves to `{"$ref": "#"}`).

9. **Validate before emission.** `MySchema.validate!` runs a DFS over `$defs` (`validator.rb`) and raises `RubyLLM::Schema::ValidationError` if a circular reference is detected. `to_json_schema` and `to_json` both call `validate!` automatically; if you want a non-raising check, use `MySchema.valid?` / `schema.valid?`.

10. **Emit.** `schema.to_json_schema` returns `{name:, description:, schema: {type:, properties:, required:, additionalProperties:, strict:, $defs:, …}}`. `puts schema.to_json` for the pretty-printed string. Both methods invoke `validate!` first; emission failures are validation failures.

## Pitfalls

- **OpenAI's "all properties required" rule.** OpenAI's structured output requires every top-level property to be present in `required` (the provider returns an error otherwise). The DSL workaround is `optional :name do string end` ⇒ `any_of :name { string; null }`, which keeps the property required-but-nullable. Bare `string :name, required: false` does NOT satisfy OpenAI — the property is just absent. This is called out in `README.md`.
- **`reference:` is deprecated for `object`.** `object :loc, reference: :name` prints `"[DEPRECATION] The \`reference\` option will be deprecated. Please use \`of\` instead."` (`dsl/schema_builders.rb#object_schema:51`). Use `of: :name` going forward. `reference: :root` on objects is still the canonical way to express recursion — it's only the named-definition form that's deprecated.
- **`reference` symbol semantics differ by caller.** On `object`, `reference: :name` warns + is rewritten to `of: :name` (deprecated). On `reference(schema_name)` directly (the DSL method in `dsl/utilities.rb`), `:root` is special-cased to `{"$ref": "#"}`; every other symbol resolves to `{"$ref": "#/$defs/<name>"}`. Don't pass `:root` to `of:` and expect `{"$ref": "#"}` — `of: :root` will look up a `$defs[:root]` that doesn't exist.
- **`of:` accepts a `Class < Schema`, a `Schema` instance, or a primitive symbol.** It raises `RubyLLM::Schema::InvalidObjectTypeError` for unknown classes (the class must inherit from `RubyLLM::Schema`) and `InvalidArrayTypeError` for unknown array item types. The error message names the constraint.
- **`optional` is sugar, not a new keyword.** `optional :name do … end` is literally `any_of :name do … end` with `null` appended at the end of the block — `dsl/complex_types.rb#optional` does `instance_eval(&block); null`. If your block raises before reaching `null`, the property becomes just whatever was inside. Don't put validation that may fail inside `optional`.
- **`required: false` re-runs on every call.** `dsl/utilities.rb#add_property` deletes from `required_properties` if `required` is false and adds back if true; calling `string :name, required: false` then `string :name` flips the state. This is expected for class-level mutation, but if you reuse a schema class across `create`/`to_json_schema` cycles in tests, expect re-evaluation each time.
- **`given` with no condition raises.** `given do … end` ⇒ `ArgumentError, "given requires at least one property condition"`. Pass at least one `property: value` pair.
- **`validates` key set is closed.** The whitelist is `type / const / enum / not_value / min_length / max_length / pattern / minimum / maximum` (`VALIDATES_KEY_MAP` in `dsl/conditionals.rb`). Anything else raises `ArgumentError, "unknown validates option: …"`. Snake_case keys are translated to JSON Schema's camelCase (`not_value` → `not`, `min_length` → `minLength`, etc.).
- **`pattern:` accepts a `Regexp` or a String.** `dsl/conditionals.rb#validates` checks `value.is_a?(Regexp)` and uses `value.source`. Pass a regexp directly to avoid double-escaping.
- **`validate!` catches circular references only.** It does **not** check semantic JSON Schema validity (required-key consistency, type compatibility, etc.). It is a guard for `define`/`reference` cycles. Don't use it as a general schema validator.
- **`strict` defaults to `true`.** `RubyLLM::Schema.strict` (no args) returns `true` unless explicitly set (`schema.rb:55-61`). `to_json_schema` adds `"strict": true` to the output schema unless `strict` was set to `false`. Some LLM providers require `strict: true` (OpenAI does); others reject it. Use `strict false` if your provider doesn't accept it.
- **Additional properties default to `false`.** `RubyLLM::Schema.additional_properties` (no args) defaults to `false`, so every emitted schema has `"additionalProperties": false`. OpenAI requires this; other providers may reject it. Override with `additional_properties true` at the class level.
- **`Schema.create` returns an anonymous class.** It cannot be reopened later. Use class inheritance if you need to extend or patch the schema in a follow-up.
- **`Helpers#schema` returns a `Schema` instance, not a class.** Reuse requires re-invoking `schema(…)`. The class itself is anonymous.
- **`method_missing` proxies to the class** (`schema.rb:87-93`). Instance calls to `string`, `array`, `object`, etc. delegate to `self.class`. This means calling `instance.string :foo` mutates class-level state — the next instance of the same class inherits the property. Don't rely on instance-only DSL calls.
- **`Validator` only walks `definitions`, not inline `anyOf` / `oneOf` chains.** A cyclic `any_of :x { any_of :y { object(:x) } }` won't be caught because `extract_references` only looks for `"$ref"` keys. If you need recursion via inline `anyOf`, the DFS won't see it.
- **`dsl/schema_builders.rb#collect_schemas_from_block` builds methods on a `context = Object.new`** (`define_singleton_method` loop over `_schema` methods). The block inside `any_of` / `one_of` runs with that isolated context, not the schema class itself. Calling `define` inside an `any_of` block writes to the local context's `definitions`, **not** to the parent schema's `definitions`. Don't try to share definitions across nested unions.

## Verification

```bash
cd /home/b08x/WorkspaceV3/_clones/ruby_llm-schema
bundle install
bundle exec rspec --format progress
```

A passing suite proves: the three entry points (`class < RubyLLM::Schema`, `RubyLLM::Schema.create`, `RubyLLM::Helpers#schema`) all emit equivalent JSON Schema documents; every primitive + complex + union + conditional + definition + reference shape serializes correctly; `Validator` catches circular references via DFS; and `to_json_schema` / `to_json` always include `additionalProperties: false` + `strict: true` defaults. The 19 spec files split by concern (entry_points / properties / robustness / strict), so a failure localizes the broken shape — e.g. `spec/ruby_llm/schema/properties/strings_spec.rb` for string-only failures, `robustness/validation_spec.rb` for the DFS cycle check, `entry_points/factory_spec.rb` for `Schema.create` regressions.