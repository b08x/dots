---
name: crewai
description: Use when building CrewAI crews with custom tools, contextual RAG pipelines, or multi-agent orchestration flows. Covers @CrewBase patterns, custom tool creation, DSPy/txtai/spaCy integration, Textual/Rich UX, and Flow-based orchestration.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [crewai, multi-agent, rag, dspy, txtai, spacy, textual, rich, orchestration, custom-tools, flows]
    related_skills: [dspy, writing-plans, subagent-driven-development]
---

# CrewAI: Custom Tools, Contextual RAG, and Multi-Agent Orchestration

## Overview

Build production-grade CrewAI systems with custom tools, contextual RAG pipelines powered by DSPy/txtai/spaCy, multi-agent orchestration via Flows, and terminal UX via Textual/Rich. This skill covers patterns beyond the basics — integrating specialized libraries into the CrewAI agent lifecycle.

**Prerequisites:** CrewAI >= 0.100.0, Python >= 3.10, < 3.14. Always check installed version before writing code:
```bash
uv run python -c "import crewai; print(crewai.__version__)"
```

## When to Use

- Creating custom CrewAI tools that wrap external libraries (txtai, spaCy, DSPy)
- Building contextual RAG pipelines where retrieval feeds agent reasoning
- Orchestrating multiple crews via Flow with state management
- Adding terminal UX (progress, panels, tables) via Rich/Textual to crew output
- Integrating NLP preprocessing (NER, classification, similarity) into agent tools

**Don't use for:**
- Simple crews with built-in tools only (use vanilla CrewAI patterns from AGENTS.md)
- Prompt-only tasks with no retrieval or tool augmentation
- Web UIs (this skill focuses on terminal UX)

## Custom Tool Creation

### Base Pattern

All custom tools inherit from `crewai.tools.BaseTool` with Pydantic v2:

```python
from crewai.tools import BaseTool
from pydantic import BaseModel, Field
from typing import Type

class MyToolInput(BaseModel):
    """Input schema for the tool."""
    query: str = Field(description="The search query")
    max_results: int = Field(default=5, description="Maximum results to return")

class MyTool(BaseTool):
    name: str = "my_tool"
    description: str = "Clear description of what this tool does and when the agent should use it."
    args_schema: Type[BaseModel] = MyToolInput

    def _run(self, query: str, max_results: int = 5) -> str:
        # Tool implementation
        return "result"
```

### Key Rules
- `description` is critical — agents decide when to use the tool based on it
- `args_schema` uses Pydantic v2 `Field` with `description` for every param
- Return `str` — agents consume text output
- Use `self._run()` not `run()` — the base class handles logging/caching
- Tools go on agents, not tasks, unless task-specific override is needed

### Registering Tools on Agents

```python
@CrewBase
class MyCrew:
    agents: List[BaseAgent]
    tasks: List[Task]

    agents_config = "config/agents.yaml"
    tasks_config = "config/tasks.yaml"

    @agent
    def researcher(self) -> Agent:
        return Agent(
            config=self.agents_config["researcher"],
            tools=[MyTool(), AnotherTool()],
            verbose=True,
        )
```

## Contextual RAG with txtai + spaCy

Build NLP-enhanced retrieval pipelines: spaCy extracts entities and keywords from queries, txtai performs hybrid semantic+BM25 search, and a combined tool reranks results by entity overlap.

**Three tool patterns:**
- `TxtaiSearchTool` — semantic search with hybrid BM25 over indexed corpus
- `SpacyNLPTool` — NER, keyword extraction, text analysis
- `ContextualRAGTool` — combined entity-aware retrieval with reranking

See `references/contextual-rag.md` for complete tool implementations with architecture diagram.

## DSPy-Optimized Agent Prompts

Use DSPy to optimize the prompts your CrewAI agents use, then inject the optimized signatures as tools or task descriptions.

**Two patterns:**
- `QueryExpanderTool` — DSPy Signature wrapped as a CrewAI tool for multi-perspective query expansion
- `CrewAIRAGWithDSPy` — DSPy RAG module wrapped as a CrewAI tool for optimized retrieval-augmented generation

See `references/flow-orchestration.md` for DSPy integration code and the `dspy` skill for full module/optimizer patterns.

## Multi-Agent Orchestration with Flows

CrewAI Flows provide event-driven orchestration of multiple crews with state management.

**Key patterns:**
- **Flow with Crew Dependencies** — chain crews via `@start()`, `@listen()`, `@router()`
- **Human-in-the-Loop** — `@human_feedback` with `emit` outcomes and `HumanFeedbackResult` (v1.8.0+)
- **Flow State Persistence** — `@persist()` decorator for SQLite-backed state across runs (v1.8.0+)

```python
from crewai.flow.flow import Flow, start, listen, router
from crewai.flow.human_feedback import human_feedback, HumanFeedbackResult
from crewai.flow.persistence import persist
```

See `references/flow-orchestration.md` for complete Flow examples.

