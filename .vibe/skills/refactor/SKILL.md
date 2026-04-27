---
name: refactor
description: "Convention-targeted Ruby refactoring sub-skill."
license: MIT
compatibility: Python 3.12+
user-invocable: true
allowed-tools:
  - read_file
  - write_file
  - grep
  - ask_user_question
  - bash
---

# Rubysmithing — Refactor

Convention-targeted Ruby refactoring sub-skill for improving existing code quality and standards compliance.

## Inputs Accepted

1. **Pasted code snippets** — Direct code in user message
2. **File paths** — Single files or directories to refactor
3. **Upload files** — Files attached to conversation
4. **Filesystem paths** — Glob patterns for multiple files

## Step 1: Detect Convention Target

**Auto-detection priority (same as plan skill):**
1. `.rubocop.yml` present → RuboCop conventions
2. `Gemfile` contains `standardrb` → StandardRB conventions
3. `.rubysmith/` config → Rubysmith conventions  
4. Default → Community Ruby conventions

**Convention target affects:** Naming patterns, formatting rules, architectural choices, gem preferences

## Step 2: Detect Mode

### Lite Mode
**Triggers:**
- Scripts under ~50 lines
- Single-purpose utilities
- No complex architectural patterns present

**Characteristics:**
- Focus on basic Ruby conventions
- Avoid over-engineering simple scripts
- Minimal dependency injection
- Direct, straightforward improvements

### Standard Mode
**Default for:**
- Class/module hierarchies
- Multi-file refactoring
- Complex architectural patterns
- Enterprise/production code

**Full refactoring including:**
- Zeitwerk compliance enforcement
- Circuit breaker pattern application
- Async/await introduction where beneficial
- Dependency injection improvements
- Error handling enhancement

## Step 3: Pre-Refactor Audit

**Use analyse skill for systematic assessment:**
1. **Convention violations** — RuboCop/StandardRB issues
2. **Anti-pattern detection** — Code smells and problematic patterns
3. **Zeitwerk compliance** — Autoloading and namespace issues
4. **Performance concerns** — N+1 queries, inefficient algorithms
5. **Security issues** — Injection vulnerabilities, unsafe practices

**Audit guides refactoring priorities and approach**

## Step 4: Refactor

Apply changes systematically:

### Core Transformations
- **Convention fixes** — Naming, formatting, structure
- **Anti-pattern removal** — Replace problematic patterns with better alternatives
- **Zeitwerk compliance** — Fix autoloading issues, namespace problems
- **Error handling** — Implement proper exception patterns
- **Performance optimization** — Address identified bottlenecks

### Change Documentation
For each non-trivial transformation:
- Show before/after inline for behavior changes
- Add inline comment if refactored pattern is non-obvious
- Flag explicitly if change alters observable behavior

## Step 5: Verify Zeitwerk Compliance

**Final validation:**
- File naming matches module structure
- Autoloading works correctly
- No circular dependencies
- Proper namespace organization

## Output Format

```markdown
# Refactoring Report

## Pre-Refactor Audit
[Analysis findings with file:line references]

## Changes Applied
[Systematic list of transformations with rationale]

## Refactored Code
```ruby
# frozen_string_literal: true
[Complete refactored implementation]
```

## Zeitwerk Compliance Verification
[Validation results and any remaining issues]

## Behavioral Changes
[Explicit documentation of any behavior modifications]
```