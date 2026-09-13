---
promptId: pronounReplacement
name: 🔁 Pronoun Replacement in Text Rewriting
description: Rewrite content to avoid using first-person singular pronouns
tags:
  - text-rewriting
  - pronoun-replacement
  - editing
version: 0.0.1
mode: replace
---
text:
{{selection}}

Please rewrite the following text to avoid using first-person singular pronouns like "I", "me", and "my":

For example:

- Instead of "I went to the store", write "The author went to the store".
- Instead of "My dog is cute", write "The dog is cute".
- Instead of "That's what I think", write "That's what the author thinks".

Rewrite the full content, avoiding use of first-person singular pronouns or any synonyms or similar phrases. Do not use the author's name. Refer to the author in the third-person as "the author" if needed.

Output your rewritten version inside <rewritten_content> tags.
