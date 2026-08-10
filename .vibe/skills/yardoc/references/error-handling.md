# Yardoc Error Handling with Result Monad

## Contents
- Result monad types
- Chaining operations with Result
- Conditional error handling with pattern matching
- YARD-specific rescue patterns

The yardoc skill uses **dry-monads** Result type for explicit, composable error handling in documentation generation workflows. This provides clear success/failure propagation and enables rescue patterns specific to YARD documentation.

## Result Monad Types

```ruby
# frozen_string_literal: true

require "dry-monads"

module RubyDev
  module Yardoc
    # Type aliases for Result monad
    Success = Dry::Monads::Result::Success
    Failure = Dry::Monads::Result::Failure

    # Convenience methods for common error types
    module ResultTypes
      FILE_NOT_FOUND = :file_not_found
      PARSE_ERROR = :parse_error
      TYPE_INFERENCE_FAILED = :type_inference_failed
      YARD_SYNTAX_ERROR = :yard_syntax_error
      GEM_CONTEXT_UNAVAILABLE = :gem_context_unavailable
      VALIDATION_ERROR = :validation_error
    end
  end
end
```

## Chaining Operations with Result

**Basic Success/Failure Propagation:**

```ruby
# @return [Dry::Monads::Result] Success with documentation or Failure with error
# @example Chaining documentation generation operations
def generate_documentation(file_path)
  parse_file(file_path)
    .bind { |ast| infer_types(ast) }
    .bind { |typed_ast| generate_yard_comments(typed_ast) }
    .bind { |comments| validate_yard_syntax(comments) }
    .fmap { |valid_comments| insert_comments(file_path, valid_comments) }
end

# @return [Dry::Monads::Result] Success with AST or Failure
# @example File parsing with explicit error handling
def parse_file(file_path)
  return Failure[ResultTypes::FILE_NOT_FOUND, "File not found: #{file_path}"] unless File.exist?(file_path)

  begin
    ast = RubyVM::AbstractSyntaxTree.parse_file(file_path)
    Success(ast)
  rescue SyntaxError => e
    Failure[ResultTypes::PARSE_ERROR, "Syntax error in #{file_path}: #{e.message}"]
  end
end
```

## Conditional Error Handling with Pattern Matching

```ruby
# @return [Dry::Monads::Result] Success with type info or Failure
# @example Type inference with fallback strategies
def infer_types(ast)
  case infer_from_ast(ast)
  in Success(type_info)
    Success(type_info)
  in Failure(:type_inference_failed, message)
    # Fallback: use conservative types with uncertainty notes
    conservative_types = infer_conservative_types(ast)
    Success(conservative_types.merge(uncertain: true, note: message))
  in Failure(type, message)
    Failure[type, message]
  end
end

# @return [Dry::Monads::Result] Success with YARD comments or Failure
# @example Rescue pattern for gem API verification
def verify_gem_api(method_signature)
  context_result = RubyDev::Context7.verify(method_signature)

  case context_result
  in Success(verified_sig)
    Success(verified_sig)
  in Failure(:context_unavailable, message)
    # Tiered fallback: use cached signature with warning
    cached = ContextCache.find(method_signature)
    if cached
      Success(cached.merge(fallback: true, warning: message))
    else
      Failure[ResultTypes::GEM_CONTEXT_UNAVAILABLE, message]
    end
  in Failure(type, message)
    Failure[type, message]
  end
end
```

## YARD-Specific Rescue Patterns

**Documentation Generation with Partial Success:**

```ruby
# @return [Dry::Monads::Result] Success with GenerationResult or Failure
# @example Partial documentation on type inference failure
def document_method(method_node)
  type_result = infer_method_types(method_node)

  type_result
    .fmap { |type_info| generate_yard_block(method_node, type_info) }
    .or do |failure|
      # Even if type inference fails, generate basic documentation
      basic_doc = generate_basic_yard_block(method_node)
      Success(basic_doc.merge(
        warnings: ["Type inference failed: #{failure.error}"],
        partial: true
      ))
    end
end

# @return [Dry::Monads::Result] Success with Array<MethodDocumentation>
# @example Batch processing with error collection
def document_file(file_path)
  methods = extract_methods(file_path)

  results = methods.map { |method| document_method(method) }

  # Collect all successes, aggregate failures
  successes = results.select { |r| r.success? }.map(&:value!)
  failures = results.select { |r| r.failure? }

  if failures.empty?
    Success(successes)
  else
    # Return partial success with error collection
    partial_result = GenerationResult.new(
      file_path: file_path,
      methods_documented: successes.size,
      documentation: successes,
      warnings: failures.map { |f| "Method #{f.failure}: #{f.error}" },
      success: false,
      error: "Partial documentation: #{failures.size} methods failed"
    )
    Success(partial_result)
  end
end
```

**YARD Syntax Validation with Monadic Flow:**

```ruby
# @return [Dry::Monads::Result] Success with validated comments or Failure
# @example Validation pipeline with monadic composition
def validate_and_insert_comments(file_path, comments)
  validation_chain = ->(acc, comment) do
    validate_yard_syntax(comment)
      .fmap { |valid| acc + [valid] }
      .or { |failure| acc + [comment.merge(syntax_error: failure.error)] }
  end

  validated_comments = comments.inject(Success([]), &validation_chain)

  validated_comments.bind do |validated|
    insert_comments_at_positions(file_path, validated)
  end
end

# @return [Dry::Monads::Result] Success with String (comment) or Failure
# @example Individual comment validation
def validate_yard_syntax(comment)
  return Failure[ResultTypes::YARD_SYNTAX_ERROR, "Empty comment block"] if comment.empty?

  # Validate YARD tag syntax
  unless valid_yard_tags?(comment)
    return Failure[ResultTypes::YARD_SYNTAX_ERROR, "Invalid YARD tag syntax"]
  end

  # Validate type annotations
  unless valid_type_annotations?(comment)
    return Failure[ResultTypes::YARD_SYNTAX_ERROR, "Invalid type annotations"]
  end

  Success(comment)
end
```
