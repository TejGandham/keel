# KEEL

**Knowledge-Encoded Engineering Lifecycle** — spec in, stable tested code out.

## The Problem

AI agents are powerful code generators but terrible project partners. Give them a prompt and they'll produce code — but it drifts from specs, ignores safety rules, forgets decisions from yesterday, and produces untested slop at scale.

```
 Session 1          Session 2          Session 3
 ┌──────────┐      ┌──────────┐      ┌──────────┐
 │ "Build X"│      │ "Build Y"│      │ "Fix X"  │
 │          │      │          │      │          │
 │ Works!   │      │ Breaks X │      │ Breaks Y │
 └──────────┘      └──────────┘      └──────────┘
       Knowledge evaporates between sessions.
       Each feature is a fresh start.
```

A single rules file (`.cursorrules`, `AGENTS.md`) works until ~10 features. After that, you need specs, architecture docs, testing doctrine, and pipeline discipline. Ad-hoc prompting stops scaling.

## The Solution

KEEL encodes everything into the repo — specs, invariants, architecture, testing strategy — and runs a self-correcting pipeline that gates quality at every step.

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

**The pipeline self-corrects.** Spec-reviewer finds a deviation → routes back to implementer with findings. Safety-auditor finds a violation → implementer fixes. After bounded retries, it escalates to you instead of thrashing.

**Knowledge compounds.** Each agent reads upstream Decisions and Constraints before starting. Feature 20 benefits from everything learned building features 1–19.

## How It Works

```
 You write:                     KEEL does:
 ┌─────────────────┐           ┌──────────────────────────────────┐
 │ Product spec     │──────────▶│ 14 agents execute the pipeline   │
 │ Domain invariants│──────────▶│ Tests written before code        │
 │ Architecture doc │──────────▶│ Code verified against spec       │
 └─────────────────┘           │ Safety invariants enforced        │
                               │ Docs updated, drift detected     │
                               └──────────────┬───────────────────┘
                                              │
                                              ▼
                               ┌──────────────────────────────────┐
                               │ Tested, spec-conformant,         │
                               │ safe code — ready to commit      │
                               └──────────────────────────────────┘
```

### The 14 Agents

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

### Self-Correcting Gates

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

### Wisdom Accumulation

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

## Install

```bash
cd my-project    # new or existing
git clone --depth 1 https://github.com/<owner>/keel.git /tmp/keel
/tmp/keel/scripts/install.sh
rm -rf /tmp/keel
```

Installs into your project. Never overwrites existing files. Your code stays yours.

**What gets installed:** 14 agents, 3 skills, 2 hooks, doc structure, templates.
Full manifest: [INSTALL.md](docs/INSTALL.md)

**Existing codebase?** Run `/keel-adopt` after install — it scans your repo and
drafts CLAUDE.md, ARCHITECTURE.md, and invariants from what exists.

**Want to remove it?** [UNINSTALL.md](docs/UNINSTALL.md) — only deletes KEEL
artifacts, never your code.

### After Install

```
 1. CLAUDE.md              ← fill in <!-- CUSTOMIZE --> sections
 2. docs/north-star.md     ← your project vision
 3. safety-auditor.md      ← your domain invariants
 4. docs/product-specs/    ← write your first spec
 5. /keel-pipeline          ← run it
```

## Who KEEL Is For

```
 KEEL is overkill          KEEL scales              KEEL shines
 ┌─────────────┐          ┌──────────────┐         ┌───────────────┐
 │ < 5 features│          │ 10-30 features│         │ 30+ features  │
 │ one-off      │          │ growing scope │         │ safety-critical│
 │ throwaway    │          │ solo + agent  │         │ institutional  │
 │ prototype    │          │ correctness   │         │ knowledge      │
 └─────────────┘          │ matters       │         │ compounds      │
                          └──────────────┘         └───────────────┘
```

- **Solo developers or small teams (1-3)** with an AI agent as primary implementer
- **Projects that grow** — today's 3 features become next month's 30
- **Any AI agent platform** — process is agent-agnostic, reference implementation uses Claude Code

## Scope

```
 KEEL covers                              KEEL does not cover
 ┌────────────────────────────────┐       ┌──────────────────────────┐
 │ Product specs and design docs  │       │ CI/CD pipelines          │
 │ Architecture and module design │       │ Deployment               │
 │ Feature decomposition          │       │ Monitoring               │
 │ spec → test → code → verify    │       │ Incident response        │
 │ Domain invariant enforcement   │       │ Team scaling beyond 3    │
 │ Doc accuracy (garbage collect) │       │ Multi-repo coordination  │
 └────────────────────────────────┘       └──────────────────────────┘
 Boundary: the git commit.
 KEEL ensures code entering CI/CD is spec-conformant, tested, and safe.
```

## Case Study

[`examples/repo-man/`](examples/repo-man/) — Phoenix LiveView dashboard, 31 features, ~3000 lines of Elixir, 250+ tests, all spec-driven. [Case study](examples/repo-man/CASE-STUDY.md).

## Deep Dive

| What | Doc |
|-|-|
| Full artifact inventory | [INSTALL.md](docs/INSTALL.md) |
| Clean removal | [UNINSTALL.md](docs/UNINSTALL.md) |
| Comprehensive process guide | [THE-KEEL-PROCESS.md](docs/process/THE-KEEL-PROCESS.md) |
| First afternoon walkthrough | [QUICK-START.md](docs/process/QUICK-START.md) |
| Existing codebase adoption | [BROWNFIELD.md](docs/process/BROWNFIELD.md) |
| Terminology | [GLOSSARY.md](docs/process/GLOSSARY.md) |
| Pipeline failure decision tree | [FAILURE-PLAYBOOK.md](docs/process/FAILURE-PLAYBOOK.md) |
| What NOT to do | [ANTI-PATTERNS.md](docs/process/ANTI-PATTERNS.md) |

## License

This framework is provided as-is for use in AI-assisted software development.
