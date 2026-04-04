# Repo Man — MVP Specification

**Date:** 2026-03-13
**Status:** Approved
**Stack:** Elixir + Phoenix LiveView

---

## 1. What Is Repo Man

A single-page localhost web dashboard for monitoring and syncing all git repositories under `~/src/shred/`. One glance tells you which repos are clean, stale, dirty, or on topic branches. One click fetches or pulls them.

## 2. Problem Statement

The `~/src/shred/` workspace contains 7+ independent git repositories (AXO471–AXO492). Software architecture and design decisions span these repos — a change in one repo's API affects the design of consumers in others. Most repos are rarely modified locally and drift behind `origin/master` silently. Without a single view of freshness, architectural decisions get made against stale code, producing designs that don't reflect reality. Syncing requires `cd`-ing into each repo manually, which is tedious enough that it gets skipped.

Repo Man is the pre-flight checklist: one glance confirms the codebase is current before starting design work. One click brings everything up to date.

## 3. Target User

Single developer (localhost only). No authentication, no multi-user support.

## 4. MVP Feature Set

### 4.1 Repo Discovery

- On startup, scan `~/src/shred/` for all immediate subdirectories containing a `.git` folder
- Defaults to `~/src/shred/` (overridable via `REPOMAN_PATH` env var)
- Re-scan on page load (picks up new repos automatically)

### 4.2 Per-Repo Status

Each repo displays the following information:

| Field | Source | Notes |
|-------|--------|-------|
| **Repo name** | Directory name | e.g., `AXO471` |
| **Current branch** | `git branch --show-current` | |
| **Default branch** | `git symbolic-ref refs/remotes/origin/HEAD` | Fallback chain: try symbolic-ref, then `master`, then `main` |
| **On default branch?** | Derived | Boolean comparison |
| **Ahead count** | `git rev-list --count origin/{default}..HEAD` | Local commits not pushed |
| **Behind count** | `git rev-list --count HEAD..origin/{default}` | Remote commits not pulled |
| **Dirty file count** | `git status --porcelain` line count | Combined: staged + unstaged + untracked |
| **Dirty file list** | `git status --porcelain` | With status codes (`M`, `??`, `A`, `D`, etc.) |
| **Local branch count** | `git branch --list` line count | Excluding current |
| **Local branch names** | `git branch --list` | For topic branch awareness |
| **Last fetch time** | `.git/FETCH_HEAD` file mtime | `nil` if file doesn't exist (never fetched) |
| **Operation state** | Internal | `idle` / `fetching` / `pulling` / `error` |
| **Last error** | Internal | Error message from last failed operation |

### 4.3 Git Operations

**Timeouts:** All git commands run with a timeout. Network operations (fetch, pull) timeout after 60 seconds. Local operations (status, branch) timeout after 10 seconds. On timeout, the OS process is killed (`Task.shutdown/2`), the GenServer sets operation state to `:error` with message "Operation timed out", and broadcasts the update.

**Error capture:** All `System.cmd/3` calls use `stderr_to_stdout: true` so git's error output (which goes to stderr) is captured and surfaced in the `last_error` field.

#### 4.3.1 Fetch (per-repo)

- Command: `git fetch --all --prune`
- **Always safe.** No preconditions.
- On completion: refresh repo status (ahead/behind counts update)

#### 4.3.2 Fetch All (global)

- Triggers fetch on all repos in parallel (`Task.async` per repo)
- Each repo row updates independently as its fetch completes
- Global button shows progress: "Fetching 4/7..."

#### 4.3.3 Pull (per-repo)

- Command: `git pull --ff-only`
- **Preconditions (ALL must be true):**
  - Currently on default branch
  - Clean working tree (0 dirty files)
  - Not diverged (ahead count must be 0)
  - Behind count > 0 (something to pull)
- If preconditions fail: button is disabled with a tooltip explaining why
- On completion: refresh repo status

#### 4.3.4 Pull All (global)

- Triggers pull on all *eligible* repos in parallel
- Skips ineligible repos — does not fail, just reports skip reason per repo
- Shows progress: "Pulling 5/7... (2 skipped)"

#### 4.3.5 Refresh Status (per-repo)

- Re-reads git status without any network call
- Instant, cheap — just re-runs the status commands

### 4.4 Safety Rules (Hard Constraints)

These are non-negotiable and cannot be overridden from the UI:

1. **Never force-pull** — no `--force`, no `--rebase`
2. **Never pull on dirty repos** — if working tree has changes, pull is disabled
3. **Never pull if diverged** — if both ahead AND behind, pull is disabled
4. **Always `--ff-only`** — if fast-forward isn't possible, fail cleanly with message
5. **Never switch branches** — the UI does not change which branch a repo is on
6. **Never modify files** — no stash, no reset, no checkout of files

### 4.5 UI Layout

Single page, no routing, no navigation.

