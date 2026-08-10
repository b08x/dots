---
title: Rubysmith - Project Scaffolding Standard
version: 1.0.0
last_updated: 2026-05-25
maintained_by: Syncopated Context
standard_gem: rubysmith
context7_id: /websites/alchemists_io_projects_rubysmith
---

# Rubysmith - Project Scaffolding Standard

## Overview

**Standard Tool**: All ruby-dev skills MUST use `rubysmith` for generating Ruby project scaffolding with best practices.

**Purpose**: Rubysmith fills the niche between simple Bundler Inline scripts and full-featured gems, ideal for:
- Spiking quick Ruby implementations
- Sharing code snippets with structure
- Building collaborative projects
- Generating standardized project layouts

---

## Installation

### System-wide Installation

```bash
gem install rubysmith

# Verify installation
rubysmith --version
```

### Configuration

```bash
# Create config directory
mkdir -p ~/.config/rubysmith

# Create configuration file
cat > ~/.config/rubysmith/configuration.yml << 'EOF'
:author:
  :name: "Your Name"
  :email: "your.email@example.com"
  :url: "https://yoursite.com"

:build:
  :amazing_print: true
  :caliber: true
  :circle_ci: false
  :console: true
  :docker: true
  :git: true
  :git_hub_ci: true
  :git_lint: true
  :guard: false
  :license: "mit"
  :maximum: false
  :readme: true
  :reek: true
  :rspec: true
  :rubocop: true
  :setup: true
  :simple_cov: true
  :versions: true
  :zeitwerk: true

:citation:
  :version: "1.0.0"

:license:
  :label: "MIT"
  :name: "mit"
  :version: "0.0.0"
EOF
```

---

## Basic Usage

### Generate New Project

```bash
# Full-featured project (default)
rubysmith build my_project

# Minimal project (bare minimum)
rubysmith build my_project --min

# Custom options
rubysmith build my_project \
  --rspec \
  --zeitwerk \
  --docker \
  --git_hub_ci
```

### Disable Specific Features

```bash
# Disable Docker and CI
rubysmith build my_project \
  --no-docker \
  --no-git_hub_ci
```

---

## Build Options

### Core Features (Always Enabled)

| Option | Description | Default |
|:-------|:------------|:--------|
| `--zeitwerk` | Zeitwerk autoloading | ✅ Enabled |
| `--git` | Initialize Git repository | ✅ Enabled |
| `--readme` | Generate README.md | ✅ Enabled |
| `--license` | Add LICENSE file | ✅ Enabled |
| `--versions` | Add .versions.yml | ✅ Enabled |

### Development Tools

| Option | Description | Default |
|:-------|:------------|:--------|
| `--console` | Add bin/console script | ✅ Enabled |
| `--setup` | Add bin/setup script | ✅ Enabled |
| `--amazing_print` | Add amazing_print gem | ✅ Enabled |
| `--pry` | Add pry for console | ✅ Enabled |

### Testing & Quality

| Option | Description | Default |
|:-------|:------------|:--------|
| `--rspec` | RSpec testing framework | ✅ Enabled |
| `--simple_cov` | Code coverage | ✅ Enabled |
| `--rubocop` | RuboCop linting | ✅ Enabled |
| `--caliber` | Caliber RuboCop config | ✅ Enabled |
| `--reek` | Code smell detection | ✅ Enabled |
| `--git_lint` | Git commit linting | ✅ Enabled |

### CI/CD

| Option | Description | Default |
|:-------|:------------|:--------|
| `--git_hub_ci` | GitHub Actions CI | ✅ Enabled |
| `--circle_ci` | Circle CI | ❌ Disabled |

### Containerization

| Option | Description | Default |
|:-------|:------------|:--------|
| `--docker` | Docker support (Dockerfile, compose.yml) | ✅ Enabled |

### Watch/Guard

| Option | Description | Default |
|:-------|:------------|:--------|
| `--guard` | Guard file watching | ❌ Disabled |

---

## Generated Project Structure

### Full Project (Default)

