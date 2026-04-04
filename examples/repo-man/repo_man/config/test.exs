import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :repo_man, RepoManWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "QKlG/ftbhXZCRs+u9zKVxiDxSEFdrC0DV7SNlQOJxgjNT25m5aJKo+qOHf0bWj6c",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

test_repos_path = Path.expand("../tmp/test_repos", __DIR__)
File.mkdir_p!(test_repos_path)
config :repo_man, repos_path: test_repos_path

# Use Mox mock for Git module in tests (see ARCHITECTURE.md Git Module Injection)
config :repo_man, git_module: RepoMan.Git.Mock

# Don't auto-start RepoServers on boot — tests start them explicitly
# with isolated supervisors and mock expectations.
config :repo_man, start_repos_on_boot: false

# Disable periodic polling in tests — tests control timing explicitly
config :repo_man, poll_interval: 0
