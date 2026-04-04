defmodule RepoMan.RepoStatusTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias RepoMan.RepoStatus

  # ── Helpers ──────────────────────────────────────────────────────────

  defp base_attrs do
    %{
      name: "AXO471",
      path: "/Users/tej/src/shred/AXO471",
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
  end

  defp new!(overrides \\ %{}) do
    RepoStatus.new(Map.merge(base_attrs(), overrides))
  end

  # ── new/1 creates struct with all derived fields correct ─────────────

  describe "new/1" do
    test "creates a struct with all supplied fields" do
      status = new!()

      assert status.name == "AXO471"
      assert status.path == "/Users/tej/src/shred/AXO471"
      assert status.current_branch == "master"
      assert status.default_branch == "master"
      assert status.ahead == 0
      assert status.behind == 0
      assert status.dirty_files == []
      assert status.local_branches == []
      assert status.last_fetch == ~U[2026-03-13 14:30:00Z]
      assert status.last_error == nil
      assert status.operation == :idle
    end

    test "derives on_default? as true when current == default" do
      status = new!(%{current_branch: "master", default_branch: "master"})
      assert status.on_default? == true
    end

    test "derives on_default? as false when current != default" do
      status = new!(%{current_branch: "feat/xyz", default_branch: "master"})
      assert status.on_default? == false
    end

    test "derives dirty_count from length of dirty_files" do
      files = [%{status: "M", path: "a.ex"}, %{status: "??", path: "b.ex"}]
      status = new!(%{dirty_files: files})
      assert status.dirty_count == 2
    end

    test "derives dirty_count as 0 when dirty_files is empty" do
      status = new!(%{dirty_files: []})
      assert status.dirty_count == 0
    end
  end

  # ── pull_eligible? ───────────────────────────────────────────────────

  describe "pull_eligible?" do
    test "false when dirty (dirty_files present)" do
      status = new!(%{dirty_files: [%{status: "M", path: "a.ex"}], behind: 1})
      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "dirty"
    end

    test "false when not on default branch" do
      status = new!(%{current_branch: "feat/xyz", default_branch: "master", behind: 1})
      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "switch to"
    end

    test "false when diverged (ahead > 0 AND behind > 0)" do
      status = new!(%{ahead: 2, behind: 3})
      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "Diverged"
    end

    test "false when ahead > 0 (unpushed commits)" do
      status = new!(%{ahead: 3, behind: 0})
      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "unpushed"
    end

    test "false when behind == 0 (already up to date)" do
      status = new!(%{ahead: 0, behind: 0})
      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "up to date"
    end

    test "true when all conditions met (on default, clean, behind > 0, ahead == 0)" do
      status = new!(%{ahead: 0, behind: 5})
      assert status.pull_eligible? == true
      assert status.pull_blocked_reason == nil
    end

    test "blocked reason priority: dirty checked before not-on-default" do
      status =
        new!(%{
          dirty_files: [%{status: "M", path: "a.ex"}],
          current_branch: "feat/xyz",
          default_branch: "master",
          behind: 1
        })

      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "dirty"
    end

    test "blocked reason priority: not-on-default checked before diverged" do
      status =
        new!(%{
          current_branch: "feat/xyz",
          default_branch: "master",
          ahead: 2,
          behind: 3
        })

      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "switch to"
    end

    test "blocked reason priority: diverged checked before ahead-only" do
      status = new!(%{ahead: 2, behind: 3})
      assert status.pull_eligible? == false
      assert status.pull_blocked_reason =~ "Diverged"
    end
  end

  # ── severity ─────────────────────────────────────────────────────────

  describe "severity" do
    test "returns :error when last_error is set" do
      status = new!(%{last_error: "fatal: not a git repository"})
      assert status.severity == :error
    end

    test "returns :error when operation is :error" do
      status = new!(%{operation: :error})
      assert status.severity == :error
    end

    test "returns :diverged when ahead > 0 and behind > 0" do
      status = new!(%{ahead: 2, behind: 3})
      assert status.severity == :diverged
    end

    test "returns :dirty when dirty_files present" do
      status = new!(%{dirty_files: [%{status: "M", path: "a.ex"}]})
      assert status.severity == :dirty
    end

    test "returns :topic_branch when not on default branch" do
      status = new!(%{current_branch: "feat/xyz", default_branch: "master"})
      assert status.severity == :topic_branch
    end

    test "returns :behind when behind > 0 (on default, clean)" do
      status = new!(%{behind: 3})
      assert status.severity == :behind
    end

    test "returns :clean when nothing to report" do
      status = new!()
      assert status.severity == :clean
    end

    # Priority ordering tests: higher-priority states win when states overlap

    test "error beats diverged" do
      status = new!(%{last_error: "timeout", ahead: 2, behind: 3})
      assert status.severity == :error
    end

    test "diverged beats dirty" do
      files = [%{status: "M", path: "a.ex"}]
      status = new!(%{ahead: 1, behind: 1, dirty_files: files})
      assert status.severity == :diverged
    end

    test "dirty beats topic_branch" do
      files = [%{status: "M", path: "a.ex"}]

      status =
        new!(%{
          dirty_files: files,
          current_branch: "feat/xyz",
          default_branch: "master"
        })

      assert status.severity == :dirty
    end

    test "topic_branch beats behind" do
      status =
        new!(%{
          current_branch: "feat/xyz",
          default_branch: "master",
          behind: 3
        })

      assert status.severity == :topic_branch
    end

    test "behind beats clean" do
      status = new!(%{behind: 1})
      assert status.severity == :behind
    end
  end

  # ── StreamData property-based tests ──────────────────────────────────

  describe "property: severity" do
    property "always returns a valid severity atom" do
      check all(attrs <- repo_attrs_generator()) do
        status = RepoStatus.new(attrs)

        assert status.severity in [
                 :error,
                 :diverged,
                 :dirty,
                 :topic_branch,
                 :behind,
                 :clean
               ]
      end
    end
  end

  describe "property: pull_eligible?" do
    property "never true when dirty" do
      check all(
              attrs <- repo_attrs_generator(),
              attrs.dirty_files != []
            ) do
        status = RepoStatus.new(attrs)
        assert status.pull_eligible? == false
      end
    end

    property "never true when not on default branch" do
      check all(
              attrs <- repo_attrs_generator(),
              attrs.current_branch != attrs.default_branch
            ) do
        status = RepoStatus.new(attrs)
        assert status.pull_eligible? == false
      end
    end

    property "never true when diverged" do
      check all(
              attrs <- repo_attrs_generator(),
              attrs.ahead > 0 and attrs.behind > 0
            ) do
        status = RepoStatus.new(attrs)
        assert status.pull_eligible? == false
      end
    end

    property "pull_eligible? is always a boolean" do
      check all(attrs <- repo_attrs_generator()) do
        status = RepoStatus.new(attrs)
        assert is_boolean(status.pull_eligible?)
      end
    end
  end

  # ── StreamData generators ────────────────────────────────────────────

  defp repo_attrs_generator do
    gen all(
          name <- string(:alphanumeric, min_length: 1, max_length: 10),
          branch <- member_of(["master", "main", "feat/xyz", "develop"]),
          default <- member_of(["master", "main"]),
          ahead <- non_negative_integer(),
          behind <- non_negative_integer(),
          dirty_count <- integer(0..5),
          dirty_files <- fixed_list(List.duplicate(dirty_file_generator(), dirty_count)),
          local_branches <-
            list_of(string(:alphanumeric, min_length: 1, max_length: 10),
              max_length: 5
            ),
          has_error <- boolean(),
          operation <- member_of([:idle, :fetching, :pulling, :error])
        ) do
      %{
        name: name,
        path: "/tmp/#{name}",
        current_branch: branch,
        default_branch: default,
        ahead: ahead,
        behind: behind,
        dirty_files: dirty_files,
        local_branches: local_branches,
        last_fetch: ~U[2026-03-13 14:30:00Z],
        last_error: if(has_error, do: "some error", else: nil),
        operation: operation
      }
    end
  end

  defp dirty_file_generator do
    gen all(
          status <- member_of(["M", "A", "D", "??", "R"]),
          path <- string(:alphanumeric, min_length: 1, max_length: 20)
        ) do
      %{status: status, path: path}
    end
  end
end
