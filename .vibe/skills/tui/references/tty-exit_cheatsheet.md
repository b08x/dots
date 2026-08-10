# tty-exit Cheatsheet

**Library ID**: `/piotrmurach/tty-exit`

## Targeted Usage Examples (GenAI / NLP / Systems)

### Complete CLI Application Example with TTY::Exit (Ruby)

Source: https://context7.com/piotrmurach/tty-exit/llms.txt

This example showcases a complete command-line file processing application using TTY::Exit. It demonstrates how to include the module, register custom exit codes, and use `exit_with` for various success and error conditions, including handling user interrupts and standard errors.

```ruby
#!/usr/bin/env ruby
require 'tty-exit'

class FileProcessor
  include TTY::Exit

  # Register application-specific exit codes
  register_exit(:empty_file, 10, "Input file is empty")
  register_exit(:parse_error, 11, "Failed to parse input file")

  def initialize(args)
    @args = args
  end

  def run
    validate_args
    validate_file
    process_file
    exit_with(:success)
  rescue Interrupt
    exit_with(:interrupt, "\nOperation cancelled by user\n")
  rescue StandardError => e
    exit_with(:software_error, "Unexpected error: #{e.message}\n")
  end

  private

  def validate_args
    if @args.empty?
      exit_with(:usage_error, "Usage: #{$0} <filename>\n")
    end

    if @args.length > 1
      exit_with(:usage_error, "Too many arguments. Expected 1, got #{@args.length}\n")
    end
  end

  def validate_file
    @filename = @args.first

    unless File.exist?(@filename)
      exit_with(:no_input, "File not found: #{@filename}\n")
    end

    unless File.readable?(@filename)
      exit_with(:no_permission, "Cannot read file: #{@filename}\n")
    end

    if File.zero?(@filename)
      exit_with(:empty_file, :default)
    end
  end

  def process_file
    content = File.read(@filename)
    # Process content...
    puts "Successfully processed #{content.lines.count} lines"
  rescue JSON::ParserError, YAML::SyntaxError
    exit_with(:parse_error, :default)
  rescue Errno::EIO
    exit_with(:io_error, :default)
  end
end

# Run the application
FileProcessor.new(ARGV).run

```

--------------------------------

### Include TTY::Exit Module in a Class (Ruby)

Source: https://github.com/piotrmurach/tty-exit/blob/master/README.md

Illustrates how to include the `TTY::Exit` module within a Ruby class to make its methods, like `exit_with`, directly available as instance methods. This allows for cleaner integration into application logic.

```ruby
class Command
  include TTY::Exit

  def execute
    exit_with(:config_error, :default)
  end
end

cmd = Command.new
cmd.execute
# => "ERROR(78): Configuration Error"
puts $?.exitstatus
# => 78
```

--------------------------------

### Register Custom Exit Codes with TTY::Exit

Source: https://github.com/piotrmurach/tty-exit/blob/master/README.md

Explains how to register custom exit codes and their associated messages using the `register_exit` method. This allows for more specific error handling and user notifications.

```ruby
class Command
  include TTY::Exit

  register_exit(:too_long, 7, "Argument list too long")

  def execute
    exit_with(:too_long, :default)
  end
end
```

--------------------------------

### Exit Program with Code and Message using TTY::Exit

Source: https://context7.com/piotrmurach/tty-exit/llms.txt

Shows how to use `TTY::Exit.exit_with` to terminate a Ruby application with a specific exit code and an optional message. It covers basic exits, default messages, custom messages, numeric codes, and redirecting output.

```ruby
require 'tty-exit'

# Basic exit with code name (no message)
TTY::Exit.exit_with(:usage_error)
# Process exits with status 64

# Exit with default formatted message (prints to stderr)
TTY::Exit.exit_with(:usage_error, :default)
# Output: "ERROR(64): Command line usage error"
# Process exits with status 64

# Exit with custom message
TTY::Exit.exit_with(:config_error, "Missing configuration file: config.yml")
# Output: "Missing configuration file: config.yml"
# Process exits with status 78

# Exit with numeric code
TTY::Exit.exit_with(1, "Something went wrong")
# Output: "Something went wrong"
# Process exits with status 1

# Redirect output to stdout instead of stderr
TTY::Exit.exit_with(:no_input, "File not found", io: $stdout)

# Include in a class for cleaner usage
class MyCommand
  include TTY::Exit

  def run(args)
    if args.empty?
      exit_with(:usage_error, "Usage: mycommand <filename>")
    end

    filename = args.first
    unless File.exist?(filename)
      exit_with(:no_input, :default)
    end

    # Process file...
    exit_with(:success)
  end
end
```

### TTY::Exit > Exit codes

Source: https://context7.com/piotrmurach/tty-exit/llms.txt

TTY::Exit provides a comprehensive set of predefined exit codes that map to common scenarios encountered in command-line applications. These codes are crucial for communicating the success or failure of a process to the operating system, shell scripts, or other automated tools. The library aims to standardize these exit codes, making it easier to build robust and predictable CLI applications. Some of the predefined exit codes include:

*   `:ok` (0): Successful execution.
*   `:error` (1): A general error occurred.
*   `:usage_error` (64): Incorrect command-line usage.
*   `:no_input` (65): Input file or resource could not be found or opened.
*   `:no_permission` (77): Insufficient permissions to perform an action.
*   `:config_error` (78): Problem with application configuration.
*   `:interrupt` (130): Process terminated by user (Ctrl+C).

These codes help in distinguishing between different types of failures and successes, allowing for more granular control and error handling in scripts that consume the output of CLI tools.

---

*Generated by RubyGemDB Explorer for tty-exit*
