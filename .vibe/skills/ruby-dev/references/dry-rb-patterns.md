---
title: dry-rb Patterns - Type Safety & Validation Standards
version: 1.0.0
last_updated: 2026-05-25
maintained_by: Syncopated Context
standard_gems: [dry-struct, dry-types, dry-schema, dry-validation, dry-monads]
---

# dry-rb Patterns - Type Safety & Validation Standards

## Overview

**Standard Gems**: All ruby-dev skills MUST use dry-rb ecosystem for type safety and validation.

**Core Principles**:
1. **dry-struct** for typed value objects and entities
2. **dry-types** for custom type definitions with constraints
3. **dry-schema** for input validation (API, user input)
4. **dry-validation** for complex business rules
5. **dry-monads** for railway-oriented error handling

---

## dry-struct: Type-Safe Value Objects

### Basic Struct Definition

```ruby
# frozen_string_literal: true

require "dry-struct"

module Types
  include Dry.Types()
end

module MyApp
  class User < Dry::Struct
    attribute :id, Types::Integer
    attribute :email, Types::String
    attribute :name, Types::String.optional
    attribute :created_at, Types::Time
    attribute :active, Types::Bool.default(true)
  end
end

# Usage
user = MyApp::User.new(
  id: 1,
  email: "user@example.com",
  created_at: Time.now
)

user.email  # => "user@example.com"
user.active # => true (default)
user.name   # => nil (optional)
```

### Nested Structs

```ruby
module MyApp
  class Address < Dry::Struct
    attribute :street, Types::String
    attribute :city, Types::String
    attribute :zip, Types::String
  end
  
  class User < Dry::Struct
    attribute :id, Types::Integer
    attribute :email, Types::String
    attribute :address, Address
  end
end

# Usage
user = MyApp::User.new(
  id: 1,
  email: "user@example.com",
  address: {
    street: "123 Main St",
    city: "Portland",
    zip: "97201"
  }
)

user.address.city # => "Portland"
```

### Arrays and Hashes

```ruby
module MyApp
  class Clause < Dry::Struct
    attribute :id, Types::Integer
    attribute :text, Types::String
    attribute :pos_tags, Types::Array.of(Types::String)
    attribute :dependencies, Types::Hash.schema(
      head: Types::Integer,
      relation: Types::String
    )
  end
end

# Usage
clause = MyApp::Clause.new(
  id: 1,
  text: "The quick brown fox jumps.",
  pos_tags: ["DET", "ADJ", "ADJ", "NOUN", "VERB"],
  dependencies: { head: 4, relation: "nsubj" }
)
```

---

## dry-types: Custom Type Definitions

### Built-in Types

```ruby
module Types
  include Dry.Types()
  
  # Strict types (raise on coercion failure)
  StrictString = Types::Strict::String
  StrictInteger = Types::Strict::Integer
  StrictBool = Types::Strict::Bool
  
  # Coercible types (attempt coercion)
  CoercibleString = Types::Coercible::String
  CoercibleInteger = Types::Coercible::Integer
  
  # Optional types
  OptionalString = Types::String.optional
  OptionalInteger = Types::Integer.optional
  
  # Default values
  ActiveStatus = Types::Bool.default(true)
  DefaultPort = Types::Integer.default(8080)
end
```

### Custom Constrained Types

```ruby
module Types
  include Dry.Types()
  
  # String constraints
  Email = Types::String.constrained(
    format: URI::MailTo::EMAIL_REGEXP
  )
  
  NonEmptyString = Types::String.constrained(
    min_size: 1
  )
  
  # Integer constraints
  PositiveInt = Types::Integer.constrained(
    gt: 0
  )
  
  Port = Types::Integer.constrained(
    gteq: 1024,
    lteq: 65535
  )
  
  # Array constraints
  NonEmptyArray = Types::Array.constrained(
    min_size: 1
  )
  
  TagList = Types::Array.of(Types::String).constrained(
    max_size: 10
  )
end
```

### Enum Types

```ruby
module Types
  include Dry.Types()
  
  # Simple enum
  LogLevel = Types::String.enum("debug", "info", "warn", "error")
  
  # With integer values
  Status = Types::Integer.enum(
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  )
  
  # With symbol values
  Environment = Types::Symbol.enum(:development, :test, :production)
end

# Usage
class MyApp::Config < Dry::Struct
  attribute :log_level, Types::LogLevel
  attribute :status, Types::Status
  attribute :env, Types::Environment
end
```

