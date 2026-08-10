# YARD Documentation Patterns and Conventions

## Contents
- [Core YARD Tag Reference](#core-yard-tag-reference)
- [Type System Conventions](#type-system-conventions)
- [Documentation Quality Standards](#documentation-quality-standards)
- [Common Anti-Patterns to Avoid](#common-anti-patterns-to-avoid)
- [Project-Specific Customization](#project-specific-customization)
- [YARD Configuration Integration](#yard-configuration-integration)

## Core YARD Tag Reference

### @param Tag Patterns

**Basic Parameter Documentation**
```ruby
# @param [String] name The user's full name
# @param [Integer] age Age in years (must be positive)
# @param [Hash] options Configuration options
```

**Complex Type Specifications**
```ruby
# @param [String, Symbol] identifier Unique identifier (string or symbol)
# @param [Array<String>] tags List of tag names
# @param [Hash{Symbol => Object}] config Configuration hash with symbol keys
# @param [Hash{String => Array<Integer>}] data Nested structure mapping
# @param [#to_s] value Any object that responds to to_s
# @param [#each] collection Enumerable collection
```

**Optional and Default Parameters**
```ruby
# @param [String, nil] description Optional description (default: nil)
# @param [Integer] timeout Timeout in seconds (default: 30)
# @param [Boolean] force Whether to force the operation (default: false)
```

**Block Parameters**
```ruby
# @param [Proc, nil] block Optional block for custom processing
# @yield [String] filename Yields each filename to the block
# @yieldparam [Hash] result Processing result hash
# @yieldreturn [Boolean] true to continue, false to stop
```

### @return Tag Patterns

**Simple Return Types**
```ruby
# @return [String] Formatted name string
# @return [Integer] Number of items processed
# @return [Boolean] true if successful, false otherwise
```

**Conditional Returns**
```ruby
# @return [User, nil] User object if found, nil otherwise
# @return [String] Success message on completion
# @return [Array<Hash>] Array of result hashes, empty if no results
```

**Complex Return Structures**
```ruby
# @return [Hash{Symbol => Object}] Status hash with :success, :message, :data keys
# @return [Enumerator<String>] Enumerator yielding filenames if no block given
# @return [Array<Hash{String => Integer}>] Array of mapping hashes
```

### @raise Tag Patterns

**Exception Documentation**
```ruby
# @raise [ArgumentError] if name is empty or nil
# @raise [TypeError] if options is not a Hash
# @raise [StandardError] if the operation fails due to external factors
# @raise [Errno::ENOENT] if the specified file does not exist
```

**Multiple Exception Scenarios**
```ruby
# @raise [ArgumentError] if required parameters are missing
# @raise [SecurityError] if access is denied
# @raise [TimeoutError] if operation exceeds timeout limit
```

### @example Tag Patterns

**Basic Usage Examples**
```ruby
# @example Basic usage
#   result = process_data("input.txt")
#   result[:status] # => "success"
#
# @example With custom options
#   process_data("data.csv", format: :csv, headers: true)
#   # => {status: "success", rows: 150, headers: ["name", "email"]}
```

**Block Usage Examples**
```ruby
# @example Processing with a block
#   parse_file("data.txt") do |line|
#     puts "Processing: #{line}"
#     line.upcase
#   end
#   # => ["LINE 1", "LINE 2", "LINE 3"]
#
# @example Error handling in blocks
#   safe_process do |item|
#     risky_operation(item)
#   rescue ProcessingError => e
#     log_error(e)
#     nil
#   end
```

**Advanced Scenario Examples with dry-struct**
```ruby
# @example Chaining operations with dry-struct
#   user = MyApp::User.new(
#     id: 1,
#     email: "user@example.com",
#     name: "John Doe",
#     active: true
#   )
#   
#   DataProcessor.new
#     .load_from("input.csv")
#     .filter { |row| row[:active] }
#     .transform(:email, &:downcase)
#     .save_to("output.csv")
#   # => 247 # number of processed records
```

## Type System Conventions

### Ruby Core Types
```ruby
String      # Basic string
Symbol      # Symbol literal
Integer     # Numeric integer
Float       # Floating point number
Numeric     # Integer or Float
Boolean     # true or false (YARD convention)
Object      # Any object
NilClass    # Explicitly nil (rarely needed, prefer Type, nil)
```

### Container Types
```ruby
Array               # Array of mixed types
Array<String>       # Array of strings only
Hash                # Hash with mixed key/value types
Hash{String => Object}  # Hash with string keys, any values
Hash{Symbol => String}  # Hash with symbol keys, string values
Range               # Range object
Set<Symbol>         # Set containing symbols
```

### Duck Typing Conventions
```ruby
#to_s        # Object that responds to to_s
#each        # Object that responds to each (Enumerable-like)
#call        # Object that responds to call (Proc-like)
#[]          # Object that supports bracket access
#push        # Object that supports push method
IO          # IO object or IO-like (StringIO, File, etc.)
```

### Nilable Type Patterns
```ruby
String, nil         # String or nil
Array<String>, nil  # Array of strings or nil
Hash, nil          # Hash or nil (prefer specific hash types)
```

### Union Types
```ruby
String, Symbol      # String or Symbol
Integer, String     # Integer or String (for flexible inputs)
File, IO           # File object or any IO
```

### dry-struct Type Patterns (v2 Standard)

**Basic dry-struct Classes**
```ruby
# @param [MyApp::User] user User entity with id, email, name attributes
# @param [MyApp::Config] config Configuration struct with host, port, timeout
# @return [MyApp::Result] Result struct with status, data, errors
```

**Nested dry-struct Types**
```ruby
# @param [MyApp::Order] order Order with nested MyApp::Address and MyApp::Item structs
# @return [Array<MyApp::Clause>] Array of Clause structs with id, text, metadata
```

**dry-types Constrained Types**
```ruby
# @param [Types::Email] email Validated email string
# @param [Types::PositiveInt] count Positive integer value
# @param [Types::Port] port Port number (1024-65535)
```

## Documentation Quality Standards

### Method Description Guidelines

**Use Active Voice**
```ruby
# Good: Processes the input file and returns formatted results
# Bad: Input file is processed and formatted results are returned
```

**Be Specific About Behavior**
```ruby
# Good: Validates email format and normalizes to lowercase
# Bad: Handles email processing
```

**Include Important Constraints**
```ruby
# Good: Calculates compound interest using daily compounding
# Bad: Calculates interest
```

### Parameter Description Best Practices

**Describe Purpose and Constraints**
```ruby
# Good: @param [String] email Valid email address (will be normalized)
# Bad: @param [String] email The email
```

**Document Expected Format**
```ruby
# @param [String] date_string Date in YYYY-MM-DD format
# @param [Hash] config Configuration with required :host and :port keys
# @param [Array<String>] paths Absolute file paths (must exist)
```

**Clarify Optional Behavior**
```ruby
# @param [String, nil] prefix Optional prefix for output (default: timestamp)
# @param [Boolean] validate Whether to validate input (default: true)
```

### Return Value Documentation Standards

**Describe Structure and Content**
```ruby
# Good: @return [Hash{Symbol => Object}] Result hash with :data, :errors, :meta keys
# Bad: @return [Hash] The results
```

**Document Conditional Returns**
```ruby
# @return [Array<MyApp::User>] Matching users (empty array if none found)
# @return [String, nil] Error message if validation fails, nil if successful
```

**Use dry-struct Return Types**
```ruby
# Good: @return [MyApp::SearchResult] Search result with items, total, offset
# Good: @return [Dry::Monads::Result] Success with data or Failure with error
# Bad: @return [Hash] The search results
```

### Example Quality Criteria

**Use Realistic Data**
```ruby
# Good:
# @example
#   user = MyApp::User.new(id: 1, email: "john@example.com", name: "John Smith")
#   user.full_name # => "John Smith"
#
# Bad:
# @example
#   user = User.find_by_email("email")
#   user.full_name # => "name"
```

**Show Expected Output**
```ruby
# Good:
# @example Parsing CSV data
#   clauses = parse_csv("id,text\n1,Hello\n2,World")
#   # => [
#        MyApp::Clause.new(id: 1, text: "Hello"),
#        MyApp::Clause.new(id: 2, text: "World")
#      ]
```

**Include Error Cases When Relevant**
```ruby
# @example Error handling with dry-monads
#   result = MyApp::UserService.new.find_user(999)
#   case result
#   in Dry::Monads::Success(user)
#     puts "Found: #{user.email}"
#   in Dry::Monads::Failure(:not_found)
#     puts "User not found"
#   end
```

**Show dry-struct Usage**
```ruby
# @example Creating and using dry-struct entities
#   address = MyApp::Address.new(
#     street: "123 Main St",
#     city: "Portland",
#     zip: "97201"
#   )
#   
#   user = MyApp::User.new(
#     id: 1,
#     email: "user@example.com",
#     address: address
#   )
#   
#   user.address.city # => "Portland"
```

## Common Anti-Patterns to Avoid

### Vague Descriptions
```ruby
# Bad: Processes data
# Good: Converts CSV data to dry-struct objects with symbol keys
```

### Missing Type Information
```ruby
# Bad: @param data The data to process
# Good: @param [Array<MyApp::Clause>] clauses Array of Clause structs
```

### Trivial Examples
```ruby
# Bad:
# @example
#   add(1, 2) # => 3
#
# Good:
# @example Calculate total with tax using dry-types
#   calculator = MyApp::TaxCalculator.new(rate: Types::Decimal[0.08])
#   calculator.add_tax(Types::Decimal[100.00]) # => Types::Decimal[108.00]
```

### Over-Documentation
```ruby
# Bad: Document every getter/setter with obvious behavior
# Good: Document complex methods, leave simple dry-struct accessors undocumented
```

### Inconsistent Terminology
```ruby
# Bad: Mix "user", "person", "account" for the same concept
# Good: Use consistent terminology throughout documentation (prefer dry-struct class names)
```

### Avoid Plain Hashes When Structs Exist
```ruby
# Bad: @return [Hash] User data with id, email, name
# Good: @return [MyApp::User] User entity with id, email, name attributes
```

## Project-Specific Customization

### Detecting Documentation Patterns

**Scan for existing patterns:**
- Consistent use of @since tags indicates version tracking
- Custom tags suggest extended documentation requirements
- Specific type annotation styles should be maintained
- Example verbosity levels should match project standards

**Common project variations:**
- Some projects prefer `Boolean` vs `true, false` for boolean types
- Version numbering schemes for @since tags
- Custom tags for API stability (@api private, @api public)
- Integration with external documentation systems

### Integration Guidelines

**Preserve existing structure:**
- Maintain spacing and indentation patterns
- Keep existing custom tags and annotations
- Respect established parameter ordering in documentation
- Follow existing example formatting conventions

**Handle special cases:**
- Metaprogrammed methods may need manual annotation
- DSL methods often require usage context examples
- Callback methods need lifecycle documentation
- Private methods may follow different documentation standards

**v2-Specific Guidelines:**
- Use dry-struct class names in type annotations
- Reference dry-types for constrained types
- Show dry-monads usage in examples
- Prefer structured return types over plain hashes

## YARD Configuration Integration

### Common .yardopts Patterns
```
--readme README.md
--files CHANGELOG.md,LICENSE
--protected
--private
--exclude spec/
--markup markdown
--output-dir doc/
```

### Custom Tag Support
```ruby
# Common custom tags found in Ruby projects:
# @api private    # Internal API not for public use
# @api stable     # Stable public API
# @deprecated     # Marked for removal
# @experimental   # New feature, may change
# @todo          # Future enhancement needed

# v2-specific tags:
# @uses dry-struct # Indicates method uses dry-struct for type safety
# @uses dry-types  # Indicates method uses dry-types for validation
# @uses dry-monads # Indicates method returns dry-monads Result
```

### Markup and Linking
```ruby
# Cross-references
# @see MyApp::User#full_name
# @see MyApp::Config
# @see http://example.com/docs

# Inline code formatting
# Use +code+ for inline code references
# Use {MyApp::User} for class references
# Use {#method_name} for method references in same class

# dry-struct specific references
# Use {MyApp::User} for dry-struct class references
# Use {Types::Email} for dry-types references
```

### v2 Documentation Standards Summary

**Always prefer:**
1. dry-struct class names over generic Hash types
2. dry-types constrained types over primitive types
3. dry-monads Result over custom error handling
4. Structured examples showing real usage patterns
5. Consistent terminology using v2 class names

**Type annotation priority:**
1. `[MyApp::ClassName]` - Specific dry-struct class
2. `[Types::CustomType]` - dry-types constrained type
3. `[Dry::Monads::Result]` - Monadic result type
4. `[Hash{Symbol => Object}]` - Generic hash (fallback)
5. `[Object]` - Any object (last resort)
