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

## KEEL (Soul)

KEEL — Knowledge-Encoded Engineering Lifecycle.
This repo follows the KEEL process. Claude owns everything. The human steers.
Consult [north-star.md](docs/north-star.md) at every decision point.

- **Docs drive code.** Never write code without reading the spec first.
- **Repo is truth.** If it's not in the repo, it doesn't exist.
- **Coding comes last.** Spec → test → code → verify. Always.
- **Progressive disclosure.** CLAUDE.md → ARCHITECTURE.md → specs → backlog.
- **Smallest testable units.** Each feature is independent and verifiable.
- **Garbage collect.** After each feature: are docs still accurate? Fix lies immediately.

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

## Workflow

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
