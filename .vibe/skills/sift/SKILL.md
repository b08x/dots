---
name: sift
description: "Use when assessing Ruby code quality, performing architectural reviews, or generating tech advisory reports. Applies SIFT Protocol (Structure, Idioms, Functionality, Testing) with Toulmin evidence framework and weighted rubrics. Four report modes - Full, System Design, Tech Advisory, Backlog."
user-invocable: true
---

# RubyDev SIFT — Quality Assessment Protocol

## Overview

This skill provides **comprehensive quality assessment** using the SIFT Protocol V1.0. SIFT evaluates four dimensions (Structure, Idioms, Functionality, Testing) with Toulmin evidence framework and produces actionable reports in four modes. This skill embodies "The Pragmatist" persona: analytical, holistic, and evidence-driven.

**SIFT Acronym**:
- **S**tructure: Zeitwerk compliance, file organization, architecture. Ground findings in named OOD principles (TRUE, SRP, dependency direction, composition bias) from `~/.vibe/skills/ruby-dev/~/.vibe/skills/sift/references/ood-principles.md` — a structure finding without a named principle as its warrant is an opinion, not evidence. Include a **portability constants sweep**: grep for hardcoded dimensions (embedding sizes, column widths), absolute/user-specific paths, magic hosts/ports, and pinned model names — each is a place the code breaks when moved to another machine, model, or dataset. Cheap to check, disproportionately often missed when the audit goes deep on architecture.
- **I**dioms: Ruby best practices, convention adherence, readability
- **F**unctionality: Logic correctness, error handling, edge cases
- **T**esting: Coverage, test quality, maintainability. Judge against the Testing Grid (incoming: assert result; outgoing command: mock; outgoing query: ignore) in `~/.vibe/skills/ruby-dev/~/.vibe/skills/sift/references/ood-principles.md`.

**References**:
- Logging patterns: `~/.vibe/skills/ruby-dev/~/.vibe/skills/sift/references/logging-patterns.md`
- Environment setup: `~/.vibe/skills/ruby-dev/~/.vibe/skills/sift/references/environment-variables.md`
- Type safety: `~/.vibe/skills/ruby-dev/~/.vibe/skills/sift/references/dry-rb-patterns.md`
- Rubysmith scaffolding: `~/.vibe/skills/ruby-dev/~/.vibe/skills/sift/references/rubysmith-scaffolding.md`
- OO design principles (Toulmin warrants for Structure/Idioms findings): `~/.vibe/skills/ruby-dev/~/.vibe/skills/sift/references/ood-principles.md`
- Assessment dry-struct types: [~/.vibe/skills/sift/references/assessment-types.md](~/.vibe/skills/sift/~/.vibe/skills/sift/references/assessment-types.md))
- Full Assessor implementation example: [~/.vibe/skills/sift/references/implementation-example.md](~/.vibe/skills/sift/~/.vibe/skills/sift/references/implementation-example.md))

---

## Required Gems

| Gem | Purpose | Context7 Library ID | Status |
|:----|:--------|:-------------------|:-------|
| `dry-struct` | Type-safe assessment results | `/dry-rb/dry-struct` | ✅ Verified |
| `dry-types` | Type system | `/dry-rb/dry-types` | ✅ Verified |
| `journald-logger` | Structured logging | `/theforeman/journald-logger` | ✅ Verified |
| `zeitwerk` | Structure validation | `/fxn/zeitwerk` | ✅ Verified |
| `rubocop` | Idiom checking | TBD | 🔴 To Verify |
| `simplecov` | Coverage analysis | TBD | 🔴 To Verify |

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
  gem "rubocop"
  gem "simplecov"
  gem "pry"
  gem "pry-byebug"
  gem "rspec"
