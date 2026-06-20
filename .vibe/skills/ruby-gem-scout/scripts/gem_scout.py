#!/usr/bin/env python3
"""
gem_scout.py
Main script for ruby-gem-scout skill.

Takes a project description, queries RubyGems from inventory CSV,
consults Context7 MCP for each gem to learn how to use it in the project context,
and generates a project scaffold with Gemfile and comprehensive usage guide.
"""

import argparse
import csv
import json
import os
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import yaml

# Constants
SKILL_DIR = Path("~/.vibe/skills/ruby-gem-scout").expanduser()
# Use the authoritative gem inventory from rubysmithing context
INVENTORY_PATH = Path(
    "/home/b08x/Workspace/Syncopated/vibe-agents/skills/context/references/gems-inventory.csv"
)
REGISTRY_PATH = Path(
    "/home/b08x/Workspace/Syncopated/vibe-agents/skills/context/references/gem-registry.md"
)
DEFAULT_OUTPUT_DIR = Path.cwd()

# Fallback paths if primary not found
FALLBACK_INVENTORY = SKILL_DIR / "references" / "gems-inventory.csv"
FALLBACK_REGISTRY = SKILL_DIR / "references" / "gem-registry.md"


def get_inventory_path() -> Path:
    """Get the path to the gems inventory CSV."""
    if INVENTORY_PATH.exists():
        return INVENTORY_PATH
    if FALLBACK_INVENTORY.exists():
        return FALLBACK_INVENTORY
    return SKILL_DIR / "references" / "gems-inventory.csv"


def get_registry_path() -> Path:
    """Get the path to the gem registry MD."""
    if REGISTRY_PATH.exists():
        return REGISTRY_PATH
    if FALLBACK_REGISTRY.exists():
        return FALLBACK_REGISTRY
    return SKILL_DIR / "references" / "gem-registry.md"