---

## dry-schema: Input Validation

### Basic Schema

```ruby
# frozen_string_literal: true

require "dry-schema"

module MyApp
  SearchSchema = Dry::Schema.Params do
    required(:query).filled(:string)
    required(:limit).value(:integer, gteq?: 1, lteq?: 100)
    optional(:offset).value(:integer, gteq?: 0)
    optional(:filter).hash do
      optional(:tags).array(:string)
      optional(:date_from).value(:date)
      optional(:date_to).value(:date)
    end
  end
end

# Usage
result = MyApp::SearchSchema.call({
  query: "ruby programming",
  limit: 10,
  filter: { tags: ["tutorial", "beginner"] }
})

if result.success?
  params = result.to_h
  # Process valid params
else
  errors = result.errors.to_h
  # Handle validation errors
end
```

### Nested Schema

```ruby
module MyApp
  AddressSchema = Dry::Schema.Params do
    required(:street).filled(:string)
    required(:city).filled(:string)
    required(:zip).filled(:string, format?: /^\d{5}(-\d{4})?$/)
  end
  
  UserSchema = Dry::Schema.Params do
    required(:email).filled(:string, format?: URI::MailTo::EMAIL_REGEXP)
    required(:name).filled(:string)
    required(:age).value(:integer, gteq?: 18)
    required(:address).hash(AddressSchema)
  end
end
```

---

## dry-validation: Business Logic Validation

### Contract with Rules

```ruby
# frozen_string_literal: true

require "dry-validation"

module MyApp
  class UserContract < Dry::Validation::Contract
    params do
      required(:email).filled(:string)
      required(:password).filled(:string)
      required(:password_confirmation).filled(:string)
      required(:age).value(:integer)
    end
    
    rule(:email) do
      unless value.match?(URI::MailTo::EMAIL_REGEXP)
        key.failure("must be a valid email")
      end
    end
    
    rule(:password) do
      unless value.length >= 8
        key.failure("must be at least 8 characters")
      end
    end
    
    rule(:password, :password_confirmation) do
      unless values[:password] == values[:password_confirmation]
        key(:password_confirmation).failure("must match password")
      end
    end
    
    rule(:age) do
      if value < 18
        key.failure("must be 18 or older")
      end
    end
  end
end

# Usage
contract = MyApp::UserContract.new
result = contract.call({
  email: "user@example.com",
  password: "secret123",
  password_confirmation: "secret123",
  age: 25
})

if result.success?
  user_params = result.to_h
  # Create user
else
  errors = result.errors.to_h
  # => { password_confirmation: ["must match password"] }
end
```

---

## dry-monads: Railway-Oriented Programming

### Maybe Monad

```ruby
# frozen_string_literal: true

require "dry-monads"

module MyApp
  class UserService
    include Dry::Monads[:maybe]
    
    def find_user(id)
      user = User.find_by(id: id)
      user ? Some(user) : None()
    end
    
    def user_email(id)
      find_user(id)
        .fmap(&:email)
        .value_or("no-email@example.com")
    end
  end
end

# Usage
service = MyApp::UserService.new
email = service.user_email(123)  # => "user@example.com" or "no-email@example.com"
```

### Result Monad

```ruby
module MyApp
  class EmbeddingService
    include Dry::Monads[:result]
    
    def embed(text)
      return Failure(:empty_text) if text.nil? || text.empty?
      
      response = llm.embed(input: text)
      Success(response.embedding)
    rescue StandardError => e
      Failure([:api_error, e.message])
    end
    
    def batch_embed(texts)
      results = texts.map { |text| embed(text) }
      
      failures = results.select(&:failure?)
      return Failure([:batch_failed, failures.size]) if failures.any?
      
      Success(results.map(&:value!))
    end
  end
end

# Usage
service = MyApp::EmbeddingService.new

service.embed("Hello world").bind do |embedding|
  # Use embedding
  Success(embedding.size)
end.or do |error|
  # Handle error
  logger.error("embedding_failed", error: error)
  Failure(error)
end
```

### Do Notation

