# Glimmer DSL for LibUI — Control Cheatsheet

Verified against `/andyobtiva/glimmer-dsl-libui` (Context7) and the repo's `examples/`. Signatures matter — check here (or re-verify) before writing a keyword.

## Windows & Containers

| Keyword | Signature / Notes |
|---------|-------------------|
| `window` | `window(title = nil, width = nil, height = nil, has_menubar = true)`; `.show` at the end; `margined true` for padding; `on_closing` listener |
| `vertical_box` / `horizontal_box` | children stack; `padded true` adds spacing between children |
| `form` | label+field rows; nested controls gain a `label` property |
| `grid` | `padded true`; children take `left`, `top`, `xspan`, `yspan`, `hexpand`, `halign`, `vexpand`, `valign` |
| `group` | `group(title)` — titled border box |
| `tab` / `tab_item` | `tab { tab_item('Name') { ... } }` |

## Basic Controls

| Keyword | Signature / Key properties | Listeners |
|---------|---------------------------|-----------|
| `button` | `button(text)` | `on_clicked` |
| `label` | `label(text)` | — |
| `entry` | `text` property | `on_changed` |
| `password_entry`, `search_entry` | like `entry` | `on_changed` |
| `multiline_entry` | `text`, `read_only`; `non_wrapping_multiline_entry` variant | `on_changed` |
| `checkbox` | `checkbox(text)`; `checked` | `on_toggled` |
| `radio_buttons` | `items ['A', 'B']`; `selected` (index) | `on_selected` |
| `combobox` | `items [...]`; `selected` (index) / `selected_item` (String) | `on_selected` |
| `editable_combobox` | `items [...]`; `text` | `on_changed` |
| `spinbox` | `spinbox(min, max)`; `value` | `on_changed` |
| `slider` | `slider(min, max)`; `value` | `on_changed` |
| `progress_bar` | `value` (0-100, or -1 for indeterminate) | — |
| `horizontal_separator` / `vertical_separator` | visual divider | — |
| `date_picker`, `time_picker`, `date_time_picker` | `time` property (Hash-like) | `on_changed` |
| `color_button` | `color` property | `on_changed` |
| `font_button` | `font` property | `on_changed` |
| `image` | `image(file_path, width = nil, height = nil)` — .png; used in `area` or table `image_column` |

## Common Properties (any control where applicable)

`enabled`, `visible`, `stretchy` (DSL-only; defaults `true` under boxes/forms), `padded`, `margined`, `checked`, `read_only`, `libui` (raw wrapped object), `parent`, `parent_proxy`.

## Table

```ruby
table {
  text_column('Name')
  button_column('Action') { on_clicked { |row| ... } }
  checkbox_column('Done')
  progress_bar_column('Progress')
  image_column('Avatar')          # also: image_text_column, checkbox_text_column
  text_color_column('Status')     # color-capable variants exist for most

  editable true                   # or editable per column
  cell_rows data                  # implicit binding, or <=> [model, :rows] explicit
  on_changed do |row, type, row_data| ... end
  on_row_clicked / on_row_double_clicked / on_selection_changed
}
```

Sorting, pagination (`paginated_refined_table` example), and lazy loading exist — see repo examples `paginated_refined_table.rb`, `lazy_table.rb`.

## Menus (top-level, before `window`)

```ruby
menu('File') {
  menu_item('Open') { on_clicked { file = open_file } }   # open_file/save_file/open_folder dialogs
  check_menu_item('Checkable')
  separator_menu_item
  quit_menu_item                  # auto-wired; optional on_clicked
  preferences_menu_item
  about_menu_item
}
```

## Dialogs

`msg_box(title, description)`, `msg_box_error(title, description)`, `open_file`, `save_file`, `open_folder` — all return values or nil on cancel.

## Platform / Runtime helpers

- `OS.mac?`, `OS.windows?`, `OS.linux?` (via the `os` gem, auto-required)
- `Glimmer::LibUI.timer(seconds) { ... }`, `Glimmer::LibUI.queue_main { ... }`
- `$stdout.sync = true` at script top for Windows/Linux stdout flushing

## What LibUI does NOT have

No tree view, no rich text editor, no webview, no native styling/theming of standard controls. For custom visuals, build [area-based custom controls](custom-controls.md) — the repo's `area_based_custom_controls.rb` shows styled buttons/text made of shapes.
