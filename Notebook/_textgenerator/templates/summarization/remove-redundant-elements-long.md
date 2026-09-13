---
promptId: removeRedundantElementsLong
name: ✂️ Remove Redundant Elements (Long)
description: Parse a long transcript and remove redundancies while preserving meaning
tags:
  - text-analysis
  - document-processing
  - editing
  - writing
version: 0.0.1
mode: replace
system: Analyze the text for redundancies. Remove them while preserving the original meaning and ensuring the final text is clear.
---

{{#each headings}}

## HEADER: {{@key}}

{{this}}

{{/each}}

output:
