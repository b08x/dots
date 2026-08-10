# SIFT Assessment Types (dry-struct)

Type-safe representations for SIFT assessment results, findings, and tech advisory verdicts.

```ruby
# frozen_string_literal: true

require "dry-struct"
require "dry-types"

module Types
  include Dry.Types()
end

module RubyDev
  module SIFT
    # Dimension scores
    class DimensionScore < Dry::Struct
      attribute :dimension, Types::String.enum("structure", "idioms", "functionality", "testing")
      attribute :score, Types::Float.constrained(gteq: 0, lteq: 100)
      attribute :weight, Types::Float
      attribute :weighted_score, Types::Float
      attribute :findings_count, Types::Integer
      attribute :critical_count, Types::Integer
    end

    # Overall assessment
    class AssessmentResult < Dry::Struct
      attribute :session_id, Types::String
      attribute :timestamp, Types::Time
      attribute :target, Types::String
      attribute :mode, Types::String.enum("full", "system_design", "tech_advisory", "backlog")
      attribute :structure, DimensionScore
      attribute :idioms, DimensionScore
      attribute :functionality, DimensionScore
      attribute :testing, DimensionScore
      attribute :overall_score, Types::Float
      attribute :verdict, Types::String.enum(
        "production_ready",
        "good_minor_improvements",
        "functional_requires_refactoring",
        "significant_issues"
      )
      attribute :findings, Types::Array.of(Finding)
    end

    # Toulmin-structured finding
    class Finding < Dry::Struct
      attribute :id, Types::String
      attribute :dimension, Types::String.enum("structure", "idioms", "functionality", "testing")
      attribute :severity, Types::String.enum("critical", "high", "medium", "low")
      attribute :location, Types::String  # file:line
      attribute :claim, Types::String
      attribute :data, Types::String
      attribute :warrant, Types::String
      attribute :backing, Types::String
      attribute :qualifier, Types::String
      attribute :rebuttal, Types::String.optional
      attribute :remediation_estimate_minutes, Types::Integer
    end

    # Tech advisory verdict
    class TechAdvisory < Dry::Struct
      attribute :verdict, Types::String.enum("go", "no_go")
      attribute :rationale, Types::String
      attribute :critical_blockers, Types::Array.of(Types::String)
      attribute :risk_score, Types::Float.constrained(gteq: 0, lteq: 100)
      attribute :deployment_checklist, Types::Array.of(Types::String)
      attribute :monitoring_recommendations, Types::Array.of(Types::String)
      attribute :rollback_plan, Types::String
    end
  end
end
```
