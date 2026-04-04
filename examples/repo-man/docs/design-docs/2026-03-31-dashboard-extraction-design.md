# Dashboard Extraction Design

**Date:** 2026-03-31
**Status:** Approved
**Type:** Refactoring — no new behavior, no UI changes
**Source:** MoES review finding #2 (agreed: Uncle Bob, Fowler, Metz, Hickey)

---

## 1. Problem

`dashboard_live.ex` is 1228 lines with 13 responsibilities. It contains domain logic, card components, button components, utility functions, and Registry lookups that don't belong in a LiveView.

## 2. Extraction Plan

### A. `RepoManWeb.RepoCard` — card function components

Extract all 7 card `defp` functions to a new module:
- `clean_card/1`
- `behind_card/1`
- `topic_card/1`
- `dirty_card/1`
- `diverged_card/1`
- `error_card/1`
- `in_progress_card/1`

Also extract the shared sub-components used by cards:
- `fetch_button/1`
- `pull_button/1`
- `open_terminal_link/1` (and `to_host_path/1`)

The card dispatcher `repo_card/1` stays in the LiveView and calls the extracted module.

**File:** `repo_man/lib/repo_man_web/components/repo_card.ex`

### B. `RepoMan.Dashboard` — pure domain logic

Extract functions that don't touch `socket` or `assigns`:
- `compute_banner/1` → `Dashboard.banner/1`
- `compute_banner_state/1` → remove (backward compat shim)
- `summary_counts/1` → `Dashboard.summary_counts/1`
- `format_time/1` → `Dashboard.format_time/1`
- `bulk_progress_text/2` → `Dashboard.bulk_progress_text/2`

**File:** `repo_man/lib/repo_man/dashboard.ex`

### C. Registry abstraction in `RepoSupervisor`

Extract the repeated Registry lookup pattern (appears 5 times in the LiveView) into `RepoSupervisor`:
- `RepoSupervisor.dispatch(name, fun)` — looks up server by name, calls `fun.(pid)`
- `RepoSupervisor.dispatch_all(names, fun)` — iterates and dispatches to each

The LiveView stops touching `Registry` directly.

**File:** `repo_man/lib/repo_man/repo_supervisor.ex` (modify existing)

## 3. Constraints

- **Zero behavior change.** All existing tests must pass without modification.
- **No UI changes.** Rendered HTML must be identical.
- **No new features.** This is purely structural.
- **Incremental.** Each extraction (A, B, C) can be done and tested independently.

## 4. Expected Outcome

`dashboard_live.ex` drops from ~1228 lines to ~400 lines:
- ~600 lines move to `RepoCard`
- ~80 lines move to `Dashboard`
- ~50 lines simplified by `dispatch/dispatch_all`

## 5. Testing

Existing tests continue to pass unchanged. No new tests needed — the extracted functions have the same behavior, just a different home address.
