# GenAI Component Templates

## Contents
- Template 1: RAG Pipeline with pgvector (schema, embedder, retriever)
- Template 2: MCP Server with Tools
- Template 3: DSPy-Style Structured Prompting

## Template 1: RAG Pipeline with pgvector

**Structure**:
```
lib/my_app/
├── rag/
│   ├── embedder.rb         # Embedding generation
│   ├── indexer.rb          # Clause indexing
│   ├── retriever.rb        # Hybrid retrieval (RRF)
│   ├── generator.rb        # LLM response generation
│   └── pipeline.rb         # Orchestrator
└── db/
    └── migrations/
        └── 001_create_embeddings.rb
```

**Schema** (`001_create_embeddings.rb`):
```ruby
Sequel.migration do
  up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    create_table(:clauses) do
      primary_key :id
      String :text, null: false
      String :source_document
      Integer :position
      jsonb :pos_tags
      jsonb :fine_tags
      jsonb :dependencies
      tsvector :tsv  # Full-text search
      index :tsv, type: :gin
    end

    create_table(:embeddings) do
      foreign_key :clause_id, :clauses, null: false
      column :embedding, "vector(1536)"  # OpenAI ada-002 size
      String :model, null: false
      DateTime :created_at, null: false
      index [:clause_id, :model], unique: true
      index :embedding, type: :ivfflat, opclass: :vector_cosine_ops
    end
  end
end
```

**Embedder** (`embedder.rb`):

The embedder's job here is RAG-specific: turn a `Failure`/`Success`-wrapped, typed `EmbeddingResult` into something `indexer.rb` and `retriever.rb` can rely on. The actual LLM call — client construction, circuit breaker, OTel span, retry/error handling — is `ruby_llm`-specific and documented in [ruby-llm/SKILL.md](~/.vibe/skills/ruby-llm/SKILL.md) (see "Embeddings" and "Resilience: Circuit Breaker"); this template only shows the seam between that client and the RAG pipeline's own types:

```ruby
# frozen_string_literal: true

require "dry-struct"
require "dry-types"
require "dry/monads"

module Types
  include Dry.Types()
end

module MyApp
  module RAG
    # Type-safe embedding result — the RAG pipeline's contract, independent of which
    # LLM client produced the vector.
    class EmbeddingResult < Dry::Struct
      attribute :embedding, Types::Array.of(Types::Float)
      attribute :model, Types::String
      attribute :tokens_used, Types::Integer
      attribute :timestamp, Types::Time
    end

    class Embedder
      include Dry::Monads[:result]

      def initialize(llm_client:, model: "text-embedding-3-small")
        @llm_client = llm_client # a ruby_llm-backed client per ~/.vibe/skills/ruby-llm/SKILL.md, injected — this class doesn't construct it
        @model = model
      end

      def embed(text)
        return Failure([:empty_text, "Text cannot be empty"]) if text.nil? || text.empty?

        result = @llm_client.embed(text, model: @model) # circuit breaker + tracing live inside llm_client, per ruby-llm/SKILL.md
        Success(EmbeddingResult.new(
          embedding: result.vectors,
          model: @model,
          tokens_used: result.tokens_used,
          timestamp: Time.now
        ))
      rescue StandardError => e
        Failure([:api_error, e.message])
      end
    end
  end
end
```

