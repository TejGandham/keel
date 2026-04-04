defmodule RepoManWeb.RepoCard do
  @moduledoc """
  Card function components for the Repo Man dashboard.

  Each repo severity/operation state has its own card component:
  `clean_card/1`, `behind_card/1`, `topic_card/1`, `dirty_card/1`,
  `diverged_card/1`, `error_card/1`, and `in_progress_card/1`.

  Also contains the shared sub-components `fetch_button/1`,
  `pull_button/1`, and `open_terminal_link/1`.
  """

  use RepoManWeb, :html

  # ── Clean Card (F18) ─────────────────────────────────────────────────
  #
  # Neutral gray left border, no action buttons, no status pill.
  # Shows: repo name, current branch (mono), "clean", ahead/behind, last fetch.

  attr :repo, RepoMan.RepoStatus, required: true

  def clean_card(assigns) do
    ~H"""
    <div
      id={"repo-#{@repo.name}"}
      class="
      bg-[#141414] dark:bg-[#141414] bg-white
      border border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5]
      border-l-[6px] border-l-[#333] dark:border-l-[#333] border-l-[#d4d4d4]
      rounded-2xl px-6 py-5 min-w-[310px]
    "
    >
      <div class="font-semibold text-[26px] text-[#e5e5e5] dark:text-[#e5e5e5] text-neutral-800 mb-2">
        {@repo.name}
      </div>
      <div class="text-[22px] text-[#525252] dark:text-[#525252] text-neutral-500">
        <span class="font-mono">{@repo.current_branch}</span> · clean
      </div>
      <div class="flex items-center justify-between mt-1">
        <span class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400">
          ↓{@repo.behind} ↑{@repo.ahead} · {RepoMan.Dashboard.format_time(@repo.last_fetch)}
        </span>
        <.open_terminal_link path={@repo.path} />
      </div>
    </div>
    """
  end

  # ── Behind Card (F19) ────────────────────────────────────────────────
  #
  # Blue left border, blue status pill ("N behind"), Fetch + Pull buttons,
  # branch list (max 5, "+N more" truncation).
  # Shows: name, branch, ahead/behind, other branches, last fetch, Open Terminal.

  attr :repo, RepoMan.RepoStatus, required: true

  def behind_card(assigns) do
    other_branches =
      assigns.repo.local_branches
      |> Enum.reject(&(&1 == assigns.repo.current_branch))

    branch_display_limit = 5
    visible_branches = Enum.take(other_branches, branch_display_limit)
    remaining_count = length(other_branches) - length(visible_branches)
    other_branch_count = length(other_branches)

    assigns =
      assigns
      |> assign(:other_branches, other_branches)
      |> assign(:visible_branches, visible_branches)
      |> assign(:remaining_count, remaining_count)
      |> assign(:other_branch_count, other_branch_count)

    ~H"""
    <div
      id={"repo-#{@repo.name}"}
      class="
      bg-[#141414] dark:bg-[#141414] bg-white
      border border-[#1e3a5f] dark:border-[#1e3a5f] border-[#bfdbfe]
      border-l-[6px] border-l-[#3b82f6] dark:border-l-[#3b82f6] border-l-[#3b82f6]
      rounded-2xl px-6 py-5 min-w-[400px]
    "
    >
      <%!-- Row 1: name + pill --%>
      <div class="flex items-center gap-4 mb-2">
        <span class="font-semibold text-[26px] text-[#e5e5e5] dark:text-[#e5e5e5] text-neutral-800">
          {@repo.name}
        </span>
        <span class="rounded-full px-4 text-[20px] bg-[#172554] dark:bg-[#172554] bg-[#eff6ff] text-[#60a5fa] dark:text-[#60a5fa] text-[#2563eb]">
          {@repo.behind} behind
        </span>
      </div>

      <%!-- Row 2: branch + ahead/behind --%>
      <div class="text-[22px] text-[#525252] dark:text-[#525252] text-neutral-500">
        <span class="font-mono">{@repo.current_branch}</span> · ↓{@repo.behind} ↑{@repo.ahead}
      </div>

      <%!-- Row 3: other branches count + last fetch --%>
      <div class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2">
        <span :if={@other_branch_count > 0}>
          {@other_branch_count} other {if @other_branch_count == 1, do: "branch", else: "branches"} ·
        </span>
        {RepoMan.Dashboard.format_time(@repo.last_fetch)}
      </div>

      <%!-- Branch list (if any other branches) --%>
      <div
        :if={@other_branch_count > 0}
        class="border-t border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5] mt-4 pt-4"
      >
        <div class="flex flex-wrap gap-2">
          <span
            :for={branch <- @visible_branches}
            class="font-mono text-[20px] text-[#525252] dark:text-[#525252] text-neutral-500"
          >
            {branch}
          </span>
        </div>
        <div
          :if={@remaining_count > 0}
          class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2"
        >
          +{@remaining_count} more
        </div>
      </div>

      <%!-- Actions --%>
      <div class="flex items-center justify-between mt-4">
        <div class="flex gap-3">
          <.fetch_button repo={@repo} />
          <.pull_button repo={@repo} />
        </div>
        <.open_terminal_link path={@repo.path} />
      </div>
    </div>
    """
  end

  # ── Topic Branch Card (F20) ──────────────────────────────────────────
  #
  # Amber left border, amber pill ("topic"), branch name in amber monospace.
  # Pull blocked: "Not on default branch". Fetch button only, no Pull.
  # Open Terminal link.

  attr :repo, RepoMan.RepoStatus, required: true

  def topic_card(assigns) do
    ~H"""
    <div
      id={"repo-#{@repo.name}"}
      class="
      bg-[#141414] dark:bg-[#141414] bg-white
      border border-[#422006] dark:border-[#422006] border-[#fde68a]
      border-l-[6px] border-l-[#f59e0b] dark:border-l-[#f59e0b] border-l-[#f59e0b]
      rounded-2xl px-6 py-5 min-w-[400px]
    "
    >
      <%!-- Row 1: name + pill --%>
      <div class="flex items-center gap-4 mb-2">
        <span class="font-semibold text-[26px] text-[#e5e5e5] dark:text-[#e5e5e5] text-neutral-800">
          {@repo.name}
        </span>
        <span class="rounded-full px-4 text-[20px] bg-[#422006] dark:bg-[#422006] bg-[#fef9c3] text-[#fbbf24] dark:text-[#fbbf24] text-[#a16207]">
          topic
        </span>
      </div>

      <%!-- Row 2: branch name in amber monospace --%>
      <div class="text-[22px] text-[#fbbf24] dark:text-[#fbbf24] text-[#a16207]">
        <span class="font-mono">{@repo.current_branch}</span>
      </div>

      <%!-- Row 3: ahead/behind + clean/dirty + last fetch --%>
      <div class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2">
        ↓{@repo.behind} ↑{@repo.ahead} · {if @repo.dirty_count == 0,
          do: "clean",
          else: "#{@repo.dirty_count} dirty"}
      </div>
      <div class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2">
        {RepoMan.Dashboard.format_time(@repo.last_fetch)}
      </div>

      <%!-- Pull-blocked reason --%>
      <div class="border-t border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5] mt-4 pt-4">
        <div class="text-[20px] text-[#525252] dark:text-[#525252] text-neutral-500">
          Not on default branch
        </div>
      </div>

      <%!-- Actions: Fetch only, no Pull --%>
      <div class="flex items-center justify-between mt-4">
        <div class="flex gap-3">
          <.fetch_button repo={@repo} />
        </div>
        <.open_terminal_link path={@repo.path} />
      </div>
    </div>
    """
  end

  # ── Dirty Card (F21) ───────────────────────────────────────────────
  #
  # Orange left border, orange pill ("N dirty"), dirty file list
  # (max 8, "+N more" truncation), file status codes in monospace.
  # Pull blocked: "Dirty — commit or stash first". Fetch + disabled Pull.
  # Open Terminal link.

  attr :repo, RepoMan.RepoStatus, required: true

  def dirty_card(assigns) do
    file_display_limit = 8
    visible_files = Enum.take(assigns.repo.dirty_files, file_display_limit)
    remaining_files = assigns.repo.dirty_count - length(visible_files)

    assigns =
      assigns
      |> assign(:visible_files, visible_files)
      |> assign(:remaining_files, remaining_files)

    ~H"""
    <div
      id={"repo-#{@repo.name}"}
      class="
      bg-[#141414] dark:bg-[#141414] bg-white
      border border-[#431407] dark:border-[#431407] border-[#fed7aa]
      border-l-[6px] border-l-[#f97316] dark:border-l-[#f97316] border-l-[#f97316]
      rounded-2xl px-6 py-5 min-w-[440px]
    "
    >
      <%!-- Row 1: name + pill --%>
      <div class="flex items-center gap-4 mb-2">
        <span class="font-semibold text-[26px] text-[#e5e5e5] dark:text-[#e5e5e5] text-neutral-800">
          {@repo.name}
        </span>
        <span class="rounded-full px-4 text-[20px] bg-[#431407] dark:bg-[#431407] bg-[#fff7ed] text-[#fb923c] dark:text-[#fb923c] text-[#ea580c]">
          {@repo.dirty_count} dirty
        </span>
      </div>

      <%!-- Row 2: branch + ahead/behind --%>
      <div class="text-[22px] text-[#525252] dark:text-[#525252] text-neutral-500">
        <span class="font-mono">{@repo.current_branch}</span> · ↓{@repo.behind} ↑{@repo.ahead}
      </div>

      <%!-- Row 3: branch count + last fetch --%>
      <div class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2">
        {RepoMan.Dashboard.format_time(@repo.last_fetch)}
      </div>

      <%!-- Dirty file list --%>
      <div class="border-t border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5] mt-4 pt-4">
        <div
          :for={file <- @visible_files}
          class="font-mono text-[20px] text-[#525252] dark:text-[#525252] text-neutral-500 leading-relaxed"
        >
          <span class="text-[#fb923c] dark:text-[#fb923c] text-[#ea580c]">{file.status}</span> {file.path}
        </div>
        <div
          :if={@remaining_files > 0}
          class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2"
        >
          +{@remaining_files} more
        </div>
      </div>

      <%!-- Pull-blocked reason --%>
      <div class="border-t border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5] mt-4 pt-4">
        <div class="text-[20px] text-[#525252] dark:text-[#525252] text-neutral-500">
          Dirty — commit or stash first
        </div>
      </div>

      <%!-- Actions: Fetch + disabled Pull --%>
      <div class="flex items-center justify-between mt-4">
        <div class="flex gap-3">
          <.fetch_button repo={@repo} />
          <.pull_button repo={@repo} />
        </div>
        <.open_terminal_link path={@repo.path} />
      </div>
    </div>
    """
  end

  # ── Diverged Card (F22) ────────────────────────────────────────────
  #
  # Red left border, red pill ("diverged"), ahead/behind counts.
  # "Diverged: N ahead, M behind — manual merge needed".
  # Fetch + Open Terminal (no Pull).

  attr :repo, RepoMan.RepoStatus, required: true

  def diverged_card(assigns) do
    ~H"""
    <div
      id={"repo-#{@repo.name}"}
      class="
      bg-[#141414] dark:bg-[#141414] bg-white
      border border-[#450a0a] dark:border-[#450a0a] border-[#fecaca]
      border-l-[6px] border-l-[#ef4444] dark:border-l-[#ef4444] border-l-[#ef4444]
      rounded-2xl px-6 py-5 min-w-[400px]
    "
    >
      <%!-- Row 1: name + pill --%>
      <div class="flex items-center gap-4 mb-2">
        <span class="font-semibold text-[26px] text-[#e5e5e5] dark:text-[#e5e5e5] text-neutral-800">
          {@repo.name}
        </span>
        <span class="rounded-full px-4 text-[20px] bg-[#450a0a] dark:bg-[#450a0a] bg-[#fef2f2] text-[#f87171] dark:text-[#f87171] text-[#dc2626]">
          diverged
        </span>
      </div>

      <%!-- Row 2: branch + ahead/behind --%>
      <div class="text-[22px] text-[#525252] dark:text-[#525252] text-neutral-500">
        <span class="font-mono">{@repo.current_branch}</span> · ↓{@repo.behind} ↑{@repo.ahead}
      </div>

      <%!-- Row 3: last fetch --%>
      <div class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2">
        {RepoMan.Dashboard.format_time(@repo.last_fetch)}
      </div>

      <%!-- Diverged reason --%>
      <div class="border-t border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5] mt-4 pt-4">
        <div class="text-[20px] text-[#525252] dark:text-[#525252] text-neutral-500">
          Diverged: {@repo.ahead} ahead, {@repo.behind} behind — manual merge needed
        </div>
      </div>

      <%!-- Actions: Fetch + Open Terminal (no Pull) --%>
      <div class="flex items-center justify-between mt-4">
        <div class="flex gap-3">
          <.fetch_button repo={@repo} />
        </div>
        <.open_terminal_link path={@repo.path} />
      </div>
    </div>
    """
  end

  # ── Error Card (F23) ───────────────────────────────────────────────
  #
  # Red left border, red pill ("✗ error"), error message in monospace.
  # "Retry fetch" button + Open Terminal.

  attr :repo, RepoMan.RepoStatus, required: true

  def error_card(assigns) do
    ~H"""
    <div
      id={"repo-#{@repo.name}"}
      class="
      bg-[#141414] dark:bg-[#141414] bg-white
      border border-[#450a0a] dark:border-[#450a0a] border-[#fecaca]
      border-l-[6px] border-l-[#ef4444] dark:border-l-[#ef4444] border-l-[#ef4444]
      rounded-2xl px-6 py-5 min-w-[400px]
    "
    >
      <%!-- Row 1: name + pill --%>
      <div class="flex items-center gap-4 mb-2">
        <span class="font-semibold text-[26px] text-[#e5e5e5] dark:text-[#e5e5e5] text-neutral-800">
          {@repo.name}
        </span>
        <span class="rounded-full px-4 text-[20px] bg-[#450a0a] dark:bg-[#450a0a] bg-[#fef2f2] text-[#f87171] dark:text-[#f87171] text-[#dc2626]">
          ✗ error
        </span>
      </div>

      <%!-- Row 2: branch + ahead/behind --%>
      <div class="text-[22px] text-[#525252] dark:text-[#525252] text-neutral-500">
        <span class="font-mono">{@repo.current_branch}</span> · ↓{@repo.behind} ↑{@repo.ahead}
      </div>

      <%!-- Row 3: last fetch --%>
      <div class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2">
        {RepoMan.Dashboard.format_time(@repo.last_fetch)}
      </div>

      <%!-- Error message --%>
      <div
        :if={@repo.last_error}
        class="border-t border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5] mt-4 pt-4"
      >
        <div class="font-mono text-[20px] text-[#f87171] dark:text-[#f87171] text-[#dc2626] leading-relaxed">
          {@repo.last_error}
        </div>
      </div>

      <%!-- Actions: Retry fetch + Open Terminal --%>
      <div class="flex items-center justify-between mt-4">
        <div class="flex gap-3">
          <button
            phx-click="retry"
            phx-value-repo={@repo.name}
            class="text-[20px] px-5 py-1 rounded-[10px] transition-colors bg-[#262626] dark:bg-[#262626] bg-[#f5f5f5] text-[#a3a3a3] dark:text-[#a3a3a3] text-neutral-600 hover:brightness-125"
          >
            Retry fetch
          </button>
        </div>
        <.open_terminal_link path={@repo.path} />
      </div>
    </div>
    """
  end

  # ── In-Progress Card (F24) ─────────────────────────────────────────
  #
  # Gray left border, gray pill with spinning icon ("⟳ fetching…"
  # or "⟳ pulling…"), 0.85 opacity on entire card, all buttons disabled.
  # Open Terminal link.

  attr :repo, RepoMan.RepoStatus, required: true

  def in_progress_card(assigns) do
    op_text =
      case assigns.repo.operation do
        :fetching -> "fetching…"
        :pulling -> "pulling…"
        _ -> "working…"
      end

    assigns = assign(assigns, :op_text, op_text)

    ~H"""
    <div
      id={"repo-#{@repo.name}"}
      class="
      bg-[#141414] dark:bg-[#141414] bg-white
      border border-[#1f1f1f] dark:border-[#1f1f1f] border-[#e5e5e5]
      border-l-[6px] border-l-[#737373] dark:border-l-[#737373] border-l-[#a3a3a3]
      rounded-2xl px-6 py-5 min-w-[400px]
      opacity-[0.85]
    "
    >
      <%!-- Row 1: name + spinner pill --%>
      <div class="flex items-center gap-4 mb-2">
        <span class="font-semibold text-[26px] text-[#e5e5e5] dark:text-[#e5e5e5] text-neutral-800">
          {@repo.name}
        </span>
        <span class="rounded-full px-4 text-[20px] bg-[#262626] dark:bg-[#262626] bg-[#f5f5f5] text-[#a3a3a3] dark:text-[#a3a3a3] text-[#737373]">
          <span class="inline-block animate-spin">⟳</span> {@op_text}
        </span>
      </div>

      <%!-- Row 2: branch + ahead/behind --%>
      <div class="text-[22px] text-[#525252] dark:text-[#525252] text-neutral-500">
        <span class="font-mono">{@repo.current_branch}</span> · ↓{@repo.behind} ↑{@repo.ahead}
      </div>

      <%!-- Row 3: last fetch --%>
      <div class="text-[20px] text-[#404040] dark:text-[#404040] text-neutral-400 mt-2">
        {RepoMan.Dashboard.format_time(@repo.last_fetch)}
      </div>

      <%!-- Actions: all disabled --%>
      <div class="flex items-center justify-between mt-4">
        <div class="flex gap-3">
          <.fetch_button repo={@repo} />
          <.pull_button repo={@repo} />
        </div>
        <.open_terminal_link path={@repo.path} />
      </div>
    </div>
    """
  end

  # ── Reusable Button Components ─────────────────────────────────────
  #
  # Shared by F19-F24 card types.
  #
  # fetch_button/1 — neutral styling, disabled during operations.
  # pull_button/1  — blue when eligible, gray when disabled, tooltip on disabled.

  attr :repo, RepoMan.RepoStatus, required: true

  def fetch_button(assigns) do
    disabled = assigns.repo.operation in [:fetching, :pulling]
    assigns = assign(assigns, :disabled, disabled)

    ~H"""
    <button
      phx-click="fetch"
      phx-value-repo={@repo.name}
      disabled={@disabled}
      class={[
        "text-[20px] px-5 py-1 rounded-[10px] transition-colors",
        if(@disabled,
          do:
            "bg-[#1f1f1f] dark:bg-[#1f1f1f] bg-[#f5f5f5] text-[#404040] dark:text-[#404040] text-neutral-400 cursor-not-allowed",
          else:
            "bg-[#262626] dark:bg-[#262626] bg-[#f5f5f5] text-[#a3a3a3] dark:text-[#a3a3a3] text-neutral-600 hover:brightness-125"
        )
      ]}
    >
      Fetch
    </button>
    """
  end

  attr :repo, RepoMan.RepoStatus, required: true

  def pull_button(assigns) do
    disabled = !assigns.repo.pull_eligible? or assigns.repo.operation in [:fetching, :pulling]
    assigns = assign(assigns, :disabled, disabled)

    tooltip =
      if !assigns.repo.pull_eligible? and assigns.repo.pull_blocked_reason do
        assigns.repo.pull_blocked_reason
      else
        nil
      end

    assigns = assign(assigns, :tooltip, tooltip)

    ~H"""
    <button
      phx-click="pull"
      phx-value-repo={@repo.name}
      disabled={@disabled}
      title={@tooltip}
      class={[
        "text-[20px] px-5 py-1 rounded-[10px] transition-colors",
        if(@disabled,
          do:
            "bg-[#1f1f1f] dark:bg-[#1f1f1f] bg-[#f5f5f5] text-[#404040] dark:text-[#404040] text-neutral-400 cursor-not-allowed",
          else:
            "bg-[#172554] dark:bg-[#172554] bg-[#eff6ff] text-[#60a5fa] dark:text-[#60a5fa] text-[#2563eb] hover:brightness-125"
        )
      ]}
    >
      Pull
    </button>
    """
  end

  # ── Open Terminal Link ───────────────────────────────────────────────
  #
  # Opens Ghostty at the repo path via the host-side terminal-opener companion.
  # Maps container path → host path, then calls localhost:4001/open?path=...
  # Shown on every card type.

  attr :path, :string, required: true

  def open_terminal_link(assigns) do
    host_path = to_host_path(assigns.path)
    assigns = assign(assigns, :host_path, host_path)

    ~H"""
    <button
      phx-click={
        Phoenix.LiveView.JS.dispatch("phx:open-terminal", detail: %{path: @host_path})
      }
      title={"Open Terminal — #{@host_path}"}
      class="text-[20px] text-[#525252] dark:text-[#525252] text-neutral-400 hover:text-[#a3a3a3] dark:hover:text-[#a3a3a3] hover:text-neutral-600 transition-colors cursor-pointer bg-transparent border-none p-0 outline-none focus:outline-none active:text-inherit"
    >
      ↗
    </button>
    """
  end

  defp to_host_path(container_path) do
    repos_path = Application.get_env(:repo_man, :repos_path, "/shred")
    host_repos_path = Application.get_env(:repo_man, :host_repos_path, repos_path)
    String.replace_prefix(container_path, repos_path, host_repos_path)
  end
end
