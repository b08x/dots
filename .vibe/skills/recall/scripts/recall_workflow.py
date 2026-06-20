#!/usr/bin/env python3
"""Multi-context session recall workflow.

Orchestrates extraction, correlation, and analysis across all session providers
with optional GitHub and restic backup integration.

Usage:
    python3 scripts/recall_workflow.py
    python3 scripts/recall_workflow.py --days 14 --github-repo owner/repo
"""

import subprocess
import json
import argparse
from pathlib import Path
from datetime import datetime, timezone, timedelta


# =============================================================================
# CONFIGURATION
# =============================================================================

DEFAULT_DAYS = 7
# Use 'all' to extract from all available tools in code-insights
# Or specify individual tools: ["claude-code", "gemini-cli", "hermes-agent", "opencode", "mistral-vibe"]
DEFAULT_PLATFORMS = ["all", "obsidian"]
OUTPUT_DIR = Path("/tmp/recall-output")

# Resolve paths relative to this script's directory (not cwd)
SCRIPT_DIR = Path(__file__).parent.resolve()
NORMALIZED_SESSIONS_SCRIPT = SCRIPT_DIR / "normalized_sessions.py"
OBSIDIAN_VIZ_SCRIPT = SCRIPT_DIR / "obsidian_viz.py"


# =============================================================================
# WORKFLOW STAGES
# =============================================================================

def stage_obsidian_viz(correlation_path: Path, days: int, vault_path: str = None) -> bool:
    """Generate Obsidian Dashboard and Canvas.
    
    Args:
        correlation_path: Path to correlation results JSON
        days: Number of days in timeframe
        vault_path: Optional path to Obsidian vault
        
    Returns:
        True if visualization generated, False otherwise
    """
    print(f"\n{'='*60}")
    print("STAGE 5: OBSIDIAN VISUALIZATION")
    print(f"{'='*60}")
    
    cmd = [
        "python3",
        str(OBSIDIAN_VIZ_SCRIPT),
        str(correlation_path),
        "--days", str(days)
    ]
    
    if vault_path:
        cmd.extend(["--vault", vault_path])
        
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.stdout:
            for line in result.stdout.strip().split('\n'):
                print(f"  {line}")
        
        if result.returncode != 0:
            print(f"  ✗ Visualization failed: {result.stderr}")
            return False
            
        return True
    except Exception as e:
        print(f"  ✗ Visualization error: {e}")
        return False


