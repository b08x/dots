---
name: analyse
description: "Use when debugging Ruby code, investigating root causes, identifying waste (dead code, over-engineering), or understanding unfamiliar codebases. Applies four diagnostic methods (Gemba Walk, Muda Analysis, Root-Cause Tracing, Five Whys) based on problem type."
user-invocable: true
---

# RubyDev Analyse — Diagnostic Framework

## Overview

This skill provides **structured diagnostic analysis** for Ruby codebases using four Kaizen-derived methods. It produces keyed findings that can be handed off to [refactor/SKILL.md](~/.vibe/skills/refactor/SKILL.md) for remediation. This skill embodies "The Stealth Debugger" persona: inquisitive, paranoid, and methodical.

**Core Mandate**: Understand before acting. Never refactor without diagnosis.

**References**:
- Logging patterns: `~/.vibe/skills/ruby-dev/~/.vibe/skills/analyse/references/logging-patterns.md`
- Environment setup: `~/.vibe/skills/ruby-dev/~/.vibe/skills/analyse/references/environment-variables.md`
- Type safety: `~/.vibe/skills/ruby-dev/~/.vibe/skills/analyse/references/dry-rb-patterns.md`
- OO design principles (naming design smells precisely): `~/.vibe/skills/ruby-dev/~/.vibe/skills/analyse/references/ood-principles.md`

---

## Required Gems

| Gem | Purpose | Context7 Library ID | Status |
|:----|:--------|:-------------------|:-------|
| `dry-struct` | Type-safe findings | `/dry-rb/dry-struct` | ✅ Verified |
| `dry-types` | Type system | `/dry-rb/dry-types` | ✅ Verified |
| `journald-logger` | Structured logging | `/theforeman/journald-logger` | ✅ Verified |
| `zeitwerk` | Autoload verification | `/fxn/zeitwerk` | ✅ Verified |
| `pry` | REPL exploration | `/websites/rdoc_info_github_pry_pry_master` | ✅ Verified |

---

## Project Setup

### Gemfile

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

# Type Safety
gem "dry-struct"
gem "dry-types"

# Logging
gem "journald-logger"

# Autoloading
gem "zeitwerk"

group :development, :test do
  gem "pry"
  gem "pry-byebug"
  gem "rubocop"
end
```

### Analysis Types (dry-struct)

Each diagnostic method produces a type-safe finding (`GembaFinding`, `MudaFinding`, `RootCauseFinding`, `FiveWhysFinding`) collected in an `AnalysisSession`. See [~/.vibe/skills/analyse/references/analysis-types.md](~/.vibe/skills/analyse/~/.vibe/skills/analyse/references/analysis-types.md)) for the complete definitions.

## When to Use

- **Zeitwerk errors**: `NameError: uninitialized constant MyApp::Data::Processor`
- **Performance issues**: "This feels slow but I don't know why"
- **Code bloat**: "Half the methods seem unused"
- **Unfamiliar codebase**: Before refactoring inherited or third-party code
- **Recurring bugs**: Same issue keeps resurfacing after fixes
- **Dead code detection**: Finding unused classes, methods, gems

**Don't use for:**
- Quality assessment (use [sift/SKILL.md](~/.vibe/skills/sift/SKILL.md) instead)
- Making diagnosed-slow code faster (hand off to [perf/SKILL.md](~/.vibe/skills/perf/SKILL.md) with the suspected hotspot)
- Direct code generation (use the [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md))
- Refactoring without diagnosis (always diagnose first)
- Convention fixes (use [refactor/SKILL.md](~/.vibe/skills/refactor/SKILL.md) after diagnosis)

## Diagnostic Methods

### Method 1: Gemba Walk

**Trigger**: Unfamiliar codebase, before refactoring, "I don't understand this code"

**Purpose**: Understand the **actual state** of the code as it exists, not as documented or assumed.

**Process**:
1. **Survey the landscape**: Map directory structure, file naming patterns, dependencies
2. **Trace execution paths**: Follow primary workflows from entry point to output
3. **Identify patterns**: Recurring idioms, design patterns, architectural layers
4. **Document assumptions**: What the code *claims* to do vs. what it *actually* does
5. **Note surprises**: Deviations from Ruby conventions or stated architecture

**Output Format**:
```markdown
## Gemba Walk: <Target>

