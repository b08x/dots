#!/usr/bin/env python3
"""Generate Obsidian Dashboard and Canvas from recall correlation data."""

import json
import argparse
import os
from pathlib import Path
from datetime import datetime, timezone

def _detect_vault_prefix():
    """Auto-detect vault prefix from CWD or VAULT_DIR env var."""
    if os.environ.get("VAULT_DIR"):
        p = os.environ["VAULT_DIR"]
        return Path(p)
    # Walk up from CWD looking for .obsidian/ directory
    cwd = Path.cwd()
    for parent in [cwd, *cwd.parents]:
        if (parent / ".obsidian").is_dir():
            return parent
    # Fallback: check ~/Notebook
    notebook = Path("~/Notebook").expanduser()
    if notebook.is_dir():
        return notebook
    return cwd

def generate_dashboard(correlation_data, vault_path: Path, days: int):
    """Generate a Markdown dashboard in Obsidian."""
    dash_dir = vault_path / "Dashboards"
    dash_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    dash_path = dash_dir / f"Recall Dashboard {datetime.now().strftime('%Y-%m-%d')}.md"
    
    correlation = correlation_data.get('correlation', {})
    timeline = correlation_data.get('timeline', [])
    
    content = [
        "---",
        "type: recall-dashboard",
        f"date: {datetime.now().strftime('%Y-%m-%d')}",
        f"window_days: {days}",
        "tags:",
        "  - recall",
        "  - dashboard",
        "---",
        f"# Recall Dashboard - {datetime.now().strftime('%Y-%m-%d')}",
        "",
        "## 🎯 One Thing",
        f"> **{correlation.get('one_thing', 'Review recent activity')}**",
        f"> {correlation.get('one_thing_reasoning', '')}",
        "",
        "## 📝 Narrative",
        correlation.get('narrative', 'No narrative generated.'),
        "",
        "## 🚀 Workstreams",
    ]
    
    for ws in correlation.get('workstreams', []):
        content.append(f"- {ws}")
    
    content.extend([
        "",
        "## 📅 Timeline",
        "| Time | Type | Platform | Summary |",
        "| ---- | ---- | -------- | ------- |"
    ])
    
    for event in timeline:
        ts = event.get('timestamp', 'unknown')
        if 'T' in ts:
            ts = ts.split('T')[1][:5]
        
        etype = event.get('type', 'event')
        platform = event.get('platform', 'unknown')
        summary = event.get('summary', 'No summary')
        
        content.append(f"| {ts} | {etype} | {platform} | {summary} |")
    
    content.extend([
        "",
        "## 🔗 Next Actions",
    ])

    for action in correlation.get('next_actions', []):
        content.append(f"- [ ] {action}")

    content.extend([
        "",
        "## 📚 Related Dashboards",
        "",
        "### Project-Specific Analysis",
        "For deeper analysis of specific projects, see:",
        "- Use `/code-insights sessions --project <id>` to find project-specific sessions",
        "- Use `knowledge-synthesizer` to create detailed project dashboards",
        "- Project dashboards location: `[[Dashboards/]]` (filter by `-Sessions.md`)",
        "",
        "### Cross-References",
        "- **Temporal view** (this dashboard): Cross-platform timeline",
        "- **Spatial view** (project dashboards): Per-project friction analysis",
        "",
        f"*Generated at {timestamp}*"
    ])
    
    dash_path.write_text("\n".join(content))
    return dash_path

def generate_canvas(correlation_data, vault_path: Path):
    """Generate an Obsidian Canvas from timeline data."""
    canvas_dir = vault_path / "Canvases"
    canvas_dir.mkdir(parents=True, exist_ok=True)
    
    canvas_path = canvas_dir / f"Recall Timeline {datetime.now().strftime('%Y-%m-%d')}.canvas"
    
    timeline = correlation_data.get('timeline', [])
    
    nodes = []
    edges = []
    
    # Platform colors (Obsidian-like)
    COLORS = {
        "claude-code": "1", # Red
        "gemini-cli": "4",  # Blue
        "hermes-agent": "2", # Orange
        "opencode": "3",    # Yellow
        "obsidian": "5",    # Green
        "github": "6",      # Purple
        "git": "6"          # Purple
    }
    
    x = 0
    y = 0
    spacing_x = 400
    spacing_y = 150
    width = 300
    height = 100
    
    prev_node_id = None
    
    for i, event in enumerate(timeline):
        node_id = f"node_{i}"
        platform = event.get('platform', 'unknown')
        if ':' in platform:
            platform = platform.split(':')[0]
            
        color = COLORS.get(platform, "0")
        
        summary = event.get('summary', 'No summary')
        ts = event.get('timestamp', 'unknown')
        if 'T' in ts:
            ts = ts.split('T')[0] + " " + ts.split('T')[1][:5]
            
        text = f"**{platform.upper()}**\n{ts}\n{summary}"
        
        nodes.append({
            "id": node_id,
            "type": "text",
            "text": text,
            "x": x,
            "y": y,
            "width": width,
            "height": height,
            "color": color
        })
        
        if prev_node_id:
            edges.append({
                "id": f"edge_{i}",
                "fromNode": prev_node_id,
                "fromSide": "right",
                "toNode": node_id,
                "toSide": "left"
            })
            
        prev_node_id = node_id
        x += spacing_x
        # Add some vertical jitter
        y = (i % 3) * spacing_y
        
    canvas_json = {
        "nodes": nodes,
        "edges": edges
    }
    
    canvas_path.write_text(json.dumps(canvas_json, indent=2))
    return canvas_path

def main():
    parser = argparse.ArgumentParser(description="Create Obsidian Dashboard and Canvas")
    parser.add_argument("input", help="Correlation JSON file")
    parser.add_argument("--vault", help="Obsidian vault path")
    parser.add_argument("--days", type=int, default=7)
    
    args = parser.parse_args()
    
    if not Path(args.input).exists():
        print(f"Error: Input file {args.input} not found")
        return
        
    with open(args.input) as f:
        data = json.load(f)
        
    vault_path = Path(args.vault) if args.vault else _detect_vault_prefix()
    print(f"Using Obsidian vault: {vault_path}")
    
    dash_path = generate_dashboard(data, vault_path, args.days)
    print(f"Dashboard created: {dash_path}")
    
    canvas_path = generate_canvas(data, vault_path)
    print(f"Canvas created: {canvas_path}")

if __name__ == "__main__":
    main()
