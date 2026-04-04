## Execution Brief: dashboard-extraction

**Spec:** docs/design-docs/2026-03-31-dashboard-extraction-design.md (all sections)
**Dependencies:** MET — all 31 backlog features are checked off; dashboard_live.ex exists at 1228 lines
**Spec consistency:** PASS — spec is self-consistent; no conflicts with backlog or ARCHITECTURE.md
**Research needed:** NO
**Designer needed:** NO — pure refactoring, no new behavior, no UI changes
**Implementer needed:** YES

**Compile check:** PASS — `docker compose run --rm app mix compile` exits 0

---

## What to build

Move code out of `RepoManWeb.DashboardLive` into three new homes without changing any behavior. Extraction A moves the 7 card `defp` functions plus `fetch_button/1`, `pull_button/1`, `open_terminal_link/1`, and `to_host_path/1` into a new `RepoManWeb.RepoCard` module. Extraction B moves `compute_banner/1`, `compute_banner_state/1`, `summary_counts/1`, `format_time/1`, and `bulk_progress_text/2` into a new `RepoMan.Dashboard` module. Extraction C adds `dispatch/2` and `dispatch_all/2` to `RepoMan.RepoSupervisor`, then replaces the five raw `Registry.lookup` call sites in the LiveView with those functions.

---

## New files

- `repo_man/lib/repo_man_web/components/repo_card.ex` — `RepoManWeb.RepoCard` module. Contains `use Phoenix.Component`. Exports via `def` (not `defp`) the 7 card functions (`clean_card/1`, `behind_card/1`, `topic_card/1`, `dirty_card/1`, `diverged_card/1`, `error_card/1`, `in_progress_card/1`) plus the shared sub-components `fetch_button/1`, `pull_button/1`, `open_terminal_link/1`, and the private helper `to_host_path/1`. All `attr` declarations move with their functions. Calls `format_time/1` from `RepoMan.Dashboard`.

- `repo_man/lib/repo_man/dashboard.ex` — `RepoMan.Dashboard` module. Pure functions, no Phoenix dependency. Exports `banner/1` (renamed from `compute_banner/1`), `compute_banner_state/1` (shim calling `banner/1` for test compatibility), `summary_counts/1`, `format_time/1`, `bulk_progress_text/2`.

---

## Modified files

- `repo_man/lib/repo_man_web/live/dashboard_live.ex` — After extraction:
  - Remove the 7 card `defp` functions, `fetch_button/1`, `pull_button/1`, `open_terminal_link/1`, `to_host_path/1`.
  - Remove `compute_banner/1`, `compute_banner_state/1`, `summary_counts/1`, `format_time/1`, `bulk_progress_text/2`.
  - Replace the four `Registry.lookup` call sites in `handle_event("fetch_all")`, `handle_event("pull_all")`, `handle_event("cycle_refresh")`, `handle_event("restore_refresh")` with `RepoSupervisor.dispatch_all/2`.
  - Replace `send_to_repo/2`'s `Registry.lookup` with `RepoSupervisor.dispatch/2`.
  - Add `import RepoManWeb.RepoCard` (or `alias`, depending on HEEx call-site syntax — see pattern note below).
  - Calls to `compute_banner/1` in `mount/3` and `handle_info/2` change to `RepoMan.Dashboard.banner/1`.
  - Calls to `summary_counts/1` in `summary_line/1` change to `RepoMan.Dashboard.summary_counts/1`.
  - Calls to `format_time/1` in `summary_line/1` stay as-is only if the function is delegated; otherwise alias the module.
  - Drop the `alias RepoMan.RepoServer` if it is no longer needed directly (it is still needed for `get_status` calls in `RepoSupervisor`).
  - Result: ~400 lines.

- `repo_man/lib/repo_man/repo_supervisor.ex` — Add two public functions:

  ```elixir
  @spec dispatch(String.t(), (pid() -> any()), keyword()) :: any()
  def dispatch(name, fun, opts \\ []) do
    registry = Keyword.get(opts, :registry, RepoMan.RepoRegistry)
    case Registry.lookup(registry, name) do
      [{pid, _}] -> fun.(pid)
      _ -> :ok
    end
  end

  @spec dispatch_all([String.t()], (pid() -> any()), keyword()) :: :ok
  def dispatch_all(names, fun, opts \\ []) do
    Enum.each(names, &dispatch(&1, fun, opts))
  end
  ```

  The `opts` keyword argument is required for testability — the existing `RepoSupervisorTest` passes a custom `registry:` name to every function.

---

## Existing patterns to follow

- `/Users/tej/src/repo-man/repo_man/lib/repo_man_web/components/core_components.ex` — How Phoenix function components are structured in this project (uses `use Phoenix.Component`, `attr` declarations, `defp`/`def` component functions with `~H` sigil). `RepoCard` should follow this exact pattern.

