---
name: ruby-gem-scout
description: >
  A skill that takes a Ruby project description, queries the authoritative
  RubyGems inventory CSV and registry from rubysmithing context, matches
  relevant gems, consults Context7 MCP for each gem to learn how to use
  it in the project context, and creates a project scaffold with Gemfile
  and comprehensive project_gem_guide.md.
user-invocable: true
allowed-tools:
  - read_file
  - write_file
  - grep
  - context7_resolve-library-id
  - context7_query-docs
  - bash
  - search_replace
---

# Ruby Gem Scout

## Overview

This skill automates the process of discovering, documenting, and scaffolding RubyGems for a new project. It uses the **authoritative gem inventory and registry** from the rubysmithing context to ensure comprehensive and up-to-date gem coverage.

### What It Does

1. **Accepts a project description** - Describe your Ruby project (e.g., "A Rails API for e-commerce with Stripe payments and PostgreSQL")

2. **Queries authoritative gem sources** - Uses:
   - `/home/b08x/Workspace/Syncopated/vibe-agents/skills/context/references/gems-inventory.csv` - 500+ gems with categories, versions, and Context7 IDs
   - `/home/b08x/Workspace/Syncopated/vibe-agents/skills/context/references/gem-registry.md` - Curated gem information with architectural roles

3. **Intelligent gem matching** - Matches gems to your project based on:
   - Direct gem name matches in description
   - Keyword matching in gem names
   - Category matching (genai, web, api, agentic, rag, nlp, etc.)
   - Description matching

4. **Context7 MCP consultation** - For each matched gem:
   - Resolves the Context7 library ID from inventory/registry
   - Generates project-context-aware queries
   - Returns structured documentation requests

5. **Scaffold generation** - Creates:
   - `Gemfile` with all selected gems and version constraints
   - `project_gem_guide.md` with comprehensive documentation
   - `README.md` with project overview
   - `.gitignore` with common exclusions

## Dependencies

- **Primary**: Access to the rubysmithing gem inventory CSV and registry MD
- **MCP**: Context7 access for gem documentation queries
- **Python**: For running the gem_scout.py script

## Instructions

### Basic Usage

```bash
/ruby-gem-scout --description "<your_project_description>"
```

### Examples

```bash
# Rails API with authentication
/ruby-gem-scout --description "A Rails REST API for user management with JWT authentication and PostgreSQL"

# CLI tool with AI
/ruby-gem-scout --description "A CLI application that uses RubyLLM for natural language processing"

# Full-stack web app
/ruby-gem-scout --description "Full-stack Rails app with Hotwire, Tailwind CSS, and Sidekiq for background jobs"
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--description, -d` | Project description (required) | - |
| `--output, -o` | Output directory | Current directory |
| `--max-gems` | Maximum gems to include | 25 |
| `--min-score` | Minimum match score | 20 |
| `--query-context7` | Actually query Context7 MCP | False (simulated) |

## Workflow

### Step 1: Gem Matching
The skill analyzes your project description and matches gems from the inventory using:
- **Exact matches**: If you mention "rails" or "devise" in your description
- **Keyword matching**: Matches keywords like "api", "auth", "database" to gem names
- **Category matching**: Matches project type keywords to gem categories (genai, web, rag, etc.)
- **Description matching**: Matches against gem descriptions in the inventory

### Step 2: Context7 Preparation
For each matched gem, the skill:
1. Resolves the Context7 library ID from the inventory CSV (preferred) or registry MD
2. Generates a project-context-aware query
3. Prepares the query for execution via Context7 MCP

Example query for "rails" with project "API for e-commerce":
```
How to use rails in a Ruby project?

Project context: API for e-commerce

Please provide:
1. Brief overview of rails' purpose
2. Installation instructions (Gemfile entry)
3. Basic usage example in Ruby
4. Common configuration options
5. Best practices for using rails
6. Any dependencies or requirements
7. Links to official documentation
8. Any project-specific recommendations
```

### Step 3: Scaffold Generation
Creates a project directory with:

```
project-name/
├── Gemfile                    # All gems with version constraints
├── Gemfile.lock               # (Optional, can be generated)
├── project_gem_guide.md       # Comprehensive gem documentation
├── README.md                  # Project overview
└── .gitignore                 # Standard exclusions
```

