# Ansible Playbook Grapher Reference

This guide documents the `ansible-playbook-grapher` CLI tool for visualizing Ansible playbook structure, task dependencies, and execution flow. Use this tool to generate graphs from your playbooks for documentation, debugging, or analysis purposes.

## Installation

```bash
# Install from PyPI
pip install ansible-playbook-grapher

# Verify installation
ansible-playbook-grapher --version
# ansible-playbook-grapher 2.11.0-dev0 (with ansible 2.17.x)
```

## Quick Start

### Basic Usage

Generate a graph from a playbook file:

```bash
ansible-playbook-grapher site.yml
# Output: site.svg (default graphviz renderer)
```

### Common Examples

| Command | Output | Description |
|---------|--------|-------------|
| `ansible-playbook-grapher site.yml` | `site.svg` | Default Graphviz SVG output |
| `ansible-playbook-grapher --renderer json site.yml` | `site.json` | Machine-readable JSON |
| `ansible-playbook-grapher --renderer mermaid-flowchart site.yml` | `site.mmd` | Mermaid flowchart for Markdown |
| `ansible-playbook-grapher --include-role-tasks site.yml` | `site.svg` | Include tasks from roles |
| `ansible-playbook-grapher --show-handlers site.yml` | `site.svg` | Include handler tasks |
| `ansible-playbook-grapher --view site.yml` | Opens SVG in browser | View output immediately |

## CLI Options

### Output Renderer: `--renderer`

Select the output format engine. Three renderers are available:

- **`graphviz`** (default): Produces `.svg` files using Graphviz
- **`mermaid-flowchart`**: Produces `.mmd` files for Mermaid diagrams
- **`json`**: Produces `.json` files with full graph structure

```bash
# JSON output for programmatic analysis
ansible-playbook-grapher --renderer json site.yml

# Mermaid for embedding in Markdown or GitHub
ansible-playbook-grapher --renderer mermaid-flowchart site.yml

# Graphviz SVG (default)
ansible-playbook-grapher --renderer graphviz site.yml
```

### Include Role Tasks: `--include-role-tasks`

By default, role tasks are not shown. Use this flag to include tasks defined within roles:

```bash
ansible-playbook-grapher --include-role-tasks site.yml
```

Note: Tasks from `import_role` are always included. This flag affects tasks from `include_role` and role directories.

### Show Handlers: `--show-handlers`

Include handler tasks in the generated graph:

```bash
ansible-playbook-grapher --show-handlers site.yml
```

### View Output: `--view`

Automatically open the rendered output in your default web browser:

```bash
ansible-playbook-grapher --view site.yml
# Opens site.svg in browser

ansible-playbook-grapher --renderer mermaid-flowchart --view site.yml
# Opens https://mermaid.live/ with the diagram
```

### Multiple Playbooks

Process multiple playbook files in a single command:

```bash
ansible-playbook-grapher playbook1.yml playbook2.yml playbook3.yml
```

## Vault and Extra Variables

The tool supports standard Ansible CLI options for handling encrypted variables and extra vars.

### Vault Password Options

```bash
# Prompt for vault password interactively
ansible-playbook-grapher -J site.yml

# Use a vault password file
ansible-playbook-grapher --vault-password-file ~/.vault_pass site.yml

# Use vault identity
ansible-playbook-grapher --vault-id prod@~/.vault_pass site.yml
```

### Extra Variables

```bash
# Pass extra variables inline
ansible-playbook-grapher -e "env=production region=us-east-1" site.yml

# Load extra variables from file
ansible-playbook-grapher -e @vars/production.yml site.yml
```

## Output Formats

### Graphviz (SVG) Output

The default renderer produces SVG files using Graphviz. The output includes:
- Playbook structure with plays, tasks, and roles
- Color-coded nodes based on task types
- Collapsible nodes for complex playbooks (with `--collapsible-nodes` in API)

```bash
ansible-playbook-grapher site.yml
# Output: site.svg
```

To also save the intermediate DOT file:
```python
# Python API only - save_dot_file option
# See Python API section below
```

### Mermaid Flowchart Output

