# Glimmer DSL for LibUI — Data-Binding

Data-binding is the backbone of maintainable Glimmer apps (MVP pattern). The view declares *what* it shows; the model owns state.

## Operators

| Operator | Direction | Use |
|----------|-----------|-----|
| `<=>` | bidirectional | editable controls: `entry` text, `checkbox` checked, table `cell_rows` |
| `<=` | model → view only | read-only display: labels, computed text |

The model side is any plain Ruby object with `attr_accessor` for the bound attribute (observers hook the writer method).

## Basic forms

```ruby
entry {
  text <=> [self, :first_name]
}

label {
  text <= [self, :status]              # one-way
}

checkbox('Active') {
  checked <=> [user, :active]
}
```

## Converters and computed bindings

```ruby
entry {
  text <=> [product, :price, on_read: :to_s, on_write: :to_i]
}

label {
  # recompute when either dependency changes
  text <= [self, :full_name, computed_by: [:first_name, :last_name]]
}
```

`on_read`/`on_write` accept a Symbol (method name) or a lambda. Other options include `after_read`, `after_write`.

## Table binding

```ruby
# Implicit: plain array of arrays — mutations to the SAME array object are picked up
data = [['cat', 'meow'], ['dog', 'woof']]
table {
  text_column('Animal'); text_column('Sound')
  cell_rows data
}
# data.delete_at(row) inside a button_column on_clicked updates the table

# Explicit: model array with <=> — column names underscore to attribute names
table {
  text_column('Full Name')   # -> :full_name
  text_column('Email')
  cell_rows <=> [self, :contacts]
}

# Explicit with attribute mapping when names don't line up
cell_rows <=> [self, :contacts, column_attributes: [:name, :email]]
```

With explicit binding, reassigning the attribute (`self.contacts = contacts + [new]`) always notifies. Explicit binding also observes array mutations on the bound attribute for tables; when in doubt — and for every non-table binding — **reassign, don't mutate**:

```ruby
self.tasks = tasks + [new_task]    # observers fire
tasks << new_task                  # label/computed observers do NOT fire
```

## Editable tables

```ruby
table {
  text_column('Name')
  editable true
  cell_rows <=> [self, :rows]
  on_edited do |row, row_data| ... end
}
```

## Manual observation (rare)

When binding isn't enough, `Glimmer::DataBinding::Observer.proc { ... }.observe(model, :attr)` gives a raw observer. Prefer bindings; reach for this only in custom-control internals.

## MVP layering rule

- Model: plain Ruby, no Glimmer requires, fully unit-testable.
- Presenter/View: `include Glimmer` (or `Glimmer::LibUI::CustomControl`), binds to model.
- Never reach from model into view. If the view needs derived state, add a computed binding or a presenter attribute.
