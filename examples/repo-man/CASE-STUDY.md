# Repo Man: A KEEL Case Study

How the KEEL process was applied to build Repo Man — a single-page localhost
Phoenix LiveView dashboard for monitoring and syncing git repos.

## Project Summary

- **What:** Dashboard that shows git repo status across `~/src/repos/`
- **Stack:** Elixir, Phoenix 1.7+, LiveView, Tailwind CSS. No Ecto, no npm.
- **Scale:** 31 features, all landed successfully through the KEEL pipeline
- **Team:** 1 human (Tej, steering) + Claude (executing)

## How Templates Were Filled

### CLAUDE.md (~80 lines)
- Quick Facts: Stack, Docker constraint, single user
- Safety Rules: 4 git-specific invariants (no --force, --ff-only, no branch switching, no file modification)
- Workflow: 4 pipeline variants mapped to feature ranges (F01-F03 bootstrap, F04-F16 backend, F17-F28 frontend, F29-F31 cross-cutting)
- Status Colors: 7-state color system for repo health

### North Star
- Adopted fully: repo as system of record, progressive disclosure, agent legibility
- Adapted: mechanical enforcement (start with mix format, add structural tests later), garbage collection (manual at session boundaries initially)
- Skipped: Chrome DevTools MCP (LiveView test helpers sufficient), automated doc-gardening (manual initially)
- Growth stages: Foundation → First Code → Working App → MVP Complete → Post-MVP

### Architecture
- One GenServer per git repo (crash isolation + operation serialization)
- 4 layers: Foundation (Git + RepoStatus) → Service (RepoServer) → Runtime (RepoSupervisor) → UI (DashboardLive)
- Git module injection via application config for Mox testability
- PubSub for real-time updates between GenServers and LiveView

### Domain Invariants (Safety Rules)
See `examples/domain-invariants/git-operations.md` for the full rule set.
These were enforced by:
- safety-auditor agent (grep for `System.cmd("git"`, verify --ff-only, check pull guards)
- PreToolUse hook on `*/git.ex|*/repo_server.ex` (safety-gate.sh)
- Layer 1 tests using real git against temp directories (never mock safety)

### Feature Backlog (31 Features)
Decomposed into 4 groups matching architectural layers:
- **Bootstrap (F01-F03):** Docker, Phoenix scaffold, Git.Behaviour + test infra
- **Foundation (F04-F11):** Git module functions, RepoStatus struct, RepoDiscovery
- **Service (F12-F16):** RepoServer GenServer, PubSub, Supervisor
- **UI (F17-F28):** LiveView mount, 7 card types, banner, controls, theme
- **Cross-cutting (F29-F31):** GitBuilder fixture, safety tests, Open Terminal

Each feature: single function or component, independently testable, with explicit dependencies.

### Testing Strategy (6 Layers)
- Layer 0: Spec consistency (pre-check verifies specs don't contradict)
- Layer 1: Safety invariants (real git against temp dirs, never mock)
- Layer 2a: Git integration (real System.cmd, tagged :integration)
- Layer 2b: Pure logic (RepoStatus derivations, no I/O)
- Layer 3: Service (GenServer behavior, Mox for git layer)
- Layer 4: LiveView (Phoenix.LiveViewTest, Mox for git layer)

### Handoff Files
Each feature got `docs/exec-plans/active/handoffs/F{id}.md`. Example flow for F05 (Git branch detection):
1. pre-check → execution brief: "Two functions: current_branch and default_branch with fallback chain"
2. test-writer → test report: 4 tests, RED-NEW (module doesn't exist yet)
3. implementer → implementation report: git.ex created, all tests GREEN
4. spec-reviewer → conformance report: CONFORMANT
5. plan-lander → landing report: LANDED
6. Orchestrator commits: `feat(F05): Git branch detection`

## Lessons Learned

1. **Bootstrap pipeline was worth it.** F01-F03 set up Docker, scaffold, and test infra before any feature work. Every subsequent feature ran smoothly because the foundation was solid.

2. **Pre-check catches real issues.** Spec drift was caught early — the original implementation plan referenced `brew install elixir` (violating Docker constraint) and expand/collapse UI (violating "all details visible at a glance").

3. **Safety-auditor earned its keep.** The git safety rules (no --force, --ff-only) were non-negotiable. Having a dedicated scanner that greps every `System.cmd("git"` call prevented subtle violations.

4. **Handoff files are the memory.** When debugging a feature weeks later, the handoff file showed every decision: what the designer chose, what the test-writer tested, what the implementer built, what the spec-reviewer confirmed.

5. **Garbage collection matters.** After a batch of features, docs drifted. The doc-gardener sweep caught that ARCHITECTURE.md still showed the old supervision tree after RepoServer was refactored.
