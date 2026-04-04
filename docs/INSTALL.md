# Installing KEEL

KEEL installs into your project — your code stays yours, KEEL adds the
scaffolding (agents, skills, doc structure). Nothing is overwritten.

## Quick Install

```bash
cd your-project
git clone --depth 1 https://github.com/anthropics/keel.git /tmp/keel
/tmp/keel/scripts/install.py
rm -rf /tmp/keel
```

The installer prompts for project name, stack, and description, then
copies everything into place.

## What Gets Installed

### `.claude/agents/` — 14 agent definitions

| Agent | Reasoning | Purpose |
|-|-|-|
| `pre-check.md` | high | Classify intent, evaluate readiness, route pipeline |
| `arch-advisor.md` | high | Architecture consultation and verification |
| `researcher.md` | high | Deep research before implementation |
| `backend-designer.md` | high | Module interfaces and data structures |
| `frontend-designer.md` | high | UI component design |
| `test-writer.md` | standard | Write tests from specs (never implementation) |
| `implementer.md` | high | Write code to pass tests (never modifies tests) |
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

### `.claude/skills/` — 3 skills

| Skill | Purpose |
|-|-|
| `keel-pipeline/SKILL.md` | Orchestrate the full pipeline for a feature |
| `keel-adopt/SKILL.md` | Adopt KEEL in an existing codebase |
| `safety-check/SKILL.md` | Quick safety audit on current changes |

### `.claude/hooks/` — 2 hooks

| Hook | Purpose |
|-|-|
| `safety-gate.py` | Pre-edit safety check on critical modules |
| `doc-gate.py` | Post-commit reminder to check for doc drift |

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
```

### Root files

| File | Purpose |
|-|-|
| `CLAUDE.md` | Project entry point (~80 lines, table of contents) |
| `ARCHITECTURE.md` | Module map, layers, dependencies |
| `Dockerfile` | Dev container template |
| `docker-compose.yml` | Container orchestration template |

## After Install

1. **`CLAUDE.md`** — Fill in `<!-- CUSTOMIZE -->` sections (safety rules,
   test commands, source layout)
2. **`docs/north-star.md`** — Define your project vision
3. **`.claude/agents/safety-auditor.md`** — Add your domain invariants
4. **`docs/design-docs/core-beliefs.md`** — Testing strategy + golden principles
5. **`docs/product-specs/`** — Write your first spec
6. **Run:** `/keel-pipeline my-feature docs/product-specs/my-spec.md`

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
git clone --depth 1 https://github.com/anthropics/keel.git /tmp/keel

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

## Existing Codebase?

After install, run `/keel-adopt` in Claude Code. It scans your repo and
drafts CLAUDE.md, ARCHITECTURE.md, and domain invariants from what exists.
See [BROWNFIELD.md](process/BROWNFIELD.md).
