---
promptId: rewriteSelection
name: ✏️ Rewrite Selected Text
description: Rewrite text in imperative mood as a knowledge base article
tags:
  - writing
  - text-rewriting
version: 1.0.0
mode: insert
---

# Context

**Register Variables:**

- **Field**: Transforming source content into accessible, actionable knowledge base articles
- **Tenor**: Expert-to-practitioner communication with authoritative yet approachable voice
- **Mode**: Knowledge base format optimized for searchability, scannability, and task completion

**Communicative Purpose**: Produce analytically precise yet immediately actionable knowledge base articles that transform complex source material into structured, searchable content that enables users to quickly find, understand, and apply information through strategic deployment of information architecture principles.

Here is the source text to rewrite:

<source_text> {{selection}} </source_text>

## Field (Content/Subject Matter)

**Experiential Function**: Transform source content into concrete user-centered knowledge experiences through:

**Opening with Task-Oriented Scenarios:**

- Begin with specific user intentions: "When you need to configure authentication..." or "If you're troubleshooting connection errors..."
- Ground abstract concepts in practical implementation moments: setup processes, troubleshooting sessions, configuration decisions
- Connect information to user workflows: "This process integrates with existing deployment pipelines..." or "Teams typically encounter this during..."

**Integrating Authoritative Source Material:**

- Preserve and properly attribute technical specifications, official documentation, and expert guidance
- Reference implementation examples: "The standard approach involves..." or "Best practices recommend..."
- Include code snippets, configuration examples, and step-by-step procedures as actionable "dialogue" between user intent and system requirements
- Maintain links to original sources and related documentation

**Meta-Commentary Connections:**

- Conclude sections by connecting specific procedures to broader system understanding
- Link individual steps to workflow integration and scaling considerations
- Explicitly bridge concrete instructions to systemic implications about maintenance, security, and operational efficiency

## Tenor (Relationship/Voice)

**Interpersonal Function**: Establish trusted knowledge transfer relationship through:

**Varied Participant Roles:**

- **Technical Guide**: Precise instructions and explanations with clear prerequisites and outcomes
- **Experience Synthesizer**: Strategic recognition of common implementation patterns and edge cases
- **Future Maintainer**: Perspective of someone returning to this information months later
- **Team Enabler**: Consideration of knowledge sharing and collaborative implementation

**Strategic Voice Shifts:**

- **Instructional Authority (80%)**: Clear, definitive guidance on procedures, configurations, and troubleshooting
- **Contextual Recognition (20%)**: Strategic acknowledgment of complexity, alternatives, and real-world implementation challenges

**Balanced Power Dynamics:**

- Respect user technical competence while providing necessary context and prerequisites
- Offer clear guidance without over-explaining obvious steps for the target audience
- Use inclusive "you" and "your team" when describing implementation scenarios
- Balance present-tense instructions with future-consideration warnings and tips

## Mode (Organization/Texture)

**Textual Function**: Structure scannable, searchable knowledge content through:

**Syntactic Variation:**

- **Imperative Instructions**: "Configure the database connection." "Update the configuration file."
- **Explanatory Constructions**: "When the system encounters authentication failures during peak traffic periods, which can cascade through dependent services, the retry mechanism automatically implements exponential backoff while preserving user session state."

**Information Packaging:**

- **Hierarchical Structure**: Clear headings, subheadings, and nested procedures
- **Conditional Embedding**: "If using Docker (which most production deployments require), follow the containerized configuration steps."
- **Cross-Reference Integration**: Links to related procedures, prerequisites, and follow-up actions

**Cohesive Parallelism:**

- **Sequential Structures**: "First configure authentication, then test connectivity, finally implement monitoring"
- **Alternative Patterns**: "For cloud deployments use method A, for on-premises installations use method B, for hybrid environments combine both approaches"
- **Systematic Organization**: "Prerequisites → Implementation → Verification → Troubleshooting"

**Thematic Progression:**

```
Overview → Prerequisites → Step-by-Step Implementation → Verification → Troubleshooting → Related Topics
```

## Implementation Patterns

### Knowledge Base Article Structure

**Title (Task-Oriented):**

```
How to [specific action] in [context]
```

Examples:

- "How to Configure SSL Certificates for Production Deployment"
- "How to Troubleshoot Database Connection Timeouts"
- "How to Set Up Automated Backup Procedures"

**Overview Section:**

- **What This Covers**: Precise scope definition with user scenario anchoring
- **Prerequisites**: Technical requirements, access permissions, and prior knowledge
- **Expected Outcome**: Clear success criteria and next steps

**Implementation Section (Core Content):**

- **Step-by-Step Instructions**: Numbered procedures with syntactic variation
- **Code Examples**: Formatted snippets with explanation and context
- **Configuration Details**: Parameters, options, and customization guidance
- **Verification Steps**: How to confirm successful implementation

**Reference Section:**

- **Troubleshooting**: Common issues with diagnostic and resolution steps
- **Related Articles**: Cross-references to prerequisite and follow-up procedures
- **External Resources**: Links to official documentation and community resources

### Information Architecture Patterns

**Scannable Organization:**

```
[H1] Main Topic
  [H2] Overview
    [H3] Prerequisites
    [H3] What You'll Accomplish
  [H2] Implementation
    [H3] Step 1: [Action]
    [H3] Step 2: [Action]
    [H3] Step 3: [Verification]
  [H2] Troubleshooting
    [H3] Common Issue A
    [H3] Common Issue B
  [H2] Related Topics
```

**Conditional Logic Integration:**

```
[If condition] → [specific instructions]
[Else if condition] → [alternative instructions]
[Otherwise] → [default approach]
```

**Cross-Reference Patterns:**

```
[current_procedure] → [related_procedure]
"For authentication setup, see [Authentication Configuration Guide]"
"This process requires completion of [Database Setup Procedures]"
```

### Content Transformation Guidelines

**From Source Material to Knowledge Base:**

**Abstract Concepts → Concrete Procedures:**

- Transform theoretical explanations into step-by-step implementations
- Convert principles into actionable checklists and verification steps
- Bridge conceptual understanding to practical application

**Narrative Content → Structured Information:**

- Extract key procedures from narrative descriptions
- Organize information hierarchically for task completion
- Create clear entry and exit points for specific user needs

**Technical Specifications → Implementation Guidance:**

- Translate specs into configuration instructions
- Provide context for parameter choices and alternatives
- Include real-world examples and common customizations

**Problem Descriptions → Solution Procedures:**

- Structure troubleshooting as diagnostic decision trees
- Convert problem narratives into systematic resolution steps
- Provide multiple solution paths for different scenarios

### Quality Assurance Patterns

**Clarity Verification:**

- Each procedure can be followed independently by target audience
- Prerequisites are explicitly stated and linked
- Success criteria are measurable and specific

**Completeness Check:**

- All necessary steps included from start to finish
- Edge cases and alternatives addressed
- Troubleshooting covers common failure modes

**Maintenance Considerations:**

- Version-specific information clearly marked
- Update triggers and review cycles identified
- Deprecation and migration paths documented

**User Experience Optimization:**

- Information findable through multiple search approaches
- Procedures executable without excessive context switching
- Follow-up actions and related tasks clearly connected

**Anti-Patterns to Avoid:**

- Burying critical steps in narrative explanations
- Assuming unstated prerequisites or context
- Creating procedures that require reading entire articles to execute single tasks
- Organizing information by source structure rather than user task flow

Generate knowledge base articles that transform source material into task-oriented, immediately actionable content that users can quickly locate, understand, and successfully implement, with clear connections to broader system understanding and workflow integration.

output: