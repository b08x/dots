# Analyse Methods Reference

Detailed templates and Ruby-specific idioms for the four analysis methods in
`rubysmithing-analyse`. Load this file before executing any method.

## Contents
- [Gemba Walk — Full Template](#gemba-walk--full-template)
- [Muda Waste Analysis — Full Category Mappings](#muda-waste-analysis--full-category-mappings)
- [Root-Cause Tracing — Full Template](#root-cause-tracing--full-template)
- [Five Whys — Full Template](#five-whys--full-template)

---

## Gemba Walk — Full Template

**Purpose:** Observe actual code behavior vs. documented or assumed behavior.
Use before refactoring unfamiliar code or when documentation and reality diverge.

### Observation Checklist

**Entry Points**
- [ ] Where does execution enter this code? (`require`/autoload, Rake task, CLI entry, initializer)
- [ ] Is the entry point documented anywhere? Does it match the actual code?
- [ ] Are there multiple entry points (e.g., both CLI and library use)?

**Data Flow**
- [ ] What data comes in? (type, shape, source)
- [ ] What transformations happen? (are they documented? are they necessary?)
- [ ] What data goes out? (type, shape, destination)
- [ ] Are there hidden side effects? (logging, file writes, network calls, mutations)

**Zeitwerk / Autoload Chain**
- [ ] Does `Zeitwerk::Loader.new` setup match the actual directory/file structure?
- [ ] Are module/class names in files matching the path exactly? (`lib/app/data/processor.rb` → `App::Data::Processor`)
- [ ] Are any files `require`'d manually that should be autoloaded?
- [ ] Is the inflector configured for acronyms? (e.g., `loader.inflector.inflect('llm' => 'LLM')`)

**Dependencies**
- [ ] Which gems are actually called? Are all Gemfile entries used?
- [ ] Are any `require` calls loading gems not in the Gemfile?
- [ ] Are any internal requires loading files that Zeitwerk should handle?
- [ ] Are there conditional requires based on environment?

**Surprises to Document**
- [ ] `puts`/`p`/`pp` debug output left in production code
- [ ] Commented-out code blocks (preserved intent or dead?)
- [ ] `rescue` without logging or re-raise (silent failure)
- [ ] Hardcoded values that should be config (URLs, timeouts, credentials)
- [ ] Methods defined but never called in this file or any grep result
- [ ] Comments that describe something different from the code below them

### Gemba Walk Output Template

```
GEMBA WALK — [target file/directory]

ASSUMED BEHAVIOR:
[What the docs/comments/name suggest this does]

ACTUAL BEHAVIOR:
[What the code actually does — traced through execution]

ENTRY POINTS:
- [method/CLI/task]: [file:line]

DATA FLOW:
[input type] → [transformation] → [output type]
Hidden side effects: [list or "none observed"]

ZEITWERK OBSERVATIONS:
[loader config vs. actual structure — match/mismatch/gaps]

SURPRISES:
- [file:line] — [what was unexpected and why]

GAPS (docs vs. reality):
- [gap description] → [recommendation or refactor-patterns.md key]
```

---

## Muda Waste Analysis — Full Category Mappings

**Purpose:** Identify and prioritize Ruby code waste using the 7 Lean waste types
adapted to software artifacts.

### Category → Ruby Artifact Mapping

**1. Overproduction** (building more than needed)
- Dead methods: defined but never called (`grep -r "def method_name"` finds no callers)
- Unused public API: methods exposed as public with no external callers
- Speculative abstractions: base classes with one subclass, modules included once
- Unused initializer arguments: params accepted but never stored or used
- Generated code artifacts no longer needed

**2. Waiting** (idle time while waiting for something)
- Synchronous HTTP/DB calls that block the fiber: should use `Async { }` wrapper
- External calls without `circuit_breaker`: one slow endpoint blocks the whole pipeline
- Sequential calls to independent services that could be parallelized with `Async::Barrier`
- Missing connection pooling causing sequential queue for shared resources

**3. Transportation** (unnecessary movement of data)
- Redundant serialization: Hash → JSON → Hash within the same process
- Object transformations adding no semantic value (rename fields only)
- Data passed through multiple layers unchanged (passing `user` through 4 methods to reach 1)
- Repeated encoding/decoding (base64 encode → store → decode → re-encode)

**4. Over-processing** (doing more than necessary)
- Duplicated `dry-schema` contracts validating the same shape at multiple layers
- Excessive logging: every method entry/exit logged at INFO (should be DEBUG or removed)
- Redundant validations: nil-check before calling a method that already raises on nil
- Double-parsing: YAML loaded twice, environment variables parsed twice
- Over-instrumented metrics for paths that are never measured

**5. Inventory** (work piling up unused)
- Commented-out code blocks (git history preserves intent — delete these)
- Stale feature flags: `if ENV['FEATURE_X']` where `FEATURE_X` is always set or always absent
- Unused Gemfile entries: gems listed but not `require`'d anywhere
- Unmerged dead branches (out of scope for file analysis — note if Gemfile hints)
- Half-finished classes: only `initialize` defined, no methods

**6. Motion** (unnecessary developer movement/friction)
- Missing Zeitwerk compliance: manual `require` chains that autoloading would eliminate
- Config scattered across multiple files (should consolidate via `tty-config`)
- Module structure not matching directory structure (constant lookup surprises)
- Test setup requiring complex manual state because of missing factory/builder patterns

**7. Defects** (bugs, rework, violations)
- Missing `# frozen_string_literal: true` on every `.rb` file
- Silent `rescue` clauses: `rescue => e` with no logging or re-raise
- RuboCop/StandardRB violations (flag category, not full list — use `/rubysmithing:report`)
- `extend self` instead of `module_function`
- `Thread.new` instead of `Async { }`
- Nested conditionals instead of guard clauses
- Methods over 25 lines without obvious justification

### Muda Output Template

```
MUDA WASTE ANALYSIS — [target]

WASTE INVENTORY (by impact):

[Waste Type] — [CRITICAL | HIGH | MEDIUM | LOW]
  Location: [file:line]
  Instance: [brief description]
  Impact: [what this costs: correctness, performance, maintainability]
  Action: /rubysmithing:refactor [file] (pattern: [refactor-patterns.md key])

[repeat for each instance]

SUMMARY:
Total waste instances: [n]
Highest impact: [type + location]
Recommended first action: [most impactful fix]
```

---

## Root-Cause Tracing — Full Template

**Purpose:** Trace bugs backward through the Ruby call chain from symptom to
original trigger. Fix at the source, then add defense-in-depth guards.

### Tracing Process

```
SYMPTOM (error at file:line)
    ↓ What code directly causes this?
IMMEDIATE CAUSE (file:line)
    ↓ What called that / what value was passed?
INTERMEDIATE STEP (file:line)
    ↓ Continue upward...
INTERMEDIATE STEP (file:line)
    ↓ Where did the bad value originate?
ORIGINAL TRIGGER (file:line — initializer, config load, test setup, user input)
```

### Ruby Instrumentation Idioms

Use `$stderr` — not the application logger, which may be suppressed in test environments:

```ruby
# Full call chain (where am I being called from?)
$stderr.puts "TRACE: #{caller.join("\n")}"

# Where is this method actually defined?
$stderr.puts "SOURCE: #{method(:suspect_method).source_location.inspect}"

# What type is this object at runtime?
$stderr.puts "CLASS: #{object.class} / #{object.inspect}"

# Environment at time of failure
$stderr.puts "ENV: #{ENV.select { |k,_| k.start_with?('APP_') }.inspect}"

# Zeitwerk loader state
$stderr.puts "ROOTS: #{loader.dirs.inspect}" # if loader is accessible
```

### Common Ruby Trace Patterns

**Zeitwerk NameError** (`uninitialized constant Foo::Bar`):
```
NameError at [caller file:line]
    ↓ What constant was expected?
Expected: Foo::Bar
    ↓ What file does Zeitwerk expect?
Expected file: lib/foo/bar.rb
    ↓ Does that file exist?
Actual: lib/foo/bar_impl.rb (wrong name) OR lib/Foo/Bar.rb (wrong case)
    ↓ Why is the file path wrong?
Zeitwerk inflector not configured for acronym OR class name doesn't match path
ORIGINAL TRIGGER: naming mismatch at project creation / inflector config omission
```

**circuit_breaker opens unexpectedly**:
```
CircuitBreaker::Open at [integration call site]
    ↓ Which external call?
External: [service/endpoint]
    ↓ What error triggers the breaker?
Error: [Timeout::Error | Net::HTTPError | ...]
    ↓ What threshold was configured?
Threshold: [n failures in m seconds]
    ↓ Where is this threshold configured?
Source: [hardcoded in class | ENV var | tty-config file | missing entirely]
ORIGINAL TRIGGER: [timeout too aggressive | service degraded | threshold misconfigured]
```

**Sequel N+1**:
```
Slow query / N+1 detected in [controller/pipeline layer]
    ↓ Which model association?
Model: [Parent] → association: [children]
    ↓ Where is eager loading missing?
Query site: [file:line] — .all without .eager(:children)
    ↓ Why was eager loading omitted?
ORIGINAL TRIGGER: association added to model after query was written; no query review
```

### Defense-in-Depth Pattern

After fixing at the original trigger, add guards at each layer up the call chain:

```
Layer 0 (source):     Fix the original trigger — correct value/state at origin
Layer 1 (input):      Validate/raise at first use of the value
Layer 2 (intermediate): Guard clause in each intermediate transformer
Layer 3 (boundary):   Type check or schema validation at external boundary
Layer 4 (logging):    $stderr / journald log with context at the error site
```

### Root-Cause Tracing Output Template

```
ROOT-CAUSE TRACE — [symptom description]

SYMPTOM:
  [error class + message]
  At: [file:line]

TRACE CHAIN:
  [symptom file:line]
    ↓ [what called it / what value]
  [intermediate file:line]
    ↓ [what called it / what value]
  [original trigger file:line]

ORIGINAL TRIGGER:
  [root cause description]
  At: [file:line]

FIX AT SOURCE:
  [what to change at the original trigger]
  Pattern: [refactor-patterns.md key if applicable]

DEFENSE-IN-DEPTH:
  Layer 1: [file:line] — [guard to add]
  Layer 2: [file:line] — [guard to add]
  Layer 3: [file:line] — [boundary validation]

NEXT: /rubysmithing:refactor [file] (pattern: [key])
```

---

## Five Whys — Full Template

**Purpose:** Iteratively ask "why" to move from surface symptoms to systemic root
causes. Use for recurring issues or when the trace chain points to a process/
architectural gap rather than a single bad value.

### Process

```
PROBLEM: [precise symptom with context]

Why 1: [immediate answer]
  ↓
Why 2: [answer to why 1]
  ↓
Why 3: [answer to why 2]
  ↓
Why 4: [answer to why 3]
  ↓
Why 5: [answer to why 4]
  ↓
ROOT CAUSE: [systemic or process cause]
```

**Validation:** Work backward — root cause should produce the symptom when you
reason forward. If it doesn't, the chain is wrong.

**Branching:** When a "why" has multiple answers, trace each branch separately.
Label branches (Branch A, Branch B) and find if they share a common root.

### Ruby-Specific Stopping Points

Stop drilling when you reach a systemic cause that requires process or architectural change:

- **Convention detection missing:** `.rubocop.yml` absent, linter not enforced in CI → process gap
- **Zeitwerk inflector not configured:** acronyms/edge cases not handled at project setup → configuration gap
- **circuit_breaker absent from class:** policy decision not made at design time → architectural gap
- **Test suite uses stubs that diverge from real gem behavior:** test design gap; stale mocks
- **No schema validation at input boundary:** data validation responsibility unassigned → architectural gap

### Five Whys Output Template

```
FIVE WHYS — [problem statement]

PROBLEM: [precise symptom]

Why 1: [immediate answer]
Why 2: [deeper cause]
Why 3: [deeper cause]
Why 4: [deeper cause]
Why 5: [systemic cause]

ROOT CAUSE: [systemic description]

VALIDATION (forward reasoning):
[root cause] → [intermediate] → [symptom] ✓

COUNTERMEASURE:
[What to change to prevent recurrence — not just fix the symptom]
Pattern: [refactor-patterns.md key if applicable]

NEXT STEPS:
- [Immediate fix] → /rubysmithing:refactor [file] (pattern: [key])
- [Systemic fix] → [architectural change or process change description]
```
