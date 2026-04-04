# Repo Man UI Design Spec

**Date:** 2026-03-13
**Status:** Approved
**Depends on:** `docs/product-specs/mvp-spec.md`

---

## 1. Purpose

Repo Man is a pre-flight checklist for software architecture work. Before Tej starts designing across 7+ repos, this dashboard answers one question: **"Is my codebase current?"**

The UI must make that answer instantly obvious — mint banner means go, anything else means sync first.

**Supersedes mvp-spec.md Section 4.7** (expandable rows) — this spec replaces click-to-expand with all-details-visible cards. The mvp-spec's expandable row pattern is dropped in favor of cards that size to their content.

## 2. Visual Direction

### Aesthetic

- **Polished minimal.** Linear/Vercel quality without excess chrome.
- **Dark-first** via `data-theme` attribute with manual toggle, light as equal citizen.
- **System sans-serif** (`-apple-system, 'Inter', sans-serif`) for UI text. **Monospace** only for git data: branch names, file paths, status codes.

### Color Philosophy

**Absence of color = everything is fine.** Color only appears to flag things needing attention.

- Clean repos render with neutral gray borders and muted text. They're quiet — nothing to see.
- Repos needing attention get colored left borders, tinted card borders, and status pills.
- The freshness banner is the only place "all clear" gets color (light mint `#86efac`).

### Status Colors (on dark background)

| State | Left Border | Card Border | Pill |
|-------|-------------|-------------|------|
| Clean + up to date | `#333` (gray) | `#1f1f1f` | None |
| Behind origin | `#3b82f6` (blue) | `#1e3a5f` | `bg:#172554 text:#60a5fa` |
| Topic branch | `#f59e0b` (amber) | `#422006` | `bg:#422006 text:#fbbf24` |
| Dirty working tree | `#f97316` (orange) | `#431407` | `bg:#431407 text:#fb923c` |
| Diverged / Error | `#ef4444` (red) | `#450a0a` | `bg:#450a0a text:#f87171` |
| Fetching / Pulling | `#737373` (gray) | `#1f1f1f` | `bg:#262626 text:#a3a3a3` |

### Status Colors (on light background)

| State | Left Border | Card Border | Pill |
|-------|-------------|-------------|------|
| Clean + up to date | `#d4d4d4` (gray) | `#e5e5e5` | None |
| Behind origin | `#3b82f6` (blue) | `#bfdbfe` | `bg:#eff6ff text:#2563eb` |
| Topic branch | `#f59e0b` (amber) | `#fde68a` | `bg:#fef9c3 text:#a16207` |
| Dirty working tree | `#f97316` (orange) | `#fed7aa` | `bg:#fff7ed text:#ea580c` |
| Diverged / Error | `#ef4444` (red) | `#fecaca` | `bg:#fef2f2 text:#dc2626` |
| Fetching / Pulling | `#a3a3a3` (gray) | `#e5e5e5` | `bg:#f5f5f5 text:#737373` |

## 3. Layout

### Page Structure