```
my_project/
├── .caliber/                    # RuboCop configuration
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions CI
├── bin/
│   ├── console                  # Pry console
│   ├── docker                   # Docker scripts
│   └── setup                    # Setup script
├── lib/
│   ├── my_project/
│   │   └── .keep
│   └── my_project.rb           # Main entry point
├── spec/
│   ├── support/
│   │   └── shared_contexts/
│   │       └── application_context.rb
│   ├── spec_helper.rb
│   └── my_project_spec.rb
├── .dockerignore
├── .gitignore
├── .reek.yml                   # Reek configuration
├── .rspec                      # RSpec configuration
├── .rubocop.yml               # RuboCop configuration
├── .ruby-version              # Ruby version
├── .versions.yml              # Dependency versions
├── compose.yml                # Docker Compose
├── Dockerfile                 # Docker image
├── Gemfile
├── LICENSE                    # MIT License
├── my_project.gemspec
├── Rakefile
└── README.md
```

### Minimal Project (--min)

```
my_project/
├── lib/
│   ├── my_project/
│   │   └── .keep
│   └── my_project.rb
├── .gitignore
├── .ruby-version
├── Gemfile
└── README.md
```

---

## Configuration File Format

```yaml
# ~/.config/rubysmith/configuration.yml

:author:
  :name: "Your Name"
  :email: "your.email@example.com"
  :url: "https://yoursite.com"

:build:
  :amazing_print: true      # Enable amazing_print debugging
  :caliber: true            # Use Caliber RuboCop config
  :circle_ci: false         # Disable Circle CI
  :console: true            # Include bin/console
  :docker: true             # Include Docker support
  :git: true                # Initialize Git repo
  :git_hub_ci: true         # Include GitHub Actions
  :git_lint: true           # Enable Git commit linting
  :guard: false             # Disable Guard file watching
  :license: "mit"           # License type
  :maximum: false           # Not maximum features (custom selection)
  :readme: true             # Generate README
  :reek: true               # Enable Reek code smell detection
  :rspec: true              # Include RSpec
  :rubocop: true            # Include RuboCop
  :setup: true              # Include bin/setup
  :simple_cov: true         # Include SimpleCov coverage
  :versions: true           # Include .versions.yml
  :zeitwerk: true           # Enable Zeitwerk autoloading

:citation:
  :version: "1.0.0"         # Project citation version

:license:
  :label: "MIT"             # License label
  :name: "mit"              # License identifier
  :version: "0.0.0"         # License version
```

---

## Integration with RubyDev Skills

### In scaffold Skill

The `ruby-dev-scaffold` skill will use Rubysmith as the standard scaffolding engine:

```markdown
## Procedure

1. Detect project type:
   - CLI application → Full Rubysmith
   - Library/Gem → Full Rubysmith
   - Quick script → Minimal Rubysmith (--min)

2. Run Rubysmith with appropriate options:
   ```bash
   rubysmith build my_project \
     --zeitwerk \
     --rspec \
     --docker \
     --git_hub_ci
   ```

3. Verify generated structure:
   - Check Zeitwerk compliance
   - Verify tests run (`bundle exec rspec`)
   - Verify RuboCop passes (`bundle exec rubocop`)
```

### Standard Options for Ruby AI/NLP Projects

```bash
rubysmith build my_ai_project \
  --zeitwerk \
  --rspec \
  --simple_cov \
  --docker \
  --git_hub_ci \
  --caliber

# Then manually add AI-specific gems:
# - ruby_llm
# - pgvector
# - sequel
# - dry-struct
# - dry-types
# - circuit_breaker
# - journald-logger
```

### Standard Options for Ruby TUI Projects

```bash
rubysmith build my_tui_project \
  --zeitwerk \
  --rspec \
  --docker \
  --git_hub_ci

# Then manually add TUI-specific gems:
# - bubbletea
# - lipgloss
# - huh
```

---

## Post-Generation Checklist

After running `rubysmith build`, verify:

