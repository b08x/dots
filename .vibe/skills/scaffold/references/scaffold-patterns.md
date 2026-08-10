# Scaffold Patterns

Flag reference, project archetype presets, decision guide, and convention pass recipes
for `ruby-dev-scaffold`. Load this file when selecting flags, determining project
type, or applying post-scaffold convention hardening.

Last updated: 2026-03-22

## Contents
- [Section 1: rubysmith Flag Reference](#section-1-rubysmith-flag-reference)
- [Section 2: gemsmith Flag Reference](#section-2-gemsmith-flag-reference)
- [Section 3: Project Archetype → Flag Preset Table](#section-3-project-archetype--flag-preset-table)
- [Section 4: Decision Guide — rubysmith vs gemsmith](#section-4-decision-guide--rubysmith-vs-gemsmith)
- [Section 5: Config File Locations & Required Setup](#section-5-config-file-locations--required-setup)
- [Section 6: Convention Pass Transformations](#section-6-convention-pass-transformations)
- [Section 7: Post-Scaffold File Tree Examples](#section-7-post-scaffold-file-tree-examples)
- [Section 8: Gem Registry Cross-Reference](#section-8-gem-registry-cross-reference)


---

## Section 1: rubysmith Flag Reference

Command form: `rubysmith build <project_name> [flags]`

| Flag | Default | When to include | Notes |
|------|---------|-----------------|-------|
| `--min` | off | Absolute bare minimum | Mutually exclusive with `--max` |
| `--max` | off | Everything enabled | Good starting point; remove unwanted with `--no-*` |
| `--git` | off | Almost always | Initializes git repo + Git Safe |
| `--setup` | off | Dev onboarding needed | Adds `bin/setup` |
| `--rake` | off | Almost always | Adds `Rakefile` + `bin/rake` |
| `--console` | off | Interactive dev work | Adds `bin/console` (IRB with project loaded) |
| `--rspec` | off | Testing required | Adds `spec/` + `spec_helper.rb` + shared contexts |
| `--simple_cov` | off | With `--rspec` | Adds SimpleCov coverage tracking |
| `--reek` | off | Code smell detection desired | Adds `.reek.yml` |
| `--git-lint` | off | Commit message linting desired | Adds Git Lint config |
| `--docker` | off | Containerization needed | Adds `Dockerfile`, `compose.yml`, `.dockerignore`, `bin/docker` |
| `--git_hub` | off | GitHub hosting | Adds `.github/ISSUE_TEMPLATE.md`, `PULL_REQUEST_TEMPLATE.md` |
| `--git_hub_ci` | off | GitHub Actions CI/CD | Adds `.github/workflows/ci.yml`; requires `--git_hub` |
| `--funding` | off | OSS with sponsors | Adds `.github/FUNDING.yml` |
| `--license` | off | Open source | Adds `LICENSE` (MIT by default; configure in `~/.config/rubysmith/configuration.yml`) |
| `--readme` | off | Almost always | Adds `README.md` (or `.adoc` if configured) |
| `--citation` | off | Academic/research tools | Adds `CITATION.cff` |
| `--conduct` | off | OSS community | Adds Code of Conduct link to README |
| `--community` | off | OSS community | Adds community/org link to README |
| `--dcoo` | off | Developer Certificate of Origin | Adds DCO link to README |

**Disable a default (when using `--max`):** prefix any flag with `--no-`, e.g. `--no-docker`.

---

## Section 2: gemsmith Flag Reference

Command form: `gemsmith build --name <gem_name> [flags]`

| Flag | Default | When to include | Notes |
|------|---------|-----------------|-------|
| `--min` | off | Bare minimum gemspec scaffold | Mutually exclusive with `--max` |
| `--max` | off | All features enabled | |
| `--cli` | off | Gem has a CLI entry point | Adds `exe/`, `bin/`, and CLI wiring via Sod/OptionParser |
| `--rspec` | off | Testing required | Adds `spec/` |
| `--security` | off | Public gem with signing | Adds signing key, cert chain, MFA enforcement in gemspec |
| `--github` | off | GitHub hosting | Adds `.github/` templates |
| `--circle-ci` | off | CircleCI CI/CD | Adds `.circleci/config.yml` |
| `--refinements` | off | Uses refinements gem | |
| `--zeitwerk` | off | Zeitwerk autoloading | Recommended for Standard Mode; adds loader wiring |

**Note:** gemsmith inherits all rubysmith configuration options — the gemsmith config
file at `~/.config/gemsmith/configuration.yml` takes precedence over rubysmith's.

---

## Section 3: Project Archetype → Flag Preset Table

Use this table to recommend flags based on the user's stated project type, rather than
asking about every flag individually. Present the preset and let the user adjust.

| Archetype | Tool | Recommended Flags |
|-----------|------|-------------------|
| Ruby CLI tool (personal) | rubysmith | `--git --rake --console --rspec --readme --license` |
| Ruby data pipeline / batch processor | rubysmith | `--git --rake --rspec --readme` |
| Open source Ruby app | rubysmith | `--git --rake --console --rspec --simple_cov --git_hub --git_hub_ci --readme --license --conduct --community` |
| Minimal throwaway script | rubysmith | `--git --readme` |
| Containerized Ruby service | rubysmith | `--git --rake --rspec --readme --docker` |
| Ruby gem — personal / internal | gemsmith | `--rspec --zeitwerk --github` |
| Ruby gem — public / OSS | gemsmith | `--rspec --security --zeitwerk --github --circle-ci` |
| Ruby gem with CLI entry point | gemsmith | `--cli --rspec --security --zeitwerk --github` |

When the archetype is ambiguous, default to the personal CLI tool preset (rubysmith)
and let the user extend from there.

---

## Section 4: Decision Guide — rubysmith vs gemsmith

**Primary decision tree:**

```
Will this code be published to rubygems.org?
  Yes → gemsmith
  No  → Does it need a gemspec for private gem server or version pinning?
          Yes → gemsmith
          No  → rubysmith
```

**Secondary signal table** (use when the user's phrasing is ambiguous):

| User says... | Likely tool |
|-------------|-------------|
| "gem", "library", "plugin", "extension" | gemsmith |
| "app", "tool", "script", "bot", "utility" | rubysmith |
| "rubygems.org", "gem release", "publish a gem" | gemsmith |
| "gemspec", "semver", "gem versioning" | gemsmith |
| "Docker", "deploy", "run a service", "containerize" | rubysmith |
| "script for my team", "internal tool" | rubysmith |
| "open source Ruby project" | Either — ask |

**When ambiguous:** ask exactly one question:
> "Will this be published as a gem on rubygems.org, or is it a local Ruby app/tool?"

---

## Section 5: Config File Locations & Required Setup

### rubysmith

- Config path: `~/.config/rubysmith/configuration.yml`
- Auto-populated from: Git global config (`user.name`, `user.email`)
- If missing: rubysmith will prompt interactively — acceptable, not fatal
- Edit with: `rubysmith --edit` (opens `$EDITOR`)

Key config fields:
```yaml
author:
  given_name: "..."
  family_name: "..."
  email: "..."
  url: ""               # Must be supplied manually — not in Git config
repository:
  handle: "github_username"
  uri: "https://github.com"
```

### gemsmith

- Config path: `~/.config/gemsmith/configuration.yml`
- Inherits all rubysmith config fields
- If missing: **gemsmith will error on build** — config is required, not optional
- Edit with: `gemsmith --edit`

Additional gemsmith fields beyond rubysmith:
```yaml
project:
  uri:
    home: "https://example.com/projects/%project_name%"
    source: "https://github.com/username/%project_name%"
    issues: "https://github.com/username/%project_name%/issues"
    funding: "https://github.com/sponsors/username"
```

**Diagnosis:** if `gemsmith build` errors with a config-related message, run
`gemsmith --edit` first, fill in required fields, then retry.

---

## Section 6: Convention Pass Transformations

Applied during Step 5 (optional) of ruby-dev-scaffold. Each transformation is
independent — apply all that match, skip those with a met skip condition.

| Convention | Files affected | Transformation | Skip condition |
|------------|---------------|----------------|----------------|
| `frozen_string_literal` | All `.rb` files | Prepend `# frozen_string_literal: true` as line 1 | Already present on line 1 |
| Zeitwerk loader | Boot file (`lib/<name>.rb` or `app.rb`) | Add `require "zeitwerk"` + `Zeitwerk::Loader.for_gem.setup` block | Already present; Lite Mode |
| Replace `puts`/`p` | All `.rb` files | Replace with `logger.info(...)` stub; add `journald-logger` to Gemfile | Only if `puts`/`p` found in non-spec files |
| Async boot | Entry point | Wrap main execution block in `Async { }` | Only if HTTP/network libs detected in Gemfile |
| `circuit_breaker` stubs | Files calling HTTP/external services | Add `require "circuit_breaker"` + wrapper comment at call sites | Only if external HTTP calls detected |

**Change log format** (produced when convention pass runs):

```
Convention pass applied — Standard Mode [Community idioms]

  lib/my_tool.rb
    + frozen_string_literal pragma (line 1)
    + Zeitwerk loader setup (lines 3–6)
    ~ puts → logger.info (line 14, line 22)

  Gemfile additions:
    gem "journald-logger"
    gem "zeitwerk"
```

---

## Section 7: Post-Scaffold File Tree Examples

These examples show what the CLI tools actually produce. Use them to describe the
generated structure in Step 4 output when the live tree isn't available.

### rubysmith build my_tool --git --rake --rspec --readme

```
my_tool/
├── .git/
├── .ruby-version
├── .gitignore
├── Gemfile
├── Gemfile.lock
├── Rakefile
├── README.md
├── bin/
│   ├── my_tool
│   └── rake
├── lib/
│   ├── my_tool.rb
│   └── my_tool/
│       └── version.rb
└── spec/
    ├── spec_helper.rb
    └── my_tool_spec.rb
```

### gemsmith build --name my_gem --cli --rspec --zeitwerk

```
my_gem/
├── .git/
├── .ruby-version
├── .gitignore
├── Gemfile
├── Gemfile.lock
├── my_gem.gemspec
├── bin/
│   └── my_gem
├── exe/
│   └── my_gem
├── lib/
│   ├── my_gem.rb
│   └── my_gem/
│       ├── cli.rb
│       ├── container.rb
│       └── version.rb
└── spec/
    ├── spec_helper.rb
    └── my_gem/
        └── cli_spec.rb
```

---

## Section 8: Gem Registry & Foundational Standards Cross-Reference

### Build-Time vs Runtime Dependencies

`rubysmith` and `gemsmith` are **build-toolchain gems** — they are not runtime
dependencies of generated projects. Do not query Context7 for build-toolchain gem APIs during a scaffold run — they are out of scope. For runtime gems the user adds to their project post-scaffold, query Context7 inline at the point of use (no central registry).

Context7 IDs for documentation queries (if needed during advisory):

```
rubysmith → /websites/alchemists_io_projects_rubysmith
gemsmith  → /bkuhlmann/gemsmith
```

For runtime gems added post-scaffold (zeitwerk, async, sequel, circuit_breaker, etc.),
query Context7 MCP inline for the API signature at the point of use.

---

### Foundational Standards (Apply Post-Scaffold)

After scaffolding a project with rubysmith/gemsmith, apply these standards from
the references/ directory:

#### 1. Gem Dependencies (Inline Context7 Verification)

**Purpose**: Zero-hallucination API usage by querying Context7 inline at the point of use

**Apply when**: Adding non-stdlib gems to Gemfile

**Standard Gems to Add**:
```ruby
# Type Safety
gem "dry-struct", "~> 1.6"
gem "dry-types", "~> 1.7"
gem "dry-schema", "~> 1.13"
gem "dry-validation", "~> 1.10"
gem "dry-monads", "~> 1.6"

# Logging
gem "journald-logger", "~> 2.1"

# Resilience
gem "circuit_breaker", "~> 1.1"

# Configuration
gem "dotenv", "~> 2.8", groups: [:development, :test]

# Debugging
gem "pry", "~> 0.14", groups: [:development, :test]
gem "pry-byebug", "~> 3.10", groups: [:development, :test]
```

**Verification**: Query Context7 MCP for each gem's API inline before generating code

---

#### 2. Logging Standard ([logging-patterns.md](~/.vibe/skills/ruby-dev/~/.vibe/skills/scaffold/references/logging-patterns.md))

**Purpose**: Structured logging with journald-logger

**Apply when**: Any project needs logging (Standard Mode)

**Pattern**:
```ruby
# lib/my_project.rb
require "journald/logger"

module MyProject
  def self.logger
    @logger ||= Journald::Logger.new("my_project")
  end
end

# Usage in any file:
MyProject.logger.info("event_name", {
  correlation_id: correlation_id,
  key: "value"
})
```

**Log Events to Implement**:
- `llm_request_completed` - Model, tokens, latency, cost
- `database_query_executed` - Operation, rows, latency
- `circuit_breaker_state_change` - State, failures, reset_timeout
- `api_error` - Error class, message, retries

---

#### 3. Environment Variables ([environment-variables.md](~/.vibe/skills/ruby-dev/~/.vibe/skills/scaffold/references/environment-variables.md))

**Purpose**: Never hardcode secrets, use .env

**Apply when**: Project needs API keys, database URLs, or config

**Pattern**:
```bash
# .env.example (committed to git)
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
DATABASE_URL=postgresql://localhost/myapp_dev
REDIS_URL=redis://localhost:6379/0
LOG_LEVEL=INFO

# .env (NOT committed, add to .gitignore)
OPENAI_API_KEY=sk-abc123...
# ...
```

```ruby
# lib/my_project/config.rb
require "dotenv/load"
require "dry-struct"

module MyProject
  class Config < Dry::Struct
    attribute :openai_api_key, Types::String
    attribute :database_url, Types::String
    # ...
    
    def self.instance
      @instance ||= new(
        openai_api_key: ENV.fetch("OPENAI_API_KEY"),
        database_url: ENV.fetch("DATABASE_URL")
      )
    end
  end
end
```

---

#### 4. Type Safety ([dry-rb-patterns.md](~/.vibe/skills/ruby-dev/~/.vibe/skills/scaffold/references/dry-rb-patterns.md))

**Purpose**: Type-safe structs, schemas, and Result monads

**Apply when**: Defining data models or error handling (Standard Mode)

**Pattern**:
```ruby
# lib/my_project/types.rb
require "dry-struct"
require "dry-types"

module MyProject
  module Types
    include Dry.Types()
  end
  
  class User < Dry::Struct
    attribute :id, Types::Integer
    attribute :email, Types::String
    attribute :active, Types::Bool.default(true)
  end
end

# lib/my_project/api_client.rb
require "dry/monads"

class APIClient
  include Dry::Monads[:result]
  
  def fetch_data
    Success(data)
  rescue NetworkError => e
    Failure([:network_error, e.message])
  end
end
```

---

#### 5. Debugging Console ([pry-console.md](~/.vibe/skills/ruby-dev/~/.vibe/skills/scaffold/references/pry-console.md))

**Purpose**: Interactive REPL for debugging and exploration

**Apply when**: Always (Standard Mode)

**Setup**: Already created by rubysmith `--console` flag

**Enhance**:
```ruby
# .pryrc
if defined?(PryByebug)
  Pry.commands.alias_command 'c', 'continue'
  Pry.commands.alias_command 's', 'step'
  Pry.commands.alias_command 'n', 'next'
end

Pry.config.prompt_name = "MyProject"

# Pre-load common objects for console
MyProject::Config.validate!
```

**Usage**:
```bash
bin/console
pry(main)> MyProject::Config.instance
pry(main)> MyProject::Database.connect
```

---

#### 6. Project Structure ([rubysmith-scaffolding.md](~/.vibe/skills/ruby-dev/~/.vibe/skills/scaffold/references/rubysmith-scaffolding.md))

**Purpose**: Standard project layout with best practices

**Apply when**: Creating new Ruby projects

**Recommended Flags**:
```bash
# CLI Tool
rubysmith build my_tool --git --rake --console --rspec --readme --license

# Ruby Gem (Public)
gemsmith build --name my_gem --rspec --security --zeitwerk --github --circle-ci

# Containerized Service
rubysmith build my_service --git --rake --rspec --docker --git_hub_ci

# AI/NLP Project (Custom)
rubysmith build my_ai_project --zeitwerk --rspec --simple_cov --docker --git_hub_ci
# Then add: ruby_llm, pgvector, sequel, dry-struct, circuit_breaker, journald-logger
```

---

### Post-Scaffold Checklist

After running `rubysmith build` or `gemsmith build`, verify:

- [ ] `bin/setup` completes without errors
- [ ] `bin/console` opens Pry REPL with project loaded
- [ ] `bundle exec rspec` runs (even if no specs yet)
- [ ] `bundle exec rubocop` passes
- [ ] Gemfile includes type safety gems (dry-struct, dry-types)
- [ ] Gemfile includes journald-logger
- [ ] Gemfile includes circuit_breaker (if calling external APIs)
- [ ] .env.example created with all required variables
- [ ] .env added to .gitignore
- [ ] Config class created with validation
- [ ] Logger singleton set up
- [ ] .pryrc configured with project name

---

**Last Updated**: 2026-05-25  
**Version**: 2.0.0  
**Cross-References Added**: 6 foundational standards

