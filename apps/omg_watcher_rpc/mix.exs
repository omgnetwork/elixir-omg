defmodule OMG.WatcherRPC.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omg_watcher_rpc,
      version: OMG.Umbrella.MixProject.umbrella_version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {OMG.WatcherRPC.Application, []},
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
      {:deferred_config, "~> 0.1.1"},
      {:cors_plug, "~> 2.0"},
      {:appsignal, "~> 1.0"},
      # UMBRELLA

      {:omg_utils, in_umbrella: true},
      {:omg_watcher, in_umbrella: true}
    ]
  end
end
