---
name: yardoc
description: "Use when generating, adding, or improving YARD documentation for Ruby files. Uses AST parsing and type inference to generate comprehensive @param, @return, @example, and @raise tags. Maintains consistency with existing project documentation patterns and YARD configuration."
user-invocable: true
---

# RubyDev Yardoc — YARD Documentation Generator

## Overview

This skill provides **semantic analysis-powered YARD documentation generation** for Ruby code. It transforms Ruby code into comprehensive, immediately usable developer resources with precise implementation guidance. This skill embodies "The Technical Writer" persona: precise, thorough, and developer-focused.

**Core Mandate**: Generate documentation that eliminates usage pitfalls and accelerates correct method implementation.

**References**:
- YARD patterns and conventions: [~/.vibe/skills/yardoc/references/yard-patterns.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/yard-patterns.md))
- Dry-struct type definitions for documentation results: [~/.vibe/skills/yardoc/references/type-structures.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/type-structures.md))
- Context7 verification workflow for YARD/gem APIs: [~/.vibe/skills/yardoc/references/context7-integration.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/context7-integration.md))
- Structured logging setup and example log calls: [~/.vibe/skills/yardoc/references/logging.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/logging.md))
- Result monad error-handling patterns: [~/.vibe/skills/yardoc/references/error-handling.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/error-handling.md))
- Full worked example (dry-struct class + custom YARD tags): [~/.vibe/skills/yardoc/references/dry-struct-example.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/dry-struct-example.md))

## When to Use

- **Generate YARD documentation** for Ruby files or methods
- **Add YARD comments** to existing code
- **Improve documentation** quality and completeness
- **Document methods** with precise type annotations
- **File paths ending in `.rb`** + documentation request
- **Missing documentation** gaps in codebase

**Don't use for:**
- README generation or project overview docs (use general writing skills)
- Non-Ruby files
- Code review or quality assessment (use [sift/SKILL.md](~/.vibe/skills/sift/SKILL.md) instead)
- Debugging or root cause analysis (use [analyse/SKILL.md](~/.vibe/skills/analyse/SKILL.md))

## Execution Layers

### Layer 1: Gem Context Check (Prerequisite)

Before generating type annotations, verify gem context:

1. **Check for non-stdlib gems** in the target file
2. **If gem-specific types detected** (e.g., `RubyLLM::Chat`, `Sequel::Dataset`, `Async::Task`, `Dry::Schema::Result`):
   - Query Context7 MCP (or DeepWiki for the gem's GitHub repo) for each gem involved, inline
   - Use verified method signatures verbatim in `@param` and `@return` tags
   - If Context7 unavailable, apply tiered fallback and note `# type annotation based on stale cache — verify before publishing`
3. **Skip for**: stdlib-only files, Lite Mode tasks, gems already resolved this session

See [~/.vibe/skills/yardoc/references/context7-integration.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/context7-integration.md)) for the full verification workflow and query patterns.

### Layer 2: Target and Context Validation

#### Target File Validation
- Verify specified Ruby file exists and is readable
- Confirm `.rb` extension (warn if missing but proceed)
- Parse file for basic syntax validity before analysis

#### Documentation Context Assessment
- Check for `.yardopts` file to maintain project YARD configuration
- Scan existing codebase for established documentation patterns
- Identify documentation coverage gaps and consistency issues
- Note any existing YARD comment style conventions

### Layer 3: Semantic Code Analysis

#### AST-Based Structure Parsing

Extract from Ruby AST:
- Class and module hierarchies with inheritance chains
- Method signatures including parameter types and defaults
- Instance vs class method distinction
- Public, private, protected method visibility
- Block parameter usage patterns and yields

#### Type Inference Engine

Analyze code implementation to infer:
- Parameter types from usage patterns and method calls
- Return value types from conditional branches and explicit returns
- Nilable returns from conditional logic and early returns
- Duck typing interfaces from method calls on parameters
- Exception conditions from raise statements and rescue blocks

#### Behavioral Pattern Recognition

Extract method purpose from:
- Implementation logic and control flow
- Parameter interactions and transformation patterns
- Side effects and state mutations
- Integration with other methods and external dependencies

### Layer 4: YARD Documentation Generation

#### Method Documentation Assembly

Generate complete YARD comment blocks:

```ruby
##
# [Clear behavioral description in active voice]
#
# [Extended description with usage context and important notes]
#
# @param [PreciseType] param_name Description with usage context and constraints
# @param [Type, nil] optional_param Description including default behavior patterns
# @return [SpecificType] Comprehensive description with type structure details
# @raise [ExceptionClass] Specific conditions that trigger this exception
# @example Basic usage pattern
#   realistic_method_call(actual_values)
#   # => expected_output_with_type
# @example Advanced scenario with blocks
#   complex_usage_pattern do |yielded_value|
#     # practical block implementation
#   end
# @since version_number (if determinable from git history)
# @see RelatedClass#related_method (if cross-references detected)
```

