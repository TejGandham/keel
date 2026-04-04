# KEEL

**Knowledge-Encoded Engineering Lifecycle** — a framework for building software with AI agents.

KEEL turns your repository into a complete operating environment for AI coding agents. Instead of giving agents vague instructions, you give them a structured knowledge base: specs that define what to build, invariants that define what's forbidden, and pipelines that enforce the build sequence.

Adapted from [OpenAI's Harness Engineering](docs/references/harness-engineering-article/) approach, where "single Codex runs work on tasks for upwards of six hours while humans sleep."

## Who KEEL Is For

KEEL is for projects that grow — where today's 3 features become next month's 30, and you need institutional knowledge to compound rather than evaporate between sessions.

- **Solo developers or small teams (1-3)** using an AI coding agent as primary implementer
- **Projects that will grow organically**, sometimes exponentially in scope
- **Projects where correctness matters** — domain invariants, safety rules, spec conformance
- **Any AI agent platform** — the process is agent-agnostic; the reference implementation uses Claude Code

A single rules file (AGENTS.md, .cursorrules) works for simple projects. KEEL is what you reach for when you outgrow that — when you need specs, architecture docs, a testing doctrine, and pipeline discipline because ad-hoc prompting stops scaling.

## What KEEL Covers (and What It Doesn't)

KEEL covers the **build phase**: from product vision to landed feature. Its boundary is the git commit.

| Covered | Not covered (yet) |
|-|-|
| Product specs and design docs | CI/CD pipelines |
| Architecture and module design | Deployment and infrastructure |
| Feature decomposition and backlog | Monitoring and observability |
| Spec → test → code → verify pipeline | Incident response |
| Domain invariants and safety enforcement | Team scaling beyond 3 people |
| Documentation accuracy (garbage collection) | Multi-repo coordination |

KEEL doesn't try to replace your CI/CD, deployment, or operations tooling. It ensures the code that enters those systems is spec-conformant, tested, and safe.

## How It Works

**Humans steer. Agents execute. The repo is the system of record.**

KEEL encodes everything an agent needs into the repository itself:

1. **Specs define what to build** — product specs, design docs, architecture
2. **Invariants define what's forbidden** — domain safety rules, mechanically enforced
3. **A feature backlog decomposes work** — smallest independently testable units
4. **A pipeline enforces the sequence** — spec → test → code → verify → land
5. **Agents execute each pipeline stage** — 14 specialized roles from pre-check to plan-lander

## Quick Start

```bash
# Clone and bootstrap a new project
git clone <this-repo> my-project
cd my-project
./scripts/bootstrap.sh

# Fill in your project docs (the script tells you what to do next)
# Then run your first feature through the pipeline
```

See [docs/process/QUICK-START.md](docs/process/QUICK-START.md) for the full walkthrough.

## Framework Components

| Component | Location | Purpose |
|-|-|-|
| **14 Agent Definitions** | `.claude/agents/` | Specialized roles: pre-check, oracle, test-writer, implementer, safety-auditor, etc. |
| **3 Skills** | `.claude/skills/` | dev-up (start env), keel-pipeline (orchestrate), safety-check (audit) |
| **2 Hooks** | `.claude/hooks/` | safety-gate (pre-edit), doc-gate (post-commit) |
| **Process Docs** | `docs/process/` | THE-KEEL-PROCESS, QUICK-START, GLOSSARY, ANTI-PATTERNS, etc. |
| **Templates** | `template/` | Starter files for new projects (CLAUDE.md, ARCHITECTURE.md, specs, etc.) |
| **Domain Invariant Examples** | `examples/domain-invariants/` | Git ops, REST API, financial, data pipeline |
| **Repo Man Case Study** | `examples/repo-man/` | Complete working app built with KEEL (Phoenix LiveView, 31 features) |

## Key Concepts

- **Knowledge Boundary** — agents can only see what's in the repo. Encode everything.
- **Progressive Disclosure** — CLAUDE.md is the entry point (~80 lines). It points to deeper docs.
- **Spec-Driven Testing** — tests enforce spec conformance. Specs change → tests change first.
- **Domain Invariants** — non-negotiable rules mechanically enforced by the safety-auditor agent.
- **Garbage Collection** — docs that lie are worse than no docs. Sweep after every feature.

## The Pipeline

```
pre-check → researcher? → oracle? → designer? → test-writer → implementer → spec-reviewer → safety-auditor? → oracle-verify? → plan-lander
```

Each stage reads the handoff file, does its work, appends its output. The orchestrator dispatches each stage and reviews gates. Oracle runs for architecture-tier features (consultation before design, verification before landing).

## Case Study: Repo Man

[`examples/repo-man/`](examples/repo-man/) is a complete Phoenix LiveView dashboard built entirely with KEEL. 31 features, ~3000 lines of Elixir, 250+ tests, all driven by specs and executed through the pipeline. See [the case study](examples/repo-man/CASE-STUDY.md) for lessons learned.

## Process Documentation

| Document | Purpose |
|-|-|
| [THE-KEEL-PROCESS.md](docs/process/THE-KEEL-PROCESS.md) | Comprehensive guide (everything) |
| [QUICK-START.md](docs/process/QUICK-START.md) | First afternoon with KEEL (greenfield) |
| [BROWNFIELD.md](docs/process/BROWNFIELD.md) | Adopting KEEL in an existing codebase |
| [GLOSSARY.md](docs/process/GLOSSARY.md) | KEEL terminology |
| [FAILURE-PLAYBOOK.md](docs/process/FAILURE-PLAYBOOK.md) | What to do when the pipeline stalls |
| [ANTI-PATTERNS.md](docs/process/ANTI-PATTERNS.md) | 10 patterns that break the process |
| [AUTONOMY-PROGRESSION.md](docs/process/AUTONOMY-PROGRESSION.md) | From full oversight to agent autonomy |
| [OPENAI-FOUNDATIONS.md](docs/process/OPENAI-FOUNDATIONS.md) | OpenAI's harness engineering adaptation |

## License

This framework is provided as-is for use in AI-assisted software development.