def stage_extract(days: int, platforms: list, output_path: Path) -> bool:
    """Extract sessions from all providers into normalized schema.
    
    This stage:
    - Discovers session files from each provider's storage location
    - Parses provider-specific formats (JSON, JSONL, SQLite)
    - Normalizes to unified ParsedSession schema
    - Outputs schema-consistent JSON for downstream processing
    
    Args:
        days: Number of days to look back
        platforms: List of provider names to extract from
        output_path: Path to save extracted sessions JSON
        
    Returns:
        True if extraction succeeded, False otherwise
    """
    print(f"\n{'='*60}")
    print("STAGE 1: MULTI-PROVIDER EXTRACTION")
    print(f"{'='*60}")
    print(f"  Time window: Last {days} days")
    print(f"  Providers: {', '.join(platforms)}")
    print(f"  Output: {output_path}")
    print()
    
    cmd = [
        "python3",
        str(NORMALIZED_SESSIONS_SCRIPT),
        "extract",
        "--days", str(days),
        "--platforms", ",".join(platforms),
        "--output", str(output_path)
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        # Print extraction summary
        if result.stdout:
            for line in result.stdout.strip().split('\n'):
                if line.startswith('[') or line.startswith('✓'):
                    print(f"  {line}")
        
        if result.returncode != 0:
            print(f"  ✗ Extraction failed: {result.stderr}")
            return False
            
        # Load and summarize extracted sessions
        if output_path.exists():
            with open(output_path) as f:
                data = json.load(f)
            total = sum(len(sessions) for sessions in data.values())
            print(f"\n  Total sessions extracted: {total}")
            for platform, sessions in data.items():
                if sessions:
                    print(f"    • {platform}: {len(sessions)} sessions")
        
        return True
        
    except Exception as e:
        print(f"  ✗ Extraction error: {e}")
        return False


def stage_correlate(days: int, github_repo: str, output_path: Path, model: str = "openai/gpt-4o-mini", no_github: bool = False) -> dict:
    """Correlate sessions with GitHub commits and generate timeline.

    This stage:
    - Auto-discovers GitHub repos with activity (or uses specified repo)
    - Fetches commits from all discovered/specified repos
    - Builds unified timeline from sessions + commits + backup diffs
    - Uses DSPy to synthesize narrative, workstreams, and next actions
    - Falls back to heuristics if DSPy unavailable

    Args:
        days: Number of days to analyze
        github_repo: GitHub repo in owner/name format (or None for auto-discovery)
        output_path: Path to save correlation results JSON
        model: DSPy-compatible model identifier
        no_github: Skip GitHub correlation entirely

    Returns:
        Correlation results dict with narrative, workstreams, next_actions, one_thing
    """
    print(f"\n{'='*60}")
    print("STAGE 2: MULTI-SOURCE CORRELATION")
    print(f"{'='*60}")
    print(f"  Time window: Last {days} days")
    if no_github:
        print(f"  GitHub: Skipped")
    elif github_repo:
        print(f"  GitHub repo: {github_repo}")
    else:
        print(f"  GitHub: Auto-discovering repos with activity")
    print(f"  Model: {model}")
    print(f"  Output: {output_path}")
    print()

    cmd = [
        "python3",
        str(NORMALIZED_SESSIONS_SCRIPT),
        "correlate",
        "--days", str(days),
        "--model", model,
        "--output", str(output_path)
    ]

    if github_repo:
        cmd.extend(["--github-repo", github_repo])
    elif no_github:
        cmd.extend(["--no-github"])
    
    # Run correlation (output is written to --output path by normalized_sessions.py)
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"  ✗ Correlation failed: {result.stderr}")
        return {}
    
    # Print progress messages from subprocess
    for line in result.stdout.strip().split('\n'):
        if line.startswith('[') or line.startswith('Fetching') or line.startswith('correlating'):
            print(f"  {line}")
    
    # Load results from file
    if not output_path.exists():
        print(f"  ✗ Output file not created: {output_path}")
        return {}
    
    with open(output_path) as f:
        results = json.load(f)
    
    # Display One Thing prominently
    correlation = results.get('correlation', {})
    if correlation.get('one_thing'):
        print(f"\n  ONE THING: {correlation['one_thing']}")
        if correlation.get('one_thing_reasoning'):
            print(f"  Reasoning: {correlation['one_thing_reasoning']}")
    
    return correlation


def stage_search(query: str, days: int, platforms: list) -> list:
    """Search sessions by topic keywords.
    
    This stage:
    - Extracts sessions from all providers
    - Performs keyword matching on title and content
    - Returns ranked list of matching sessions
    
    Args:
        query: Search query string
        days: Number of days to search
        platforms: List of providers to search
        
    Returns:
        List of matching session metadata dicts
    """
    print(f"\n{'='*60}")
    print("STAGE 3: TOPIC SEARCH")
    print(f"{'='*60}")
    print(f"  Query: '{query}'")
    print(f"  Time window: Last {days} days")
    print(f"  Providers: {', '.join(platforms)}")
    print()
    
    cmd = [
        "python3",
        str(NORMALIZED_SESSIONS_SCRIPT),
        "search",
        query,
        "--days", str(days)
    ]
    
    if platforms:
        cmd.extend(["--platforms", ",".join(platforms)])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"  ✗ Search failed: {result.stderr}")
            return []
        
        # Print results
        lines = result.stdout.strip().split('\n')
        for line in lines:
            if line.startswith('Found') or line.startswith('['):
                print(f"  {line}")
        
        # Try to parse results from output
        results = []
        for line in lines:
            if line.strip().startswith('['):
                # Parse session match format: [platform] title (N msgs)
                parts = line.split(']', 1)
                if len(parts) == 2:
                    platform = parts[0].strip('[').strip()
                    rest = parts[1].strip()
                    results.append({
                        'platform': platform,
                        'match': rest
                    })
        
        return results
        
    except Exception as e:
        print(f"  ✗ Search error: {e}")
        return []


