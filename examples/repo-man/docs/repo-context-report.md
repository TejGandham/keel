# Repo Man — Complete Codebase Context Report

**Generated:** 2026-04-04
**Source:** Full read of every code and text file in the repository
**Cross-validated by:** Claude Opus 4.6, Codex, Gemini 3.1 Pro (roundtable consensus)

---

## 1. Repository Identity

**Name:** Keel (repo) / Repo Man (application)
**Purpose:** Single-page localhost Phoenix LiveView dashboard for monitoring and syncing git repos under `~/src/shred/`. Pre-flight checklist for software architecture work — ensures the codebase is current before making design decisions.
**User:** Single developer (Tej), localhost only. No auth.
**Builder:** Claude (sole builder). Tej steers.
**Process:** "Keel" — a structured spec-driven agent development process adapted from OpenAI's harness engineering article.

---

## 2. Tech Stack

| Layer | Technology | Notes |
|-|-|-|
| Language | Elixir 1.19.5 (OTP 28) | |
| Framework | Phoenix 1.8.5, LiveView 1.1.x | |
| CSS | Tailwind CSS 4.1.12 | No npm. Vendored DaisyUI theme. |
| JS | Minimal hooks only | RefreshInterval hook, theme toggle, terminal opener. No npm/node_modules. |
| Git Interface | `System.cmd/3` | Shells out to user's git binary. Respects config/SSH/credentials. |
| HTTP Server | Bandit 1.5+ | |
| Build | esbuild 0.25.4 | |
| Test | ExUnit, Mox 1.x, StreamData 1.x, LazyHTML | |
| Container | Docker (elixir:1.19-slim + git + gh CLI) | All dev done inside container. |
| Database | **None** | No Ecto. All state derived from git. |

---

## 3. Project Structure

```
keel/                           # Repository root
├── ARCHITECTURE.md             # Process model, layers, module map
├── CLAUDE.md                   # ~80-line table of contents for Claude
├── Dockerfile                  # elixir:1.19-slim + git + gh CLI
├── docker-compose.yml          # Volume mounts: ./repo_man → /app, ~/src/shred → /shred
│
├── docs/
│   ├── north-star.md           # Keel process vision (adapted from OpenAI article)
│   ├── product-specs/
│   │   ├── index.md
│   │   └── mvp-spec.md         # 10 success criteria, full feature spec
│   ├── design-docs/
│   │   ├── index.md
│   │   ├── core-beliefs.md     # Safety rules, testing strategy (5 layers)
│   │   ├── ui-design.md        # Card anatomy, colors, typography, spacing
│   │   ├── 2026-03-16-monitoring-wall-sizing-design.md
│   │   ├── 2026-03-31-dashboard-extraction-design.md
│   │   └── 2026-03-31-refresh-control-design.md
│   ├── exec-plans/
│   │   ├── active/
│   │   │   ├── feature-backlog.md          # 31 features, ALL checked off
│   │   │   └── moes-implementation-queue.md # MoES code review findings queue
│   │   ├── completed/
│   │   │   ├── handoffs/F01.md..F31.md     # Per-feature execution records
│   │   │   ├── handoffs/dashboard-extraction.md
│   │   │   ├── 2026-03-16-monitoring-wall-sizing.md
│   │   │   └── 2026-03-31-refresh-control.md
│   │   └── tech-debt-tracker.md
│   ├── references/brainstorm/  # 12 HTML design mockups
│   └── harness-engineering-article/  # Saved OpenAI article + assets
│
├── keel-kit/                   # Reusable Keel process template
│   ├── ARCHITECTURE.md         # Template (fillable)
│   ├── CLAUDE.md               # Template
│   ├── .claude/
│   │   ├── agents/             # 13 agent definitions (pre-check, test-writer, etc.)
│   │   ├── hooks/              # doc-gate.sh, safety-gate.sh
│   │   ├── skills/             # dev-up, keel-pipeline, safety-check
│   │   └── settings.json
│   ├── docs/                   # Template docs structure
│   ├── examples/               # Domain invariant examples (financial, git, REST, data-pipeline)
│   └── scripts/bootstrap.sh
│
├── repo_man/                   # Phoenix project root
│   ├── lib/repo_man/           # Backend modules
│   ├── lib/repo_man_web/       # Web layer (LiveView, components)
│   ├── test/                   # Tests (ExUnit)
│   ├── config/                 # Phoenix configs
│   ├── assets/                 # CSS, JS, vendor libs
│   ├── mix.exs                 # Dependencies
│   ├── AGENTS.md               # Agent-specific instructions
│   └── README.md
│
└── scripts/
    └── terminal-opener.py      # Host-side companion — opens Ghostty tabs via AppleScript
```

