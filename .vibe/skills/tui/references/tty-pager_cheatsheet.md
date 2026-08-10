# tty-pager Cheatsheet

**Library ID**: `/piotrmurach/tty-pager`

## Targeted Usage Examples (GenAI / NLP / Systems)

### Instantiate and Use System Pager

Source: https://context7.com/piotrmurach/tty-pager/llms.txt

Directly instantiate TTY::Pager::SystemPager to use native paging tools. It raises an error if no system pager is available. You can specify a command and content to page. It also provides class methods to check for pager availability and find executables.

```ruby
require 'tty-pager'

try
  # Use system pager with specific command
  pager = TTY::Pager::SystemPager.new(command: "less -R")
  pager.page("Content with ANSI colors: \e[31mred\e[0m \e[32mgreen\e[0m")
rescue TTY::Pager::Error => e
  puts "System pager not available: #{e.message}"
end

# Check if system pager is available before creating
if TTY::Pager::SystemPager.exec_available?
  pager = TTY::Pager::SystemPager.new
  pager.page(path: "/var/log/syslog")
end

# Check for specific pager command
if TTY::Pager::SystemPager.exec_available?("less")
  puts "less is available"
end

# Find available executable from list
executable = TTY::Pager::SystemPager.find_executable("less", "more", "cat")
puts "Found pager: #{executable}"
```

--------------------------------

### Paginate Content with TTY::Pager.page (Class Method)

Source: https://context7.com/piotrmurach/tty-pager/llms.txt

Shows how to use the class-level `TTY::Pager.page` method for a quick way to paginate content. It handles pager creation, display, and cleanup automatically. Supports paginating strings, file contents, and streaming via a block.

```ruby
require 'tty-pager'

# Page a string directly
TTY::Pager.page("Very long text content here...")

# Page with specific pager command
TTY::Pager.page("Long text...", command: "less -R")

# Page file contents by path
TTY::Pager.page(path: "/path/to/large_file.txt")

# Block form for streaming content
TTY::Pager.page do |pager|
  File.foreach("large_file.txt") do |line|
    processed_line = line.upcase  # Process each line
    pager.write(processed_line)
  end
end
# Pager automatically closed after block
```

--------------------------------

### Stream Content with pager.write

Source: https://context7.com/piotrmurach/tty-pager/llms.txt

Demonstrates the `pager.write` method for sending text to the pager without automatically closing it. This is useful for streaming large amounts of data or building content incrementally. It supports multiple calls and the `<<` alias.

```ruby
require 'tty-pager'

pager = TTY::Pager.new

begin
  # Write multiple chunks
  pager.write("Header information\n")
  pager.write("=" * 40, "\n")

  # Process and stream data
  1000.times do |i|
    pager.write("Line #{i}: #{Time.now}\n")
  end

  # Chainable calls using << alias
  pager << "Footer " << "information\n"

rescue TTY::Pager::PagerClosed
  # User closed pager early (pressed 'q')
  puts "Pager was closed by user"
ensure
  pager.close
end
```

### Summary

Source: https://context7.com/piotrmurach/tty-pager/llms.txt

TTY::Pager is ideal for CLI applications that need to display large amounts of text, log files, help documentation, or any scrollable content. Common use cases include building command-line tools that output lengthy reports, creating interactive REPL environments, displaying man-page style documentation, and streaming real-time logs or data processing results. Integration is straightforward: add the gem to your project, create a pager instance, and call `page` or `write` methods. The library handles platform differences automatically, falling back to a Ruby implementation when system pagers aren't available. For CI environments or non-interactive contexts, simply disable paging with `enabled: false` to output directly to stdout without modification.

--------------------------------

### TTY::Pager > 1. Usage

Source: https://github.com/piotrmurach/tty-pager/blob/master/README.md

The **TTY::Pager** will pick the best paging mechanism available on your system when initialized:

```ruby
pager = TTY::Pager.new
```

Then to start paginating text call the `page` method with the content as the first argument:

```ruby
pager.page("Very long text...")
```

This will launch a pager in the background and wait until the user is done.

Alternatively, you can pass the `:path` keyword to specify a file path:

```ruby
pager.page(path: "/path/to/filename.txt")
```

If instead you'd like to paginate a long-running operation, you could use the block form of the pager:

```ruby
TTY::Pager.page do |pager|
  File.open("file_with_lots_of_lines.txt", "r").each_line do |line|
    # do some work with the line

    pager.write(line) # send it to the pager
  end
end
```

After block finishes, the pager is automatically closed.

For more control, you can translate the block form into separate `write` and `close` calls:

```ruby
begin
  pager = TTY::Pager.new

  File.open("file_with_lots_of_lines.txt", "r").each_line do |line|
    # do some work with the line

    pager.write(line) # send it to the pager
  end
rescue TTY::Pager::PagerClosed
  # the user closed the paginating tool
ensure
  pager.close
end
```

If you want to use a specific pager you can do so by invoking it directly:

```ruby
pager = TTY::Pager::BasicPager.new
# or
pager = TTY::Pager::SystemPager.new
# or
pager = TTY::Pager::NullPager.new
```

---

*Generated by RubyGemDB Explorer for tty-pager*
