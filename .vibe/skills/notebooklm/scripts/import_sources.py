#!/usr/bin/env python3
"""Import NotebookLM sources into vault as notebook-source files.

Usage:
  python3 import_sources.py --sources /tmp/sources.json --slug my-notebook --dashboard "Dashboard Title"
  python3 import_sources.py --sources /tmp/sources.json --slug my-notebook --dashboard "Dashboard Title" --skip-guides
  python3 import_sources.py --sources /tmp/sources.json --slug my-notebook --dashboard "Dashboard Title" --skip-fulltext
  python3 import_sources.py --sources /tmp/sources.json --slug my-notebook --dashboard "Dashboard Title" --skip-mindmap

Creates one .md file per source with frontmatter + AI source guide + full text + mermaid mind map.

Notes:
  - Fulltext is fetched via --json to avoid the 2KB terminal truncation on plain output.
  - Mind maps are converted to Mermaid mindmap syntax (indentation-based tree).
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

VAULT = Path.cwd()  # Expected to run from vault root

# Map NotebookLM type strings to our source_type values
TYPE_MAP = {
    "SourceType.YOUTUBE": "youtube",
    "SourceType.WEB_PAGE": "web",
    "SourceType.PDF": "pdf",
    "SourceType.TEXT": "text",
    "SourceType.GOOGLE_DOCS": "gdocs",
    "SourceType.GOOGLE_SLIDES": "gslides",
}


def safe_filename(title: str) -> str:
    """Make title safe for filesystem."""
    title = re.sub(r'[/:*?"<>|]', "-", title)
    title = re.sub(r"\s+", " ", title).strip()
    if len(title) > 120:
        title = title[:120].rstrip(" -")
    return title


def fetch_guide(source_id: str) -> tuple[str, list[str], list[str]]:
    """Fetch AI-generated source guide. Returns (summary, topics, keywords)."""
    try:
        result = subprocess.run(
            ["notebooklm", "source", "guide", source_id, "--json"],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            return "", [], []
        data = json.loads(result.stdout)
        return data.get("summary", ""), data.get("topics", []), data.get("keywords", [])
    except Exception:
        return "", [], []


def fetch_fulltext(source_id: str) -> str:
    """Fetch full source text.

    Plain `notebooklm source fulltext <id>` truncates to ~2KB in the terminal.
    Using --json and extracting .content avoids this limit (PDFs can be 35KB+).
    """
    try:
        result = subprocess.run(
            ["notebooklm", "source", "fulltext", source_id, "--json"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode != 0:
            return ""
        data = json.loads(result.stdout)
        return data.get("content", "")
    except Exception:
        return ""


def fetch_mindmap(source_id: str) -> dict:
    """Fetch mind map data for a source. Returns raw data dict or empty dict."""
    try:
        result = subprocess.run(
            ["notebooklm", "source", "mindmap", source_id, "--json"],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            return {}
        return json.loads(result.stdout)
    except Exception:
        return {}


def mindmap_to_mermaid(mindmap_data: dict, title: str = "") -> str:
    """Convert NotebookLM mind map data to Mermaid mindmap syntax.

    NotebookLM mind maps are hierarchical trees. Mermaid mindmap syntax is
    indentation-based: each extra 2-space indent = one deeper level.

    Example output:
        mindmap
          root((My Source))
            Topic A
              Subtopic 1
              Subtopic 2
            Topic B
    """
    if not mindmap_data:
        return ""

    lines = ["mindmap"]
    root_label = (
        (mindmap_data.get("title") or title or "Source").replace('"', "'").strip()
    )
    lines.append(f"  root(({root_label}))")

    def render_node(node: dict, depth: int) -> None:
        indent = "  " * depth
        # Handle varying field names across API versions
        label = (
            node.get("label")
            or node.get("title")
            or node.get("text")
            or node.get("name")
            or ""
        )
        label = label.replace('"', "'").replace("\n", " ").strip()
        if not label:
            return
        lines.append(f"{indent}{label}")
        children = node.get("children") or node.get("nodes") or node.get("items") or []
        for child in children:
            render_node(child, depth + 1)

    top_nodes = (
        mindmap_data.get("nodes")
        or mindmap_data.get("children")
        or mindmap_data.get("topics")
        or []
    )
    for node in top_nodes:
        render_node(node, 2)

    # Return empty string if only the root was added (no real content)
    if len(lines) <= 2:
        return ""
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Import NotebookLM sources into vault")
    parser.add_argument(
        "--sources", required=True, help="Path to notebooklm source list JSON"
    )
    parser.add_argument(
        "--slug", required=True, help="Notebook slug (kebab-case folder name)"
    )
    parser.add_argument(
        "--dashboard", required=True, help="Dashboard title for related links"
    )
    parser.add_argument(
        "--skip-guides", action="store_true", help="Skip fetching AI source guides"
    )
    parser.add_argument(
        "--skip-fulltext", action="store_true", help="Skip fetching full source text"
    )
    parser.add_argument(
        "--skip-mindmap", action="store_true", help="Skip fetching mind map data"
    )
    args = parser.parse_args()

    with open(args.sources) as f:
        data = json.load(f)

    notebook_id = data.get("notebook_id", "")
    sources = data["sources"]
    sources_dir = VAULT / "NotebookLM" / args.slug / "Sources"
    sources_dir.mkdir(parents=True, exist_ok=True)
    dashboard_path = f"Dashboards/{args.dashboard}"

    created = 0
    skipped = 0

    for source in sources:
        title = source["title"].strip()
        source_id = source["id"]
        source_type = TYPE_MAP.get(source["type"], "web")
        url = source.get("url") or ""
        date = source.get("created_at", "")[:10]

        # Skip sources with garbage titles (multi-URL web pages etc.)
        if title == "- YouTube" or len(title) < 3:
            print(f"  SKIP: '{title}' (bad title)")
            skipped += 1
            continue

        filename = safe_filename(title) + ".md"
        filepath = sources_dir / filename

        if filepath.exists():
            print(f"  EXISTS: {filename}")
            skipped += 1
            continue

        # Fetch guide
        guide_text = ""
        keywords = []
        if not args.skip_guides:
            print(f"  Fetching guide: {title[:60]}...")
            summary, topics, keywords = fetch_guide(source_id)
            if summary:
                guide_text = summary
                if topics:
                    guide_text += "\n\n### Topics\n\n" + ", ".join(topics)
                print(f"    OK: {len(summary)} chars, {len(keywords)} keywords")
            else:
                print(f"    WARN: no guide returned")

        # Fetch mind map and convert to Mermaid
        mermaid_block = ""
        if not args.skip_mindmap:
            print(f"  Fetching mindmap: {title[:60]}...")
            mindmap_data = fetch_mindmap(source_id)
            if mindmap_data:
                mermaid_str = mindmap_to_mermaid(mindmap_data, title=title)
                if mermaid_str:
                    mermaid_block = f"```mermaid\n{mermaid_str}\n```"
                    print(f"    OK: mindmap converted to mermaid")
                else:
                    print(f"    WARN: mindmap data present but no renderable nodes")
            else:
                print(f"    SKIP: no mindmap available")

        # Fetch full text (uses --json to bypass 2KB terminal truncation)
        fulltext = ""
        if not args.skip_fulltext:
            print(f"  Fetching fulltext: {title[:60]}...")
            fulltext = fetch_fulltext(source_id)
            if fulltext:
                print(f"    OK: {len(fulltext)} chars")
            else:
                print(f"    WARN: no fulltext returned")

        # Build topics frontmatter
        topics_yaml = ""
        if keywords:
            topics_yaml = (
                "topics:\n" + "\n".join(f'  - "[[{k}]]"' for k in keywords) + "\n"
            )

        # Build optional sections
        mindmap_section = f"\n## Mind Map\n\n{mermaid_block}\n" if mermaid_block else ""
        fulltext_section = f"\n## Full Text\n\n{fulltext}\n" if fulltext else ""

        # Build tags from source_type
        tags_yaml = f"tags:\n  - notebooklm\n  - {source_type}\n"

        content = f"""---
title: "{title}"
type: notebook-source
source_id: "{source_id}"
notebook_id: "{notebook_id}"
url: "{url}"
source_type: {source_type}
status: active
date: {date}
{topics_yaml}{tags_yaml}related:
  - "[[{dashboard_path}]]"
---

# {title}

## Source Guide

{guide_text}
{mindmap_section}{fulltext_section}"""

        filepath.write_text(content)
        print(f"  CREATED: {filename}")
        created += 1

    print(f"\nDone: {created} created, {skipped} skipped")


if __name__ == "__main__":
    main()
