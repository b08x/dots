# Yardoc Logging

## Contents
- Logger initialization
- Context enrichment
- Example log calls: parsing, semantic analysis, documentation generation, quality assurance

## Initialization

```ruby
# frozen_string_literal: true

require "journald/logger"

module RubyDev
  module Yardoc
    def self.logger
      @logger ||= Journald::Logger.new("ruby-dev-yardoc")
    end
  end
end
```

## Context Enrichment

Enrich log entries with correlation IDs and operational context:

```ruby
module RubyDev
  module Yardoc
    class DocumentationGenerator
      attr_reader :correlation_id, :logger

      def initialize(correlation_id: SecureRandom.uuid)
        @correlation_id = correlation_id
        @logger = RubyDev::Yardoc.logger
      end

      private

      def log_context
        {
          correlation_id: correlation_id,
          skill: "ruby-dev-yardoc",
          timestamp: Time.now.utc.iso8601(6)
        }
      end

      def enriched_logger
        logger.tagged(correlation_id)
      end
    end
  end
end
```

## Example Log Calls for Key Operations

### Parsing Operations

```ruby
def parse_file(file_path:)
  start_time = Time.now

  enriched_logger.info("parsing_started", log_context.merge({
    operation: "file_parsing",
    file_path: file_path,
    file_size: File.size(file_path)
  }))

  ast = parse_ruby_file(file_path)
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)

  enriched_logger.info("parsing_completed", log_context.merge({
    operation: "file_parsing",
    file_path: file_path,
    node_count: ast.children.size,
    classes_found: count_nodes(ast, :class),
    modules_found: count_nodes(ast, :module),
    methods_found: count_nodes(ast, :def),
    latency_ms: elapsed_ms
  }))

  ast
rescue Parser::SyntaxError => e
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)

  enriched_logger.error("parsing_failed", log_context.merge({
    operation: "file_parsing",
    file_path: file_path,
    error_class: e.class.name,
    error_message: e.message,
    line_number: e.line,
    latency_ms: elapsed_ms,
    backtrace: e.backtrace.first(3)
  }))

  raise
end
```

### Semantic Analysis Operations

```ruby
def analyze_methods(ast:)
  start_time = Time.now
  method_count = count_nodes(ast, :def)

  enriched_logger.info("semantic_analysis_started", log_context.merge({
    operation: "semantic_analysis",
    methods_to_analyze: method_count
  }))

  analysis_results = perform_semantic_analysis(ast)
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)

  enriched_logger.info("semantic_analysis_completed", log_context.merge({
    operation: "semantic_analysis",
    methods_analyzed: analysis_results.size,
    parameters_inferred: analysis_results.sum { |m| m[:parameters].size },
    return_types_inferred: analysis_results.sum { |m| m[:return_types].size },
    duck_types_detected: analysis_results.count { |m| m[:duck_types].any? },
    latency_ms: elapsed_ms
  }))

  analysis_results
end
```

### Documentation Generation Operations

```ruby
def generate_documentation(methods:)
  start_time = Time.now

  enriched_logger.info("documentation_generation_started", log_context.merge({
    operation: "documentation_generation",
    methods_to_document: methods.size
  }))

  generated_docs = []
  methods.each_with_index do |method, index|
    doc_start = Time.now

    documentation = generate_method_documentation(method)
    doc_elapsed_ms = ((Time.now - doc_start) * 1000).round(2)

    enriched_logger.info("method_documented", log_context.merge({
      operation: "documentation_generation",
      method_name: method.name,
      method_index: index + 1,
      total_methods: methods.size,
      tags_generated: documentation.tags.size,
      examples_generated: documentation.examples.size,
      latency_ms: doc_elapsed_ms
    }))

    generated_docs << documentation
  end

  elapsed_ms = ((Time.now - start_time) * 1000).round(2)

  enriched_logger.info("documentation_generation_completed", log_context.merge({
    operation: "documentation_generation",
    methods_documented: generated_docs.size,
    total_params_documented: generated_docs.sum { |d| d.parameters.size },
    total_examples_generated: generated_docs.sum { |d| d.examples.size },
    total_return_types: generated_docs.sum { |d| d.return_types.size },
    latency_ms: elapsed_ms
  }))

  generated_docs
rescue StandardError => e
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)

  enriched_logger.error("documentation_generation_failed", log_context.merge({
    operation: "documentation_generation",
    error_class: e.class.name,
    error_message: e.message,
    methods_attempted: methods.size,
    methods_completed: generated_docs.size,
    latency_ms: elapsed_ms,
    backtrace: e.backtrace.first(5)
  }))

  raise
end
```

### Quality Assurance Operations

```ruby
def validate_documentation(documentation:)
  start_time = Time.now

  enriched_logger.info("quality_assurance_started", log_context.merge({
    operation: "quality_assurance",
    methods_to_validate: documentation.size
  }))

  validation_results = perform_validation(documentation)
  elapsed_ms = ((Time.now - start_time) * 1000).round(2)

  enriched_logger.info("quality_assurance_completed", log_context.merge({
    operation: "quality_assurance",
    methods_validated: validation_results.size,
    validation_passed: validation_results.count { |r| r[:valid] },
    validation_failed: validation_results.count { |r| !r[:valid] },
    warnings_found: validation_results.sum { |r| r[:warnings].size },
    latency_ms: elapsed_ms
  }))

  validation_results
end
```
