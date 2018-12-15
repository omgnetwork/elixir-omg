use Mix.Config

# bumping these timeouts into infinity - let's rely on test timeouts rather than these
config :ethereumex,
  request_timeout: :infinity,
  http_options: [recv_timeout: :infinity]
