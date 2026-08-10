# Yardoc Type-Safe Data Structures

## Contents
- Required gems
- Documentation types (dry-struct definitions)
- Type explanations

## Required Gems

```ruby
gem "dry-struct", "~> 1.6"
gem "dry-types", "~> 1.7"
gem "dry-monads", "~> 1.6"

# Logging
gem "journald-logger", "~> 2.1"
```

## Documentation Types

```ruby
# frozen_string_literal: true

require "dry-struct"
require "dry-types"

module Types
  include Dry.Types()
end

module RubyDev
  module Yardoc
    # Type annotation for YARD tags
    TagType = Types::String.enum(
      "param", "return", "example", "raise", "since", "see", "deprecated", "note"
    )

    # Complex type representation
    ComplexType = Types::String | Types::Hash | Types::Array

    # Parameter definition
    class Parameter < Dry::Struct
      attribute :name, Types::String
      attribute :type, Types::String
      attribute :description, Types::String
      attribute :optional, Types::Bool.default(false)
      attribute :default, Types::String.optional
    end

    # Return type definition
    class ReturnType < Dry::Struct
      attribute :type, Types::String
      attribute :description, Types::String
      attribute :nilable, Types::Bool.default(false)
    end

    # Example definition
    class Example < Dry::Struct
      attribute :description, Types::String
      attribute :code, Types::String
      attribute :output, Types::String.optional
    end

    # Exception definition
    class Exception < Dry::Struct
      attribute :type, Types::String
      attribute :description, Types::String
      attribute :conditions, Types::Array.of(Types::String).default([].freeze)
    end

    # Complete method documentation
    class MethodDocumentation < Dry::Struct
      attribute :name, Types::String
      attribute :description, Types::String
      attribute :parameters, Types::Array.of(Parameter).default([].freeze)
      attribute :return_types, Types::Array.of(ReturnType).default([].freeze)
      attribute :examples, Types::Array.of(Example).default([].freeze)
      attribute :exceptions, Types::Array.of(Exception).default([].freeze)
      attribute :since, Types::String.optional
      attribute :see, Types::Array.of(Types::String).default([].freeze)
      attribute :notes, Types::Array.of(Types::String).default([].freeze)
    end

    # Documentation generation result
    class GenerationResult < Dry::Struct
      attribute :file_path, Types::String
      attribute :methods_documented, Types::Integer
      attribute :documentation, Types::Array.of(MethodDocumentation).default([].freeze)
      attribute :warnings, Types::Array.of(Types::String).default([].freeze)
      attribute :success, Types::Bool
      attribute :error, Types::String.optional
    end

    # Individual documentation entry from YARD parsing
    class DocumentationEntry < Dry::Struct
      attribute :name, Types::String
      attribute :type, Types::String
      attribute :description, Types::String
      attribute :tags, Types::Array.of(Types::String).default([].freeze)
    end

    # YARD documentation parsing result
    class YardResult < Dry::Struct
      attribute :success, Types::Bool
      attribute :message, Types::String
      attribute :entries, Types::Array.of(DocumentationEntry).default([].freeze)
    end
  end
end
```

## Type Explanations

**YardResult**: Represents the result of YARD documentation parsing operations. The `success` field indicates whether the parsing was successful, `message` contains status or error information, and `entries` holds an array of parsed documentation entries.

**DocumentationEntry**: Represents an individual documentation entry extracted from YARD parsing. Contains the `name` of the documented item (method, class, etc.), its `type` (method, class, module, etc.), a `description` of its purpose, and `tags` for categorization and filtering.