### Landscape
- **Entry points**: <list>
- **Core abstractions**: <list>
- **External dependencies**: <list>

### Execution Paths
1. <Primary workflow>
2. <Secondary workflow>

### Patterns Observed
- <Pattern 1>
- <Pattern 2>

### Assumptions vs. Reality
| Documented | Actual |
|:-----------|:-------|
| <claim 1>  | <reality 1> |

### Surprises
- <Unexpected behavior>

### Handoff Keys
- `pattern:<name>` → References in refactor-patterns.md
- `gap:<description>` → Missing functionality
```

### Method 2: Muda Analysis

**Trigger**: "Code feels bloated", performance issues, unused gems in Gemfile

**Purpose**: Identify **seven types of Ruby waste** (muda):

| Waste Type | Examples |
|:-----------|:---------|
| **Transportation** | Data copied between layers unnecessarily |
| **Inventory** | Unused gems in Gemfile, dead code, commented-out methods |
| **Motion** | Excessive indirection (wrapper classes with no logic) |
| **Waiting** | Synchronous I/O without Async, blocking on external APIs |
| **Overprocessing** | Parsing full documents when only metadata needed |
| **Overproduction** | Generating reports no one reads, logs no one monitors |
| **Defects** | Known bugs lingering unfixed, failing tests skipped |

**Process**:
1. **Inventory scan**: Find unused gems (`bundle-audit unused`), dead methods (RuboCop's `Lint/UselessMethodDefinition`)
2. **I/O analysis**: Identify blocking calls without `Async {}` or circuit breakers
3. **Wrapper audit**: Check for classes that only delegate without adding logic
4. **Data flow tracing**: Find unnecessary serialization/deserialization cycles
5. **Log analysis**: Check for debug logs in production, unmonitored metrics

**Output Format**:
```markdown
## Muda Analysis: <Target>

### Inventory Waste
- [ ] Gem: <name> — unused (bundler-audit confirms)
- [ ] Method: <Class#method> — dead code (no callers found)

### Motion Waste
- [ ] Class: <name> — wrapper with no logic (consider inlining)

### Waiting Waste
- [ ] File: <path> — blocking I/O without Async

### Overprocessing Waste
- [ ] Feature: <name> — parsing full file when metadata suffices

### Quantified Impact
- **Gem removal potential**: <count> gems, <MB> size reduction
- **Method removal potential**: <count> methods, <LOC> reduction
- **I/O optimization potential**: <count> blocking calls

### Handoff Keys
- `muda:inventory` → Dead code for removal
- `muda:waiting` → I/O for async conversion
- `muda:motion` → Wrappers for inlining
```

### Method 3: Root-Cause Tracing

**Trigger**: Specific error (NameError, NoMethodError, TypeError), failing test, bug report

**Purpose**: Trace error back to **original cause**, not just the symptom.

**Process**:
1. **Error manifestation**: Where the error surfaced (stack trace top)
2. **Immediate cause**: The line that raised the error
3. **Propagation path**: How the bad state reached that line
4. **Introduction point**: Where the bad state originated (root cause)
5. **Zeitwerk-specific**: For `NameError: uninitialized constant`:
   - Check file path → constant name mapping (`MyApp::Data::Processor` → `my_app/data/processor.rb`)
   - Verify autoload paths in config
   - Check for `require` statements in Zeitwerk-managed files (forbidden)

**Output Format**:
```markdown
## Root-Cause Trace: <Error>

### Error Manifestation
```ruby
# Location: <file>:<line>
# Stack trace:
<top 5 frames>
```

### Immediate Cause
<What line raised the error>

### Propagation Path
1. <Step 1: where bad state entered>
2. <Step 2: how it moved through the system>
3. <Step 3: arrived at error location>

### Root Cause
<The original source of the problem>

### Fix Strategy
<How to address at the root, not the symptom>

