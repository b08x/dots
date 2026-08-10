# Example: YARD Tag Generation for dry-struct Classes

A complete, runnable example demonstrating how to generate YARD documentation (including custom tags) for a dry-struct class. The example includes the dry-struct definition, YARD tag annotations, and the code to trigger documentation generation.

```ruby
# frozen_string_literal: true

require "dry-struct"
require "dry-types"
require "yard"

# Define custom YARD tags for domain-specific documentation
class CustomYARDTags < YARD::Tags::Library
  def self.register!
    # Register custom tags for domain-specific documentation
    register_tag!(:domain, :domain, :"The business domain this struct belongs to")
    register_tag!(:persistence, :persistence, :"How this struct is persisted")
    register_tag!(:validation, :validation, :"Validation rules applied to this struct")
    register_tag!(:serialization, :serialization, :"How this struct should be serialized")
  end
end

# Register custom tags
CustomYARDTags.register!

module Types
  include Dry.Types()
end

module MyApp
  # Represents a user in the MyApp system with type-safe attributes.
  #
  # @!attribute [r] id
  #   @return [Integer] The unique identifier for the user
  #   @domain [UserManagement] This attribute belongs to the user management domain
  # @!attribute [r] name
  #   @return [String] The user's full name
  #   @validation [required, min_length: 2, max_length: 100] Name must be present and reasonable length
  # @!attribute [r] email
  #   @return [String] The user's email address
  #   @validation [required, format: email] Must be a valid email format
  #   @domain [UserManagement] This attribute belongs to the user management domain
  # @!attribute [r] created_at
  #   @return [Time, nil] When the user was created
  #   @persistence [auto_timestamp] Automatically set on creation
  # @!attribute [r] updated_at
  #   @return [Time, nil] When the user was last updated
  #   @persistence [auto_timestamp] Automatically updated on changes
  # @!attribute [r] active
  #   @return [Boolean] Whether the user account is active (default: true)
  #   @domain [AccountStatus] This attribute belongs to the account status domain
  # @!attribute [r] metadata
  #   @return [Hash{Symbol => String}, nil] Additional user metadata
  #   @serialization [json] Should be serialized as JSON when persisted
  #
  # @example Creating a new user
  #   user = MyApp::User.new(id: 1, name: "Alice", email: "alice@example.com")
  #   user.id # => 1
  #   user.name # => "Alice"
  #   user.active # => true
  #
  # @example Creating a user with optional fields
  #   user = MyApp::User.new(
  #     id: 2,
  #     name: "Bob",
  #     email: "bob@example.com",
  #     created_at: Time.now,
  #     metadata: { role: "admin", department: "Engineering" }
  #   )
  #   user.created_at # => 2024-01-15 10:30:00 +0000
  #   user.metadata # => { role: "admin", department: "Engineering" }
  #
  # @example Serializing a user to hash
  #   user.to_h # => { id: 1, name: "Alice", email: "alice@example.com", ... }
  #
  # @note This struct uses dry-struct for type safety and immutability by default.
  # @since 1.0.0
  class User < Dry::Struct
    attribute :id, Types::Integer
    attribute :name, Types::String
    attribute :email, Types::String
    attribute :created_at, Types::Time.optional
    attribute :updated_at, Types::Time.optional
    attribute :active, Types::Bool.default(true)
    attribute :metadata, Types::Hash.map(Types::Symbol, Types::String).optional
  end
end

# Code to trigger YARD documentation generation
module MyApp
  module Documentation
    class Generator
      # Generate YARD documentation for a dry-struct class
      #
      # @param klass [Class] The dry-struct class to document
      # @return [String] The generated YARD documentation
      # @raise [ArgumentError] If the class is not a dry-struct
      # @example Generate documentation for User class
      #   generator = MyApp::Documentation::Generator.new
      #   docs = generator.generate(MyApp::User)
      #   puts docs
      def generate(klass)
        validate_dry_struct!(klass)

        doc_string = build_class_documentation(klass)
        doc_string + build_attribute_documentation(klass)
      end

      private

      # Validates that the class is a dry-struct
      #
      # @param klass [Class] The class to validate
      # @return [void]
      # @raise [ArgumentError] If the class is not a dry-struct
      def validate_dry_struct!(klass)
        unless klass.ancestors.include?(Dry::Struct)
          raise ArgumentError, "#{klass} is not a dry-struct class"
        end
      end

      # Builds the class-level YARD documentation
      #
      # @param klass [Class] The dry-struct class
      # @return [String] The class documentation string
      def build_class_documentation(klass)
        <<~DOCUMENTATION
          # #{klass.name.split('::').last} represents a #{extract_domain(klass)} entity.
          #
        DOCUMENTATION
      end

      # Builds attribute documentation for a dry-struct class
      #
      # @param klass [Class] The dry-struct class
      # @return [String] The attribute documentation string
      def build_attribute_documentation(klass)
        attributes = extract_attributes(klass)

        attributes.map do |attr_name, attr_type|
          build_attribute_doc(attr_name, attr_type)
        end.join("\n")
      end

      # Extracts attributes from a dry-struct class
      #
      # @param klass [Class] The dry-struct class
      # @return [Hash{Symbol => String}] Hash of attribute names to types
      def extract_attributes(klass)
        klass.schema.key_map.to_h.transform_values do |meta|
          extract_type_string(meta)
        end
      end

      # Extracts a type string from dry-struct metadata
      #
      # @param meta [Dry::Struct::Meta] The attribute metadata
      # @return [String] The type string
      def extract_type_string(meta)
        type = meta[:type]

        case type
        when Dry::Types::Array
          member_type = type.member
          "Array<#{extract_simple_type(member_type)}>"
        when Dry::Types::Hash
          key_type = type.key_type || "Symbol"
          value_type = type.value_type || "String"
          "Hash{#{key_type} => #{value_type}}"
        else
          extract_simple_type(type)
        end
      end

      # Extracts a simple type name from a dry-type
      #
      # @param type [Dry::Types::Type] The dry-type
      # @return [String] The simple type name
      def extract_simple_type(type)
        case type
        when Dry::Types::Integer then "Integer"
        when Dry::Types::String then "String"
        when Dry::Types::Bool then "Boolean"
        when Dry::Types::Time then "Time"
        when Dry::Types::Symbol then "Symbol"
        else type.to_s.split('::').last
        end
      end

      # Builds documentation for a single attribute
      #
      # @param attr_name [Symbol] The attribute name
      # @param attr_type [String] The attribute type
      # @return [String] The attribute documentation
      def build_attribute_doc(attr_name, attr_type)
        <<~ATTRIBUTE
          # @!attribute [r] #{attr_name}
          #   @return [#{attr_type}] Description of #{attr_name}
        ATTRIBUTE
      end

      # Extracts the domain from class name or metadata
      #
      # @param klass [Class] The class to analyze
      # @return [String] The extracted domain
      def extract_domain(klass)
        klass.name.split('::')[0..-2].join('::') || "Application"
      end
    end
  end
end

# Usage: Generate and display documentation
if __FILE__ == $PROGRAM_NAME
  require "stringio"

  # Create a documentation generator
  generator = MyApp::Documentation::Generator.new

  # Generate documentation for the User class
  user_docs = generator.generate(MyApp::User)

  puts "Generated YARD Documentation for MyApp::User:"
  puts "=" * 50
  puts user_docs

  # You can also use YARD's built-in documentation generation
  puts "\n" + "=" * 50
  puts "Using YARD's built-in generation:"
  puts "=" * 50

  # Configure YARD to use our custom tags
  YARD::Tags::Library.register_custom_tags!

  # Generate documentation using YARD
  YARD::Rake::YardocTask.new do |t|
    t.files = [__FILE__]
    t.options = ['--no-progress']
  end
end
```
