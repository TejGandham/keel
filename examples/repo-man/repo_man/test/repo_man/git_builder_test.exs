defmodule RepoMan.GitBuilderTest do
  use ExUnit.Case, async: true

  @moduletag :integration
  @moduletag :tmp_dir

  alias RepoMan.GitBuilder

  # ---------------------------------------------------------------------------
  # Helpers — raw git commands only, no application Git module
  # ---------------------------------------------------------------------------

  defp git_repo?(path) do
    File.dir?(Path.join(path, ".git"))
  end

  defp porcelain_output(path) do
    {output, 0} = System.cmd("git", ["status", "--porcelain"], cd: path)
    output
  end

  defp current_branch(path) do
    {branch, 0} = System.cmd("git", ["branch", "--show-current"], cd: path)
    String.trim(branch)
  end

  defp behind_count(path, remote_branch) do
    {count_str, 0} =
      System.cmd("git", ["rev-list", "--count", "HEAD..#{remote_branch}"], cd: path)

    String.trim(count_str) |> String.to_integer()
  end

  defp ahead_count(path, remote_branch) do
    {count_str, 0} =
      System.cmd("git", ["rev-list", "--count", "#{remote_branch}..HEAD"], cd: path)

    String.trim(count_str) |> String.to_integer()
  end

  defp has_any_commit?(path) do
    # git rev-parse HEAD exits 0 only when at least one commit exists
    {_, exit_code} = System.cmd("git", ["rev-parse", "HEAD"], cd: path, stderr_to_stdout: true)
    exit_code == 0
  end

  # ---------------------------------------------------------------------------
  # :clean state
  # ---------------------------------------------------------------------------

  describe "build/2 :clean" do
    test "returns a valid git repo path", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :clean)

      assert is_binary(path)
      assert git_repo?(path)
    end

    test "repo has at least one commit", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :clean)

      assert has_any_commit?(path)
    end

    test "working tree is clean — git status --porcelain is empty", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :clean)

      assert porcelain_output(path) == ""
    end

    test "returned path is a subdirectory of tmp_dir", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :clean)

      assert String.starts_with?(path, tmp_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # :dirty state
  # ---------------------------------------------------------------------------

  describe "build/2 :dirty" do
    test "returns a valid git repo path", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :dirty)

      assert is_binary(path)
      assert git_repo?(path)
    end

    test "git status --porcelain returns at least one line", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :dirty)

      output = porcelain_output(path)
      assert String.trim(output) != ""
      assert length(String.split(output, "\n", trim: true)) >= 1
    end

    test "returned path is a subdirectory of tmp_dir", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :dirty)

      assert String.starts_with?(path, tmp_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # :behind state
  # ---------------------------------------------------------------------------

  describe "build/2 :behind" do
    test "returns a valid git repo path", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :behind)

      assert is_binary(path)
      assert git_repo?(path)
    end

    test "working tree is clean", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :behind)

      assert porcelain_output(path) == ""
    end

    test "behind count > 0 against origin/master after fetch", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :behind)

      # Fetch is already done by GitBuilder, but run it again to be safe
      System.cmd("git", ["fetch"], cd: path)

      behind = behind_count(path, "origin/master")
      assert behind > 0
    end

    test "ahead count is 0 against origin/master", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :behind)

      System.cmd("git", ["fetch"], cd: path)

      ahead = ahead_count(path, "origin/master")
      assert ahead == 0
    end

    test "returned path is a subdirectory of tmp_dir", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :behind)

      assert String.starts_with?(path, tmp_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # :diverged state
  # ---------------------------------------------------------------------------

  describe "build/2 :diverged" do
    test "returns a valid git repo path", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :diverged)

      assert is_binary(path)
      assert git_repo?(path)
    end

    test "working tree is clean", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :diverged)

      assert porcelain_output(path) == ""
    end

    test "behind count > 0 against origin/master after fetch", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :diverged)

      System.cmd("git", ["fetch"], cd: path)

      behind = behind_count(path, "origin/master")
      assert behind > 0
    end

    test "ahead count > 0 against origin/master", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :diverged)

      System.cmd("git", ["fetch"], cd: path)

      ahead = ahead_count(path, "origin/master")
      assert ahead > 0
    end

    test "returned path is a subdirectory of tmp_dir", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :diverged)

      assert String.starts_with?(path, tmp_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # :topic_branch state
  # ---------------------------------------------------------------------------

  describe "build/2 :topic_branch" do
    test "returns a valid git repo path", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :topic_branch)

      assert is_binary(path)
      assert git_repo?(path)
    end

    test "current branch is not master or main", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :topic_branch)

      branch = current_branch(path)
      refute branch == "master"
      refute branch == "main"
      assert branch != ""
    end

    test "working tree is clean", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :topic_branch)

      assert porcelain_output(path) == ""
    end

    test "returned path is a subdirectory of tmp_dir", %{tmp_dir: tmp_dir} do
      path = GitBuilder.build(tmp_dir, :topic_branch)

      assert String.starts_with?(path, tmp_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # No collisions — two sequential calls return distinct paths
  # ---------------------------------------------------------------------------

  describe "build/2 path uniqueness" do
    test "two :clean builds in the same tmp_dir return distinct paths", %{tmp_dir: tmp_dir} do
      path1 = GitBuilder.build(tmp_dir, :clean)
      path2 = GitBuilder.build(tmp_dir, :clean)

      assert path1 != path2
      assert git_repo?(path1)
      assert git_repo?(path2)
    end

    test "two :dirty builds in the same tmp_dir return distinct paths", %{tmp_dir: tmp_dir} do
      path1 = GitBuilder.build(tmp_dir, :dirty)
      path2 = GitBuilder.build(tmp_dir, :dirty)

      assert path1 != path2
    end

    test "different states return distinct paths", %{tmp_dir: tmp_dir} do
      clean = GitBuilder.build(tmp_dir, :clean)
      dirty = GitBuilder.build(tmp_dir, :dirty)
      topic = GitBuilder.build(tmp_dir, :topic_branch)

      paths = [clean, dirty, topic]
      assert length(Enum.uniq(paths)) == 3
    end
  end
end
