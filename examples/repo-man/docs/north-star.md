# North Star: Keel

Adapted from [OpenAI's harness engineering article](https://openai.com/index/harness-engineering/).
This document defines where we're heading — not where we are today.

## The Principle

Humans steer. Claude executes. The repo is Claude's workspace, context, and
system of record. Everything Claude needs to make decisions lives here.

## What We Adopt (Fully)

**Repository = system of record.** If it's not in the repo, it doesn't exist
to Claude. Slack discussions, verbal decisions, tacit knowledge — all must be
encoded as markdown, code, or config in this repo.

**CLAUDE.md as table of contents.** ~80 lines, pointers to deeper docs. Not an
encyclopedia. Teaches Claude what this project is and where to look next.

**Progressive disclosure.** CLAUDE.md → ARCHITECTURE.md → specs → plans.
Claude reads what it needs when it needs it.

**Plans as first-class artifacts.** Active plans in `exec-plans/active/`,
completed plans in `exec-plans/completed/`. Progress and decisions logged
in the plan itself.

**Agent legibility is the goal.** Docs are written for Claude's comprehension,
not for a human audience. Clear, scannable, with explicit cross-references.

## What We Adapt (Scaled Down)

**Mechanical enforcement.** OpenAI uses custom linters and structural tests
from day one. We start with `mix format` and `mix test`, adding structural
tests after the module layout stabilizes (Stage 2).

**Garbage collection.** OpenAI runs background agents to scan for drift.
We do manual review at session boundaries — Claude re-reads CLAUDE.md and
ARCHITECTURE.md at the start of each session and flags staleness.

**Agent review loops.** OpenAI has agents reviewing agents' PRs. We use
Claude's self-review capabilities (pr-review-toolkit) before presenting
work to Tej.

**Observability stack.** OpenAI wires up Victoria Logs/Metrics/Traces.
We start with Docker stdout/stderr. Add structured logging after MVP.

## What We Skip (For Now)

- No `PLANS.md` index — too few plans to warrant it
- No `QUALITY.md` — no code to score yet (add at Stage 2)
- No `RELIABILITY.md` — add after MVP when patterns emerge
- No automated doc-gardening — manual at session boundaries
- No Chrome DevTools MCP — LiveView test helpers suffice for validation

## Target Folder Structure (Fully Realized)

```
CLAUDE.md                           # ~80 lines, table of contents
ARCHITECTURE.md                     # Process model, layers, module map
Dockerfile                          # Dev container
docker-compose.yml                  # Orchestration

docs/
├── north-star.md                   # This document
├── product-specs/
│   ├── index.md
│   └── mvp-spec.md
├── design-docs/
│   ├── index.md
│   ├── core-beliefs.md             # Golden principles
│   └── ui-design.md               # Card anatomy, colors, typography
├── exec-plans/
│   ├── active/                     # Plans being executed
│   ├── completed/                  # Finished plans
│   └── tech-debt-tracker.md        # Known shortcuts
├── references/
│   └── brainstorm/                 # HTML mockups from design sessions
├── QUALITY.md                      # Quality score (added Stage 2)
└── RELIABILITY.md                  # Error handling patterns (added Stage 3)

repo_man/                           # Phoenix project root
├── lib/repo_man/                   # Business logic
├── lib/repo_man_web/               # Web layer
├── test/                           # Tests
├── config/                         # Phoenix config
└── mix.exs
```

## Growth Stages

| Stage | Trigger | Keel Additions |
|-------|---------|-------------------|
| **0: Foundation** | Before first code | Folder structure, CLAUDE.md ToC, ARCHITECTURE.md, core-beliefs, Docker, git init |
| **1: First Code** | Git module works | Tech debt updates, `mix format --check-formatted` |
| **2: Working App** | LiveView renders | QUALITY.md (first score), structural test for module coverage |
| **3: MVP Complete** | All 10 success criteria | Move plan to completed/, RELIABILITY.md, garbage collection pass |
| **4: Post-MVP** | New features | New plans in active/, periodic doc review, consider pre-commit hooks |

## The Four Loops (Adapted from Article Diagrams)

### 1. Validation Loop
```
Claude writes code → runs mix test → checks output →
fixes failures → re-runs → repeats until green
```
LiveView test helpers (`live/2`, `render_click/3`) for UI validation.
No browser automation needed — server-rendered HTML.

### 2. Knowledge Boundary
```
┌─────────────────────────────┐
│    What Claude CAN see      │
│  Code, markdown, schemas,   │
│  exec plans, tests, configs │
└─────────────────────────────┘
        ↑ must encode ↑
┌─────────────────────────────┐
│   What Claude CAN'T see     │
│  Slack, verbal decisions,   │
│  Tej's head, Google Docs    │
└─────────────────────────────┘
```

### 3. Layered Architecture
```
DashboardLive (UI)
      ↓
RepoSupervisor (Runtime)
      ↓
RepoServer (Service)
      ↓
Git + RepoStatus (Foundation)
```
Dependencies flow strictly downward. Enforced by convention now,
by structural tests later (Stage 2).

### 4. Garbage Collection
After each implementation chunk:
- Re-read CLAUDE.md — still accurate?
- Re-read ARCHITECTURE.md — still matches code?
- Update tech-debt-tracker with new shortcuts
- Fix any docs that lie