```ruby
module MyApp
  class RAGPipeline
    include Dry::Monads[:result, :do]
    
    def query(text)
      embedding = yield embed(text)
      results = yield search(embedding)
      context = yield build_context(results)
      response = yield generate(text, context)
      
      Success(response)
    end
    
    private
    
    def embed(text)
      # Returns Result
    end
    
    def search(embedding)
      # Returns Result
    end
    
    def build_context(results)
      # Returns Result
    end
    
    def generate(text, context)
      # Returns Result
    end
  end
end

# Usage
pipeline = MyApp::RAGPipeline.new
result = pipeline.query("What is Ruby?")

case result
in Success(response)
  puts response
in Failure([:empty_text])
  puts "Text cannot be empty"
in Failure([:api_error, message])
  puts "API error: #{message}"
end
```

---

## Integration Patterns

### Pattern 1: API Endpoint with Validation

```ruby
# frozen_string_literal: true

require "dry-validation"
require "dry-monads"

module MyApp
  class SearchEndpoint
    include Dry::Monads[:result]
    
    SearchSchema = Dry::Schema.Params do
      required(:query).filled(:string)
      required(:limit).value(:integer, gteq?: 1, lteq?: 100)
    end
    
    def call(params)
      validation = SearchSchema.call(params)
      return Failure([:invalid_params, validation.errors.to_h]) if validation.failure?
      
      search_params = validation.to_h
      results = perform_search(search_params)
      
      Success(results)
    end
  end
end
```

### Pattern 2: Domain Model with dry-struct

```ruby
module MyApp
  class Clause < Dry::Struct
    attribute :id, Types::Integer
    attribute :text, Types::String
    attribute :embedding, Types::Array.of(Types::Float)
    attribute :metadata, Types::Hash.schema(
      document_id: Types::Integer,
      position: Types::Integer,
      created_at: Types::Time
    )
    
    def similarity(other_embedding)
      cosine_similarity(embedding, other_embedding)
    end
  end
end
```

### Pattern 3: Service with Railway-Oriented Flow

```ruby
module MyApp
  class RAGService
    include Dry::Monads[:result, :do]
    
    def query(text)
      params = yield validate_params(text)
      embedding = yield generate_embedding(params[:text])
      results = yield search_similar(embedding)
      context = yield build_context(results)
      response = yield generate_response(params[:text], context)
      
      Success(response)
    rescue StandardError => e
      Failure([:unexpected_error, e.message])
    end
  end
end
```

---

## Common Pitfalls

### ❌ Pitfall 1: Not Using Types

```ruby
# Bad: No type safety
class User
  attr_accessor :id, :email, :name
end

user = User.new
user.email = 123  # Silently accepts wrong type
```

```ruby
# Good: Type-safe with dry-struct
class User < Dry::Struct
  attribute :id, Types::Integer
  attribute :email, Types::String
  attribute :name, Types::String
end

user = User.new(id: 1, email: 123, name: "John")
# => Dry::Struct::Error: [User.new] 123 (Integer) has invalid type for :email
```

### ❌ Pitfall 2: Using Hash Instead of Struct

```ruby
# Bad: Anonymous hash
def process_user(user_data)
  email = user_data[:email]  # No type checking, could be nil
  # ...
end
```

```ruby
# Good: Typed struct
def process_user(user)
  email = user.email  # Guaranteed to be String
  # ...
end
```

### ❌ Pitfall 3: Not Handling Validation Failures

```ruby
# Bad: Assuming success
result = UserContract.new.call(params)
user = create_user(result.to_h)  # Boom if validation failed
```

```ruby
# Good: Check result first
result = UserContract.new.call(params)
if result.success?
  user = create_user(result.to_h)
else
  return Failure([:validation_error, result.errors.to_h])
end
```

---

## References

- [dry-struct](https://dry-rb.org/gems/dry-struct/)
- [dry-types](https://dry-rb.org/gems/dry-types/)
- [dry-schema](https://dry-rb.org/gems/dry-schema/)
- [dry-validation](https://dry-rb.org/gems/dry-validation/)
- [dry-monads](https://dry-rb.org/gems/dry-monads/)

---

**Last Updated**: 2026-05-25  
**Next Review**: After implementing in all 5 core skills  
**Status**: Active Standard