```
┌─────────────────────────────────────────────────────────┐
│  Repo Man                              [Fetch All] [Pull All] │
├─────────────────────────────────────────────────────────┤
│  ✓ All repos current — ready for design work            │  ← Freshness banner
│  OR                                                      │
│  ⚠ 2 repos behind origin — designs may be stale         │
├─────────────────────────────────────────────────────────┤
│  ~/src/shred · 7 repos · 4 synced · 1 behind · ...     │  ← Summary line
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                   │
│  │AXO471│ │AXO473│ │AXO478│ │AXO484│  ← Clean: compact │
│  └──────┘ └──────┘ └──────┘ └──────┘                   │
│                                                          │
│  ┌────────────┐ ┌────────────┐ ┌──────────────┐        │
│  │AXO472      │ │AXO491      │ │AXO492        │        │
│  │3 behind    │ │topic branch│ │7 dirty       │  ← Attention: bigger │
│  │branches    │ │branch name │ │file list     │        │
│  │[Fetch][Pull│ │[Fetch]     │ │[Fetch][Pull] │        │
│  └────────────┘ └────────────┘ └──────────────┘        │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Flow Grid

- `display: flex; flex-wrap: wrap; gap: 8px; align-items: flex-start`
- Cards size to their content — clean repos are compact, problem repos expand to show details
- No fixed column count — cards wrap naturally based on viewport width
- All details visible at a glance — **no click-to-expand**

## 4. Card Anatomy

### Clean Repo Card (Neutral)

```
┌─ gray border-left ────────────┐
│  AXO471          (600 weight) │
│  master · clean    (muted)    │
│  ↓0 ↑0 · 2h ago     [↗]     │  ← Open Terminal link
└───────────────────────────────┘
```

- No Fetch/Pull buttons (nothing to do)
- No status pill (absence of badge = fine)
- No branch list (only on default branch)
- Minimum width: 155px

### Behind Repo Card (Blue)

```
┌─ blue border-left ────────────┐
│  AXO472  [3 behind]  (pill)  │
│  master · ↓3 ↑0              │
│  2 other branches · 2h ago   │  ← excludes current branch
│  ─────────────────            │
│  feat/SHRED-2926 · fix/...   │  ← branch names in monospace
│  [Fetch] [Pull]              │  ← Pull highlighted blue
└───────────────────────────────┘
```

### Topic Branch Card (Amber)

```
┌─ amber border-left ───────────┐
│  AXO491  [topic]    (pill)   │
│  feat/SHRED-2926-email       │  ← branch name in amber monospace
│  ↓0 ↑2 · clean              │
│  1h ago                      │
│  ─────────────────            │
│  Not on default branch       │  ← pull-blocked reason
│  [Fetch]                     │  ← no Pull button
└───────────────────────────────┘
```

### Dirty Repo Card (Orange)

```
┌─ orange border-left ──────────┐
│  AXO492  [7 dirty]  (pill)   │
│  master · ↓0 ↑0              │
│  3 branches · 5m ago         │
│  ─────────────────            │
│  M src/main.py               │  ← dirty files in monospace
│  M src/utils.py              │
│  A src/new_module.py         │
│  D src/deprecated.py         │
│  ?? tmp/scratch.txt          │
│  +2 more                     │  ← truncated if > 8 files
│  ─────────────────            │
│  Dirty — commit or stash     │  ← pull-blocked reason
│  [Fetch] [Pull (disabled)]   │
└───────────────────────────────┘
```

**Truncation:** Show at most 8 dirty files. If more, show "+N more" in muted text. Same rule for branch lists: show at most 5 branches, then "+N more".

### Diverged Card (Red)

```
┌─ red border-left ─────────────┐
│  AXO484  [diverged]  (pill)  │
│  master · ↓3 ↑2              │  ← both ahead AND behind
│  30m ago                     │
│  ─────────────────            │
│  Diverged: 2 ahead, 3 behind │  ← pull-blocked reason
│  — manual merge needed       │
│  [Fetch] [Open Terminal ↗]   │  ← opens Ghostty at repo path
└───────────────────────────────┘
```

### Error Card (Red)

```
┌─ red border-left ─────────────┐
│  AXO484  [✗ error]  (pill)   │
│  master · ↓0 ↑0              │
│  30m ago                     │
│  ─────────────────            │
│  fatal: Could not read from  │  ← git error in monospace
│  remote repository.          │
│  [Retry fetch] [Open Terminal ↗] │
└───────────────────────────────┘
```

### In-Progress Card (Gray)

```
┌─ gray border-left ────────────┐
│  AXO472  [⟳ fetching…]      │
│  master · ↓3 ↑0              │
│  2 branches · 2h ago         │
│  [Fetch (disabled)] [Pull (disabled)] │  ← both disabled during op
└───────────────────────────────┘
```

- Slight opacity reduction (0.85) during operation
- Buttons disabled while operation runs

## 5. Freshness Banner

The banner answers the headline question: **"Can I trust this codebase right now?"**

### States

| Condition | Background | Icon | Text | Subtext |
|-----------|-----------|------|------|---------|
| All repos current | `#111714` | ✓ `#86efac` | "All repos current" `#86efac` | "— ready for design work" `#4b5563` |
| Some behind origin | `#1c1917` | ⚠ | "N repos behind origin" `#fbbf24` | "— designs may be stale" `#92400e` |
| Dirty or topic branch | `#1c1917` | ⚠ | "N repos need attention" `#fbbf24` | "— dirty or on topic branch" `#92400e` |
| Errors / diverged | `#1a0a0a` | ✗ | "N repos need attention" `#f87171` | "— diverged or errored" `#7f1d1d` |

### Behavior

- Banner is always visible (not dismissable)
- Updates in real-time as repo statuses change
- Worst status wins: errors > dirty/topic > behind > all clear
- Multiple conditions combine: "2 behind, 1 dirty" → show the worst category
- During in-progress operations: banner holds its previous state. A repo mid-fetch is not counted as "current" until the fetch completes and status refreshes.

## 6. Header & Controls

### Global Actions

- **Fetch All** — always enabled. Fetches all repos in parallel.
- **Pull All** — highlighted blue when pullable repos exist. Grayed out when nothing to pull.
- During bulk operation: button shows "Fetching 4/7..." and disables.

