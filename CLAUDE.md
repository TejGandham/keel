# KEEL — Knowledge-Encoded Engineering Lifecycle

This repository IS the KEEL framework. It provides the process, agents, and
templates for building software with AI coding agents.

## What This Repo Contains

- **Framework** (root): Process docs, agent definitions, skills, hooks
- **Templates** (`template/`): Starter files for new KEEL projects
- **Examples** (`examples/`): Domain invariant patterns + Repo Man case study
- **Bootstrap** (`scripts/bootstrap.sh`): Initialize a new KEEL project

## Directory Map

```
.claude/agents/     13 agent definitions (pre-check, test-writer, etc.)
.claude/skills/     3 skills (dev-up, keel-pipeline, safety-check)
.claude/hooks/      2 hooks (safety-gate, doc-gate)
docs/process/       Process guides (THE-KEEL-PROCESS, QUICK-START, etc.)
docs/               Framework-level templates (north-star, specs, design docs)
template/           Starter files copied by bootstrap.sh
examples/           Domain invariant examples + Repo Man case study
scripts/            Bootstrap and utilities
```

## Core Principles

1. **Docs drive code.** Never write code without reading the spec first.
2. **Repo is truth.** If it's not in the repo, it doesn't exist to the agent.
3. **Coding comes last.** Spec → test → code → verify. Always.
4. **Smallest testable units.** Each feature is independent and verifiable.
5. **Garbage collect.** After each feature: are docs still accurate? Fix lies immediately.

## Working on the Framework

When modifying KEEL itself (agents, process docs, templates):

- Read [docs/process/THE-KEEL-PROCESS.md](docs/process/THE-KEEL-PROCESS.md) for full context
- Agent definitions are in `.claude/agents/` — each is a standalone markdown file
- Templates in `template/` have `<!-- CUSTOMIZE -->` markers for project-specific sections
- The Repo Man example (`examples/repo-man/`) serves as the reference implementation
- Domain invariant examples (`examples/domain-invariants/`) show different safety patterns

## Working on the Repo Man Example

```bash
cd examples/repo-man
docker compose up                     # starts dev server at localhost:4000
docker compose run --rm app mix test  # run tests
```

See [examples/repo-man/CLAUDE.md](examples/repo-man/CLAUDE.md) for Repo Man-specific instructions.

## References

- [Process guide](docs/process/THE-KEEL-PROCESS.md) — Full KEEL process
- [Quick start](docs/process/QUICK-START.md) — First afternoon with KEEL
- [Glossary](docs/process/GLOSSARY.md) — KEEL terminology
- [Anti-patterns](docs/process/ANTI-PATTERNS.md) — What to avoid
- [OpenAI foundations](docs/process/OPENAI-FOUNDATIONS.md) — Where KEEL came from
- [Repo Man case study](examples/repo-man/CASE-STUDY.md) — Lessons learned
