---
name: refactor
description: "Use when applying named refactoring patterns to Ruby code. Matches code issues to known transformations (Zeitwerk, async, frozen strings, etc.) and applies surgical fixes."
user-invocable: true
---

# RubyDev Refactor — Named Pattern Refactoring

## Overview

Refactoring by hand is error-prone and inconsistent. The refactor skill matches code issues to named transformation patterns, then applies surgical fixes. Each pattern has a defined before/after shape, severity rating, and affected areas.

The pattern catalog lives in `~/.vibe/skills/refactor/references/refactor-patterns.md` — load it for the full list of available transforms. It covers three families: mechanical fixes (Zeitwerk, frozen strings, async), **OO design refactorings** (extract class, inject dependency, duck types, composition — warrants in [~/.vibe/skills/ruby-dev/~/.vibe/skills/refactor/references/ood-principles.md](~/.vibe/skills/ruby-dev/~/.vibe/skills/refactor/references/ood-principles.md)), and **resilience patterns** (backoff with jitter, fail-closed authorization, bang saves).

## When to Use

- `analyse` or `sift` identified a specific code issue (e.g., Zeitwerk mismatch, bare rescue, missing circuit breaker)
- You need to apply a known transformation like `thread_to_async` or `nested_conditionals`
- User says "fix this" with a clear symptom that matches an existing pattern
- Code review flagged a violation that has a mechanical fix

**Don't use for:**
- Exploratory code changes without a diagnosis (run [analyse/SKILL.md](~/.vibe/skills/analyse/SKILL.md) first)
- Large-scale redesigns that change architecture (use the [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md) instead)
- Stylistic formatting that RuboCop handles better

## Pattern Selection

Each pattern in `~/.vibe/skills/refactor/references/refactor-patterns.md` has:

| Field | Description |
|-------|-------------|
| `pattern` | Machine key (e.g., `zeitwerk_mismatch`) — also the YAML report key |
| `severity` | CRITICAL, MAJOR, MINOR |
| `area` | Affected concern (async, config, naming, resilience, etc.) |
| `before` | Code before transformation |
| `after` | Code after transformation |
| `conditions` | Optional pre-conditions (Ruby version, gem availability) |

### Selection Heuristic

Match code smell → pattern name → load the exact transform. Fall back to a custom fix only when no named pattern covers the issue.

1. Read the error or symptom from analyse/sift output
2. Check the pattern name in `~/.vibe/skills/refactor/references/refactor-patterns.md` table of contents
3. Load the matching pattern
4. Apply the before→after transformation
5. Run `ruby -c` and tests to verify

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| `~/.vibe/skills/refactor/references/refactor-patterns.md` | Pattern file not found | Apply the fix manually based on general Ruby best practices. Note the missing pattern file in the output. |
| [analyse/SKILL.md](~/.vibe/skills/analyse/SKILL.md) | Precursor diagnosis missing | Ask the user or the orchestrator for the specific issue. If none available, inspect the code for common issues (Zeitwerk, rescue, frozen_string_literal). |
| `ruby -c` / tests | Verification tools missing | Provide the transformed code and note that syntax/tests were not verified. |

## Common Pitfalls

1. **Applying a pattern without diagnosis**: A pattern fixes one thing; if you don't know the root cause, you might fix a symptom. Always run [analyse/SKILL.md](~/.vibe/skills/analyse/SKILL.md) first.
2. **Pattern mismatch**: A `zeitwerk_mismatch` fix might look similar to a `hardcoded_config` fix. Verify the exact issue before applying.
3. **Forgetting verification**: Always run `ruby -c` after refactoring. Patterns can introduce syntax errors if the match was inexact.
4. **Over-applying `--max` patterns**: Not every pattern applies to every codebase. Pick the pattern that matches the specific issue.
5. **Ignoring context lines**: The before/after in refactor-patterns.md shows minimal context. Real code may need surrounding structure preserved.

## Verification Checklist

- [ ] Issue identified by analyse or user matches a named pattern
- [ ] Pattern loaded and before/after understood
- [ ] Surgical fix applied (not a blanket transformation)
- [ ] `ruby -c` passes on all modified files
- [ ] Tests pass (if available)
- [ ] Result reported back to the caller (analyse/sift/orchestrator)