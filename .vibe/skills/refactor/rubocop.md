---
name: ruby-styler
description: "Use when code needs formatting, linting, or style corrections. Automates RuboCop execution and surgical fixes."
version: 1.0.0
---

# Ruby Styler (RuboCop)

This skill provides the logic for the `ruby-styler` profile to maintain high-quality Ruby code standards.

## Core Mandates
- **Surgical Edits:** Prefer fixing specific RuboCop violations over running `--auto-correct` on the entire file.
- **Consistency:** Always check for a local `.rubocop.yml` before applying changes.
- **Non-Destructive:** Ensure that styling changes do not alter the logic of the code.

## Workflow
1.  **Analyze:** Run `rubocop <file>` to identify violations.
2.  **Filter:** Focus on `Layout` and `Style` departments first.
3.  **Execute:** Apply fixes using `rubocop -a <file>` or manual `replace` calls.
4.  **Verify:** Run `rubocop <file>` again to confirm the fix.

## Tools
- `rubocop`: The primary linter.
- `prettier`: For combined Ruby/HTML/JS styling if applicable.

## Common Pitfalls
- **Over-Correction:** Avoid fixing "Style" violations that are intentionally ignored in the local context.
- **Breaking Logic:** Be careful with `Lint/UselessAssignment` or `Lint/ShadowingOuterLocalVariable` - these can be structural.

## Verification Checklist
- [ ] `rubocop` returns no offenses for the target file.
- [ ] Tests pass (if available).
- [ ] Code is more readable but functionally identical.