### Handoff Keys
- `root-cause:zeitwerk` → Constant naming mismatch
- `root-cause:nil-propagation` → Nil check missing upstream
- `root-cause:type-mismatch` → Type coercion needed
```

### Method 4: Five Whys

**Trigger**: Recurring bugs, systemic issues, "We keep hitting this problem"

**Purpose**: Drill down from **symptom to systemic root cause** through iterative questioning.

**Process**:
1. **State the problem**: The observable symptom
2. **Why 1**: Immediate cause
3. **Why 2**: Cause of the immediate cause
4. **Why 3**: Deeper layer
5. **Why 4**: Organizational/architectural layer
6. **Why 5**: Systemic root (process, tooling, or architectural decision)
7. **Actionable remediation**: Address the systemic root, not just the symptom

**Output Format**:
```markdown
## Five Whys: <Problem>

### Problem Statement
<Observable symptom>

### Why 1: <Immediate cause>
<Explanation>

### Why 2: <Cause of Why 1>
<Explanation>

### Why 3: <Deeper cause>
<Explanation>

### Why 4: <Architectural cause>
<Explanation>

### Why 5: <Systemic root>
<Explanation>

### Remediation Strategy
**Symptom fix** (short-term): <Quick patch>
**Root fix** (long-term): <Systemic change>

### Handoff Keys
- `five-whys:systemic` → Architectural change needed
- `five-whys:process` → Development workflow issue
- `five-whys:tooling` → Linter/CI gap
```

## Method Selection Matrix

Use this table to choose the right diagnostic method:

| Situation | Method | Reason |
|:----------|:-------|:-------|
| "I don't understand this codebase" | **Gemba Walk** | Need holistic understanding before changes |
| "This file seems bloated" | **Muda Analysis** | Identify specific waste types for removal |
| NameError, NoMethodError, TypeError | **Root-Cause Tracing** | Follow error back to introduction point |
| "We fixed this twice already" | **Five Whys** | Recurring issue suggests systemic problem |
| Before any refactoring | **Gemba Walk** | Understand current state first |
| Performance is slow | **Muda Analysis** (Waiting) | Find blocking I/O and overprocessing |

---

## Implementation Examples

See [~/.vibe/skills/analyse/references/implementation-examples.md](~/.vibe/skills/analyse/~/.vibe/skills/analyse/references/implementation-examples.md)) for a Muda waste analyzer and a Zeitwerk root-cause tracer, both built on the AnalysisSession types.

## Handoff Pattern

Diagnosis findings use **keyed patterns** for downstream handoff:

```
Key Format: <method>:<category>

