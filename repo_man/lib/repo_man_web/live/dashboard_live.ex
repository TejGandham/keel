defmodule RepoManWeb.DashboardLive do
  @moduledoc """
  Single LiveView page for the Repo Man dashboard.

  Mounts by loading all repo statuses from `RepoSupervisor.all_statuses/1`,
  subscribes to PubSub "repos" topic for real-time updates, and assigns
  the repo list plus bulk operation state to the socket.

  ## Card Components

  Cards are rendered via `repo_card/1` which dispatches to the appropriate
  card type in `RepoManWeb.RepoCard` based on `repo.severity`.

  ## Domain Logic

  Banner computation, summary counts, and time formatting live in
  `RepoMan.Dashboard`.

  ## F25-F28 Features

  - F25: Freshness banner — `freshness_banner/1` shows the worst-case
    status across all repos. Holds previous state during in-progress ops.
  - F26: Summary line — `summary_line/1` with `Dashboard.summary_counts/1`.
    Shows repo path, count breakdowns, and bulk op progress.
  - F27: Fetch All / Pull All — event handlers for bulk operations with
    progress tracking via `{done, total}` tuples.
  - F28: Dark-first theme — `data-theme` attribute with manual toggle, localStorage persistence.
  """

  use RepoManWeb, :live_view

  alias RepoMan.Dashboard
  alias RepoMan.RepoServer
  alias RepoMan.RepoSupervisor

  import RepoManWeb.RepoCard

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RepoMan.PubSub, "repos")
    end

    repos = RepoSupervisor.all_statuses()
    {banner_state, banner_count} = Dashboard.banner(repos)

    socket =
      socket
      |> assign(:repos, repos)
      |> assign(:bulk_op, nil)
      |> assign(:bulk_progress, {0, 0})
      |> assign(:banner_state, banner_state)
      |> assign(:banner_count, banner_count)
      |> assign(:refresh_interval, 2_000)

    {:ok, socket}
  end

  # ── Event Handlers (F27) ──────────────────────────────────────────────

  @impl true
  def handle_event("fetch", %{"repo" => name}, socket) do
    RepoSupervisor.dispatch(name, &RepoServer.fetch/1)
    {:noreply, socket}
  end

  def handle_event("pull", %{"repo" => name}, socket) do
    RepoSupervisor.dispatch(name, &RepoServer.pull/1)
    {:noreply, socket}
  end

  def handle_event("retry", %{"repo" => name}, socket) do
    RepoSupervisor.dispatch(name, &RepoServer.fetch/1)
    {:noreply, socket}
  end

  def handle_event("fetch_all", _params, socket) do
    repos = socket.assigns.repos
    total = length(repos)

    if total > 0 and socket.assigns.bulk_op == nil do
      repo_names = Enum.map(repos, & &1.name)
      RepoSupervisor.dispatch_all(repo_names, &RepoServer.fetch/1)

      socket =
        socket
        |> assign(:bulk_op, :fetching)
        |> assign(:bulk_progress, {0, total})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("pull_all", _params, socket) do
    repos = socket.assigns.repos
    eligible = Enum.filter(repos, & &1.pull_eligible?)
    total = length(eligible)

    if total > 0 and socket.assigns.bulk_op == nil do
      eligible_names = Enum.map(eligible, & &1.name)
      RepoSupervisor.dispatch_all(eligible_names, &RepoServer.pull/1)

      socket =
        socket
        |> assign(:bulk_op, :pulling)
        |> assign(:bulk_progress, {0, total})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

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
    repo_names = Enum.map(socket.assigns.repos, & &1.name)
    RepoSupervisor.dispatch_all(repo_names, &RepoServer.set_poll_interval(&1, next))

    socket =
      socket
      |> assign(:refresh_interval, next)
      |> push_event("refresh-interval-changed", %{interval: next})

    {:noreply, socket}
  end

  def handle_event("restore_refresh", %{"interval" => interval}, socket)
      when is_integer(interval) and interval in [0, 2_000, 10_000, 30_000] do
    repo_names = Enum.map(socket.assigns.repos, & &1.name)
    RepoSupervisor.dispatch_all(repo_names, &RepoServer.set_poll_interval(&1, interval))

    {:noreply, assign(socket, :refresh_interval, interval)}
  end

  def handle_event("restore_refresh", _params, socket) do
    {:noreply, socket}
  end

  # ── PubSub Handlers ──────────────────────────────────────────────────

  @impl true
  def handle_info({:repo_updated, updated_status}, socket) do
    repos =
      socket.assigns.repos
      |> Enum.map(fn repo ->
        if repo.name == updated_status.name, do: updated_status, else: repo
      end)

    socket = assign(socket, :repos, repos)

    # Update bulk operation progress (F27)
    socket = update_bulk_progress(socket, repos)

    # Update banner state — only when no in-progress repos (F25: hold during ops)
    in_progress_count = Enum.count(repos, &(&1.operation in [:fetching, :pulling]))

    socket =
      if in_progress_count == 0 do
        {banner_state, banner_count} = Dashboard.banner(repos)

        socket
        |> assign(:banner_state, banner_state)
        |> assign(:banner_count, banner_count)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # ── Bulk Progress Tracking (F27) ─────────────────────────────────────

  defp update_bulk_progress(socket, repos) do
    case socket.assigns.bulk_op do
      nil ->
        socket

      _op ->
        {_done, total} = socket.assigns.bulk_progress
        in_progress_count = Enum.count(repos, &(&1.operation in [:fetching, :pulling]))

        done = total - min(in_progress_count, total)

        if done >= total do
          # Bulk operation complete
          socket
          |> assign(:bulk_op, nil)
          |> assign(:bulk_progress, {0, 0})
        else
          assign(socket, :bulk_progress, {done, total})
        end
    end
  end

  # ── Render ───────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="dashboard"
      class="min-h-screen bg-[#0a0a0a] dark:bg-[#0a0a0a] bg-[#fafafa] p-10 font-[-apple-system,'Inter',sans-serif]"
    >
      <%!-- F26: Header with Fetch All / Pull All buttons (F27) --%>
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

      <%!-- F25: Freshness banner --%>
      <.freshness_banner state={@banner_state} count={@banner_count} />

      <%!-- F26: Summary line --%>
      <.summary_line repos={@repos} bulk_op={@bulk_op} bulk_progress={@bulk_progress} />

      <div id="repo-grid" class="flex flex-wrap gap-4 items-start">
        <.repo_card :for={repo <- @repos} repo={repo} />
      </div>
    </div>
    """
  end

  # ── Freshness Banner (F25) ──────────────────────────────────────────

  attr :state, :atom, required: true
  attr :count, :integer, required: true

  defp freshness_banner(%{state: :current} = assigns) do
    ~H"""
    <div
      id="freshness-banner"
      class="rounded-xl px-6 py-4 mb-4 bg-[#111714] dark:bg-[#111714] bg-[#ecfdf5] flex items-center gap-4"
    >
      <span class="text-[#86efac] dark:text-[#86efac] text-[#22c55e] text-[24px]">✓</span>
      <span class="text-[24px] font-medium text-[#86efac] dark:text-[#86efac] text-[#22c55e]">
        All repos current
      </span>
      <span class="text-[24px] text-[#4b5563] dark:text-[#4b5563] text-[#6b7280]">
        — ready for design work
      </span>
    </div>
    """
  end

  defp freshness_banner(%{state: :behind} = assigns) do
    ~H"""
    <div
      id="freshness-banner"
      class="rounded-xl px-6 py-4 mb-4 bg-[#1c1917] dark:bg-[#1c1917] bg-[#fffbeb] flex items-center gap-4"
    >
      <span class="text-[#fbbf24] dark:text-[#fbbf24] text-[#f59e0b] text-[24px]">⚠</span>
      <span class="text-[24px] font-medium text-[#fbbf24] dark:text-[#fbbf24] text-[#f59e0b]">
        {@count} {if @count == 1, do: "repo", else: "repos"} behind origin
      </span>
      <span class="text-[24px] text-[#92400e] dark:text-[#92400e] text-[#92400e]">
        — designs may be stale
      </span>
    </div>
    """
  end

  defp freshness_banner(%{state: :warning} = assigns) do
    ~H"""
    <div
      id="freshness-banner"
      class="rounded-xl px-6 py-4 mb-4 bg-[#1c1917] dark:bg-[#1c1917] bg-[#fffbeb] flex items-center gap-4"
    >
      <span class="text-[#fbbf24] dark:text-[#fbbf24] text-[#f59e0b] text-[24px]">⚠</span>
      <span class="text-[24px] font-medium text-[#fbbf24] dark:text-[#fbbf24] text-[#f59e0b]">
        {@count} {if @count == 1, do: "repo needs", else: "repos need"} attention
      </span>
      <span class="text-[24px] text-[#92400e] dark:text-[#92400e] text-[#92400e]">
        — dirty or on topic branch
      </span>
    </div>
    """
  end

  defp freshness_banner(%{state: :error} = assigns) do
    ~H"""
    <div
      id="freshness-banner"
      class="rounded-xl px-6 py-4 mb-4 bg-[#1a0a0a] dark:bg-[#1a0a0a] bg-[#fef2f2] flex items-center gap-4"
    >
      <span class="text-[#f87171] dark:text-[#f87171] text-[#ef4444] text-[24px]">✗</span>
      <span class="text-[24px] font-medium text-[#f87171] dark:text-[#f87171] text-[#ef4444]">
        {@count} {if @count == 1, do: "repo needs", else: "repos need"} attention
      </span>
      <span class="text-[24px] text-[#7f1d1d] dark:text-[#7f1d1d] text-[#991b1b]">
        — diverged or errored
      </span>
    </div>
    """
  end

  # ── Summary Line (F26) ──────────────────────────────────────────────

  attr :repos, :list, required: true
  attr :bulk_op, :atom, required: true
  attr :bulk_progress, :any, required: true

  defp summary_line(assigns) do
    counts = Dashboard.summary_counts(assigns.repos)
    repos_path = Application.get_env(:repo_man, :repos_path, "~/src/shred")
    host_repos_path = Application.get_env(:repo_man, :host_repos_path, repos_path)
    assigns = assign(assigns, :counts, counts)
    assigns = assign(assigns, :repos_path, repos_path)
    assigns = assign(assigns, :host_repos_path, host_repos_path)

    ~H"""
    <p id="summary-line" class="text-[22px] text-[#525252] dark:text-[#525252] text-neutral-500 mb-6">
      <button
        phx-click={
          Phoenix.LiveView.JS.dispatch("phx:open-terminal", detail: %{path: @host_repos_path})
        }
        title={"Open Terminal — #{@host_repos_path}"}
        class="inline text-inherit hover:text-[#a3a3a3] dark:hover:text-[#a3a3a3] hover:text-neutral-600 transition-colors cursor-pointer bg-transparent border-none p-0 font-inherit text-[length:inherit] outline-none focus:outline-none active:text-inherit"
      >
        {@repos_path} ↗
      </button>
      · {@counts.total} {if @counts.total == 1, do: "repo", else: "repos"} · {@counts.synced} synced
      · {@counts.behind} behind
      · {@counts.dirty} dirty
      · {@counts.topic} topic
      · {@counts.diverged} diverged
      · {@counts.errored} errored
      <span :if={@bulk_op != nil} class="text-[#a3a3a3] dark:text-[#a3a3a3] text-neutral-600">
        · {Dashboard.bulk_progress_text(@bulk_op, @bulk_progress)}
      </span>
    </p>
    """
  end

  # ── Fetch All / Pull All Buttons (F27) ──────────────────────────────

  attr :bulk_op, :atom, required: true
  attr :bulk_progress, :any, required: true
  attr :repos, :list, required: true

  defp fetch_all_button(assigns) do
    disabled = assigns.bulk_op != nil
    {done, total} = assigns.bulk_progress

    label =
      if assigns.bulk_op == :fetching do
        "Fetching #{done}/#{total}…"
      else
        "Fetch All"
      end

    assigns = assign(assigns, :disabled, disabled)
    assigns = assign(assigns, :label, label)

    ~H"""
    <button
      id="fetch-all-btn"
      phx-click="fetch_all"
      disabled={@disabled}
      class={[
        "text-[22px] px-7 py-3 rounded-xl transition-colors font-medium",
        if(@disabled,
          do:
            "bg-[#1f1f1f] dark:bg-[#1f1f1f] bg-[#f5f5f5] text-[#404040] dark:text-[#404040] text-neutral-400 cursor-not-allowed",
          else:
            "bg-[#262626] dark:bg-[#262626] bg-[#f5f5f5] text-[#a3a3a3] dark:text-[#a3a3a3] text-neutral-600 hover:brightness-125"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  attr :bulk_op, :atom, required: true
  attr :bulk_progress, :any, required: true
  attr :repos, :list, required: true

  defp pull_all_button(assigns) do
    has_pullable = Enum.any?(assigns.repos, & &1.pull_eligible?)
    disabled = assigns.bulk_op != nil or not has_pullable
    {done, total} = assigns.bulk_progress

    label =
      if assigns.bulk_op == :pulling do
        "Pulling #{done}/#{total}…"
      else
        "Pull All"
      end

    assigns = assign(assigns, :disabled, disabled)
    assigns = assign(assigns, :label, label)
    assigns = assign(assigns, :has_pullable, has_pullable)

    ~H"""
    <button
      id="pull-all-btn"
      phx-click="pull_all"
      disabled={@disabled}
      class={[
        "text-[22px] px-7 py-3 rounded-xl transition-colors font-medium",
        cond do
          @disabled ->
            "bg-[#1f1f1f] dark:bg-[#1f1f1f] bg-[#f5f5f5] text-[#404040] dark:text-[#404040] text-neutral-400 cursor-not-allowed"

          @has_pullable ->
            "bg-[#172554] dark:bg-[#172554] bg-[#eff6ff] text-[#60a5fa] dark:text-[#60a5fa] text-[#2563eb] hover:brightness-125"

          true ->
            "bg-[#262626] dark:bg-[#262626] bg-[#f5f5f5] text-[#a3a3a3] dark:text-[#a3a3a3] text-neutral-600 hover:brightness-125"
        end
      ]}
    >
      {@label}
    </button>
    """
  end

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

  # ── Card Dispatcher ──────────────────────────────────────────────────
  #
  # Routes to the correct card component in RepoManWeb.RepoCard based on
  # operation and severity. Operation-based dispatching (in-progress, error)
  # takes priority over severity, since a repo mid-fetch should show the
  # in-progress card regardless of its underlying severity.

  attr :repo, RepoMan.RepoStatus, required: true

  # F24: In-progress — operation overrides severity for display
  defp repo_card(%{repo: %{operation: op}} = assigns) when op in [:fetching, :pulling] do
    in_progress_card(assigns)
  end

  # F23: Error by operation (e.g. failed fetch/pull)
  defp repo_card(%{repo: %{operation: :error}} = assigns) do
    error_card(assigns)
  end

  # F18: Clean
  defp repo_card(%{repo: %{severity: :clean}} = assigns) do
    clean_card(assigns)
  end

  # F19: Behind
  defp repo_card(%{repo: %{severity: :behind}} = assigns) do
    behind_card(assigns)
  end

  # F20: Topic branch
  defp repo_card(%{repo: %{severity: :topic_branch}} = assigns) do
    topic_card(assigns)
  end

  # F21: Dirty
  defp repo_card(%{repo: %{severity: :dirty}} = assigns) do
    dirty_card(assigns)
  end

  # F22: Diverged
  defp repo_card(%{repo: %{severity: :diverged}} = assigns) do
    diverged_card(assigns)
  end

  # F23: Error by severity
  defp repo_card(%{repo: %{severity: :error}} = assigns) do
    error_card(assigns)
  end

  # Fallback
  defp repo_card(assigns) do
    ~H"""
    <div
      id={"repo-#{@repo.name}"}
      class="
      bg-[#141414] dark:bg-[#141414] bg-white
      border border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5]
      border-l-[6px] border-l-[#737373] dark:border-l-[#737373] border-l-[#a3a3a3]
      rounded-2xl px-6 py-5 min-w-[310px]
    "
    >
      <div class="font-semibold text-[26px] text-[#e5e5e5] dark:text-[#e5e5e5] text-neutral-800 mb-2">
        {@repo.name}
      </div>
      <div class="text-[22px] text-[#525252] dark:text-[#525252] text-neutral-500">
        <span class="font-mono">{@repo.current_branch}</span>
      </div>
    </div>
    """
  end

  # ── Delegation Shims (backwards compatibility with tests) ────────────

  @doc """
  Computes the freshness banner state and count from the list of repos.

  Delegates to `RepoMan.Dashboard.banner/1`.
  """
  def compute_banner(repos), do: Dashboard.banner(repos)

  # Kept for backwards compatibility with tests that call compute_banner_state/1
  def compute_banner_state(repos), do: Dashboard.banner_state(repos)

  @doc """
  Computes summary counts from the repos list.

  Delegates to `RepoMan.Dashboard.summary_counts/1`.
  """
  def summary_counts(repos), do: Dashboard.summary_counts(repos)

  @doc false
  def format_time(time), do: Dashboard.format_time(time)
end
