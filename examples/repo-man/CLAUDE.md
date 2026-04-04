# Repo Man

Single-page localhost Phoenix LiveView dashboard for monitoring and syncing
git repos under `~/src/repos/`. Pre-flight checklist for software architecture
work — ensures the codebase is current before making design decisions.

## Quick Facts

- **Stack:** Elixir, Phoenix 1.7+, LiveView, Tailwind CSS, minimal JS hooks. No Ecto, no npm.
- **Development:** Docker container driven. No local Elixir/Erlang.
- **User:** Single developer (Tej), localhost only.
- **Claude's role:** Sole builder. Design, development, maintenance, documentation.

## Keel (Soul)

This repo follows the Keel process. Claude owns everything. Tej steers.
Consult [north-star.md](docs/north-star.md) at every decision point.

- **Docs drive code.** Never write code without reading the spec first.
- **Repo is truth.** If it's not in the repo, it doesn't exist.
- **Coding comes last.** Spec → test → code → verify. Always.
- **Progressive disclosure.** CLAUDE.md → ARCHITECTURE.md → specs → backlog.
- **Smallest testable units.** Each feature is independent and verifiable.
- **Garbage collect.** After each feature: are docs still accurate? Fix lies immediately.

## Safety Rules

1. Never force-pull, never pull on dirty repos, never switch branches, never modify files.
2. `--ff-only` always. Non-negotiable.
3. Docker for everything. No local runtime dependencies.
4. Update docs when you change behavior. Docs that lie are worse than no docs.

## Workflow

### Bootstrap pipeline (F01-F03)
```
docker-builder → plan-lander          (F01)
scaffolder → plan-lander              (F02)
config-writer → plan-lander           (F03)
```

### Backend pipeline (F04-F16)
```
pre-check → researcher? → backend-designer? → test-writer → implementer → spec-reviewer → safety-auditor? → plan-lander
```
Designer skipped when pre-check says `Designer needed: NO`.
Safety-auditor only for features touching fetch/pull/RepoServer.

### Frontend pipeline (F17-F28)
```
pre-check → researcher? → frontend-designer → test-writer → implementer → spec-reviewer → plan-lander
```

### Cross-cutting pipeline (F29-F31)
```
pre-check → test-writer → implementer → plan-lander
```

### Handoffs
Each feature gets `docs/exec-plans/active/handoffs/F{id}.md`.
Each agent's output is appended. Next agent reads the handoff file.
Moved to `completed/handoffs/` when feature lands.

### After plan-lander reports LANDED
**Bootstrap:** `git add` artifacts from bootstrap agent → commit
**Standard:** `git add` files from test-writer + implementer → commit
All variants: `feat(F{id}): {feature name}` → check off backlog → move handoff to completed

### Path Convention
Phoenix project lives at `repo_man/` subdirectory (not repo root).
Host: `~/src/repo-man/repo_man/lib/...` → Docker: `/app/lib/...`
All agents write to host paths. Docker volume mount makes them visible in container.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for process model, data flow, and module map.

## Specs

- [Product spec](docs/product-specs/mvp-spec.md) — What to build
- [UI design](docs/design-docs/ui-design.md) — How it looks
- [Core beliefs](docs/design-docs/core-beliefs.md) — Principles + testing strategy

## Plans

- [Feature backlog](docs/exec-plans/active/feature-backlog.md) — 31 features, execute top-to-bottom
- [Completed plans](docs/exec-plans/completed/) — Finished (reference only)
- [Tech debt tracker](docs/exec-plans/tech-debt-tracker.md) — Known shortcuts

## Status Colors

| State | Color | Meaning |
|-------|-------|---------|
| Clean + up to date | Neutral (gray) | Nothing to do |
| Behind origin | Blue | Can pull — stale code |
| Topic branch | Amber | Not on default branch |
| Dirty | Orange | Uncommitted changes |
| Diverged / Error | Red | Manual intervention needed |
| In progress | Gray | Operation running |
| All current (banner) | Light mint | Ready for design work |

**Priority:** Error > Diverged > Dirty > Topic > Behind > Clean.
**Principle:** Absence of color = everything is fine.

## Development

```bash
python3 scripts/terminal-opener.py &  # host-side companion (opens Ghostty from UI)
docker compose up                     # starts dev server at localhost:4000
docker compose build                  # rebuild after Dockerfile changes
docker compose run --rm app mix test  # run tests inside container
```

Source and `~/src/repos/` are volume-mounted into the container.
The terminal-opener companion runs on the host (not in Docker) because
it needs macOS `open` to launch Ghostty.

## References

- [Brainstorm mockups](docs/references/brainstorm/) — HTML design comps
- [North star](docs/north-star.md) — Keel process vision
