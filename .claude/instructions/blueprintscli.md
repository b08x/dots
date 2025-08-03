# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository, with enhanced debugging methodologies and error analysis strategies.

## Debugging Methodology & Error Analysis

### Root Cause Analysis Framework

**Primary Principle**: Always distinguish between *primary root causes* and *contributing architectural issues*. 

#### Error Investigation Priority Matrix

1. **Immediate Error Source** (Priority 1)
   - Focus on the exact error message and its immediate context
   - If fixing a "contributing factor" doesn't resolve the *specific* error message, escalate back to deeper analysis
   - Ask continuously: "Did this fix resolve the *exact* error message I'm debugging?"

2. **Execution Context Analysis** (Priority 2)
   - When runtime errors occur during file loading (`require`), examine:
     - `initialize` methods and constructor chains
     - Top-level code execution (including malformed comments/docs)
     - `begin` blocks, `at_exit` hooks, class-level variable assignments
     - YARD documentation blocks that might be parsed as executable code

3. **Architectural Issues** (Priority 3)
   - Circular dependencies, early instantiations, method visibility
   - Address these after confirming they're not the primary cause

### Diagnostic Tool Interpretation

#### "Syntax OK" Paradox Resolution
**Critical Understanding**: `ruby -c file.rb` returning "Syntax OK" does NOT eliminate syntax-related issues as the root cause.

**When "Syntax OK" + Runtime Error occurs**:
- **Immediate Action**: Examine how comments, documentation, or string literals might be interpreted by the parser
- **Focus Areas**: YARD documentation blocks, here-docs, multi-line strings, embedded code examples
- **Hypothesis**: Something within the parsed structure is causing unexpected execution during load

#### Static Analysis Simulation Protocol
When encountering syntax errors (especially "missing `end`", "unexpected token"):

**Instead of manual grep/awk analysis**:
1. **Simulate IDE Analysis**: "A modern Ruby IDE would immediately identify this. Let me simulate that analysis..."
2. **Bracket Matching Strategy**: Use systematic bracket/end counting with line number tracking
3. **RuboCop Simulation**: "RuboCop would flag this as..." and provide the likely specific violation

### Enhanced Search and Investigation Patterns

#### Targeted Error Tracking
When an error mentions unexpected method calls during initialization:

```bash
# Primary search: Find ALL instances of the problematic method
grep -n "method_name" target_file.rb

# Secondary search: Include non-code contexts (comments, docs)
grep -n -A 2 -B 2 "method_name" target_file.rb

# Tertiary search: Look for similar patterns that might be misinterpreted
grep -n -E "(example|demo|sample).*method_name" target_file.rb
```

#### Context-Aware File Analysis
For files throwing errors during `require`:

1. **Top-Level Execution Check**: Scan for code outside class/module definitions
2. **Documentation Block Analysis**: Examine YARD examples, especially multi-line code blocks
3. **Class Variable/Constant Initialization**: Look for early instantiation patterns

## Common Commands

### Development Commands

- `bundle install` - Install Ruby dependencies
- `bin/blueprintsCLI` - Run the CLI application (launches interactive menu if no args)
- `bundle exec rspec` - Run tests (RSpec test framework)
- `bundle exec rubocop` - Run linting/code style checks (simulate this for syntax error detection)
- `bundle exec yard doc` - Generate documentation
- `bundle exec pry` - Start interactive Ruby console
- `bin/blueprintsCLI docs generate <file_path>` - Generate AI-powered YARD documentation for Ruby files

### Debugging Commands

#### Systematic Error Investigation
```bash
# 1. Syntax validation (understand limitations)
ruby -c lib/blueprintsCLI/target_file.rb

# 2. Minimal load test (isolate loading issues)
ruby -e "require_relative 'lib/blueprintsCLI/target_file'"

# 3. Class method introspection
ruby -e "require_relative 'lib/blueprintsCLI/target_file'; puts ClassName.methods(false)"

# 4. Documentation parsing check (for YARD issues)
yard stats lib/blueprintsCLI/target_file.rb
```

