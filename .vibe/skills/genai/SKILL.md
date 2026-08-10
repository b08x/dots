---
name: genai
description: "Use when scaffolding AI/RAG components in Ruby - retrieval pipeline architecture, LLM agents, neuro-symbolic processors, MCP servers, pgvector integration. Prioritizes clause-level granularity (SFL), RRF hybrid retrieval, and verified gem APIs (dspy.rb, fast-mcp). For the LLM client itself see ruby-llm; for tokenization/tagging/lexical tools see ruby-nlp."
user-invocable: true
---

# RubyDev GenAI — AI/NLP Component Scaffolding

## Overview

This skill scaffolds **AI/NLP components** in Ruby with verified APIs and architectural best practices. It embodies "The Cognitive Architect" persona: structured, modern, and evidence-based. This skill implements **Systemic Functional Linguistics (SFL)** principles for clause-level semantic processing and **Reciprocal Rank Fusion (RRF)** for hybrid retrieval.

**Core Mandate**: Treat the clause, not the document, as the primary unit of meaning.

## When to Use

- **RAG pipelines**: Retrieval-Augmented Generation with pgvector
- **LLM agents**: Chatbots, tool-using agents, multi-agent systems
- **Embeddings**: Semantic search, similarity scoring, clustering
- **MCP servers**: Model Context Protocol tool servers
- **Neuro-symbolic**: Combining neural (LLMs) with symbolic (knowledge graphs)
- **DSPy workflows**: Structured prompting and optimization
- **Hybrid retrieval**: Semantic + keyword search with RRF

**Don't use for:**
- **General Ruby code** (use the [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md))
- **Data pipelines without AI** (use [data-engineer/SKILL.md](~/.vibe/skills/data-engineer/SKILL.md))
- **Frontend AI clients** (this is for Ruby backends)
- **Python AI code** (this is Ruby-specific)
- **The `ruby_llm` client itself** — chat/tool-calling/streaming/embeddings API, circuit breakers and OpenTelemetry tracing around it, Rails persistence, MCP client integration — use [ruby-llm/SKILL.md](~/.vibe/skills/ruby-llm/SKILL.md); this skill treats `ruby_llm` as the LLM client its pipelines call, but doesn't own that client's API surface
- **Tokenization, sentence segmentation, POS/dependency tagging, WordNet lookup, fuzzy/TF-IDF/BM25 scoring, topic modeling, or transformer inference** — use [ruby-nlp/SKILL.md](~/.vibe/skills/ruby-nlp/SKILL.md); this skill's clause-level pipeline consumes those tools but doesn't own their API surface

## Required Gems

