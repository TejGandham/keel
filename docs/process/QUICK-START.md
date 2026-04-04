# Quick Start: Your First Afternoon with KEEL

KEEL — Knowledge-Encoded Engineering Lifecycle. From clone to first feature through the pipeline.

## Prerequisites

- An AI coding agent (Claude Code, Codex, Cursor, etc.)
- Docker installed (or your stack's runtime)
- A product idea (even rough is fine)

## How KEEL Grows With Your Project

You don't need everything on day one. KEEL is designed to match the weight
of your project at each stage:

| Stage | What you add | What it unlocks |
|-|-|-|
| **Day 1** | CLAUDE.md + core-beliefs.md | Agent has project context and safety rules |
| **Day 2** | Product spec + ARCHITECTURE.md | Agent can reason about what to build and where it fits |
| **Week 1** | Feature backlog + first handoff files | Structured pipeline execution begins |
| **Week 2+** | Safety-auditor config + domain invariants | Mechanical enforcement of non-negotiable rules |
| **Month 2+** | Full pipeline + garbage collection | Institutional knowledge compounds across features |

Start with whatever you need now. Add the rest as complexity demands it.
The framework catches you when ad-hoc prompting stops scaling.

## The 10 Steps

### 1. Install KEEL
```bash
# New project
mkdir my-project && cd my-project && git init

# Install KEEL into your project
git clone --depth 1 https://github.com/TejGandham/keel.git /tmp/keel
python3 /tmp/keel/scripts/install.py
rm -rf /tmp/keel
```
The installer prompts for project name, stack, and description. It copies
agents, skills, doc structure, and template files into your project. It
never overwrites existing files — safe for existing projects too.

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
The installer already replaced `[PROJECT_NAME]`, `[STACK]`, `[DESCRIPTION]`.
Now fill in the `<!-- CUSTOMIZE -->` sections: safety rules, test commands,
source layout. Keep it under 100 lines — table of contents, not encyclopedia.

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
Configure `.claude/hooks/safety-gate.py` with your critical file patterns.

### 8. Configure Agents, Hooks, and Commands
Several agent definitions contain `<!-- CUSTOMIZE -->` comments marking
stack-specific commands that need your input. At minimum, configure:
- `.claude/agents/pre-check.md` — your compile/build command
- `.claude/agents/test-writer.md` — your test framework, mock framework, test command
- `.claude/agents/implementer.md` — your formatter, container command, domain invariants
- `.claude/agents/landing-verifier.md` — your test command for each pipeline variant
- `.claude/agents/scaffolder.md` — your framework's scaffold command
- `.claude/agents/docker-builder.md` — your stack's required tools
- `.claude/agents/config-writer.md` — your compile/build command

Also configure hooks:
- `.claude/hooks/safety-gate.py` — set the file patterns that trigger safety reminders
- `.claude/hooks/doc-gate.py` — adjust the doc reference if needed

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
/keel-pipeline F01 docs/design-docs/core-beliefs.md   # docker-builder → landing-verifier
/keel-pipeline F02 docs/product-specs/your-spec.md     # scaffolder → landing-verifier
/keel-pipeline F03 docs/design-docs/core-beliefs.md   # config-writer → landing-verifier
```

After bootstrap, run your first real feature through the full pipeline:
```
/keel-pipeline F04 docs/product-specs/your-spec.md
```
The pipeline handles everything: pre-check → designer? → test-writer → implementer → spec-reviewer → landing-verifier.

## What Happens Next

After bootstrap lands, the pipeline becomes your daily workflow:
1. Pick next feature from backlog
2. Run `/keel-pipeline F{id} spec-path`
3. Review the handoff file for context
4. Commit landed features
5. Run doc-gardener periodically

When the pipeline stalls, see [FAILURE-PLAYBOOK.md](FAILURE-PLAYBOOK.md) for the decision tree.

See [THE-KEEL-PROCESS.md](THE-KEEL-PROCESS.md) for the comprehensive guide.
