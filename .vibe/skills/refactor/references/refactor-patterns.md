# Refactor Patterns

Named patterns for ruby-dev-refactor. Each entry maps a `pattern` key
(used in report YAML output) to a before/after transformation.

## Contents

Mechanical & convention fixes:
- [thread_to_async](#thread_to_async)
- [hardcoded_config](#hardcoded_config)
- [zeitwerk_mismatch](#zeitwerk_mismatch)
- [missing_frozen_string_literal](#missing_frozen_string_literal)
- [extend_self_to_module_function](#extend_self_to_module_function)
- [puts_to_logger](#puts_to_logger)
- [bare_rescue_exception](#bare_rescue_exception)
- [silent_rescue](#silent_rescue)
- [missing_circuit_breaker](#missing_circuit_breaker)
- [nested_conditionals](#nested_conditionals)
- [positional_args_to_kwargs](#positional_args_to_kwargs)
- [ad_hoc_hash_validation](#ad_hoc_hash_validation)
- [unauthorized_require](#unauthorized_require)
- [missing_namespace](#missing_namespace)
- [hash_to_dry_struct](#hash_to_dry_struct)
- [exception_to_result_monad](#exception_to_result_monad)
- [global_constant_to_config](#global_constant_to_config)
- [manual_logging_to_journald](#manual_logging_to_journald)
- [no_gemfile_to_rubysmith](#no_gemfile_to_rubysmith)

OO design patterns (POODR; warrants in ~/.vibe/skills/ruby-dev/~/.vibe/skills/refactor/references/ood-principles.md):
- [extract_class](#extract_class)
- [inject_dependency](#inject_dependency)
- [isolate_class_reference](#isolate_class_reference)
- [demeter_chain](#demeter_chain)
- [type_switch_to_duck_type](#type_switch_to_duck_type)
- [inheritance_to_composition](#inheritance_to_composition)
- [super_to_hook_methods](#super_to_hook_methods)

Resilience patterns (Polished Ruby ch5):
- [retry_without_backoff](#retry_without_backoff)
- [hot_loop_exception_backtrace](#hot_loop_exception_backtrace)
- [fail_open_authorization](#fail_open_authorization)
- [boolean_save_to_bang](#boolean_save_to_bang)

---

## thread_to_async
**Severity:** CRITICAL
**Area:** async

```ruby
# Before
def fetch_all(urls)
  threads = urls.map do |url|
    Thread.new { fetch(url) }
  end
  threads.map(&:join)
end

# After
require "async"

def fetch_all(urls)
  results = []
  Async do
    barrier = Async::Barrier.new
    urls.each do |url|
      barrier.async { results << fetch(url) }
    end
    barrier.wait
  end
  results
end
```

---

## hardcoded_config
**Severity:** CRITICAL
**Area:** architecture

```ruby
# Before
API_KEY = "sk-abc123..."
DB_URL = "postgres://localhost/mydb"

# After — .env file
# ANTHROPIC_API_KEY=sk-abc123...
# DATABASE_URL=postgres://localhost/mydb

# config/application.rb
require "dotenv/load"
require "tty-config"

config = TTY::Config.new
config.set_from_env("api_key",    var: "ANTHROPIC_API_KEY")
config.set_from_env("db_url",     var: "DATABASE_URL")
```

---

## zeitwerk_mismatch
**Severity:** CRITICAL
**Area:** architecture

```ruby
# Before: file is lib/my_app/dataProcessor.rb
class DataProcessor; end

# After: rename file to lib/my_app/data_processor.rb
# frozen_string_literal: true

module MyApp
  class DataProcessor; end
end
```

---

## missing_frozen_string_literal
**Severity:** ERROR
**Area:** style

Add `# frozen_string_literal: true` as the first line of every Ruby file.
Exception: files that must build dynamic strings via `<<` mutation (rare).

---

## extend_self_to_module_function
**Severity:** ERROR
**Area:** style

```ruby
# Before
module TextUtils
  extend self

  def normalize(text)
    text.strip.downcase
  end
end

# After
module TextUtils
  module_function

  def normalize(text)
    text.strip.downcase
  end
end
```

---

## puts_to_logger
**Severity:** ERROR
**Area:** logging

```ruby
# Before
puts "Processing #{doc.id}"
p response
STDOUT.puts "Done"

# After
LOGGER.info("Processing document", doc_id: doc.id)
LOGGER.debug("LLM response", response: response.to_h)
LOGGER.info("Pipeline complete")
```

---

## bare_rescue_exception
**Severity:** ERROR
**Area:** error_handling

```ruby
# Before
rescue Exception => e
  puts e.message

# After
rescue MyApp::Error, StandardError => e
  LOGGER.error("Operation failed", error: e.message, class: e.class.name)
  raise
```

---

## silent_rescue
**Severity:** ERROR
**Area:** error_handling

```ruby
# Before
rescue => e
  nil

rescue => _e
  false

# After — be explicit about what you're swallowing and why
rescue MyApp::TransientError => e
  LOGGER.warn("Transient error ignored", error: e.message)
  nil
```

---

## missing_circuit_breaker
**Severity:** ERROR
**Area:** async

```ruby
# Before
def call_llm(prompt)
  RubyLLM.chat.ask(prompt)
end

# After
require "circuit_breaker"

class LLMClient
  include CircuitBreaker

  def call_llm(prompt)
    RubyLLM.chat.ask(prompt)
  end

  circuit_method :call_llm

  circuit_handler do |handler|
    handler.failure_threshold = 5
    handler.failure_timeout = 60
    handler.invocation_timeout = 30
    handler.logger = LOGGER
  end
end
```

---

## nested_conditionals
**Severity:** WARNING
**Area:** style

```ruby
# Before
def process(doc)
  if doc
    if doc.valid?
      if doc.content && !doc.content.empty?
        run_pipeline(doc)
      end
    end
  end
end

# After
def process(doc)
  return unless doc
  return unless doc.valid?
  return if doc.content.nil? || doc.content.empty?

  run_pipeline(doc)
end
```

---

## positional_args_to_kwargs
**Severity:** WARNING
**Area:** style

```ruby
# Before (3+ positional args)
def embed(text, model, batch_size, normalize)

# After
def embed(text:, model: "text-embedding-3-small", batch_size: 100, normalize: true)
```

---

## ad_hoc_hash_validation
**Severity:** WARNING
**Area:** architecture

```ruby
# Before
def process(params)
  raise "text required" unless params[:text]
  raise "must be string" unless params[:text].is_a?(String)
  # ...
end

# After
require "dry-schema"

ProcessParams = Dry::Schema.Params do
  required(:text).filled(:string)
  optional(:model).filled(:string)
end

def process(params)
  result = ProcessParams.call(params)
  raise MyApp::ValidationError, result.errors.to_h.inspect if result.failure?
  # ...
end
```

---

## unauthorized_require
**Severity:** WARNING
**Area:** architecture

Remove `require` statements for files managed by Zeitwerk:
```ruby
# Before
require_relative "../agents/chat"
require_relative "../../lib/my_app/utils"

# After — delete these lines; Zeitwerk autoloads them
# Ensure loader.setup is called before these constants are first referenced
```

---

## missing_namespace
**Severity:** WARNING
**Area:** architecture

Wrap all application classes in the project module namespace:
```ruby
# Before
class DataProcessor; end

# After
module MyApp
  class DataProcessor; end
end
```


---

## hash_to_dry_struct
**Severity:** ERROR
**Area:** type_safety

```ruby
# Before — raw hash return values
def embed(text)
  response = client.embeddings(input: text)
  {
    embedding: response.embedding,
    model: response.model,
    tokens: response.usage.total_tokens,
    latency_ms: elapsed_ms
  }
end

# After — type-safe dry-struct
require "dry-struct"

class EmbeddingResult < Dry::Struct
  attribute :embedding, Types::Array.of(Types::Float)
  attribute :model, Types::String
  attribute :tokens_used, Types::Integer
  attribute :latency_ms, Types::Float
  attribute :timestamp, Types::Time.default { Time.now }
end

def embed(text)
  response = client.embeddings(input: text)
  EmbeddingResult.new(
    embedding: response.embedding,
    model: response.model,
    tokens_used: response.usage.total_tokens,
    latency_ms: elapsed_ms
  )
end
```

**Benefits**:
- Compile-time type checking
- Automatic coercion (e.g., "123" → 123)
- Self-documenting method signatures
- Prevents invalid data propagation

---

## exception_to_result_monad
**Severity:** ERROR
**Area:** error_handling

```ruby
# Before — exception-based control flow
def verify_gem(gem_name)
  begin
    result = query_context7(gem_name)
    cache_result(result)
    result
  rescue NetworkError => e
    logger.error("Network failure: #{e.message}")
    nil
  rescue CacheError => e
    logger.error("Cache failure: #{e.message}")
    nil
  end
end

# After — railway-oriented programming with Result monad
require "dry/monads"

class GemVerifier
  include Dry::Monads[:result]
  
  def verify_gem(gem_name)
    query_context7(gem_name)
      .bind { |result| cache_result(result) }
      .or { |error| log_and_fail(error) }
  end
  
  private
  
  def query_context7(gem_name)
    Success(api.query(gem_name))
  rescue NetworkError => e
    Failure([:network_error, e.message])
  end
  
  def cache_result(result)
    Success(cache.write(result))
  rescue CacheError => e
    Failure([:cache_error, e.message])
  end
  
  def log_and_fail(error)
    error_type, message = error
    logger.error("verification_failed", { error_type: error_type, message: message })
    Failure(error)
  end
end

# Usage:
# verifier.verify_gem("sequel").value_or { |error| handle_failure(error) }
```

**Benefits**:
- Error paths are explicit and composable
- No hidden control flow via exceptions
- Callers must handle both Success and Failure cases
- Natural chaining with `.bind`, `.or`, `.fmap`

---

## global_constant_to_config
**Severity:** WARNING
**Area:** architecture

```ruby
# Before — global constants scattered across codebase
# lib/my_app/llm_client.rb
API_KEY = ENV["OPENAI_API_KEY"]
MAX_TOKENS = 4096

# lib/my_app/database.rb
DATABASE_URL = ENV["DATABASE_URL"]

# lib/my_app/cache.rb
REDIS_URL = ENV["REDIS_URL"] || "redis://localhost:6379"

# After — centralized Config class with validation
# lib/my_app/config.rb
require "dotenv/load"
require "dry-struct"

module MyApp
  class Config < Dry::Struct
    attribute :openai_api_key, Types::String
    attribute :anthropic_api_key, Types::String.optional
    attribute :database_url, Types::String
    attribute :redis_url, Types::String.default("redis://localhost:6379")
    attribute :max_tokens, Types::Integer.default(4096)
    attribute :log_level, Types::String.default("INFO")
    
    # Singleton instance
    def self.instance
      @instance ||= new(
        openai_api_key: ENV.fetch("OPENAI_API_KEY"),
        anthropic_api_key: ENV["ANTHROPIC_API_KEY"],
        database_url: ENV.fetch("DATABASE_URL"),
        redis_url: ENV.fetch("REDIS_URL", "redis://localhost:6379"),
        max_tokens: ENV.fetch("MAX_TOKENS", "4096").to_i,
        log_level: ENV.fetch("LOG_LEVEL", "INFO")
      )
    end
    
    # Validation on instantiation
    def self.validate!
      instance # Will raise KeyError if required ENV vars missing
    end
  end
end

# Usage:
# MyApp::Config.validate! # Call at app startup
# config = MyApp::Config.instance
# client = OpenAI::Client.new(api_key: config.openai_api_key)
```

**Benefits**:
- Single source of truth for configuration
- Type-safe with defaults
- Fails fast on missing required vars
- Easy to test (inject mock Config)

---

## manual_logging_to_journald
**Severity:** ERROR
**Area:** logging

```ruby
# Before — inconsistent logging approaches
puts "Starting pipeline"
STDERR.puts "Error: #{e.message}"
@logger.info("Completed") if @logger
File.open("log/app.log", "a") { |f| f.puts log_entry }

# After — standardized journald-logger
require "journald/logger"

module MyApp
  def self.logger
    @logger ||= Journald::Logger.new("my_app")
  end
end

# Structured logging with metadata
MyApp.logger.info("pipeline_started", {
  correlation_id: correlation_id,
  document_count: docs.size
})

MyApp.logger.error("processing_failed", {
  correlation_id: correlation_id,
  error_class: e.class.name,
  error_message: e.message,
  backtrace: e.backtrace.first(5)
})

MyApp.logger.info("pipeline_completed", {
  correlation_id: correlation_id,
  duration_ms: elapsed_ms,
  documents_processed: processed_count
})

# Query with journalctl
# journalctl -t my_app -o json-pretty
# journalctl -t my_app CORRELATION_ID=550e8400
```

**Benefits**:
- Systemd-native integration
- Structured metadata (queryable)
- Automatic log rotation
- No file I/O in application code
- Correlation ID tracking across services

---

## no_gemfile_to_rubysmith
**Severity:** CRITICAL
**Area:** architecture

```ruby
# Before — flat directory with scattered scripts
my_project/
├── script1.rb  # require "sequel"
├── script2.rb  # require "dry-struct"
├── utils.rb
└── README.md

# Dependencies only in comments:
# script1.rb:
# gem install sequel sqlite3
require "sequel"
DB = Sequel.connect("sqlite://data.db")

# After — proper gem structure via rubysmith
# Step 1: Generate scaffold
$ cd ~/projects
$ rubysmith build my_project \
    --zeitwerk \
    --rspec \
    --docker \
    --git_hub_ci

# Step 2: Add dependencies to Gemfile
# Gemfile:
source "https://rubygems.org"

gem "sequel", "~> 5.73"
gem "sqlite3", "~> 1.6"
gem "dry-struct", "~> 1.6"
gem "dry-types", "~> 1.7"
gem "journald-logger", "~> 2.1"

group :development, :test do
  gem "pry", "~> 0.14"
  gem "pry-byebug", "~> 3.10"
end

# Step 3: Migrate scripts to lib/
lib/my_project/
├── database.rb         # Sequel connection
├── models/
│   └── record.rb       # dry-struct models
├── scripts/
│   ├── script1.rb      # Original script1
│   └── script2.rb      # Original script2
└── my_project.rb       # Main entry point with Zeitwerk loader

# Step 4: Setup autoloading
# lib/my_project.rb:
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.setup

module MyProject
  # ...
end

# Step 5: Verify
$ bin/setup
$ bin/console
pry> MyProject::Database.connect
pry> MyProject::Models::Record.new(...)
```

**Benefits**:
- Explicit dependency management (no "gem install" comments)
- Zeitwerk autoloading (no require_relative)
- Proper test suite (RSpec)
- CI/CD pipeline (GitHub Actions)
- Docker support for deployment
- Interactive console (Pry)

**When to apply**:
- 3+ Ruby files in same directory
- Dependencies mentioned in comments
- No Gemfile present
- Using require_relative between files
- No test suite

---

**Last Updated**: 2026-05-25  
**Version**: 2.0.0  
**New Patterns**: 5 added for RubyDevV2 standards

---

## extract_class
**Severity:** HIGH
**Area:** ood
When a class description needs "and"/"or", extract the second responsibility. Warrant: SRP (ood-principles.md).

```ruby
# Before
class Gear
  def initialize(chainring:, cog:, rim:, tire:)
    @chainring, @cog, @rim, @tire = chainring, cog, rim, tire
  end

  def gear_inches = ratio * (@rim + (@tire * 2))  # wheel math inside Gear
end

# After
Wheel = Data.define(:rim, :tire) do
  def diameter = rim + (tire * 2)
end

class Gear
  def initialize(chainring:, cog:, wheel:)
    @chainring, @cog, @wheel = chainring, cog, wheel
  end

  def gear_inches = ratio * @wheel.diameter
end
```

---

## inject_dependency
**Severity:** HIGH
**Area:** ood
Hardcoded class name inside a method couples to name, messages, and construction. Inject the collaborator via keyword argument. Warrant: Dependency Checklist items 1-4.

```ruby
# Before
def gear_inches
  ratio * Wheel.new(rim, tire).diameter
end

# After
def initialize(wheel:, ...)
  @wheel = wheel
end

def gear_inches
  ratio * @wheel.diameter
end
```

---

## isolate_class_reference
**Severity:** MEDIUM
**Area:** ood
When injection isn't feasible (framework constraints), quarantine the class name in one factory method so only one line knows it.

```ruby
# Before
def gear_inches = ratio * Wheel.new(rim, tire).diameter

# After
def gear_inches = ratio * wheel.diameter

private

def wheel = @wheel ||= Wheel.new(rim, tire)
```

---

## demeter_chain
**Severity:** MEDIUM
**Area:** ood
Train wrecks couple the caller to the whole intermediate object graph. Ask the nearest neighbor for what you want. Warrant: Law of Demeter.

```ruby
# Before
customer.bicycle.wheel.rotate

# After — Customer exposes intent; each object forwards to its neighbor
customer.ride
```

---

## type_switch_to_duck_type
**Severity:** HIGH
**Area:** ood
A case/respond_to?/is_a? chain switching on type hides a duck. Define one message; let each player implement it. Warrant: Duck Typing.

```ruby
# Before
def prepare(preparers)
  preparers.each do |p|
    case p
    when Mechanic  then p.prepare_bicycles(bicycles)
    when TripCoordinator then p.buy_food(customers)
    end
  end
end

# After
def prepare(preparers)
  preparers.each { |p| p.prepare_trip(self) }
end
# each preparer implements prepare_trip(trip), pulling what it needs
```

---

## inheritance_to_composition
**Severity:** HIGH
**Area:** ood
Subclasses that override to remove/ignore superclass behavior signal a broken is-a. Compose parts instead. Warrant: Choosing Relationships table.

```ruby
# Before
class RoadBike < Bicycle
  def spares = super.merge(tape_color: tape_color) # every subclass must remember super
end

# After
class Bicycle
  def initialize(parts:) = @parts = parts
  def spares = @parts.spares
end
# Parts built by a factory from config; no hierarchy to coordinate
```

---

## super_to_hook_methods
**Severity:** MEDIUM
**Area:** ood
Forcing subclasses to call super couples them to the superclass algorithm's order. Superclass sends hooks with no-op defaults. Warrant: Template Method + Hook Methods.

```ruby
# Before
class RoadBike < Bicycle
  def initialize(**opts)
    @tape_color = opts[:tape_color]
    super  # forgetting this breaks everything
  end
end

# After
class Bicycle
  def initialize(**opts)
    # common setup...
    post_initialize(**opts)
  end

  def post_initialize(**) = nil  # hook, no-op default
end

class RoadBike < Bicycle
  def post_initialize(tape_color:, **) = @tape_color = tape_color
end
```

---

## retry_without_backoff
**Severity:** HIGH
**Area:** resilience
Immediate retries on transient errors hammer a recovering service (thundering herd). Exponential backoff with jitter; rescue only transient error classes.

```ruby
# Before
begin
  response = http_call
rescue StandardError
  retry
end

# After
retries = 0
begin
  response = http_call
rescue Errno::ETIMEDOUT, Net::OpenTimeout => e
  retries += 1
  raise if retries > 4
  wait = (2**retries) * 0.5
  sleep(wait / 2 + rand(wait / 2))  # jitter prevents synchronized retries
  retry
end
```

---

## hot_loop_exception_backtrace
**Severity:** MEDIUM
**Area:** resilience
Backtrace capture dominates raise cost. In hot loops where exceptions are frequent/expected, raise backtraceless.

```ruby
# Before (in a loop called millions of times)
raise ArgumentError, "invalid row"

# After
EMPTY_ARRAY = [].freeze
raise ArgumentError, "invalid row", EMPTY_ARRAY
```

---

## fail_open_authorization
**Severity:** CRITICAL
**Area:** resilience
Boolean auth checks fail open: forget the `if` and access is granted. Raise on denial so failure cannot be ignored.

```ruby
# Before
def authorized?(user, action)
  policy(user).allows?(action)
rescue StandardError
  false  # caller may never check
end

# After
class UnauthorizedError < StandardError; end

def authorize!(user, action)
  raise UnauthorizedError, "#{user.id} denied #{action}" unless policy(user).allows?(action)
end
```

---

## boolean_save_to_bang
**Severity:** HIGH
**Area:** resilience
`model.save` returning false is fail-open: unchecked, execution continues as if persisted. Prefer bang methods that raise; pair with DB constraints (NOT NULL, FK, UNIQUE) as the real integrity layer.

```ruby
# Before
model.save
send_confirmation_email  # runs even when save failed

# After
model.save!              # raises on failure
send_confirmation_email
```
