defmodule RepoMan.RepoSupervisorTest do
  # async: false because Mox global mode is needed — RepoServer.init/1
  # runs in spawned GenServer processes before we can Mox.allow/3 them.
  use ExUnit.Case, async: false

  import Mox

  alias RepoMan.RepoSupervisor
  alias RepoMan.RepoStatus

  setup :set_mox_global
  setup :verify_on_exit!

  # Each test gets its own Registry, PubSub, TaskSupervisor, and DynamicSupervisor
  # to avoid cross-test interference.
  setup do
    registry_name = :"registry_#{System.unique_integer([:positive])}"
    start_supervised!({Registry, keys: :unique, name: registry_name})

    task_sup_name = :"task_sup_#{System.unique_integer([:positive])}"
    start_supervised!({Task.Supervisor, name: task_sup_name})

    pubsub_name = :"pubsub_#{System.unique_integer([:positive])}"
    start_supervised!({Phoenix.PubSub, name: pubsub_name})

    sup_name = :"sup_#{System.unique_integer([:positive])}"

    start_supervised!({RepoSupervisor, name: sup_name})

    # Create a temporary repos directory with some fake git repos
    test_dir = Path.join(System.tmp_dir!(), "repo_sup_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(test_dir)
    on_exit(fn -> File.rm_rf!(test_dir) end)

    %{
      registry: registry_name,
      task_supervisor: task_sup_name,
      pubsub: pubsub_name,
      supervisor: sup_name,
      test_dir: test_dir
    }
  end

  defp start_repos_opts(ctx, test_dir) do
    [
      supervisor: ctx.supervisor,
      repos_path: test_dir,
      registry: ctx.registry,
      task_supervisor: ctx.task_supervisor,
      pubsub: ctx.pubsub
    ]
  end

  # Stubs repo? to return true for paths in the given set, false otherwise.
  defp stub_repo_detection(git_paths) do
    git_set = MapSet.new(git_paths)

    stub(RepoMan.Git.Mock, :repo?, fn path ->
      MapSet.member?(git_set, path)
    end)
  end

  # Stubs all 6 git status functions to return clean defaults for any path.
  defp stub_all_git_status do
    RepoMan.Git.Mock
    |> stub(:current_branch, fn _path -> {:ok, "master"} end)
    |> stub(:default_branch, fn _path -> {:ok, "master"} end)
    |> stub(:ahead_behind, fn _path, "master" -> {:ok, {0, 0}} end)
    |> stub(:dirty_files, fn _path -> {:ok, []} end)
    |> stub(:local_branches, fn _path -> {:ok, []} end)
    |> stub(:last_fetch_time, fn _path -> {:ok, ~U[2026-03-13 14:30:00Z]} end)
  end

  describe "start_link/1" do
    test "starts the DynamicSupervisor", ctx do
      # The supervisor was already started in setup — just verify it's alive
      assert Process.alive?(Process.whereis(ctx.supervisor))
    end
  end

  describe "start_repos/1" do
    test "discovers and starts a RepoServer for each git repo", ctx do
      repo_a = Path.join(ctx.test_dir, "alpha")
      repo_b = Path.join(ctx.test_dir, "bravo")
      File.mkdir_p!(repo_a)
      File.mkdir_p!(repo_b)

      stub_repo_detection([repo_a, repo_b])
      stub_all_git_status()

      {:ok, started} = RepoSupervisor.start_repos(start_repos_opts(ctx, ctx.test_dir))

      assert length(started) == 2

      # Verify both repos are registered
      assert [{_, _}] = Registry.lookup(ctx.registry, "alpha")
      assert [{_, _}] = Registry.lookup(ctx.registry, "bravo")
    end

    test "returns empty list when no git repos found", ctx do
      # Empty directory — no repos
      {:ok, started} = RepoSupervisor.start_repos(start_repos_opts(ctx, ctx.test_dir))

      assert started == []
    end

    test "skips non-git directories", ctx do
      git_repo = Path.join(ctx.test_dir, "real_repo")
      plain_dir = Path.join(ctx.test_dir, "plain_dir")
      File.mkdir_p!(git_repo)
      File.mkdir_p!(plain_dir)

      # Only real_repo is a git repo
      stub_repo_detection([git_repo])
      stub_all_git_status()

      {:ok, started} = RepoSupervisor.start_repos(start_repos_opts(ctx, ctx.test_dir))

      assert length(started) == 1
      assert [{_, _}] = Registry.lookup(ctx.registry, "real_repo")
      assert [] = Registry.lookup(ctx.registry, "plain_dir")
    end
  end

  describe "all_statuses/1" do
    test "returns sorted list of RepoStatus structs", ctx do
      # Create repos that sort in a specific order
      repo_c = Path.join(ctx.test_dir, "charlie")
      repo_a = Path.join(ctx.test_dir, "alpha")
      File.mkdir_p!(repo_c)
      File.mkdir_p!(repo_a)

      stub_repo_detection([repo_a, repo_c])
      stub_all_git_status()

      {:ok, _started} = RepoSupervisor.start_repos(start_repos_opts(ctx, ctx.test_dir))

      statuses = RepoSupervisor.all_statuses(registry: ctx.registry)

      assert length(statuses) == 2
      assert [%RepoStatus{name: "alpha"}, %RepoStatus{name: "charlie"}] = statuses
    end

    test "returns empty list when no servers running", ctx do
      statuses = RepoSupervisor.all_statuses(registry: ctx.registry)
      assert statuses == []
    end

    test "each status has expected fields populated", ctx do
      repo = Path.join(ctx.test_dir, "myrepo")
      File.mkdir_p!(repo)

      stub_repo_detection([repo])
      stub_all_git_status()

      {:ok, _} = RepoSupervisor.start_repos(start_repos_opts(ctx, ctx.test_dir))

      [status] = RepoSupervisor.all_statuses(registry: ctx.registry)

      assert %RepoStatus{} = status
      assert status.name == "myrepo"
      assert status.path == repo
      assert status.current_branch == "master"
      assert status.operation == :idle
      assert status.severity == :clean
    end
  end

  describe "validate_repos_path!/1" do
    test "raises when path does not exist" do
      assert_raise RuntimeError, ~r/REPOMAN_PATH/, fn ->
        RepoSupervisor.validate_repos_path!("/nonexistent/path/that/does/not/exist")
      end
    end

    test "raises when path is a file" do
      tmp =
        Path.join(System.tmp_dir!(), "repoman_file_test_#{System.unique_integer([:positive])}")

      File.write!(tmp, "not a directory")
      on_exit(fn -> File.rm(tmp) end)

      assert_raise RuntimeError, ~r/REPOMAN_PATH/, fn ->
        RepoSupervisor.validate_repos_path!(tmp)
      end
    end

    test "returns :ok when path is a valid directory", ctx do
      assert :ok = RepoSupervisor.validate_repos_path!(ctx.test_dir)
    end
  end
end