---

## 4. Architecture

### Supervision Tree

```
Phoenix Application
├── RepoManWeb.Telemetry
├── DNSCluster
├── {Phoenix.PubSub, name: RepoMan.PubSub}
├── {Registry, keys: :unique, name: RepoMan.RepoRegistry}
├── {Task.Supervisor, name: RepoMan.TaskSupervisor}
├── RepoMan.RepoSupervisor (DynamicSupervisor)
│   ├── RepoMan.RepoServer (GenServer) — repo1
│   ├── RepoMan.RepoServer (GenServer) — repo2
│   └── ...
├── RepoManWeb.Endpoint
└── (post-boot) RepoMan.RepoSupervisor.start_repos()
```

RepoServers start AFTER the tree is up, gated by `start_repos_on_boot` config (default true, false in test).

### Layer Dependencies (strict downward flow)

```
DashboardLive (UI)            ← F17-F28
      ↓ subscribes via PubSub
RepoSupervisor (Runtime)      ← F16
      ↓ starts
RepoServer (Service)          ← F12-F15
      ↓ calls via @git_module
Git + RepoStatus (Foundation) ← F04-F11
```

Cross-cutting: Phoenix.PubSub, Task.Supervisor, Registry

### Data Flow (Fetch Example)

```
User clicks "Fetch" on a repo
  → LiveView sends event to repo's GenServer via RepoSupervisor.dispatch/2
  → GenServer sets state to :fetching, broadcasts update via PubSub
  → GenServer spawns Task under TaskSupervisor (async_nolink)
  → Task runs `git fetch --all --prune` + `git remote set-head origin --auto`
  → Task completes, sends result back to GenServer
  → GenServer runs status refresh (6 git commands)
  → GenServer updates state, broadcasts update
  → LiveView receives broadcast, re-renders card
```

### Docker Architecture

```
Docker Container (elixir:1.19-slim + git + gh)
  /app  ← ./repo_man (source mounted for live reload)
  /shred ← ~/src/shred (repos mounted read-write)
  mix phx.server → :4000
        │ port 4000
        ↓
  localhost:4000 (browser)
        │ fetch() on ↗ click
        ↓
  localhost:4001 (terminal-opener.py, host-side)
        │ AppleScript → Ghostty
        ↓
  Ghostty (new tab at repo dir)
```

Environment variables:
- `REPOMAN_PATH=/shred` (container-side repos path)
- `REPOMAN_HOST_PATH=$HOME/src/shred` (host-side, for UI links)
- `REPOMAN_SHRED_PATH` (docker-compose override, defaults to `/mnt/agent-storage/vader/src`)

---

## 5. Module Map (All Elixir Modules)

### Backend (lib/repo_man/)