#### Type Annotation Precision

- Use specific Ruby types: `String`, `Integer`, `Hash{Symbol => Object}`
- Document complex structures: `Array<Hash{String => Symbol}>`
- Include duck typing: `#to_s`, `#each`, `#call`
- Specify nilable types: `String, nil` for conditional returns
- Document union types: `String, Symbol` for flexible parameters

#### Example Generation Strategy

Create realistic, working code examples:
- Use actual parameter values that demonstrate typical usage
- Show return value structure with comments
- Include both simple and complex usage scenarios
- Demonstrate block usage patterns where applicable
- Avoid trivial examples that don't add value

See [~/.vibe/skills/yardoc/references/dry-struct-example.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/dry-struct-example.md)) for a complete runnable example.

### Layer 5: Documentation Quality Assurance

#### Validation Checklist
- **Type Accuracy**: Verify type annotations match actual code behavior
- **Example Validation**: Ensure all examples are syntactically correct and realistic
- **Completeness**: Check all method parameters and return scenarios are documented
- **Consistency**: Maintain terminological and structural consistency across methods
- **YARD Compliance**: Validate generated syntax against YARD standards

#### Integration Verification
- Preserve existing comment structure and formatting
- Maintain project-specific documentation conventions
- Ensure generated documentation integrates cleanly with existing docs
- Verify no conflicts with existing YARD tags or custom extensions

### Layer 6: Output and Application

#### Documentation Insertion
- Insert generated YARD comments at appropriate code locations
- Preserve existing code structure and indentation
- Maintain proper spacing between methods and comment blocks
- Handle edge cases like nested classes and metaprogramming

#### Quality Report Summary

Provide completion summary:
- Number of methods documented
- Types of documentation generated (params, returns, examples, etc.)
- Any limitations or unresolved patterns encountered
- Suggestions for manual review or enhancement

## Advanced Features

### Project Pattern Learning
- Detect and follow established parameter naming conventions
- Match existing documentation verbosity and style preferences
- Inherit project-specific type annotation patterns
- Respect existing @since, @deprecated, and custom tag usage

### Error Handling

Documentation generation uses dry-monads Result types for explicit success/failure propagation, with rescue patterns for partial documentation when type inference fails. See [~/.vibe/skills/yardoc/references/error-handling.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/error-handling.md)) for the full Result monad chain and YARD-specific rescue patterns.

### Type-Safe Data Structures

Documentation results are represented as dry-struct types (`MethodDocumentation`, `GenerationResult`, `YardResult`, etc.) rather than raw hashes. See [~/.vibe/skills/yardoc/references/type-structures.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/type-structures.md)) for the complete definitions.

### Logging

All operations (parsing, semantic analysis, generation, validation) emit structured logs via `journald-logger` with correlation IDs. See [~/.vibe/skills/yardoc/references/logging.md](~/.vibe/skills/yardoc/~/.vibe/skills/yardoc/references/logging.md)) for setup and example log calls.

## Operational Protocol

### Decision Statement

At the start of every yardoc operation, create a structured decision:

```
[YARDOC DECISION]
Target: <file_path>
Mode: <standard|lite>
Gems to Verify: <list or none>
Methods to Document: <count>
Quality Gate: <validation_level>
[/YARDOC DECISION]
```

### Quality Gates

1. **Syntax Validation**: Parse target file with Ruby parser before generation
2. **Type Verification**: All non-stdlib gem APIs must be verified inline via Context7/DeepWiki
3. **Example Testing**: All generated examples must be syntactically valid Ruby
4. **Integration Check**: Generated docs must not break existing YARD processing

### Output Format

For each documented method, output:
1. The YARD comment block
2. Verification status
3. Any warnings or limitations

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| Context7 / DeepWiki | Both unreachable | Use conservative type inference (String, Object, etc.) and add a `# type annotation based on unverified API — verify before publishing` comment. |
| [sift/SKILL.md](~/.vibe/skills/sift/SKILL.md) | Quality assessment unavailable | Run manual YARD validation: check each tag against YARD spec, verify @param names match method signature, confirm @return type is plausible. |
| [analyse/SKILL.md](~/.vibe/skills/analyse/SKILL.md) | Diagnostic unavailable | Document uncertainty in generated comments with `# TODO: verify this type` markers for later review. |

## Common Pitfalls

1. **Documenting without context**: Always check for non-stdlib gems first
2. **Over-documenting trivial methods**: One-liners may not need full YARD blocks
3. **Ignoring existing patterns**: Match the project's established documentation style
4. **Hallucinating types**: Never invent type annotations for unverified gem APIs
5. **Breaking YARD syntax**: Validate all generated tags against YARD standards
6. **Forgetting examples**: Always include at least one realistic usage example
7. **Inconsistent formatting**: Match existing codebase indentation and style
