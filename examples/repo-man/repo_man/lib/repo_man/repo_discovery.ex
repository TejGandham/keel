defmodule RepoMan.RepoDiscovery do
  @moduledoc """
  Scans a directory for immediate subdirectories that are git repositories.

  Used at startup and on page load to discover repos under the configured
  `REPOMAN_PATH` (defaults to `~/src/shred/`). Hidden directories (starting
  with `.`) are ignored.

  Returns a sorted list of `%{name: String.t(), path: String.t()}` maps.
  """

  @git_module Application.compile_env(:repo_man, :git_module, RepoMan.Git)

  @doc """
  Scans `base_path` for immediate subdirectories that are git repositories.

  Returns a sorted (by name) list of `%{name: String.t(), path: String.t()}`
  maps. Ignores hidden directories (names starting with `.`). Returns an
  empty list if `base_path` does not exist or contains no git repos.
  """
  @spec scan(String.t()) :: [%{name: String.t(), path: String.t()}]
  def scan(base_path) do
    case File.ls(base_path) do
      {:ok, entries} ->
        entries
        |> Enum.reject(&hidden?/1)
        |> Enum.map(&{&1, Path.join(base_path, &1)})
        |> Enum.filter(fn {_name, path} -> File.dir?(path) and @git_module.repo?(path) end)
        |> Enum.map(fn {name, path} -> %{name: name, path: path} end)
        |> Enum.sort_by(& &1.name)

      {:error, _reason} ->
        []
    end
  end

  defp hidden?(name), do: String.starts_with?(name, ".")
end