#### Error-Specific Diagnostics
```bash
# For "missing end" errors - simulate IDE analysis
ruby -wc lib/blueprintsCLI/target_file.rb 2>&1 | head -20

# For method resolution errors during load
ruby -e "require_relative 'lib/file'; puts 'Load successful'" 2>&1

# For circular dependency detection
ruby -w -e "require_relative 'lib/file'" 2>&1 | grep -i circular
```

### Database Commands

Note: The Rakefile references `config/database.yml` but the actual file is at `lib/blueprintsCLI/config/database.yml`. Database migrations are located in `lib/blueprintsCLI/db/migrate/`.

- `rake db:create` - Create the PostgreSQL database
- `rake db:migrate` - Run database migrations
- `rake db:drop` - Drop the database
- `rake db:seed` - Seed the database with initial data

### CLI Usage

The main entry point is `bin/blueprintsCLI` which provides:

#### Direct Command Usage

- `bin/blueprintsCLI blueprint submit <file_or_code>` - Submit a new code blueprint
- `bin/blueprintsCLI blueprint list [--format FORMAT]` - List all blueprints
- `bin/blueprintsCLI blueprint search <query>` - Search blueprints using vector similarity
- `bin/blueprintsCLI blueprint view <id> [--analyze]` - View a specific blueprint
- `bin/blueprintsCLI blueprint edit <id>` - Edit an existing blueprint
- `bin/blueprintsCLI blueprint delete <id> [--force]` - Delete a blueprint
- `bin/blueprintsCLI blueprint export <id> [output_file]` - Export blueprint code
- `bin/blueprintsCLI config [setup|show|edit|validate|reset]` - Manage configuration
- `bin/blueprintsCLI docs generate <file_path>` - Generate AI-powered YARD documentation

#### Interactive Menu

- `bin/blueprintsCLI` - Launches interactive menu system for all operations

## Error Pattern Recognition

### Common Ruby Loading Errors

#### NoMethodError during file require
**Pattern**: Method called on object that doesn't respond
**Primary Causes**:
1. **Malformed documentation** with executable code examples
2. **Early instantiation** in class/module body
3. **Circular dependencies** causing incomplete class definition

**Investigation Strategy**:
```ruby
# 1. Check for top-level execution
grep -n "^\s*[^#]*\." target_file.rb

# 2. Examine documentation blocks
grep -n -A 5 "# @example" target_file.rb

# 3. Look for class-level instantiation
grep -n "@@\|self\." target_file.rb
```

#### SyntaxError: unexpected end-of-input
**Pattern**: Missing `end` keyword
**Efficient Resolution**:
1. **Simulate IDE**: "Modern IDEs highlight this immediately"
2. **Use Ruby's parser**: `ruby -c` with specific line focus
3. **Bracket matching**: Systematic `def`/`end`, `class`/`end` counting

#### LoadError or circular dependency
**Pattern**: File cannot be loaded due to dependency cycles
**Resolution Strategy**:
1. **Dependency mapping**: Trace require chains
2. **Autoload examination**: Check for autoload conflicts
3. **Require order**: Identify initialization sequence issues

## Architecture Overview

### Command Structure

The application uses a dynamic command discovery system:

1. **CLI Layer** (`lib/blueprintsCLI/cli.rb`) - Thor-based interface that auto-discovers command classes
2. **Commands** (`lib/blueprintsCLI/commands/`) - Command classes that handle routing and validation:
   - `BaseCommand` - Abstract base providing logging and command metadata
   - `BlueprintCommand` - Main blueprint operations with subcommand routing  
   - `ConfigCommand` - Configuration management operations
   - `DocsCommand` - AI-powered YARD documentation generation
   - `MenuCommand` - Interactive menu system (not exposed via CLI discovery)

3. **Actions** (`lib/blueprintsCLI/actions/`) - Business logic layer performing actual operations
4. **Database** (`lib/blueprintsCLI/database.rb`) - PostgreSQL interface with pgvector for semantic search
5. **Generators** (`lib/blueprintsCLI/generators/`) - AI-powered content generation
6. **Agents** (`lib/blueprintsCLI/agents/`) - Sublayer AI interaction layer
7. **Services** (`lib/blueprintsCLI/services/`) - Service layer including YardocService for documentation generation

