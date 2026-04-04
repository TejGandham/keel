defmodule RepoMan.GitSafetyTest do
  use ExUnit.Case, async: true

  @moduletag :integration
  @moduletag :tmp_dir

  alias RepoMan.GitBuilder
  alias RepoMan.RepoStatus

  # ---------------------------------------------------------------------------
  # Helpers — raw git commands for assertion verification
  # ---------------------------------------------------------------------------

  defp porcelain_output(path) do
    {output, 0} = System.cmd("git", ["status", "--porcelain"], cd: path)
    output
  end

  defp ahead_count(path, remote_branch) do
    {count_str, 0} =
      System.cmd("git", ["rev-list", "--count", "#{remote_branch}..HEAD"], cd: path)

    String.trim(count_str) |> String.to_integer()
  end

  defp behind_count(path, remote_branch) do
    {count_str, 0} =
      System.cmd("git", ["rev-list", "--count", "HEAD..#{remote_branch}"], cd: path)

    String.trim(count_str) |> String.to_integer()
  end

  # Base attrs for building minimal RepoStatus structs without I/O
  defp base_attrs do
    %{
      name: "test-repo",
      path: "/tmp/test-repo",
      current_branch: "master",
      default_branch: "master",
      ahead: 0,
      behind: 0,
      dirty_files: [],
      local_branches: [],
      last_fetch: nil,
      last_error: nil,
      operation: :idle
    }
  end

  # ---------------------------------------------------------------------------
  # Group 1 — Source-level invariant: no --force in git.ex
  # ---------------------------------------------------------------------------

  describe "source-level: no --force or --rebase flags" do
    test "git.ex source contains no occurrence of --force" do
      source = File.read!("/app/lib/repo_man/git.ex")
      refute String.contains?(source, "--force"),
             "git.ex must never use --force; found occurrence in source"
    end

    test "git.ex source does not contain --force-with-lease either" do
      source = File.read!("/app/lib/repo_man/git.ex")
      refute String.contains?(source, "--force-with-lease"),
             "git.ex must never use --force-with-lease; found occurrence in source"
    end

    test "git.ex source contains no occurrence of --rebase" do
      source = File.read!("/app/lib/repo_man/git.ex")
      refute String.contains?(source, "--rebase"),
             "git.ex must never use --rebase; found occurrence in source"
    end
  end

  # ---------------------------------------------------------------------------
  # Group 2 — --ff-only always used on pull
  # ---------------------------------------------------------------------------

  describe "--ff-only always used on pull" do
    test "git.ex source contains --ff-only" do
      source = File.read!("/app/lib/repo_man/git.ex")
      assert String.contains?(source, "--ff-only"),
             "git.ex pull_ff_only/1 must use --ff-only flag"
    end

    test "pull_ff_only/1 succeeds and advances HEAD on a :behind repo", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :behind)

      behind_before = behind_count(path, "origin/master")
      assert behind_before > 0

      assert RepoMan.Git.pull_ff_only(path) == :ok

      behind_after = behind_count(path, "origin/master")
      assert behind_after == 0
    end

    test "pull_ff_only/1 returns {:error, _} on a :diverged repo (ff not possible)", %{
      tmp_dir: tmp_dir
    } do
      path = GitBuilder.build(tmp_dir, :diverged)

      ahead_before = ahead_count(path, "origin/master")
      assert ahead_before > 0

      assert {:error, _reason} = RepoMan.Git.pull_ff_only(path)

      # Working tree must be unchanged — local ahead commits still there
      ahead_after = ahead_count(path, "origin/master")
      assert ahead_after > 0
    end
  end

  # ---------------------------------------------------------------------------
  # Group 3 — Pull rejected when dirty
  # ---------------------------------------------------------------------------

  describe "pull rejected when dirty" do
    test "pull_eligible? is false when dirty_count > 0", _ctx do
      status =
        RepoStatus.new(
          Map.merge(base_attrs(), %{
            dirty_files: [%{status: "??", path: "dirty.txt"}],
            behind: 1
          })
        )

      assert status.pull_eligible? == false
      assert status.dirty_count > 0
    end

    test "dirty files are still present after pull_ff_only/1 on :dirty repo", %{
      tmp_dir: tmp_dir
    } do
      path = GitBuilder.build(tmp_dir, :dirty)

      dirty_before = porcelain_output(path)
      assert String.trim(dirty_before) != ""

      # pull_ff_only may succeed or fail (dirty repos can still be fast-forwarded
      # if there are no conflicting tracked changes), but the dirty files must remain
      _result = RepoMan.Git.pull_ff_only(path)

      dirty_after = porcelain_output(path)
      assert String.trim(dirty_after) != "",
             "Dirty files were unexpectedly cleaned by pull_ff_only/1"
    end
  end

  # ---------------------------------------------------------------------------
  # Group 4 — Pull rejected when diverged
  # ---------------------------------------------------------------------------

  describe "pull rejected when diverged" do
    test "pull_eligible? is false when ahead > 0 AND behind > 0", _ctx do
      status =
        RepoStatus.new(
          Map.merge(base_attrs(), %{
            ahead: 1,
            behind: 1
          })
        )

      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "Diverged"
    end

    test "pull_ff_only/1 returns {:error, _} on diverged repo", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :diverged)

      assert {:error, _reason} = RepoMan.Git.pull_ff_only(path)
    end

    test "local ahead commits remain after failed pull_ff_only/1 on :diverged repo", %{
      tmp_dir: tmp_dir
    } do
      path = GitBuilder.build(tmp_dir, :diverged)

      ahead_before = ahead_count(path, "origin/master")
      assert ahead_before > 0

      {:error, _} = RepoMan.Git.pull_ff_only(path)

      ahead_after = ahead_count(path, "origin/master")
      assert ahead_after > 0,
             "Local commits were lost after failed ff-only pull — working tree was modified"
    end
  end

  # ---------------------------------------------------------------------------
  # Group 5 — Pull rejected when not on default branch
  # ---------------------------------------------------------------------------

  describe "pull rejected when not on default branch" do
    test "pull_eligible? is false when on_default? is false", _ctx do
      status =
        RepoStatus.new(
          Map.merge(base_attrs(), %{
            current_branch: "topic-branch",
            default_branch: "master",
            behind: 1
          })
        )

      assert status.on_default? == false
      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "switch to"
    end

    test "pull_eligible? is false for :topic_branch repo status", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :topic_branch)

      {current_branch, 0} = System.cmd("git", ["branch", "--show-current"], cd: path)
      current_branch = String.trim(current_branch)

      # topic-branch has no remote, so we use "master" as default_branch
      status =
        RepoStatus.new(%{
          name: "topic-repo",
          path: path,
          current_branch: current_branch,
          default_branch: "master",
          ahead: 0,
          behind: 1,
          dirty_files: [],
          local_branches: [],
          last_fetch: nil,
          last_error: nil,
          operation: :idle
        })

      assert status.on_default? == false
      assert status.pull_eligible? == false
    end
  end

  # ---------------------------------------------------------------------------
  # Group 6 — Pull rejected when not behind (already up to date)
  # ---------------------------------------------------------------------------

  describe "pull rejected when not behind" do
    test "pull_eligible? is false when behind == 0", _ctx do
      status =
        RepoStatus.new(
          Map.merge(base_attrs(), %{
            ahead: 0,
            behind: 0
          })
        )

      assert status.behind == 0
      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "up to date"
    end

    test "pull_eligible? is false for :clean repo status (already up to date)", %{
      tmp_dir: tmp_dir
    } do
      path = GitBuilder.build(tmp_dir, :clean)

      # clean repo has no remote; behind == 0 always
      status =
        RepoStatus.new(%{
          name: "clean-repo",
          path: path,
          current_branch: "master",
          default_branch: "master",
          ahead: 0,
          behind: 0,
          dirty_files: [],
          local_branches: [],
          last_fetch: nil,
          last_error: nil,
          operation: :idle
        })

      assert status.pull_eligible? == false
    end
  end

  # ---------------------------------------------------------------------------
  # Group 7 — No working tree modification beyond ff-only pull
  # ---------------------------------------------------------------------------

  describe "no working tree modification beyond ff-only pull" do
    test "fetch/1 does not modify the working tree of a :dirty repo", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :dirty)

      dirty_before = porcelain_output(path)
      assert String.trim(dirty_before) != ""

      assert RepoMan.Git.fetch(path) == :ok

      dirty_after = porcelain_output(path)
      assert dirty_after == dirty_before,
             "fetch/1 modified the working tree: before=#{inspect(dirty_before)} after=#{inspect(dirty_after)}"
    end

    test "fetch/1 returns :ok on a :clean repo", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :clean)

      # clean repo has no remote, fetch is a no-op
      assert RepoMan.Git.fetch(path) == :ok
    end

    test "fetch/1 does not modify the working tree of a :behind repo", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :behind)

      porcelain_before = porcelain_output(path)

      assert RepoMan.Git.fetch(path) == :ok

      porcelain_after = porcelain_output(path)
      assert porcelain_after == porcelain_before,
             "fetch/1 modified the working tree on a :behind repo"
    end

    test "fetch/1 does not modify the working tree of a :diverged repo", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :diverged)

      porcelain_before = porcelain_output(path)

      assert RepoMan.Git.fetch(path) == :ok

      porcelain_after = porcelain_output(path)
      assert porcelain_after == porcelain_before,
             "fetch/1 modified the working tree on a :diverged repo"
    end
  end
end
