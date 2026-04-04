defmodule RepoMan.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    repos_path = Application.get_env(:repo_man, :repos_path)
    RepoMan.RepoSupervisor.validate_repos_path!(repos_path)

    children = [
      RepoManWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:repo_man, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RepoMan.PubSub},
      {Registry, keys: :unique, name: RepoMan.RepoRegistry},
      {Task.Supervisor, name: RepoMan.TaskSupervisor},
      RepoMan.RepoSupervisor,
      # Start to serve requests, typically the last entry
      RepoManWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RepoMan.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Start RepoServers after the supervision tree is up so the
        # DynamicSupervisor, Registry, TaskSupervisor, and PubSub are ready.
        # Skipped in test env — tests start repos explicitly with their own
        # isolated supervisors and mock expectations.
        if Application.get_env(:repo_man, :start_repos_on_boot, true) do
          RepoMan.RepoSupervisor.start_repos()
        end

        {:ok, pid}

      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RepoManWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