Produces Mermaid flowchart syntax (`.mmd` files) that can be:
- Embedded directly in Markdown documents
- Rendered in GitHub/GitLab
- Opened in [Mermaid Live Editor](https://mermaid.live/)

```bash
ansible-playbook-grapher --renderer mermaid-flowchart site.yml
# Output: site.mmd
```

**Mermaid Features:**
- Supports custom directives for themes and curve styles
- Configurable orientation (`TB` top-to-bottom, `LR` left-to-right)

### JSON Output

Produces structured JSON with complete graph information:
- Node hierarchy and relationships
- File locations (path, line, column)
- Colors and styling
- Role/task relationships
- Handler definitions

```bash
ansible-playbook-grapher --renderer json site.yml
# Output: site.json
```

## Complete CLI Examples

### Example 1: Full Playbook Analysis with JSON

```bash
ansible-playbook-grapher \
  --renderer json \
  --include-role-tasks \
  --show-handlers \
  site.yml
# Output: site.json with complete task hierarchy
```

### Example 2: Mermaid for Documentation

```bash
ansible-playbook-grapher \
  --renderer mermaid-flowchart \
  --include-role-tasks \
  --view \
  site.yml
# Opens interactive Mermaid diagram in browser
```

### Example 3: Complex Playbook with Vault

```bash
ansible-playbook-grapher \
  --vault-password-file ~/.vault_pass \
  -e "env=staging" \
  --include-role-tasks \
  --show-handlers \
  deploy.yml
```

### Example 4: JSON for CI/CD Pipeline Analysis

```bash
ansible-playbook-grapher \
  --renderer json \
  --include-role-tasks \
  --show-handlers \
  ci-pipeline.yml \
  > pipeline-structure.json
```

## Python API

For programmatic use, import and use the renderers directly.

### GraphvizRenderer (SVG Output)

```python
from ansibleplaybookgrapher.renderer.graphviz import GraphvizRenderer
from ansibleplaybookgrapher.grapher import Grapher

grapher = Grapher({"site.yml": "/project/site.yml"})
playbook_nodes, roles_usage = grapher.parse()

for pb_node in playbook_nodes:
    pb_node.remove_empty_plays()
    pb_node.calculate_indices()

renderer = GraphvizRenderer(
    playbook_nodes=playbook_nodes,
    roles_usage=roles_usage,
)

svg_path = renderer.render(
    open_protocol_handler="vscode",
    open_protocol_custom_formats=None,
    output_filename="/tmp/site_graph",
    title="My Site Playbook",
    include_role_tasks=True,
    view=False,
    show_handlers=True,
    save_dot_file=True,       # Also write .dot file
    collapsible_nodes=True,   # Add +/- collapse buttons
)
print(f"SVG written to: {svg_path}")
```

### MermaidFlowChartRenderer (Mermaid Output)

```python
from ansibleplaybookgrapher.renderer.mermaid import MermaidFlowChartRenderer, DEFAULT_DIRECTIVE
from ansibleplaybookgrapher.grapher import Grapher

grapher = Grapher({"site.yml": "/project/site.yml"})
playbook_nodes, roles_usage = grapher.parse()

for pb_node in playbook_nodes:
    pb_node.calculate_indices()

renderer = MermaidFlowChartRenderer(
    playbook_nodes=playbook_nodes,
    roles_usage=roles_usage,
)

mmd_path = renderer.render(
    open_protocol_handler="default",
    open_protocol_custom_formats=None,
    output_filename="/tmp/site_graph",
    title="Site Deployment",
    include_role_tasks=False,
    view=False,            # If True, opens https://mermaid.live/
    show_handlers=False,
    directive=DEFAULT_DIRECTIVE,  # Customize with themes, curves
    orientation="LR",             # Left-to-right layout (TB, BT, LR, RL)
)
print(f"Mermaid file: {mmd_path}")

# Standalone: open any mermaid code in the browser
MermaidFlowChartRenderer.view("flowchart LR\n  A --> B")
```

### JSONRenderer (JSON Output)

```python
from ansibleplaybookgrapher.renderer.json import JSONRenderer
from ansibleplaybookgrapher.grapher import Grapher

grapher = Grapher({"site.yml": "/project/site.yml"})
playbook_nodes, roles_usage = grapher.parse()

for pb_node in playbook_nodes:
    pb_node.calculate_indices()

renderer = JSONRenderer(
    playbook_nodes=playbook_nodes,
    roles_usage=roles_usage,
)

json_path = renderer.render(
    open_protocol_handler="default",
    open_protocol_custom_formats=None,
    output_filename="/tmp/site_graph",
    title="Site Playbook",
    include_role_tasks=True,
    view=False,
    show_handlers=True,
)
print(f"JSON written to: {json_path}")
```

**Expected JSON Structure:**
```json
{
  "version": 1,
  "title": "Site Playbook",
  "playbooks": [
    {
      "type": "PlaybookNode",
      "id": "playbook_a1b2c3d4",
      "name": "site.yml",
      "location": {
        "type": "file",
        "path": "/project/site.yml",
        "line": 1,
        "column": 1
      },
      "plays": [
        {
          "type": "PlayNode",
          "id": "play_e5f6g7h8",
          "name": "Deploy",
          "hosts": ["web"],
          "colors": {"main": "#4a826b", "font": "#ffffff"},
          "pre_tasks": [],
          "roles": [...],
          "tasks": [...],
          "post_tasks": [],
          "handlers": []
        }
      ]
    }
  ]
}
```

## Use Cases

### 1. Playbook Documentation

Generate Mermaid diagrams to document complex playbook structures in your README files:

```bash
ansible-playbook-grapher --renderer mermaid-flowchart infrastructure.yml > docs/infrastructure.mmd
```

### 2. Debugging Complex Playbooks

Visualize role dependencies and task flow to identify issues:

```bash
ansible-playbook-grapher --include-role-tasks --show-handlers --view deploy.yml
```

### 3. CI/CD Pipeline Visualization

Analyze playbook structure programmatically in your CI/CD pipeline:

```bash
ansible-playbook-grapher --renderer json pipeline.yml | jq '.playbooks[0].plays'
```

### 4. Team Onboarding

Help new team members understand existing Ansible automation:

```bash
# Generate diagrams for all playbooks
for pb in playbooks/*.yml; do
  ansible-playbook-grapher --renderer mermaid-flowchart "$pb"
done
```

## Best Practices

1. **Start with default output** to get a high-level view of your playbook
2. **Use `--include-role-tasks`** when you need to see the full picture including role internals
3. **Use `--show-handlers`** when debugging handler triggers
4. **Use JSON output** for programmatic analysis or integration with other tools
5. **Use Mermaid output** for documentation that renders nicely in Markdown
6. **Combine flags** for comprehensive analysis: `--include-role-tasks --show-handlers --renderer json`

## Troubleshooting

### Graphviz Not Installed

The `graphviz` renderer requires Graphviz to be installed on your system:

```bash
# Fedora/RHEL
sudo dnf install graphviz

# Debian/Ubuntu
sudo apt install graphviz

# macOS
brew install graphviz
```

### Playbook Parsing Errors

Ensure your playbook syntax is valid:

```bash
ansible-playbook --syntax-check site.yml
```

### Role Tasks Not Showing

Make sure to use `--include-role-tasks` flag. Note that `import_role` tasks are always included, but `include_role` tasks require the flag.

## Integration with Ansible Automation Skill

When using this tool with the `ansible-automation` skill:

1. **Verify playbook syntax** first with `ansible-playbook --syntax-check`
2. **Use style guide conventions** (2-space indentation, fully qualified modules)
3. **Generate documentation** as part of your role/playbook creation workflow
4. **Use JSON output** for programmatic validation in your CI/CD

## See Also

- [Official GitHub Repository](https://github.com/haidaram/ansible-playbook-grapher)
- [Mermaid Live Editor](https://mermaid.live/) - For interactive Mermaid diagram viewing
- [Graphviz Documentation](https://graphviz.org/doc/info/lang.html) - For DOT language reference
