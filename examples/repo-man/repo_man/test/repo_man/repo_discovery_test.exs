defmodule RepoMan.RepoDiscoveryTest do
  use ExUnit.Case, async: true

  import Mox

  @moduletag :integration
  @moduletag :tmp_dir

  alias RepoMan.RepoDiscovery

  # RepoDiscovery uses @git_module which compiles to Git.Mock in test env.
  # For integration tests we stub the mock to pass through to the real Git.
  setup :verify_on_exit!

  setup do
    stub(RepoMan.Git.Mock, :repo?, &RepoMan.Git.repo?/1)
    :ok
  end

  # Helper: create a minimal git repo (git init) at the given path
  defp create_git_repo(path) do
    File.mkdir_p!(path)
    System.cmd("git", ["init", "-b", "master"], cd: path)
  end

  # Helper: create a plain directory (no .git)
  defp create_plain_dir(path) do
    File.mkdir_p!(path)
  end

  describe "scan/1" do
    test "discovers git repos in a directory", %{tmp_dir: tmp_dir} do
      create_git_repo(Path.join(tmp_dir, "alpha"))
      create_git_repo(Path.join(tmp_dir, "bravo"))
      create_plain_dir(Path.join(tmp_dir, "not-a-repo"))

      result = RepoDiscovery.scan(tmp_dir)

      assert length(result) == 2
      assert Enum.any?(result, &(&1.name == "alpha"))
      assert Enum.any?(result, &(&1.name == "bravo"))
      refute Enum.any?(result, &(&1.name == "not-a-repo"))
    end

    test "returns maps with :name and :path keys", %{tmp_dir: tmp_dir} do
      create_git_repo(Path.join(tmp_dir, "my-repo"))

      [repo] = RepoDiscovery.scan(tmp_dir)

      assert repo.name == "my-repo"
      assert repo.path == Path.join(tmp_dir, "my-repo")
    end

    test "returns empty list for empty directory", %{tmp_dir: tmp_dir} do
      assert RepoDiscovery.scan(tmp_dir) == []
    end

    test "ignores hidden directories", %{tmp_dir: tmp_dir} do
      create_git_repo(Path.join(tmp_dir, ".hidden-repo"))
      create_git_repo(Path.join(tmp_dir, "visible-repo"))

      result = RepoDiscovery.scan(tmp_dir)

      assert length(result) == 1
      assert hd(result).name == "visible-repo"
    end

    test "returns sorted by name", %{tmp_dir: tmp_dir} do
      create_git_repo(Path.join(tmp_dir, "zulu"))
      create_git_repo(Path.join(tmp_dir, "alpha"))
      create_git_repo(Path.join(tmp_dir, "mike"))

      result = RepoDiscovery.scan(tmp_dir)

      names = Enum.map(result, & &1.name)
      assert names == ["alpha", "mike", "zulu"]
    end

    test "returns empty list for nonexistent path", %{tmp_dir: tmp_dir} do
      nonexistent = Path.join(tmp_dir, "does-not-exist")

      assert RepoDiscovery.scan(nonexistent) == []
    end
  end
end
