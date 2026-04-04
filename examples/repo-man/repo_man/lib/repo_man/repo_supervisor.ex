defmodule RepoMan.RepoSupervisor do
  @moduledoc """
  DynamicSupervisor that manages one `RepoServer` per discovered git repository.

  After the supervision tree starts, `start_repos/1` scans the configured repos
  path via `RepoDiscovery`, then starts a `RepoServer` child for each discovered
  repo. Servers register themselves in `RepoMan.RepoRegistry` for lookup by name.

  ## Usage

      # Called by Application.start after the supervisor tree is up:
      RepoSupervisor.start_repos()

      # Query all repo statuses (sorted by name):
      RepoSupervisor.all_statuses()
  """

  use DynamicSupervisor

  alias RepoMan.RepoDiscovery
  alias RepoMan.RepoServer

  # ── Client API ──────────────────────────────────────────────────────

  @doc """
  Starts the DynamicSupervisor.

  Accepts a keyword list. The `:name` key defaults to `RepoMan.RepoSupervisor`.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(init_arg \\ []) do
    name = Keyword.get(init_arg, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: name)
  end

  @doc """
  Discovers git repos under `repos_path` and starts a `RepoServer` for each.

  Options (all have application-level defaults):
  - `:supervisor` — DynamicSupervisor name (default: `RepoMan.RepoSupervisor`)
  - `:repos_path` — path to scan (default: from application config)
  - `:registry` — Registry name (default: `RepoMan.RepoRegistry`)
  - `:task_supervisor` — Task.Supervisor name (default: `RepoMan.TaskSupervisor`)
  - `:pubsub` — Phoenix.PubSub name (default: `RepoMan.PubSub`)

  Returns `{:ok, pids}` where `pids` is the list of started server PIDs.
  """
  @spec start_repos(keyword()) :: {:ok, [pid()]}
  def start_repos(opts \\ []) do
    supervisor = Keyword.get(opts, :supervisor, __MODULE__)
    repos_path = Keyword.get(opts, :repos_path, Application.get_env(:repo_man, :repos_path))
    registry = Keyword.get(opts, :registry, RepoMan.RepoRegistry)
    task_supervisor = Keyword.get(opts, :task_supervisor, RepoMan.TaskSupervisor)
    pubsub = Keyword.get(opts, :pubsub, RepoMan.PubSub)

    repos = RepoDiscovery.scan(repos_path)

    pids =
      Enum.reduce(repos, [], fn repo, acc ->
        repo_info = %{
          name: repo.name,
          path: repo.path,
          registry: registry,
          task_supervisor: task_supervisor,
          pubsub: pubsub
        }

        case DynamicSupervisor.start_child(supervisor, {RepoServer, repo_info}) do
          {:ok, pid} ->
            [pid | acc]

          {:error, {:already_started, pid}} ->
            [pid | acc]

          {:error, reason} ->
            require Logger
            Logger.error("Failed to start RepoServer for #{repo.name}: #{inspect(reason)}")
            acc
        end
      end)

    {:ok, Enum.reverse(pids)}
  end

  @doc """
  Returns all `%RepoStatus{}` structs from running RepoServers, sorted by name.

  Queries the Registry for all registered servers and calls `get_status/1` on each.

  Options:
  - `:registry` — Registry name (default: `RepoMan.RepoRegistry`)
  """
  @spec all_statuses(keyword()) :: [RepoMan.RepoStatus.t()]
  def all_statuses(opts \\ []) do
    registry = Keyword.get(opts, :registry, RepoMan.RepoRegistry)

    registry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.map(fn {_name, pid} -> RepoServer.get_status(pid) end)
    |> Enum.sort_by(& &1.name)
  end

  @doc """
  Validates that the given path exists and is a directory.

  Raises a `RuntimeError` with a clear message if the path is missing
  or is not a directory. Called during application startup.
  """
  @spec validate_repos_path!(String.t()) :: :ok
  def validate_repos_path!(path) do
    unless File.dir?(path) do
      raise """
      REPOMAN_PATH is not accessible: #{path}

      The configured repos path does not exist or is not a directory.
      Set REPOMAN_PATH to a valid directory containing your git repositories.

      Example: REPOMAN_PATH=~/src/repos mix phx.server
      """
    end

    :ok
  end

  @doc """
  Looks up a RepoServer by name and calls `fun.(pid)`.

  Returns the result of `fun.(pid)` if the server is found,
  or `:ok` if not found.

  Options:
  - `:registry` — Registry name (default: `RepoMan.RepoRegistry`)
  """
  @spec dispatch(String.t(), (pid() -> any()), keyword()) :: any()
  def dispatch(name, fun, opts \\ []) do
    registry = Keyword.get(opts, :registry, RepoMan.RepoRegistry)

    case Registry.lookup(registry, name) do
      [{pid, _}] -> fun.(pid)
      _ -> :ok
    end
  end

  @doc """
  Dispatches `fun` to each named RepoServer.

  Options:
  - `:registry` — Registry name (default: `RepoMan.RepoRegistry`)
  """
  @spec dispatch_all([String.t()], (pid() -> any()), keyword()) :: :ok
  def dispatch_all(names, fun, opts \\ []) do
    Enum.each(names, &dispatch(&1, fun, opts))
  end

  # ── Server Callbacks ────────────────────────────────────────────────

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
