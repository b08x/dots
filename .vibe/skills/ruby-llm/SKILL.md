---
name: ruby-llm
description: "Use for the RubyLLM gem ecosystem in Ruby - unified multi-provider chat/completion API, tool calling, streaming, embeddings, image generation, structured output (ruby_llm-schema), Rails persistence (ruby_llm-rails), and MCP client integration (ruby_llm-mcp). Trigger on 'ruby_llm', 'RubyLLM.chat', 'LLM client', 'tool calling', 'function calling', 'structured output', 'acts_as_chat', 'MCP client'."
user-invocable: true
---

# RubyDev Ruby-LLM — RubyLLM Gem Ecosystem

## Overview

This skill covers the **`ruby_llm`** gem ecosystem (`crmne/ruby_llm`, docs at rubyllm.com): a single, provider-agnostic Ruby API for OpenAI, Anthropic, Gemini, Ollama, DeepSeek, Bedrock, OpenRouter, Perplexity, Mistral, and any OpenAI-compatible custom endpoint. It embodies "The LLM Integrator" persona: one client interface, swappable providers, typed tool calls, and durable observability around every external call.

**Core Mandate**: Write LLM-calling code against `RubyLLM`'s unified API, never against a provider SDK directly — provider choice becomes a configuration change, not a rewrite.

**⚠️ Verification notice**: The API shapes documented here (method names, class structure, gem list) are from training knowledge and have **not** been re-verified against current docs in this session — the Context7/DeepWiki fetch path was unavailable when this skill was written. Before writing production code against any `ruby_llm*` gem, verify the exact API inline via Context7 MCP (library ID `/crmne/ruby_llm`, confirmed by the user) or DeepWiki, per this plugin's standing verification mandate. Treat every code sample below as "shape, not gospel" until verified.

## When to Use

- Calling any LLM provider from Ruby (chat, completion, streaming)
- Defining tools/functions the LLM can call
- Generating embeddings or images through a unified client
- Requesting structured (schema-constrained) output from an LLM
- Persisting chat history to ActiveRecord (Rails apps)
- Connecting a `ruby_llm` chat to external tools via MCP (client side)
- Wrapping LLM calls in circuit breakers and OpenTelemetry tracing

**Don't use for:**
- **RAG architecture, clause-level chunking, RRF hybrid retrieval, pgvector schema design** — use [genai/SKILL.md](~/.vibe/skills/genai/SKILL.md); that skill treats `ruby_llm` as its LLM client but owns the retrieval/storage architecture, not this one
- **Building an MCP *server*** (exposing tools to other clients) — that's `fast-mcp`, covered in [genai/SKILL.md](~/.vibe/skills/genai/SKILL.md); this skill covers the MCP *client* side (`ruby_llm-mcp`, consuming someone else's MCP server as tools)
- **Non-LLM Ruby code** — use the [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md)
- **dspy.rb structured-prompting workflows** — those layer on top of an LLM client but are their own paradigm; see [genai/SKILL.md](~/.vibe/skills/genai/SKILL.md)

## Ecosystem Gems

All gems below MUST have their API verified via Context7 MCP (or DeepWiki) **at the point of use** — there is no central registry or verification step to dispatch to.

| Gem | Purpose | Context7 Library ID | Status |
|:----|:--------|:-------------------|:-------|
| `ruby_llm` | Core unified multi-provider LLM client (chat, tools, streaming, embeddings, images) | `/crmne/ruby_llm` | ✅ Confirmed by user |
| `ruby_llm-mcp` | MCP client — consume external MCP servers' tools inside a `ruby_llm` chat | — | 🔴 To verify |
| `ruby_llm-schema` | Fluent JSON-schema builder for structured LLM output | — | 🔴 To verify |
| `ruby_llm-rails` | Rails integration — `acts_as_chat`, ActiveRecord persistence for chats/messages/tool calls, generators | — | 🔴 To verify |
| `circuit_breaker` | Fault tolerance around external LLM calls | `/wsargent/circuit_breaker` | ✅ Verified |
| `opentelemetry-instrumentation-ruby_llm` | Distributed tracing — auto-instruments `ruby_llm` calls (model, tokens, latency) | `/thoughtbot/opentelemetry-instrumentation-ruby_llm` | ✅ Verified |
| `opentelemetry-sdk` | Core tracer/span provider (hard dependency of the instrumentation gem above) | — | 🔴 To verify |
| `journald-logger` | Structured logging for request/response events | `/theforeman/journald-logger` | ✅ Verified |
| `dotenv` | Environment variable loading for provider API keys | `/bkeepers/dotenv` | ✅ Verified |

**Prerequisites**:
1. Verify each gem's API inline via Context7 MCP before use (no central dispatch step)
2. Set provider API keys as environment variables (see `~/.vibe/skills/ruby-dev/~/.vibe/skills/ruby-llm/references/environment-variables.md`)
3. Configure logging (see `~/.vibe/skills/ruby-dev/~/.vibe/skills/ruby-llm/references/logging-patterns.md`)

**Gemfile fragment** (add only the extensions actually in use — `ruby_llm` itself is the only hard requirement):

```ruby
gem "ruby_llm"
gem "ruby_llm-mcp"      # only if consuming external MCP servers as tools
gem "ruby_llm-schema"   # only if requesting structured/schema-constrained output
gem "ruby_llm-rails"    # only in a Rails app persisting chat history
gem "circuit_breaker"
gem "opentelemetry-sdk"
gem "opentelemetry-instrumentation-ruby_llm"
gem "journald-logger"

group :development, :test do
  gem "dotenv"
end
```

## Configuration

`ruby_llm` is configured once, globally, then used statelessly per call — provider credentials live in one place, not scattered through call sites:

```ruby
# frozen_string_literal: true

require "dotenv/load"
require "ruby_llm"

RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
  # Only set keys for providers actually in use — unset provider keys are fine,
  # RubyLLM only raises if you try to use a provider with no key configured.
end
```

## Core API Surface

### Chat

```ruby
chat = RubyLLM.chat(model: "gpt-4.1-nano")
chat.with_instructions("You are a terse Ruby code reviewer.")

response = chat.ask("Review this method for thread safety: #{method_source}")
puts response.content
```

### Streaming

```ruby
chat.ask("Summarize this codebase") do |chunk|
  print chunk.content
end
```

### Tool Calling

Define a tool as a class; `RubyLLM` handles the call/response round-trip:

```ruby
class SearchCodebase < RubyLLM::Tool
  description "Search the local codebase for a symbol or pattern"

  param :query, desc: "Search term or regex pattern"
  param :limit, desc: "Max results", required: false

  def execute(query:, limit: 10)
    Grep.search(query, limit: limit).map { |m| { file: m.file, line: m.line, text: m.text } }
  end
end

chat = RubyLLM.chat(model: "claude-sonnet-4").with_tool(SearchCodebase)
chat.ask("Find where UserSession is defined")
```

`execute`'s return value must be JSON-serializable (Hash/Array/String/Numeric) — the tool's return value is round-tripped back to the model as the tool result. Don't return a domain object; map it to plain data first.

### Embeddings

```ruby
result = RubyLLM.embed("The quick brown fox", model: "text-embedding-3-small")
result.vectors # => Array of Float
```

### Structured Output

```ruby
require "ruby_llm/schema"

class ReviewSchema < RubyLLM::Schema
  string :verdict, enum: %w[approve request_changes]
  array :issues do
    object do
      string :file
      integer :line
      string :description
    end
  end
end

response = chat.with_schema(ReviewSchema).ask("Review this diff: #{diff}")
response.content # parsed against the schema, not raw text
```

### Image Generation

```ruby
image = RubyLLM.paint("a diagram of a hexagonal architecture, technical illustration style")
image.url # or image.save("architecture.png") depending on the gem's actual return shape — verify before relying on either
```

## Resilience: Circuit Breaker

Wrap every external `ruby_llm` call — provider outages and rate limits are a "when," not an "if":

```ruby
require "circuit_breaker"

circuit = CircuitBreaker.new(threshold: 5, timeout: 30, reevaluate_after: 60)

response = circuit.call { chat.ask(prompt) }
```

## Observability: OpenTelemetry Tracing

Structured logs tell you *that* a call happened; traces tell you *where it sat* in a multi-step pipeline (retrieval → rerank → LLM call → tool call) and how latency breaks down across hops. Use `opentelemetry-instrumentation-ruby_llm` to auto-instrument `ruby_llm` calls instead of hand-rolling spans:

```ruby
require "opentelemetry/sdk"
require "opentelemetry/instrumentation/ruby_llm"

OpenTelemetry::SDK.configure do |c|
  c.service_name = "my_app"
  c.use "OpenTelemetry::Instrumentation::RubyLLM"
end

tracer = OpenTelemetry.tracer_provider.tracer("my_app")

tracer.in_span("agent.answer_question") do |span|
  span.set_attribute("question_length", question.length)

  response = circuit.call { chat.ask(question) } # auto-traced child span from the instrumentation gem

  span.set_attribute("response_length", response.content.length)
  response
end
```

The instrumentation gem creates its own child span around the actual API call (model, token usage, latency) — you only need an outer `in_span` for the surrounding business operation (a tool call, an agent turn, a retrieval step), not for the LLM call itself.

