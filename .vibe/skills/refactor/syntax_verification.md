---
name: ruby-syntax
description: "Use when code has syntax errors or suspected recursive loops. Leverages `syntax_suggest` for precision debugging."
version: 1.0.0
---

# Ruby Syntax Verification

This skill provides the "conduit" logic for identifying and fixing syntax errors and "Strange Loop" recursive failures.

## Core Mandates
- **Precision:** Use `syntax_suggest` to find the *exact* missing `end` or mismatched bracket.
- **Recursive Safety:** If a `RecursionDepthError` or similar is detected, analyze the call stack before attempting a fix.
- **Minimal Invasive:** Only touch the lines identified as broken.

## Workflow
1.  **Detect:** Run `ruby -c <file>` to confirm a syntax error.
2.  **Pinpoint:** Run `syntax_suggest <file>` to get a localized snippet of the error.
3.  **Trace (Logic):** If the syntax is valid but the code hangs, use `irb` or `pry` to step through the execution.
4.  **Fix:** Apply the surgical edit.
5.  **Validate:** Run `ruby -c <file>` again.

## Tools
- `syntax_suggest`: The primary tool for pinpointing syntax issues.
- `ruby -c`: Quick check for valid syntax.
- `irb` / `pry`: For interactive debugging of logic loops.

## Common Pitfalls
- **Incorrect Suggestion:** Sometimes `syntax_suggest` points to the *result* of a missing `end` further up. Check the indentation.
- **Recursive Hallucination:** Agents can get caught in their own loops when analyzing recursive code. Always set a timeout on the analysis tool.

## Verification Checklist
- [ ] `ruby -c` returns "Syntax OK".
- [ ] Indentation is consistent with the fix.
- [ ] The logic loop (if any) has been broken with a proper guard clause.
