# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# By default, the umbrella project as well as each child
# application will require this configuration file, ensuring
# they all use the same configuration. While one could
# configure all applications here, we prefer to delegate
# back to each application for organization purposes.
import_config "../apps/*/config/config.exs"

# Sample configuration (overrides the imported configuration above):

config :logger, :console,
  level: :debug,
  #format: "$date $time [$level] $metadata⋅$message⋅\n",
  format: {OMG.API.LoggerExt, :format},
  discard_threshold: 2000,
  metadata: [:module, :function, :line, :file, :request_id],
  remove_module: [
     "Phoenix.Logger",
     ":application_controller",
  #  "OMG,Watcher.Web.Controller.Utxo",
  #  "BlockQueue.Core", 
     "API.FeeChecker",
     "FreshBlocks",
     "BlockQueue",
     "Plug.Logger",
     "Ecto.LogEntry",
     "OMG.DB", 
     "OMG.API.RootChainCoordinator", 
     "OMG.Watcher.BlockGetter",
     "OMG.Watcher.DB",
  #   "Watcher.Fixtures", 
     "Eth.DevGeth", 
  #  "BlockQueue.Server","Ecto.","Plug.Logger",
    "OMG.API",
    "OMG.API.EthereumEventListener",
    "Performance.SenderServer"] |> Enum.join("|")

config :ethereumex,
  request_timeout: 60_000

import_config "#{Mix.env()}.exs"
