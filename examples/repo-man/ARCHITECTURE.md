# Architecture

## Overview

Phoenix LiveView app. One GenServer per discovered git repo holds status and
serializes operations. A single LiveView page subscribes to PubSub for real-time
updates. Git commands shell out via `System.cmd/3`. No database — all state
derived from git.

## Supervision Tree

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

RepoServers are started AFTER the supervision tree is up, gated by
`start_repos_on_boot` config (default true, false in test).

## Data Flow

```
User clicks "Fetch" on a repo
  → LiveView sends event to repo's GenServer
  → GenServer sets state to :fetching, broadcasts update
  → GenServer spawns Task under TaskSupervisor
  → Task runs `git fetch --all --prune`
  → Task completes, sends result back to GenServer
  → GenServer runs status refresh commands
  → GenServer updates state, broadcasts update
  → LiveView receives broadcast, re-renders card
```

## Module Map

| Module | File | Responsibility | Depends On |
|--------|------|---------------|------------|
| `RepoMan.Git.Behaviour` | `lib/repo_man/git/behaviour.ex` | 9-callback contract for git interface. | Nothing |
| `RepoMan.Git` | `lib/repo_man/git.ex` | Shell-out implementation of Behaviour. | Nothing |
| `RepoMan.RepoStatus` | `lib/repo_man/repo_status.ex` | Status struct with derived fields. | Nothing (pure data) |
| `RepoMan.RepoDiscovery` | `lib/repo_man/repo_discovery.ex` | Scans filesystem for git repos. | @git_module |
| `RepoMan.RepoServer` | `lib/repo_man/repo_server.ex` | GenServer per repo. Holds state, serializes ops, polls git status on a configurable interval. | @git_module, RepoStatus, PubSub, TaskSupervisor |
| `RepoMan.Dashboard` | `lib/repo_man/dashboard.ex` | Pure functions: banner state, summary counts, time formatting. | RepoStatus (data only) |
| `RepoMan.RepoSupervisor` | `lib/repo_man/repo_supervisor.ex` | DynamicSupervisor. Discovers + starts RepoServers. Dispatch helpers for name-based server lookup. | RepoServer, RepoDiscovery, Registry |
| `RepoManWeb.RepoCard` | `lib/repo_man_web/components/repo_card.ex` | Function components for all 7 card types + shared button components. | Dashboard (format_time) |
| `RepoManWeb.DashboardLive` | `lib/repo_man_web/live/dashboard_live.ex` | LiveView coordinator. Mounts, handles events, dispatches to card components. | PubSub, RepoSupervisor, Dashboard, RepoCard |

## Layer Dependencies

Dependencies flow strictly downward:

```
DashboardLive (UI)            ← F17-F28
      ↓ subscribes via PubSub
RepoSupervisor (Runtime)      ← F16
      ↓ starts
RepoServer (Service)          ← F12-F15
      ↓ calls via @git_module
Git + RepoStatus (Foundation) ← F04-F11
```

Cross-cutting: `Phoenix.PubSub`, `Task.Supervisor`, `Registry`

## Git Module Injection

The Git module is injected via application config for Mox testability:

```elixir
# In modules that call Git:
@git_module Application.compile_env(:repo_man, :git_module, RepoMan.Git)

# config/test.exs:
config :repo_man, git_module: RepoMan.Git.Mock

# config/dev.exs and config/config.exs:
# (no config needed — defaults to RepoMan.Git)
```

All modules that call Git functions use `@git_module.function()` instead of
`RepoMan.Git.function()`. This allows Mox to replace the real implementation.

### Mox in Multi-Process Tests

For GenServer/Task tests, use `Mox.set_mox_global` or `Mox.allow/3`:

```elixir
Mox.set_mox_global(context)  # in setup — allows all processes
# or
Mox.allow(RepoMan.Git.Mock, self(), pid)  # specific process
```

## Key Design Decisions

- **One GenServer per repo:** Crash isolation + operation serialization
- **Registry for named lookup:** `{:via, Registry, {RepoMan.RepoRegistry, name}}`
- **System.cmd/3 for git:** Respects user's git config, SSH keys, credentials
- **No database:** All truth comes from git. GenServer state is a cache.
- **PubSub for real-time:** GenServers broadcast on topic "repos", LiveView subscribes
- **Task.Supervisor for git commands:** Crash isolation for long-running ops
- **Timeouts:** Network ops 60s, local ops 10s. On timeout, OS process killed.
- **start_repos_on_boot:** Config flag (default true) skips auto-start in test
- **Periodic polling:** RepoServer polls git status every N seconds (default 2s, configurable via `poll_interval` config). Broadcasts only on change. Skips during in-progress ops. LiveView controls the interval via `set_poll_interval/2`.
- **Host path mapping:** `REPOMAN_HOST_PATH` env var provides the host-side repos path for UI links (container path `/repos` differs from host path `~/src/repos`)

## Docker Architecture

```
┌─────────────────────────────────┐
│  Docker Container               │
│  elixir:1.19-slim + git        │
│                                 │
│  /app  ← ./repo_man (mounted)  │
│  /repos ← ~/src/repos (mounted)│
│                                 │
│  mix phx.server → :4000        │
└────────────┬────────────────────┘
             │ port 4000
             ↓
        localhost:4000 (browser)
             │ fetch() on ↗ click
             ↓
        localhost:4001 (terminal-opener.py, host-side)
             │ open -a Ghostty.app via AppleScript
             ↓
        Ghostty (new tab at repo dir)
```

- Source mounted for live code reload
- `~/src/repos/` mounted read-write (fetch/pull modify .git/)
- `REPOMAN_PATH=/repos` environment variable (container-side)
- `REPOMAN_HOST_PATH=$HOME/src/repos` environment variable (host-side, for UI links)
- `scripts/terminal-opener.py` runs on the host (not in Docker) — opens Ghostty tabs via AppleScript
