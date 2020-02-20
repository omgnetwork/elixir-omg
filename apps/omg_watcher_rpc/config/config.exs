use Mix.Config

# In mix environment, all modules are loaded, therefore it behaves like a watcher_info
config :omg_watcher_rpc,
  api_mode: :watcher_info

# Configures the endpoint
# https://ninenines.eu/docs/en/cowboy/2.4/manual/cowboy_http/
# defaults are:
# protocol_options:[max_header_name_length: 64,
# max_header_value_length: 4096,
# max_headers: 100,
# max_request_line_length: 8096
# ]
config :omg_watcher_rpc, OMG.WatcherRPC.Web.Endpoint,
  render_errors: [view: OMG.WatcherRPC.Web.Views.Error, accepts: ~w(json)],
  pubsub: [name: OMG.WatcherRPC.PubSub, adapter: Phoenix.PubSub.PG2],
  instrumenters: [SpandexPhoenix.Instrumenter],
  enable_cors: true,
  http: [:inet6, port: 7434, protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]],
  url: [host: "w.example.com", port: 80],
  code_reloader: false

config :phoenix,
  json_library: Jason,
  serve_endpoints: true,
  persistent: true

config :omg_watcher_rpc, OMG.WatcherRPC.Tracer,
  service: :web,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :web

config :spandex_phoenix, tracer: OMG.WatcherRPC.Tracer

import_config "#{Mix.env()}.exs"
