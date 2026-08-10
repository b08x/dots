# SIFT Implementation Example

A complete `Assessor` class showing how the four SIFT dimensions are scored, weighted, and combined into an `AssessmentResult`, plus how a `TechAdvisory` verdict is derived when the score falls below threshold. Depends on the types defined in [assessment-types.md](assessment-types.md).

```ruby
# frozen_string_literal: true

require "journald/logger"
require "zeitwerk"
require "rubocop"
require_relative "assessment_types"

module RubyDev
  module SIFT
    class Assessor
      WEIGHTS = {
        structure: 0.25,
        idioms: 0.20,
        functionality: 0.35,
        testing: 0.20
      }.freeze

      def initialize(target_path, mode: "full")
        @target_path = target_path
        @mode = mode
        @logger = Journald::Logger.new("sift_assessor")
        @session_id = SecureRandom.uuid
      end

      def assess
        @logger.info("assessment_started", {
          session_id: @session_id,
          mode: @mode,
          target: @target_path
        })

        start_time = Time.now

        # Run assessments for each dimension
        structure_result = assess_structure
        idioms_result = assess_idioms
        functionality_result = assess_functionality
        testing_result = assess_testing

        # Calculate overall score
        overall_score = (
          (structure_result.score * WEIGHTS[:structure]) +
          (idioms_result.score * WEIGHTS[:idioms]) +
          (functionality_result.score * WEIGHTS[:functionality]) +
          (testing_result.score * WEIGHTS[:testing])
        ).round(2)

        verdict = determine_verdict(overall_score)

        all_findings = [
          structure_result.findings,
          idioms_result.findings,
          functionality_result.findings,
          testing_result.findings
        ].flatten

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.info("assessment_completed", {
          session_id: @session_id,
          overall_score: overall_score,
          verdict: verdict,
          findings_count: all_findings.size,
          latency_ms: elapsed_ms
        })

        AssessmentResult.new(
          session_id: @session_id,
          timestamp: Time.now,
          target: @target_path,
          mode: @mode,
          structure: structure_result.dimension_score,
          idioms: idioms_result.dimension_score,
          functionality: functionality_result.dimension_score,
          testing: testing_result.dimension_score,
          overall_score: overall_score,
          verdict: verdict,
          findings: all_findings
        )
      end

      private

      def assess_structure
        findings = []

        # Check Zeitwerk compliance
        loader = Zeitwerk::Loader.new
        loader.push_dir(@target_path)

        begin
          loader.setup
          loader.eager_load
          zeitwerk_score = 100
        rescue Zeitwerk::NameError => e
          findings << Finding.new(
            id: "struct-#{SecureRandom.hex(4)}",
            dimension: "structure",
            severity: "critical",
            location: extract_location(e),
            claim: "Zeitwerk naming violation",
            data: e.message,
            warrant: "Zeitwerk requires file paths to mirror constant nesting",
            backing: "https://github.com/fxn/zeitwerk#file-structure",
            qualifier: "Will cause runtime errors in production",
            rebuttal: "Not applicable if using classic autoloading",
            remediation_estimate_minutes: 5
          )
          zeitwerk_score = 70
        end

        # More structure checks...
        score = zeitwerk_score  # Simplified for example

        DimensionResult.new(
          dimension_score: DimensionScore.new(
            dimension: "structure",
            score: score,
            weight: WEIGHTS[:structure],
            weighted_score: (score * WEIGHTS[:structure]).round(2),
            findings_count: findings.size,
            critical_count: findings.count { |f| f.severity == "critical" }
          ),
          findings: findings
        )
      end

      def assess_idioms
        findings = []

        # Run RuboCop
        cli = RuboCop::CLI.new
        result = cli.run(["--format", "json", @target_path])

        # Parse RuboCop output and create findings
        # (simplified for example)
        score = result == 0 ? 100 : 85

        DimensionResult.new(
          dimension_score: DimensionScore.new(
            dimension: "idioms",
            score: score,
            weight: WEIGHTS[:idioms],
            weighted_score: (score * WEIGHTS[:idioms]).round(2),
            findings_count: findings.size,
            critical_count: 0
          ),
          findings: findings
        )
      end

      def assess_functionality
        # Logic correctness, error handling checks
        # (simplified for example)
        findings = []
        score = 90

        DimensionResult.new(
          dimension_score: DimensionScore.new(
            dimension: "functionality",
            score: score,
            weight: WEIGHTS[:functionality],
            weighted_score: (score * WEIGHTS[:functionality]).round(2),
            findings_count: findings.size,
            critical_count: 0
          ),
          findings: findings
        )
      end

      def assess_testing
        # Coverage analysis
        # (simplified for example)
        findings = []
        score = 82

        DimensionResult.new(
          dimension_score: DimensionScore.new(
            dimension: "testing",
            score: score,
            weight: WEIGHTS[:testing],
            weighted_score: (score * WEIGHTS[:testing]).round(2),
            findings_count: findings.size,
            critical_count: 0
          ),
          findings: findings
        )
      end

      def determine_verdict(score)
        case score
        when 90..100 then "production_ready"
        when 75..89 then "good_minor_improvements"
        when 60..74 then "functional_requires_refactoring"
        else "significant_issues"
        end
      end

      def extract_location(error)
        error.backtrace.first || "unknown"
      end

      # Helper struct for dimension results
      DimensionResult = Struct.new(:dimension_score, :findings, keyword_init: true)
    end
  end
end

# Usage
assessor = RubyDev::SIFT::Assessor.new("lib/my_app", mode: "full")
result = assessor.assess

puts "Overall Score: #{result.overall_score}"
puts "Verdict: #{result.verdict}"
puts "Findings: #{result.findings.size}"

# Tech Advisory mode
if result.overall_score < 75
  advisory = TechAdvisory.new(
    verdict: "no_go",
    rationale: "Critical structure issues found",
    critical_blockers: result.findings.select { |f| f.severity == "critical" }.map(&:claim),
    risk_score: 100 - result.overall_score,
    deployment_checklist: ["Fix Zeitwerk issues", "Add error handling", "Increase test coverage"],
    monitoring_recommendations: ["Monitor error rates", "Track response times"],
    rollback_plan: "Revert to previous commit"
  )

  puts "Tech Advisory: #{advisory.verdict.upcase}"
end
```
