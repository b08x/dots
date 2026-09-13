---
title: AGENT.md The Universal Agent Configuration File
tags:
  - agent-design
  - ai-agent
  - configuration-management
  - documentation
  - markdown
last updated: Wednesday, November 5th 2025, 3:05:47 pm
---

# AGENT.md: The Universal Agent Configuration File

**Author:**Geoffrey Huntley

**Organization:**Sourcegraph, Inc.

**Status:**Informational

**Date:**July 2025

## Abstract

AI-powered coding tools are reshaping how we build software, but they're scattered across a mess of configuration files.

This document defines AGENT.md, a standardized format that lets your codebase speak directly to any agentic coding tool.

## Table of Contents

## 1. Introduction

Everything is changing. Developer tooling companies are building AI agents that can read, understand, and modify entire codebases but here's the thing: they need to know how your project works. What commands to run, what conventions to follow, where the important stuff lives.

Right now it's a mess for consumers. They have to maintain separate config files for  
each tool they want to use: `.cursorrules`

, `.windsurfrules`

, `.clauderules`

, and a dozen other files scattered across tools. Every  
other day another agent is brought to market with its own convention which worsens  
the mess.

AGENT.md changes this. One file, any agent. Your codebase gets a universal voice that every AI coding tool can understand.

The Amp team is working with other agentic coding tool makers to clean up this mess of filenames. We like AGENT.md because we own the domain name for <https://agent.md> and we are committed to keeping it vendor-neutral, so anyone typing "agent.md" on X or chat will be taken to a neutral, trusted site but we're willing to compromise.

## 2. Specification

The AGENT.md file SHOULD be placed in the root directory of a software project and MUST use Markdown formatting. The file SHOULD contain the following sections:

* Project structure and organization
* Build, test, and development commands
* Code style and conventions
* Architecture and design patterns
* Testing guidelines
* Security considerations

The format is designed to be human-readable while providing structured information that can be parsed by agentic coding tools.

### 2.1. Multiple AGENT.md Files

Implementations SHOULD support multiple AGENT.md files in a hierarchical structure:

* Root-level AGENT.md for general project guidance
* Subdirectory AGENT.md files for specific subsystem guidance
* User-global AGENT.md in ~/.config/AGENT.md for personal preferences

When multiple files exist, tools SHOULD merge the configurations with more specific files taking precedence over general ones.

### 2.2. File References

AGENT.md files MAY reference other files using @-mentions (e.g., @filename.md) to include additional context or documentation that should be considered when working in the project.

## 3. Implementation Guidelines

Tool implementers SHOULD follow these guidelines when adding AGENT.md support:

* Parse the AGENT.md file during project initialization
* Extract relevant configuration for the tool's specific use case
* Provide fallback behavior when AGENT.md is not present
* Respect existing tool-specific configuration files for backward compatibility

## 4. Migration from Legacy Configuration Files

Ready to make the switch? If you've got scattered config files lying around your project, we'll help you consolidate them into a single AGENT.md that works with everything. It's simpler than you think.

### 4.1. Migration Commands

Here's how to move your existing config to AGENT.md while keeping backward compatibility:

```shell
# Cline
mv .clinerules AGENT.md && ln -s AGENT.md .clinerules
# Claude Code
mv CLAUDE.md AGENT.md && ln -s AGENT.md CLAUDE.md
# Cursor
mv .cursorrules AGENT.md && ln -s AGENT.md .cursorrules
# Gemini CLI
mv GEMINI.md AGENT.md && ln -s AGENT.md GEMINI.md
# OpenAI Codex
mv AGENTS.md AGENT.md && ln -s AGENT.md AGENTS.md
# GitHub Copilot (replace [name] with your actual filename)
mv .github/instructions/[name].instructions.md AGENT.md && ln -s ../../AGENT.md .github/instructions/[name].instructions.md
# Replit
mv .replit.md AGENT.md && ln -s AGENT.md .replit.md
# Windsurf
mv .windsurfrules AGENT.md && ln -s AGENT.md .windsurfrules
```

These commands move your existing config to AGENT.md and create symbolic links back to the old locations. Your tools keep working, but now they're all reading from the same source of truth.

### 4.2. AGENT.md Content Structure

What should you put in your AGENT.md? Think about what you'd tell a new team member on their first day. Here's what works:

