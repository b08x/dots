# Yardoc Context7 Integration

## Contents
- YARD gem compatibility verification workflow
- Resolving the YARD library ID
- Verifying method signatures
- Batch verification for multiple gems
- Query patterns table
- Fallback strategy

## YARD Gem Compatibility Verification

Use Context7 to verify YARD gem compatibility and versioning before generating documentation. This ensures type annotations and API references are accurate and up-to-date.

**Verification Workflow:**

1. **Resolve YARD gem library ID** using Context7's library resolution
2. **Query YARD documentation** for specific API methods and types
3. **Validate gem version compatibility** against project requirements
4. **Cache verified signatures** for offline use with fallback warnings

**Example: Resolving YARD Library ID:**

```ruby
# Use Context7 MCP tools to resolve YARD gem library ID
# Library ID format: /yard/yard or /yard/yard/version

# Query Context7 for YARD gem documentation
library_id = "/yard/yard"  # or "/yard/yard/v0.9.37" for specific version
query = "How to use @param tag with type annotations in YARD"

# The Context7 response provides:
# - Verified method signatures
# - Type annotation patterns
# - Version-specific API changes
# - Compatibility notes
```

**Example: Verifying Method Signatures via Context7:**

```ruby
# When documenting a method that uses YARD gem APIs
# First, verify the gem context via Context7

def verify_yard_api_compatibility(method_name, gem_version = nil)
  library_id = gem_version ? "/yard/yard/#{gem_version}" : "/yard/yard"

  # Query Context7 for the specific method
  query = "#{method_name} method signature, parameters, and return types"

  # Process Context7 response
  context7_result = mcp_context7_query_docs(
    libraryId: library_id,
    query: query
  )

  if context7_result[:verified]
    # Use verified signature for documentation
    verified_signature = context7_result[:signature]
    type_annotations = context7_result[:types]

    Success({
      signature: verified_signature,
      types: type_annotations,
      source: "context7_verified",
      version: gem_version || "latest"
    })
  else
    # Fallback to cached or conservative types
    Failure[:context7_unavailable,
            "YARD API verification failed: #{context7_result[:error]}"]
  end
end
```

**Example: Batch Verification for Multiple Gems:**

```ruby
# Verify multiple gem dependencies for a Ruby file
def verify_gem_contexts(file_path)
  # Parse file for gem dependencies
  gem_dependencies = extract_gem_dependencies(file_path)

  verification_results = gem_dependencies.map do |gem_name, version_constraint|
    verify_via_context7(gem_name, version_constraint)
  end

  # Collect results
  all_verified = verification_results.all?(&:success?)
  unverified_gems = verification_results.select(&:failure?).map(&:failure)

  if all_verified
    Success(verification_results.map(&:value!))
  else
    # Partial verification - proceed with warnings
    Success({
      verified: verification_results.select(&:success?).map(&:value!),
      unverified: unverified_gems,
      warnings: ["Some gem contexts unverified - using cached signatures"]
    })
  end
end

# Helper to extract gem dependencies from Ruby file
def extract_gem_dependencies(file_path)
  content = File.read(file_path)

  # Find require statements and Gemfile references
  dependencies = {}

  # Match require 'gem_name' patterns
  content.scan(/require\s+["']([^"']+)["']/).each do |gem_name|
    clean_name = gem_name.first.split('/').first
    dependencies[clean_name] ||= "any"
  end

  # Match Gemfile gem entries
  if File.exist?("Gemfile")
    gemfile_content = File.read("Gemfile")
    gemfile_content.scan(/gem\s+["']([^"']+)["']\s*,\s*["']([^"']*)["']/).each do |name, version|
      dependencies[name] = version.empty? ? "any" : version
    end
  end

  dependencies
end
```

## Context7 Query Patterns for YARD

| Query Type | Example Query | Use Case |
|------------|---------------|----------|
| Method signature | "YARD::CodeObjects::MethodObject#docstring method parameters" | Verify @param tag generation |
| Type annotation | "How to document Hash{Symbol => Array<String>} in YARD" | Complex type formatting |
| Tag syntax | "YARD @raise tag format and examples" | Exception documentation |
| Version compatibility | "YARD 0.9.37 vs 0.9.38 @example tag changes" | Version-specific patterns |
| Gem integration | "Using YARD with dry-struct classes" | Framework-specific docs |

## Fallback Strategy

When Context7 is unavailable or returns incomplete results:
1. Use cached signatures from previous sessions (with `# type annotation based on stale cache — verify before publishing`)
2. Apply conservative type inference (String, Object, etc.)
3. Document the uncertainty in the generated YARD comments
4. Flag for manual review in the quality assurance phase
