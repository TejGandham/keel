# How KEEL Works

KEEL encodes everything into the repo — specs, invariants, architecture,
testing strategy — and runs a self-correcting pipeline that gates quality
at every step.

## The Pipeline

```
                          KEEL Pipeline
 ┌─────────┐                                           ┌─────────┐
 │         │    classify    research?   design?         │         │
 │  Spec   │──▶ pre-check ──▶ researcher ──▶ oracle? ──▶│         │
 │         │    │ intent   │             │  consult  │  │         │
 └─────────┘    │ complexity│             │           │  │         │
                ▼           ▼             ▼           │  │         │
             ┌──────────────────────────────────────┐ │  │ Landed  │
             │  designer? ──▶ test-writer ──▶ implementer │  │ Feature │
             └──────────────────────────────────────┘ │  │         │
                                    │                 │  │         │
                ┌───────────────────▼─────────────┐   │  │         │
                │  spec-reviewer ──▶ safety-auditor?│──▶│         │
                │  CONFORMANT?       PASS?         │   │         │
                │  ↻ max 2          ↻ max 3        │   │         │
                └──────────────────────────────────┘   │         │
                                    │                  │         │
                         oracle-verify? ──────────────▶│         │
                         SOUND?                        └─────────┘
                         ↻ max 1
```

**The pipeline self-corrects.** Spec-reviewer finds a deviation → routes
back to implementer with findings. Safety-auditor finds a violation →
implementer fixes. After bounded retries, it escalates to you instead of
thrashing.

**Knowledge compounds.** Each agent reads upstream Decisions and Constraints
before starting. Feature 20 benefits from everything learned building
features 1–19.

## The 14 Agents

```
 ROUTING                 BUILDING               GATES                 LANDING
 ┌──────────┐           ┌──────────┐           ┌──────────────┐      ┌───────────┐
 │pre-check │           │test-     │           │spec-reviewer │      │plan-lander│
 │  classify│           │  writer  │           │  CONFORMANT? │      │  LANDED?  │
 │  route   │           │  RED     │           │  or DEVIATION│      │           │
 ├──────────┤           ├──────────┤           ├──────────────┤      └───────────┘
 │researcher│           │implement-│           │safety-auditor│
 │  discover│           │  er      │           │  PASS?       │
 ├──────────┤           │  GREEN   │           │  or VIOLATION│
 │oracle    │           └──────────┘           ├──────────────┤
 │  consult │                                  │oracle        │
 │  verify  │           ┌──────────┐           │  SOUND?      │
 ├──────────┤           │designer  │           │  or UNSOUND  │
 │doc-      │           │  backend │           └──────────────┘
 │ gardener │           │  frontend│
 └──────────┘           └──────────┘
                        ┌──────────┐
  BOOTSTRAP             │scaffolder│
  ┌──────────┐          │config-   │
  │docker-   │          │  writer  │
  │  builder │          └──────────┘
  └──────────┘
```

| Tier | Agents | Why |
|-|-|-|
| **High reasoning** | oracle, implementer, spec-reviewer, safety-auditor, designers, researcher | Design decisions, gate verdicts, deep analysis |
| **Standard reasoning** | pre-check, test-writer, plan-lander, doc-gardener, scaffolder, config-writer, docker-builder | Classification, pattern-following, verification |

See [THE-KEEL-PROCESS.md](process/THE-KEEL-PROCESS.md) for the full agent
roster with inputs, outputs, and tool access.

## Self-Correcting Gates

```
  spec-reviewer            safety-auditor           oracle (verify)
  ┌────────────────┐       ┌────────────────┐       ┌────────────────┐
  │ CONFORMANT ──▶ next    │ PASS ──────▶ next      │ SOUND ─────▶ next
  │ DEVIATION  ──▶ fix     │ VIOLATION ─▶ fix       │ UNSOUND ───▶ fix
  │ max 2 loops            │ max 3 loops             │ max 1 retry
  │ then: escalate         │ then: escalate          │ then: escalate
  └────────────────┘       └────────────────┘       └────────────────┘

  MINOR-only deviations → CONFORMANT with notes (don't burn loops)
```

Gate agents output structured `**Verdict:**` fields. The orchestrator copies
verdicts to YAML frontmatter in the handoff file for reliable routing —
no parsing agent prose.

See [FAILURE-PLAYBOOK.md](process/FAILURE-PLAYBOOK.md) for the full decision
tree when gates fail.

## Wisdom Accumulation

```
  pre-check                 designer                  implementer
  ┌──────────────┐         ┌──────────────┐          ┌──────────────┐
  │ Constraints: │────────▶│ Decisions:   │─────────▶│ Decisions:   │
  │ MUST: ...    │         │ chose X      │          │ chose Y      │
  │ MUST NOT: ...│         │ Constraints: │          │ (no constraints
  └──────────────┘         │ MUST: ...    │          │  — can't bind │
                           └──────────────┘          │  own reviewers)│
                                                     └──────────────┘
  Each agent reads upstream context before starting.
  Knowledge flows forward. Mistakes don't repeat.
```

Decision-heavy agents (pre-check, designers, oracle) produce both Decisions
and Constraints. The implementer produces Decisions only — it cannot
constrain its own reviewers (spec-reviewer, safety-auditor).

## Intent Classification

Pre-check classifies every feature before routing:

```
  Intent                Complexity              Routing
  ┌──────────────┐     ┌──────────────┐        ┌──────────────────────┐
  │ refactoring  │     │ trivial      │───────▶│ skip designer        │
  │ build        │     │ standard     │───────▶│ normal pipeline      │
  │ mid-sized    │     │ complex      │───────▶│ all gates            │
  │ architecture │     │ architecture │───────▶│ Oracle consult+verify│
  │ research     │     │   -tier      │        └──────────────────────┘
  └──────────────┘     └──────────────┘
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
