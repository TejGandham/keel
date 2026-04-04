# Core Beliefs

Non-negotiable principles that govern every decision in Repo Man.

## Safety Above All

- Never force-pull, never rebase from UI, never switch branches.
- `--ff-only` always. If it can't fast-forward, fail cleanly.
- Never modify the working tree beyond fast-forward pulls.
- Dirty repos are read-only. Period.

## Git Is Truth

- No database. No persistence. All state derived from git.
- If git says it, we display it. If git doesn't say it, we don't guess.
- GenServer state is a cache of git state, not a source of truth.

## Glanceable Over Detailed

- The dashboard answers one question: "Is my codebase current?"
- 2-second rule: status must be scannable in under 2 seconds.
- Color is information, not decoration.
- Absence of color = everything is fine.
- All details visible at a glance — no click-to-reveal. This is a cockpit.

## Docker Is The Runtime

- No local Elixir/Erlang installation. Ever.
- If it doesn't work in Docker, it doesn't work.
- Container must have git and access to `~/src/repos/` via volume mount.

## Brand Personality

- Playful, sharp, confident.
- Subtle wit in microcopy. Clear and unambiguous in data.
- Think "the friend who's really good at git and has good taste."
- Reference: Linear, Vercel dashboard. Anti-reference: Bootstrap admin panels.

## Design Tokens

- Dark-first via `data-theme` attribute with manual toggle, light as equal citizen.
- System sans-serif for UI. Monospace only for git data.
- Polished minimal. Earn every element — no decorative chrome.

## Claude Is The Builder

- Claude is responsible for design, development, testing, documentation, maintenance.
- Tej steers. Claude executes.
- Every decision must be traceable to a document in this repo.
- When in doubt, ask. When confident, explain in a commit message.
- Repository is the system of record. If it's not here, it doesn't exist.

## Testing Strategy: Spec-Driven Testing

Tests enforce spec conformance, not discover design. Every spec assertion has
a corresponding test. When specs change, tests change first.

### Layer 0: Spec Consistency

Docs must not contradict each other. Before writing tests, verify that
product-specs, design-docs, exec-plans, and ARCHITECTURE.md agree. Spec
drift in an agent-built project is as dangerous as a code bug.

### Layer 1: Safety Invariants

From core-beliefs + mvp-spec section 4.4. These are the first tests written,
last tests deleted. **Must use real git** against temp directories — mocking
safety means testing your mock.

- No git command uses `--force`
- Pull always uses `--ff-only`
- Pull rejected when dirty, diverged, not on default branch, or not behind
- No command modifies working tree beyond ff-only pull

### Layer 2a: Git Integration (Slow)

Real `System.cmd` calls against temp repos created by `GitBuilder`.
Tagged `@tag :integration` so fast loops can skip them.

- `git fetch --all --prune` produces expected state changes
- Timeout enforcement (60s network, 10s local)
- Parse failure resilience (rebase in progress, detached HEAD, locale quirks)

### Layer 2b: Pure Domain Logic (Fast)

No I/O. Tests for `RepoStatus` derivations and pure functions.

- `pull_eligible?` derived correctly from on_default? + dirty_count + ahead + behind
- Status priority ordering: error > diverged > dirty > topic > behind > clean
- Use `StreamData` for property-based invariant testing where applicable

### Layer 3: Service / Process Behavior

GenServer serialization, PubSub broadcasts, Task.Supervisor crash isolation.
Uses `Mox` with `RepoMan.Git.Behaviour` — no real git in these tests.

- GenServer serializes operations (spam fetch events → only one runs)
- PubSub broadcasts on state changes
- Task timeout triggers error state and broadcast
- Concurrent Fetch All doesn't spawn duplicate tasks per repo

### Layer 4: LiveView / Component Behavior

Uses `Phoenix.LiveViewTest` and `render_component/2`. Mox for git layer —
fast and deterministic.

- Clean card: neutral border, no buttons, no pill
- Behind card: blue pill, enabled Pull button
- Dirty card: orange pill, file list (max 8 + "+N more")
- Banner states: all current (mint), behind (amber), error (red)
- Banner holds previous state during in-progress ops
- Fetch All shows progress, disables button
- Open Terminal link present on every card

### Layer 5: Acceptance + Docker Smoke

Validates the full stack boots correctly inside Docker.

- `docker compose build` succeeds
- `docker compose run --rm app mix test` passes
- `docker compose up` + `curl localhost:4000` returns 200
- `REPOMAN_PATH` validated at `Application.start` — crash if inaccessible
- Test suite uses `/tmp` for repos, never touches real `~/src/repos/`

### Testing Infrastructure

- **`RepoMan.Git.Behaviour`**: Define behaviour early. Real impl for Layers 1-2a.
  Mox for Layers 3-4.
- **`test/support/git_builder.ex`**: Shared helper to create temp repos in
  specific states (`:clean`, `:dirty`, `:behind`, `:diverged`, `:topic_branch`).
- **ExUnit tags**: `@tag :integration` for slow tests, `@tag :docker` for smoke.
  Default `mix test` runs fast tests only. `mix test --include integration` for full suite.
