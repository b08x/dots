# tty-reader Cheatsheet

**Library ID**: `/piotrmurach/tty-reader`

## Targeted Usage Examples (GenAI / NLP / Systems)

### Implement Word Completion

Source: https://context7.com/piotrmurach/tty-reader/llms.txt

Enable tab completion for command-line input by providing a `completion_handler` lambda. This handler receives a partial word and should return an array of matching suggestions. A `completion_suffix` can be added after a successful completion.

```ruby
require "tty-reader"

# Define available completions
COMMANDS = %w[help quit exit list show create delete update search]
COLORS = %w[red green blue yellow orange purple pink]

# Completion handler returns matching suggestions
completion_handler = ->(word) {
  all_words = COMMANDS + COLORS
  all_words.grep(/^#{Regexp.escape(word)}/i)
}

reader = TTY::Reader.new(
  completion_handler: completion_handler,
  completion_suffix: " "  # Add space after completion
)

# Listen for completion events
reader.on(:complete) do |event|
  puts "\nCompleted: #{event.completion}"
end

puts "Type a command and press Tab to complete"
puts "Commands: #{COMMANDS.join(', ')}"
puts "Colors: #{COLORS.join(', ')}"

loop do
  input = reader.read_line("=> ")
  break if input.strip == "exit"
  puts "Executing: #{input}"
end

# Dynamic completion based on context
reader.completion_handler = ->(word) {
  # Could query database, filesystem, or API
  Dir.glob("#{word}*").take(10)
}
```

--------------------------------

### Build Interactive Shell with TTY::Reader

Source: https://context7.com/piotrmurach/tty-reader/llms.txt

This Ruby code defines a `Shell` class that utilizes TTY::Reader to create an interactive command-line interface. It handles user input, command parsing, custom keybindings for screen clearing and interrupt handling, and autocompletion for predefined commands. Dependencies include the 'tty-reader' gem.

```ruby
require "tty-reader"

class Shell
  COMMANDS = %w[help list show create delete quit exit clear history]

  def initialize
    @reader = TTY::Reader.new(
      interrupt: :noop,
      history_cycle: false,
      history_duplicates: false,
      completion_handler: method(:complete),
      completion_suffix: " "
    )

    setup_keybindings
  end

  def complete(word)
    COMMANDS.grep(/^#{Regexp.escape(word)}/i)
  end

  def setup_keybindings
    @reader.on(:keyctrl_c) do
      puts "\nUse 'quit' or 'exit' to leave"
    end

    @reader.on(:keyctrl_l) do
      print "\e[2J\e[H"  # Clear screen
    end

    @reader.on(:keyescape) do
      puts "\nEscape pressed"
    end
  end

  def run
    puts "Welcome to MyShell v1.0"
    puts "Type 'help' for commands, Tab for completion"
    puts ""

    loop do
      input = @reader.read_line("myshell> ").strip

      case input
      when ""
        next
      when "quit", "exit"
        puts "Goodbye!"
        break
      when "help"
        puts "Available commands: #{COMMANDS.join(', ')}"
      when "clear"
        print "\e[2J\e[H"
      when "history"
        puts "History feature enabled - use up/down arrows"
      when /^list/
        puts "Listing items..."
      when /^show (.+)/ 
        puts "Showing: #{$1}"
      when /^create (.+)/ 
        puts "Creating: #{$1}"
      when /^delete (.+)/ 
        puts "Deleting: #{$1}"
      else
        puts "Unknown command: #{input}"
      end
    end
  end
end

Shell.new.run

```

### Building an Interactive Shell

Source: https://context7.com/piotrmurach/tty-reader/llms.txt

This example demonstrates how to build a shell-like interface with TTY::Reader. It sets up a reader with custom key bindings for Ctrl+C (to display a hint), Ctrl+L (to clear the screen), and Escape. It also configures command completion for a predefined list of commands and uses `read_line` to prompt the user for input. The shell then processes various commands, including `help`, `clear`, `history`, and pattern matching for other commands, providing a basic interactive command-line experience.

--------------------------------

### tty-reader > Word Completion

Source: https://context7.com/piotrmurach/tty-reader/llms.txt

The `tty-reader` gem supports word completion, allowing you to provide suggestions as the user types. This is configured by providing a `completion_handler` to the `TTY::Reader.new` constructor. This handler is a callable (like a lambda or proc) that accepts a partial word as input and returns an array of matching suggestions. You can also specify a `completion_suffix` to be appended after a completion is selected, such as a space. The gem emits a `:complete` event when a completion occurs, which you can listen to. For dynamic completion, the `completion_handler` can be updated at runtime to provide context-aware suggestions, such as listing files in a directory based on the current input.

--------------------------------

### Summary

Source: https://context7.com/piotrmurach/tty-reader/llms.txt

Integration with other Ruby applications is straightforward: instantiate a Reader object, configure history and completion options as needed, then use `read_line` or `read_multiline` for input. For advanced scenarios, combine event handlers via `on` or `subscribe` to react to specific keystrokes, and use `trigger` to programmatically simulate input. TTY::Reader works well alongside other TTY toolkit gems (tty-prompt, tty-cursor, tty-screen) for building comprehensive terminal interfaces.

---

*Generated by RubyGemDB Explorer for tty-reader*