| Module | File | Lines | Responsibility |
|-|-|-|-|
| `RepoMan` | `lib/repo_man.ex` | 9 | Root context module (empty) |
| `RepoMan.Application` | `lib/repo_man/application.ex` | 52 | OTP app startup. Validates repos_path, starts supervision tree, post-boot start_repos. |
| `RepoMan.Git.Behaviour` | `lib/repo_man/git/behaviour.ex` | 57 | 9-callback contract: repo?, current_branch, default_branch, ahead_behind, dirty_files, local_branches, last_fetch_time, fetch, pull_ff_only |
| `RepoMan.Git` | `lib/repo_man/git.ex` | 260 | Real git implementation via System.cmd. Includes default_branch fallback chain (symbolic-ref → remote tracking → config → local). fetch/1 also runs `git remote set-head origin --auto`. |
| `RepoMan.RepoStatus` | `lib/repo_man/repo_status.ex` | 161 | Pure data struct with derived fields. `new/1` computes: on_default?, dirty_count, pull_eligible?, pull_blocked_reason, severity. Severity priority: error > diverged > dirty > topic_branch > behind > clean. |
| `RepoMan.RepoDiscovery` | `lib/repo_man/repo_discovery.ex` | 38 | Scans base_path for immediate subdirs that are git repos. Ignores hidden dirs. Returns sorted list. |
| `RepoMan.RepoServer` | `lib/repo_man/repo_server.ex` | 373 | GenServer per repo. Holds RepoStatus, serializes ops (fetch/pull), async Task.Supervisor spawn, PubSub broadcasts, periodic polling (default 2s, configurable). |
| `RepoMan.RepoSupervisor` | `lib/repo_man/repo_supervisor.ex` | 161 | DynamicSupervisor. start_repos/1 (discover + start servers), all_statuses/1 (query Registry), dispatch/3 and dispatch_all/3 (name-based server lookup). validate_repos_path!/1. |
| `RepoMan.Dashboard` | `lib/repo_man/dashboard.ex` | 110 | Pure functions extracted from LiveView: banner/1 (freshness state), banner_state/1, summary_counts/1, format_time/1, bulk_progress_text/2. |

### Web (lib/repo_man_web/)

| Module | File | Lines | Responsibility |
|-|-|-|-|
| `RepoManWeb` | `lib/repo_man_web.ex` | 114 | Module dispatch (router, controller, live_view, html macros). |
| `RepoManWeb.Endpoint` | `lib/repo_man_web/endpoint.ex` | ~45 | Phoenix endpoint config. |
| `RepoManWeb.Router` | `lib/repo_man_web/router.ex` | ~25 | Single route: `live "/", DashboardLive`. |
| `RepoManWeb.Telemetry` | `lib/repo_man_web/telemetry.ex` | ~80 | Standard Phoenix telemetry. |
| `RepoManWeb.Gettext` | `lib/repo_man_web/gettext.ex` | ~25 | Gettext backend. |
| `RepoManWeb.CoreComponents` | `lib/repo_man_web/components/core_components.ex` | ~700 | Standard Phoenix core components (button, input, modal, flash, etc.). |
| `RepoManWeb.Layouts` | `lib/repo_man_web/components/layouts.ex` | ~15 | Layout embed. |
| `RepoManWeb.RepoCard` | `lib/repo_man_web/components/repo_card.ex` | 568 | 7 card function components (clean, behind, topic, dirty, diverged, error, in_progress) + fetch_button, pull_button, open_terminal_link. Uses `to_host_path/1` for container→host path mapping. |
| `RepoManWeb.DashboardLive` | `lib/repo_man_web/live/dashboard_live.ex` | 592 | The single LiveView page. Mount, PubSub subscription, event handlers (fetch, pull, retry, fetch_all, pull_all, cycle_refresh, restore_refresh), card dispatcher (routes by operation then severity), freshness_banner/1, summary_line/1, fetch_all_button/1, pull_all_button/1, refresh_button/1. Delegation shims for backwards compat. |
| `RepoManWeb.ErrorHTML` | `lib/repo_man_web/controllers/error_html.ex` | ~15 | Error page renderer. |
| `RepoManWeb.ErrorJSON` | `lib/repo_man_web/controllers/error_json.ex` | ~15 | Error JSON renderer. |
| `RepoManWeb.PageHTML` | `lib/repo_man_web/controllers/page_html.ex` | ~10 | (Unused/standard) |

### Test Support

| Module | File | Lines | Responsibility |
|-|-|-|-|
| `RepoMan.GitBuilder` | `test/support/git_builder.ex` | ~120 | Creates temp git repos in 5 states: :clean, :dirty, :behind, :diverged, :topic_branch. Uses raw System.cmd, unique paths via :erlang.unique_integer. |
| `RepoManWeb.ConnCase` | `test/support/conn_case.ex` | ~25 | Standard Phoenix ConnCase. |

---

## 6. Test Suite

### Test Files

