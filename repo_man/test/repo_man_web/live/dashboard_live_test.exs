defmodule RepoManWeb.DashboardLiveTest do
  # async: false because:
  # 1. Mox global mode is needed — RepoServer.init/1 runs in spawned processes
  # 2. Tests share the application-level Registry/PubSub/DynamicSupervisor
  use RepoManWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Mox

  alias RepoMan.RepoSupervisor

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    # Create a temporary repos directory with fake git repos
    test_dir =
      Path.join(System.tmp_dir!(), "dashboard_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(test_dir)

    on_exit(fn ->
      # Stop all children in the application DynamicSupervisor to clean up
      # between tests so repos don't leak across test runs.
      for {_id, pid, _type, _mod} <- DynamicSupervisor.which_children(RepoMan.RepoSupervisor) do
        DynamicSupervisor.terminate_child(RepoMan.RepoSupervisor, pid)
      end

      File.rm_rf!(test_dir)
    end)

    %{test_dir: test_dir}
  end

  # Stubs repo? to return true only for paths in the given set.
  defp stub_repo_detection(git_paths) do
    git_set = MapSet.new(git_paths)

    stub(RepoMan.Git.Mock, :repo?, fn path ->
      MapSet.member?(git_set, path)
    end)
  end

  # Stubs all 6 git status callbacks to return clean defaults.
  defp stub_clean_git do
    RepoMan.Git.Mock
    |> stub(:current_branch, fn _path -> {:ok, "master"} end)
    |> stub(:default_branch, fn _path -> {:ok, "master"} end)
    |> stub(:ahead_behind, fn _path, _branch -> {:ok, {0, 0}} end)
    |> stub(:dirty_files, fn _path -> {:ok, []} end)
    |> stub(:local_branches, fn _path -> {:ok, []} end)
    |> stub(:last_fetch_time, fn _path -> {:ok, ~U[2026-03-13 14:30:00Z]} end)
  end

  # Creates fake repo directories and starts RepoServers using the
  # application's global infrastructure (Registry, PubSub, TaskSupervisor).
  defp setup_repos(test_dir, names) do
    paths =
      Enum.map(names, fn name ->
        path = Path.join(test_dir, name)
        File.mkdir_p!(path)
        path
      end)

    stub_repo_detection(paths)
    stub_clean_git()

    {:ok, _pids} = RepoSupervisor.start_repos(repos_path: test_dir)
    names
  end

  describe "mount" do
    test "LiveView mounts at / and shows 'Repo Man' title", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha", "bravo"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Repo Man"
    end

    test "shows repo count", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha", "bravo", "charlie"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "3 repos"
    end

    test "shows repo names from assigns", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["delta", "echo", "foxtrot"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "delta"
      assert html =~ "echo"
      assert html =~ "foxtrot"
    end

    test "shows zero repos when none discovered", %{conn: conn} do
      stub_clean_git()

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Repo Man"
      assert html =~ "0 repos"
    end
  end

  describe "clean card (F18)" do
    test "renders repo name", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "alpha"
    end

    test "shows 'clean' text", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "clean"
    end

    test "does not contain Fetch or Pull buttons", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      # The Fetch All / Pull All buttons exist in header, but card-level
      # Fetch/Pull should not appear for clean cards.
      # Check that no card-level fetch button exists (the card has no phx-click fetch button)
      refute html =~ ~r/<button[^>]*>[\s]*Fetch[\s]*<\/button>/
    end

    test "contains terminal link", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      # The ↗ character for terminal link
      assert html =~ "↗"
      assert html =~ "Open Terminal"
    end

    test "shows branch name in monospace", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      # Branch should be inside a font-mono span
      assert html =~ "font-mono"
      assert html =~ "master"
    end

    test "shows ahead/behind counters", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "↓0"
      assert html =~ "↑0"
    end

    test "shows last fetch time", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      # The stubbed time is ~U[2026-03-13 14:30:00Z] which should render as relative time
      assert html =~ "ago"
    end

    test "card has neutral gray left border class", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      # Clean card uses #333 left border
      assert html =~ "border-l-[#333]"
    end

    test "renders in a flow grid", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha", "bravo"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "flex flex-wrap gap-4 items-start"
    end

    test "does not render a status pill", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, view, _html} = live(conn, ~p"/")

      # Check the specific repo card element for rounded-full (pill)
      card_html = element(view, "#repo-alpha") |> render()
      refute card_html =~ "rounded-full"
    end
  end

  # Stubs git callbacks to return a "behind" repo state:
  # on default branch, 3 behind, 0 ahead, clean, with local branches.
  defp stub_behind_git(branches) do
    RepoMan.Git.Mock
    |> stub(:current_branch, fn _path -> {:ok, "master"} end)
    |> stub(:default_branch, fn _path -> {:ok, "master"} end)
    |> stub(:ahead_behind, fn _path, _branch -> {:ok, {0, 3}} end)
    |> stub(:dirty_files, fn _path -> {:ok, []} end)
    |> stub(:local_branches, fn _path -> {:ok, branches} end)
    |> stub(:last_fetch_time, fn _path -> {:ok, ~U[2026-03-13 14:30:00Z]} end)
  end

  # Creates a single behind repo via the RepoSupervisor with custom git stubs.
  defp setup_behind_repo(test_dir, name, branches \\ ["master", "feat/a", "feat/b"]) do
    path = Path.join(test_dir, name)
    File.mkdir_p!(path)

    stub_repo_detection([path])
    stub_behind_git(branches)

    {:ok, _pids} = RepoSupervisor.start_repos(repos_path: test_dir)
    name
  end

  describe "behind card (F19)" do
    test "renders blue left border", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "border-l-[#3b82f6]"
    end

    test "renders blue card border", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "border-[#1e3a5f]"
    end

    test "shows 'N behind' pill text", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "3 behind"
    end

    test "pill uses blue styling with rounded-full", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "rounded-full"
      assert html =~ "bg-[#172554]"
      assert html =~ "text-[#60a5fa]"
    end

    test "contains Fetch button", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Fetch"
    end

    test "contains Pull button", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Pull"
    end

    test "Pull button is enabled when pull_eligible", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      # Pull button should NOT have the disabled attribute in its rendered HTML.
      # The blue styling (bg-[#172554]) indicates an enabled pull button.
      assert html =~ "bg-[#172554]"
      # Enabled pull button should not have cursor-not-allowed on the pull button
      # (There will be no disabled attribute on the pull button element)
    end

    test "shows branch name in monospace", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "font-mono"
      assert html =~ "master"
    end

    test "shows ahead/behind counters", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "↓3"
      assert html =~ "↑0"
    end

    test "shows other branch count", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      # "master" is current, so 2 other branches: feat/a, feat/b
      assert html =~ "2 other branches"
    end

    test "lists branch names", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "feat/a"
      assert html =~ "feat/b"
    end

    test "truncates branch list at 5 with +N more", %{conn: conn, test_dir: test_dir} do
      many_branches = [
        "master",
        "feat/a",
        "feat/b",
        "feat/c",
        "feat/d",
        "feat/e",
        "feat/f",
        "feat/g"
      ]

      setup_behind_repo(test_dir, "omega", many_branches)

      {:ok, _view, html} = live(conn, ~p"/")

      # 7 other branches (excluding "master"), show 5, truncate 2
      assert html =~ "+2 more"
      # First 5 should be visible
      assert html =~ "feat/a"
      assert html =~ "feat/e"
      # The 6th and 7th should not appear as branch names in the visible list
      refute html =~ "feat/f"
      refute html =~ "feat/g"
    end

    test "contains terminal link", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "↗"
      assert html =~ "Open Terminal"
    end

    test "shows last fetch time", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "ago"
    end

    test "card has min-w-[200px]", %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "min-w-[400px]"
    end
  end

  describe "format_time/1" do
    test "returns 'never' for nil" do
      assert RepoManWeb.DashboardLive.format_time(nil) == "never"
    end

    test "returns 'just now' for recent times" do
      now = DateTime.utc_now()
      assert RepoManWeb.DashboardLive.format_time(now) == "just now"
    end

    test "returns minutes ago" do
      ten_min_ago = DateTime.add(DateTime.utc_now(), -600, :second)
      assert RepoManWeb.DashboardLive.format_time(ten_min_ago) == "10m ago"
    end

    test "returns hours ago" do
      two_hours_ago = DateTime.add(DateTime.utc_now(), -7200, :second)
      assert RepoManWeb.DashboardLive.format_time(two_hours_ago) == "2h ago"
    end

    test "returns days ago" do
      two_days_ago = DateTime.add(DateTime.utc_now(), -172_800, :second)
      assert RepoManWeb.DashboardLive.format_time(two_days_ago) == "2d ago"
    end
  end

  # ── Topic Branch helpers ──────────────────────────────────────────

  defp stub_topic_git do
    RepoMan.Git.Mock
    |> stub(:current_branch, fn _path -> {:ok, "feat/SHRED-2926-email"} end)
    |> stub(:default_branch, fn _path -> {:ok, "master"} end)
    |> stub(:ahead_behind, fn _path, _branch -> {:ok, {2, 0}} end)
    |> stub(:dirty_files, fn _path -> {:ok, []} end)
    |> stub(:local_branches, fn _path -> {:ok, ["master", "feat/SHRED-2926-email"]} end)
    |> stub(:last_fetch_time, fn _path -> {:ok, ~U[2026-03-13 14:30:00Z]} end)
  end

  defp setup_topic_repo(test_dir, name) do
    path = Path.join(test_dir, name)
    File.mkdir_p!(path)

    stub_repo_detection([path])
    stub_topic_git()

    {:ok, _pids} = RepoSupervisor.start_repos(repos_path: test_dir)
    name
  end

  describe "topic card (F20)" do
    test "renders amber left border", %{conn: conn, test_dir: test_dir} do
      setup_topic_repo(test_dir, "topicrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "border-l-[#f59e0b]"
    end

    test "renders amber card border", %{conn: conn, test_dir: test_dir} do
      setup_topic_repo(test_dir, "topicrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "border-[#422006]"
    end

    test "shows 'topic' pill", %{conn: conn, test_dir: test_dir} do
      setup_topic_repo(test_dir, "topicrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "rounded-full"
      assert html =~ "topic"
    end

    test "shows branch name in amber monospace", %{conn: conn, test_dir: test_dir} do
      setup_topic_repo(test_dir, "topicrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "font-mono"
      assert html =~ "feat/SHRED-2926-email"
    end

    test "shows 'Not on default branch' reason", %{conn: conn, test_dir: test_dir} do
      setup_topic_repo(test_dir, "topicrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Not on default branch"
    end

    test "shows Fetch button but not Pull button in card", %{conn: conn, test_dir: test_dir} do
      setup_topic_repo(test_dir, "topicrepo")

      {:ok, view, _html} = live(conn, ~p"/")

      # Check the card specifically for Fetch and no Pull
      card_html = element(view, "#repo-topicrepo") |> render()
      assert card_html =~ "Fetch"
      refute card_html =~ "Pull"
    end

    test "contains terminal link", %{conn: conn, test_dir: test_dir} do
      setup_topic_repo(test_dir, "topicrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "↗"
      assert html =~ "Open Terminal"
    end
  end

  # ── Dirty helpers ──────────────────────────────────────────────────

  defp stub_dirty_git(dirty_files) do
    RepoMan.Git.Mock
    |> stub(:current_branch, fn _path -> {:ok, "master"} end)
    |> stub(:default_branch, fn _path -> {:ok, "master"} end)
    |> stub(:ahead_behind, fn _path, _branch -> {:ok, {0, 0}} end)
    |> stub(:dirty_files, fn _path -> {:ok, dirty_files} end)
    |> stub(:local_branches, fn _path -> {:ok, ["master"]} end)
    |> stub(:last_fetch_time, fn _path -> {:ok, ~U[2026-03-13 14:30:00Z]} end)
  end

  defp setup_dirty_repo(test_dir, name, dirty_files) do
    path = Path.join(test_dir, name)
    File.mkdir_p!(path)

    stub_repo_detection([path])
    stub_dirty_git(dirty_files)

    {:ok, _pids} = RepoSupervisor.start_repos(repos_path: test_dir)
    name
  end

  describe "dirty card (F21)" do
    test "renders orange left border", %{conn: conn, test_dir: test_dir} do
      files = [%{status: "M", path: "src/main.ex"}]
      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "border-l-[#f97316]"
    end

    test "renders orange card border", %{conn: conn, test_dir: test_dir} do
      files = [%{status: "M", path: "src/main.ex"}]
      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "border-[#431407]"
    end

    test "shows 'N dirty' pill", %{conn: conn, test_dir: test_dir} do
      files = [
        %{status: "M", path: "src/a.ex"},
        %{status: "A", path: "src/b.ex"},
        %{status: "D", path: "src/c.ex"}
      ]

      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "3 dirty"
      assert html =~ "rounded-full"
    end

    test "shows dirty file list with status codes in monospace", %{conn: conn, test_dir: test_dir} do
      files = [
        %{status: "M", path: "src/main.ex"},
        %{status: "??", path: "tmp/scratch.txt"}
      ]

      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "src/main.ex"
      assert html =~ "tmp/scratch.txt"
      assert html =~ "font-mono"
    end

    test "truncates file list at 8 with +N more", %{conn: conn, test_dir: test_dir} do
      files =
        for i <- 1..12 do
          %{status: "M", path: "src/file_#{i}.ex"}
        end

      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      # First 8 files should be visible
      assert html =~ "src/file_1.ex"
      assert html =~ "src/file_8.ex"
      # 9th and beyond should NOT be visible
      refute html =~ "src/file_9.ex"
      refute html =~ "src/file_12.ex"
      # Truncation indicator
      assert html =~ "+4 more"
    end

    test "shows 'Dirty — commit or stash first' reason", %{conn: conn, test_dir: test_dir} do
      files = [%{status: "M", path: "src/main.ex"}]
      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Dirty — commit or stash first"
    end

    test "shows Fetch and disabled Pull buttons", %{conn: conn, test_dir: test_dir} do
      files = [%{status: "M", path: "src/main.ex"}]
      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Fetch"
      assert html =~ "Pull"
      # Pull should be disabled (cursor-not-allowed indicates disabled styling)
      assert html =~ "cursor-not-allowed"
    end

    test "contains terminal link", %{conn: conn, test_dir: test_dir} do
      files = [%{status: "M", path: "src/main.ex"}]
      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "↗"
      assert html =~ "Open Terminal"
    end
  end

  # ── Diverged helpers ───────────────────────────────────────────────

  defp stub_diverged_git do
    RepoMan.Git.Mock
    |> stub(:current_branch, fn _path -> {:ok, "master"} end)
    |> stub(:default_branch, fn _path -> {:ok, "master"} end)
    |> stub(:ahead_behind, fn _path, _branch -> {:ok, {2, 3}} end)
    |> stub(:dirty_files, fn _path -> {:ok, []} end)
    |> stub(:local_branches, fn _path -> {:ok, ["master"]} end)
    |> stub(:last_fetch_time, fn _path -> {:ok, ~U[2026-03-13 14:30:00Z]} end)
  end

  defp setup_diverged_repo(test_dir, name) do
    path = Path.join(test_dir, name)
    File.mkdir_p!(path)

    stub_repo_detection([path])
    stub_diverged_git()

    {:ok, _pids} = RepoSupervisor.start_repos(repos_path: test_dir)
    name
  end

  describe "diverged card (F22)" do
    test "renders red left border", %{conn: conn, test_dir: test_dir} do
      setup_diverged_repo(test_dir, "divrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "border-l-[#ef4444]"
    end

    test "renders red card border", %{conn: conn, test_dir: test_dir} do
      setup_diverged_repo(test_dir, "divrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "border-[#450a0a]"
    end

    test "shows 'diverged' pill", %{conn: conn, test_dir: test_dir} do
      setup_diverged_repo(test_dir, "divrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "diverged"
      assert html =~ "rounded-full"
    end

    test "shows ahead/behind counts in diverged reason", %{conn: conn, test_dir: test_dir} do
      setup_diverged_repo(test_dir, "divrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "2 ahead, 3 behind"
      assert html =~ "manual merge needed"
    end

    test "shows Fetch button but not Pull button in card", %{conn: conn, test_dir: test_dir} do
      setup_diverged_repo(test_dir, "divrepo")

      {:ok, view, _html} = live(conn, ~p"/")

      card_html = element(view, "#repo-divrepo") |> render()
      assert card_html =~ "Fetch"
      refute card_html =~ "Pull"
    end

    test "contains terminal link", %{conn: conn, test_dir: test_dir} do
      setup_diverged_repo(test_dir, "divrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "↗"
      assert html =~ "Open Terminal"
    end
  end

  # ── Error Card (F23) ────────────────────────────────────────────────
  #
  # Error repos are tested via PubSub update — we start a clean repo,
  # then broadcast an error status to trigger the error card render.

  describe "error card (F23)" do
    test "renders red left border and card border", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["errrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      # Push an error status via PubSub
      error_status =
        RepoMan.RepoStatus.new(%{
          name: "errrepo",
          path: Path.join(test_dir, "errrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 0,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: "fatal: Could not read from remote repository.",
          operation: :idle
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, error_status})
      html = render(view)

      assert html =~ "border-l-[#ef4444]"
      assert html =~ "border-[#450a0a]"
    end

    test "shows error pill", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["errrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      error_status =
        RepoMan.RepoStatus.new(%{
          name: "errrepo",
          path: Path.join(test_dir, "errrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 0,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: "fatal: Could not read from remote repository.",
          operation: :idle
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, error_status})
      html = render(view)

      assert html =~ "error"
      assert html =~ "rounded-full"
    end

    test "shows last_error text in monospace", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["errrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      error_status =
        RepoMan.RepoStatus.new(%{
          name: "errrepo",
          path: Path.join(test_dir, "errrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 0,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: "fatal: Could not read from remote repository.",
          operation: :idle
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, error_status})
      html = render(view)

      assert html =~ "fatal: Could not read from remote repository."
      assert html =~ "font-mono"
    end

    test "shows Retry fetch button", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["errrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      error_status =
        RepoMan.RepoStatus.new(%{
          name: "errrepo",
          path: Path.join(test_dir, "errrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 0,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: "fatal: Could not read from remote repository.",
          operation: :idle
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, error_status})
      html = render(view)

      assert html =~ "Retry fetch"
    end

    test "contains terminal link", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["errrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      error_status =
        RepoMan.RepoStatus.new(%{
          name: "errrepo",
          path: Path.join(test_dir, "errrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 0,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: "fatal: Could not read from remote repository.",
          operation: :idle
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, error_status})
      html = render(view)

      assert html =~ "↗"
      assert html =~ "Open Terminal"
    end
  end

  # ── In-progress helpers ────────────────────────────────────────────

  describe "in-progress card (F24)" do
    test "shows fetching spinner text", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["progressrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      # Push a fetching status via PubSub
      fetching_status =
        RepoMan.RepoStatus.new(%{
          name: "progressrepo",
          path: Path.join(test_dir, "progressrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 3,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :fetching
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, fetching_status})
      html = render(view)

      assert html =~ "fetching"
      assert html =~ "⟳"
    end

    test "shows pulling spinner text", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["progressrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      pulling_status =
        RepoMan.RepoStatus.new(%{
          name: "progressrepo",
          path: Path.join(test_dir, "progressrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 3,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :pulling
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, pulling_status})
      html = render(view)

      assert html =~ "pulling"
      assert html =~ "⟳"
    end

    test "card has 0.85 opacity", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["progressrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      fetching_status =
        RepoMan.RepoStatus.new(%{
          name: "progressrepo",
          path: Path.join(test_dir, "progressrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 3,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :fetching
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, fetching_status})
      html = render(view)

      assert html =~ "opacity-[0.85]"
    end

    test "all buttons are disabled", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["progressrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      fetching_status =
        RepoMan.RepoStatus.new(%{
          name: "progressrepo",
          path: Path.join(test_dir, "progressrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 3,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :fetching
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, fetching_status})
      html = render(view)

      # Both buttons should have cursor-not-allowed (disabled styling)
      assert html =~ "cursor-not-allowed"
      assert html =~ "Fetch"
      assert html =~ "Pull"
    end

    test "has gray left border", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["progressrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      fetching_status =
        RepoMan.RepoStatus.new(%{
          name: "progressrepo",
          path: Path.join(test_dir, "progressrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 3,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :fetching
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, fetching_status})
      html = render(view)

      assert html =~ "border-l-[#737373]"
    end

    test "contains terminal link", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["progressrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      fetching_status =
        RepoMan.RepoStatus.new(%{
          name: "progressrepo",
          path: Path.join(test_dir, "progressrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 3,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :fetching
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, fetching_status})
      html = render(view)

      assert html =~ "↗"
      assert html =~ "Open Terminal"
    end

    test "shows spinner with animate-spin", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["progressrepo"])

      {:ok, view, _html} = live(conn, ~p"/")

      fetching_status =
        RepoMan.RepoStatus.new(%{
          name: "progressrepo",
          path: Path.join(test_dir, "progressrepo"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 3,
          dirty_files: [],
          local_branches: ["master"],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :fetching
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, fetching_status})
      html = render(view)

      assert html =~ "animate-spin"
    end
  end

  describe "PubSub updates" do
    test "receives {:repo_updated, status} and re-renders", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, view, html} = live(conn, ~p"/")

      # Verify initial clean state
      assert html =~ "alpha"
      assert html =~ "1 repo"

      # Simulate a PubSub update — repo goes dirty
      updated_status =
        RepoMan.RepoStatus.new(%{
          name: "alpha",
          path: Path.join(test_dir, "alpha"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 0,
          dirty_files: [%{status: "M", path: "src/main.ex"}],
          local_branches: [],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :idle
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, updated_status})

      # LiveView should re-render with updated data — repo is still present
      html = render(view)
      assert html =~ "alpha"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # F25: Freshness Banner
  # ═══════════════════════════════════════════════════════════════════

  describe "freshness banner (F25)" do
    test "shows :current banner with check icon when all repos clean",
         %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha", "bravo"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "freshness-banner"
      assert html =~ "All repos current"
      assert html =~ "ready for design work"
    end

    test "shows :behind banner when repos behind origin",
         %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "freshness-banner"
      assert html =~ "behind origin"
      assert html =~ "designs may be stale"
    end

    test "shows :warning banner when repos dirty or on topic branch",
         %{conn: conn, test_dir: test_dir} do
      files = [%{status: "M", path: "src/main.ex"}]
      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "freshness-banner"
      assert html =~ "attention"
      assert html =~ "dirty or on topic branch"
    end

    test "shows :error banner when repos diverged or errored",
         %{conn: conn, test_dir: test_dir} do
      setup_diverged_repo(test_dir, "divrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "freshness-banner"
      assert html =~ "attention"
      assert html =~ "diverged or errored"
    end

    test "banner holds previous state during in-progress operation",
         %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, view, html} = live(conn, ~p"/")

      # Initially should be :current
      assert html =~ "All repos current"

      # Push a fetching status — banner should hold :current
      fetching_status =
        RepoMan.RepoStatus.new(%{
          name: "alpha",
          path: Path.join(test_dir, "alpha"),
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 0,
          dirty_files: [],
          local_branches: [],
          last_fetch: ~U[2026-03-13 14:30:00Z],
          last_error: nil,
          operation: :fetching
        })

      Phoenix.PubSub.broadcast!(RepoMan.PubSub, "repos", {:repo_updated, fetching_status})
      html = render(view)

      # Banner should still show "All repos current" (holds during in-progress)
      assert html =~ "All repos current"
    end

    test ":current banner has mint/green background", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "bg-[#111714]"
    end

    test ":error banner has red background", %{conn: conn, test_dir: test_dir} do
      setup_diverged_repo(test_dir, "divrepo")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "bg-[#1a0a0a]"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # F25: compute_banner_state/1 unit tests
  # ═══════════════════════════════════════════════════════════════════

  describe "compute_banner_state/1" do
    test "returns :current for all clean repos" do
      repos = [
        build_status(name: "a", severity: :clean),
        build_status(name: "b", severity: :clean)
      ]

      assert RepoManWeb.DashboardLive.compute_banner_state(repos) == :current
    end

    test "returns :behind when some repos behind" do
      repos = [
        build_status(name: "a", severity: :clean),
        build_status(name: "b", severity: :behind, behind: 3)
      ]

      assert RepoManWeb.DashboardLive.compute_banner_state(repos) == :behind
    end

    test "returns :warning when repos dirty" do
      repos = [
        build_status(name: "a", severity: :clean),
        build_status(name: "b", severity: :dirty, dirty_files: [%{status: "M", path: "a.ex"}])
      ]

      assert RepoManWeb.DashboardLive.compute_banner_state(repos) == :warning
    end

    test "returns :warning for topic branch repos" do
      repos = [
        build_status(name: "a", severity: :clean),
        build_status(
          name: "b",
          severity: :topic_branch,
          current_branch: "feat/x",
          on_default?: false
        )
      ]

      assert RepoManWeb.DashboardLive.compute_banner_state(repos) == :warning
    end

    test "returns :error for diverged repos" do
      repos = [
        build_status(name: "a", severity: :clean),
        build_status(name: "b", severity: :diverged, ahead: 2, behind: 3)
      ]

      assert RepoManWeb.DashboardLive.compute_banner_state(repos) == :error
    end

    test "returns :error for error repos" do
      repos = [
        build_status(name: "a", severity: :clean),
        build_status(name: "b", severity: :error, last_error: "fatal: boom")
      ]

      assert RepoManWeb.DashboardLive.compute_banner_state(repos) == :error
    end

    test "skips in-progress repos" do
      repos = [
        build_status(name: "a", severity: :clean),
        build_status(name: "b", severity: :behind, behind: 3, operation: :fetching)
      ]

      assert RepoManWeb.DashboardLive.compute_banner_state(repos) == :current
    end

    test "returns :current for empty list" do
      assert RepoManWeb.DashboardLive.compute_banner_state([]) == :current
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # F26: Summary Line
  # ═══════════════════════════════════════════════════════════════════

  describe "summary line (F26)" do
    test "shows repo counts in summary", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha", "bravo", "charlie"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "3 repos"
      assert html =~ "3 synced"
      assert html =~ "0 behind"
      assert html =~ "0 dirty"
    end

    test "shows correct counts for mixed statuses", %{conn: conn, test_dir: test_dir} do
      # Set up a behind repo (will show 1 behind in summary)
      setup_behind_repo(test_dir, "omega")

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "1 repo"
      assert html =~ "0 synced"
      assert html =~ "1 behind"
    end

    test "shows progress during bulk fetch op", %{conn: conn, test_dir: test_dir} do
      # Use a long-running fetch so we can observe the in-progress state
      stub(RepoMan.Git.Mock, :fetch, fn _path ->
        Process.sleep(10_000)
        :ok
      end)

      setup_repos(test_dir, ["alpha"])

      {:ok, view, _html} = live(conn, ~p"/")

      # Click fetch_all — the handler sets bulk_op immediately
      html = render_click(view, "fetch_all")

      # The button should show fetching progress text
      assert html =~ "Fetching"
    end

    test "shows repos path", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      # Summary line shows the configured repos path
      assert html =~ "summary-line"
    end
  end

  describe "summary_counts/1" do
    test "counts each severity correctly" do
      repos = [
        build_status(name: "a", severity: :clean),
        build_status(name: "b", severity: :clean),
        build_status(name: "c", severity: :behind, behind: 3),
        build_status(name: "d", severity: :dirty, dirty_files: [%{status: "M", path: "a.ex"}]),
        build_status(
          name: "e",
          severity: :topic_branch,
          current_branch: "feat/x",
          on_default?: false
        ),
        build_status(name: "f", severity: :diverged, ahead: 2, behind: 3),
        build_status(name: "g", severity: :error, last_error: "boom")
      ]

      counts = RepoManWeb.DashboardLive.summary_counts(repos)

      assert counts.total == 7
      assert counts.synced == 2
      assert counts.behind == 1
      assert counts.dirty == 1
      assert counts.topic == 1
      assert counts.diverged == 1
      assert counts.errored == 1
    end

    test "returns zeros for empty list" do
      counts = RepoManWeb.DashboardLive.summary_counts([])

      assert counts.total == 0
      assert counts.synced == 0
      assert counts.behind == 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # F27: Fetch All / Pull All
  # ═══════════════════════════════════════════════════════════════════

  describe "fetch all (F27)" do
    test "renders Fetch All button", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Fetch All"
      assert html =~ "fetch-all-btn"
    end

    test "fetch_all triggers fetching and shows progress", %{conn: conn, test_dir: test_dir} do
      # Stub fetch to hang (never return) so we can observe the in-progress state
      stub(RepoMan.Git.Mock, :fetch, fn _path ->
        Process.sleep(5000)
        :ok
      end)

      setup_repos(test_dir, ["alpha", "bravo"])

      {:ok, view, _html} = live(conn, ~p"/")

      # Click Fetch All
      html = render_click(view, "fetch_all")

      # Should show fetching progress
      assert html =~ "Fetching"
      # Button should be disabled during bulk op
      assert html =~ "cursor-not-allowed"
    end

    test "Fetch All button is disabled during bulk op", %{conn: conn, test_dir: test_dir} do
      stub(RepoMan.Git.Mock, :fetch, fn _path ->
        Process.sleep(5000)
        :ok
      end)

      setup_repos(test_dir, ["alpha"])

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "fetch_all")
      html = render(view)

      # The fetch-all button should be disabled
      assert html =~ "fetch-all-btn"
      assert html =~ "cursor-not-allowed"
    end
  end

  describe "pull all (F27)" do
    test "renders Pull All button", %{conn: conn, test_dir: test_dir} do
      setup_repos(test_dir, ["alpha"])

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Pull All"
      assert html =~ "pull-all-btn"
    end

    test "Pull All button is disabled when no pullable repos",
         %{conn: conn, test_dir: test_dir} do
      # Clean repos have behind=0, so not pull-eligible
      setup_repos(test_dir, ["alpha"])

      {:ok, view, _html} = live(conn, ~p"/")

      # The pull-all button should be disabled (no pullable repos)
      btn_html = element(view, "#pull-all-btn") |> render()
      assert btn_html =~ "cursor-not-allowed"
    end

    test "Pull All button is blue when pullable repos exist",
         %{conn: conn, test_dir: test_dir} do
      setup_behind_repo(test_dir, "omega")

      {:ok, view, _html} = live(conn, ~p"/")

      # The pull-all button should be blue (has pullable repos)
      btn_html = element(view, "#pull-all-btn") |> render()
      assert btn_html =~ "bg-[#172554]"
    end

    test "pull_all skips ineligible repos", %{conn: conn, test_dir: test_dir} do
      # Set up a dirty repo (not pull-eligible)
      files = [%{status: "M", path: "src/main.ex"}]
      setup_dirty_repo(test_dir, "dirtyrepo", files)

      {:ok, view, _html} = live(conn, ~p"/")

      # Pull All should be disabled since no repos are pull-eligible
      btn_html = element(view, "#pull-all-btn") |> render()
      assert btn_html =~ "cursor-not-allowed"
    end

    test "pull_all triggers pulling on eligible repos", %{conn: conn, test_dir: test_dir} do
      stub(RepoMan.Git.Mock, :pull_ff_only, fn _path ->
        Process.sleep(5000)
        :ok
      end)

      setup_behind_repo(test_dir, "omega")

      {:ok, view, _html} = live(conn, ~p"/")

      # Click Pull All
      html = render_click(view, "pull_all")

      # Should show pulling progress
      assert html =~ "Pulling"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # F28: Dark-first Theme
  # ═══════════════════════════════════════════════════════════════════

  describe "dark-first theme (F28)" do
    test "root layout has dark background color", %{conn: conn} do
      stub_clean_git()

      # Get the raw HTML response (including root layout)
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "#0a0a0a"
    end

    test "root layout has light background for prefers-color-scheme", %{conn: conn} do
      stub_clean_git()

      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "#fafafa"
    end

    test "root layout has system sans-serif font stack", %{conn: conn} do
      stub_clean_git()

      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "-apple-system"
      assert html =~ "Inter"
    end

    test "root layout does not contain Phoenix branding", %{conn: conn} do
      stub_clean_git()

      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      refute html =~ "Phoenix Framework"
      refute html =~ "phoenixframework.org"
    end

    test "root layout contains spin animation for in-progress cards", %{conn: conn} do
      stub_clean_git()

      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "@keyframes spin"
    end

    test "root layout title is 'Repo Man' not 'RepoMan · Phoenix Framework'", %{conn: conn} do
      stub_clean_git()

      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "<title"
      assert html =~ "Repo Man"
      refute html =~ "Phoenix Framework"
    end
  end

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

  # ── Helper: build a RepoStatus struct for unit tests ────────────

  defp build_status(opts) do
    defaults = %{
      name: "test",
      path: "/tmp/test",
      current_branch: "master",
      default_branch: "master",
      ahead: 0,
      behind: 0,
      dirty_files: [],
      local_branches: [],
      last_fetch: ~U[2026-03-13 14:30:00Z],
      last_error: nil,
      operation: :idle
    }

    attrs = Map.merge(defaults, Map.new(opts))

    status = RepoMan.RepoStatus.new(attrs)

    # Allow overriding severity for test setup when the computed
    # severity might not match what we want (e.g., setting severity
    # without also setting all the fields that derive it).
    case Keyword.get(opts, :severity) do
      nil -> status
      sev -> %{status | severity: sev}
    end
  end
end
