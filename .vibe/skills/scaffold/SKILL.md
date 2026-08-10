---
name: scaffold
description: "Use when scaffolding new Ruby projects or gems. Applies rubysmith/gemsmith flag presets by project archetype and runs convention passes for project hardening."
user-invocable: true
---

# RubyDev Scaffold — Project Scaffolding

## Overview

Starting a new Ruby project or gem requires dozens of decisions: test framework, CI, licensing, container setup, console, and more. The scaffold skill maps project archetypes to rubysmith/gemsmith flag presets, runs the scaffolding command, then applies a convention pass to harden the generated structure.

The full flag reference and decision guide lives in `~/.vibe/skills/scaffold/references/scaffold-patterns.md`.

## When to Use

- User says "start a new Ruby project" or "scaffold a CLI app"
- User says "create a new gem" or "publish a library"
- User provides a project name and type (e.g., "web app", "CLI tool", "gem library")
- A new project needs CI, Docker, testing, and documentation from day one

**Don't use for:**
- One-off scripts (just write a file)
- Rails applications (use Rails generators instead)
- Modifying existing projects (use [refactor/SKILL.md](~/.vibe/skills/refactor/SKILL.md) or the [ruby-dev orchestrator](~/.vibe/skills/ruby-dev/SKILL.md))

## Archetype → Flag Preset

| Archetype | Tool | Key Flags |
|-----------|------|-----------|
| Bare min script | `rubysmith` | `--min` |
| CLI application | `rubysmith` | `--max --no-docker --no-git_hub_ci` |
| Web service | `rubysmith` | `--max` (all features) |
| Ruby gem (library) | `gemsmith` | `--max` (most flags shared with rubysmith) |
| Rails engine | `gemsmith` | `--max --rails` (if supported) |
| OSS project | `rubysmith` or `gemsmith` | `--max --license --funding --conduct --community` |
| Internal library | `gemsmith` | Core flags + `--git --rake --rspec --console` |

See `~/.vibe/skills/scaffold/references/scaffold-patterns.md` sections 1-4 for complete flag tables and the rubysmith-vs-gemsmith decision guide.

## Convention Pass (Post-Scaffold)

After scaffolding, the skill runs a convention pass to harden the generated project. These are documented in `~/.vibe/skills/scaffold/references/scaffold-patterns.md` Section 6:

1. **Ruby version pinning** — Ensure `.ruby-version` matches the active runtime
2. **Frozen string literals** — Add `# frozen_string_literal: true` to all `.rb` files
3. **Gemfile organization** — Group gems by purpose (development, test, runtime)
4. **Rakefile cleanup** — Remove unused tasks
5. **README hardening** — Fill placeholder sections
6. **Guardfile** — Add if using guard for auto-testing
7. **`.gitignore` audit** — Match standard Ruby gitignore

## Failover

| Dependency | If Unavailable | Fallback |
|------------|---------------|----------|
| `rubysmith` gem | Not installed | `gem install rubysmith` first. If install fails, scaffold manually: create directory structure, Gemfile, Rakefile, and `bin/console` by hand. |
| `gemsmith` gem | Not installed | `gem install gemsmith` first. If install fails, scaffold a gem manually with `bundler`'s `gem` command. |
| `~/.vibe/skills/scaffold/references/scaffold-patterns.md` | Pattern file not found | Use defaults (`--max` for project, `--git --rake --rspec` for gem). Document that flag reference was skipped. |

## Common Pitfalls

1. **Wrong tool for the job**: `rubysmith` is for applications/scripts; `gemsmith` is for gems/libraries. Using the wrong tool produces an awkward structure.
2. **Missing config**: Both tools read `~/.config/rubysmith/configuration.yml`. If this file is missing, defaults may not match user preferences.
3. **Overriding existing files**: Never scaffold over an existing project directory without explicit user confirmation.
4. **Skipping the convention pass**: The scaffolding output is a skeleton. The convention pass (frozen strings, README hardening, Gemfile organization) turns it into a production-ready project.
5. **Missing post-scaffold verification**: After scaffolding, verify with `ruby -c`, `bundle exec rspec`, and `bin/setup` (if included).

## Verification Checklist

- [ ] Correct tool selected (rubysmith for app, gemsmith for gem)
- [ ] Scaffold command ran successfully
- [ ] Convention pass applied (frozen strings, ruby-version, Gemfile audit)
- [ ] `ruby -c` passes on generated files
- [ ] `bundle install` or equivalent succeeds
- [ ] Project directory structure matches expected archetype
- [ ] README placeholder sections filled