defmodule RepoMan.RepoServer do
  @moduledoc """
  GenServer that holds the current status of a single git repository.

  One RepoServer per discovered repo. Reads git status on init,
  responds to `get_status/1` calls, and runs async fetch operations
  under a `Task.Supervisor`.

  Registered via `Registry` using the repo name as key, enabling
  lookup by name rather than PID.

  ## Operation Serialization

  Only one async operation (fetch/pull) runs at a time per repo.
  If an operation is already in progress, subsequent requests are
  silently ignored. The `operation` field in `%RepoStatus{}` tracks
  the current state: `:idle`, `:fetching`, `:pulling`, or `:error`.

  ## Usage

      # Start with a repo info map
      RepoServer.start_link(%{
        name: "AXO471",
        path: "/path/to/repo",
        registry: RepoMan.RepoRegistry,
        task_supervisor: RepoMan.TaskSupervisor
      })

      # Get current status by PID or via-tuple
      RepoServer.get_status(pid)

      # Trigger an async fetch
      RepoServer.fetch(pid)
  """

  use GenServer

  alias RepoMan.RepoStatus

  @git_module Application.compile_env(:repo_man, :git_module, RepoMan.Git)
  @default_poll_interval Application.compile_env(:repo_man, :poll_interval, 2_000)

  # ── Client API ──────────────────────────────────────────────────────

  @doc """
  Starts a RepoServer for the given repo.

  Expects a map with `:name`, `:path`, `:registry`, and optionally
  `:task_supervisor` keys. The server registers itself under
  `{:via, Registry, {registry, name}}`.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(%{name: name, path: _path, registry: registry} = repo_info) do
    GenServer.start_link(__MODULE__, repo_info, name: via(registry, name))
  end

  @doc """
  Returns the current `%RepoStatus{}` for this server.

  Accepts a PID or a via-tuple.
  """
  @spec get_status(GenServer.server()) :: RepoStatus.t()
  def get_status(server) do
    GenServer.call(server, :get_status)
  end

  @doc """
  Triggers an async `git fetch --all --prune` for this repo.

  Always safe — no preconditions. Delegates to `Git.fetch/1` via
  a Task spawned under the configured `Task.Supervisor`.

  If an operation is already in progress, the request is silently
  ignored (operation serialization).

  On completion, repo status is automatically refreshed.
  """
  @spec fetch(GenServer.server()) :: :ok
  def fetch(server) do
    GenServer.cast(server, :fetch)
  end

  @doc """
  Triggers an async `git pull --ff-only` for this repo.

  Delegates to `Git.pull_ff_only/1` via a Task spawned under the
  configured `Task.Supervisor`.

  **Preconditions** (checked via `RepoStatus.pull_eligible?`):
  - On default branch
  - Clean working tree (0 dirty files)
  - Not diverged (ahead == 0)
  - Behind > 0 (something to pull)

  If preconditions are not met or an operation is already in progress,
  the request is silently ignored.

  On completion, repo status is automatically refreshed.
  """
  @spec pull(GenServer.server()) :: :ok
  def pull(server) do
    GenServer.cast(server, :pull)
  end

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

  # ── Server Callbacks ────────────────────────────────────────────────

  @impl true
  def init(%{name: name, path: path} = repo_info) do
    status = read_status(name, path)
    poll_interval = Map.get(repo_info, :poll_interval, @default_poll_interval)

    state = %{
      name: name,
      path: path,
      status: status,
      task_supervisor: Map.get(repo_info, :task_supervisor, RepoMan.TaskSupervisor),
      pubsub: Map.get(repo_info, :pubsub, RepoMan.PubSub),
      task_ref: nil,
      poll_interval: poll_interval,
      poll_timer: nil
    }

    broadcast(state)
    poll_timer = schedule_poll(state)

    {:ok, %{state | poll_timer: poll_timer}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.status, state}
  end

  @impl true
  def handle_cast(:fetch, %{status: %{operation: op}} = state) when op != :idle do
    # Operation already in progress — silently ignore
    {:noreply, state}
  end

  def handle_cast(:fetch, state) do
    # Set operation to :fetching
    status = RepoStatus.new(status_attrs(state.status, operation: :fetching, last_error: nil))
    state = %{state | status: status}
    broadcast(state)

    # Spawn async task under Task.Supervisor
    %Task{ref: ref} =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        @git_module.fetch(state.path)
      end)

    {:noreply, %{state | task_ref: ref}}
  end

  @impl true
  def handle_cast(:pull, %{status: %{operation: op}} = state) when op != :idle do
    # Operation already in progress — silently ignore
    {:noreply, state}
  end

  def handle_cast(:pull, %{status: %{pull_eligible?: false}} = state) do
    # Preconditions not met — silently ignore
    {:noreply, state}
  end

  def handle_cast(:pull, state) do
    # Set operation to :pulling
    status = RepoStatus.new(status_attrs(state.status, operation: :pulling, last_error: nil))
    state = %{state | status: status}
    broadcast(state)

    # Spawn async task under Task.Supervisor — delegates to Git.pull_ff_only/1
    %Task{ref: ref} =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        @git_module.pull_ff_only(state.path)
      end)

    {:noreply, %{state | task_ref: ref}}
  end

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

        %{state | poll_timer: schedule_poll(state)}
      else
        state
      end

    {:noreply, state}
  end

  # Task completed successfully (handles both fetch and pull)
  @impl true
  def handle_info({ref, result}, %{task_ref: ref} = state) do
    # Demonitor and flush the :DOWN message
    Process.demonitor(ref, [:flush])

    case result do
      :ok ->
        # Refresh status after successful operation
        status = read_status(state.name, state.path)
        state = %{state | status: status, task_ref: nil}
        broadcast(state)
        {:noreply, state}

      {:error, message} ->
        # Operation failed — set error state
        status =
          RepoStatus.new(status_attrs(state.status, operation: :error, last_error: message))

        state = %{state | status: status, task_ref: nil}
        broadcast(state)
        {:noreply, state}
    end
  end

  # Task process crashed (abnormal exit)
  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    op_name = if state.status.operation == :pulling, do: "Pull", else: "Fetch"
    message = "#{op_name} task crashed: #{inspect(reason)}"
    status = RepoStatus.new(status_attrs(state.status, operation: :error, last_error: message))
    state = %{state | status: status, task_ref: nil}
    broadcast(state)
    {:noreply, state}
  end

  # Periodic poll — re-read git status and broadcast if changed.
  # Skips during in-progress operations to avoid conflicting reads.
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

  # Ignore unrelated messages
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp via(registry, name) do
    {:via, Registry, {registry, name}}
  end

  defp broadcast(%{pubsub: pubsub, status: status}) do
    Phoenix.PubSub.broadcast(pubsub, "repos", {:repo_updated, status})
  end

  defp schedule_poll(%{poll_interval: interval}) when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :poll, interval)
  end

  defp schedule_poll(_state), do: nil

  defp cancel_poll_timer(%{poll_timer: ref} = state) when is_reference(ref) do
    Process.cancel_timer(ref)
    %{state | poll_timer: nil}
  end

  defp cancel_poll_timer(state), do: state

  defp read_status(name, path) do
    # Call each git function exactly once, capture the result tuples
    branch_result = @git_module.current_branch(path)
    default_result = @git_module.default_branch(path)

    current_branch = unwrap(branch_result, "unknown")
    default_branch = unwrap(default_result, "unknown")

    ab_result = @git_module.ahead_behind(path, default_branch)

    {ahead, behind} =
      case ab_result do
        {:ok, {a, b}} -> {a, b}
        {:error, _} -> {0, 0}
      end

    dirty_result = @git_module.dirty_files(path)
    branches_result = @git_module.local_branches(path)
    fetch_result = @git_module.last_fetch_time(path)

    dirty_files = unwrap(dirty_result, [])
    local_branches = unwrap(branches_result, [])
    last_fetch = unwrap(fetch_result, nil)

    errors =
      [branch_result, default_result, ab_result, dirty_result, branches_result, fetch_result]
      |> Enum.flat_map(fn
        {:error, msg} -> [msg]
        _ -> []
      end)

    last_error = if errors == [], do: nil, else: Enum.join(errors, "; ")

    RepoStatus.new(%{
      name: name,
      path: path,
      current_branch: current_branch,
      default_branch: default_branch,
      ahead: ahead,
      behind: behind,
      dirty_files: dirty_files,
      local_branches: local_branches,
      last_fetch: last_fetch,
      last_error: last_error,
      operation: :idle
    })
  end

  # Build a new attrs map from an existing status, overriding specific fields.
  # Used to update operation/error state without re-reading git.
  defp status_attrs(%RepoStatus{} = status, overrides) do
    %{
      name: status.name,
      path: status.path,
      current_branch: status.current_branch,
      default_branch: status.default_branch,
      ahead: status.ahead,
      behind: status.behind,
      dirty_files: status.dirty_files,
      local_branches: status.local_branches,
      last_fetch: status.last_fetch,
      last_error: status.last_error,
      operation: status.operation
    }
    |> Map.merge(Map.new(overrides))
  end

  defp unwrap({:ok, value}, _default), do: value
  defp unwrap({:error, _}, default), do: default
end
