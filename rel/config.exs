# Import all plugins from `rel/plugins`
# They can then be used by adding `plugin MyPlugin` to
# either an environment, or release definition, where
# `MyPlugin` is the name of the plugin module.
~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

sha = String.replace(elem(System.cmd("git", ["rev-parse", "--short=7", "HEAD"]), 0), "\n", "")

use Distillery.Releases.Config,
  # This sets the default environment used by `mix release`
  default_environment: Mix.env()

environment :dev do
  set(dev_mode: true)
  set(include_erts: false)
  set(cookie: :dev)
end

environment :prod do
  set(include_erts: true)
  set(include_src: false)
  set(cookie: :prod)
end

current_version = current_version(:omg_child_chain) <> "+" <> sha

release :watcher do
  set(version: current_version)

  set(vm_args: "rel/vm.args")

  set(
    applications: [
      :runtime_tools,
      omg_watcher: :permanent,
      omg_watcher_rpc: :permanent,
      omg: :permanent,
      omg_status: :permanent,
      omg_db: :permanent,
      omg_eth: :permanent,
      omg_bus: :permanent
    ]
  )

  set(
    config_providers: [
      {OMG.ReleaseTasks.SetEthereumEventsCheckInterval, []},
      {OMG.Eth.ReleaseTasks.SetEthereumEventsCheckInterval, []},
      {OMG.Eth.ReleaseTasks.SetEthereumStalledSyncThreshold, []},
      {OMG.Eth.ReleaseTasks.SetEthereumClient, []},
      {OMG.Eth.ReleaseTasks.SetContract, []},
      {OMG.DB.ReleaseTasks.SetKeyValueDB, []},
      {OMG.WatcherRPC.ReleaseTasks.SetEndpoint, []},
      {OMG.WatcherRPC.ReleaseTasks.SetTracer, []},
      {OMG.WatcherRPC.ReleaseTasks.SetApiMode, :watcher},
      {OMG.Status.ReleaseTasks.SetSentry, [release: :watcher, current_version: current_version]},
      {OMG.Status.ReleaseTasks.SetTracer, [release: :watcher]},
      {OMG.Status.ReleaseTasks.SetApplication, [release: :watcher, current_version: current_version]},
      {OMG.Status.ReleaseTasks.SetLogger, []},
      {OMG.Watcher.ReleaseTasks.SetChildChain, []},
      {OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMargin, []},
      {OMG.Watcher.ReleaseTasks.SetTracer, []},
      {OMG.Watcher.ReleaseTasks.SetApplication, [release: :watcher, current_version: current_version]}
    ]
  )

  set(
    commands: [
      init_key_value_db: "rel/commands/init_key_value_db.sh"
    ]
  )
end

release :watcher_info do
  set(version: current_version(:omg_child_chain) <> "+" <> sha)

  set(vm_args: "rel/vm.args")

  set(
    applications: [
      :runtime_tools,
      omg_watcher: :permanent,
      omg_watcher_info: :permanent,
      omg_watcher_rpc: :permanent,
      omg: :permanent,
      omg_status: :permanent,
      omg_db: :permanent,
      omg_eth: :permanent,
      omg_bus: :permanent
    ]
  )

  set(
    config_providers: [
      {OMG.ReleaseTasks.SetEthereumEventsCheckInterval, []},
      {OMG.Eth.ReleaseTasks.SetEthereumEventsCheckInterval, []},
      {OMG.Eth.ReleaseTasks.SetEthereumStalledSyncThreshold, []},
      {OMG.Eth.ReleaseTasks.SetEthereumClient, []},
      {OMG.Eth.ReleaseTasks.SetContract, []},
      {OMG.DB.ReleaseTasks.SetKeyValueDB, []},
      {OMG.WatcherRPC.ReleaseTasks.SetEndpoint, []},
      {OMG.WatcherRPC.ReleaseTasks.SetTracer, []},
      {OMG.WatcherRPC.ReleaseTasks.SetApiMode, :watcher_info},
      {OMG.Status.ReleaseTasks.SetSentry, [release: :watcher_info, current_version: current_version]},
      {OMG.Status.ReleaseTasks.SetTracer, [release: :watcher_info]},
      {OMG.Status.ReleaseTasks.SetApplication, [release: :watcher_info, current_version: current_version]},
      {OMG.Status.ReleaseTasks.SetLogger, []},
      {OMG.Watcher.ReleaseTasks.SetChildChain, []},
      {OMG.WatcherInfo.ReleaseTasks.SetChildChain, []},
      {OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMargin, []},
      {OMG.Watcher.ReleaseTasks.SetTracer, []},
      {OMG.Watcher.ReleaseTasks.SetApplication, [release: :watcher_info, current_version: current_version]},
      {OMG.WatcherInfo.ReleaseTasks.SetDB, []},
      {OMG.WatcherInfo.ReleaseTasks.SetTracer, []}
    ]
  )

  set(
    commands: [
      init_postgresql_db: "rel/commands/watcher_info/init_postgresql_db.sh",
      init_key_value_db: "rel/commands/init_key_value_db.sh"
    ]
  )
end

release :child_chain do
  set(version: current_version(:omg_child_chain) <> "+" <> sha)

  set(vm_args: "rel/vm.args")

  set(
    applications: [
      :runtime_tools,
      omg_child_chain: :permanent,
      omg_child_chain_rpc: :permanent,
      omg: :permanent,
      omg_status: :permanent,
      omg_db: :permanent,
      omg_eth: :permanent,
      omg_bus: :permanent
    ]
  )

  set(
    config_providers: [
      {OMG.ReleaseTasks.SetEthereumEventsCheckInterval, []},
      {OMG.Eth.ReleaseTasks.SetEthereumEventsCheckInterval, []},
      {OMG.Eth.ReleaseTasks.SetEthereumStalledSyncThreshold, []},
      {OMG.ChildChain.ReleaseTasks.SetFeeClaimerAddress, []},
      {OMG.ChildChain.ReleaseTasks.SetFeeBufferDuration, []},
      {OMG.ChildChain.ReleaseTasks.SetTracer, []},
      {OMG.ChildChain.ReleaseTasks.SetApplication, [release: :child_chain, current_version: current_version]},
      {OMG.Eth.ReleaseTasks.SetEthereumClient, []},
      {OMG.Eth.ReleaseTasks.SetContract, []},
      {OMG.DB.ReleaseTasks.SetKeyValueDB, []},
      {OMG.ChildChainRPC.ReleaseTasks.SetEndpoint, []},
      {OMG.ChildChainRPC.ReleaseTasks.SetTracer, []},
      {OMG.Status.ReleaseTasks.SetSentry, [release: :child_chain, current_version: current_version]},
      {OMG.Status.ReleaseTasks.SetTracer, [release: :child_chain]},
      {OMG.Status.ReleaseTasks.SetApplication, [release: :child_chain, current_version: current_version]},
      {OMG.Status.ReleaseTasks.SetLogger, []}
    ]
  )

  set(
    commands: [
      init_key_value_db: "rel/commands/init_key_value_db.sh"
    ]
  )
end