```
┌──────────────────────────────────────────────────────────────────┐
│  REPO MAN                                    [Fetch All] [Pull All] │
│  ~/src/shred · 7 repos · Last scan: just now                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ● AXO471   master   ✓ clean    ↓0 ↑0           [Fetch] [Pull] │
│  ● AXO472   master   ✓ clean    ↓3 ↑0           [Fetch] [Pull] │
│  ● AXO473   master   ✓ clean    ↓0 ↑0           [Fetch] [Pull] │
│  ● AXO478   master   ✓ clean    ↓1 ↑0           [Fetch] [Pull] │
│  ● AXO484   master   ✓ clean    ↓0 ↑0           [Fetch] [Pull] │
│  ● AXO491   master   ✓ clean    ↓0 ↑0           [Fetch] [Pull] │
│  ● AXO492   master   7 dirty    ↓0 ↑0           [Fetch] [   ] │
│    └─ 3 topic branches: feat/SHRED-2926-email-service-...       │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  6 synced · 1 dirty · 0 behind · 0 diverged                     │
└──────────────────────────────────────────────────────────────────┘
```

### 4.6 Status Indicators & Color Coding

| State | Icon | Color | Meaning |
|-------|------|-------|---------|
| Clean, on default branch, up to date | `●` | Green | Nothing to do |
| Clean, on default branch, behind origin | `●` | Blue | Can pull |
| On a topic branch | `●` | Yellow/Amber | Not on default branch |
| Dirty working tree | `●` | Orange | Has uncommitted changes |
| Diverged (ahead AND behind) | `●` | Red | Manual intervention needed |
| Fetching / Pulling | Spinner | Gray | Operation in progress |
| Error | `✗` | Red | Last operation failed |

**Priority ordering** (when states overlap, first match wins): Error > Diverged > Dirty > Topic branch > Behind > Clean.

### 4.7 Inline Card Detail

> **Note:** Originally specified as expandable rows. Superseded by the UI design spec (`docs/design-docs/ui-design.md`) — all details are visible at a glance in flow cards, no click-to-expand.

Each repo card shows inline (when applicable):

- **Dirty files** (if any): list with status codes (`M src/foo.py`, `?? new_file.txt`). Max 8 shown, then "+N more".
- **Topic branches** (if any): list of local branch names other than default. Max 5 shown, then "+N more".
- **Pull disabled reason** (if applicable): human-readable explanation
  - "7 dirty files — commit or stash changes first"
  - "On branch `feat/SHRED-2926` — switch to master first"
  - "Diverged: 2 ahead, 3 behind — manual merge needed"
  - "Already up to date"

### 4.8 Bulk Operation Progress

When "Fetch All" or "Pull All" is clicked:

- The global button transforms to show progress: `Fetching 3/7...`
- Each repo row updates independently as its operation completes
- On completion, button returns to normal state
- Summary line updates with new totals
- No cancel mechanism in MVP (fetches are safe and fast; acceptable limitation)

## 5. Architecture

### 5.1 Process Model

```
Phoenix Application
├── RepoMan.RepoSupervisor (DynamicSupervisor)
│   ├── RepoMan.RepoServer (GenServer) — AXO471
│   ├── RepoMan.RepoServer (GenServer) — AXO472
│   ├── RepoMan.RepoServer (GenServer) — AXO473
│   ├── RepoMan.RepoServer (GenServer) — AXO478
│   ├── RepoMan.RepoServer (GenServer) — AXO484
│   ├── RepoMan.RepoServer (GenServer) — AXO491
│   └── RepoMan.RepoServer (GenServer) — AXO492
├── RepoMan.TaskSupervisor (Task.Supervisor)
│   └── (transient tasks for fetch/pull operations)
└── RepoManWeb.Live.DashboardLive (LiveView)
```

- **One GenServer per repo**: holds the current status struct, serializes operations so you can't fetch and pull the same repo simultaneously
- **Task.Supervisor**: runs actual git commands as supervised tasks; if a command hangs or crashes, it's isolated
- **PubSub**: GenServers broadcast status changes → LiveView subscribes and updates UI

### 5.2 Data Flow

```
User clicks "Fetch" on AXO472
  → LiveView sends event to AXO472's GenServer
  → GenServer sets state to :fetching, broadcasts update
  → GenServer spawns Task under TaskSupervisor
  → Task runs `git fetch --all --prune`
  → Task completes, sends result back to GenServer
  → GenServer runs status refresh commands
  → GenServer updates state, broadcasts update
  → LiveView receives broadcast, re-renders row
```

### 5.3 Git Interface

All git operations go through a single module: `RepoMan.Git`.

```elixir
# All functions take a repo_path and return {:ok, result} | {:error, reason}
RepoMan.Git.status(repo_path)        # → %RepoStatus{}
RepoMan.Git.fetch(repo_path)         # → :ok | {:error, message}
RepoMan.Git.pull_ff_only(repo_path)  # → :ok | {:error, message}
RepoMan.Git.branch_info(repo_path)   # → %BranchInfo{}
```

