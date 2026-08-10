# Analyse Implementation Examples

## Contents
- Example 1: Muda Analysis with Logging
- Example 2: Root-Cause Tracing with Zeitwerk

Depends on the types defined in [analysis-types.md](analysis-types.md).

## Example 1: Muda Analysis with Logging

```ruby
# frozen_string_literal: true

require "journald/logger"
require_relative "analysis_types"

module RubyDev
  module Analyse
    class MudaAnalyzer
      def initialize(target_path)
        @target_path = target_path
        @logger = Journald::Logger.new("muda_analyzer")
        @session_id = SecureRandom.uuid
      end

      def analyze
        @logger.info("analysis_started", {
          session_id: @session_id,
          method: "muda",
          target: @target_path
        })

        start_time = Time.now
        findings = []

        # Detect inventory waste (unused gems)
        findings += detect_unused_gems

        # Detect motion waste (empty wrappers)
        findings += detect_empty_wrappers

        # Detect waiting waste (blocking I/O)
        findings += detect_blocking_io

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.info("analysis_completed", {
          session_id: @session_id,
          method: "muda",
          findings_count: findings.size,
          latency_ms: elapsed_ms
        })

        AnalysisSession.new(
          session_id: @session_id,
          timestamp: Time.now,
          target: @target_path,
          method: "muda",
          muda_findings: findings
        )
      end

      private

      def detect_unused_gems
        # Implementation: parse Gemfile, check usage
        [
          MudaFinding.new(
            waste_type: "inventory",
            location: "Gemfile:42",
            description: "Gem 'unused_gem' - no require statements found",
            impact: { gem_count: 1, loc_reduction: 0 },
            handoff_key: "muda:inventory:unused_gem"
          )
        ]
      end

      def detect_empty_wrappers
        # Implementation: find classes with only delegation
        []
      end

      def detect_blocking_io
        # Implementation: grep for File.read, HTTP calls without Async
        []
      end
    end
  end
end

# Usage
analyzer = RubyDev::Analyse::MudaAnalyzer.new("lib/my_app")
session = analyzer.analyze

# Handoff to refactor skill
session.muda_findings.each do |finding|
  puts "#{finding.handoff_key} → #{finding.description}"
end
```

## Example 2: Root-Cause Tracing with Zeitwerk

```ruby
# frozen_string_literal: true

require "zeitwerk"
require "journald/logger"
require_relative "analysis_types"

module RubyDev
  module Analyse
    class RootCauseTracer
      def initialize(error)
        @error = error
        @logger = Journald::Logger.new("root_cause_tracer")
        @session_id = SecureRandom.uuid
      end

      def trace
        @logger.info("trace_started", {
          session_id: @session_id,
          error_class: @error.class.name,
          error_message: @error.message
        })

        # Zeitwerk-specific check
        if zeitwerk_name_error?
          finding = trace_zeitwerk_issue
        else
          finding = trace_generic_error
        end

        @logger.info("trace_completed", {
          session_id: @session_id,
          root_cause: finding.root_cause,
          handoff_key: finding.handoff_key
        })

        AnalysisSession.new(
          session_id: @session_id,
          timestamp: Time.now,
          target: extract_location(@error),
          method: "root_cause",
          root_cause_findings: [finding]
        )
      end

      private

      def zeitwerk_name_error?
        @error.is_a?(NameError) && @error.message.include?("uninitialized constant")
      end

      def trace_zeitwerk_issue
        # Extract constant name from error
        constant = @error.message.match(/uninitialized constant (.+)/)[1]

        # Convert to expected file path
        expected_path = constant.gsub("::", "/").gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, "")

        RootCauseFinding.new(
          error_class: @error.class.name,
          error_message: @error.message,
          manifestation_location: extract_location(@error),
          stack_trace: @error.backtrace.first(5),
          immediate_cause: "Constant not found by Zeitwerk autoloader",
          propagation_path: [
            "Application attempted to reference constant #{constant}",
            "Zeitwerk looked for file matching constant naming convention",
            "File not found at expected path: #{expected_path}.rb"
          ],
          root_cause: "File naming doesn't match Zeitwerk conventions",
          fix_strategy: "Rename file to #{expected_path}.rb or use explicit require",
          handoff_key: "root-cause:zeitwerk:#{constant}"
        )
      end

      def trace_generic_error
        # Generic error tracing logic
        RootCauseFinding.new(
          error_class: @error.class.name,
          error_message: @error.message,
          manifestation_location: extract_location(@error),
          stack_trace: @error.backtrace.first(5),
          immediate_cause: "TBD",
          propagation_path: [],
          root_cause: "TBD",
          fix_strategy: "TBD",
          handoff_key: "root-cause:generic"
        )
      end

      def extract_location(error)
        error.backtrace.first
      end
    end
  end
end

# Usage with Pry
begin
  MyApp::Data::Processor.new
rescue => e
  # Drop into Pry for interactive diagnosis
  binding.pry

  # Or programmatic tracing
  tracer = RubyDev::Analyse::RootCauseTracer.new(e)
  session = tracer.trace

  puts session.root_cause_findings.first.fix_strategy
end
```
