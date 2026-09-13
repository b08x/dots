---
name: 🗞️ Markdown Refactor
description: Templates for cleaning malformatted markdown
---
# Markdown Refactor Templates

Templates for cleaning malformatted markdown.

**Verified provider IDs** from `src/LLMProviders/index.ts`:
- `"OpenAI Chat (Langchain)"` — OpenAI GPT models
- `"MistralAI Chat (Langchain)"` — Mistral AI models
- `"Huggingface (Langchain)"` — HuggingFace Inference API
- `"Default (Custom)"` — Custom OpenAI-compatible endpoints (OpenRouter, etc.)

---

## Frontmatter Format (Verified)

```yaml
---
config:
  provider: "OpenAI Chat (Langchain)"
  model: gpt-4o
  max_tokens: 4096
  temperature: 0.3
  stream: true
---
```

**Note:** Chain-based processing (`chain.type: map_reduce/refine`) requires
`@langchain/classic` which may not be installed. These templates use direct
LLM invocation instead.

---

## Templates

### `markdown-cleanup.md`

General-purpose markdown cleanup. Select text, run template, get cleaned output. Uses default provider settings — configure your provider in plugin settings.

### `artifact-remover.md`

Detailed cleanup with explicit preserve rules. Larger `max_tokens` (8192) for long documents.

---

## Provider Setup

### OpenRouter

Uses Custom provider. In plugin settings:
1. Set endpoint: `https://openrouter.ai/api/v1/chat/completions`
2. Set API key
3. Add headers: `HTTP-Referer: https://obsidian.md`

### Mistral AI

1. Get API key from [console.mistral.ai](https://console.mistral.ai/users/)
2. Enter in plugin settings under MistralAI provider

### HuggingFace

1. Get token from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
2. Enter in plugin settings under HuggingFace provider
3. **Streaming not supported** — use `stream: false`

---

## Configuration Reference

### Provider IDs (Verified)

| Provider | ID | Slug |
|----------|-----|------|
| OpenAI Chat | `"OpenAI Chat (Langchain)"` | `openaiChat` |
| OpenAI Instruct | `"OpenAI Instruct (Langchain)"` | `openaiInstruct` |
| Anthropic | `"ChatAnthropic (Langchain)"` | `chatanthropic` |
| Mistral AI | `"MistralAI Chat (Langchain)"` | `mistralAIChat` |
| HuggingFace | `"Huggingface (Langchain)"` | `hf` |
| Google Generative AI | `"Google GenerativeAI (Langchain)"` | `googleGenerativeAI` |
| Ollama | `"Ollama (Langchain)"` | `ollama` |
| Perplexity | `"Perplexity Chat (Langchain)"` | `perplexityChat` |
| Together AI | `"Together AI Chat (Langchain)"` | `togetherChat` |
| Custom | `"Default (Custom)"` | `custom` |

### Temperature

- `0.2` — Conservative, preserves exact content (recommended)
- `0.3` — Slight creativity for formatting decisions
- `0.5+` — More creative rewrites (not recommended for cleanup)

---

## Troubleshooting

### Output is truncated
- Increase `max_tokens` in frontmatter
- For very long documents, process in sections (select part at a time)

### Formatting not consistent
- Try a different template with different prompt wording

### OpenRouter returns 401
- Verify API key is set in Custom provider settings
- Check that headers include `Authorization: Bearer YOUR_KEY`
- Ensure endpoint is `https://openrouter.ai/api/v1/chat/completions`

### HuggingFace streaming error
- Set `stream: false` in frontmatter (HF Inference doesn't support streaming)
- Use a model that supports the `/v1/chat/completions` endpoint for streaming
