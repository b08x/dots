# tty-markdown Cheatsheet

**Library ID**: `/piotrmurach/tty-markdown`

## Targeted Usage Examples (GenAI / NLP / Systems)

### Parse Markdown String with TTY::Markdown

Source: https://context7.com/piotrmurach/tty-markdown/llms.txt

Demonstrates parsing Markdown strings into terminal-formatted output using TTY::Markdown.parse. Covers basic usage, custom width, color modes, themes, symbols, and indentation.

```ruby
require "tty-markdown"

# Basic usage - parse a simple Markdown string
markdown = "# Hello World\n\nThis is **bold** and *italic* text."
output = TTY::Markdown.parse(markdown)
puts output
# Output: Colored header "Hello World" followed by styled text

# Parse with custom width
markdown = <<~MD
  # Project Documentation

  This is a paragraph that will be wrapped to fit within the specified width.

  - First item in the list
  - Second item with more content
  - Third item
MD
output = TTY::Markdown.parse(markdown, width: 60)
puts output

# Parse with 16-color mode for limited terminal support
output = TTY::Markdown.parse("# Heading\n\n```ruby\nputs 'hello'\n```", mode: 16)
puts output

# Parse with custom theme colors
output = TTY::Markdown.parse(
  "# Custom Styled\n\n[Link text](https://example.com)",
  theme: { link: :magenta, header: %i[green bold] }
)
puts output

# Parse with ASCII symbols instead of Unicode
output = TTY::Markdown.parse(
  "- Item 1\n- Item 2\n- Item 3",
  symbols: :ascii
)
puts output
# Uses "*" instead of "●" for bullets

# Force color output regardless of terminal detection
output = TTY::Markdown.parse("# Always Colored", color: :always)

# Disable color output entirely
output = TTY::Markdown.parse("# No Color", color: :never)

# Custom indentation (default is 2 spaces)
output = TTY::Markdown.parse("# Header\n\n## Subheader", indent: 4)
puts output
```

--------------------------------

### Render Markdown with TTY::Markdown (Ruby)

Source: https://github.com/piotrmurach/tty-markdown/blob/master/README.md

Demonstrates how to use the TTY::Markdown.parse method in Ruby to render Markdown strings. It shows examples of setting the color mode, customizing themes, controlling output width, and adjusting symbols.

```ruby
TTY::Markdown.parse(markdown_string, mode: 16)

```

```ruby
TTY::Markdown.parse(markdown_string, theme: {link: :magenta, list: %i[magenta bold]})

```

```ruby
TTY::Markdown.parse(markdown_string, width: 80)

```

```ruby
TTY::Markdown.parse(markdown_string, symbols: :ascii)

```

```ruby
TTY::Markdown.parse(markdown_string, symbols: {base: :ascii})

```

```ruby
TTY::Markdown.parse(markdown_string, symbols: {override: {bullet: "x"}})

```

```ruby
TTY::Markdown.parse(markdown_string, indent: 0)

```

```ruby
TTY::Markdown.parse(markdown_string, color: :always)

```

--------------------------------

### Render Code Blocks with Syntax Highlighting using TTY-Markdown

Source: https://context7.com/piotrmurach/tty-markdown/llms.txt

Shows how to render code blocks with syntax highlighting using TTY-Markdown and Rouge. Supports automatic language detection and different color modes (16-color, 256-color, true color). Inline code is also supported.

```ruby
require "tty-markdown"

markdown = <<~MD
  ## Ruby Example

  ```ruby
  class Greeter
    def initialize(name)
      @name = name
    end

    def greet
      puts "Hello #{@name}!"
    end
  end

  greeter = Greeter.new("World")
  greeter.greet
  ```

  ## JavaScript Example

  ```javascript
  function fibonacci(n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
  }

  console.log(fibonacci(10));
  ```

  ## Inline Code

  Use `require "tty-markdown"` to load the library.
MD

# Default 256-color highlighting
puts TTY::Markdown.parse(markdown)

# 16-color mode for basic terminals
puts TTY::Markdown.parse(markdown, mode: 16)

# True color (24-bit) if supported
puts TTY::Markdown.parse(markdown, mode: 16777216)
```

### TTY::Markdown

Source: https://context7.com/piotrmurach/tty-markdown/llms.txt

The gem renders all standard Markdown elements beautifully in the terminal, including headers with indentation-based hierarchy, ordered and unordered lists with bullet points, tables with Unicode borders and proper alignment, blockquotes with vertical bars, syntax-highlighted code blocks, links with URLs displayed, footnotes, horizontal rules, and definition lists. It automatically detects terminal capabilities and adjusts color output accordingly, while providing extensive customization options for themes, symbols, width, and indentation.

--------------------------------

### Summary

Source: https://context7.com/piotrmurach/tty-markdown/llms.txt

TTY::Markdown excels at creating beautiful, readable documentation in terminal applications. Common use cases include displaying README files, help documentation, changelogs, and formatted output in CLI tools. It integrates seamlessly with other TTY toolkit gems like tty-prompt for interactive prompts, tty-box for bordered containers, and tty-spinner for progress indicators.

---

*Generated by RubyGemDB Explorer for tty-markdown*
