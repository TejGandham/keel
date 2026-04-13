# [PROJECT_NAME]

<!-- DELETE AFTER FILLING: Replace [PROJECT_NAME] with your project name.
     Replace [DESCRIPTION] with a 1-2 sentence description.
     Replace [STACK] with your tech stack.
     Keep this file under 100 lines. It's a table of contents, not an encyclopedia. -->

[DESCRIPTION]

## Quick Facts

- **Stack:** [STACK]
- **Development:** Docker container driven. No local runtime dependencies.
- **User:** <!-- CUSTOMIZE: who uses this? Single dev? Team? -->
- **Claude's role:** Sole builder. Design, development, maintenance, documentation.

## KEEL — Mandatory Process

**KEEL is not a suggestion. It is the engineering process for this repo. You MUST follow it.**

KEEL — Knowledge-Encoded Engineering Lifecycle.
Claude owns execution. The human steers. Every action you take MUST go through the KEEL pipeline defined below. There are no exceptions, no shortcuts, no "just this once."

Consult [north-star.md](docs/north-star.md) at every decision point.

### Non-negotiable rules

You MUST obey all six rules. Violating any one of them is a process failure.

1. **Docs drive code.** You MUST read the spec before writing any code. No spec, no code.
2. **Repo is truth.** If it is not in the repo, it does not exist. Do not act on assumptions.
3. **Coding comes last.** Spec → test → code → verify. You MUST NOT skip or reorder steps.
4. **Progressive disclosure.** Read CLAUDE.md → ARCHITECTURE.md → specs → backlog. In that order.
5. **Smallest testable units.** Each feature is independent and verifiable. Do not bundle.
6. **Garbage collect.** After each feature: verify docs are still accurate. Fix lies immediately.

### What you MUST NOT do

- Do NOT write code without a spec and a failing test.
- Do NOT skip pipeline stages or run them out of order.
- Do NOT treat the pipeline as a guideline you can adapt "for efficiency."
- Do NOT make architectural decisions outside of the designer stage.
- Do NOT commit without landing-verifier confirmation.
- Do NOT invent your own workflow. The pipeline IS the workflow.

**Any deviation from this process requires explicit, written permission from the human in the loop.** "I think it would be faster" is not permission. "This case seems different" is not permission. Only a direct human instruction to skip or alter a step counts. If in doubt, ask — do not assume.

## Safety Rules

<!-- CUSTOMIZE: Define your domain's non-negotiable invariants.
     Examples:
     - Git domain: Never force-pull, always --ff-only, never switch branches.
     - API domain: Validate at boundaries, auth every endpoint, no raw SQL.
     - Data pipeline: Idempotent transforms, schema validation, no silent data loss.
     See examples/domain-invariants/ for templates. -->

1. [YOUR INVARIANT RULE 1]
2. [YOUR INVARIANT RULE 2]
3. Docker for everything. No local runtime dependencies.
4. Update docs when you change behavior. Docs that lie are worse than no docs.

## Workflow — Mandatory Pipelines

Every feature MUST go through one of the pipelines below. The orchestrator selects which pipeline based on the feature type. You MUST NOT execute steps outside of the assigned pipeline.

### Bootstrap pipeline
```
docker-builder → landing-verifier
scaffolder → landing-verifier
config-writer → landing-verifier
```

### Backend pipeline
```
pre-check → researcher? → backend-designer? → test-writer → implementer → code-reviewer → spec-reviewer → safety-auditor? → landing-verifier
```
Designer skipped when pre-check says `Designer needed: NO`.
Safety-auditor only for features touching domain-critical modules.

### Frontend pipeline
```
pre-check → researcher? → frontend-designer → test-writer → implementer → code-reviewer → spec-reviewer → landing-verifier
```

### Cross-cutting pipeline
```
pre-check → test-writer → implementer → code-reviewer → landing-verifier
```

### Handoffs
Each feature gets `docs/exec-plans/active/handoffs/F{id}-{feature-name}.md`.
Each agent's output is appended. Next agent reads the handoff file.
Moved to `completed/handoffs/` when feature lands.

### After landing-verifier reports LANDED
The orchestrator runs Step 9 (post-LANDED procedure) automatically:
1. `doc-gardener` agent → apply any reported drift fixes to the working tree
2. Move handoff: `active/handoffs/F{id}-{slug}.md` → `completed/handoffs/F{id}-{slug}.md`
3. Log any new shortcuts to `tech-debt-tracker.md`
4. `git add -A` → commit `feat(F{id}): {title from spec H1}` with spec ref + verdict table
5. `git push -u origin HEAD` (branch is already `keel/F{id}-{slug}`, set at "Before Starting")
6. `gh pr create --fill` (ready-for-review; falls back to manual PR instructions if gh is absent)

The human reviews the PR on GitHub, not each step. No per-commit approval.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for process model, data flow, and module map.

## Specs

- [Product spec](docs/product-specs/) — What to build
- [Core beliefs](docs/design-docs/core-beliefs.md) — Principles + testing strategy
<!-- CUSTOMIZE: Add your spec files here -->

## Plans

- [Feature backlog](docs/exec-plans/active/feature-backlog.md) — Features, execute top-to-bottom
- [Completed plans](docs/exec-plans/completed/) — Finished (reference only)
- [Tech debt tracker](docs/exec-plans/tech-debt-tracker.md) — Known shortcuts

## Development

```bash
docker compose up                     # starts dev server
docker compose build                  # rebuild after Dockerfile changes
<!-- CUSTOMIZE: Add your test command, e.g.:
docker compose run --rm app mix test  # Elixir
docker compose run --rm app npm test  # Node
docker compose run --rm app pytest    # Python -->
```

## References

- [North star](docs/north-star.md) — KEEL process vision
- [KEEL process guide](docs/process/THE-KEEL-PROCESS.md) — Comprehensive how-to
