# Refresh Control Design

**Date:** 2026-03-31
**Status:** Draft
**Depends on:** Existing poll infrastructure in `RepoServer`, F28 dark/light theme

---

## 1. Purpose

Give the user control over how frequently the dashboard re-reads git status from the filesystem. A single icon button in the header cycles through auto-refresh intervals or turns polling off entirely. When off, the UI only updates in response to user-initiated actions (Fetch, Pull, Fetch All, Pull All).

## 2. Interaction

### Click Cycle

Each click advances to the next state:

```
2s → 10s → 30s → off → 2s → ...
```

Default on page load: **2s** (current behavior preserved).

### Persistence

The selected interval is stored in `localStorage` (same pattern as theme toggle). On mount, LiveView reads the stored value via a `phx-hook` and applies it.

## 3. UI Specification

### Placement

In the header, after Pull All with extra left margin. Theme toggle moved to far right with its own left margin:

```
Repo Man                    [Fetch All] [Pull All]  ··  [↻ badge]  ··  [☾/☀]
```

- Gap between Pull All and refresh button: `margin-left: 16px` (visual separation from action buttons)
- Gap between refresh button and theme toggle: `margin-left: 16px` (theme toggle anchored to far right)

### Anatomy

A rounded button containing the `↻` character. A small badge is positioned at the top-right corner showing either a live countdown (`1`, `2`, ... counting down to next refresh) or `off`.

- Button padding: `7px 11px`
- Button border-radius: `10px`
- Icon font-size: `28px` (matches theme toggle sizing)
- Badge font-size: `14px`, font-weight: `600`
- Badge padding: `1px 5px`
- Badge border-radius: `6px`
- Badge position: absolute, `top: -6px; right: -8px`

### Countdown Badge

Badge behavior depends on the interval:

- **2s** — static badge showing `2s`. No countdown (flipping between 1 and 2 is distracting, not useful).
- **10s** — live countdown: `10`, `9`, `8`, ... `1`, poll fires, resets to `10`.
- **30s** — live countdown: `30`, `29`, `28`, ... `1`, poll fires, resets to `30`.
- **off** — static badge showing `off`.

The countdown makes the 10s/30s modes visually distinct from Fetch All / Pull All — it's clearly a timer, not an action button.

The countdown is driven client-side by a `setInterval` in the `RefreshInterval` hook (1-second tick). The hook tracks the selected interval and seconds remaining. On each tick it updates the badge text (only when interval >= 10s). When the countdown reaches 0, it resets to the full interval (the actual poll is server-side via `RepoServer`).

### Visual Distinction from Fetch/Pull

The refresh button is visually separated from the action buttons by:
1. **Position** — placed left of the theme toggle, away from Fetch All / Pull All
2. **Animated countdown** — the ticking number makes it clearly a status indicator, not an action
3. **Blue tint when active** — but uses a border (action buttons have no border), creating a different visual weight
4. **No text label** — icon-only with badge, unlike the text-labeled Fetch All / Pull All

### Colors

#### Active states (2s, 10s, 30s)

| Element | Dark | Light |
|---------|------|-------|
| Button background | `#262626` | `#eff6ff` |
| Button border | `1px solid #1e3a5f` | `1px solid #bfdbfe` |
| Icon color | `#60a5fa` | `#2563eb` |
| Badge background | `#172554` | `#dbeafe` |
| Badge border | `1px solid #1e3a5f` | `1px solid #bfdbfe` |
| Badge text | `#60a5fa` | `#2563eb` |

#### Off state

| Element | Dark | Light |
|---------|------|-------|
| Button background | `#1a1a1a` | `#f5f5f5` |
| Button border | `1px solid #262626` | `1px solid #e5e5e5` |
| Icon color | `#404040` | `#a3a3a3` |
| Badge background | `#262626` | `#e5e5e5` |
| Badge border | `1px solid #333` | `1px solid #d4d4d4` |
| Badge text | `#525252` | `#737373` |

These use the same blue family as Pull All and behind-card pills (active) and the same neutral family as Fetch All (off).

### Hover

Subtle `brightness-125` on hover (same as existing buttons). No hover effect change needed between active/off.

## 4. Backend

### RepoServer Changes

`RepoServer` already has `poll_interval` in state and `schedule_poll/1`. Add:

- **`:set_poll_interval` cast** — updates the interval in server state, cancels any pending timer. If the new interval is non-zero: performs an immediate status read (broadcast if changed), then schedules the next poll. If zero: stops polling.
- **Client function `set_poll_interval/2`** — `GenServer.cast(server, {:set_poll_interval, ms})`.

### LiveView Changes

- **New assign:** `:refresh_interval` — one of `2000`, `10000`, `30000`, or `0`. Default `2000`.
- **New event handler:** `"cycle_refresh"` — advances to the next interval in the cycle, updates the assign, and broadcasts `{:set_poll_interval, new_interval}` to all RepoServers via Registry.
- **Hook for persistence:** A `RefreshInterval` hook reads/writes `localStorage["refresh_interval"]`. On mount, pushes the stored value to the server. On update, writes the new value to storage.
- **Render:** The `refresh_button/1` component reads `@refresh_interval` to determine icon color and badge text.

### Interval Mapping

| Badge | Milliseconds | Next on click |
|-------|-------------|---------------|
| `2s` (static) | `2000` | `10000` |
| Countdown from `10` | `10000` | `30000` |
| Countdown from `30` | `30000` | `0` |
| `off` (static) | `0` | `2000` |

When the user clicks to change interval, the countdown resets to the new interval's starting value (or becomes static for 2s/off).

## 5. Data Flow

```
User clicks ↻ button
  → LiveView "cycle_refresh" event
  → LiveView updates @refresh_interval assign
  → LiveView iterates all repos, sends :set_poll_interval to each RepoServer
  → Each RepoServer cancels pending timer, schedules new poll (or stops)
  → LiveView pushes new interval to RefreshInterval hook
  → Hook writes to localStorage
  → UI re-renders with new badge text/colors
```

On page load:
```
LiveView mounts
  → RefreshInterval hook reads localStorage
  → Hook pushes stored interval (or default 2000) to server
  → LiveView handle_event sets @refresh_interval
  → LiveView sends :set_poll_interval to all RepoServers
```

## 6. Testing

- **Unit:** `cycle_refresh` event handler advances through the 4 states correctly and wraps around.
- **Unit:** `refresh_button/1` renders correct badge text and CSS classes for each interval.
- **Unit:** `RepoServer.set_poll_interval/2` updates state and reschedules timer.
- **Integration:** Changing interval to 0 stops polling; changing from 0 to 2000 resumes.