### Summary Line

```
~/src/shred · 7 repos · 4 synced · 1 behind · 1 dirty · 1 topic · 0 diverged · 0 errored
```

Updates in real-time. During bulk ops, append progress without losing counts:
```
~/src/shred · 7 repos · 4 synced · 1 behind · 1 dirty · 1 topic · Fetching 4/7…
```

## 7. Per-Card Actions

- **Fetch** — always enabled (safe operation). Neutral styling.
- **Pull** — enabled only when eligible (on default branch, clean, behind, not diverged). Blue styling when enabled. Gray/disabled otherwise.
- **Retry** — replaces Fetch after an error. Re-runs whatever operation failed (fetch or pull). Neutral styling.
- **Open Terminal ↗** — shown on every card. Opens Ghostty terminal with CWD set to the repo path (`open -a Ghostty --args --working-directory=<repo_path>`). Styled as a subtle link, not a primary action button. Useful for any hands-on work: fixing diverged state, switching to a topic branch, committing dirty files, or just poking around.
- Both Fetch/Pull buttons disabled during an in-progress operation on that repo.

## 8. Typography

| Element | Font | Size | Weight | Color (dark) |
|---------|------|------|--------|-------------|
| Page title | System sans | 32px | 700 | `#fafafa` |
| Repo name | System sans | 26px | 600 | `#e5e5e5` |
| Status pill | System sans | 20px | 400 | Per status color |
| Detail text | System sans | 22px | 400 | `#525252` |
| Tertiary text | System sans | 20px | 400 | `#404040` |
| Git data (branches, files) | Monospace | 20-22px | 400 | `#525252` or status color |
| Banner headline | System sans | 24px | 500 | Per banner state |
| Buttons | System sans | 20-22px | 400 | `#a3a3a3` or status color |

## 9. Spacing & Sizing

- Card padding: `20px 24px`
- Card border-radius: `16px`
- Card left border: `6px solid`
- Card gap: `16px`
- Card min-width: 310px (clean), 400px (with details), 440px (with file list)
- Banner padding: `16px 24px`
- Banner border-radius: `12px`
- Button padding: `4px 20px` (card) / `10px 28px` (header)
- Button border-radius: `10px` (card) / `12px` (header)

## 10. Interaction States

### Card Hover

Not needed for MVP. Cards are informational, not clickable (no expand/collapse).

### Button Hover

Subtle brightness increase on hover for enabled buttons. No hover effect on disabled buttons.

### Operation In-Progress

- Card opacity reduces to 0.85
- Spinning icon (⟳) in status pill text — CSS `animation: spin 1s linear infinite` on the character
- All buttons on that card disabled
- Card border reverts to gray (operation state overrides status color)

### Post-Operation

Card snaps to its new status immediately (color, pill, details update via LiveView push).

## 11. Theme Support

Dark theme is primary. Theme controlled via `data-theme` attribute on `<html>`, with manual toggle. Falls back to `prefers-color-scheme` on first visit.

Dark background: `#0a0a0a`
Card background: `#141414`
Card border: `#1f1f1f`

Light equivalents:
Page background: `#fafafa`
Card background: `#fff`
Card border: `#e5e5e5`

Status colors use the same hue families, adjusted for contrast against each background. Status pills use light tinted backgrounds in both themes.

## 12. Implementation Notes

### Tailwind Mapping

- Cards: flow grid via `flex flex-wrap gap-4 items-start`
- Left border: `border-l-[6px]` with status-dependent color
- Status pills: `rounded-full px-4 text-[20px]` with status-dependent bg/text
- Dark/light: Tailwind's `dark:` variant keyed to `[data-theme=dark]` via `@custom-variant` in app.css

### LiveView Considerations

- Each card is a function component receiving a `%RepoStatus{}` assign
- Card size is determined by content (dirty files, branches) — no explicit size classes
- Banner component derives state from the full list of repo statuses
- All updates via PubSub → LiveView re-render of affected cards only

### Docker Development

All development runs inside Docker containers — no local Elixir/Erlang installation. The container must:
- Volume-mount the project source for live code reload
- Volume-mount `~/src/shred/` (or `REPOMAN_PATH`) so git commands inside the container can read the host's repos
- Expose port 4000 to the host
- Include git in the container image

### What This Spec Does NOT Cover

- Exact Tailwind classes (derive from the design tokens above)
- Animations/transitions beyond opacity change during operations
- Mobile/responsive behavior (localhost tool, desktop only)
- Docker configuration details (Dockerfile, docker-compose.yml)
