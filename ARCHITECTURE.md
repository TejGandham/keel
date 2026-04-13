# Architecture

This describes the **KEEL framework repo itself**. For the template that
gets installed into user projects, see `template/ARCHITECTURE.md`.

## Overview

KEEL is a markdown-driven agent framework for AI-assisted development.
It has no runtime, no server, no binary. The "architecture" is an
artifact bundle (agents, skills, hooks, docs, templates) plus a set of
Python installers that copy that bundle into a user's repo. The
framework ships by being cloned.

## Component Model

```
                ┌─────────────────────────────┐
                │  KEEL source repo (this)    │
                ├─────────────────────────────┤
                │  .claude/                   │
                │    agents/    (15 prompts)  │
                │    skills/    (4 skills)    │
                │    hooks/     (2 hooks)     │
                │    settings.json            │
                │  template/                  │
                │    CLAUDE.md                │
                │    ARCHITECTURE.md          │
                │    Dockerfile               │
                │    docker-compose.yml       │
                │    docs/                    │
                │  docs/                      │
                │    process/   (6 guides)    │◄── copied to user
                │    HOW-IT-WORKS.md          │    (framework-only)
                │    INSTALL.md               │    (framework-only)
                │    references/              │    (framework-only)
                │  scripts/                   │
                │    install.py               │
                │    uninstall.py             │
                │    validate-handoff.py      │
                │  examples/                  │
                │    domain-invariants/       │◄── reference for users
                └─────────────────────────────┘
                           │
                   install.py runs
                           ▼
                ┌─────────────────────────────┐
                │  User project               │
                ├─────────────────────────────┤
                │  .claude/agents/  (copied)  │
                │  .claude/skills/  (copied)  │
                │  .claude/hooks/   (copied)  │
                │  .claude/keel-uninstall.py  │
                │  CLAUDE.md        (from tmpl)│
                │  ARCHITECTURE.md  (from tmpl)│
                │  Dockerfile       (from tmpl)│
                │  docker-compose.yml         │
                │  docs/            (from tmpl)│
                │  docs/process/    (copied)  │
                └─────────────────────────────┘
```

## Data Flow — installing KEEL into a project

```
User runs: python3 scripts/install.py
  → resolve_keel_source()    finds local clone or git-clones from GitHub
  → prompts for              project name, stack, description
  → copies .claude/agents/   (skips existing files)
  → copies .claude/skills/   keel-pipeline, keel-adopt, safety-check
  → copies .claude/hooks/    safety-gate.py, doc-gate.py
  → copies .claude/settings.json if missing
  → copies scripts/uninstall.py as .claude/keel-uninstall.py
  → copies template/         CLAUDE.md, ARCHITECTURE.md, Dockerfile,
                              docker-compose.yml, docs/ tree
  → replace_placeholders()   [PROJECT_NAME], [STACK], [DESCRIPTION]
                              across every text file newer than
                              reference mtime; strips DELETE AFTER
                              FILLING comments
  → copies docs/process/     6 reference guides into user's docs/process/
```

Existing files are never overwritten. Placeholder replacement is scoped
by mtime against `.claude/agents/pre-check.md` so pre-existing user
files are untouched.

## Data Flow — a feature running through the shipped pipeline

```
User writes spec in docs/product-specs/
  → /keel-pipeline          reads spec, creates handoff
  → pre-check                classifies intent, decides variant
  → researcher?              if pre-check flags research needed
  → backend-designer? /      if pre-check flags designer needed
    frontend-designer?
  → test-writer              writes tests from spec
  → implementer              writes code to pass tests
  → code-reviewer            quality gate
  → spec-reviewer            spec-conformance gate (self-correct ≤2)
  → safety-auditor?          invariant gate, if touching critical code
                             (self-correct ≤3)
  → landing-verifier         final gate — feature landed cleanly
  → Step 9 post-LANDED procedure (runs automatically after LANDED):
    → doc-gardener           repo-wide drift sweep; orchestrator applies fixes
    → handoff archived       active/handoffs/ → completed/handoffs/
    → tech-debt-tracker      log shortcuts, check off resolved items
    → git add -A, commit     commit subject from spec H1 + verdict table body
    → git push -u origin     to keel/F{id}-{slug} feature branch
    → gh pr create --fill    ready-for-review PR (falls back to manual instructions
                             if gh is missing or not authed)
```

