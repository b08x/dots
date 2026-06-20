# Inversion Prefix Pattern

## Overview

**Gathers user-specific context in a single Phase 0 message before any tool calls
or file loading begin.** The agent asks 3 targeted questions, stores the answers,
and uses them to drive every subsequent pipeline step — reducing wasted tool calls,
wrong pattern selections, and rework.

"Inversion" means the agent's first move is to *receive* rather than *do*. The
pipeline runs on confirmed user intent, not assumptions.

## When to Use

Add an Inversion prefix when:
- The agent can't determine scope, audience, or constraints from the invocation alone
- Different user answers would produce meaningfully different pipeline paths
- At least 2 of the 3 questions gate decisions in Step 1 or Gate 1

Do **not** add one when:
- The invocation already contains all needed context (e.g. a task with a named file)
- All users of this agent have identical needs
- You'd only ask 1 question — just ask it inline at the relevant step

## Structure

```
Phase 0 — Discovery
   │
   One message, ≤3 questions, all answered before any tool call
   │
   ▼
[store: {var1}, {var2}, {var3}]
   │
   ▼
Step 1 → Gate 1 → Step 2 → Gate 2 → ...
```

## Design Rules for Phase 0 Questions

**Rule 1 — One message, all questions.**
Never split Phase 0 into multiple `ask_user_question` calls. One message, all
questions, user replies once. This is what distinguishes Inversion from ordinary
inline questioning.

**Rule 2 — Maximum 3 questions.**
If you need more than 3 questions to begin, the agent is under-specified. Either
tighten the scope or move later questions into the relevant pipeline step.

**Rule 3 — Each question must gate at least one downstream decision.**
A question that doesn't change what happens next is noise. Before finalising each
question, identify which step or gate it influences.

**Rule 4 — Questions must be answerable without prior context.**
The user has just invoked the agent. They haven't seen any output yet. Don't ask
about things they'd need to run a tool to know.

**Rule 5 — Store every answer as a named variable.**
Each answer becomes a variable (`{var_name}`) referenced explicitly in the
pipeline steps that depend on it. Undeclared variables = dead questions.

## Phase 0 Message Format

```
🔍 [Agent Name] — Discovery
────────────────────────────────────────
Before I begin, [one sentence explaining why these questions matter]:

1. [Question 1 — determines: {what it gates}]
   [Options if single-choice, or "> " for free text]

2. [Question 2 — determines: {what it gates}]
   [Options or "> "]

3. [Question 3 — determines: {what it gates}]  ← omit if only 2 needed
   [Options or "> "]
```

Notes:
- The parenthetical "(determines: ...)" is for the *designer*, not the rendered message
- Use numbered options when there are 2–4 known answers; use `>` for free text
- Don't explain the pipeline in Phase 0 — just ask

## Integration with Pipeline Patterns

Inversion prefix is compatible with all pipeline patterns. The Phase 0 answers
feed into these pipeline points:

| Stored variable | Typically used in |
|---|---|
| Scope / target | Step 1 (what to load), Gate 1 (confirm before loading) |
| Audience | Step 3 (generation — tone, depth, format) |
| Mode / depth | Gate 2 (confirm config scope) |
| Optional feature | Step 2 (include/exclude question blocks) |

## Example — Agent Creator (this skill)

Phase 0 stores: `{agent_slug}`, `{purpose_id}`, `{skill_mode}`

- `{purpose_id}` → Step 1 (pattern recommendation lookup)
- `{agent_slug}` → Gate 1 display, all generated file names
- `{skill_mode}` → Step 2 (which skill question blocks to show)

None of these could be reliably inferred from `/agent-creator` alone.

## Example — Codebase Mapper

Phase 0 stores: `{target_dir}`, `{audience}`, `{doc_depth}`

```
🔍 Codebase Mapper — Discovery
────────────────────────────────────────
Three quick questions before I start mapping:

1. Target directory (absolute path or . for current):
   >

2. Primary audience for these docs:
   1. Internal developers — full transformation contracts, module details
   2. External / onboarding — overview + architecture, lighter module docs
   3. Stakeholders — README + architecture diagrams only

3. Is qmd indexed for this codebase?
   1. Yes — use qmd for semantic enrichment
   2. No — graphify only
   3. Not sure — skip qmd
```

## Anti-Patterns

| ❌ | ✅ |
|---|---|
| Two separate `ask_user_question` calls for Phase 0 | All questions in one message |
| Asking 6 questions "to be thorough" | Max 3; move the rest to relevant steps |
| "What format do you want?" (no impact on pipeline) | Only questions that gate a decision |
| Asking about something the agent could grep for | Only ask what requires user judgment |
| Phase 0 message with explanatory paragraphs | Short preamble, numbered questions only |

## What to Put in the Generated System Prompt

When generating an agent that uses Inversion prefix, the system prompt gets a
`## Phase 0 — Discovery` section before `## Pipeline`. It should contain:

1. The instruction to load any reference files *after* Phase 0 (not before)
2. The exact Phase 0 message script (filled with the agent's specific questions)
3. A `Store answers:` line listing the variable names
4. The rule: "Do not call any tool before Phase 0 is complete"
