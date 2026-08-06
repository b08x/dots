---
name: rubyllm-agentic-workflows
description: "Build RubyLLM agentic workflows: routing, parallel, RAG."
version: 0.1.0
author: Hermes
metadata:
  hermes:
    tags: [RubyLLM, Agentic, Workflows, RAG, Async]
---

# RubyLLM Agentic Workflows

Orchestrate plain Ruby classes that compose `RubyLLM::Agent` calls into repeatable multi-agent pipelines. Covers the five canonical patterns from the RubyLLM guide (sequential, routing, parallel, fan-out/fan-in, evaluator-optimizer) plus a RAG-as-step pattern using `neighbor` + pgvector. Does NOT cover model fine-tuning, multi-modal input pipelines, or production deployment hardening.

Source: https://rubyllm.com/agentic-workflows/

## When to Use

- "Compose multiple LLM calls into a pipeline with Ruby."
- "Build a router that picks the right model per request."
- "Run several agents in parallel with `async` and merge the results."
- "Iterate on a draft with an evaluator-optimizer loop."
- "Add RAG to an existing agent using pgvector."

## Prerequisites

- Ruby 3.x (the guide's examples use Ruby 3.3 features like endless methods).
- Gems: `ruby_llm` (the framework), `async` (required for parallel patterns), `neighbor` (pgvector adapter for the RAG step).
- A configured RubyLLM provider — export at least one of `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, etc., before invoking scripts.
- For the RAG step: PostgreSQL with the `pgvector` extension installed, plus a Rails migration generated via `bin/rails generate neighbor:vector`.

## How to Run

The skill is a code-pattern reference, not a single script. Author each pattern as its own Ruby file (e.g. `workflows/research_writer.rb`) and invoke through the `terminal` tool:

```
ruby workflows/research_writer.rb "Ruby 3.3 features"
```

For Rails-based RAG, drop the model into `app/models/document.rb` and the tool into `app/tools/document_search.rb`, then exercise via `bin/rails runner 'SupportWithDocsAgent.new.ask("...").content'`.

## Quick Reference

- Sequential: chain `Agent.new.ask(input).content` calls.
- Routing: classify first with a small classifier agent, dispatch to a per-category agent class.
- Parallel: `Async do |task| ... task.async { ... }.wait end`.
- Fan-Out/Fan-In: parallel specialists + a synthesizer agent that consumes their outputs.
- Evaluator-Optimizer: `MAX_ROUNDS.times` loop with a critic schema (`verdict`, `feedback`).
- RAG model: `has_neighbors :embedding`, populated via `RubyLLM.embed(content).vectors`.
- RAG retrieval: `Document.nearest_neighbors(:embedding, embedding, distance: "euclidean").limit(3)`.
- Tool class: `RubyLLM::Tool` with `param :name, desc: "..."` and `def execute(name:)`.
- Agent with tool: declare `tools DocumentSearch` inside the agent class.

## Procedure

1. Define each role as a `RubyLLM::Agent` subclass with `model` and `instructions`.
2. Wrap the agents in a plain Ruby class with one public method (e.g. `def call(input)`).
3. Pick a composition pattern from the snippets below; the code is verbatim from the RubyLLM guide.
4. For parallel patterns, `require 'async'` and use `Async do |task| ... task.async { ... }`.
5. For RAG, install `gem 'neighbor'`, generate the pgvector migration, declare `has_neighbors :embedding` on the model, populate embeddings via `RubyLLM.embed`, and expose a `RubyLLM::Tool` that calls `Document.nearest_neighbors`.
6. Invoke the workflow through the `terminal` tool, or `bin/rails runner` for Rails projects.

### Sequential

```ruby
class ResearchAgent < RubyLLM::Agent
  model "gemini-3.1-pro-preview"
  instructions "Given a topic, return concise, reliable key facts."
end

class WriterAgent < RubyLLM::Agent
  model "claude-sonnet-4-6"
  instructions "Given research notes, write a clear article."
end

class ResearchWriterWorkflow
  def create_article(topic)
    research = ResearchAgent.new.ask(topic).content
    WriterAgent.new.ask(research).content
  end
end
```

### Routing

```ruby
class CodeAgent < RubyLLM::Agent
  model "gpt-5.4"
  instructions "You are a coding assistant. Be precise and practical."
end

class CreativeAgent < RubyLLM::Agent
  model "claude-opus-4-6"
  instructions "You are a creative writing assistant."
end

class FactualAgent < RubyLLM::Agent
  model "gemini-3.1-pro-preview"
  instructions "You are a factual assistant. Prioritize accuracy."
end

class TaskClassifierAgent < RubyLLM::Agent
  model "gpt-5-mini"
  instructions "Classify the request as one word only: code, creative, or factual."
end

class ModelRouterWorkflow
  def call(query)
    agent_for(query).new.ask(query).content
  end

  private

  def agent_for(query)
    case classify(query)
    when :code then CodeAgent
    when :creative then CreativeAgent
    when :factual then FactualAgent
    else FactualAgent
    end
  end

  def classify(query)
    TaskClassifierAgent.new.ask(query).content.downcase.to_sym
  end
end
```

### Parallel

```ruby
require 'async'

class SentimentAgent < RubyLLM::Agent
  instructions "Given text, return one word sentiment: positive, negative, or neutral."
end

class SummaryAgent < RubyLLM::Agent
  instructions "Given text, summarize it in one concise sentence."
end

class KeywordAgent < RubyLLM::Agent
  instructions "Given text, extract exactly 5 relevant keywords."
end

class ParallelAnalyzer
  def analyze(text)
    Async do |task|
      sentiment = task.async { SentimentAgent.new.ask(text).content }
      summary   = task.async { SummaryAgent.new.ask(text).content }
      keywords  = task.async { KeywordAgent.new.ask(text).content }

      { sentiment: sentiment.wait, summary: summary.wait, keywords: keywords.wait }
    end.wait
  end
end
```

### Fan-Out / Fan-In

```ruby
require 'async'

class SecurityReviewAgent < RubyLLM::Agent
  model "claude-sonnet-4-6"
  instructions "Given code, review it for security issues."
end

class PerformanceReviewAgent < RubyLLM::Agent
  model "gpt-5.4"
  instructions "Given code, review it for performance issues."
end

class StyleReviewAgent < RubyLLM::Agent
  model "gpt-5-mini"
  instructions "Given code, review style against Ruby conventions."
end

class ReviewSynthesizerAgent < RubyLLM::Agent
  instructions "Given multiple code review reports, summarize prioritized findings."
end

class CodeReviewSystem
  def review_code(code)
    Async do |task|
      security    = task.async { SecurityReviewAgent.new.ask(code).content }
      performance = task.async { PerformanceReviewAgent.new.ask(code).content }
      style       = task.async { StyleReviewAgent.new.ask(code).content }

      ReviewSynthesizerAgent.new.ask(
        "security: #{security.wait}\n\n" \
        "performance: #{performance.wait}\n\n" \
        "style: #{style.wait}"
      ).content
    end.wait
  end
end
```

### Evaluator-Optimizer

```ruby
class DraftAgent < RubyLLM::Agent
  instructions "Given a task, produce the best possible draft response."
end

class CriticAgent < RubyLLM::Agent
  schema do
    string :verdict,  enum: ["pass", "revise"], description: "Whether the draft passes or needs changes"
    string :feedback, description: "Specific feedback for improvement"
  end
  instructions "Review the draft against the task and return a verdict and specific feedback."
end

class EvaluatorOptimizerWorkflow
  MAX_ROUNDS = 3

  def call(task)
    draft = DraftAgent.new.ask(task).content

    MAX_ROUNDS.times do
      verdict, feedback = review(task: task, draft: draft)
      return draft if verdict == "pass"

      draft = revise(task: task, draft: draft, feedback: feedback)
    end

    draft
  end

  private

  def review(task:, draft:)
    result = CriticAgent.new.ask("Task:\n#{task}\n\nDraft:\n#{draft}").content
    [result.fetch("verdict"), result.fetch("feedback")]
  end

  def revise(task:, draft:, feedback:)
    DraftAgent.new.ask("Task:\n#{task}\n\nCurrent draft:\n#{draft}\n\nFeedback:\n#{feedback}").content
  end
end
```

### RAG as a workflow step

```ruby
# Gemfile
gem 'neighbor'
gem 'ruby_llm'

# Generate pgvector-backed migration
bin/rails generate neighbor:vector
bin/rails db:migrate

class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.text :content
      t.string :title
      t.vector :embedding, limit: 1536 # OpenAI embedding size
      t.timestamps
    end

    add_index :documents, :embedding, using: :hnsw, opclass: :vector_l2_ops
  end
end

# app/models/document.rb
class Document < ApplicationRecord
  has_neighbors :embedding

  before_save :generate_embedding, if: :content_changed?

  private

  def generate_embedding
    response = RubyLLM.embed(content)
    self.embedding = response.vectors
  end
end

# app/tools/document_search.rb
class DocumentSearch < RubyLLM::Tool
  description "Searches knowledge base for relevant information"
  param :query, desc: "Search query"

  def execute(query:)
    embedding = RubyLLM.embed(query).vectors

    documents = Document.nearest_neighbors(
      :embedding,
      embedding,
      distance: "euclidean"
    ).limit(3)

    documents.map do |doc|
      "#{doc.title}: #{doc.content.truncate(500)}"
    end.join("\n\n---\n\n")
  end
end

# Agent that uses the tool
class SupportWithDocsAgent < RubyLLM::Agent
  tools DocumentSearch
  instructions "Search for context before answering. Cite sources."
end
```

## Pitfalls

- Model names (`gemini-3.1-pro-preview`, `claude-sonnet-4-6`, `claude-opus-4-6`, `gpt-5.4`, `gpt-5-mini`) are what the RubyLLM guide used at time of writing — check the current RubyLLM model catalog before pinning; providers retire and rename models.
- The RAG migration hardcodes `limit: 1536` (OpenAI embedding size). Switch that value to match your embedding provider's dimensions (e.g. Gemini's `text-embedding-004` has its own size).
- Parallel patterns require `require 'async'` — without it `Async do |task|` raises `NameError`.
- `EvaluatorOptimizerWorkflow::MAX_ROUNDS = 3` returns the *last* draft after three revises without converging; surface it as a configurable constant and add a convergence log if quality is critical.
- `TaskClassifierAgent` returning anything other than `code`, `creative`, or `factual` falls through to `FactualAgent` — design the classifier prompt to keep its output in that enum, or extend the `case`.
- `Document.nearest_neighbors` returns distance-ascending hits; the example takes `limit(3)` without a distance cutoff — add one for production, irrelevant chunks will still get fed to the answering agent.
- Error handling is delegated to the Tools guide — return `{ error: "..." }` for recoverable failures the LLM might fix, raise exceptions for unrecoverable config/service errors, and rely on RubyLLM's retry middleware for transient provider failures.

## Verification

After scaffolding a workflow, exercise it through the `terminal` tool:

```
ruby -e 'require_relative "workflows/research_writer"; puts ResearchWriterWorkflow.new.create_article("Ruby 3.3 features")'
```

For a Rails-backed RAG step:

```
bin/rails runner 'puts SupportWithDocsAgent.new.ask("What is our refund policy?").content'
```

Either invocation should print a non-empty string from the final agent in the chain, confirming that credentials, gems, and pattern wiring all work end-to-end.