Each agent reads and appends to the same handoff file in
`docs/exec-plans/active/handoffs/F{id}-{name}.md`.
`scripts/validate-handoff.py` enforces handoff-file structure.

## Module Map

|Module|File|Responsibility|Depends On|
|-|-|-|-|
|Installer|`scripts/install.py`|Copy framework artifacts into user project|stdlib only|
|Uninstaller|`scripts/uninstall.py`|Remove KEEL artifacts while preserving user customizations|stdlib only|
|Handoff validator|`scripts/validate-handoff.py`|Structural checks on pipeline handoff files|stdlib only|
|Agents|`.claude/agents/*.md`|15 prompts with YAML frontmatter (name, description, tools, model)|read by Claude Code|
|Skills|`.claude/skills/*/SKILL.md`|Orchestration entry points (`keel-pipeline`, `keel-adopt`, `keel-setup`, `safety-check`, `dev-up`)|read by Claude Code|
|Hooks|`.claude/hooks/*.py`|`safety-gate.py` (PreToolUse on Edit/Write), `doc-gate.py` (PostToolUse on Bash)|stdlib only|
|Template|`template/`|Files copied into user projects verbatim, with placeholder substitution|none|
|Process docs|`docs/process/*.md`|Reference guides copied into every install|none|
|Framework docs|`docs/HOW-IT-WORKS.md`, `docs/INSTALL.md`, `docs/UNINSTALL.md`|Describe the framework itself; not copied to installs|none|

## Layer Dependencies

```
[ Documentation layer ]       README.md, NORTH-STAR.md, docs/
        ↓ describes
[ Artifact layer ]            .claude/, template/, examples/
        ↓ copied by
[ Install layer ]             scripts/install.py, scripts/uninstall.py
        ↓ invoked from
[ User project ]              (outside this repo)
```

Dependencies flow strictly downward. The install layer knows about
artifacts, but artifacts never know about the installer. Docs describe
artifacts, artifacts never reference specific doc files by path outside
the install bundle.

## Key Design Decisions

- **Markdown-driven, no runtime.** The framework is a bundle of
  prompts and Python install scripts. This keeps KEEL portable across
  any agent platform that reads markdown — and avoids a package-manager
  dependency for users.
- **Stdlib-only Python 3.10+.** The installer must run on a clean
  machine before any project deps exist, so adding any third-party
  dependency would create a bootstrap problem. Python over shell for
  cross-platform behavior (bash assumptions don't hold on Windows).
- **Copy, don't link.** Install copies files into the user's repo so
  users own their customizations. Updates are a manual diff-and-copy
  (see `docs/INSTALL.md` §Updating).
- **Never overwrite.** `install.py` skips any file that already exists.
  This is the only safe policy for a tool that writes into user repos.
- **One feature, one handoff file.** Every agent in a pipeline run
  reads and appends to the same markdown file. Handoff is the
  serialization format between agents.
- **Bounded self-correction.** Gate agents self-correct up to a fixed
  count before escalating: spec-reviewer ≤2, safety-auditor ≤3,
  arch-advisor ≤1, code-reviewer ≤1. Never unbounded retry loops.
- **Accuracy over speed.** The pipeline can grow more agents and more
  gates without apology. See `NORTH-STAR.md` §The Principle.

## Container Architecture

KEEL itself does not run in a container. The `Dockerfile` and
`docker-compose.yml` at the repo root are **templates** — they are
copied into user projects and customized per stack. See
`template/Dockerfile` for the source.

## What is NOT in this architecture

- No runtime server or daemon
- No database or persistent state (handoff files on disk are per-feature)
- No network calls outside `git clone` in the installer
- No cross-repo orchestration
- No CI/CD integration — KEEL's boundary is the git commit
