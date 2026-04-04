# How KEEL Works

KEEL encodes everything into the repo — specs, invariants, architecture,
testing strategy — and runs a self-correcting pipeline that gates quality
at every step.

## The Pipeline

A feature flows through the pipeline like this:

```mermaid
graph TD
    Spec["🧑 <b>YOU WRITE A FEATURE SPEC</b>"] --> PC["🤖 Pre-check classifies it<br/>intent · complexity · routing"]
    PC -->|"research needed"| R["🤖 Researcher investigates<br/>unknowns before building"]
    PC -->|"architecture-tier"| OC["🤖 Arch-advisor provides<br/>architecture guidance"]
    R --> OC
    OC --> D["🤖 Designer defines<br/>interfaces + data structures"]
    PC -->|"standard"| D
    D --> TW["🤖 Test-writer writes tests<br/>from the spec (RED)"]
    TW --> IMP["🤖 Implementer writes code<br/>to pass tests (GREEN)"]
    IMP --> CR["🤖 Code review checks<br/>quality + patterns"]
    CR --> SR{"🤖 Spec-reviewer:<br/>does code match spec?"}
    SR -->|"CONFORMANT"| SA{"🤖 Safety-auditor:<br/>any invariant violations?"}
    SR -->|"DEVIATION"| FIX1["🤖 Findings → implementer fixes"]
    FIX1 --> SR
    SA -->|"PASS"| OV{"🤖 Arch-advisor verify:<br/>architecture sound?"}
    SA -->|"VIOLATION"| FIX2["🤖 Findings → implementer fixes"]
    FIX2 --> SA
    OV -->|"SOUND"| PL["🤖 Landing-verifier verifies<br/>everything landed"]
    OV -->|"UNSOUND"| FIX3["🤖 Findings → implementer fixes"]
    FIX3 --> SR
    PL --> GC["🤖 Doc-gardener sweeps<br/>for stale docs"]
    GC --> PR["🧑 <b>YOU REVIEW THE RESULT</b>"]

    SR -.-|"after 2 retries"| ESC["🧑 <b>ESCALATED TO YOU</b>"]
    SA -.-|"after 3 retries"| ESC
    OV -.-|"after 1 retry"| ESC

    style Spec fill:#1976D2,stroke:#0D47A1,color:#fff
    style PC fill:#303F9F,stroke:#1A237E,color:#fff
    style R fill:#303F9F,stroke:#1A237E,color:#fff
    style OC fill:#303F9F,stroke:#1A237E,color:#fff
    style D fill:#00796B,stroke:#004D40,color:#fff
    style TW fill:#00796B,stroke:#004D40,color:#fff
    style IMP fill:#00796B,stroke:#004D40,color:#fff
    style CR fill:#546E7A,stroke:#37474F,color:#fff
    style SR fill:#7B1FA2,stroke:#4A148C,color:#fff
    style SA fill:#7B1FA2,stroke:#4A148C,color:#fff
    style OV fill:#7B1FA2,stroke:#4A148C,color:#fff
    style FIX1 fill:#F57F17,stroke:#E65100,color:#000
    style FIX2 fill:#F57F17,stroke:#E65100,color:#000
    style FIX3 fill:#F57F17,stroke:#E65100,color:#000
    style PL fill:#388E3C,stroke:#1B5E20,color:#fff
    style GC fill:#546E7A,stroke:#37474F,color:#fff
    style PR fill:#1976D2,stroke:#0D47A1,color:#fff
    style ESC fill:#D32F2F,stroke:#B71C1C,color:#fff
```

> 🧑 = you &nbsp;&nbsp; 🤖 = agents &nbsp;&nbsp; You write the spec and review the result. Everything in between is autonomous.

The pipeline **self-corrects**: when a gate finds a problem, it sends
specific findings back to the implementer. After bounded retries, it
escalates to you instead of thrashing.

## How Agents Pass Context