def load_gem_inventory() -> List[Dict[str, str]]:
    """Load the gem inventory from CSV file."""
    inventory_path = get_inventory_path()

    if not inventory_path.exists():
        print(f"Warning: Gem inventory not found at {inventory_path}")
        # Return a minimal default
        return [
            {
                "gem": "rails",
                "version": ">= 7.1.0",
                "category": "genai",
                "description": "Web framework",
                "homepage": "",
                "context7_id": "/rails/rails",
            },
            {
                "gem": "pg",
                "version": ">= 1.1",
                "category": "rag",
                "description": "PostgreSQL adapter",
                "homepage": "",
                "context7_id": "/ged/ruby-pg",
            },
            {
                "gem": "devise",
                "version": ">= 5.0",
                "category": "genai",
                "description": "Authentication",
                "homepage": "",
                "context7_id": "/heartcombo/devise",
            },
            {
                "gem": "sidekiq",
                "version": ">= 7.0",
                "category": "genai",
                "description": "Background jobs",
                "homepage": "",
                "context7_id": "/mperham/sidekiq",
            },
        ]

    gems = []
    with open(inventory_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            gems.append(row)

    return gems


def load_registry_context7_ids() -> Dict[str, str]:
    """Extract Context7 IDs from gem-registry.md."""
    registry_path = get_registry_path()

    if not registry_path.exists():
        return {}

    context7_ids = {}

    with open(registry_path, "r") as f:
        content = f.read()

    # Parse markdown tables for Context7 IDs
    # Look for patterns like: | Gem | Context7 ID | ... |
    #                       |-----|--------------| ... |
    #                       | gem_name | /org/repo | ... |

    lines = content.split("\n")
    in_table = False
    header_indices = {}

    for line in lines:
        # Check if we're in a table
        if line.strip().startswith("|") and line.strip().endswith("|"):
            # Parse table row
            cells = [c.strip() for c in line.split("|")[1:-1]]

            # Check if this is a header row
            if "Gem" in cells and "Context7" in " ".join(cells):
                in_table = True
                # Find column indices
                for i, cell in enumerate(cells):
                    if "Gem" in cell:
                        header_indices["gem"] = i
                    if "Context7" in cell or "context7" in cell.lower():
                        header_indices["context7"] = i
                continue

            if in_table and cells and len(cells) > 1:
                # Try to extract gem name and context7 ID
                gem_col = header_indices.get("gem", 0)
                ctx_col = header_indices.get("context7", 1)

                if gem_col < len(cells) and ctx_col < len(cells):
                    gem_name = cells[gem_col]
                    context7_id = cells[ctx_col]

                    if (
                        gem_name
                        and context7_id
                        and context7_id != "—"
                        and context7_id != "-"
                    ):
                        context7_ids[gem_name.lower()] = context7_id

            # Check if we're leaving the table
            if line.strip() == "|" + "---|" * (len(cells)):
                in_table = True
            elif in_table and not any(
                c.strip() and c.strip()[0].isalpha() for c in cells
            ):
                in_table = False
        else:
            in_table = False

    return context7_ids


def get_context7_id(
    gem_name: str, inventory: List[Dict], registry_ids: Dict[str, str]
) -> Optional[str]:
    """Get Context7 ID for a gem from inventory or registry."""
    gem_lower = gem_name.lower()

    # First try inventory CSV
    for item in inventory:
        if item.get("gem", "").lower() == gem_lower:
            ctx_id = item.get("context7_id", "")
            if ctx_id and ctx_id.strip():
                return ctx_id

    # Then try registry
    if gem_lower in registry_ids:
        return registry_ids[gem_lower]

    # Generate a default based on common patterns
    # Many Ruby gems are on GitHub under the same name
    return f"/{gem_name}/{gem_name}"


def match_gems_to_description(
    description: str, inventory: List[Dict]
) -> List[Tuple[str, str, str]]:
    """
    Match gems from inventory to project description.
    Returns list of (gem_name, category, description) tuples sorted by relevance.
    """
    matched = []
    description_lower = description.lower()

    # Extract keywords from description (words and multi-word phrases)
    keywords = re.findall(r"\b[a-z]+(?:\s+[a-z]+)*\b", description_lower)
    keyword_set = set(re.findall(r"\b[a-z]+\b", description_lower))

    for item in inventory:
        gem = item.get("gem", "")
        if not gem:
            continue

        gem_lower = gem.lower()
        category = item.get("category", "misc")
        gem_desc = item.get("description", "")

        score = 0
        reasons = []

        # Direct gem name match
        if gem_lower in description_lower:
            score += 100
            reasons.append("exact gem name")

        # Gem name contains keyword
        if any(kw in gem_lower for kw in keyword_set):
            score += 50
            reasons.append("gem name contains keyword")

        # Category match
        if category and any(kw in category.lower() for kw in keyword_set):
            score += 30
            reasons.append("category match")

        # Description match
        if gem_desc and any(kw in gem_desc.lower() for kw in keyword_set):
            score += 20
            reasons.append("description match")

        if score > 0:
            matched.append((gem, category, gem_desc, score, ", ".join(reasons)))

    # Sort by score (descending), then by gem name
    matched.sort(key=lambda x: (-x[3], x[0]))

    # Return unique gems with their best match
    seen = set()
    result = []
    for gem, category, desc, _, _ in matched:
        if gem not in seen:
            seen.add(gem)
            result.append((gem, category, desc))

    return result


def query_context7(
    gem_name: str, project_description: str, library_id: str
) -> Dict[str, Any]:
    """
    Query Context7 MCP for gem documentation.

    In the Vibe agent context, this would call the context7_query-docs tool.
    For this script, we return a structured query that can be executed.
    """
    query = f"""How to use {gem_name} in a Ruby project?

Project context: {project_description}

Please provide:
1. Brief overview of {gem_name}'s purpose
2. Installation instructions (Gemfile entry)
3. Basic usage example in Ruby
4. Common configuration options
5. Best practices for using {gem_name}
6. Any dependencies or requirements
7. Links to official documentation
8. Any project-specific recommendations based on the context above
"""

    return {
        "gem": gem_name,
        "library_id": library_id,
        "query": query,
        "status": "ready",
        "message": f"Query ready for {gem_name}",
    }


def get_gem_version(gem_name: str, inventory: List[Dict]) -> str:
    """Get the version constraint for a gem from inventory."""
    gem_lower = gem_name.lower()

    for item in inventory:
        if item.get("gem", "").lower() == gem_lower:
            version = item.get("version", "")
            if version:
                return version

    # Default version constraints for common gems
    version_map = {
        "rails": ">= 7.1.0",
        "pg": ">= 1.5.0",
        "mysql2": ">= 0.5.0",
        "sqlite3": ">= 1.6.0",
        "devise": ">= 4.9.0",
        "sidekiq": ">= 7.2.0",
        "redis": ">= 5.0.0",
        "faraday": ">= 2.9.0",
        "httparty": ">= 0.22.0",
        "nokogiri": ">= 1.16.0",
        "json": ">= 2.6.0",
        "jwt": ">= 2.3.0",
        "bcrypt": ">= 3.1.0",
        "rspec": ">= 3.13.0",
        "factory_bot": ">= 6.4.0",
        "capybara": ">= 3.40.0",
        "stripe": ">= 12.0.0",
        "grape": ">= 1.10.0",
        "sinatra": ">= 3.1.0",
    }

    return version_map.get(gem_name, ">= 0")


def generate_gemfile(gems: List[Tuple[str, str, str]], inventory: List[Dict]) -> str:
    """Generate a Gemfile with the selected gems."""
    lines = [
        "# Generated by ruby-gem-scout",
        "# https://github.com/mistralai/mistral-vibe",
        "source 'https://rubygems.org'",
        "",
    ]

    # Group gems by category for better organization
    categories = {}
    for gem, category, _ in gems:
        if category not in categories:
            categories[category] = []
        categories[category].append(gem)

    # Define category display order
    category_order = [
        "genai",
        "web",
        "api",
        "agentic",
        "rag",
        "nlp",
        "media",
        "misc",
        "devops",
        "plugin",
        "tui",
        "game",
        "data",
        "testing",
        "security",
        "database",
        "cache",
        "jobs",
    ]

    for category in category_order:
        if category in categories:
            # Add category comment
            lines.append(f"# ===== {category.upper()} =====")
            for gem in sorted(categories[category]):
                version = get_gem_version(gem, inventory)
                lines.append(f"gem '{gem}', '{version}'")
            lines.append("")

    # Add any remaining categories
    for category, gems_list in categories.items():
        if category not in category_order:
            lines.append(f"# ===== {category.upper()} =====")
            for gem in sorted(gems_list):
                version = get_gem_version(gem, inventory)
                lines.append(f"gem '{gem}', '{version}'")
            lines.append("")

    lines.extend(
        [
            "",
            "# Windows does not include zoneinfo files, so bundle the tzinfo-data gem",
            "gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]",
            "",
            "# Reduces boot time through caching; required in config/boot.rb",
            "gem 'bootsnap', require: false",
        ]
    )

    return "\n".join(lines)


def generate_gem_guide(
    gems: List[Tuple[str, str, str]],
    project_description: str,
    context7_results: Dict[str, Dict],
    inventory: List[Dict],
) -> str:
    """Generate a comprehensive project_gem_guide.md."""
    lines = [
        "# Project Gem Guide",
        "",
        "> **Generated by ruby-gem-scout**",
        "> Mistral Vibe Skill for Ruby project scaffolding",
        "",
        f"## Project Description\n\n{project_description}",
        "",
        "---",
        "",
        "## Gem Index",
        "",
    ]

    # Create index by category
    categories = {}
    for gem, category, desc in gems:
        if category not in categories:
            categories[category] = []
        categories[category].append((gem, desc))

    for category, gem_list in sorted(categories.items()):
        lines.append(f"### {category.replace('_', ' ').title()}")
        lines.append("")
        for gem, desc in gem_list:
            version = get_gem_version(gem, inventory)
            lines.append(
                f"- **[{gem}](https://rubygems.org/gems/{gem})** v{version}: {desc or 'No description'}"
            )
        lines.append("")

    lines.extend(
        [
            "---",
            "",
            "## Gem Documentation",
            "",
        ]
    )

    # Detailed documentation for each gem
    for gem, category, desc in gems:
        lines.append(f"### `{gem}`")
        lines.append("")

        result = context7_results.get(gem, {})
        version = get_gem_version(gem, inventory)
        homepage = ""
        context7_id = ""

        # Find gem in inventory
        for item in inventory:
            if item.get("gem", "").lower() == gem.lower():
                homepage = item.get("homepage", "")
                context7_id = item.get("context7_id", "")
                break

        # Basic info
        lines.append(f"- **Category**: {category}")
        lines.append(f"- **Version**: `{version}`")
        if homepage:
            lines.append(f"- **Homepage**: {homepage}")
        if context7_id:
            lines.append(f"- **Context7**: {context7_id}")
        lines.append("")

        # Description from inventory
        if desc:
            lines.append(f"- **Purpose**: {desc}")
            lines.append("")

        # Installation
        lines.append("- **Installation**:")
        lines.append(f"  ```ruby")
        lines.append(f"  gem '{gem}', '{version}'")
        lines.append(f"  ```")
        lines.append("")

        # Context7 query status
        if result.get("status") == "ready":
            lines.append("- **Context7 Query**: Ready to execute")
            lines.append(f"  - Library ID: `{result['library_id']}`")
            lines.append("")
            lines.append("  Run the following query in Context7:")
            lines.append("")
            lines.append(f"  ```")
            lines.append(f"  {result['query']}")
            lines.append(f"  ```")
            lines.append("")
        elif result.get("error"):
            lines.append(f"- **Error**: {result['error']}")
            lines.append("")

        # RubyGems link
        lines.append("- **Resources**:")
        lines.append(f"  - [RubyGems](https://rubygems.org/gems/{gem})")
        if homepage:
            lines.append(f"  - [Homepage]({homepage})")
        lines.append("")

        lines.append("---")
        lines.append("")

    # Quick Start section
    lines.extend(
        [
            "## Quick Start",
            "",
            "1. **Create your project directory**",
            "   ```bash",
            "   mkdir my_project",
            "   cd my_project",
            "   ```",
            "",
            "2. **Copy the Gemfile**",
            "   ```bash",
            "   cp ../Gemfile .",
            "   ```",
            "",
            "3. **Install dependencies**",
            "   ```bash",
            "   bundle install",
            "   ```",
            "",
            "4. **Query Context7 for each gem**",
            "   Use the queries provided above for each gem to get detailed usage information.",
            "",
            "5. **Consult the official documentation**",
            "   Each gem section includes links to RubyGems and homepage for reference.",
            "",
        ]
    )

    # Next Steps
    lines.extend(
        [
            "## Next Steps",
            "",
            "- [ ] Review each gem's documentation",
            "- [ ] Query Context7 for gems marked as 'ready'",
            "- [ ] Set up database and other required services",
            "- [ ] Configure each gem according to your project needs",
            "- [ ] Add your application code",
            "- [ ] Run `bundle outdated` to check for newer versions",
            "",
        ]
    )

    # Notes
    lines.extend(
        [
            "## Notes",
            "",
            f"- Generated for project: {project_description[:100]}",
            f"- Total gems: {len(gems)}",
            "- This guide was generated automatically by ruby-gem-scout",
            "- Some gems may require additional setup steps not covered here",
            "- Always check the official documentation for the most up-to-date information",
            "- Context7 queries can be re-run at any time to get updated documentation",
            "",
        ]
    )

    return "\n".join(lines)


def generate_project_name(description: str) -> str:
    """Generate a project name from the description."""
    # Remove special characters and normalize
    name = re.sub(r"[^a-zA-Z0-9\s-]", "", description)
    name = name.strip().lower()
    name = re.sub(r"\s+", "-", name)
    return name[:50]  # Limit length


def main():
    parser = argparse.ArgumentParser(
        description="Ruby Gem Scout - Generate project scaffold with recommended gems"
    )
    parser.add_argument(
        "--description",
        "-d",
        type=str,
        required=True,
        help="Project description (e.g., 'A Rails API for e-commerce with Stripe payments')",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Output directory (default: current directory)",
    )
    parser.add_argument(
        "--max-gems",
        type=int,
        default=25,
        help="Maximum number of gems to include (default: 25)",
    )
    parser.add_argument(
        "--min-score",
        type=int,
        default=20,
        help="Minimum match score to include a gem (default: 20)",
    )
    parser.add_argument(
        "--query-context7",
        action="store_true",
        help="Actually query Context7 MCP (otherwise just prepare queries)",
    )

    args = parser.parse_args()

    print("=" * 60)
    print("Ruby Gem Scout")
    print("=" * 60)
    print()

    # Load gem inventory
    print("Loading gem inventory...")
    inventory = load_gem_inventory()
    print(f"  Loaded {len(inventory)} gems from inventory")

    # Load registry Context7 IDs
    print("Loading gem registry...")
    registry_ids = load_registry_context7_ids()
    print(f"  Loaded {len(registry_ids)} Context7 IDs from registry")

    # Match gems to description
    print(f"\nAnalyzing project description: '{args.description}'")
    matched_gems = match_gems_to_description(args.description, inventory)

    # Filter by minimum score
    matched_gems = [
        (g, c, d)
        for g, c, d in matched_gems
        if any(
            args.description.lower().count(kw) > 0
            for kw in re.findall(r"\b[a-z]+\b", g.lower() + c.lower() + d.lower())
        )
        or g.lower() in args.description.lower()
    ]

    # Limit results
    selected_gems = matched_gems[: args.max_gems]

    if not selected_gems:
        print("No gems matched your description. Try providing more details.")
        return

    print(f"\nFound {len(selected_gems)} matching gems:")
    for gem, category, desc in selected_gems:
        version = get_gem_version(gem, inventory)
        ctx_id = get_context7_id(gem, inventory, registry_ids)
        print(f"  - {gem:25} v{version:15} [{category:10}] -> {ctx_id}")

    # Query Context7 for each gem
    print("\nPreparing Context7 queries...")
    context7_results = {}

    for gem, category, desc in selected_gems:
        ctx_id = get_context7_id(gem, inventory, registry_ids)
        result = query_context7(gem, args.description, ctx_id)
        context7_results[gem] = result

    print(f"  Prepared {len(context7_results)} Context7 queries")

    # Generate output
    print("\nGenerating project scaffold...")

    project_name = generate_project_name(args.description)
    project_dir = args.output / project_name
    project_dir.mkdir(parents=True, exist_ok=True)

    # Generate Gemfile
    gemfile_content = generate_gemfile(selected_gems, inventory)
    gemfile_path = project_dir / "Gemfile"
    gemfile_path.write_text(gemfile_content)
    print(f"  ✓ Created: {gemfile_path}")

    # Generate project_gem_guide.md
    guide_content = generate_gem_guide(
        selected_gems, args.description, context7_results, inventory
    )
    guide_path = project_dir / "project_gem_guide.md"
    guide_path.write_text(guide_content)
    print(f"  ✓ Created: {guide_path}")

    # Generate README
    readme_content = f"""# {project_name.replace("-", " ").title()}

> {args.description}

---

## 🚀 Quick Start

This project was scaffolded by **ruby-gem-scout** - a Mistral Vibe skill for Ruby project generation.

### Setup

1. **Install dependencies:**
   ```bash
   cd {project_name}
   bundle install
   ```

2. **Review the gems:**
   See [{project_name}/project_gem_guide.md](./project_gem_guide.md) for complete documentation.

3. **Query Context7:**
   The guide includes prepared queries for Context7 MCP to get detailed usage information.

### Project Structure

- `Gemfile` - Ruby dependencies with version constraints
- `project_gem_guide.md` - Comprehensive gem documentation with Context7 queries
- `README.md` - This file

### Next Steps

- [ ] Run `bundle install` to install all gems
- [ ] Query Context7 for each gem using the provided queries
- [ ] Configure gems according to your project needs
- [ ] Add your application code

---

## 📦 Included Gems ({len(selected_gems)} total)

"""

    for gem, category, desc in selected_gems:
        version = get_gem_version(gem, inventory)
        readme_content += f"\n- **{gem}** ({category}): {desc or 'No description'}"

    readme_content += f"\n\n---\n\n## 📚 Documentation\n\n"
    readme_content += f"See [project_gem_guide.md](./project_gem_guide.md) for detailed documentation.\n\n"
    readme_content += f"---\n\n"
    readme_content += (
        f"Generated by [ruby-gem-scout](~/.vibe/skills/ruby-gem-scout/SKILL.md)\n"
    )

    readme_path = project_dir / "README.md"
    readme_path.write_text(readme_content)
    print(f"  ✓ Created: {readme_path}")

    # Generate .gitignore
    gitignore_content = """# Ignore bundler config
/.bundle/

# Ignore the default database
*.sqlite3

# Ignore log files
*.log
*.log.*
log/*

# Ignore tmp and temp files
tmp/**/*
temp/**/*

# Ignore environment files
.env
.env.local
.env.*.local

# Ignore IDE files
.idea/
.vscode/
*.swp
*.swo

# Ignore OS files
.DS_Store
Thumbs.db

# Ignore coverage reports
coverage/

# Ignore YARD documentation
doc/
"""
    gitignore_path = project_dir / ".gitignore"
    gitignore_path.write_text(gitignore_content)
    print(f"  ✓ Created: {gitignore_path}")

    print(f"\n{'=' * 60}")
    print(f"Project scaffold created at: {project_dir}")
    print(f"{'=' * 60}")
    print(f"\nNext steps:")
    print(f"  1. cd {project_name}")
    print(f"  2. bundle install")
    print(f"  3. Review project_gem_guide.md")
    print(f"  4. Query Context7 for gem-specific documentation")
    print(f"\nTotal gems: {len(selected_gems)}")
    print(f"Context7 queries prepared: {len(context7_results)}")


if __name__ == "__main__":
    main()
