# Monitoring Wall Sizing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 2x scale-up of all typography, spacing, and sizing in the dashboard for monitoring wall readability.

**Architecture:** Purely presentational Tailwind class changes in one file (`dashboard_live.ex`) plus doc updates to `ui-design.md`. No logic changes. No new files. No new tests.

**Tech Stack:** Elixir/Phoenix LiveView, Tailwind CSS 4.1

**Spec:** `docs/design-docs/2026-03-16-monitoring-wall-sizing-design.md`

---

## Chunk 1: Implementation

### Task 1: Scale Page Layout, Header, and Theme Toggle

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:194-229`

The `render/1` function contains the page wrapper, header, and repo grid. Apply 2x to all sizing classes.

- [ ] **Step 1: Scale page wrapper and repo grid**

In `render/1`, change:
```
p-5 → p-10
```
```
gap-2 (repo grid, line 225) → gap-4
```

- [ ] **Step 2: Scale header**

```
mb-1.5 → mb-3
text-[16px] → text-[32px]
gap-2 (header button group, line 205) → gap-4
```

- [ ] **Step 3: Scale theme toggle button**

```
text-[14px] → text-[28px]
px-1.5 → px-3
py-1 → py-2
rounded-md → rounded-xl
```

- [ ] **Step 4: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 2: Scale Freshness Banners

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:283-349`

All 4 banner variants (`:current`, `:behind`, `:warning`, `:error`) share the same sizing pattern. Apply identical changes to each.

- [ ] **Step 1: Scale all 4 banner wrappers**

Each banner `<div>` (lines 287, 304, 321, 338):
```
px-3 → px-6
py-2 → py-4
mb-2 → mb-4
rounded-md → rounded-xl
gap-2 → gap-4
```

- [ ] **Step 2: Scale all banner text**

Each banner has 3 `<span>` elements. In all 4 variants:
```
text-[12px] → text-[24px]
```
(This appears on the icon span, headline span, and subtext span — all become 24px.)

- [ ] **Step 3: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 3: Scale Summary Line

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:390-403`

- [ ] **Step 1: Scale summary line**

```
text-[11px] → text-[22px]
mb-3 → mb-6
```

- [ ] **Step 2: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 4: Scale Header Buttons (Fetch All / Pull All)

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:429-491`

Both `fetch_all_button/1` and `pull_all_button/1` share the same sizing pattern.

- [ ] **Step 1: Scale both header button components**

In both buttons (lines 435 and 475):
```
text-[11px] → text-[22px]
px-3.5 → px-7
py-1.5 → py-3
rounded-md → rounded-xl
```

- [ ] **Step 2: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 5: Scale Fallback Card and Clean Card

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:543-594`

- [ ] **Step 1: Scale fallback card (lines 543-562)**

Card wrapper:
```
border-l-[3px] → border-l-[6px]
rounded-lg → rounded-2xl
px-3 → px-6
py-2.5 → py-5
min-w-[155px] → min-w-[310px]
```

Repo name:
```
text-[13px] → text-[26px]
mb-1 → mb-2
```

Detail text:
```
text-[11px] → text-[22px]
```

- [ ] **Step 2: Scale clean card (lines 569-594)**

Card wrapper — same pattern as fallback:
```
border-l-[3px] → border-l-[6px]
rounded-lg → rounded-2xl
px-3 → px-6
py-2.5 → py-5
min-w-[155px] → min-w-[310px]
```

Repo name:
```
text-[13px] → text-[26px]
mb-1 → mb-2
```

Detail text:
```
text-[11px] → text-[22px]
```

Tertiary row:
```
mt-0.5 → mt-1
text-[10px] → text-[20px]
```

- [ ] **Step 3: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 6: Scale Behind Card

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:619-683`

- [ ] **Step 1: Scale behind card wrapper**

```
border-l-[3px] → border-l-[6px]
rounded-lg → rounded-2xl
px-3 → px-6
py-2.5 → py-5
min-w-[200px] → min-w-[400px]
```

- [ ] **Step 2: Scale behind card internal elements**

Name + pill row:
```
gap-2 → gap-4
mb-1 → mb-2
text-[13px] → text-[26px]
```

Status pill:
```
px-2 → px-4
text-[10px] → text-[20px]
```

Detail text:
```
text-[11px] → text-[22px]
```

Tertiary text:
```
text-[10px] → text-[20px]
mt-0.5 → mt-1
```

Branch list divider:
```
mt-2 → mt-4
pt-2 → pt-4
```

Branch wrap gap:
```
gap-1 → gap-2
```

Branch names:
```
text-[10px] → text-[20px]
```

"+N more" text:
```
text-[10px] → text-[20px]
mt-1 → mt-2
```

Action row:
```
mt-2 → mt-4
gap-1.5 → gap-3
```

- [ ] **Step 3: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 7: Scale Topic Card

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:691-743`

- [ ] **Step 1: Scale topic card**

Card wrapper:
```
border-l-[3px] → border-l-[6px]
rounded-lg → rounded-2xl
px-3 → px-6
py-2.5 → py-5
min-w-[200px] → min-w-[400px]
```

Name + pill row:
```
gap-2 → gap-4
mb-1 → mb-2
text-[13px] → text-[26px]
px-2 → px-4  (pill)
text-[10px] → text-[20px]  (pill)
```

Branch name (amber):
```
text-[11px] → text-[22px]
```

Tertiary text:
```
text-[10px] → text-[20px]
mt-0.5 → mt-1
```

Pull-blocked divider:
```
mt-2 → mt-4
pt-2 → pt-4
text-[10px] → text-[20px]
```

Action row:
```
mt-2 → mt-4
gap-1.5 → gap-3
```

- [ ] **Step 2: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 8: Scale Dirty Card

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:752-825`