Each agent reads a shared **handoff file** — an append-only document that
accumulates context as the feature flows through the pipeline.

```mermaid
graph LR
    PC3["🤖 pre-check<br/>writes <b>Constraints</b><br/>MUST use X · MUST NOT do Y"] --> DE3["🤖 designer<br/>reads constraints, writes<br/><b>Decisions</b> + <b>Constraints</b>"]
    DE3 --> TW3["🤖 test-writer<br/>reads decisions,<br/>writes tests from spec"]
    TW3 --> IM3["🤖 implementer<br/>reads everything above,<br/>writes <b>Decisions</b> only"]
    IM3 --> SR3["🤖 spec-reviewer<br/>reads spec + implementation<br/>judges conformance"]

    style PC3 fill:#303F9F,stroke:#1A237E,color:#fff
    style DE3 fill:#00796B,stroke:#004D40,color:#fff
    style TW3 fill:#00796B,stroke:#004D40,color:#fff
    style IM3 fill:#F57F17,stroke:#E65100,color:#000
    style SR3 fill:#7B1FA2,stroke:#4A148C,color:#fff
```

The implementer writes **Decisions only** — it cannot write Constraints
because its downstream agents (spec-reviewer, safety-auditor) are its
reviewers. Letting the implementee constrain its reviewers would undermine
the gates.

## How Gates Decide

Each gate agent outputs a **verdict**. The pipeline branches on it.

```mermaid
graph LR
    subgraph "spec-reviewer"
        SR4["verdict"] -->|"CONFORMANT"| N1["✓ proceed"]
        SR4 -->|"DEVIATION"| F4["⟲ fix · max 2"]
        F4 --> E4["✗ escalate"]
    end

    subgraph "safety-auditor"
        SA4["verdict"] -->|"PASS"| N2["✓ proceed"]
        SA4 -->|"VIOLATION"| F5["⟲ fix · max 3"]
        F5 --> E5["✗ escalate"]
    end

    subgraph "arch-advisor verify"
        OV4["verdict"] -->|"SOUND"| N3["✓ proceed"]
        OV4 -->|"UNSOUND"| F6["⟲ fix · max 1"]
        F6 --> E6["✗ escalate"]
    end

    style SR4 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style SA4 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style OV4 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style N1 fill:#388E3C,stroke:#1B5E20,color:#fff
    style N2 fill:#388E3C,stroke:#1B5E20,color:#fff
    style N3 fill:#388E3C,stroke:#1B5E20,color:#fff
    style F4 fill:#F57F17,stroke:#E65100,color:#000
    style F5 fill:#F57F17,stroke:#E65100,color:#000
    style F6 fill:#F57F17,stroke:#E65100,color:#000
    style E4 fill:#D32F2F,stroke:#B71C1C,color:#fff
    style E5 fill:#D32F2F,stroke:#B71C1C,color:#fff
    style E6 fill:#D32F2F,stroke:#B71C1C,color:#fff
```

MINOR-only deviations get `CONFORMANT` with notes — they don't burn loops.

See [FAILURE-PLAYBOOK.md](process/FAILURE-PLAYBOOK.md) for the full decision
tree when gates fail.

## How Pre-check Routes the Pipeline

Before anything runs, pre-check classifies the feature:

