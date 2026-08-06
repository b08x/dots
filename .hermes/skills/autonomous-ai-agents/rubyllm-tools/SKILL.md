---
name: rubyllm-tools
description: "Define and wire RubyLLM tools into Chat with parameters."
version: 0.1.0
author: Hermes
metadata:
  hermes:
    tags: [RubyLLM, Tools, FunctionCalling, MCP, Agents]
---

# RubyLLM Tools

Define Ruby classes that let an LLM call into your code via function-calling, then wire them into `RubyLLM.chat`. Covers the four parameter styles (signature inference, `param`, `params` DSL, raw JSON Schema), chat wiring (`with_tool`/`with_tools`), call controls (`choice`, `calls`, `concurrency`), additive callbacks, `halt`, `RubyLLM::Content` returns with file attachments, the `with_params` provider metadata hook, error handling, and security hygiene. Does NOT cover MCP server authoring (it ships as the separate `ruby_llm-mcp gem`) or Rails chat persistence.

Source: https://rubyllm.com/tools/

## When to Use

- "Let the LLM call my Ruby method as a function."
- "Add a tool to a `RubyLLM.chat` session."
- "Pass nested objects or enums to a tool with a schema."
- "Run multiple tool calls concurrently."
- "Stream tool-call events for logging or rate-limiting."
- "Stop the LLM from narrating after a tool returns."
- "Attach a generated image or PDF to a tool result."

## Prerequisites

- Ruby 3.x (the guide uses Ruby 3.3 features).
- Gem: `ruby_llm` (`gem 'ruby_llm'` in the Gemfile).
- A configured RubyLLM provider key — `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, or another supported provider.
- For `concurrency: :fibers`: also `gem 'async'` in the Gemfile.
- For MCP server integration: install the community-maintained `ruby_llm-mcp` gem separately.

## How to Run

This is a code-pattern reference. Author each tool in `app/tools/` (Rails) or `lib/tools/` (plain Ruby), then exercise via the `terminal` tool:

```
bin/rails runner 'puts RubyLLM.chat(model: "gpt-5.4").with_tool(Weather).ask("Weather in Berlin?").content'
```

For plain Ruby:

```
ruby -e 'require "ruby_llm"; require_relative "lib/tools/weather"; puts RubyLLM.chat.with_tool(Weather).ask("Weather in Berlin?").content'
```

To debug, prefix with `RUBYLLM_DEBUG=true`:

```
RUBYLLM_DEBUG=true ruby script.rb
```

## Quick Reference

- Tool base class: `RubyLLM::Tool`.
- Tool description: `desc "..."` (or `description "..."`) — short class-method summary for the LLM.
- Name override: define `def name; "..."; end` on the tool class.
- Parameter styles (pick one):
  - `def execute(latitude:, longitude:, units: "metric")` — signature inference (v1.15+).
  - `param :name, desc: "...", type: :integer, required: false` — flat scalar helper.
  - `params do ... end` — nested objects, arrays, enums, unions (v1.9+).
  - `params type: "object", properties: {...}, ...` — raw JSON Schema hash (v1.9+).
- Attach: `chat.with_tool(MyTool)` or `chat.with_tools(ToolA, ToolB.new, replace: true)`.
- Clear: `chat.with_tools(replace: true)`.
- Controls: `choice:` (`:auto | :required | :none | :name | ToolClass`), `calls:` (`:many | :one | 1`), `concurrency:` (`:threads | :fibers | true | false`).
- Global concurrency: `RubyLLM.configure { |c| c.tool_concurrency = true }`.
- Callbacks (additive, v1.15+): `chat.before_tool_call { |tc| ... }.after_tool_result { |r| ... }`.
- Provider metadata: `with_params cache_control: { type: "ephemeral" }` inside the tool class.
- Skip LLM continuation: `halt "saved"` inside `execute`.
- Rich return: `RubyLLM::Content.new("text", [path_or_blob])`.
- Tool hallucination: RubyLLM returns the missing tool name + available list to the model so it can recover.
- Debug: `export RUBYLLM_DEBUG=true`.

## Procedure

1. Subclass `RubyLLM::Tool`, declare `desc`/`description`, and write `def execute(...)`. Optional: define `def name` to override the snake_cased class name.
2. Pick a parameter style. Use signature inference for trivial scalars; add `param` for descriptions or non-string types; use `params do ... end` for nested/array/enum inputs; pass a raw schema hash to `params` when you must own the JSON Schema yourself.
3. For content-bearing tools, return `RubyLLM::Content.new("text", [attachment_paths])` so the model can see the files.
4. For tools with dependencies, accept them in `def initialize(...)` and register the *instance* via `chat.with_tool(MyTool.new(dep))`.
5. Create the chat: `chat = RubyLLM.chat(model: 'gpt-5.4')` (use a function-calling-capable model).
6. Register tools: `chat.with_tool(Weather)` or `chat.with_tools(ToolA, ToolB.new, choice: :auto, calls: :many, concurrency: :threads)`. Pass `replace: true` to swap or clear.
7. Add additive callbacks for observability: `.before_tool_call { |tc| ... }.after_tool_result { |r| ... }`.
8. For provider-specific knobs (e.g. Anthropic `cache_control`), declare `with_params cache_control: { type: "ephemeral" }` on the tool class.
9. Call `chat.ask(...)` — RubyLLM handles tool dispatch, error responses from the tool, and the multi-step flow internally.
10. If a tool's output should be the final answer, end `execute` with `halt "..."`.

### Minimal tool with signature inference (v1.15+)

```ruby
class Weather < RubyLLM::Tool
  desc "Gets current weather for a location"

  def execute(latitude:, longitude:, units: "metric")
    url = "https://api.open-meteo.com/v1/forecast?latitude=#{latitude}&longitude=#{longitude}&current=temperature_2m,wind_speed_10m"
    response = Faraday.get(url)
    JSON.parse(response.body)
  rescue => e
    { error: e.message }
  end
