# tty-config Cheatsheet

**Library ID**: `/piotrmurach/tty-config`

## Targeted Usage Examples (GenAI / NLP / Systems)

### Complete Application Example with TTY-Config and Optparse

Source: https://context7.com/piotrmurach/tty-config/llms.txt

This comprehensive example illustrates integrating TTY-Config with the `optparse` gem to build a command-line application. It showcases setting configuration paths, loading from environment variables, defining defaults, adding validation rules, parsing command-line arguments, and merging configurations from various sources.

```ruby
require "tty-config"
require "optparse"

class App
  attr_reader :config

  def initialize
    @config = TTY::Config.new
    @config.filename = "myapp"
    @config.append_path(Dir.pwd)
    @config.append_path(File.join(Dir.home, ".config", "myapp"))
    @config.append_path("/etc/myapp")

    # Set up environment variable loading
    @config.env_prefix = "myapp"
    @config.autoload_env

    # Set defaults
    @config.set_if_empty(:host, value: "localhost")
    @config.set_if_empty(:port, value: 8080)
    @config.set_if_empty(:debug, value: false)

    # Add validation
    @config.validate(:port) do |key, value|
      unless value.to_i.between?(1, 65535)
        raise TTY::Config::ValidationError, "Invalid port: #{value}"
      end
    end
  end

  def load_config_file
    if @config.exist?
      @config.read
      puts "Loaded config from: #{@config.source_file}"
    end
  rescue TTY::Config::ReadError => e
    warn "Warning: #{e.message}"
  end

  def parse_options(argv)
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: myapp [options]"

      opts.on("-h", "--host HOST", "Server host") do |h|
        options[:host] = h
      end

      opts.on("-p", "--port PORT", Integer, "Server port") do |p|
        options[:port] = p
      end

      opts.on("-d", "--debug", "Enable debug mode") do
        options[:debug] = true
      end

      opts.on("-c", "--config FILE", "Config file path") do |c|
        options[:config_file] = c
      end
    end.parse!(argv)

    # Merge CLI options (highest priority)
    @config.merge(options)
  end

  def run
    puts "Starting server on #{@config.fetch(:host)}:#{@config.fetch(:port)}"
    puts "Debug mode: #{@config.fetch(:debug)}"
  end
end

# Usage:
# MYAPP_HOST=production.example.com ruby app.rb --port 3000 --debug

app = App.new
app.load_config_file
app.parse_options(ARGV)
app.run
```

--------------------------------

### Working with Environment Variables in TTY::Config (Ruby)

Source: https://github.com/piotrmurach/tty-config/blob/master/README.md

Provides examples of how TTY::Config integrates with environment variables. It shows setting environment variables, configuring TTY::Config to read them using `env_prefix` and `set_from_env` or `autoload_env`, and then fetching the values.

```ruby
ENV["MYTOOL_HOST"] = "192.168.1.17"
ENV["MYTOOL_PORT"] = "7727"

config.env_prefix = "mytool"
config.set_from_env(:host)
config.set_from_env(:port)

# Alternatively, using autoload_env:
# config.autoload_env

config.fetch(:host)
# => "192.168.1.17"
config.fetch(:port)
# => "7727"
```

--------------------------------

### Merge External Settings into Configuration

Source: https://context7.com/piotrmurach/tty-config/llms.txt

Demonstrates the `merge` method for incorporating external hash data into the existing configuration, performing a deep merge for nested structures.

```ruby
config = TTY::Config.new
config.set(:database, :host, value: "localhost")
config.set(:database, :port, value: 5432)

external_settings = {
  database: {
    host: "192.168.1.1",
    username: "admin"
  },
  logging: {
    level: "debug"
  }
}

config.merge(external_settings)

config.fetch(:database, :host)     # => "192.168.1.1" (overwritten)
config.fetch(:database, :port)     # => 5432 (original preserved)
config.fetch(:database, :username) # => "admin" (newly added)
config.fetch(:logging, :level)     # => "debug" (newly added)
```

--------------------------------

### Set Configuration Values with TTY::Config

Source: https://context7.com/piotrmurach/tty-config/llms.txt

Shows how to set configuration values using `set`, supporting simple key-value pairs, deeply nested keys via multiple arguments or dot notation, and lazy evaluation using blocks.

```ruby
config = TTY::Config.new

# Simple key-value
config.set(:api_key, value: "abc123")

# Deeply nested keys with multiple arguments
config.set(:database, :primary, :host, value: "localhost")
config.set(:database, :primary, :port, value: 5432)

# Dot notation for nested keys
config.set("database.replica.host", value: "replica.example.com")

# Lazy evaluation with block (evaluated each time value is fetched)
config.set(:timestamp) { Time.now.to_i }

# Current configuration
config.to_h
# => {"api_key"=>"abc123",
#     "database"=>{"primary"=>{"host"=>"localhost", "port"=>5432},
#                  "replica"=>{"host"=>"replica.example.com"}},
#     "timestamp"=>#<Proc:...>}
```

--------------------------------

### Fetch Configuration Values with TTY::Config

Source: https://context7.com/piotrmurach/tty-config/llms.txt

Explains how to retrieve configuration values using `fetch`, supporting nested keys, default values, lazy block defaults, and indifferent access (symbols/strings).

```ruby
config = TTY::Config.new
config.set(:settings, :base, value: "USD")
config.set(:settings, :color, value: true)
config.set(:coins, value: ["BTC", "ETH", "TRX"])

# Simple fetch
config.fetch(:coins)
# => ["BTC", "ETH", "TRX"]

# Nested key fetch (multiple arguments)
config.fetch(:settings, :base)
# => "USD"

# Dot notation for nested keys
config.fetch("settings.color")
# => true

# Indifferent access (mix symbols and strings)
config.fetch("settings", :base)   # => "USD"
config.fetch(:settings, "color")  # => true

# With default value
config.fetch(:missing_key, default: "fallback")
# => "fallback"

# With block default (lazy evaluated)
config.fetch(:missing_key) { "computed_#{rand(100)}" }
# => "computed_42"
```

---

*Generated by RubyGemDB Explorer for tty-config*
