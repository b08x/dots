---
promptId: classifyBartLargeMnli
name: 🏷️ Classify using BART-large-MNLI
description: Zero-shot classification using BART-large-MNLI — specify candidate_labels
tags:
  - huggingface
  - classification
  - zero-shot
version: 0.0.1
mode: replace
provider: custom
endpoint: https://api-inference.huggingface.co/models/facebook/bart-large-mnli
headers: '{ "Authorization": "Bearer {{keys.hf}}" }'
body: '{ "parameters": { "candidate_labels": ["refund", "legal", "faq"] }, "inputs": "{{escp prompt}}" }'
output: "{{requestResults.labels.[0]}}"
bodyParams:
streaming: false
---
{{selection}}
***
=={{output}}==