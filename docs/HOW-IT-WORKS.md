# How KEEL Works

KEEL encodes everything into the repo — specs, invariants, architecture,
testing strategy — and runs a self-correcting pipeline that gates quality
at every step.

## The Pipeline

```mermaid
graph TD
    Spec[Feature Spec] --> PC[pre-check<br/>classify intent + complexity]
    PC -->|research needed| R[researcher]
    PC -->|oracle needed| OC[oracle<br/>CONSULT]
    R --> OC
    OC --> D[designer?<br/>backend / frontend]
    PC -->|standard| D
    D --> TW[test-writer<br/>RED]
    TW --> IMP[implementer<br/>GREEN]
    IMP --> CR[code review]
    CR --> SR{spec-reviewer}
    SR -->|CONFORMANT| SA{safety-auditor?}
    SR -->|DEVIATION| IMP
    SA -->|PASS| OV{oracle verify?}
    SA -->|VIOLATION| IMP
    OV -->|SOUND| PL[plan-lander<br/>LANDED]
    OV -->|UNSOUND| IMP

    SR -.-|max 2 loops| ESC1[escalate to human]
    SA -.-|max 3 loops| ESC2[escalate to human]
    OV -.-|max 1 retry| ESC3[escalate to human]

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
    style PL fill:#388E3C,stroke:#1B5E20,color:#fff
    style ESC1 fill:#D32F2F,stroke:#B71C1C,color:#fff
    style ESC2 fill:#D32F2F,stroke:#B71C1C,color:#fff
    style ESC3 fill:#D32F2F,stroke:#B71C1C,color:#fff
```

**The pipeline self-corrects.** Spec-reviewer finds a deviation → routes
back to implementer with findings. Safety-auditor finds a violation →
implementer fixes. After bounded retries, it escalates to you instead of
thrashing.

**Knowledge compounds.** Each agent reads upstream Decisions and Constraints
before starting. Feature 20 benefits from everything learned building
features 1–19.

## The 14 Agents

```mermaid
graph LR
    subgraph Routing
        PC2[pre-check<br/>classify + route]
        RS[researcher<br/>discover]
        OR[oracle<br/>consult + verify]
        DG[doc-gardener<br/>drift sweep]
    end

    subgraph Building
        DE[designer<br/>backend / frontend]
        TW2[test-writer<br/>RED]
        IM[implementer<br/>GREEN]
    end

    subgraph Gates
        SR2[spec-reviewer<br/>CONFORMANT?]
        SA2[safety-auditor<br/>PASS?]
        OV2[oracle verify<br/>SOUND?]
    end

    subgraph Landing
        PL2[plan-lander<br/>LANDED?]
    end

    subgraph Bootstrap
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
| **High reasoning** | oracle, implementer, spec-reviewer, safety-auditor, designers, researcher | Design decisions, gate verdicts, deep analysis |
| **Standard reasoning** | pre-check, test-writer, plan-lander, doc-gardener, scaffolder, config-writer, docker-builder | Classification, pattern-following, verification |

See [THE-KEEL-PROCESS.md](process/THE-KEEL-PROCESS.md) for the full agent
roster with inputs, outputs, and tool access.

## Self-Correcting Gates

```mermaid
graph LR
    subgraph spec-reviewer
        SR3[Verdict] -->|CONFORMANT| N1[next step]
        SR3 -->|DEVIATION| F1[back to implementer]
        F1 -->|max 2| E1[escalate]
    end

    subgraph safety-auditor
        SA3[Verdict] -->|PASS| N2[next step]
        SA3 -->|VIOLATION| F2[back to implementer]
        F2 -->|max 3| E2[escalate]
    end

    subgraph oracle verify
        OV3[Verdict] -->|SOUND| N3[next step]
        OV3 -->|UNSOUND| F3[back to implementer]
        F3 -->|max 1| E3[escalate]
    end

    style SR3 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style SA3 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style OV3 fill:#7B1FA2,stroke:#4A148C,color:#fff
    style N1 fill:#388E3C,stroke:#1B5E20,color:#fff
    style N2 fill:#388E3C,stroke:#1B5E20,color:#fff
    style N3 fill:#388E3C,stroke:#1B5E20,color:#fff
    style F1 fill:#F57F17,stroke:#E65100,color:#000
    style F2 fill:#F57F17,stroke:#E65100,color:#000
    style F3 fill:#F57F17,stroke:#E65100,color:#000
    style E1 fill:#D32F2F,stroke:#B71C1C,color:#fff
    style E2 fill:#D32F2F,stroke:#B71C1C,color:#fff
    style E3 fill:#D32F2F,stroke:#B71C1C,color:#fff
```

MINOR-only deviations → CONFORMANT with notes (don't burn loops).

Gate agents output structured `**Verdict:**` fields. The orchestrator copies
verdicts to YAML frontmatter in the handoff file for reliable routing —
no parsing agent prose.

See [FAILURE-PLAYBOOK.md](process/FAILURE-PLAYBOOK.md) for the full decision
tree when gates fail.

## Wisdom Accumulation

```mermaid
graph LR
    PC3["pre-check<br/><b>Constraints:</b><br/>MUST / MUST NOT"] --> DE3["designer<br/><b>Decisions:</b> chose X<br/><b>Constraints:</b> MUST / MUST NOT"]
    DE3 --> IM3["implementer<br/><b>Decisions:</b> chose Y<br/><i>no constraints —<br/>can't bind own reviewers</i>"]

    style PC3 fill:#303F9F,stroke:#1A237E,color:#fff
    style DE3 fill:#00796B,stroke:#004D40,color:#fff
    style IM3 fill:#F57F17,stroke:#E65100,color:#000
```

Decision-heavy agents (pre-check, designers, oracle) produce both Decisions
and Constraints. The implementer produces Decisions only — it cannot
constrain its own reviewers (spec-reviewer, safety-auditor).

## Intent Classification

Pre-check classifies every feature before routing:

```mermaid
graph LR
    subgraph Intent
        I1[refactoring]
        I2[build]
        I3[mid-sized]
        I4[architecture]
        I5[research]
    end

    subgraph Complexity
        C1[trivial]
        C2[standard]
        C3[complex]
        C4[architecture-tier]
    end

    C1 --> R1[skip designer]
    C2 --> R2[normal pipeline]
    C3 --> R3[all gates]
    C4 --> R4[Oracle consult + verify]

    style I1 fill:#303F9F,stroke:#1A237E,color:#fff
    style I2 fill:#303F9F,stroke:#1A237E,color:#fff
    style I3 fill:#303F9F,stroke:#1A237E,color:#fff
    style I4 fill:#303F9F,stroke:#1A237E,color:#fff
    style I5 fill:#303F9F,stroke:#1A237E,color:#fff
    style C1 fill:#546E7A,stroke:#37474F,color:#fff
    style C2 fill:#00796B,stroke:#004D40,color:#fff
    style C3 fill:#F57F17,stroke:#E65100,color:#000
    style C4 fill:#D32F2F,stroke:#B71C1C,color:#fff
    style R1 fill:#546E7A,stroke:#37474F,color:#fff
    style R2 fill:#00796B,stroke:#004D40,color:#fff
    style R3 fill:#F57F17,stroke:#E65100,color:#000
    style R4 fill:#D32F2F,stroke:#B71C1C,color:#fff
```

This prevents over-engineering trivial changes and ensures complex changes
get the scrutiny they need.

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
