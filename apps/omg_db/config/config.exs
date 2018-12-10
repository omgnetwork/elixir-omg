use Mix.Config

config :omg_db,
  leveldb_path: Path.join([System.get_env("HOME"), ".omg/data"]),
  server_module: OMG.DB.LevelDBServer,
  server_name: OMG.DB.LevelDBServer

config :sentry,
  dsn: {:system, "SENTRY_DSN"},
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: Mix.env(),
    application: Mix.Project.config()[:app]
  },
  server_name: elem(:inet.gethostname(), 1),
  included_environments: [:prod, :dev]
