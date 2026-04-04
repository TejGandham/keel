# KEEL

**Knowledge-Encoded Engineering Lifecycle** — a process framework for AI-assisted development. Spec in, stable tested code out.

## The Problem

AI agents forget between sessions. Feature 2 breaks Feature 1. A rules file works until ~10 features — then you need structure.

```mermaid
graph LR
    S1["Session 1<br/><b>Build X</b><br/>Works!"] --> S2["Session 2<br/><b>Build Y</b><br/>Breaks X"]
    S2 --> S3["Session 3<br/><b>Fix X</b><br/>Breaks Y"]
    style S1 fill:#388E3C,stroke:#1B5E20,color:#fff
    style S2 fill:#F57F17,stroke:#E65100,color:#000
    style S3 fill:#D32F2F,stroke:#B71C1C,color:#fff
```

> Knowledge evaporates. Each feature is a fresh start.

## The Solution

KEEL encodes everything into the repo and runs a self-correcting pipeline.

```mermaid
graph LR
    subgraph input [You write]
        Spec[Product spec]
        Inv[Domain invariants]
        Arch[Architecture doc]
    end
    subgraph pipeline [KEEL does]
        P1[14 agents execute pipeline]
        P2[Tests before code]
        P3[Code verified against spec]
        P4[Safety invariants enforced]
        P5[Self-corrects on failure]
    end
    Spec --> P1
    Inv --> P4
    Arch --> P3
    P5 --> Out[Tested, spec-conformant,<br/>safe code]

    style Spec fill:#1976D2,stroke:#0D47A1,color:#fff
    style Inv fill:#1976D2,stroke:#0D47A1,color:#fff
    style Arch fill:#1976D2,stroke:#0D47A1,color:#fff
    style P1 fill:#00796B,stroke:#004D40,color:#fff
    style P2 fill:#00796B,stroke:#004D40,color:#fff
    style P3 fill:#00796B,stroke:#004D40,color:#fff
    style P4 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style P5 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style Out fill:#388E3C,stroke:#1B5E20,color:#fff
```

Gates self-correct: deviation → fix → retry (bounded). Escalates to you instead of thrashing. Knowledge flows forward through handoff files — Feature 20 benefits from Features 1–19.

**[How it works in detail →](docs/HOW-IT-WORKS.md)**

## Who This Is For

- **Solo devs or small teams (1-3)** with an AI agent as primary implementer
- **Projects that grow** — today's 3 features become next month's 30
- **Any AI agent platform** — process is agent-agnostic; reference implementation uses Claude Code

Not for: one-off scripts, throwaway prototypes, <5 feature projects.

## Install

```bash
cd my-project    # new or existing
git clone --depth 1 https://github.com/anthropics/keel.git /tmp/keel
/tmp/keel/scripts/install.sh
rm -rf /tmp/keel
```

Installs 14 agents, 3 skills, 2 hooks, and doc structure into your project. Never overwrites existing files.

```
 After install:
 1. CLAUDE.md            ← fill in <!-- CUSTOMIZE --> sections
 2. docs/north-star.md   ← your project vision
 3. safety-auditor.md    ← your domain invariants
 4. Write a spec         ← docs/product-specs/
 5. /keel-pipeline       ← run it
```

**Existing codebase?** Run `/keel-adopt` after install.
**Full manifest:** [INSTALL.md](docs/INSTALL.md) | **Remove:** [UNINSTALL.md](docs/UNINSTALL.md)

## Case Study

[`examples/repo-man/`](examples/repo-man/) — 31 features, ~3000 LOC Elixir, 250+ tests, all spec-driven. [Lessons learned →](examples/repo-man/CASE-STUDY.md)

## Docs

| Doc | What you'll learn |
|-|-|
| **[NORTH-STAR.md](NORTH-STAR.md)** | Vision, autonomy ceiling, growth stages |
| **[HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md)** | Pipeline, agents, gates, wisdom accumulation |
| [INSTALL.md](docs/INSTALL.md) | Full artifact inventory |
| [UNINSTALL.md](docs/UNINSTALL.md) | Clean removal |
| [QUICK-START.md](docs/process/QUICK-START.md) | First afternoon walkthrough |
| [BROWNFIELD.md](docs/process/BROWNFIELD.md) | Existing codebase adoption |
| [THE-KEEL-PROCESS.md](docs/process/THE-KEEL-PROCESS.md) | Comprehensive process guide |
| [FAILURE-PLAYBOOK.md](docs/process/FAILURE-PLAYBOOK.md) | When the pipeline stalls |
| [GLOSSARY.md](docs/process/GLOSSARY.md) | Terminology |
| [ANTI-PATTERNS.md](docs/process/ANTI-PATTERNS.md) | What not to do |

## License

This framework is provided as-is for use in AI-assisted software development.