def stage_export_integration(days: int, export_graphify: bool, export_qmd: bool, extracted_sessions: dict) -> bool:
    """Export sessions to graphify and/or QMD via code-insights skill.

    Args:
        days: Number of days in timeframe
        export_graphify: Whether to export to graphify
        export_qmd: Whether to export to QMD
        extracted_sessions: Dict of extracted sessions by platform

    Returns:
        True if export succeeded, False otherwise
    """
    print(f"\n{'='*60}")
    print("STAGE 6: EXPORT INTEGRATION")
    print(f"{'='*60}")

    # Find code-insights skill path
    code_insights_skill = Path.home() / ".vibe/skills/code-insights/code-insights"

    if not code_insights_skill.exists():
        print(f"  ⚠ code-insights skill not found at {code_insights_skill}")
        print(f"  Skipping export integration")
        return False

    # Count total sessions
    total_sessions = sum(len(sessions) for sessions in extracted_sessions.values())

    if export_graphify:
        print(f"\n  Exporting {total_sessions} sessions to graphify...")
        try:
            result = subprocess.run(
                [
                    "ruby",
                    str(code_insights_skill),
                    "export",
                    "--recent", str(days * 24),  # Convert days to hours
                    "--graphify"
                ],
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )

            if result.returncode == 0:
                print(f"  ✓ Graphify export complete")
                if result.stdout:
                    for line in result.stdout.strip().split('\n')[-5:]:  # Last 5 lines
                        print(f"    {line}")
            else:
                print(f"  ✗ Graphify export failed: {result.stderr}")
                return False

        except subprocess.TimeoutExpired:
            print(f"  ✗ Graphify export timed out (>5min)")
            return False
        except Exception as e:
            print(f"  ✗ Graphify export error: {e}")
            return False

    if export_qmd:
        print(f"\n  Exporting {total_sessions} sessions to QMD...")
        try:
            result = subprocess.run(
                [
                    "ruby",
                    str(code_insights_skill),
                    "export",
                    "--recent", str(days * 24),  # Convert days to hours
                    "--qmd-index"
                ],
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )

            if result.returncode == 0:
                print(f"  ✓ QMD export complete")
                if result.stdout:
                    for line in result.stdout.strip().split('\n')[-5:]:  # Last 5 lines
                        print(f"    {line}")
            else:
                print(f"  ✗ QMD export failed: {result.stderr}")
                return False

        except subprocess.TimeoutExpired:
            print(f"  ✗ QMD export timed out (>5min)")
            return False
        except Exception as e:
            print(f"  ✗ QMD export error: {e}")
            return False

    return True


def stage_one_thing(correlation: dict) -> str:
    """Generate the single highest-leverage next action.
    
    This stage:
    - Analyzes correlation results for workstreams and blockers
    - Uses DSPy OneThingGenerator signature for synthesis
    - Falls back to heuristic selection if DSPy unavailable
    
    Args:
        correlation: Correlation results from stage_correlate
        
    Returns:
        Single recommended action string
    """
    print(f"\n{'='*60}")
    print("STAGE 4: ONE THING GENERATION")
    print(f"{'='*60}")
    print()
    
    # Use correlation results to determine one thing
    if not correlation:
        print("  ⚠ No correlation data available")
        return "Review recent sessions to identify next steps"
    
    workstreams = correlation.get('workstreams', [])
    next_actions = correlation.get('next_actions', [])
    
    if next_actions:
        one_thing = next_actions[0]
    elif workstreams:
        one_thing = f"Continue {workstreams[0]} work"
    else:
        one_thing = "Review and synthesize recent activity"
    
    print(f"  Recommended action:\n")
    print(f"    → {one_thing}")
    print()
    
    return one_thing


# =============================================================================
# MAIN WORKFLOW
# =============================================================================