- [ ] `bin/setup` runs successfully
- [ ] `bin/console` opens Pry REPL
- [ ] `bundle exec rspec` runs tests (even if none exist yet)
- [ ] `bundle exec rubocop` passes linting
- [ ] `.ruby-version` matches system Ruby
- [ ] `.gitignore` includes `.env` (if using dotenv)
- [ ] `lib/` directory follows Zeitwerk conventions
- [ ] `spec/` directory has `spec_helper.rb`
- [ ] Docker builds successfully (`docker compose build`)
- [ ] GitHub Actions CI is configured (`.github/workflows/ci.yml`)

---

## Customization Patterns

### Pattern 1: Add Dry-RB Stack

```bash
# After Rubysmith generation
cd my_project

# Add to Gemfile
cat >> Gemfile << 'EOF'

# Type safety and validation
gem "dry-struct"
gem "dry-types"
gem "dry-schema"
gem "dry-validation"
gem "dry-monads"
EOF

bundle install
```

### Pattern 2: Add AI/NLP Stack

```bash
cd my_project

# Add to Gemfile
cat >> Gemfile << 'EOF'

# AI/NLP
gem "ruby_llm"
gem "pgvector"
gem "sequel"
gem "dspy"
gem "pragmatic_segmenter"

# Resilience
gem "circuit_breaker"

# Logging
gem "journald-logger"

# Config
gem "dotenv", groups: [:development, :test]
EOF

bundle install

# Create .env template
cat > .env.example << 'EOF'
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
DATABASE_URL=postgresql://localhost/myapp_dev
EOF
```

### Pattern 3: Add Custom Scripts

```bash
cd my_project

# Add migration script
cat > bin/migrate << 'RUBY'
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/my_project"
require "sequel"

DB = Sequel.connect(ENV.fetch("DATABASE_URL"))
Sequel.extension :migration

Sequel::Migrator.run(DB, "db/migrations")
RUBY

chmod +x bin/migrate
```

---

## Common Workflows

### Workflow 1: Generate + Customize + Verify

```bash
# 1. Generate project
rubysmith build my_project --zeitwerk --rspec --docker

# 2. Customize Gemfile
cd my_project
# Add custom gems to Gemfile

# 3. Setup
bin/setup

# 4. Verify
bundle exec rspec
bundle exec rubocop
docker compose build
```

### Workflow 2: Minimal → Full Migration

```bash
# Start minimal
rubysmith build my_project --min

cd my_project

# Add features incrementally
rubysmith build my_project --rspec --rubocop --docker

# Note: This overwrites with new structure
# Better to start with full and remove if needed
```

### Workflow 3: Template for Team

```bash
# Create team template
rubysmith build project_template \
  --zeitwerk \
  --rspec \
  --simple_cov \
  --docker \
  --git_hub_ci \
  --caliber

cd project_template

# Add team-specific gems and config
# ...

# Commit to template repo
git init
git add .
git commit -m "Initial team template"
git remote add origin git@github.com:team/ruby-template.git
git push -u origin main

# Team members clone and rename
git clone git@github.com:team/ruby-template.git my_new_project
```

---

## Troubleshooting

### Issue 1: "rubysmith: command not found"

**Cause**: Not installed or not in PATH

```bash
# Fix: Install globally
gem install rubysmith

# Verify
which rubysmith
```

### Issue 2: Generated project has wrong Ruby version

**Cause**: `.ruby-version` doesn't match system Ruby

```bash
# Fix: Update .ruby-version
echo "3.3.0" > .ruby-version

# Or regenerate with correct Ruby
rubysmith build my_project --ruby-version=3.3.0
```

### Issue 3: bin/setup fails

**Cause**: Missing dependencies or wrong directory

```bash
# Fix: Ensure in project root
cd my_project

# Run setup
bin/setup

# If still fails, manually install
bundle install
```

---

## References

- [Rubysmith Documentation](https://alchemists.io/projects/rubysmith)
- [Rubysmith GitHub](https://github.com/bkuhlmann/rubysmith)
- [Zeitwerk](https://github.com/fxn/zeitwerk)
- [Caliber (RuboCop Config)](https://alchemists.io/projects/caliber)

---

**Last Updated**: 2026-05-25  
**Next Review**: After creating scaffold skill  
**Status**: Active Standard
