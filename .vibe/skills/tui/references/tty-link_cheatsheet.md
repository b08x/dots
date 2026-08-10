# tty-link Cheatsheet

**Library ID**: `/piotrmurach/tty-link`

## Targeted Usage Examples (GenAI / NLP / Systems)

### Generate Terminal Hyperlinks - Ruby

Source: https://context7.com/piotrmurach/tty-link/llms.txt

Illustrates generating terminal hyperlinks using TTY::Link. This covers basic name and URL links, URL-only links, adding HTML-like attributes, using class method shortcuts, forcing ANSI output, and applying custom plain text templates.

```ruby
require "tty-link"

link = TTY::Link.new

# Basic hyperlink with name and URL
result = link.link_to("TTY Toolkit", "https://ttytoolkit.org")
# Supported terminal:   "\e]8;;https://ttytoolkit.org\aTTY Toolkit\e]8;;\a"
# Unsupported terminal: "TTY Toolkit -> https://ttytoolkit.org"

# URL-only link (name defaults to URL)
result = link.link_to("https://github.com/piotrmurach/tty-link")
# => "https://github.com/piotrmurach/tty-link -> https://github.com/piotrmurach/tty-link"

# Hyperlink with ID attribute (for terminal-specific features)
result = link.link_to("Documentation", "https://docs.example.com", attrs: {id: "docs-link"})
# => "\e]8;id=docs-link;https://docs.example.com\aDocumentation\e]8;;\a"

# Multiple attributes
result = link.link_to("Example", "https://example.com", attrs: {
  id: "example-link",
  lang: "en",
  title: "Example Website"
})
# => "\e]8;id=example-link:lang=en:title=Example Website;https://example.com\aExample\e]8;;\a"

# Class method shortcut (creates instance internally)
puts TTY::Link.link_to("Ruby", "https://ruby-lang.org")

# Force ANSI output even on unsupported terminals
puts TTY::Link.link_to("Forced Link", "https://example.com", hyperlink: :always)

# Custom plain text template
link_custom = TTY::Link.new(plain: "[:name](:url)")
result = link_custom.link_to("GitHub", "https://github.com")
# Unsupported terminal: "[GitHub](https://github.com)"
```

--------------------------------

### Create TTY::Link Instance - Ruby

Source: https://context7.com/piotrmurach/tty-link/llms.txt

Demonstrates how to create a TTY::Link instance with various configuration options. This includes forcing or disabling hyperlinks, specifying a custom output stream, providing mock environment variables for testing, and defining a plain text fallback template.

```ruby
require "tty-link"

# Basic instance creation (auto-detects terminal support)
link = TTY::Link.new

# Force hyperlinks regardless of terminal support
link = TTY::Link.new(hyperlink: :always)

# Disable hyperlinks entirely (always use plain text)
link = TTY::Link.new(hyperlink: :never)

# Custom output stream
link = TTY::Link.new(output: $stderr)

# Custom environment variables for testing
link = TTY::Link.new(env: {
  "TERM_PROGRAM" => "iTerm.app",
  "TERM_PROGRAM_VERSION" => "3.4.0"
})

# Custom plain text template (used when hyperlinks not supported)
link = TTY::Link.new(plain: ":name (:url)")
# => Produces: "My Link (https://example.com)"

# Using environment variable to control hyperlink detection
link = TTY::Link.new(env: {"TTY_LINK_HYPERLINK" => "always"})
```

--------------------------------

### Configure Plain Text Fallback Templates with TTY::Link

Source: https://context7.com/piotrmurach/tty-link/llms.txt

Explains how to configure the fallback plain text format for TTY::Link using the `:plain` option with `:name` and `:url` tokens. This template is used when the terminal does not support hyperlinks, demonstrating various formats like Markdown, parenthetical, name-only, URL-only, and HTML-style.

```ruby
require "tty-link"

# Default template: ":name -> :url"
link = TTY::Link.new(hyperlink: :never)
puts link.link_to("Google", "https://google.com")
# => "Google -> https://google.com"

# Markdown-style links
link = TTY::Link.new(hyperlink: :never, plain: "[:name](:url)")
puts link.link_to("Google", "https://google.com")
# => "[Google](https://google.com)"

# Parenthetical style
link = TTY::Link.new(hyperlink: :never, plain: ":name (:url)")
puts link.link_to("Google", "https://google.com")
# => "Google (https://google.com)"

# Name only (hide URL)
link = TTY::Link.new(hyperlink: :never, plain: ":name")
puts link.link_to("Google", "https://google.com")
# => "Google"

# URL only (hide name)
link = TTY::Link.new(hyperlink: :never, plain: ":url")
puts link.link_to("Google", "https://google.com")
# => "https://google.com"

# HTML-style
link = TTY::Link.new(hyperlink: :never, plain: "<a href=':url'>:name</a>")
puts link.link_to("Google", "https://google.com")
# => "<a href='https://google.com'>Google</a>"
```

### TTY::Link > Usage

Source: https://github.com/piotrmurach/tty-link/blob/master/README.md

Create a **TTY::Link** instance: 

```ruby
link = TTY::Link.new
```

Then use the [link_to](#23-link_to) method to print a hyperlink in the terminal: 

```ruby
puts link.link_to("TTY Toolkit", "https://ttytoolkit.org")
```

This will output a clickable link in the [terminal supporting](#3-supported-terminals) hyperlinks: 

```shell
TTY Toolkit
```

Or it will print a [plain](#214-plain) text version with a URL in unsupported terminals: 

```shell
TTY Toolkit -> https://ttytoolkit.org
```

By default, **TTY::Link** uses the [link?](#22-link) method to detect whether the terminal supports hyperlinks: 

```ruby
link.link?
```

Overwrite this automatic detection with the [:hyperlink](#213-hyperlink) keyword. 

For example, to always create hyperlinks in the terminal: 

```ruby
link = TTY::Link.new(hyperlink: :always)
```

Alternatively, use the `TTY_LINK_HYPERLINK` environment variable to control hyperlink support detection. The variable takes precedence over the [:hyperlink](#213-hyperlink) keyword. 

Use the [:env](#211-env) keyword to overwrite any environment variables set in the terminal: 

```ruby
link = TTY::Link.new(env: {"TTY_LINK_HYPERLINK" => "always"})
```

As a convenience, the [link?](#22-link) and [link_to](#23-link_to) methods are also available on the **TTY::Link** class. The methods accept all the configuration keywords. 

For example, to always output hyperlinks in the terminal: 

```ruby
puts TTY::Link.link_to("TTY Toolkit", "https://ttytoolkit.org", hyperlink: :always)
```

--------------------------------

### TTY::Link > Summary

Source: https://context7.com/piotrmurach/tty-link/llms.txt

TTY::Link is a valuable tool for Ruby terminal applications that need to display clickable hyperlinks. It's particularly useful for CLI tools showing URLs (e.g., git clients), documentation viewers, and log analyzers where users can click on file paths. The gem simplifies development by handling the complexities of terminal detection and ANSI escape sequences, allowing developers to concentrate on their application's core logic. Integration is flexible, with options for direct class method use or instance creation for consistent settings. TTY::Link integrates well with other TTY toolkit components and testing is facilitated through `:env` and `:output` options.

---

*Generated by RubyGemDB Explorer for tty-link*
