# Full Integration Example: Research Crew with Contextual RAG

## crew.py

```python
from crewai import Agent, Crew, Process, Task
from crewai.project import CrewBase, agent, crew, task
from crewai import LLM
from typing import List
from crewai.agents.agent_builder.base_agent import BaseAgent

# Import custom tools (defined in tools/ directory)
from .tools.contextual_rag import ContextualRAGTool
from .tools.spacy_nlp import SpacyNLPTool
from .tools.query_expander import QueryExpanderTool

@CrewBase
class ContextualResearchCrew:
    agents: List[BaseAgent]
    tasks: List[Task]

    agents_config = "config/agents.yaml"
    tasks_config = "config/tasks.yaml"

    @agent
    def research_analyst(self) -> Agent:
        return Agent(
            config=self.agents_config["research_analyst"],
            tools=[
                SpacyNLPTool(),
                ContextualRAGTool(embeddings=self._get_embeddings()),
            ],
            llm=LLM(model="openai/gpt-4o"),
            verbose=True,
            max_iter=20,
        )

    @agent
    def synthesis_writer(self) -> Agent:
        return Agent(
            config=self.agents_config["synthesis_writer"],
            llm=LLM(model="openai/gpt-4o"),
            verbose=True,
        )

    @task
    def research_task(self) -> Task:
        return Task(config=self.tasks_config["research_task"])

    @task
    def synthesis_task(self) -> Task:
        return Task(config=self.tasks_config["synthesis_task"])

    @crew
    def crew(self) -> Crew:
        return Crew(
            agents=self.agents,
            tasks=self.tasks,
            process=Process.sequential,
            verbose=True,
        )

    def _get_embeddings(self):
        import txtai
        embeddings = txtai.Embeddings(hybrid=True, path="sentence-transformers/all-MiniLM-L6-v2")
        # Index your corpus here or load pre-built index
        return embeddings
```

## config/agents.yaml

```yaml
research_analyst:
  role: >
    Senior Research Analyst specializing in {topic}
  goal: >
    Find comprehensive, verified information about {topic} using
    semantic search and NLP-enhanced retrieval
  backstory: >
    You are an expert researcher who uses advanced search tools
    to find relevant information. You analyze entities and concepts
    in queries to improve retrieval accuracy. You always verify
    findings across multiple sources.

synthesis_writer:
  role: >
    Technical Writer and Synthesizer
  goal: >
    Transform research findings into clear, well-structured reports
  backstory: >
    You excel at distilling complex research into actionable insights.
    You maintain source attribution and highlight confidence levels.
```

## config/tasks.yaml

```yaml
research_task:
  description: >
    Research {topic} thoroughly. Use the text_analysis tool to extract
    key entities and concepts from the query, then use contextual_rag_search
    to find relevant passages. Verify findings across multiple searches.
  expected_output: >
    A structured research brief with: key findings (with source scores),
    identified entities and relationships, confidence assessment per finding,
    and suggested areas for deeper investigation.
  agent: research_analyst

synthesis_task:
  description: >
    Synthesize the research findings into a polished report for {topic}.
    Organize by theme, cite sources, and note confidence levels.
  expected_output: >
    A well-structured report in markdown with: executive summary,
    key findings organized by theme, source citations, and conclusion.
  agent: synthesis_writer
  output_file: output/report.md
```

## main.py

```python
from contextual_research_crew.crew import ContextualResearchCrew
from rich.console import Console

console = Console()

def run():
    topic = "latest developments in multi-agent AI systems"
    console.print(f"[bold]Researching:[/] {topic}\n")

    result = ContextualResearchCrew().crew().kickoff(inputs={"topic": topic})

    console.print("\n[bold green]Research Complete![/]")
    console.print(result.raw)

if __name__ == "__main__":
    run()
```
