defmodule OMG.Umbrella.MixProject do
  use Mix.Project

  def project() do
    [
      # name the ap for the sake of `mix coveralls --umbrella`
      # see https://github.com/parroty/excoveralls/issues/23#issuecomment-339379061
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.circle": :test,
        dialyzer: :test
      ],
      build_path: "_build" <> docker(),
      deps_path: "deps" <> docker(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      # gets all apps test folders for the sake of `mix coveralls --umbrella`
      test_paths: test_paths(),
      aliases: aliases(),
      # Docs
      source_url: "https://github.com/omgnetwork/elixir-omg",
      version: current_version(),
      releases: [
        watcher: [
          steps: steps(),
          applications: [
            tools: :permanent,
            runtime_tools: :permanent,
            omg_watcher: :permanent,
            omg_watcher_rpc: :permanent,
            omg: :permanent,
            omg_status: :permanent,
            omg_db: :permanent,
            omg_eth: :permanent,
            omg_bus: :permanent
          ],
          config_providers: [
            {OMG.Status.ReleaseTasks.SetSentry, [release: :watcher, current_version: current_version()]},
            {OMG.Status.ReleaseTasks.SetTracer, [release: :watcher]},
            {OMG.Status.ReleaseTasks.SetApplication, [release: :watcher, current_version: current_version()]},
            {OMG.ReleaseTasks.SetEthereumEventsCheckInterval, []},
            {OMG.Eth.ReleaseTasks.SetEthereumEventsCheckInterval, []},
            {OMG.Eth.ReleaseTasks.SetEthereumStalledSyncThreshold, []},
            {OMG.Eth.ReleaseTasks.SetEthereumClient, []},
            {OMG.Eth.ReleaseTasks.SetContract, []},
            {OMG.DB.ReleaseTasks.SetKeyValueDB, [release: :watcher]},
            {OMG.WatcherRPC.ReleaseTasks.SetEndpoint, []},
            {OMG.WatcherRPC.ReleaseTasks.SetTracer, []},
            {OMG.WatcherRPC.ReleaseTasks.SetApiMode, :watcher},
            {OMG.Status.ReleaseTasks.SetLogger, []},
            {OMG.Watcher.ReleaseTasks.SetChildChain, []},
            {OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMargin, []},
            {OMG.Watcher.ReleaseTasks.SetTracer, []},
            {OMG.Watcher.ReleaseTasks.SetApplication, [release: :watcher, current_version: current_version()]}
          ]
        ],
        watcher_info: [
          steps: steps(),
          version: current_version(),
          applications: [
            tools: :permanent,
            runtime_tools: :permanent,
            omg_watcher: :permanent,
            omg_watcher_info: :permanent,
            omg_watcher_rpc: :permanent,
            omg: :permanent,
            omg_status: :permanent,
            omg_db: :permanent,
            omg_eth: :permanent,
            omg_bus: :permanent
          ],
          config_providers: [
            {OMG.Status.ReleaseTasks.SetSentry, [release: :watcher_info, current_version: current_version()]},
            {OMG.Status.ReleaseTasks.SetTracer, [release: :watcher_info]},
            {OMG.Status.ReleaseTasks.SetApplication, [release: :watcher_info, current_version: current_version()]},
            {OMG.Status.ReleaseTasks.SetLogger, []},
            {OMG.ReleaseTasks.SetEthereumEventsCheckInterval, []},
            {OMG.Eth.ReleaseTasks.SetEthereumEventsCheckInterval, []},
            {OMG.Eth.ReleaseTasks.SetEthereumStalledSyncThreshold, []},
            {OMG.Eth.ReleaseTasks.SetEthereumClient, []},
            {OMG.Eth.ReleaseTasks.SetContract, []},
            {OMG.DB.ReleaseTasks.SetKeyValueDB, [release: :watcher_info]},
            {OMG.WatcherRPC.ReleaseTasks.SetEndpoint, []},
            {OMG.WatcherRPC.ReleaseTasks.SetTracer, []},
            {OMG.WatcherRPC.ReleaseTasks.SetApiMode, :watcher_info},
            {OMG.Watcher.ReleaseTasks.SetChildChain, []},
            {OMG.WatcherInfo.ReleaseTasks.SetChildChain, []},
            {OMG.Watcher.ReleaseTasks.SetExitProcessorSLAMargin, []},
            {OMG.Watcher.ReleaseTasks.SetTracer, []},
            {OMG.Watcher.ReleaseTasks.SetApplication, [release: :watcher_info, current_version: current_version()]},
            {OMG.WatcherInfo.ReleaseTasks.SetDB, []},
            {OMG.WatcherInfo.ReleaseTasks.SetTracer, []}
          ]
        ],
        child_chain: [
          steps: steps(),
          version: current_version(),
          applications: [
            tools: :permanent,
            runtime_tools: :permanent,
            omg_child_chain: :permanent,
            omg_child_chain_rpc: :permanent,
            omg: :permanent,
            omg_status: :permanent,
            omg_db: :permanent,
            omg_eth: :permanent,
            omg_bus: :permanent
          ],
          config_providers: [
            {OMG.Status.ReleaseTasks.SetSentry, [release: :child_chain, current_version: current_version()]},
            {OMG.Status.ReleaseTasks.SetTracer, [release: :child_chain]},
            {OMG.Status.ReleaseTasks.SetApplication, [release: :child_chain, current_version: current_version()]},
            {OMG.Status.ReleaseTasks.SetLogger, []},
            {OMG.ReleaseTasks.SetEthereumEventsCheckInterval, []},
            {OMG.Eth.ReleaseTasks.SetEthereumEventsCheckInterval, []},
            {OMG.Eth.ReleaseTasks.SetEthereumStalledSyncThreshold, []},
            {OMG.ChildChain.ReleaseTasks.SetBlockSubmitMaxGasPrice, []},
            {OMG.ChildChain.ReleaseTasks.SetFeeClaimerAddress, []},
            {OMG.ChildChain.ReleaseTasks.SetFeeBufferDuration, []},
            {OMG.ChildChain.ReleaseTasks.SetFeeFileAdapterOpts, []},
            {OMG.ChildChain.ReleaseTasks.SetFeeFeedAdapterOpts, []},
            {OMG.ChildChain.ReleaseTasks.SetTracer, []},
            {OMG.ChildChain.ReleaseTasks.SetApplication, [release: :child_chain, current_version: current_version()]},
            {OMG.Eth.ReleaseTasks.SetEthereumClient, []},
            {OMG.Eth.ReleaseTasks.SetContract, []},
            {OMG.DB.ReleaseTasks.SetKeyValueDB, [release: :child_chain]},
            {OMG.ChildChainRPC.ReleaseTasks.SetEndpoint, []},
            {OMG.ChildChainRPC.ReleaseTasks.SetTracer, []}
          ]
        ]
      ]
    ]
  end

  defp test_paths() do
    "apps/*/test" |> Path.wildcard() |> Enum.sort()
  end

  defp deps() do
    [
      {:mix_audit, "~> 0.1", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.3", only: [:dev, :test], runtime: false},
      # https://github.com/xadhoom/excoveralls.git `52c6c8e5d7fe9abb814e5e3e546c863b9b2b41b7` rebased on `master`
      # more or less around v0.11.1
      {:excoveralls, "~> 0.12.3"},
      {:licensir, "~> 0.2.0", only: :dev, runtime: false},
      {
        :ex_unit_fixtures,
        git: "https://github.com/omgnetwork/ex_unit_fixtures.git",
        branch: "feature/require_files_not_load",
        only: [:test]
      },
      {:ex_doc, "~> 0.20.2", only: :dev, runtime: false},
      {:libsecp256k1, git: "https://github.com/omgnetwork/libsecp256k1.git", branch: "elixir-only", override: true},
      {:spandex, "~> 2.4.3"}
    ]
  end

  defp aliases() do
    [
      test: ["test --no-start"],
      coveralls: ["coveralls --no-start"],
      "coveralls.html": ["coveralls.html --no-start"],
      "coveralls.detail": ["coveralls.detail --no-start"],
      "coveralls.post": ["coveralls.post --no-start"],
      "coveralls.circle": ["coveralls.circle --no-start"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"]
    ]
  end

  defp dialyzer() do
    [
      flags: [:error_handling, :race_conditions, :underspecs, :unknown, :unmatched_returns],
      ignore_warnings: "dialyzer.ignore-warnings",
      list_unused_filters: true,
      plt_add_apps: plt_apps(),
      paths: Enum.map(File.ls!("apps"), fn app -> "_build#{docker()}/#{Mix.env()}/lib/#{app}/ebin" end)
    ]
  end

  defp plt_apps() do
    [
      :briefly,
      :cowboy,
      :ex_machina,
      :ex_unit,
      :exexec,
      :fake_server,
      :iex,
      :jason,
      :mix,
      :plug,
      :ranch,
      :sentry,
      :vmstats
    ]
  end

  defp docker(), do: if(System.get_env("DOCKER"), do: "_docker", else: "")

  defp current_version() do
    sha = String.replace(elem(System.cmd("git", ["rev-parse", "--short=7", "HEAD"]), 0), "\n", "")
    "#{String.trim(File.read!("VERSION"))}" <> "+" <> sha
  end

  defp steps() do
    case Mix.env() do
      :prod -> [:assemble, :tar]
      _ -> [:assemble]
    end
  end
end
