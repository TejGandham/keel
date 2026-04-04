defmodule RepoMan.GitTest do
  use ExUnit.Case, async: true

  @moduletag :integration
  @moduletag :tmp_dir

  # Configure git identity in a repo so commits work in CI/Docker environments
  defp git_config_identity(repo) do
    System.cmd("git", ["config", "user.email", "test@example.com"], cd: repo)
    System.cmd("git", ["config", "user.name", "Test"], cd: repo)
  end

  describe "repo?/1" do
    test "returns true for directory with .git subdirectory", %{tmp_dir: tmp_dir} do
      repo_path = Path.join(tmp_dir, "real-repo")
      File.mkdir_p!(Path.join(repo_path, ".git"))

      assert RepoMan.Git.repo?(repo_path) == true
    end

    test "returns true for directory with .git file (worktree)", %{tmp_dir: tmp_dir} do
      repo_path = Path.join(tmp_dir, "worktree-repo")
      File.mkdir_p!(repo_path)
      File.write!(Path.join(repo_path, ".git"), "gitdir: /some/other/repo/.git/worktrees/wt")

      assert RepoMan.Git.repo?(repo_path) == true
    end

    test "returns false for plain directory without .git", %{tmp_dir: tmp_dir} do
      plain_dir = Path.join(tmp_dir, "plain-dir")
      File.mkdir_p!(plain_dir)

      assert RepoMan.Git.repo?(plain_dir) == false
    end

    test "returns false for nonexistent path", %{tmp_dir: tmp_dir} do
      nonexistent = Path.join(tmp_dir, "does-not-exist")

      assert RepoMan.Git.repo?(nonexistent) == false
    end

    test "returns false for path that is a file", %{tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "just-a-file.txt")
      File.write!(file_path, "not a repo")

      assert RepoMan.Git.repo?(file_path) == false
    end
  end

  describe "current_branch/1" do
    test "returns {:ok, \"master\"} for repo initialized on master", %{tmp_dir: tmp_dir} do
      repo = Path.join(tmp_dir, "master-repo")
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "master"], cd: repo)

      assert RepoMan.Git.current_branch(repo) == {:ok, "master"}
    end

    test "returns {:ok, \"feature-branch\"} after checkout -b", %{tmp_dir: tmp_dir} do
      repo = Path.join(tmp_dir, "feature-repo")
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "master"], cd: repo)
      git_config_identity(repo)
      # Need at least one commit so checkout -b works
      System.cmd("git", ["commit", "--allow-empty", "-m", "init"], cd: repo)
      System.cmd("git", ["checkout", "-b", "feature-branch"], cd: repo)

      assert RepoMan.Git.current_branch(repo) == {:ok, "feature-branch"}
    end

    test "returns {:error, _} for non-git directory", %{tmp_dir: tmp_dir} do
      plain = Path.join(tmp_dir, "not-a-repo")
      File.mkdir_p!(plain)

      assert {:error, _reason} = RepoMan.Git.current_branch(plain)
    end
  end

  describe "default_branch/1" do
    test "returns {:ok, \"master\"} when symbolic-ref origin/HEAD points to master", %{
      tmp_dir: tmp_dir
    } do
      # Create a bare "remote" repo with master as default
      origin = Path.join(tmp_dir, "origin-repo.git")
      System.cmd("git", ["init", "--bare", "-b", "master", origin])

      # Clone it so origin/HEAD is set automatically
      repo = Path.join(tmp_dir, "cloned-repo")
      System.cmd("git", ["clone", origin, repo])

      assert RepoMan.Git.default_branch(repo) == {:ok, "master"}
    end

    test "falls back to \"master\" when no origin/HEAD but master branch exists", %{
      tmp_dir: tmp_dir
    } do
      repo = Path.join(tmp_dir, "local-master-repo")
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "master"], cd: repo)
      git_config_identity(repo)
      # Need a commit so the branch actually exists in refs
      System.cmd("git", ["commit", "--allow-empty", "-m", "init"], cd: repo)

      assert RepoMan.Git.default_branch(repo) == {:ok, "master"}
    end

    test "falls back to \"main\" when no master exists but main does", %{tmp_dir: tmp_dir} do
      repo = Path.join(tmp_dir, "local-main-repo")
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "main"], cd: repo)
      git_config_identity(repo)
      # Need a commit so the branch actually exists in refs
      System.cmd("git", ["commit", "--allow-empty", "-m", "init"], cd: repo)

      assert RepoMan.Git.default_branch(repo) == {:ok, "main"}
    end

    test "returns {:error, _} when no origin/HEAD, no master, no main", %{tmp_dir: tmp_dir} do
      repo = Path.join(tmp_dir, "no-default-repo")
      File.mkdir_p!(repo)
      # Init on a non-standard branch name
      System.cmd("git", ["init", "-b", "develop"], cd: repo)
      git_config_identity(repo)
      System.cmd("git", ["commit", "--allow-empty", "-m", "init"], cd: repo)

      assert {:error, _reason} = RepoMan.Git.default_branch(repo)
    end
  end

  describe "ahead_behind/2" do
    # Helper: create a bare remote, clone it, and return {origin, clone} paths.
    # The clone starts with one commit on master so rev-parse works.
    defp setup_remote_and_clone(tmp_dir, name) do
      origin = Path.join(tmp_dir, "#{name}-origin.git")
      clone = Path.join(tmp_dir, "#{name}-clone")

      # Create bare remote with an initial commit via a temp repo
      tmp_init = Path.join(tmp_dir, "#{name}-tmp-init")
      File.mkdir_p!(tmp_init)
      System.cmd("git", ["init", "-b", "master", tmp_init])
      git_config_identity(tmp_init)
      System.cmd("git", ["commit", "--allow-empty", "-m", "seed"], cd: tmp_init)
      System.cmd("git", ["clone", "--bare", tmp_init, origin])

      # Clone from bare remote
      System.cmd("git", ["clone", origin, clone])
      git_config_identity(clone)

      {origin, clone}
    end

    # Helper: push a commit to the bare remote from a temporary working copy,
    # so the clone falls behind without the clone knowing.
    defp push_commit_to_remote(tmp_dir, origin, name) do
      pusher = Path.join(tmp_dir, "#{name}-pusher")
      System.cmd("git", ["clone", origin, pusher])
      git_config_identity(pusher)
      System.cmd("git", ["commit", "--allow-empty", "-m", "remote advance"], cd: pusher)
      System.cmd("git", ["push"], cd: pusher)
    end

    test "returns {:ok, {0, 0}} when clone is in sync with origin", %{tmp_dir: tmp_dir} do
      {_origin, clone} = setup_remote_and_clone(tmp_dir, "sync")

      assert RepoMan.Git.ahead_behind(clone, "master") == {:ok, {0, 0}}
    end

    test "returns {:ok, {0, N}} when behind origin", %{tmp_dir: tmp_dir} do
      {origin, clone} = setup_remote_and_clone(tmp_dir, "behind")

      # Push 2 commits to remote from a separate working copy
      push_commit_to_remote(tmp_dir, origin, "behind-push1")
      push_commit_to_remote(tmp_dir, origin, "behind-push2")

      # Fetch so the clone knows about the new remote commits
      System.cmd("git", ["fetch"], cd: clone)

      assert RepoMan.Git.ahead_behind(clone, "master") == {:ok, {0, 2}}
    end

    test "returns {:ok, {N, 0}} when ahead of origin", %{tmp_dir: tmp_dir} do
      {_origin, clone} = setup_remote_and_clone(tmp_dir, "ahead")

      # Make 3 local commits without pushing
      System.cmd("git", ["commit", "--allow-empty", "-m", "local 1"], cd: clone)
      System.cmd("git", ["commit", "--allow-empty", "-m", "local 2"], cd: clone)
      System.cmd("git", ["commit", "--allow-empty", "-m", "local 3"], cd: clone)

      assert RepoMan.Git.ahead_behind(clone, "master") == {:ok, {3, 0}}
    end

    test "returns {:ok, {N, M}} when diverged", %{tmp_dir: tmp_dir} do
      {origin, clone} = setup_remote_and_clone(tmp_dir, "diverged")

      # Push 1 commit to remote from a separate working copy
      push_commit_to_remote(tmp_dir, origin, "diverge-push")

      # Make 2 local commits without pushing
      System.cmd("git", ["commit", "--allow-empty", "-m", "local a"], cd: clone)
      System.cmd("git", ["commit", "--allow-empty", "-m", "local b"], cd: clone)

      # Fetch so the clone sees the remote commit
      System.cmd("git", ["fetch"], cd: clone)

      assert RepoMan.Git.ahead_behind(clone, "master") == {:ok, {2, 1}}
    end

    test "returns {:error, _} for non-git directory", %{tmp_dir: tmp_dir} do
      plain = Path.join(tmp_dir, "not-a-repo")
      File.mkdir_p!(plain)

      assert {:error, _reason} = RepoMan.Git.ahead_behind(plain, "master")
    end
  end

  describe "dirty_files/1" do
    # Helper: init a repo with one commit so it's not bare/empty
    defp init_repo_with_commit(tmp_dir, name) do
      repo = Path.join(tmp_dir, name)
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "master"], cd: repo)
      git_config_identity(repo)
      File.write!(Path.join(repo, "README.md"), "# init")
      System.cmd("git", ["add", "."], cd: repo)
      System.cmd("git", ["commit", "-m", "initial"], cd: repo)
      repo
    end

    test "returns {:ok, []} for a clean repo", %{tmp_dir: tmp_dir} do
      repo = init_repo_with_commit(tmp_dir, "clean-repo")

      assert RepoMan.Git.dirty_files(repo) == {:ok, []}
    end

    test "returns modified file with M status", %{tmp_dir: tmp_dir} do
      repo = init_repo_with_commit(tmp_dir, "modified-repo")

      # Modify an existing tracked file
      File.write!(Path.join(repo, "README.md"), "# changed")

      assert {:ok, files} = RepoMan.Git.dirty_files(repo)
      assert length(files) == 1
      assert %{status: "M", path: "README.md"} in files
    end

    test "returns untracked file with ?? status", %{tmp_dir: tmp_dir} do
      repo = init_repo_with_commit(tmp_dir, "untracked-repo")

      # Create an untracked file
      File.write!(Path.join(repo, "new_file.txt"), "hello")

      assert {:ok, files} = RepoMan.Git.dirty_files(repo)
      assert length(files) == 1
      assert %{status: "??", path: "new_file.txt"} in files
    end

    test "returns multiple dirty files with correct statuses", %{tmp_dir: tmp_dir} do
      repo = init_repo_with_commit(tmp_dir, "multi-dirty-repo")

      # Modify a tracked file
      File.write!(Path.join(repo, "README.md"), "# changed")
      # Create an untracked file
      File.write!(Path.join(repo, "untracked.txt"), "new")

      assert {:ok, files} = RepoMan.Git.dirty_files(repo)
      assert length(files) == 2
      assert %{status: "M", path: "README.md"} in files
      assert %{status: "??", path: "untracked.txt"} in files
    end

    test "returns staged file with appropriate status", %{tmp_dir: tmp_dir} do
      repo = init_repo_with_commit(tmp_dir, "staged-repo")

      # Create and stage a new file
      File.write!(Path.join(repo, "staged.txt"), "staged content")
      System.cmd("git", ["add", "staged.txt"], cd: repo)

      assert {:ok, files} = RepoMan.Git.dirty_files(repo)
      assert length(files) == 1
      assert %{status: "A", path: "staged.txt"} in files
    end

    test "returns {:error, _} for non-git directory", %{tmp_dir: tmp_dir} do
      plain = Path.join(tmp_dir, "not-a-git-dir")
      File.mkdir_p!(plain)

      assert {:error, _reason} = RepoMan.Git.dirty_files(plain)
    end
  end

  describe "local_branches/1" do
    test "returns {:ok, []} when only one branch exists (current)", %{tmp_dir: tmp_dir} do
      repo = Path.join(tmp_dir, "single-branch-repo")
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "master"], cd: repo)
      git_config_identity(repo)
      System.cmd("git", ["commit", "--allow-empty", "-m", "init"], cd: repo)

      assert RepoMan.Git.local_branches(repo) == {:ok, []}
    end

    test "returns {:ok, [branches]} excluding current branch when multiple branches exist", %{
      tmp_dir: tmp_dir
    } do
      repo = Path.join(tmp_dir, "multi-branch-repo")
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "master"], cd: repo)
      git_config_identity(repo)
      System.cmd("git", ["commit", "--allow-empty", "-m", "init"], cd: repo)
      System.cmd("git", ["branch", "feature-a"], cd: repo)
      System.cmd("git", ["branch", "feature-b"], cd: repo)

      assert {:ok, branches} = RepoMan.Git.local_branches(repo)
      assert Enum.sort(branches) == ["feature-a", "feature-b"]
      refute "master" in branches
    end

    test "returns {:error, _} for non-git directory", %{tmp_dir: tmp_dir} do
      plain = Path.join(tmp_dir, "not-a-git-dir-branches")
      File.mkdir_p!(plain)

      assert {:error, _reason} = RepoMan.Git.local_branches(plain)
    end
  end

  describe "fetch/1" do
    # Helper: create a bare remote with one commit, clone it, return {origin, clone}.
    defp setup_fetch_remote_and_clone(tmp_dir, name) do
      origin = Path.join(tmp_dir, "#{name}-origin.git")
      clone = Path.join(tmp_dir, "#{name}-clone")

      tmp_init = Path.join(tmp_dir, "#{name}-tmp-init")
      File.mkdir_p!(tmp_init)
      System.cmd("git", ["init", "-b", "master", tmp_init])
      git_config_identity(tmp_init)
      System.cmd("git", ["commit", "--allow-empty", "-m", "seed"], cd: tmp_init)
      System.cmd("git", ["clone", "--bare", tmp_init, origin])

      System.cmd("git", ["clone", origin, clone])
      git_config_identity(clone)

      {origin, clone}
    end

    test "returns :ok on repo with remote", %{tmp_dir: tmp_dir} do
      {_origin, clone} = setup_fetch_remote_and_clone(tmp_dir, "fetch-ok")

      assert RepoMan.Git.fetch(clone) == :ok
    end

    test "returns :ok on repo without remote (no-op)", %{tmp_dir: tmp_dir} do
      repo = Path.join(tmp_dir, "fetch-no-remote")
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "master"], cd: repo)
      git_config_identity(repo)
      System.cmd("git", ["commit", "--allow-empty", "-m", "init"], cd: repo)

      assert RepoMan.Git.fetch(repo) == :ok
    end
  end

  describe "pull_ff_only/1" do
    # Helper: create a bare remote with one commit, clone it, return {origin, clone}.
    defp setup_pull_remote_and_clone(tmp_dir, name) do
      origin = Path.join(tmp_dir, "#{name}-origin.git")
      clone = Path.join(tmp_dir, "#{name}-clone")

      tmp_init = Path.join(tmp_dir, "#{name}-tmp-init")
      File.mkdir_p!(tmp_init)
      System.cmd("git", ["init", "-b", "master", tmp_init])
      git_config_identity(tmp_init)
      System.cmd("git", ["commit", "--allow-empty", "-m", "seed"], cd: tmp_init)
      System.cmd("git", ["clone", "--bare", tmp_init, origin])

      System.cmd("git", ["clone", origin, clone])
      git_config_identity(clone)

      {origin, clone}
    end

    # Helper: push a commit to the bare remote from a temporary working copy.
    defp push_pull_commit_to_remote(tmp_dir, origin, name) do
      pusher = Path.join(tmp_dir, "#{name}-pusher")
      System.cmd("git", ["clone", origin, pusher])
      git_config_identity(pusher)
      System.cmd("git", ["commit", "--allow-empty", "-m", "remote advance"], cd: pusher)
      System.cmd("git", ["push"], cd: pusher)
    end

    test "returns :ok when fast-forward is possible", %{tmp_dir: tmp_dir} do
      {origin, clone} = setup_pull_remote_and_clone(tmp_dir, "pull-ff")

      # Push a commit to the remote so clone is behind
      push_pull_commit_to_remote(tmp_dir, origin, "pull-ff-push")

      # Fetch so clone knows about the remote commit
      System.cmd("git", ["fetch"], cd: clone)

      assert RepoMan.Git.pull_ff_only(clone) == :ok
    end

    test "returns {:error, _} when fast-forward is not possible (diverged)", %{
      tmp_dir: tmp_dir
    } do
      {origin, clone} = setup_pull_remote_and_clone(tmp_dir, "pull-diverge")

      # Push a commit to the remote
      push_pull_commit_to_remote(tmp_dir, origin, "pull-diverge-push")

      # Make a local commit to cause divergence
      System.cmd("git", ["commit", "--allow-empty", "-m", "local diverge"], cd: clone)

      # Fetch so clone sees the remote commit
      System.cmd("git", ["fetch"], cd: clone)

      assert {:error, _reason} = RepoMan.Git.pull_ff_only(clone)
    end
  end

  describe "last_fetch_time/1" do
    test "returns {:ok, nil} when no FETCH_HEAD exists", %{tmp_dir: tmp_dir} do
      repo = Path.join(tmp_dir, "never-fetched")
      File.mkdir_p!(repo)
      System.cmd("git", ["init", "-b", "master"], cd: repo)
      git_config_identity(repo)
      System.cmd("git", ["commit", "--allow-empty", "-m", "init"], cd: repo)

      assert RepoMan.Git.last_fetch_time(repo) == {:ok, nil}
    end

    test "returns {:ok, %DateTime{}} after a fetch creates FETCH_HEAD", %{tmp_dir: tmp_dir} do
      origin = Path.join(tmp_dir, "lft-origin.git")
      clone = Path.join(tmp_dir, "lft-clone")

      tmp_init = Path.join(tmp_dir, "lft-tmp-init")
      File.mkdir_p!(tmp_init)
      System.cmd("git", ["init", "-b", "master", tmp_init])
      git_config_identity(tmp_init)
      System.cmd("git", ["commit", "--allow-empty", "-m", "seed"], cd: tmp_init)
      System.cmd("git", ["clone", "--bare", tmp_init, origin])
      System.cmd("git", ["clone", origin, clone])

      # Perform a fetch to create FETCH_HEAD
      System.cmd("git", ["fetch"], cd: clone)

      assert {:ok, %DateTime{} = dt} = RepoMan.Git.last_fetch_time(clone)
      # The fetch just happened, so the time should be very recent (within 60 seconds)
      assert DateTime.diff(DateTime.utc_now(), dt, :second) < 60
    end

    test "returns {:error, _} for non-git directory", %{tmp_dir: tmp_dir} do
      plain = Path.join(tmp_dir, "not-a-git-dir-fetch-time")
      File.mkdir_p!(plain)

      assert {:error, _reason} = RepoMan.Git.last_fetch_time(plain)
    end
  end
end
