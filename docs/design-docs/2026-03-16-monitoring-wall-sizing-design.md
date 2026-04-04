# Monitoring Wall Sizing — Design Spec

**Date:** 2026-03-16
**Status:** Approved
**Depends on:** `docs/design-docs/ui-design.md` (Section 8-9)

---

## 1. Problem

Dashboard typography and card sizing are too small to read comfortably. The current scale (10-16px) was designed for a compact checklist but doesn't suit the monitoring wall use case — glanceable status at a comfortable viewing distance.

## 2. Solution

Uniform 2x scale-up of all typography, spacing, and sizing. The visual hierarchy, color system, layout model, and all Elixir/LiveView logic remain unchanged. This is a purely presentational change.

## 3. Typography Scale

| Element | Before | After | Weight |
|---------|--------|-------|--------|
| Page title | 16px | 32px | 700 |
| Repo name | 13px | 26px | 600 |
| Status pill | 10px | 20px | 400 |
| Detail text (branch, status) | 11px | 22px | 400 |
| Tertiary text (ahead/behind, time) | 10px | 20px | 400 |
| Git data (branches, files, errors) | 10-11px | 20-22px | 400 |
| Open Terminal link | 10px | 20px | 400 |
| Theme toggle button | 14px | 28px | 400 |
| Buttons (card) | 10px | 20px | 400 |
| Buttons (header) | 11px | 22px | 500 |
| Banner headline | 12px | 24px | 500 |
| Banner subtext | 12px | 24px | 400 |
| Summary line | 11px | 22px | 400 |

## 4. Spacing & Sizing

### Cards

| Element | Before | After |
|---------|--------|-------|
| Card padding | 10px 12px | 20px 24px |
| Card border-radius | 8px | 16px |
| Card left border | 3px | 6px |
| Card gap (grid) | 8px | 16px |
| Card min-width (clean) | 155px | 310px |
| Card min-width (with details) | 200px | 400px |
| Card min-width (with file list) | 220px | 440px |

### Card Internal Spacing

| Element | Before | After |
|---------|--------|-------|
| Name + pill row gap | 8px | 16px |
| Name row margin-bottom | 4px | 8px |
| Tertiary text margin-top | 2px | 4px |
| Divider section margin-top + padding-top | 8px + 8px | 16px + 16px |
| Action row margin-top | 8px | 16px |
| Action button gap | 6px | 12px |
| Branch name wrap gap | 4px | 8px |
| "+N more" truncation margin-top | 4px | 8px |

### Banner & Summary

| Element | Before | After |
|---------|--------|-------|
| Banner padding | 8px 12px | 16px 24px |
| Banner border-radius | 6px | 12px |
| Banner internal gap | 8px | 16px |
| Banner margin-bottom | 8px | 16px |
| Summary line margin-bottom | 12px | 24px |

### Header

| Element | Before | After |
|---------|--------|-------|
| Header margin-bottom | 6px | 12px |
| Header button group gap | 8px | 16px |
| Theme toggle padding | 4px 6px | 8px 12px |
| Theme toggle border-radius | 6px | 12px |

### Buttons

| Element | Before | After |
|---------|--------|-------|
| Button padding (card) | 2px 10px | 4px 20px |
| Button padding (header) | 5px 14px | 10px 28px |
| Button border-radius (card) | 5px | 10px |
| Button border-radius (header) | 6px | 12px |

### Page

| Element | Before | After |
|---------|--------|-------|
| Page padding | 20px | 40px |
| Pill horizontal padding | 8px | 16px |

## 5. What Stays the Same

- All colors, borders, status color mapping
- Layout model (`flex flex-wrap`)
- Dark/light theme toggle functionality
- Component hierarchy and card dispatch logic (including fallback card)
- All Elixir/LiveView business logic
- PubSub, event handlers, bulk operations
- Pill shape (`rounded-full` — stays pill-shaped at any size)
- Spin animation for in-progress spinners

## 6. Files Changed

1. **`repo_man/lib/repo_man_web/live/dashboard_live.ex`** — All Tailwind size/spacing classes in render functions and all component functions (clean_card, behind_card, topic_card, dirty_card, diverged_card, error_card, in_progress_card, fallback card, fetch_button, pull_button, fetch_all_button, pull_all_button, open_terminal_link, freshness_banner variants, summary_line, theme toggle)
2. **`docs/design-docs/ui-design.md`** — Update typography (Section 8) and spacing (Section 9) tables to reflect new sizes

## 7. Testing Strategy

- Existing LiveView tests continue to pass (they test structure/content, not sizing)
- Visual verification at localhost:4000 after implementation
- Confirm both dark and light themes render correctly at new sizes
