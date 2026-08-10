# tty-table Cheatsheet

**Library ID**: `/piotrmurach/tty-table`

## Targeted Usage Examples (GenAI / NLP / Systems)

### Create TTY::Table Objects in Ruby

Source: https://context7.com/piotrmurach/tty-table/llms.txt

Demonstrates various ways to create TTY::Table objects, including using 2D arrays, headers and rows, keyword arguments, block-based initialization, and dynamic row addition. Requires the 'tty-table' gem.

```ruby
require "tty-table"

# Simple 2D array creation
table = TTY::Table [["a1", "a2"], ["b1", "b2"]]

# With headers and rows
table = TTY::Table.new(["Name", "Age", "City"], [
  ["Alice", "30", "NYC"],
  ["Bob", "25", "LA"],
  ["Charlie", "35", "Chicago"]
])

# Using keyword arguments
table = TTY::Table.new(
  header: ["Product", "Price", "Stock"],
  rows: [
    ["Laptop", "$999", "15"],
    ["Phone", "$599", "42"],
    ["Tablet", "$399", "28"]
  ]
)

# Block-based initialization
table = TTY::Table.new(header: ["ID", "Status"]) do |t|
  t << ["001", "Active"]
  t << ["002", "Pending"]
  t << ["003", "Completed"]
end

# Adding rows dynamically
table = TTY::Table.new
table << ["First", "Row"]
table << ["Second", "Row"]

puts table.render(:ascii)
# =>
#  +------+----+
#  |First |Row |
#  |Second|Row |
#  +------+----+

```

--------------------------------

### Configure TTY::Table Rendering Options Using a Block

Source: https://context7.com/piotrmurach/tty-table/llms.txt

This example shows how to configure multiple TTY::Table rendering options, such as alignment, border separators, border styles, and padding, using a convenient block syntax. It also demonstrates creating a reusable renderer instance for consistent table formatting.

```ruby
require "tty-table"

table = TTY::Table.new(
  ["Product", "Price", "Qty", "Total"],
  [
    ["Widget A", "$10.00", "5", "$50.00"],
    ["Widget B", "$25.00", "2", "$50.00"],
    ["Widget C", "$15.00", "3", "$45.00"]
  ]
)

puts table.render(:unicode) do |renderer|
  renderer.alignments = [:left, :right, :center, :right]
  renderer.border.separator = :each_row
  renderer.border.style = :blue
  renderer.padding = [0, 1]
  renderer.filter = ->(val, row, col) {
    col == 3 && row > 0 ? val.gsub("$", "USD ") : val
  }
end

# Creating reusable renderer
renderer = TTY::Table::Renderer::Unicode.new(table, {
  multiline: true,
  padding: [0, 2],
  alignments: [:left, :right, :center, :right]
})

# Render same table multiple times with same config
puts renderer.render
```

--------------------------------

### Apply Custom Filters to Cell Values (Ruby)

Source: https://context7.com/piotrmurach/tty-table/llms.txt

Demonstrates how to use a filter function with TTY-Table to apply custom transformations to cell values during rendering. The filter lambda receives the value, row index, and column index, allowing conditional formatting or modification.

```ruby
require "tty-table"

table = TTY::Table.new(
  ["Name", "Status"],
  [["alice", "active"], ["bob", "inactive"], ["charlie", "pending"]]
)

# Capitalize second column (skip header row at index 0)
puts table.render(:ascii) do |renderer|
  renderer.filter = ->(val, row_index, col_index) do
    if col_index == 1 && row_index != 0
      val.upcase
    else
      val
    end
  end
end

# Using Pastel for colored output
require "pastel"
pastel = Pastel.new

puts table.render(:ascii) do |renderer|
  renderer.filter = ->(val, row_index, col_index) do
    if col_index == 1 && row_index != 0
      case val
      when "active" then pastel.green(val)
      when "inactive" then pastel.red(val)
      else pastel.yellow(val)
      end
    else
      val
    end
  end
end
```

--------------------------------

### Apply Color and Separator Styles to TTY::Table Borders

Source: https://context7.com/piotrmurach/tty-table/llms.txt

This code illustrates how to style TTY::Table borders using colors from the Pastel gem and control border separators. It shows applying a green border with ASCII rendering, a blue border with row separators using Unicode rendering, and combining border styling with header coloring using Pastel.

```ruby
require "tty-table"

table = TTY::Table.new(
  ["Name", "Value"],
  [["foo", "100"], ["bar", "200"]]
)

# Green border
puts table.render(:ascii) do |renderer|
  renderer.border.style = :green
end

# Blue border with separator
puts table.render(:unicode) do |renderer|
  renderer.border.style = :blue
  renderer.border.separator = :each_row
end

# Combined with pastel for header coloring
require "pastel"
pastel = Pastel.new

header = [pastel.bold("Name"), pastel.bold("Value")]
table = TTY::Table.new(header, [["foo", "100"], ["bar", "200"]])
puts table.render(:ascii) do |renderer|
  renderer.border.style = :cyan
end
```

--------------------------------

### Control TTY::Table Width and Enable Terminal Resizing

Source: https://context7.com/piotrmurach/tty-table/llms.txt

This example demonstrates how to manage the width of TTY tables, including enabling automatic resizing to fit terminal dimensions. It shows rendering with `resize: true`, setting a fixed `width`, specifying individual `column_widths`, and combining resizing with padding.

```ruby
require "tty-table"

header = ["Column 1", "Column 2", "Column 3"]
rows = [
  ["Short", "Medium text", "A very long text that might need wrapping"],
  ["A", "B", "C"]
]
table = TTY::Table.new(header, rows)

# Resize to fit terminal width automatically
puts table.render(:ascii, resize: true)

# Set specific width
puts table.render(:ascii, width: 40, resize: true)

# Specify column widths manually
puts table.render(:ascii, column_widths: [10, 15, 20])

# Combine resize with padding
puts table.render(:ascii, resize: true, padding: [0, 1])
```

---

*Generated by RubyGemDB Explorer for tty-table*
