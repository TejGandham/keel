# KEEL — Knowledge-Encoded Engineering Lifecycle

This repository IS the KEEL framework. It provides the process, agents, and
templates for building software with AI coding agents.

**Scope:** KEEL covers the build phase — from product vision to landed feature.
Its boundary is the git commit. It does not cover CI/CD, deployment, or operations.

**For:** Projects that grow organically. Solo developers or small teams (1-3)
using an AI agent as primary implementer. Any agent platform — the process
is agent-agnostic; the reference implementation uses Claude Code.

## What This Repo Contains

- **Framework** (root): Process docs, agent definitions, skills, hooks
- **Templates** (`template/`): Starter files for new KEEL projects
- **Examples** (`examples/`): Domain invariant patterns
- **Installer** (`scripts/install.sh`): Install KEEL into any project directory
- **Legacy Bootstrap** (`scripts/bootstrap.sh`): In-place placeholder replacement

## Directory Map

```
.claude/agents/     14 agent definitions (pre-check, arch-advisor, test-writer, etc.)
.claude/skills/     4 skills (dev-up, keel-pipeline, keel-adopt, safety-check)
.claude/hooks/      2 hooks (safety-gate, doc-gate)
docs/process/       Process guides (THE-KEEL-PROCESS, QUICK-START, etc.)
docs/               Framework-level templates (north-star, specs, design docs)
template/           Starter files copied by bootstrap.sh
examples/           Domain invariant examples
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
- Domain invariant examples (`examples/domain-invariants/`) show different safety patterns

## Vision

- [NORTH-STAR.md](NORTH-STAR.md) — Where KEEL is heading (spec-to-commit automation engine)

## References

- [Process guide](docs/process/THE-KEEL-PROCESS.md) — Full KEEL process
- [Quick start](docs/process/QUICK-START.md) — First afternoon with KEEL (greenfield)
- [Brownfield](docs/process/BROWNFIELD.md) — Adopting KEEL in an existing codebase
- [Glossary](docs/process/GLOSSARY.md) — KEEL terminology
- [Failure playbook](docs/process/FAILURE-PLAYBOOK.md) — Pipeline stall decision tree
- [Anti-patterns](docs/process/ANTI-PATTERNS.md) — What to avoid
- [OpenAI foundations](docs/process/OPENAI-FOUNDATIONS.md) — Where KEEL came from
- [Repo Man case study](examples/repo-man/CASE-STUDY.md) — Lessons learned
