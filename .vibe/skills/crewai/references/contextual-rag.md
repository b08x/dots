# Contextual RAG with txtai + spaCy

## Architecture

```
User Query
    |
    v
[spaCy NLP Preprocessing]  -- NER, lemmatization, entity linking
    |
    v
[txtai Semantic Index]     -- vector search + hybrid BM25
    |
    v
[Context Assembly]          -- top-k passages + metadata
    |
    v
[CrewAI Agent]              -- reasoning over retrieved context
```

## txtai Embeddings Tool

```python
from crewai.tools import BaseTool
from pydantic import BaseModel, Field
from typing import Type
import txtai

class TxtaiSearchInput(BaseModel):
    query: str = Field(description="Natural language search query")
    top_k: int = Field(default=5, description="Number of results")

class TxtaiSearchTool(BaseTool):
    name: str = "semantic_search"
    description: str = (
        "Search the knowledge base using semantic similarity. "
        "Returns the most relevant document passages for a query. "
        "Use this when you need to find specific information in the corpus."
    )
    args_schema: Type[BaseModel] = TxtaiSearchInput

    def __init__(self, index_path: str = None, documents: list = None, **kwargs):
        super().__init__(**kwargs)
        self._embeddings = txtai.Embeddings(
            hybrid=True,
            path="sentence-transformers/all-MiniLM-L6-v2"
        )
        if index_path:
            self._embeddings.load(index_path)
        elif documents:
            self._embeddings.index(documents)

    def _run(self, query: str, top_k: int = 5) -> str:
        results = self._embeddings.search(query, top_k)
        formatted = []
        for i, (text, score) in enumerate(results):
            formatted.append(f"[{i+1}] (score: {score:.3f}) {text}")
        return "\n\n".join(formatted) if formatted else "No relevant results found."
```

## spaCy NLP Preprocessing Tool

```python
import spacy
from crewai.tools import BaseTool
from pydantic import BaseModel, Field
from typing import Type

class SpacyNLPInput(BaseModel):
    text: str = Field(description="Text to analyze")
    analysis_type: str = Field(
        default="entities",
        description="Type of analysis: 'entities', 'keywords', 'summary'"
    )

class SpacyNLPTool(BaseTool):
    name: str = "text_analysis"
    description: str = (
        "Analyze text using NLP to extract entities, keywords, or structural info. "
        "Use before searching to identify key terms, names, and concepts."
    )
    args_schema: Type[BaseModel] = SpacyNLPInput

    def __init__(self, model: str = "en_core_web_sm", **kwargs):
        super().__init__(**kwargs)
        self._nlp = spacy.load(model)

    def _run(self, text: str, analysis_type: str = "entities") -> str:
        doc = self._nlp(text)

        if analysis_type == "entities":
            entities = [(ent.text, ent.label_) for ent in doc.ents]
            if not entities:
                return "No named entities found."
            return "Entities:\n" + "\n".join(
                f"  - {text} ({label})" for text, label in entities
            )

        elif analysis_type == "keywords":
            # Extract noun chunks as keywords
            keywords = list(set(chunk.root.lemma_ for chunk in doc.noun_chunks))
            return "Keywords: " + ", ".join(keywords[:15])

        elif analysis_type == "summary":
            sentences = list(doc.sents)
            return f"Sentences: {len(sentences)}, Tokens: {len(doc)}, " \
                   f"Entities: {len(list(doc.ents))}, " \
                   f"First sentence: {sentences[0].text if sentences else 'N/A'}"

        return f"Unknown analysis_type: {analysis_type}"
```

## Combined RAG Tool (txtai + spaCy)

```python
class ContextualRAGInput(BaseModel):
    query: str = Field(description="Research question or topic")
    top_k: int = Field(default=5, description="Number of passages to retrieve")

class ContextualRAGTool(BaseTool):
    name: str = "contextual_rag_search"
    description: str = (
        "Search the knowledge base with NLP-enhanced retrieval. "
        "Automatically extracts key entities and concepts from the query, "
        "then performs semantic search with entity-aware boosting. "
        "Returns scored passages with source metadata."
    )
    args_schema: Type[BaseModel] = ContextualRAGInput

    def __init__(self, embeddings: txtai.Embeddings, nlp_model: str = "en_core_web_sm", **kwargs):
        super().__init__(**kwargs)
        self._embeddings = embeddings
        self._nlp = spacy.load(nlp_model)

    def _run(self, query: str, top_k: int = 5) -> str:
        # Extract entities for boosted search
        doc = self._nlp(query)
        entities = [ent.text for ent in doc.ents]
        keywords = [chunk.root.lemma_ for chunk in doc.noun_chunks]

        # Primary semantic search
        results = self._embeddings.search(query, top_k)

        # Entity-aware reranking: boost results containing detected entities
        if entities:
            boosted = []
            for text, score in results:
                entity_hits = sum(1 for e in entities if e.lower() in text.lower())
                boosted.append((text, score + entity_hits * 0.1))
            boosted.sort(key=lambda x: x[1], reverse=True)
            results = boosted[:top_k]

        # Format output
        parts = [f"Query entities: {', '.join(entities)}" if entities else None]
        parts = [p for p in parts if p]

        for i, (text, score) in enumerate(results):
            parts.append(f"[{i+1}] (score: {score:.3f}) {text[:500]}")

        return "\n\n".join(parts) if parts else "No relevant context found."
```
