defmodule RepoMan.RepoStatus do
  @moduledoc """
  Status struct for a single git repository with derived fields.

  All derived fields (`on_default?`, `dirty_count`, `pull_eligible?`,
  `pull_blocked_reason`, `severity`) are computed at construction time
  via `new/1`. This is a pure-logic module — no git shell-outs, no I/O.

  ## Severity Priority

  When states overlap, highest priority wins:

      error > diverged > dirty > topic_branch > behind > clean

  ## Pull Eligibility Rules

  A repo is pull-eligible only when ALL of these hold:

  1. Working tree is clean (0 dirty files)
  2. On the default branch
  3. Not diverged (ahead must be 0)
  4. Not ahead-only (no unpushed commits)
  5. Behind > 0 (there's something to pull)
  """

  @type t :: %__MODULE__{
          name: String.t(),
          path: String.t(),
          current_branch: String.t(),
          default_branch: String.t(),
          on_default?: boolean(),
          ahead: non_neg_integer(),
          behind: non_neg_integer(),
          dirty_count: non_neg_integer(),
          dirty_files: [%{status: String.t(), path: String.t()}],
          local_branches: [String.t()],
          last_fetch: DateTime.t() | nil,
          pull_eligible?: boolean(),
          pull_blocked_reason: String.t() | nil,
          last_error: String.t() | nil,
          severity: :error | :diverged | :dirty | :topic_branch | :behind | :clean,
          operation: :idle | :fetching | :pulling | :error
        }

  defstruct [
    :name,
    :path,
    :current_branch,
    :default_branch,
    :on_default?,
    :ahead,
    :behind,
    :dirty_count,
    :dirty_files,
    :local_branches,
    :last_fetch,
    :pull_eligible?,
    :pull_blocked_reason,
    :last_error,
    :severity,
    operation: :idle
  ]

  @doc """
  Creates a new `%RepoStatus{}` with all derived fields computed.

  Expects a map with at minimum:
  - `:name`, `:path`, `:current_branch`, `:default_branch`
  - `:ahead`, `:behind`, `:dirty_files`, `:local_branches`
  - `:last_fetch`, `:last_error`, `:operation`
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    on_default? = attrs.current_branch == attrs.default_branch
    dirty_count = length(attrs.dirty_files)

    {pull_eligible?, pull_blocked_reason} =
      compute_pull_eligibility(dirty_count, on_default?, attrs)

    severity =
      compute_severity(
        attrs.last_error,
        attrs.operation,
        attrs.ahead,
        attrs.behind,
        dirty_count,
        on_default?
      )

    %__MODULE__{
      name: attrs.name,
      path: attrs.path,
      current_branch: attrs.current_branch,
      default_branch: attrs.default_branch,
      on_default?: on_default?,
      ahead: attrs.ahead,
      behind: attrs.behind,
      dirty_count: dirty_count,
      dirty_files: attrs.dirty_files,
      local_branches: attrs.local_branches,
      last_fetch: attrs.last_fetch,
      pull_eligible?: pull_eligible?,
      pull_blocked_reason: pull_blocked_reason,
      last_error: attrs.last_error,
      severity: severity,
      operation: Map.get(attrs, :operation, :idle)
    }
  end

  # ── Pull Eligibility ─────────────────────────────────────────────────
  #
  # Priority order (first match wins):
  # 1. dirty → blocked
  # 2. not on default → blocked
  # 3. diverged (ahead > 0 AND behind > 0) → blocked
  # 4. ahead > 0 → blocked
  # 5. behind == 0 → blocked
  # 6. Otherwise → eligible

  defp compute_pull_eligibility(dirty_count, on_default?, attrs) do
    cond do
      dirty_count > 0 ->
        {false, "#{dirty_count} dirty #{pluralize("file", dirty_count)} — commit or stash first"}

      not on_default? ->
        {false, "On branch #{attrs.current_branch} — switch to #{attrs.default_branch} first"}

      attrs.ahead > 0 and attrs.behind > 0 ->
        {false, "Diverged: #{attrs.ahead} ahead, #{attrs.behind} behind"}

      attrs.ahead > 0 ->
        {false, "#{attrs.ahead} unpushed #{pluralize("commit", attrs.ahead)}"}

      attrs.behind == 0 ->
        {false, "Already up to date"}

      true ->
        {true, nil}
    end
  end

  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"

  # ── Severity ─────────────────────────────────────────────────────────
  #
  # Priority order (first match wins):
  # error > diverged > dirty > topic_branch > behind > clean

  defp compute_severity(last_error, operation, ahead, behind, dirty_count, on_default?) do
    cond do
      last_error != nil -> :error
      operation == :error -> :error
      ahead > 0 and behind > 0 -> :diverged
      dirty_count > 0 -> :dirty
      not on_default? -> :topic_branch
      behind > 0 -> :behind
      true -> :clean
    end
  end
end
