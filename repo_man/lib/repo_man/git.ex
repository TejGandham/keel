defmodule RepoMan.Git do
  @moduledoc """
  Real git implementation. Shells out via `System.cmd/3`.

  Pure functions, no state. Used by default in dev/prod.
  In tests, `RepoMan.Git.Mock` (via Mox) replaces this module.
  """

  @behaviour RepoMan.Git.Behaviour

  @impl true
  def repo?(path) do
    git_path = Path.join(path, ".git")
    File.exists?(git_path)
  end

  @impl true
  def current_branch(path) do
    case System.cmd("git", ["branch", "--show-current"], cd: path, stderr_to_stdout: true) do
      {branch, 0} ->
        branch = String.trim(branch)

        if branch == "" do
          {:error, "not on a branch (detached HEAD)"}
        else
          {:ok, branch}
        end

      {output, _code} ->
        {:error, String.trim(output)}
    end
  end

  @impl true
  def default_branch(path) do
    case System.cmd(
           "git",
           ["symbolic-ref", "refs/remotes/origin/HEAD", "--short"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {ref, 0} ->
        branch =
          ref
          |> String.trim()
          |> String.replace(~r{^origin/}, "")

        # Validate that the remote tracking branch actually exists.
        # origin/HEAD can become stale when a remote renames its default branch.
        if remote_tracking_exists?(path, branch) do
          {:ok, branch}
        else
          infer_default_from_remote(path)
        end

      _ ->
        infer_default_from_remote(path)
    end
  end

  # Check remote tracking branches (main before master) since most repos
  # have moved to main. Falls back to config and local branch detection.
  defp infer_default_from_remote(path) do
    cond do
      remote_tracking_exists?(path, "main") -> {:ok, "main"}
      remote_tracking_exists?(path, "master") -> {:ok, "master"}
      true -> fallback_default_branch(path)
    end
  end

  defp remote_tracking_exists?(path, branch) do
    case System.cmd("git", ["rev-parse", "--verify", "refs/remotes/origin/#{branch}"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp fallback_default_branch(path) do
    case config_default_branch(path) do
      {:ok, branch} -> {:ok, branch}
      :none -> local_fallback_default_branch(path)
    end
  end

  # When origin/HEAD symbolic-ref is unavailable (e.g. empty clone),
  # try to infer the default branch from the git config's tracking setup.
  # `git clone` records `branch.<name>.remote = origin` and
  # `branch.<name>.merge = refs/heads/<name>` for the default branch.
  defp config_default_branch(path) do
    case System.cmd("git", ["config", "--get-regexp", "^branch\\..*\\.remote$"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        # Find the first branch that tracks "origin"
        output
        |> String.split("\n", trim: true)
        |> Enum.find_value(:none, fn line ->
          case String.split(line) do
            [key, "origin"] ->
              # key is like "branch.master.remote", extract branch name
              key
              |> String.trim_leading("branch.")
              |> String.trim_trailing(".remote")
              |> then(fn branch -> {:ok, branch} end)

            _ ->
              nil
          end
        end)

      _ ->
        :none
    end
  end

  defp local_fallback_default_branch(path) do
    cond do
      branch_exists?(path, "master") -> {:ok, "master"}
      branch_exists?(path, "main") -> {:ok, "main"}
      true -> {:error, "could not determine default branch"}
    end
  end

  defp branch_exists?(path, branch) do
    case System.cmd("git", ["rev-parse", "--verify", "refs/heads/#{branch}"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {_, 0} -> true
      _ -> false
    end
  end

  @impl true
  def ahead_behind(path, branch) do
    case System.cmd(
           "git",
           ["rev-list", "--left-right", "--count", "HEAD...origin/#{branch}"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        [ahead_str, behind_str] =
          output
          |> String.trim()
          |> String.split(~r/\s+/)

        {:ok, {String.to_integer(ahead_str), String.to_integer(behind_str)}}

      {output, _code} ->
        {:error, String.trim(output)}
    end
  end

  @impl true
  def dirty_files(path) do
    case System.cmd("git", ["status", "--porcelain"], cd: path, stderr_to_stdout: true) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(fn line ->
            # Porcelain format: XY path (first 2 chars are status, then a space, then the path)
            # For renames: XY old_path -> new_path
            status = line |> String.slice(0, 2) |> String.trim()
            file_path = line |> String.slice(3..-1//1) |> String.trim()
            %{status: status, path: file_path}
          end)

        {:ok, files}

      {output, _code} ->
        {:error, String.trim(output)}
    end
  end

  @impl true
  def local_branches(path) do
    case System.cmd("git", ["branch", "--list", "--format=%(refname:short)"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        all_branches =
          output
          |> String.split("\n", trim: true)
          |> Enum.map(&String.trim/1)

        case current_branch(path) do
          {:ok, current} ->
            {:ok, Enum.reject(all_branches, &(&1 == current))}

          {:error, _} ->
            # Detached HEAD or similar — no branch to exclude
            {:ok, all_branches}
        end

      {output, _code} ->
        {:error, String.trim(output)}
    end
  end

  @impl true
  def last_fetch_time(path) do
    if repo?(path) do
      fetch_head = Path.join([path, ".git", "FETCH_HEAD"])

      case File.stat(fetch_head, time: :posix) do
        {:ok, %File.Stat{mtime: mtime}} ->
          {:ok, DateTime.from_unix!(mtime)}

        {:error, :enoent} ->
          # FETCH_HEAD doesn't exist — repo has never been fetched
          {:ok, nil}

        {:error, reason} ->
          {:error, "could not stat FETCH_HEAD: #{reason}"}
      end
    else
      {:error, "not a git repository: #{path}"}
    end
  end

  @impl true
  def fetch(path) do
    case System.cmd("git", ["fetch", "--all", "--prune"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        # Update origin/HEAD to track the remote's current default branch.
        # This fixes stale refs when a remote renames master → main.
        # Ignore failures (no remote, no network, etc.)
        System.cmd("git", ["remote", "set-head", "origin", "--auto"],
          cd: path,
          stderr_to_stdout: true
        )

        :ok

      {output, _code} ->
        {:error, String.trim(output)}
    end
  end

  @impl true
  def pull_ff_only(path) do
    case System.cmd("git", ["pull", "--ff-only"],
           cd: path,
           stderr_to_stdout: true
         ) do
      {_output, 0} -> :ok
      {output, _code} -> {:error, String.trim(output)}
    end
  end
end