**Pairs with, doesn't replace, structured logging**: keep emitting `journald-logger` events for business-significant facts (which model, which user, success/failure) — traces are for latency/causality across hops, logs are for searchable, durable event records.

## Rails Integration (`ruby_llm-rails`)

For persisting chat history as ActiveRecord models rather than hand-rolling `Chat`/`Message`/`ToolCall` tables:

```ruby
class Conversation < ApplicationRecord
  acts_as_chat # provides #ask, #with_tool, persisted message history, etc.
end

conversation = Conversation.create!(user: current_user)
conversation.ask("What's the status of order #1234?")
conversation.messages # ActiveRecord-persisted, not in-memory only
```

Verify the generator names and exact migration shape via Context7 before running — `acts_as_chat`'s underlying schema (message roles, tool_call associations) is exactly the kind of detail that drifts between gem versions.

## MCP Client (`ruby_llm-mcp`)

Consume an external MCP server's tools inside a `ruby_llm` chat, without hand-writing `RubyLLM::Tool` subclasses for each one:

```ruby
require "ruby_llm/mcp"

client = RubyLLM::MCP::Client.new(url: "http://localhost:8080")
chat = RubyLLM.chat(model: "gpt-4.1").with_tools(*client.tools)

chat.ask("Search the knowledge base for pricing tiers")
```

This is the client-side counterpart to a `fast-mcp`-built server (see [genai/SKILL.md](~/.vibe/skills/genai/SKILL.md) for building the server). A single app can be both: expose its own domain as an MCP server via `fast-mcp`, and separately consume other MCP servers as a client via `ruby_llm-mcp`.

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| Context7 / DeepWiki | Both unreachable | Skip gem verification. Output code with `[WARNING: APIs unverified]` annotation on every non-stdlib gem call. Append a summary of unverified gems at the end of the response. |
| `circuit_breaker` gem | Not in Gemfile or unavailable | Wrap external calls in a plain `begin/rescue/retry` block with max 3 retries and exponential backoff instead. Document the missing circuit breaker as a tech debt note. |
| `opentelemetry-instrumentation-ruby_llm` / `opentelemetry-sdk` | Not in Gemfile or unavailable | Fall back to structured logging alone (latency, tokens, model captured by `journald-logger` calls instead). Note that multi-hop latency must be reconstructed manually from log timestamps. |
| `ruby_llm-mcp` | Not in Gemfile or unavailable | Hand-write `RubyLLM::Tool` subclasses that shell out to the MCP server's HTTP endpoint directly, or vendor the specific tools needed rather than the whole client. |

## Common Pitfalls

1. **Calling a provider SDK directly instead of `RubyLLM`.** Defeats the entire point of the abstraction — provider swaps become rewrites instead of config changes.
2. **Skipping API verification.** Generating code against unverified gem APIs is the #1 source of hallucinated Ruby code — this is especially true here, since this skill's own examples are unverified as written (see the notice above).
3. **Returning a domain object from a `Tool#execute`.** The result must be JSON-serializable; map to a plain Hash/Array before returning.
4. **Not wrapping calls in a circuit breaker.** One provider outage or rate-limit spike shouldn't crash the whole request path.
5. **Tracing the LLM call but not the pipeline around it.** The instrumentation gem auto-traces the API call itself; without an outer span around the surrounding business operation, you still can't see where time went across a multi-hop flow.
6. **Hardcoding API keys.** Always load provider keys from `ENV`, never commit them — configure once via `RubyLLM.configure`, not inline per call.
7. **Assuming `ruby_llm-schema` output is pre-validated against arbitrary constraints.** It shapes the *format* the model must return; it doesn't replace domain validation (range checks, business rules) on the parsed result.

## Verification Checklist

- [ ] All `ruby_llm*` gem APIs verified inline via Context7 (`/crmne/ruby_llm`) or DeepWiki before relying on this skill's examples
- [ ] Provider keys loaded from `ENV` via `RubyLLM.configure`, not hardcoded or passed per-call
- [ ] Tool `execute` methods return JSON-serializable data, not domain objects
- [ ] Circuit breaker wraps every external `ruby_llm` call
- [ ] OpenTelemetry tracing configured with the `ruby_llm` instrumentation, plus outer spans around each surrounding pipeline stage
- [ ] Structured logging captures model, tokens, latency, and success/failure for every call
- [ ] If using `ruby_llm-rails`: persisted chat schema verified against the gem's actual generator output, not assumed
- [ ] If using `ruby_llm-mcp`: distinguished clearly from `fast-mcp` (server-side) in code comments/naming, since both terms are "MCP" but opposite roles
