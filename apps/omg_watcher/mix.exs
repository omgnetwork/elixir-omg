defmodule OMG.Watcher.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omg_watcher,
      version: OMG.Umbrella.MixProject.umbrella_version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      env: [
        exit_processor_sla_margin: 4 * 4 * 60,
        maximum_block_withholding_time_ms: 1_200_000,
        block_getter_loops_interval_ms: 500,
        maximum_number_of_unapplied_blocks: 50,
        exit_finality_margin: 12,
        block_getter_reorg_margin: 200,
        convenience_api_mode: false
      ],
      mod: {OMG.Watcher.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:phoenix, "~> 1.3"},
      {:plug_cowboy, "~> 1.0"},
      {:phoenix_ecto, "~> 3.3"},
      {:postgrex, ">= 0.13.5"},
      {:deferred_config, "~> 0.1.1"},
      {:cors_plug, "~> 2.0"},
      {:appsignal, "~> 1.0"},
      # UMBRELLA
      {:omg, in_umbrella: true},
      {:omg_status, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:utils, in_umbrella: true},

      # TEST ONLY
      # here only to leverage common test helpers and code
      {:fake_server, "~> 1.5", only: [:dev, :test], runtime: false},
      {:briefly, "~> 0.3.0", only: [:dev, :test], runtime: false},
      {:omg_api, in_umbrella: true, only: [:test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate", "test"]
    ]
  end
end
