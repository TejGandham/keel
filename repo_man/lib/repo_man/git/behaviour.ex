defmodule RepoMan.Git.Behaviour do
  @moduledoc """
  Behaviour defining the git interface contract.

  All modules that interact with git call through this behaviour via
  `Application.get_env(:repo_man, :git_module, RepoMan.Git)`.

  The real implementation (`RepoMan.Git`) shells out to `System.cmd/3`.
  In tests, `RepoMan.Git.Mock` (defined via Mox) replaces it for fast,
  deterministic assertions without touching the filesystem.
  """

  @type repo_path :: String.t()
  @type dirty_file :: %{status: String.t(), path: String.t()}

  @doc "Returns true if the given path is a git repository."
  @callback repo?(repo_path()) :: boolean()

  @doc "Returns the current branch name for the repo at `path`."
  @callback current_branch(repo_path()) :: {:ok, String.t()} | {:error, String.t()}

  @doc "Returns the default branch name (e.g. master/main) for the repo at `path`."
  @callback default_branch(repo_path()) :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Returns the ahead/behind counts relative to `origin/{branch}`.

  Returns `{ahead, behind}` where ahead is the number of local commits
  not on remote, and behind is the number of remote commits not local.
  """
  @callback ahead_behind(repo_path(), branch :: String.t()) ::
              {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, String.t()}

  @doc "Returns the list of dirty files (staged, unstaged, untracked) in the working tree."
  @callback dirty_files(repo_path()) :: {:ok, [dirty_file()]} | {:error, String.t()}

  @doc "Returns the list of local branch names."
  @callback local_branches(repo_path()) :: {:ok, [String.t()]} | {:error, String.t()}

  @doc """
  Returns the last fetch time based on `.git/FETCH_HEAD` mtime.

  Returns `nil` inside the ok tuple if the file does not exist (never fetched).
  """
  @callback last_fetch_time(repo_path()) :: {:ok, DateTime.t() | nil} | {:error, String.t()}

  @doc "Runs `git fetch --all --prune`. Always safe."
  @callback fetch(repo_path()) :: :ok | {:error, String.t()}

  @doc """
  Runs `git pull --ff-only`.

  Callers must enforce preconditions (clean, on default branch, not diverged,
  behind > 0) before invoking this.
  """
  @callback pull_ff_only(repo_path()) :: :ok | {:error, String.t()}
end
