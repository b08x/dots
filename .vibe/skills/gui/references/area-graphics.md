# Glimmer DSL for LibUI — Area Canvas & Graphics

`area` is the 2D canvas: shapes, text, gradients, transforms, mouse/keyboard events. `scrolling_area(width, height)` is the scrollable variant. Games (tetris, snake), plots (histogram), and custom widgets are all areas — the repo's `examples/` has complete versions of each.

## Two drawing modes

**Declarative (stable shapes) — default choice.** Shapes nested under `area` (or under `path` to share fill/stroke) persist and redraw automatically; you can data-bind or mutate their properties later.

```ruby
area {
  path {                                # shapes sharing one fill/stroke
    square(0, 0, 100)
    rectangle(0, 100, 100, 400)

    fill r: 102, g: 102, b: 204
  }

  circle(200, 200, 90) {                # implicit path for a single shape
    fill r: 202, g: 102, b: 204, a: 0.5
    stroke r: 0, g: 0, b: 0, thickness: 2
  }

  text(161, 40, 100) {                  # x, y, width
    string('Hello') {
      font family: 'Arial', size: 14
      color :black
    }
  }
}
```

**Semi-declarative (`on_draw`) — for scenes redrawn wholesale each frame** (games, plots with thousands of points; faster, no shape objects retained):

```ruby
area {
  on_draw do |area_draw_params|
    rectangle(0, 0, 400, 400) { fill :white }
    # draw current frame from model state
  end
}
# trigger redraw: area_proxy.queue_redraw_all
```

## Shapes

`rectangle(x, y, w, h)`, `square(x, y, size)`, `circle(xc, yc, radius)`, `arc(xc, yc, radius, start_angle, sweep, negative)`, `line(x1, y1, x2, y2)`, `polygon(x1, y1, ...)`, `polyline(...)`, `polybezier(x1, y1, cx1, cy1, cx2, cy2, x2, y2, ...)`, `figure(x, y) { line/curve; closed true }`.

## Fill & Stroke

```ruby
fill r: 102, g: 102, b: 204, a: 1.0            # color hash; also :steelblue, 0x6666cc, 'CSS-ish' names
stroke r: 0, g: 0, b: 0, thickness: 2, dashes: [50, 10], dash_phase: -50.0
fill x0: 10, y0: 10, x1: 350, y1: 350,          # linear gradient
     stops: [{pos: 0.25, r: 204, g: 102, b: 204}, {pos: 0.75, r: 102, g: 102, b: 204}]
fill outer_radius: 90, x0: 0, y0: 0, x1: 500, y1: 500, stops: [...]   # radial gradient
```

## Transforms

```ruby
rectangle(0, 0, 100, 100) {
  fill :green

  transform {
    translate 100, 100
    rotate 100, 100, 45      # x, y, degrees
    scale 2, 2
    skew 0.3, 0.1
  }
}
```

## Events

```ruby
area {
  on_mouse_down  do |e| ... end     # e is a hash: :x, :y, :area_width, ...
  on_mouse_up    do |e| ... end
  on_mouse_moved do |e| ... end
  on_mouse_event do |e| ... end     # catch-all
  on_key_down    do |e| ... end     # :key, :ext_key (e.g. :up, :down), modifiers
  on_key_up      do |e| ... end
}
```

Declarative shapes also take listeners directly (`on_mouse_up` on a `circle` fires only inside it) and support `include?(x, y)` hit-testing — this is how area-based custom buttons work.

## Animation

```ruby
Glimmer::LibUI.timer(0.05) do
  model.tick                     # advance state
  @area.queue_redraw_all         # with on_draw mode
  # or mutate declarative shape properties directly
end
```

Store the area proxy via block arg: `area { |a| @area = a; ... }`.

## Composite & custom shapes

`shape(x, y) { ... }` groups shapes into a composite moved/painted as one; class-based custom shapes include `Glimmer::LibUI::CustomShape` with `options` + `body` (see `basic_custom_shape.rb` example). For reusable widgets built from shapes, see [custom-controls.md](custom-controls.md).