end
```

### `param` helper for typed scalars

```ruby
class Distance < RubyLLM::Tool
  desc "Calculates distance between two cities"
  param :origin,      desc: "Origin city name"
  param :destination, description: "Destination city name"
  param :units,       type: :string, desc: "Unit system (metric or imperial)", required: false

  def execute(origin:, destination:, units: "metric")
    # ...
  end
end
```

### `params` DSL for nested/array/enum

```ruby
class Scheduler < RubyLLM::Tool
  desc "Books a meeting"

  params do
    object :window, description: "Time window to reserve" do
      string :start,  description: "ISO8601 start time"
      string :finish, description: "ISO8601 end time"
    end

    array :participants, of: :string, description: "Email addresses to invite"

    any_of :format, description: "Optional meeting format" do
      string enum: %w[virtual in_person]
      null
    end
  end

  def execute(window:, participants:, format: nil)
    # ...
  end
end
```

### Raw JSON Schema (strict mode)

```ruby
class Lookup < RubyLLM::Tool
  description "Performs catalog lookups"

  params type: "object",
         properties: {
           sku:    { type: "string", description: "Product SKU" },
           locale: { type: "string", description: "Country code", default: "US" }
         },
         required: %w[sku],
         additionalProperties: false,
         strict: true

  def execute(sku:, locale: "US")
    # ...
  end
end
```

### Rich `RubyLLM::Content` return with attachments

```ruby
class AnalyzeTool < RubyLLM::Tool
  description "Analyzes data and returns results with visualizations"
  param :query, desc: "Analysis query"

  def execute(query:)
    chart_path = generate_chart(query)
    RubyLLM::Content.new("Analysis complete for: #{query}", [chart_path])
  end

  private

  def generate_chart(query)
    "/tmp/chart_#{Time.now.to_i}.png"
  end
end

chat = RubyLLM.chat.with_tool(AnalyzeTool)
chat.ask("Analyze sales trends for Q4")
```

### Custom initialization

```ruby
class DocumentSearch < RubyLLM::Tool
  description "Searches documents by relevance"
  param :query, desc: "The search query"
  param :limit, type: :integer, desc: "Maximum number of results", required: false

  def initialize(database)
    @database = database
  end

  def execute(query:, limit: 5)
    @database.search(query, limit: limit)
  end
end

search_tool = DocumentSearch.new(MyDatabase)
chat.with_tool(search_tool)
```

### Wire tools into Chat + controls

```ruby
chat = RubyLLM.chat(model: 'gpt-5.4')
weather_tool = Weather.new

chat.with_tool(weather_tool)
# Or: chat.with_tools(Weather, AnotherTool.new)
# Or: chat.with_tools(NewTool, AnotherTool, replace: true)  # swap
# Or: chat.with_tools(replace: true)                       # clear

# Choice (v1.13+): :auto | :required | :none | :name | ToolClass
chat.with_tools(Weather, Calculator, choice: :required)   # forces a tool call
chat.with_tools(Weather, Calculator, choice: :weather)   # forces one specific tool
chat.with_tools(Weather, Calculator, choice: Weather)    # same, by class

# Calls (v1.13+): :many | :one | 1   (default: provider's usual = :many)
chat.with_tools(Weather, Calculator, calls: :one)

