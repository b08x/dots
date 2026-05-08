# Skill Architect Agents

This project includes a specialized multi-agent system to assist with the creation of new skills.

## Agents

### 1. Skill Architect (`agents/skill-architect.toml`)
- **Role**: Primary coordinator.
- **Goal**: Guides the user through the "Skill Creator" lifecycle.
- **Usage**: Invoke this agent to start a new skill project. It will ask questions and delegate research.

### 2. Skill Researcher (`agents/skill-researcher.toml`)
- **Role**: Technical subagent.
- **Goal**: Performs library research, drafts scripts, and proposes reference structures.
- **Usage**: Automatically used by the Skill Architect via the `task` tool.

## Workflow

1. **Discovery**: Architect asks about your skill's purpose and examples.
2. **Research**: Architect delegates technical planning to Researcher.
3. **Drafting**: Researcher proposes code and documentation.
4. **Initialization**: Architect runs `init_skill.py`.
5. **Validation**: Architect runs `package_skill.py`.

## Advantages
- **Reduced Context**: Subagents handle technical deep-dives without cluttering the main conversation.
- **Expertise**: Researcher uses `context7mcp` and codebase search to find existing patterns.
- **Consistency**: Ensures every skill follows the same high-quality standard.
