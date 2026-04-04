defmodule RepoMan.GitBuilder do
  @moduledoc """
  Test helper that builds real git repositories in various states.

  Used by integration tests to create fixture repos under a tmp_dir.
  Each call to `build/2` returns the path to a freshly created repo
  in the requested state, with a unique subdirectory name to avoid collisions.

  ## States

  - `:clean` — repo with at least one commit, clean working tree
  - `:dirty` — repo with at least one commit plus uncommitted changes
  - `:behind` — cloned repo that is behind origin/master (ahead count 0)
  - `:diverged` — cloned repo with local commits AND remote-only commits
  - `:topic_branch` — repo on a branch that is not master or main
  """

  @doc """
  Builds a git repository in the given state under `tmp_dir`.

  Returns the absolute path to the created repository.
  """
  @spec build(String.t(), atom()) :: String.t()
  def build(tmp_dir, state) when is_binary(tmp_dir) and is_atom(state) do
    case state do
      :clean -> build_clean(tmp_dir)
      :dirty -> build_dirty(tmp_dir)
      :behind -> build_behind(tmp_dir)
      :diverged -> build_diverged(tmp_dir)
      :topic_branch -> build_topic_branch(tmp_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # State builders
  # ---------------------------------------------------------------------------

  defp build_clean(tmp_dir) do
    repo = unique_path(tmp_dir, "clean")
    init_repo_with_commit(repo)
    repo
  end

  defp build_dirty(tmp_dir) do
    repo = unique_path(tmp_dir, "dirty")
    init_repo_with_commit(repo)

    # Create an untracked file to make the working tree dirty
    File.write!(Path.join(repo, "dirty.txt"), "uncommitted change")
    repo
  end

  defp build_behind(tmp_dir) do
    suffix = unique_suffix()
    origin_path = Path.join(tmp_dir, "behind-origin-#{suffix}.git")
    clone_path = Path.join(tmp_dir, "behind-clone-#{suffix}")

    # Create bare remote with a seed commit
    {origin_path, _tmp_init} = create_bare_remote(tmp_dir, origin_path, "behind-init-#{suffix}")

    # Clone from bare remote
    git!(["clone", origin_path, clone_path])
    git_config_identity(clone_path)

    # Push an extra commit to origin from a separate working copy
    pusher = Path.join(tmp_dir, "behind-pusher-#{suffix}")
    git!(["clone", origin_path, pusher])
    git_config_identity(pusher)
    git!(["commit", "--allow-empty", "-m", "remote advance"], pusher)
    git!(["push"], pusher)

    # Fetch so the clone sees the new remote commit, but do NOT merge/pull
    git!(["fetch"], clone_path)

    clone_path
  end

  defp build_diverged(tmp_dir) do
    suffix = unique_suffix()
    origin_path = Path.join(tmp_dir, "diverged-origin-#{suffix}.git")
    clone_path = Path.join(tmp_dir, "diverged-clone-#{suffix}")

    # Create bare remote with a seed commit
    {origin_path, _tmp_init} = create_bare_remote(tmp_dir, origin_path, "diverged-init-#{suffix}")

    # Clone from bare remote
    git!(["clone", origin_path, clone_path])
    git_config_identity(clone_path)

    # Push a commit to origin from a separate working copy (creates remote-only commit)
    pusher = Path.join(tmp_dir, "diverged-pusher-#{suffix}")
    git!(["clone", origin_path, pusher])
    git_config_identity(pusher)
    git!(["commit", "--allow-empty", "-m", "remote diverge"], pusher)
    git!(["push"], pusher)

    # Make a local commit on the clone (creates local-only commit)
    git!(["commit", "--allow-empty", "-m", "local diverge"], clone_path)

    # Fetch so the clone sees the remote divergence
    git!(["fetch"], clone_path)

    clone_path
  end

  defp build_topic_branch(tmp_dir) do
    repo = unique_path(tmp_dir, "topic")
    init_repo_with_commit(repo)

    # Create and switch to a topic branch
    git!(["checkout", "-b", "topic-branch"], repo)

    repo
  end

  # ---------------------------------------------------------------------------
  # Primitives
  # ---------------------------------------------------------------------------

  defp init_repo_with_commit(repo) do
    File.mkdir_p!(repo)
    git!(["init", "-b", "master"], repo)
    git_config_identity(repo)
    File.write!(Path.join(repo, "README.md"), "# init")
    git!(["add", "."], repo)
    git!(["commit", "-m", "initial"], repo)
  end

  defp create_bare_remote(tmp_dir, origin_path, init_name) do
    tmp_init = Path.join(tmp_dir, init_name)
    File.mkdir_p!(tmp_init)
    git!(["init", "-b", "master", tmp_init])
    git_config_identity(tmp_init)
    git!(["commit", "--allow-empty", "-m", "seed"], tmp_init)
    git!(["clone", "--bare", tmp_init, origin_path])
    {origin_path, tmp_init}
  end

  defp git_config_identity(repo) do
    git!(["config", "user.email", "test@example.com"], repo)
    git!(["config", "user.name", "Test"], repo)
  end

  defp git!(args, cd \\ nil) do
    opts = if cd, do: [cd: cd, stderr_to_stdout: true], else: [stderr_to_stdout: true]
    {output, exit_code} = System.cmd("git", args, opts)

    if exit_code != 0 do
      raise "git #{Enum.join(args, " ")} failed (exit #{exit_code}): #{output}"
    end

    output
  end

  defp unique_path(tmp_dir, prefix) do
    Path.join(tmp_dir, "#{prefix}-#{unique_suffix()}")
  end

  defp unique_suffix do
    :erlang.unique_integer([:positive]) |> Integer.to_string()
  end
end
