---
name: gui
description: "Use when building desktop GUI applications in Ruby with glimmer-dsl-libui - native cross-platform windows, forms, tables, drawing areas, custom controls, and data-bound MVP architectures. Trigger on 'desktop app', 'GUI', 'native window', 'glimmer', or 'libui' in a Ruby context."
user-invocable: true
---

# RubyDev GUI — Desktop Apps with Glimmer DSL for LibUI

## Overview

`glimmer-dsl-libui` provides a declarative Ruby DSL over LibUI, producing prerequisite-free native desktop apps on Mac, Windows, and Linux (no Java, no Electron — the `libui` gem bundles the C library). The DSL follows Glimmer conventions: nested blocks map to control hierarchies, lowercase underscored keywords map to controls, and bidirectional data-binding (`<=>`) wires views to plain Ruby models.

**Core Mandate**: Let data-binding do the work. Prefer a model + `<=>` binding over manual listener bookkeeping; the result is an MVP architecture where the view is a declarative description, not a state machine.

**References** (load the one matching the task):
- Control catalog, properties, listeners: [~/.vibe/skills/gui/references/controls-cheatsheet.md](~/.vibe/skills/gui/~/.vibe/skills/gui/references/controls-cheatsheet.md))
- Data-binding (`<=>`, `<=`, converters, table binding): [~/.vibe/skills/gui/references/data-binding.md](~/.vibe/skills/gui/~/.vibe/skills/gui/references/data-binding.md))
- Area canvas, shapes, transforms, animation: [~/.vibe/skills/gui/references/area-graphics.md](~/.vibe/skills/gui/~/.vibe/skills/gui/references/area-graphics.md))
- Custom controls (method-based and class-based): [~/.vibe/skills/gui/references/custom-controls.md](~/.vibe/skills/gui/~/.vibe/skills/gui/references/custom-controls.md))

## When to Use

- User asks for a "desktop app", "GUI", "native window", or names glimmer/libui
- A CLI tool needs a graphical front-end (forms, tables, buttons)
- Custom 2D graphics: dashboards, games, visualizations on an `area` canvas
- Reusable view components across an app (custom controls)

**Don't use for:**
- Terminal interfaces (use [tui/SKILL.md](~/.vibe/skills/tui/SKILL.md))
- Web UIs (Rails/Sinatra + frontend instead)
- Mobile apps

## Required Gems

| Gem | Purpose | Verification |
|-----|---------|--------------|
| `glimmer-dsl-libui` | The DSL | Context7 `/andyobtiva/glimmer-dsl-libui` (1200+ snippets) |
| `libui` | Bundled C bindings (transitive) | comes with glimmer-dsl-libui |

Verify DSL keywords via Context7 at the point of use — the DSL is large (100+ keywords) and signatures matter (e.g., `window(title, width, height)`, `spinbox(min, max)`). If a local clone of the glimmer-dsl-libui repo is available, its `examples/` directory (100+ runnable examples) and `docs/examples/*.md` are authoritative; prefer copying idioms from a matching example over inventing structure.

## Golden Structure

Every app follows this shape:

```ruby
# frozen_string_literal: true

require 'glimmer-dsl-libui'

class TaskManager
  include Glimmer

  attr_accessor :task_name, :tasks

  def initialize
    @tasks = []
    @task_name = ''
  end

  def launch
    window('Task Manager', 400, 300) {
      margined true

      vertical_box {
        horizontal_box {
          stretchy false

          entry {
            text <=> [self, :task_name]   # bidirectional binding
          }

          button('Add') {
            stretchy false

            on_clicked do
              self.tasks = tasks + [[task_name]] unless task_name.empty?  # reassign to notify observers
              self.task_name = ''
            end
          }
        }

        table {
          text_column('Task')

          cell_rows <=> [self, :tasks]    # table binding to model array
        }
      }

      on_closing do
        # cleanup if needed
      end
    }.show
  end
end

TaskManager.new.launch
```

DSL rules embedded above, in order of importance:

1. `include Glimmer` in the class (or at top level for scripts); build with `window(...) { ... }.show`.
2. Inside a control block: **properties first, blank line, then nested controls/listeners**. Layout properties (`stretchy`, `margined`) at the top.
3. `stretchy` defaults to `true` under `horizontal_box`/`vertical_box`/`form` — set `stretchy false` on fixed-size controls or everything stretches.
4. Data-binding beats listeners: `text <=> [model, :attr]` (bidirectional), `text <= [model, :attr]` (one-way to view). Converters: `[model, :attr, on_read: :to_s, on_write: :to_i]`.
5. To notify table/label observers of collection changes, **reassign the attribute** (`self.tasks = tasks + [x]`) or use explicit binding with mutation-aware options — see the data-binding reference.
6. Listeners are `on_`-prefixed inside the control block (`on_clicked`, `on_changed`, `on_closing`).

## Concurrency & Timing

- `Glimmer::LibUI.timer(interval_seconds) { ... }` — repeated UI-thread callback (polling, clocks, animation ticks).
- `Glimmer::LibUI.queue_main { ... }` — schedule UI updates from background threads; never touch controls directly from another thread.
- On Windows, `$stdout.flush` after `puts` in listeners (documented platform quirk).

## Workflow

1. **Classify the app**: form/CRUD (form + entries + table), canvas (area + shapes), composite (custom controls). Load the matching reference file.
2. **Model first**: plain Ruby class(es) with `attr_accessor` for every bound attribute. `dry-struct` types are welcome for non-bound domain data, but bound attributes need plain accessors for observers to hook.
3. **View as a `launch` method or class-based custom control** (see custom-controls reference for when to promote).
4. **Verify each DSL keyword** signature (Context7 or local repo examples) before use.
5. **Syntax-check** with `ruby -c`. A GUI can't be launched headlessly in most sandboxes — say so rather than claiming it ran, and smoke-test the model logic separately (models are plain Ruby: unit-test them without the GUI).

## Scaffolding Integration

When the app warrants a full project (not a single script), dispatch to [scaffold/SKILL.md](~/.vibe/skills/scaffold/SKILL.md) first, then place views under `lib/<app>/view/`, models under `lib/<app>/model/`, keeping Zeitwerk mapping. Custom controls get one file per class.

## Common Pitfalls

1. **Forgetting `stretchy false`** on buttons/labels in boxes — everything stretches and the layout looks broken.
2. **Mutating a bound array in place** (`tasks << x`) and expecting the table to update — observers fire on assignment, not mutation (unless using explicit binding with the documented mutation support). Reassign instead.
3. **Assuming a control exists** — LibUI is deliberately minimal (no tree view, limited styling). Check the controls cheatsheet; for missing widgets, compose an `area`-based custom control (see references).
4. **Doing slow work in listeners** — the UI freezes. Move work to a Thread and marshal updates back via `queue_main`.
5. **Testing the GUI instead of the model** — keep logic in models; test those. GUI launch requires a display.

## Verification Checklist

- [ ] Every DSL keyword verified against Context7 or a matching repo example
- [ ] `# frozen_string_literal: true` on every file; `ruby -c` passes
- [ ] Bound attributes have `attr_accessor`; collection updates reassign
- [ ] `stretchy false` applied to fixed-size controls
- [ ] Model logic separated from view and unit-testable without a display
