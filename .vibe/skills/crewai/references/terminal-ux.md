# Terminal UX with Rich and Textual

## Rich Output Formatting

Use Rich to format crew output for terminal consumption:

```python
from rich.console import Console
from rich.panel import Panel
from rich.markdown import Markdown
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn

console = Console()

def display_crew_result(result, title="Crew Output"):
    """Display crew result in a formatted panel."""
    console.print(Panel(
        Markdown(result.raw),
        title=f"[bold green]{title}[/]",
        border_style="green",
        padding=(1, 2),
    ))

def display_agent_metrics(result):
    """Show token usage and agent breakdown."""
    table = Table(title="Agent Metrics")
    table.add_column("Metric", style="cyan")
    table.add_column("Value", style="magenta")

    if hasattr(result, 'usage_metrics') and result.usage_metrics:
        metrics = result.usage_metrics
        table.add_row("Total Tokens", str(getattr(metrics, 'total_tokens', 'N/A')))
        table.add_row("Prompt Tokens", str(getattr(metrics, 'prompt_tokens', 'N/A')))
        table.add_row("Completion Tokens", str(getattr(metrics, 'completion_tokens', 'N/A')))

    console.print(table)

def run_with_spinner(crew, inputs, description="Agents working..."):
    """Run a crew with a Rich spinner."""
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    ) as progress:
        task = progress.add_task(description, total=None)
        result = crew.kickoff(inputs=inputs)
        progress.update(task, description="[green]Done![/]")
    return result
```

## Textual App for Interactive Crew Management

```python
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Input, Button, DataTable
from textual.containers import Vertical, Horizontal
from rich.text import Text

class CrewRunner(Static):
    """Widget that runs a crew and displays output."""

    def __init__(self, crew_class, **kwargs):
        super().__init__(**kwargs)
        self.crew_class = crew_class
        self.result = None

    def compose(self) -> ComposeResult:
        yield Input(placeholder="Enter topic...", id="topic-input")
        yield Button("Run Crew", id="run-btn", variant="primary")
        yield Static("Results will appear here.", id="output")

    def on_button_pressed(self, event: Button.Pressed):
        if event.button.id == "run-btn":
            topic = self.query_one("#topic-input").value
            if topic:
                self.run_crew(topic)

    def run_crew(self, topic: str):
        output = self.query_one("#output", Static)
        output.update(f"[yellow]Running crew on: {topic}[/]")
        try:
            result = self.crew_class().crew().kickoff(inputs={"topic": topic})
            self.result = result
            output.update(f"[green]Complete![/]\n\n{result.raw}")
        except Exception as e:
            output.update(f"[red]Error: {e}[/]")

class CrewApp(App):
    """Terminal app for running CrewAI crews interactively."""

    CSS = """
    Screen { background: $surface }
    #topic-input { margin: 1; }
    #run-btn { margin: 1; }
    #output { margin: 1; height: auto; }
    """

    def __init__(self, crew_class, **kwargs):
        super().__init__(**kwargs)
        self.crew_class = crew_class

    def compose(self) -> ComposeResult:
        yield Header()
        yield CrewRunner(self.crew_class)
        yield Footer()

# Usage:
# app = CrewApp(MyCrew)
# app.run()
```

## Flow Visualization with Rich Tree

```python
from rich.tree import Tree

def visualize_flow(flow_class):
    """Render a Flow's structure as a tree."""
    tree = Tree(f"[bold]{flow_class.__name__}[/]")

    for method_name in dir(flow_class):
        method = getattr(flow_class, method_name, None)
        if method and hasattr(method, '__wrapped__'):
            # Detect decorators
            decs = []
            if hasattr(method, '_start'): decs.append("start")
            if hasattr(method, '_listen'): decs.append(f"listen({method._listen})")
            if hasattr(method, '_router'): decs.append("router")

            label = f"{method_name}"
            if decs:
                label += f" [dim]({', '.join(decs)})[/]"
            tree.add(label)

    Console().print(tree)
```
