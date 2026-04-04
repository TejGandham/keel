# Quick Start: Your First Afternoon with KEEL

KEEL — Knowledge-Encoded Engineering Lifecycle. From clone to first feature through the pipeline.

## Prerequisites

- Claude Code installed and configured
- Docker installed
- A product idea (even rough is fine)

## The 10 Steps

### 1. Clone KEEL
```bash
git clone <keel-repo> my-project
cd my-project
./scripts/bootstrap.sh
```
The bootstrap script will prompt for project name, stack, and description, then replace placeholders in all template files.

### 2. Write your North Star
Open `docs/north-star.md`. Answer the guiding questions:
- What are we building and why?
- Who steers? Who (what agent) executes?
- What do we adopt fully from harness engineering?
- What do we adapt or skip for now?
- What does the folder structure look like when fully realized?
- What are the growth stages?

This is where you encode taste before it becomes linters.

### 3. Fill in CLAUDE.md
Replace all `[PROJECT_NAME]`, `[STACK]`, `[DESCRIPTION]` placeholders.
Keep it under 100 lines. It's a table of contents, not an encyclopedia.

### 4. Write your Product Spec
Copy `docs/product-specs/_TEMPLATE.md` to your spec file.
Define: what to build, actors, features, state machines, constraints.
Be specific enough that an agent can derive tests without asking questions.

### 5. Write Core Beliefs + Testing Strategy
Fill in `docs/design-docs/core-beliefs.md`:
- Your domain's non-negotiable safety rules
- Your testing layers (adapt the 6-layer model)
- Your design principles

### 6. Define Architecture Layers
Fill in `ARCHITECTURE.md`:
- Overview (1-2 sentences)
- Process/component model
- Data flow
- Module map (even if empty — define the categories)
- Layer dependencies (what calls what)

### 7. Define Domain Invariants
Look at `examples/domain-invariants/` for inspiration.
Write your invariants in `docs/design-docs/core-beliefs.md`.
Configure `.claude/agents/safety-auditor.md` with your rules.
Configure `.claude/hooks/safety-gate.sh` with your critical file patterns.

### 8. Configure Agents, Hooks, and Commands
Several agent definitions contain `<!-- CUSTOMIZE -->` comments marking
stack-specific commands that need your input. At minimum, configure:
- `.claude/agents/pre-check.md` — your compile/build command
- `.claude/agents/test-writer.md` — your test framework, mock framework, test command
- `.claude/agents/implementer.md` — your formatter, container command, domain invariants
- `.claude/agents/plan-lander.md` — your test command for each pipeline variant
- `.claude/agents/scaffolder.md` — your framework's scaffold command
- `.claude/agents/docker-builder.md` — your stack's required tools
- `.claude/agents/config-writer.md` — your compile/build command

Also configure hooks:
- `.claude/hooks/safety-gate.sh` — set the file patterns that trigger safety reminders
- `.claude/hooks/doc-gate.sh` — adjust the doc reference if needed

Hooks are already wired in `.claude/settings.json`.

### 9. Decompose into Feature Backlog
Open `docs/exec-plans/active/feature-backlog.md`.
List features as F01, F02, F03... with:
- Spec reference
- Dependencies (which features must land first)
- Pipeline assignment (bootstrap / backend / frontend / cross-cutting)

Start with bootstrap features (Docker, scaffold, config).

### 10. Run Your First Features

Bootstrap features (F01-F03) are orchestrator-direct — they use specialized agents, not the full pipeline:
```
/keel-pipeline F01 docs/design-docs/core-beliefs.md   # docker-builder → plan-lander
/keel-pipeline F02 docs/product-specs/your-spec.md     # scaffolder → plan-lander
/keel-pipeline F03 docs/design-docs/core-beliefs.md   # config-writer → plan-lander
```

After bootstrap, run your first real feature through the full pipeline:
```
/keel-pipeline F04 docs/product-specs/your-spec.md
```
The pipeline handles everything: pre-check → designer? → test-writer → implementer → spec-reviewer → plan-lander.

## What Happens Next

After bootstrap lands, the pipeline becomes your daily workflow:
1. Pick next feature from backlog
2. Run `/keel-pipeline F{id} spec-path`
3. Review the handoff file for context
4. Commit landed features
5. Run doc-gardener periodically

See [THE-KEEL-PROCESS.md](THE-KEEL-PROCESS.md) for the comprehensive guide.