Examples:
- pattern:wrapper → Links to refactor-patterns.md entry
- muda:inventory → Dead code list for removal
- root-cause:zeitwerk → Naming convention fix needed
- five-whys:systemic → Architectural change ticket
```

**Handoff to [refactor/SKILL.md](~/.vibe/skills/refactor/SKILL.md)**:
```
# After diagnosis
Refactor lib/my_app/processor.rb --findings=analysis-2024-03-29.md
```

The refactor skill reads the keyed findings and applies targeted fixes.

## Integration with Other Skills

### With the diagnostic workflow
- `analyse` provides the diagnosis step of a broader debug-fix-verify workflow
- That workflow orchestrates: analyse → resolution → verification
- Run the full workflow for an end-to-end fix, or `analyse` alone for diagnosis only

### With [refactor/SKILL.md](~/.vibe/skills/refactor/SKILL.md)
- `analyse` produces findings → `refactor` applies fixes
- Never refactor without running `analyse` first

### With the `ruby-dev` Orchestrator

The [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md) drives the full pipeline:
1. **Semantic Survey (L1)**: Determines Field-Tenor-Mode
2. **Convention Detection (L2)**: Scans environment
3. **Verification (L3)**: Queries Context7/DeepWiki inline for any non-stdlib gems encountered during analysis
4. **Dispatch (L4)**: Routes to builders
5. **Audit Gate (L5)**: Runs [sift/SKILL.md](~/.vibe/skills/sift/SKILL.md) and quality checks

`analyse` feeds into Layer 1 (Semantic Survey) by diagnosing existing code health before generation begins.

## One-Shot Recipes

### Recipe 1: Zeitwerk NameError

**User Request**: "I keep getting `NameError: uninitialized constant MyApp::Data::Processor`"

**Analysis**:
```
Diagnose NameError: uninitialized constant MyApp::Data::Processor
```

**Method**: Root-Cause Tracing

**Steps**:
1. Check constant name → expected file path: `MyApp::Data::Processor` → `my_app/data/processor.rb`
2. Verify actual file path: `lib/my_app/data_processor.rb` (MISMATCH!)
3. Root cause: File named with underscore instead of nested directory
4. Fix: Rename `lib/my_app/data_processor.rb` → `lib/my_app/data/processor.rb`

### Recipe 2: Performance Investigation

**User Request**: "This data pipeline is slow but I don't know why"

**Analysis**:
```
Diagnose lib/my_app/pipeline.rb
```

**Method**: Muda Analysis (Waiting + Overprocessing)

**Steps**:
1. Scan for blocking I/O: Found 12 `HTTParty.get` calls without `Async {}`
2. Check data processing: Parsing full JSON files when only metadata needed
3. Quantify impact: 12 blocking calls × ~200ms = 2.4s latency
4. Recommendations:
   - Wrap HTTP calls in `Async {}`
   - Use `JSON.load(file, symbolize_names: true)` with `slice(:id, :created_at)` for metadata-only needs

### Recipe 3: Dead Code Cleanup

**User Request**: "This codebase feels bloated, lots of unused code"

**Analysis**:
```
Diagnose lib/my_app/ --scope=inventory
```

**Method**: Muda Analysis (Inventory)

**Steps**:
1. Run `bundle-audit unused`: Found 8 gems not imported anywhere
2. Run RuboCop `Lint/UselessMethodDefinition`: Found 23 empty wrapper methods
3. Grep for `TODO` and `FIXME`: Found 47 instances, 12 >1 year old
4. Output: Prioritized removal list with impact estimates

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| [refactor/SKILL.md](~/.vibe/skills/refactor/SKILL.md) | Not loaded or missing | Output findings as structured YAML in the response instead of dispatching to refactor. Each finding includes: `handoff_key`, `description`, `fix_strategy`, and `file_path`. The human or the ruby-dev orchestrator can apply fixes from this output. |
| Diagnostic workflow | Parent workflow not available | Run all 4 diagnostic methods (Gemba, Muda, Root-Cause, Five Whys) independently instead of relying on the workflow for ordering. Present results as a flat diagnostic report. |
| [sift/SKILL.md](~/.vibe/skills/sift/SKILL.md) | Holistic assessment not available | Surface the `handoff_key` findings directly. The orchestrator can pass them to sift manually. |

## Common Pitfalls

1. **Starting without a clear problem statement.** A vague "something is slow" leads to aimless analysis. Always pin down a specific symptom.

2. **Using the wrong method.** Root-Cause Tracing for general code bloat is overkill. Match the method to the problem type.

3. **Stopping at the symptom.** If Five Whys lands on "the developer forgot", dig deeper — why was forgetting possible? (Tooling gap)

4. **Not keying findings for handoff.** Unstructured findings can't be consumed by [refactor/SKILL.md](~/.vibe/skills/refactor/SKILL.md).

5. **Analyzing without quantifying.** Muda Analysis without impact estimates ("this could save ~200ms per request") lacks urgency.

6. **Assuming documentation is accurate.** Gemba Walk reveals the truth; documentation reveals intentions. They often diverge.

7. **Refactoring before diagnosis.** The Sovereign's mandate: "Understand before acting."

8. **Ignoring Zeitwerk naming rules.** Ruby 3.x+ projects default to Zeitwerk. Misnamed files cause `NameError` at runtime, not load time.

## Verification Checklist

- [ ] Correct diagnostic method selected based on problem type
- [ ] Gemba Walk performed if codebase is unfamiliar
- [ ] Findings are keyed with `<method>:<category>` format
- [ ] Quantitative impact estimates provided (LOC, latency, size)
- [ ] Handoff keys reference known patterns in `refactor-patterns.md`
- [ ] Root cause identified (not just symptom)
- [ ] For Five Whys: reached systemic layer (not stopped at "developer error")
- [ ] Output format matches method template
- [ ] Findings are actionable (specific file:line references)
- [ ] For Zeitwerk errors: constant-to-path mapping verified
