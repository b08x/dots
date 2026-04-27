---
name: analyse
description: "Ruby-targeted analysis skill implementing Gemba Walk (code archaeology, docs-vs-reality gaps), Muda waste analysis (dead methods, N+1 queries, unused gems, over-engineering), Root-Cause Tracing (backward call-chain from symptom to source), and Five Whys (iterative causal drilling)."
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

# Rubysmithing — Analyse

Ruby-targeted analysis skill implementing Lean/Kaizen methodologies for code quality assessment and pre-refactor investigation.

## Architecture

```
analyse/SKILL.md
  references/analyse-methods.md  — Full method templates, Ruby instrumentation
                                   idioms, Muda category mappings, Gemba
                                   observation checklist, defense-in-depth pattern
```

Load `references/analyse-methods.md` immediately when executing any method.

## Method Auto-Selection

**User input** → **Auto-select method** → **Execute analysis** → **Format findings** → **Reference refactor patterns**

1. **"Why is this failing?"** | **"trace this bug"** | **"root cause"** → **Root-Cause Tracing**
2. **"what's wasting cycles?"** | **"dead code audit"** | **"muda"** → **Muda Waste Analysis**
3. **"explore this codebase"** | **"docs vs reality"** | **"gemba"** → **Gemba Walk**
4. **"keep asking why"** | **"five whys"** → **Five Whys** (iterative)

## Target Detection

Before analysis execution:
1. **File paths** → Direct file analysis
2. **Error messages** → Symptom-based Root-Cause Tracing
3. **Performance complaints** → Muda Waste Analysis
4. **General "understand this"** → Gemba Walk

## Method: Gemba Walk (Ruby Adaptation)

**Purpose**: Code archaeology and docs-vs-reality gap detection
**When**: New codebase exploration, documentation audits, onboarding

```ruby
# Investigation checklist:
- README claims vs actual setup steps
- API documentation vs actual method signatures
- Configuration files vs runtime behavior
- Dependencies in Gemfile vs actual usage
- Test coverage claims vs actual coverage
- Performance characteristics vs benchmarks
```

**Output**: Discrepancy report with file:line evidence

## Method: Muda Waste Analysis (Ruby Adaptation)

**Purpose**: Identify wasteful code patterns and resource inefficiencies
**When**: Performance optimization, dead code removal, pre-refactor cleanup

**Ruby Muda Categories**:
1. **Overproduction**: Excessive abstractions, premature optimization
2. **Waiting**: Slow queries, blocking I/O, inefficient algorithms
3. **Transport**: Unnecessary data movement, serialization overhead
4. **Inappropriate Processing**: Wrong algorithms, inefficient gems
5. **Inventory**: Dead code, unused gems, stale configurations
6. **Motion**: Poor code organization, excessive indirection
7. **Defects**: Bug patterns, code smells, anti-patterns

**Output**: Categorized waste inventory with refactor pattern references

## Method: Root-Cause Tracing (Ruby Adaptation)

**Purpose**: Backward call-chain analysis from symptom to source
**When**: Bug investigation, error analysis, failure post-mortems

**Tracing Strategy**:
1. **Start from symptom** (error message, failed test, performance issue)
2. **Walk backward** through call stack, Git history, dependencies
3. **Identify decision points** where the root cause was introduced
4. **Document causal chain** with evidence links

**Ruby-Specific Traces**:
- Zeitwerk loading errors → Namespace conflicts → File organization
- N+1 queries → Eager loading → Association design
- Memory leaks → Object retention → GC pressure points
- Gem conflicts → Version constraints → Dependency hell

**Output**: Causal chain diagram with fix recommendations

## Method: Five Whys (Ruby Adaptation)

**Purpose**: Iterative causal drilling to reach fundamental issues
**When**: Complex failures, systemic problems, recurring bugs

**Process**:
1. **State the problem** clearly
2. **Ask "Why?"** and provide evidence-based answer
3. **Repeat 4 more times**, drilling deeper each iteration
4. **Reach root cause** that addresses fundamental issue

**Example Ruby Five Whys**:
```
Problem: Tests are flaky
Why? → Database state isn't reset between tests
Why? → Using shared database connections
Why? → Connection pooling configured incorrectly  
Why? → Environment variables not set for test environment
Why? → Configuration management is inconsistent across environments
Root Cause: Need standardized environment configuration system
```

**Output**: Five-level causal analysis with actionable root cause fix

## Output Format

```markdown
# Analysis Report: [Method Used]

## Summary
[One-line problem statement]

## Findings
[Bulleted list with file:line references]

## Evidence
[Code snippets, log excerpts, configuration differences]

## Refactor Patterns
[References to refactor-patterns.md where applicable]

## Recommended Actions
[Prioritized list of fixes with effort estimates]
```

## Integration with refactor

Findings reference named patterns from
`~/.vibe/skills/refactor/references/refactor-patterns.md` wherever a match exists.
This enables direct handoff: the refactor agent receives a pre-keyed issue list
rather than freeform descriptions.

## Integration with sift

For quality assessment, findings feed into sift quality dimensions:
- Structure violations → Architectural SIFT
- Performance issues → Performance SIFT  
- Dead code → Maintainability SIFT
- Documentation gaps → Documentation SIFT