end
```

### Assessment Types (dry-struct)

Assessment results use type-safe dry-struct types (`DimensionScore`, `AssessmentResult`, `Finding`, `TechAdvisory`) rather than raw hashes. See [~/.vibe/skills/sift/references/assessment-types.md](~/.vibe/skills/sift/~/.vibe/skills/sift/references/assessment-types.md)) for the complete definitions.

## When to Use

- **Quality assessment**: "Review this project and tell me what's wrong"
- **Pre-merge review**: Before accepting a large PR or refactor
- **Architectural review**: Evaluating design decisions in a codebase
- **Tech advisory**: "Is this production-ready?"
- **Backlog generation**: Converting findings into prioritized work items
- **Post-refactor validation**: Confirming improvements met standards

**Don't use for:**
- **Root cause debugging** (use [analyse/SKILL.md](~/.vibe/skills/analyse/SKILL.md) instead)
- **Direct code generation** (use the [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md))
- **Simple linting** (use `rubocop` directly)
- **Performance profiling** (use `ruby-prof` or `stackprof`)

## Report Modes

### Mode 1: Full Report (Default)

**Trigger**: "Review this project", "SIFT this codebase", "Full quality assessment"

**Output**: 8-section comprehensive report with weighted scores

**Sections**:
1. **Executive Summary**: High-level findings and overall score
2. **Structure Assessment**: Zeitwerk compliance, file organization, namespace design
3. **Idiom Analysis**: Ruby best practices, convention adherence, readability
4. **Functionality Review**: Logic correctness, error handling, edge case coverage
5. **Testing Evaluation**: Coverage metrics, test quality, maintainability
6. **Quantified Impact**: File:line references, estimated remediation time
7. **Prioritized Recommendations**: Ordered by severity and impact
8. **Verification Footer** (optional): SADD-integrated verification if in do-and-judge loop

**Scoring**:
```
Overall Score = (Structure × 0.25) + (Idioms × 0.20) + (Functionality × 0.35) + (Testing × 0.20)

Score Bands:
- 90-100: Production-ready
- 75-89: Good, minor improvements needed
- 60-74: Functional but requires refactoring
- Below 60: Significant issues, not recommended for production
```

### Mode 2: System Design Review

**Trigger**: "Architectural review", "Design review", "Is this architecture sound?"

**Focus**: Structure and high-level design patterns only

**Sections**:
1. **Architecture Overview**: Layer diagram, module dependencies
2. **Design Patterns**: Identified patterns (Strategy, Factory, Observer, etc.)
3. **Separation of Concerns**: Coupling analysis, dependency direction
4. **Extensibility**: How easy to add new features
5. **Technical Debt**: Structural issues requiring refactoring
6. **Recommendations**: Prioritized by architectural impact

**Scoring**: Structure dimension only (0-100)

### Mode 3: Tech Advisory

**Trigger**: "Is this production-ready?", "Tech advisory", "Should we deploy this?"

**Focus**: Risk assessment with binary recommendations

**Sections**:
1. **Verdict**: GO / NO-GO with rationale
2. **Critical Blockers**: Issues that must be fixed before deployment
3. **Risk Assessment**: Security, performance, maintainability risks
4. **Deployment Checklist**: Pre-flight checks
5. **Monitoring Recommendations**: What to watch in production
6. **Rollback Plan**: How to revert if issues surface

**Scoring**: Risk-weighted composite (Security × 0.4, Functionality × 0.3, Testing × 0.3)

### Mode 4: Backlog

**Trigger**: "Generate backlog items", "Convert findings to tickets"

**Focus**: Actionable work items with estimates

**Output**: Markdown checklist formatted as GitHub/Linear issues:
```markdown
## High Priority (Must Fix)
- [ ] **Zeitwerk NameError**: Rename `lib/app/data_processor.rb` → `lib/app/data/processor.rb` [1h]
- [ ] **Missing error handling**: Wrap external API calls in circuit breaker [2h]

## Medium Priority (Should Fix)
- [ ] **Dead code**: Remove unused `ReportGenerator` class (no callers) [30m]
- [ ] **Test coverage**: Add tests for `PaymentProcessor#refund` (0% coverage) [3h]

## Low Priority (Nice to Have)
- [ ] **Readability**: Extract 150-line method into smaller units [4h]
- [ ] **Documentation**: Add YARD docs for public API [2h]
```

## Toulmin Evidence Framework

Every SIFT finding follows the Toulmin argumentation model:

```
[CLAIM] → [DATA] → [WARRANT] → [BACKING] → [QUALIFIER] → [REBUTTAL]
```

**Example**:
```markdown
### Finding: Zeitwerk Naming Violation

**Claim**: File `lib/app/data_processor.rb` violates Zeitwerk naming convention.

**Data**: 
- File path: `lib/app/data_processor.rb`
- Expected constant: `App::DataProcessor`
- Actual constant: `App::Data::Processor` (nested)

**Warrant**: Zeitwerk requires file paths to mirror constant nesting. Nested constants need nested directories.