All gems listed below MUST have their API verified via Context7 MCP (or DeepWiki for the gem's GitHub repo) **at the point of use** — there is no central registry or verification skill to dispatch to. Query inline before writing code against any of these. For the `ruby_llm` client gem itself and its ecosystem (tool calling, streaming, structured output, Rails/MCP integration, tracing), see [ruby-llm/SKILL.md](~/.vibe/skills/ruby-llm/SKILL.md)'s own gem table instead. For tokenization, tagging, lexical, or scoring gems, see [ruby-nlp/SKILL.md](~/.vibe/skills/ruby-nlp/SKILL.md)'s own gem table instead.

| Gem | Purpose | Context7 Library ID | Status |
|:----|:--------|:-------------------|:-------|
| `pgvector` | Vector embeddings in PostgreSQL | `/pgvector/pgvector-ruby` | ✅ Verified |
| `sequel` | Database abstraction | `/jeremyevans/sequel` | ✅ Verified |
| `fast-mcp` | MCP server framework | `/tompng/fast-mcp` | ✅ Verified |
| `dspy.rb` | Structured prompting (Ruby port) | `/vicentereig/dspy.rb` | ✅ Verified |
| `circuit_breaker` | Fault tolerance | `/wsargent/circuit_breaker` | ✅ Verified |
| `journald-logger` | Structured logging | `/theforeman/journald-logger` | ✅ Verified |
| `dotenv` | Environment variables | `/bkeepers/dotenv` | ✅ Verified |
| `dry-struct` | Type-safe structs | `/dry-rb/dry-struct` | ✅ Verified |
| `dry-types` | Type system | `/dry-rb/dry-types` | ✅ Verified |
| `pry` | REPL/debugging | `/websites/rdoc_info_github_pry_pry_master` | ✅ Verified |

**Prerequisites**:
1. Verify each gem's API inline via Context7 MCP before use (no central dispatch step)
2. Set environment variables (see `~/.vibe/skills/ruby-dev/references/environment-variables.md`)
3. Configure logging (see `~/.vibe/skills/ruby-dev/references/logging-patterns.md`)
4. For the LLM client itself (configuration, tool calling, tracing), see [ruby-llm/SKILL.md](~/.vibe/skills/ruby-llm/SKILL.md)

---

## Project Setup

See [references/project-setup.md](~/.vibe/skills/genai/references/project-setup.md) for the Gemfile, environment variable setup (`.env` / `.env.example`), and application bootstrap/config validation pattern.

---

## Architectural Principles

### 1. Clause-Level Granularity (SFL)

**Not This** (document-level chunking):
```ruby
# Bad: Treating documents as atomic units
embeddings = documents.map { |doc| embed(doc.full_text) }
```

**This** (clause-level processing):
```ruby
# Good: Treating clauses as primary units
clauses = documents.flat_map { |doc| segment_into_clauses(doc) }
embeddings = clauses.map do |clause|
  {
    clause_id: clause.id,
    text: clause.text,
    embedding: embed(clause.text),
    pos_tags: clause.pos_tags,      # Coarse
    fine_tags: clause.fine_tags,    # Fine-grained (tag_)
    dependencies: clause.dependencies
  }
end
```

**Why**: Clauses capture propositional content better than arbitrary character chunks or full documents.

`segment_into_clauses` and the `pos_tags`/`fine_tags`/`dependencies` fields are produced by a sentence segmenter and a POS/dependency tagger — see [ruby-nlp/SKILL.md](~/.vibe/skills/ruby-nlp/SKILL.md) ("Segment text into sentences" and "Tag part-of-speech, parse dependencies, extract entities") for the actual `pragmatic_segmenter`/`ruby-spacy` calls. This principle is about *why* the pipeline chunks at clause granularity, not which gem produces the clause boundaries.

### 2. Hybrid Retrieval with RRF

**Reciprocal Rank Fusion** formula:
```ruby
RRF_score = 1.0 / (60 + rank)
```

**Implementation**:
```ruby
# Semantic search (pgvector)
semantic_results = DB[:embeddings]
  .order(Sequel.lit("embedding <=> ?", query_embedding))
  .limit(100)
  .select(:clause_id, Sequel.lit("ROW_NUMBER() OVER (ORDER BY embedding <=> ?) AS rank", query_embedding))

# Keyword search (full-text)
keyword_results = DB[:clauses]
  .where(Sequel.ilike(:text, "%#{query}%"))
  .select(:clause_id, Sequel.lit("ROW_NUMBER() OVER (ORDER BY ts_rank(tsv, plainto_tsquery(?)) DESC) AS rank", query))

# Merge with RRF
merged = DB.from(
  semantic_results.full_outer_join(keyword_results, clause_id: :clause_id)
).select(
  Sequel.lit("COALESCE(semantic.clause_id, keyword.clause_id) AS clause_id"),
  Sequel.lit("(1.0 / (60 + COALESCE(semantic.rank, 100))) + (1.0 / (60 + COALESCE(keyword.rank, 100))) AS rrf_score")
).order(Sequel.desc(:rrf_score))
```

**Why**: RRF outperforms pure semantic or pure keyword search for most retrieval tasks.

The keyword arm above uses Postgres's `ts_rank`/`plainto_tsquery`. When Postgres full-text search isn't available (or the pipeline needs to stay pure-Ruby), [ruby-nlp/SKILL.md](~/.vibe/skills/ruby-nlp/SKILL.md)'s `bm25f` or `tf-idf-similarity` gems can compute the same kind of relevance score in-process instead — the RRF merge logic above is unchanged either way, only the source of `keyword_rank` differs.

### 3. Circuit Breaker for LLM Calls

**Always wrap external LLM APIs**:
```ruby
require "circuit_breaker"

circuit = CircuitBreaker.new(
  threshold: 5,         # Open after 5 failures
  timeout: 30,          # 30 seconds timeout
  reevaluate_after: 60  # Check again after 60s
)

response = circuit.call do
  llm.complete(prompt: prompt, max_tokens: 500)
end
```

**Why**: LLM APIs fail (rate limits, timeouts, outages). Circuit breakers prevent cascading failures.

### 4. Structured Logging for AI Pipelines

```ruby
require "journald/logger"

logger = Journald::Logger.new("rag_pipeline")

logger.info("embedding_generated", {
  clause_id: clause.id,
  model: "text-embedding-ada-002",
  latency_ms: elapsed_ms,
  token_count: tokens
})
```

**Why**: AI pipelines need observability. Log inputs, outputs, latency, token counts, and errors.

### 5. Distributed Tracing for LLM Calls

A RAG pipeline has too many hops (retrieve, rerank, generate, tool-call) for latency logs alone to localize a slowdown — wrap each pipeline stage in its own OpenTelemetry span so the waterfall is visible across hops in one view (Honeycomb, Jaeger, Tempo, etc.), not just inside the LLM call itself. If the LLM client is `ruby_llm`, its auto-instrumentation gem and the exact tracing setup are covered in [ruby-llm/SKILL.md](~/.vibe/skills/ruby-llm/SKILL.md) — this pipeline only needs its own outer spans around retrieve/rerank/generate/tool-call, the LLM call's own child span comes from that instrumentation.

## Component Templates

See [references/component-templates.md](~/.vibe/skills/genai/references/component-templates.md) for three full scaffolds: a RAG pipeline with pgvector (schema, embedder, retriever), an MCP server with tools, and DSPy-style structured prompting.

## Integration Patterns

### Pattern 1: RAG + MCP Server

```ruby
# Expose RAG pipeline as MCP tools
server = MyApp::MCP::Server.new(port: 8080)

server.register_tool(MyApp::MCP::Tools::Search.new(
  retriever: MyApp::RAG::Retriever.new(db: DB, embedder: embedder)
))

server.start
```

### Pattern 2: Async Embedding Generation

```ruby
require "async"

Async do
  clauses.each_slice(10) do |batch|
    Async do
      batch.each do |clause|
        embedding = embedder.embed(clause.text)
        DB[:embeddings].insert(
          clause_id: clause.id,
          embedding: embedding,
          model: "text-embedding-ada-002",
          created_at: Time.now
        )
      end
    end
  end
end
```

### Pattern 3: Neuro-Symbolic with Knowledge Graph

```ruby
# Combine neural retrieval with symbolic reasoning
results = retriever.retrieve(query)

# Expand with graph relationships
expanded = results.flat_map do |result|
  clause = result[:clause_id]
  related = graph.neighbors(clause, max_hops: 2)
  [result] + related
end

# Re-rank with hybrid score
reranked = expanded.map do |item|
  {
    **item,
    final_score: (item[:rrf_score] * 0.7) + (item[:graph_score] * 0.3)
  }
end.sort_by { |i| -i[:final_score] }
```

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| Context7 / DeepWiki | Both unreachable | Skip gem verification. Output code with `[WARNING: APIs unverified]` annotation on every non-stdlib gem call. Append a summary of unverified gems at the end of the response. |
| `circuit_breaker` gem | Not in Gemfile or unavailable | Wrap external calls in a plain `begin/rescue/retry` block with max 3 retries and exponential backoff instead. Document the missing circuit breaker as a tech debt note. |
| `opentelemetry-instrumentation-ruby_llm` / `opentelemetry-sdk` | Not in Gemfile or unavailable | Fall back to structured logging alone (latency, tokens, model already captured by the `journald-logger` calls). Note in the output that distributed tracing is unavailable, so multi-hop latency must be reconstructed manually from log timestamps. |

## Common Pitfalls

1. **Skipping verification.** Generating code with unverified gem APIs is the #1 source of hallucinated Ruby code.

2. **Pure semantic search without keyword fallback.** RRF hybrid retrieval is more robust.

3. **Not wrapping LLM calls in circuit breakers.** One API outage shouldn't crash your entire pipeline.

4. **Ignoring token limits.** Count tokens before sending to LLM. Truncate or summarize if needed.

5. **Hardcoding API keys.** Always use `ENV["OPENAI_API_KEY"]`, never commit secrets.

6. **Not caching embeddings.** Re-embedding the same text is expensive. Use database cache.

7. **Blocking I/O in tight loops.** Use `Async {}` for concurrent embedding generation.

8. **No observability.** Log every LLM call with latency, token count, and cost estimates.

9. **Tracing the LLM call but not the pipeline around it.** An LLM client's own instrumentation (see [ruby-llm/SKILL.md](~/.vibe/skills/ruby-llm/SKILL.md) if using `ruby_llm`) auto-traces the API call itself; if you don't also wrap the surrounding retrieve/rerank/generate steps in your own spans, you still can't see where time went across the whole pipeline — only inside the LLM call.

## Verification Checklist

- [ ] All non-stdlib gem APIs verified inline via Context7/DeepWiki before use
- [ ] Clause-level granularity implemented (not document-level)
- [ ] RRF hybrid retrieval used (not pure semantic or pure keyword)
- [ ] Circuit breakers wrap all LLM API calls
- [ ] Structured logging with Journald (includes latency, tokens, model)
- [ ] OpenTelemetry spans wrap each pipeline stage (retrieve, rerank, generate, tool call) — see [ruby-llm/SKILL.md](~/.vibe/skills/ruby-llm/SKILL.md) for the LLM call's own instrumentation
- [ ] API keys loaded from ENV (not hardcoded)
- [ ] Embeddings cached in database (not re-generated on every query)
- [ ] Async used for concurrent operations (embedding generation, batch processing)
- [ ] pgvector indexes created (ivfflat or hnsw for vector columns)
- [ ] Full-text search indexes created (GIN for tsvector columns)
