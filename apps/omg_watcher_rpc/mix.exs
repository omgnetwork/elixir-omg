defmodule OMG.WatcherRPC.Mixfile do
  use Mix.Project

  def project do
    [
      app: :omg_watcher_rpc,
      version: "#{String.trim(File.read!("../../VERSION"))}",
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
      extra_applications: [:logger, :runtime_tools, :telemetry]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  defp deps do
    [
      {:phoenix, "~> 1.3"},
      {:plug_cowboy, "~> 1.0"},
      {:cors_plug, "~> 2.0"},
      {:spandex_phoenix, "~> 0.4.1"},
      {:spandex_datadog, "~> 0.4"},
      {:telemetry, "~> 0.4.0"},
      # UMBRELLA
      {:omg_bus, in_umbrella: true},
      {:omg_utils, in_umbrella: true},
      # {:omg_watcher, in_umbrella: true},
      {:omg_watcher_security, in_umbrella: true}
    ]
  end
end
