# Glimmer DSL for LibUI — Custom Controls

Custom controls turn repeated view code into reusable keywords. Two forms; promote from method to class as the control grows.

## Method-based (quick, same-file reuse)

Any method returning DSL content acts as a keyword:

```ruby
def form_field(model, attribute)
  entry {
    label attribute.to_s.split('_').map(&:capitalize).join(' ')
    text <=> [model, attribute]
  }
end

form {
  form_field(address, :street)
  form_field(address, :city)
}
```

## Class-based (cross-file, cross-app reuse)

```ruby
class FormField
  include Glimmer::LibUI::CustomControl

  options :model, :attribute        # keyword args of the control

  body {
    entry {
      label attribute.to_s.split('_').map(&:capitalize).join(' ')
      text <=> [model, attribute]
    }
  }
end

# class name underscores into the DSL keyword:
form {
  form_field(model: address, attribute: :street)
}
```

Rules:

- `options :a, :b` declares constructor keyword options, readable as methods inside `body`.
- `option :name, default: value` for single options with defaults.
- `body { ... }` must have exactly one root control.
- Class name `FormField` → keyword `form_field`. Namespace under a module and the keyword still resolves when the module is in scope.
- Custom controls can define `before_body { ... }` (setup: initialize model state referenced in body) and `after_body { ... }` (post-construction wiring, observers).
- Attributes of the custom control itself can be data-bound by declaring `attr_accessor` and binding inside `body` to `[self, :attr]`.

## Content slots (class-based)

A custom control can accept nested content from callers. The caller's block arrives as `content`:

```ruby
class Card
  include Glimmer::LibUI::CustomControl

  options :title

  body {
    group(title) {
      vertical_box {
        content            # caller's nested block renders here
      }
    }
  }
end

card(title: 'Details') {
  label('nested by caller')
}
```

Named slots are supported via slot methods — see the repo example `class_based_custom_control_slots.rb` for the full pattern.

## Custom windows

For whole windows, include `Glimmer::LibUI::CustomWindow` (alias: `Application`); launch with `MyApp.launch`. The repo's `login.rb` and larger apps (tetris, snake) show full MVP structure: `model/` classes with pure logic, `view/` custom controls binding to them.

## Area-based custom controls

When LibUI lacks a widget (styled button, toggle, gauge), compose it from `area` shapes with hit-testing and mouse listeners. See `area_based_custom_controls.rb` in the repo: `text_label`, `push_button` built from `rectangle` + `text` + `on_mouse_up`. Pattern:

```ruby
class Gauge
  include Glimmer::LibUI::CustomControl

  option :value, default: 0

  body {
    area {
      rectangle(0, 0, 200, 20) { stroke :black }
      rectangle(0, 0, 1, 20) {     # width driven by value
        fill :steelblue
        width <= [self, :value, on_read: ->(v) { 2 * v }]
      }
    }
  }
end
```

## When to promote

- Same snippet twice in one view → method-based.
- Used across files/views, needs options/defaults/observers → class-based, own file under `lib/<app>/view/`.
- Needs to look custom (not native) → area-based.