```mermaid
graph TD
    FEAT["🤖 Pre-check reads the spec"] --> INT{"What kind of work?"}
    INT -->|"refactoring"| C1["Behavior preservation focus"]
    INT -->|"build / mid-sized"| C2["Guardrails + exact deliverables"]
    INT -->|"architecture"| C3["Long-term impact analysis"]
    INT -->|"research"| C4["Investigation with exit criteria"]

    FEAT --> COMP{"How complex?"}
    COMP -->|"trivial"| R1["Skip designer"]
    COMP -->|"standard"| R2["Normal pipeline"]
    COMP -->|"complex"| R3["All gates run"]
    COMP -->|"architecture-tier"| R4["Arch-advisor consult + verify"]

    style FEAT fill:#303F9F,stroke:#1A237E,color:#fff
    style INT fill:#303F9F,stroke:#1A237E,color:#fff
    style COMP fill:#303F9F,stroke:#1A237E,color:#fff
    style C1 fill:#546E7A,stroke:#37474F,color:#fff
    style C2 fill:#00796B,stroke:#004D40,color:#fff
    style C3 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style C4 fill:#303F9F,stroke:#1A237E,color:#fff
    style R1 fill:#546E7A,stroke:#37474F,color:#fff
    style R2 fill:#00796B,stroke:#004D40,color:#fff
    style R3 fill:#F57F17,stroke:#E65100,color:#000
    style R4 fill:#D32F2F,stroke:#B71C1C,color:#fff
```

This prevents over-engineering trivial changes and ensures complex changes
get the scrutiny they need.

## The 14 Agents

```mermaid
graph LR
    subgraph "🧭 Routing"
        PC2[pre-check<br/>classify + route]
        RS[researcher<br/>discover]
        OR[arch-advisor<br/>consult + verify]
        DG[doc-gardener<br/>drift sweep]
    end

    subgraph "🔨 Building"
        DE[designer<br/>backend / frontend]
        TW2[test-writer<br/>RED]
        IM[implementer<br/>GREEN]
    end

    subgraph "🛡️ Gates"
        SR2[spec-reviewer<br/>CONFORMANT?]
        SA2[safety-auditor<br/>PASS?]
        OV2[arch-advisor verify<br/>SOUND?]
    end

    subgraph "🏁 Landing"
        PL2[landing-verifier<br/>LANDED?]
    end

    subgraph "⚙️ Bootstrap"
        DB[docker-builder]
        SC[scaffolder]
        CW[config-writer]
    end

    style PC2 fill:#303F9F,stroke:#1A237E,color:#fff
    style RS fill:#303F9F,stroke:#1A237E,color:#fff
    style OR fill:#303F9F,stroke:#1A237E,color:#fff
    style DG fill:#303F9F,stroke:#1A237E,color:#fff
    style DE fill:#00796B,stroke:#004D40,color:#fff
    style TW2 fill:#00796B,stroke:#004D40,color:#fff
    style IM fill:#00796B,stroke:#004D40,color:#fff
    style SR2 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style SA2 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style OV2 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style PL2 fill:#388E3C,stroke:#1B5E20,color:#fff
    style DB fill:#546E7A,stroke:#37474F,color:#fff
    style SC fill:#546E7A,stroke:#37474F,color:#fff
    style CW fill:#546E7A,stroke:#37474F,color:#fff
```

| Tier | Agents | Why |
|-|-|-|
| **High reasoning** | arch-advisor, implementer, spec-reviewer, safety-auditor, designers, researcher | Design decisions, gate verdicts, deep analysis |
| **Standard reasoning** | pre-check, test-writer, landing-verifier, doc-gardener, scaffolder, config-writer, docker-builder | Classification, pattern-following, verification |

See [THE-KEEL-PROCESS.md](process/THE-KEEL-PROCESS.md) for the full agent
roster with inputs, outputs, and tool access.

## AI-Slop Prevention

Pre-check flags these anti-patterns for downstream agents:

- **Scope inflation** — building features not in the spec
- **Premature abstraction** — utilities for one-time operations
- **Over-validation** — error handling for impossible states
- **Documentation bloat** — docstrings on code you didn't write
- **Gold-plating** — feature flags and backwards compatibility when not required

## Platform Mapping

The reference implementation uses Claude Code. The process is agent-agnostic.

| Tier | Claude Code | Other platforms |
|-|-|-|
| **High reasoning** | opus | Your platform's highest-tier model |
| **Standard reasoning** | sonnet | Your platform's standard-tier model |
