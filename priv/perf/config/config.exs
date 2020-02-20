use Mix.Config

# Better adapter for tesla.
# default httpc would fail when doing post request without param.
# https://github.com/googleapis/elixir-google-api/issues/26#issuecomment-360209019
config :tesla, adapter: Tesla.Adapter.Hackney

config :load_test,
  child_chain_url: System.get_env("CHILD_CHAIN_URL") || "http://localhost:9656",
  watcher_security_url: System.get_env("WATCHER_SECURITY_URL") || "http://localhost:7434",
  watcher_info_url: System.get_env("WATCHER_INFO_URL") || "http://localhost:7534"