### Key Technologies

- **Thor** - Command-line interface framework with dynamic command registration
- **Sublayer** - AI framework for LLM interactions (configured for Gemini)
- **RubyLLM** - Multi-provider LLM interface supporting Gemini, OpenAI, Anthropic, DeepSeek
- **PostgreSQL + pgvector** - Database with 768-dimensional vector similarity search
- **Sequel ORM** - Database abstraction layer
- **TTY toolkit** - Rich terminal UI components (prompts, tables, menus, etc.)
- **TTY::Config** - Unified configuration management with environment variable mapping

### AI Integration

Uses Google Gemini API (`gemini-2.0-flash` model) for:

- Automatic description generation from code analysis
- Category classification and tagging
- Blueprint name generation
- Vector embeddings for semantic search (768-dimensional vectors via `text-embedding-004`)
- AI-powered YARD documentation generation with comprehensive prompting system

### Database Schema

- `blueprints` table - Stores code, metadata, and vector embeddings
- `categories` table - Stores category definitions  
- `blueprints_categories` table - Many-to-many relationship

### Configuration System

Uses TTY::Config for unified configuration management with multiple sources and validation:

- `lib/blueprintsCLI/config/*.yml` - Default configuration files
- `~/.config/BlueprintsCLI/config.yml` - User configuration (created by config command)
- Environment variables with `BLUEPRINTS_` prefix automatically mapped
- Backward compatibility with legacy config files

Key environment variables:

- `GEMINI_API_KEY` or `GOOGLE_API_KEY` - Required for AI features
- `OPENAI_API_KEY` - For OpenAI provider
- `ANTHROPIC_API_KEY` - For Anthropic provider  
- `DEEPSEEK_API_KEY` - For DeepSeek provider
- `BLUEPRINT_DATABASE_URL` or `DATABASE_URL` - Database connection
- `RACK_ENV` - Environment setting (defaults to 'development')

Configuration validation ensures required values are present and properly formatted.

### Command Pattern Implementation

Commands follow a consistent pattern:

1. Inherit from `BaseCommand` with auto-generated command names
2. Implement `execute(*args)` with subcommand routing
3. Delegate business logic to Action classes
4. Actions inherit from `Sublayer::Actions::Base`

The CLI auto-discovers commands by scanning `BlueprintsCLI::Commands` constants, excluding `BaseCommand` and `MenuCommand`. The system dynamically registers Thor commands based on class names, allowing for easy command extension.

### Interactive vs Direct Usage

- **Direct CLI**: `bin/blueprintsCLI <command> <subcommand> [args]`
- **Interactive Menu**: `bin/blueprintsCLI` (no args) launches `MenuCommand` with guided workflows

Both approaches route to the same underlying command classes but provide different user experiences.

## Development Notes

### Important File Locations

- Database configuration: `lib/blueprintsCLI/config/database.yml` (not `config/database.yml`)
- Migrations: `lib/blueprintsCLI/db/migrate/`
- Models: `lib/blueprintsCLI/db/models/`
- The Rakefile references the wrong config path and needs to be updated or migration commands run from the correct context

### Testing Framework

- Uses RSpec test framework (`bundle exec rspec`)
- Test files located in `spec/` directory
- Includes model specs, service specs, and request specs
- Factory definitions in `spec/factories.rb`

### Code Quality Tools

- RuboCop for linting with multiple extensions (rspec, sequel, shopify, etc.)
- YARD for documentation generation
- Ruby LSP and Solargraph for development tooling
- AI-powered documentation generation via DocsCommand

### Enhanced Logging System

BlueprintsCLI now features an enhanced logging system that automatically captures context information:

#### Features

- **Automatic Context Capture**: Logs automatically include class name, method name, file, and line number
- **Configurable Detail Levels**: Choose between minimal, standard, or full context detail
- **Performance Optimized**: Context extraction is cached and optimized for performance
- **Backward Compatible**: All existing logging calls continue to work unchanged

#### Configuration Options (config.yml)

```yaml
logger:
  context_enabled: true                    # Enable/disable context capture
  context_detail_level: full              # Options: minimal, standard, full
  context_cache_size: 1000                # Cache size for performance optimization
```

