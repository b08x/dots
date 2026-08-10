---
title: Pry Console - REPL & Debugging Standard
version: 1.0.0
last_updated: 2026-05-25
maintained_by: Syncopated Context
standard_gem: pry
---

# Pry Console - REPL & Debugging Standard

## Overview

**Standard Gem**: All ruby-dev skills MUST use `pry` for interactive debugging and REPL-driven development.

**Rule**: Always set up Pry console for exploration, debugging, and development workflows.

---

## Setup

### 1. Add to Gemfile

```ruby
# Gemfile
group :development, :test do
  gem "pry"
  gem "pry-byebug"  # Adds step debugging
  gem "pry-doc"     # Adds Ruby core/stdlib docs
end
```

### 2. Configure .pryrc

```ruby
# .pryrc (project root or ~/.pryrc for global)

# Enable history
Pry.config.history_file = "#{Dir.home}/.pry_history"

# Syntax highlighting
Pry.config.color = true

# Auto-indent
Pry.config.auto_indent = true

# Pagination (less-like pager)
Pry.config.pager = true

# Custom prompt showing context
Pry.config.prompt = Pry::Prompt.new(
  "custom",
  "Custom prompt",
  [
    proc { |obj, nest_level, _| "[#{nest_level}] #{obj}> " },
    proc { |obj, nest_level, _| "[#{nest_level}] #{obj}* " }
  ]
)

# Load project-specific helpers
if File.exist?("config/boot.rb")
  require_relative "config/boot"
end

# Aliases
Pry.commands.alias_command "c", "continue"
Pry.commands.alias_command "s", "step"
Pry.commands.alias_command "n", "next"
Pry.commands.alias_command "f", "finish"
```

### 3. Project-Specific Console Script

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# scripts/console

require "bundler/setup"
require_relative "../lib/my_app"
require "pry"

# Preload common modules
include MyApp

# Load dotenv for development
require "dotenv/load" if ENV["RACK_ENV"] != "production"

# Start Pry
Pry.start
```

```bash
chmod +x scripts/console
./scripts/console
```

---

## Basic Usage

### Starting Pry

```ruby
# In code - drop into REPL at this point
require "pry"
binding.pry

# From command line
pry

# With preloaded context
pry -r ./lib/my_app.rb
```

### Navigation Commands

```ruby
# Show current context
whereami

# Show source of method
show-method User#email

# Show documentation
show-doc Array#map

# List instance variables
ls

# List methods on object
ls User

# Go up one context level
exit

# Exit Pry completely
exit!
```

---

## Debugging with pry-byebug

### Breakpoint Commands

```ruby
# Set breakpoint in code
require "pry-byebug"

def process_data(data)
  binding.pry  # Execution stops here
  result = transform(data)
  result
end
```

### Step Commands

```ruby
# Step into method
step

# Step over method (execute but don't enter)
next

# Continue to end of method
finish

# Continue execution
continue

# Show backtrace
backtrace

# Move up/down stack frames
up
down

# Show local variables
local_variables
```

### Conditional Breakpoints

```ruby
def batch_process(items)
  items.each_with_index do |item, idx|
    # Only break on 10th iteration
    binding.pry if idx == 9
    process(item)
  end
end
```

---

## Exploration Patterns

### Pattern 1: REPL-Driven Development

```ruby
# In Pry console
> require "sequel"
> DB = Sequel.connect("sqlite://test.db")
> DB.create_table(:users) do
*   primary_key :id
*   String :email
* end
> DB[:users].insert(email: "test@example.com")
> DB[:users].all
# => [{:id=>1, :email=>"test@example.com"}]

# Once working, move to actual code
```

### Pattern 2: Object Introspection

```ruby
# Inspect object structure
> user = User.new(email: "test@example.com")
> ls user
# Shows all methods and instance variables

# View method source
> show-method user.valid?

# Check method location
> user.method(:valid?).source_location
# => ["/path/to/user.rb", 42]
```

### Pattern 3: Testing API Calls

```ruby
# Test LLM API in Pry
> require "dotenv/load"
> require "ruby_llm"
> llm = RubyLLM::Client.new(api_key: ENV["OPENAI_API_KEY"])
> response = llm.complete(prompt: "Hello", model: "gpt-4o-mini")
> response.choices.first.message.content
# => "Hello! How can I assist you today?"

# Inspect token usage
> response.usage
# => #<OpenStruct prompt_tokens=8, completion_tokens=9, total_tokens=17>
```

### Pattern 4: Database Query Testing

```ruby
# Test Sequel queries
> require "sequel"
> DB = Sequel.connect(ENV["DATABASE_URL"])
> DB[:embeddings].where { id > 100 }.limit(5).all

# Test pgvector similarity search
> query_embedding = [0.1, 0.2, 0.3, ...]
> DB[:embeddings]
    .order(Sequel.lit("embedding <=> ?", query_embedding))
    .limit(10)
    .all
```

---

## Advanced Features

### Custom Commands

```ruby
# .pryrc
Pry::Commands.block_command "reload!", "Reload the application" do
  puts "Reloading..."
  load "lib/my_app.rb"
  puts "Reloaded!"
end

# In Pry
> reload!
# Reloading...
# Reloaded!
```

### Hooks

```ruby
# .pryrc
Pry.config.hooks.add_hook(:before_session, :load_env) do
  require "dotenv/load"
  puts "Environment variables loaded"
