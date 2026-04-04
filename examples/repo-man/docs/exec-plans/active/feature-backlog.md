# Feature Backlog

Smallest independently testable features. Execute top-to-bottom.
Each feature: read spec → write test → write code → verify.

**Specs:** `docs/product-specs/mvp-spec.md`, `docs/design-docs/ui-design.md`
**Principles:** `docs/design-docs/core-beliefs.md`
**Architecture:** `ARCHITECTURE.md`

---

## Bootstrap (orchestrator-direct, no test-writer/implementer pipeline)

- [x] **F01 Docker dev environment**
  Spec: core-beliefs:Docker | Agent: docker-builder
  Test: `docker compose build` succeeds, container has git+elixir

- [x] **F02 Phoenix scaffold**
  Spec: mvp-spec:7 | Needs: F01 | Agent: scaffolder
  Test: `mix phx.server` boots at :4000 inside container
  Note: `--no-ecto --no-mailer --no-dashboard`. Add mox + stream_data deps.

- [x] **F03 Git.Behaviour + test infra**
  Spec: core-beliefs:Testing | Needs: F02 | Agent: config-writer
  Test: `Mox.defmock` compiles, behaviour defines 9 callbacks

## Foundation (backend pipeline starts here)

- [x] **F04 Git.repo?/1**
  Spec: mvp-spec:4.1 | Needs: F02, F03
  Test: true for .git dirs, false for plain dirs and nonexistent paths

- [x] **F05 Git branch detection**
  Spec: mvp-spec:4.2 | Needs: F04
  Test: current_branch returns branch name, default_branch falls back master→main

- [x] **F06 Git ahead/behind**
  Spec: mvp-spec:4.2 | Needs: F05
  Test: correct {ahead, behind} counts against origin/{default}

- [x] **F07 Git dirty files**
  Spec: mvp-spec:4.2 | Needs: F04
  Test: returns %{status, path} list from porcelain output

- [x] **F08 Git local branches**
  Spec: mvp-spec:4.2 | Needs: F05
  Test: lists branches excluding current

- [x] **F09 Git fetch + pull + last_fetch**
  Spec: mvp-spec:4.3 | Needs: F04
  Test: fetch --all --prune works, pull --ff-only works, FETCH_HEAD mtime read

- [x] **F10 RepoStatus struct**
  Spec: mvp-spec:5.4 | Needs: F05-F09
  Test: derived fields correct, severity priority: error>diverged>dirty>topic>behind>clean
  Test: pull_eligible? false when dirty/diverged/not-default/not-behind

- [x] **F11 RepoDiscovery**
  Spec: mvp-spec:4.1 | Needs: F04
  Test: finds git repos, ignores hidden dirs, sorts by name

## Service

- [x] **F12 RepoServer init + status**
  Spec: mvp-spec:5.1 | Needs: F10
  Test: starts, reads git status, responds to get_status call

- [x] **F13 RepoServer fetch**
  Spec: mvp-spec:4.3.1 | Needs: F12
  Test: async fetch, :fetching state, serialization guard (ignores if busy)

- [x] **F14 RepoServer pull**
  Spec: mvp-spec:4.3.3 | Needs: F12
  Test: eligibility guard, async pull, :pulling state

- [x] **F15 RepoServer PubSub**
  Spec: mvp-spec:5.2 | Needs: F12
  Test: broadcasts {:repo_updated, status} on every state change

- [x] **F16 Supervisor + app wiring**
  Spec: mvp-spec:5.1 | Needs: F11-F15
  Test: DynamicSupervisor starts servers, REPOMAN_PATH crash if missing

## UI

- [x] **F17 Dashboard LiveView mount**
  Spec: mvp-spec:4.5 | Needs: F16
  Test: mounts at /, subscribes PubSub, loads repos into assigns

- [x] **F18 Clean card**
  Spec: ui-design:4.1 | Needs: F17
  Test: neutral border, no buttons, no pill, name+branch+ahead/behind

- [x] **F19 Behind card**
  Spec: ui-design:4.2 | Needs: F17
  Test: blue border+pill, Fetch+Pull buttons, branch list (max 5+N more)

- [x] **F20 Topic card**
  Spec: ui-design:4.3 | Needs: F17
  Test: amber border+pill, branch name in mono, "Not on default branch"

- [x] **F21 Dirty card**
  Spec: ui-design:4.4 | Needs: F17
  Test: orange border+pill, file list max 8+"+N more", pull-blocked reason

- [x] **F22 Diverged card**
  Spec: ui-design:4.5 | Needs: F17
  Test: red border+pill, ahead/behind counts, "manual merge needed"

- [x] **F23 Error card**
  Spec: ui-design:4.6 | Needs: F17
  Test: red border+pill, error in monospace, "Retry fetch" button

- [x] **F24 In-progress card**
  Spec: ui-design:4.7 | Needs: F17
  Test: gray border, ⟳ spinner pill, 0.85 opacity, buttons disabled

- [x] **F25 Freshness banner**
  Spec: ui-design:5 | Needs: F17
  Test: 4 states — current(mint), behind(amber), warning(amber), error(red)
  Test: holds previous state during in-progress ops

- [x] **F26 Summary line + header**
  Spec: ui-design:6 | Needs: F17
  Test: counts by status, progress appended during bulk ops

- [x] **F27 Fetch All / Pull All**
  Spec: mvp-spec:4.3.2, 4.3.4 | Needs: F13, F14, F17
  Test: parallel execution, progress in button, skip ineligible on pull

- [x] **F28 Dark-first theme**
  Spec: ui-design:11 | Needs: F17
  Test: data-theme attribute, bg-[#0a0a0a]/[#fafafa], system font, manual toggle

## Cross-cutting

- [x] **F29 GitBuilder fixture helper**
  Spec: core-beliefs:Testing | Needs: F02
  Test: creates repos in 5 states — :clean, :dirty, :behind, :diverged, :topic_branch

- [x] **F30 Safety invariant tests**
  Spec: core-beliefs:Testing L1, mvp-spec:4.4 | Needs: F09, F10, F29
  Test: real git — no --force, no --rebase, --ff-only always, no pull when dirty/diverged/not-default

- [x] **F31 Open Terminal ↗**
  Spec: ui-design:7 | Needs: F18-F24
  Test: ↗ link present on all 7 card types, href points to repo path