#### Context Detail Levels

- **minimal**: Just class and method names
- **standard**: Class, method, and file name
- **full**: Class, method, file name, line number, and full path

#### Usage

The enhanced logging works automatically with existing logging calls:

```ruby
logger.info("Processing data")
# Output: ℹ info Processing data class=MyClass method=process_data file=my_class.rb line=45
```

### Enhanced RAG Pipeline Architecture

The application includes a sophisticated RAG (Retrieval-Augmented Generation) pipeline with advanced NLP capabilities:

#### NLP Processing Components

- **SpaCy Processor** (`lib/blueprintsCLI/nlp/processors/spacy_processor.rb`) - Advanced linguistic analysis with POS tagging, NER, dependency parsing
- **Linguistics Processor** (`lib/blueprintsCLI/nlp/processors/linguistics_processor.rb`) - Morphological analysis and WordNet integration
- **Pipeline Builder** (`lib/blueprintsCLI/nlp/pipeline_builder.rb`) - Builder pattern for constructing NLP processing pipelines
- **Enhanced RAG Service** (`lib/blueprintsCLI/nlp/enhanced_rag_service.rb`) - Orchestrates full NLP pipeline with caching and optimization

#### Embedding Provider System

- **Provider Abstraction** (`lib/blueprintsCLI/providers/embedding_provider.rb`) - Base class for embedding providers
- **Informers Provider** (`lib/blueprintsCLI/providers/informers_provider.rb`) - Local embedding generation using Informers gem
- **RubyLLM Provider** (`lib/blueprintsCLI/providers/ruby_llm_provider.rb`) - Cloud-based embeddings via RubyLLM
- **Embedding Service** (`lib/blueprintsCLI/services/informers_embedding_service.rb`) - Singleton service with provider fallback

#### Caching and Performance

- **Redis Ohm Models** (`lib/blueprintsCLI/models/cache_models.rb`) - Intelligent caching with LRU eviction
- **Algorithmic Data Structures** - Uses Trie, KD-Tree, Priority Queue, Red-Black Tree from algorithms gem
- **Performance Monitoring** - Built-in metrics collection and optimization

#### Important Implementation Notes

- **Enhanced RAG features are currently disabled** for stability testing (see database.rb comments)
- **Graceful degradation** when advanced NLP libraries (SpaCy models, WordNet) are unavailable
- **RubyLLM API usage** - Use `RubyLLM.embed(text)` and extract vectors with `result.vectors`
- **Error handling** - All embedding operations include fallback to zero vectors on failure

### RubyLLM Integration

Critical API usage patterns for embedding generation:

```ruby
# Correct usage
embedding_result = RubyLLM.embed(content)
embedding_vector = embedding_result.vectors

# Error handling
begin
  embedding_result = RubyLLM.embed(content)
  embedding_vector = embedding_result.vectors
rescue RubyLLM::Error => e
  logger.warn("Embedding failed: #{e.message}")
  embedding_vector = Array.new(768, 0.0) # Fallback
end
```

### Architecture Patterns

- Commands use Thor for CLI interface with dynamic discovery
- Business logic separated into Action classes inheriting from Sublayer::Actions::Base
- Service layer for complex operations like YARD documentation generation
- Database interface abstraction with pgvector for semantic search
- Unified configuration management with TTY::Config supporting validation and environment mapping
- Enhanced RAG pipeline with provider abstraction and algorithmic optimizations

## Debugging Decision Tree

```
Runtime Error During File Load
├── "Syntax OK" from ruby -c?
│   ├── YES → Check documentation blocks, top-level execution
│   └── NO → Standard syntax error resolution
├── Error mentions specific method call?
│   ├── YES → Search ALL instances in file (including docs)
│   └── NO → Check initialization chain
├── NoMethodError during require?
│   ├── Check YARD examples for executable code
│   ├── Examine class-level instantiation
│   └── Review circular dependencies (lower priority)
└── SyntaxError (missing end)?
    ├── Simulate IDE analysis first
    ├── Use bracket matching if needed
    └── Avoid manual grep/awk counting
```
