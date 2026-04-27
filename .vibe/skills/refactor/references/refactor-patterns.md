# Refactor Patterns

Named patterns for rubysmithing-refactor. Each entry maps a `pattern` key
(used in report YAML output) to a before/after transformation.

## Contents
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