**Retriever** (`retriever.rb`):
```ruby
# frozen_string_literal: true

require "sequel"

module MyApp
  module RAG
    class Retriever
      def initialize(db:, embedder:)
        @db = db
        @embedder = embedder
      end

      def retrieve(query, limit: 10)
        query_embedding = @embedder.embed(query)

        # Semantic search
        semantic = @db[:embeddings]
          .join(:clauses, id: :clause_id)
          .order(Sequel.lit("embedding <=> ?", query_embedding))
          .limit(100)
          .select(
            Sequel[:clauses][:id].as(:clause_id),
            Sequel[:clauses][:text],
            Sequel.lit("ROW_NUMBER() OVER (ORDER BY embedding <=> ?) AS semantic_rank", query_embedding)
          )

        # Keyword search
        keyword = @db[:clauses]
          .where(Sequel.lit("tsv @@ plainto_tsquery(?)", query))
          .select(
            :id,
            Sequel.lit("ROW_NUMBER() OVER (ORDER BY ts_rank(tsv, plainto_tsquery(?)) DESC) AS keyword_rank", query)
          )

        # RRF merge
        @db.from(semantic.full_outer_join(keyword, clause_id: :id))
          .select(
            Sequel.lit("COALESCE(semantic.clause_id, keyword.id) AS clause_id"),
            Sequel[:semantic][:text],
            Sequel.lit("(1.0 / (60 + COALESCE(semantic_rank, 100))) + (1.0 / (60 + COALESCE(keyword_rank, 100))) AS rrf_score")
          )
          .order(Sequel.desc(:rrf_score))
          .limit(limit)
          .all
      end
    end
  end
end
```

## Template 2: MCP Server with Tools

**Structure**:
```
lib/my_app/
└── mcp/
    ├── server.rb           # Fast-MCP server
    ├── tools/
    │   ├── search.rb       # Semantic search tool
    │   ├── summarize.rb    # Summarization tool
    │   └── base.rb         # Tool base class
    └── schemas/
        └── tool_schemas.rb # JSON schemas for tools
```

**Server** (`server.rb`):
```ruby
# frozen_string_literal: true

require "fast_mcp"

module MyApp
  module MCP
    class Server
      def initialize(port: 8080)
        @server = FastMCP::Server.new(port: port)
        register_tools
      end

      def start
        @server.start
      end

      private

      def register_tools
        @server.register_tool(Tools::Search.new)
        @server.register_tool(Tools::Summarize.new)
      end
    end
  end
end
```

**Tool** (`tools/search.rb`):
```ruby
# frozen_string_literal: true

module MyApp
  module MCP
    module Tools
      class Search < Base
        def name
          "semantic_search"
        end

        def description
          "Search knowledge base using semantic similarity"
        end

        def parameters
          {
            type: "object",
            properties: {
              query: { type: "string", description: "Search query" },
              limit: { type: "integer", default: 10, description: "Max results" }
            },
            required: ["query"]
          }
        end

        def execute(query:, limit: 10)
          retriever = RAG::Retriever.new(db: DB, embedder: RAG::Embedder.new)
          results = retriever.retrieve(query, limit: limit)

          {
            results: results.map { |r| { text: r[:text], score: r[:rrf_score] } },
            count: results.size
          }
        end
      end
    end
  end
end
```

## Template 3: DSPy-Style Structured Prompting

**Structure**:
```ruby
# frozen_string_literal: true

module MyApp
  module Prompts
    class Signature
      attr_reader :input_fields, :output_fields, :instructions

      def initialize(instructions:, input_fields:, output_fields:)
        @instructions = instructions
        @input_fields = input_fields
        @output_fields = output_fields
      end

      def format(inputs)
        prompt = "#{@instructions}\n\n"

        @input_fields.each do |field, description|
          prompt += "#{field.to_s.capitalize}: #{description}\n"
          prompt += "#{inputs[field]}\n\n"
        end

        prompt += "Output:\n"
        @output_fields.each do |field, description|
          prompt += "#{field.to_s.capitalize}: #{description}\n"
        end

        prompt
      end
    end

    class ChainOfThought
      def initialize(llm:, signature:)
        @llm = llm
        @signature = signature
      end

      def predict(**inputs)
        prompt = @signature.format(inputs)

        circuit_breaker do
          response = @llm.complete(prompt: prompt, max_tokens: 500)
          parse_output(response)
        end
      end

      private

      def parse_output(response)
        # Parse structured output based on signature
        @signature.output_fields.keys.each_with_object({}) do |field, acc|
          acc[field] = extract_field(response, field)
        end
      end
    end
  end
end
```
