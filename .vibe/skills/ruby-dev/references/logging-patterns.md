---
title: Ruby Logging Patterns - Structured & Actionable
version: 1.0.0
last_updated: 2026-05-25
maintained_by: Syncopated Context
standard_logger: journald-logger
---

# Ruby Logging Patterns - Structured & Actionable

## Overview

**Standard Logger**: All ruby-dev skills MUST use `journald-logger` for structured logging.

**Rule**: Every external call (LLM, database, Redis, HTTP) MUST be logged with structured context.

**Principles**:
1. **Structured, not strings**: Use key-value pairs, not interpolated messages
2. **Actionable context**: Include request ID, user ID, trace ID
3. **Performance metrics**: Log latency, token count, cost estimates
4. **Error details**: Include error class, message, backtrace (truncated)

---

## Logger Setup

**Required Gem**: `journald-logger` (`/theforeman/journald-logger`)

### Standard Pattern

```ruby
# frozen_string_literal: true

require "journald/logger"

module MyApp
  def self.logger
    @logger ||= Journald::Logger.new("my_app")
  end
end

# Usage
MyApp.logger.info("request_started", {
  request_id: SecureRandom.uuid,
  path: "/api/search",
  method: "POST"
})
```

### Module Mixin Pattern

```ruby
# frozen_string_literal: true

require "journald/logger"

module MyApp
  module Logging
    def logger
      @logger ||= Journald::Logger.new(self.class.name.downcase)
    end
  end
end

class MyService
  include MyApp::Logging
  
  def call
    logger.info("service_called", timestamp: Time.now.to_i)
  end
end
```

### Features

✅ **Native systemd integration**: Logs queryable via `journalctl`  
✅ **Structured fields**: Key-value pairs automatically indexed  
✅ **Tag support**: `logger.tagged("subsystem")` for namespacing  
✅ **Exception handling**: Automatic backtrace logging  
✅ **Trace logging**: Built-in support for request tracing

---

## Logging Patterns

### Pattern 1: LLM API Calls

```ruby
def call_llm(prompt:, model:, max_tokens:)
  start_time = Time.now
  request_id = SecureRandom.uuid
  
  logger.info("llm_request_started", {
    request_id: request_id,
    model: model,
    prompt_length: prompt.length,
    max_tokens: max_tokens
  })
  
  response = llm.complete(prompt: prompt, model: model, max_tokens: max_tokens)
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)
  
  logger.info("llm_request_completed", {
    request_id: request_id,
    model: model,
    tokens_used: response.usage.total_tokens,
    latency_ms: elapsed_ms,
    cost_usd: estimate_cost(model, response.usage.total_tokens)
  })
  
  response
rescue StandardError => e
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)
  
  logger.error("llm_request_failed", {
    request_id: request_id,
    model: model,
    error_class: e.class.name,
    error_message: e.message,
    latency_ms: elapsed_ms,
    backtrace: e.backtrace.first(5)
  })
  
  raise
end
```

**Key Fields**:
- `request_id`: Unique identifier for correlation
- `model`: LLM model name (gpt-4o-mini, claude-sonnet-4)
- `tokens_used`: Total token count (prompt + completion)
- `latency_ms`: Round-trip time in milliseconds
- `cost_usd`: Estimated cost per request

### Pattern 2: Database Queries

```ruby
def query_embeddings(query_embedding:, limit:)
  start_time = Time.now
  query_id = SecureRandom.uuid
  
  logger.info("db_query_started", {
    query_id: query_id,
    operation: "vector_search",
    table: "embeddings",
    limit: limit
  })
  
  results = DB[:embeddings]
    .order(Sequel.lit("embedding <=> ?", query_embedding))
    .limit(limit)
    .all
  
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)
  
  logger.info("db_query_completed", {
    query_id: query_id,
    operation: "vector_search",
    rows_returned: results.size,
    latency_ms: elapsed_ms
  })
  
  results
rescue Sequel::DatabaseError => e
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)
  
  logger.error("db_query_failed", {
    query_id: query_id,
    operation: "vector_search",
    error_class: e.class.name,
    error_message: e.message,
    latency_ms: elapsed_ms
  })
  
  raise
end
```

**Key Fields**:
- `query_id`: Unique identifier
- `operation`: Type of query (vector_search, insert, update)
- `table`: Target table
- `rows_returned`: Result count
- `latency_ms`: Query execution time

### Pattern 3: Circuit Breaker Events

```ruby
require "circuit_breaker"

circuit = CircuitBreaker.new(
  threshold: 5,
  timeout: 30,
  reevaluate_after: 60
)

circuit.on(:open) do
  logger.warn("circuit_breaker_opened", {
    circuit: "llm_api",
    threshold: 5,
    consecutive_failures: circuit.failure_count
  })
end

circuit.on(:close) do
  logger.info("circuit_breaker_closed", {
    circuit: "llm_api"
  })
end

circuit.on(:half_open) do
  logger.info("circuit_breaker_half_open", {
    circuit: "llm_api",
    reevaluate_after: 60
  })
end

begin
  circuit.call do
    call_external_api
  end
rescue CircuitBreaker::OpenError
  logger.error("circuit_breaker_blocked", {
    circuit: "llm_api",
    reason: "circuit_open"
  })
  raise
end
```

**Key Fields**:
- `circuit`: Circuit identifier
- `threshold`: Failure threshold before opening
- `consecutive_failures`: Current failure count
- `reevaluate_after`: Seconds until half-open state

