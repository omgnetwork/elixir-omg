defmodule OMG.WatcherSecurity.MixProject do
  use Mix.Project

  def project do
    [
      app: :omg_watcher_security,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      start_phases: [{:attach_telemetry, []}],
      mod: {OMG.WatcherSecurity.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:omg_bus, in_umbrella: true},
      {:omg, in_umbrella: true},
      {:omg_db, in_umbrella: true},
      {:omg_eth, in_umbrella: true},
      {:omg_status, in_umbrella: true}
    ]
  end
end
