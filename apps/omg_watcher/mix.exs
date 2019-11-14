defmodule OMG.Watcher.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_watcher,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      start_phases: [{:attach_telemetry, []}],
      mod: {OMG.Watcher.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:omg_bus, in_umbrella: true},
      {:omg, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_status, in_umbrella: true},

      # testing
      {:fake_server, "~> 1.5", only: [:dev, :test], runtime: false},
      {:briefly, "~> 0.3.0", only: [:dev, :test]},
      {:omg_child_chain, in_umbrella: true, only: [:test], runtime: false}
    ]
  end
end
