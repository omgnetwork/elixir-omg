use Mix.Config

# Configures the endpoint
# https://ninenines.eu/docs/en/cowboy/2.4/manual/cowboy_http/
# defaults are:
# protocol_options:[max_header_name_length: 64,
# max_header_value_length: 4096,
# max_headers: 100,
# max_request_line_length: 8096
# ]
config :omg_child_chain_rpc, OMG.ChildChainRPC.Web.Endpoint,
  render_errors: [view: OMG.ChildChainRPC.Web.Views.Error, accepts: ~w(json)],
  instrumenters: [SpandexPhoenix.Instrumenter],
  enable_cors: true,
  http: [:inet6, port: 9656, protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]],
  url: [host: "cc.example.com", port: 80],
  code_reloader: false

# Use Poison for JSON parsing in Phoenix
config :phoenix,
  json_library: Jason,
  serve_endpoints: true,
  persistent: true

config :omg_child_chain_rpc, OMG.ChildChainRPC.Tracer,
  service: :web,
  adapter: SpandexDatadog.Adapter,
  disabled?: true,
  type: :web

config :spandex_phoenix, tracer: OMG.ChildChainRPC.Tracer

import_config "#{Mix.env()}.exs"