## Terminal UX with Rich and Textual

Add formatted output and interactive interfaces to your crews.

**Rich patterns:**
- `Panel` + `Markdown` for crew result display
- `Table` for agent metrics (tokens, timing)
- `Progress` + `SpinnerColumn` for long-running crew execution
- `Tree` for Flow structure visualization

**Textual patterns:**
- `App` + `compose()` for interactive crew runner
- `Input` + `Button` + `Static` for topic entry and output display
- CSS styling for layout

See `references/terminal-ux.md` for complete Rich/Textual implementations.

## Full Integration Example

A complete research crew combining contextual RAG, custom tools, YAML config, and Rich output — `crew.py`, `agents.yaml`, `tasks.yaml`, `main.py`.

See `references/full-integration-example.md` for the full working example.

## Common Pitfalls

1. **Using `ChatOpenAI()` or `from langchain.chat_models`.** Always use `crewai.LLM` or string shorthand like `"openai/gpt-4o"`. LangChain ChatOpenAI is deprecated in CrewAI.

2. **Forgetting `# type: ignore[index]` on config access.** Every `self.agents_config["key"]` and `self.tasks_config["key"]` needs the type ignore comment.

3. **Tool description too vague.** Agents pick tools based on description. "Search documents" is bad. "Search the knowledge base using semantic similarity. Returns the most relevant document passages for a query. Use this when you need to find specific information in the corpus." is good.

4. **Not returning strings from tools.** Tools must return `str`. Returning dicts or objects breaks the agent loop. Use `json.dumps()` if structured data is needed.

5. **Loading spaCy models at import time.** Use `__init__` on the tool class, not module-level `spacy.load()`. Module-level loading breaks CrewAI's tool discovery.

6. **txtai index not persisted.** If you build the index at runtime, save it with `embeddings.save("index_path")` and load with `embeddings.load("index_path")` on subsequent runs. Re-indexing every time is expensive.

7. **Using `process=Process.hierarchical` without `manager_llm`.** Hierarchical process requires either `manager_llm=LLM(...)` or `manager_agent=Agent(...)` on the Crew.

8. **Flow state mutation without Pydantic.** Always use a Pydantic `BaseModel` for Flow state. Raw dicts lose type safety and break persistence.

9. **Textual app blocking crew execution.** CrewAI runs synchronously. Use `app.run_async()` or `Worker` threads if you need the Textual UI to remain responsive during long crew runs.

10. **Skipping the version check.** CrewAI API changes fast. Always verify `crewai.__version__` and check docs before coding against a feature.

## Verification Checklist

- [ ] `uv run python -c "import crewai; print(crewai.__version__)"` matches expected version
- [ ] All LLM references use `crewai.LLM` or string shorthand (no LangChain ChatOpenAI)
- [ ] Custom tools inherit `BaseTool`, return `str`, have descriptive `description`
- [ ] Config dictionary access uses `# type: ignore[index]`
- [ ] Agent/task method names match YAML keys exactly
- [ ] `expected_output` present in every task config
- [ ] spaCy models loaded in `__init__`, not at module level
- [ ] txtai embeddings indexed once, loaded thereafter
- [ ] Flow state uses Pydantic `BaseModel`
- [ ] Rich/Textual imports are optional (graceful fallback if not installed)
- [ ] `uv lock` committed after adding new dependencies

## Quick Reference

### Dependencies

```bash
# Core
uv add crewai crewai-tools

# Contextual RAG stack
uv add txtai spacy
uv run python -m spacy download en_core_web_sm

# DSPy integration
uv add dspy

# Terminal UX
uv add rich textual

# Optional: larger spaCy models for better NER
uv run python -m spacy download en_core_web_trf
```

### File Layout

```
my_crew/
├── src/my_crew/
│   ├── config/
│   │   ├── agents.yaml
│   │   └── tasks.yaml
│   ├── tools/
│   │   ├── contextual_rag.py    # ContextualRAGTool
│   │   ├── spacy_nlp.py         # SpacyNLPTool
│   │   ├── txtai_search.py      # TxtaiSearchTool
│   │   └── query_expander.py    # QueryExpanderTool (DSPy)
│   ├── crew.py                  # @CrewBase class
│   ├── main.py                  # Entry point
│   └── ux.py                    # Rich/Textual display helpers
├── knowledge/                   # Corpus for txtai indexing
├── output/                      # Task output files
├── .env
└── pyproject.toml
```

## See Also

- `references/contextual-rag.md` — txtai + spaCy tool implementations
- `references/flow-orchestration.md` — Flow, human_feedback, persist, DSPy patterns
- `references/terminal-ux.md` — Rich/Textual display and interactive apps
- `references/full-integration-example.md` — Complete working crew example
- `dspy` skill — Full DSPy module/optimizer patterns for prompt optimization
- `writing-plans` skill — Plan multi-step crew implementations before coding
- `subagent-driven-development` skill — Dispatch and review crew implementation tasks
