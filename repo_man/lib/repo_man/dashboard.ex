defmodule RepoMan.Dashboard do
  @moduledoc """
  Pure domain logic extracted from `DashboardLive`.

  Contains banner computation, summary counts, time formatting,
  and bulk progress text. No Phoenix or socket dependencies.
  """

  @doc """
  Computes the freshness banner state and count from the list of repos.

  Skips repos with in-progress operations. Returns a tuple of
  `{state, count}` where state is one of `:current`, `:behind`,
  `:warning`, or `:error`, and count is the number of repos
  contributing to the worst state.
  """
  @spec banner([map()]) :: {atom(), non_neg_integer()}
  def banner(repos) do
    # Only consider non-in-progress repos
    active_repos = Enum.reject(repos, &(&1.operation in [:fetching, :pulling]))

    cond do
      active_repos == [] ->
        {:current, 0}

      Enum.any?(active_repos, &(&1.severity in [:error, :diverged])) ->
        count =
          Enum.count(
            active_repos,
            &(&1.severity in [:error, :diverged, :dirty, :topic_branch, :behind])
          )

        {:error, count}

      Enum.any?(active_repos, &(&1.severity in [:dirty, :topic_branch])) ->
        count =
          Enum.count(active_repos, &(&1.severity in [:dirty, :topic_branch, :behind]))

        {:warning, count}

      Enum.any?(active_repos, &(&1.severity == :behind)) ->
        count = Enum.count(active_repos, &(&1.severity == :behind))
        {:behind, count}

      true ->
        {:current, 0}
    end
  end

  @doc """
  Returns just the banner state atom. Delegates to `banner/1`.

  Kept for backwards compatibility with tests that call `compute_banner_state/1`.
  """
  @spec banner_state([map()]) :: atom()
  def banner_state(repos) do
    {state, _count} = banner(repos)
    state
  end

  @doc """
  Computes summary counts from the repos list.

  Returns a map with keys: `:total`, `:synced`, `:behind`, `:dirty`,
  `:topic`, `:diverged`, `:errored`.
  """
  @spec summary_counts([map()]) :: map()
  def summary_counts(repos) do
    counts =
      Enum.reduce(
        repos,
        %{synced: 0, behind: 0, dirty: 0, topic: 0, diverged: 0, errored: 0},
        fn repo, acc ->
          case repo.severity do
            :clean -> %{acc | synced: acc.synced + 1}
            :behind -> %{acc | behind: acc.behind + 1}
            :dirty -> %{acc | dirty: acc.dirty + 1}
            :topic_branch -> %{acc | topic: acc.topic + 1}
            :diverged -> %{acc | diverged: acc.diverged + 1}
            :error -> %{acc | errored: acc.errored + 1}
            _ -> acc
          end
        end
      )

    Map.put(counts, :total, length(repos))
  end

  @doc false
  @spec format_time(nil | DateTime.t()) :: String.t()
  def format_time(nil), do: "never"

  def format_time(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, dt, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86400)}d ago"
    end
  end

  @doc false
  @spec bulk_progress_text(atom(), {non_neg_integer(), non_neg_integer()}) :: String.t()
  def bulk_progress_text(:fetching, {done, total}), do: "Fetching #{done}/#{total}…"
  def bulk_progress_text(:pulling, {done, total}), do: "Pulling #{done}/#{total}…"
  def bulk_progress_text(_, _), do: ""
end