- [ ] **Step 1: Scale dirty card**

Card wrapper:
```
border-l-[3px] → border-l-[6px]
rounded-lg → rounded-2xl
px-3 → px-6
py-2.5 → py-5
min-w-[220px] → min-w-[440px]
```

Name + pill row:
```
gap-2 → gap-4
mb-1 → mb-2
text-[13px] → text-[26px]
px-2 → px-4  (pill)
text-[10px] → text-[20px]  (pill)
```

Detail text:
```
text-[11px] → text-[22px]
```

Tertiary text:
```
text-[10px] → text-[20px]
mt-0.5 → mt-1
```

Dirty file list divider:
```
mt-2 → mt-4
pt-2 → pt-4
```

File entries:
```
text-[10px] → text-[20px]
```

"+N more":
```
text-[10px] → text-[20px]
mt-1 → mt-2
```

Pull-blocked divider:
```
mt-2 → mt-4
pt-2 → pt-4
text-[10px] → text-[20px]
```

Action row:
```
mt-2 → mt-4
gap-1.5 → gap-3
```

- [ ] **Step 2: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 9: Scale Diverged, Error, and In-Progress Cards

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:833-998`

- [ ] **Step 1: Scale diverged card (lines 833-880)**

Card wrapper:
```
border-l-[3px] → border-l-[6px]
rounded-lg → rounded-2xl
px-3 → px-6
py-2.5 → py-5
min-w-[200px] → min-w-[400px]
```

Name + pill row: `gap-2→gap-4`, `mb-1→mb-2`, `text-[13px]→text-[26px]`, pill `px-2→px-4`, `text-[10px]→text-[20px]`
Detail: `text-[11px]→text-[22px]`
Tertiary: `text-[10px]→text-[20px]`, `mt-0.5→mt-1`
Divider: `mt-2→mt-4`, `pt-2→pt-4`, `text-[10px]→text-[20px]`
Action row: `mt-2→mt-4`, `gap-1.5→gap-3`

- [ ] **Step 2: Scale error card (lines 887-939)**

Same card wrapper pattern as diverged.
Same name + pill, detail, tertiary pattern.

Error message text:
```
text-[10px] → text-[20px]
```

Retry button:
```
text-[10px] → text-[20px]
px-2.5 → px-5
py-0.5 → py-1
rounded-[5px] → rounded-[10px]
```

Divider and action row: same pattern.

- [ ] **Step 3: Scale in-progress card (lines 947-998)**

Same card wrapper pattern (but `min-w-[200px]→min-w-[400px]`).
Same name + pill, detail, tertiary, action row patterns.

- [ ] **Step 4: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 10: Scale Reusable Button Components and Open Terminal Link

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex:1009-1086`

- [ ] **Step 1: Scale fetch_button (lines 1009-1031)**

```
text-[10px] → text-[20px]
px-2.5 → px-5
py-0.5 → py-1
rounded-[5px] → rounded-[10px]
```

- [ ] **Step 2: Scale pull_button (lines 1035-1067)**

Same sizing pattern as fetch_button:
```
text-[10px] → text-[20px]
px-2.5 → px-5
py-0.5 → py-1
rounded-[5px] → rounded-[10px]
```

- [ ] **Step 3: Scale open_terminal_link (lines 1076-1086)**

```
text-[10px] → text-[20px]
```

- [ ] **Step 4: Verify compilation**

Run: `docker compose run --rm app mix compile --warnings-as-errors`
Expected: Compilation success

---

### Task 11: Run Full Test Suite

**Files:**
- Test: `repo_man/test/` (all existing tests)

- [ ] **Step 1: Run full test suite**

Run: `docker compose run --rm app mix test`
Expected: All tests pass. No sizing-related assertions in existing tests.

- [ ] **Step 2: Visual verification**

Open `http://localhost:4000` in browser. Verify:
- All text is ~2x larger
- Cards have proportionally larger padding and borders
- Banner is larger with more padding
- Both dark and light themes render correctly (use toggle button)
- Fetch All / Pull All buttons are larger
- Card buttons (Fetch, Pull, Retry) are larger
- Theme toggle icon is larger

---

## Chunk 2: Documentation

### Task 12: Update ui-design.md Typography and Spacing Tables

**Files:**
- Modify: `docs/design-docs/ui-design.md:248-270` (Section 8: Typography, Section 9: Spacing)

- [ ] **Step 1: Update Section 8 (Typography) table**

Replace all size values with new 2x values:
```
16px → 32px (Page title)
13px → 26px (Repo name)
10px → 20px (Status pill)
11px → 22px (Detail text)
10px → 20px (Tertiary text)
10-11px → 20-22px (Git data)
12px → 24px (Banner headline)
10-11px → 20-22px (Buttons)
```

- [ ] **Step 2: Update Section 9 (Spacing & Sizing) table**

Replace all spacing values with new 2x values:
```
10px 12px → 20px 24px (Card padding)
8px → 16px (Card border-radius)
3px → 6px (Card left border)
8px → 16px (Card gap)
155px → 310px (Card min-width clean)
200px → 400px (Card min-width details)
220px → 440px (Card min-width file list)
8px 12px → 16px 24px (Banner padding)
6px → 12px (Banner border-radius)
2px 10px → 4px 20px (Button padding card)
5px 14px → 10px 28px (Button padding header)
5px → 10px (Button border-radius card)
6px → 12px (Button border-radius header)
```

- [ ] **Step 3: Commit all changes**

```bash
git add repo_man/lib/repo_man_web/live/dashboard_live.ex docs/design-docs/ui-design.md
git commit -m "feat: 2x monitoring wall sizing for dashboard readability"
```
