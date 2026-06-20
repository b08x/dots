# Multi-Agent Flow Orchestration

## Flow with Crew Dependencies

```python
from crewai import Crew, Process, Task
from crewai.flow.flow import Flow, start, listen, router
from pydantic import BaseModel

class ResearchState(BaseModel):
    topic: str = ""
    raw_findings: str = ""
    verified_facts: list[str] = []
    final_report: str = ""

class ResearchFlow(Flow[ResearchState]):
    @start()
    def gather_research(self):
        """Run the research crew first."""
        result = ResearchCrew().crew().kickoff(inputs={"topic": self.state.topic})
        self.state.raw_findings = result.raw
        return result.raw

    @listen(gather_research)
    def verify_findings(self, findings):
        """Run fact-checking crew on research output."""
        result = FactCheckCrew().crew().kickoff(inputs={"findings": findings})
        self.state.verified_facts = result.raw
        return result.raw

    @router(verify_findings)
    def assess_quality(self, verified):
        """Route based on quality score."""
        if len(self.state.verified_facts) >= 3:
            return "sufficient"
        return "needs_more_research"

    @listen("sufficient")
    def synthesize_report(self):
        """Final synthesis crew."""
        result = SynthesisCrew().crew().kickoff(
            inputs={"findings": self.state.raw_findings, "facts": str(self.state.verified_facts)}
        )
        self.state.final_report = result.raw
        return result.raw

    @listen("needs_more_research")
    def deepen_research(self):
        """Re-run with refined query."""
        return self.gather_research()

# Run the flow
flow = ResearchFlow()
flow.state.topic = "multi-agent AI systems"
result = flow.kickoff()
```

## Human-in-the-Loop (v1.8.0+)

```python
from crewai.flow.flow import Flow, start, listen, or_
from crewai.flow.human_feedback import human_feedback, HumanFeedbackResult
from pydantic import BaseModel

class ReviewState(BaseModel):
    draft: str = ""
    status: str = "pending"

class ReviewedFlow(Flow[ReviewState]):
    @start()
    def draft(self):
        result = DraftCrew().crew().kickoff(inputs={"topic": self.state.topic})
        self.state.draft = result.raw
        return result.raw

    @human_feedback(
        message="Please review this draft. Approve, reject, or describe changes:",
        emit=["approved", "rejected", "needs_revision"],
        llm="gpt-4o-mini",
        default_outcome="needs_revision",
    )
    @listen(or_("draft", "needs_revision"))
    def review(self):
        return self.state.draft

    @listen("approved")
    def publish(self, result: HumanFeedbackResult):
        self.state.status = "published"
        return f"Published! Reviewer said: {result.feedback}"

    @listen("rejected")
    def discard(self, result: HumanFeedbackResult):
        self.state.status = "rejected"
        return f"Rejected: {result.feedback}"

    @listen("needs_revision")
    def revise(self, result: HumanFeedbackResult):
        revision = RevisionCrew().crew().kickoff(
            inputs={"draft": self.state.draft, "feedback": result.feedback}
        )
        self.state.draft = revision.raw
        return revision.raw
```

## Flow State Persistence (v1.8.0+)

```python
from crewai.flow.flow import Flow, start
from crewai.flow.persistence import persist
from pydantic import BaseModel

class MyState(BaseModel):
    data: str = ""

@persist()  # SQLite-backed state persistence (note: parentheses required)
class PersistentFlow(Flow[MyState]):
    @start()
    def step_one(self):
        # State survives restarts — automatically loaded on next run
        self.state.data = "persisted value"
```

## DSPy-Optimized Agent Prompts

Use DSPy to optimize the prompts your CrewAI agents use, then inject the optimized signatures as tools or task descriptions.

### Pattern: DSPy Signatures as CrewAI Tools

```python
import dspy

class QueryExpansion(dspy.Signature):
    """Expand a user query into multiple search perspectives."""
    query = dspy.InputField()
    expanded_queries: list[str] = dspy.OutputField(desc="3-5 alternative phrasings")

class QueryExpanderTool(BaseTool):
    name: str = "query_expander"
    description: str = (
        "Expand a research query into multiple search perspectives "
        "for comprehensive retrieval. Use before searching to improve recall."
    )
    args_schema: Type[BaseModel] = QueryExpanderInput

    def __init__(self, lm=None, **kwargs):
        super().__init__(**kwargs)
        if lm:
            dspy.configure(lm=lm)
        self._expander = dspy.Predict(QueryExpansion)

    def _run(self, query: str) -> str:
        result = self._expander(query=query)
        return "Expanded queries:\n" + "\n".join(
            f"  - {q}" for q in result.expanded_queries
        )
```

### Pattern: DSPy RAG Module Wrapped as Tool

```python
class CrewAIRAGWithDSPy(BaseTool):
    name: str = "optimized_rag"
    description: str = "Answer questions using optimized retrieval-augmented generation."
    args_schema: Type[BaseModel] = RAGInput

    def __init__(self, rag_module: dspy.Module, **kwargs):
        super().__init__(**kwargs)
        self._rag = rag_module

    def _run(self, question: str) -> str:
        result = self._rag(question=question)
        return f"Answer: {result.answer}\nSources: {result.context[:200]}"
```

See the `dspy` skill for full DSPy module/optimizer patterns.
