use Mix.Config

# increasing timeout to handle slow geth on Jenkins
config :ethereumex,
  request_timeout: 50000
