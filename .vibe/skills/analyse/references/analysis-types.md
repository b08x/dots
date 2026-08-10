# Analyse Types (dry-struct)

Type-safe representations for each diagnostic method's findings, plus the `AnalysisSession` container that holds them.

```ruby
# frozen_string_literal: true

require "dry-struct"
require "dry-types"

module Types
  include Dry.Types()
end

module RubyDev
  module Analyse
    # Gemba Walk finding
    class GembaFinding < Dry::Struct
      attribute :entry_points, Types::Array.of(Types::String)
      attribute :core_abstractions, Types::Array.of(Types::String)
      attribute :external_dependencies, Types::Array.of(Types::String)
      attribute :execution_paths, Types::Array.of(Types::String)
      attribute :patterns_observed, Types::Array.of(Types::String)
      attribute :assumptions_vs_reality, Types::Hash
      attribute :surprises, Types::Array.of(Types::String)
      attribute :handoff_keys, Types::Array.of(Types::String)
    end

    # Muda (waste) finding
    class MudaFinding < Dry::Struct
      attribute :waste_type, Types::String.enum(
        "inventory", "motion", "waiting", "overprocessing",
        "overproduction", "transportation", "defects"
      )
      attribute :location, Types::String  # File path
      attribute :description, Types::String
      attribute :impact, Types::Hash.schema(
        gem_count: Types::Integer.optional,
        method_count: Types::Integer.optional,
        loc_reduction: Types::Integer.optional,
        io_calls: Types::Integer.optional
      )
      attribute :handoff_key, Types::String
    end

    # Root-cause finding
    class RootCauseFinding < Dry::Struct
      attribute :error_class, Types::String
      attribute :error_message, Types::String
      attribute :manifestation_location, Types::String  # file:line
      attribute :stack_trace, Types::Array.of(Types::String)
      attribute :immediate_cause, Types::String
      attribute :propagation_path, Types::Array.of(Types::String)
      attribute :root_cause, Types::String
      attribute :fix_strategy, Types::String
      attribute :handoff_key, Types::String
    end

    # Five Whys finding
    class FiveWhysFinding < Dry::Struct
      attribute :problem_statement, Types::String
      attribute :whys, Types::Array.of(Types::String).constrained(size: 5)
      attribute :systemic_root, Types::String
      attribute :remediation, Types::String
      attribute :handoff_key, Types::String
    end

    # Analysis session (container for all findings)
    class AnalysisSession < Dry::Struct
      attribute :session_id, Types::String
      attribute :timestamp, Types::Time
      attribute :target, Types::String  # File or directory analyzed
      attribute :method, Types::String.enum("gemba", "muda", "root_cause", "five_whys")
      attribute :gemba_findings, Types::Array.of(GembaFinding).default { [] }
      attribute :muda_findings, Types::Array.of(MudaFinding).default { [] }
      attribute :root_cause_findings, Types::Array.of(RootCauseFinding).default { [] }
      attribute :five_whys_findings, Types::Array.of(FiveWhysFinding).default { [] }
    end
  end
end
```