| File | Tests | Type | Coverage |
|-|-|-|-|
| `test/repo_man/git_test.exs` | ~35 | Integration (real git) | repo?, current_branch, default_branch, ahead_behind, dirty_files, local_branches, fetch, pull_ff_only, last_fetch_time |
| `test/repo_man/git_safety_test.exs` | 18 | Integration (real git) | No --force, --ff-only always, pull rejected when dirty/diverged/topic/not-behind, fetch doesn't modify working tree |
| `test/repo_man/git_builder_test.exs` | 24 | Integration | GitBuilder.build/2 for all 5 states, path uniqueness |
| `test/repo_man/repo_status_test.exs` | 26 unit + 5 property | Unit + StreamData | Severity priority, pull_eligible? derivation, all field computations |
| `test/repo_man/repo_discovery_test.exs` | ~8 | Unit (Mox) | scan/1 finds repos, ignores hidden, sorts, handles missing path |
| `test/repo_man/repo_server_test.exs` | ~30 | Unit (Mox) | init, get_status, fetch serialization, pull preconditions, PubSub broadcasts, task crash handling, polling |
| `test/repo_man/repo_supervisor_test.exs` | ~12 | Unit (Mox) | start_repos, all_statuses, validate_repos_path!, dispatch, dispatch_all |
| `test/repo_man_web/live/dashboard_live_test.exs` | ~120+ | LiveView (Mox) | All 7 card types, banner states, summary line, fetch/pull/retry events, fetch_all/pull_all, theme toggle, format_time, refresh control |
| `test/repo_man_web/controllers/error_html_test.exs` | 2 | Unit | 404, 500 rendering |
| `test/repo_man_web/controllers/error_json_test.exs` | 2 | Unit | 404, 500 JSON |

### Testing Strategy (5 Layers from core-beliefs.md)

- **Layer 0:** Spec consistency — docs don't contradict each other
- **Layer 1:** Safety invariants — real git, no --force, --ff-only always, pull guards (F30)
- **Layer 2a:** Git integration (slow) — real System.cmd against temp repos via GitBuilder (F29)
- **Layer 2b:** Pure domain logic (fast) — RepoStatus derivations, StreamData properties
- **Layer 3:** Service/process behavior — GenServer serialization, PubSub, Task crash isolation (Mox)
- **Layer 4:** LiveView/component behavior — card rendering, banner, bulk ops (Mox)
- **Layer 5:** Acceptance/Docker smoke — full boot, curl localhost:4000

### Git Module Injection

```elixir
@git_module Application.compile_env(:repo_man, :git_module, RepoMan.Git)
# config/test.exs: config :repo_man, git_module: RepoMan.Git.Mock
# test_helper.exs: Mox.defmock(RepoMan.Git.Mock, for: RepoMan.Git.Behaviour)
```

---

## 7. Feature Backlog — All 31 Features (ALL COMPLETE)

### Bootstrap (F01-F03)
- **F01** Docker dev environment — elixir:1.19-slim, git, hex, phx_new
- **F02** Phoenix scaffold — mix phx.new --no-ecto --no-mailer --no-dashboard, added mox+stream_data
- **F03** Git.Behaviour + test infra — 9 callbacks, Mox.defmock, ExUnit tags

### Foundation (F04-F11)
- **F04** Git.repo?/1 — File.exists?(Path.join(path, ".git"))
- **F05** Git branch detection — current_branch (--show-current), default_branch (fallback chain)
- **F06** Git ahead/behind — rev-list --left-right --count
- **F07** Git dirty files — status --porcelain
- **F08** Git local branches — branch --list --format=%(refname:short), excludes current
- **F09** Git fetch + pull + last_fetch — fetch --all --prune, pull --ff-only, FETCH_HEAD mtime
- **F10** RepoStatus struct — derived fields, severity priority, pull_eligible?, StreamData
- **F11** RepoDiscovery — scan/1, ignores hidden, sorts

### Service (F12-F16)
- **F12** RepoServer init + status — GenServer, Registry via-tuple, read_status on init
- **F13** RepoServer fetch — async Task.Supervisor, :fetching state, serialization guard
- **F14** RepoServer pull — pull_eligible? guard, async, :pulling state
- **F15** RepoServer PubSub — broadcasts {:repo_updated, status} on every state change
- **F16** Supervisor + app wiring — DynamicSupervisor, Registry, start_repos_on_boot

