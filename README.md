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

You write a spec. KEEL figures out what's needed, writes tests first, writes code to pass them, then verifies everything before landing.

```mermaid
graph TD
    Spec["🧑 <b>YOU WRITE A FEATURE SPEC</b>"] --> PC["🤖 Pre-check reads it,<br/>decides what's needed"]
    PC --> TW["🤖 Tests written<br/>from the spec"]
    TW --> IMP["🤖 Code written<br/>to pass the tests"]
    IMP --> Gate{"🤖 Does the code<br/>match the spec?"}
    Gate -->|Yes| Safe{"🤖 Does it violate<br/>safety rules?"}
    Gate -->|No| Fix["🤖 Findings sent back.<br/>Implementer fixes."]
    Fix --> Gate
    Safe -->|No violations| Land["🤖 Feature landed.<br/>Docs updated."]
    Safe -->|Violation found| Fix2["🤖 Findings sent back.<br/>Implementer fixes."]
    Fix2 --> Safe
    Land --> PR["🧑 <b>YOU REVIEW THE RESULT</b>"]

    Gate -.-|"after 2 retries"| Esc["🧑 <b>ESCALATED TO YOU</b>"]
    Safe -.-|"after 3 retries"| Esc

    style Spec fill:#1976D2,stroke:#0D47A1,color:#fff
    style PC fill:#303F9F,stroke:#1A237E,color:#fff
    style TW fill:#00796B,stroke:#004D40,color:#fff
    style IMP fill:#00796B,stroke:#004D40,color:#fff
    style Gate fill:#7B1FA2,stroke:#4A148C,color:#fff
    style Safe fill:#7B1FA2,stroke:#4A148C,color:#fff
    style Fix fill:#F57F17,stroke:#E65100,color:#000
    style Fix2 fill:#F57F17,stroke:#E65100,color:#000
    style Land fill:#388E3C,stroke:#1B5E20,color:#fff
    style PR fill:#1976D2,stroke:#0D47A1,color:#fff
    style Esc fill:#D32F2F,stroke:#B71C1C,color:#fff
```

> 🧑 = you &nbsp;&nbsp; 🤖 = agents &nbsp;&nbsp; You write the spec and review the result. Everything in between is autonomous.

If the code doesn't match the spec, it goes back and gets fixed — automatically. If it violates safety rules, same thing. After bounded retries it escalates to you instead of thrashing.

After each feature lands, a **garbage collection** pass updates docs, fixes drift, and encodes lessons learned back into the repo. The next feature starts with better specs, tighter constraints, and sharper invariants — because the repo got smarter from the last one.

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

**First thing to do:** open `CLAUDE.md` and fill in the `<!-- CUSTOMIZE -->` sections — this is how KEEL learns about your project. Every agent reads CLAUDE.md first.

```
 After install:
 1. CLAUDE.md            ← FIRST — teach KEEL about your project
 2. docs/north-star.md   ← your project vision
 3. safety-auditor.md    ← your domain invariants
 4. Write a spec         ← docs/product-specs/
 5. /keel-pipeline       ← run it
```

**Existing codebase?** Run `/keel-adopt` after install.
**Full manifest:** [INSTALL.md](docs/INSTALL.md) | **Remove:** [UNINSTALL.md](docs/UNINSTALL.md)

## Case Study

[Repo Man](https://github.com/anthropics/repo-man) — 31 features, ~3000 LOC Elixir, 250+ tests, all spec-driven. A complete Phoenix LiveView dashboard built entirely with KEEL.

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