## Output Files

### Gemfile
- Organized by category (genai, web, api, agentic, rag, etc.)
- Includes version constraints from inventory
- Adds standard gems (tzinfo-data, bootsnap)

### project_gem_guide.md
Contains:
- **Gem Index**: Organized by category with links to RubyGems
- **Detailed Documentation** for each gem:
  - Category, version, homepage, Context7 ID
  - Purpose/description
  - Installation instructions
  - Prepared Context7 query (ready to execute)
  - Links to RubyGems and official documentation
- **Quick Start**: Step-by-step setup instructions
- **Next Steps**: Checklist for project completion
- **Notes**: Metadata about the generated scaffold

### README.md
- Project description
- Quick start instructions
- List of included gems
- Links to documentation

## Gem Categories

The skill uses the following categories from the rubysmithing inventory:

| Category | Description | Example Gems |
|----------|-------------|--------------|
| genai | General AI/ML | rails, devise, sidekiq |
| web | Web development | sinatra, grape, rack |
| api | API development | jwt, faraday, httparty |
| agentic | Agent frameworks | bubbletea, ruby_llm, dspy |
| rag | Retrieval-Augmented Generation | async, circuit_breaker, pgvector |
| nlp | Natural Language Processing | ruby-spacy, lingua, hugging-face |
| media | Media processing | mini_magick, ruby-vips, pdf-reader |
| misc | Miscellaneous | nokogiri, json, yaml |
| devops | DevOps tools | kamal, capybara, rspec |
| plugin | Plugins/extensions | pry, byebug, better_errors |
| tui | Terminal UI | lipgloss, bubbles, glamour |

## Context7 Integration

### Library ID Resolution
The skill resolves Context7 library IDs in this order:

1. **Inventory CSV** (`context7_id` column) - Primary source
2. **Registry MD** (parsed from markdown tables) - Secondary source
3. **Default pattern** (`/{gem}/{gem}`) - Fallback

### Query Generation
Each Context7 query is customized with:
- The gem name
- The full project description for context
- Specific requests for:
  - Purpose overview
  - Installation instructions
  - Usage examples
  - Configuration options
  - Best practices
  - Dependencies
  - Official documentation links
  - Project-specific recommendations

## Error Handling

| Scenario | Behavior |
|----------|----------|
| No gems match | Suggests broader description |
| Gem inventory not found | Uses fallback with common gems |
| Context7 ID not found | Generates default ID pattern |
| No Context7 access | Prepares queries without execution |

## Configuration

### Custom Inventory
To use a custom gem inventory, pass the `--inventory` argument or ensure your inventory is at:
- Primary: `/home/b08x/Workspace/Syncopated/vibe-agents/skills/context/references/gems-inventory.csv`
- Fallback: `~/.vibe/skills/ruby-gem-scout/references/gems-inventory.csv`

### Custom Registry
Similarly for the registry:
- Primary: `/home/b08x/Workspace/Syncopated/vibe-agents/skills/context/references/gem-registry.md`
- Fallback: `~/.vibe/skills/ruby-gem-scout/references/gem-registry.md`

## Usage in Vibe Agent Context

When invoked as a Vibe skill, the `query_context7` function would call the actual Context7 MCP tools:

```python
# In a Vibe agent, this would be:
from mistral_vibe import context7_query_docs

result = context7_query_docs(
    libraryId=library_id,
    query=query
)
```

For standalone usage, the skill prepares the queries for manual execution.

---

## File References

All file paths in this skill use absolute paths:
- **Main script**: `~/.vibe/skills/ruby-gem-scout/scripts/gem_scout.py`
- **Skill definition**: `~/.vibe/skills/ruby-gem-scout/SKILL.md`
- **Default inventory**: `~/.vibe/skills/ruby-gem-scout/references/gems-inventory.csv`
- **Default registry**: `~/.vibe/skills/ruby-gem-scout/references/gem-registry.md`
- **Primary inventory**: `/home/b08x/Workspace/Syncopated/vibe-agents/skills/context/references/gems-inventory.csv`
- **Primary registry**: `/home/b08x/Workspace/Syncopated/vibe-agents/skills/context/references/gem-registry.md`