**Project Overview:**Brief description of the project's purpose and architecture**Build & Commands:**Development, testing, and deployment commands**Code Style:**Formatting rules, naming conventions, and best practices**Testing:**Testing frameworks, conventions, and execution guidelines**Security:**Security considerations and data protection guidelines**Configuration:**Environment setup and configuration management

### 4.3. Example AGENT.md File

Here's what a solid AGENT.md looks like in practice. Copy this structure and adapt it to your project:

```shell
# MyApp Project
MyApp is a full-stack web application with TypeScript frontend and Node.js backend.
The core functionality lives in the `src/` folder, with separate client (`client/`)
and server (`server/`) components.
## Build & Commands
- Typecheck and lint everything: `pnpm check`
- Fix linting/formatting: `pnpm check:fix`
- Run tests: `pnpm test --run --no-color`
- Run single test: `pnpm test --run src/file.test.ts`
- Start development server: `pnpm dev`
- Build for production: `pnpm build`
- Preview production build: `pnpm preview`
### Development Environment
- Frontend dev server: http://localhost:3000
- Backend dev server: http://localhost:3001
- Database runs on port 5432
- Redis cache on port 6379
## Code Style
- TypeScript: Strict mode with exactOptionalPropertyTypes, noUncheckedIndexedAccess
- Tabs for indentation (2 spaces for YAML/JSON/MD)
- Single quotes, no semicolons, trailing commas
- Use JSDoc docstrings for documenting TypeScript definitions, not `//` comments
- 100 character line limit
- Imports: Use consistent-type-imports
- Use descriptive variable/function names
- In CamelCase names, use "URL" (not "Url"), "API" (not "Api"), "ID" (not "Id")
- Prefer functional programming patterns
- Use TypeScript interfaces for public APIs
- NEVER use `@ts-expect-error` or `@ts-ignore` to suppress type errors
## Testing
- Vitest for unit testing
- Testing Library for component tests
- Playwright for E2E tests
- When writing tests, do it one test case at a time
- Use `expect(VALUE).toXyz(...)` instead of storing in variables
- Omit "should" from test names (e.g., `it("validates input")` not `it("should validate input")`)
- Test files: `*.test.ts` or `*.spec.ts`
- Mock external dependencies appropriately
## Architecture
- Frontend: React with TypeScript
- Backend: Express.js with TypeScript
- Database: PostgreSQL with Prisma ORM
- State management: Zustand
- Styling: Tailwind CSS
- Build tool: Vite
- Package manager: pnpm
## Security
- Use appropriate data types that limit exposure of sensitive information
- Never commit secrets or API keys to repository
- Use environment variables for sensitive data
- Validate all user inputs on both client and server
- Use HTTPS in production
- Regular dependency updates
- Follow principle of least privilege
## Git Workflow
- ALWAYS run `pnpm check` before committing
- Fix linting errors with `pnpm check:fix`
- Run `pnpm build` to verify typecheck passes
- NEVER use `git push --force` on the main branch
- Use `git push --force-with-lease` for feature branches if needed
- Always verify current branch before force operations
## Configuration
When adding new configuration options, update all relevant places:
1. Environment variables in `.env.example`
2. Configuration schemas in `src/config/`
3. Documentation in README.md
All configuration keys use consistent naming and MUST be documented.
```

## 5. Tool Integration

AGENT.md is already working with these tools, and more are joining every day:

**Amp:**Native support since 2025-05-07. Multiple AGENT.md files since 2025-07-07.**Claude Code:**Supports AGENT.md via symbolic linking (see Migration section).**Cursor:**Supports AGENT.md via symbolic linking (see Migration section).**Firebase Studio:**Supports AGENT.md via symbolic linking (see Migration section).**Gemini CLI:**Supports AGENT.md via symbolic linking (see Migration section).**OpenAI Codex:**Supports AGENT.md via symbolic linking (see Migration section).**OpenCode:**Supports AGENT.md via symbolic linking (see Migration section).**Replit:**Supports AGENT.md via symbolic linking (see Migration section).**Windsurf:**Supports AGENT.md via symbolic linking (see Migration section).

## 6. IANA Considerations

This document does not require any IANA actions. The .md file extension is already registered for Markdown files.

## 7. References

**7.1. Normative References**

**7.2. Informative References**

## 8. Authors' Addresses

To propose changes to this page, email amp-devs@sourcegraph.com or mention @AmpCode (on X).
