---
name: tui
description: "Use when building terminal user interfaces in Ruby - interactive prompts, tables, progress bars, color output, and multi-step workflows using the TTY toolkit and related gems."
user-invocable: true
---

# RubyDev TUI — Terminal User Interface

## Overview

Ruby's TTY Toolkit provides a suite of composable components for building polished terminal interfaces. The tui skill covers 21 TTY gems — from interactive prompts to tables, progress bars, spinners, loggers, and more.

Full usage examples and option tables for each gem live in `~/.vibe/skills/tui/references/`:
- Load the specific cheatsheet for the gem you're using (e.g., `~/.vibe/skills/tui/references/tty-prompt_cheatsheet.md`)
- The Gem Selection table below serves as the overall gem index

Applied after scaffolding a CLI project, or when enhancing an existing CLI with rich terminal interactions.

## When to Use

- User asks for "interactive prompts" or "a wizard" in a Ruby CLI
- A scaffolded CLI needs richer UI than plain `puts`/`gets`
- You need tables, progress bars, or paged output
- Converting a one-shot script into a multi-step workflow

**Don't use for:**
- Desktop GUI applications (use [gui/SKILL.md](~/.vibe/skills/gui/SKILL.md))
- Non-Ruby projects (use the language's native TUI)
- Web UIs (use HTML/JS)
- Simple scripts that need just `puts` and `gets` (keep it lightweight)

## Core Components

| Component | Gem | Cheatsheet | Usage |
|-----------|-----|------------|-------|
| Interactive prompts | `tty-prompt` | `~/.vibe/skills/tui/references/tty-prompt_cheatsheet.md` | Menus, multi-select, ask, mask, yes/no, slider |
| Tables | `tty-table` | `~/.vibe/skills/tui/references/tty-table_cheatsheet.md` | Render arrays/hashes as aligned terminal tables |
| Progress bars | `tty-progressbar` | `~/.vibe/skills/tui/references/tty-progressbar_cheatsheet.md` | Multi-bar, indeterminate, percentage, elapsed time |
| Spinners | `tty-spinner` | `~/.vibe/skills/tui/references/tty-spinner_cheatsheet.md` | Single/multi-spinner for async task progress |
| Color | `pastel` | External gem | Detached color styling, chainable, theme support |
| Box/layout | `tty-box` | `~/.vibe/skills/tui/references/tty-box_cheatsheet.md` | Bordered frames, columns, padding |
| Command runner | `tty-command` | `~/.vibe/skills/tui/references/tty-command_cheatsheet.md` | Run shell commands with streaming output |
| Markdown | `tty-markdown` | `~/.vibe/skills/tui/references/tty-markdown_cheatsheet.md` | Render markdown to terminal |
| Logger | `tty-logger` | `~/.vibe/skills/tui/references/tty-logger_cheatsheet.md` | Structured terminal logging with levels, colors |
| Page/scroll | `tty-pager` | `~/.vibe/skills/tui/references/tty-pager_cheatsheet.md` | Paged output (like `less`) |
| Editor | `tty-editor` | `~/.vibe/skills/tui/references/tty-editor_cheatsheet.md` | Open files in system editor |
| File ops | `tty-file` | `~/.vibe/skills/tui/references/tty-file_cheatsheet.md` | Safe file/directory operations |
| Font | `tty-font` | `~/.vibe/skills/tui/references/tty-font_cheatsheet.md` | FIGlet-style ASCII art rendering |
| Cursor | `tty-cursor` | `~/.vibe/skills/tui/references/tty-cursor_cheatsheet.md` | ANSI cursor movement and control |
| Screen | `tty-screen` | `~/.vibe/skills/tui/references/tty-screen_cheatsheet.md` | Terminal dimension detection |
| Config | `tty-config` | `~/.vibe/skills/tui/references/tty-config_cheatsheet.md` | YAML/JSON/TOML config management |
| Options | `tty-option` | `~/.vibe/skills/tui/references/tty-option_cheatsheet.md` | CLI argument parsing |
| Reader | `tty-reader` | `~/.vibe/skills/tui/references/tty-reader_cheatsheet.md` | Low-level keypress reading |
| Tree | `tty-tree` | `~/.vibe/skills/tui/references/tty-tree_cheatsheet.md` | Directory/data structure visualization |
| Which | `tty-which` | `~/.vibe/skills/tui/references/tty-which_cheatsheet.md` | Find executables in PATH |
| Link | `tty-link` | `~/.vibe/skills/tui/references/tty-link_cheatsheet.md` | Clickable terminal hyperlinks |
| Exit | `tty-exit` | `~/.vibe/skills/tui/references/tty-exit_cheatsheet.md` | Standardized exit codes |

## Common Patterns

### Prompt Menu

```ruby
prompt = TTY::Prompt.new
choice = prompt.select("What type of project?", %w[CLI Gem Script])
```

### Table Rendering

```ruby
table = TTY::Table.new(header: ["Name", "Version"], rows: [["Ruby", "3.4"], ["Rails", "8.0"]])
puts table.render(:ascii)
```

### Progress Bar with Multi-step

```ruby
bar = TTY::ProgressBar.new("Installing [:bar] :percent", total: 30)
30.times { sleep 0.01; bar.advance }
```

### Styled Output

```ruby
pastel = Pastel.new
puts pastel.green.bold("✓ Success") + " " + pastel.cyan("Operation completed")
```

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| `tty-prompt` | Gem not installed | `gem install tty-prompt`. If fails, fall back to `gets.chomp` with basic prompt text. |
| `pastel` | Gem not installed | `gem install pastel`. If fails, strip color codes and use plain text. |
| `tty-table` | Gem not installed | `gem install tty-table`. If fails, format columns manually with `printf`/`ljust`. |
| All TTY gems | None available | Build UI with bare Ruby: `puts`, `gets`, `print`, basic ANSI codes (`"\e[32m"`). Note the degraded rendering. |

## Common Pitfalls

1. **Gem not installed**: TTY gems aren't part of stdlib. Always check with `gem list tty-prompt` or rescue `LoadError`.
2. **Terminal width**: `tty-table` auto-detects terminal width but can exceed it. Use `width: terminal_width - 2` for margins.
3. **Color on pipes**: `pastel` auto-detects TTY but may output raw escape codes. Use `pastel.enabled?` to check before piping.
4. **Prompt injection in selections**: Validate user input even from menu selections — `tty-prompt` doesn't sanitize `echo: false` inputs for type safety.
5. **Missing `require`**: TTY gems are each separate — `require "tty-prompt"`, not `require "tty"`.

## Verification Checklist

- [ ] Required TTY gems installed (`gem list` check)
- [ ] Prompts render correctly in test/development terminal
- [ ] Color works in TTY and degrades in pipe mode
- [ ] Tables don't overflow terminal width
- [ ] Progress bars complete without blocking
- [ ] Keyboard input (arrows, enter, ctrl-c) handled gracefully
- [ ] No raw escape codes visible in logged output