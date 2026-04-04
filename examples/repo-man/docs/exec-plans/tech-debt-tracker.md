# Tech Debt Tracker

Known shortcuts, deferred improvements, and open questions.

## Pre-Implementation

### Spec Drift (identified 2026-03-13 by Copilot GPT-5.4 review)

- [x] Implementation plan references `brew install elixir`. **Fixed:** Supersession
      header added to plan. Must use Docker per `Dockerfile` and `docker-compose.yml`.
- [x] Implementation plan has expand/collapse UI (`toggle_expand`, `expanded` assigns).
      **Fixed:** Supersession header added. Per `ui-design.md`, all details visible at a
      glance. Cards size to content. No expand/collapse.
- [x] Implementation plan tests row expansion (lines ~1824-1829, 1872).
      **Fixed:** Supersession header notes replacement with always-visible card tests.
- [x] Implementation plan references old file paths (`docs/mvp-spec.md`).
      **Fixed:** Supersession header notes new paths.

### Open Questions

- [ ] SSH/credential forwarding for `git fetch` in Docker needs testing.
      If repos use HTTPS with credential helpers, it may work via mounted `.gitconfig`.
- [ ] Implementation plan is 66KB with full code listings. Many sections are
      now stale. Consider rewriting as a lighter exec-plan that references specs
      rather than duplicating code inline.

## During Implementation

- [x] Default branch detection was stale — `origin/HEAD` pointed to `master` after
      remotes moved to `main`. **Fixed:** `Git.fetch/1` now runs `git remote set-head origin --auto`
      after fetch. `Git.default_branch/1` validates symref against remote tracking branches
      and falls back to `origin/main` then `origin/master`.
- [x] Open Terminal link used `ghostty://` URL scheme which Ghostty doesn't register.
      **Fixed:** Host-side companion script (`scripts/terminal-opener.py`) listens on
      localhost:4001. UI sends fetch() to open Ghostty via AppleScript new-tab. Added
      `REPOMAN_HOST_PATH` env var to map container paths to host paths.

## Post-MVP

- [ ] Open Terminal companion (`scripts/terminal-opener.py`) requires a host-side
      process. Could be replaced if Ghostty adds URL scheme support.
- [ ] `dashboard_live.ex` is ~1200 lines. Consider extracting card components into
      separate modules if it grows further.
- [ ] Polling interval is broadcast to all RepoServers individually via Registry
      iteration. Could use a PubSub topic for efficiency at scale.