# Concurrency (v1.16+): sequential by default
chat.with_tools(Weather, StockPrice, Currency, concurrency: :threads)  # stdlib threads
chat.with_tools(Weather, StockPrice, Currency, concurrency: :fibers)   # needs `async` gem
chat.with_tools(Weather, StockPrice, concurrency: false)               # per-chat override
```

### Concurrent tool execution (v1.16+)

```ruby
# Global default
RubyLLM.configure do |config|
  config.tool_concurrency = true
end

# Per-chat override
chat_record.with_tools(Weather, StockPrice, concurrency: :threads)
chat_record.with_tools(Weather, StockPrice, concurrency: :fibers)
```

With concurrency on, tool results stream back as each tool finishes; RubyLLM waits for all of them before the next model turn.

### Callbacks for observability and limits (v1.15+)

```ruby
chat = RubyLLM.chat(model: 'gpt-5.4')
      .with_tool(Weather)
      .before_tool_call do |tool_call|
        puts "Calling tool: #{tool_call.name}"
        puts "Arguments: #{tool_call.arguments}"
      end
      .after_tool_result do |result|
        puts "Tool returned: #{result}"
      end
```

### Limiting tool calls (use with care)

```ruby
call_count = 0
max_calls = 10

chat = RubyLLM.chat(model: 'gpt-5.4')
      .with_tool(Weather)
      .before_tool_call do |_tool_call|
        call_count += 1
        raise "Tool call limit exceeded (#{max_calls} calls)" if call_count > max_calls
      end
```

Raising inside `before_tool_call` leaves the chat mid-flow (the LLM expects a tool response). Prefer clearer tool descriptions over hard limits.

### Provider-specific metadata (v1.9+)

```ruby
class TodoTool < RubyLLM::Tool
  description "Adds a task to the shared TODO list"

  params do
    string :title, description: "Human-friendly task description"
  end

  with_params cache_control: { type: "ephemeral" }

  def execute(title:)
    Todo.create!(title:)
    "Added "#{title}" to the list."
  end
end
```

Provider metadata is passed through verbatim — set `RUBYLLM_DEBUG=true` to inspect the merged payload.

### `halt` to skip the LLM's follow-up

```ruby
class SaveFileTool < RubyLLM::Tool
  description "Save content to a file"
  param :path,    desc: "File path"
  param :content, desc: "File content"

  def execute(path:, content:)
    File.write(path, content)
    halt "Saved to #{path}"
  end
end
```

Sub-agent variant:

```ruby
class DelegateTool < RubyLLM::Tool
  description "Delegate to expert"
  param :query, desc: "The query"

  def execute(query:)
    response = RubyLLM.chat
      .with_instructions("You are an expert...")
      .ask(query) { |chunk| print chunk }
    halt response.content
  end
end
```

## Pitfalls

- Signature inference (v1.15+) treats all keyword arguments as strings and infers nothing about type or description. Add `param` declarations whenever type or semantics matter.
- The tool class name is auto-snake_cased into the LLM-visible name (e.g. `WeatherLookup` → `weather_lookup`); override with `def name` if you need a different identifier.
- Tool hallucination happens — the model sometimes names tools that don't exist. RubyLLM returns the available tool list so the model can self-correct, but expect and log it.
- `choice: :required` (or pinning a single tool) auto-resets to `nil` after execution to avoid infinite loops. The first call is forced; subsequent calls fall back to the model default.
- `calls` and `choice` are provider/model-dependent — not every provider honors every value.
- `:fibers` concurrency requires the `async` gem; without it you'll see a load error. `:threads` and `true` use stdlib threads.
- With concurrency on, RubyLLM adds tool results to the conversation as each finishes and *waits for all of them* before the next model turn — partial streams are not exposed to the router mid-turn.
- Raising inside `before_tool_call` halts the chat in an inconsistent state. Prefer clearer descriptions over hard call limits.
- Provider metadata via `with_params` is passed through verbatim only for keys the provider recognizes; silently ignored otherwise.
- MCP support lives in the separate `ruby_llm-mcp` gem — it's not built into `ruby_llm` core.
- `RUBYLLM_DEBUG=true` is the only built-in tool-call logger; structured logging requires your own callbacks.
- All `execute` arguments are untrusted model output. Never `eval`, `system`, or interpolate raw arguments into SQL/commands — validate, sanitize, and apply least-privilege.

## Verification

After registering at least one tool, exercise it through the `terminal` tool with debug enabled:

```
RUBYLLM_DEBUG=true ruby -e 'require "ruby_llm"; require_relative "lib/tools/weather"; puts RubyLLM.chat.with_tool(Weather).ask("What is the weather at 52.52, 13.40?").content'
```

You should see a `D, [timestamp] -- RubyLLM: Tool weather called with: {...}` line followed by a non-empty assistant message confirming dispatch, execution, and final response generation.
