# MoES Implementation Queue

Findings from the 2026-03-31 full-panel code review. Work in order.

## Done

- [x] **#2** Extract dashboard_live.ex — card components, domain logic, Registry abstraction (major, agreed all 4)

## Queue

- [ ] **#3** Add `RepoStatus.with_operation/2`, remove `status_attrs/2` from RepoServer (major, agreed all 4)
- [ ] **#5** Extract `card_shell` slot component to deduplicate 7 card types (major, agreed 3)
- [ ] **#4** Separate `operation` from RepoStatus — keep it as process state in RepoServer only (major, Hickey)
- [ ] **#6** Convert `compute_severity/6` to accept a map instead of 6 positional params (minor, Metz + Uncle Bob)
- [ ] **#7** Make `local_branches/1` return all branches, filter at caller (minor, Fowler + Hickey)
- [ ] **#8** Rewrite `compute_banner/1` as a single `Enum.reduce` (minor, Fowler + Hickey)
- [ ] **#9** Move `Application.get_env` out of `summary_line/1` render into mount assigns (minor, Uncle Bob)
- [ ] **#10** Add `--` separator in `git rev-list` branch argument (minor, Schneier)

## Skipped

- **#1** AppleScript injection in terminal-opener.py — user chose to skip (localhost-only, single user)
