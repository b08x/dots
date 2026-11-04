---
name: genai
description: "Use when building LLM-backed components in Python: typed agents with pydantic-ai, provider-neutral calls with litellm, structured output with instructor, DSPy programs and optimizers (GEPA or MIPROv2), MCP servers and clients with FastMCP, and embedding generation (storage and search belong to db-engineer). Loaded by the implementer when the brief names genai, dspy, pydantic-ai, litellm, instructor, or FastMCP."
---

# GenAI: LLM Components in Python

Every LLM call is typed at both ends: the input is a pydantic model, and the output is a validated model. The model provider is a configuration value, not a code path.

## Verify APIs before use

Use Context7 to fetch the current signature of each library at the point of use. Library APIs in this area change between releases. Do not write a call from memory.

## Libraries and when to use each

| Need | Library | Rule |
|---|---|---|
| Typed agent with tools and dependencies | `pydantic-ai` | Dependencies injected through a typed `deps` object; tools validated by pydantic. |
| One call API across providers | `litellm` | The model name is a setting. No provider-specific code in business logic. |
| Structured output from any model | `instructor` | Response model is a pydantic class. Retries on validation errors. |
| Optimized prompts and few-shot programs | `dspy` 3.2 or later | Signatures declare inputs and outputs; optimizers compile the program. |
| Tool servers and clients | `FastMCP` (`mcp` package) | Tools declared with `@mcp.tool()`; the type hints are the schema. |
| Embeddings | Generation only, in this skill | Storage and search follow `db-engineer`. |

## Structured output contract

```python
from __future__ import annotations

from pydantic import BaseModel, ConfigDict


class Ticket(BaseModel):
    """A triaged support ticket."""

    model_config = ConfigDict(frozen=True, strict=True, extra="forbid")

    category: str
    priority: int
    summary: str
```

Every LLM boundary has one model in and one model out. A test sends a fixture response that fails validation and asserts that the call raises or retries, as the library documents.

## DSPy: choosing the optimizer

The choice is between two optimizers. The decision rule is in the implementer role skill and is repeated here for the genai path:

- **`dspy.GEPA`**: use when the metric can return `dspy.Prediction(score=float, feedback=str)` and the labeled set has roughly 20 to 100 examples. GEPA reads the feedback through a reflection model. Set `reflection_lm` to a strong model and the task model to a cheap one, because reflection runs rarely and evaluation runs often.
- **`dspy.MIPROv2`**: use for a scalar-only metric, or a larger training set where few-shot bootstrapping dominates.

A plain-scalar metric passed to GEPA still runs, but it discards the feedback channel. The optimizer then sees only "This trajectory got a score of N". Do not do this silently. If the metric cannot produce feedback, choose MIPROv2 and say why.

## Metrics for optimization

- Return a float in `[0, 1]` for the scalar part.
- For GEPA, also return a feedback string that names the failing field and the expected value.
- Keep the metric deterministic. A metric that calls an LLM needs its own evaluation.

## Testing

- Unit tests replace the model with a fake that returns fixed output. The fake lives in `tests/fakes/`.
- Integration tests that call a real provider live under `tests/integration/` and run in a separate command. The default suite never contacts a provider, so it needs no key.
- The secret key comes from `pydantic-settings` as `SecretStr`. See `environment-variables.md`.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Output fails validation intermittently | Schema is looser than the prompt | Tighten the model; add an example to the signature |
| Optimizer score does not move | Metric returns a constant | Check the metric on three known examples before optimizing |
| Provider switch changes output shape | Code reads provider-specific fields | Read only the validated model |
| Cost spikes in tests | Real model called in a unit test | Replace the model with the fake |

## Related

- `db-engineer` for storing and querying embeddings.
- `nlp` for classical retrieval scoring (BM25, TF-IDF), which is not LLM work.
- `implementer` role skill for the GEPA and MIPROv2 rule in the brief.