Implementation: `System.cmd("git", args, cd: repo_path, stderr_to_stdout: true)` — shells out to the user's git binary. This respects the user's git config, SSH keys, credential helpers, etc. The `stderr_to_stdout: true` option ensures git error messages are captured and surfaced in the UI rather than lost to the server console.

### 5.4 Status Struct

```elixir
defmodule RepoMan.RepoStatus do
  defstruct [
    :name,              # "AXO471"
    :path,              # "/Users/tej/src/shred/AXO471"
    :current_branch,    # "master"
    :default_branch,    # "master"
    :on_default?,       # true
    :ahead,             # 0
    :behind,            # 3
    :dirty_count,       # 0
    :dirty_files,       # [%{status: "M", path: "src/foo.py"}, ...]
    :local_branches,    # ["feat/SHRED-2926-email-...", ...]
    :last_fetch,        # ~U[2026-03-13 14:30:00Z] | nil
    :operation,         # :idle | :fetching | :pulling
    :last_error,        # nil | "fatal: not a git repository"
    :pull_eligible?,    # true (derived: on_default? && dirty_count == 0 && ahead == 0 && behind > 0)
    :pull_blocked_reason # nil | "7 dirty files — commit or stash first"
  ]
end
```

## 6. Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Language | Elixir | Process model maps 1:1 to "one GenServer per repo" |
| Framework | Phoenix 1.7+ | LiveView ships built-in, Tailwind ships built-in |
| Real-time | LiveView | Server-push UI diffs over WebSocket, zero JS |
| Git interface | `System.cmd/3` | Respects user's git config, SSH, credentials |
| Concurrency | `Task.Supervisor` + GenServer | Crash isolation, parallel operations |
| State | In-memory (GenServer state) | No database. All truth comes from git. |
| CSS | Tailwind CSS (Phoenix default) | Ships with `mix phx.new`, zero extra config |
| Database | **None** | No Ecto, no migrations, no schema |
| JS | **None** (LiveView handles it) | No npm, no node_modules, no bundler |

## 7. Project Structure

```
repo_man/
├── lib/
│   ├── repo_man/
│   │   ├── application.ex          # Starts supervisors
│   │   ├── git.ex                  # Git command interface
│   │   ├── repo_status.ex          # Status struct + derivations
│   │   ├── repo_server.ex          # GenServer per repo
│   │   ├── repo_supervisor.ex      # DynamicSupervisor for repo servers
│   │   └── repo_discovery.ex       # Scan filesystem for git repos
│   └── repo_man_web/
│       ├── components/
│       │   └── layouts/
│       │       ├── app.html.heex
│       │       └── root.html.heex
│       ├── live/
│       │   ├── dashboard_live.ex   # The single LiveView page
│       │   └── dashboard_live.html.heex
│       ├── endpoint.ex
│       ├── router.ex
│       └── telemetry.ex
├── config/
│   ├── config.exs
│   ├── dev.exs
│   └── runtime.exs                 # SHRED_PATH env var (default ~/src/shred)
├── test/
│   ├── repo_man/
│   │   ├── git_test.exs
│   │   ├── repo_server_test.exs
│   │   └── repo_discovery_test.exs
│   └── repo_man_web/
│       └── live/
│           └── dashboard_live_test.exs
├── mix.exs
└── docs/
    └── mvp-spec.md                 # This file
```

## 8. Configuration

Minimal. One environment variable with a sensible default:

```elixir
# config/runtime.exs
config :repo_man,
  repos_path: System.get_env("REPOMAN_PATH", Path.expand("~/src/shred"))
```

## 9. What Is Explicitly NOT in MVP

| Feature | Why it's cut |
|---------|-------------|
| Database / Ecto | All state comes from git. No persistence needed. |
| Authentication | Localhost only. Single user. |
| Config file / repo registry | Auto-discovery is simpler and always correct. |
| Branch switching from UI | Dangerous. Out of scope. |
| Commit log viewer | Use `git log` or GitHub for that. |
| Diff viewer | Use your IDE or `git diff`. |
| Auto-polling / scheduled refresh | Manual is safer for MVP. Add later if wanted. |
| Dark/light theme toggle | Pick one good theme, ship it. |
| Notifications | You're looking at the dashboard. You can see it. |
| Stash management | Read-only for working tree state. |
| Remote management | Single remote (`origin`) assumed. |
| Configurable scan paths | Hardcoded with env var escape hatch. Good enough. |

## 10. Success Criteria

The MVP is done when:

1. `mix phx.server` starts and opens a dashboard at `localhost:4000`
2. All git repos under `~/src/shred/` appear with correct status
3. "Fetch" updates a single repo and the UI reflects the new state in real-time
4. "Fetch All" fetches all repos in parallel with per-repo progress
5. "Pull" fast-forward merges an eligible repo and updates the UI
6. "Pull All" pulls all eligible repos, skips ineligible ones with reasons
7. Dirty repos show file list on expand
8. Topic branch repos are visually distinct with branch names shown
9. Disabled pull buttons explain why they're disabled
10. No git operation can damage or modify the working tree beyond fast-forward pulls