### Pattern 4: Batch Operations

```ruby
def batch_embed(clauses:, batch_size: 10)
  batch_id = SecureRandom.uuid
  total = clauses.size
  
  logger.info("batch_started", {
    batch_id: batch_id,
    operation: "embedding_generation",
    total_items: total,
    batch_size: batch_size
  })
  
  processed = 0
  failures = 0
  
  clauses.each_slice(batch_size) do |batch|
    batch.each do |clause|
      begin
        embed(clause.text)
        processed += 1
      rescue StandardError => e
        failures += 1
        logger.warn("batch_item_failed", {
          batch_id: batch_id,
          clause_id: clause.id,
          error_class: e.class.name,
          error_message: e.message
        })
      end
    end
    
    logger.info("batch_progress", {
      batch_id: batch_id,
      processed: processed,
      total: total,
      failures: failures,
      percent_complete: ((processed.to_f / total) * 100).round(2)
    })
  end
  
  logger.info("batch_completed", {
    batch_id: batch_id,
    processed: processed,
    failures: failures,
    success_rate: ((processed - failures).to_f / processed * 100).round(2)
  })
end
```

**Key Fields**:
- `batch_id`: Unique batch identifier
- `total_items`: Total items to process
- `processed`: Items processed so far
- `failures`: Failed items
- `percent_complete`: Progress percentage

---

## Anti-Patterns

### ❌ Anti-Pattern 1: String Interpolation

```ruby
# Bad
logger.info("User #{user_id} searched for #{query} and got #{results.size} results")
```

**Problem**: Not machine-parseable, no structured queries

```ruby
# Good
logger.info("search_executed", {
  user_id: user_id,
  query: query,
  results_count: results.size
})
```

### ❌ Anti-Pattern 2: Logging Exceptions as Strings

```ruby
# Bad
rescue StandardError => e
  logger.error("Error: #{e.message}")
end
```

**Problem**: Loses backtrace, error class, context

```ruby
# Good
rescue StandardError => e
  logger.error("operation_failed", {
    operation: "embed_generation",
    error_class: e.class.name,
    error_message: e.message,
    backtrace: e.backtrace.first(5)
  })
end
```

### ❌ Anti-Pattern 3: No Performance Metrics

```ruby
# Bad
response = llm.complete(prompt: prompt)
logger.info("LLM call completed")
```

**Problem**: No latency, token count, or cost tracking

```ruby
# Good
start_time = Time.now
response = llm.complete(prompt: prompt)
elapsed_ms = ((Time.now - start_time) * 1000).round(2)

logger.info("llm_completed", {
  model: "gpt-4o-mini",
  tokens: response.usage.total_tokens,
  latency_ms: elapsed_ms,
  cost_usd: estimate_cost("gpt-4o-mini", response.usage.total_tokens)
})
```

### ❌ Anti-Pattern 4: Logging Sensitive Data

```ruby
# Bad
logger.info("user_login", {
  username: username,
  password: password  # NEVER LOG PASSWORDS
})
```

**Problem**: Security breach, compliance violation

```ruby
# Good
logger.info("user_login", {
  username: username,
  auth_method: "password",
  success: true
})
```

---

## Log Levels

| Level | When to Use | Example |
|:------|:------------|:--------|
| **DEBUG** | Development only, verbose | Variable values, control flow |
| **INFO** | Normal operations | Request started, batch progress |
| **WARN** | Degraded but functional | Circuit breaker half-open, fallback used |
| **ERROR** | Operation failed | API call failed, query timeout |
| **FATAL** | System unrecoverable | Database unavailable, config missing |

---

## Querying Logs

### Journald (systemd)

```bash
# All logs for app
journalctl -u my_app.service

# Logs with specific field
journalctl -u my_app.service REQUEST_ID=abc-123

# Logs since timestamp
journalctl -u my_app.service --since "2026-05-25 10:00:00"

# Follow logs in real-time
journalctl -u my_app.service -f
```

### JSON Logs (stdout)

```bash
# Filter by event
cat app.log | jq 'select(.event == "llm_request_completed")'

# Calculate average latency
cat app.log | jq -s 'map(select(.event == "llm_request_completed").latency_ms) | add / length'

# Group by error class
cat app.log | jq -s 'group_by(.error_class) | map({error: .[0].error_class, count: length})'
```

---

## Integration with Skills

### In SKILL.md Procedures

```markdown
## Procedure

1. Initialize logger:
   ```ruby
   logger = MyApp.logger
   ```

2. Log request start:
   ```ruby
   logger.info("operation_started", operation: "rag_query", query: query)
   ```

3. Wrap external calls:
   ```ruby
   start_time = Time.now
   response = llm.complete(prompt: prompt)
   logger.info("llm_completed", latency_ms: (Time.now - start_time) * 1000)
   ```

4. Log errors with context:
   ```ruby
   rescue StandardError => e
     logger.error("operation_failed", error_class: e.class.name, error_message: e.message)
     raise
   end
   ```
```

---

## References

- [Journald Logger](https://github.com/theforeman/journald-logger)
- [Semantic Logger](https://logger.rocketjob.io/)
- [Ruby Logger (stdlib)](https://ruby-doc.org/stdlib/libdoc/logger/rdoc/Logger.html)

---

**Last Updated**: 2026-05-25  
**Next Review**: After implementing logging in all 5 core skills  
**Status**: Active