### UI (F17-F28)
- **F17** Dashboard LiveView mount — /, PubSub subscribe, loads repos
- **F18** Clean card — gray border, no buttons, no pill
- **F19** Behind card — blue border+pill, Fetch+Pull, branch list (max 5)
- **F20** Topic card — amber border+pill, branch name in amber mono
- **F21** Dirty card — orange border+pill, file list (max 8), pull-blocked reason
- **F22** Diverged card — red border+pill, ahead/behind, "manual merge needed"
- **F23** Error card — red border+pill, error in mono, "Retry fetch"
- **F24** In-progress card — gray, spinner, 0.85 opacity, buttons disabled
- **F25** Freshness banner — 4 states (current/behind/warning/error), holds during ops
- **F26** Summary line + header — counts by status, repos path, progress text
- **F27** Fetch All / Pull All — parallel, progress tracking, skip ineligible
- **F28** Dark-first theme — data-theme, localStorage, toggle button

### Cross-cutting (F29-F31)
- **F29** GitBuilder fixture helper — 5 states, 24 tests
- **F30** Safety invariant tests — 18 tests, real git, source scanning
- **F31** Open Terminal ↗ — on all 7 cards, host-side companion

---

## 8. Safety Rules (Hard Constraints)

1. **Never force-pull** — no `--force`, no `--rebase` anywhere in git.ex
2. **Never pull on dirty repos** — pull_eligible? enforced at RepoStatus + RepoServer level
3. **Never pull if diverged** — ahead > 0 blocks pull
4. **Always `--ff-only`** — verified by source scan + behavioral test
5. **Never switch branches** — no checkout/switch in codebase
6. **Never modify files** — no stash, no reset, no checkout of files

Enforced by:
- `RepoStatus.pull_eligible?` derivation (5 conditions)
- `RepoServer.handle_cast(:pull)` guard clause
- Source-level scans in `git_safety_test.exs` (no `--force`, no `--force-with-lease`)
- Behavioral tests against real git temp repos

---

## 9. UI Design

### Status Colors (Dark Theme)

| State | Left Border | Card Border | Pill |
|-|-|-|-|
| Clean | #333 (gray) | #1f1f1f | None |
| Behind | #3b82f6 (blue) | #1e3a5f | bg:#172554 text:#60a5fa |
| Topic | #f59e0b (amber) | #422006 | bg:#422006 text:#fbbf24 |
| Dirty | #f97316 (orange) | #431407 | bg:#431407 text:#fb923c |
| Diverged/Error | #ef4444 (red) | #450a0a | bg:#450a0a text:#f87171 |
| In-progress | #737373 (gray) | #1f1f1f | bg:#262626 text:#a3a3a3 |

### Layout
- Flow grid: `flex flex-wrap gap-4 items-start`
- Cards size to content (clean = compact, problem repos = expanded)
- No click-to-expand — all details visible at a glance (cockpit philosophy)
- Dark-first with manual toggle, localStorage persistence, prefers-color-scheme fallback

