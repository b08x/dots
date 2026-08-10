---
title: Environment Variable Management - dotenv Standard
version: 1.0.0
last_updated: 2026-05-25
maintained_by: Syncopated Context
standard_gem: dotenv
---

# Environment Variable Management - dotenv Standard

## Overview

**Standard Gem**: All ruby-dev skills MUST use `dotenv` (`/bkeepers/dotenv`) for environment variable management.

**Rule**: Never hardcode secrets, API keys, or environment-specific configuration in code.

---

## Setup

### 1. Add to Gemfile

```ruby
# Gemfile
gem "dotenv", groups: [:development, :test]
```

**Important**: Only load in development/test, NOT production. Production uses actual environment variables.

### 2. Create .env File

```bash
# .env (NEVER COMMIT THIS FILE)
OPENAI_API_KEY=sk-proj-...
ANTHROPIC_API_KEY=sk-ant-...
DATABASE_URL=postgresql://localhost/myapp_dev
REDIS_URL=redis://localhost:6379/0
```

### 3. Add to .gitignore

```bash
# .gitignore
.env
.env.local
.env.*.local
```

### 4. Create .env.example Template

```bash
# .env.example (COMMIT THIS FILE)
# OpenAI API key - get from https://platform.openai.com/api-keys
OPENAI_API_KEY=

# Anthropic API key - get from https://console.anthropic.com/
ANTHROPIC_API_KEY=

# Database connection string
DATABASE_URL=postgresql://localhost/myapp_dev

# Redis connection
REDIS_URL=redis://localhost:6379/0
```

### 5. Load in Application

```ruby
# config/boot.rb or lib/my_app.rb
require "dotenv/load"

# Or with explicit path
require "dotenv"
Dotenv.load(".env", ".env.local")
```

---

## Standard Patterns

### Pattern 1: Required Environment Variables

```ruby
# frozen_string_literal: true

require "dotenv/load"

module MyApp
  class Config
    REQUIRED_VARS = %w[
      OPENAI_API_KEY
      DATABASE_URL
    ].freeze
    
    def self.validate!
      missing = REQUIRED_VARS.reject { |var| ENV.key?(var) }
      
      if missing.any?
        raise ConfigurationError, "Missing required environment variables: #{missing.join(', ')}"
      end
    end
    
    def self.openai_api_key
      ENV.fetch("OPENAI_API_KEY")
    end
    
    def self.database_url
      ENV.fetch("DATABASE_URL")
    end
  end
  
  class ConfigurationError < StandardError; end
end

# At app startup
MyApp::Config.validate!
```

### Pattern 2: Optional with Defaults

```ruby
module MyApp
  class Config
    def self.log_level
      ENV.fetch("LOG_LEVEL", "info")
    end
    
    def self.port
      ENV.fetch("PORT", "8080").to_i
    end
    
    def self.workers
      ENV.fetch("WORKERS", "4").to_i
    end
    
    def self.timeout
      ENV.fetch("TIMEOUT", "30").to_i
    end
  end
end
```

### Pattern 3: Type Coercion with dry-types

```ruby
# frozen_string_literal: true

require "dotenv/load"
require "dry-types"

module Types
  include Dry.Types()
end

module MyApp
  class Config
    extend Dry::Configurable
    
    setting :openai_api_key, constructor: Types::String
    setting :database_url, constructor: Types::String
    setting :port, default: 8080, constructor: Types::Coercible::Integer
    setting :workers, default: 4, constructor: Types::Coercible::Integer
    setting :debug, default: false, constructor: Types::Params::Bool
    
    def self.load!
      config.openai_api_key = ENV.fetch("OPENAI_API_KEY")
      config.database_url = ENV.fetch("DATABASE_URL")
      config.port = ENV.fetch("PORT", "8080")
      config.workers = ENV.fetch("WORKERS", "4")
      config.debug = ENV.fetch("DEBUG", "false")
    end
  end
end

# At app startup
MyApp::Config.load!
```

### Pattern 4: Environment-Specific Files

```ruby
# frozen_string_literal: true

require "dotenv"

module MyApp
  class Env
    ENVIRONMENT = ENV.fetch("RACK_ENV", "development")
    
    def self.load!
      # Load in order (later files override earlier ones)
      Dotenv.load(
        ".env.#{ENVIRONMENT}.local",  # Environment-specific overrides
        ".env.local",                  # Local overrides (not committed)
        ".env.#{ENVIRONMENT}",         # Environment defaults (committed)
        ".env"                         # Base defaults (committed)
      )
    end
    
    def self.development?
      ENVIRONMENT == "development"
    end
    
    def self.test?
      ENVIRONMENT == "test"
    end
    
    def self.production?
      ENVIRONMENT == "production"
    end
  end
end
```