end

Pry.config.hooks.add_hook(:after_session, :cleanup) do
  puts "Goodbye!"
end
```

### Editor Integration

```ruby
# Edit method in $EDITOR
edit User#valid?

# Edit-method opens file at method definition
edit-method User#valid?

# Reload file after editing
reload-code User
```

---

## Integration with Skills

### In SKILL.md Procedures

```markdown
## Development Workflow

1. Start Pry console:
   ```bash
   ./scripts/console
   ```

2. Load required modules:
   ```ruby
   require "my_app/rag/pipeline"
   ```

3. Test interactively:
   ```ruby
   pipeline = MyApp::RAG::Pipeline.new
   result = pipeline.query("test query")
   ```

4. Set breakpoints for debugging:
   ```ruby
   # In lib/my_app/rag/pipeline.rb
   def query(text)
     binding.pry  # Inspect state here
     # ...
   end
   ```
```

### Console Helper Methods

```ruby
# lib/my_app/console_helpers.rb
module MyApp
  module ConsoleHelpers
    def reload!
      Dir.glob("lib/**/*.rb").each { |f| load f }
      puts "Reloaded!"
    end
    
    def test_embedding(text)
      embedder = MyApp::RAG::Embedder.new
      embedder.embed(text)
    end
    
    def test_search(query, limit: 10)
      retriever = MyApp::RAG::Retriever.new(db: DB, embedder: embedder)
      retriever.retrieve(query, limit: limit)
    end
  end
end

# In .pryrc or scripts/console
include MyApp::ConsoleHelpers
```

---

## Common Workflows

### Workflow 1: Debugging Zeitwerk Issues

```ruby
# In Pry
> require "zeitwerk"
> loader = Zeitwerk::Loader.new
> loader.push_dir("lib")
> loader.setup
> loader.eager_load

# Check for naming violations
> loader.all_dirs
> loader.all_expected_cpaths

# Test autoloading
> MyApp::Data::Processor
# => NameError if file path doesn't match constant
```

### Workflow 2: Testing Circuit Breaker

```ruby
# In Pry
> require "circuit_breaker"
> circuit = CircuitBreaker.new(threshold: 3, timeout: 5)

> 5.times do
*   begin
*     circuit.call { raise "API Error" }
*   rescue => e
*     puts e.message
*   end
* end
# API Error
# API Error
# API Error
# Circuit breaker is open (RuntimeError)
# Circuit breaker is open (RuntimeError)
```

### Workflow 3: Iterating on Dry-Struct Models

```ruby
# In Pry
> require "dry-struct"
> module Types
*   include Dry.Types()
* end

> class User < Dry::Struct
*   attribute :email, Types::String
*   attribute :age, Types::Integer
* end

> user = User.new(email: "test@example.com", age: 25)
# => #<User email="test@example.com" age=25>

> user.age = 30
# => NoMethodError (Dry::Struct is immutable)

# Iterate: add .optional, .default, etc.
```

---

## Troubleshooting

### Issue 1: Pry Not Stopping at binding.pry

**Cause**: `binding.pry` not reached, or gem not loaded

```ruby
# Fix: Ensure pry is required
require "pry"
require "pry-byebug"

# Verify breakpoint is hit
def my_method
  puts "Before pry"
  binding.pry
  puts "After pry"
end
```

### Issue 2: "Cannot find gem 'pry'"

**Cause**: Not in development/test environment

```bash
# Fix: Set RACK_ENV
RACK_ENV=development ruby script.rb

# Or bundle install with development group
bundle install --with development
```

### Issue 3: No Syntax Highlighting

**Cause**: Missing CodeRay gem

```ruby
# Fix: Add to Gemfile
gem "coderay", groups: [:development, :test]
```

---

## Security Notes

**⚠️ Never leave `binding.pry` in production code**

```ruby
# Bad: Committed breakpoint
def process_payment(amount)
  binding.pry  # DO NOT COMMIT THIS
  charge(amount)
end
```

```ruby
# Good: Conditional breakpoint for dev only
def process_payment(amount)
  binding.pry if ENV["DEBUG"] == "true"
  charge(amount)
end
```

**Pre-commit Hook**:
```bash
#!/bin/bash
# .git/hooks/pre-commit

if git grep -n "binding.pry" -- "*.rb"; then
  echo "Error: Found binding.pry in staged files"
  exit 1
fi
```

---

## Verification Checklist

- [ ] `pry` and `pry-byebug` in Gemfile (development/test groups)
- [ ] `.pryrc` configured with history, colors, auto-indent
- [ ] `scripts/console` script created for project-specific REPL
- [ ] Console helper methods defined for common tasks
- [ ] Pre-commit hook to prevent `binding.pry` in production
- [ ] Editor integration configured (edit-method support)
- [ ] Pry prompt customized to show context

---

## References

- [Pry Documentation](https://pry.github.io/)
- [Pry Wiki](https://github.com/pry/pry/wiki)
- [pry-byebug](https://github.com/deivid-rodriguez/pry-byebug)
- [pry-doc](https://github.com/pry/pry-doc)

---

**Last Updated**: 2026-05-25  
**Next Review**: After implementing in all 5 core skills  
**Status**: Active Standard
