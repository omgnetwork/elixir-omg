defmodule OMG.Performance.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_performance,
      version: OMG.Umbrella.MixProject.umbrella_version(),
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :tools]
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:appsignal, "~> 1.0"},
      {:deferred_config, "~> 0.1.1"},
      # TEST ONLY
      {:briefly, "~> 0.3.0", only: [:dev, :test], runtime: false},
      {:omg_api, in_umbrella: true, only: [:test], runtime: false},
      {:omg_rpc, in_umbrella: true, only: [:test], runtime: false},
      {:omg_watcher, in_umbrella: true, only: [:test], runtime: false}
    ]
  end
end
