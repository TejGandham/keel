defmodule RepoMan.RepoServerTest do
  # async: false because Mox global mode is needed — init/1 runs in the
  # GenServer process before we have a PID to Mox.allow/3 on.
  use ExUnit.Case, async: false

  import Mox

  alias RepoMan.RepoServer
  alias RepoMan.RepoStatus

  setup :set_mox_global
  setup :verify_on_exit!

  # Start a fresh Registry, Task.Supervisor, and PubSub per test to avoid name collisions
  setup do
    registry_name = :"registry_#{System.unique_integer([:positive])}"
    start_supervised!({Registry, keys: :unique, name: registry_name})

    task_sup_name = :"task_sup_#{System.unique_integer([:positive])}"
    start_supervised!({Task.Supervisor, name: task_sup_name})

    pubsub_name = :"pubsub_#{System.unique_integer([:positive])}"
    start_supervised!({Phoenix.PubSub, name: pubsub_name})

    %{registry: registry_name, task_supervisor: task_sup_name, pubsub: pubsub_name}
  end

  defp repo_info(registry, task_supervisor \\ nil, pubsub \\ nil) do
    base = %{name: "AXO471", path: "/fake/path/AXO471", registry: registry}

    base =
      if task_supervisor do
        Map.put(base, :task_supervisor, task_supervisor)
      else
        base
      end

    if pubsub do
      Map.put(base, :pubsub, pubsub)
    else
      base
    end
  end

  defp stub_clean_repo do
    RepoMan.Git.Mock
    |> expect(:current_branch, fn "/fake/path/AXO471" -> {:ok, "master"} end)
    |> expect(:default_branch, fn "/fake/path/AXO471" -> {:ok, "master"} end)
    |> expect(:ahead_behind, fn "/fake/path/AXO471", "master" -> {:ok, {0, 0}} end)
    |> expect(:dirty_files, fn "/fake/path/AXO471" -> {:ok, []} end)
    |> expect(:local_branches, fn "/fake/path/AXO471" -> {:ok, []} end)
    |> expect(:last_fetch_time, fn "/fake/path/AXO471" -> {:ok, ~U[2026-03-13 14:30:00Z]} end)
  end

  describe "start_link/1" do
    test "starts and returns initial status with correct name and branch", %{registry: registry} do
      stub_clean_repo()

      pid = start_supervised!({RepoServer, repo_info(registry)})
      assert is_pid(pid)

      status = RepoServer.get_status(pid)

      assert %RepoStatus{} = status
      assert status.name == "AXO471"
      assert status.path == "/fake/path/AXO471"
      assert status.current_branch == "master"
      assert status.default_branch == "master"
      assert status.on_default? == true
      assert status.ahead == 0
      assert status.behind == 0
      assert status.dirty_count == 0
      assert status.dirty_files == []
      assert status.local_branches == []
      assert status.last_fetch == ~U[2026-03-13 14:30:00Z]
      assert status.operation == :idle
      assert status.last_error == nil
      assert status.severity == :clean
    end

    test "reads correct status for repo behind origin", %{registry: registry} do
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 5}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, ["feat/xyz"]} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-14 10:00:00Z]} end)

      pid = start_supervised!({RepoServer, repo_info(registry)})

      status = RepoServer.get_status(pid)

      assert status.behind == 5
      assert status.ahead == 0
      assert status.local_branches == ["feat/xyz"]
      assert status.severity == :behind
      assert status.pull_eligible? == true
    end

    test "reads correct status for dirty repo on topic branch", %{registry: registry} do
      dirty_files = [%{status: "M", path: "lib/app.ex"}, %{status: "??", path: "new.txt"}]

      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "feat/SHRED-123"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {2, 1}} end)
      |> expect(:dirty_files, fn _ -> {:ok, dirty_files} end)
      |> expect(:local_branches, fn _ -> {:ok, ["develop"]} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, nil} end)

      pid = start_supervised!({RepoServer, repo_info(registry)})

      status = RepoServer.get_status(pid)

      assert status.current_branch == "feat/SHRED-123"
      assert status.default_branch == "master"
      assert status.on_default? == false
      assert status.dirty_count == 2
      assert status.dirty_files == dirty_files
      assert status.last_fetch == nil
      assert status.pull_eligible? == false
    end

    test "registers with the provided registry under repo name", %{registry: registry} do
      stub_clean_repo()

      pid = start_supervised!({RepoServer, repo_info(registry)})

      # Look up by name in the registry
      assert [{^pid, _}] = Registry.lookup(registry, "AXO471")
    end
  end

  describe "get_status/1" do
    test "returns the current RepoStatus struct", %{registry: registry} do
      stub_clean_repo()

      pid = start_supervised!({RepoServer, repo_info(registry)})

      status = RepoServer.get_status(pid)

      assert %RepoStatus{} = status
      assert status.name == "AXO471"
    end

    test "can be called via registry name", %{registry: registry} do
      stub_clean_repo()

      _pid = start_supervised!({RepoServer, repo_info(registry)})

      via = {:via, Registry, {registry, "AXO471"}}
      status = RepoServer.get_status(via)

      assert %RepoStatus{} = status
      assert status.name == "AXO471"
    end
  end

  describe "init/1 error handling" do
    test "handles git errors gracefully with error status", %{registry: registry} do
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:error, "fatal: not a git repo"} end)
      |> expect(:default_branch, fn _ -> {:error, "fatal: not a git repo"} end)
      |> expect(:ahead_behind, fn _, _ -> {:error, "fatal: not a git repo"} end)
      |> expect(:dirty_files, fn _ -> {:error, "fatal: not a git repo"} end)
      |> expect(:local_branches, fn _ -> {:error, "fatal: not a git repo"} end)
      |> expect(:last_fetch_time, fn _ -> {:error, "fatal: not a git repo"} end)

      pid = start_supervised!({RepoServer, repo_info(registry)})

      status = RepoServer.get_status(pid)

      assert %RepoStatus{} = status
      assert status.name == "AXO471"
      assert status.last_error != nil
      assert status.severity == :error
    end
  end

  describe "fetch/1" do
    test "sets operation to :fetching while in progress", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      # Use a ref to synchronize — block the fetch until we've checked :fetching
      test_pid = self()
      gate_ref = make_ref()

      stub_clean_repo()

      # fetch will block until we send the gate signal
      expect(RepoMan.Git.Mock, :fetch, fn "/fake/path/AXO471" ->
        send(test_pid, :fetch_started)
        # Block until the test signals us to continue
        receive do
          {:continue, ^gate_ref} -> :ok
        after
          5_000 -> :ok
        end
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      RepoServer.fetch(pid)

      # Wait for the fetch task to actually start
      assert_receive :fetch_started, 5_000

      # While fetch is blocked, operation should be :fetching
      status = RepoServer.get_status(pid)
      assert status.operation == :fetching

      # Stub the status refresh calls that happen after fetch completes
      stub_status_refresh()

      # Unblock the fetch
      send_to_task(pid, {:continue, gate_ref})

      # Wait for it to settle back to :idle
      assert_eventually(fn ->
        RepoServer.get_status(pid).operation == :idle
      end)
    end

    test "ignored when operation already in progress (serialization)", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      test_pid = self()
      gate_ref = make_ref()

      stub_clean_repo()

      # First fetch blocks
      expect(RepoMan.Git.Mock, :fetch, fn "/fake/path/AXO471" ->
        send(test_pid, :fetch_started)

        receive do
          {:continue, ^gate_ref} -> :ok
        after
          5_000 -> :ok
        end
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      # Start first fetch
      RepoServer.fetch(pid)
      assert_receive :fetch_started, 5_000

      # Second fetch should be ignored (no second :fetch expectation set)
      RepoServer.fetch(pid)

      # Still fetching (not crashed, not doubled)
      status = RepoServer.get_status(pid)
      assert status.operation == :fetching

      stub_status_refresh()
      send_to_task(pid, {:continue, gate_ref})

      assert_eventually(fn ->
        RepoServer.get_status(pid).operation == :idle
      end)
    end

    test "after task completes, operation returns to :idle", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      stub_clean_repo()

      expect(RepoMan.Git.Mock, :fetch, fn "/fake/path/AXO471" -> :ok end)
      stub_status_refresh()

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      RepoServer.fetch(pid)

      assert_eventually(fn ->
        RepoServer.get_status(pid).operation == :idle
      end)
    end

    test "after task completes, status is refreshed", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      # Init: behind by 5
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 5}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

      # Fetch succeeds
      expect(RepoMan.Git.Mock, :fetch, fn "/fake/path/AXO471" -> :ok end)

      # After fetch, status refresh shows behind by 3 (updated)
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 3}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-14 10:00:00Z]} end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      # Before fetch, behind is 5
      status = RepoServer.get_status(pid)
      assert status.behind == 5

      RepoServer.fetch(pid)

      # After fetch completes, behind should be 3 (refreshed)
      assert_eventually(fn ->
        status = RepoServer.get_status(pid)
        status.behind == 3 and status.last_fetch == ~U[2026-03-14 10:00:00Z]
      end)
    end

    test "task crash sets operation to :error with last_error message", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      stub_clean_repo()

      expect(RepoMan.Git.Mock, :fetch, fn "/fake/path/AXO471" ->
        {:error, "fatal: unable to access remote"}
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      RepoServer.fetch(pid)

      assert_eventually(fn ->
        status = RepoServer.get_status(pid)
        status.operation == :error and status.last_error == "fatal: unable to access remote"
      end)
    end
  end

  describe "pull/1" do
    test "sets operation to :pulling when eligible", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      test_pid = self()
      gate_ref = make_ref()

      # Init: on default branch, clean, behind by 3 → pull_eligible? = true
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 3}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

      # pull_ff_only blocks until we signal
      expect(RepoMan.Git.Mock, :pull_ff_only, fn "/fake/path/AXO471" ->
        send(test_pid, :pull_started)

        receive do
          {:continue, ^gate_ref} -> :ok
        after
          5_000 -> :ok
        end
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      # Verify pull_eligible? is true before pulling
      assert RepoServer.get_status(pid).pull_eligible? == true

      RepoServer.pull(pid)

      assert_receive :pull_started, 5_000

      # While pull is blocked, operation should be :pulling
      status = RepoServer.get_status(pid)
      assert status.operation == :pulling

      # Stub the status refresh calls that happen after pull completes
      stub_status_refresh()

      # Unblock the pull
      send_to_task(pid, {:continue, gate_ref})

      assert_eventually(fn ->
        RepoServer.get_status(pid).operation == :idle
      end)
    end

    test "rejected when pull_eligible? is false (dirty repo)", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      # Init: dirty repo — pull_eligible? should be false
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 3}} end)
      |> expect(:dirty_files, fn _ -> {:ok, [%{status: "M", path: "lib/app.ex"}]} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

      # pull_ff_only should NEVER be called — no expectation set
      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      # Verify precondition
      assert RepoServer.get_status(pid).pull_eligible? == false

      RepoServer.pull(pid)

      # Allow time for any unexpected async work
      Process.sleep(50)

      # Operation should remain :idle — pull was rejected
      status = RepoServer.get_status(pid)
      assert status.operation == :idle
    end

    test "rejected when operation already in progress", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      test_pid = self()
      gate_ref = make_ref()

      # Init: eligible repo
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 3}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

      # First pull blocks
      expect(RepoMan.Git.Mock, :pull_ff_only, fn "/fake/path/AXO471" ->
        send(test_pid, :pull_started)

        receive do
          {:continue, ^gate_ref} -> :ok
        after
          5_000 -> :ok
        end
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      # Start first pull
      RepoServer.pull(pid)
      assert_receive :pull_started, 5_000

      # Second pull should be ignored (no second :pull_ff_only expectation set)
      RepoServer.pull(pid)

      # Still pulling (not crashed, not doubled)
      status = RepoServer.get_status(pid)
      assert status.operation == :pulling

      stub_status_refresh()
      send_to_task(pid, {:continue, gate_ref})

      assert_eventually(fn ->
        RepoServer.get_status(pid).operation == :idle
      end)
    end

    test "after pull completes, status is refreshed and operation is :idle", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      # Init: behind by 3, eligible
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 3}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

      # Pull succeeds
      expect(RepoMan.Git.Mock, :pull_ff_only, fn "/fake/path/AXO471" -> :ok end)

      # After pull, status refresh shows behind by 0 (pulled)
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 0}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-14 10:00:00Z]} end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      # Before pull, behind is 3
      assert RepoServer.get_status(pid).behind == 3

      RepoServer.pull(pid)

      # After pull completes, behind should be 0 (refreshed) and operation :idle
      assert_eventually(fn ->
        status = RepoServer.get_status(pid)
        status.behind == 0 and status.operation == :idle
      end)
    end

    test "pull error sets operation to :error with last_error message", %{
      registry: registry,
      task_supervisor: task_sup
    } do
      # Init: eligible repo
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 3}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

      expect(RepoMan.Git.Mock, :pull_ff_only, fn "/fake/path/AXO471" ->
        {:error, "fatal: Not possible to fast-forward, aborting."}
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup)})

      RepoServer.pull(pid)

      assert_eventually(fn ->
        status = RepoServer.get_status(pid)

        status.operation == :error and
          status.last_error == "fatal: Not possible to fast-forward, aborting."
      end)
    end
  end

  describe "PubSub broadcasts" do
    test "broadcasts {:repo_updated, status} on init", %{
      registry: registry,
      pubsub: pubsub
    } do
      Phoenix.PubSub.subscribe(pubsub, "repos")

      stub_clean_repo()

      _pid = start_supervised!({RepoServer, repo_info(registry, nil, pubsub)})

      assert_receive {:repo_updated, %RepoStatus{} = status}, 1_000
      assert status.name == "AXO471"
      assert status.operation == :idle
    end

    test "broadcasts {:repo_updated, status} on fetch complete", %{
      registry: registry,
      task_supervisor: task_sup,
      pubsub: pubsub
    } do
      Phoenix.PubSub.subscribe(pubsub, "repos")

      stub_clean_repo()

      expect(RepoMan.Git.Mock, :fetch, fn "/fake/path/AXO471" -> :ok end)
      stub_status_refresh()

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup, pubsub)})

      # Drain the init broadcast
      assert_receive {:repo_updated, %RepoStatus{}}, 1_000

      RepoServer.fetch(pid)

      # Should receive broadcast for :fetching transition
      assert_receive {:repo_updated, %RepoStatus{operation: :fetching}}, 2_000

      # Should receive broadcast for :idle after fetch completes (status refresh)
      assert_receive {:repo_updated, %RepoStatus{operation: :idle}}, 2_000
    end

    test "broadcasts {:repo_updated, status} on fetch error", %{
      registry: registry,
      task_supervisor: task_sup,
      pubsub: pubsub
    } do
      Phoenix.PubSub.subscribe(pubsub, "repos")

      stub_clean_repo()

      expect(RepoMan.Git.Mock, :fetch, fn "/fake/path/AXO471" ->
        {:error, "fatal: unable to access remote"}
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup, pubsub)})

      # Drain the init broadcast
      assert_receive {:repo_updated, %RepoStatus{}}, 1_000

      RepoServer.fetch(pid)

      # Should receive broadcast for :fetching transition
      assert_receive {:repo_updated, %RepoStatus{operation: :fetching}}, 2_000

      # Should receive broadcast for :error after fetch fails
      assert_receive {:repo_updated, %RepoStatus{operation: :error} = status}, 2_000
      assert status.last_error == "fatal: unable to access remote"
    end

    test "broadcasts {:repo_updated, status} on pull complete", %{
      registry: registry,
      task_supervisor: task_sup,
      pubsub: pubsub
    } do
      Phoenix.PubSub.subscribe(pubsub, "repos")

      # Init: eligible repo (behind by 3)
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 3}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

      expect(RepoMan.Git.Mock, :pull_ff_only, fn "/fake/path/AXO471" -> :ok end)
      stub_status_refresh()

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup, pubsub)})

      # Drain the init broadcast
      assert_receive {:repo_updated, %RepoStatus{}}, 1_000

      RepoServer.pull(pid)

      # Should receive broadcast for :pulling transition
      assert_receive {:repo_updated, %RepoStatus{operation: :pulling}}, 2_000

      # Should receive broadcast for :idle after pull completes (status refresh)
      assert_receive {:repo_updated, %RepoStatus{operation: :idle}}, 2_000
    end

    test "broadcasts {:repo_updated, status} on pull error", %{
      registry: registry,
      task_supervisor: task_sup,
      pubsub: pubsub
    } do
      Phoenix.PubSub.subscribe(pubsub, "repos")

      # Init: eligible repo (behind by 3)
      RepoMan.Git.Mock
      |> expect(:current_branch, fn _ -> {:ok, "master"} end)
      |> expect(:default_branch, fn _ -> {:ok, "master"} end)
      |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 3}} end)
      |> expect(:dirty_files, fn _ -> {:ok, []} end)
      |> expect(:local_branches, fn _ -> {:ok, []} end)
      |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

      expect(RepoMan.Git.Mock, :pull_ff_only, fn "/fake/path/AXO471" ->
        {:error, "fatal: Not possible to fast-forward, aborting."}
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup, pubsub)})

      # Drain the init broadcast
      assert_receive {:repo_updated, %RepoStatus{}}, 1_000

      RepoServer.pull(pid)

      # Should receive broadcast for :pulling transition
      assert_receive {:repo_updated, %RepoStatus{operation: :pulling}}, 2_000

      # Should receive broadcast for :error after pull fails
      assert_receive {:repo_updated, %RepoStatus{operation: :error} = status}, 2_000
      assert status.last_error == "fatal: Not possible to fast-forward, aborting."
    end

    test "broadcasts {:repo_updated, status} on task crash", %{
      registry: registry,
      task_supervisor: task_sup,
      pubsub: pubsub
    } do
      Phoenix.PubSub.subscribe(pubsub, "repos")

      stub_clean_repo()

      expect(RepoMan.Git.Mock, :fetch, fn "/fake/path/AXO471" ->
        raise "boom"
      end)

      pid = start_supervised!({RepoServer, repo_info(registry, task_sup, pubsub)})

      # Drain the init broadcast
      assert_receive {:repo_updated, %RepoStatus{}}, 1_000

      RepoServer.fetch(pid)

      # Should receive broadcast for :fetching transition
      assert_receive {:repo_updated, %RepoStatus{operation: :fetching}}, 2_000

      # Should receive broadcast for :error after task crash
      assert_receive {:repo_updated, %RepoStatus{operation: :error} = status}, 2_000
      assert status.last_error =~ "Fetch task crashed"
    end
  end

  describe "set_poll_interval/2" do
    test "updates poll interval in server state", %{registry: registry} do
      # Use stub (not expect) since set_poll_interval triggers an immediate read
      RepoMan.Git.Mock
      |> stub(:current_branch, fn _ -> {:ok, "master"} end)
      |> stub(:default_branch, fn _ -> {:ok, "master"} end)
      |> stub(:ahead_behind, fn _, _ -> {:ok, {0, 0}} end)
      |> stub(:dirty_files, fn _ -> {:ok, []} end)
      |> stub(:local_branches, fn _ -> {:ok, []} end)
      |> stub(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-13 14:30:00Z]} end)

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
      assert state.poll_timer == nil
    end

    test "setting interval from 0 to non-zero triggers immediate poll and broadcast", %{
      registry: registry,
      pubsub: pubsub
    } do
      # Stub for init read
      stub_clean_repo()

      Phoenix.PubSub.subscribe(pubsub, "repos")

      pid = start_supervised!({RepoServer, repo_info(registry, nil, pubsub)})

      # Drain the init broadcast
      assert_receive {:repo_updated, _}

      # Stub for the immediate poll read — return a CHANGED status (behind=1)
      # so the broadcast fires (only broadcasts on status change)
      RepoMan.Git.Mock
      |> stub(:current_branch, fn _ -> {:ok, "master"} end)
      |> stub(:default_branch, fn _ -> {:ok, "master"} end)
      |> stub(:ahead_behind, fn _, _ -> {:ok, {0, 1}} end)
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

  # ── Helpers ──────────────────────────────────────────────────────────

  # Stub the 6 git status calls used by read_status/2 for post-fetch refresh
  defp stub_status_refresh do
    RepoMan.Git.Mock
    |> expect(:current_branch, fn _ -> {:ok, "master"} end)
    |> expect(:default_branch, fn _ -> {:ok, "master"} end)
    |> expect(:ahead_behind, fn _, "master" -> {:ok, {0, 0}} end)
    |> expect(:dirty_files, fn _ -> {:ok, []} end)
    |> expect(:local_branches, fn _ -> {:ok, []} end)
    |> expect(:last_fetch_time, fn _ -> {:ok, ~U[2026-03-14 10:00:00Z]} end)
  end

  # Send a message to the Task process spawned by the GenServer.
  # The GenServer stores the task ref; we find the task via Process.info.
  defp send_to_task(server_pid, message) do
    # The Task.Supervisor.async_nolink spawns a process that is linked to
    # the supervisor but monitored by the GenServer. We find it by checking
    # the GenServer's monitored processes.
    {:monitors, monitors} = Process.info(server_pid, :monitors)

    Enum.each(monitors, fn
      {:process, task_pid} -> send(task_pid, message)
      _ -> :ok
    end)
  end

  # Poll until fun returns true, with timeout
  defp assert_eventually(fun, timeout \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_assert_eventually(fun, deadline)
  end

  defp do_assert_eventually(fun, deadline) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) > deadline do
        flunk("Condition not met within timeout")
      else
        Process.sleep(10)
        do_assert_eventually(fun, deadline)
      end
    end
  end
end
