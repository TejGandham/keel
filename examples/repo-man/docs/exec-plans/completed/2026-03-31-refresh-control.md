# Refresh Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a header button that cycles auto-refresh intervals (2s/10s/30s/off) with a countdown badge, persisted in localStorage.

**Architecture:** LiveView holds the current interval in assigns and pushes it to all RepoServers via Registry. A JS hook handles localStorage persistence and client-side countdown animation. RepoServer gains a `set_poll_interval` cast to dynamically change its timer.

**Tech Stack:** Elixir/Phoenix LiveView, JS hooks (phoenix-colocated pattern), Tailwind CSS, Mox for testing.

**Spec:** `docs/design-docs/2026-03-31-refresh-control-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `repo_man/lib/repo_man/repo_server.ex` | Add `set_poll_interval/2` client API + cast handler |
| Modify | `repo_man/lib/repo_man_web/live/dashboard_live.ex` | Add `refresh_interval` assign, `cycle_refresh` + `restore_refresh` events, `refresh_button/1` component, reorder header |
| Modify | `repo_man/assets/js/app.js` | Add `RefreshInterval` hook with countdown logic + localStorage |
| Modify | `repo_man/test/repo_man/repo_server_test.exs` | Tests for `set_poll_interval` |
| Modify | `repo_man/test/repo_man_web/live/dashboard_live_test.exs` | Tests for cycle_refresh event + refresh button rendering |

---

### Task 1: RepoServer.set_poll_interval/2

**Files:**
- Modify: `repo_man/lib/repo_man/repo_server.ex`
- Modify: `repo_man/test/repo_man/repo_server_test.exs`

- [ ] **Step 1: Write the failing test for set_poll_interval**

Add to `repo_man/test/repo_man/repo_server_test.exs`, inside a new `describe "set_poll_interval/2"` block:

```elixir
describe "set_poll_interval/2" do
  test "updates poll interval in server state", %{registry: registry} do
    stub_clean_repo()

    pid = start_supervised!({RepoServer, repo_info(registry)})

    RepoServer.set_poll_interval(pid, 10_000)
    # Give the cast time to process
    :sys.get_state(pid)

    # Verify by checking the state directly
    state = :sys.get_state(pid)
    assert state.poll_interval == 10_000
  end

  test "setting interval to 0 stops polling", %{registry: registry} do
    stub_clean_repo()

    pid = start_supervised!({RepoServer, repo_info(registry)})

    RepoServer.set_poll_interval(pid, 0)
    :sys.get_state(pid)

    state = :sys.get_state(pid)
    assert state.poll_interval == 0
  end

  test "setting interval from 0 to non-zero triggers immediate poll and broadcast", %{
    registry: registry,
    pubsub: pubsub
  } do
    # Stub for init read
    stub_clean_repo()

    pid = start_supervised!({RepoServer, repo_info(registry, nil, pubsub)})

    Phoenix.PubSub.subscribe(pubsub, "repos")
    # Drain the init broadcast
    assert_receive {:repo_updated, _}

    # Stub for the immediate poll read (needs new expects since init consumed the first ones)
    RepoMan.Git.Mock
    |> stub(:current_branch, fn _ -> {:ok, "master"} end)
    |> stub(:default_branch, fn _ -> {:ok, "master"} end)
    |> stub(:ahead_behind, fn _, _ -> {:ok, {0, 0}} end)
    |> stub(:dirty_files, fn _ -> {:ok, []} end)
    |> stub(:local_branches, fn _ -> {:ok, []} end)
    |> stub(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

    # Set to 0 first
    RepoServer.set_poll_interval(pid, 0)
    :sys.get_state(pid)

    # Now set to non-zero — should trigger immediate read + broadcast
    RepoServer.set_poll_interval(pid, 10_000)

    # Should receive a broadcast from the immediate poll
    assert_receive {:repo_updated, _}, 500
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `docker compose run --rm app mix test test/repo_man/repo_server_test.exs --only "describe:set_poll_interval/2" 2>&1`

Expected: FAIL — `set_poll_interval/2` is undefined.

- [ ] **Step 3: Implement set_poll_interval**

In `repo_man/lib/repo_man/repo_server.ex`, add client API after `pull/1`:

```elixir
@doc """
Updates the poll interval for this server.

Cancels any pending poll timer. If the new interval is non-zero,
performs an immediate status read and schedules the next poll.
If zero, stops polling entirely.
"""
@spec set_poll_interval(GenServer.server(), non_neg_integer()) :: :ok
def set_poll_interval(server, interval_ms) when is_integer(interval_ms) and interval_ms >= 0 do
  GenServer.cast(server, {:set_poll_interval, interval_ms})
end
```

Add cast handler after the existing `:pull` handlers (before `handle_info`):

```elixir
def handle_cast({:set_poll_interval, interval}, state) do
  # Cancel any pending poll timer
  state = cancel_poll_timer(state)
  state = %{state | poll_interval: interval}

  # If non-zero, do an immediate read + broadcast, then schedule next
  state =
    if interval > 0 and state.task_ref == nil do
      new_status = read_status(state.name, state.path)

      state =
        if new_status != state.status do
          state = %{state | status: new_status}
          broadcast(state)
          state
        else
          state
        end

      schedule_poll(state)
      state
    else
      state
    end

  {:noreply, state}
end
```

Add `cancel_poll_timer/1` private helper and update state to track the timer ref. In `init/1`, capture the timer ref from `schedule_poll`:

First, update `schedule_poll/1` to return a timer ref:

```elixir
defp schedule_poll(%{poll_interval: interval}) when is_integer(interval) and interval > 0 do
  Process.send_after(self(), :poll, interval)
end

defp schedule_poll(_state), do: nil
```

Add `cancel_poll_timer/1`:

```elixir
defp cancel_poll_timer(%{poll_timer: ref} = state) when is_reference(ref) do
  Process.cancel_timer(ref)
  state
end

defp cancel_poll_timer(state), do: state
```

Update `init/1` to store the timer ref:

```elixir
state = %{state | poll_timer: schedule_poll(state)}
```

Add `poll_timer: nil` to the state map in `init/1`.

Update both `handle_info(:poll, ...)` clauses to store the timer ref:

```elixir
def handle_info(:poll, %{task_ref: ref} = state) when ref != nil do
  {:noreply, %{state | poll_timer: schedule_poll(state)}}
end

def handle_info(:poll, state) do
  new_status = read_status(state.name, state.path)

  state =
    if new_status != state.status do
      state = %{state | status: new_status}
      broadcast(state)
      state
    else
      state
    end

  {:noreply, %{state | poll_timer: schedule_poll(state)}}
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `docker compose run --rm app mix test test/repo_man/repo_server_test.exs 2>&1`

Expected: ALL PASS

- [ ] **Step 5: Run full test suite**

Run: `docker compose run --rm app mix test 2>&1`

Expected: ALL PASS (no regressions)

- [ ] **Step 6: Commit**

```bash
git add repo_man/lib/repo_man/repo_server.ex repo_man/test/repo_man/repo_server_test.exs
git commit -m "feat: add RepoServer.set_poll_interval/2 for dynamic interval control"
```

---

### Task 2: LiveView cycle_refresh event + refresh_button component

**Files:**
- Modify: `repo_man/lib/repo_man_web/live/dashboard_live.ex`
- Modify: `repo_man/test/repo_man_web/live/dashboard_live_test.exs`

- [ ] **Step 1: Write failing tests for cycle_refresh and refresh button**

Add to `repo_man/test/repo_man_web/live/dashboard_live_test.exs`:

```elixir
describe "refresh control" do
  test "refresh button renders with default 2s interval", %{conn: conn, test_dir: test_dir} do
    setup_repos(test_dir, ["alpha"])

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "cycle_refresh"
    assert html =~ "2s"
  end

  test "clicking refresh button cycles through intervals", %{conn: conn, test_dir: test_dir} do
    setup_repos(test_dir, ["alpha"])

    {:ok, view, _html} = live(conn, ~p"/")

    # Default is 2000, click cycles to 10000
    html = view |> element("#refresh-btn") |> render_click()
    assert html =~ "10s"

    # Click again: 10000 → 30000
    html = view |> element("#refresh-btn") |> render_click()
    assert html =~ "30s"

    # Click again: 30000 → 0 (off)
    html = view |> element("#refresh-btn") |> render_click()
    assert html =~ "off"

    # Click again: 0 → 2000 (wraps)
    html = view |> element("#refresh-btn") |> render_click()
    assert html =~ "2s"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `docker compose run --rm app mix test test/repo_man_web/live/dashboard_live_test.exs --only "describe:refresh control" 2>&1`

Expected: FAIL — no element with id `refresh-btn`.

- [ ] **Step 3: Implement mount assign, event handler, and component**

In `repo_man/lib/repo_man_web/live/dashboard_live.ex`:

**Mount** — add `:refresh_interval` assign:

```elixir
socket =
  socket
  |> assign(:repos, repos)
  |> assign(:bulk_op, nil)
  |> assign(:bulk_progress, {0, 0})
  |> assign(:banner_state, banner_state)
  |> assign(:banner_count, banner_count)
  |> assign(:refresh_interval, 2_000)
```

**Event handler** — add after existing `handle_event` functions:

```elixir
def handle_event("cycle_refresh", _params, socket) do
  current = socket.assigns.refresh_interval

  next =
    case current do
      2_000 -> 10_000
      10_000 -> 30_000
      30_000 -> 0
      0 -> 2_000
      _ -> 2_000
    end

  # Update all RepoServers
  Enum.each(socket.assigns.repos, fn repo ->
    case Registry.lookup(RepoMan.RepoRegistry, repo.name) do
      [{pid, _}] -> RepoMan.RepoServer.set_poll_interval(pid, next)
      _ -> :ok
    end
  end)

  socket =
    socket
    |> assign(:refresh_interval, next)
    |> push_event("refresh-interval-changed", %{interval: next})

  {:noreply, socket}
end

def handle_event("restore_refresh", %{"interval" => interval}, socket)
    when is_integer(interval) and interval in [0, 2_000, 10_000, 30_000] do
  # Restore interval from localStorage via hook
  Enum.each(socket.assigns.repos, fn repo ->
    case Registry.lookup(RepoMan.RepoRegistry, repo.name) do
      [{pid, _}] -> RepoMan.RepoServer.set_poll_interval(pid, interval)
      _ -> :ok
    end
  end)

  {:noreply, assign(socket, :refresh_interval, interval)}
end

def handle_event("restore_refresh", _params, socket) do
  {:noreply, socket}
end
```

**Render** — update the header in `render/1`. Reorder: Fetch All, Pull All, then refresh button with margin, then theme toggle with margin:

```elixir
<header class="flex justify-between items-center mb-3">
  <h1 class="font-bold text-[32px] text-[#fafafa] dark:text-[#fafafa] text-neutral-900 tracking-tight">
    Repo Man
  </h1>
  <div class="flex items-center gap-4">
    <.fetch_all_button bulk_op={@bulk_op} bulk_progress={@bulk_progress} repos={@repos} />
    <.pull_all_button bulk_op={@bulk_op} bulk_progress={@bulk_progress} repos={@repos} />
    <.refresh_button interval={@refresh_interval} />
    <button
      onclick="toggleTheme()"
      title="Toggle dark/light theme"
      class="ml-4 text-[28px] px-3 py-2 rounded-xl transition-colors text-neutral-400 dark:text-[#525252] hover:text-neutral-600 dark:hover:text-[#a3a3a3]"
    >
      <span class="dark:hidden">☾</span>
      <span class="hidden dark:inline">☀</span>
    </button>
  </div>
</header>
```

**refresh_button/1 component** — add after `pull_all_button`:

```elixir
attr :interval, :integer, required: true

defp refresh_button(assigns) do
  active = assigns.interval > 0

  badge_text =
    case assigns.interval do
      2_000 -> "2s"
      10_000 -> "10s"
      30_000 -> "30s"
      0 -> "off"
      _ -> "?"
    end

  assigns =
    assigns
    |> assign(:active, active)
    |> assign(:badge_text, badge_text)

  ~H"""
  <button
    id="refresh-btn"
    phx-click="cycle_refresh"
    phx-hook="RefreshInterval"
    data-interval={@interval}
    title={"Auto-refresh: #{@badge_text}"}
    class={[
      "ml-4 relative text-[28px] px-3 py-2 rounded-[10px] transition-colors cursor-pointer hover:brightness-125",
      if(@active,
        do: "bg-[#262626] dark:bg-[#262626] bg-[#eff6ff] text-[#60a5fa] dark:text-[#60a5fa] text-[#2563eb] border border-[#1e3a5f] dark:border-[#1e3a5f] border-[#bfdbfe]",
        else: "bg-[#1a1a1a] dark:bg-[#1a1a1a] bg-[#f5f5f5] text-[#404040] dark:text-[#404040] text-[#a3a3a3] border border-[#262626] dark:border-[#262626] border-[#e5e5e5]"
      )
    ]}
  >
    ↻
    <span
      id="refresh-badge"
      class={[
        "absolute -top-1.5 -right-2 text-[14px] font-semibold px-1.5 rounded-md min-w-[18px] text-center",
        if(@active,
          do: "bg-[#172554] dark:bg-[#172554] bg-[#dbeafe] text-[#60a5fa] dark:text-[#60a5fa] text-[#2563eb] border border-[#1e3a5f] dark:border-[#1e3a5f] border-[#bfdbfe]",
          else: "bg-[#262626] dark:bg-[#262626] bg-[#e5e5e5] text-[#525252] dark:text-[#525252] text-[#737373] border border-[#333] dark:border-[#333] border-[#d4d4d4]"
        )
      ]}
    >
      {@badge_text}
    </span>
  </button>
  """
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `docker compose run --rm app mix test test/repo_man_web/live/dashboard_live_test.exs 2>&1`

Expected: ALL PASS

- [ ] **Step 5: Run full test suite**

Run: `docker compose run --rm app mix test 2>&1`

Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add repo_man/lib/repo_man_web/live/dashboard_live.ex repo_man/test/repo_man_web/live/dashboard_live_test.exs
git commit -m "feat: add refresh control button with cycle_refresh event"
```

---

### Task 3: JS hook — localStorage persistence + countdown

**Files:**
- Modify: `repo_man/assets/js/app.js`

- [ ] **Step 1: Add RefreshInterval hook to app.js**

Add before the `window.toggleTheme` function in `repo_man/assets/js/app.js`:

```javascript
// Refresh interval hook: localStorage persistence + countdown badge
const RefreshInterval = {
  mounted() {
    this.countdownTimer = null
    this.remaining = 0

    // Restore from localStorage
    const stored = parseInt(localStorage.getItem("refresh_interval"), 10)
    if ([0, 2000, 10000, 30000].includes(stored)) {
      this.pushEvent("restore_refresh", {interval: stored})
      this.startCountdown(stored)
    } else {
      this.startCountdown(2000)
    }

    // Listen for server-pushed interval changes
    this.handleEvent("refresh-interval-changed", ({interval}) => {
      localStorage.setItem("refresh_interval", interval)
      this.startCountdown(interval)
    })
  },

  updated() {
    const interval = parseInt(this.el.dataset.interval, 10)
    this.startCountdown(interval)
  },

  startCountdown(interval) {
    clearInterval(this.countdownTimer)
    this.countdownTimer = null
    const badge = document.getElementById("refresh-badge")
    if (!badge) return

    if (interval === 0) {
      badge.textContent = "off"
      return
    }

    if (interval < 10000) {
      // 2s: static badge, no countdown
      badge.textContent = (interval / 1000) + "s"
      return
    }

    // 10s, 30s: live countdown
    this.remaining = Math.round(interval / 1000)
    badge.textContent = this.remaining
    this.countdownTimer = setInterval(() => {
      this.remaining--
      if (this.remaining <= 0) this.remaining = Math.round(interval / 1000)
      badge.textContent = this.remaining
    }, 1000)
  },

  destroyed() {
    clearInterval(this.countdownTimer)
  }
}
```

Update the `hooks` object in the LiveSocket constructor to include it:

```javascript
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, RefreshInterval},
})
```

- [ ] **Step 2: Verify manually**

Run: `docker compose up`

Open `http://localhost:4000`. Verify:
1. Refresh button appears after Pull All with blue badge showing `2s`
2. Click cycles: `2s` → `10s` (countdown starts) → `30s` (countdown starts) → `off` (gray) → `2s`
3. Reload page — interval persists from localStorage
4. Theme toggle is at far right

- [ ] **Step 3: Commit**

```bash
git add repo_man/assets/js/app.js
git commit -m "feat: add RefreshInterval JS hook with countdown and localStorage"
```

---

### Task 4: Full integration verification

- [ ] **Step 1: Run full test suite**

Run: `docker compose run --rm app mix test --include integration 2>&1`

Expected: ALL PASS

- [ ] **Step 2: Manual end-to-end test**

Run: `docker compose up`

Test flow:
1. Open `http://localhost:4000`
2. Badge shows `2s` (default, blue, active)
3. Click ↻ → badge shows countdown from `10`
4. Click ↻ → badge shows countdown from `30`
5. Click ↻ → badge shows `off` (gray, inactive)
6. While on `off`, run `touch ~/src/repos/my-project/newfile` from terminal — UI should NOT update
7. Click ↻ → badge shows `2s` — UI should update within 2 seconds showing dirty file
8. Reload page — interval is preserved
9. Verify Fetch All / Pull All still work independently of refresh timer

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "feat: refresh control — UI button with cycling intervals and countdown badge"
```
