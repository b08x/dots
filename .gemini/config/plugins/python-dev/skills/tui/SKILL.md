---
name: tui
description: "Use when building a terminal user interface or CLI output in Python: rich for tables, progress, panels, trees, markdown, and logging; questionary for interactive prompts; textual for full-screen reactive apps; pyfiglet for banners; platformdirs for config and cache paths. Loaded by the implementer when the brief names tui, CLI output, prompts, or a terminal app."
---

# TUI: Terminal Interfaces in Python

Use one rendering layer. `rich` covers output. Add `questionary` for prompts and `textual` only when the app needs a persistent, full-screen UI.

## Terminal UI Components and Recommended Libraries

| Need | Python Library / Tool | Description / Role |
|---|---|---|
| Tables | `rich.table.Table` | Formatted, borders, styles, column alignment |
| Progress bars and spinners | `rich.progress` | Multi-bar tasks, spinner animations, ETA |
| Boxes and panels | `rich.panel.Panel` | Framed content, titles, subtitle styling |
| Trees | `rich.tree.Tree` | Hierarchical file or category structures |
| Markdown | `rich.markdown.Markdown` | Rendered terminal markdown |
| Logging output | `rich.logging.RichHandler` | Highlighting, timestamps, traceback formatting |
| Colour | `rich` styles | 24-bit colour, hex, semantic styles |
| Interactive prompts | `questionary` | Text, select, checkbox, confirm, password |
| Full-screen reactive UI | `textual` | TUI application framework with widgets and events |
| Big text / banners | `pyfiglet` | ASCII art banners |
| Executable lookup | `shutil.which` | Standard library binary resolution |
| Config and cache directories | `platformdirs` | Platform-standard config, cache, and data dirs |
| Subprocess output streaming | `asyncio.create_subprocess_exec` | Non-blocking command execution and streaming |
| File operations | `pathlib.Path`, `shutil` | Robust cross-platform path and file manipulation |

## Rules

- One `rich.console.Console` per process, created at the entry point and passed in. Do not create consoles inside functions.
- Write to the console, not `print`, so output respects the terminal width and colour settings.
- Keep rendering separate from logic. A function returns data; a render function turns it into a `Table` or `Panel`. Tests check the data.
- Interactive prompts run only when stdin is a TTY. Otherwise take the value from an argument or fail with a message.
- Exit codes come from the command, not the renderer. `0` for success, `2` for usage errors, `1` for failures.

## Structure

```python
from __future__ import annotations

from rich.console import Console
from rich.table import Table

__all__ = ["render_summary"]


def render_summary(rows: list[tuple[str, int]]) -> Table:
    """Build a table from name and count pairs."""
    table = Table(title="Summary")
    table.add_column("Name")
    table.add_column("Count", justify="right")
    for name, count in rows:
        table.add_row(name, str(count))
    return table


def main() -> int:
    """Entry point. Returns the exit code."""
    console = Console()
    console.print(render_summary([("alpha", 2)]))
    return 0
```

## Testing

- Render to a string with `Console(record=True, width=80)` and assert on the text.
- Use `CliRunner`-style invocation for the command, or call `main()` with arguments.
- For textual apps, use the library's pilot API to drive the app in tests.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Output garbled in CI | Colour codes in a non-TTY | Set `Console(force_terminal=False)` in tests and CI |
| Prompt hangs in a script | Prompt called without a TTY | Check `sys.stdin.isatty()` first |
| Config written to the wrong place | Hard-coded home path | Use `platformdirs` |

## Related

- `scaffold` for the project layout, including the `__main__.py` entry point.
- `logging-patterns.md` for logger setup.
