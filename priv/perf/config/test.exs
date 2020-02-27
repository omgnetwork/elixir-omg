use Mix.Config

config :load_test,
  child_chain_url: System.get_env("CHILD_CHAIN_URL") || "http://localhost:9656",
  watcher_security_url: System.get_env("WATCHER_SECURITY_URL") || "http://localhost:7434",
  watcher_info_url: System.get_env("WATCHER_INFO_URL") || "http://localhost:7534"
