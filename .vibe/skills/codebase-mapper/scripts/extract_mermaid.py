#!/usr/bin/env python3
"""
extract_mermaid.py
Extracts Mermaid diagram definitions from a graphify callflow HTML file
and writes them as standalone .mmd files alongside a ready-to-embed
markdown snippet.

Usage:
    python extract_mermaid.py [callflow.html] [--out-dir ./diagrams]

Output:
    diagrams/architecture_overview.mmd    - module/layer diagram
    diagrams/callflow_N.mmd               - per-section call-flow diagrams
    diagrams/diagrams.md                  - markdown with all diagrams embedded
"""

import sys
import re
import json
import os
from pathlib import Path
from html import unescape


def extract_from_html(html_path: str, out_dir: str) -> list[dict]:
    """Pull Mermaid blocks out of graphify callflow HTML."""
    html = Path(html_path).read_text(encoding="utf-8", errors="replace")

    # graphify embeds mermaid in <div class="mermaid">...</div> or <pre class="mermaid">
    pattern = re.compile(
        r'<(?:div|pre)[^>]*class=["\'][^"\']*mermaid[^"\']*["\'][^>]*>(.*?)</(?:div|pre)>',
        re.DOTALL | re.IGNORECASE,
    )
    raw_blocks = pattern.findall(html)

    # Also catch ```mermaid fences inside <script> or <code> blocks
    fence_pattern = re.compile(r"```mermaid\s*(.*?)```", re.DOTALL)
    raw_blocks += fence_pattern.findall(html)

    # Fallback: graphify stores diagram data in window.__GRAPHIFY__ JSON
    json_pattern = re.compile(r"window\.__GRAPHIFY__\s*=\s*(\{.*?\});", re.DOTALL)
    json_match = json_pattern.search(html)
    if json_match:
        try:
            data = json.loads(json_match.group(1))
            for section in data.get("sections", []):
                if "mermaid" in section:
                    raw_blocks.append(section["mermaid"])
        except Exception:
            pass

    diagrams = []
    for i, raw in enumerate(raw_blocks):
        clean = unescape(raw).strip()
        if not clean or len(clean) < 20:
            continue
        # Determine diagram type from first token
        first_line = clean.splitlines()[0].strip().lower()
        kind = "diagram"
        if "graph" in first_line or "flowchart" in first_line:
            kind = "architecture" if i == 0 else f"callflow_{i}"
        elif "sequencediagram" in first_line.replace(" ", ""):
            kind = f"sequence_{i}"
        elif "classDiagram" in first_line:
            kind = f"class_{i}"

        diagrams.append({"name": kind, "content": clean})

    return diagrams


def write_outputs(diagrams: list[dict], out_dir: str) -> str:
    """Write .mmd files and a combined diagrams.md."""
    os.makedirs(out_dir, exist_ok=True)
    md_lines = ["# Codebase Diagrams\n", "_Auto-extracted from graphify callflow output._\n"]

    for d in diagrams:
        fname = f"{d['name']}.mmd"
        fpath = os.path.join(out_dir, fname)
        Path(fpath).write_text(d["content"], encoding="utf-8")
        print(f"  Wrote {fpath}")

        # Embed in markdown
        title = d["name"].replace("_", " ").title()
        md_lines += [
            f"\n## {title}\n",
            "```mermaid",
            d["content"],
            "```\n",
        ]

    md_path = os.path.join(out_dir, "diagrams.md")
    Path(md_path).write_text("\n".join(md_lines), encoding="utf-8")
    return md_path


def synthesize_fallback(graph_json_path: str, out_dir: str) -> str:
    """
    If no Mermaid blocks found, synthesize a basic architecture diagram
    from graph.json using the top-connected (god) nodes.
    """
    graph = json.loads(Path(graph_json_path).read_text())
    nodes = graph.get("nodes", [])
    edges = graph.get("edges", [])

    # Count connections per node
    degree: dict[str, int] = {}
    for e in edges:
        for key in ("source", "target", "from", "to"):
            n = e.get(key)
            if n:
                degree[n] = degree.get(n, 0) + 1

    # Top 12 nodes by degree
    top_nodes = sorted(degree.items(), key=lambda x: x[1], reverse=True)[:12]
    top_ids = {n[0] for n in top_nodes}

    # Only keep edges between top nodes
    top_edges = [
        e for e in edges
        if (e.get("source") or e.get("from")) in top_ids
        and (e.get("target") or e.get("to")) in top_ids
    ]

    lines = ["flowchart TD"]
    for nid, _ in top_nodes:
        label = nid.replace('"', "'")
        lines.append(f'    {sanitize_id(nid)}["{label}"]')
    for e in top_edges[:30]:
        src = sanitize_id(e.get("source") or e.get("from", ""))
        tgt = sanitize_id(e.get("target") or e.get("to", ""))
        rel = e.get("label") or e.get("type") or "→"
        lines.append(f"    {src} -- {rel} --> {tgt}")

    mermaid = "\n".join(lines)
    diagrams = [{"name": "architecture_overview", "content": mermaid}]
    return write_outputs(diagrams, out_dir)


def sanitize_id(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_]", "_", s)[:40] or "node"


def main():
    args = sys.argv[1:]
    out_dir = "./diagrams"
    html_path = None
    graph_json = "graphify-out/graph.json"

    for i, a in enumerate(args):
        if a == "--out-dir" and i + 1 < len(args):
            out_dir = args[i + 1]
        elif a.endswith(".html"):
            html_path = a
        elif a.endswith(".json"):
            graph_json = a

    # Auto-discover callflow HTML
    if not html_path:
        candidates = list(Path("graphify-out").glob("*callflow*.html")) if Path("graphify-out").exists() else []
        if candidates:
            html_path = str(candidates[0])
            print(f"Auto-detected callflow HTML: {html_path}")

    print(f"Output directory: {out_dir}")

    if html_path and Path(html_path).exists():
        print(f"Extracting Mermaid diagrams from {html_path}...")
        diagrams = extract_from_html(html_path, out_dir)
        if diagrams:
            md_path = write_outputs(diagrams, out_dir)
            print(f"\nExtracted {len(diagrams)} diagram(s). Markdown: {md_path}")
            return

    # Fallback to graph.json synthesis
    if Path(graph_json).exists():
        print(f"No callflow HTML found. Synthesizing from {graph_json}...")
        md_path = synthesize_fallback(graph_json, out_dir)
        print(f"\nSynthesized architecture diagram. Markdown: {md_path}")
    else:
        print("ERROR: No callflow HTML or graph.json found. Run map_codebase.sh first.")
        sys.exit(1)


if __name__ == "__main__":
    main()
