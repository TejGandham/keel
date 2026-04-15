# Quick Start: Your First Afternoon with KEEL

KEEL — Knowledge-Encoded Engineering Lifecycle. From install to first feature through the pipeline.

> New here? Visual walkthrough at [tejgandham.github.io/keel](https://tejgandham.github.io/keel/).

## Prerequisites

- [Claude Code](https://claude.com/claude-code) — the only supported agent runtime today
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

## The 3 Steps

### 1. Install KEEL

```bash
# New project
mkdir my-project && cd my-project && git init

# Existing project
cd my-project

# Install KEEL
git clone --depth 1 https://github.com/TejGandham/keel.git /tmp/keel
python3 /tmp/keel/scripts/install.py
rm -rf /tmp/keel
```

The installer prompts for project name, stack, and description. It copies
agents, skills, doc structure, and template files into your project,
replaces placeholders, and cleans up instruction comments. It never
overwrites existing files.

### 2. Configure with Claude Code

Open Claude Code in your project directory and run the command the
installer printed:

- **New project (no existing code):** `/keel-setup`
- **Existing codebase:** `/keel-adopt`

Both skills walk you through everything interactively:
- CLAUDE.md refinement (project identity, safety rules, commands)
- North star (vision, growth stages, principles)
- Architecture (layers, modules, data flow)
- Domain invariants (per-item confirmation)
- Safety enforcement and agent configuration

Every phase drafts from context first, then asks you to review.
You confirm at every gate.

### 3. Run Your First Feature

Create your feature backlog and write your first product spec:
```
docs/exec-plans/active/feature-backlog.md    # Ordered feature list
docs/product-specs/my-spec.md                # Your first spec
```

Then run the pipeline:
```
/keel-pipeline F01 docs/product-specs/my-spec.md
```

Bootstrap features (F01-F03) use specialized agents — Docker, scaffold,
config. After bootstrap, the full pipeline handles everything (simplified):
pre-check → arch-advisor? → designer? → roundtable? → test-writer →
implementer → code-reviewer → spec-reviewer → safety-auditor? →
arch-advisor-verify? → landing-verifier → roundtable? → land per strategy.
See `template/CLAUDE.md` for the canonical pipeline variants.

## What Happens Next

After bootstrap lands, the pipeline becomes your daily workflow:
1. Pick next feature from backlog
2. Run `/keel-pipeline F{id} spec-path`
3. Watch the pipeline — it runs end-to-end, self-corrects at gates, and stops in-session only on escalation
4. Review the resulting PR — the pipeline archives the handoff, commits, pushes the feature branch, and opens a PR on your forge for you to review and merge

When the pipeline stalls, see [FAILURE-PLAYBOOK.md](FAILURE-PLAYBOOK.md) for the decision tree.

See [THE-KEEL-PROCESS.md](THE-KEEL-PROCESS.md) for the comprehensive guide.