- `/Users/tej/src/repo-man/repo_man/lib/repo_man/repo_supervisor.ex:all_statuses/1` — The pattern for accepting `opts \\ []` with `Keyword.get(opts, :registry, RepoMan.RepoRegistry)`. The new `dispatch/2` and `dispatch_all/2` must use the same opts pattern so existing tests pass unchanged.

- `/Users/tej/src/repo-man/repo_man/lib/repo_man_web/live/dashboard_live.ex:handle_event("fetch_all")` — The five Registry.lookup call sites that `dispatch/dispatch_all` will replace. Each currently does `case Registry.lookup(RepoMan.RepoRegistry, repo.name) do [{pid, _}] -> ...; _ -> :ok end`.

---

## Acceptance tests (for test-writer)

The spec (section 5) states: "Existing tests continue to pass unchanged. No new tests needed." The test-writer's job is therefore verification, not authorship:

1. Run `mix test` and confirm the full suite passes green after each extraction step (A, B, C independently).
2. Confirm `RepoManWeb.DashboardLiveTest` — all existing assertions pass; no module-not-found or undefined-function errors.
3. Confirm `RepoMan.RepoSupervisorTest` — all existing tests pass; confirm `dispatch/2` and `dispatch_all/2` are reachable.
4. Add targeted unit tests for the new `RepoSupervisor.dispatch/2` covering: pid found → fun is called; name not found → returns `:ok`.
5. Add targeted unit tests for the new `RepoSupervisor.dispatch_all/2` covering: dispatches to each name in list; skips names with no registered server.
6. Add targeted unit tests for `RepoMan.Dashboard.banner/1` covering the four return states (`:current`, `:behind`, `:warning`, `:error`) and the in-progress skip logic.
7. Add targeted unit tests for `RepoMan.Dashboard.summary_counts/1` covering all 6 severity buckets.
8. Add targeted unit tests for `RepoMan.Dashboard.format_time/1` covering nil, just-now, minutes, hours, days.

---

## Edge cases

- `compute_banner_state/1` is a public function called by existing tests. It must remain public and continue to delegate to `banner/1`. Do not delete it.
- `format_time/1` is referenced inside `RepoCard` (card HEEx templates call it). Either keep a delegating call in `DashboardLive` or have `RepoCard` call `RepoMan.Dashboard.format_time/1` directly. The latter is cleaner and eliminates the circular dependency risk.
- HEEx call syntax for extracted components: if `RepoCard` functions are called as `<.clean_card ...>` inside `DashboardLive`, you need `import RepoManWeb.RepoCard` in the LiveView (or `use RepoManWeb.RepoCard`). If called as `<RepoManWeb.RepoCard.clean_card ...>`, no import is needed. Follow whichever pattern matches `core_components.ex` usage in this project — currently `DashboardLive` uses dot-call syntax (e.g., `<.fetch_button>`), so an import is the path of least resistance.
- The `dispatch/dispatch_all` opts argument must default to `RepoMan.RepoRegistry` to keep the LiveView call sites clean (no opts needed at call site). Tests that need a custom registry pass `registry: ctx.registry` explicitly, matching the existing pattern in `RepoSupervisorTest`.
- `behind_card/1` computes `other_branches`, `visible_branches`, `remaining_count`, `other_branch_count` from `assigns` before the `~H` block. These local variable assignments must move into the new module intact.
- `dirty_card/1` and `in_progress_card/1` similarly have pre-HEEx local computation that must move with the function.

---

## Risks

- **Import scope for HEEx components.** If `RepoCard` components are imported into `DashboardLive` but also referenced from within `RepoCard` itself (e.g., `dirty_card` calling `<.fetch_button>`), the internal calls resolve because they are in the same module. After extraction this still holds as long as `fetch_button/1` and `pull_button/1` are in `RepoCard` and the card functions call them as `<.fetch_button>` within the same module. Verify this compiles before running tests.
- **`format_time/1` visibility.** It is currently marked `@doc false` with `def` (public) in `DashboardLive`. Tests call `DashboardLive.format_time/1` directly (check test file before assuming). If tests call it on `DashboardLive`, a delegation shim must remain there, or the test alias must update. Review dashboard_live_test.exs for direct calls to `format_time`.
- **Safety-auditor scope.** `dispatch/dispatch_all` wrap the Registry lookup that currently precedes every `RepoServer.fetch/pull` call. The auditor must verify: (a) no new code path can trigger fetch/pull that bypasses the existing guards in `RepoServer` itself; (b) `dispatch_all` does not introduce a race condition different from the existing `Enum.each` pattern it replaces.

---

**Path convention:** Phoenix project at `repo_man/` subdirectory. All lib/test paths relative to that.
Host: `~/src/repo-man/repo_man/lib/...` → Docker: `/app/lib/...`

**Ready:** YES
**Next hop:** test-writer → implementer → spec-reviewer → safety-auditor