### Banner States
- **Current** (mint #86efac): "All repos current — ready for design work"
- **Behind** (amber #fbbf24): "N repos behind origin — designs may be stale"
- **Warning** (amber): "N repos need attention — dirty or on topic branch"
- **Error** (red #f87171): "N repos need attention — diverged or errored"

---

## 10. Configuration

### Environment Variables
| Var | Default | Purpose |
|-|-|-|
| `REPOMAN_PATH` | `~/src/shred` | Container-side repos directory |
| `REPOMAN_HOST_PATH` | Same as REPOMAN_PATH | Host-side repos path for UI terminal links |
| `REPOMAN_SHRED_PATH` | `/mnt/agent-storage/vader/src` | Docker-compose volume mount source |
| `PORT` | 4000 | HTTP port |
| `PHX_HOST` | localhost | Host for endpoint URL |
| `GIT_TERMINAL_PROMPT` | 0 | Disable git interactive prompts |

### Application Config
| Key | Default | Purpose |
|-|-|-|
| `git_module` | `RepoMan.Git` | Module injection (Mox in test) |
| `start_repos_on_boot` | true | false in test to prevent auto-start |
| `poll_interval` | 2000 | Default polling interval (ms) |
| `repos_path` | from REPOMAN_PATH | Repos directory |
| `host_repos_path` | from REPOMAN_HOST_PATH | Host-side path for terminal links |

---

## 11. Key Design Decisions

1. **One GenServer per repo** — crash isolation + operation serialization
2. **Registry for named lookup** — `{:via, Registry, {RepoMan.RepoRegistry, name}}`
3. **System.cmd/3 for git** — respects user's git config, SSH keys, credentials
4. **No database** — all truth from git, GenServer state is a cache
5. **PubSub for real-time** — GenServers broadcast on "repos" topic
6. **Task.Supervisor for git commands** — crash isolation for long-running ops
7. **Timeouts** — network ops 60s, local ops 10s
8. **Periodic polling** — RepoServer polls git status every N seconds (default 2s, configurable). Broadcasts only on change. Skips during in-progress ops.
9. **Host path mapping** — REPOMAN_HOST_PATH maps container paths to host paths for terminal links
10. **Git module injection** — `@git_module Application.compile_env(:repo_man, :git_module, RepoMan.Git)` for Mox testability

---

## 12. Development Workflow

```bash
# Start everything
python3 scripts/terminal-opener.py &  # host-side companion
docker compose up                     # dev server at localhost:4000

# Build
docker compose build                  # after Dockerfile changes

# Tests
docker compose run --rm app mix test                    # fast tests only
docker compose run --rm app mix test --include integration  # full suite

# Format
docker compose run --rm app mix format

# Precommit (compile+format+test)
docker compose run --rm app mix precommit
```

---

## 13. Outstanding Work (MoES Queue)

From the 2026-03-31 full-panel code review:

| # | Item | Severity | Status |
|-|-|-|-|
| 2 | Extract dashboard_live.ex (cards, domain logic, Registry) | Major | Done |
| 3 | Add `RepoStatus.with_operation/2`, remove `status_attrs/2` | Major | Queued |
| 5 | Extract `card_shell` slot component to deduplicate 7 cards | Major | Queued |
| 4 | Separate `operation` from RepoStatus (process state only) | Major | Queued |
| 6 | Convert `compute_severity/6` to accept map, not 6 params | Minor | Queued |
| 7 | Make `local_branches/1` return all branches, filter at caller | Minor | Queued |
| 8 | Rewrite `compute_banner/1` as single Enum.reduce | Minor | Queued |
| 9 | Move `Application.get_env` out of `summary_line/1` render | Minor | Queued |
| 10 | Add `--` separator in `git rev-list` branch argument | Minor | Queued |

Skipped: #1 AppleScript injection in terminal-opener.py (localhost-only, single user).

---

## 14. Tech Debt

### Open
- SSH/credential forwarding for git fetch in Docker needs testing
- 66KB stale implementation plan — consider rewriting as lighter exec-plan
- terminal-opener.py requires host-side process (could be replaced if Ghostty adds URL scheme)
- Polling interval broadcast via Registry iteration (could use PubSub topic at scale)

### Resolved
- Default branch detection stale (origin/HEAD → fixed with set-head --auto)
- Open Terminal ghostty:// URL scheme (fixed with host-side companion)
- dashboard_live.ex 1200 lines (fixed via extraction in dashboard-extraction task)

---

## 15. Keel-Kit (Reusable Template)

The `keel-kit/` directory contains a reusable version of the Keel process, including:

### Agents (13 definitions)
- **pre-check** — validates dependencies, spec consistency, research needs
- **researcher** — deep-dives when pre-check says research needed
- **backend-designer** — designs backend features
- **frontend-designer** — designs frontend features
- **test-writer** — writes failing tests from acceptance criteria
- **implementer** — makes tests pass
- **spec-reviewer** — verifies implementation matches spec
- **safety-auditor** — audits features touching fetch/pull/RepoServer
- **plan-lander** — final verification, marks feature as LANDED
- **docker-builder** — sets up Docker environment
- **scaffolder** — scaffolds framework project
- **config-writer** — writes config/infrastructure code
- **doc-gardener** — maintains doc accuracy

### Pipeline
```
pre-check → researcher? → designer? → test-writer → implementer → spec-reviewer → safety-auditor? → plan-lander
```

### Process Documentation
- THE-KEEL-PROCESS.md — full process description
- QUICK-START.md — getting started guide
- ANTI-PATTERNS.md — what to avoid
- AUTONOMY-PROGRESSION.md — trust levels for Claude
- GLOSSARY.md — terminology
- OPENAI-FOUNDATIONS.md — origins and adaptation

---

## 16. File Statistics

| Category | Count | Notes |
|-|-|-|
| Elixir source (.ex) | 22 | lib/ modules |
| Elixir test (.exs) | 13 | test/ + config/ |
| Markdown docs (.md) | ~65 | specs, designs, handoffs, process docs |
| HTML mockups | 12 | docs/references/brainstorm/ |
| Config files | 8 | mix.exs, docker-compose, Dockerfile, .formatter, .gitignore, tsconfig |
| JS/CSS assets | 6 | app.js, app.css, vendor/ (daisyui, heroicons, topbar) |
| Python scripts | 1 | terminal-opener.py |
| Total lines of Elixir | ~3,000+ | Across lib/ and test/ |

---

## 17. Errata & Corrections (Roundtable Cross-Validation)

The following corrections were identified by a 3-model roundtable (Claude, Codex, Gemini) reviewing this report against the actual source code.

### Confirmed Corrections (all 3 models agree)

1. **Timeouts are documented but NOT implemented.** Both this report and ARCHITECTURE.md claim "network ops 60s, local ops 10s, OS process killed." In reality, `git.ex` uses bare `System.cmd/3` with no timeout option, and `repo_server.ex` uses `Task.Supervisor.async_nolink/2` with no timer or kill mechanism. A hanging git process will hang the task indefinitely. This is a spec/code gap.

2. **Elixir version: runtime vs constraint.** Report says "Elixir 1.19.5 (OTP 28)" — that's the Docker runtime version. The project constraint in `mix.exs` is `~> 1.15`. Both are true but the distinction matters.

3. **esbuild/Tailwind versions conflated.** Report lists esbuild 0.25.4 and Tailwind CSS 4.1.12 — these are the binary versions from `config.exs`. The `mix.exs` hex deps are `{:esbuild, "~> 0.10"}` and `{:tailwind, "~> 0.3"}`.

4. **Safety rule #3 oversimplified.** Report says "Never pull if diverged — ahead > 0 blocks pull." The actual code has 5 distinct blocking conditions in `compute_pull_eligibility/3`: (1) dirty, (2) not on default branch, (3) diverged (ahead > 0 AND behind > 0), (4) ahead-only (unpushed commits, ahead > 0 without being behind), (5) already up-to-date (behind == 0). The "ahead-only" case is a distinct condition from "diverged."

5. **Precommit alias incomplete.** Report says "compile+format+test". Actual: `["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]`. The `--warnings-as-errors` and `deps.unlock --unused` steps were omitted.

### Additional Details Found

6. **Default branch fallback order reversal.** Remote tracking checks `main` before `master` (`git.ex:65-66`), but local fallback checks `master` before `main` (`git.ex:121-122`). This asymmetry is architecturally intentional (most remotes have moved to main, but local-only repos are more likely to use master).

7. **Test config overrides not documented.** `config/test.exs` sets `repos_path: "tmp/test_repos"` and `poll_interval: 0` (disables polling in tests). The `preferred_envs: [precommit: :test]` in `mix.exs` means the precommit alias runs in test env.

8. **`restore_refresh` event has interval whitelist.** `DashboardLive` only accepts `[0, 2_000, 10_000, 30_000]` — arbitrary intervals are rejected silently.

9. **Banner counting includes lower-severity repos.** When a worse state exists (e.g., error), the count includes all repos at that level AND below, not just repos matching the named category.

10. **Layer 5 tests (acceptance/Docker smoke) are documented but not implemented** as a test file in the test suite. They exist as manual verification steps only.

11. **`RepoServer` pull guard uses cached state.** The `handle_cast(:pull)` checks `pull_eligible?` from the cached `%RepoStatus{}`, not by re-reading git state immediately before pull. This creates a small race window.
