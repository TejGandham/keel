ExUnit.start(exclude: [:integration, :docker])

Mox.defmock(RepoMan.Git.Mock, for: RepoMan.Git.Behaviour)
