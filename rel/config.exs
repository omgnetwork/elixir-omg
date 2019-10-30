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

release :watcher do
  set(version: current_version(:omg_child_chain) <> "+" <> sha)

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
      {OMG.Eth.ReleaseTasks.SetContract, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Eth.ReleaseTasks.SetEthereumClient, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.DB.ReleaseTasks.SetKeyValueDB, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.WatcherRPC.ReleaseTasks.SetEndpoint, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.WatcherRPC.ReleaseTasks.SetTracer, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Status.ReleaseTasks.SetSentry, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Status.ReleaseTasks.SetTracer, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Watcher.ReleaseTasks.SetChildChain, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Watcher.ReleaseTasks.SetDB, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Watcher.ReleaseTasks.SetTracer, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMargin, ["${RELEASE_ROOT_DIR}/config/config.exs"]}
    ]
  )

  set(
    commands: [
      init_postgresql_db: "rel/commands/watcher/init_postgresql_db.sh",
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
      {OMG.Eth.ReleaseTasks.SetContract, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Eth.ReleaseTasks.SetEthereumClient, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.DB.ReleaseTasks.SetKeyValueDB, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.ChildChainRPC.ReleaseTasks.SetEndpoint, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.ChildChainRPC.ReleaseTasks.SetTracer, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Status.ReleaseTasks.SetSentry, ["${RELEASE_ROOT_DIR}/config/config.exs"]},
      {OMG.Status.ReleaseTasks.SetTracer, ["${RELEASE_ROOT_DIR}/config/config.exs"]}
    ]
  )

  set(
    commands: [
      init_key_value_db: "rel/commands/init_key_value_db.sh"
    ]
  )
end