---

## Production Deployment

### Systemd Service

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My App

[Service]
Type=simple
User=myapp
WorkingDirectory=/opt/myapp
Environment="OPENAI_API_KEY=sk-proj-..."
Environment="DATABASE_URL=postgresql://..."
Environment="RACK_ENV=production"
ExecStart=/usr/bin/bundle exec ruby app.rb

[Install]
WantedBy=multi-user.target
```

### Docker Container

```dockerfile
# Dockerfile
FROM ruby:3.3

# Do NOT copy .env into container
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

COPY . .

# Environment variables passed at runtime
CMD ["bundle", "exec", "ruby", "app.rb"]
```

```bash
# docker-compose.yml
services:
  app:
    build: .
    environment:
      OPENAI_API_KEY: ${OPENAI_API_KEY}
      DATABASE_URL: postgresql://db/myapp_production
    env_file:
      - .env.production  # Only for production-specific vars
```

### Kubernetes Secret

```yaml
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
type: Opaque
stringData:
  OPENAI_API_KEY: sk-proj-...
  DATABASE_URL: postgresql://...
---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        image: myapp:latest
        envFrom:
        - secretRef:
            name: myapp-secrets
```

---

## Security Best Practices

### ✅ Do This

```ruby
# Good: Fetch from ENV
api_key = ENV.fetch("OPENAI_API_KEY")

# Good: Fail fast if missing
api_key = ENV.fetch("OPENAI_API_KEY") do
  raise "OPENAI_API_KEY not set"
end

# Good: Optional with safe default
log_level = ENV.fetch("LOG_LEVEL", "info")
```

### ❌ Don't Do This

```ruby
# Bad: Hardcoded secret
api_key = "sk-proj-abc123..."

# Bad: Silent nil fallback
api_key = ENV["OPENAI_API_KEY"]  # Returns nil if missing

# Bad: Inline default (hard to change)
api_key = ENV.fetch("OPENAI_API_KEY", "sk-proj-default")
```

---

## Validation Checklist

- [ ] `.env` file created and populated
- [ ] `.env` added to `.gitignore`
- [ ] `.env.example` committed with template
- [ ] `dotenv` gem in Gemfile (development/test groups only)
- [ ] `require "dotenv/load"` at app entry point
- [ ] All required vars validated at startup
- [ ] No hardcoded secrets in code
- [ ] Production uses actual environment variables (not .env)
- [ ] Environment-specific files use correct precedence

---

## Common Environment Variables

### AI/LLM Services

```bash
OPENAI_API_KEY=sk-proj-...
OPENAI_ORG_ID=org-...
ANTHROPIC_API_KEY=sk-ant-...
GROQ_API_KEY=gsk_...
OLLAMA_HOST=http://localhost:11434
```

### Databases

```bash
DATABASE_URL=postgresql://user:pass@localhost/myapp_dev
REDIS_URL=redis://localhost:6379/0
NEO4J_URL=neo4j://localhost:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=password
```

### Application Config

```bash
RACK_ENV=development
LOG_LEVEL=info
PORT=8080
WORKERS=4
TIMEOUT=30
DEBUG=false
```

### External Services

```bash
CONTEXT7_API_KEY=...
GITHUB_TOKEN=ghp_...
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
```

---

## Integration with Skills

### In SKILL.md Frontmatter

```yaml
required_environment_variables:
  - name: OPENAI_API_KEY
    prompt: "Enter your OpenAI API key"
    help: "Get one at https://platform.openai.com/api-keys"
    required_for: "LLM API access"
```

### In Code Examples

```ruby
# Always show ENV.fetch pattern
require "dotenv/load"

api_key = ENV.fetch("OPENAI_API_KEY")
llm = RubyLLM::Client.new(api_key: api_key)
```

---

## References

- [Dotenv Gem](https://github.com/bkeepers/dotenv)
- [Twelve-Factor App Config](https://12factor.net/config)
- [Ruby ENV Documentation](https://ruby-doc.org/core/ENV.html)

---

**Last Updated**: 2026-05-25  
**Next Review**: After implementing in all 5 core skills  
**Status**: Active Standard
