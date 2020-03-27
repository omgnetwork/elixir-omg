defmodule OMG.Performance.MixProject do
  use Mix.Project

  def project() do
    [
      app: :omg_performance,
      version: "#{String.trim(File.read!("../../VERSION"))}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :tools]
    ]
  end

  # Specifies which paths to compile per environment.
  # We don't need the performance app in a production release
  defp elixirc_paths(:prod), do: []
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    [
      # TEST ONLY
      {:briefly, "~> 0.3.0", only: [:dev, :test]},
      {:omg_utils, in_umbrella: true, only: [:test], runtime: false},
      {:omg_child_chain, in_umbrella: true, only: [:test], runtime: false},
      {:omg_child_chain_rpc, in_umbrella: true, only: [:test], runtime: false},
      {:omg_eth, in_umbrella: true, only: [:test], runtime: false},
      {:omg_watcher, in_umbrella: true, only: [:test], runtime: false},
      {:omg_status, in_umbrella: true, only: [:test], runtime: false}
    ]
  end
end
