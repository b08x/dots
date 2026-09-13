---
promptId: summarizeBART
name: 📰 Summarize Text using BART Facebook
description: Summarize text using Facebook BART-large-CNN model
tags:
  - huggingface
  - text-summarization
version: 0.0.3
mode: replace
provider: custom
endpoint: https://api-inference.huggingface.co/models/facebook/bart-large-cnn
headers: '{ "Authorization": "Bearer {{keys.hf}}" }'
body: '{ "inputs": "{{escp prompt}}" }'
output: "{{requestResults.[0].summary_text}}"
bodyParams:
streaming: false
---
{{selection}}
***
{{output}}