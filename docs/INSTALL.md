# Installing KEEL

KEEL installs into your project — your code stays yours, KEEL adds the
scaffolding (agents, skills, doc structure). Nothing is overwritten.

## Quick Install

```bash
cd your-project
git clone --depth 1 https://github.com/TejGandham/keel.git /tmp/keel
python3 /tmp/keel/scripts/install.py
rm -rf /tmp/keel
```

The installer prompts for project name, stack, and description, then
copies everything into place.

## What Gets Installed

### `.claude/agents/` — 15 agent definitions

| Agent | Reasoning | Purpose |
|-|-|-|
| `pre-check.md` | high | Classify intent, evaluate readiness, route pipeline |
| `arch-advisor.md` | high | Architecture consultation and verification |
| `researcher.md` | high | Deep research before implementation |
| `backend-designer.md` | high | Module interfaces and data structures |
| `frontend-designer.md` | high | UI component design |
| `test-writer.md` | standard | Write tests from specs (never implementation) |
| `implementer.md` | high | Write code to pass tests (never modifies tests) |
| `code-reviewer.md` | high | Review code quality — DRY, patterns, edge cases |
| `spec-reviewer.md` | high | Verify code matches spec — gate agent |
| `safety-auditor.md` | high | Verify domain invariants — gate agent |
| `landing-verifier.md` | standard | Verify feature landed completely |
| `doc-gardener.md` | standard | Detect and report doc drift |
| `docker-builder.md` | standard | Build and verify Docker images |
| `scaffolder.md` | standard | Create project skeleton |
| `config-writer.md` | standard | Write config and boilerplate |

Each agent is a standalone markdown file with YAML frontmatter (name,
description, tools, model). The prompt is the body of the file.

**Customization:** Look for `<!-- CUSTOMIZE -->` comments inside each
agent. At minimum, fill in `safety-auditor.md` with your domain invariants.

### `.claude/skills/` — 4 skills

| Skill | Purpose |
|-|-|
| `keel-pipeline/SKILL.md` | Orchestrate the full pipeline for a feature |
| `keel-adopt/SKILL.md` | Adopt KEEL in an existing codebase |
| `keel-setup/SKILL.md` | Post-install greenfield setup (interactive) |
| `safety-check/SKILL.md` | Quick safety audit on current changes |

### `.claude/hooks/` — 2 hooks

| Hook | Purpose |
|-|-|
| `safety-gate.py` | Pre-edit safety check on critical modules |
| `doc-gate.py` | Post-commit reminder to check for doc drift |

### Optional: Roundtable MCP server

KEEL integrates with the roundtable MCP server for multi-model advisory
review at two pipeline points:

- **Post-designer (Step 2.5):** `architect` + `challenge` tools review design output
- **Pre-landing (Step 8.5):** `xray` + `challenge` tools review implementation

Roundtable is optional. When the MCP server is unavailable, these steps are
skipped gracefully — the pipeline never blocks on an external service.

To enable: install and configure the roundtable MCP server in your Claude Code
settings. KEEL detects it automatically. Set `Roundtable review: false` in
CLAUDE.md to disable even when available.

### `docs/` — document structure

```
docs/
  north-star.md                         # Vision and principles
  product-specs/
    _TEMPLATE.md                        # Spec template
  design-docs/
    core-beliefs.md                     # Domain invariants + testing strategy
    ui-design.md                        # Design tokens (if frontend)
    index.md                            # Design doc index
  exec-plans/
    active/
      feature-backlog.md                # Ordered feature list
      handoffs/
        _TEMPLATE.md                    # Handoff file template (YAML frontmatter)
    completed/
      handoffs/                         # Archived handoff files
    tech-debt-tracker.md                # Known shortcuts
  references/
    README.md                           # External docs, API contracts
  process/
    THE-KEEL-PROCESS.md                 # Comprehensive process guide
    QUICK-START.md                      # First afternoon walkthrough
    BROWNFIELD.md                       # Adopting in existing codebase
    GLOSSARY.md                         # KEEL terminology
    ANTI-PATTERNS.md                    # What to avoid
    FAILURE-PLAYBOOK.md                 # Pipeline failure decision tree
    AUTONOMY-PROGRESSION.md             # Stages of agent autonomy
```

### Root files

| File | Purpose |
|-|-|
| `CLAUDE.md` | Project entry point (~80 lines, table of contents) |
| `ARCHITECTURE.md` | Module map, layers, dependencies |
| `Dockerfile` | Dev container template |
| `docker-compose.yml` | Container orchestration template |

## After Install

Open Claude Code in your project directory and run:

- **New project (no existing code):** `/keel-setup`
- **Existing codebase:** `/keel-adopt`

The skill walks you through all configuration interactively — CLAUDE.md,
north star, architecture, domain invariants, agent config. Everything is
drafted from context first, then presented for your review.

After setup, write your first product spec and run:
`/keel-pipeline my-feature docs/product-specs/my-spec.md`

### `scripts/validate-handoff.py` — handoff file validator

Validates any completed handoff file for structural integrity:

```bash
python scripts/validate-handoff.py docs/exec-plans/completed/handoffs/
python scripts/validate-handoff.py docs/exec-plans/active/handoffs/F13.md
```

Checks: YAML frontmatter, pipeline-aware sections, gate verdicts, routing
fields, status consistency. Zero dependencies (Python 3.10+).

## Important: Your Customizations Live in Agent Files

KEEL agents contain `<!-- CUSTOMIZE -->` sections where you add your
project-specific rules (domain invariants in `safety-auditor.md`, test
commands in `test-writer.md`, source layout in `pre-check.md`, etc.).

**These customizations live in the same files as the framework prompts.**
If you overwrite agents during an update, you will lose your customizations.
Always back up before updating and diff before overwriting.

## Updating KEEL

The installer is a one-time copy. To update agents or skills later:

```bash
git clone --depth 1 https://github.com/TejGandham/keel.git /tmp/keel

# Update specific agents (review diff before overwriting)
diff /tmp/keel/.claude/agents/arch-advisor.md .claude/agents/arch-advisor.md
cp /tmp/keel/.claude/agents/arch-advisor.md .claude/agents/arch-advisor.md

# Or update all agents (backup first if you customized prompts)
cp -r .claude/agents .claude/agents.bak
cp /tmp/keel/.claude/agents/*.md .claude/agents/

rm -rf /tmp/keel
```

Process docs in `docs/process/` can be updated the same way — they are
reference material, not project-specific.

### Migration: PR-only landing

Earlier KEEL versions offered configurable landing strategies (`merge`,
`pr`, `auto`). These were removed — KEEL now always pushes the feature
branch and opens a PR on your forge.

If upgrading:
- **CLAUDE.md:** the `## Landing Preferences` section was replaced by
  `## Pipeline Preferences`, which keeps only the `Roundtable review`
  knob. Update your project's CLAUDE.md to match the template.
- **Handoff schema:** `landing_strategy` and `landing_strategy_resolved`
  fields are gone. A new `pr_url` field is set after `gh pr create`.
- **Need a different landing flow?** Edit Step 9 of
  `.claude/skills/keel-pipeline/SKILL.md` in your project — the skill
  is a first-class customization point.
- **Handoff status change:** `landing-verifier` now emits `VERIFIED`
  instead of `LANDED`. Existing completed handoff files with
  `status: LANDED` remain valid — the validator accepts both.

## Existing Codebase?

After install, run `/keel-adopt` in Claude Code. It scans your codebase,
drafts CLAUDE.md, ARCHITECTURE.md, and domain invariants from what it finds.
See [BROWNFIELD.md](process/BROWNFIELD.md).