def run_workflow(days: int = DEFAULT_DAYS,
                 platforms: list = None,
                 github_repo: str = None,
                 search_query: str = None,
                 model: str = "openai/gpt-4o-mini",
                 vault_path: str = None,
                 no_github: bool = False,
                 export_graphify: bool = False,
                 export_qmd: bool = False) -> dict:
    """Execute the complete recall workflow.

    Pipeline:
    1. Extract sessions from all providers (normalized schema)
    2. Auto-discover and correlate GitHub commits (or skip with --no-github)
    3. Search for specific topics (if query provided)
    4. Generate single recommended action
    5. Generate Obsidian Dashboard and Canvas

    Args:
        days: Number of days to analyze
        platforms: List of providers to extract from
        github_repo: GitHub repo in owner/name format (None = auto-discover)
        search_query: Optional topic search query
        model: DSPy-compatible model identifier
        vault_path: Optional path to Obsidian vault
        no_github: Skip GitHub correlation entirely

    Returns:
        Dict with extracted_sessions, correlation, search_results, one_thing
    """
    platforms = platforms or DEFAULT_PLATFORMS
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    extract_path = OUTPUT_DIR / f"sessions_{timestamp}.json"
    correlate_path = OUTPUT_DIR / f"correlation_{timestamp}.json"
    
    print(f"\n{'#'*60}")
    print(f"# RECALL WORKFLOW - {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"{'#'*60}")
    
    results = {
        'extracted_sessions': {},
        'correlation': {},
        'search_results': [],
        'one_thing': None
    }
    
    # Stage 1: Extract
    if not stage_extract(days, platforms, extract_path):
        print("\n  ✗ Workflow halted: extraction failed")
        return results
    
    if extract_path.exists():
        with open(extract_path) as f:
            results['extracted_sessions'] = json.load(f)
    
    # Stage 2: Correlate
    correlation = stage_correlate(days, github_repo, correlate_path, model, no_github)
    results['correlation'] = correlation
    
    if correlate_path.exists():
        with open(correlate_path) as f:
            results['correlation'] = json.load(f).get('correlation', {})
    
    # Stage 3: Search (optional)
    if search_query:
        results['search_results'] = stage_search(search_query, days, platforms)
    
    # Stage 4: One Thing (use from correlation if available)
    if results['correlation'].get('one_thing'):
        results['one_thing'] = results['correlation']['one_thing']
        print(f"\n{'='*60}")
        print("STAGE 4: ONE THING GENERATION")
        print(f"{'='*60}")
        print(f"\n  Recommended action:\n")
        print(f"    → {results['one_thing']}")
        if results['correlation'].get('one_thing_reasoning'):
            print(f"\n  Reasoning: {results['correlation']['one_thing_reasoning']}")
        print()
    else:
        results['one_thing'] = stage_one_thing(results['correlation'])
    
    # Stage 5: Visualization
    stage_obsidian_viz(correlate_path, days, vault_path)

    # Stage 6: Optional Export Integration
    if export_graphify or export_qmd:
        stage_export_integration(days, export_graphify, export_qmd, results['extracted_sessions'])

    # Summary
    print(f"\n{'='*60}")
    print("WORKFLOW COMPLETE")
    print(f"{'='*60}")
    total_sessions = sum(len(s) for s in results['extracted_sessions'].values())
    print(f"  Sessions extracted: {total_sessions}")
    print(f"  Workstreams identified: {len(results['correlation'].get('workstreams', []))}")
    print(f"  Search matches: {len(results['search_results'])}")
    print(f"\n  ONE THING: {results['one_thing']}")
    print(f"\n  Output directory: {OUTPUT_DIR}")
    print(f"{'='*60}\n")
    
    return results


def main():
    global OUTPUT_DIR  # Allow override from command line
    
    parser = argparse.ArgumentParser(
        description="Multi-context session recall workflow",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument("--days", type=int, default=DEFAULT_DAYS,
                        help=f"Days to analyze (default: {DEFAULT_DAYS})")
    
    parser.add_argument("--platforms", 
                        help="Comma-separated providers (default: all)")
    
    parser.add_argument("--github-repo",
                        help="GitHub repo in owner/name format (if not specified, auto-discovers repos with activity)")

    parser.add_argument("--no-github", action="store_true",
                        help="Skip GitHub correlation entirely (no auto-discovery)")
    
    parser.add_argument("--search",
                        help="Optional topic search query")
    
    parser.add_argument("--model", default="openai/gpt-4o-mini",
                        help="DSPy model (default: openai/gpt-4o-mini)")
    
    parser.add_argument("--output", type=Path, default=None,
                        help=f"Output directory (default: {OUTPUT_DIR})")
    
    parser.add_argument("--vault", help="Obsidian vault path")

    parser.add_argument("--export-graphify", action="store_true",
                        help="Export sessions to graphify after correlation")

    parser.add_argument("--export-qmd", action="store_true",
                        help="Export sessions to QMD after correlation")

    args = parser.parse_args()
    
    platforms = args.platforms.split(",") if args.platforms else None
    
    if args.output:
        OUTPUT_DIR = args.output
    
    run_workflow(
        days=args.days,
        platforms=platforms,
        github_repo=args.github_repo,
        search_query=args.search,
        model=args.model,
        vault_path=args.vault,
        no_github=args.no_github,
        export_graphify=args.export_graphify,
        export_qmd=args.export_qmd
    )


if __name__ == "__main__":
    main()