**Backing**: 
- Zeitwerk docs: "A file is expected to define a constant whose name matches the basename" (https://github.com/fxn/zeitwerk#file-structure)
- Running `zeitwerk:check` raises `Zeitwerk::NameError`

**Qualifier**: This will cause runtime errors in production if the constant is autoloaded.

**Rebuttal**: If the codebase uses classic autoloading (`require` statements), this is not an issue. However, Ruby 3.x+ defaults to Zeitwerk.

**Severity**: **Critical** (runtime error)
**Remediation**: Rename to `lib/app/data/processor.rb` [5 minutes]
```

## SIFT Dimensions

### Structure (Weight: 0.25)

**What**: File organization, namespace design, architectural layers

**Checks**:
- [ ] **Zeitwerk compliance**: All constants match file paths
- [ ] **Autoload paths**: Configured correctly in `config/` or project root
- [ ] **Namespace pollution**: No top-level constants (except entry point)
- [ ] **Directory structure**: Logical grouping (models/, services/, lib/)
- [ ] **Circular dependencies**: No A → B → A cycles
- [ ] **Configuration management**: Secrets in ENV, not committed
- [ ] **Gemfile organization**: Groups (development, test, production) present

**Scoring Example**:
```
Total checks: 7
Passed: 5
Score: (5 / 7) × 100 = 71.4
```

### Idioms (Weight: 0.20)

**What**: Ruby best practices, convention adherence, readability

**Checks**:
- [ ] **Frozen string literal**: Present on all files
- [ ] **Keyword arguments**: Preferred over positional (Ruby 3+)
- [ ] **Module function**: Preferred over `extend self`
- [ ] **Struct initialization**: `keyword_init: true` used
- [ ] **Refinements**: Used for monkey-patching (not reopening classes)
- [ ] **Enumerable methods**: Preferred over manual loops (`map` vs `each` + push)
- [ ] **Safe navigation**: `&.` used for nil-safe calls
- [ ] **Symbol-to-proc**: `&:method_name` shorthand used
- [ ] **Multi-line blocks**: `do...end` for multi-line, `{...}` for one-line
- [ ] **Method length**: <25 lines per method (median)
- [ ] **Variable hoisting in hot loops**: Repeated `@ivar` reads or no-arg method calls (`attr_reader`s, `size`, etc.) inside loops that run thousands+ times are hoisted into a local before the loop, not re-looked-up on every iteration

**Rubocop Integration**: Run `rubocop --format json` and parse offenses.

### Functionality (Weight: 0.35)

**What**: Logic correctness, error handling, edge cases

**Checks**:
- [ ] **Error handling**: `rescue` blocks present for external calls
- [ ] **Circuit breakers**: Wrapping external APIs (HTTP, DB, Redis)
- [ ] **Nil checks**: Explicit handling of nil values
- [ ] **Type coercion**: Safe conversions (`to_i` with fallback)
- [ ] **Edge cases**: Empty arrays, zero values, boundary conditions handled
- [ ] **Idempotency**: Repeated calls produce same result (where applicable)
- [ ] **Transaction safety**: DB operations wrapped in transactions
- [ ] **Async execution**: Blocking I/O moved to `Async {}` blocks
- [ ] **Resource cleanup**: `ensure` blocks for file/socket closure
- [ ] **Logging**: Structured logs with context (not just strings)

**Highest Weight**: Functionality is 35% of overall score because correctness matters most.

### Testing (Weight: 0.20)

**What**: Test coverage, test quality, maintainability

**Checks**:
- [ ] **Coverage threshold**: >80% line coverage (run `simplecov`)
- [ ] **Test framework**: RSpec or Minitest present
- [ ] **Unit tests**: Public methods have test coverage
- [ ] **Integration tests**: Happy path and error path tested
- [ ] **Test isolation**: No shared state between tests
- [ ] **Test speed**: <5 seconds for unit suite, <60 seconds for full suite
- [ ] **Test readability**: Descriptive names, clear assertions
- [ ] **Fixtures**: Factories or fixtures for test data
- [ ] **Mocking**: External dependencies mocked (HTTP, DB)
- [ ] **CI integration**: Tests run on every commit

**Coverage Extraction**:
```ruby
require "simplecov"
SimpleCov.start

# After running tests:
coverage_data = SimpleCov.result
line_coverage = coverage_data.covered_percent # → 87.4
```

---

## Implementation Example

See [~/.vibe/skills/sift/references/implementation-example.md](~/.vibe/skills/sift/~/.vibe/skills/sift/references/implementation-example.md)) for a complete `Assessor` class showing dimension scoring, weighting, and verdict derivation.

---

## Integration with Other Skills

### From the ruby-dev Orchestrator (Audit Gate)

The [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md) uses SIFT as its primary quality check within the pipeline:

1. **Survey**: Codebase overview (orchestrator entry survey)
2. **Evaluation**: Run this skill (audit gate)
3. **Recommendations**: Generate backlog (self-correction loop)

### Receiving Findings (Input-Driven)

SIFT evaluates whatever findings it receives, making it agnostic to the source:

- **From [analyse/SKILL.md](~/.vibe/skills/analyse/SKILL.md)** — analyse produces `AnalysisSession` findings. SIFT evaluates whether those findings have been resolved.
- **From the orchestrator (Audit Gate)** — the ruby-dev orchestrator calls SIFT for the quality check within its pipeline.
- **From the orchestrator (do-and-judge)** — rubric + code. SIFT evaluates against the rubric.

**Pattern**: [Any source produces findings] → SIFT evaluates → Score + recommendations

### With Do-and-Judge Loop

When called by the [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md) in a do-and-judge loop:

1. **Meta-Judge** generates pre-evaluation rubric (YAML)
2. **Builder** produces code
3. **SIFT** evaluates against rubric
4. If score < threshold: Builder retries with feedback
5. Loop until passing or max retries

**SADD Verification Footer** (added in do-and-judge mode):
```markdown
---
## SADD Verification

**Iteration**: 2 of 3
**Previous Score**: 68.2
**Current Score**: 84.7
**Threshold**: 75.0
**Status**: PASS

**Improvements Made**:
- Added circuit breakers to external API calls (+8 points)
- Fixed Zeitwerk naming violations (+5 points)
- Increased test coverage from 45% to 82% (+15 points)
```

## One-Shot Recipes

### Recipe 1: Quick Quality Check

**User Request**: "Is this code good?"

```
Assess lib/my_app/processor.rb
```

**Process**:
1. Run SIFT Full Report (default mode)
2. Score all four dimensions
3. Generate prioritized recommendations
4. Output overall score: 78.3 → "Good, minor improvements needed"

### Recipe 2: Pre-Deployment Review

**User Request**: "Can we deploy this to production?"

```
Assess --mode=tech-advisory
```

**Process**:
1. Focus on risk assessment
2. Check for critical blockers:
   - Secrets in code? ❌
   - Test coverage >80%? ✅
   - Error handling present? ✅
   - Circuit breakers for external calls? ❌ (BLOCKER)
3. Verdict: **NO-GO** until circuit breakers added

### Recipe 3: Backlog Generation

**User Request**: "Convert these findings into GitHub issues"

```
Assess --mode=backlog --output=github-issues.md
```

**Process**:
1. Run full assessment
2. Group findings by priority (High/Medium/Low)
3. Add time estimates based on complexity
4. Output markdown checklist compatible with GitHub/Linear

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| No input findings provided | Caller didn't supply findings | Accept findings as structured input from the caller. If none arrive, run assessment using only the code surface — Structure and Idioms from direct inspection, Functionality from file-level analysis, Testing from test file presence. |
| [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md) | Orchestrator not driving a do-and-judge loop | Run SIFT as a single-pass evaluation. Output the score with recommendations but without the iteration rubric or SADD Verification Footer. The caller can trigger a re-evaluation manually. |
| Do-and-Judge loop | Builder fails mid-loop | Output partial results with [`WARNING: Partial Assessment`] marking and include which iterations completed versus failed. |

## Common Pitfalls

1. **Skipping the survey phase.** Jumping straight to scoring without understanding the codebase context yields meaningless scores.
2. **Ignoring the evidence rubric.** Each dimension score must be backed by specific evidence, not gut feeling.
3. **Treating all findings as equal.** Use Toulmin's **severity qualifier** to prioritize critical vs. nice-to-have.
4. **Ignoring test quality.** 100% coverage with bad tests is worse than 60% with good tests. Assess test **quality**, not just quantity.
5. **Over-focusing on idioms.** A readable codebase with broken logic is still broken. Functionality weight (35%) > Idioms weight (20%).
6. **Not providing file:line references.** Vague findings ("error handling is missing") aren't actionable. Cite specific locations.
7. **Skipping the rebuttal.** Toulmin's rebuttal acknowledges when a finding might not apply (e.g., "unless you're using classic autoloading").
8. **Generating reports no one reads.** Backlog mode converts findings into actionable tickets. Use it.
9. **Not tracking improvements.** In do-and-judge loops, include the SADD verification footer to show progress.

## Verification Checklist

- [ ] Correct report mode selected (Full, System Design, Tech Advisory, Backlog)
- [ ] All four SIFT dimensions evaluated (Structure, Idioms, Functionality, Testing)
- [ ] Every finding includes Toulmin evidence (Claim → Data → Warrant → Backing)
- [ ] Severity qualifiers applied (Critical, High, Medium, Low)
- [ ] File:line references provided for all findings
- [ ] Remediation time estimates included
- [ ] Overall score calculated with weighted dimensions
- [ ] Recommendations prioritized by impact
- [ ] Rebuttal included where findings might not apply
- [ ] SADD verification footer added if in do-and-judge loop
