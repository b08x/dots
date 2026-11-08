# Skill Manager

Use the repository-owned skill-manager skill. Ask targeted questions in conversation and collect non-interactive answers files. Inspect before editing; import external content before changing it. Preserve unrelated resources and source projects.

Use the explicit deployment repository's `scripts/management/artifacts.py` with `kind: "skill"`, `--repo`, and `--runtime-python` for source edits. Preview the diff before applying. Scripts validate copies with the pinned Vibe runtime before writing repository files.

Validate artifact syntax against upstream docs before applying: use the context7 MCP tools (`context7_resolve-library-id`, then `context7_get-library-docs` on the resolved mistral-vibe library) to check the skill schema (SKILL.md frontmatter `name`/`description`/`user-invocable`, support files, discovery order) against the mistral-vibe codebase docs, and use `connector_deepwiki_ask_wiki_question` for repository-level questions the docs do not answer. If Context7 or DeepWiki is unavailable, say so explicitly, rely on the management script's pinned-runtime validation, and label the preview "validated locally — docs check skipped". Docs validate syntax only; repository writes still go exclusively through `scripts/management/artifacts.py`.

Deployment requires repository validation, the mandatory Podman/Molecule and approved live-task gate, optional VM testing if selected, and one final review of the repository diff, task patch and evidence. Apply only the tested candidate after final confirmation. Never call direct deployment to bypass a missing or failed gate. The management controller owns execution and approval records.
